-- ModiTools: núcleo compartido (base de datos, utilidades de marcos y comandos).
--
-- /modi                         -> abrir opciones
-- /modi yards | focus | marked | prepot  -> activar/desactivar la herramienta
-- /modi unlock <yards|focus|marked|prepot|all>
-- /modi lock   <yards|focus|marked|prepot|all>
-- /modi reset                   -> restablece posiciones
-- /modi size <10-72>            -> tamaño de la fuente de las yardas
-- /modi prepot test|add <id>|remove <id>
-- /modi debug                   -> muestra los eventos de casteo del focus

local ADDON_NAME, ns = ...

ns.PREFIX = "|cff33aaffModiTools:|r "
ns.defaults = {}
ns.modules = {}
ns.order = {}
ns.debug = false

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
    local keep = { enabled = true, unlocked = true, point = true, x = true, y = true, extra = true }
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

    ModiToolsDB = ModiToolsDB or {}
    ns.db = ModiToolsDB
    MergeDefaults(ns.db, ns.defaults)

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
    if Settings and Settings.OpenToCategory and ns.categoryID then
        Settings.OpenToCategory(ns.categoryID)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("ModiTools")
    end
end

local function Help()
    print(ns.PREFIX .. "/modi, /modi yards|focus|marked|prepot, /modi unlock|lock <yards|focus|marked|prepot|all>, /modi reset, /modi size <n>, /modi prepot test|add <id>|remove <id>")
end

SLASH_MODITOOLS1 = "/modi"
SLASH_MODITOOLS2 = "/moditools"
SlashCmdList["MODITOOLS"] = function(msg)
    local db = ns.db
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")

    if cmd == "" or cmd == "options" then
        OpenOptions()
    elseif ns.modules[cmd] then
        local mod = ns.modules[cmd]
        if arg == "" then
            db[cmd].enabled = not db[cmd].enabled
            mod.Apply()
            if ns.RefreshOptions then ns.RefreshOptions() end
            print(ns.PREFIX .. cmd .. (db[cmd].enabled and " activado." or " desactivado."))
        elseif mod.Slash then
            mod.Slash(arg)
        else
            Help()
        end
    elseif cmd == "unlock" or cmd == "lock" then
        local list = Targets(arg)
        if not list then
            print(ns.PREFIX .. "uso: /modi " .. cmd .. " <yards|focus|marked|prepot|all>")
            return
        end
        for _, key in ipairs(list) do
            db[key].unlocked = (cmd == "unlock")
            ns.modules[key].Apply()
        end
        if ns.RefreshOptions then ns.RefreshOptions() end
        print(ns.PREFIX .. (cmd == "unlock"
            and "desbloqueado. Arrastra con click izquierdo para mover."
            or "fijado."))
    elseif cmd == "reset" then
        for _, key in ipairs(ns.order) do
            local d = ns.defaults[key]
            db[key].point, db[key].x, db[key].y = d.point, d.x, d.y
            ns.modules[key].Apply()
        end
        print(ns.PREFIX .. "posiciones restablecidas.")
    elseif cmd == "size" then
        local n = tonumber(arg)
        if n and n >= 10 and n <= 72 then
            db.yards.fontSize = n
            ns.modules.yards.Apply()
            if ns.RefreshOptions then ns.RefreshOptions() end
        else
            print(ns.PREFIX .. "uso: /modi size <10-72>")
        end
    elseif cmd == "debug" then
        ns.debug = not ns.debug
        print(ns.PREFIX .. "depuración " .. (ns.debug and "activada." or "desactivada."))
    else
        Help()
    end
end
