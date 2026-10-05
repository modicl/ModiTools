-- Herramienta: resurrección en combate (brez) sobre una tecla ya usada.
--
-- Elegida una tecla, esta pasa a lanzar el brez de tu clase mientras el mouse esté sobre un
-- aliado muerto (por ejemplo su unitframe). En cualquier otro momento la tecla funciona como siempre.
--
-- En combate los addons no pueden cambiar teclas, así que se usa un manejador seguro de Blizzard
-- (SecureHandlerStateTemplate): un "state driver" evalúa la condición [@mouseover,help,dead] y
-- activa/desactiva el enlace de la tecla desde el propio entorno seguro, también en combate.
-- Los ajustes (tecla, hechizo) solo se pueden aplicar fuera de combate.

local _, ns = ...
local PREFIX = ns.PREFIX
local L = ns.L

local defaults = {
    enabled = true,
    key = "",             -- por ejemplo "H" o "SHIFT-H"
    onlyCombat = true,    -- no gastar el brez fuera de combate
    customSpell = "",     -- ID de hechizo (número) a usar en lugar del detectado
}

local Brez = { noPosition = true }
ns.RegisterModule("brez", defaults, Brez)

local function cfg() return ns.db.brez end

-- Resurrecciones en combate por clase (spellIDs).
local BREZ = {
    DRUID = { 20484 },        -- Renacer
    DEATHKNIGHT = { 61999 },  -- Resucitar aliado
    WARLOCK = { 20707 },      -- Piedra de alma
    PALADIN = { 391054 },     -- Intercesión
}

---------------------------------------------------------------------------
-- Hechizo de la clase
---------------------------------------------------------------------------

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end

local function IsKnown(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return IsSpellKnown and IsSpellKnown(id) or false
end

-- Devuelve nombre, conocido (bool), origen ("custom" | "clase" | nil), id
local function ResolveSpell()
    local c = cfg()
    local customID = tonumber(c.customSpell)
    if customID then
        local name = SpellName(customID)
        return name, name ~= nil, "custom", customID
    end
    local _, class = UnitClass("player")
    local list = BREZ[class]
    if not list then return nil, false, nil end
    for _, id in ipairs(list) do
        local name = SpellName(id)
        if name and IsKnown(id) then return name, true, "clase", id end
    end
    return SpellName(list[1]), false, "clase", list[1]
end

---------------------------------------------------------------------------
-- Marcos seguros
---------------------------------------------------------------------------

-- Botón que lanza el hechizo sobre el mouseover cuando se le hace "click" desde la tecla.
local button = CreateFrame("Button", "ModiToolsBrezButton", UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyDown", "AnyUp")
button:SetAttribute("type", "macro")

-- Manejador seguro: activa la tecla solo mientras la condición se cumple.
local handler = CreateFrame("Frame", "ModiToolsBrezHandler", UIParent, "SecureHandlerStateTemplate")
handler:SetAttribute("_onstate-modibrez", [[
    if newstate == "on" then
        local key = self:GetAttribute("modikey")
        if key and key ~= "" then
            self:SetBindingClick(true, key, "ModiToolsBrezButton")
        end
    else
        self:ClearBindings()
    end
]])

local pending = false
local applied = { active = false }

function Brez.Apply()
    if InCombatLockdown() then
        pending = true   -- se aplica al salir de combate
        return
    end
    pending = false

    local c = cfg()
    local name, known = ResolveSpell()
    local active = c.enabled and c.key ~= "" and name and known and true or false

    UnregisterStateDriver(handler, "modibrez")
    SecureHandlerExecute(handler, "self:ClearBindings()")

    if active then
        button:SetAttribute("macrotext", "/cast [@mouseover,help,dead,exists] " .. name)
        handler:SetAttribute("modikey", c.key)
        local cond = c.onlyCombat and "[combat,@mouseover,help,dead,exists] on; off"
            or "[@mouseover,help,dead,exists] on; off"
        RegisterStateDriver(handler, "modibrez", cond)
    end

    applied.active, applied.key, applied.spell = active, c.key, name
end

---------------------------------------------------------------------------
-- Estado (para la ventana de opciones)
---------------------------------------------------------------------------

-- Ícono del hechizo detectado (o del ID elegido). Devuelve textura, spellID, conocido.
function Brez.SpellIcon()
    local name, known, _, id = ResolveSpell()
    if not id then return nil end
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
        tex = C_Spell.GetSpellTexture(id)
    elseif GetSpellTexture then
        tex = GetSpellTexture(id)
    end
    return tex, id, known
end

function Brez.StatusText()
    local c = cfg()
    local green, red, grey = "|cff7fe07f", "|cffff6060", "|cffa0aa95"
    local className = UnitClass("player") or "?"
    local name, known, source, id = ResolveSpell()
    local lines = {}

    lines[#lines + 1] = string.format(L["Class: %s"], className)
    if source == "custom" and not name then
        lines[#lines + 1] = red .. string.format(L["ID %s is not a valid spell."], tostring(c.customSpell)) .. "|r"
    elseif not name then
        lines[#lines + 1] = red .. L["Your class has no combat res."] .. "|r"
    elseif known then
        lines[#lines + 1] = green .. string.format(L["Spell: %s (ID %d)"], name, id) .. "|r"
            .. (source == "custom" and grey .. L[" custom"] .. "|r" or "")
    else
        lines[#lines + 1] = red .. string.format(L["Spell: %s (ID %d, not learned yet)"], name, id) .. "|r"
    end

    if not c.enabled then
        lines[#lines + 1] = grey .. L["Status: disabled"] .. "|r"
    elseif c.key == "" then
        lines[#lines + 1] = grey .. L["Status: choose a key"] .. "|r"
    elseif pending then
        lines[#lines + 1] = "|cffffd060" .. L["Status: will apply after combat"] .. "|r"
    elseif applied.active then
        lines[#lines + 1] = green .. string.format(L["Status: active on %s"], c.key) .. "|r"
    else
        lines[#lines + 1] = red .. L["Status: inactive"] .. "|r"
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
}) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    Brez.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
end)

function Brez.Slash(arg)
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    if cmd == "key" and rest ~= "" then
        cfg().key = rest:upper()
        Brez.Apply()
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(PREFIX .. string.format(L["Brez key: %s"], cfg().key) .. (pending and L[" (will apply after combat)"] or ""))
    elseif cmd == "status" then
        print(PREFIX .. (Brez.StatusText():gsub("\n", " | ")))
    else
        print(PREFIX .. L["Usage: /modi brez key <key> | status"])
    end
end
