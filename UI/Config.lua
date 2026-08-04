--[[
    UI/Config.lua - settings, deliberately secondary.

    Getting started does not come through here. The picker does that in two
    clicks; this is for the player who has already chosen a campaign and now
    wants to adjust something.

    The organising principle is progressive disclosure. A named preset owns its
    rules, so its section shows what those rules are and no controls at all -
    there is nothing to fiddle with, because fiddling would mean you were no
    longer playing that campaign. Only Custom exposes the knobs.

    That is the answer to the WeakAuras problem: the panel is not a complete
    inventory of everything the addon can do. It shows what is relevant to the
    campaign you are actually running, and hides the rest.
]]

local ADDON, ns = ...

local Config = {}
ns.Config = Config

local L = ns.L

local panel, category, content
local controls = {}
local SECTION_GAP = 16

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Campaign()
    return ns.DB.GetActiveCampaign()
end

local function IsCustom()
    local c = Campaign()
    return c and ns.Presets.Get(c.preset).isCustom
end

--- Assigns whatever the player is currently riding to a campaign slot.
local function AssignCurrentMount(slot)
    local campaign = Campaign()
    if not campaign then return end

    local info = ns.Mount.GetCurrent()
    if not info then
        ns.Notify.System("You need to be riding a mount to assign it.")
        return
    end

    if slot == "ground" and ns.Mount.CanFly(info.mountID) then
        ns.Notify.System(("%s flies - assign it as the flying mount instead."):format(info.name))
        return
    end

    if slot == "bonded" then
        campaign.mounts.bonded     = info.spellID
        campaign.mounts.bondedName = info.name
    else
        campaign.mounts[slot] = info.spellID
    end

    ns.Notify.System(("%s set to |cffffd100%s|r."):format(
        slot == "ground" and "Ground mount" or (slot == "flying" and "Flying mount" or "Bonded mount"),
        info.name))

    ns.RideButton.Update()
    Config.Refresh()
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function BuildPanel()
    panel = CreateFrame("Frame", "DWMKConfigPanel")
    panel.name = L.ADDON_NAME

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(560)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    local y = 0
    local function Place(widget, extraGap)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -(y + (extraGap or 0)))
        widget:SetPoint("RIGHT", content, "RIGHT", -8, 0)
        y = y + widget:GetHeight() + (extraGap or 0) + 8
    end

    ----------------------------------------------------------------------------
    -- Campaign
    ----------------------------------------------------------------------------

    Place(ns.Widgets.CreateSectionHeader(content, L.CFG_SECTION_CAMPAIGN))

    controls.campaignName = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    controls.campaignName:SetPoint("TOPLEFT", 8, -y)
    y = y + 22

    controls.campaignHook = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    controls.campaignHook:SetPoint("TOPLEFT", 8, -y)
    controls.campaignHook:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    controls.campaignHook:SetJustifyH("LEFT")
    controls.campaignHook:SetTextColor(0.78, 0.74, 0.66)
    y = y + 24

    local changeBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    changeBtn:SetSize(160, 24)
    changeBtn:SetPoint("TOPLEFT", 8, -y)
    changeBtn:SetText("Change campaign")
    changeBtn:SetScript("OnClick", function() ns.Picker.Open() end)
    y = y + 34

    ----------------------------------------------------------------------------
    -- Mounts
    ----------------------------------------------------------------------------

    local function MountRow(labelText, slot)
        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 8, -y)
        label:SetText(labelText)

        local value = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("LEFT", label, "RIGHT", 8, 0)
        value:SetTextColor(ns.Widgets.HexToRGB(ns.COLOR.HIGHLIGHT))

        local set = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        set:SetSize(140, 22)
        set:SetPoint("TOPLEFT", 8, -(y + 18))
        set:SetText("Use current mount")
        set:SetScript("OnClick", function() AssignCurrentMount(slot) end)

        local clear = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        clear:SetSize(60, 22)
        clear:SetPoint("LEFT", set, "RIGHT", 6, 0)
        clear:SetText("Clear")
        clear:SetScript("OnClick", function()
            local c = Campaign()
            if not c then return end
            c.mounts[slot] = nil
            if slot == "bonded" then c.mounts.bondedName = nil end
            ns.RideButton.Update()
            Config.Refresh()
        end)

        y = y + 48
        return { label = label, value = value, set = set, clear = clear }
    end

    controls.ground = MountRow("Ground mount:", "ground")
    controls.flying = MountRow("Flying mount:", "flying")
    controls.bonded = MountRow("Bonded mount:", "bonded")

    ----------------------------------------------------------------------------
    -- Rules
    ----------------------------------------------------------------------------

    Place(ns.Widgets.CreateSectionHeader(content, L.CFG_SECTION_RULES), SECTION_GAP)

    -- Read-only summary, shown when a named preset owns the rules.
    controls.ruleSummary = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    controls.ruleSummary:SetPoint("TOPLEFT", 8, -y)
    controls.ruleSummary:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    controls.ruleSummary:SetJustifyH("LEFT")
    controls.ruleSummary:SetSpacing(3)
    controls.ruleSummary:SetTextColor(ns.Widgets.HexToRGB(ns.COLOR.BODY))
    y = y + 120

    controls.enforcement = ns.Widgets.CreateDropdown(content,
        L.CFG_ENFORCEMENT, L.CFG_ENFORCEMENT_DESC,
        function()
            local c = Campaign()
            local current = c and c.rules.enforcement
            return {
                { text = L.ENFORCE_OFF_NAME    .. " - " .. L.ENFORCE_OFF_DESC,
                  value = ns.ENFORCE.OFF,    selected = current == ns.ENFORCE.OFF },
                { text = L.ENFORCE_NOTIFY_NAME .. " - " .. L.ENFORCE_NOTIFY_DESC,
                  value = ns.ENFORCE.NOTIFY, selected = current == ns.ENFORCE.NOTIFY },
                { text = L.ENFORCE_REFUSE_NAME .. " - " .. L.ENFORCE_REFUSE_DESC,
                  value = ns.ENFORCE.REFUSE, selected = current == ns.ENFORCE.REFUSE },
            }
        end,
        function(value)
            local c = Campaign()
            if c then c.rules.enforcement = value end
            ns.RideButton.Update()
            Config.Refresh()
        end)
    Place(controls.enforcement)

    controls.groundOnly = ns.Widgets.CreateCheckbox(content,
        "Ground mounts only",
        "Flying mounts and skyriding are refused.",
        function(checked)
            local c = Campaign()
            if c then c.rules.groundOnly = checked end
            ns.RideButton.Update()
        end)
    Place(controls.groundOnly)

    controls.settlement = ns.Widgets.CreateCheckbox(content,
        "Dismount in settlements",
        "Riding is refused in cities, towns and inns. The open road is unaffected.",
        function(checked)
            local c = Campaign()
            if c then c.rules.settlementDismount = checked end
            ns.RideButton.Update()
        end)
    Place(controls.settlement)

    ----------------------------------------------------------------------------
    -- Retrieval
    ----------------------------------------------------------------------------

    Place(ns.Widgets.CreateSectionHeader(content, L.CFG_SECTION_RETRIEVAL), SECTION_GAP)

    controls.dispatch = ns.Widgets.CreateDropdown(content,
        L.CFG_DISPATCH, "",
        function()
            local c = Campaign()
            local current = c and c.rules.dispatch
            return {
                { text = L.CFG_DISPATCH_AUTO, value = ns.DISPATCH.AUTO, selected = current == ns.DISPATCH.AUTO },
                { text = L.CFG_DISPATCH_CALL, value = ns.DISPATCH.CALL, selected = current == ns.DISPATCH.CALL },
                { text = L.CFG_DISPATCH_NONE, value = ns.DISPATCH.NONE, selected = current == ns.DISPATCH.NONE },
            }
        end,
        function(value)
            local c = Campaign()
            if c then c.rules.dispatch = value end
            Config.Refresh()
        end)
    Place(controls.dispatch)

    controls.pickupRadius = ns.Widgets.CreateSlider(content,
        L.CFG_PICKUP_RADIUS, L.CFG_PICKUP_RADIUS_DESC,
        50, 400, 10,
        function(value)
            local c = Campaign()
            if c then c.rules.pickupRadius = value end
        end)
    Place(controls.pickupRadius)

    ----------------------------------------------------------------------------
    -- Notifications
    ----------------------------------------------------------------------------

    Place(ns.Widgets.CreateSectionHeader(content, L.CFG_SECTION_NOTIFY), SECTION_GAP)

    controls.bell = ns.Widgets.CreateCheckbox(content,
        L.CFG_BELL, L.CFG_BELL_DESC,
        function(checked) ns.DB.GetGlobals().bell = checked end)
    Place(controls.bell)

    controls.company = ns.Widgets.CreateDropdown(content,
        L.CFG_COMPANY, L.CFG_COMPANY_DESC,
        function()
            local c = Campaign()
            local current = c and c.service and c.service.company
            return {
                { text = L.COMPANY_GOBLIN, value = "goblin", selected = current == "goblin" },
                { text = L.COMPANY_GNOME,  value = "gnome",  selected = current == "gnome" },
            }
        end,
        function(value)
            local c = Campaign()
            if c then c.service = ns.Presets.RollService(value) end
            Config.Refresh()
        end)
    Place(controls.company)

    ----------------------------------------------------------------------------
    -- Map & tracking
    ----------------------------------------------------------------------------

    Place(ns.Widgets.CreateSectionHeader(content, L.CFG_SECTION_MAP), SECTION_GAP)

    controls.restorePin = ns.Widgets.CreateCheckbox(content,
        L.CFG_AUTO_RESTORE_PIN, L.CFG_AUTO_RESTORE_DESC,
        function(checked) ns.DB.GetGlobals().autoRestorePin = checked end)
    Place(controls.restorePin)

    controls.tracker = ns.Widgets.CreateCheckbox(content,
        L.CFG_SHOW_TRACKER, L.CFG_SHOW_TRACKER_DESC,
        function(checked)
            ns.DB.GetGlobals().showTracker = checked
            ns.Tracker.Update()
        end)
    Place(controls.tracker)

    ----------------------------------------------------------------------------
    -- Advanced
    ----------------------------------------------------------------------------

    Place(ns.Widgets.CreateSectionHeader(content, L.CFG_SECTION_ADVANCED), SECTION_GAP)

    controls.rideButton = ns.Widgets.CreateCheckbox(content,
        "Show the Ride button on screen",
        "A draggable button that casts this campaign's mount. The key binding does the same thing without taking up space.",
        function(checked) ns.RideButton.SetShown(checked) end)
    Place(controls.rideButton)

    -- The honesty note. This addon cannot block a mount cast, and saying so
    -- plainly is better than letting a player discover the limit and conclude
    -- the addon is broken.
    local howTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    howTitle:SetPoint("TOPLEFT", 8, -y)
    howTitle:SetText(L.CFG_HOW_IT_WORKS_TITLE)
    howTitle:SetTextColor(ns.Widgets.HexToRGB(ns.COLOR.HIGHLIGHT))
    y = y + 20

    local howBody = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    howBody:SetPoint("TOPLEFT", 8, -y)
    howBody:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    howBody:SetJustifyH("LEFT")
    howBody:SetSpacing(3)
    howBody:SetText(L.CFG_HOW_IT_WORKS_BODY)
    howBody:SetTextColor(0.72, 0.70, 0.66)
    y = y + howBody:GetStringHeight() + 20

    content:SetHeight(y)

    category = Settings.RegisterCanvasLayoutCategory(panel, L.ADDON_NAME)
    category.ID = ADDON
    Settings.RegisterAddOnCategory(category)
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------

--- Shows or hides a control and its description together.
local function SetControlShown(control, shown)
    if not control then return end
    control:SetShown(shown)
end

function Config.Refresh()
    if not panel then return end

    local campaign = Campaign()
    if not campaign then
        controls.campaignName:SetText(L.STATUS_NO_CAMPAIGN)
        return
    end

    local preset = ns.Presets.Get(campaign.preset)

    controls.campaignName:SetText(campaign.name)
    controls.campaignName:SetTextColor(ns.Widgets.HexToRGB(ns.Presets.SeverityColor(campaign)))
    controls.campaignHook:SetText(preset.hook)

    -- Mount slots. Which ones apply depends on the campaign's mount policy, so
    -- the irrelevant ones are hidden rather than shown greyed out.
    local policy = campaign.rules.mountPolicy
    local showAssigned = (policy == ns.MOUNTPOLICY.ASSIGNED)
    local showBonded   = (policy == ns.MOUNTPOLICY.SINGLE)

    local function SetMountRow(row, shown, spellID, name)
        SetControlShown(row.label, shown)
        SetControlShown(row.value, shown)
        SetControlShown(row.set, shown)
        SetControlShown(row.clear, shown)
        if shown then
            row.value:SetText(spellID and ns.Mount.NameFromSpell(spellID, name) or "Not assigned")
        end
    end

    -- A ground-only campaign has no use for a flying slot, so it isn't shown.
    SetMountRow(controls.ground, showAssigned, campaign.mounts.ground)
    SetMountRow(controls.flying, showAssigned and not campaign.rules.groundOnly, campaign.mounts.flying)
    SetMountRow(controls.bonded, showBonded, campaign.mounts.bonded, campaign.mounts.bondedName)

    -- Rules. A named preset owns its rules, so it gets a summary and no controls.
    local custom = IsCustom()

    if custom then
        controls.ruleSummary:SetText("")
        controls.ruleSummary:Hide()
    else
        local lines = {}
        for _, row in ipairs(ns.Presets.CardRows(campaign)) do
            table.insert(lines, ("|cffffd100%s|r  %s"):format(row.label, row.text))
        end
        table.insert(lines, "")
        table.insert(lines, "|cff9e9e9eThese are what make this campaign what it is. Switch to Custom if you want to change them.|r")
        controls.ruleSummary:SetText(table.concat(lines, "\n"))
        controls.ruleSummary:Show()
    end

    SetControlShown(controls.enforcement, custom)
    SetControlShown(controls.groundOnly, custom)
    SetControlShown(controls.settlement, custom)
    SetControlShown(controls.dispatch, custom)

    if custom then
        controls.enforcement:Refresh()
        controls.dispatch:Refresh()
        controls.groundOnly:SetValue(campaign.rules.groundOnly)
        controls.settlement:SetValue(campaign.rules.settlementDismount)
    end

    -- Pick-up radius is always adjustable. It's a comfort setting rather than a
    -- rule - how forgiving the collection is, not what the campaign demands.
    controls.pickupRadius:SetValue(campaign.rules.pickupRadius)

    local g = ns.DB.GetGlobals()
    controls.bell:SetValue(g.bell)
    controls.restorePin:SetValue(g.autoRestorePin)
    controls.tracker:SetValue(g.showTracker)
    controls.rideButton:SetValue(g.showRideButton)
    controls.company:Refresh()
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function Config.Open()
    if not panel then BuildPanel() end
    Config.Refresh()
    Settings.OpenToCategory(category.ID)
end

ns:OnLoad(function()
    BuildPanel()
    Config.Refresh()
end)
