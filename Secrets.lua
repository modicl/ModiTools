-- Utilidades para trabajar con "valores secretos" (Midnight).
--
-- En contenido restringido (combate, encuentros, Mythic+, PvP) el juego devuelve ciertos datos como valores
-- secretos: un addon puede guardarlos y pasarlos a widgets, pero NO puede compararlos, hacer cuentas con ellos
-- ni usarlos en un `if`. Dos reglas que se siguen en todo el addon:
--   1. Preguntar antes con los predicados oficiales C_Secrets.Should*BeSecret (en vez de "probar y atrapar el error").
--   2. Para saber si una función devolvió algo sin mirar el valor, usar select("#", ...).

local _, ns = ...

local Secrets = {}
ns.Secrets = Secrets

-- Llama a un predicado de C_Secrets: true / false, o nil si el cliente no tiene esa función.
local function Predicate(name, ...)
    local fn = C_Secrets and C_Secrets[name]
    if not fn then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result and true or false end
    return nil
end

-- ¿La información de casteo de esta unidad vendrá como secreta?
function Secrets.CastIsSecret(unit)
    return Predicate("ShouldUnitSpellCastingBeSecret", unit)
end

-- ¿El estado de threat de esta unidad vendrá como secreto?
function Secrets.ThreatIsSecret(unit, mobUnit)
    return Predicate("ShouldUnitThreatStateBeSecret", unit, mobUnit)
end

-- ¿El cooldown de este hechizo vendrá como secreto?
function Secrets.SpellCooldownIsSecret(spellID)
    return Predicate("ShouldSpellCooldownBeSecret", spellID)
end

-- Devuelve (cantidad de valores, primer valor) sin inspeccionar ese valor.
local function Count(...)
    return select("#", ...), ...
end

-- ¿La función devolvió un valor real? No devolver nada o devolver nil significa "no hay".
-- Un valor secreto siempre cuenta como presente (y nunca se compara).
local function Present(n, value)
    if n == 0 then return false end
    if issecretvalue and issecretvalue(value) then return true end
    return value ~= nil
end

-- Duración del casteo de una unidad sin mirar ningún valor secreto: devuelve (esCanalizado, objetoDeDuración),
-- o nil si no está casteando.
function Secrets.CastDuration(unit)
    if UnitCastingDuration then
        local n, duration = Count(UnitCastingDuration(unit))
        if Present(n, duration) then return false, duration end
    end
    if UnitChannelDuration then
        local n, duration = Count(UnitChannelDuration(unit))
        if Present(n, duration) then return true, duration end
    end
    return nil
end
