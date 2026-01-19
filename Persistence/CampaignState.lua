local CampaignState = {}
CampaignState.__index = CampaignState

local function EnsureCampaignRoot()
    if not DismountedDB then
        return nil
    end

    DismountedDB.campaigns = DismountedDB.campaigns or {}
    return DismountedDB.campaigns
end

function CampaignState:CreateCampaign(campaignID, campaignName)
    if not campaignID then
        return nil
    end

    local campaigns = EnsureCampaignRoot()
    if not campaigns then
        return nil
    end

    if campaigns[campaignID] then
        return campaigns[campaignID]
    end

    campaigns[campaignID] = {
        id = campaignID,
        name = campaignName or "Unnamed Campaign",
        -- timestamp metadata
        createdAt = time(),
        lastAccessedAt = time(),
        -- campaign systems
        mounts = {},
        narrativeFlags = {},
        settingsSnapshot = {},
        version = 1,
    }

    return campaigns[campaignID]
end

function CampaignState:GetCampaign(campaignID)
    if not campaignID then
        return nil
    end

    local campaigns = EnsureCampaignRoot()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self()
    if not campaigns then
        return nil
    end

    local campaign = campaigns[campaignID]
    if campaign then
        campaign.lastAccessedAt = time()
    end

    return campaign
end

function CampaignState:SetNarrativeFlag(campaignID, flagKey, value)
    local campaign = self:GetCampaign(campaignID)
    if not campaign or not flagKey then
        return false
    end

    campaign.narrativeFlags[flagKey] = value ~= false
    return true
end

function CampaignState:GetNarrativeFlag(campaignID, flagKey)
    local campaign = self:GetCampaign(campaignID)
    if not campaign or not flagKey then
        return nil
    end

    return campaign.narrativeFlags[flagKey]
end

function CampaignState:GetAllCampaigns()
    local campaigns = EnsureCampaignRoot()
    if not campaigns then
        return nil
    end

    return campaigns
end

function CampaignState:DeleteCampaign(campaignID)
    if not campaignID then
        return false
    end

    local campaigns = EnsureCampaignRoot()
    if not campaigns or not campaigns[campaignID] then
        return false
    end

    campaigns[campaignID] = nil
    return true
end

return CampaignState
