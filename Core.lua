-- ModiTools: núcleo compartido (base de datos, utilidades de marcos y comandos).
--
-- /modi                         -> abrir opciones
-- /modi yards | focus | marked | prepot  -> activar/desactivar la herramienta
-- /modi unlock <yards|focus|marked|threat|brez|timeline|prepot|all>
-- /modi lock   <yards|focus|marked|threat|brez|timeline|prepot|all>
-- /modi reset                   -> restablece posiciones
-- /modi size <10-72>            -> tamaño de la fuente de las yardas
-- /modi prepot test|add <id>|remove <id>
-- /modi debug                   -> muestra los eventos de casteo del focus

local ADDON_NAME, ns = ...
local L = ns.L

ns.PREFIX = "|cff33aaffModiTools:|r "
ns.defaults = {}
ns.modules = {}
ns.order = {}
ns.debug = false
ns.globalDefaults = {}

-- Fuentes disponibles para los textos que permiten elegir tipo de letra.
ns.FONT_PATHS = {
    default = STANDARD_TEXT_FONT,
    frizqt = "Fonts/FRIZQT__.TTF",
    arialn = "Fonts/ARIALN.TTF",
    morpheus = "Fonts/MORPHEUS.TTF",
}
function ns.FontPath(key)
    return ns.FONT_PATHS[key] or STANDARD_TEXT_FONT
end   -- ajustes comunes a todos los perfiles (ventana, minimapa, idioma)

function ns.RegisterModule(key, defaults, mod)
    ns.defaults[key] = defaults
    ns.modules[key] = mod
    ns.order[#ns.order + 1] = key
end

function ns.DeepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = ns.DeepCopy(x) end
    return t
end

local function MergeDefaults(target, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

ns.MergeDefaults = MergeDefaults

---------------------------------------------------------------------------
-- Utilidades de marcos
---------------------------------------------------------------------------

function ns.ApplyPosition(frame, cfg)
    frame:ClearAllPoints()
    frame:SetPoint(cfg.point, UIParent, cfg.point, cfg.x, cfg.y)
end

function ns.MakeMovable(frame, cfg)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if cfg.unlocked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        cfg.point, cfg.x, cfg.y = point, x, y
    end)
end

-- Tinte azul sobre el marco mientras está desbloqueado.
function ns.ApplyLockVisuals(frame, cfg)
    if not frame.unlockTex then
        local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetAllPoints()
        t:SetColorTexture(0, 0.4, 0.8, 0.35)
        frame.unlockTex = t
    end
    local show = cfg.enabled and cfg.unlocked and true or false
    frame:EnableMouse(show)
    frame.unlockTex:SetShown(show)
end

function ns.ResetModule(key)
    local keep = { enabled = true, unlocked = true, point = true, x = true, y = true, extra = true, spells = true, spellSounds = true }
    local cfg = ns.db[key]
    for k, v in pairs(ns.defaults[key]) do
        if not keep[k] then cfg[k] = ns.DeepCopy(v) end
    end
    ns.modules[key].Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

---------------------------------------------------------------------------
-- Carga
---------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    ns.InitProfiles()
    ns.SetLanguage(ns.global.language or ns.DetectLanguage())

    for _, key in ipairs(ns.order) do
        ns.modules[key].Apply()
    end
    ns.CreateOptions()
end)

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------

local function Targets(arg)
    if arg == "all" then return ns.order end
    if ns.modules[arg] then return { arg } end
    return nil
end

local function OpenOptions()
    if ns.ToggleWindow then ns.ToggleWindow() end
end

local function Help()
    print(ns.PREFIX .. "/modi, /modi yards|focus|marked|threat|brez|timeline|prepot, /modi unlock|lock <yards|focus|marked|threat|brez|timeline|prepot|all>, /modi reset, /modi minimap, /modi lang en|es, /modi profile, /modi size <n>, /modi prepot test|add <id>|remove <id>")
end

SLASH_MODITOOLS1 = "/modi"
SLASH_MODITOOLS2 = "/moditools"
SlashCmdList["MODITOOLS"] = function(msg)
    local db = ns.db
    -- solo el comando se pasa a minúsculas: el resto (texto, rutas) conserva su formato
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "options" then
        OpenOptions()
    elseif ns.modules[cmd] then
        local mod = ns.modules[cmd]
        if arg == "" then
            db[cmd].enabled = not db[cmd].enabled
            mod.Apply()
            if ns.RefreshOptions then ns.RefreshOptions() end
            print(ns.PREFIX .. string.format(db[cmd].enabled and L["%s enabled."] or L["%s disabled."], cmd))
        elseif mod.Slash then
            mod.Slash(arg)
        else
            Help()
        end
    elseif cmd == "unlock" or cmd == "lock" then
        local list = Targets(arg:lower())
        if not list then
            print(ns.PREFIX .. string.format(L["Usage: /modi %s <yards|focus|marked|threat|brez|timeline|prepot|all>"], cmd))
            return
        end
        for _, key in ipairs(list) do
            if not ns.modules[key].noPosition then
                db[key].unlocked = (cmd == "unlock")
                ns.modules[key].Apply()
            end
        end
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(ns.PREFIX .. (cmd == "unlock"
            and L["unlocked. Drag with left click to move."]
            or L["locked."]))
    elseif cmd == "reset" then
        for _, key in ipairs(ns.order) do
            local d = ns.defaults[key]
            if not ns.modules[key].noPosition then
                db[key].point, db[key].x, db[key].y = d.point, d.x, d.y
                ns.modules[key].Apply()
            end
        end
        print(ns.PREFIX .. L["positions reset."])
    elseif cmd == "size" then
        local n = tonumber(arg)
        if n and n >= 10 and n <= 72 then
            db.yards.fontSize = n
            ns.modules.yards.Apply()
            if ns.RefreshOptions then ns.RefreshOptions() end
        else
            print(ns.PREFIX .. L["Usage: /modi size <10-72>"])
        end
    elseif cmd == "minimap" then
        ns.global.minimap.hide = not ns.global.minimap.hide
        if ns.UpdateMinimap then ns.UpdateMinimap() end
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(ns.PREFIX .. (ns.global.minimap.hide and L["Minimap icon hidden."] or L["Minimap icon shown."]))
    elseif cmd == "lang" then
        local lang = arg:lower()
        if lang == "en" or lang == "es" then
            ns.ChangeLanguage(lang)
        else
            print(ns.PREFIX .. L["Usage: /modi lang en|es"])
        end
    elseif cmd == "profile" then
        local sub, rest = arg:match("^(%S*)%s*(.*)$")
        if sub:lower() == "use" and rest ~= "" then
            local ok, err = ns.SetProfile(rest)
            print(ns.PREFIX .. (ok and string.format(L["Profile '%s' is now active."], rest) or err))
        else
            print(ns.PREFIX .. string.format(L["Profiles: %s (active: %s)"], table.concat(ns.ListProfiles(), ", "), ns.profileName))
            print(ns.PREFIX .. L["Usage: /modi profile use <name>"])
        end
    elseif cmd == "diag" then
        -- diagnóstico: qué datos de casteo entrega el cliente (útil en Mythic+ / contenido restringido)
        local function secret(v) return issecretvalue and issecretvalue(v) or false end
        local shown = false
        for _, unit in ipairs({ "focus", "target", "nameplate1", "nameplate2" }) do
            if UnitExists(unit) then
                shown = true
                local ok, name, _, _, startMS = pcall(UnitCastingInfo, unit)
                local dur = (UnitCastingDuration and UnitCastingDuration(unit))
                    or (UnitChannelDuration and UnitChannelDuration(unit))
                print(ns.PREFIX .. string.format("%s: duration object=%s, name secret=%s, time secret=%s, raid marker=%s",
                    unit, tostring(dur ~= nil), tostring(ok and secret(name)), tostring(ok and secret(startMS)),
                    tostring(GetRaidTargetIndex and GetRaidTargetIndex(unit))))
            end
        end
        if not shown then print(ns.PREFIX .. "diag: target a casting enemy (or focus it) and run again.") end
    elseif cmd == "debug" then
        ns.debug = not ns.debug
        print(ns.PREFIX .. (ns.debug and L["Debug enabled."] or L["Debug disabled."]))
    else
        Help()
    end
end
