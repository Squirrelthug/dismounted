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
            -- Figure out which mount
            local mountID, spellID = nil, nil
            
            for i = 1, 40 do
                local name, _, _, _, _, _, _, _, _, auraSpellID = UnitAura("player", i, "HELPFUL")
                if not name then break end
                
                local foundMountID = C_MountJournal.GetMountFromSpell(auraSpellID)
                if foundMountID then
                    mountID = foundMountID
                    spellID = auraSpellID
                    TestPrint("Mounted: " .. name .. " (Mount ID: " .. mountID .. ", Spell ID: " .. spellID .. ")")
                    break
                end
            end
            
            if not mountID then
                TestPrint("ERROR: Mounted but couldn't detect which mount!")
            end
            
            -- Still dismount for testing
            Dismount()
        end
    end

