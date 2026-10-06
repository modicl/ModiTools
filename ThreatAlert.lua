-- Herramienta: alerta de threat.
--
-- Muestra un texto cuando estás perdiendo el threat (aggro) de algún mob:
--   * mientras lo tienes de forma inestable (otro jugador casi te lo quita), y
--   * al perderlo (lo tenías y dejaste de tenerlo).
-- Por defecto solo para tanks, para no avisar a quien no está tankeando.

local _, ns = ...
local PREFIX = ns.PREFIX
local L = ns.L

local FONTS = {
    default = STANDARD_TEXT_FONT,
    frizqt = "Fonts/FRIZQT__.TTF",
    arialn = "Fonts/ARIALN.TTF",
    morpheus = "Fonts/MORPHEUS.TTF",
}

local defaults = {
    enabled = true, unlocked = false,
    point = "CENTER", x = 0, y = 120,
    text = "",   -- vacío = texto por defecto del idioma activo
    fontSize = 36, alpha = 1, font = "default", outline = "OUTLINE",
    colorText = { 1, 0.2, 0.2, 1 },
    showBG = false, colorBG = { 0, 0, 0, 0.5 },
    flash = true, showMob = false,
    onlyTank = true, holdSeconds = 3,
    sound = false, soundKey = "alarm",
    soundCustom = "",   -- soundkit ID o ruta de archivo, usado con la opción "Personalizado"
}

local Threat = {}
ns.RegisterModule("threat", defaults, Threat)

local function cfg() return ns.db.threat end

---------------------------------------------------------------------------
-- Marco del texto
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "ModiToolsThreatFrame", UIParent)
frame:SetFrameStrata("HIGH")
frame:Hide()

local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()

local text = frame:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER", 0, 0)

local mobText = frame:CreateFontString(nil, "OVERLAY")
mobText:SetPoint("TOP", text, "BOTTOM", 0, -2)

-- Texto que se muestra: el escrito por el usuario o el predeterminado del idioma.
local function DisplayText()
    local c = cfg()
    if c.text == nil or c.text == "" then return L["LOSING AGGRO!"] end
    return c.text
end
ns.ThreatText = DisplayText

local function Layout()
    local c = cfg()
    local w = math.max(160, text:GetStringWidth() + 40)
    local h = c.fontSize + 24
    if c.showMob then h = h + 18 end
    frame:SetSize(w, h)
    text:ClearAllPoints()
    text:SetPoint("CENTER", 0, c.showMob and 9 or 0)
end

---------------------------------------------------------------------------
-- Detección
---------------------------------------------------------------------------

local FIXED_UNITS = { "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }
local units = {}            -- se reutiliza en cada escaneo (sin crear tablas nuevas)

-- Unidades a revisar: las fijas + las nameplates que existen ahora (no las 40 posibles).
local function CollectUnits()
    wipe(units)
    for i = 1, #FIXED_UNITS do units[#units + 1] = FIXED_UNITS[i] end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        for i = 1, #plates do
            local token = plates[i].namePlateUnitToken
            if token then units[#units + 1] = token end
        end
    end
    return units
end

local last = {}          -- [unit] = último estado de threat conocido
local alertUntil = 0
local lastSound = -10
local mobName
local inCombat = false
local eventsOn = false
local warned = false

local function IsTank()
    if GetSpecialization and GetSpecializationRole then
        local spec = GetSpecialization()
        if spec then
            local role = GetSpecializationRole(spec)
            if role then return role == "TANK" end
        end
    end
    return UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == "TANK"
end

local function PlayAlertSound()
    local c = cfg()
    if not c.sound then return end
    local now = GetTime()
    if now - lastSound < 1.5 then return end
    lastSound = now
    ns.PlaySoundKey(c.soundKey, c.soundCustom)
end

local SyncDriver   -- (definida en la sección de actualización)

local function SetAlert(duration, unit)
    local c = cfg()
    local now = GetTime()
    local wasActive = alertUntil > now
    alertUntil = math.max(alertUntil, now + duration)
    if c.showMob and unit then
        local ok, name = pcall(UnitName, unit)
        mobName = ok and name or nil
    end
    if not wasActive then PlayAlertSound() end
    SyncDriver()
end

local function ScanUnits()
    local c = cfg()
    if c.onlyTank and not IsTank() then
        wipe(last)
        return
    end
    local losing, lost, mob
    local list = CollectUnits()
    local Secrets = ns.Secrets
    for i = 1, #list do
        local unit = list[i]
        if Secrets.ThreatIsSecret("player", unit) == true then
            last[unit] = nil     -- threat oculto (Mythic+/encuentro): no se puede leer
        elseif UnitExists(unit) and UnitCanAttack("player", unit) and UnitAffectingCombat(unit) then
            -- 0 = sin threat, 1 = más que el tank sin tener aggro, 2 = aggro inestable, 3 = aggro seguro
            local status = UnitThreatSituation("player", unit) or 0
            local prev = last[unit]
            if status == 2 then
                losing, mob = true, mob or unit
            elseif prev and prev >= 2 and status < 2 then
                lost, mob = true, mob or unit
            end
            last[unit] = status
        else
            last[unit] = nil
        end
    end
    if losing then
        SetAlert(0.6, mob)
    elseif lost then
        SetAlert(c.holdSeconds, mob)
    end
end

local function Scan()
    local ok, err = pcall(ScanUnits)
    if not ok and not warned then
        warned = true
        print(PREFIX .. string.format(L["Could not read threat: %s"], tostring(err)))
    end
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------

local driver = CreateFrame("Frame")

-- Animación del aviso: el OnUpdate solo existe mientras hay algo que mostrar (alerta activa o marco desbloqueado).
local function Animate()
    local c = cfg()
    local now = GetTime()
    local active = now < alertUntil
    if active or c.unlocked then
        if active and mobName and c.showMob then
            mobText:SetText(mobName)
        elseif c.showMob then
            mobText:SetText(c.unlocked and L["Mob name"] or "")
        end
        frame:Show()
        frame:SetAlpha(c.alpha * (c.flash and (0.65 + 0.35 * math.sin(now * 8)) or 1))
    else
        frame:Hide()
        driver:SetScript("OnUpdate", nil)
    end
end

SyncDriver = function()
    local c = cfg()
    if GetTime() < alertUntil or c.unlocked then
        driver:SetScript("OnUpdate", Animate)
    else
        driver:SetScript("OnUpdate", nil)
    end
    Animate()
end

-- Escaneo con debounce: varios eventos seguidos producen una sola lectura.
local scanQueued = false
local function QueueScan()
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(0.1, function()
        scanQueued = false
        if inCombat and eventsOn then
            Scan()
            SyncDriver()
        end
    end)
end

-- Respaldo mientras dura el combate (por si algún cambio no emite evento); se cancela al salir.
local ticker
local function StartTicker()
    if ticker then return end
    ticker = C_Timer.NewTicker(0.5, function()
        Scan()
        SyncDriver()
    end)
end
local function StopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
end

driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        StartTicker()
        QueueScan()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        StopTicker()
        wipe(last)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        QueueScan()
    end
end)

local function SetEvents(on)
    if on == eventsOn then return end
    eventsOn = on
    driver:UnregisterAllEvents()
    if not on then StopTicker(); inCombat = false; return end
    for _, e in ipairs({
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE",
    }) do
        local ok = pcall(driver.RegisterEvent, driver, e)
        if not ok then print(PREFIX .. string.format(L["Event not available: %s"], e)) end
    end
    inCombat = UnitAffectingCombat("player") and true or false
    if inCombat then StartTicker(); QueueScan() end
end

---------------------------------------------------------------------------
-- Aplicar configuración
---------------------------------------------------------------------------

function Threat.Apply()
    local c = cfg()
    ns.MakeMovable(frame, c)
    ns.ApplyPosition(frame, c)
    ns.ApplyLockVisuals(frame, c)

    local flags = c.outline ~= "NONE" and c.outline or ""
    local font = FONTS[c.font] or FONTS.default
    local ok = pcall(text.SetFont, text, font, c.fontSize, flags)
    if not ok then text:SetFont(STANDARD_TEXT_FONT, c.fontSize, flags) end
    mobText:SetFont(STANDARD_TEXT_FONT, math.max(10, math.floor(c.fontSize / 2.5)), "OUTLINE")
    mobText:SetShown(c.showMob)
    -- el texto por defecto antiguo (en español) pasa a ser "el del idioma activo"
    if c.text == "¡PERDIENDO THREAT!" then c.text = "" end
    text:SetText(DisplayText())
    text:SetTextColor(c.colorText[1], c.colorText[2], c.colorText[3], c.colorText[4] or 1)

    bg:SetShown(c.showBG)
    bg:SetColorTexture(c.colorBG[1], c.colorBG[2], c.colorBG[3], c.colorBG[4] or 1)
    Layout()

    SetEvents(c.enabled)
    if not c.enabled then
        alertUntil = 0
        wipe(last)
    end
    SyncDriver()
end

function Threat.Slash(arg)
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    local c = cfg()
    if cmd == "test" then
        alertUntil = 0
        mobName = L["Test mob"]
        SetAlert(c.holdSeconds)
        print(PREFIX .. L["Threat alert test."])
    elseif cmd == "text" and rest ~= "" then
        c.text = rest
        Threat.Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif cmd == "sound" and rest ~= "" then
        c.soundCustom = rest
        c.soundKey = "custom"
        Threat.Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(PREFIX .. string.format(L["Custom sound: %s"], rest))
        ns.PlaySoundKey("custom", rest)
    else
        print(PREFIX .. L["Usage: /modi threat test | text <text> | sound <soundkitID or file path>"])
    end
end
