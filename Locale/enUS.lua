--[[
    Locale/enUS.lua - every user-facing string.

    Loaded first. The addon table (`ns`) is created by the game and shared across
    all files, so this can populate ns.L before any other module exists.

    Emote strings use these tokens, substituted by Core/Notify.lua:
        {service}  the retrieval company's courier name  e.g. "Grimble Sparkwhistle"
        {company}  the company name                      e.g. "Swiftwheel Freight & Salvage"
        {mount}    the mount's name (or its given name under Bonded)
        {zone}     zone name
        {coords}   formatted "44.2, 61.8"
        {time}     humanised duration e.g. "1 minute"
]]

local ADDON, ns = ...

local L = {}
ns.L = L

--------------------------------------------------------------------------------
-- Addon chrome
--------------------------------------------------------------------------------

L.ADDON_NAME        = "Dude Where's My K'arroc"
L.ADDON_SHORT       = "DWMK"

--------------------------------------------------------------------------------
-- Enforcement levels
--------------------------------------------------------------------------------

L.ENFORCE_OFF_NAME      = "Off"
L.ENFORCE_OFF_CARD      = "Nothing. Tracking only."
L.ENFORCE_OFF_DESC      = "Records where you leave mounts and lets you retrieve them. You are never dismounted."

L.ENFORCE_NOTIFY_NAME   = "Notify"
L.ENFORCE_NOTIFY_CARD   = "A chat message. You are never dismounted."
L.ENFORCE_NOTIFY_DESC   = "One line in chat naming the rule you broke. You keep riding."

L.ENFORCE_REFUSE_NAME   = "Refuse"
L.ENFORCE_REFUSE_CARD   = "The mount doesn't happen."
L.ENFORCE_REFUSE_DESC   = "The Ride key won't cast it. Summoned another way, it's gone the moment it appears."

--------------------------------------------------------------------------------
-- Rule violation reasons
--------------------------------------------------------------------------------

L.DENY_NOT_ASSIGNED     = "%s is not one of this campaign's mounts."
L.DENY_NOT_BONDED       = "You are bonded to %s. You ride nothing else."
L.DENY_NO_BOND_CHOSEN   = "You haven't chosen your mount yet."
L.DENY_FLYING           = "%s flies. This campaign keeps you on the ground."
L.DENY_SETTLEMENT       = "You do not ride through a settlement."
L.DENY_NOT_HERE         = "Your %s isn't here. You left it in %s."
L.DENY_NO_LEGAL_MOUNT   = "You have no mount to ride."

--------------------------------------------------------------------------------
-- Ride button
--------------------------------------------------------------------------------

L.BINDING_HEADER        = "Dude Where's My K'arroc"
L.BINDING_RIDE          = "Ride"
L.RIDE_TOOLTIP          = "Summons this campaign's mount.\n\nIf no mount is currently legal, nothing is cast."

--------------------------------------------------------------------------------
-- Retrieval - state and emotes
--------------------------------------------------------------------------------

-- Dispatch (auto)
L.EMOTE_DISPATCH_AUTO   = "Word reaches {company}. {service} sets out for your {mount}."
-- Dispatch (manual whistle)
L.EMOTE_DISPATCH_CALL   = "You sound the signal. {service} of {company} sets out for your {mount}."
-- Timer A complete, Timer B begins
L.EMOTE_PICKUP_CLOSE    = "{service} has your {mount} in hand. You aren't far - they're on their way."
L.EMOTE_PICKUP_FAR      = "{service} has your {mount} in hand, and a long road ahead of them."
-- 30 seconds out
L.EMOTE_NEARLY_THERE    = "{service} is close now. You can hear your {mount} coming."
-- Delivered
L.EMOTE_DELIVERED       = "{service} hands you the reins of your {mount}. Business concluded."
-- Self-recovery
L.EMOTE_SELF_APPROACH   = "You can see your {mount} from here."
L.EMOTE_SELF_RECOVERED  = "You've reached your {mount} - it's yours again."
L.EMOTE_SELF_CANCELLED  = "You got there first. {service} turns the cart around, unpaid and unbothered."
-- Left behind
L.EMOTE_LEFT_BEHIND     = "You leave your {mount} in {zone} ({coords})."
L.EMOTE_LEFT_NO_SERVICE = "You leave your {mount} in {zone} ({coords}). No one is coming for it."
L.EMOTE_AWAITING_CALL   = "Your {mount} waits in {zone}. Sound the signal when you want it back."

--------------------------------------------------------------------------------
-- Retrieval - plain status (tracker, tooltips, /dwmk status)
--------------------------------------------------------------------------------

L.STATE_IDLE            = "With you"
L.STATE_LEFT            = "Left behind"
L.STATE_AWAITING        = "Awaiting your call"
L.STATE_DISPATCHED      = "%s is on the way to it"
L.STATE_CARRYING        = "%s is bringing it to you"

L.TRACKER_REACHING      = "Reaching your mount"
L.TRACKER_DELIVERING    = "Bringing it to you"
L.TRACKER_DISTANCE      = "%d yd away"
L.TRACKER_ARRIVES_IN    = "Arrives in %s"

--------------------------------------------------------------------------------
-- Waypoint
--------------------------------------------------------------------------------

L.PIN_TRACK             = "Track it"
L.PIN_SET               = "Map pin set on your %s in %s (%s)."
L.PIN_STASHED           = "Your own map pin was saved and will be put back."
L.PIN_RESTORED          = "Your map pin has been restored."
L.PIN_CLEARED           = "Map pin cleared."
L.PIN_YIELDED           = "You moved your map pin, so DWMK has let go of it."
L.PIN_INVALID_MAP       = "You can't place a map pin on this map."
L.PIN_RADIUS_HINT       = "Get anywhere inside the circle - you don't need the exact spot."

--------------------------------------------------------------------------------
-- Campaign picker
--------------------------------------------------------------------------------

L.PICKER_TITLE          = "Choose your campaign"
L.PICKER_SUBTITLE       = "How constrained do you want your riding to be? You can change this later."
L.PICKER_BEGIN          = "Begin Campaign"
L.PICKER_CURRENT        = "Current campaign"
L.PICKER_ACTIVE_TAG     = "ACTIVE"

-- The six rows every card answers, in order.
L.ROW_WHICH_MOUNTS      = "WHICH MOUNTS"
L.ROW_IF_BREAK          = "IF YOU BREAK IT"
L.ROW_LEAVING           = "LEAVING IT"
L.ROW_GETTING_BACK      = "GETTING IT BACK"
L.ROW_PICK_UP           = "PICK IT UP"
L.ROW_ALSO              = "ALSO"

--------------------------------------------------------------------------------
-- Config panel
--------------------------------------------------------------------------------

L.CFG_SECTION_CAMPAIGN  = "Campaign"
L.CFG_SECTION_RULES     = "Rules"
L.CFG_SECTION_RETRIEVAL = "Retrieval"
L.CFG_SECTION_NOTIFY    = "Notifications"
L.CFG_SECTION_MAP       = "Map & Tracking"
L.CFG_SECTION_ADVANCED  = "Advanced"

L.CFG_HOW_IT_WORKS_TITLE = "How enforcement works"
L.CFG_HOW_IT_WORKS_BODY  = [[An addon cannot stop the game from summoning a mount - that part of the game is closed to addons, and always has been.

So DWMK works two ways. The Ride key only ever casts a mount your campaign allows, which means an illegal one is never cast in the first place. If you mount some other way, DWMK removes it the moment it appears.

You will never be given a countdown and then yanked off a mount.]]

L.CFG_ENFORCEMENT       = "If you break a rule"
L.CFG_ENFORCEMENT_DESC  = "What happens when you ride something this campaign doesn't allow."

L.CFG_DISPATCH          = "Sending for a left-behind mount"
L.CFG_DISPATCH_AUTO     = "Automatically, when I walk away"
L.CFG_DISPATCH_CALL     = "Only when I call for it"
L.CFG_DISPATCH_NONE     = "Never - I'll go and get it myself"

L.CFG_PICKUP_RADIUS     = "Pick-up distance"
L.CFG_PICKUP_RADIUS_DESC = "How close you need to get to a left-behind mount to collect it yourself. Generous on purpose - you shouldn't have to land on an exact spot."

L.CFG_BELL              = "Ring a bell on delivery"
L.CFG_BELL_DESC         = "Plays a short sound when your mount is handed back. Off by default."

L.CFG_COMPANY           = "Retrieval company"
L.CFG_COMPANY_DESC      = "Who fetches your mounts. Cosmetic - it only changes the flavour of the messages."

L.CFG_AUTO_RESTORE_PIN  = "Put my map pin back afterwards"
L.CFG_AUTO_RESTORE_DESC = "The game only allows one map pin. When DWMK borrows it, this puts yours back when it's finished."

L.CFG_SHOW_TRACKER      = "Show the retrieval timer"
L.CFG_SHOW_TRACKER_DESC = "A small frame with a countdown while a mount is being brought to you. Hides itself when nothing is happening."

L.CFG_CHAT_FRAME        = "Send messages to"
L.CFG_CHAT_FRAME_DESC   = "Which chat window DWMK talks in."

--------------------------------------------------------------------------------
-- Retrieval companies (cosmetic)
--------------------------------------------------------------------------------

L.COMPANY_GOBLIN        = "Swiftwheel Freight & Salvage"
L.COMPANY_GNOME         = "Cogspring Mount Retrieval Cooperative"

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

L.SLASH_HEADER          = "Commands:"
L.SLASH_BARE            = "|cffffd100/dwmk|r - choose or review your campaign"
L.SLASH_CONFIG          = "|cffffd100/dwmk config|r - open settings"
L.SLASH_STATUS          = "|cffffd100/dwmk status|r - where your mounts are"
L.SLASH_CALL            = "|cffffd100/dwmk call|r - send for a left-behind mount"
L.SLASH_TRACK           = "|cffffd100/dwmk track|r - put a map pin on it"
L.SLASH_UNKNOWN         = "Unknown command. Type |cffffd100/dwmk help|r."

L.STATUS_CAMPAIGN       = "Campaign: |cffffd100%s|r"
L.STATUS_NO_CAMPAIGN    = "No campaign yet. Type |cffffd100/dwmk|r to choose one."
L.STATUS_NOTHING_LEFT   = "You haven't left any mounts behind."

L.CALL_NOTHING_TO_CALL  = "You have nothing to send for."
L.CALL_ALREADY_COMING   = "%s is already on the way."
L.CALL_NO_SERVICE       = "This campaign has no retrieval service. You'll have to go and get it."

--------------------------------------------------------------------------------
-- Migration / first run
--------------------------------------------------------------------------------

L.MIGRATED              = "Your old campaigns have been carried over. They're set to |cffffd100Custom|r so nothing about how they play has changed."
L.MIGRATED_GRACE        = "The old 'grace period' setting is gone - campaigns that used it now simply refuse the mount instead."
L.FIRST_RUN             = "Welcome. Pick a campaign to get started - |cffffd100Wayfarer|r is the gentle one."

--------------------------------------------------------------------------------
-- Time formatting
--------------------------------------------------------------------------------

L.TIME_SECONDS          = "%d seconds"
L.TIME_ONE_MINUTE       = "1 minute"
L.TIME_MINUTES          = "%d minutes"
L.TIME_MIN_SEC          = "%dm %02ds"
