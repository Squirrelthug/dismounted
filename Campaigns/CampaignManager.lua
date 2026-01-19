-- manages campaign lifecycle, selection, and validation

local _, ns = ...
local CampaignManager = {}
ns.CampaignManager = CampaignManager

local Defaults = ns.CampaignDefaults

function CampaignManager:Initialize()
    if not DismountedDB then
        DismountedDB = {}
    end

    if not DismountedDB.campaigns then
        DismountedDB.campaigns = {}
    end

    if not DismountedDB.activeCampaignID then
        DismountedDB.activeCampaignID = nil
    end

    -- ensure default campaign exists
    if not DismountedDB.campaigns[Defaults.DefaultCampaign.id] then
        self:CreateCampaign(CopyTable(Defaults.DefaultCampaign))
        DismountedDB.activeCampaignID = Defaults.DefaultCampaign.id
    end

    -- validation of active campaign
    if DismountedDB.activeCampaignID then
        if not DismountedDB.campaigns[DismountedDB.activeCampaignID] then
            DismountedDB.activeCampaignID = Defaults.DefaultCampaign.id
        end
    end
end

-- Create new campaign
function CampaignManager:CreateCampaign(campaignData)
    if not campaignData or not campaignData.id then
        return false
    end

    if DismountedDB.campaigns[campaignData.id] then
        return false
    end

    -- ensure required fields
    campaignData.schemaVersion = campaignData.schemaVersion or Defaults.CAMPAIGN_SCHEMA_VERSION
    campaignData.settings = campaignData.settings or CopyTable(Defaults.DefaultSettings)
    campaignData.mounts = campaignData.mounts or {}

    DismountedDB.campaigns[campaignData.id] = campaignData
    return true
end

-- activate campaign by id
function CampaignManager:SetActiveCampaign(campaignID)
    if campaignID = nil then
        DismountedDB.activeCampaignID = nil
        return true
    end
    
    if not DismountedDB.campaigns[campaignID] then
        return false
    end

    DismountedDB.activeCampaignID = campaignID
    return true
end

-- get acive campaign table
function CampaignManager:GetActiveCampaign()
    local id = DismountedDB.activeCampaignID
    if not id  then
        returns nil
    end
    return DismountedDB.campaigns[id]
end

-- get active campaign ID
function CampaignManager:GetActiveCampaignID()
    return DismountedDB.activeCampaignID
end

-- safe accessor for campaign settings
function CampaignManager:GetActiveCampaignSettings()
    local campaign = self.GetActiveCampaign()
    if not campaign then
        return nil
    end
    return campaign.settings
end

-- get mount store for active campaign
function CampaignManager:GetActiveCampaignMounts()
    local campaign = self.GetActiveCampaign()
    if not campaign then
        return nil
    end
    return campaign.mounts
end

-- iterate campaigns
function CampaignManager:IterateCampaigns()
    return pairs(DismountedDB.campaigns)
end

-- system active check
function CampaignManager:IsCampaignActive()
    return DismountedDB.activeCampaignID ~= nil
end

return CampaignManager
