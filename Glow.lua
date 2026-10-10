-- Resplandores animados alrededor de un marco. Los estilos siguen los de las librerías habituales de glow
-- (LibCustomGlow: "pixel" y "autocast shine"), hechos sin dependencias:
--   pulse  borde que late          solid  borde fijo
--   pixel  líneas que recorren el contorno          shine  destellos que giran por el contorno
-- El OnUpdate solo existe mientras el glow está visible y su estilo se anima.

local _, ns = ...
local L = ns.L

local Glow = {}
ns.Glow = Glow

local PIXELS = 8
local SPARKS = 12
local PAD = 4                      -- cuánto sobresale del marco
local STAR = "Interface\\Cooldown\\star4"

Glow.styles = { "pulse", "solid", "pixel", "shine" }
local ANIMATED = { pulse = true, pixel = true, shine = true }

-- Opciones para un dropdown (las etiquetas salen del idioma activo).
function Glow.StyleOptions()
    return {
        { value = "pulse", label = L["Pulse"] },
        { value = "solid", label = L["Solid"] },
        { value = "pixel", label = L["Rotating lines"] },
        { value = "shine", label = L["Sparkles"] },
    }
end

-- Punto a una distancia d del contorno (en el sentido del reloj desde la esquina superior izquierda).
-- Devuelve x, y (relativos a TOPLEFT) y el lado: 1 arriba, 2 derecha, 3 abajo, 4 izquierda.
local function OnPerimeter(d, w, h)
    if d < w then return d, 0, 1 end
    d = d - w
    if d < h then return w, -d, 2 end
    d = d - h
    if d < w then return w - d, -h, 3 end
    d = d - w
    return 0, -(h - d), 4
end

local function Step(self, dt)
    local style = self.style
    local now = GetTime()
    if style == "pulse" then
        self.edge:SetAlpha(0.45 + 0.35 * math.sin(now * 5))
        return
    end
    local w, h = self:GetWidth(), self:GetHeight()
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return end
    local perimeter = 2 * (w + h)
    local r, g, b = self.r, self.g, self.b

    if style == "pixel" then
        self.phase = (self.phase + dt * 0.25) % 1
        local len = math.max(6, math.min(w, h) * 0.5)
        for i = 1, PIXELS do
            local t = self.pixels[i]
            local x, y, side = OnPerimeter(((self.phase + (i - 1) / PIXELS) % 1) * perimeter, w, h)
            if side == 1 or side == 3 then t:SetSize(len, 2) else t:SetSize(2, len) end
            t:ClearAllPoints()
            t:SetPoint("CENTER", self, "TOPLEFT", x, y)
        end
    elseif style == "shine" then
        self.phase = (self.phase + dt * 0.12) % 1
        for i = 1, SPARKS do
            local t = self.sparks[i]
            local x, y = OnPerimeter(((self.phase + (i - 1) / SPARKS) % 1) * perimeter, w, h)
            local size = 7 + (i % 3) * 3
            t:SetSize(size, size)
            t:SetAlpha(0.55 + 0.45 * math.sin(now * 6 + i))
            t:ClearAllPoints()
            t:SetPoint("CENTER", self, "TOPLEFT", x, y)
        end
    end
end

-- Enciende o apaga el OnUpdate según el estilo y si el glow está a la vista.
local function Sync(self)
    if self:IsShown() and ANIMATED[self.style] then
        self:SetScript("OnUpdate", Step)
    else
        self:SetScript("OnUpdate", nil)
    end
end

local function Paint(self)
    local style, r, g, b = self.style, self.r, self.g, self.b
    local useEdge = style == "pulse" or style == "solid"
    self.edge:SetShown(useEdge)
    self.edge:SetBackdropBorderColor(r, g, b, 1)
    self.edge:SetAlpha(style == "solid" and 0.7 or 0.6)
    for i = 1, PIXELS do
        local t = self.pixels[i]
        t:SetShown(style == "pixel")
        t:SetColorTexture(r, g, b, 1)
    end
    for i = 1, SPARKS do
        local t = self.sparks[i]
        t:SetShown(style == "shine")
        t:SetVertexColor(r, g, b, 1)
    end
    Sync(self)
    if style == "pixel" or style == "shine" then Step(self, 0) end
end

function Glow.Create(parent, pad)
    local g = CreateFrame("Frame", nil, parent)
    pad = pad or PAD
    g:SetPoint("TOPLEFT", -pad, pad)
    g:SetPoint("BOTTOMRIGHT", pad, -pad)
    g:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    g.style, g.phase, g.r, g.g, g.b = "pulse", 0, 1, 0.82, 0

    g.edge = CreateFrame("Frame", nil, g, "BackdropTemplate")
    g.edge:SetAllPoints()
    g.edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 4 })

    g.pixels, g.sparks = {}, {}
    for i = 1, PIXELS do
        g.pixels[i] = g:CreateTexture(nil, "OVERLAY")
        g.pixels[i]:Hide()
    end
    for i = 1, SPARKS do
        local t = g:CreateTexture(nil, "OVERLAY")
        t:SetTexture(STAR)
        t:SetBlendMode("ADD")
        t:Hide()
        g.sparks[i] = t
    end

    function g:SetStyle(style)
        self.style = ANIMATED[style] and style or (style == "solid" and "solid" or "pulse")
        Paint(self)
    end
    function g:SetGlowColor(r, gg, b)
        self.r, self.g, self.b = r, gg, b
        Paint(self)
    end
    g:SetScript("OnShow", Sync)
    g:SetScript("OnHide", Sync)
    Paint(g)
    return g
end
