--[[
    Core/Mount.lua - where you are, what you're riding, and how far apart things are.

    Detection is carried over from version 1.x, which had it right: scan the
    player's helpful auras for one the mount journal recognises, and keep the
    spell ID from UNIT_SPELLCAST_SENT as a fallback for the cases where the aura
    scan comes up empty. Version 1.x had this logic copy-pasted into both of its
    files; there is one copy here.

    All distance work is same-map only. That is not a limitation we're working
    around - it's the design. A mount on a different map is simply "far", so no
    cross-continent world-coordinate machinery is needed anywhere in the addon.
]]

local ADDON, ns = ...

local Mount = {}
ns.Mount = Mount

--------------------------------------------------------------------------------
-- Mount type classification
--
-- Values from C_MountJournal.GetMountInfoExtraByID. The wiki's table is
-- explicitly incomplete, so unknown IDs are treated as flight-capable: a
-- ground-only campaign wrongly refusing an exotic mount is a visible annoyance
-- the player can work around, whereas one silently permitting a flyer breaks the
-- campaign without ever saying so.
--------------------------------------------------------------------------------

local FLYING_TYPES = {
    [242] = true,  -- Swift Spectral Gryphon (ghost mount, used while dead)
    [247] = true,  -- Disc of the Red Flying Cloud
    [248] = true,  -- most flying mounts
}

local SKYRIDING_TYPES = {
    [402] = true,  -- dragonriding, original
    [424] = true,  -- dragonriding / skyriding, current
}

local GROUND_TYPES = {
    [230] = true,  -- most ground mounts
    [231] = true,  -- slow aquatic (Riding Turtle)
    [232] = true,  -- fast aquatic (Vashj'ir Seahorse)
    [241] = true,  -- Qiraji Battle Tanks, Temple of Ahn'Qiraj only
    [254] = true,  -- deep sea (Poseidus, Fathom Dweller)
    [269] = true,  -- water striders
    [284] = true,  -- chauffeured
    [398] = true,  -- Kua'fon's Harness
    [407] = true,  -- Deepstar Polyp, Ottuk Carrier
    [408] = true,  -- Unsuccessful Prototype Fleetpod
    [412] = true,  -- Ottuk
    [436] = true,  -- Wondrous Wavewhisker
}

ns.MOUNTCLASS = {
    GROUND    = "ground",
    FLYING    = "flying",
    SKYRIDING = "skyriding",
}

--- Classifies a mount by its journal ID. Returns one of ns.MOUNTCLASS.
function Mount.Classify(mountID)
    if not mountID then return ns.MOUNTCLASS.FLYING end

    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    if not mountTypeID then return ns.MOUNTCLASS.FLYING end

    if GROUND_TYPES[mountTypeID] then
        return ns.MOUNTCLASS.GROUND
    elseif SKYRIDING_TYPES[mountTypeID] then
        return ns.MOUNTCLASS.SKYRIDING
    elseif FLYING_TYPES[mountTypeID] then
        return ns.MOUNTCLASS.FLYING
    end

    return ns.MOUNTCLASS.FLYING
end

--- True if this mount leaves the ground under any flight style.
function Mount.CanFly(mountID)
    local class = Mount.Classify(mountID)
    return class == ns.MOUNTCLASS.FLYING or class == ns.MOUNTCLASS.SKYRIDING
end

--------------------------------------------------------------------------------
-- Position
--------------------------------------------------------------------------------

--- Returns mapID, x, y for the player, or nil if the game can't place them
--- (loading screens, some instanced content).
function Mount.GetPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return nil end

    local x, y = position:GetXY()
    if not x or not y then return nil end

    return mapID, x, y
end

--------------------------------------------------------------------------------
-- Neighborhoods
--
-- Player housing neighborhoods are rested areas, which means the settlement rule
-- would otherwise refuse mounts in the player's own front garden. They are also
-- where people go to show mounts off - Blizzard is actively building toward
-- displaying mounts and pets at your house - so an addon that forbids riding
-- there is fighting the game.
--
-- So a neighborhood is treated as home ground: no rule applies inside one.
--
-- Every call is guarded. C_Housing arrived in 12.0 and the exact function set is
-- still moving, so a missing function must degrade to "not in a neighborhood"
-- rather than erroring on every mount.
--------------------------------------------------------------------------------

function Mount.InNeighborhood()
    if not C_Housing then return false end

    -- The broadest check: covers the whole neighborhood zone, not just the
    -- player's own plot.
    if C_Housing.IsOnNeighborhoodMap and C_Housing.IsOnNeighborhoodMap() then
        return true
    end

    -- Fallbacks, in case the map check misses an interior or an instanced plot.
    if C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot() then
        return true
    end
    if C_Housing.IsInsideHouse and C_Housing.IsInsideHouse() then
        return true
    end
    if C_Housing.IsInsidePlot and C_Housing.IsInsidePlot() then
        return true
    end

    return false
end

function Mount.GetMapName(mapID)
    if not mapID then return UNKNOWN end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("Map " .. mapID)
end

function Mount.FormatCoords(x, y)
    if not x or not y then return UNKNOWN end
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

--------------------------------------------------------------------------------
-- Distance
--------------------------------------------------------------------------------

--- Distance in yards between the player and a saved anchor.
---
--- Returns nil when the two are on different maps. Callers treat nil as "far"
--- rather than as an error - that is the whole cross-map story in this addon.
function Mount.DistanceToAnchor(anchor)
    if not anchor or not anchor.mapID then return nil end

    local mapID, x, y = Mount.GetPosition()
    if not mapID or mapID ~= anchor.mapID then return nil end

    local width, height = C_Map.GetMapWorldSize(mapID)
    if not width or not height then return nil end

    local dx = (x - anchor.x) * width
    local dy = (y - anchor.y) * height
    return math.sqrt(dx * dx + dy * dy)
end

--------------------------------------------------------------------------------
-- What am I riding?
--------------------------------------------------------------------------------

-- Set from UNIT_SPELLCAST_SENT. Kept as the fallback for the window where the
-- player is mounted but the aura hasn't surfaced in the scan yet.
local lastMountSpellID = nil

function Mount.GetLastCastSpellID()
    return lastMountSpellID
end

function Mount.ClearLastCastSpellID()
    lastMountSpellID = nil
end

--- Builds the info table for a spell ID, or nil if it isn't a mount.
local function InfoFromSpell(spellID)
    if not spellID or not C_MountJournal or not C_MountJournal.GetMountFromSpell then
        return nil
    end

    local mountID = C_MountJournal.GetMountFromSpell(spellID)
    if not mountID then return nil end

    local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
    return {
        mountID = mountID,
        spellID = spellID,
        name    = name,
        icon    = icon,
        class   = Mount.Classify(mountID),
    }
end

Mount.InfoFromSpell = InfoFromSpell

--- What the player is currently mounted on, or nil.
---
--- Taxi flights and vehicles return nil deliberately: a gryphon you did not
--- summon is not a mount you left anywhere, and no rule should ever fire on one.
function Mount.GetCurrent()
    if not IsMounted() then return nil end
    if UnitOnTaxi("player") then return nil end
    if UnitInVehicle("player") then return nil end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end

            local info = InfoFromSpell(aura.spellId)
            if info then
                info.name = info.name or aura.name
                return info
            end
        end
    end

    -- Aura scan found nothing the journal recognises. Fall back to whatever we
    -- last saw cast.
    return InfoFromSpell(lastMountSpellID)
end

--- Resolves a stored spell ID to a display name, for status text and emotes.
--- Version 1.x printed the raw spell ID here (DWMK.lua:622).
function Mount.NameFromSpell(spellID, fallbackName)
    if fallbackName then return fallbackName end
    local info = InfoFromSpell(spellID)
    return info and info.name or UNKNOWN
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- UNIT_SPELLCAST_SENT fires when the cast is sent, which is roughly 1.5 seconds
-- before the mount actually appears. Recording it here is what lets Core/Rules
-- reach its verdict before PLAYER_MOUNT_DISPLAY_CHANGED arrives, so an illegal
-- mount can be removed the moment it shows rather than after a round of checks.
ns:On("UNIT_SPELLCAST_SENT", function(unit, _, _, spellID)
    if unit ~= "player" then return end
    if not C_MountJournal or not C_MountJournal.GetMountFromSpell then return end

    if C_MountJournal.GetMountFromSpell(spellID) then
        lastMountSpellID = spellID
        if ns.Rules and ns.Rules.PreJudge then
            ns.Rules.PreJudge(spellID)
        end
    end
end)
