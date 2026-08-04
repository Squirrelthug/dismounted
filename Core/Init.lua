--[[
    Core/Init.lua - namespace, constants, event dispatch.

    Everything in the addon hangs off `ns`, the per-addon table the game hands to
    every file. Nothing here touches _G except the frame it creates, which is
    unnamed. Version 1.x leaked DWMK_CreateCampaign as a bare global to bridge its
    two files; the shared namespace removes the need for that entirely.
]]

local ADDON, ns = ...

ns.ADDON     = ADDON
ns.VERSION   = "2.0.0"
ns.DB_SCHEMA = 2

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- Enforcement. Three values, deliberately: there is no grace tier. A player who
-- is given a countdown and then pulled off a mount they already cast is a player
-- who uninstalls the addon.
ns.ENFORCE = {
    OFF    = 0,  -- tracking only, never dismounts
    NOTIFY = 1,  -- says something, never dismounts
    REFUSE = 2,  -- the mount does not happen
}

-- How a left-behind mount gets sent for.
ns.DISPATCH = {
    AUTO = "auto",  -- the moment you walk away
    CALL = "call",  -- only when you sound the signal
    NONE = "none",  -- never; walk back for it (Caravan)
}

-- Which mounts a campaign permits.
ns.MOUNTPOLICY = {
    ANY      = "any",       -- anything in your journal
    ASSIGNED = "assigned",  -- one ground + one flyer you nominate
    SINGLE   = "single",    -- exactly one mount, named (Bonded)
}

-- Retrieval state machine.
ns.STATE = {
    IDLE       = "idle",        -- the mount is with you
    LEFT       = "left",        -- sitting where you left it, nobody sent for
    DISPATCHED = "dispatched",  -- Timer A: service travelling to the mount
    CARRYING   = "carrying",    -- Timer B: service bringing it to you
}

--------------------------------------------------------------------------------
-- Tuning
--
-- These produce the numbers printed on the campaign cards. Change one and the
-- card copy in Core/Presets.lua must change with it.
--------------------------------------------------------------------------------

ns.TIMER_A          = 60    -- seconds for the service to reach your mount. Always.
ns.TIMER_B_CLOSE    = 30    -- seconds to bring it to you, if you're near
ns.TIMER_B_FAR      = 180   -- seconds to bring it to you, if you're not
ns.CLOSE_DISTANCE   = 1000  -- yards; the close/far threshold, same-map only

ns.PICKUP_RADIUS    = 200   -- yards; collect it yourself by getting this close
ns.APPROACH_FACTOR  = 2     -- announce "you can see it" at this multiple of the radius

-- Polling. A 5s tick at flying speed (~60 yd/s) covers 300 yards and would step
-- clean over a 200 yard pickup bubble without ever noticing it, so the tick
-- tightens to 1s once you're anywhere near the anchor.
ns.POLL_SLOW        = 5
ns.POLL_FAST        = 1
ns.POLL_FAST_RANGE  = 1000  -- yards from the anchor at which polling tightens

ns.NEARLY_THERE_AT  = 30    -- seconds remaining when the "close now" emote fires

--------------------------------------------------------------------------------
-- Colours
--------------------------------------------------------------------------------

ns.COLOR = {
    -- Keyword chip severity
    PERMISSIVE = "ff40c057",  -- green  - QoL, forgiving
    CONSTRAINT = "ffffd43b",  -- yellow - a real limit, gently applied
    STRICT     = "ffff922b",  -- orange - refuses things
    HARSH      = "ffff6b6b",  -- red    - refuses things and won't help you

    NEUTRAL    = "ff9e9e9e",  -- grey   - Custom
    HIGHLIGHT  = "ffffd100",  -- gold   - emphasis in body text
    BODY       = "ffd8d0c0",  -- parchment - rule copy
}

-- Severity ordering, used to sort the picker and pick the card's dot colour.
ns.SEVERITY = {
    PERMISSIVE = 1,
    CONSTRAINT = 2,
    STRICT     = 3,
    HARSH      = 4,
    NEUTRAL    = 5,
}

--------------------------------------------------------------------------------
-- Event dispatch
--
-- Modules call ns:On("EVENT", fn). One frame, one OnEvent, so registration order
-- across files doesn't matter and nothing has to know about anything else.
--------------------------------------------------------------------------------

local dispatcher = CreateFrame("Frame")
local handlers   = {}

function ns:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        dispatcher:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        -- One module erroring must not stop the others from seeing the event.
        local ok, err = pcall(list[i], ...)
        if not ok then
            geterrorhandler()(("%s: error in %s handler: %s"):format(ADDON, event, tostring(err)))
        end
    end
end)

--------------------------------------------------------------------------------
-- Deferred initialisation
--
-- ns:OnLoad(fn) runs once, after our SavedVariables are available. Modules use
-- this instead of executing at file scope so load order stays flexible.
--------------------------------------------------------------------------------

local loadCallbacks = {}
local hasLoaded     = false

function ns:OnLoad(fn)
    if hasLoaded then
        fn()
    else
        table.insert(loadCallbacks, fn)
    end
end

ns:On("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= ADDON then return end
    if hasLoaded then return end  -- belt and braces; running the list twice would error
    hasLoaded = true
    for i = 1, #loadCallbacks do
        local ok, err = pcall(loadCallbacks[i])
        if not ok then
            geterrorhandler()(("%s: error during load: %s"):format(ADDON, tostring(err)))
        end
    end
    loadCallbacks = nil
end)

--------------------------------------------------------------------------------
-- Small shared helpers
--------------------------------------------------------------------------------

--- Wraps text in a colour escape. `color` is one of ns.COLOR.
function ns.Colorize(text, color)
    return ("|c%s%s|r"):format(color, tostring(text))
end

--- Humanises a duration for player-facing text. Whole minutes read as minutes;
--- anything under a minute stays in seconds. Used by card copy and the tracker.
function ns.FormatDuration(seconds)
    local L = ns.L
    seconds = math.max(0, math.floor(seconds + 0.5))

    if seconds < 60 then
        return L.TIME_SECONDS:format(seconds)
    end

    local minutes = seconds / 60
    if minutes == math.floor(minutes) then
        if minutes == 1 then
            return L.TIME_ONE_MINUTE
        end
        return L.TIME_MINUTES:format(minutes)
    end

    return L.TIME_MIN_SEC:format(math.floor(seconds / 60), seconds % 60)
end

--- Counts entries in a non-sequential table. Version 1.x open-coded this loop in
--- four separate places.
function ns.CountKeys(t)
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
