--[[
    Core/Commands.lua - slash commands and first-run.

    Version 1.x registered its command handler in one file and then monkeypatched
    it from the other at load time, which made behaviour depend on file order.
    There is one handler here and nothing patches it.
]]

local ADDON, ns = ...

local L = ns.L

--------------------------------------------------------------------------------
-- Status
--------------------------------------------------------------------------------

local function PrintStatus()
    local campaign = ns.DB.GetActiveCampaign()
    if not campaign then
        ns.Notify.System(L.STATUS_NO_CAMPAIGN)
        return
    end

    ns.Notify.System(L.STATUS_CAMPAIGN:format(campaign.name))

    for _, row in ipairs(ns.Presets.CardRows(campaign)) do
        ns.Notify.System(("  |cffffd100%s|r  %s"):format(row.label, row.text))
    end

    local r = ns.DB.GetRetrieval()
    if not r or r.state == ns.STATE.IDLE then
        ns.Notify.System(L.STATUS_NOTHING_LEFT)
        return
    end

    local mountName = ns.Mount.NameFromSpell(
        r.spellID,
        campaign.mounts.bonded == r.spellID and campaign.mounts.bondedName or nil
    )

    ns.Notify.System(("  |cffffd100%s|r - %s"):format(mountName, ns.Retrieval.StatusText()))

    local distance = ns.Retrieval.DistanceToMount()
    if distance then
        ns.Notify.System(("  %s (%s)"):format(
            L.TRACKER_DISTANCE:format(math.floor(distance)),
            ns.Mount.GetMapName(r.mapID)))
    else
        ns.Notify.System(("  %s (%s)"):format(
            ns.Mount.GetMapName(r.mapID),
            ns.Mount.FormatCoords(r.x, r.y)))
    end

    local remaining = ns.Retrieval.SecondsRemaining()
    if remaining then
        ns.Notify.System("  " .. L.TRACKER_ARRIVES_IN:format(ns.FormatDuration(remaining)))
    end
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

SLASH_DWMK1 = "/dwmk"
SLASH_DWMK2 = "/dude"

SlashCmdList["DWMK"] = function(input)
    local msg = (input or ""):lower():trim()

    if msg == "" then
        ns.Picker.Toggle()

    elseif msg == "help" then
        ns.Notify.Help()

    elseif msg == "config" or msg == "options" or msg == "settings" then
        ns.Config.Open()

    elseif msg == "status" then
        PrintStatus()

    elseif msg == "call" or msg == "whistle" then
        ns.Retrieval.Call()

    elseif msg == "track" or msg == "pin" then
        ns.Retrieval.Track()

    elseif msg:match("^sim") then
        ns.Debug.Command(msg:match("^sim%s*(.*)$") or "")

    else
        ns.Notify.System(L.SLASH_UNKNOWN)
    end
end

--------------------------------------------------------------------------------
-- First run
--------------------------------------------------------------------------------

ns:OnLoad(function()
    local g = ns.DB.GetGlobals()
    if g.firstRunDone then return end

    -- Opening on a loading screen is jarring, so wait until the player is
    -- actually in the world and settled.
    ns:On("PLAYER_ENTERING_WORLD", function()
        if ns.DB.GetGlobals().firstRunDone then return end
        C_Timer.After(2, function()
            if ns.DB.GetGlobals().firstRunDone then return end
            ns.Notify.System(L.FIRST_RUN)
            ns.Picker.Open()
        end)
    end)
end)
