--[[
    Core/Waypoint.lua - borrowing the map pin, and giving it back.

    The game has exactly one user waypoint: the same slot the player's own
    right-click pin lives in. Setting ours destroys theirs. TomTom, which this
    addon used to depend on, had no such limit - so the old behaviour of setting
    a waypoint automatically on every violation would have been actively hostile
    once ported to the built-in system.

    Hence: DWMK never takes the pin on its own initiative. The player asks, via
    Track it. We save whatever was there, put ours down, and give theirs back
    when we're finished. And if they move the pin themselves while we're holding
    it, we let go immediately and never touch it again for that mount - fighting
    a player over their own map pin is not a fight worth winning.

    The pin is also static. It marks where the mount was left and never moves.
    A retrieval in progress is narrated in chat, not animated on the map.
]]

local ADDON, ns = ...

local Waypoint = {}
ns.Waypoint = Waypoint

local L = ns.L

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local weOwnIt   = false  -- the current pin is ours
local stashed   = nil    -- the player's pin, saved for later
local ourWrite  = false  -- guard: distinguishes our SetUserWaypoint from theirs

--------------------------------------------------------------------------------
-- Track
--------------------------------------------------------------------------------

--- Puts a pin on a left-behind mount. Returns true if it worked.
function Waypoint.Track(anchor, mountName)
    if not anchor or not anchor.mapID then return false end

    if not C_Map.CanSetUserWaypointOnMap(anchor.mapID) then
        ns.Notify.System(L.PIN_INVALID_MAP)
        return false
    end

    -- Save the player's pin, but only if it isn't already one of ours - two
    -- Track presses in a row must not overwrite the stash with our own pin.
    if not weOwnIt then
        stashed = C_Map.GetUserWaypoint()
    end

    ourWrite = true
    local set = C_Map.SetUserWaypoint(
        UiMapPoint.CreateFromCoordinates(anchor.mapID, anchor.x, anchor.y)
    )
    ourWrite = false

    if not set then
        ns.Notify.System(L.PIN_INVALID_MAP)
        return false
    end

    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    weOwnIt = true

    ns.Notify.System(L.PIN_SET:format(
        mountName or UNKNOWN,
        ns.Mount.GetMapName(anchor.mapID),
        ns.Mount.FormatCoords(anchor.x, anchor.y)
    ))

    if stashed then
        ns.Notify.System(L.PIN_STASHED)
    end

    ns.Notify.System(L.PIN_RADIUS_HINT)
    ns.MapCircle.Show(anchor)

    return true
end

--------------------------------------------------------------------------------
-- Release
--------------------------------------------------------------------------------

--- Drops our pin and restores the player's, if we're still holding it.
---
--- Called when the mount comes back by any route. The message is always sent
--- alongside the reason the mount was recovered, never on its own - a pin that
--- silently vanishes as you approach reads as a bug.
function Waypoint.Release(announce)
    ns.MapCircle.Hide()

    if not weOwnIt then
        -- The player took the pin back at some point. Nothing owed.
        stashed = nil
        return
    end

    weOwnIt = false

    local restore = ns.DB.GetGlobals() and ns.DB.GetGlobals().autoRestorePin
    ourWrite = true

    if restore and stashed then
        C_Map.SetUserWaypoint(stashed)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        if announce ~= false then
            ns.Notify.System(L.PIN_RESTORED)
        end
    else
        C_Map.ClearUserWaypoint()
        if announce ~= false then
            ns.Notify.System(L.PIN_CLEARED)
        end
    end

    ourWrite = false
    stashed  = nil
end

function Waypoint.WeOwnIt()
    return weOwnIt
end

--------------------------------------------------------------------------------
-- Yielding
--------------------------------------------------------------------------------

-- Fires for our own writes too, hence the guard. If the pin changed and it
-- wasn't us, the player has taken it back - so we forget the stash and stop
-- considering the pin ours.
ns:On("USER_WAYPOINT_UPDATED", function()
    if ourWrite then return end
    if not weOwnIt then return end

    weOwnIt = false
    stashed = nil
    ns.MapCircle.Hide()
    ns.Notify.System(L.PIN_YIELDED)
end)
