--[[
    Core/Rules.lua - deciding whether a mount is allowed, and acting on it.

    Three enforcement levels and no fourth. There is deliberately no grace
    period: being handed a countdown and then pulled off a mount you already
    cast is the single most irritating thing this addon could do, so it does not
    exist. Either the mount is refused, or it isn't.

    Timing matters here. The verdict is reached at UNIT_SPELLCAST_SENT, roughly
    1.5 seconds before the mount appears, so by the time
    PLAYER_MOUNT_DISPLAY_CHANGED fires there is nothing left to work out and the
    mount can be removed on the spot. Version 1.x did all its checking after the
    player was already mounted.

    In practice this path is the fallback. Core/RideButton.lua prevents most
    illegal mounts from ever being cast, which is a far better experience than
    any amount of fast reacting.
]]

local ADDON, ns = ...

local Rules = {}
ns.Rules = Rules

local L = ns.L

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- Verdict from the most recent cast, keyed by spell ID so a second cast can't
-- be judged by the first one's answer.
local lastVerdict = { spellID = nil, allowed = true, reason = nil }

-- Set immediately before we call Dismount() so Core/Retrieval knows the
-- resulting dismount was ours and must not be recorded as the player leaving a
-- mount somewhere. Carried over from version 1.x, which got this right.
local enforcementDismount = false

-- A dismount we owe the player but can't safely perform yet.
local pendingDismount = nil
local landingWatcher  = nil

function Rules.IsEnforcementDismount()
    return enforcementDismount
end

function Rules.ClearEnforcementDismount()
    enforcementDismount = false
end

--------------------------------------------------------------------------------
-- Settlement detection
--
-- There is no API that answers "am I in a town". IsResting() is the closest
-- available signal: it's true wherever you accumulate rested experience, which
-- covers capital cities and the inns at the heart of most towns and villages.
--
-- So this is an approximation, and it errs toward permissive - you can ride
-- through the outskirts of a settlement without complaint, and are only stopped
-- once you're properly inside it. For the gentlest preset in the library that is
-- the right way round to be wrong.
--------------------------------------------------------------------------------

local function InSettlement()
    -- A housing neighborhood is a rested area, so without this it would read as
    -- a settlement and refuse the player a mount outside their own front door.
    if ns.Mount.InNeighborhood() then return false end

    return IsResting() and true or false
end

Rules.InSettlement = InSettlement

--------------------------------------------------------------------------------
-- Evaluation
--------------------------------------------------------------------------------

--- Is this mount one the campaign permits at all?
local function CheckMountPolicy(campaign, info)
    local r = campaign.rules

    if r.mountPolicy == ns.MOUNTPOLICY.ANY then
        return true
    end

    if r.mountPolicy == ns.MOUNTPOLICY.SINGLE then
        local bonded = campaign.mounts.bonded
        if not bonded then
            return false, L.DENY_NO_BOND_CHOSEN
        end
        if info.spellID ~= bonded then
            local bondedName = campaign.mounts.bondedName
                or ns.Mount.NameFromSpell(bonded)
            return false, L.DENY_NOT_BONDED:format(bondedName)
        end
        return true
    end

    -- ASSIGNED. Until the player has nominated anything, allow everything -
    -- a fresh campaign that refuses every mount would look broken rather than
    -- strict.
    local ground, flying = campaign.mounts.ground, campaign.mounts.flying
    if not ground and not flying then
        return true
    end

    if info.spellID == ground or info.spellID == flying then
        return true
    end

    return false, L.DENY_NOT_ASSIGNED:format(info.name or UNKNOWN)
end

--- Full verdict for a mount. Returns allowed, reason.
function Rules.Evaluate(info)
    local campaign = ns.DB.GetActiveCampaign()
    if not campaign or not info then return true end

    local r = campaign.rules

    -- Off means off. The addon still records where mounts are left and still
    -- retrieves them; it simply never objects to anything.
    if r.enforcement == ns.ENFORCE.OFF then
        return true
    end

    -- Home ground. No campaign rule applies inside a housing neighborhood: it's
    -- where your stables are, it's where people go to show mounts off, and it is
    -- a rested area that would otherwise trip the settlement rule. Whatever
    -- constraints you signed up for, they are about the road, not your garden.
    if ns.Mount.InNeighborhood() then
        return true
    end

    local ok, reason = CheckMountPolicy(campaign, info)
    if not ok then
        return false, reason
    end

    if r.groundOnly and ns.Mount.CanFly(info.mountID) then
        return false, L.DENY_FLYING:format(info.name or UNKNOWN)
    end

    if r.settlementDismount and InSettlement() then
        return false, L.DENY_SETTLEMENT
    end

    -- The heart of the addon: a mount you left somewhere is not here to ride.
    --
    -- IsAtHand covers the case that would otherwise be maddening - stepping off
    -- a mount and immediately getting back on. You have not left anything behind
    -- while you are still standing next to it.
    local retrieval = ns.DB.GetRetrieval()
    if retrieval and retrieval.state ~= ns.STATE.IDLE
       and retrieval.spellID == info.spellID
       and not ns.Retrieval.IsAtHand() then
        return false, L.DENY_NOT_HERE:format(
            info.name or UNKNOWN,
            ns.Mount.GetMapName(retrieval.mapID)
        )
    end

    return true
end

--- Called from Core/Mount.lua the moment a mount cast is sent, so the answer is
--- already known when the mount appears.
function Rules.PreJudge(spellID)
    local info = ns.Mount.InfoFromSpell(spellID)
    if not info then return end

    local allowed, reason = Rules.Evaluate(info)
    lastVerdict.spellID = spellID
    lastVerdict.allowed = allowed
    lastVerdict.reason  = reason
end

--------------------------------------------------------------------------------
-- Acting on a verdict
--------------------------------------------------------------------------------

--- Dismounts, unless doing so would drop the player out of the sky.
---
--- This overrides every enforcement level without exception. An addon that kills
--- you from altitude gets uninstalled regardless of which campaign asked for it,
--- so a dismount owed in the air is simply held until the player is back on the
--- ground. Core/RideButton means this rarely comes up: an illegal flyer is
--- usually never summoned in the first place.
local function SafeDismount(reason)
    if IsFlying() or IsFalling() then
        pendingDismount = reason or true

        if not landingWatcher then
            landingWatcher = C_Timer.NewTicker(0.5, function()
                if not IsMounted() then
                    -- Landed and dismounted on their own, or the mount ended some
                    -- other way. Nothing left to owe.
                    pendingDismount = nil
                    if landingWatcher then
                        landingWatcher:Cancel()
                        landingWatcher = nil
                    end
                    return
                end

                if not IsFlying() and not IsFalling() then
                    if landingWatcher then
                        landingWatcher:Cancel()
                        landingWatcher = nil
                    end
                    local held = pendingDismount
                    pendingDismount = nil
                    enforcementDismount = true
                    Dismount()
                    if type(held) == "string" then
                        ns.Notify.Refused(held)
                    end
                end
            end)
        end
        return
    end

    enforcementDismount = true
    Dismount()
    if reason then
        ns.Notify.Refused(reason)
    end
end

Rules.SafeDismount = SafeDismount

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local function OnMounted()
    local campaign = ns.DB.GetActiveCampaign()
    if not campaign then return end

    local info = ns.Mount.GetCurrent()
    if not info then return end

    campaign.lastUsed = time()

    -- Use the verdict from the cast if it's for this mount, otherwise judge now
    -- (the player may have been mounted by something we never saw cast).
    local allowed, reason
    if lastVerdict.spellID == info.spellID then
        allowed, reason = lastVerdict.allowed, lastVerdict.reason
    else
        allowed, reason = Rules.Evaluate(info)
    end

    if allowed then
        ns.Retrieval.OnMounted(info)
        return
    end

    local level = campaign.rules.enforcement

    if level == ns.ENFORCE.NOTIFY then
        ns.Notify.Refused(reason)
    elseif level == ns.ENFORCE.REFUSE then
        SafeDismount(reason)
    end
end

ns:On("PLAYER_MOUNT_DISPLAY_CHANGED", function()
    -- A taxi or vehicle is not something the player summoned, and no rule in
    -- this addon should ever fire on one.
    if UnitOnTaxi("player") or UnitInVehicle("player") then return end

    if IsMounted() then
        OnMounted()
    else
        if enforcementDismount then
            -- Our own doing. Don't record it as the player leaving a mount.
            enforcementDismount = false
            ns.Mount.ClearLastCastSpellID()
            return
        end
        ns.Retrieval.OnDismounted()
    end
end)

-- Entering or leaving a rest area can change the answer for a settlement
-- campaign while the player is already mounted.
local function RecheckSettlement()
    local campaign = ns.DB.GetActiveCampaign()
    if not campaign or not campaign.rules.settlementDismount then return end
    if campaign.rules.enforcement ~= ns.ENFORCE.REFUSE then return end
    if not IsMounted() then return end
    if UnitOnTaxi("player") or UnitInVehicle("player") then return end

    if InSettlement() then
        SafeDismount(L.DENY_SETTLEMENT)
    end
end

ns:On("PLAYER_UPDATE_RESTING", RecheckSettlement)
ns:On("ZONE_CHANGED", RecheckSettlement)
ns:On("ZONE_CHANGED_NEW_AREA", RecheckSettlement)
