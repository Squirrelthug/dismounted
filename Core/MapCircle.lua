--[[
    Core/MapCircle.lua - drawing the pick-up radius on the world map.

    This exists to solve one specific confusion. A left-behind mount is collected
    by getting anywhere within a couple of hundred yards of it, which means the
    map pin disappears while you are still visibly short of it. Without something
    showing the radius, that reads as the pin breaking.

    So the radius is drawn. The target is an area, and it looks like an area.

    Two other things guard the same confusion, in Core/Notify.lua: a message when
    you come within twice the radius, and a recovery message that always names
    the reason the pin went away.

    There is no circular texture guaranteed to exist in the game files, so the
    circle is a flat colour with a circular alpha mask over it. The mask texture
    used here ships with the character frame and has been present for years.
]]

local ADDON, ns = ...

local MapCircle = {}
ns.MapCircle = MapCircle

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local fill, ring, current, ticker

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

local function GetMapCanvas()
    if not WorldMapFrame then return nil end
    local container = WorldMapFrame.ScrollContainer
    return container and container.Child or nil
end

local function Build()
    if fill then return true end

    local canvas = GetMapCanvas()
    if not canvas then return false end

    -- Outer ring, drawn slightly larger and more opaque so the edge of the area
    -- is legible against busy map art.
    ring = canvas:CreateTexture(nil, "OVERLAY", nil, 2)
    ring:SetColorTexture(1, 0.82, 0, 0.5)
    local ringMask = canvas:CreateMaskTexture()
    ringMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ringMask:SetAllPoints(ring)
    ring:AddMaskTexture(ringMask)

    fill = canvas:CreateTexture(nil, "OVERLAY", nil, 3)
    fill:SetColorTexture(1, 0.82, 0, 0.16)
    local fillMask = canvas:CreateMaskTexture()
    fillMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    fillMask:SetAllPoints(fill)
    fill:AddMaskTexture(fillMask)

    ring:Hide()
    fill:Hide()
    return true
end

--------------------------------------------------------------------------------
-- Positioning
--------------------------------------------------------------------------------

local function Refresh()
    if not current or not fill then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local canvas = GetMapCanvas()
    if not canvas then return end

    -- Only draw on the map the mount is actually on.
    local shownMapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or nil
    if shownMapID ~= current.mapID then
        ring:Hide()
        fill:Hide()
        return
    end

    local mapWidthYards = C_Map.GetMapWorldSize(current.mapID)
    if not mapWidthYards or mapWidthYards <= 0 then
        ring:Hide()
        fill:Hide()
        return
    end

    local canvasWidth, canvasHeight = canvas:GetWidth(), canvas:GetHeight()
    if not canvasWidth or canvasWidth <= 0 then return end

    -- Radius as a fraction of the map, then as pixels on the current canvas, so
    -- the circle stays correct through zoom and resize.
    local diameterPx = (current.radius / mapWidthYards) * canvasWidth * 2

    -- Below a couple of pixels the circle is noise rather than information.
    if diameterPx < 4 then diameterPx = 4 end

    local px =  current.x * canvasWidth
    local py = -current.y * canvasHeight

    fill:SetSize(diameterPx, diameterPx)
    fill:ClearAllPoints()
    fill:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
    fill:Show()

    ring:SetSize(diameterPx + 3, diameterPx + 3)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
    ring:Show()
end

MapCircle.Refresh = Refresh

--------------------------------------------------------------------------------
-- Show / hide
--------------------------------------------------------------------------------

--- Shows the pick-up radius for an anchor. Radius comes from the active
--- campaign, so a campaign with a tighter radius draws a tighter circle.
function MapCircle.Show(anchor)
    if not anchor or not anchor.mapID then return end
    if not Build() then return end

    local rules = ns.DB.GetRules()

    current = {
        mapID  = anchor.mapID,
        x      = anchor.x,
        y      = anchor.y,
        radius = (rules and rules.pickupRadius) or ns.PICKUP_RADIUS,
    }

    Refresh()

    -- The canvas moves under pan and zoom without firing anything useful, so
    -- while the map is open the circle is simply kept in step. It stops as soon
    -- as the map closes.
    if not ticker then
        ticker = C_Timer.NewTicker(0.1, function()
            if not current then return end
            if WorldMapFrame and WorldMapFrame:IsShown() then
                Refresh()
            end
        end)
    end
end

function MapCircle.Hide()
    current = nil
    if fill then fill:Hide() end
    if ring then ring:Hide() end
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

ns:OnLoad(function()
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", Refresh)
    end
end)
