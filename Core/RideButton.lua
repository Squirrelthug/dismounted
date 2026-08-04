--[[
    Core/RideButton.lua - the prevention layer.

    An addon cannot interrupt a mount cast. SpellStopCasting() has been protected
    since patch 2.0.1, and the macrotext attribute that used to let a secure
    button run /stopcasting was removed in 11.0. Reacting after the fact is all
    that's left - and reacting is exactly what makes an addon feel like it's
    fighting you.

    So this approaches it from the other end. A secure button with type="spell"
    whose spell attribute only ever holds a mount the campaign permits. Press it
    and you get a legal mount; press it when nothing is legal and you get a
    message and no cast at all. There is no illegal cast to interrupt because one
    never begins.

    The attribute can only be written outside combat, so writes during a lockdown
    are queued and flushed on PLAYER_REGEN_ENABLED. Holding the previous legal
    value through a fight is always safe - it was legal when it was set.
]]

local ADDON, ns = ...

local RideButton = {}
ns.RideButton = RideButton

local L = ns.L

-- "Summon Random Favorite Mount". Used when a campaign doesn't nominate specific
-- mounts, so the button behaves the way the player's own mount key already does.
local RANDOM_FAVORITE = 150544

--------------------------------------------------------------------------------
-- The button
--------------------------------------------------------------------------------

local button = CreateFrame("Button", "DWMKRideButton", UIParent, "SecureActionButtonTemplate")
button:SetSize(40, 40)
button:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
button:RegisterForClicks("AnyDown", "AnyUp")
button:SetAttribute("type", "spell")
button:Hide()  -- the keybind is the primary interface; the visible button is opt-in

button:SetNormalTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
button:SetMovable(true)
button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", button.StartMoving)
button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    local g = ns.DB.GetGlobals()
    if g then
        g.ridePos = { point = point, relPoint = relPoint, x = x, y = y }
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BINDING_RIDE, 1, 1, 1)
    GameTooltip:AddLine(L.RIDE_TOOLTIP, nil, nil, nil, true)

    local _, reason = RideButton.ChooseMount()
    if reason then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(reason, 1, 0.3, 0.3, true)
    end
    GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

-- The refusal message has to come from somewhere that isn't the secure handler,
-- so it rides on PreClick. This runs before the secure action, and when no spell
-- attribute is set the secure action does nothing at all.
button:SetScript("PreClick", function()
    local spellID, reason = RideButton.ChooseMount()
    if not spellID and reason then
        ns.Notify.Refused(reason)
    end
end)

--------------------------------------------------------------------------------
-- Choosing the mount
--------------------------------------------------------------------------------

--- Which mount, if any, this campaign will let the player ride right now.
--- Returns spellID, or nil plus the reason it won't.
function RideButton.ChooseMount()
    local campaign = ns.DB.GetActiveCampaign()
    if not campaign then return RANDOM_FAVORITE end

    local r         = campaign.rules
    local retrieval = ns.DB.GetRetrieval()

    -- Off means the button is just a mount key.
    if r.enforcement == ns.ENFORCE.OFF then
        return RANDOM_FAVORITE
    end

    -- Inside a housing neighborhood no campaign rule applies, so the button
    -- should never refuse there. See Core/Mount.lua for why.
    local homeGround = ns.Mount.InNeighborhood()

    -- "Away" means genuinely out of reach. A mount you are standing next to is
    -- still yours to ride, even though the retrieval state technically has it
    -- marked as left behind.
    local function isAway(spellID)
        if homeGround then return false end
        return retrieval
            and retrieval.state ~= ns.STATE.IDLE
            and retrieval.spellID == spellID
            and not ns.Retrieval.IsAtHand()
    end

    local function awayReason(spellID)
        return L.DENY_NOT_HERE:format(
            ns.Mount.NameFromSpell(spellID),
            ns.Mount.GetMapName(retrieval and retrieval.mapID)
        )
    end

    if r.settlementDismount and ns.Rules.InSettlement() then
        return nil, L.DENY_SETTLEMENT
    end

    if r.mountPolicy == ns.MOUNTPOLICY.SINGLE then
        local bonded = campaign.mounts.bonded
        if not bonded then
            -- At home the key still has to do something, even before the player
            -- has chosen who they're bonded to.
            if homeGround then return RANDOM_FAVORITE end
            return nil, L.DENY_NO_BOND_CHOSEN
        end
        if isAway(bonded) then
            return nil, awayReason(bonded)
        end
        return bonded
    end

    if r.mountPolicy == ns.MOUNTPOLICY.ANY then
        return RANDOM_FAVORITE
    end

    -- ASSIGNED.
    local ground, flying = campaign.mounts.ground, campaign.mounts.flying

    -- Nothing nominated yet - behave like a normal mount key rather than
    -- refusing everything on a campaign the player has only just started.
    if not ground and not flying then
        return RANDOM_FAVORITE
    end

    -- Ground-only is a rule about the road, so it doesn't bind at home either.
    local canUseFlyer = flying and (homeGround or not r.groundOnly) and not isAway(flying)

    -- Prefer the flyer where flying is actually possible, otherwise the ground
    -- mount. This is the one place the button makes a judgement call for the
    -- player, and it matches what they'd have picked themselves.
    if canUseFlyer and IsFlyableArea() then
        return flying
    end
    if ground and not isAway(ground) then
        return ground
    end
    if canUseFlyer then
        return flying
    end

    -- Everything this campaign allows is somewhere else.
    if ground and isAway(ground) then
        return nil, awayReason(ground)
    end
    if flying and isAway(flying) then
        return nil, awayReason(flying)
    end

    return nil, L.DENY_NO_LEGAL_MOUNT
end

--------------------------------------------------------------------------------
-- Keeping the attribute current
--------------------------------------------------------------------------------

local updateQueued = false

function RideButton.Update()
    if InCombatLockdown() then
        -- Can't touch a secure attribute mid-fight. Whatever is on the button
        -- was legal when it was written, so leaving it is safe.
        updateQueued = true
        return
    end
    updateQueued = false

    local spellID = RideButton.ChooseMount()

    if spellID then
        button:SetAttribute("spell", spellID)
        button:Enable()
        button:SetAlpha(1)
    else
        -- No legal mount. Clearing the attribute is what makes the refusal real:
        -- the secure action has nothing to cast, so nothing is cast.
        button:SetAttribute("spell", nil)
        button:SetAlpha(0.4)
    end
end

--------------------------------------------------------------------------------
-- Visible button
--------------------------------------------------------------------------------

function RideButton.SetShown(shown)
    local g = ns.DB.GetGlobals()
    if g then g.showRideButton = shown end
    if shown then button:Show() else button:Hide() end
end

function RideButton.IsShown()
    return button:IsShown()
end

--------------------------------------------------------------------------------
-- Bindings
--
-- The CLICK binding form is declared in Bindings.xml; these globals give it a
-- readable name in the Key Bindings panel.
--------------------------------------------------------------------------------

_G["BINDING_HEADER_DWMK"] = L.BINDING_HEADER
_G["BINDING_NAME_CLICK DWMKRideButton:LeftButton"] = L.BINDING_RIDE

--------------------------------------------------------------------------------
-- Events
--
-- Anything that can change which mount is legal has to re-evaluate the button,
-- or it will happily cast something the campaign forbids.
--------------------------------------------------------------------------------

ns:On("PLAYER_REGEN_ENABLED", function()
    if updateQueued then RideButton.Update() end
end)

ns:On("ZONE_CHANGED_NEW_AREA", RideButton.Update)  -- flyable area may have changed
ns:On("ZONE_CHANGED", RideButton.Update)
ns:On("PLAYER_UPDATE_RESTING", RideButton.Update)  -- entered or left a settlement
ns:On("PLAYER_MOUNT_DISPLAY_CHANGED", RideButton.Update)

ns:OnLoad(function()
    local g = ns.DB.GetGlobals()

    if g and g.ridePos then
        button:ClearAllPoints()
        button:SetPoint(g.ridePos.point, UIParent, g.ridePos.relPoint, g.ridePos.x, g.ridePos.y)
    end

    if g and g.showRideButton then
        button:Show()
    end

    RideButton.Update()
end)
