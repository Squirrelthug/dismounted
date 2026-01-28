--[[
    Dude Where's My K'arroc UI - Simple settings panel
]]

local ADDON_NAME = "DudeWheresMyKarroc"

-- Get reference to main addon namespace if needed
local frame = CreateFrame("Frame", "DWMKSettingsPanel", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(400, 350)
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

-- Campaign name label
local campaignLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
campaignLabel:SetPoint("TOPLEFT", 20, -40)
campaignLabel:SetText("Active Campaign:")

local campaignName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
campaignName:SetPoint("LEFT", campaignLabel, "RIGHT", 5, 0)

-- Ground Mount section
local groundLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groundLabel:SetPoint("TOPLEFT", 20, -70)
groundLabel:SetText("Ground Mount:")

local groundMountName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
groundMountName:SetPoint("TOPLEFT", 20, -90)
groundMountName:SetTextColor(0.7, 0.7, 0.7)

local tag = 
        "|cffffa500D|r" .. -- orange
        "|cffff0000W|r" .. -- red
        "|cff00ff00M|r" .. -- green
        "|cff0000ffK|r"    -- blue

local groundButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
groundButton:SetSize(140, 25)
groundButton:SetPoint("TOPLEFT", 20, -110)
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
flyingLabel:SetPoint("TOPLEFT", 20, -145)
flyingLabel:SetText("Flying Mount:")

local flyingMountName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
flyingMountName:SetPoint("TOPLEFT", 20, -165)
flyingMountName:SetTextColor(0.7, 0.7, 0.7)

local flyingButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
flyingButton:SetSize(140, 25)
flyingButton:SetPoint("TOPLEFT", 20, -185)
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

-- Enforcement Level dropdown
local enforcementLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enforcementLabel:SetPoint("TOPLEFT", 20, -220)
enforcementLabel:SetText("Enforcement Level:")

local enforcementDropdown = CreateFrame("Frame", "DWMKEnforcementDropdown", frame, "UIDropDownMenuTemplate")
enforcementDropdown:SetPoint("TOPLEFT", 10, -235)

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
radiusLabel:SetPoint("TOPLEFT", 20, -275)
radiusLabel:SetText("Anchor Radius:")

local radiusValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
radiusValue:SetPoint("LEFT", radiusLabel, "RIGHT", 5, 0)

local radiusSlider = CreateFrame("Slider", "DWMKRadiusSlider", frame, "OptionsSliderTemplate")
radiusSlider:SetPoint("TOPLEFT", 20, -295)
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

-- Update UI function
local function UpdateUI()
    local campaign = GetActiveCampaign()
    
    if not campaign then
        campaignName:SetText("None")
        groundMountName:SetText("No active campaign")
        flyingMountName:SetText("No active campaign")
        radiusValue:SetText("N/A")
        return
    end
    
    -- Campaign name
    campaignName:SetText(campaign.name)
    
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

-- Show/hide functions
frame:SetScript("OnShow", function(self)
    UpdateUI()
end)

-- Add slash command to show UI
_G["SLASH_DWMKCONFIG1"] = "/dwmkconfig"
SlashCmdList["DWMKCONFIG"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Add to existing /dm command
local oldSlashHandler = SlashCmdList["DWMK"]
SlashCmdList["DWMK"] = function(msg)
    if msg:lower():trim() == "config" then
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    else
        oldSlashHandler(msg)
    end
end

-- Update help text
local oldPrint = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, msg, ...)
    if msg and msg:match("Commands:") and msg:match("Dude Where's My K'arroc") then
        oldPrint(self, msg, ...)
        oldPrint(self, "[" .. tag .. "] " .. "/dwmk config - Open settings panel", ...)
        return
    end
    oldPrint(self, msg, ...)
end