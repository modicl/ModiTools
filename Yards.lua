-- Herramienta: distancia en yardas al target.
--
-- WoW no entrega la distancia a un enemigo, solo preguntas de sí/no del tipo "¿está dentro del alcance de
-- este ítem?". Se usan ítems de alcance conocido (lista tomada de LibRangeCheck-3.0, rama retail) y como
-- los alcances son monótonos (si está a 30 yd, también está dentro de 35 yd) se encuentra el intervalo con una
-- búsqueda binaria: ~5 consultas en vez de probar todos los ítems.
--
-- Costo: solo corre mientras hay un target (no hay OnUpdate sin target) y no crea tablas ni funciones por tick.

local _, ns = ...

local defaults = {
    enabled = true, unlocked = false,
    point = "CENTER", x = 0, y = -150,
    fontSize = 28,
}

local Yards = {}
ns.RegisterModule("yards", defaults, Yards)

local function cfg() return ns.db.yards end

-- { yardas, itemID }, ordenados de menor a mayor. Todos verificados contra LibRangeCheck-3.0 (retail).
local HARM_ITEMS = {
    { 3, 42732 }, { 4, 129055 }, { 5, 8149 }, { 7, 61323 }, { 8, 34368 }, { 10, 32321 }, { 12, 208068 },
    { 15, 33069 }, { 20, 10645 }, { 25, 24268 }, { 30, 835 }, { 35, 24269 }, { 38, 140786 }, { 40, 28767 },
    { 45, 23836 }, { 50, 116139 }, { 60, 37887 }, { 70, 41265 }, { 80, 35278 }, { 100, 33119 },
}
local FRIEND_ITEMS = {
    { 3, 42732 }, { 4, 129055 }, { 5, 1970 }, { 7, 61323 }, { 8, 34368 }, { 10, 21267 }, { 12, 208068 },
    { 15, 1251 }, { 20, 21519 }, { 25, 31463 }, { 30, 954 }, { 35, 24501 }, { 38, 140786 }, { 40, 34471 },
    { 45, 32698 }, { 50, 116139 }, { 60, 32825 }, { 70, 41265 }, { 80, 35278 }, { 100, 41058 },
}

-- Alias locales: esta ruta se ejecuta ~10 veces por segundo.
local pcall, floor = pcall, math.floor
local IsItemInRange = (C_Item and C_Item.IsItemInRange) or IsItemInRange

---------------------------------------------------------------------------
-- Rango
---------------------------------------------------------------------------

-- Sin los datos del ítem en caché, IsItemInRange devuelve nil. Se piden una sola vez (como hace LibRangeCheck).
local dataRequested = false
local function RequestItemData()
    if dataRequested then return end
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if not request then return end
    dataRequested = true
    for _, list in ipairs({ HARM_ITEMS, FRIEND_ITEMS }) do
        for _, entry in ipairs(list) do pcall(request, entry[2]) end
    end
end

-- true / false si el target está dentro del alcance del ítem; nil si no se puede saber.
-- Un ítem que responde nil muchas veces seguidas se descarta (no existe o no carga).
local function Probe(entry, unit)
    if entry.dead then return nil end
    local ok, inRange = pcall(IsItemInRange, entry[2], unit)
    if ok and inRange ~= nil then
        entry.misses = 0
        return inRange
    end
    entry.misses = (entry.misses or 0) + 1
    if entry.misses >= 8 then entry.dead = true end
    return nil
end

-- Búsqueda binaria del intervalo. Devuelve (mínimo, máximo): "más de <mínimo> y hasta <máximo>".
-- máximo = nil si está fuera del alcance más largo; mínimo = 0 si está dentro del más corto.
local function Bracket(list, unit)
    local lo, hi = 1, #list + 1          -- hi = primer índice con "sí" (hi = #list + 1: ninguno)
    local minRange, maxRange = 0, nil
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        -- buscar un ítem que responda cerca de la mitad (algunos pueden no estar disponibles)
        local idx, res
        for i = mid, hi - 1 do
            res = Probe(list[i], unit)
            if res ~= nil then idx = i break end
        end
        if not idx then
            for i = mid - 1, lo, -1 do
                res = Probe(list[i], unit)
                if res ~= nil then idx = i break end
            end
        end
        if not idx then break end
        if res then
            hi = idx
            maxRange = list[idx][1]
        else
            lo = idx + 1
            minRange = list[idx][1]
        end
    end
    if maxRange and minRange >= maxRange then minRange = 0 end
    return minRange, maxRange
end

-- Distancia exacta cuando el cliente entrega posiciones (miembros del grupo).
local function ExactDistance(unit)
    if not UnitPosition then return nil end
    local ok, py, px, _, pi = pcall(UnitPosition, "player")
    if not ok or not px then return nil end
    local ok2, ty, tx, _, ti = pcall(UnitPosition, unit)
    if not ok2 or not tx or pi ~= ti then return nil end
    local dx, dy = px - tx, py - ty
    return (dx * dx + dy * dy) ^ 0.5
end

---------------------------------------------------------------------------
-- Marco
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "ModiToolsYardsFrame", UIParent)
frame:SetFrameStrata("HIGH")
local text = frame:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER")

-- Solo se vuelve a escribir el texto cuando cambia el resultado (sin formatear cada tick).
local lastKind, lastA, lastB

local function SetResult(kind, a, b)
    if kind == lastKind and a == lastA and b == lastB then return end
    lastKind, lastA, lastB = kind, a, b
    if kind == "exact" then
        text:SetText(string.format("%.1f yd", a))
    elseif kind == "between" then
        text:SetText(string.format("%d - %d yd", a, b))
    elseif kind == "within" then
        text:SetText(string.format("< %d yd", b))
    elseif kind == "beyond" then
        text:SetText(string.format("> %d yd", a))
    elseif kind == "self" then
        text:SetText("0 yd")
    elseif kind == "unknown" then
        text:SetText("?? yd")
    else
        text:SetText("")
    end
end

local elapsed = 0
local function Update()
    local unit = "target"
    if UnitIsUnit(unit, "player") then
        SetResult("self")
        return
    end
    local exact = ExactDistance(unit)
    if exact then
        SetResult("exact", floor(exact * 10 + 0.5) / 10)
        return
    end
    local minR, maxR = Bracket(UnitCanAttack("player", unit) and HARM_ITEMS or FRIEND_ITEMS, unit)
    if maxR then
        if minR == 0 then SetResult("within", nil, maxR) else SetResult("between", minR, maxR) end
    elseif minR > 0 then
        SetResult("beyond", minR)
    else
        SetResult("unknown")
    end
end

local function OnUpdate(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.1 then return end
    elapsed = 0
    Update()
end

-- El OnUpdate solo existe mientras hay un target (sin target no corre nada).
local function RefreshTarget()
    local c = cfg()
    lastKind = nil
    if c.enabled and UnitExists("target") then
        RequestItemData()
        text:SetTextColor(1, 1, 1)
        frame:SetScript("OnUpdate", OnUpdate)
        elapsed = 1   -- calcula en el próximo frame
        return
    end
    frame:SetScript("OnUpdate", nil)
    if c.unlocked then
        text:SetText("-- yd")
        text:SetTextColor(0.7, 0.7, 0.7)
    else
        text:SetText("")
    end
end

frame:SetScript("OnEvent", RefreshTarget)

function Yards.Apply()
    local c = cfg()
    ns.MakeMovable(frame, c)
    text:SetFont(STANDARD_TEXT_FONT, c.fontSize, "OUTLINE")
    frame:SetSize(math.max(120, c.fontSize * 6), c.fontSize + 16)
    ns.ApplyPosition(frame, c)
    ns.ApplyLockVisuals(frame, c)

    frame:UnregisterAllEvents()
    if c.enabled then
        frame:Show()
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        RefreshTarget()
    else
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
    end
end

-- Solo para pruebas.
Yards.Text = text
Yards.Lists = { harm = HARM_ITEMS, friend = FRIEND_ITEMS }
