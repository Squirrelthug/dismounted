local frame = CreateFrame("Frame")
local function TestPrint(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[Dismounted Test]|r " .. msg)
end

-- Event Registration
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Dismounted_Test" then
            TestPrint("Addon loaded and listening")
        end
    
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        if IsMounted() then
            TestPrint("Mount detected")


            -- enforcement test
            Dismount()
            TestPrint("Mount Interrupted (dismounted). ")
        end
    
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...

        if unit == "player" then
            TestPrint("Spell cast succeeded. SpellID: " .. tostring(spellID))
        end
    end
end)

