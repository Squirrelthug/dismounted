--[[ Offline harness: stubs enough of the WoW API to actually run DWMK's Core
     modules, then drives migration, preset rendering and a full retrieval cycle.
     Catches runtime bugs that a syntax check cannot. ]]

local ADDON_DIR = arg[1] or "D:/Projects/wow_addons/DWMK"

--==============================================================
-- Clock we control
--==============================================================
local NOW = 1000000
function time() return NOW end
local function advance(s) NOW = NOW + s end

--==============================================================
-- Frame stub: every method is a no-op that returns the frame
--==============================================================
local frameMT
local function NewFrame()
    local f = { __isFrame = true, __children = {} }
    return setmetatable(f, frameMT)
end

frameMT = {
    __index = function(t, k)
        -- Our own bookkeeping fields must stay nil-able, not become no-op funcs.
        if type(k) == "string" and k:sub(1, 2) == "__" then return nil end
        local fn = function(self, ...) return self end
        rawset(t, k, fn)
        return fn
    end,
}

-- Methods that must return something specific
local stubFrame
function stubFrame()
    local f = NewFrame()
    rawset(f, "CreateFontString", function() return stubFrame() end)
    rawset(f, "CreateTexture",    function() return stubFrame() end)
    rawset(f, "CreateMaskTexture",function() return stubFrame() end)
    rawset(f, "GetWidth",   function() return 400 end)
    rawset(f, "GetHeight",  function() return 100 end)
    rawset(f, "GetStringWidth",  function() return 60 end)
    rawset(f, "GetStringHeight", function() return 12 end)
    rawset(f, "IsShown",    function() return false end)
    rawset(f, "GetChecked", function() return false end)
    rawset(f, "GetPoint",   function() return "CENTER", nil, "CENTER", 0, 0 end)
    return f
end

local eventFrames = {}
function CreateFrame(kind, name, parent, template)
    local f = stubFrame()
    rawset(f, "RegisterEvent", function(self, e)
        if not self.__events then
            self.__events = {}
            eventFrames[#eventFrames+1] = self   -- register the frame once, not per event
        end
        self.__events[e] = true
        return self
    end)
    rawset(f, "SetScript", function(self, script, fn)
        self.__scripts = self.__scripts or {}
        self.__scripts[script] = fn
        return self
    end)
    rawset(f, "HookScript", function(self) return self end)
    if name then _G[name] = f end
    return f
end

local function fireEvent(event, ...)
    for _, f in ipairs(eventFrames) do
        if f.__events and f.__events[event] and f.__scripts and f.__scripts.OnEvent then
            f.__scripts.OnEvent(f, event, ...)
        end
    end
end

--==============================================================
-- Timers: collected, fired manually
--==============================================================
local tickers = {}
C_Timer = {
    NewTicker = function(interval, fn)
        local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
        tickers[#tickers+1] = t
        return t
    end,
    After = function(delay, fn) return fn end,  -- not auto-run
}
local function tickAll(n)
    for _ = 1, (n or 1) do
        for _, t in ipairs(tickers) do
            if not t.cancelled then t.fn() end
        end
    end
end

--==============================================================
-- Map / mounts
--==============================================================
local PLAYER = { mapID = 84, x = 0.50, y = 0.50 }

C_Map = {
    GetBestMapForUnit = function() return PLAYER.mapID end,
    GetPlayerMapPosition = function()
        return { GetXY = function() return PLAYER.x, PLAYER.y end }
    end,
    GetMapInfo = function(id) return { name = "TestZone" .. id } end,
    GetMapWorldSize = function() return 10000, 10000 end,  -- 1.0 == 10000 yards
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function() return true end,
    GetUserWaypoint = function() return nil end,
    ClearUserWaypoint = function() end,
}
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
UiMapPoint = { CreateFromCoordinates = function(...) return { ... } end }

local MOUNTS = {
    [111] = { id = 1, name = "Test Horse",  type = 230 },  -- ground
    [222] = { id = 2, name = "Test Drake",  type = 248 },  -- flying
    [333] = { id = 3, name = "Test Dragon", type = 424 },  -- skyriding
}
local byMountID = {}
for spell, m in pairs(MOUNTS) do byMountID[m.id] = { spell = spell, m = m } end

C_MountJournal = {
    GetMountFromSpell = function(spellID) return MOUNTS[spellID] and MOUNTS[spellID].id or nil end,
    GetMountInfoByID = function(mountID)
        local e = byMountID[mountID]; if not e then return nil end
        return e.m.name, e.spell, "icon", false, true
    end,
    GetMountInfoExtraByID = function(mountID)
        local e = byMountID[mountID]; if not e then return nil end
        return 0, "", "", false, e.m.type
    end,
}
C_UnitAuras = { GetAuraDataByIndex = function() return nil end }

--==============================================================
-- Misc globals
--==============================================================
local mounted = false
function IsMounted() return mounted end
function UnitOnTaxi() return false end
function UnitInVehicle() return false end
function IsFlying() return false end
function IsFalling() return false end
function IsFlyableArea() return true end
function IsResting() return false end
function InCombatLockdown() return false end
function Dismount() mounted = false end
function PlaySound() end
function geterrorhandler() return function(e) error(e, 0) end end
function tinsert(t, v) table.insert(t, v) end

UNKNOWN, SETTINGS = "Unknown", "Settings"
UIParent, UIErrorsFrame, GameTooltip = stubFrame(), stubFrame(), stubFrame()
GameTooltip_Hide = function() end
UISpecialFrames, SlashCmdList, SOUNDKIT = {}, {}, { ALARM_CLOCK_WARNING_3 = 1 }
WorldMapFrame = nil
Settings = {
    RegisterCanvasLayoutCategory = function() return { ID = "x" } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}

local CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) CHAT[#CHAT+1] = msg end }

--==============================================================
-- Load the addon
--==============================================================
local ns = {}
local FILES = {
    "Locale/enUS.lua", "Core/Init.lua", "Core/DB.lua", "Core/Mount.lua",
    "Core/Presets.lua", "Core/Rules.lua", "Core/RideButton.lua",
    "Core/Waypoint.lua", "Core/MapCircle.lua", "Core/Notify.lua",
    "Core/Retrieval.lua",
    "UI/Widgets.lua", "UI/CampaignPicker.lua", "UI/Config.lua", "UI/Tracker.lua",
    "Core/Commands.lua", "Core/Debug.lua",
}

for _, rel in ipairs(FILES) do
    local chunk, err = loadfile(ADDON_DIR .. "/" .. rel)
    if not chunk then error("load " .. rel .. ": " .. tostring(err)) end
    chunk("DWMK", ns)
end

--==============================================================
-- Assertions
--==============================================================
local pass, fail = 0, 0
local function check(label, cond, detail)
    if cond then pass = pass + 1; print("  ok   " .. label)
    else fail = fail + 1; print("  FAIL " .. label .. (detail and ("  -> " .. tostring(detail)) or "")) end
end
local function lastChat() return CHAT[#CHAT] or "" end
local function chatSince(n)
    local out = {}
    for i = n + 1, #CHAT do out[#out+1] = CHAT[i] end
    return table.concat(out, " | ")
end

--==============================================================
print("\n== 1. v1 migration ==")
--==============================================================
DismountedDB = {
    version = 1,
    campaigns = {
        old_one = {
            name = "My Old Run",
            settings = { enforcementLevel = 2, anchorRadius = 300 },  -- grace tier
            mounts = { ground = 111, flying = 222 },
            anchors = { [111] = { 84, 0.2, 0.3, 900000 } },
        },
        off_one = {
            name = "Tracking Only",
            settings = { enforcementLevel = 0, anchorRadius = 30 },
            mounts = {}, anchors = {},
        },
    },
}
DismountedCharDB = { activeCampaign = "old_one" }

fireEvent("ADDON_LOADED", "DWMK")

check("migrated campaign exists", DWMKDB.campaigns.old_one ~= nil)
check("grace tier (2) collapsed to Refuse",
      DWMKDB.campaigns.old_one.rules.enforcement == ns.ENFORCE.REFUSE,
      DWMKDB.campaigns.old_one.rules.enforcement)
check("level 0 stayed Off",
      DWMKDB.campaigns.off_one.rules.enforcement == ns.ENFORCE.OFF)
check("mounts preserved", DWMKDB.campaigns.old_one.mounts.ground == 111)
check("wide anchorRadius carried into pickupRadius",
      DWMKDB.campaigns.old_one.rules.pickupRadius == 300,
      DWMKDB.campaigns.old_one.rules.pickupRadius)
check("landed on Custom preset", DWMKDB.campaigns.old_one.preset == "custom")
check("active campaign carried over", DWMKCharDB.activeCampaign == "old_one")
check("v1 anchors moved to character", DWMKCharDB.anchors[111] ~= nil)
check("v1 tables left intact for rollback", DismountedDB.campaigns.old_one ~= nil)
check("migration announced", lastChat():find("carried over") ~= nil or chatSince(0):find("carried over") ~= nil)

--==============================================================
print("\n== 2. all 8 presets render ==")
--==============================================================
for _, preset in ipairs(ns.Presets.Ordered()) do
    local c = ns.DB.NewCampaign(preset.key, preset.name)
    local rows = ns.Presets.CardRows(c)
    local chips = ns.Presets.Chips(c)
    local ok = #rows == 6
    for _, r in ipairs(rows) do
        if type(r.text) ~= "string" or r.text == "" then ok = false end
        if r.text:find("{") then ok = false end
    end
    check(("%-11s 6 rows, %d chips, colour %s"):format(preset.key, #chips,
          ns.Presets.SeverityColor(c):sub(3,8)), ok and #chips > 0)
end

--==============================================================
print("\n== 3. card copy matches the constants ==")
--==============================================================
local wf = ns.DB.NewCampaign("wayfarer", "W")
local rows = ns.Presets.CardRows(wf)
local gettingBack
for _, r in ipairs(rows) do if r.label == ns.L.ROW_GETTING_BACK then gettingBack = r.text end end
check("Timer A appears as '1 minute'", gettingBack:find("1 minute") ~= nil, gettingBack)
check("Timer B close appears as '30 seconds'", gettingBack:find("30 seconds") ~= nil, gettingBack)
check("Timer B far appears as '3 minutes'", gettingBack:find("3 minutes") ~= nil, gettingBack)
check("FormatDuration 90s", ns.FormatDuration(90) == "1m 30s", ns.FormatDuration(90))

--==============================================================
print("\n== 4. mount classification ==")
--==============================================================
check("ground mount is ground", ns.Mount.Classify(1) == ns.MOUNTCLASS.GROUND)
check("flyer can fly", ns.Mount.CanFly(2))
check("skyriding counts as flight", ns.Mount.CanFly(3))
check("ground mount cannot fly", not ns.Mount.CanFly(1))
check("unknown mount treated as flight-capable", ns.Mount.CanFly(999))

--==============================================================
print("\n== 5. retrieval: leave, dispatch, deliver ==")
--==============================================================
DWMKDB.campaigns.test = ns.DB.NewCampaign("stablehand", "Test")
DWMKDB.campaigns.test.mounts.ground = 111
ns.DB.SetActiveCampaign("test")

-- Mount, then dismount, at the origin.
PLAYER.x, PLAYER.y = 0.50, 0.50
mounted = true
fireEvent("UNIT_SPELLCAST_SENT", "player", nil, nil, 111)
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mounted = false
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

local r = ns.DB.GetRetrieval()
check("state is LEFT after dismount", r.state == ns.STATE.LEFT, r.state)
check("anchor recorded", r.mapID == 84 and r.spellID == 111)

-- Standing right there: must NOT self-recover or announce.
local before = #CHAT
tickAll(6)
check("standing next to it does not announce or recover",
      r.state == ns.STATE.LEFT and not r.leftAnnounced and #CHAT == before,
      chatSince(before))
check("mount is still rideable while at hand", ns.Retrieval.IsAtHand())

-- Walk 500 yards away (0.05 * 10000).
before = #CHAT
PLAYER.x = 0.55
tickAll(6)
check("walking away announces the mount as left", r.leftAnnounced == true)
check("auto-dispatch started Timer A", r.state == ns.STATE.DISPATCHED, r.state)
check("dispatch was narrated", chatSince(before):find("sets out") ~= nil, chatSince(before))
check("mount now refused as away", not ns.Retrieval.IsAtHand())

local allowed, reason = ns.Rules.Evaluate(ns.Mount.InfoFromSpell(111))
check("Rules refuses the absent mount", allowed == false, reason)
check("refusal names the zone", reason and reason:find("TestZone84") ~= nil, reason)

-- Timer A elapses. Player is 500 yd away -> close.
before = #CHAT
advance(ns.TIMER_A + 1)
tickAll(1)
check("Timer A -> CARRYING", r.state == ns.STATE.CARRYING, r.state)
check("Timer B locked to close (30s)", r.deliverySeconds == ns.TIMER_B_CLOSE, r.deliverySeconds)
check("pickup narrated", chatSince(before):find("in hand") ~= nil, chatSince(before))

-- Moving away now must NOT change the locked timer.
PLAYER.x = 0.95
tickAll(1)
check("Timer B stays locked after the player moves",
      r.deliverySeconds == ns.TIMER_B_CLOSE, r.deliverySeconds)
check("self-recovery no longer possible once carrying", not ns.Retrieval.IsAtHand())

before = #CHAT
advance(ns.TIMER_B_CLOSE + 1)
tickAll(1)
check("delivered -> IDLE", r.state == ns.STATE.IDLE, r.state)
check("delivery narrated", chatSince(before):find("reins") ~= nil, chatSince(before))

--==============================================================
print("\n== 6. far tier ==")
--==============================================================
PLAYER.x, PLAYER.y = 0.50, 0.50
mounted = true
fireEvent("UNIT_SPELLCAST_SENT", "player", nil, nil, 111)
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mounted = false
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

PLAYER.x = 0.80              -- 3000 yards, well beyond CLOSE_DISTANCE
tickAll(6)
advance(ns.TIMER_A + 1)
tickAll(1)
check("beyond 1000 yd locks the far timer",
      r.deliverySeconds == ns.TIMER_B_FAR, r.deliverySeconds)

-- Different map is simply far, with no distance maths at all.
ns.Debug.Command("clear")
mounted = true
fireEvent("UNIT_SPELLCAST_SENT", "player", nil, nil, 111)
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mounted = false
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
PLAYER.mapID = 99            -- different map
tickAll(6)
check("different map counts as away", r.leftAnnounced == true)
advance(ns.TIMER_A + 1)
tickAll(1)
check("different map -> far timer", r.deliverySeconds == ns.TIMER_B_FAR, r.deliverySeconds)
PLAYER.mapID = 84

--==============================================================
print("\n== 7. self-recovery ==")
--==============================================================
ns.Debug.Command("clear")
PLAYER.x, PLAYER.y = 0.50, 0.50
mounted = true
fireEvent("UNIT_SPELLCAST_SENT", "player", nil, nil, 111)
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mounted = false
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

PLAYER.x = 0.60              -- 1000 yd: gone
tickAll(6)
check("dispatched", r.state == ns.STATE.DISPATCHED, r.state)

before = #CHAT
PLAYER.x = 0.5300            -- 300 yd: inside 2x the 200 yd radius
tickAll(1)
check("approach announced before anything changes",
      chatSince(before):find("see your") ~= nil, chatSince(before))

before = #CHAT
PLAYER.x = 0.5100            -- 100 yd: inside the radius
tickAll(1)
check("self-recovered -> IDLE", r.state == ns.STATE.IDLE, r.state)
check("recovery names the reason", chatSince(before):find("reached your") ~= nil, chatSince(before))
check("cancelled service narrated", chatSince(before):find("turns the cart") ~= nil, chatSince(before))

--==============================================================
print("\n== 8. offline time ==")
--==============================================================
ns.Debug.Command("clear")
PLAYER.x, PLAYER.y = 0.50, 0.50
mounted = true
fireEvent("UNIT_SPELLCAST_SENT", "player", nil, nil, 111)
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mounted = false
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
PLAYER.x = 0.55
tickAll(6)
check("dispatched before logout", r.state == ns.STATE.DISPATCHED)

advance(3600)                -- an hour offline
tickAll(2)
check("both timers resolved on return", r.state == ns.STATE.IDLE, r.state)

--==============================================================
print("\n== 9. ground-only refuses flyers ==")
--==============================================================
DWMKDB.campaigns.nomad = ns.DB.NewCampaign("nomad", "Nomad")
DWMKDB.campaigns.nomad.mounts.ground = 111
ns.DB.SetActiveCampaign("nomad")
ns.Debug.Command("clear")

local okG = ns.Rules.Evaluate(ns.Mount.InfoFromSpell(111))
local okF, whyF = ns.Rules.Evaluate(ns.Mount.InfoFromSpell(222))
local okS = ns.Rules.Evaluate(ns.Mount.InfoFromSpell(333))
check("ground mount allowed under Nomad", okG == true)
check("flyer refused under Nomad", okF == false, whyF)
check("skyriding refused under Nomad", okS == false)
check("Ride button picks the ground mount", ns.RideButton.ChooseMount() == 111)

--==============================================================
print("\n== 10. bonded ==")
--==============================================================
DWMKDB.campaigns.bond = ns.DB.NewCampaign("bonded", "Bonded")
ns.DB.SetActiveCampaign("bond")
local okNone, whyNone = ns.Rules.Evaluate(ns.Mount.InfoFromSpell(111))
check("no bond chosen -> refused", okNone == false, whyNone)
local spell, why = ns.RideButton.ChooseMount()
check("Ride button casts nothing without a bond", spell == nil, why)

DWMKDB.campaigns.bond.mounts.bonded = 111
DWMKDB.campaigns.bond.mounts.bondedName = "Old Faithful"
check("bonded mount allowed", ns.Rules.Evaluate(ns.Mount.InfoFromSpell(111)) == true)
local okOther, whyOther = ns.Rules.Evaluate(ns.Mount.InfoFromSpell(222))
check("every other mount refused", okOther == false)
check("refusal uses the given name", whyOther:find("Old Faithful") ~= nil, whyOther)

--==============================================================
print("\n== 11. Caravan has no service ==")
--==============================================================
DWMKDB.campaigns.car = ns.DB.NewCampaign("caravan", "Caravan")
DWMKDB.campaigns.car.mounts.ground = 111
ns.DB.SetActiveCampaign("car")
ns.Debug.Command("clear")

mounted = true
fireEvent("UNIT_SPELLCAST_SENT", "player", nil, nil, 111)
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mounted = false
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
PLAYER.x = 0.60
before = #CHAT
tickAll(6)
check("Caravan never dispatches", r.state == ns.STATE.LEFT, r.state)
check("told no one is coming", chatSince(before):find("No one is coming") ~= nil, chatSince(before))
check("calling is refused", ns.Retrieval.Call() == false)

--==============================================================
print("\n== 12. enforcement Off ==")
--==============================================================
DWMKDB.campaigns.off = ns.DB.NewCampaign("custom", "Off")
DWMKDB.campaigns.off.rules.enforcement = ns.ENFORCE.OFF
DWMKDB.campaigns.off.mounts.ground = 111
ns.DB.SetActiveCampaign("off")
check("Off allows an unassigned mount", ns.Rules.Evaluate(ns.Mount.InfoFromSpell(222)) == true)

--==============================================================
print("\n== 13. UI renders for every preset ==")
--==============================================================
local okPicker = pcall(function() ns.Picker.Open(); ns.Picker.Refresh() end)
check("picker opens and renders all cards", okPicker)

for _, preset in ipairs(ns.Presets.Ordered()) do
    local id = "ui_" .. preset.key
    DWMKDB.campaigns[id] = ns.DB.NewCampaign(preset.key, preset.name)
    ns.DB.SetActiveCampaign(id)

    local okAll, err = pcall(function()
        ns.Config.Refresh()
        ns.Tracker.Update()
        ns.Picker.Refresh()
        ns.RideButton.Update()
    end)
    check("UI refresh under " .. preset.key, okAll, err)
end

--==============================================================
print("\n== 14. tracker across every retrieval state ==")
--==============================================================
DWMKDB.campaigns.tk = ns.DB.NewCampaign("ironhoof", "Ironhoof")
DWMKDB.campaigns.tk.mounts.ground = 111
ns.DB.SetActiveCampaign("tk")
ns.Debug.Command("clear")
PLAYER.mapID, PLAYER.x, PLAYER.y = 84, 0.50, 0.50

mounted = true
fireEvent("UNIT_SPELLCAST_SENT", "player", nil, nil, 111)
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mounted = false
fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
PLAYER.x = 0.60
tickAll(6)

check("Ironhoof waits to be called", r.state == ns.STATE.LEFT, r.state)
check("tracker renders while awaiting call", pcall(ns.Tracker.Update))
check("manual call dispatches", ns.Retrieval.Call() == true)
check("tracker renders while dispatched", pcall(ns.Tracker.Update))
advance(ns.TIMER_A + 1); tickAll(1)
check("tracker renders while carrying", pcall(ns.Tracker.Update))
advance(ns.TIMER_B_FAR + 1); tickAll(1)
check("returned to idle", r.state == ns.STATE.IDLE, r.state)

--==============================================================
print("\n== 15. debug harness commands ==")
--==============================================================
for _, cmd in ipairs({ "leave 800", "state", "ff 30", "state", "offline 600", "clear", "bogus" }) do
    local okCmd, err = pcall(ns.Debug.Command, cmd)
    check("/dwmk sim " .. cmd, okCmd, err)
end

--==============================================================
print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
