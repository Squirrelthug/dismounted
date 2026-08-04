--[[
    Core/Presets.lua - the campaign library.

    Data only. Every card in the picker renders entirely from these tables, so
    adding a campaign is one entry here and no UI code at all.

    Each preset answers the same six questions in the same order. That
    consistency is the point: a player learns the format once on the first card
    and can then read any other campaign at a glance, or compare two by reading
    down a single column.

    Timer copy is generated from the constants in Core/Init.lua rather than
    typed out, so what the card promises and what the code does cannot drift
    apart.
]]

local ADDON, ns = ...

local Presets = {}
ns.Presets = Presets

local L = ns.L

--------------------------------------------------------------------------------
-- Shared card copy
--------------------------------------------------------------------------------

local function GettingBackText()
    return ("%s for the service to reach it, then %s if you're nearby, %s if not.")
        :format(
            ns.FormatDuration(ns.TIMER_A),
            ns.FormatDuration(ns.TIMER_B_CLOSE),
            ns.FormatDuration(ns.TIMER_B_FAR)
        )
end

local function GettingBackOnCallText()
    return ("From the moment you call: %s to reach it, then %s if you're nearby, %s if not.")
        :format(
            ns.FormatDuration(ns.TIMER_A),
            ns.FormatDuration(ns.TIMER_B_CLOSE),
            ns.FormatDuration(ns.TIMER_B_FAR)
        )
end

local function PickUpText(radius, note)
    return ("Come within %d yd%s and it's yours instantly."):format(radius, note or ", on foot or in the air")
end

local ASSIGNED_MOUNTS = "One ground mount and one flyer that you assign."
local LEAVING_AUTO    = "Sent for automatically the moment you walk away."
local LEAVING_CALL    = "Nothing happens until you call for it. The mount stays put indefinitely."
local NOTHING_ELSE    = "Nothing else."

--------------------------------------------------------------------------------
-- The presets
--------------------------------------------------------------------------------

local C = ns.COLOR
local S = ns.SEVERITY
local E = ns.ENFORCE
local D = ns.DISPATCH
local M = ns.MOUNTPOLICY

local definitions = {

    ----------------------------------------------------------------------------
    {
        key      = "wayfarer",
        name     = "Wayfarer",
        hook     = "The road is long and you are not a purist.",
        severity = S.PERMISSIVE,
        order    = 1,
        isDefault = true,
        chips = {
            { text = "Any Mount",   color = C.PERMISSIVE },
            { text = "Auto-Recall", color = C.PERMISSIVE },
            { text = "Notify Only", color = C.PERMISSIVE },
        },
        rules = {
            enforcement        = E.NOTIFY,
            mountPolicy        = M.ANY,
            groundOnly         = false,
            settlementDismount = false,
            dispatch           = D.AUTO,
            pickupRadius       = 200,
        },
        card = {
            whichMounts = "Any mount you own.",
            ifBreak     = L.ENFORCE_NOTIFY_CARD,
            leaving     = LEAVING_AUTO,
            gettingBack = GettingBackText,
            pickUp      = function(p) return PickUpText(p.rules.pickupRadius) end,
            also        = "Nothing else. This is the gentle one.",
        },
    },

    ----------------------------------------------------------------------------
    {
        key      = "pilgrim",
        name     = "Pilgrim",
        hook     = "You do not ride through a man's home. You walk, and you nod.",
        severity = S.PERMISSIVE,
        order    = 2,
        chips = {
            { text = "Any Mount",        color = C.PERMISSIVE },
            { text = "Dismount in Town", color = C.CONSTRAINT },
            { text = "Refuses Illegal",  color = C.STRICT },
        },
        rules = {
            enforcement        = E.REFUSE,
            mountPolicy        = M.ANY,
            groundOnly         = false,
            settlementDismount = true,
            dispatch           = D.AUTO,
            pickupRadius       = 200,
        },
        card = {
            whichMounts = "Any mount you own.",
            ifBreak     = L.ENFORCE_REFUSE_CARD,
            leaving     = "Sent for automatically.",
            gettingBack = GettingBackText,
            pickUp      = function(p) return PickUpText(p.rules.pickupRadius) end,
            also        = "Riding inside cities, towns and settlements is refused. The open road is entirely yours, and so is your own neighborhood.",
        },
    },

    ----------------------------------------------------------------------------
    {
        key      = "stablehand",
        name     = "Stablehand",
        hook     = "You put your beast up properly, and you fetch it properly.",
        severity = S.CONSTRAINT,
        order    = 3,
        chips = {
            { text = "Assigned Mounts", color = C.CONSTRAINT },
            { text = "Auto-Recall",     color = C.PERMISSIVE },
            { text = "Refuses Illegal", color = C.STRICT },
        },
        rules = {
            enforcement        = E.REFUSE,
            mountPolicy        = M.ASSIGNED,
            groundOnly         = false,
            settlementDismount = false,
            dispatch           = D.AUTO,
            pickupRadius       = 200,
        },
        card = {
            whichMounts = ASSIGNED_MOUNTS,
            ifBreak     = L.ENFORCE_REFUSE_CARD,
            leaving     = "Sent for automatically.",
            gettingBack = GettingBackText,
            pickUp      = function(p) return PickUpText(p.rules.pickupRadius) end,
            also        = NOTHING_ELSE,
        },
    },

    ----------------------------------------------------------------------------
    {
        key      = "nomad",
        name     = "Nomad",
        hook     = "The sky is for dragons. You have the road.",
        severity = S.STRICT,
        order    = 4,
        chips = {
            { text = "Assigned Mounts", color = C.CONSTRAINT },
            { text = "Ground Only",     color = C.STRICT },
            { text = "Refuses Illegal", color = C.STRICT },
        },
        rules = {
            enforcement        = E.REFUSE,
            mountPolicy        = M.ASSIGNED,
            groundOnly         = true,
            settlementDismount = false,
            dispatch           = D.AUTO,
            pickupRadius       = 200,
        },
        card = {
            whichMounts = "One ground mount you assign.",
            ifBreak     = L.ENFORCE_REFUSE_CARD,
            leaving     = "Sent for automatically.",
            gettingBack = GettingBackText,
            pickUp      = function(p)
                return PickUpText(p.rules.pickupRadius, " - on foot, since you won't be flying")
            end,
            also        = "Flying mounts and skyriding are refused outright.",
        },
    },

    ----------------------------------------------------------------------------
    {
        key      = "ironhoof",
        name     = "Ironhoof",
        hook     = "No one rides for you. Send word, and wait.",
        severity = S.STRICT,
        order    = 5,
        chips = {
            { text = "Assigned Mounts",  color = C.CONSTRAINT },
            { text = "Call to Retrieve", color = C.STRICT },
            { text = "Refuses Illegal",  color = C.STRICT },
        },
        rules = {
            enforcement        = E.REFUSE,
            mountPolicy        = M.ASSIGNED,
            groundOnly         = false,
            settlementDismount = false,
            dispatch           = D.CALL,
            pickupRadius       = 150,
        },
        card = {
            whichMounts = ASSIGNED_MOUNTS,
            ifBreak     = L.ENFORCE_REFUSE_CARD,
            leaving     = LEAVING_CALL,
            gettingBack = GettingBackOnCallText,
            pickUp      = function(p) return PickUpText(p.rules.pickupRadius) end,
            also        = NOTHING_ELSE,
        },
    },

    ----------------------------------------------------------------------------
    {
        key      = "bonded",
        name     = "Bonded",
        hook     = "One beast. You know its temper and it knows yours. There is no other.",
        severity = S.HARSH,
        order    = 6,
        chips = {
            { text = "One Mount Only",   color = C.HARSH },
            { text = "Call to Retrieve", color = C.STRICT },
            { text = "Refuses Illegal",  color = C.STRICT },
        },
        rules = {
            enforcement        = E.REFUSE,
            mountPolicy        = M.SINGLE,
            groundOnly         = false,
            settlementDismount = false,
            dispatch           = D.CALL,
            pickupRadius       = 150,
        },
        card = {
            whichMounts = "Exactly one, chosen at campaign start. You name it, and the messages use that name.",
            ifBreak     = L.ENFORCE_REFUSE_CARD,
            leaving     = LEAVING_CALL,
            gettingBack = GettingBackOnCallText,
            pickUp      = function(p) return PickUpText(p.rules.pickupRadius) end,
            also        = "No ground and flyer split. Every other mount you own is refused.",
        },
    },

    ----------------------------------------------------------------------------
    {
        key      = "caravan",
        name     = "Caravan",
        hook     = "No one is coming. Where you left it is where it stays.",
        severity = S.HARSH,
        order    = 7,
        chips = {
            { text = "Assigned Mounts", color = C.CONSTRAINT },
            { text = "No Service",      color = C.HARSH },
            { text = "Walk Back",       color = C.HARSH },
        },
        rules = {
            enforcement        = E.REFUSE,
            mountPolicy        = M.ASSIGNED,
            groundOnly         = false,
            settlementDismount = false,
            dispatch           = D.NONE,
            pickupRadius       = 200,
        },
        card = {
            whichMounts = ASSIGNED_MOUNTS,
            ifBreak     = L.ENFORCE_REFUSE_CARD,
            leaving     = "It stays exactly where you left it.",
            gettingBack = "There is no service. You go and get it. Track it puts a map pin on it.",
            pickUp      = function(p)
                return PickUpText(p.rules.pickupRadius, " - kept generous, since it's your only option")
            end,
            also        = "This is the addon's original behaviour, kept as a deliberate choice.",
        },
    },

    ----------------------------------------------------------------------------
    {
        key      = "custom",
        name     = "Custom",
        hook     = "Set your own terms.",
        severity = S.NEUTRAL,
        order    = 8,
        isCustom = true,
        chips = {
            { text = "Your Rules", color = C.NEUTRAL },
        },
        rules = {
            enforcement        = E.NOTIFY,
            mountPolicy        = M.ASSIGNED,
            groundOnly         = false,
            settlementDismount = false,
            dispatch           = D.AUTO,
            pickupRadius       = 200,
        },
        card = {
            whichMounts = "Whatever you decide.",
            ifBreak     = "Whatever you decide.",
            leaving     = "Whatever you decide.",
            gettingBack = "Whatever you decide.",
            pickUp      = function(p) return PickUpText(p.rules.pickupRadius) end,
            also        = "Opens the settings with every option unlocked.",
        },
    },
}

--------------------------------------------------------------------------------
-- Lookup
--------------------------------------------------------------------------------

local byKey = {}
for i = 1, #definitions do
    byKey[definitions[i].key] = definitions[i]
end

function Presets.Get(key)
    return byKey[key] or byKey.custom
end

function Presets.Exists(key)
    return byKey[key] ~= nil
end

--- All presets in display order: gentlest first, so the list itself teaches the
--- gradient before the player has read a single rule.
function Presets.Ordered()
    local list = {}
    for i = 1, #definitions do
        list[i] = definitions[i]
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

function Presets.Default()
    for i = 1, #definitions do
        if definitions[i].isDefault then return definitions[i] end
    end
    return definitions[1]
end

--- Resolves one card row, which may be a plain string or a function of the
--- campaign (for anything that depends on a value the player can change).
function Presets.ResolveRow(value, campaign)
    if type(value) == "function" then
        return value(campaign)
    end
    return value
end

--- Builds the six card rows for a campaign, in display order.
function Presets.CardRows(campaign)
    local preset = Presets.Get(campaign.preset)
    local card   = preset.card

    -- Custom campaigns describe themselves from their live rules rather than
    -- from static copy, otherwise every row would read "whatever you decide".
    if preset.isCustom then
        card = Presets.DescribeRules(campaign)
    end

    return {
        { label = L.ROW_WHICH_MOUNTS, text = Presets.ResolveRow(card.whichMounts, campaign) },
        { label = L.ROW_IF_BREAK,     text = Presets.ResolveRow(card.ifBreak,     campaign) },
        { label = L.ROW_LEAVING,      text = Presets.ResolveRow(card.leaving,     campaign) },
        { label = L.ROW_GETTING_BACK, text = Presets.ResolveRow(card.gettingBack, campaign) },
        { label = L.ROW_PICK_UP,      text = Presets.ResolveRow(card.pickUp,      campaign) },
        { label = L.ROW_ALSO,         text = Presets.ResolveRow(card.also,        campaign) },
    }
end

--- Generates card copy from a campaign's actual rule values. Used for Custom,
--- and by the config panel to show the player what their edits amount to.
function Presets.DescribeRules(campaign)
    local r = campaign.rules

    local whichMounts
    if r.mountPolicy == M.ANY then
        whichMounts = "Any mount you own."
    elseif r.mountPolicy == M.SINGLE then
        whichMounts = "Exactly one mount, chosen and named by you."
    elseif r.groundOnly then
        whichMounts = "One ground mount you assign."
    else
        whichMounts = ASSIGNED_MOUNTS
    end

    local ifBreak
    if r.enforcement == E.OFF then
        ifBreak = L.ENFORCE_OFF_CARD
    elseif r.enforcement == E.NOTIFY then
        ifBreak = L.ENFORCE_NOTIFY_CARD
    else
        ifBreak = L.ENFORCE_REFUSE_CARD
    end

    local leaving, gettingBack
    if r.dispatch == D.AUTO then
        leaving     = LEAVING_AUTO
        gettingBack = GettingBackText()
    elseif r.dispatch == D.CALL then
        leaving     = LEAVING_CALL
        gettingBack = GettingBackOnCallText()
    else
        leaving     = "It stays exactly where you left it."
        gettingBack = "There is no service. You go and get it."
    end

    local also = {}
    if r.groundOnly then
        table.insert(also, "Flying mounts and skyriding are refused.")
    end
    if r.settlementDismount then
        table.insert(also, "Riding inside settlements is refused.")
    end
    table.insert(also, "No rule applies inside your housing neighborhood.")

    return {
        whichMounts = whichMounts,
        ifBreak     = ifBreak,
        leaving     = leaving,
        gettingBack = gettingBack,
        pickUp      = PickUpText(r.pickupRadius),
        also        = #also > 0 and table.concat(also, " ") or NOTHING_ELSE,
    }
end

--- Chips for a campaign. Custom derives them from its rules so an edited
--- campaign still scans correctly in the list.
function Presets.Chips(campaign)
    local preset = Presets.Get(campaign.preset)
    if not preset.isCustom then return preset.chips end

    local r, chips = campaign.rules, {}

    if r.mountPolicy == M.ANY then
        table.insert(chips, { text = "Any Mount", color = C.PERMISSIVE })
    elseif r.mountPolicy == M.SINGLE then
        table.insert(chips, { text = "One Mount Only", color = C.HARSH })
    else
        table.insert(chips, { text = "Assigned Mounts", color = C.CONSTRAINT })
    end

    if r.groundOnly then
        table.insert(chips, { text = "Ground Only", color = C.STRICT })
    end
    if r.settlementDismount then
        table.insert(chips, { text = "Dismount in Town", color = C.CONSTRAINT })
    end

    if r.dispatch == D.NONE then
        table.insert(chips, { text = "No Service", color = C.HARSH })
    elseif r.dispatch == D.CALL then
        table.insert(chips, { text = "Call to Retrieve", color = C.STRICT })
    else
        table.insert(chips, { text = "Auto-Recall", color = C.PERMISSIVE })
    end

    if r.enforcement == E.OFF then
        table.insert(chips, { text = "Tracking Only", color = C.PERMISSIVE })
    elseif r.enforcement == E.NOTIFY then
        table.insert(chips, { text = "Notify Only", color = C.PERMISSIVE })
    else
        table.insert(chips, { text = "Refuses Illegal", color = C.STRICT })
    end

    return chips
end

--- Colour for a campaign's severity dot.
function Presets.SeverityColor(campaign)
    local preset = Presets.Get(campaign.preset)

    local severity = preset.severity
    if preset.isCustom then
        -- Rank an edited campaign by what it actually enforces.
        local r = campaign.rules
        if r.mountPolicy == M.SINGLE or r.dispatch == D.NONE then
            severity = S.HARSH
        elseif r.groundOnly or r.dispatch == D.CALL then
            severity = S.STRICT
        elseif r.enforcement == E.REFUSE then
            severity = S.CONSTRAINT
        else
            severity = S.PERMISSIVE
        end
    end

    if severity == S.PERMISSIVE then return C.PERMISSIVE
    elseif severity == S.CONSTRAINT then return C.CONSTRAINT
    elseif severity == S.STRICT then return C.STRICT
    elseif severity == S.HARSH then return C.HARSH end
    return C.NEUTRAL
end

--------------------------------------------------------------------------------
-- Retrieval companies
--
-- Purely cosmetic. Rolled once when a campaign is created and then persisted, so
-- the same courier turns up every time and starts to feel like a fixture.
--------------------------------------------------------------------------------

local GOBLIN_FIRST = { "Grimble", "Nixxle", "Zabber", "Fizzik", "Krenk", "Snazzle", "Rikkit", "Bozzle" }
local GOBLIN_LAST  = { "Sparkwhistle", "Coggrind", "Boltwrench", "Fasttrack", "Sureprofit", "Quickcart" }

local GNOME_FIRST  = { "Tinky", "Wizzle", "Fimble", "Bixby", "Nedwin", "Pilby", "Tocky", "Merrin" }
local GNOME_LAST   = { "Cogspring", "Gearwhistle", "Sprocketwind", "Fizzlebolt", "Turnkey", "Winderly" }

--- Rolls a courier identity. Returns { company = key, companyName, courierName }.
function Presets.RollService(forceCompany)
    local isGoblin
    if forceCompany == "goblin" then
        isGoblin = true
    elseif forceCompany == "gnome" then
        isGoblin = false
    else
        isGoblin = math.random(2) == 1
    end

    local first = isGoblin and GOBLIN_FIRST or GNOME_FIRST
    local last  = isGoblin and GOBLIN_LAST  or GNOME_LAST

    return {
        company     = isGoblin and "goblin" or "gnome",
        companyName = isGoblin and L.COMPANY_GOBLIN or L.COMPANY_GNOME,
        courierName = ("%s %s"):format(first[math.random(#first)], last[math.random(#last)]),
    }
end
