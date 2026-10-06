-- Herramienta: prepot / trinket. Duración restante de la poción usada y sonidos cuando la poción
-- o un trinket elegido vuelven a estar listos.
--
-- Detección: al lanzarse un hechizo (UNIT_SPELLCAST_SENT) se revisa si corresponde
-- a una poción de tus bolsas. Si lo es, tras el éxito del casteo se busca el buff
-- que aplicó y se muestra su ícono con el tiempo restante.
-- Si alguna poción no se detecta sola, agrégala con /modi prepot add <spellID>.

local _, ns = ...
local PREFIX = ns.PREFIX
local L = ns.L
local Secrets = ns.Secrets

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
    soundReady = true, soundReadyKey = "mt_potion_ready",   -- sonido al terminar el cooldown de la poción
    soundCustom = "",   -- soundkit ID o ruta de archivo, usado con la opción "Personalizado"
    trinketSound = true, trinketSoundKey = "mt_trinket_ready",   -- sonido cuando un trinket vuelve a estar listo
    trinketSlots = { [13] = true, [14] = true },                 -- qué trinkets equipados se vigilan (ranuras 13 y 14)
    healingSound = true, healingSoundKey = "mt_healing_potion_ready",   -- sonido de la poción de vida (HP)
    healingSpells = {},   -- [spellID de uso] = true/false: marcado a mano como poción de HP / de combate (nil = automático)
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
    -- el texto y el color solo se reescriben cuando cambia la décima mostrada
    local tenths = math.floor(remaining * 10)
    if tenths == tracked.lastTenths then return end
    tracked.lastTenths = tenths
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

---------------------------------------------------------------------------
-- Cooldowns: sonido cuando la poción o un trinket vuelven a estar listos
--
-- No hay ningún sondeo por tiempo (nada corre en cada frame ni cada X segundos):
--   * los eventos de cooldown avisan cuándo EMPIEZA o cambia un cooldown (el juego no avisa cuando termina);
--   * al detectarlo se lee una sola vez y el fin se programa con UN temporizador;
--   * si el juego oculta el cooldown (combate, Mythic+), se usa un objeto de duración y un marco Cooldown
--     invisible: es el propio juego el que avisa (OnCooldownDone), sin que el addon vea los números.
---------------------------------------------------------------------------

local watches = {}    -- [clave] = vigilancia armada: { kind, slot, spell, expiration, estimated, byFrame, token }
local awaiting = {}   -- [clave] = uso visto cuyo cooldown aún no se lee: { kind, slot, spell, since }
local tokenSeq = 0
local scanQueued = false

-- Cooldown de un hechizo. Devuelve (fin, duración) o nil; el tercer valor es true si el dato está OCULTO:
-- la API oficial (C_Secrets) avisa antes de leer, así no se depende de atrapar errores.
local function SpellCooldownEnd(spellID)
    if Secrets.SpellCooldownIsSecret(spellID) == true then return nil, nil, true end
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(spellID)
    end
    -- se ignora el GCD y los cooldowns cortos
    if start and duration and duration > 2 and start > 0 then return start + duration, duration end
end

-- Cooldown por ÍTEM. En la documentación de Blizzard, C_Item.GetItemCooldown / C_Container.GetItemCooldown NO están
-- marcadas como secretas (los cooldowns de hechizo sí), así que siguen entregando números en combate y Mythic+.
local function ItemCooldownEnd(itemID)
    local fn = (C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown)
    if not fn then return nil end
    local start, duration = fn(itemID)
    if start and duration and duration > 2 and start > 0 then return start + duration, duration end
end

-- Cooldown de un trinket equipado (ranura 13 o 14): primero por su ítem; si no, por la ranura.
local function SlotCooldownEnd(slot)
    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
    if itemID then
        local e, dur = ItemCooldownEnd(itemID)
        if e then return e, dur end
    end
    if not GetInventoryItemCooldown then return nil end
    local start, duration = GetInventoryItemCooldown("player", slot)
    if start and duration and duration > 2 and start > 0 then return start + duration, duration end
end

local function BaseCooldownOf(spellID)
    local fn = (C_Spell and C_Spell.GetSpellBaseCooldown) or GetSpellBaseCooldown
    if not fn or not spellID then return nil end
    local ok, ms = pcall(fn, spellID)
    if ok and type(ms) == "number" and ms > 0 then return ms / 1000 end
end

local function PlayReady(w)
    local c = cfg()
    if w.kind == "trinket" then
        if ns.debug then print(PREFIX .. "trinket ready: slot " .. w.slot) end
        if c.trinketSound then ns.PlaySoundKey(c.trinketSoundKey, c.soundCustom) end
    elseif w.kind == "healing" then
        if ns.debug then print(PREFIX .. "healing potion ready") end
        if c.healingSound then ns.PlaySoundKey(c.healingSoundKey, c.soundCustom) end
    else
        if ns.debug then print(PREFIX .. "prepot: potion ready") end
        if c.soundReady then ns.PlaySoundKey(c.soundReadyKey, c.soundCustom) end
    end
end

local PotionCooldownEnd   -- (definida junto a la lista de pociones)

-- Lee el momento en que termina el cooldown de una vigilancia. Devuelve ok (false = datos ocultos) y el fin.
local function ReadEnd(w)
    local ok, e, _, hidden
    if w.kind == "trinket" then
        ok, e, _, hidden = pcall(SlotCooldownEnd, w.slot)
        if ok and not e and not hidden and w.spell then
            ok, e, _, hidden = pcall(SpellCooldownEnd, w.spell)   -- respaldo: hechizo de uso
        end
    else
        ok, e, _, hidden = pcall(PotionCooldownEnd, w.spell)
    end
    if hidden then return false end
    return ok, e
end

-- Un único temporizador por cooldown: al vencer se vuelve a leer por si el cooldown se alargó.
local Arm

local function OnTimer(key, token)
    local w = watches[key]
    if not w or w.token ~= token then return end   -- reemplazado o cancelado
    if not w.estimated then
        local ok, e = ReadEnd(w)
        if ok and e and e > GetTime() + 0.5 then
            w.expiration = e
            Arm(key, w)
            return
        end
    end
    watches[key] = nil
    PlayReady(w)
end

Arm = function(key, w)
    tokenSeq = tokenSeq + 1
    w.token = tokenSeq
    watches[key] = w
    local token = w.token
    C_Timer.After(math.max(0.05, w.expiration - GetTime() + 0.05), function() OnTimer(key, token) end)
end

-- Datos ocultos: marco Cooldown invisible que avisa cuando termina (OnCooldownDone).
local doneFrames = {}

local function DoneFrame(key)
    local cf = doneFrames[key]
    if cf then return cf end
    cf = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
    cf:SetSize(1, 1)
    cf:SetPoint("CENTER", UIParent, "CENTER")
    cf:SetAlpha(0)
    cf:SetDrawSwipe(false)
    cf:SetDrawEdge(false)
    cf:SetDrawBling(false)
    cf:SetHideCountdownNumbers(true)
    doneFrames[key] = cf
    return cf
end

local function DurationObjectFor(w)
    -- (no existe una versión por ítem de GetSpellCooldownDuration: se usa la del hechizo de uso)
    if w.spell and C_Spell and C_Spell.GetSpellCooldownDuration then
        local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, w.spell)
        if ok and dur then return dur end
    end
end

local function ArmByFrame(key, w)
    local dur = DurationObjectFor(w)
    local cf = dur and DoneFrame(key)
    if not (cf and cf.SetCooldownFromDurationObject) then return false end
    tokenSeq = tokenSeq + 1
    w.token, w.byFrame = tokenSeq, true
    watches[key] = w
    local token = w.token
    cf:SetScript("OnCooldownDone", function()
        local current = watches[key]
        if current and current.token == token then
            watches[key] = nil
            PlayReady(current)
        end
    end)
    if not pcall(cf.SetCooldownFromDurationObject, cf, dur) then
        watches[key] = nil
        return false
    end
    if ns.debug then print(PREFIX .. key .. ": cooldown hidden, the game will signal when it ends") end
    return true
end

-- Intenta convertir un uso visto en una vigilancia armada. Devuelve true si quedó armada.
local function Resolve(key, w)
    local ok, e = ReadEnd(w)
    if ok then
        if not e then return false end   -- legible pero aún sin cooldown: se sigue esperando
        w.expiration = e
        if ns.debug then print(PREFIX .. string.format("%s cooldown read: ready in %.0f s", key, e - GetTime())) end
        Arm(key, w)
        return true
    end
    -- datos ocultos
    if ArmByFrame(key, w) then return true end
    local base = BaseCooldownOf(w.spell) or (w.kind ~= "trinket" and 300 or nil)
    if base then
        w.expiration = w.since + base
        w.estimated = true
        if ns.debug then print(PREFIX .. string.format("%s cooldown hidden: estimated %.0f s", key, base)) end
        Arm(key, w)
        return true
    end
    return false
end

-- Pociones: se recuerdan los hechizos de uso de las pociones de tus bolsas (todas comparten el mismo
-- cooldown de 5 min) y se lee su cooldown aunque la poción ya se haya gastado.
local POTION_MIN_COOLDOWN = 31
local TRINKET_MIN_COOLDOWN = 31   -- el cooldown compartido de 20-30 s del otro trinket no cuenta
local knownPotionSpells = {}
local potionItems = {}   -- [spellID de uso] = itemID (para saber su nombre)
local potionScanDirty = true

-- Cooldown de una poción: primero por su ítem (legible aunque el de hechizo sea secreto) y si no, por su hechizo.
PotionCooldownEnd = function(spellID)
    local itemID = potionItems[spellID]
    if itemID then
        local e, dur = ItemCooldownEnd(itemID)
        if e then return e, dur end
    end
    return SpellCooldownEnd(spellID)
end

local function ScanPotionSpells()
    potionScanDirty = false
    local getSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local getItem = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
    if not (getSlots and getItem) then return end
    for bag = 0, (NUM_BAG_SLOTS or 4) + 1 do
        for slot = 1, (getSlots(bag) or 0) do
            local itemID = getItem(bag, slot)
            if itemID then
                local classID, subClassID = ItemClasses(itemID)
                if classID == 0 and subClassID == 1 then   -- consumible de tipo poción
                    local spellID = ItemSpellID(itemID)
                    if spellID then
                        knownPotionSpells[spellID] = true
                        potionItems[spellID] = itemID
                    end
                end
            end
        end
    end
end

-- Pociones de vida (HP): tienen su propio cooldown, aparte del de las pociones de combate.
-- Se reconocen por el nombre del objeto (varios idiomas); lo marcado a mano en el selector manda.
local HEALING_WORDS = {
    "health", "healing", "curaci", "sanaci", "salud", "heilung", "lebenstrank", "soin", "santé",
    "guérison", "cura", "saúde", "salute", "лечен", "здоров", "치유", "治疗", "治療", "生命",
}

local function PotionName(spellID)
    local itemID = potionItems[spellID]
    if not itemID then return nil end
    local name
    if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(itemID) end
    if not name and GetItemInfo then name = (GetItemInfo(itemID)) end
    return name
end

local function IsHealing(spellID)
    local explicit = cfg().healingSpells[spellID]
    if explicit ~= nil then return explicit end
    local name = PotionName(spellID)
    if not name then return false end
    name = name:lower()
    for _, word in ipairs(HEALING_WORDS) do
        if name:find(word, 1, true) then return true end
    end
    return false
end

local function PotionKey(spellID)
    return IsHealing(spellID) and "healing" or "potion"
end

local function SoundEnabledFor(key)
    local c = cfg()
    if key == "healing" then return c.healingSound end
    return c.soundReady
end

-- Cooldowns ya en curso que no vimos empezar (p. ej. al entrar al juego): solo si se pueden leer.
local function FindRunningCooldowns(now)
    local c = cfg()
    for spellID in pairs(c.extra) do knownPotionSpells[spellID] = true end
    for spellID in pairs(knownPotionSpells) do
        local key = PotionKey(spellID)
        if SoundEnabledFor(key) and not watches[key] and not awaiting[key] then
            local ok, expiration, duration = pcall(PotionCooldownEnd, spellID)
            if ok and expiration and duration and duration >= POTION_MIN_COOLDOWN and expiration > now then
                -- si ya hay otra poción armada con este mismo cooldown, es un cooldown compartido: no se duplica
                local shared = false
                for k, w in pairs(watches) do
                    if k ~= key and w.kind ~= "trinket" and w.expiration and math.abs(w.expiration - expiration) < 1.5 then
                        shared = true
                    end
                end
                if not shared then
                    if ns.debug then
                        print(PREFIX .. string.format("%s potion on cooldown: ready in %.0f s (spell %d)", key, expiration - now, spellID))
                    end
                    Arm(key, { kind = key, spell = spellID, since = now, expiration = expiration })
                end
            end
        end
    end
    if c.trinketSound then
        for _, slot in ipairs({ 13, 14 }) do
            local key = "trinket" .. slot
            if c.trinketSlots[slot] and not watches[key] and not awaiting[key] then
                local ok, expiration, duration = pcall(SlotCooldownEnd, slot)
                if ok and expiration and duration and duration >= TRINKET_MIN_COOLDOWN and expiration > now then
                    if ns.debug then
                        print(PREFIX .. string.format("trinket %d on cooldown: ready in %.0f s", slot, expiration - now))
                    end
                    Arm(key, { kind = "trinket", slot = slot, since = now, expiration = expiration })
                end
            end
        end
    end
end

-- Una pasada de lectura: se dispara por eventos (agrupados), nunca por tiempo.
local function Scan()
    scanQueued = false
    local c = cfg()
    if not c.enabled then return end
    local now = GetTime()
    if potionScanDirty then pcall(ScanPotionSpells) end

    for key, w in pairs(awaiting) do
        if watches[key] then
            awaiting[key] = nil
        elseif now - w.since > 15 then
            awaiting[key] = nil
            if ns.debug then print(PREFIX .. key .. ": no cooldown found after use") end
        elseif Resolve(key, w) then
            awaiting[key] = nil
        end
    end
    FindRunningCooldowns(now)
end

local function QueueScan(delay)
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(delay or 0.15, Scan)
end

-- Trinket equipado en una ranura: itemID, nombre y si tiene efecto de uso (para la ventana de opciones).
function Prepot.TrinketLabel(slot)
    local n = slot == 13 and 1 or 2
    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not itemID then return string.format(L["Trinket %d: %s"], n, L["(empty)"]) end
    local name
    if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(itemID) end
    if not name and GetItemInfo then name = (GetItemInfo(itemID)) end
    name = name or ("Item " .. itemID)
    if not ItemSpellID(itemID) then name = name .. " " .. L["(no on-use effect)"] end
    return string.format(L["Trinket %d: %s"], n, name)
end


-- Pociones conocidas (de las bolsas y las ya usadas) para el selector de pociones de HP.
function Prepot.ScanPotions()
    pcall(ScanPotionSpells)
    local list = {}
    for spellID in pairs(knownPotionSpells) do
        local itemID = potionItems[spellID]
        local icon
        if itemID then
            if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(itemID) end
            if not icon and C_Item and C_Item.GetItemInfoInstant then
                local ok, _, _, _, _, ic = pcall(C_Item.GetItemInfoInstant, itemID)
                if ok then icon = ic end
            end
        end
        list[#list + 1] = {
            id = spellID, kind = "potion", icon = icon,
            name = PotionName(spellID) or ("Spell " .. spellID),
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function Prepot.IsHealingPotion(spellID)
    return IsHealing(spellID)
end

function Prepot.SetHealing(spellID, value)
    cfg().healingSpells[spellID] = value
    -- las vigilancias en curso quedaron con la categoría anterior: se descartan y se vuelve a leer
    watches.potion, watches.healing, awaiting.potion, awaiting.healing = nil, nil, nil, nil
    QueueScan()
end

function Prepot.HealingCount()
    local n = 0
    for spellID in pairs(knownPotionSpells) do
        if IsHealing(spellID) then n = n + 1 end
    end
    return n
end

frame:SetScript("OnEvent", function(_, event, a, b, c, d)
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
            knownPotionSpells[c] = true
            local key = PotionKey(c)
            watches[key] = nil   -- un uso nuevo reemplaza cualquier vigilancia anterior de esa categoría
            awaiting[key] = { kind = key, spell = c, since = GetTime() }
            C_Timer.After(0.2, function() pcall(Detect, c, before) end)
            QueueScan(0.3)
            C_Timer.After(2, function() QueueScan(0) end)
        end

        -- trinkets: si el hechizo lanzado es el de uso de un trinket equipado que se vigila
        local cc = cfg()
        if cc.trinketSound then
            for _, slot in ipairs({ 13, 14 }) do
                if cc.trinketSlots[slot] then
                    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
                    if itemID and c and ItemSpellID(itemID) == c then
                        watches["trinket" .. slot] = nil
                        awaiting["trinket" .. slot] = { kind = "trinket", slot = slot, spell = c, since = GetTime() }
                        if ns.debug then print(PREFIX .. "trinket " .. slot .. " used (spell " .. c .. ")") end
                        QueueScan(0.3)
                        C_Timer.After(2, function() QueueScan(0) end)
                    end
                end
            end
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
        QueueScan()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- args: slot, hasCurrent. Si cambia un trinket vigilado, se descarta su vigilancia anterior.
        if a == 13 or a == 14 then
            watches["trinket" .. a] = nil
            awaiting["trinket" .. a] = nil
            QueueScan()
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" then
        potionScanDirty = true
        QueueScan()
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
        for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED",
                             "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do
            pcall(frame.RegisterEvent, frame, e)
        end
        potionScanDirty = true
        QueueScan(1)   -- lectura inicial (cooldowns que ya venían corriendo)
        frame:SetScript("OnUpdate", OnUpdate)
    else
        frame:SetScript("OnUpdate", nil)
        tracked = nil
        wipe(watches)
        wipe(awaiting)
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
    elseif cmd == "status" then
        local c = cfg()
        local function flag(v) return v and "on" or "off" end
        print(PREFIX .. string.format("potion sound: %s (%s) | trinket sound: %s (%s)",
            flag(c.soundReady), tostring(c.soundReadyKey), flag(c.trinketSound), tostring(c.trinketSoundKey)))
        for _, slot in ipairs({ 13, 14 }) do
            local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
            local useSpell = itemID and ItemSpellID(itemID)
            print(PREFIX .. string.format("trinket slot %d: watched=%s, item=%s, on-use spell=%s",
                slot, flag(c.trinketSlots[slot]), tostring(itemID), tostring(useSpell)))
        end
        local potions = {}
        for spellID in pairs(knownPotionSpells) do
            potions[#potions + 1] = tostring(spellID) .. (IsHealing(spellID) and " (HP)" or "")
        end
        table.sort(potions)
        print(PREFIX .. "potion spells known: " .. (#potions > 0 and table.concat(potions, ", ") or "none (no potion in bags yet)"))
        local now, any = GetTime(), false
        for key, w in pairs(watches) do
            any = true
            local left = w.byFrame and "cooldown hidden: the game signals when it ends"
                or string.format("%.0f s%s", (w.expiration or now) - now, w.estimated and " (estimated)" or "")
            print(PREFIX .. string.format("watching %s: %s", key, left))
        end
        for key in pairs(awaiting) do
            any = true
            print(PREFIX .. string.format("%s used: waiting for its cooldown to start", key))
        end
        if not any then print(PREFIX .. "no cooldown being watched (use the potion / trinket first)") end
    elseif cmd == "sound" and rest ~= "" then
        cfg().soundCustom = rest
        cfg().soundReadyKey = "custom"
        Prepot.Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(PREFIX .. string.format(L["Custom sound: %s"], rest))
        ns.PlaySoundKey("custom", rest)
    else
        print(PREFIX .. L["Usage: /modi prepot test | add <spellID> | remove <spellID> | sound <soundkitID or file path>"])
    end
end
