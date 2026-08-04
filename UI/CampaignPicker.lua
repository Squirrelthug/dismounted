--[[
    UI/CampaignPicker.lua - choosing a campaign.

    One scrolling column, gentlest first. A single column is deliberate: strictness
    then reads top to bottom, and comparing two campaigns is a matter of running
    your eye down one line of labels rather than across a grid.

    Cards expand in place, like reading an item. Only one at a time - an accordion
    rather than a set of independent toggles - so the list never turns into a wall
    and the player is always comparing a detailed card against summarised ones.

    Getting started is two clicks from here: the default campaign is preselected
    and expanded, so Begin Campaign is immediately visible without reading
    anything at all.
]]

local ADDON, ns = ...

local Picker = {}
ns.Picker = Picker

local L = ns.L

local PANEL_W, PANEL_H = 560, 620
local CARD_SPACING = 8

local frame, scrollChild, cards, expandedIndex

--------------------------------------------------------------------------------
-- Committing to a campaign
--------------------------------------------------------------------------------

--- Finds an existing campaign running this preset, so choosing Stablehand twice
--- resumes the one you already had rather than piling up duplicates.
local function FindCampaignForPreset(presetKey)
    for id, campaign in pairs(DWMKDB.campaigns) do
        if campaign.preset == presetKey then
            return id
        end
    end
    return nil
end

local function BeginCampaign(data)
    local presetKey = data.presetKey

    local id = FindCampaignForPreset(presetKey)

    if not id then
        local preset = ns.Presets.Get(presetKey)
        id = ns.DB.MakeCampaignID(preset.name)
        DWMKDB.campaigns[id] = ns.DB.NewCampaign(presetKey, preset.name)
    end

    ns.DB.SetActiveCampaign(id)

    local campaign = DWMKDB.campaigns[id]
    ns.Notify.System(("Campaign set to |cffffd100%s|r."):format(campaign.name))

    -- Bonded is the one preset that cannot function until the player nominates a
    -- mount, so say so straight away rather than letting them discover it when
    -- the Ride key refuses to do anything.
    if campaign.rules.mountPolicy == ns.MOUNTPOLICY.SINGLE and not campaign.mounts.bonded then
        ns.Notify.System("Choose the mount you're bonded to in |cffffd100/dwmk config|r before you set out.")
    end

    ns.DB.GetGlobals().firstRunDone = true
    ns.RideButton.Update()
    if ns.Tracker then ns.Tracker.Update() end
    if ns.Config then ns.Config.Refresh() end

    Picker.Refresh()
    frame:Hide()
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

local function BuildData()
    local activeCampaign, activeID = ns.DB.GetActiveCampaign()
    local list = {}

    for _, preset in ipairs(ns.Presets.Ordered()) do
        -- Describe an existing campaign if the player already runs this preset,
        -- so an edited Custom shows its real rules rather than boilerplate.
        local existingID = FindCampaignForPreset(preset.key)
        local campaign = existingID and DWMKDB.campaigns[existingID]
            or ns.DB.NewCampaign(preset.key, preset.name)

        table.insert(list, {
            presetKey     = preset.key,
            name          = preset.name,
            hook          = preset.hook,
            chips         = ns.Presets.Chips(campaign),
            rows          = ns.Presets.CardRows(campaign),
            severityColor = ns.Presets.SeverityColor(campaign),
            isActive      = (existingID ~= nil and existingID == activeID),
        })
    end

    return list
end

local function LayoutCards()
    local y = 0
    for i, card in ipairs(cards) do
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
        card:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        y = y + card:GetHeight() + CARD_SPACING
    end
    scrollChild:SetHeight(math.max(y, 1))
end

local function OnCardClicked(clicked)
    local index
    for i, card in ipairs(cards) do
        if card == clicked then index = i break end
    end
    if not index then return end

    if expandedIndex == index then
        expandedIndex = nil
        clicked:SetExpanded(false)
    else
        if expandedIndex and cards[expandedIndex] then
            cards[expandedIndex]:SetExpanded(false)
        end
        expandedIndex = index
        clicked:SetExpanded(true)
    end

    LayoutCards()
end

--------------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------------

local function Build()
    if frame then return end

    frame = CreateFrame("Frame", "DWMKPickerFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(PANEL_W, PANEL_H)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    tinsert(UISpecialFrames, "DWMKPickerFrame")  -- Escape closes it

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText(L.PICKER_TITLE)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 16, -32)
    subtitle:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(L.PICKER_SUBTITLE)
    subtitle:SetTextColor(0.75, 0.72, 0.66)

    local settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settings:SetSize(90, 22)
    settings:SetPoint("BOTTOMRIGHT", -14, 12)
    settings:SetText(SETTINGS or "Settings")
    settings:SetScript("OnClick", function()
        frame:Hide()
        ns.Config.Open()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -54)
    scroll:SetPoint("BOTTOMRIGHT", -32, 42)

    scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(PANEL_W - 52)
    scrollChild:SetHeight(1)
    scroll:SetScrollChild(scrollChild)

    cards = {}
    for i = 1, #ns.Presets.Ordered() do
        cards[i] = ns.Widgets.CreateCard(scrollChild, BeginCampaign, OnCardClicked)
    end

    frame:SetScript("OnShow", function()
        Picker.Refresh()
    end)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function Picker.Refresh()
    if not frame then return end

    local data = BuildData()

    -- Open on whichever campaign is running, or on the default for a new player,
    -- so Begin Campaign is on screen without any reading or scrolling.
    if expandedIndex == nil then
        for i, entry in ipairs(data) do
            if entry.isActive then expandedIndex = i break end
        end
        if not expandedIndex then
            for i, entry in ipairs(data) do
                if entry.presetKey == ns.Presets.Default().key then expandedIndex = i break end
            end
        end
    end

    for i, entry in ipairs(data) do
        local card = cards[i]
        card.expanded = (i == expandedIndex)
        card:SetCampaign(entry)
        card:Show()
    end

    LayoutCards()
end

function Picker.Open()
    Build()
    frame:Show()
end

function Picker.Toggle()
    Build()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Picker.IsShown()
    return frame and frame:IsShown()
end
