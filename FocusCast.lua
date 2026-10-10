-- Herramienta: barra de casteo del focus target.

local _, ns = ...
local PREFIX = ns.PREFIX
local L = ns.L
local Secrets = ns.Secrets

local TEXTURES = {
    Blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
    Plano = "Interface\\Buttons\\WHITE8x8",
    Raid = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    Habilidades = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
}
ns.FocusTextures = { "Blizzard", "Plano", "Raid", "Habilidades" }
ns.BarTextures = TEXTURES

local defaults = {
    enabled = true, unlocked = false,
    point = "CENTER", x = 0, y = -200,
    width = 260, height = 24, alpha = 1,
    texture = "Blizzard", fontSize = 12,
    showIcon = true, showName = true, showTime = true,
    showBorder = true, showSpark = true, showGlow = false, glowStyle = "pulse",
    colorCast = { 1, 0.8, 0.1, 1 },
    colorChannel = { 0.2, 0.9, 0.3, 1 },
    colorLocked = { 0.6, 0.6, 0.6, 1 },
    colorFailed = { 0.9, 0.2, 0.2, 1 },
    colorBG = { 0, 0, 0, 0.6 },
    colorBorder = { 0, 0, 0, 1 },
    soundStart = false, soundStartKey = "mt_focus_casting", soundOnlyInterruptible = true,
    soundInterrupt = false, soundInterruptKey = "ready",
    soundCustom = "",   -- soundkit ID o ruta de archivo, usado con la opción "Personalizado"
}

-- Lista de sonidos para el dropdown: clásicos + biblioteca del Cooldown Manager
-- (Sounds.lua) + personalizado. Las entradas con header = true son títulos de grupo.
ns.FocusSounds = {}
local soundIndex = {}   -- [value] = entrada reproducible

do
    local list = ns.FocusSounds
    local function add(entry)
        list[#list + 1] = entry
        if not entry.header then soundIndex[entry.value] = entry end
    end

    -- `en` es la clave de traducción; ns.LocalizeSounds() rellena `label` al crear la interfaz.
    -- sonidos propios del addon (archivos en Media\)
    add({ header = true, en = "ModiTools" })
    add({ value = "mt_potion_ready", en = "Potion ready (voice)",
          file = "Interface\\AddOns\\ModiTools\\Media\\potion_ready.mp3" })
    add({ value = "mt_focus_casting", en = "Focus casting (voice)",
          file = "Interface\\AddOns\\ModiTools\\Media\\focus_casting.mp3" })
    add({ value = "mt_trinket_ready", en = "Trinket ready (voice)",
          file = "Interface\\AddOns\\ModiTools\\Media\\trinket_ready.mp3" })
    add({ value = "mt_healing_potion_ready", en = "Healing potion ready (voice)",
          file = "Interface\\AddOns\\ModiTools\\Media\\healing_potion_ready.mp3" })

    add({ header = true, en = "Classic" })
    add({ value = "raid", en = "Raid warning", id = 8959 })
    add({ value = "ready", en = "Ready check", id = 8960 })
    add({ value = "alarm", en = "Alarm", id = 12867 })
    add({ value = "ping", en = "Map ping", id = 3175 })
    add({ value = "whisper", en = "Whisper", id = 3081 })
    add({ value = "quest", en = "Quest complete", id = 878 })
    add({ value = "levelup", en = "Level up", id = 888 })

    for _, group in ipairs(ns.SoundLibrary or {}) do
        add({ header = true, en = group.category })
        for _, snd in ipairs(group.sounds) do
            -- el texto localizado lo entrega el propio juego (CDMSND_*)
            add({ value = "cdm" .. snd.id, label = _G[snd.key] or snd.name, id = snd.id })
        end
    end

    add({ header = true, en = "Other" })
    add({ value = "custom", en = "Custom" })
end

-- Asigna los textos según el idioma activo (se llama al crear la interfaz).
function ns.LocalizeSounds()
    for _, e in ipairs(ns.FocusSounds) do
        if e.en then e.label = L[e.en] end
    end
    ns.FocusSounds._groups = nil
end

local Focus = {}
ns.RegisterModule("focus", defaults, Focus)

local function cfg() return ns.db.focus end

---------------------------------------------------------------------------
-- Marcos
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "ModiToolsFocusCastFrame", UIParent)
frame:SetFrameStrata("HIGH")

local glow = ns.Glow.Create(frame)   -- resplandor animado (estilos en Glow.lua)

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local bar = CreateFrame("StatusBar", nil, frame)
bar:SetStatusBarTexture(TEXTURES.Blizzard)

local barBG = bar:CreateTexture(nil, "BACKGROUND")
barBG:SetAllPoints()
barBG:SetColorTexture(0, 0, 0, 0.6)

-- velo gris para "no interrumpible" cuando el dato es secreto
local lockedTex = bar:CreateTexture(nil, "ARTWORK", nil, 2)
lockedTex:SetAllPoints()
lockedTex:SetColorTexture(0.5, 0.5, 0.5, 1)
lockedTex:SetAlpha(0)

local spark = bar:CreateTexture(nil, "OVERLAY")
spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
spark:SetBlendMode("ADD")

local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
border:SetAllPoints()
border:SetFrameLevel(bar:GetFrameLevel() + 2)
border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })

local nameText = bar:CreateFontString(nil, "OVERLAY")
nameText:SetPoint("LEFT", 4, 0)
nameText:SetJustifyH("LEFT")

local timeText = bar:CreateFontString(nil, "OVERLAY")
timeText:SetPoint("RIGHT", -4, 0)
nameText:SetPoint("RIGHT", timeText, "LEFT", -4, 0)

---------------------------------------------------------------------------
-- Estado del casteo
---------------------------------------------------------------------------

local cast = { active = false, timer = false }
local failedUntil = 0
local currentColor
local ShowPreview

local function SetBarColor(c)
    currentColor = c
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    glow:SetGlowColor(c[1], c[2], c[3])
end

-- "No interrumpible": en contenido restringido el booleano es secreto y no se puede comparar.
-- SetAlphaFromBoolean lo acepta directamente: pinta un velo gris solo si es verdadero.
local function SetLockedOverlay(tex, notInterruptible)
    if tex.SetAlphaFromBoolean then
        pcall(tex.SetAlphaFromBoolean, tex, notInterruptible, 0.65, 0)
    else
        tex:SetAlpha(0)
    end
end

local function ReadCast()
    local name, _, tex, startMS, endMS, _, _, notInterruptible = UnitCastingInfo("focus")
    if name then
        return name, tex, startMS, endMS, false, notInterruptible
    end
    local cname, _, ctex, cstart, cend, _, cNotInt = UnitChannelInfo("focus")
    if cname then
        return cname, ctex, cstart, cend, true, cNotInt
    end
    return nil
end

local function UpdateCastClassic()
    local c = cfg()
    local name, tex, startMS, endMS, isChannel, notInt = ReadCast()
    if name then
        -- primero los cálculos: si los datos son secretos, falla aquí sin tocar el estado
        local startS, endS = startMS / 1000, endMS / 1000
        cast.timer = false
        cast.preview = false
        cast.active = true
        cast.channel = isChannel
        cast.start = startS
        cast.finish = endS
        failedUntil = 0
        icon:SetTexture(tex)
        nameText:SetText(name)
        bar:SetMinMaxValues(0, cast.finish - cast.start)
        SetBarColor(notInt and c.colorLocked or (isChannel and c.colorChannel or c.colorCast))
        lockedTex:SetAlpha(0)
        frame:Show()
    else
        cast.active = false
        cast.timer = false
        if not c.unlocked and GetTime() >= failedUntil then
            frame:Hide()
        end
    end
end

-- Ruta para contenido restringido (Mythic+, raids, combate). Nombre, ícono y tiempos son valores "secretos":
-- no se pueden comparar, hacer cuentas ni usar en un `if`. Por eso aquí NO se mira ningún valor:
--   * que haya un casteo se sabe por si la función de duración devolvió algo (Secrets.CastDuration);
--   * nombre e ícono van directo a los widgets; "no interrumpible" con SetAlphaFromBoolean;
--   * el progreso lo anima el propio StatusBar con SetTimerDuration.
-- Sin casteo: se oculta la barra (salvo la vista previa o el aviso de interrupción en curso).
local function NoCast(c)
    cast.timer = false
    if not c.unlocked and GetTime() >= failedUntil then
        frame:Hide()
    end
end

local function UpdateCastSecret()
    local c = cfg()
    local isChannel, dur = Secrets.CastDuration("focus")
    if isChannel == nil then
        NoCast(c)
        return
    end

    local name, tex, notInt
    if isChannel then
        name, _, tex, _, _, _, notInt = UnitChannelInfo("focus")
    else
        name, _, tex, _, _, _, _, notInt = UnitCastingInfo("focus")
    end
    local dirs = Enum and Enum.StatusBarTimerDirection
    local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    local dir
    if dirs then
        if isChannel then dir = dirs.RemainingTime else dir = dirs.ElapsedTime end
    end
    -- si el StatusBar no acepta el objeto (no había casteo), se trata como "sin casteo"
    if not pcall(bar.SetTimerDuration, bar, dur, interp, dir) then
        NoCast(c)
        return
    end

    pcall(icon.SetTexture, icon, tex)
    pcall(nameText.SetText, nameText, name)
    timeText:SetText("")
    SetBarColor(isChannel and c.colorChannel or c.colorCast)
    SetLockedOverlay(lockedTex, notInt)
    cast.active = false
    cast.timer = true
    cast.preview = false
    failedUntil = 0
    frame:Show()
end

local warned = false
local function UpdateCast()
    if not cfg().enabled then return end
    -- la API oficial indica si los datos de este focus vendrán secretos: true = ruta segura directa
    if Secrets.CastIsSecret("focus") ~= true and pcall(UpdateCastClassic) then return end
    local ok, err = pcall(UpdateCastSecret)
    if not ok and not warned then
        warned = true
        print(PREFIX .. string.format(L["Could not read the focus cast: %s"], tostring(err)))
    end
end

local function ShowFailed(text)
    cast.active = false
    cast.timer = false
    cast.preview = false
    failedUntil = GetTime() + 0.8
    nameText:SetText(text)
    timeText:SetText("")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    SetBarColor(cfg().colorFailed)
    lockedTex:SetAlpha(0)
    frame:Show()
end

-- Vista previa para poder ubicar y personalizar la barra mientras está desbloqueada.
function ShowPreview()
    cast.preview = true
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    nameText:SetText(L["Focus cast"])
    timeText:SetText("1.5")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.6)
    SetBarColor(cfg().colorCast)
    lockedTex:SetAlpha(0)
    frame:Show()
end

local function OnUpdate()
    local c = cfg()
    local now = GetTime()

    if cast.active then
        local remaining = cast.finish - now
        if remaining <= 0 then
            UpdateCast()
            return
        end
        bar:SetValue(cast.channel and remaining or (now - cast.start))
        -- el texto solo se reescribe cuando cambia la décima de segundo
        local tenths = math.floor(remaining * 10)
        if tenths ~= cast.lastTenths then
            cast.lastTenths = tenths
            timeText:SetText(string.format("%.1f", remaining))
        end
    elseif failedUntil > 0 and now >= failedUntil then
        failedUntil = 0
        UpdateCast()
        if c.unlocked and not cast.active and not cast.timer then ShowPreview() end
    elseif c.unlocked and failedUntil == 0 and not cast.timer and not cast.preview then
        ShowPreview()
    end
end

---------------------------------------------------------------------------
-- Sonidos
---------------------------------------------------------------------------

local lastSound = 0

local fileWarned = {}

-- Reproduce un sonido de la lista (o uno personalizado: soundkit ID o ruta de archivo).
function ns.PlaySoundKey(key, custom)
    if key == "custom" then
        if tonumber(custom) then
            PlaySound(tonumber(custom), "Master")
        elseif custom and custom ~= "" then
            PlaySoundFile(custom, "Master")
        end
        return
    end
    local snd = soundIndex[key]
    if snd and snd.id then
        PlaySound(snd.id, "Master")
    elseif snd and snd.file then
        -- PlaySoundFile devuelve false si el archivo no existe o el juego aún no lo conoce
        -- (un archivo nuevo se reconoce al reiniciar el juego, no con /reload)
        local willPlay = PlaySoundFile(snd.file, "Master")
        if willPlay == false and not fileWarned[snd.file] then
            fileWarned[snd.file] = true
            print(PREFIX .. L["Could not play the sound file. If you just added it, restart the game (a /reload is not enough)."])
        end
    end
end

function ns.PlayFocusSound(key)
    ns.PlaySoundKey(key, cfg().soundCustom)
end

local function PlayLimited(key)
    local now = GetTime()
    if now - lastSound < 0.3 then return end
    lastSound = now
    ns.PlayFocusSound(key)
end

-- Con "solo interrumpibles", si no se puede saber (datos secretos) suena igual.
local function ShouldPlayStart(c)
    if not c.soundOnlyInterruptible then return true end
    local ok, res = pcall(function()
        local _, _, _, _, _, notInt = ReadCast()
        return not notInt
    end)
    if ok then return res end
    return true
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local unitEvents = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
local eventsOn = false

frame:SetScript("OnEvent", function(_, event)
    if ns.debug then print(PREFIX .. "event: " .. event) end
    local c = cfg()
    if event == "PLAYER_FOCUS_CHANGED" then
        failedUntil = 0
        UpdateCast()
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        UpdateCast()
        if c.soundStart and ShouldPlayStart(c) then PlayLimited(c.soundStartKey) end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        ShowFailed(L["Interrupted"])
        if c.soundInterrupt then PlayLimited(c.soundInterruptKey) end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        if not cast.active then return end
        UpdateCast()
    else
        UpdateCast()
    end
end)

local function SetEvents(on)
    if on == eventsOn then return end
    eventsOn = on
    frame:UnregisterAllEvents()
    if not on then return end
    frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    for _, e in ipairs(unitEvents) do
        -- un evento que el cliente no conozca no debe romper la carga
        local ok = pcall(frame.RegisterUnitEvent, frame, e, "focus")
        if not ok then print(PREFIX .. string.format(L["Event not available: %s"], e)) end
    end
end

---------------------------------------------------------------------------
-- Aplicar configuración
---------------------------------------------------------------------------

function Focus.Apply()
    local c = cfg()
    ns.MakeMovable(frame, c)
    ns.ApplyPosition(frame, c)
    ns.ApplyLockVisuals(frame, c)

    frame:SetSize(c.width, c.height)
    frame:SetAlpha(c.alpha)

    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMLEFT", 1, 1)
    icon:SetWidth(c.height - 2)
    icon:SetShown(c.showIcon)

    bar:ClearAllPoints()
    if c.showIcon then
        bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, 0)
    else
        bar:SetPoint("TOPLEFT", 1, -1)
    end
    bar:SetPoint("BOTTOMRIGHT", -1, 1)

    bar:SetStatusBarTexture(TEXTURES[c.texture] or TEXTURES.Blizzard)
    if currentColor then SetBarColor(currentColor) end
    barBG:SetColorTexture(c.colorBG[1], c.colorBG[2], c.colorBG[3], c.colorBG[4] or 1)

    border:SetShown(c.showBorder)
    border:SetBackdropBorderColor(c.colorBorder[1], c.colorBorder[2], c.colorBorder[3], c.colorBorder[4] or 1)

    spark:ClearAllPoints()
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:SetSize(16, c.height * 2.2)
    spark:SetShown(c.showSpark)

    glow:SetStyle(c.glowStyle)
    glow:SetShown(c.showGlow)

    nameText:SetFont(STANDARD_TEXT_FONT, c.fontSize, "OUTLINE")
    timeText:SetFont(STANDARD_TEXT_FONT, c.fontSize, "OUTLINE")
    nameText:SetShown(c.showName)
    timeText:SetShown(c.showTime)

    if c.enabled then
        SetEvents(true)
        frame:SetScript("OnUpdate", OnUpdate)
        UpdateCast()
        if c.unlocked and not cast.active and not cast.timer then ShowPreview() end
    else
        SetEvents(false)
        frame:SetScript("OnUpdate", nil)
        cast.active = false
        cast.timer = false
        frame:Hide()
    end
end

function Focus.Slash(arg)
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    if cmd == "sound" and rest ~= "" then
        local c = cfg()
        c.soundCustom = rest
        c.soundStartKey = "custom"
        Focus.Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(PREFIX .. string.format(L["Custom sound: %s"], rest))
        ns.PlayFocusSound("custom")
    else
        print(PREFIX .. L["Usage: /modi focus sound <soundkitID or file path>"])
    end
end
