--[[
    Core/Retrieval.lua - leaving a mount behind, and getting it back.

    Two timers, both fixed, neither recalculated:

      Timer A   60 seconds for the service to reach your mount. Always 60,
                regardless of where anyone is. One number to learn.

      Timer B   evaluated once, at the moment Timer A ends, and then locked.
                30 seconds if you are on the same map and within 1000 yards,
                3 minutes otherwise.

    Worst case is four minutes. Nothing chases the player, nothing recalculates
    while they move, and the only variable is where they happen to be standing
    when the service picks the mount up.

    Because the close/far test only needs a real distance when the player is
    already on the same map as the mount, every distance calculation in this
    addon is same-map. A different map is simply far. No cross-continent
    coordinate work exists anywhere.

    Self-recovery runs alongside all of it: get within the pick-up radius of a
    mount that hasn't been collected yet and it's yours immediately, cancelling
    any service on its way. The radius is deliberately loose - you should be able
    to fly over the area at speed and have it come back, not have to land on an
    exact spot.
]]

local ADDON, ns = ...

local Retrieval = {}
ns.Retrieval = Retrieval

local L = ns.L

local ticker
local tickCount = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Anchor()
    local r = ns.DB.GetRetrieval()
    if not r or not r.mapID then return nil end
    return { mapID = r.mapID, x = r.x, y = r.y }
end

local function PickupRadius()
    local rules = ns.DB.GetRules()
    return (rules and rules.pickupRadius) or ns.PICKUP_RADIUS
end

--- Distance from the player to the left-behind mount, or nil across maps.
local function DistanceToMount()
    local anchor = Anchor()
    if not anchor then return nil end
    return ns.Mount.DistanceToAnchor(anchor)
end

Retrieval.DistanceToMount = DistanceToMount

--- Is the mount close enough to simply take?
---
--- Core/Rules consults this so that stepping off a mount and immediately getting
--- back on is never refused. You have not "left" anything while you're standing
--- next to it.
function Retrieval.IsAtHand()
    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then return true end

    -- Once the service has the mount in hand, going back to where you left it
    -- finds nothing. Only LEFT and DISPATCHED can be intercepted.
    if r.state == ns.STATE.CARRYING then return false end

    local distance = DistanceToMount()
    return distance ~= nil and distance <= PickupRadius()
end

local function ClearState()
    local r = ns.DB.GetRetrieval()
    if not r then return end
    for k, v in pairs(ns.DB.DefaultRetrieval()) do
        r[k] = v
    end
end

--------------------------------------------------------------------------------
-- Transitions
--------------------------------------------------------------------------------

--- The mount is back with the player, by whatever route.
local function Recover(selfRecovered)
    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then return end

    local wasDispatched = (r.state == ns.STATE.DISPATCHED)

    if selfRecovered then
        ns.Notify.Emote(L.EMOTE_SELF_RECOVERED)
        if wasDispatched then
            ns.Notify.Emote(L.EMOTE_SELF_CANCELLED)
        end
    else
        ns.Notify.Emote(L.EMOTE_DELIVERED)
        ns.Notify.Bell()
    end

    -- Released here, alongside the message that explains why. A pin that
    -- vanishes without a reason attached reads as a bug.
    ns.Waypoint.Release()

    ClearState()
    ns.RideButton.Update()
    if ns.Tracker then ns.Tracker.Update() end
end

Retrieval.Recover = Recover

--- Sends the service out. Returns false with a reason if it can't be done.
function Retrieval.Call(silent)
    local r     = ns.DB.GetRetrieval()
    local rules = ns.DB.GetRules()
    if not r or not rules then return false end

    if r.state == ns.STATE.IDLE then
        if not silent then ns.Notify.System(L.CALL_NOTHING_TO_CALL) end
        return false
    end

    if rules.dispatch == ns.DISPATCH.NONE then
        if not silent then ns.Notify.System(L.CALL_NO_SERVICE) end
        return false
    end

    if r.state ~= ns.STATE.LEFT then
        if not silent then
            local campaign = ns.DB.GetActiveCampaign()
            local courier  = campaign and campaign.service and campaign.service.courierName or "The courier"
            ns.Notify.System(L.CALL_ALREADY_COMING:format(courier))
        end
        return false
    end

    r.state        = ns.STATE.DISPATCHED
    r.dispatchedAt = time()

    if rules.dispatch == ns.DISPATCH.AUTO then
        ns.Notify.Emote(L.EMOTE_DISPATCH_AUTO)
    else
        ns.Notify.Emote(L.EMOTE_DISPATCH_CALL)
    end

    if ns.Tracker then ns.Tracker.Update() end
    return true
end

--- Timer A has elapsed. Lock Timer B against where the player is right now.
local function PickUp()
    local r = ns.DB.GetRetrieval()
    if not r then return end

    local distance = DistanceToMount()
    local isClose  = distance ~= nil and distance <= ns.CLOSE_DISTANCE

    r.state = ns.STATE.CARRYING

    -- Stamp this as the moment Timer A actually elapsed, not the moment we
    -- noticed. They are the same during play, but after a logout they are not:
    -- using time() here would restart Timer B from scratch on login, so a player
    -- who left for an hour would still be made to wait out the delivery.
    r.pickedUpAt      = (r.dispatchedAt or time()) + ns.TIMER_A
    r.deliverySeconds = isClose and ns.TIMER_B_CLOSE or ns.TIMER_B_FAR

    ns.Notify.Emote(isClose and L.EMOTE_PICKUP_CLOSE or L.EMOTE_PICKUP_FAR)

    -- The mount is no longer where the pin says it is.
    ns.Waypoint.Release(false)

    ns.RideButton.Update()
    if ns.Tracker then ns.Tracker.Update() end
end

--------------------------------------------------------------------------------
-- Mount events
--------------------------------------------------------------------------------

--- The player got on a mount, and the rules allowed it.
function Retrieval.OnMounted(info)
    local r = ns.DB.GetRetrieval()
    if not r then return end

    -- Riding the very mount that was left behind means it's back with them -
    -- either they walked to it, or the campaign isn't enforcing anything.
    if r.state ~= ns.STATE.IDLE and r.spellID == info.spellID then
        Recover(true)
    end

    -- The tracked spell ID is deliberately NOT cleared here. It is the only
    -- record of what the player is riding, and OnDismounted needs it to know
    -- which mount was just left behind. Clearing it on mount breaks the entire
    -- loop: nothing would ever be recorded.
end

--- The player got off a mount of their own accord.
function Retrieval.OnDismounted()
    local spellID = ns.Mount.GetLastCastSpellID()
    if not spellID then return end

    local r = ns.DB.GetRetrieval()
    if not r then return end

    -- Stepping off inside your own neighborhood doesn't strand anything. It's
    -- home: your mounts live there, and no rule applies there anyway. Recording
    -- it would mean teleporting out of your own garden left a mount behind that
    -- had to be couriered back to you, which is a silly way to treat a stable.
    if ns.Mount.InNeighborhood() then
        ns.Mount.ClearLastCastSpellID()
        return
    end

    -- Only one mount can be out at a time. If something is already left behind,
    -- the older one is forgotten rather than tracked in parallel - two pending
    -- retrievals would double the state and the explaining for very little gain.
    local mapID, x, y = ns.Mount.GetPosition()
    if not mapID then
        ns.Mount.ClearLastCastSpellID()
        return
    end

    r.state             = ns.STATE.LEFT
    r.spellID           = spellID
    r.mapID             = mapID
    r.x                 = x
    r.y                 = y
    r.leftAt            = time()
    r.dispatchedAt      = nil
    r.pickedUpAt        = nil
    r.deliverySeconds   = nil
    r.announcedApproach = false
    r.announcedNearly   = false

    -- Historical record, kept per character. Useful for "where did I leave
    -- things" and carried over from version 1.x's anchors.
    local anchors = ns.DB.GetAnchors()
    if anchors then
        anchors[spellID] = { mapID = mapID, x = x, y = y, at = time() }
    end

    ns.Mount.ClearLastCastSpellID()
    ns.RideButton.Update()

    -- Nothing is announced yet. Standing next to a mount you just stepped off is
    -- not leaving it behind; that only becomes true once the player walks away,
    -- which the tick below notices.
end

--------------------------------------------------------------------------------
-- The tick
--------------------------------------------------------------------------------

--- Announced once, when the player first walks out of range of the mount.
local function AnnounceLeft()
    local r     = ns.DB.GetRetrieval()
    local rules = ns.DB.GetRules()
    if not r or not rules then return end

    if rules.dispatch == ns.DISPATCH.AUTO then
        ns.Notify.Emote(L.EMOTE_LEFT_BEHIND)
        Retrieval.Call(true)
    elseif rules.dispatch == ns.DISPATCH.CALL then
        ns.Notify.Emote(L.EMOTE_LEFT_BEHIND)
        ns.Notify.Emote(L.EMOTE_AWAITING_CALL)
    else
        ns.Notify.Emote(L.EMOTE_LEFT_NO_SERVICE)
    end
end

local function Tick()
    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then return end

    local now    = time()
    local radius = PickupRadius()

    ------------------------------------------------------------------
    -- Timers. Checked before position so that a session resumed after a
    -- long logout settles immediately rather than a tick later.
    ------------------------------------------------------------------

    if r.state == ns.STATE.DISPATCHED and r.dispatchedAt then
        if now - r.dispatchedAt >= ns.TIMER_A then
            PickUp()
            return
        end
    end

    if r.state == ns.STATE.CARRYING and r.pickedUpAt and r.deliverySeconds then
        local remaining = r.deliverySeconds - (now - r.pickedUpAt)

        if remaining <= 0 then
            Recover(false)
            return
        end

        if not r.announcedNearly and remaining <= ns.NEARLY_THERE_AT then
            r.announcedNearly = true
            ns.Notify.Emote(L.EMOTE_NEARLY_THERE)
        end

        if ns.Tracker then ns.Tracker.Update() end
        return
    end

    ------------------------------------------------------------------
    -- Position. Only LEFT and DISPATCHED can still be intercepted.
    ------------------------------------------------------------------

    local distance = DistanceToMount()

    -- Standing next to a mount you just stepped off is not leaving it behind.
    -- Until the player actually walks out of range, nothing has happened: no
    -- announcement, no dispatch, and no self-recovery either - otherwise every
    -- single dismount would be immediately followed by "you've reached your
    -- mount", which is both wrong and maddening.
    if r.state == ns.STATE.LEFT and not r.leftAnnounced then
        if distance == nil or distance > radius then
            r.leftAnnounced = true
            AnnounceLeft()
        end
        return
    end

    -- Past this point the mount has genuinely been left behind, so coming back
    -- to it means something.

    if distance == nil then
        return  -- different map; nothing to measure and nothing to announce
    end

    if distance <= radius then
        Recover(true)
        return
    end

    -- Coming back for it. Said once, before anything changes, so the pin
    -- disappearing a moment later is never a surprise.
    if distance <= radius * ns.APPROACH_FACTOR then
        if not r.announcedApproach then
            r.announcedApproach = true
            ns.Notify.Emote(L.EMOTE_SELF_APPROACH)
        end
    else
        -- Moved away again; let it be said afresh next time.
        r.announcedApproach = false
    end

    if ns.Tracker then ns.Tracker.Update() end
end

--------------------------------------------------------------------------------
-- Polling
--
-- One second while anywhere near the mount, five otherwise. At flying speed a
-- five second tick covers roughly 300 yards and would step clean over a 200 yard
-- pick-up bubble without ever seeing it, which would make the generous radius
-- feel arbitrary and broken.
--------------------------------------------------------------------------------

local function ShouldRunSlowTick()
    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then return true end

    -- Timer states need a steady tick regardless of where the player is.
    if r.state == ns.STATE.DISPATCHED or r.state == ns.STATE.CARRYING then
        return false
    end

    local distance = DistanceToMount()
    return distance == nil or distance > ns.POLL_FAST_RANGE
end

local function OnTick()
    tickCount = tickCount + 1

    -- The slow case still runs on the one second ticker, it just does the real
    -- work every fifth pass. One timer, two rates.
    if ShouldRunSlowTick() and (tickCount % ns.POLL_SLOW) ~= 0 then
        return
    end

    Tick()
end

function Retrieval.Start()
    if ticker then return end
    ticker = C_Timer.NewTicker(ns.POLL_FAST, OnTick)
end

function Retrieval.Stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

--------------------------------------------------------------------------------
-- Tracking
--------------------------------------------------------------------------------

--- Puts a map pin on the left-behind mount, at the player's request.
function Retrieval.Track()
    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then
        ns.Notify.System(L.STATUS_NOTHING_LEFT)
        return false
    end

    if r.state == ns.STATE.CARRYING then
        -- It isn't there any more; pinning the old spot would send the player
        -- somewhere the mount has already left.
        local campaign = ns.DB.GetActiveCampaign()
        local courier  = campaign and campaign.service and campaign.service.courierName
        ns.Notify.System(L.CALL_ALREADY_COMING:format(courier or "The courier"))
        return false
    end

    return ns.Waypoint.Track(Anchor(), ns.Mount.NameFromSpell(r.spellID))
end

--------------------------------------------------------------------------------
-- Status
--------------------------------------------------------------------------------

--- Human-readable state, for the tracker and /dwmk status.
function Retrieval.StatusText()
    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then return L.STATE_IDLE end

    local campaign = ns.DB.GetActiveCampaign()
    local courier  = campaign and campaign.service and campaign.service.courierName or "The courier"

    if r.state == ns.STATE.LEFT then
        local rules = ns.DB.GetRules()
        if rules and rules.dispatch == ns.DISPATCH.CALL then
            return L.STATE_AWAITING
        end
        return L.STATE_LEFT
    elseif r.state == ns.STATE.DISPATCHED then
        return L.STATE_DISPATCHED:format(courier)
    elseif r.state == ns.STATE.CARRYING then
        return L.STATE_CARRYING:format(courier)
    end

    return L.STATE_IDLE
end

--- Seconds until the mount is handed back, or nil if nothing is running.
function Retrieval.SecondsRemaining()
    local r = ns.DB.GetRetrieval()
    if not r then return nil end

    local now = time()

    if r.state == ns.STATE.DISPATCHED and r.dispatchedAt then
        -- Timer B isn't decided yet, so only Timer A can be promised.
        return math.max(0, ns.TIMER_A - (now - r.dispatchedAt)), L.TRACKER_REACHING
    end

    if r.state == ns.STATE.CARRYING and r.pickedUpAt and r.deliverySeconds then
        return math.max(0, r.deliverySeconds - (now - r.pickedUpAt)), L.TRACKER_DELIVERING
    end

    return nil
end

--------------------------------------------------------------------------------
-- Load
--------------------------------------------------------------------------------

ns:OnLoad(function()
    Retrieval.Start()
end)

-- Resolve anything that finished while the player was logged out as soon as
-- they're back in the world, rather than up to five seconds later.
ns:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(1, Tick)
end)
