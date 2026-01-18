local ADDON_NAME, Addon = ...
local ContextBuilder = {}

Addon.ContextBuilder = ContextBuilder

-- localize global functions
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitFactionGroup = UnitFactionGroup
local IsMounted = IsMounted
local IsIndoors = IsIndoors
local IsFlying = IsFlying
local IsSwimming = IsSwimming

-- snapshotting for race conditions
local snapshotCounter = 0

local function NextSnapshotID()
    snapshotCounter = snapshotCounter + 1
    return snapshotCounter
end

-- misc builders
local function BuildMeta(triggerType)
    return {
        snapshotID = NextSnapshotID(),
        timestamp = GetTime(),
        addonVersion = Addon.version or "dev",
        evaluationReason = triggerType,
    }
end

local function BuildTrigger(trigger)
    return {
        type = trigger.type,
        unit = trigger.unit or "player",
        reactive = trigger.reactive or false,
        rawHint = trigger.rawHint,
    }
end

local function BuildCampaign()
    local Campaigns = Addon.Campaigns

    if not Campaigns or not Campaigns.IsActive() then
        return {
            active = false,
        }
    end

    local campaign = Campaigns.GetActiveCampaign()

    return {
        active = true,
        id = campaign.id,
        ruleProfile = campaign.ruleProfile,
        severity = campaign.severity,
        overrides = campaign.overrides,
    }
end

-- player section
local function BuildPlayer()
    local className, classFile = UnitClass("player"),
    local raceName, raceFile = Unitrace("player"),
    local faction = UnitFactionGroup("player")

    return {
        guid = UnitGUID("player"),
        level = UnitLevel("player"),
        class = classFile,
        race = raceFile,
        faction = faction,
        mounted = IsMounted(),
    }
end

local function BuildMovement()
    return{
        locomotion = IsMounted() and "mounted" or "ground",
        forced = UnitOnTaxi("player"),
        control = UnitIsDeadOrGhost("player") and "none" or "full",
    }
end

-- environments
local function BuildEnvironment()
    local mapID = C_Map.GetBestMapForUnit("player")
    local instanceName, instanceType = GetInstanceInfo()

    return {
        mapID = mapID,
        instanceType = instanceType,
        indoors = IsIndoors(),
        swimming = IsSwimming(),
        flying = IsFlying(),
        resting = IsResting(),
    }
end

-- mounts
local function BuildMounts()
    if not IsMounted() then
        return {
            mounted = false,
        }
    end

    local mountID = C_MountJournal.GetMountFromSpell(GetSpellInfo(SpellID))

    return {
        mounted = true,
        mountID = mountID,
        source = "spell",
    }
end

local function BuildHistory()
    local Persistence = Addon.Persistence
    if not Persistence then
        return {}
    end

    return Persistence.GetRecentMountHistory() or {}
end

local function BuildCapabilities()
    return {
        canDismount = not InCombatLockedown(),
        canBlockMount = true,
        canNotify = true,
    }
end

local function BuildIntegrity(context)
    local issues = {}

    if context.mount.mounted and not context.mount.mountID then
        table.insert(issues, "Mounted but mountID unknown")
    end

    return {
        issues = issues,
        safeToEnforce = #issues == 0,
    }
end

-- entry point
function ContextBuilder.Build(trigger)
    local context = {}

    context.meta = BuildMeta(trigger.type)
    context.trigger = BuildTrigger(trigger)
    context.campaign = BuildCampaign()
    context.player = BuildPlayer()
    context.environment = BuildEnvironment()
    context.mount = BuildMount()
    context.movement = BuildMovement()
    context.history = BuildHistory()
    context.capabilities = BuildCapabilities()
    context.integrity = BuildIntegrity(context)

    return context
end
