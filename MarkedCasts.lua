-- Herramienta: casteos de mobs marcados (calavera, estrella, diamante, etc.).
--
-- Muestra una barra por cada mob con marca que esté casteando, con el ícono de la marca.
-- Al terminar el casteo indica si fue interrumpido (verde) o no (rojo).
-- Detecta los mobs a través de sus nameplates (deben estar visibles).

local _, ns = ...
local PREFIX = ns.PREFIX

local defaults = {
    enabled = true, unlocked = false,
    point = "CENTER", x = 0, y = -260,
    width = 220, height = 20, spacing = 4, maxBars = 4, growUp = false, alpha = 1,
    texture = "Blizzard", fontSize = 11,
    showTime = true, showBorder = true,
    showResult = true, chatMessage = false, resultSeconds = 1.5,
    colorCast = { 1, 0.8, 0.1, 1 },
    colorChannel = { 0.2, 0.9, 0.3, 1 },
    colorLocked = { 0.6, 0.6, 0.6, 1 },
    colorInterrupted = { 0.2, 0.85, 0.3, 1 },
    colorNotInterrupted = { 0.9, 0.2, 0.2, 1 },
    colorBG = { 0, 0, 0, 0.6 },
    colorBorder = { 0, 0, 0, 1 },
}

local Marked = {}
ns.RegisterModule("marked", defaults, Marked)

local function cfg() return ns.db.marked end

local MAX_POOL = 8
local ICON_SHEET = "Interface/TargetingFrame/UI-RaidTargetingIcons"

---------------------------------------------------------------------------
-- Barras
---------------------------------------------------------------------------

local anchor = CreateFrame("Frame", "ModiToolsMarkedFrame", UIParent)
anchor:SetFrameStrata("HIGH")

local pool = {}
local active = {}   -- barras en uso, en orden de aparición
local byUnit = {}   -- [nameplateN] = barra

local function SetMarkerIcon(f, idx)
    f.marker = idx
    local l = ((idx - 1) % 4) * 0.25
    local t = math.floor((idx - 1) / 4) * 0.25
    f.icon:SetTexCoord(l, l + 0.25, t, t + 0.25)
end

local function SetBarColor(f, c)
    f.bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
end

local function CreateBar()
    local f = CreateFrame("Frame", nil, anchor)
    f:Hide()

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexture(ICON_SHEET)

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")

    f.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()

    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetAllPoints()
    f.border:SetFrameLevel(f.bar:GetFrameLevel() + 2)
    f.border:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })

    f.nameText = f.bar:CreateFontString(nil, "OVERLAY")
    f.nameText:SetPoint("LEFT", 4, 0)
    f.nameText:SetJustifyH("LEFT")
    f.timeText = f.bar:CreateFontString(nil, "OVERLAY")
    f.timeText:SetPoint("RIGHT", -4, 0)
    f.nameText:SetPoint("RIGHT", f.timeText, "LEFT", -4, 0)
    return f
end

for i = 1, MAX_POOL do pool[i] = CreateBar() end

local function StyleBar(f)
    local c = cfg()
    local textures = ns.BarTextures or {}
    f:SetSize(c.width, c.height)

    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMLEFT", 1, 1)
    f.icon:SetWidth(c.height - 2)

    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 1, 0)
    f.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    f.bar:SetStatusBarTexture(textures[c.texture] or "Interface/TargetingFrame/UI-StatusBar")

    f.bg:SetColorTexture(c.colorBG[1], c.colorBG[2], c.colorBG[3], c.colorBG[4] or 1)
    f.border:SetShown(c.showBorder)
    f.border:SetBackdropBorderColor(c.colorBorder[1], c.colorBorder[2], c.colorBorder[3], c.colorBorder[4] or 1)

    f.nameText:SetFont(STANDARD_TEXT_FONT, c.fontSize, "OUTLINE")
    f.timeText:SetFont(STANDARD_TEXT_FONT, c.fontSize, "OUTLINE")
    f.timeText:SetShown(c.showTime)
end

local function PositionBar(f, slot)
    local c = cfg()
    local off = (slot - 1) * (c.height + c.spacing)
    f:ClearAllPoints()
    if c.growUp then
        f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, off)
    else
        f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -off)
    end
end

---------------------------------------------------------------------------
-- Vista previa (mientras está desbloqueado y no hay casteos reales)
---------------------------------------------------------------------------

local function ClearPreview()
    for _, f in ipairs(pool) do
        if f.preview then
            f.preview = false
            if not f.unit then f:Hide() end
        end
    end
end

local function ShowPreview()
    local c = cfg()
    local samples = {
        { marker = 8, text = "Cast de ejemplo", time = "1.8", color = c.colorCast, value = 0.6 },
        { marker = 1, text = "Interrumpido", time = "", color = c.colorInterrupted, value = 1 },
        { marker = 3, text = "No interrumpido", time = "", color = c.colorNotInterrupted, value = 1 },
    }
    for k, s in ipairs(samples) do
        local f = pool[k]
        if not f.unit then
            f.preview = true
            SetMarkerIcon(f, s.marker)
            f.nameText:SetText(s.text)
            f.timeText:SetText(s.time)
            f.bar:SetMinMaxValues(0, 1)
            f.bar:SetValue(s.value)
            SetBarColor(f, s.color)
            PositionBar(f, k)
            f:Show()
        end
    end
end

---------------------------------------------------------------------------
-- Asignación de barras
---------------------------------------------------------------------------

local function Layout()
    local slot = 0
    for _, f in ipairs(active) do
        if f.silent then
            f:Hide()
        else
            slot = slot + 1
            PositionBar(f, slot)
            f:Show()
        end
    end
    if #active == 0 and cfg().enabled and cfg().unlocked then
        ShowPreview()
    end
end

local function ResetBar(f)
    f.unit, f.mode, f.channel = nil, nil, nil
    f.result, f.resultUntil, f.pendingEnd, f.pendingKind, f.announceAt = nil, nil, nil, nil, nil
    f.silent, f.spellName, f.marker = false, nil, nil
end

local function Release(f)
    for i, b in ipairs(active) do
        if b == f then table.remove(active, i) break end
    end
    if f.unit and byUnit[f.unit] == f then byUnit[f.unit] = nil end
    ResetBar(f)
    f:Hide()
    Layout()
end

local function ReleaseAll()
    for i = #active, 1, -1 do Release(active[i]) end
end

local function Acquire(unit)
    if byUnit[unit] then return byUnit[unit] end
    if #active >= math.min(cfg().maxBars, MAX_POOL) then return nil end
    ClearPreview()
    for _, f in ipairs(pool) do
        if not f.unit then
            ResetBar(f)
            f.unit = unit
            byUnit[unit] = f
            active[#active + 1] = f
            return f
        end
    end
end

---------------------------------------------------------------------------
-- Lectura del casteo
---------------------------------------------------------------------------

local function ReadUnitCast(unit)
    local name, _, tex, startMS, endMS, _, _, notInt = UnitCastingInfo(unit)
    if name then return name, tex, startMS, endMS, false, notInt end
    local cname, _, ctex, cstart, cend, _, cNotInt = UnitChannelInfo(unit)
    if cname then return cname, ctex, cstart, cend, true, cNotInt end
    return nil
end

local function FillClassic(f, unit)
    local c = cfg()
    local name, _, startMS, endMS, isChannel, notInt = ReadUnitCast(unit)
    if not name then return false end
    -- primero los cálculos: si los datos son secretos, falla aquí
    local startS, endS = startMS / 1000, endMS / 1000
    f.mode = "classic"
    f.channel = isChannel
    f.start, f.finish = startS, endS
    f.nameText:SetText(name)
    f.spellName = name
    f.bar:SetMinMaxValues(0, endS - startS)
    SetBarColor(f, notInt and c.colorLocked or (isChannel and c.colorChannel or c.colorCast))
    return true
end

-- Ruta alternativa para datos "secretos": el StatusBar anima desde un objeto de duración.
local function FillTimer(f, unit)
    local c = cfg()
    local isChannel = false
    local dur = UnitCastingDuration and UnitCastingDuration(unit)
    local name = UnitCastingInfo(unit)
    if not name then
        isChannel = true
        dur = UnitChannelDuration and UnitChannelDuration(unit)
        name = UnitChannelInfo(unit)
    end
    if not name or not dur then return false end
    local dirs = Enum and Enum.StatusBarTimerDirection
    local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    local dir = dirs and (isChannel and dirs.RemainingTime or dirs.ElapsedTime)
    f.mode = "timer"
    f.channel = isChannel
    f.nameText:SetText(name)
    local ok, s = pcall(tostring, name)
    f.spellName = ok and s or nil
    f.timeText:SetText("")
    f.bar:SetTimerDuration(dur, interp, dir)
    SetBarColor(f, isChannel and c.colorChannel or c.colorCast)
    return true
end

local warned = false
local function Fill(f, unit)
    local ok, found = pcall(FillClassic, f, unit)
    if ok then return found end
    local ok2, found2 = pcall(FillTimer, f, unit)
    if ok2 then return found2 end
    if not warned then
        warned = true
        print(PREFIX .. "no se pudo leer el casteo de un mob marcado: " .. tostring(found2))
    end
    return false
end

local function GetMarker(unit)
    local ok, idx = pcall(GetRaidTargetIndex, unit)
    if ok and type(idx) == "number" and idx >= 1 and idx <= 8 then return idx end
    return nil
end

local function IsDead(unit)
    local ok, dead = pcall(UnitIsDead, unit)
    return ok and dead
end

---------------------------------------------------------------------------
-- Resultado: interrumpido / no interrumpido
---------------------------------------------------------------------------

local function Announce(f)
    f.announceAt = nil
    if not cfg().chatMessage then return end
    pcall(function()
        local idx = f.marker or 8
        local l = ((idx - 1) % 4) * 64
        local t = math.floor((idx - 1) / 4) * 64
        local icon = string.format(
            "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:14:14:0:0:256:256:%d:%d:%d:%d|t",
            l, l + 64, t, t + 64)
        local spell = f.spellName and (" " .. f.spellName) or ""
        if f.result == "int" then
            print(PREFIX .. icon .. spell .. " |cff33ff55interrumpido|r")
        else
            print(PREFIX .. icon .. spell .. " |cffff3333NO interrumpido|r")
        end
    end)
end

local function Resolve(f, interrupted)
    local c = cfg()
    f.result = interrupted and "int" or "notint"
    f.pendingEnd, f.pendingKind = nil, nil
    f.announceAt = GetTime() + 0.2   -- margen por si llega un INTERRUPTED justo después
    f.silent = not c.showResult
    f.resultUntil = GetTime() + (c.showResult and c.resultSeconds or 0.3)
    if c.showResult then
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(1)
        SetBarColor(f, interrupted and c.colorInterrupted or c.colorNotInterrupted)
        f.nameText:SetText(interrupted and "Interrumpido" or "No interrumpido")
        f.timeText:SetText("")
    end
    Layout()
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local function RefreshUnit(unit)
    local idx = GetMarker(unit)
    local f = byUnit[unit]
    if not idx then
        if f and not f.result then Release(f) end
        return
    end
    local fresh = not f
    f = f or Acquire(unit)
    if not f then return end
    if Fill(f, unit) then
        f.result, f.pendingEnd, f.pendingKind, f.announceAt, f.silent = nil, nil, nil, nil, false
        SetMarkerIcon(f, idx)
        Layout()
    elseif fresh then
        Release(f)
    end
end

local function ScanAll()
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            pcall(RefreshUnit, unit)
        elseif byUnit[unit] then
            Release(byUnit[unit])
        end
    end
end

local function IsPlate(unit)
    return type(unit) == "string" and unit:sub(1, 9) == "nameplate"
end

local startEvents = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_DELAYED = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
}

anchor:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "RAID_TARGET_UPDATE" then
        ScanAll()
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        ReleaseAll()
        ScanAll()
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        pcall(RefreshUnit, unit)
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if byUnit[unit] then Release(byUnit[unit]) end
        return
    end

    if not IsPlate(unit) then return end
    local f = byUnit[unit]

    if startEvents[event] then
        if ns.debug then print(PREFIX .. "marcado " .. unit .. ": " .. event) end
        pcall(RefreshUnit, unit)
    elseif not f then
        return
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if ns.debug then print(PREFIX .. "marcado " .. unit .. ": " .. event) end
        Resolve(f, true)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- en los channels SUCCEEDED llega al inicio: se ignora
        if not f.channel and not f.result then Resolve(f, false) end
    elseif event == "UNIT_SPELLCAST_STOP" then
        -- puede llegar antes que INTERRUPTED: se espera un momento antes de soltar la barra
        if not f.result and not f.pendingEnd then
            f.pendingEnd, f.pendingKind = GetTime() + 0.15, "release"
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if not f.result then
            -- args: castGUID, spellID, interruptedBy
            local ok, by = pcall(select, 3, ...)
            local interrupted = false
            if ok then
                local ok2, res = pcall(function() return by ~= nil end)
                interrupted = ok2 and res
            end
            if interrupted then
                Resolve(f, true)
            else
                f.pendingEnd, f.pendingKind = GetTime() + 0.15, "notint"
            end
        end
    end
end)

local eventList = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "RAID_TARGET_UPDATE", "PLAYER_ENTERING_WORLD",
}
local eventsOn = false

local function SetEvents(on)
    if on == eventsOn then return end
    eventsOn = on
    anchor:UnregisterAllEvents()
    if not on then return end
    for _, e in ipairs(eventList) do
        local ok = pcall(anchor.RegisterEvent, anchor, e)
        if not ok then print(PREFIX .. "evento no disponible: " .. e) end
    end
end

---------------------------------------------------------------------------
-- Actualización por frame
---------------------------------------------------------------------------

local function OnUpdate()
    local now = GetTime()
    for i = #active, 1, -1 do
        local f = active[i]
        if f.result then
            if f.announceAt and now >= f.announceAt then Announce(f) end
            if now >= f.resultUntil then Release(f) end
        elseif f.pendingEnd then
            if now >= f.pendingEnd then
                if f.pendingKind == "release" or IsDead(f.unit) then Release(f) else Resolve(f, false) end
            end
        elseif f.mode == "classic" then
            local remaining = f.finish - now
            if remaining < -1.5 then
                Release(f)   -- no llegó evento de cierre
            else
                if remaining < 0 then remaining = 0 end
                f.bar:SetValue(f.channel and remaining or (now - f.start))
                f.timeText:SetText(string.format("%.1f", remaining))
            end
        end
    end
end

---------------------------------------------------------------------------
-- Aplicar configuración
---------------------------------------------------------------------------

function Marked.Apply()
    local c = cfg()
    ns.MakeMovable(anchor, c)
    ns.ApplyPosition(anchor, c)
    ns.ApplyLockVisuals(anchor, c)
    anchor:SetSize(c.width, c.height)
    anchor:SetAlpha(c.alpha)

    for _, f in ipairs(pool) do StyleBar(f) end

    if c.enabled then
        SetEvents(true)
        anchor:SetScript("OnUpdate", OnUpdate)
        ClearPreview()
        Layout()
        ScanAll()
    else
        SetEvents(false)
        anchor:SetScript("OnUpdate", nil)
        ReleaseAll()
        ClearPreview()
    end
end
