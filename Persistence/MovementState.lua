local MovementState = {}
MovementState.__index = MovementState

-- constants / enums
MovementState.RESTRICTION = {
    NONE = "NONE",
    WALK_ONLY = "WALK_ONLY",
}

MovementState.REASON = {
    SACRED_GROUND = "SACRED_GROUND",
    CITY_LAW = "CITY_LAW",
    INDOOR_RESTRICTION = "INDOOR_RESTRICTION",
    CAMPAIGN_RULE = "CAMPAIGN_RULE",
    SYSTEM_UNKNOWN = "SYSTEM_UNKNOWN",
}

-- internal helpers
local function EnsureCampaignRoot()
    if not DismountedDB then
        return nil
    end

    DismountedDB.campaigns = DismountedDB.campaigns or {}
    return DismountedDB.campaigns
end

local function GetCampaign(campaignID)
    if not campaignID then
        return nil
    end

    local campaigns = EnsureCampaignRoot()
    if not campaigns then
        return nil
    end

    return campaigns[campaignID]
end

local function DefaultMovementRecord()
    return {
        restriction = MovementState.RESTRICTION.NONE,
        reason = MovementState.REASON.SYSTEM_UNKNOWN,
        appliedAt = nil,
        expiresAt = nil,
        meta = {},
    }
end

local function EnsureMovementRecord(campaignID)
    local campaign = GetCampaign(campaignID)
    if not campaign then
        return nil
    end

    campaign.movement = campaign.movement or DefaultMovementRecord()
    return campaign.movement
end

-- public accessors
function MovementState:Get(campaignID)
    if not campaignID then
        return nil
    end

    return EnsureMovementRecord(campaignID)
end

-- public mutation
function MovementState:SetRestriction(
    campaignID,
    restriction,
    reason,
    expiresAt,
    meta,
)
    if not campaignID or not restriction then
        return false
    end

    local record = EnsureMovementRecord(campaignID)
    if not record then
        return false
    end

    local isKnown = false
    for _, v in pairs(MovementState.RESTRICTION) do
        if v == restriction then
            isKnown = true
            break
        end
    end
    if not isKnown then
        return false
    end

    record.restriction = restriction
    record.reason = reason or MovementState.REASON.SYSTEM_UNKNOWN
    record.appliedAt = time()
    record.expiresAt = expiresAt

    if type(meta) == "table" then
        record.meta = meta
    else
        record.meta = {}
    end

    return true
end
