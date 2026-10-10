-- Herramienta: debuffs del otro tank. Íconos con stacks, tiempo restante y tooltip de los debuffs que tiene
-- el otro tank del grupo/raid, con lista blanca, cuadrícula configurable y glow opcional.
--
-- Midnight: en combate y contenido restringido el juego devuelve los datos de los auras como valores "secretos"
-- (no se pueden comparar ni usar en un `if`, solo pasarlos a widgets). Por eso aquí:
--   * los auras se piden por ID de instancia (C_UnitAuras.GetUnitAuraInstanceIDs) y se dibujan directo:
--     textura, stacks (GetAuraApplicationDisplayCount) y tiempo (GetAuraDuration -> Cooldown) van a los widgets;
--   * la lista blanca usa GetUnitAuraBySpellID, que solo responde cuando el juego permite leer ese aura;
--   * todo se actualiza por eventos (UNIT_AURA de la unidad seguida), sin OnUpdate.

local _, ns = ...
local PREFIX = ns.PREFIX
local L = ns.L
local Secrets = ns.Secrets

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local MAX_ICONS = 24
local MAX_LIST = 40

local defaults = {
    enabled = false, unlocked = false,
    point = "CENTER", x = -320, y = 0,
    tankName = "",                 -- vacío = el primer otro tank del grupo
    mode = "all",                  -- all = todos los debuffs | whitelist = solo la lista
    sort = "default",              -- default | expiration | name | none
    maxAuras = 8, columns = 4, rows = 2,
    iconSize = 40, spacing = 4, grow = "RIGHT_DOWN", alpha = 1,
    showStacks = true, stackSize = 16, stackMin = 2,
    showTimer = true, showSwirl = true,
    showBorder = true, dispelBorder = true, tooltip = true,
    colorBorder = { 0.75, 0.1, 0.1, 1 },
    colorStack = { 1, 1, 1, 1 },
    glow = false, glowStyle = "pixel", glowMinStacks = 0,
    colorGlow = { 1, 0.82, 0, 1 },
    spells = {},                   -- lista blanca (spellIDs)
}

local TankDebuffs = {}
ns.RegisterModule("tankdebuffs", defaults, TankDebuffs)

local function cfg() return ns.db.tankdebuffs end

local function Readable(v)
    return not (issecretvalue and issecretvalue(v))
end

---------------------------------------------------------------------------
-- Marcos
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "ModiToolsTankDebuffsFrame", UIParent)
frame:SetFrameStrata("MEDIUM")
frame:SetSize(100, 40)

local icons = {}

local function ShowTooltip(self)
    local c = cfg()
    if not c.tooltip or not self.auraID or not self.unit then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = false
    if GameTooltip.SetUnitDebuffByAuraInstanceID then
        ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, self.unit, self.auraID)
    end
    if not ok and GameTooltip.SetUnitAuraByAuraInstanceID then
        ok = pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self.unit, self.auraID)
    end
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

local function CreateIcon()
    local f = CreateFrame("Frame", nil, frame)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints()
    f.border:SetColorTexture(1, 1, 1, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetDrawEdge(false)
    f.top = CreateFrame("Frame", nil, f)
    f.top:SetAllPoints()
    f.top:SetFrameLevel(f.cooldown:GetFrameLevel() + 2)
    f.stack = f.top:CreateFontString(nil, "OVERLAY")
    f.stack:SetPoint("BOTTOMRIGHT", -2, 2)
    f.glow = ns.Glow.Create(f, 3)
    f.glow:Hide()
    f:SetScript("OnEnter", ShowTooltip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    return f
end

local PlaceIcon   -- (definida más abajo: estilo y posición de un ícono)

local function GetIcon(i)
    local f = icons[i]
    if not f then
        f = CreateIcon()
        icons[i] = f
        PlaceIcon(f, i)
    end
    return f
end

---------------------------------------------------------------------------
-- Estilo y posición de los íconos
---------------------------------------------------------------------------

local GROW = {
    RIGHT_DOWN = { "TOPLEFT", 1, -1 },
    LEFT_DOWN = { "TOPRIGHT", -1, -1 },
    RIGHT_UP = { "BOTTOMLEFT", 1, 1 },
    LEFT_UP = { "BOTTOMRIGHT", -1, 1 },
}

local function Shown()
    local c = cfg()
    return math.max(1, math.min(c.maxAuras, c.columns * c.rows, MAX_ICONS))
end

local function StyleIcon(f)
    local c = cfg()
    local bt = c.showBorder and 2 or 0
    f:SetSize(c.iconSize, c.iconSize)
    f.border:SetShown(c.showBorder)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", bt, -bt)
    f.icon:SetPoint("BOTTOMRIGHT", -bt, bt)
    f.cooldown:SetHideCountdownNumbers(not c.showTimer)
    f.cooldown:SetDrawSwipe(c.showSwirl)
    f.stack:SetFont(STANDARD_TEXT_FONT, c.stackSize, "OUTLINE")
    f.stack:SetTextColor(c.colorStack[1], c.colorStack[2], c.colorStack[3], c.colorStack[4] or 1)
    f.glow:SetStyle(c.glowStyle)
    f.glow:SetGlowColor(c.colorGlow[1], c.colorGlow[2], c.colorGlow[3])
    f:EnableMouse(c.tooltip and not c.unlocked)
end

PlaceIcon = function(f, i)
    local c = cfg()
    local g = GROW[c.grow] or GROW.RIGHT_DOWN
    local step = c.iconSize + c.spacing
    local col = (i - 1) % c.columns
    local row = math.floor((i - 1) / c.columns)
    StyleIcon(f)
    f:ClearAllPoints()
    f:SetPoint(g[1], frame, g[1], g[2] * col * step, g[3] * row * step)
end

-- Tamaño del contenedor y reposición de los íconos que ya existen (los demás se crean al necesitarlos).
local function Layout()
    local c = cfg()
    local n = Shown()
    local cols = math.min(c.columns, n)
    local rows = math.ceil(n / c.columns)
    local step = c.iconSize + c.spacing
    frame:SetSize(cols * step - c.spacing, rows * step - c.spacing)
    frame:SetAlpha(c.alpha)
    for i, f in ipairs(icons) do PlaceIcon(f, i) end
end

---------------------------------------------------------------------------
-- Colores del borde según el tipo de debuff
---------------------------------------------------------------------------

local DISPEL_COLORS = {
    Magic = { 0.2, 0.6, 1 }, Curse = { 0.65, 0.2, 1 }, Disease = { 0.65, 0.45, 0.1 },
    Poison = { 0.1, 0.7, 0.2 }, Bleed = { 1, 0.25, 0.25 },
}

local dispelCurve, curveTried
local function GetCurve()
    if curveTried then return dispelCurve end
    curveTried = true
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        c:SetType(Enum.LuaCurveType.Step)
        local D = Enum.DispelType
        local function add(t, rgb) c:AddPoint(t, CreateColor(rgb[1], rgb[2], rgb[3], 1)) end
        add(D.None or 0, { 0.75, 0.1, 0.1 })
        add(D.Magic, DISPEL_COLORS.Magic)
        add(D.Curse, DISPEL_COLORS.Curse)
        add(D.Disease, DISPEL_COLORS.Disease)
        add(D.Poison, DISPEL_COLORS.Poison)
        if D.Bleed then add(D.Bleed, DISPEL_COLORS.Bleed) end
        return c
    end)
    if ok then dispelCurve = curve end
    return dispelCurve
end

local function PaintBorder(f, unit, id, aura)
    local c = cfg()
    if not c.showBorder then return end
    local col = c.colorBorder
    if c.dispelBorder then
        local curve = GetCurve()
        if curve and C_UnitAuras.GetAuraDispelTypeColor then
            local ok, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, id, curve)
            if ok and color and pcall(function() f.border:SetVertexColor(color:GetRGBA()) end) then return end
        end
        if aura and Readable(aura.dispelName) and aura.dispelName and DISPEL_COLORS[aura.dispelName] then
            local d = DISPEL_COLORS[aura.dispelName]
            f.border:SetVertexColor(d[1], d[2], d[3], 1)
            return
        end
    end
    f.border:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
end

---------------------------------------------------------------------------
-- Datos del aura -> widgets (nada de comparaciones con valores secretos)
---------------------------------------------------------------------------

local function Fill(f, unit, id)
    local c = cfg()
    f.unit, f.auraID = unit, id
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
    if not ok then aura = nil end

    if aura then pcall(f.icon.SetTexture, f.icon, aura.icon) else f.icon:SetTexture(QUESTION) end

    -- stacks: el juego da el texto ya formateado (vacío si hay menos de stackMin)
    if c.showStacks and C_UnitAuras.GetAuraApplicationDisplayCount then
        local okS, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, c.stackMin)
        if okS then pcall(f.stack.SetText, f.stack, text) else f.stack:SetText("") end
    else
        f.stack:SetText("")
    end

    -- tiempo: objeto de duración directo al Cooldown; si no existe la API, valores numéricos legibles
    local done = false
    if C_UnitAuras.GetAuraDuration and f.cooldown.SetCooldownFromDurationObject then
        local okD, dur = pcall(C_UnitAuras.GetAuraDuration, unit, id)
        if okD and dur then done = pcall(f.cooldown.SetCooldownFromDurationObject, f.cooldown, dur) end
    end
    if not done then
        local e, d = aura and aura.expirationTime, aura and aura.duration
        if e and d and Readable(e) and Readable(d) and d > 0 then
            f.cooldown:SetCooldown(e - d, d)
        else
            f.cooldown:Clear()
        end
    end

    PaintBorder(f, unit, id, aura)

    -- glow: con mínimo de stacks solo se puede decidir si el dato es legible
    local glow = c.glow
    if glow and c.glowMinStacks > 0 then
        local apps = aura and aura.applications
        glow = Readable(apps) and apps ~= nil and apps >= c.glowMinStacks
    end
    f.glow:SetShown(glow and true or false)
    f:Show()
end

local SAMPLE_ICONS = {
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Ability_Warrior_Sunder",
    "Interface\\Icons\\Spell_Fire_Immolation", "Interface\\Icons\\Ability_Rogue_Rupture",
    "Interface\\Icons\\Spell_Shadow_CurseOfTounges", "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_Excorcism",
}

local function FillSample(f, i)
    local c = cfg()
    f.unit, f.auraID = nil, nil
    f.icon:SetTexture(SAMPLE_ICONS[(i - 1) % #SAMPLE_ICONS + 1])
    local stacks = (i * 2) % 5 + 1
    f.stack:SetText((c.showStacks and stacks >= c.stackMin) and tostring(stacks) or "")
    f.cooldown:SetCooldown(GetTime() - i * 2, 20)
    local col = c.colorBorder
    f.border:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    f.glow:SetShown(c.glow and (c.glowMinStacks <= 0 or stacks >= c.glowMinStacks) or false)
    f:Show()
end

---------------------------------------------------------------------------
-- Tank seguido y lista de auras
---------------------------------------------------------------------------

local trackedUnit

-- Primer otro tank del grupo (o el que tenga el nombre indicado).
local function FindTank()
    local want = cfg().tankName
    want = (want and want ~= "") and (want:match("^[^-]+") or want):lower() or nil
    local prefix, count
    if IsInRaid and IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    elseif IsInGroup and IsInGroup() then
        prefix, count = "party", GetNumSubgroupMembers()
    else
        return nil
    end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            if want then
                local name = UnitName(unit)
                if name and name:lower() == want then return unit end
            elseif UnitGroupRolesAssigned(unit) == "TANK" then
                return unit
            end
        end
    end
end

-- (solo para pruebas) cantidad de íconos visibles
function TankDebuffs.ShownCount()
    local n = 0
    for _, f in ipairs(icons) do if f:IsShown() then n = n + 1 end end
    return n
end

function TankDebuffs.TrackedName()
    if not trackedUnit then return nil end
    return UnitName(trackedUnit)
end

local SORT = { default = "Default", expiration = "ExpirationOnly", name = "NameOnly", none = "Unsorted" }
local idList = {}

local function CollectIDs(unit, n)
    local c = cfg()
    wipe(idList)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return idList end
    if c.mode == "whitelist" then
        if not C_UnitAuras.GetUnitAuraBySpellID then return idList end
        for _, spellID in ipairs(c.spells) do
            local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
            local iid = ok and aura and aura.auraInstanceID
            if iid and Readable(iid) then
                idList[#idList + 1] = iid
                if #idList >= n then break end
            end
        end
    else
        local rule = Enum and Enum.UnitAuraSortRule and Enum.UnitAuraSortRule[SORT[c.sort] or "Default"]
        local ok, ids
        if rule then
            ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, "HARMFUL", n, rule,
                Enum.UnitAuraSortDirection and Enum.UnitAuraSortDirection.Normal)
        else
            ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, "HARMFUL", n)
        end
        if ok and type(ids) == "table" then
            for i = 1, math.min(#ids, n) do idList[#idList + 1] = ids[i] end
        end
    end
    return idList
end

local function Refresh()
    local c = cfg()
    if not c.enabled then
        frame:Hide()
        return
    end
    local n = Shown()
    local count = 0
    if trackedUnit and UnitExists(trackedUnit) then
        local ids = CollectIDs(trackedUnit, n)
        for i = 1, #ids do
            Fill(GetIcon(i), trackedUnit, ids[i])
            count = i
        end
    end
    -- vista previa: se completa con ejemplos para ver cómo queda la cuadrícula
    if c.unlocked then
        for i = count + 1, n do FillSample(GetIcon(i), i) end
        count = n
    end
    for i = count + 1, #icons do
        local f = icons[i]
        f.auraID, f.unit = nil, nil
        f.glow:Hide()
        f:Hide()
    end
    frame:SetShown(count > 0)
end

local queued = false
local function QueueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0.05, function()
        queued = false
        Refresh()
    end)
end

local watcher = CreateFrame("Frame")
local registeredUnit

local function ResolveUnit()
    local unit = FindTank()
    if unit ~= registeredUnit then
        watcher:UnregisterEvent("UNIT_AURA")
        registeredUnit = unit
        if unit then pcall(watcher.RegisterUnitEvent, watcher, "UNIT_AURA", unit) end
    end
    trackedUnit = unit
    if ns.RefreshOptions then ns.RefreshOptions() end
end

watcher:SetScript("OnEvent", function(_, event)
    if event == "UNIT_AURA" then
        QueueRefresh()
    else
        ResolveUnit()
        QueueRefresh()
    end
end)

---------------------------------------------------------------------------
-- Lista blanca
---------------------------------------------------------------------------

function TankDebuffs.EntryName(id)
    local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    local ok, name = pcall(fn, id)
    return ok and type(name) == "string" and name or nil
end

function TankDebuffs.EntryIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

local function IndexOf(id)
    for i, v in ipairs(cfg().spells) do
        if v == id then return i end
    end
end

function TankDebuffs.AddSpell(text)
    local id = tonumber(text)
    if not id or id <= 0 or id ~= math.floor(id) or id >= 10000000 then return false, L["Enter a valid spell ID."] end
    if not TankDebuffs.EntryName(id) then return false, string.format(L["Spell %d does not exist."], id) end
    local list = cfg().spells
    if IndexOf(id) then return false, string.format(L["%s is already on the list."], TankDebuffs.EntryName(id)) end
    if #list >= MAX_LIST then return false, L["The list is full."] end
    list[#list + 1] = id
    QueueRefresh()
    return true, string.format(L["%s added."], TankDebuffs.EntryName(id))
end

function TankDebuffs.RemoveSpell(id)
    id = tonumber(id)
    local i = id and IndexOf(id)
    if not i then return false, L["It is not on the list."] end
    table.remove(cfg().spells, i)
    QueueRefresh()
    return true, L["Removed."]
end

-- Agrega a la lista los debuffs que el tank tiene ahora (solo los que el juego deja leer).
function TankDebuffs.CaptureCurrent()
    if not trackedUnit then return false, L["No tank to follow right now."] end
    local ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, trackedUnit, "HARMFUL")
    if not ok or type(ids) ~= "table" then return false, L["Could not read the tank's debuffs."] end
    local added, hidden = 0, 0
    for _, id in ipairs(ids) do
        local okA, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, trackedUnit, id)
        local spellID = okA and aura and aura.spellId
        if spellID and Readable(spellID) then
            if TankDebuffs.AddSpell(spellID) then added = added + 1 end
        else
            hidden = hidden + 1
        end
    end
    return true, string.format(L["Added %d debuffs. %d are hidden by the game right now."], added, hidden)
end

-- Cuántos debuffs de la lista el juego podría ocultar en combate.
function TankDebuffs.HiddenCount()
    local n = 0
    for _, id in ipairs(cfg().spells) do
        if Secrets.SpellAuraIsSecret(id) == true then n = n + 1 end
    end
    return n, #cfg().spells
end

---------------------------------------------------------------------------
-- Aplicar configuración
---------------------------------------------------------------------------

function TankDebuffs.Apply()
    local c = cfg()
    ns.MakeMovable(frame, c)
    ns.ApplyPosition(frame, c)
    ns.ApplyLockVisuals(frame, c)
    Layout()

    watcher:UnregisterAllEvents()
    registeredUnit = nil
    if c.enabled then
        for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD",
                             "PLAYER_SPECIALIZATION_CHANGED" }) do
            pcall(watcher.RegisterEvent, watcher, e)
        end
        ResolveUnit()
    else
        trackedUnit = nil
    end
    Refresh()
end

function TankDebuffs.Slash(arg)
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    if cmd == "add" then
        local _, msg = TankDebuffs.AddSpell(rest)
        print(PREFIX .. msg)
    elseif cmd == "remove" then
        local _, msg = TankDebuffs.RemoveSpell(rest)
        print(PREFIX .. msg)
    elseif cmd == "capture" then
        local _, msg = TankDebuffs.CaptureCurrent()
        print(PREFIX .. msg)
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif cmd == "status" then
        local name = TankDebuffs.TrackedName()
        print(PREFIX .. (name and string.format(L["Following: %s"], name) or L["No tank to follow right now."]))
    else
        print(PREFIX .. L["Usage: /modi tankdebuffs add <spellID> | remove <spellID> | capture | status"])
    end
end
