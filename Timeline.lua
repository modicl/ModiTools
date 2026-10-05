-- Herramienta: línea de tiempo de cooldowns.
--
-- Una línea (horizontal o vertical) en la que los hechizos que elijas se acercan al "ahora"
-- a medida que su cooldown está por terminar, al estilo de la línea de tiempo de jefes de Blizzard.
-- La línea aparece cuando a algún cooldown le quedan N segundos o menos.
--
-- Los cooldowns se leen del juego. Si el cliente los oculta (valores secretos en combate), al lanzar
-- el hechizo se estima el fin con su cooldown base.

local _, ns = ...
local PREFIX = ns.PREFIX
local L = ns.L

local MAX_SPELLS = 12
local MAX_TICKS = 13
local QUESTION = "Interface/Icons/INV_Misc_QuestionMark"

local defaults = {
    enabled = true, unlocked = false,
    point = "CENTER", x = 0, y = -320,
    spells = {},            -- spellIDs que se muestran
    window = 30,            -- segundos: la línea aparece cuando a un cooldown le quedan N o menos
    minCooldown = 2,        -- se ignoran cooldowns más cortos (GCD)
    alwaysShow = false,     -- mostrar la línea aunque no haya nada cerca
    combatOnly = false,     -- mostrar la línea (y sus sonidos) solo en combate
    orientation = "H",      -- "H" horizontal | "V" vertical
    reverse = false,        -- H: el "ahora" queda a la derecha. V: arriba.
    length = 420, thickness = 10, iconSize = 32, alpha = 1, fontSize = 11,
    showTime = true, showTicks = true, showNow = true, flashReady = true, iconBorder = true,
    colorLine = { 0.08, 0.08, 0.1, 0.75 },
    colorTick = { 1, 1, 1, 0.55 },
    colorNow = { 1, 0.82, 0, 1 },
    colorBorder = { 0, 0, 0, 1 },
    font = "default",
    soundWarn = false, soundWarnKey = "alarm", warnAt = 5,   -- aviso al quedar N segundos
    soundReady = false, soundReadyKey = "ready",             -- sonido al estar listo
    soundCustom = "",       -- soundkit ID o ruta de archivo, usado con la opción "Personalizado"
    spellSounds = {},       -- [spellID] = { warn = clave, ready = clave, warnAt = segundos }
}

local Timeline = {}
ns.RegisterModule("timeline", defaults, Timeline)

local function cfg() return ns.db.timeline end

---------------------------------------------------------------------------
-- Información de hechizos
---------------------------------------------------------------------------

function Timeline.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end

function Timeline.SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

-- Cooldown de un hechizo: devuelve el momento en que termina y su duración, o nil.
local function ReadSpellCooldown(id)
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(id)
        if info then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(id)
    end

    -- hechizos con cargas: cuenta lo que falta para recuperar una carga
    if C_Spell and C_Spell.GetSpellCharges then
        local ch = C_Spell.GetSpellCharges(id)
        if ch and ch.maxCharges and ch.maxCharges > 1 and ch.currentCharges < ch.maxCharges then
            start, duration = ch.cooldownStartTime, ch.cooldownDuration
        end
    end

    if start and duration and duration > 0 and start > 0 then
        return start + duration, duration
    end
    return nil, 0
end

---------------------------------------------------------------------------
-- Objetos (pociones y trinkets): se guardan en la lista como ID negativo (-itemID)
---------------------------------------------------------------------------

local itemSpellCache = {}

-- Hechizo de uso del objeto (el que se lanza al usarlo), o nil.
local function ItemUseSpell(itemID)
    if itemSpellCache[itemID] ~= nil then return itemSpellCache[itemID] or nil end
    local fn = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    local spellID
    if fn then
        local ok, _, id = pcall(fn, itemID)
        if ok then spellID = id end
    end
    itemSpellCache[itemID] = spellID or false
    return spellID
end

local function IsValidItem(itemID)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return false end
    local ok, id = pcall(fn, itemID)
    return ok and id ~= nil
end

function Timeline.EntryName(id)
    if id > 0 then return Timeline.SpellName(id) end
    local itemID = -id
    local fn = (C_Item and C_Item.GetItemNameByID) or nil
    local name = fn and fn(itemID)
    if not name then
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if info then
            local ok, n = pcall(info, itemID)
            if ok and type(n) == "string" then name = n end
        end
    end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)   -- el nombre llega después (GET_ITEM_INFO_RECEIVED)
    end
    return name
end

function Timeline.EntryIcon(id)
    if id > 0 then return Timeline.SpellIcon(id) end
    local itemID = -id
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID) end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if fn then
        local ok, _, _, _, _, icon = pcall(fn, itemID)
        if ok then return icon end
    end
end

local function ReadItemCooldown(itemID)
    local fn = (C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not fn then return nil, 0 end
    local a, b = fn(itemID)
    local start, duration = a, b
    if type(a) == "table" then start, duration = a.startTime or a.start, a.duration end
    if start and duration and duration > 0 and start > 0 then
        return start + duration, duration
    end
    return nil, 0
end

-- Cooldown de una entrada de la lista (hechizo si el ID es positivo, objeto si es negativo).
local function ReadCooldown(id)
    if id > 0 then return ReadSpellCooldown(id) end
    local itemID = -id
    local expiration, duration = ReadItemCooldown(itemID)
    if expiration then return expiration, duration end
    -- si el objeto ya no está en las bolsas, su hechizo de uso conserva el cooldown
    local spellID = ItemUseSpell(itemID)
    if spellID then return ReadSpellCooldown(spellID) end
    return nil, 0
end

local function BaseCooldown(id)
    local fn = (C_Spell and C_Spell.GetSpellBaseCooldown) or GetSpellBaseCooldown
    if not fn then return nil end
    local ok, ms = pcall(fn, id)
    if ok and type(ms) == "number" and ms > 0 then return ms / 1000 end
    return nil
end

---------------------------------------------------------------------------
-- Marcos
---------------------------------------------------------------------------

local root = CreateFrame("Frame", "ModiToolsTimelineFrame", UIParent)
root:SetFrameStrata("HIGH")

local lineBG = root:CreateTexture(nil, "BACKGROUND")
lineBG:SetAllPoints()

local border = CreateFrame("Frame", nil, root, "BackdropTemplate")
border:SetAllPoints()
border:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })

local nowMarker = root:CreateTexture(nil, "ARTWORK")

local ticks, tickLabels = {}, {}
for i = 1, MAX_TICKS do
    ticks[i] = root:CreateTexture(nil, "ARTWORK")
    tickLabels[i] = root:CreateFontString(nil, "OVERLAY")
    ticks[i]:Hide()
    tickLabels[i]:Hide()
end

local icons = {}
local function CreateIcon()
    local f = CreateFrame("Frame", nil, root)
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetPoint("TOPLEFT", -4, 4)
    f.glow:SetPoint("BOTTOMRIGHT", 4, -4)
    f.glow:SetColorTexture(1, 0.82, 0, 0.6)
    f.glow:Hide()
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetAllPoints()
    f.border:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1 })
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("BOTTOM", 0, 2)
    f:Hide()
    return f
end
for i = 1, MAX_SPELLS do icons[i] = CreateIcon() end

---------------------------------------------------------------------------
-- Estado de los cooldowns
---------------------------------------------------------------------------

local state = {}       -- [spellID] = { expiration, duration, estimated, readyUntil, icon }
local castAt = {}      -- [spellID] = momento en que se lanzó (para estimar si los datos están ocultos)
local dirty = true
local inCombat = false
local polled = 0

local function Track(id)
    local e = state[id]
    if not e then
        e = {}
        state[id] = e
    end
    e.icon = Timeline.EntryIcon(id)
    if id < 0 then e.useSpell = ItemUseSpell(-id) end
    return e
end

---------------------------------------------------------------------------
-- Sonidos: global o independiente por hechizo
---------------------------------------------------------------------------

-- Segundos restantes a los que suena el aviso (el del hechizo, si lo tiene; si no, el global).
local function WarnAt(id)
    local c = cfg()
    local own = c.spellSounds[id]
    return (own and own.warnAt) or c.warnAt
end

-- Sonido a reproducir. "none" silencia ese hechizo; "global" (o nada) usa el compartido.
local function SoundKeyFor(id, kind)
    local c = cfg()
    local own = c.spellSounds[id]
    local key = own and own[kind]
    if key == "none" then return nil end
    if key and key ~= "global" then return key end
    if kind == "warn" then return c.soundWarn and c.soundWarnKey or nil end
    return c.soundReady and c.soundReadyKey or nil
end

local function PlayFor(id, kind)
    -- con "solo en combate" los sonidos también se silencian fuera de combate
    if cfg().combatOnly and not inCombat then return end
    local key = SoundKeyFor(id, kind)
    if key then ns.PlaySoundKey(key, cfg().soundCustom) end
end

-- El cooldown terminó: destello y sonido de "listo".
local function MarkReady(id, e, now)
    if cfg().flashReady then e.readyUntil = now + 1 end
    PlayFor(id, "ready")
end

local function Poll()
    local c = cfg()
    local now = GetTime()
    for _, id in ipairs(c.spells) do
        local e = state[id] or Track(id)
        local ok, expiration, duration = pcall(ReadCooldown, id)
        if ok then
            if expiration and duration >= c.minCooldown and expiration > now then
                if not e.expiration then
                    -- cooldown nuevo: si ya va por debajo del aviso, no suena
                    e.warned = (expiration - now) <= WarnAt(id)
                end
                e.expiration, e.duration, e.estimated = expiration, duration, false
            elseif e.expiration and not e.estimated then
                -- terminó solo ("listo") o antes de tiempo por un reset (sin destello ni sonido)
                if e.expiration <= now + 0.3 then MarkReady(id, e, now) end
                e.expiration = nil
            end
        elseif castAt[id] and now - castAt[id] < 1 and not e.expiration then
            -- los datos están ocultos: se estima con el cooldown base
            local base = BaseCooldown(id > 0 and id or e.useSpell)
            if base and base >= c.minCooldown then
                e.expiration, e.duration, e.estimated = castAt[id] + base, base, true
                e.warned = false
            end
        end
    end
end

---------------------------------------------------------------------------
-- Estilo y marcas
---------------------------------------------------------------------------

-- Fuente elegida por el usuario; si no existe en el cliente se usa la predeterminada.
local function SetFont(fontString, size)
    local ok = pcall(fontString.SetFont, fontString, ns.FontPath(cfg().font), size, "OUTLINE")
    if not ok then fontString:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
end

---------------------------------------------------------------------------
-- (marcas)
---------------------------------------------------------------------------

local function IsHorizontal() return cfg().orientation ~= "V" end

local function StyleTicks()
    local c = cfg()
    local horizontal = IsHorizontal()
    local step = (c.window <= 20 and 5) or (c.window <= 60 and 10) or 30
    local n = 0
    local t = step
    while t <= c.window and n < MAX_TICKS do
        n = n + 1
        local pos = (t / c.window) * c.length
        local tick, label = ticks[n], tickLabels[n]
        tick:SetColorTexture(c.colorTick[1], c.colorTick[2], c.colorTick[3], c.colorTick[4] or 1)
        SetFont(label, math.max(8, c.fontSize - 1))
        label:SetTextColor(c.colorTick[1], c.colorTick[2], c.colorTick[3], 1)
        label:SetText(t .. "s")
        tick:ClearAllPoints()
        label:ClearAllPoints()
        if horizontal then
            tick:SetSize(1, c.thickness + 6)
            tick:SetPoint("CENTER", root, c.reverse and "RIGHT" or "LEFT", c.reverse and -pos or pos, 0)
            label:SetPoint("TOP", tick, "BOTTOM", 0, -1)
        else
            tick:SetSize(c.thickness + 6, 1)
            tick:SetPoint("CENTER", root, c.reverse and "TOP" or "BOTTOM", 0, c.reverse and -pos or pos)
            label:SetPoint("LEFT", tick, "RIGHT", 2, 0)
        end
        tick:SetShown(c.showTicks)
        label:SetShown(c.showTicks)
        t = t + step
    end
    for i = n + 1, MAX_TICKS do
        ticks[i]:Hide()
        tickLabels[i]:Hide()
    end
end

local function StyleAll()
    local c = cfg()
    local horizontal = IsHorizontal()
    root:SetSize(horizontal and c.length or c.thickness, horizontal and c.thickness or c.length)
    root:SetAlpha(c.alpha)
    lineBG:SetColorTexture(c.colorLine[1], c.colorLine[2], c.colorLine[3], c.colorLine[4] or 1)
    border:SetBackdropBorderColor(c.colorBorder[1], c.colorBorder[2], c.colorBorder[3], c.colorBorder[4] or 1)

    -- marcador de "ahora"
    nowMarker:SetColorTexture(c.colorNow[1], c.colorNow[2], c.colorNow[3], c.colorNow[4] or 1)
    nowMarker:ClearAllPoints()
    if horizontal then
        nowMarker:SetSize(3, c.thickness + 10)
        nowMarker:SetPoint("CENTER", root, c.reverse and "RIGHT" or "LEFT", 0, 0)
    else
        nowMarker:SetSize(c.thickness + 10, 3)
        nowMarker:SetPoint("CENTER", root, c.reverse and "TOP" or "BOTTOM", 0, 0)
    end
    nowMarker:SetShown(c.showNow)

    for _, f in ipairs(icons) do
        f:SetSize(c.iconSize, c.iconSize)
        f.border:SetShown(c.iconBorder)
        f.border:SetBackdropBorderColor(c.colorBorder[1], c.colorBorder[2], c.colorBorder[3], c.colorBorder[4] or 1)
        SetFont(f.text, c.fontSize)
    end
    StyleTicks()
end

---------------------------------------------------------------------------
-- Dibujo
---------------------------------------------------------------------------

local function FormatTime(t)
    if t >= 60 then
        return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
    elseif t >= 10 then
        return string.format("%d", math.floor(t))
    end
    return string.format("%.1f", t)
end

-- Elementos de ejemplo mientras la línea está desbloqueada y no hay cooldowns reales.
local function PreviewItems(now)
    local c = cfg()
    local items = {}
    for i = 1, 3 do
        -- segundos RESTANTES: bajan con el tiempo, así los íconos avanzan hacia el "ahora"
        local r = c.window - ((now * 1.5 + i * c.window / 3.2) % c.window)
        items[i] = { r = r, icon = QUESTION }
    end
    return items
end
Timeline.PreviewItems = PreviewItems

local function Render()
    local c = cfg()
    local now = GetTime()
    local horizontal = IsHorizontal()

    local items = {}
    for _, id in ipairs(c.spells) do
        local e = state[id]
        if e then
            if e.expiration and now >= e.expiration then
                e.expiration = nil
                MarkReady(id, e, now)
            end
            if e.expiration then
                local r = e.expiration - now
                if not e.warned then
                    local at = WarnAt(id)
                    if at > 0 and r <= at then
                        e.warned = true
                        PlayFor(id, "warn")
                    end
                end
                if r <= c.window then items[#items + 1] = { r = r, icon = e.icon } end
            elseif e.readyUntil and now < e.readyUntil then
                items[#items + 1] = { r = 0, icon = e.icon, ready = true }
            end
        end
    end
    -- "solo en combate": se oculta el dibujo (y PlayFor silencia los sonidos); el seguimiento sigue
    if c.combatOnly and not inCombat and not c.unlocked then
        root:Hide()
        return
    end
    if #items == 0 and c.unlocked then items = PreviewItems(now) end

    local show = #items > 0 or c.alwaysShow or c.unlocked
    root:SetShown(show)
    if not show then return end

    table.sort(items, function(a, b) return a.r < b.r end)

    local lanePos = {}
    local gap = c.iconSize + 2
    for i = 1, MAX_SPELLS do
        local f, item = icons[i], items[i]
        if not item then
            f:Hide()
        else
            local frac = math.min(1, math.max(0, item.r / c.window))
            local pos = frac * c.length

            -- si dos íconos se pisan, el segundo pasa a otra fila (centro, arriba, abajo)
            local lane = 3
            for l = 0, 2 do
                if lanePos[l] == nil or pos - lanePos[l] >= gap then lane = l break end
            end
            lane = math.min(lane, 2)
            lanePos[lane] = pos
            local perp = (lane == 0 and 0) or (lane == 1 and gap) or -gap

            f:ClearAllPoints()
            if horizontal then
                f:SetPoint("CENTER", root, c.reverse and "RIGHT" or "LEFT", c.reverse and -pos or pos, perp)
            else
                f:SetPoint("CENTER", root, c.reverse and "TOP" or "BOTTOM", perp, c.reverse and -pos or pos)
            end

            f.tex:SetTexture(item.icon or QUESTION)
            if item.ready then
                f.text:SetText("")
                f.glow:Show()
                f.glow:SetAlpha(0.5 + 0.5 * math.sin(now * 14))
            else
                f.glow:Hide()
                f.text:SetText(c.showTime and FormatTime(item.r) or "")
            end
            f:Show()
        end
    end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local driver = CreateFrame("Frame")

driver:SetScript("OnUpdate", function(_, dt)
    if not cfg().enabled then return end
    polled = polled + dt
    if dirty or polled >= 0.1 then
        dirty, polled = false, 0
        Poll()
    end
    Render()
end)

driver:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and spellID then
            local now = GetTime()
            castAt[spellID] = now
            for _, id in ipairs(cfg().spells) do
                local e = state[id]
                if id < 0 and e and e.useSpell == spellID then castAt[id] = now end
            end
        end
    elseif event == "SPELLS_CHANGED" or event == "GET_ITEM_INFO_RECEIVED" then
        for _, id in ipairs(cfg().spells) do Track(id) end
        if event == "GET_ITEM_INFO_RECEIVED" and ns.RefreshOptions then ns.RefreshOptions() end
    end
    dirty = true
end)

local eventsOn = false
local function SetEvents(on)
    if on == eventsOn then return end
    eventsOn = on
    driver:UnregisterAllEvents()
    if not on then return end
    for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD",
      "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" }) do
        local ok = pcall(driver.RegisterEvent, driver, e)
        if not ok then print(PREFIX .. string.format(L["Event not available: %s"], e)) end
    end
    local ok = pcall(driver.RegisterUnitEvent, driver, "UNIT_SPELLCAST_SUCCEEDED", "player")
    if not ok then print(PREFIX .. string.format(L["Event not available: %s"], "UNIT_SPELLCAST_SUCCEEDED")) end
end

---------------------------------------------------------------------------
-- Lista de hechizos
---------------------------------------------------------------------------

local function IndexOf(id)
    for i, v in ipairs(cfg().spells) do
        if v == id then return i end
    end
end

-- Agrega una entrada: ID positivo = hechizo, ID negativo = objeto. Devuelve ok, mensaje.
function Timeline.AddEntry(id)
    id = tonumber(id)
    if not id or id == 0 then return false, L["Invalid spell ID."] end
    local isItem = id < 0
    local valid = isItem and IsValidItem(-id) or (not isItem and Timeline.SpellName(id) ~= nil)
    if not valid then return false, isItem and L["Invalid item ID."] or L["Invalid spell ID."] end
    local list = cfg().spells
    if IndexOf(id) then return false, L["That spell is already on the list."] end
    if #list >= MAX_SPELLS then return false, string.format(L["The list is full (%d entries)."], MAX_SPELLS) end
    list[#list + 1] = id
    Track(id)
    dirty = true
    if ns.RefreshOptions then ns.RefreshOptions() end
    local name = Timeline.EntryName(id) or ("#" .. math.abs(id))
    return true, string.format(isItem and L["Item '%s' added."] or L["Spell '%s' added."], name)
end

function Timeline.AddSpell(id)
    id = tonumber(id)
    return Timeline.AddEntry(id and math.abs(id))
end

function Timeline.AddItem(id)
    id = tonumber(id)
    return Timeline.AddEntry(id and -math.abs(id))
end

function Timeline.RemoveEntry(id)
    id = tonumber(id)
    local i = id and IndexOf(id)
    if not i then return false, L["Invalid spell ID."] end
    table.remove(cfg().spells, i)
    cfg().spellSounds[id] = nil
    state[id] = nil
    dirty = true
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true, L["Removed from the timeline."]
end

function Timeline.RemoveSpell(id)
    id = tonumber(id)
    return Timeline.RemoveEntry(id and math.abs(id))
end

function Timeline.RemoveItem(id)
    id = tonumber(id)
    return Timeline.RemoveEntry(id and -math.abs(id))
end

---------------------------------------------------------------------------
-- Detección de los hechizos de la clase
---------------------------------------------------------------------------

Timeline.MaxSpells = MAX_SPELLS

function Timeline.IsTracked(id)
    return IndexOf(id) ~= nil
end

local function IsKnownSpell(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return IsSpellKnown and IsSpellKnown(id) or false
end

local function IsPassive(id)
    if C_Spell and C_Spell.IsSpellPassive then return C_Spell.IsSpellPassive(id) end
    return IsPassiveSpell and IsPassiveSpell(id) or false
end

local function HasCharges(id)
    if not (C_Spell and C_Spell.GetSpellCharges) then return false end
    local ch = C_Spell.GetSpellCharges(id)
    return ch and ch.maxCharges and ch.maxCharges > 1 or false
end

-- Lee el libro de hechizos y devuelve los activos con cooldown: { id, name, icon, cd }.
-- Ordenados de mayor a menor cooldown (los cooldowns grandes primero).
function Timeline.ScanSpells()
    local list, seen = {}, {}
    local minCD = 3   -- segundos; los hechizos sin cooldown propio no sirven en la línea

    local function Consider(id)
        if type(id) ~= "number" or seen[id] then return end
        seen[id] = true
        local ok, name, cd, charges = pcall(function()
            if not IsKnownSpell(id) or IsPassive(id) then return nil end
            return Timeline.SpellName(id), BaseCooldown(id), HasCharges(id)
        end)
        if not ok or not name then return end
        if (cd and cd >= minCD) or charges then
            list[#list + 1] = { id = id, name = name, icon = Timeline.SpellIcon(id), cd = cd, kind = "spell" }
        end
    end

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local spellType = (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) or 1
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.offSpecID and not info.isGuild then
                for i = 1, info.numSpellBookItems or 0 do
                    local item = C_SpellBook.GetSpellBookItemInfo(info.itemIndexOffset + i, bank)
                    if item and item.itemType == spellType and not item.isOffSpec then
                        Consider(item.spellID or item.actionID)
                    end
                end
            end
        end
    elseif GetNumSpellTabs then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for i = offset + 1, offset + count do
                local kind, id = GetSpellBookItemInfo(i, "spell")
                if kind == "SPELL" then Consider(id) end
            end
        end
    end

    table.sort(list, function(a, b)
        if (a.cd or 0) ~= (b.cd or 0) then return (a.cd or 0) > (b.cd or 0) end
        return a.name < b.name
    end)
    return list
end


-- Hechizos de la clase + trinkets equipados con efecto de uso + pociones de las bolsas.
-- Cada entrada: { id (negativo si es objeto), name, icon, cd, kind = "spell" | "trinket" | "potion" }.
function Timeline.ScanEntries()
    local list = Timeline.ScanSpells()

    -- trinkets equipados (ranuras 13 y 14) que se pueden usar
    for _, slot in ipairs({ 13, 14 }) do
        local ok = pcall(function()
            local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
            local useSpell = itemID and ItemUseSpell(itemID)
            if useSpell then
                list[#list + 1] = {
                    id = -itemID, kind = "trinket", cd = BaseCooldown(useSpell),
                    name = Timeline.EntryName(-itemID) or ("Item " .. itemID), icon = Timeline.EntryIcon(-itemID),
                }
            end
        end)
        if not ok then break end
    end

    -- pociones en las bolsas (consumibles de tipo poción con efecto de uso)
    local potions, seen = {}, {}
    pcall(function()
        local getSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
        local getItem = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
        local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if not (getSlots and getItem and instant) then return end
        for bag = 0, (NUM_BAG_SLOTS or 4) + 1 do
            for slot = 1, (getSlots(bag) or 0) do
                local itemID = getItem(bag, slot)
                if itemID and not seen[itemID] then
                    seen[itemID] = true
                    local _, _, _, _, _, classID, subClassID = instant(itemID)
                    local useSpell = (classID == 0 and subClassID == 1) and ItemUseSpell(itemID)
                    if useSpell then
                        potions[#potions + 1] = {
                            id = -itemID, kind = "potion", cd = BaseCooldown(useSpell),
                            name = Timeline.EntryName(-itemID) or ("Item " .. itemID), icon = Timeline.EntryIcon(-itemID),
                        }
                    end
                end
            end
        end
    end)
    table.sort(potions, function(a, b) return a.name < b.name end)
    for _, p in ipairs(potions) do list[#list + 1] = p end
    return list
end

---------------------------------------------------------------------------
-- Aplicar configuración
---------------------------------------------------------------------------

function Timeline.Apply()
    local c = cfg()
    ns.MakeMovable(root, c)
    ns.ApplyPosition(root, c)
    ns.ApplyLockVisuals(root, c)
    StyleAll()
    inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    for _, id in ipairs(c.spells) do Track(id) end
    SetEvents(c.enabled)
    dirty = true
    if not c.enabled then
        root:Hide()
        for _, f in ipairs(icons) do f:Hide() end
    end
end

function Timeline.Slash(arg)
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    if cmd == "add" then
        local _, msg = Timeline.AddSpell(rest)
        print(PREFIX .. msg)
    elseif cmd == "remove" then
        local _, msg = Timeline.RemoveSpell(rest)
        print(PREFIX .. msg)
    elseif cmd == "additem" then
        local _, msg = Timeline.AddItem(rest)
        print(PREFIX .. msg)
    elseif cmd == "removeitem" then
        local _, msg = Timeline.RemoveItem(rest)
        print(PREFIX .. msg)
    elseif cmd == "pick" then
        if ns.OpenSpellPicker then ns.OpenSpellPicker() end
    elseif cmd == "sound" and rest ~= "" then
        cfg().soundCustom = rest
        print(PREFIX .. string.format(L["Custom sound: %s"], rest))
        ns.PlaySoundKey("custom", rest)
    elseif cmd == "list" then
        local names = {}
        for _, id in ipairs(cfg().spells) do
            names[#names + 1] = (Timeline.EntryName(id) or "?") .. " (" .. (id < 0 and ("item " .. -id) or id) .. ")"
        end
        print(PREFIX .. string.format(L["On the timeline: %s"], #names > 0 and table.concat(names, ", ") or "-"))
    else
        print(PREFIX .. L["Usage: /modi timeline pick | add <spellID> | addItem <itemID> | remove <spellID> | removeItem <itemID> | list | sound <soundkitID or file path>"])
    end
end
