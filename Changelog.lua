-- Registro de cambios: una ventana aparte con las novedades de cada versión.
-- Aparece sola una vez, la primera vez que se abre el juego con una versión nueva (no en una instalación nueva),
-- y se puede abrir cuando se quiera con /modi changelog o el botón del Inicio.

local _, ns = ...
local L = ns.L

local Changelog = {}
ns.Changelog = Changelog

---------------------------------------------------------------------------
-- Datos: de la más nueva a la más antigua. Cada versión tiene sus líneas en inglés y en español.
-- Al publicar una versión nueva: agregar una entrada arriba y subir ## Version en el .toc.
---------------------------------------------------------------------------

Changelog.entries = {
    {
        version = "0.8", date = "2026-10",
        en = {
            "New ready sounds with voice: potion, healing potion, trinket, and focus casting.",
            "Prepot/Trinket reorganized: the potion icon is now optional, and the healing potion has its own sound.",
            "Cooldown sounds no longer poll: they react to game events, so they use almost no CPU.",
            "Fixed focus and marked-mob casts not showing in Mythic+ (restricted content).",
            "Performance audit of every tool: on-demand updates, no per-frame allocations, and the window is built only when you first open it.",
            "Bigger, friendlier window with wider columns, so texts no longer wrap into several lines.",
            "Closing ModiTools turns off all active previews.",
            "The interface language is picked from your game client (Spanish or English).",
            "This changelog.",
        },
        es = {
            "Nuevos sonidos de listo con voz: poción, poción de HP, trinket y focus casteando.",
            "Prepot/Trinket reorganizado: el ícono de la prepota ahora es opcional y la poción de HP tiene su propio sonido.",
            "Los sonidos de cooldown ya no revisan cada cierto tiempo: reaccionan a eventos del juego y casi no gastan CPU.",
            "Corregido: los casteos del focus y de mobs marcados no se veían en Mythic+ (contenido restringido).",
            "Auditoría de rendimiento de todas las herramientas: actualizaciones bajo demanda, sin crear tablas por frame y la ventana se construye solo al abrirla por primera vez.",
            "Ventana más grande y amigable, con columnas más anchas para que los textos no se partan en varias líneas.",
            "Al cerrar ModiTools se apagan todas las vistas previas activas.",
            "El idioma de la interfaz se elige según el cliente del juego (español o inglés).",
            "Este registro de cambios.",
        },
    },
    {
        version = "0.7", date = "2026-09",
        en = {
            "Interface in English and Spanish (MX), with game jargon like aggro, prepot and brez.",
            "Profiles: create, switch, and share them with an import/export code.",
            "CD Timeline: a line with your upcoming cooldowns (spells, potions and trinkets), horizontal or vertical, with sounds and a combat-only option.",
            "Choose the font and the sound for each skill on the timeline.",
            "Sliders accept a typed value.",
        },
        es = {
            "Interfaz en español (MX) e inglés, con jerga del juego como aggro, prepota y brez.",
            "Perfiles: crea, cambia y comparte perfiles con un código de importar/exportar.",
            "CD Timeline: una línea con tus próximos cooldowns (hechizos, pociones y trinkets), horizontal o vertical, con sonidos y opción de solo en combate.",
            "Elige la fuente y el sonido de cada habilidad en la línea.",
            "Los deslizadores aceptan un valor escrito.",
        },
    },
    {
        version = "0.5", date = "2026-08",
        en = {
            "First public version: yards to your target, focus cast bar, marked-mob casts, threat alert, brez on a key, and the prepot timer.",
            "Own Steam-classic window with a sidebar, plus a minimap button.",
            "Sound list with preview and categories, bar textures, and per-tool previews.",
        },
        es = {
            "Primera versión pública: yardas al target, barra de casteo del focus, casteos de mobs marcados, alerta de threat, brez en una tecla y el temporizador de la prepota.",
            "Ventana propia estilo Steam clásico con barra lateral, y botón en el minimapa.",
            "Lista de sonidos con vista previa y categorías, texturas de barra y vistas previas por herramienta.",
        },
    },
}

---------------------------------------------------------------------------
-- Versiones
---------------------------------------------------------------------------

function ns.AddonVersion()
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(fn, "ModiTools", "Version")
    return (ok and v) or Changelog.entries[1].version
end

-- Compara "0.10" con "0.9" número por número: devuelve -1, 0 o 1.
local function CompareVersions(a, b)
    local pa, pb = {}, {}
    for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end
Changelog.CompareVersions = CompareVersions

---------------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------------

local WIDTH, HEIGHT = 620, 560
local TEXT_W = WIDTH - 70
local popup

local function BuildText(lastSeen)
    local lang = ns.GetLanguage and ns.GetLanguage() or "en"
    local accent, muted, text = "|cffc4b550", "|cffa0aa95", "|cffffffff"
    local out = {}
    for _, entry in ipairs(Changelog.entries) do
        local isNew = lastSeen and CompareVersions(entry.version, lastSeen) > 0
        local head = accent .. string.format(L["Version %s"], entry.version) .. "|r  " .. muted .. entry.date .. "|r"
        if isNew then head = head .. "   |cff6fd36f[" .. L["New"] .. "]|r" end
        out[#out + 1] = head
        for _, line in ipairs(entry[lang] or entry.en) do
            out[#out + 1] = text .. "•|r  " .. line
        end
        out[#out + 1] = ""
    end
    return table.concat(out, "\n")
end

local function Build()
    local UI = ns.UI
    local Skin, Label, CreateButton, C, rgb = UI.Skin, UI.Label, UI.CreateButton, UI.C, UI.rgb

    local p = CreateFrame("Frame", "ModiToolsChangelog", UIParent)
    p:SetSize(WIDTH, HEIGHT)
    p:SetPoint("CENTER", 0, 20)
    p:SetFrameStrata("DIALOG")
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:EnableMouseWheel(true)
    Skin(p, C.bg, false)
    p:Hide()
    table.insert(UISpecialFrames, "ModiToolsChangelog")

    local bar = CreateFrame("Frame", nil, p)
    bar:SetHeight(40)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() p:StartMoving() end)
    bar:SetScript("OnDragStop", function() p:StopMovingOrSizing() end)
    p.title = Label(bar, "", 18, C.accent)
    p.title:SetPoint("LEFT", 16, 0)
    local x = CreateButton(bar, "X", 28, 24, function() p:Hide() end)
    x:SetPoint("RIGHT", -8, 0)

    -- zona de lectura: el texto se desplaza dentro de un marco que recorta lo que sobra
    local view = CreateFrame("Frame", nil, p)
    view:SetPoint("TOPLEFT", 12, -48)
    view:SetPoint("BOTTOMRIGHT", -12, 56)
    Skin(view, C.bgDark, true)
    local clip = CreateFrame("Frame", nil, view)
    clip:SetPoint("TOPLEFT", 12, -10)
    clip:SetPoint("BOTTOMRIGHT", -26, 10)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end

    p.body = Label(clip, "", 12, C.text)
    p.body:SetPoint("TOPLEFT", 0, 0)
    p.body:SetWidth(TEXT_W - 30)
    p.body:SetSpacing(4)
    p.body:SetJustifyV("TOP")

    p.scroll = CreateFrame("Slider", nil, view)
    p.scroll:SetPoint("TOPRIGHT", -6, -8)
    p.scroll:SetPoint("BOTTOMRIGHT", -6, 8)
    p.scroll:SetWidth(10)
    p.scroll:SetOrientation("VERTICAL")
    Skin(p.scroll, C.bgDarker, true)
    p.scroll:SetThumbTexture("Interface/Buttons/WHITE8x8")
    p.scroll:GetThumbTexture():SetSize(10, 30)
    p.scroll:GetThumbTexture():SetVertexColor(rgb(C.muted))
    p.scroll:SetMinMaxValues(0, 0)
    p.scroll:SetValue(0)

    local function Scroll(value)
        p.body:ClearAllPoints()
        p.body:SetPoint("TOPLEFT", 0, value)
    end
    p.scroll:SetScript("OnValueChanged", function(_, v) Scroll(v) end)
    local function OnWheel(_, delta)
        local lo, hi = p.scroll:GetMinMaxValues()
        p.scroll:SetValue(math.max(lo, math.min(hi, p.scroll:GetValue() - delta * 40)))
    end
    p:SetScript("OnMouseWheel", OnWheel)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", OnWheel)
    p.clip = clip

    p.close = CreateButton(p, "", 160, 28, function() p:Hide() end)
    p.close:SetPoint("BOTTOM", 0, 14)

    popup = p
end

-- Abre la ventana. lastSeen (opcional): las versiones más nuevas que ésa se marcan como [Nueva].
function Changelog.Show(lastSeen)
    if not popup then Build() end
    popup.title:SetText(L["What's new in ModiTools"])
    popup.close.label:SetText(L["Close"])
    popup.body:SetText(BuildText(lastSeen))
    local textH = popup.body:GetStringHeight()
    local viewH = popup.clip:GetHeight()
    local max = 0
    if type(textH) == "number" and type(viewH) == "number" then max = math.max(0, textH - viewH + 8) end
    popup.scroll:SetMinMaxValues(0, max)
    popup.scroll:SetValue(0)
    popup.scroll:SetShown(max > 0)
    popup:Show()
    popup:Raise()
end

---------------------------------------------------------------------------
-- Aviso automático: solo cuando la versión cambió respecto a la última vez
---------------------------------------------------------------------------

local pending

local function ShowIfNew()
    pending = nil
    local current = ns.AddonVersion()
    local last = ns.global.lastVersion
    if last == current then return end
    ns.global.lastVersion = current
    if last == nil and ns.freshInstall then return end   -- instalación nueva: nada que contar
    Changelog.Show(last or "0.7")                        -- sin registro previo: viene de la 0.7 o anterior
end

function ns.CheckChangelog()
    if pending then return end
    if ns.global.lastVersion == ns.AddonVersion() then return end
    pending = true
    -- unos segundos después de entrar, y nunca en medio de un combate
    C_Timer.After(4, function()
        if InCombatLockdown and InCombatLockdown() then
            local f = CreateFrame("Frame")
            f:RegisterEvent("PLAYER_REGEN_ENABLED")
            f:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                ShowIfNew()
            end)
        else
            ShowIfNew()
        end
    end)
end

function ns.ShowChangelog()
    Changelog.Show(nil)
end
