-- Herramienta: distancia en yardas al target.

local _, ns = ...

local defaults = {
    enabled = true, unlocked = false,
    point = "CENTER", x = 0, y = -150,
    fontSize = 28,
}

local Yards = {}
ns.RegisterModule("yards", defaults, Yards)

local function cfg() return ns.db.yards end

-- { yardas, itemID }. IsItemInRange funciona sin tener el item.
local HARM_ITEMS = {
    { 5, 37727 }, { 8, 34368 }, { 10, 32321 }, { 15, 33069 }, { 20, 10645 },
    { 25, 24268 }, { 30, 835 }, { 35, 24269 }, { 40, 28767 }, { 45, 23836 },
    { 60, 37887 }, { 80, 35278 },
}
local FRIEND_ITEMS = {
    { 15, 1251 }, { 20, 21519 }, { 25, 31463 }, { 40, 34471 },
    { 45, 32698 }, { 60, 32825 }, { 80, 35278 },
}
-- CheckInteractDistance: { índice, yardas }
local INTERACT = { { 3, 10 }, { 2, 11 }, { 4, 28 } }

local function ItemInRange(itemID, unit)
    local fn = (C_Item and C_Item.IsItemInRange) or IsItemInRange
    if not fn then return nil end
    local ok, res = pcall(fn, itemID, unit)
    if ok then return res end
    return nil
end

local function BuildCheckers(unit)
    local list = {}
    local items = UnitCanAttack("player", unit) and HARM_ITEMS or FRIEND_ITEMS
    for _, it in ipairs(items) do
        local yd, id = it[1], it[2]
        list[#list + 1] = { yd, function(u) return ItemInRange(id, u) end }
    end
    if CheckInteractDistance then
        for _, it in ipairs(INTERACT) do
            local idx, yd = it[1], it[2]
            list[#list + 1] = { yd, function(u)
                local ok, res = pcall(CheckInteractDistance, u, idx)
                if ok then return res end
                return nil
            end }
        end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
end

-- Distancia exacta cuando el cliente entrega posiciones (miembros del grupo).
local function ExactDistance(unit)
    if not UnitPosition then return nil end
    local ok, py, px, _, pi = pcall(UnitPosition, "player")
    if not ok or not px then return nil end
    local ok2, ty, tx, _, ti = pcall(UnitPosition, unit)
    if not ok2 or not tx or pi ~= ti then return nil end
    local dx, dy = px - tx, py - ty
    return math.sqrt(dx * dx + dy * dy)
end

local function BracketDistance(unit)
    local minRange, maxRange = 0, nil
    for _, c in ipairs(BuildCheckers(unit)) do
        local res = c[2](unit)
        if res == true then
            maxRange = maxRange and math.min(maxRange, c[1]) or c[1]
        elseif res == false then
            minRange = math.max(minRange, c[1])
        end
    end
    if maxRange and minRange >= maxRange then minRange = 0 end
    return minRange, maxRange
end

local function DistanceText()
    if not UnitExists("target") then return nil end
    if UnitIsUnit("target", "player") then return "0 yd" end
    local exact = ExactDistance("target")
    if exact then return string.format("%.1f yd", exact) end
    local minR, maxR = BracketDistance("target")
    if maxR then
        if minR == 0 then return string.format("< %d yd", maxR) end
        return string.format("%d - %d yd", minR, maxR)
    end
    if minR > 0 then return string.format("> %d yd", minR) end
    return "?? yd"
end

local frame = CreateFrame("Frame", "ModiToolsYardsFrame", UIParent)
frame:SetFrameStrata("HIGH")
local text = frame:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER")

local elapsed = 0
local function OnUpdate(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.1 then return end
    elapsed = 0

    local str = DistanceText()
    if str then
        text:SetText(str)
        text:SetTextColor(1, 1, 1)
    elseif cfg().unlocked then
        text:SetText("-- yd")
        text:SetTextColor(0.7, 0.7, 0.7)
    else
        text:SetText("")
    end
end

function Yards.Apply()
    local c = cfg()
    ns.MakeMovable(frame, c)
    text:SetFont(STANDARD_TEXT_FONT, c.fontSize, "OUTLINE")
    frame:SetSize(math.max(120, c.fontSize * 6), c.fontSize + 16)
    ns.ApplyPosition(frame, c)
    ns.ApplyLockVisuals(frame, c)

    if c.enabled then
        frame:Show()
        frame:SetScript("OnUpdate", OnUpdate)
    else
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
    end
end
