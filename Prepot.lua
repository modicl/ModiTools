-- Herramienta: duración restante de la prepot (poción usada).
--
-- Detección: al lanzarse un hechizo (UNIT_SPELLCAST_SENT) se revisa si corresponde
-- a una poción de tus bolsas. Si lo es, tras el éxito del casteo se busca el buff
-- que aplicó y se muestra su ícono con el tiempo restante.
-- Si alguna poción no se detecta sola, agrégala con /modi prepot add <spellID>.

local _, ns = ...
local PREFIX = ns.PREFIX
local L = ns.L

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local defaults = {
    enabled = true, unlocked = false,
    point = "CENTER", x = 0, y = -100,
    iconSize = 48, alpha = 1,
    showText = true, fontSize = 20, textPos = "CENTER",
    showSwirl = true, showBorder = true,
    warnAt = 10,
    colorText = { 1, 1, 1, 1 },
    colorWarn = { 1, 0.2, 0.2, 1 },
    colorBorder = { 0, 0, 0, 1 },
    extra = {},   -- spellIDs de pociones agregados a mano
}

local Prepot = {}
ns.RegisterModule("prepot", defaults, Prepot)

local function cfg() return ns.db.prepot end

---------------------------------------------------------------------------
-- Marcos
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "ModiToolsPrepotFrame", UIParent)
frame:SetFrameStrata("HIGH")

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
cooldown:SetAllPoints()
cooldown:SetHideCountdownNumbers(true)
cooldown:SetDrawEdge(false)
cooldown:EnableMouse(false)

local over = CreateFrame("Frame", nil, frame)
over:SetAllPoints()
over:SetFrameLevel(cooldown:GetFrameLevel() + 2)

local border = CreateFrame("Frame", nil, over, "BackdropTemplate")
border:SetAllPoints()
border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })

local text = over:CreateFontString(nil, "OVERLAY")

---------------------------------------------------------------------------
-- Seguimiento
---------------------------------------------------------------------------

local tracked   -- { spellID, icon, duration, expiration, test }

local function FormatTime(t)
    if t >= 60 then
        return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
    elseif t >= 10 then
        return string.format("%d", math.floor(t))
    end
    return string.format("%.1f", t)
end

local function SetTextColor(col)
    text:SetTextColor(col[1], col[2], col[3], col[4] or 1)
end

local function Render()
    local c = cfg()
    if not c.enabled then
        frame:Hide()
        return
    end
    if tracked then
        icon:SetTexture(tracked.icon)
        cooldown:SetCooldown(tracked.expiration - tracked.duration, tracked.duration)
        frame:Show()
    elseif c.unlocked then
        icon:SetTexture(QUESTION)
        cooldown:SetCooldown(0, 0)
        text:SetText("30")
        SetTextColor(c.colorText)
        frame:Show()
    else
        frame:Hide()
    end
end

local function Stop()
    tracked = nil
    Render()
end

local function Start(spellID, tex, duration, expiration, isTest)
    tracked = { spellID = spellID, icon = tex, duration = duration, expiration = expiration, test = isTest }
    Render()
end

local function OnUpdate()
    if not tracked then return end
    local remaining = tracked.expiration - GetTime()
    if remaining <= 0 then
        Stop()
        return
    end
    local c = cfg()
    text:SetText(FormatTime(remaining))
    SetTextColor(remaining <= c.warnAt and c.colorWarn or c.colorText)
end

---------------------------------------------------------------------------
-- Detección de la poción y su buff
---------------------------------------------------------------------------

local potionSpell = {}   -- [spellID] = true/false (caché)
local pending = {}       -- [spellID] = snapshot de buffs previos al casteo

local function ItemSpellID(itemID)
    local fn = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not fn then return nil end
    local _, spellID = fn(itemID)
    return spellID
end

local function ItemClasses(itemID)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local _, _, _, _, _, classID, subClassID = fn(itemID)
    return classID, subClassID
end

local function IsPotionSpell(spellID)
    if not spellID then return false end
    if cfg().extra[spellID] then return true end
    if potionSpell[spellID] ~= nil then return potionSpell[spellID] end

    local found = false
    local getSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local getItem = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
    if getSlots and getItem then
        for bag = 0, (NUM_BAG_SLOTS or 4) + 1 do
            for slot = 1, (getSlots(bag) or 0) do
                local itemID = getItem(bag, slot)
                if itemID then
                    local classID, subClassID = ItemClasses(itemID)
                    -- 0 = Consumible, 1 = Poción
                    if classID == 0 and subClassID == 1 and ItemSpellID(itemID) == spellID then
                        found = true
                        break
                    end
                end
            end
            if found then break end
        end
    end
    potionSpell[spellID] = found
    return found
end

local function EachBuff(fn)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 60 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not a then break end
            fn(a.spellId, a.icon, a.duration, a.expirationTime)
        end
    else
        for i = 1, 60 do
            local name, ic, _, _, duration, expiration, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end
            fn(spellId, ic, duration, expiration)
        end
    end
end

local function SnapshotBuffs()
    local set = {}
    EachBuff(function(id) set[id] = true end)
    return set
end

-- Busca el buff de la poción: primero por el mismo spellID, si no, el buff nuevo de mayor duración.
local function Detect(spellID, before)
    local best
    EachBuff(function(id, ic, dur, exp)
        if not dur or dur <= 0 or dur > 300 then return end
        if id == spellID then
            best = { id = id, icon = ic, duration = dur, expiration = exp, exact = true }
        elseif not before[id] and not (best and best.exact) then
            if not best or dur > best.duration then
                best = { id = id, icon = ic, duration = dur, expiration = exp }
            end
        end
    end)
    if best then
        Start(best.id, best.icon, best.duration, best.expiration)
    elseif ns.debug then
        print(PREFIX .. "prepot: potion buff not found (" .. tostring(spellID) .. ").")
    end
end

-- Si el buff desaparece (o se refresca) mientras lo seguimos, lo reflejamos.
local function CheckTracked()
    if not tracked or tracked.test then return end
    local exp
    EachBuff(function(id, _, _, e)
        if id == tracked.spellID then exp = e end
    end)
    if not exp then
        Stop()
    elseif exp ~= tracked.expiration then
        tracked.expiration = exp
        Render()
    end
end

frame:SetScript("OnEvent", function(_, event, _, b, c, d)
    if event == "UNIT_SPELLCAST_SENT" then
        -- args: unit, target, castGUID, spellID
        local ok, isPotion = pcall(IsPotionSpell, d)
        if ok and isPotion then
            local ok, snap = pcall(SnapshotBuffs)
            pending[d] = ok and snap or {}
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- args: unit, castGUID, spellID
        local before = pending[c]
        if before then
            pending[c] = nil
            if ns.debug then print(PREFIX .. "prepot detected: " .. tostring(c)) end
            C_Timer.After(0.2, function() pcall(Detect, c, before) end)
        end
    elseif event == "UNIT_AURA" then
        pcall(CheckTracked)
    end
end)

---------------------------------------------------------------------------
-- Aplicar configuración
---------------------------------------------------------------------------

function Prepot.Apply()
    local c = cfg()
    ns.MakeMovable(frame, c)
    ns.ApplyPosition(frame, c)
    ns.ApplyLockVisuals(frame, c)

    frame:SetSize(c.iconSize, c.iconSize)
    frame:SetAlpha(c.alpha)
    cooldown:SetAlpha(c.showSwirl and 1 or 0)

    border:SetShown(c.showBorder)
    border:SetBackdropBorderColor(c.colorBorder[1], c.colorBorder[2], c.colorBorder[3], c.colorBorder[4] or 1)

    text:SetFont(STANDARD_TEXT_FONT, c.fontSize, "OUTLINE")
    text:SetShown(c.showText)
    text:ClearAllPoints()
    if c.textPos == "BOTTOM" then
        text:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    elseif c.textPos == "TOP" then
        text:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    else
        text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    frame:UnregisterAllEvents()
    if c.enabled then
        frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
        frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        frame:RegisterUnitEvent("UNIT_AURA", "player")
        frame:SetScript("OnUpdate", OnUpdate)
    else
        frame:SetScript("OnUpdate", nil)
        tracked = nil
    end
    Render()
    if tracked then
        SetTextColor(c.colorText)
    end
end

function Prepot.Slash(arg)
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    local id = tonumber(rest)
    if cmd == "test" then
        Start(-1, QUESTION, 30, GetTime() + 30, true)
        print(PREFIX .. L["Prepot test: 30 s."])
    elseif cmd == "add" and id then
        cfg().extra[id] = true
        print(PREFIX .. string.format(L["spellID %d added as a potion."], id))
    elseif cmd == "remove" and id then
        cfg().extra[id] = nil
        potionSpell[id] = nil
        print(PREFIX .. string.format(L["spellID %d removed."], id))
    else
        print(PREFIX .. L["Usage: /modi prepot test | add <spellID> | remove <spellID>"])
    end
end
