-- Perfiles: guardar, cambiar, copiar y compartir la configuración por código.
--
-- ModiToolsDB = {
--     global   = { window, minimap, language },       -- común a todos los perfiles
--     profiles = { [nombre] = { yards = {...}, focus = {...}, ... } },
--     chars    = { ["Personaje-Reino"] = nombre },     -- perfil activo de cada personaje
-- }
-- ns.db apunta siempre al perfil activo del personaje.

local _, ns = ...
local L = ns.L

local DEFAULT_PROFILE = "Default"
local CODE_PREFIX = "MT1:"
local MAX_NAME = 24

local function charKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

-- Las vistas previas (desbloqueado) nunca se conservan: ni al reloguear ni al cambiar de perfil.
local function ClearPreviews(profile)
    for key in pairs(ns.defaults) do
        if type(profile[key]) == "table" then profile[key].unlocked = false end
    end
end

local function CleanName(name)
    name = tostring(name or ""):gsub("[%c]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    return name:sub(1, MAX_NAME)
end

local function UniqueName(name)
    local profiles = ns.root.profiles
    if not profiles[name] then return name end
    local i = 2
    while profiles[name:sub(1, MAX_NAME - 4) .. " (" .. i .. ")"] do i = i + 1 end
    return name:sub(1, MAX_NAME - 4) .. " (" .. i .. ")"
end

---------------------------------------------------------------------------
-- Inicio y cambio de perfil
---------------------------------------------------------------------------

function ns.InitProfiles()
    ModiToolsDB = ModiToolsDB or {}
    local root = ModiToolsDB

    -- migración desde la versión sin perfiles (todo estaba en la raíz)
    if not root.profiles then
        local legacy = {}
        for key in pairs(ns.defaults) do
            legacy[key] = root[key]
            root[key] = nil
        end
        root.global = root.global or {}
        for _, k in ipairs({ "window", "minimap", "language" }) do
            root.global[k] = root[k]
            root[k] = nil
        end
        root.profiles = { [DEFAULT_PROFILE] = legacy }
    end
    root.global = root.global or {}
    root.chars = root.chars or {}

    ns.root = root
    ns.global = root.global
    ns.MergeDefaults(ns.global, ns.globalDefaults)

    local name = root.chars[charKey()] or DEFAULT_PROFILE
    if not root.profiles[name] then name = DEFAULT_PROFILE end
    root.profiles[name] = root.profiles[name] or {}
    root.chars[charKey()] = name

    ns.profileName = name
    ns.db = root.profiles[name]
    ns.MergeDefaults(ns.db, ns.defaults)
    ClearPreviews(ns.db)
end

function ns.ListProfiles()
    local names = {}
    for name in pairs(ns.root.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function ns.SetProfile(name)
    local root = ns.root
    if not root.profiles[name] then return false, L["Profile not found."] end
    root.chars[charKey()] = name
    ns.profileName = name
    ns.db = root.profiles[name]
    ns.MergeDefaults(ns.db, ns.defaults)
    ClearPreviews(ns.db)
    for _, key in ipairs(ns.order) do ns.modules[key].Apply() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true
end

-- Crea un perfil como copia del actual (o de `source`) y lo activa.
function ns.CreateProfile(name, source)
    name = CleanName(name)
    if name == "" then return false, L["Type a name first."] end
    if ns.root.profiles[name] then return false, L["A profile with that name already exists."] end
    local from = ns.root.profiles[source or ns.profileName]
    ns.root.profiles[name] = ns.DeepCopy(from or {})
    ns.SetProfile(name)
    return true, name
end

function ns.RenameProfile(newName)
    newName = CleanName(newName)
    if newName == "" then return false, L["Type a name first."] end
    if ns.root.profiles[newName] then return false, L["A profile with that name already exists."] end
    local old = ns.profileName
    ns.root.profiles[newName] = ns.root.profiles[old]
    ns.root.profiles[old] = nil
    for char, p in pairs(ns.root.chars) do
        if p == old then ns.root.chars[char] = newName end
    end
    ns.profileName = newName
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true, newName
end

function ns.DeleteProfile(name)
    local profiles = ns.root.profiles
    if not profiles[name] then return false, L["Profile not found."] end
    local count = 0
    for _ in pairs(profiles) do count = count + 1 end
    if count <= 1 then return false, L["You cannot delete the only profile."] end
    profiles[name] = nil
    if ns.profileName == name then
        local fallback = profiles[DEFAULT_PROFILE] and DEFAULT_PROFILE or ns.ListProfiles()[1]
        ns.SetProfile(fallback)
    elseif ns.RefreshOptions then
        ns.RefreshOptions()
    end
    return true
end

function ns.ResetProfile()
    ns.root.profiles[ns.profileName] = {}
    ns.SetProfile(ns.profileName)
end

---------------------------------------------------------------------------
-- Serialización (formato propio, sin loadstring: el código importado nunca se ejecuta)
---------------------------------------------------------------------------

local function Serialize(value, out)
    local t = type(value)
    if t == "number" then
        out[#out + 1] = "n" .. string.format("%.10g", value) .. ";"
    elseif t == "boolean" then
        out[#out + 1] = value and "T" or "F"
    elseif t == "string" then
        out[#out + 1] = "s" .. #value .. ":" .. value
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, v in pairs(value) do
            Serialize(k, out)
            Serialize(v, out)
        end
        out[#out + 1] = "}"
    end
end

local function Deserialize(str)
    local pos = 1
    local function parse(depth)
        if depth > 8 then error("depth") end
        local c = str:sub(pos, pos)
        pos = pos + 1
        if c == "n" then
            local e = str:find(";", pos, true)
            local num = e and tonumber(str:sub(pos, e - 1))
            if not num then error("number") end
            pos = e + 1
            return num
        elseif c == "T" then
            return true
        elseif c == "F" then
            return false
        elseif c == "s" then
            local e = str:find(":", pos, true)
            local len = e and tonumber(str:sub(pos, e - 1))
            if not len or len < 0 or len > 5000 then error("length") end
            local s = str:sub(e + 1, e + len)
            if #s ~= len then error("truncated") end
            pos = e + len + 1
            return s
        elseif c == "{" then
            local t = {}
            while str:sub(pos, pos) ~= "}" do
                if pos > #str then error("eof") end
                local k = parse(depth + 1)
                local v = parse(depth + 1)
                if type(k) ~= "string" and type(k) ~= "number" then error("key") end
                t[k] = v
            end
            pos = pos + 1
            return t
        end
        error("token")
    end
    return parse(0)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, #B64 do B64_INDEX[B64:sub(i, i)] = i - 1 end

local function Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function Base64Decode(text)
    text = text:gsub("[^%w%+/=]", "")
    local out = {}
    for i = 1, #text, 4 do
        local chunk = text:sub(i, i + 3)
        if #chunk < 4 then error("length") end
        local a, b = B64_INDEX[chunk:sub(1, 1)], B64_INDEX[chunk:sub(2, 2)]
        local c, d = B64_INDEX[chunk:sub(3, 3)], B64_INDEX[chunk:sub(4, 4)]
        if not a or not b then error("char") end
        local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if d then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- Exportar / importar
---------------------------------------------------------------------------

function ns.ExportProfile(name)
    local data = ns.root.profiles[name or ns.profileName]
    if not data then return nil, L["Profile not found."] end
    local copy = ns.DeepCopy(data)
    ClearPreviews(copy)
    local out = {}
    Serialize({ name = name or ns.profileName, data = copy }, out)
    return CODE_PREFIX .. Base64Encode(table.concat(out))
end

-- Reconstruye un valor a partir de los valores por defecto: solo se aceptan campos conocidos
-- y del tipo correcto, así un código ajeno no puede colar datos inesperados.
local function Sanitize(value, default)
    if type(default) == "table" then
        local out = {}
        for k, d in pairs(default) do
            local v
            if type(value) == "table" then v = value[k] end
            out[k] = Sanitize(v, d)
        end
        -- tablas sin campos fijos (p. ej. prepot.extra: lista de spellIDs)
        if next(default) == nil and type(value) == "table" then
            for k, v in pairs(value) do
                if (type(k) == "number" or type(k) == "string") and type(v) == "boolean" then out[k] = v end
            end
        end
        return out
    end
    if type(value) == type(default) then
        if type(value) == "string" then return value:sub(1, 200) end
        if type(value) == "number" and (value ~= value or math.abs(value) > 10000) then
            return default
        end
        return value
    end
    return ns.DeepCopy(default)
end

-- Devuelve el nombre del perfil creado, o nil y el motivo del error.
function ns.ImportProfile(code, newName)
    code = tostring(code or ""):gsub("%s+", "")
    if code == "" then return nil, L["Paste a code first."] end
    if code:sub(1, #CODE_PREFIX) ~= CODE_PREFIX then return nil, L["Invalid profile code."] end

    local ok, payload = pcall(function()
        return Deserialize(Base64Decode(code:sub(#CODE_PREFIX + 1)))
    end)
    if not ok or type(payload) ~= "table" or type(payload.data) ~= "table" then
        return nil, L["Invalid profile code."]
    end

    local name = CleanName(newName)
    if name == "" then name = CleanName(payload.name) end
    if name == "" then name = "Imported" end
    name = UniqueName(name)

    local clean = {}
    for key, defaults in pairs(ns.defaults) do
        clean[key] = Sanitize(payload.data[key], defaults)
    end
    ClearPreviews(clean)
    ns.root.profiles[name] = clean
    return name
end
