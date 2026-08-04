--[[
    UI/Tracker.lua - the small frame that shows a retrieval in progress.

    Present only when something is actually happening. A persistent panel that
    reads "nothing to report" most of the time is clutter, so this hides itself
    the moment a mount is back with the player.

    It also carries the two actions that are otherwise buried in slash commands:
    calling for a mount, and putting a pin on it. Those are exactly the moments a
    player wants them, which makes this the addon's main interface during play
    even though it takes up almost no room.
]]

local ADDON, ns = ...

local Tracker = {}
ns.Tracker = Tracker

local L = ns.L

local frame, ticker

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function Build()
    if frame then return end

    frame = CreateFrame("Frame", "DWMKTracker", UIParent, "BackdropTemplate")
    frame:SetSize(230, 74)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        local g = ns.DB.GetGlobals()
        if g then
            g.trackerPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    frame:Hide()

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0.65)
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.25)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title:SetPoint("TOPLEFT", 10, -8)
    frame.title:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetTextColor(ns.Widgets.HexToRGB(ns.COLOR.HIGHLIGHT))

    frame.phase = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.phase:SetPoint("TOPLEFT", 10, -24)
    frame.phase:SetJustifyH("LEFT")
    frame.phase:SetTextColor(0.78, 0.75, 0.7)

    frame.countdown = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.countdown:SetPoint("TOPRIGHT", -10, -24)
    frame.countdown:SetJustifyH("RIGHT")

    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetPoint("TOPLEFT", 10, -40)
    frame.bar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.bar:SetHeight(6)
    frame.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    frame.bar:SetStatusBarColor(1, 0.82, 0, 0.7)
    frame.bar:SetMinMaxValues(0, 1)

    frame.barBG = frame.bar:CreateTexture(nil, "BACKGROUND")
    frame.barBG:SetAllPoints()
    frame.barBG:SetColorTexture(1, 1, 1, 0.08)

    frame.action = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.action:SetSize(96, 20)
    frame.action:SetPoint("BOTTOMLEFT", 10, 8)

    frame.track = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.track:SetSize(96, 20)
    frame.track:SetPoint("BOTTOMRIGHT", -10, 8)
    frame.track:SetText(L.PIN_TRACK)
    frame.track:SetScript("OnClick", function() ns.Retrieval.Track() end)
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

function Tracker.Update()
    Build()

    local g = ns.DB.GetGlobals()
    if not g or not g.showTracker then
        frame:Hide()
        return
    end

    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then
        frame:Hide()
        return
    end

    local campaign = ns.DB.GetActiveCampaign()
    if not campaign then
        frame:Hide()
        return
    end

    local mountName = ns.Mount.NameFromSpell(
        r.spellID,
        campaign.mounts.bonded == r.spellID and campaign.mounts.bondedName or nil
    )

    frame.title:SetText(mountName)
    frame.phase:SetText(ns.Retrieval.StatusText())

    local remaining, phaseLabel = ns.Retrieval.SecondsRemaining()

    if remaining then
        frame.countdown:SetText(ns.FormatDuration(remaining))
        frame.countdown:SetTextColor(1, 1, 1)

        -- Progress through whichever timer is currently running.
        local total = (r.state == ns.STATE.DISPATCHED) and ns.TIMER_A or (r.deliverySeconds or 1)
        frame.bar:SetValue(1 - (remaining / total))
        frame.bar:Show()

        if phaseLabel then frame.phase:SetText(phaseLabel) end
    else
        -- Sitting where it was left. Show the distance instead of a countdown,
        -- since that's the number the player can actually act on.
        local distance = ns.Retrieval.DistanceToMount()
        if distance then
            frame.countdown:SetText(L.TRACKER_DISTANCE:format(math.floor(distance)))
            frame.countdown:SetTextColor(0.7, 0.7, 0.7)
        else
            frame.countdown:SetText(ns.Mount.GetMapName(r.mapID))
            frame.countdown:SetTextColor(0.7, 0.7, 0.7)
        end
        frame.bar:Hide()
    end

    -- The action button is whatever the player can usefully do right now.
    local rules = campaign.rules
    if r.state == ns.STATE.LEFT and rules.dispatch == ns.DISPATCH.CALL then
        frame.action:SetText("Send for it")
        frame.action:Enable()
        frame.action:SetScript("OnClick", function() ns.Retrieval.Call() end)
        frame.action:Show()
    else
        frame.action:Hide()
    end

    -- Once the service has the mount, the old spot is empty and pinning it would
    -- send the player somewhere pointless.
    frame.track:SetShown(r.state ~= ns.STATE.CARRYING)

    frame:Show()
end

--------------------------------------------------------------------------------
-- Load
--------------------------------------------------------------------------------

ns:OnLoad(function()
    Build()

    local g = ns.DB.GetGlobals()
    if g and g.trackerPos then
        frame:ClearAllPoints()
        frame:SetPoint(g.trackerPos.point, UIParent, g.trackerPos.relPoint, g.trackerPos.x, g.trackerPos.y)
    end

    -- One second refresh so the countdown reads smoothly. Cheap: it only formats
    -- a couple of strings, and does nothing at all while the frame is hidden.
    ticker = C_Timer.NewTicker(1, function()
        if frame and frame:IsShown() then
            Tracker.Update()
        end
    end)

    Tracker.Update()
end)
