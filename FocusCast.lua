-- Herramienta: barra de casteo del focus target.

local _, ns = ...
local PREFIX = ns.PREFIX

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
    showBorder = true, showSpark = true, showGlow = false,
    colorCast = { 1, 0.8, 0.1, 1 },
    colorChannel = { 0.2, 0.9, 0.3, 1 },
    colorLocked = { 0.6, 0.6, 0.6, 1 },
    colorFailed = { 0.9, 0.2, 0.2, 1 },
    colorBG = { 0, 0, 0, 0.6 },
    colorBorder = { 0, 0, 0, 1 },
    soundStart = false, soundStartKey = "raid", soundOnlyInterruptible = true,
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

    add({ header = true, label = "Clásicos" })
    add({ value = "raid", label = "Aviso de banda", id = 8959 })
    add({ value = "ready", label = "Ready check", id = 8960 })
    add({ value = "alarm", label = "Alarma", id = 12867 })
    add({ value = "ping", label = "Ping de mapa", id = 3175 })
    add({ value = "whisper", label = "Susurro", id = 3081 })
    add({ value = "quest", label = "Misión completa", id = 878 })
    add({ value = "levelup", label = "Subida de nivel", id = 888 })

    for _, group in ipairs(ns.SoundLibrary or {}) do
        add({ header = true, label = group.category })
        for _, snd in ipairs(group.sounds) do
            -- el texto localizado lo entrega el propio juego (CDMSND_*)
            add({ value = "cdm" .. snd.id, label = _G[snd.key] or snd.name, id = snd.id })
        end
    end

    add({ header = true, label = "Otros" })
    add({ value = "custom", label = "Personalizado" })
end

local Focus = {}
ns.RegisterModule("focus", defaults, Focus)

local function cfg() return ns.db.focus end

---------------------------------------------------------------------------
-- Marcos
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "ModiToolsFocusCastFrame", UIParent)
frame:SetFrameStrata("HIGH")

local glow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
glow:SetPoint("TOPLEFT", -4, 4)
glow:SetPoint("BOTTOMRIGHT", 4, -4)
glow:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
glow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 4 })

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local bar = CreateFrame("StatusBar", nil, frame)
bar:SetStatusBarTexture(TEXTURES.Blizzard)

local barBG = bar:CreateTexture(nil, "BACKGROUND")
barBG:SetAllPoints()
barBG:SetColorTexture(0, 0, 0, 0.6)

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
    glow:SetBackdropBorderColor(c[1], c[2], c[3], 0.5)
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
        cast.active = true
        cast.channel = isChannel
        cast.start = startS
        cast.finish = endS
        failedUntil = 0
        icon:SetTexture(tex)
        nameText:SetText(name)
        bar:SetMinMaxValues(0, cast.finish - cast.start)
        SetBarColor(notInt and c.colorLocked or (isChannel and c.colorChannel or c.colorCast))
        frame:Show()
    else
        cast.active = false
        cast.timer = false
        if not c.unlocked and GetTime() >= failedUntil then
            frame:Hide()
        end
    end
end

-- Ruta alternativa para clientes que entregan datos de casteo "secretos":
-- el propio StatusBar anima el progreso a partir de un objeto de duración.
local function UpdateCastTimer()
    local c = cfg()
    local isChannel = false
    local dur = UnitCastingDuration and UnitCastingDuration("focus")
    local name, _, tex = UnitCastingInfo("focus")
    if not name then
        isChannel = true
        dur = UnitChannelDuration and UnitChannelDuration("focus")
        name, _, tex = UnitChannelInfo("focus")
    end
    if not name or not dur then
        cast.timer = false
        if not c.unlocked and GetTime() >= failedUntil then
            frame:Hide()
        end
        return
    end
    local dirs = Enum and Enum.StatusBarTimerDirection
    local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    local dir = dirs and (isChannel and dirs.RemainingTime or dirs.ElapsedTime)
    icon:SetTexture(tex)
    nameText:SetText(name)
    timeText:SetText("")
    bar:SetTimerDuration(dur, interp, dir)
    SetBarColor(isChannel and c.colorChannel or c.colorCast)
    cast.active = false
    cast.timer = true
    failedUntil = 0
    frame:Show()
end

local warned = false
local function UpdateCast()
    if not cfg().enabled then return end
    if pcall(UpdateCastClassic) then return end
    local ok, err = pcall(UpdateCastTimer)
    if not ok and not warned then
        warned = true
        print(PREFIX .. "no se pudo leer el casteo del focus: " .. tostring(err))
    end
end

local function ShowFailed(text)
    cast.active = false
    cast.timer = false
    failedUntil = GetTime() + 0.8
    nameText:SetText(text)
    timeText:SetText("")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    SetBarColor(cfg().colorFailed)
    frame:Show()
end

-- Vista previa para poder ubicar y personalizar la barra mientras está desbloqueada.
function ShowPreview()
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    nameText:SetText("Cast del focus")
    timeText:SetText("1.5")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.6)
    SetBarColor(cfg().colorCast)
    frame:Show()
end

local function OnUpdate()
    local c = cfg()
    local now = GetTime()

    if c.showGlow and glow:IsShown() then
        glow:SetAlpha(0.45 + 0.35 * math.sin(now * 5))
    end

    if cast.active then
        local remaining = cast.finish - now
        if remaining <= 0 then
            UpdateCast()
            return
        end
        bar:SetValue(cast.channel and remaining or (now - cast.start))
        timeText:SetText(string.format("%.1f", remaining))
    elseif failedUntil > 0 and now >= failedUntil then
        failedUntil = 0
        UpdateCast()
        if c.unlocked and not cast.active and not cast.timer then ShowPreview() end
    elseif c.unlocked and failedUntil == 0 and not cast.timer then
        ShowPreview()
    end
end

---------------------------------------------------------------------------
-- Sonidos
---------------------------------------------------------------------------

local lastSound = 0

function ns.PlayFocusSound(key)
    if key == "custom" then
        local v = cfg().soundCustom
        if tonumber(v) then
            PlaySound(tonumber(v), "Master")
        elseif v and v ~= "" then
            PlaySoundFile(v, "Master")
        end
        return
    end
    local snd = soundIndex[key]
    if snd and snd.id then
        PlaySound(snd.id, "Master")
    end
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
    if ns.debug then print(PREFIX .. "evento: " .. event) end
    local c = cfg()
    if event == "PLAYER_FOCUS_CHANGED" then
        failedUntil = 0
        UpdateCast()
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        UpdateCast()
        if c.soundStart and ShouldPlayStart(c) then PlayLimited(c.soundStartKey) end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        ShowFailed("Interrumpido")
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
        if not ok then print(PREFIX .. "evento no disponible: " .. e) end
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

    glow:SetShown(c.showGlow)
    if not c.showGlow then glow:SetAlpha(1) end

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
    if cmd == "sound" and rest ~= "" then
        local c = cfg()
        c.soundCustom = rest
        c.soundStartKey = "custom"
        Focus.Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(PREFIX .. "sonido personalizado: " .. rest)
        ns.PlayFocusSound("custom")
    else
        print(PREFIX .. "uso: /modi focus sound <soundkitID o ruta del archivo>")
    end
end
