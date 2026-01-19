local MountState = {}
MountState.__index = MountState

-- constants/enums
MountState.CUSTODY = {
    WITH_PLAYER = "WITH_PLAYER",
    ANCHORED = "ANCHORED",
    STABLED = "STABLED",
    DISPLACED = "DISPLACED",
    UNKNOWN = "UNKNOWN",
}

MountState.DISMOUNT_REASON = {
    VOLUNTARY = "VOLUNTARY",
    RULE_VIOLATION_ZONE = "RULE_VIOLATION_ZONE",
    RULE_VIOLATION_MOUNT = "RULE_VIOLATION_MOUNT",
    AIRSPACE_VIOLATION = "AIRSPACE_VIOLATION",
    COMBAT_FORCED = "COMBAT_FORCED",
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

local function EnsureMountTable(campaign)
    if not campaign then
        return nil
    end

    campaign.mounts = campaign.mounts or {}
    return campaign.mounts
end

local function DefaultMountRecord()
    return {
        custody = MountState.CUSTODY.UNKNOWN,
        anchored = false,
        lastKnown = nil,
        lastSummonedAt = nil,
        lastDismountedAt = nil,
        lastDismountReason = MountState.DISMOUNT_REASON.SYSTEM_UNKNOWN,
    }
end

local function EnsureMountRecord(campaignID, mountID)
    if not mountID then
        return nil
    end

    local campaign = GetCampaign(campaignID)
    if not campaign then
        return nil
    end

    local mounts = EnsureMountTable(campaign)
    if not mounts then
        return nil
    end

    mounts[mountID] = mounts[mountID] or DefaultMountRecord()
    return mounts[mountID]
end

-- public accessors
function MountState:Get(campaignID, mountID)
    if not campaignID or not mountID then
        return nil
    end

    return EnsureMountRecord(campaignID, mountID)
end

-- anchoring / location updates
function MountState:SetAnchoredAt(
    campaignID,
    mountID,
    mapID,
    x,
    y,
    dismountReason,
)
    if not campaignID or not mountID or not mapID or not x or not y then
        return false
    end

    local record = EnsureMountRecord(campaignID, mountID)
    if not record then
        return false
    end

    record.custody = MountState.CUSTODY.ANCHORED
    record.anchored = true

    record.lastKnown = {
        mapID = mapID,
        x = x,
        y = y,
        at = time(),
    }

    record.lastDismountedAt = time()
    record.lastDismountReason = dismountReason or MountState.DISMOUNT_REASON.SYSTEM_UNKNOWN

    return true
end

-- custody updates
function MountState:SetWithPlayer(campaignID, mountID)
    if not campaignID or not mountID then
        return false
    end

    local record = EnsureMountRecord(campaignID, mountID)
    if not record then
        return false
    end

    record.custody = MountState.CUSTODY.WITH_PLAYER
    record.anchored = false
    
    record.lastSummonedAt = time()

    return true
end

-- maintenance
function MountState:ClearLocation(campaignID, mountID)
    if not campaignID or not mountID then
        return false
    end

    local record = EnsureMountRecord(campaignID, mountID)
    if not record then
        return false
    end

    record.lastKnown = nil
    record.anchored = false
    record.custody = MountState.CUSTODY.UNKNOWN

    return true
end
