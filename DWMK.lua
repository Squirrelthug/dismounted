--[[
    Dude Where's My K'arroc - Campaign-based mount persistence and immersion
    Author: [Your Name]
    Version: 0.1.0
]]

local ADDON_NAME = ...
local ADDON_VERSION = "0.1.0"

-- Create main frame
local frame = CreateFrame("Frame")

-- Constants
local ENFORCEMENT_LEVELS = {
    [0] = "Off",
    [1] = "Permissive",
    [2] = "Balanced", 
    [3] = "Strict"
}

local MIN_ANCHOR_RADIUS = 10
local MAX_ANCHOR_RADIUS = 200
local DEFAULT_ANCHOR_RADIUS = 30

-- State tracking
local lastMountSpellID = nil  -- Track spell from UNIT_SPELLCAST_SUCCEEDED
local enforcementDismountInProgress = false  -- Flag to prevent anchor recording on enforcement

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

local function Print(msg)
    local tag = 
    "|cffffa500D|r" ..
    "|cffff0000W|r" ..
    "|cff00ff00M|r" ..
    "|cff0000ffK|r"
    DEFAULT_CHAT_FRAME:AddMessage("[" .. tag .. "]" .. msg)
end

local function PrintWarning(msg)
    UIErrorsFrame:AddMessage(msg, 1.0, 0.8, 0.0, 1.0, 3)
end


--------------------------------------------------------------------------------
-- Database Management
--------------------------------------------------------------------------------

local function CreateDefaultCampaign()
    return {
        name = "Default Campaign",
        created = time(),
        lastUsed = time(),
        
        settings = {
            enforcementLevel = 1,  -- Permissive by default
            anchorRadius = DEFAULT_ANCHOR_RADIUS,
        },
        
        mounts = {
            ground = nil,
            flying = nil,
        },
        
        anchors = {}
    }
end

local function InitializeDatabase()
    -- Create account-wide database
    if not DismountedDB then
        DismountedDB = {
            version = 1,
            campaigns = {}
        }
        Print("Database initialized")
    end
    
    -- Create character database
    if not DismountedCharDB then
        DismountedCharDB = {
            activeCampaign = nil
        }
    end
    
    -- Ensure default campaign exists
    if not DismountedDB.campaigns["default"] then
        DismountedDB.campaigns["default"] = CreateDefaultCampaign()
        Print("Default campaign created")
    end
    
    -- Ensure character has valid active campaign
    if not DismountedCharDB.activeCampaign then
        DismountedCharDB.activeCampaign = "default"
    end
    
    -- Validate active campaign exists
    if not DismountedDB.campaigns[DismountedCharDB.activeCampaign] then
        Print("Warning: Active campaign not found, switching to default")
        DismountedCharDB.activeCampaign = "default"
    end
end

local function GetActiveCampaign()
    if not DismountedCharDB or not DismountedCharDB.activeCampaign then
        return nil
    end
    
    return DismountedDB.campaigns[DismountedCharDB.activeCampaign]
end

local function GetActiveCampaignID()
    return DismountedCharDB and DismountedCharDB.activeCampaign
end

--------------------------------------------------------------------------------
-- Position and Map Functions
--------------------------------------------------------------------------------

local function GetCurrentPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return nil, nil, nil
    end
    
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil, nil, nil
    end
    
    local x, y = position:GetXY()
    return mapID, x, y
end

local function GetMapInfo(mapID)
    if not mapID then
        return "Unknown"
    end
    
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo then
        return mapInfo.name
    end
    
    return "Map " .. mapID
end

local function FormatCoordinates(x, y)
    if not x or not y then
        return "Unknown"
    end
    
    return string.format("%.1f, %.1f", x * 100, y * 100)
end

local function SetTomTomWaypoint(mapID, x, y, mountName)
    -- Check if TomTom is loaded
    if not TomTom then
        return false
    end
    
    -- TomTom API: AddWaypoint(mapID, x, y, options)
    if TomTom.AddWaypoint then
        local waypointInfo = {
            title = "Dismounted: " .. (mountName or "Mount Location"),
            persistent = false,  -- Don't save permanently
            minimap = true,
            world = true
        }
        
        TomTom:AddWaypoint(mapID, x, y, waypointInfo)
        Print("TomTom waypoint set for your mount location")
        return true
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Mount Detection
--------------------------------------------------------------------------------

local function GetCurrentMountInfo()
    if not IsMounted() then
        return nil
    end
    
    -- Check for taxi/flight path first
    if UnitOnTaxi("player") then
        return nil
    end
    
    -- Use new C_UnitAuras API (Midnight pre-patch compatible)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            
            if not auraData then
                break
            end
            
            if C_MountJournal and C_MountJournal.GetMountFromSpell then
                local mountID = C_MountJournal.GetMountFromSpell(auraData.spellId)
                
                if mountID then
                    -- Get full mount details
                    local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
                    
                    return {
                        mountID = mountID,
                        spellID = auraData.spellId,
                        name = name or auraData.name,
                        icon = icon
                    }
                end
            end
        end
    end
    
    -- FALLBACK: Use the spell ID we tracked from UNIT_SPELLCAST_SUCCEEDED
    if lastMountSpellID and C_MountJournal then
        local mountID = C_MountJournal.GetMountFromSpell(lastMountSpellID)
        if mountID then
            local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
            return {
                mountID = mountID,
                spellID = lastMountSpellID,
                name = name,
                icon = icon
            }
        end
    end
    
    return nil
end

--------------------------------------------------------------------------------
-- Enforcement Logic
--------------------------------------------------------------------------------

local function HandleViolation(reason, campaign, mountInfo)
    
    local level = campaign.settings.enforcementLevel or 1
    
    
    if level == 0 then
        -- Off - do nothing
        return
        
    elseif level == 1 then
        -- Permissive - warn only (no dismount, no flag)
        
    elseif level == 2 then
        -- Balanced - warn then dismount after 3 seconds
        PrintWarning("Warning: " .. reason)
        Print("Grace period: 3 seconds to dismount voluntarily...")
        
        C_Timer.After(3, function()
            if IsMounted() then
                enforcementDismountInProgress = true  -- SET FLAG BEFORE DISMOUNT
                Dismount()
                Print("Dismounted after grace period")
            else
            end
        end)
        
    elseif level == 3 then
        -- Strict - immediate dismount
        enforcementDismountInProgress = true  -- SET FLAG BEFORE DISMOUNT
        Dismount()
        PrintWarning("Dismounted: " .. reason)
    end
end

local function CheckMountRestrictions(campaign, mountInfo)
    
    -- Check 1: Is this mount assigned to the campaign?
    local isAssigned = false
    local assignedSlot = nil
    
    
    for slotName, slotSpellID in pairs(campaign.mounts) do
        if slotSpellID == mountInfo.spellID then
            isAssigned = true
            assignedSlot = slotName
            break
        end
    end
    
    
    if not isAssigned then
        -- Check if ANY mounts are assigned
        local hasAnyMounts = false
        for _, spellID in pairs(campaign.mounts) do
            if spellID then
                hasAnyMounts = true
                break
            end
        end
        
        
        if not hasAnyMounts then
            -- No mounts assigned yet - inform but allow
            Print("No mounts assigned to campaign '" .. campaign.name .. "' yet.")
            Print("This mount will be allowed until you configure the campaign.")
            return true
        else
            -- Mounts ARE assigned, but this isn't one of them
            HandleViolation(
                "'" .. mountInfo.name .. "' is not assigned to campaign '" .. campaign.name .. "'",
                campaign,
                mountInfo
            )
            return false
        end
    end
    
    
    -- Check 2: Does this mount have an anchor?
    local anchor = campaign.anchors[mountInfo.spellID]
    
    
    if not anchor then
        -- First use of this mount in this campaign
        Print("First use of '" .. mountInfo.name .. "' in this campaign.")
        Print("Anchor will be set when you dismount.")
        return true
    end
    
    
    -- Check 3: Are we within range of the anchor?
    local currentMapID, currentX, currentY = GetCurrentPosition()
    
    
    if not currentMapID then
        Print("Warning: Could not determine your current position")
        return true  -- Allow if we can't check
    end
    
    local anchorMapID = anchor[1]
    local anchorX = anchor[2]
    local anchorY = anchor[3]
    
    
    -- Different maps = not within range
    if currentMapID ~= anchorMapID then
        local currentMapName = GetMapInfo(currentMapID)
        local anchorMapName = GetMapInfo(anchorMapID)
        
        Print("Your '" .. mountInfo.name .. "' is in a different location:")
        Print("  Current: " .. currentMapName)
        Print("  Mount at: " .. anchorMapName .. " (" .. FormatCoordinates(anchorX, anchorY) .. ")")
        
        -- Set TomTom waypoint (will work even on different map)
        if TomTom then
            SetTomTomWaypoint(anchorMapID, anchorX, anchorY, mountInfo.name)
        else
            Print("  (Install TomTom addon for automatic waypoint)")
        end
        
        HandleViolation(
            "Mount is in " .. anchorMapName .. ", you are in " .. currentMapName,
            campaign,
            mountInfo
        )
        return false
    end
    
    
    -- Same map - calculate distance using actual map dimensions
    local mapWidth, mapHeight = C_Map.GetMapWorldSize(currentMapID)
    
    
    if not mapWidth or not mapHeight then
        Print("Warning: Could not determine map size, allowing mount")
        return true
    end
    
    -- Calculate actual distance in yards
    local dx = (currentX - anchorX) * mapWidth
    local dy = (currentY - anchorY) * mapHeight
    local distance = math.sqrt(dx * dx + dy * dy)
    
    
    local radius = campaign.settings.anchorRadius or DEFAULT_ANCHOR_RADIUS
    
    
    if distance > radius then
        local mapName = GetMapInfo(currentMapID)
        
        Print("Your '" .. mountInfo.name .. "' is too far away:")
        Print("  Distance: " .. string.format("%.0f", distance) .. " yards (limit: " .. radius .. " yards)")
        Print("  Location: " .. mapName .. " (" .. FormatCoordinates(anchorX, anchorY) .. ")")
        
        -- Automatically set TomTom waypoint if available
        if TomTom then
            SetTomTomWaypoint(anchorMapID, anchorX, anchorY, mountInfo.name)
        else
            Print("  (Install TomTom addon for automatic waypoint)")
        end
        
        HandleViolation(
            string.format("Mount is %.0f yards away (limit: %d yards)", distance, radius),
            campaign,
            mountInfo
        )
        return false
    end
    
    -- All checks passed
    return true
end

--------------------------------------------------------------------------------
-- Mount Event Handlers
--------------------------------------------------------------------------------

local function OnPlayerMounted()
    
    -- Get active campaign
    local campaign = GetActiveCampaign()
    if not campaign then
        return
    end
    
    
    -- Detect which mount
    local mountInfo = GetCurrentMountInfo()
    if not mountInfo then
        return
    end
    
    
    -- Check restrictions
    CheckMountRestrictions(campaign, mountInfo)
    
    -- Update campaign last used time
    campaign.lastUsed = time()
end

local function OnPlayerDismounted()
    
    -- Check if this was an enforcement dismount
    if enforcementDismountInProgress then
        enforcementDismountInProgress = false  -- Clear flag
        lastMountSpellID = nil  -- Clear tracked mount
        return  -- Exit early, don't record anchor
    end
    
    
    -- Get active campaign
    local campaign = GetActiveCampaign()
    if not campaign then
        return
    end
    
    
    -- Try to detect which mount we were on
    -- Use lastMountSpellID from the cast event
    if not lastMountSpellID then
        return
    end
    
    
    local mountID = C_MountJournal.GetMountFromSpell(lastMountSpellID)
    if not mountID then
        return
    end
    
    
    -- Get mount name for messaging
    local mountName = C_MountJournal.GetMountInfoByID(mountID)
    
    
    -- Get current position
    local mapID, x, y = GetCurrentPosition()
    
    
    if not mapID or not x or not y then
        Print("Warning: Could not record dismount location")
        return
    end
    
    -- Record anchor
    campaign.anchors[lastMountSpellID] = {mapID, x, y, time()}
    
    
    local mapName = GetMapInfo(mapID)
    local coords = FormatCoordinates(x, y)
    
    Print("Mount anchored: '" .. (mountName or "Unknown") .. "' at " .. mapName .. " (" .. coords .. ")")
    
    -- Clear the tracked spell
    lastMountSpellID = nil
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            InitializeDatabase()
            
            local campaign = GetActiveCampaign()
            if campaign then
                local levelName = ENFORCEMENT_LEVELS[campaign.settings.enforcementLevel] or "Unknown"
                Print("v" .. ADDON_VERSION .. " loaded")
                Print("Active campaign: " .. campaign.name .. " (Level: " .. levelName .. ")")
            else
                Print("v" .. ADDON_VERSION .. " loaded (no active campaign)")
            end
        end
    
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        
        if unit == "player" then
            -- Check if this is a mount spell
            if C_MountJournal and C_MountJournal.GetMountFromSpell then
                local mountID = C_MountJournal.GetMountFromSpell(spellID)
                if mountID then
                    -- Track this for dismount event
                    lastMountSpellID = spellID
                end
            end
        end
    
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        
        -- Ignore taxis/flight paths
        if UnitOnTaxi("player") then
            return
        end
        
        if IsMounted() then
            OnPlayerMounted()
        else
            OnPlayerDismounted()
        end
    
    elseif event == "PLAYER_LOGOUT" then
        
        -- If mounted on logout, record the position
        if IsMounted() then
            
            local campaign = GetActiveCampaign()
            if campaign and lastMountSpellID then
                local mapID, x, y = GetCurrentPosition()
                if mapID and x and y then
                    campaign.anchors[lastMountSpellID] = {mapID, x, y, time()}
                end
            end
        end
    end
end)

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("PLAYER_LOGOUT")

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------

SLASH_DWMK1 = "/dwmk"
SLASH_DWMK2 = "/dude"

SlashCmdList["DWMK"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "" or msg == "help" then
        Print("Commands:")
        Print("  /dwmk status - Show current campaign status")
        Print("  /dwmk level <0-3> - Set enforcement level")
        Print("  /dwmk radius <10-200> - Set anchor radius in yards")
        Print("  /dwmk config - Open settings panel")
        
    elseif msg == "status" then
        local campaign = GetActiveCampaign()
        if not campaign then
            Print("No active campaign")
            return
        end
        
        local levelName = ENFORCEMENT_LEVELS[campaign.settings.enforcementLevel] or "Unknown"
        
        Print("Campaign: " .. campaign.name)
        Print("  Enforcement: " .. levelName .. " (Level " .. campaign.settings.enforcementLevel .. ")")
        Print("  Anchor radius: " .. campaign.settings.anchorRadius .. " yards")
        Print("  Ground mount: " .. (campaign.mounts.ground or "Not assigned"))
        Print("  Flying mount: " .. (campaign.mounts.flying or "Not assigned"))
        
        local anchorCount = 0
        for _ in pairs(campaign.anchors) do
            anchorCount = anchorCount + 1
        end
        Print("  Anchored mounts: " .. anchorCount)
        
    elseif msg:match("^level%s+(%d+)$") then
        local level = tonumber(msg:match("^level%s+(%d+)$"))
        
        if level < 0 or level > 3 then
            Print("Error: Level must be 0-3")
            Print("  0 = Off, 1 = Permissive, 2 = Balanced, 3 = Strict")
            return
        end
        
        local campaign = GetActiveCampaign()
        if not campaign then
            Print("No active campaign")
            return
        end
        
        campaign.settings.enforcementLevel = level
        local levelName = ENFORCEMENT_LEVELS[level]
        Print("Enforcement level set to: " .. levelName)
        
    elseif msg:match("^radius%s+(%d+)$") then
        local radius = tonumber(msg:match("^radius%s+(%d+)$"))
        
        if radius < MIN_ANCHOR_RADIUS or radius > MAX_ANCHOR_RADIUS then
            Print("Error: Radius must be " .. MIN_ANCHOR_RADIUS .. "-" .. MAX_ANCHOR_RADIUS .. " yards")
            return
        end
        
        local campaign = GetActiveCampaign()
        if not campaign then
            Print("No active campaign")
            return
        end
        
        campaign.settings.anchorRadius = radius
        Print("Anchor radius set to: " .. radius .. " yards")
        
    else
        Print("Unknown command. Type /dm help for commands.")
    end
end

Print("Type /dwmk help for commands")