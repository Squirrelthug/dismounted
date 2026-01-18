local ADDON_NAME, Addon = ...
local EventRouter = {}

Addon.EventRouter = EventRouter

local frame = CreateFrame("Frame")

local function EmitTrigger(trigger)
    local safeTrigger = CopyTable(trigger)

    Addon.CorePipeline:Evaluate(safeTrigger)
end

local function MakeTrigger(triggerType, data)
    return {
        type = triggerType,
        unit = data and data.unit or "player",
        reactive = data and data.reactive or false,
        rawHint = data,
    }
end

frame:RegisterEvent("ADDON_LOADED")

frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")

frame:RegisterEvent("PLAYER_STARTED_MOVING")
frame:RegisterEvent("PLAYER_STOPPED_MOVING")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            EmitTrigger(MakeTrigger("SYSTEM_INITIALIZE"))
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...

        if unit ~= "player" then
            return
        end

        EmitTrigger(MakeTrigger("MOUNT_ATTEMPT", {
            unit = "player",
            spellID = spellID,
            reactive = false,
        }))
        return
    end

    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        EmitTrigger(MakeTrigger("MOUNT_STATE_CHANGED", {
            reactive = true,
        }))
        return
    end

    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then

        EmitTrigger(MakeTrigger("LOCATION_CHANGED", {
            reactive = true,
            event = event,
        }))
        return
    end

    if event == "PLAYER_STARTED_MOVING" then
        EmitTrigger(MakeTrigger("MOVEMENT_STARTED", {
            reactive = true,
        }))
        return
    end

    if event == "PLAYER_STOPPED_MOVING" then
        EmitTrigger(MakeTrigger("MOVEMENT_STOPPED", {
            reactive = true,
        }))
        return
    end

    if event == "PLAYER_CONTROL_LOST" then
        EmitTrigger(MakeTrigger("CONTROL_LOST", {
            reactive = true,
        }))
        return
    end

    if event == "PLAYER_CONTROL_GAINED" then
        EmitTrigger(MakeTrigger("CONTROL_GAINED", {
            reactive = true,
        }))
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        EmitTrigger(MakeTrigger("ENTERED_COMBAT", {
            reactive = true,
        }))
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        EmitTrigger(MakeTrigger("LEFT_COMBAT", {
            reactive = true,
        }))
        return
    end
end)