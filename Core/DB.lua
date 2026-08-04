--[[
    Core/DB.lua - saved variables, schema and the v1 -> v2 migration.

    Split of responsibility:

      DWMKDB (account)      campaigns and their rules, plus global preferences.
                            Rules are shared deliberately: a campaign is a game
                            type, and you should be able to run the same one on
                            several characters.

      DWMKCharDB (character) which campaign this character is running, where this
                            character left its mounts, and the state of this
                            character's retrieval.

    Version 1.x kept anchors on the campaign, which is account-wide - so two
    characters running the same campaign silently overwrote each other's mount
    locations. Anchors are per-character here, which fixes that.
]]

local ADDON, ns = ...

local DB = {}
ns.DB = DB

--------------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------------

local function DefaultGlobals()
    return {
        bell           = false,  -- off by default, as specified
        autoRestorePin = true,
        showTracker    = true,
        chatFrame      = 1,
        firstRunDone   = false,
        migratedFromV1 = false,
    }
end

local function DefaultRetrieval()
    return {
        state             = ns.STATE.IDLE,
        spellID           = nil,
        mapID             = nil,
        x                 = nil,
        y                 = nil,
        leftAt            = nil,
        dispatchedAt      = nil,   -- when Timer A started
        pickedUpAt        = nil,   -- when Timer A ended and Timer B was locked in
        deliverySeconds   = nil,   -- the locked Timer B value; never recalculated
        announcedApproach = false, -- "you can see it from here", re-armable
        announcedNearly   = false, -- "close now", fires once per delivery
        leftAnnounced     = false, -- "you leave your mount", fires once per anchor
    }
end

DB.DefaultRetrieval = DefaultRetrieval

--------------------------------------------------------------------------------
-- Campaign construction
--------------------------------------------------------------------------------

--- Builds a campaign from a preset definition. `presetKey` must exist in
--- ns.Presets; the caller is responsible for that.
function DB.NewCampaign(presetKey, name)
    local preset = ns.Presets.Get(presetKey)

    local rules = {}
    for k, v in pairs(preset.rules) do
        rules[k] = v
    end

    return {
        name     = name or preset.name,
        preset   = presetKey,
        created  = time(),
        lastUsed = time(),
        rules    = rules,
        mounts   = {
            ground     = nil,
            flying     = nil,
            bonded     = nil,
            bondedName = nil,
        },
        service  = ns.Presets.RollService(),
    }
end

--- Turns a display name into a stable, unique table key.
function DB.MakeCampaignID(name)
    local base = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
    if base == "" then base = "campaign" end

    local id, n = base, 1
    while DWMKDB.campaigns[id] do
        id = base .. "_" .. n
        n = n + 1
    end
    return id
end

--------------------------------------------------------------------------------
-- Accessors
--------------------------------------------------------------------------------

function DB.GetActiveCampaignID()
    return DWMKCharDB and DWMKCharDB.activeCampaign
end

function DB.GetActiveCampaign()
    local id = DB.GetActiveCampaignID()
    if not id or not DWMKDB or not DWMKDB.campaigns then return nil end
    return DWMKDB.campaigns[id], id
end

function DB.GetRules()
    local campaign = DB.GetActiveCampaign()
    return campaign and campaign.rules or nil
end

function DB.GetRetrieval()
    return DWMKCharDB and DWMKCharDB.retrieval
end

function DB.GetAnchors()
    return DWMKCharDB and DWMKCharDB.anchors
end

function DB.GetGlobals()
    return DWMKDB and DWMKDB.global
end

function DB.SetActiveCampaign(id)
    if not DWMKDB.campaigns[id] then return false end
    DWMKCharDB.activeCampaign = id
    DWMKDB.campaigns[id].lastUsed = time()
    return true
end

--- Rules a campaign carries only when its mount policy calls for them. The
--- config panel uses this to hide controls the active preset never consults,
--- rather than showing a wall of settings most of which do nothing.
function DB.RuleIsRelevant(ruleKey)
    local rules = DB.GetRules()
    if not rules then return false end

    if ruleKey == "groundOnly" then
        return true
    elseif ruleKey == "settlementDismount" then
        return true
    elseif ruleKey == "pickupRadius" then
        return true
    elseif ruleKey == "dispatch" then
        return rules.dispatch ~= ns.DISPATCH.NONE
    end

    return true
end

--------------------------------------------------------------------------------
-- v1 -> v2 migration
--
-- Version 1 shape:
--   DismountedDB     = { version = 1, campaigns = { [id] = { name, created,
--                        lastUsed, settings = { enforcementLevel, anchorRadius },
--                        mounts = { ground, flying }, anchors = {} } } }
--   DismountedCharDB = { activeCampaign = id }
--
-- Every migrated campaign lands on the Custom preset. That is deliberate: the
-- player configured those rules by hand, and silently reinterpreting them as one
-- of the named presets would change how their game plays without asking.
--------------------------------------------------------------------------------

local function MigrateEnforcement(oldLevel)
    -- v1: 0 Off, 1 Permissive (warn), 2 Balanced (grace then dismount), 3 Strict.
    -- The grace tier no longer exists, so 2 folds into Refuse alongside 3 - the
    -- player asked to be dismounted, and now it simply happens without the wait.
    if oldLevel == 0 then
        return ns.ENFORCE.OFF
    elseif oldLevel == 1 then
        return ns.ENFORCE.NOTIFY
    end
    return ns.ENFORCE.REFUSE
end

local function MigrateFromV1()
    if not DismountedDB or not DismountedDB.campaigns then return false end
    if DWMKDB.global.migratedFromV1 then return false end

    local migrated, usedGrace = 0, false

    for oldID, old in pairs(DismountedDB.campaigns) do
        if not DWMKDB.campaigns[oldID] then
            local settings = old.settings or {}

            if settings.enforcementLevel == 2 then
                usedGrace = true
            end

            local campaign = DB.NewCampaign("custom", old.name or oldID)
            campaign.created  = old.created  or time()
            campaign.lastUsed = old.lastUsed or time()

            campaign.rules.enforcement  = MigrateEnforcement(settings.enforcementLevel or 1)
            campaign.rules.pickupRadius = ns.PICKUP_RADIUS
            campaign.rules.mountPolicy  = ns.MOUNTPOLICY.ASSIGNED

            if old.mounts then
                campaign.mounts.ground = old.mounts.ground
                campaign.mounts.flying = old.mounts.flying
            end

            -- v1's anchorRadius governed how far you could stray before the mount
            -- counted as left behind. v2 has no such setting - a mount you walk
            -- away from is left behind, and the radius that matters now is how
            -- close you must get to collect it. Carry it into pickupRadius only
            -- if the player had widened it beyond our default.
            local oldRadius = tonumber(settings.anchorRadius)
            if oldRadius and oldRadius > ns.PICKUP_RADIUS then
                campaign.rules.pickupRadius = oldRadius
            end

            DWMKDB.campaigns[oldID] = campaign
            migrated = migrated + 1

            -- v1 anchors were account-wide. There is no way to know which
            -- character left which mount, so they land on whichever character
            -- logs in first and the rest start clean. Better than dropping them.
            if old.anchors then
                for spellID, anchor in pairs(old.anchors) do
                    if DWMKCharDB.anchors[spellID] == nil then
                        DWMKCharDB.anchors[spellID] = {
                            mapID = anchor[1],
                            x     = anchor[2],
                            y     = anchor[3],
                            at    = anchor[4] or time(),
                        }
                    end
                end
            end
        end
    end

    if migrated == 0 then return false end

    if DismountedCharDB and DismountedCharDB.activeCampaign
       and DWMKDB.campaigns[DismountedCharDB.activeCampaign] then
        DWMKCharDB.activeCampaign = DismountedCharDB.activeCampaign
    end

    DWMKDB.global.migratedFromV1 = true
    DWMKDB.global.firstRunDone   = true

    -- The v1 tables are left untouched on purpose, so a player who dislikes 2.0
    -- can roll back without losing anything. Core/DB.lua drops them in 2.1.
    return true, usedGrace
end

--------------------------------------------------------------------------------
-- Initialise
--------------------------------------------------------------------------------

function DB.Initialize()
    DWMKDB = DWMKDB or {}
    DWMKDB.schema    = DWMKDB.schema or ns.DB_SCHEMA
    DWMKDB.campaigns = DWMKDB.campaigns or {}
    DWMKDB.global    = DWMKDB.global or DefaultGlobals()

    -- Fill in any preference added after this profile was created.
    for k, v in pairs(DefaultGlobals()) do
        if DWMKDB.global[k] == nil then
            DWMKDB.global[k] = v
        end
    end

    DWMKCharDB = DWMKCharDB or {}
    DWMKCharDB.anchors   = DWMKCharDB.anchors or {}
    DWMKCharDB.retrieval = DWMKCharDB.retrieval or DefaultRetrieval()

    for k, v in pairs(DefaultRetrieval()) do
        if DWMKCharDB.retrieval[k] == nil then
            DWMKCharDB.retrieval[k] = v
        end
    end

    local migrated, usedGrace = MigrateFromV1()

    -- An active campaign that no longer exists (deleted on another character)
    -- falls back to any surviving campaign rather than erroring on every event.
    local activeID = DWMKCharDB.activeCampaign
    if activeID and not DWMKDB.campaigns[activeID] then
        DWMKCharDB.activeCampaign = nil
        for id in pairs(DWMKDB.campaigns) do
            DWMKCharDB.activeCampaign = id
            break
        end
    end

    return migrated, usedGrace
end

ns:OnLoad(function()
    local migrated, usedGrace = DB.Initialize()

    if migrated then
        ns.Notify.System(ns.L.MIGRATED)
        if usedGrace then
            ns.Notify.System(ns.L.MIGRATED_GRACE)
        end
    end
end)
