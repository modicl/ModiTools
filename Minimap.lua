-- Botón del minimapa: abre/cierra la ventana de ModiTools.
-- Se arrastra alrededor del minimapa y su posición se guarda.

local _, ns = ...
local L = ns.L

ns.globalDefaults.minimap = { angle = 215, hide = false }

local atan2 = math.atan2 or math.atan
local RADIUS_EXTRA = 5

local button

local function UpdatePosition()
    local angle = math.rad(ns.global.minimap.angle)
    local radius = (Minimap:GetWidth() / 2) + RADIUS_EXTRA
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Mientras se arrastra: el ángulo sale de la posición del cursor respecto al centro del minimapa.
local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    ns.global.minimap.angle = math.deg(atan2(cy - my, cx - mx)) % 360
    UpdatePosition()
end

local function CreateButton()
    button = CreateFrame("Button", "ModiToolsMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface/Minimap/UI-Minimap-Background")
    bg:SetSize(22, 22)
    bg:SetPoint("TOPLEFT", 5, -4)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface/AddOns/ModiTools/Media/dwarf")
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 6, -5)
    -- recorte circular; si el cliente no tiene la máscara se ve cuadrado
    pcall(function()
        local mask = button:CreateMaskTexture()
        mask:SetTexture("Interface/CharacterFrame/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function() ns.ToggleWindow() end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("ModiTools")
        GameTooltip:AddLine(L["Click: open / close the window"], 1, 1, 1)
        GameTooltip:AddLine(L["Drag: move the icon"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.UpdateMinimap()
    if not button then return end
    if ns.global.minimap.hide then
        button:Hide()
    else
        UpdatePosition()
        button:Show()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    CreateButton()
    ns.UpdateMinimap()
end)
