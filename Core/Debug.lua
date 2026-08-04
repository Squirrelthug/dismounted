--[[
    Core/Debug.lua - the simulation harness.

    Testing the retrieval timers honestly would mean leaving a mount in Elwynn,
    flying to Kalimdor and waiting four minutes, per case, per preset. Nobody is
    going to do that often enough to catch regressions, so the harness fakes the
    inputs instead:

        /dwmk sim leave <yards>   plant an anchor at a synthetic distance
        /dwmk sim ff <seconds>    wind the retrieval clock forward
        /dwmk sim offline <secs>  pretend the player was logged out that long
        /dwmk sim state           dump the retrieval state
        /dwmk sim clear           reset to idle

    Winding the clock works by moving the recorded timestamps backwards, which is
    exactly what a logout gap does to them. So `ff` and `offline` exercise the
    same arithmetic the real thing does, rather than a special test path that
    could drift away from it.
]]

local ADDON, ns = ...

local Debug = {}
ns.Debug = Debug

local function Say(text)
    ns.Notify.System("|cff9e9e9e[sim]|r " .. text)
end

--------------------------------------------------------------------------------
-- Synthetic anchor
--------------------------------------------------------------------------------

--- Plants an anchor the given number of yards from the player, on the current
--- map, using whatever mount they're on (or a placeholder if they're on foot).
local function SimLeave(yards)
    yards = tonumber(yards) or 500

    local mapID, x, y = ns.Mount.GetPosition()
    if not mapID then
        Say("Can't read your position on this map.")
        return
    end

    local width, height = C_Map.GetMapWorldSize(mapID)
    if not width or width <= 0 then
        Say("This map has no world size, so distance can't be faked here.")
        return
    end

    local info    = ns.Mount.GetCurrent()
    local spellID = info and info.spellID or ns.DB.GetActiveCampaign().mounts.ground

    if not spellID then
        Say("No mount to work with. Get on one, or assign a ground mount first.")
        return
    end

    -- Offset purely along x, clamped inside the map so the anchor stays real.
    local offset = yards / width
    local anchorX = x - offset
    if anchorX < 0.02 then anchorX = x + offset end
    if anchorX > 0.98 then anchorX = 0.5 end

    local r = ns.DB.GetRetrieval()
    for k, v in pairs(ns.DB.DefaultRetrieval()) do r[k] = v end

    r.state   = ns.STATE.LEFT
    r.spellID = spellID
    r.mapID   = mapID
    r.x       = anchorX
    r.y       = y
    r.leftAt  = time()

    ns.RideButton.Update()
    ns.Tracker.Update()

    local actual = ns.Retrieval.DistanceToMount()
    Say(("Left %s about %d yd away (asked for %d)."):format(
        ns.Mount.NameFromSpell(spellID),
        math.floor(actual or -1),
        math.floor(yards)))
end

--------------------------------------------------------------------------------
-- Clock
--------------------------------------------------------------------------------

--- Winds every timestamp back, which is indistinguishable from time passing.
local function SimFastForward(seconds)
    seconds = tonumber(seconds) or 60

    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then
        Say("Nothing is running.")
        return
    end

    if r.dispatchedAt then r.dispatchedAt = r.dispatchedAt - seconds end
    if r.pickedUpAt   then r.pickedUpAt   = r.pickedUpAt   - seconds end
    if r.leftAt       then r.leftAt       = r.leftAt       - seconds end

    Say(("Wound forward %d seconds."):format(seconds))
    ns.Tracker.Update()
end

--------------------------------------------------------------------------------
-- Reporting
--------------------------------------------------------------------------------

local function SimState()
    local r = ns.DB.GetRetrieval()
    if not r then
        Say("No retrieval table.")
        return
    end

    Say(("state=%s"):format(tostring(r.state)))

    if r.state == ns.STATE.IDLE then return end

    Say(("mount=%s  map=%s (%s)"):format(
        ns.Mount.NameFromSpell(r.spellID),
        ns.Mount.GetMapName(r.mapID),
        ns.Mount.FormatCoords(r.x, r.y)))

    local distance = ns.Retrieval.DistanceToMount()
    Say(("distance=%s  pickupRadius=%d  atHand=%s"):format(
        distance and ("%.0f yd"):format(distance) or "different map",
        (ns.DB.GetRules() or {}).pickupRadius or ns.PICKUP_RADIUS,
        tostring(ns.Retrieval.IsAtHand())))

    local now = time()
    if r.dispatchedAt then
        Say(("timerA elapsed=%ds of %ds"):format(now - r.dispatchedAt, ns.TIMER_A))
    end
    if r.pickedUpAt then
        Say(("timerB elapsed=%ds of %ds (locked)"):format(now - r.pickedUpAt, r.deliverySeconds or -1))
    end

    Say(("announced: left=%s approach=%s nearly=%s"):format(
        tostring(r.leftAnnounced), tostring(r.announcedApproach), tostring(r.announcedNearly)))
end

local function SimClear()
    local r = ns.DB.GetRetrieval()
    for k, v in pairs(ns.DB.DefaultRetrieval()) do r[k] = v end
    ns.Waypoint.Release(false)
    ns.RideButton.Update()
    if ns.Tracker then ns.Tracker.Update() end
    Say("Reset to idle.")
end

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

function Debug.Command(args)
    local cmd, rest = args:match("^(%S*)%s*(.*)$")

    if cmd == "leave" then
        SimLeave(rest)
    elseif cmd == "ff" then
        SimFastForward(rest)
    elseif cmd == "offline" then
        -- Same arithmetic as ff; named separately because it's the case that
        -- actually matters and deserves to be reachable by its own name.
        SimFastForward(rest)
        Say("Resolving as if you'd just logged back in.")
    elseif cmd == "state" then
        SimState()
    elseif cmd == "clear" then
        SimClear()
    else
        Say("leave <yards> | ff <seconds> | offline <seconds> | state | clear")
    end
end
