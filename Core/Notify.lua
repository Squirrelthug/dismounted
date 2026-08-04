--[[
    Core/Notify.lua - everything the addon says.

    Two registers, deliberately kept apart:

      System   plain, factual. Pin moved, campaign changed, mount recovered.
      Emote    in-character narration of the retrieval service.

    A player who wants the mechanic without the roleplay can turn emotes down to
    plain text and still be told everything they need to know, because the system
    messages carry the actual information on their own.

    Emote timing is milestone-based - dispatch, pick-up, nearly there, arrival -
    and never fires on the polling tick. A courier who reports in every five
    seconds stops being charming within about a minute.
]]

local ADDON, ns = ...

local Notify = {}
ns.Notify = Notify

local L = ns.L

-- The version 1.x tag, kept: it's the addon's signature and reads well.
local TAG = "|cffffa500D|r|cffff0000W|r|cff00ff00M|r|cff5588ffK|r"

--------------------------------------------------------------------------------
-- Output
--------------------------------------------------------------------------------

local function GetFrame()
    local g = ns.DB and ns.DB.GetGlobals and ns.DB.GetGlobals()
    local index = g and g.chatFrame or 1

    if index and index > 1 then
        local frame = _G["ChatFrame" .. index]
        if frame then return frame end
    end
    return DEFAULT_CHAT_FRAME
end

local function Emit(text)
    GetFrame():AddMessage(("[%s] %s"):format(TAG, text))
end

--- Plain, factual output.
function Notify.System(text)
    if not text then return end
    Emit(ns.Colorize(text, ns.COLOR.BODY))
end

--- A rule refusing something. Goes to chat and flashes in the centre of the
--- screen, because it explains why an action the player just took did nothing.
function Notify.Refused(reason)
    if not reason then return end
    Emit(ns.Colorize(reason, ns.COLOR.STRICT))
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(reason, 1.0, 0.57, 0.17, 1.0, 3)
    end
end

--------------------------------------------------------------------------------
-- Emotes
--------------------------------------------------------------------------------

--- Fills the {token} placeholders in a locale string.
---
--- Tokens: {service} {company} {mount} {zone} {coords} {time}
function Notify.Fill(template, values)
    if not template then return "" end

    return (template:gsub("{(%w+)}", function(token)
        local v = values and values[token]
        if v == nil then return "{" .. token .. "}" end
        return tostring(v)
    end))
end

--- Builds the standard token set for the active campaign and a mount.
function Notify.Tokens(extra)
    local campaign  = ns.DB.GetActiveCampaign()
    local retrieval = ns.DB.GetRetrieval()

    local service = campaign and campaign.service or {}

    local tokens = {
        service = service.courierName or "The courier",
        company = service.companyName or L.COMPANY_GOBLIN,
    }

    if retrieval and retrieval.spellID then
        -- Under Bonded the player named the mount, and that name is what the
        -- narration should use.
        local bondedName
        if campaign and campaign.mounts.bonded == retrieval.spellID then
            bondedName = campaign.mounts.bondedName
        end
        tokens.mount  = ns.Mount.NameFromSpell(retrieval.spellID, bondedName)
        tokens.zone   = ns.Mount.GetMapName(retrieval.mapID)
        tokens.coords = ns.Mount.FormatCoords(retrieval.x, retrieval.y)
    end

    if extra then
        for k, v in pairs(extra) do tokens[k] = v end
    end

    return tokens
end

--- Narration. `template` is a locale string containing {tokens}.
function Notify.Emote(template, extra)
    if not template then return end
    Emit(ns.Colorize(Notify.Fill(template, Notify.Tokens(extra)), ns.COLOR.HIGHLIGHT))
end

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------

--- Rung when a mount is handed back, if the player asked for it. Off by default.
function Notify.Bell()
    local g = ns.DB.GetGlobals()
    if not g or not g.bell then return end

    local kit = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3
    if kit then
        PlaySound(kit, "Master")
    end
end

--------------------------------------------------------------------------------
-- Help
--------------------------------------------------------------------------------

function Notify.Help()
    Notify.System(L.SLASH_HEADER)
    Emit(L.SLASH_BARE)
    Emit(L.SLASH_STATUS)
    Emit(L.SLASH_CALL)
    Emit(L.SLASH_TRACK)
    Emit(L.SLASH_CONFIG)
end
