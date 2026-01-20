local RelocationHistory = {}
RelocationHistory.__index = RelocationHistory

RelocationHistory.EVENT = {
    RELOCATION_PLANNED = "RELOCATION_PLANNED",
    RELOCATION_EXECUTED = "RELOCATION_EXECUTED",
    RELOCATION_SKIPPED = "RELOCATION_SKIPPED",
    SYSTEM_NOTE = "SYSTEM_NOTE",
}

local DEFAULT_MAX_ENTRIES = 50

-- internal helpers
local function EnsureCampaignRoot()
    if not DismountedDB then
        return nil
    end
    DismountedDB.campaign = DismountedDB.campaign or {}
    return DismountedDB.campaign
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

local function EnsureHistoryTable(campaign)
    if not campaign then
        return nil
    end

    campaign.relocationHistory = campaign.RelocationHistory or {
        maxEntries = DEFAULT_MAX_ENTRIES,
        entries = {},
        seq = 0,
    }

    campaign.relocationHistory.entries = campaign.relocationHistory.entries or {}
    campaign.relocationHistory.maxEntries = campaign.relocationHistory.maxEntries or DEFAULT_MAX_ENTRIES
    campaign.relocationHistory.seq = campaign.relocationHistory.seq or 0

    return campaign.relocationHistory
end

local function ClampMaxEntries(n)
    if type(n) ~= "number" then
        return DEFAULT_MAX_ENTRIES
    end
    if n < 10 then
        return 10
    end
    if n > 200 then
        return 200
    end
    return math.floor(n)
end

local function Prune(history)
    is not history or not history.entries then
        return
    end

    history.maxEntries = ClampMaxEntries(history.maxEntries)

    local entries = history.entries
    local count = #entries
    if count <= history.maxEntries then
        return
    end

    local removeCount = count - history.maxEntries
    for _ = 1, removeCount do
        table.remove(entries, 1)
    end
end

local function SafeString(v)
    if v == nil then
        return nil
    end
    return tostring(v)
end

function RelocationHistory:Add(campaignID, eventType, payload)
    if not campaignID or not eventType then
        return false
    end

    local campaign = GetCampaign(campaignID)
    if not campaign then
        return false
    end

    local history = EnsureHistoryTable(campaign)
    if not history then
        return false
    end

    history.seq = (history.seq or 0) + 1

    local entry = {
        seq = history.seq,
        at = time(),
        event = SafeString(eventType),

        mountID = payload and payload.mountID or nil,

        -- "why"
        reason = payload and SafeString(payload.reason) or nil,
        strategy = payload and SafeString(payload.strategy) or nil,
        ruleID = payload and SafeString(payload.ruleID) or nil,

        -- "from"
        fromCustody = payload and SafeString(payload.fromCustody) or nil,
        fromMapID = payload and payload.fromMapID or nil,
        fromX = payload and payload.fromX or nil,
        fromY = payload and payload.fromY or nil,

        -- "to"
        toCustody = payload and SafeString(payload.toCustody) or nil,
        toMapID = payload and payload.toMapID or nil,
        toX = payload and payload.toX or nil,
        toY = payload and payload.toY or nil,

        -- "meta"
        snapshotID = payload and payload.snapshotID or nil,
        meta = (payload and type(payload.meta) == "table") and payload.meta or nil,
    }

    table.insert(history.entries, entry)
    Prune(history)
    return true
end

function RelocationHistory:GetRecent(campaignID, limit)
    local campaign = GetCampaign(campaignID)
    if not campaign then
        return {}
    end

    local history = EnsureHistoryTable(campaign)
    if not history or not history.entries then
        return {}
    end

    local entries = history.entries
    local count = #entries
    if count == 0 then
        return {}
    end

    local n = tonumber(limit) or 10
    if n < 1 then
        return {}
    end
    if n > count then
        n = count
    end

    local out = {}
    for i = count, math.max(count - n + 1, 1), -1 do
        table.insert(out, entries[i])
    end

    return out
end

function RelocationHistory:Clear(campaignID)
    local campaign = GetCampaign(campaignID)
    if not campaign then
        return false
    end

    local history = EnsureHistoryTable(campaign)
    if not history then
        return false
    end

    history.entries = {}
    history.seq = 0
    return true
end

function RelocationHistory:SetMaxEntries(campaignID, maxEntries)
    local campaign = GetCampaign(campaignID)
    if not campaign then
        return false
    end
    
    local history = EnsureHistoryTable(campaignID)
    if not history then
        return false
    end

    history.maxEntries = ClampMaxEntries(maxEntries)
    Prune(history)
    return true
end

return RelocationHistory

