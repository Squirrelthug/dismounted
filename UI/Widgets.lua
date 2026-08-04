--[[
    UI/Widgets.lua - the pieces the picker and config panel are built from.

    The campaign card is the important one. Every card answers the same six
    questions in the same order, with the same labels in the same column. That
    repetition is the whole design: a player learns the shape once on the first
    card and can then read any campaign at a glance, or compare two by running
    their eye down a single column. Cards that each explained themselves in their
    own bespoke way would be prettier and far less useful.
]]

local ADDON, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local L = ns.L

local CARD_PADDING   = 12
local CHIP_HEIGHT    = 16
local CHIP_SPACING   = 6
local ROW_LABEL_W    = 118
local COLLAPSED_H    = 74

-- OptionsSliderTemplate needs a real frame name to build its labels, so sliders
-- are numbered rather than anonymous.
local sliderCount = 0

--------------------------------------------------------------------------------
-- Colour helpers
--------------------------------------------------------------------------------

--- Turns an "aarrggbb" hex string into r, g, b floats.
local function HexToRGB(hex)
    local r = tonumber(hex:sub(3, 4), 16) / 255
    local g = tonumber(hex:sub(5, 6), 16) / 255
    local b = tonumber(hex:sub(7, 8), 16) / 255
    return r, g, b
end

Widgets.HexToRGB = HexToRGB

--------------------------------------------------------------------------------
-- Chip
--
-- A short keyword with a tinted background. Colour carries severity, so a card's
-- strictness is readable before a single word has been processed.
--------------------------------------------------------------------------------

function Widgets.CreateChip(parent)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(CHIP_HEIGHT)

    chip.bg = chip:CreateTexture(nil, "BACKGROUND")
    chip.bg:SetAllPoints()

    chip.border = chip:CreateTexture(nil, "BORDER")
    chip.border:SetPoint("TOPLEFT", -1, 1)
    chip.border:SetPoint("BOTTOMRIGHT", 1, -1)

    chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chip.text:SetPoint("CENTER")

    function chip:SetChip(text, color)
        local r, g, b = HexToRGB(color)
        self.text:SetText(text)
        self.text:SetTextColor(r, g, b)
        self.bg:SetColorTexture(r, g, b, 0.14)
        self.border:SetColorTexture(r, g, b, 0.3)
        self:SetWidth(self.text:GetStringWidth() + 14)
    end

    return chip
end

--------------------------------------------------------------------------------
-- Rule row
--
-- Label in a fixed left column, wrapped body text to its right.
--------------------------------------------------------------------------------

local function CreateRuleRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(16)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("TOPLEFT")
    row.label:SetWidth(ROW_LABEL_W)
    row.label:SetJustifyH("LEFT")
    row.label:SetTextColor(HexToRGB(ns.COLOR.HIGHLIGHT))

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.label, "TOPRIGHT", 8, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetSpacing(2)
    row.text:SetTextColor(HexToRGB(ns.COLOR.BODY))

    function row:SetRow(label, text)
        self.label:SetText(label)
        self.text:SetText(text)
        -- Height follows the wrapped body, which is always the taller of the two.
        self:SetHeight(math.max(14, self.text:GetStringHeight() + 2))
    end

    return row
end

--------------------------------------------------------------------------------
-- Campaign card
--------------------------------------------------------------------------------

--- Creates a card. `onBegin(campaignOrPresetKey)` fires when the player commits.
function Widgets.CreateCard(parent, onBegin, onExpand)
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(COLLAPSED_H)

    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    card.bg:SetColorTexture(1, 1, 1, 0.03)

    card.hover = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.hover:SetAllPoints()
    card.hover:SetColorTexture(1, 1, 1, 0.05)
    card.hover:Hide()

    -- Severity stripe down the left edge. Reads faster than a dot at a glance,
    -- and survives being scrolled past at speed.
    card.stripe = card:CreateTexture(nil, "ARTWORK")
    card.stripe:SetPoint("TOPLEFT", 0, 0)
    card.stripe:SetPoint("BOTTOMLEFT", 0, 0)
    card.stripe:SetWidth(3)

    card.dot = card:CreateTexture(nil, "ARTWORK")
    card.dot:SetSize(8, 8)
    card.dot:SetPoint("TOPLEFT", CARD_PADDING, -CARD_PADDING - 3)
    card.dot:SetColorTexture(1, 1, 1, 1)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.title:SetPoint("TOPLEFT", CARD_PADDING + 16, -CARD_PADDING)
    card.title:SetJustifyH("LEFT")

    card.activeTag = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.activeTag:SetPoint("LEFT", card.title, "RIGHT", 8, 0)
    card.activeTag:SetText(L.PICKER_ACTIVE_TAG)
    card.activeTag:SetTextColor(HexToRGB(ns.COLOR.PERMISSIVE))
    card.activeTag:Hide()

    card.arrow = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.arrow:SetPoint("TOPRIGHT", -CARD_PADDING, -CARD_PADDING)
    card.arrow:SetText("+")
    card.arrow:SetTextColor(0.6, 0.6, 0.6)

    card.hook = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.hook:SetPoint("TOPLEFT", CARD_PADDING + 16, -CARD_PADDING - 20)
    card.hook:SetPoint("RIGHT", card, "RIGHT", -CARD_PADDING - 20, 0)
    card.hook:SetJustifyH("LEFT")
    card.hook:SetTextColor(0.78, 0.74, 0.66)

    card.chips = {}
    card.rows  = {}

    -- Expanded content -------------------------------------------------------

    card.divider = card:CreateTexture(nil, "ARTWORK")
    card.divider:SetHeight(1)
    card.divider:SetColorTexture(1, 1, 1, 0.09)
    card.divider:Hide()

    card.begin = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.begin:SetSize(150, 24)
    card.begin:SetText(L.PICKER_BEGIN)
    card.begin:Hide()

    ---------------------------------------------------------------------------

    card.expanded = false

    function card:SetCampaign(data)
        self.data = data

        local color = data.severityColor
        local r, g, b = HexToRGB(color)
        self.stripe:SetColorTexture(r, g, b, 0.85)
        self.dot:SetColorTexture(r, g, b, 1)
        self.title:SetText(data.name)
        self.title:SetTextColor(1, 1, 1)
        self.hook:SetText(data.hook)

        self.activeTag:SetShown(data.isActive)

        -- Chips
        for i = 1, #self.chips do self.chips[i]:Hide() end
        local x = 0
        for i, chipData in ipairs(data.chips) do
            local chip = self.chips[i]
            if not chip then
                chip = Widgets.CreateChip(self)
                self.chips[i] = chip
            end
            chip:SetChip(chipData.text, chipData.color)
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", self, "TOPLEFT", CARD_PADDING + 16 + x, -CARD_PADDING - 40)
            chip:Show()
            x = x + chip:GetWidth() + CHIP_SPACING
        end

        -- Rows
        for i = 1, #self.rows do self.rows[i]:Hide() end
        for i, rowData in ipairs(data.rows) do
            local row = self.rows[i]
            if not row then
                row = CreateRuleRow(self)
                self.rows[i] = row
            end
            row:SetRow(rowData.label, rowData.text)
        end

        self:Layout()
    end

    function card:Layout()
        if not self.expanded then
            self.divider:Hide()
            self.begin:Hide()
            for i = 1, #self.rows do self.rows[i]:Hide() end
            self.arrow:SetText("+")
            self:SetHeight(COLLAPSED_H)
            return
        end

        self.arrow:SetText("\226\128\147")  -- en dash, reads as "collapse"

        local y = COLLAPSED_H - 4

        self.divider:ClearAllPoints()
        self.divider:SetPoint("TOPLEFT", CARD_PADDING + 16, -y)
        self.divider:SetPoint("RIGHT", self, "RIGHT", -CARD_PADDING, 0)
        self.divider:Show()

        y = y + 10

        for i = 1, #self.rows do
            local row = self.rows[i]
            if self.data and self.data.rows[i] then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", CARD_PADDING + 16, -y)
                row:SetPoint("RIGHT", self, "RIGHT", -CARD_PADDING, 0)
                -- Re-measure now that the row has its final width; the wrapped
                -- height is meaningless until the frame knows how wide it is.
                row:SetRow(self.data.rows[i].label, self.data.rows[i].text)
                row:Show()
                y = y + row:GetHeight() + 5
            else
                row:Hide()
            end
        end

        y = y + 6
        self.begin:ClearAllPoints()
        self.begin:SetPoint("TOPRIGHT", -CARD_PADDING, -y)
        self.begin:Show()

        self:SetHeight(y + 24 + CARD_PADDING)
    end

    function card:SetExpanded(expanded)
        self.expanded = expanded
        self:Layout()
    end

    card:SetScript("OnEnter", function(self) self.hover:Show() end)
    card:SetScript("OnLeave", function(self) self.hover:Hide() end)

    card:SetScript("OnClick", function(self)
        if onExpand then onExpand(self) end
    end)

    card.begin:SetScript("OnClick", function()
        if onBegin and card.data then onBegin(card.data) end
    end)

    return card
end

--------------------------------------------------------------------------------
-- Config primitives
--------------------------------------------------------------------------------

--- A section heading with a rule beneath it.
function Widgets.CreateSectionHeader(parent, text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(28)

    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header.text:SetPoint("TOPLEFT")
    header.text:SetText(text)
    header.text:SetTextColor(HexToRGB(ns.COLOR.HIGHLIGHT))

    header.line = header:CreateTexture(nil, "ARTWORK")
    header.line:SetHeight(1)
    header.line:SetPoint("TOPLEFT", header.text, "BOTTOMLEFT", 0, -5)
    header.line:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    header.line:SetColorTexture(1, 1, 1, 0.1)

    return header
end

--- A checkbox with a description line underneath.
---
--- The description is not optional. A settings panel where every control is a
--- bare label is how you end up with the wall of options this addon is
--- explicitly trying not to be.
function Widgets.CreateCheckbox(parent, label, description, onChange)
    local container = CreateFrame("Frame", nil, parent)

    -- The label is ours rather than the template's. Templates that name their
    -- children $parentText give you nothing when the frame is anonymous, and
    -- naming every checkbox just to reach its label is not worth the globals.
    local check = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 0, 0)
    check:SetSize(24, 24)

    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", check, "RIGHT", 2, 0)
    labelText:SetText(label)

    local desc = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, 2)
    desc:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(description)
    desc:SetSpacing(2)

    container:SetHeight(28 + desc:GetStringHeight())

    check:SetScript("OnClick", function(self)
        if onChange then onChange(self:GetChecked()) end
    end)

    container.check = check
    container.desc  = desc

    function container:SetValue(v) check:SetChecked(v) end

    return container
end

--- A slider with a live value readout and a description.
function Widgets.CreateSlider(parent, label, description, min, max, step, onChange)
    local container = CreateFrame("Frame", nil, parent)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetText(label)

    local value = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("LEFT", text, "RIGHT", 6, 0)
    value:SetTextColor(HexToRGB(ns.COLOR.HIGHLIGHT))

    -- OptionsSliderTemplate builds its low/high/current labels as $parent-named
    -- children, so this one does need a unique name for them to exist.
    sliderCount = sliderCount + 1
    local sliderName = "DWMKSlider" .. sliderCount

    local slider = CreateFrame("Slider", sliderName, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 4, -10)
    slider:SetWidth(220)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local low, high = _G[sliderName .. "Low"], _G[sliderName .. "High"]
    if low  then low:SetText(tostring(min))  end
    if high then high:SetText(tostring(max)) end
    if _G[sliderName .. "Text"] then _G[sliderName .. "Text"]:SetText("") end

    -- Extra clearance below the slider for the template's own low/high labels.
    local desc = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, -16)
    desc:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(description)
    desc:SetSpacing(2)

    container:SetHeight(70 + desc:GetStringHeight())

    slider:SetScript("OnValueChanged", function(self, v)
        -- Round on the way out. Version 1.x wrote the raw float straight into
        -- saved variables and displayed "35.0000 yards".
        v = math.floor(v / step + 0.5) * step
        value:SetText(("%d yd"):format(v))
        if onChange then onChange(v) end
    end)

    function container:SetValue(v)
        slider:SetValue(v)
        value:SetText(("%d yd"):format(v))
    end

    container.slider = slider
    return container
end

--- A dropdown.
---
--- Built on DropdownButton and MenuUtil. UIDropDownMenu was deprecated in 11.0
--- with no compatibility shim and EasyMenu was removed outright, so the two
--- dropdowns version 1.x used had to be rewritten regardless of anything else.
function Widgets.CreateDropdown(parent, label, description, getOptions, onSelect)
    local container = CreateFrame("Frame", nil, parent)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetText(label)

    local dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    dropdown:SetWidth(260)

    local desc = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 2, -4)
    desc:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(description)
    desc:SetSpacing(2)

    container:SetHeight(52 + desc:GetStringHeight())

    dropdown:SetupMenu(function(_, rootDescription)
        for _, option in ipairs(getOptions()) do
            rootDescription:CreateRadio(
                option.text,
                function() return option.selected end,
                function()
                    onSelect(option.value)
                    dropdown:GenerateMenu()
                end
            )
        end
    end)

    function container:Refresh()
        for _, option in ipairs(getOptions()) do
            if option.selected then
                dropdown:SetDefaultText(option.text)
                break
            end
        end
    end

    container.dropdown = dropdown
    return container
end
