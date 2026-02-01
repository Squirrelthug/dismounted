--[[
    Dude Where's My K'arroc UI - Simple settings panel
]]

local ADDON_NAME = "DudeWheresMyKarroc"
local UpdateUI

-- Get reference to main addon namespace if needed
local frame = CreateFrame("Frame", "DWMKSettingsPanel", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(400, 450)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

-- Title
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", 0, -5)
frame.title:SetText("Dude Where's My K'arroc - Campaign Settings")

-- Helper function to get active campaign
local function GetActiveCampaign()
    if not DismountedCharDB or not DismountedCharDB.activeCampaign then
        return nil
    end
    return DismountedDB.campaigns[DismountedCharDB.activeCampaign]
end

-- Helper function to get current mount info
local function GetCurrentMountInfo()
    if not IsMounted() then
        return nil
    end
    
    if UnitOnTaxi("player") then
        return nil
    end
    
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not auraData then break end
            
            if C_MountJournal and C_MountJournal.GetMountFromSpell then
                local mountID = C_MountJournal.GetMountFromSpell(auraData.spellId)
                if mountID then
                    local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
                    return {
                        mountID = mountID,
                        spellID = auraData.spellId,
                        name = name or auraData.name,
                        icon = icon
                    }
                end
            end
        end
    end
    return nil
end

local tag = 
        "|cffffa500D|r" .. -- orange
        "|cffff0000W|r" .. -- red
        "|cff00ff00M|r" .. -- green
        "|cff0000ffK|r"    -- blue

--------------------------------------------------------------------------------
-- Campaign Management Section
--------------------------------------------------------------------------------

local campaignSectionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
campaignSectionLabel:SetPoint("TOPLEFT", 20, -30)
campaignSectionLabel:SetText("Campaign Management")

-- Campaign Selection Dropdown
local activeCampaignLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
activeCampaignLabel:SetPoint("TOPLEFT", 20, -55)
activeCampaignLabel:SetText("Active Campaign:")

local campaignDropdown = CreateFrame("Frame", "DWMKCampaignDropdown", frame, "UIDropDownMenuTemplate")
campaignDropdown:SetPoint("TOPLEFT", 10, -70)
UIDropDownMenu_SetWidth(campaignDropdown, 180)

local deleteCampaignButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
deleteCampaignButton:SetSize(100, 22)
deleteCampaignButton:SetPoint("TOPLEFT", 250, -75)
deleteCampaignButton:SetText("Delete Campaign")

-- New Campaign Creation
local newCampaignEditBox = CreateFrame("EditBox", "DWMKNewCampaignEditBox", frame, "InputBoxTemplate")
newCampaignEditBox:SetSize(150, 20)
newCampaignEditBox:SetPoint("TOPLEFT", 25, -105)
newCampaignEditBox:SetAutoFocus(false)
newCampaignEditBox:SetMaxLetters(30)
newCampaignEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
newCampaignEditBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)

local createCampaignButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
createCampaignButton:SetSize(70, 22)
createCampaignButton:SetPoint("LEFT", newCampaignEditBox, "RIGHT", 10, 0)
createCampaignButton:SetText("Create")

--------------------------------------------------------------------------------
-- Separator 1
--------------------------------------------------------------------------------

local separator = frame:CreateTexture(nil, "ARTWORK")
separator:SetSize(360, 1)
separator:SetPoint("TOPLEFT", 20, -135)
separator:SetColorTexture(0.5, 0.5, 0.5, 0.5)

--------------------------------------------------------------------------------
-- Mount Assignment Section
--------------------------------------------------------------------------------

-- Ground Mount section
local groundLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groundLabel:SetPoint("TOPLEFT", 20, -150)
groundLabel:SetText("Ground Mount:")

local groundMountName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
groundMountName:SetPoint("TOPLEFT", 20, -170)
groundMountName:SetTextColor(0.7, 0.7, 0.7)

local groundButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
groundButton:SetSize(140, 25)
groundButton:SetPoint("TOPLEFT", 20, -190)
groundButton:SetText("Set Current Mount")
groundButton:SetScript("OnClick", function()
    local campaign = GetActiveCampaign()
    if not campaign then
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "No active campaign")
        return
    end
    
    local mountInfo = GetCurrentMountInfo()
    if not mountInfo then
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "You must be mounted to set a mount")
        return
    end
    
    campaign.mounts.ground = mountInfo.spellID
    groundMountName:SetText(mountInfo.name)
    DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "Ground mount set to: " .. mountInfo.name)
end)

local groundClearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
groundClearButton:SetSize(60, 25)
groundClearButton:SetPoint("LEFT", groundButton, "RIGHT", 5, 0)
groundClearButton:SetText("Clear")
groundClearButton:SetScript("OnClick", function()
    local campaign = GetActiveCampaign()
    if campaign then
        campaign.mounts.ground = nil
        groundMountName:SetText("Not assigned")
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "Ground mount cleared")
    end
end)

-- Flying Mount section
local flyingLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
flyingLabel:SetPoint("TOPLEFT", 20, -225)
flyingLabel:SetText("Flying Mount:")

local flyingMountName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
flyingMountName:SetPoint("TOPLEFT", 20, -245)
flyingMountName:SetTextColor(0.7, 0.7, 0.7)

local flyingButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
flyingButton:SetSize(140, 25)
flyingButton:SetPoint("TOPLEFT", 20, -265)
flyingButton:SetText("Set Current Mount")
flyingButton:SetScript("OnClick", function()
    local campaign = GetActiveCampaign()
    if not campaign then
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "No active campaign")
        return
    end
    
    local mountInfo = GetCurrentMountInfo()
    if not mountInfo then
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "You must be mounted to set a mount")
        return
    end
    
    campaign.mounts.flying = mountInfo.spellID
    flyingMountName:SetText(mountInfo.name)
    DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "Flying mount set to: " .. mountInfo.name)
end)

local flyingClearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
flyingClearButton:SetSize(60, 25)
flyingClearButton:SetPoint("LEFT", flyingButton, "RIGHT", 5, 0)
flyingClearButton:SetText("Clear")
flyingClearButton:SetScript("OnClick", function()
    local campaign = GetActiveCampaign()
    if campaign then
        campaign.mounts.flying = nil
        flyingMountName:SetText("Not assigned")
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "Flying mount cleared")
    end
end)

--------------------------------------------------------------------------------
-- Separator 2
--------------------------------------------------------------------------------

local separator2 = frame:CreateTexture(nil, "ARTWORK")
separator2:SetSize(360, 1)
separator2:SetPoint("TOPLEFT", 20, -300)
separator2:SetColorTexture(0.5, 0.5, 0.5, 0.5)

--------------------------------------------------------------------------------
-- Settings Section
--------------------------------------------------------------------------------

-- Enforcement Level dropdown
local enforcementLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enforcementLabel:SetPoint("TOPLEFT", 20, -315)
enforcementLabel:SetText("Enforcement Level:")

local enforcementDropdown = CreateFrame("Frame", "DWMKEnforcementDropdown", frame, "UIDropDownMenuTemplate")
enforcementDropdown:SetPoint("TOPLEFT", 10, -330)

local LEVELS = {
    {value = 0, text = "Off (No enforcement)"},
    {value = 1, text = "Permissive (Warnings only)"},
    {value = 2, text = "Balanced (3s grace period)"},
    {value = 3, text = "Strict (Immediate dismount)"}
}

UIDropDownMenu_SetWidth(enforcementDropdown, 200)
UIDropDownMenu_Initialize(enforcementDropdown, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    
    for _, levelData in ipairs(LEVELS) do
        info.text = levelData.text
        info.value = levelData.value
        info.func = function(self)
            local campaign = GetActiveCampaign()
            if campaign then
                campaign.settings.enforcementLevel = self.value
                UIDropDownMenu_SetText(enforcementDropdown, self:GetText())
                DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] " .. "Enforcement level set to: " .. self:GetText())
            end
        end
        UIDropDownMenu_AddButton(info)
    end
end)

-- Anchor Radius slider
local radiusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
radiusLabel:SetPoint("TOPLEFT", 20, -370)
radiusLabel:SetText("Anchor Radius:")

local radiusValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
radiusValue:SetPoint("LEFT", radiusLabel, "RIGHT", 5, 0)

local radiusSlider = CreateFrame("Slider", "DWMKRadiusSlider", frame, "OptionsSliderTemplate")
radiusSlider:SetPoint("TOPLEFT", 20, -390)
radiusSlider:SetMinMaxValues(10, 200)
radiusSlider:SetValueStep(5)
radiusSlider:SetObeyStepOnDrag(true)
radiusSlider:SetWidth(200)
DWMKRadiusSliderLow:SetText("10")
DWMKRadiusSliderHigh:SetText("200")
radiusSlider:SetScript("OnValueChanged", function(self, value)
    local campaign = GetActiveCampaign()
    if campaign then
        campaign.settings.anchorRadius = value
        radiusValue:SetText(value .. " yards")
    end
end)

--------------------------------------------------------------------------------
-- Update UI function
--------------------------------------------------------------------------------

local function UpdateUI()
    local campaign = GetActiveCampaign()
    
    if not campaign then
        groundMountName:SetText("No active campaign")
        flyingMountName:SetText("No active campaign")
        radiusValue:SetText("N/A")
        return
    end
    
    -- Ground mount
    if campaign.mounts.ground then
        local mountID = C_MountJournal.GetMountFromSpell(campaign.mounts.ground)
        if mountID then
            local name = C_MountJournal.GetMountInfoByID(mountID)
            groundMountName:SetText(name or "Unknown")
        else
            groundMountName:SetText("Spell ID: " .. campaign.mounts.ground)
        end
    else
        groundMountName:SetText("Not assigned")
    end
    
    -- Flying mount
    if campaign.mounts.flying then
        local mountID = C_MountJournal.GetMountFromSpell(campaign.mounts.flying)
        if mountID then
            local name = C_MountJournal.GetMountInfoByID(mountID)
            flyingMountName:SetText(name or "Unknown")
        else
            flyingMountName:SetText("Spell ID: " .. campaign.mounts.flying)
        end
    else
        flyingMountName:SetText("Not assigned")
    end
    
    -- Enforcement level
    local level = campaign.settings.enforcementLevel or 1
    for _, levelData in ipairs(LEVELS) do
        if levelData.value == level then
            UIDropDownMenu_SetText(enforcementDropdown, levelData.text)
            break
        end
    end
    
    -- Anchor radius
    local radius = campaign.settings.anchorRadius or 30
    radiusSlider:SetValue(radius)
    radiusValue:SetText(radius .. " yards")
end

--------------------------------------------------------------------------------
-- Campaign Dropdown Initialization
--------------------------------------------------------------------------------

local function InitializeCampaignDropdown()
    UIDropDownMenu_Initialize(campaignDropdown, function(self, level)
        if not DismountedDB or not DismountedDB.campaigns then
            return
        end

        local info = UIDropDownMenu_CreateInfo()
        local currentCampaignID = DismountedCharDB and DismountedCharDB.activeCampaign

        for campaignID, campaignData in pairs(DismountedDB.campaigns) do
            info.text = campaignData.name
            info.value = campaignID
            info.checked = (campaignID == currentCampaignID)
            info.func = function(self)
                DismountedCharDB.activeCampaign = self.value
                UIDropDownMenu_SetText(campaignDropdown, DismountedDB.campaigns[self.value].name)
                DEFAULT_CHAT_FRAME:AddMessage("[".. tag .."] Switched to campaign: " .. DismountedDB.campaigns[self.value].name)
                UpdateUI()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
end

--------------------------------------------------------------------------------
-- Button Click Handlers
--------------------------------------------------------------------------------

createCampaignButton:SetScript("OnClick", function()
    local newName = newCampaignEditBox:GetText():trim()

    if newName == "" then        
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] Please enter a campaign name")
        return
    end

    -- generate unique id
    local campaignID = newName:lower():gsub("%s+", "_"):gsub("[^%w_]", "")

    -- ensure unique id
    local baseID = campaignID
    local counter = 1
    while DismountedDB.campaigns[campaignID] do
        campaignID = baseID .. "_" .. counter
        counter = counter + 1
    end

    -- create new campaign using exposed function
    local newCampaign
    if DWMK_CreateCampaign then
        newCampaign = DWMK_CreateCampaign(newName)
    else
        -- fallback if function not available
        DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] WARNING[UI.lua]: local newCampaign fallback triggered")
        newCampaign = {
            name = newName,
            created = time(),
            lastUsed = time(),
            settings = {
                enforcementLevel = 1,
                anchorRadius = 30,
            },
            mounts = {
                ground = nil,
                flying = nil,
            },
            anchors = {}
        }
    end

    DismountedDB.campaigns[campaignID] = newCampaign
    DismountedCharDB.activeCampaign = campaignID

    newCampaignEditBox:SetText("")
    newCampaignEditBox:ClearFocus()

    InitializeCampaignDropdown()
    UIDropDownMenu_SetText(campaignDropdown, newName)
    UpdateUI()

    DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "] Created and switched to campaign: " .. newName)
end)

deleteCampaignButton:SetScript("OnClick", function()
    local currentCampaignID = DismountedCharDB and DismountedCharDB.activeCampaign

    if not currentCampaignID then
        DEFAULT_CHAT_FRAME:AddMessage("[".. tag .. "] No Campaign to delete")
        return
    end

    local campaignName = DismountedDB.campaigns[currentCampaignID].name

    -- show confirmation dialog
    StaticPopupDialogs["DWMK_DELETE_CAMPAIGN"] = {
        text = "Are you sure you want to delete the campaign:\n\n|cFFFFFF00" .. campaignName .. "|r\n\nThis will remove all mount assignments and anchors for this campaign.",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            -- delete the campaign
            DismountedDB.campaigns[currentCampaignID] = nil

            -- find another campaign to switch to, or create default
            local newCampaignID = nil
            for campaignID in pairs(DismountedDB.campaigns) do
                newCampaignID = campaignID
                break
            end

            if not newCampaignID then
                -- no campaigns left, create a new default
                if DWMK_CreateCampaign then
                    DismountedDB.campaigns["default"] = DWMK_CreateCampaign("Default Campaign")
                else
                    DismountedDB.campaigns["default"] = {
                        name = "Default Campaign",
                        created = time(),
                        lastUsed = time(),
                        settings = {
                            enforcementLevel = 1,
                            anchorRadius = 30,
                        },
                        mounts = {
                            ground = nil,
                            flying = nil,
                        },
                        anchors = {}
                    }
                end
                newCampaignID = "default"
                DEFAULT_CHAT_FRAME:AddMessage("[".. tag .."] Created new default campaign")
            end

            DismountedCharDB.activeCampaign = newCampaignID

            -- refresh UI
            InitializeCampaignDropdown()
            UIDropDownMenu_SetText(campaignDropdown, DismountedDB.campaigns[newCampaignID].name)
            UpdateUI()

            DEFAULT_CHAT_FRAME:AddMessage("[".. tag .."] Deleted campaign: " .. campaignName)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("DWMK_DELETE_CAMPAIGN")
end)

--------------------------------------------------------------------------------
-- Show/hide functions
--------------------------------------------------------------------------------

frame:SetScript("OnShow", function(self)
    InitializeCampaignDropdown()
    UpdateUI()
end)

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------

-- Add slash command to show UI
_G["SLASH_DWMKCONFIG1"] = "/dwmkconfig"
SlashCmdList["DWMKCONFIG"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Add to existing /dwmk command by wrapping the original handler
local oldSlashHandler = SlashCmdList["DWMK"]
SlashCmdList["DWMK"] = function(msg)
    if msg:lower():trim() == "config" then
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    elseif oldSlashHandler then
        oldSlashHandler(msg)
    end
end
