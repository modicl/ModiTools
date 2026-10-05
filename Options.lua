-- Interfaz de ModiTools: ventana propia con estilo "Steam clásico"
-- (verde oliva, bordes biselados, acento dorado).
-- Barra lateral de navegación a la izquierda y una página por herramienta a la derecha.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Paleta y utilidades de estilo
---------------------------------------------------------------------------

local C = {
    bg       = { 0.298, 0.345, 0.267 },   -- #4C5844
    bgDark   = { 0.243, 0.275, 0.216 },   -- #3E4637
    bgDarker = { 0.165, 0.188, 0.145 },   -- #2A3025
    light    = { 0.533, 0.569, 0.502 },   -- #889180
    dark     = { 0.161, 0.180, 0.137 },   -- #292E23
    text     = { 1, 1, 1 },
    muted    = { 0.627, 0.667, 0.584 },   -- #A0AA95
    accent   = { 0.769, 0.710, 0.314 },   -- #C4B550
    hover    = { 0.361, 0.420, 0.322 },   -- #5C6B52
    select   = { 0.353, 0.416, 0.314 },   -- #5A6A50
}

local function rgb(c, a) return c[1], c[2], c[3], a or 1 end

-- Borde biselado de 1 px: claro arriba/izquierda y oscuro abajo/derecha (hundido al revés).
local function Bevel(f, sunken)
    if not f.bev then
        local b = {}
        for _, k in ipairs({ "top", "left", "bottom", "right" }) do
            b[k] = f:CreateTexture(nil, "BORDER")
        end
        b.top:SetPoint("TOPLEFT"); b.top:SetPoint("TOPRIGHT"); b.top:SetHeight(1)
        b.bottom:SetPoint("BOTTOMLEFT"); b.bottom:SetPoint("BOTTOMRIGHT"); b.bottom:SetHeight(1)
        b.left:SetPoint("TOPLEFT"); b.left:SetPoint("BOTTOMLEFT"); b.left:SetWidth(1)
        b.right:SetPoint("TOPRIGHT"); b.right:SetPoint("BOTTOMRIGHT"); b.right:SetWidth(1)
        f.bev = b
    end
    local tl, br = C.light, C.dark
    if sunken then tl, br = C.dark, C.light end
    f.bev.top:SetColorTexture(rgb(tl))
    f.bev.left:SetColorTexture(rgb(tl))
    f.bev.bottom:SetColorTexture(rgb(br))
    f.bev.right:SetColorTexture(rgb(br))
end

local function Skin(f, color, sunken)
    if not f.fill then
        f.fill = f:CreateTexture(nil, "BACKGROUND")
        f.fill:SetAllPoints()
    end
    f.fill:SetColorTexture(rgb(color))
    Bevel(f, sunken)
end

-- Mayúsculas que también cubren las vocales acentuadas del español (string.upper no lo hace).
local ACCENTS = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
local function Upper(text)
    return (string.upper(text):gsub("[\195][\161-\188]", function(ch) return ACCENTS[ch] or ch end))
end

local function Label(parent, text, size, color)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont(STANDARD_TEXT_FONT, size or 12, "")
    fs:SetTextColor(rgb(color or C.text))
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    return fs
end

local function CreateButton(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    Skin(b, C.bg, false)
    b.label = Label(b, text, 12, C.text)
    b.label:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self) self.fill:SetColorTexture(rgb(C.hover)) end)
    b:SetScript("OnLeave", function(self) self.fill:SetColorTexture(rgb(C.bg)) end)
    b:SetScript("OnMouseDown", function(self)
        Bevel(self, true)
        self.label:SetPoint("CENTER", 1, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
        Bevel(self, false)
        self.label:SetPoint("CENTER", 0, 0)
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

---------------------------------------------------------------------------
-- Selector de color (compatible con la API nueva y la antigua)
---------------------------------------------------------------------------

local function OpenColor(c, withAlpha, onChange)
    local r, g, b, a = c[1], c[2], c[3], c[4] or 1

    local function commit()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = a
        if withAlpha then
            if ColorPickerFrame.GetColorAlpha then
                na = ColorPickerFrame:GetColorAlpha()
            elseif OpacitySliderFrame then
                na = 1 - OpacitySliderFrame:GetValue()
            end
        end
        onChange(nr, ng, nb, na)
    end
    local function cancel() onChange(r, g, b, a) end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            opacity = a, hasOpacity = withAlpha and true or false,
            swatchFunc = commit, opacityFunc = commit, cancelFunc = cancel,
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = withAlpha and true or false
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.previousValues = { r, g, b, a }
        ColorPickerFrame.func = commit
        ColorPickerFrame.opacityFunc = commit
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end
end

---------------------------------------------------------------------------
-- Dropdown compartido.
-- Listas planas: se muestran directo. Listas con encabezados (header = true):
-- primero se elige la categoría y luego el elemento. Si options.preview existe,
-- cada elemento trae su botón "Probar" dentro de la lista.
---------------------------------------------------------------------------

local ITEM_H = 22
local TITLE_H = 24
local MAX_ROWS = 9
local MENU_W = 220
local SCROLL_W = 14
local PLAY_W = 46
local menu

local function BuildGroups(options)
    if options._groups ~= nil then return options._groups end
    local groups, cur = {}, nil
    for _, e in ipairs(options) do
        if e.header then
            cur = { label = e.label, items = {} }
            groups[#groups + 1] = cur
        elseif cur then
            cur.items[#cur.items + 1] = e
        end
    end
    options._groups = (#groups > 0) and groups or false
    return options._groups
end

local function RenderMenu(m)
    local total = #m.entries
    local rows = math.min(total, MAX_ROWS)
    local maxOffset = math.max(0, total - MAX_ROWS)
    m.offset = math.max(0, math.min(m.offset, maxOffset))

    for i = 1, rows do
        local entry = m.entries[m.offset + i]
        local item = m.items[i]
        item.entry = entry
        item.text:SetText(entry.label)
        if entry.isCategory then
            item.arrow:Show()
            item.play:Hide()
            item.text:SetTextColor(rgb(entry.hasCurrent and C.accent or C.text))
        else
            item.arrow:Hide()
            item.play:SetShown(m.preview ~= nil)
            item.text:SetTextColor(rgb(entry.value == m.current and C.accent or C.text))
        end
        item:Show()
    end
    for i = rows + 1, #m.items do m.items[i]:Hide() end

    if maxOffset > 0 then
        m.scroll.loading = true
        m.scroll:SetMinMaxValues(0, maxOffset)
        m.scroll:SetValue(m.offset)
        m.scroll.loading = false
    end
end

-- Muestra una lista (categorías, elementos de una categoría o lista plana).
local function ShowList(m, entries, title, focusValue)
    m.entries = entries
    local total = #entries
    local rows = math.min(total, MAX_ROWS)
    local scrollable = total > MAX_ROWS
    local top = title and TITLE_H or 0

    m.titleBar:SetShown(title ~= nil)
    if title then m.titleBar.text:SetText("<  " .. title) end

    local rightInset = 2 + (scrollable and SCROLL_W or 0)
    for i = 1, MAX_ROWS do
        local item = m.items[i]
        item:SetPoint("TOPLEFT", 2, -2 - top - (i - 1) * ITEM_H)
        item:SetPoint("TOPRIGHT", -rightInset, -2 - top - (i - 1) * ITEM_H)
    end
    m.scroll:ClearAllPoints()
    m.scroll:SetPoint("TOPRIGHT", -3, -3 - top)
    m.scroll:SetPoint("BOTTOMRIGHT", -3, 3)
    m.scroll:SetShown(scrollable)

    m.offset = 0
    if focusValue ~= nil then
        for i, e in ipairs(entries) do
            if e.value == focusValue then m.offset = i - math.floor(rows / 2) end
        end
    end

    m:SetSize(MENU_W, top + rows * ITEM_H + 4)
    RenderMenu(m)
end

local function ShowCategories(m)
    local cats = {}
    for gi, g in ipairs(m.groups) do
        local has = false
        for _, e in ipairs(g.items) do
            if e.value == m.current then has = true end
        end
        cats[#cats + 1] = { label = g.label, isCategory = true, group = gi, hasCurrent = has }
    end
    ShowList(m, cats, nil)
end

local function GetMenu()
    if menu then return menu end
    menu = CreateFrame("Frame", "ModiToolsDropdownMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    Skin(menu, C.bgDarker, false)
    menu.items = {}
    menu.entries = {}
    menu.offset = 0

    -- barra superior para volver a las categorías
    local bar = CreateFrame("Button", nil, menu)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("TOPRIGHT", -2, -2)
    Skin(bar, C.bg, false)
    bar.text = Label(bar, "", 12, C.accent)
    bar.text:SetPoint("LEFT", 8, 0)
    bar:SetScript("OnEnter", function(self) self.fill:SetColorTexture(rgb(C.hover)) end)
    bar:SetScript("OnLeave", function(self) self.fill:SetColorTexture(rgb(C.bg)) end)
    bar:SetScript("OnClick", function() ShowCategories(menu) end)
    bar:Hide()
    menu.titleBar = bar

    for i = 1, MAX_ROWS do
        local item = CreateFrame("Button", nil, menu)
        item:SetHeight(ITEM_H)
        item.hl = item:CreateTexture(nil, "HIGHLIGHT")
        item.hl:SetAllPoints()
        item.hl:SetColorTexture(rgb(C.hover, 0.8))
        item.text = Label(item, "", 12, C.text)
        item.text:SetPoint("LEFT", 10, 0)
        item.arrow = Label(item, ">", 12, C.accent)
        item.arrow:SetPoint("RIGHT", -8, 0)

        -- botón de prueba dentro de la fila: no selecciona el elemento
        local play = CreateButton(item, L["Play"], PLAY_W, ITEM_H - 6)
        play:SetPoint("RIGHT", -2, 0)
        play.label:SetFont(STANDARD_TEXT_FONT, 10, "")
        play.fill:SetColorTexture(rgb(C.select))
        play:SetScript("OnLeave", function(self) self.fill:SetColorTexture(rgb(C.select)) end)
        play:SetScript("OnClick", function()
            if item.entry and menu.preview then menu.preview(item.entry.value) end
        end)
        item.play = play
        item.text:SetPoint("RIGHT", play, "LEFT", -4, 0)

        item:SetScript("OnClick", function(self)
            local e = self.entry
            if not e then return end
            if e.isCategory then
                ShowList(menu, menu.groups[e.group].items, menu.groups[e.group].label, menu.current)
            else
                menu:Hide()
                menu.onSelect(e.value)
            end
        end)
        menu.items[i] = item
    end

    menu.scroll = CreateFrame("Slider", nil, menu)
    menu.scroll:SetOrientation("VERTICAL")
    menu.scroll:SetWidth(10)
    menu.scroll:SetValueStep(1)
    if menu.scroll.SetObeyStepOnDrag then menu.scroll:SetObeyStepOnDrag(true) end
    Skin(menu.scroll, C.bgDark, true)
    menu.scroll:SetThumbTexture("Interface/Buttons/WHITE8x8")
    menu.scroll:GetThumbTexture():SetSize(10, 28)
    menu.scroll:GetThumbTexture():SetVertexColor(rgb(C.muted))
    menu.scroll:SetScript("OnValueChanged", function(self, v)
        if self.loading then return end
        menu.offset = math.floor(v + 0.5)
        RenderMenu(menu)
    end)

    menu:SetScript("OnMouseWheel", function(self, delta)
        self.offset = self.offset - delta * 3
        RenderMenu(self)
    end)

    -- se cierra al hacer click fuera de la lista y del botón que la abrió
    menu:SetScript("OnUpdate", function(self)
        if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
            and not self:IsMouseOver()
            and not (self.owner and self.owner:IsMouseOver()) then
            self:Hide()
        end
    end)
    menu:Hide()
    return menu
end

local function OpenMenu(owner, options, current, onSelect)
    local m = GetMenu()
    if m:IsShown() and m.owner == owner then
        m:Hide()
        return
    end
    m.owner = owner
    m.current = current
    m.onSelect = onSelect
    m.preview = options.preview
    m.groups = BuildGroups(options) or nil

    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    if m.groups then
        ShowCategories(m)
    else
        ShowList(m, options, nil, current)
    end
    m:Show()
end

---------------------------------------------------------------------------
-- Constructor de controles (cada página usa uno)
---------------------------------------------------------------------------

local ROW = 26
local ROW0 = -70
local COLX = { 16, 306 }
local MAXROWS = 15
local builders = {}

-- Casilla con estilo; devuelve la función que la sincroniza con el valor guardado.
local function CreateCheck(panel, x, y, text, get, set, help)
    local box = CreateFrame("Button", nil, panel)
    box:SetSize(18, 18)
    box:SetPoint("TOPLEFT", x, y - 2)
    Skin(box, C.bgDarker, true)
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 4, -4)
    mark:SetPoint("BOTTOMRIGHT", -4, 4)
    mark:SetColorTexture(rgb(C.accent))
    local label = Label(panel, text, 12, C.text)
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    box:SetHitRectInsets(0, -(label:GetStringWidth() + 10), 0, 0)

    -- botón "?" con una explicación en el tooltip
    if help then
        local q = CreateFrame("Button", nil, panel)
        q:SetSize(16, 16)
        q:SetPoint("LEFT", label, "RIGHT", 8, 0)
        Skin(q, C.bg, false)
        q.sign = Label(q, "?", 11, C.accent)
        q.sign:SetPoint("CENTER", 0, 0)
        q:SetScript("OnEnter", function(self)
            self.fill:SetColorTexture(rgb(C.hover))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 0.82, 0)
            GameTooltip:AddLine(help, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        q:SetScript("OnLeave", function(self)
            self.fill:SetColorTexture(rgb(C.bg))
            GameTooltip:Hide()
        end)
    end

    local checked = false
    local function paint() mark:SetShown(checked) end
    box:SetScript("OnClick", function()
        checked = not checked
        paint()
        set(checked)
    end)
    box:SetScript("OnEnter", function() label:SetTextColor(rgb(C.accent)) end)
    box:SetScript("OnLeave", function() label:SetTextColor(rgb(C.text)) end)
    return function()
        checked = get() and true or false
        paint()
    end
end

local function NewBuilder(panel)
    local b = { panel = panel, col = 1, row = 0, refreshers = {} }

    -- Siguiente posición libre; pasa a la segunda columna al llenar la primera.
    function b:Next()
        if self.row >= MAXROWS then
            self.col = self.col + 1
            self.row = 0
        end
        local x = COLX[self.col] or COLX[#COLX]
        local y = ROW0 - self.row * ROW
        self.row = self.row + 1
        return x, y
    end

    function b:NewColumn()
        self.col = self.col + 1
        self.row = 0
    end

    function b:Refresh()
        for _, fn in ipairs(self.refreshers) do fn() end
    end

    function b:Header(text)
        local x, y = self:Next()
        local h = Label(panel, Upper(text), 12, C.accent)
        h:SetPoint("TOPLEFT", x, y - 6)
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", x, y - 22)
        line:SetSize(262, 1)
        line:SetColorTexture(rgb(C.light, 0.45))
    end

    function b:Check(text, get, set, help)
        local x, y = self:Next()
        self.refreshers[#self.refreshers + 1] = CreateCheck(panel, x, y, text, get, set, help)
    end

    function b:Slider(text, min, max, step, get, set)
        local x, y = self:Next()
        local label = Label(panel, text, 12, C.text)
        label:SetPoint("TOPLEFT", x, y - 4)
        label:SetWidth(118)

        local s = CreateFrame("Slider", nil, panel)
        s:SetPoint("TOPLEFT", x + 122, y - 7)
        s:SetSize(100, 10)
        s:SetOrientation("HORIZONTAL")
        s:EnableMouse(true)
        Skin(s, C.bgDarker, true)
        s:SetThumbTexture("Interface/Buttons/WHITE8x8")
        s:GetThumbTexture():SetSize(8, 18)
        s:GetThumbTexture():SetVertexColor(rgb(C.muted))
        s:SetMinMaxValues(min, max)
        s:SetValueStep(step)
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

        -- el valor se puede arrastrar con la barra o escribir en la cajita (solo números)
        local box = CreateFrame("EditBox", nil, panel)
        box:SetPoint("LEFT", s, "RIGHT", 8, 0)
        box:SetSize(40, 18)
        box:SetAutoFocus(false)
        box:SetMaxLetters(6)
        box:SetJustifyH("CENTER")
        box:SetFont(STANDARD_TEXT_FONT, 11, "")
        box:SetTextColor(rgb(C.accent))
        Skin(box, C.bgDarker, true)
        s.box = box
        s.caption = text

        local fmt = step < 1 and "%.2f" or "%d"
        local allowDot = step < 1
        local loading = false

        local function Snap(v)
            v = math.max(min, math.min(max, v))
            return math.floor(v / step + 0.5) * step
        end
        local function ShowValue(v)
            box:SetText(string.format(fmt, v))
        end

        s:SetScript("OnValueChanged", function(_, v)
            v = math.floor(v / step + 0.5) * step
            if not box:HasFocus() then ShowValue(v) end
            if loading then return end
            set(v)
        end)

        -- solo dígitos (y un punto decimal cuando el paso es menor a 1)
        box:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local raw = self:GetText() or ""
            local clean = raw:gsub(allowDot and "[^%d%.]" or "[^%d]", "")
            if allowDot then
                local first = clean:find("%.", 1)
                if first then clean = clean:sub(1, first) .. clean:sub(first + 1):gsub("%.", "") end
            end
            if clean ~= raw then self:SetText(clean) end
        end)
        local function Commit()
            local typed = tonumber(box:GetText())
            if typed then
                local v = Snap(typed)
                loading = true
                s:SetValue(v)       -- mueve la barra (sin guardar dos veces)
                loading = false
                set(v)              -- guarda el valor escrito
                ShowValue(v)
            else
                ShowValue(Snap(get()))
            end
        end
        box:SetScript("OnEnterPressed", function(self) Commit() self:ClearFocus() end)
        box:SetScript("OnEditFocusLost", function() Commit() end)
        box:SetScript("OnEscapePressed", function(self)
            ShowValue(Snap(get()))
            self:ClearFocus()
        end)
        self.refreshers[#self.refreshers + 1] = function()
            loading = true
            s:SetValue(get())
            loading = false
        end
    end

    -- Lista desplegable (ver OpenMenu).
    function b:Cycle(text, options, get, set)
        local x, y = self:Next()
        local label = Label(panel, text, 12, C.text)
        label:SetPoint("TOPLEFT", x, y - 4)
        label:SetWidth(118)

        local btn = CreateButton(panel, "", 140, 22)
        btn:SetPoint("TOPLEFT", x + 122, y)
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", 8, 0)
        btn.label:SetPoint("RIGHT", -20, 0)
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface/Buttons/Arrow-Down-Up")
        arrow:SetSize(14, 14)
        arrow:SetPoint("RIGHT", -4, -1)

        local function labelOf(value)
            for _, o in ipairs(options) do
                if o.value == value then return o.label end
            end
            return tostring(value)
        end
        btn:SetScript("OnClick", function(self)
            OpenMenu(self, options, get(), function(value)
                set(value)
                btn.label:SetText(labelOf(value))
            end)
        end)
        self.refreshers[#self.refreshers + 1] = function() btn.label:SetText(labelOf(get())) end
    end

    -- Muestra de color. withAlpha agrega el control de transparencia.
    function b:Color(text, key, field, withAlpha)
        local x, y = self:Next()
        local btn = CreateFrame("Button", nil, panel)
        btn:SetSize(22, 18)
        btn:SetPoint("TOPLEFT", x, y - 2)
        Skin(btn, C.bgDarker, true)
        local swatch = btn:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("TOPLEFT", 2, -2)
        swatch:SetPoint("BOTTOMRIGHT", -2, 2)

        local label = Label(panel, text, 12, C.text)
        label:SetPoint("LEFT", btn, "RIGHT", 8, 0)
        btn:SetHitRectInsets(0, -(label:GetStringWidth() + 10), 0, 0)
        btn:SetScript("OnEnter", function() label:SetTextColor(rgb(C.accent)) end)
        btn:SetScript("OnLeave", function() label:SetTextColor(rgb(C.text)) end)

        local function paint()
            local c = ns.db[key][field]
            swatch:SetColorTexture(c[1], c[2], c[3], 1)
        end
        btn:SetScript("OnClick", function()
            local c = ns.db[key][field]
            OpenColor(c, withAlpha, function(r, g, bl, a)
                c[1], c[2], c[3], c[4] = r, g, bl, a
                paint()
                ns.modules[key].Apply()
            end)
        end)
        self.refreshers[#self.refreshers + 1] = paint
    end

    -- Campo de texto de una línea (ocupa dos filas: etiqueta y caja).
    function b:Input(text, get, set, numeric)
        local x, y = self:Next()
        local label = Label(panel, text, 12, C.text)
        label:SetPoint("TOPLEFT", x, y - 4)
        local x2, y2 = self:Next()
        local eb = CreateFrame("EditBox", nil, panel)
        eb:SetPoint("TOPLEFT", x2, y2)
        eb:SetSize(262, 22)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(numeric and 10 or 60)
        if numeric then eb:SetNumeric(true) end
        eb:SetFont(STANDARD_TEXT_FONT, 12, "")
        eb:SetTextColor(rgb(C.text))
        eb:SetTextInsets(8, 8, 0, 0)
        Skin(eb, C.bgDarker, true)
        eb:SetScript("OnTextChanged", function(self, userInput)
            if userInput then set(self:GetText()) end
        end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        self.refreshers[#self.refreshers + 1] = function()
            if not eb:HasFocus() then eb:SetText(tostring(get() or "")) end
        end
    end

    -- Texto informativo de varias líneas; textFn devuelve el texto (se actualiza al refrescar).
    function b:Info(textFn, rows)
        local x, y = self:Next()
        for _ = 2, (rows or 1) do self:Next() end
        local fs = Label(panel, "", 11, C.muted)
        fs:SetPoint("TOPLEFT", x, y - 4)
        fs:SetWidth(262)
        fs:SetSpacing(3)
        fs:SetJustifyV("TOP")
        self.refreshers[#self.refreshers + 1] = function() fs:SetText(textFn()) end
    end

    -- Ícono (por ejemplo de un hechizo) con un texto a su derecha.
    -- texFn devuelve textura, spellID y si el hechizo está conocido.
    function b:IconInfo(textFn, texFn, rows)
        local x, y = self:Next()
        for _ = 2, (rows or 2) do self:Next() end

        local box = CreateFrame("Frame", nil, panel)
        box:SetSize(40, 40)
        box:SetPoint("TOPLEFT", x, y - 2)
        Skin(box, C.bgDarker, true)
        box:EnableMouse(true)
        local icon = box:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local fs = Label(panel, "", 11, C.muted)
        fs:SetPoint("TOPLEFT", box, "TOPRIGHT", 10, -2)
        fs:SetWidth(212)
        fs:SetSpacing(3)
        fs:SetJustifyV("TOP")

        local spellID
        box:SetScript("OnEnter", function(self)
            if not spellID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
            if ok then GameTooltip:Show() end
        end)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)

        self.refreshers[#self.refreshers + 1] = function()
            local tex, id, known = texFn()
            spellID = id
            icon:SetTexture(tex or "Interface/Icons/INV_Misc_QuestionMark")
            -- sin conocer el hechizo, o sin ninguno, el ícono se ve apagado
            icon:SetDesaturated(not tex or known == false)
            icon:SetAlpha((not tex or known == false) and 0.6 or 1)
            fs:SetText(textFn())
        end
    end

    -- Captura de una tecla (con modificadores y botones extra del mouse).
    local MODIFIER_KEYS = {
        LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
        LALT = true, RALT = true, LMETA = true, RMETA = true,
    }
    local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

    function b:KeyBind(text, get, set)
        local x, y = self:Next()
        local label = Label(panel, text, 12, C.text)
        label:SetPoint("TOPLEFT", x, y - 4)
        label:SetWidth(118)

        local btn = CreateButton(panel, "", 140, 22)
        btn:SetPoint("TOPLEFT", x + 122, y)
        local clear = CreateButton(panel, "X", 22, 22)
        clear:SetPoint("LEFT", btn, "RIGHT", 4, 0)

        local capturing = false
        local function paint()
            if capturing then
                btn.label:SetText(L["Press a key..."])
                btn.label:SetTextColor(rgb(C.accent))
            else
                local key = get()
                btn.label:SetText((key and key ~= "") and key or L["Unassigned"])
                btn.label:SetTextColor(rgb(C.text))
            end
        end
        local function finish(key)
            capturing = false
            btn:EnableKeyboard(false)
            if key then set(key) end
            paint()
        end

        btn:SetScript("OnClick", function(self)
            capturing = true
            self:EnableKeyboard(true)
            paint()
        end)
        btn:SetScript("OnKeyDown", function(_, key)
            if not capturing then return end
            if key == "ESCAPE" then finish(nil) return end
            if MODIFIER_KEYS[key] then return end
            local prefix = ""
            if IsAltKeyDown() then prefix = prefix .. "ALT-" end
            if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
            if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
            finish(prefix .. key)
        end)
        btn:HookScript("OnMouseDown", function(_, button)
            if not capturing then return end
            if MOUSE_KEYS[button] then
                finish(MOUSE_KEYS[button])
            else
                finish(nil)
            end
        end)
        clear:SetScript("OnClick", function() finish("") end)
        panel:HookScript("OnHide", function() if capturing then finish(nil) end end)
        self.refreshers[#self.refreshers + 1] = paint
    end

    -- Lista de hechizos (ícono, nombre e ID) con botón para quitar cada uno.
    function b:SpellList(getList, onRemove, maxRows)
        local rows = {}
        for i = 1, maxRows do
            local x, y = self:Next()
            local row = CreateFrame("Frame", nil, panel)
            row:SetSize(262, 22)
            row:SetPoint("TOPLEFT", x, y - 1)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", 0, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.name = Label(row, "", 11, C.text)
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.name:SetWidth(200)
            row.remove = CreateButton(row, "X", 20, 18, function()
                if row.id then onRemove(row.id) end
            end)
            row.remove:SetPoint("RIGHT", 0, 0)
            row:Hide()
            rows[i] = row
        end
        local empty = Label(panel, L["No spells yet."], 11, C.muted)
        empty:SetPoint("TOPLEFT", rows[1], "TOPLEFT", 4, -4)

        self.refreshers[#self.refreshers + 1] = function()
            local list = getList()
            local module = ns.modules.timeline
            for i, row in ipairs(rows) do
                local id = list[i]
                if id then
                    row.id = id
                    row.icon:SetTexture(module.EntryIcon(id) or "Interface/Icons/INV_Misc_QuestionMark")
                    local tag = id < 0 and (L["Item"] .. " " .. -id) or tostring(id)
                    row.name:SetText((module.EntryName(id) or L["Unknown spell"]) .. " |cffa0aa95(" .. tag .. ")|r")
                    row:Show()
                else
                    row.id = nil
                    row:Hide()
                end
            end
            empty:SetShown(#list == 0)
        end
    end

    -- Caja de texto para códigos largos (exportar / importar). Devuelve la caja.
    function b:Code(text)
        local x, y = self:Next()
        local label = Label(panel, text, 12, C.text)
        label:SetPoint("TOPLEFT", x, y - 4)
        local x2, y2 = self:Next()
        local eb = CreateFrame("EditBox", nil, panel)
        eb:SetPoint("TOPLEFT", x2, y2)
        eb:SetSize(262, 22)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(0)
        eb:SetFont(STANDARD_TEXT_FONT, 10, "")
        eb:SetTextColor(rgb(C.muted))
        eb:SetTextInsets(8, 8, 0, 0)
        Skin(eb, C.bgDarker, true)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        return eb
    end

    function b:Button(text, onClick)
        local x, y = self:Next()
        local btn = CreateButton(panel, text, 160, 22, onClick)
        -- el botón se ensancha para que el texto quepa (máximo: el ancho de la columna)
        btn:SetWidth(math.max(160, math.min(262, btn.label:GetStringWidth() + 28)))
        btn:SetPoint("TOPLEFT", x, y)
    end

    builders[#builders + 1] = b
    return b
end

---------------------------------------------------------------------------
-- Enlaces con la configuración
---------------------------------------------------------------------------

-- Devuelve getter y setter de db[key][field]; el setter reaplica la herramienta.
local function Bind(key, field)
    return function() return ns.db[key][field] end,
        function(v)
            ns.db[key][field] = v
            ns.modules[key].Apply()
        end
end

-- Bind para los campos de sonido (la prueba se hace con el botón dentro de la lista).
local function SoundBind(field)
    return function() return ns.db.focus[field] end,
        function(v)
            ns.db.focus[field] = v
            ns.modules.focus.Apply()
        end
end

-- Bloque común al inicio de cada página de herramienta.
local function GeneralSection(b, key)
    b:Header(L["General"])
    b:Check(L["Enable"], Bind(key, "enabled"))
    b:Check(L["Preview / unlock to move"], Bind(key, "unlocked"))
end

---------------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------------

ns.globalDefaults.window = { point = "CENTER", x = 0, y = 0 }

local win
local pages = {}      -- [key] = { frame, nav, module }
ns._pages = pages   -- solo para pruebas
local pageOrder = {}

local function AddonVersion()
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(fn, "ModiTools", "Version")
    return (ok and v) or "0.7"
end

local function RefreshNav()
    for _, key in ipairs(pageOrder) do
        local p = pages[key]
        if p.module and p.nav.dot then
            local on = ns.db[p.module] and ns.db[p.module].enabled
            p.nav.dot:SetColorTexture(rgb(on and C.accent or C.light, on and 1 or 0.4))
        end
    end
end

function ns.RefreshOptions()
    for _, b in ipairs(builders) do b:Refresh() end
    if win then RefreshNav() end
end

-- Barra lateral en árbol: una entrada puede tener subpáginas que se muestran con el cuadrito "+".

local function LayoutNav()
    local y = 4
    for _, key in ipairs(pageOrder) do
        local p = pages[key]
        local nav = p.nav
        local parent = p.parent and pages[p.parent]
        if parent and not parent.nav.expanded then
            nav:Hide()
        else
            nav:ClearAllPoints()
            nav:SetPoint("TOPLEFT", 4, -y)
            nav:SetPoint("TOPRIGHT", -4, -y)
            nav:Show()
            y = y + 34
        end
    end
end

local function PaintToggle(nav)
    if nav.toggle then nav.toggle.sign:SetText(nav.expanded and "-" or "+") end
end

local function SelectPage(key)
    local chosen = pages[key]
    -- elegir una subpágina despliega a su padre
    if chosen.parent then
        local parentNav = pages[chosen.parent].nav
        parentNav.expanded = true
        PaintToggle(parentNav)
    end
    for k, p in pairs(pages) do
        local selected = (k == key)
        p.frame:SetShown(selected)
        p.nav.selectedBG:SetShown(selected)
        p.nav.bar:SetShown(selected)
        p.nav.label:SetTextColor(rgb(selected and C.accent or C.text))
    end
    win.current = key
    LayoutNav()
    ns.RefreshOptions()
end

-- Cuadrito "+" / "-" de una entrada con subpáginas (se crea al agregar su primera subpágina).
local function EnsureToggle(nav, parentKey)
    if nav.toggle then return end
    local box = CreateFrame("Button", nil, nav)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 8, 0)
    Skin(box, C.bgDarker, true)
    box.sign = Label(box, "+", 12, C.accent)
    box.sign:SetPoint("CENTER", 0, 1)
    box:SetScript("OnEnter", function(self) self.fill:SetColorTexture(rgb(C.hover)) end)
    box:SetScript("OnLeave", function(self) self.fill:SetColorTexture(rgb(C.bgDarker)) end)
    box:SetScript("OnClick", function()
        nav.expanded = not nav.expanded
        PaintToggle(nav)
        -- al plegar con una subpágina abierta, se vuelve a la página principal
        if not nav.expanded and win.current and pages[win.current] and pages[win.current].parent == parentKey then
            SelectPage(parentKey)
        else
            LayoutNav()
        end
    end)
    nav.toggle = box
    nav.label:ClearAllPoints()
    nav.label:SetPoint("LEFT", 28, 0)
end

local function AddNav(key, text, moduleKey, parentKey)
    local nav = CreateFrame("Button", nil, win.sidebar)
    nav:SetHeight(32)
    nav.selectedBG = nav:CreateTexture(nil, "BACKGROUND")
    nav.selectedBG:SetAllPoints()
    nav.selectedBG:SetColorTexture(rgb(C.select))
    nav.selectedBG:Hide()
    nav.hl = nav:CreateTexture(nil, "HIGHLIGHT")
    nav.hl:SetAllPoints()
    nav.hl:SetColorTexture(rgb(C.hover, 0.6))
    nav.bar = nav:CreateTexture(nil, "ARTWORK")
    nav.bar:SetPoint("TOPLEFT")
    nav.bar:SetPoint("BOTTOMLEFT")
    nav.bar:SetWidth(3)
    nav.bar:SetColorTexture(rgb(C.accent))
    nav.bar:Hide()
    nav.label = Label(nav, text, parentKey and 12 or 13, C.text)
    nav.label:SetPoint("LEFT", parentKey and 32 or 14, 0)
    nav.expanded = false
    if moduleKey then
        nav.dot = nav:CreateTexture(nil, "ARTWORK")
        nav.dot:SetSize(8, 8)
        nav.dot:SetPoint("RIGHT", -10, 0)
    end
    if parentKey then EnsureToggle(pages[parentKey].nav, parentKey) end
    nav:SetScript("OnClick", function() SelectPage(key) end)
    return nav
end

local function PageHeader(panel, title, desc)
    local t = Label(panel, title, 18, C.accent)
    t:SetPoint("TOPLEFT", 16, -14)
    if desc then
        local d = Label(panel, desc, 11, C.muted)
        d:SetPoint("TOPLEFT", 16, -40)
        d:SetWidth(556)
    end
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 16, -58)
    line:SetPoint("TOPRIGHT", -16, -58)
    line:SetHeight(1)
    line:SetColorTexture(rgb(C.light, 0.5))
end

-- Crea una página de herramienta: marco + constructor + entrada en la barra lateral.
-- opts.parent: clave de la página padre (la entrada queda dentro de su "+"); opts.label: texto corto del menú.
local function MakePage(key, title, desc, moduleKey, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", nil, win.content)
    frame:SetAllPoints()
    frame:Hide()
    PageHeader(frame, title, desc)
    local b = NewBuilder(frame)
    frame:SetScript("OnShow", function() b:Refresh() end)
    pageOrder[#pageOrder + 1] = key
    pages[key] = {
        frame = frame, module = moduleKey, parent = opts.parent,
        nav = AddNav(key, opts.label or title, moduleKey, opts.parent),
    }
    return b
end

local function BuildHome()
    local frame = CreateFrame("Frame", nil, win.content)
    frame:SetAllPoints()
    pageOrder[#pageOrder + 1] = "home"
    pages.home = { frame = frame, nav = AddNav("home", L["Home"], nil, nil) }

    local title = Label(frame, "ModiTools", 40, C.accent)
    title:SetFont(STANDARD_TEXT_FONT, 40, "OUTLINE")
    title:SetPoint("TOPLEFT", 24, -22)

    local version = Label(frame, string.format(L["Version %s"], AddonVersion()), 14, C.text)
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -8)

    local art = frame:CreateTexture(nil, "ARTWORK")
    art:SetTexture("Interface\\AddOns\\ModiTools\\Media\\dwarf")
    art:SetSize(190, 190)
    art:SetPoint("TOPRIGHT", -24, -24)
    local artFrame = CreateFrame("Frame", nil, frame)
    artFrame:SetPoint("TOPLEFT", art, "TOPLEFT", -2, 2)
    artFrame:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 2, -2)
    Bevel(artFrame, true)

    local intro = Label(frame,
        L["Utilities for your interface, each with its own page in the sidebar:"] .. "\n\n"
        .. "- " .. L["Yards: distance to your target."] .. "\n"
        .. "- " .. L["Focus cast: your focus' cast bar."] .. "\n"
        .. "- " .. L["Marked casts: casts of marked mobs."] .. "\n"
        .. "- " .. L["Threat alert: warning when you lose aggro."] .. "\n"
        .. "- " .. L["Brez: combat res on a key."] .. "\n"
        .. "- " .. L["CD Timeline: upcoming cooldowns of your spells."] .. "\n"
        .. "- " .. L["Prepot: time left on the potion you used."] .. "\n\n"
        .. L["The dot next to each tool shows whether it is enabled."],
        12, C.text)
    intro:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -28)
    intro:SetWidth(330)
    intro:SetSpacing(2)

    -- ícono del minimapa e idioma
    local hb = NewBuilder(frame)
    hb.row = 11
    hb:Check(L["Show minimap icon"],
        function() return not ns.global.minimap.hide end,
        function(v)
            ns.global.minimap.hide = not v
            if ns.UpdateMinimap then ns.UpdateMinimap() end
        end)
    hb:Cycle("Language / Idioma", {
        { value = "en", label = "English" },
        { value = "es", label = "Español (MX)" },
    }, function() return ns.GetLanguage() end, function(v) ns.ChangeLanguage(v) end)
    frame:SetScript("OnShow", function() hb:Refresh() end)

    local cmds = Label(frame,
        L["Commands:"] .. "  /modi   ·   /modi yards|focus|marked|threat|brez|timeline|prepot   ·   "
        .. "/modi unlock|lock " .. L["<tool|all>"] .. "   ·   /modi reset   ·   /modi minimap   ·   /modi lang en|es",
        10, C.muted)
    cmds:SetWidth(538)
    cmds:SetSpacing(2)
    cmds:SetPoint("BOTTOMLEFT", 24, 16)
end

local function BuildWindow()
    win = CreateFrame("Frame", "ModiToolsWindow", UIParent)
    win:SetSize(780, 560)
    win:SetFrameStrata("HIGH")
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    Skin(win, C.bg, false)
    win:Hide()
    local pos = ns.global.window
    win:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    table.insert(UISpecialFrames, "ModiToolsWindow")

    -- barra de título (arrastrable)
    local bar = CreateFrame("Frame", nil, win)
    bar:SetHeight(36)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() win:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        local point, _, _, x, y = win:GetPoint()
        pos.point, pos.x, pos.y = point, x, y
    end)
    local name = Label(bar, "ModiTools", 16, C.accent)
    name:SetPoint("LEFT", 14, 0)
    local ver = Label(bar, "v" .. AddonVersion(), 11, C.muted)
    ver:SetPoint("LEFT", name, "RIGHT", 8, -2)
    local close = CreateButton(bar, "X", 24, 20, function() win:Hide() end)
    close:SetPoint("RIGHT", -8, 0)

    win.sidebar = CreateFrame("Frame", nil, win)
    win.sidebar:SetPoint("TOPLEFT", 8, -44)
    win.sidebar:SetPoint("BOTTOMLEFT", 8, 8)
    win.sidebar:SetWidth(170)
    Skin(win.sidebar, C.bgDark, true)

    win.content = CreateFrame("Frame", nil, win)
    win.content:SetPoint("TOPLEFT", win.sidebar, "TOPRIGHT", 8, 0)
    win.content:SetPoint("BOTTOMRIGHT", -8, 8)
    Skin(win.content, C.bgDark, true)
end

function ns.OpenWindow(page)
    if not win then return end
    win:Show()
    SelectPage(page or win.current or "home")
end

function ns.ToggleWindow()
    if not win then return end
    if win:IsShown() then win:Hide() else ns.OpenWindow() end
end

---------------------------------------------------------------------------
-- Selector de hechizos de la clase (para la línea de cooldowns)
---------------------------------------------------------------------------

local picker
local PICK_ROWS = 10
local PICK_ROW_H = 38

local function FormatCooldown(seconds)
    if not seconds then return "" end
    if seconds >= 60 then
        local m, s = math.floor(seconds / 60), math.floor(seconds % 60)
        return s > 0 and string.format("%d:%02d", m, s) or string.format("%d min", m)
    end
    return string.format("%d s", math.floor(seconds + 0.5))
end

local function RefreshPicker()
    local p = picker
    local total = #p.visible
    local maxOffset = math.max(0, total - PICK_ROWS)
    p.offset = math.max(0, math.min(p.offset, maxOffset))
    local module = ns.modules.timeline

    for i = 1, PICK_ROWS do
        local row = p.rows[i]
        local spell = p.visible[p.offset + i]
        if spell then
            row.spell = spell
            row.icon:SetTexture(spell.icon or "Interface/Icons/INV_Misc_QuestionMark")
            row.name:SetText(spell.name)
            local detail = "ID " .. math.abs(spell.id)
            if spell.cd then detail = string.format(L["Cooldown: %s"], FormatCooldown(spell.cd)) .. "  ·  " .. detail end
            if spell.kind == "trinket" then detail = L["Trinket"] .. "  ·  " .. detail
            elseif spell.kind == "potion" then detail = L["Potion"] .. "  ·  " .. detail end
            row.detail:SetText(detail)
            row.mark:SetShown(module.IsTracked(spell.id))
            row:Show()
        else
            row.spell = nil
            row:Hide()
        end
    end

    if maxOffset > 0 then
        p.scroll.loading = true
        p.scroll:SetMinMaxValues(0, maxOffset)
        p.scroll:SetValue(p.offset)
        p.scroll.loading = false
    end
    p.scroll:SetShown(maxOffset > 0)
    p.empty:SetShown(total == 0)
    p.status:SetText(string.format(L["%d of %d on the timeline"], #ns.db.timeline.spells, module.MaxSpells))
end

local function FilterPicker()
    local p = picker
    local query = (p.search:GetText() or ""):lower()
    p.visible = {}
    for _, spell in ipairs(p.spells) do
        if query == "" or spell.name:lower():find(query, 1, true) or tostring(spell.id):find(query, 1, true) then
            p.visible[#p.visible + 1] = spell
        end
    end
    p.offset = 0
    RefreshPicker()
end

local function BuildPicker()
    local p = CreateFrame("Frame", "ModiToolsSpellPicker", UIParent)
    p:SetSize(430, 560)
    p:SetPoint("CENTER", 60, 0)
    p:SetFrameStrata("DIALOG")
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:EnableMouseWheel(true)
    Skin(p, C.bg, false)
    p:Hide()
    table.insert(UISpecialFrames, "ModiToolsSpellPicker")
    p.spells, p.visible, p.rows, p.offset = {}, {}, {}, 0

    local bar = CreateFrame("Frame", nil, p)
    bar:SetHeight(32)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() p:StartMoving() end)
    bar:SetScript("OnDragStop", function() p:StopMovingOrSizing() end)
    local title = Label(bar, L["Pick from my spells and items"], 15, C.accent)
    title:SetPoint("LEFT", 14, 0)
    local close = CreateButton(bar, "X", 24, 20, function() p:Hide() end)
    close:SetPoint("RIGHT", -8, 0)

    local hint = Label(p, L["Click an entry to add or remove it."], 11, C.muted)
    hint:SetPoint("TOPLEFT", 14, -40)

    local search = CreateFrame("EditBox", nil, p)
    search:SetPoint("TOPLEFT", 14, -62)
    search:SetPoint("TOPRIGHT", -14, -62)
    search:SetHeight(24)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    search:SetFont(STANDARD_TEXT_FONT, 12, "")
    search:SetTextColor(rgb(C.text))
    search:SetTextInsets(8, 8, 0, 0)
    Skin(search, C.bgDarker, true)
    search:SetScript("OnTextChanged", function(_, userInput) if userInput then FilterPicker() end end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.search = search
    local placeholder = Label(search, L["Search..."], 11, C.muted)
    placeholder:SetPoint("LEFT", 8, 0)
    search:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) placeholder:SetShown((self:GetText() or "") == "") end)
    p.placeholder = placeholder

    local list = CreateFrame("Frame", nil, p)
    list:SetPoint("TOPLEFT", 14, -94)
    list:SetPoint("TOPRIGHT", -14, -94)
    list:SetHeight(PICK_ROWS * PICK_ROW_H + 4)
    Skin(list, C.bgDark, true)

    for i = 1, PICK_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(PICK_ROW_H)
        row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * PICK_ROW_H)
        row:SetPoint("TOPRIGHT", -18, -2 - (i - 1) * PICK_ROW_H)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(rgb(C.hover, 0.7))
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = Label(row, "", 12, C.text)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3)
        row.name:SetWidth(250)
        row.detail = Label(row, "", 10, C.muted)
        row.detail:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3)
        local check = CreateFrame("Frame", nil, row)
        check:SetSize(18, 18)
        check:SetPoint("RIGHT", -8, 0)
        Skin(check, C.bgDarker, true)
        row.mark = check:CreateTexture(nil, "ARTWORK")
        row.mark:SetPoint("TOPLEFT", 4, -4)
        row.mark:SetPoint("BOTTOMRIGHT", -4, 4)
        row.mark:SetColorTexture(rgb(C.accent))
        row:SetScript("OnClick", function(self)
            local spell = self.spell
            if not spell then return end
            local module = ns.modules.timeline
            local ok, msg
            if module.IsTracked(spell.id) then
                ok, msg = module.RemoveEntry(spell.id)
            else
                ok, msg = module.AddEntry(spell.id)
            end
            if msg then print(ns.PREFIX .. msg) end
            RefreshPicker()
        end)
        row:Hide()
        p.rows[i] = row
    end

    p.scroll = CreateFrame("Slider", nil, list)
    p.scroll:SetOrientation("VERTICAL")
    p.scroll:SetWidth(10)
    p.scroll:SetPoint("TOPRIGHT", -4, -4)
    p.scroll:SetPoint("BOTTOMRIGHT", -4, 4)
    p.scroll:SetValueStep(1)
    if p.scroll.SetObeyStepOnDrag then p.scroll:SetObeyStepOnDrag(true) end
    Skin(p.scroll, C.bgDarker, true)
    p.scroll:SetThumbTexture("Interface/Buttons/WHITE8x8")
    p.scroll:GetThumbTexture():SetSize(10, 30)
    p.scroll:GetThumbTexture():SetVertexColor(rgb(C.muted))
    p.scroll:SetScript("OnValueChanged", function(self, v)
        if self.loading then return end
        p.offset = math.floor(v + 0.5)
        RefreshPicker()
    end)

    p:SetScript("OnMouseWheel", function(_, delta)
        p.offset = p.offset - delta * 3
        RefreshPicker()
    end)

    p.empty = Label(list, L["No spells found."], 12, C.muted)
    p.empty:SetPoint("CENTER")

    p.status = Label(p, "", 11, C.accent)
    p.status:SetPoint("BOTTOMLEFT", 14, 14)
    local done = CreateButton(p, L["Done"], 90, 24, function() p:Hide() end)
    done:SetPoint("BOTTOMRIGHT", -14, 10)

    p:SetScript("OnShow", function()
        p.spells = ns.modules.timeline.ScanEntries()
        p.search:SetText("")
        p.placeholder:Show()
        FilterPicker()
    end)
    picker = p
    return p
end

function ns.OpenSpellPicker()
    local p = picker or BuildPicker()
    if p:IsShown() then p:Hide() else p:Show() end
end

function ns.CreateOptions()
    ns.LocalizeSounds()
    BuildWindow()
    BuildHome()

    -- Yardas
    local yb = MakePage("yards", L["Yards"], L["Shows the distance in yards to your target."], "yards")
    GeneralSection(yb, "yards")
    yb:Header(L["Appearance"])
    yb:Slider(L["Text size"], 10, 72, 1, Bind("yards", "fontSize"))
    yb:NewColumn()
    yb:Header(L["How to read it"])
    yb:Info(function()
        local g = "|cffc4b550"
        return L["WoW does not give the exact distance to an enemy: the addon estimates it."] .. "\n\n"
            .. g .. "15 - 20 yd|r  " .. L["more than 15 and up to 20."] .. "\n"
            .. g .. "< 5 yd|r  " .. L["less than 5."] .. "\n"
            .. g .. "> 80 yd|r  " .. L["more than 80."] .. "\n"
            .. g .. "12.4 yd|r  " .. L["exact (party members only)."]
    end, 8)

    -- Barra de casteo del focus
    local textureLabels = { Plano = L["Flat"], Habilidades = L["Skills"] }
    local textureOptions = {}
    for _, n in ipairs(ns.FocusTextures) do
        textureOptions[#textureOptions + 1] = { value = n, label = textureLabels[n] or n }
    end
    ns.FocusSounds.preview = ns.PlayFocusSound

    local fb = MakePage("focus", L["Focus cast"],
        L["Bar with your focus' cast, with customizable colors and sounds."], "focus")
    GeneralSection(fb, "focus")
    fb:Header(L["Appearance"])
    fb:Slider(L["Width"], 100, 600, 5, Bind("focus", "width"))
    fb:Slider(L["Height"], 10, 60, 1, Bind("focus", "height"))
    fb:Slider(L["Opacity"], 0.2, 1, 0.05, Bind("focus", "alpha"))
    fb:Slider(L["Font size"], 8, 24, 1, Bind("focus", "fontSize"))
    fb:Cycle(L["Texture"], textureOptions, Bind("focus", "texture"))
    fb:Header(L["Sounds"])
    fb:Check(L["Sound when a cast starts"], Bind("focus", "soundStart"))
    fb:Cycle(L["Start sound"], ns.FocusSounds, SoundBind("soundStartKey"))
    fb:Check(L["Only if it can be interrupted"], Bind("focus", "soundOnlyInterruptible"))
    fb:Check(L["Sound when interrupted"], Bind("focus", "soundInterrupt"))
    fb:Cycle(L["Interrupt sound"], ns.FocusSounds, SoundBind("soundInterruptKey"))
    fb:NewColumn()
    fb:Header(L["Elements"])
    fb:Check(L["Show icon"], Bind("focus", "showIcon"))
    fb:Check(L["Show spell name"], Bind("focus", "showName"))
    fb:Check(L["Show time"], Bind("focus", "showTime"))
    fb:Check(L["Show border"], Bind("focus", "showBorder"))
    fb:Check(L["Spark (glow on the progress edge)"], Bind("focus", "showSpark"))
    fb:Check(L["Glow around the bar"], Bind("focus", "showGlow"))
    fb:Header(L["Colors"])
    fb:Color(L["Normal cast"], "focus", "colorCast")
    fb:Color(L["Channel"], "focus", "colorChannel")
    fb:Color(L["Uninterruptible"], "focus", "colorLocked")
    fb:Color(L["Interrupted"], "focus", "colorFailed")
    fb:Color(L["Background"], "focus", "colorBG", true)
    fb:Color(L["Border"], "focus", "colorBorder", true)
    fb:Button(L["Restore defaults"], function() ns.ResetModule("focus") end)

    -- Casteos de mobs marcados
    local mb = MakePage("marked", L["Marked casts"],
        L["Bars with the casts of marked mobs, showing whether they were interrupted."], "marked")
    GeneralSection(mb, "marked")
    mb:Header(L["Appearance"])
    mb:Slider(L["Width"], 100, 500, 5, Bind("marked", "width"))
    mb:Slider(L["Height"], 10, 50, 1, Bind("marked", "height"))
    mb:Slider(L["Spacing"], 0, 20, 1, Bind("marked", "spacing"))
    mb:Slider(L["Max bars"], 1, 8, 1, Bind("marked", "maxBars"))
    mb:Slider(L["Opacity"], 0.2, 1, 0.05, Bind("marked", "alpha"))
    mb:Slider(L["Font size"], 8, 24, 1, Bind("marked", "fontSize"))
    mb:Cycle(L["Texture"], textureOptions, Bind("marked", "texture"))
    mb:Check(L["Grow upward"], Bind("marked", "growUp"))
    mb:Button(L["Restore defaults"], function() ns.ResetModule("marked") end)
    mb:NewColumn()
    mb:Header(L["Result"])
    mb:Check(L["Show the result on the bar"], Bind("marked", "showResult"))
    mb:Check(L["Announce in chat"], Bind("marked", "chatMessage"))
    mb:Slider(L["Result duration (s)"], 0.5, 5, 0.5, Bind("marked", "resultSeconds"))
    mb:Check(L["Show time"], Bind("marked", "showTime"))
    mb:Check(L["Show border"], Bind("marked", "showBorder"))
    mb:Header(L["Colors"])
    mb:Color(L["Normal cast"], "marked", "colorCast")
    mb:Color(L["Channel"], "marked", "colorChannel")
    mb:Color(L["Uninterruptible"], "marked", "colorLocked")
    mb:Color(L["Interrupted"], "marked", "colorInterrupted")
    mb:Color(L["Not interrupted"], "marked", "colorNotInterrupted")
    mb:Color(L["Background"], "marked", "colorBG", true)
    mb:Color(L["Border"], "marked", "colorBorder", true)

    -- Alerta de threat
    local threatSounds = {}
    for i, e in ipairs(ns.FocusSounds) do threatSounds[i] = e end
    threatSounds.preview = function(v) ns.PlaySoundKey(v, ns.db.threat.soundCustom) end
    local fontOptions = {
        { value = "default", label = L["Default"] },
        { value = "frizqt", label = "Friz Quadrata" },
        { value = "arialn", label = "Arial Narrow" },
        { value = "morpheus", label = "Morpheus" },
    }
    local outlineOptions = {
        { value = "NONE", label = L["No outline"] },
        { value = "OUTLINE", label = L["Outline"] },
        { value = "THICKOUTLINE", label = L["Thick outline"] },
    }

    local tb = MakePage("threat", L["Threat alert"],
        L["Shows text when you are losing aggro on a mob."], "threat")
    GeneralSection(tb, "threat")
    tb:Header(L["Text"])
    tb:Input(L["Alert text"],
        function() return ns.ThreatText() end,
        function(v)
            local c = ns.db.threat
            c.text = (v == L["LOSING AGGRO!"]) and "" or v
            ns.modules.threat.Apply()
        end)
    tb:Header(L["Appearance"])
    tb:Slider(L["Size"], 12, 96, 1, Bind("threat", "fontSize"))
    tb:Slider(L["Opacity"], 0.2, 1, 0.05, Bind("threat", "alpha"))
    tb:Cycle(L["Font"], fontOptions, Bind("threat", "font"))
    tb:Cycle(L["Outline"], outlineOptions, Bind("threat", "outline"))
    tb:Button(L["Restore defaults"], function() ns.ResetModule("threat") end)
    tb:NewColumn()
    tb:Header(L["Behavior"])
    tb:Check(L["Only if I am the tank"], Bind("threat", "onlyTank"))
    tb:Check(L["Flash"], Bind("threat", "flash"))
    tb:Check(L["Show mob name"], Bind("threat", "showMob"))
    tb:Slider(L["Duration (s)"], 1, 10, 0.5, Bind("threat", "holdSeconds"))
    tb:Header(L["Sound"])
    tb:Check(L["Sound when losing aggro"], Bind("threat", "sound"))
    tb:Cycle(L["Sound"], threatSounds, Bind("threat", "soundKey"))
    tb:Header(L["Colors"])
    tb:Color(L["Text"], "threat", "colorText")
    tb:Check(L["Show background"], Bind("threat", "showBG"))
    tb:Color(L["Background"], "threat", "colorBG", true)
    tb:Button(L["Test alert"], function() ns.modules.threat.Slash("test") end)

    -- Brez en una tecla
    local bb = MakePage("brez", L["Brez on a key"],
        L["Your key casts your class's combat res when you hover over a dead ally."], "brez")
    bb:Header(L["General"])
    bb:Check(L["Enable"], Bind("brez", "enabled"))
    bb:Check(L["Combat only"], Bind("brez", "onlyCombat"))
    bb:Header(L["Key"])
    bb:KeyBind(L["Key"], Bind("brez", "key"))
    bb:Info(function()
        return L["It can be a key you already use: it only becomes brez while your mouse is over a dead ally. The rest of the time it does what it always does."]
    end, 5)
    bb:NewColumn()
    bb:Header(L["Status"])
    bb:IconInfo(function() return ns.modules.brez.StatusText() end,
        function() return ns.modules.brez.SpellIcon() end, 5)
    bb:Header(L["Advanced"])
    bb:Input(L["Spell ID (optional)"], Bind("brez", "customSpell"), true)
    bb:Info(function()
        return L["Only if your brez is not detected: enter the numeric spell ID (the number in its wowhead.com page, e.g. /spell=20484)."]
            .. "\n\n" .. L["Changes apply after combat."]
    end, 5)
    bb:Button(L["Restore defaults"], function() ns.ResetModule("brez") end)

    -- Prepot
    local posOptions = {
        { value = "CENTER", label = L["Center"] },
        { value = "BOTTOM", label = L["Below"] },
        { value = "TOP", label = L["Above"] },
    }
    local prepotSounds = {}
    for i, e in ipairs(ns.FocusSounds) do prepotSounds[i] = e end
    prepotSounds.preview = function(v) ns.PlaySoundKey(v, ns.db.prepot.soundCustom) end
    local pb = MakePage("prepot", L["Prepot"], L["Icon with the time left on the potion you used."], "prepot")
    GeneralSection(pb, "prepot")
    pb:Header(L["Appearance"])
    pb:Slider(L["Icon size"], 24, 128, 2, Bind("prepot", "iconSize"))
    pb:Slider(L["Opacity"], 0.2, 1, 0.05, Bind("prepot", "alpha"))
    pb:Slider(L["Font size"], 8, 40, 1, Bind("prepot", "fontSize"))
    pb:Slider(L["Warn at (s)"], 0, 30, 1, Bind("prepot", "warnAt"))
    pb:Cycle(L["Time position"], posOptions, Bind("prepot", "textPos"))
    pb:Header(L["Sound"])
    pb:Check(L["Sound when the potion is ready"], Bind("prepot", "soundReady"))
    pb:Cycle(L["Ready sound"], prepotSounds, Bind("prepot", "soundReadyKey"))
    pb:Button(L["Test (30 s)"], function() ns.modules.prepot.Slash("test") end)
    pb:Button(L["Restore defaults"], function() ns.ResetModule("prepot") end)
    pb:NewColumn()
    pb:Header(L["Elements"])
    pb:Check(L["Show time"], Bind("prepot", "showText"))
    pb:Check(L["Cooldown swirl"], Bind("prepot", "showSwirl"))
    pb:Check(L["Show border"], Bind("prepot", "showBorder"))
    pb:Header(L["Colors"])
    pb:Color(L["Text"], "prepot", "colorText")
    pb:Color(L["Warning text"], "prepot", "colorWarn")
    pb:Color(L["Border"], "prepot", "colorBorder", true)

    -- Línea de tiempo de cooldowns
    local tlStatus, tlSpellField, tlKind = "", "", "spell"
    local kindOptions = {
        { value = "spell", label = L["Spell"] },
        { value = "item", label = L["Item"] },
    }
    local tl = MakePage("timeline", "CD Timeline",
        L["A timeline of the cooldowns you choose, showing when they come back."], "timeline")
    GeneralSection(tl, "timeline")
    local orientationOptions = {
        { value = "H", label = L["Horizontal"] },
        { value = "V", label = L["Vertical"] },
    }
    tl:Header(L["Add to the timeline"])
    tl:Button(L["Pick from my spells and items"], function() ns.OpenSpellPicker() end)
    tl:Cycle(L["Type"], kindOptions, function() return tlKind end, function(v) tlKind = v end)
    tl:Input(L["ID"], function() return tlSpellField end, function(v) tlSpellField = v end, true)
    tl:Button(L["Add"], function()
        local add = tlKind == "item" and ns.modules.timeline.AddItem or ns.modules.timeline.AddSpell
        local ok, msg = add(tlSpellField)
        if ok then tlSpellField = "" end
        tlStatus = msg
        print(ns.PREFIX .. msg)
        ns.RefreshOptions()
    end)
    tl:Info(function()
        if tlStatus ~= "" then return tlStatus end
        return L["Pick from the list, or type a spell or item ID (the number in its wowhead.com page) and press Add."]
    end, 2)
    tl:Header(L["Timing"])
    tl:Slider(L["Appear within (s)"], 5, 120, 1, Bind("timeline", "window"))
    tl:Slider(L["Ignore cooldowns under (s)"], 1, 10, 0.5, Bind("timeline", "minCooldown"))
    local combatGet, combatSet = Bind("timeline", "combatOnly")
    tl:Check(L["Only in combat"], combatGet, combatSet,
        L["The timeline is only shown while you are in combat, and its sounds (warning and ready) are muted outside of combat. Cooldowns keep being tracked, so everything works as soon as you enter combat. The preview (unlocked) is always visible so you can move it."])
    tl:NewColumn()
    tl:Header(L["On the timeline"])
    tl:SpellList(function() return ns.db.timeline.spells end, function(id)
        -- RemoveEntry respeta el signo del ID (negativo = objeto); RemoveSpell lo volvería positivo
        local _, msg = ns.modules.timeline.RemoveEntry(id)
        tlStatus = msg
        ns.RefreshOptions()
    end, 12)
    tl:Cycle(L["Orientation"], orientationOptions, Bind("timeline", "orientation"))
    tl:Button(L["Restore defaults"], function() ns.ResetModule("timeline") end)

    local ts = MakePage("timeline_style", L["Timeline style"],
        L["Orientation, size and colors of the timeline."], nil, { parent = "timeline", label = L["Style"] })
    ts:Header(L["Layout"])
    ts:Cycle(L["Orientation"], orientationOptions, Bind("timeline", "orientation"))
    ts:Cycle(L["Font"], fontOptions, Bind("timeline", "font"))
    ts:Check(L["Reverse direction"], Bind("timeline", "reverse"))
    ts:Slider(L["Length"], 100, 900, 5, Bind("timeline", "length"))
    ts:Slider(L["Thickness"], 2, 40, 1, Bind("timeline", "thickness"))
    ts:Slider(L["Icon size"], 16, 64, 1, Bind("timeline", "iconSize"))
    ts:Slider(L["Opacity"], 0.2, 1, 0.05, Bind("timeline", "alpha"))
    ts:Slider(L["Font size"], 8, 20, 1, Bind("timeline", "fontSize"))
    ts:Header(L["Elements"])
    ts:Check(L["Show time"], Bind("timeline", "showTime"))
    ts:Check(L["Show ticks"], Bind("timeline", "showTicks"))
    ts:Check(L["Show now marker"], Bind("timeline", "showNow"))
    ts:Check(L["Flash when ready"], Bind("timeline", "flashReady"))
    ts:Check(L["Icon border"], Bind("timeline", "iconBorder"))
    ts:NewColumn()
    ts:Header(L["Colors"])
    ts:Color(L["Line"], "timeline", "colorLine", true)
    ts:Color(L["Ticks"], "timeline", "colorTick", true)
    ts:Color(L["Now marker"], "timeline", "colorNow")
    ts:Color(L["Border"], "timeline", "colorBorder", true)
    ts:Header(L["Visibility"])
    ts:Check(L["Always show the line"], Bind("timeline", "alwaysShow"))

    -- Sonidos de la línea de cooldowns
    local tsSelected
    local globalSounds = {}
    for i, e in ipairs(ns.FocusSounds) do globalSounds[i] = e end
    globalSounds.preview = function(v) ns.PlaySoundKey(v, ns.db.timeline.soundCustom) end

    -- por hechizo: opciones especiales primero, luego la lista completa de sonidos
    local perSpellSounds = {
        { header = true, label = L["Options"] },
        { value = "global", label = L["Use the global sound"] },
        { value = "none", label = L["No sound"] },
    }
    for _, e in ipairs(ns.FocusSounds) do perSpellSounds[#perSpellSounds + 1] = e end
    perSpellSounds.preview = globalSounds.preview

    local spellChoices = {}
    local function RefreshSpellChoices()
        for i = #spellChoices, 1, -1 do spellChoices[i] = nil end
        local found = false
        for _, id in ipairs(ns.db.timeline.spells) do
            spellChoices[#spellChoices + 1] = {
                value = id,
                label = (ns.modules.timeline.EntryName(id) or L["Unknown spell"]) .. " (" .. math.abs(id) .. ")",
            }
            if id == tsSelected then found = true end
        end
        if not found then tsSelected = spellChoices[1] and spellChoices[1].value or nil end
    end

    local function SpellSound(field, default)
        return function()
            local s = tsSelected and ns.db.timeline.spellSounds[tsSelected]
            return (s and s[field]) or default
        end,
        function(v)
            if not tsSelected then return end
            local all = ns.db.timeline.spellSounds
            all[tsSelected] = all[tsSelected] or {}
            if field == "warnAt" and v == 0 then v = nil end
            all[tsSelected][field] = v
        end
    end

    local tsd = MakePage("timeline_sound", L["Timeline sounds"],
        L["Sounds for when your cooldowns are about to end or are ready."], nil, { parent = "timeline", label = L["Sounds"] })
    tsd.refreshers[#tsd.refreshers + 1] = RefreshSpellChoices
    tsd:Header(L["All spells"])
    tsd:Check(L["Sound when a cooldown is about to end"], Bind("timeline", "soundWarn"))
    tsd:Cycle(L["Warning sound"], globalSounds, Bind("timeline", "soundWarnKey"))
    tsd:Slider(L["Warn at (s)"], 1, 60, 1, Bind("timeline", "warnAt"))
    tsd:Check(L["Sound when ready"], Bind("timeline", "soundReady"))
    tsd:Cycle(L["Ready sound"], globalSounds, Bind("timeline", "soundReadyKey"))
    tsd:Info(function()
        return L["Choose \"Custom\" in a sound list and set it with /modi timeline sound <soundkitID or file path>."]
    end, 3)
    tsd:NewColumn()
    tsd:Header(L["Per spell or item"])
    tsd:Cycle(L["Spell or item"], spellChoices,
        function() return tsSelected end,
        function(v) tsSelected = v; ns.RefreshOptions() end)
    tsd:Info(function()
        if #ns.db.timeline.spells == 0 then return L["Add something to the timeline first."] end
        return L["Choose a spell or item to give it its own sounds. \"Use the global sound\" keeps the shared one."]
    end, 3)
    tsd:Cycle(L["Warning sound"], perSpellSounds, SpellSound("warn", "global"))
    tsd:Slider(L["Warn at (s), 0 = global"], 0, 60, 1, SpellSound("warnAt", 0))
    tsd:Cycle(L["Ready sound"], perSpellSounds, SpellSound("ready", "global"))

    -- Perfiles
    local profileOptions = {}
    local function RefreshProfileOptions()
        for i = #profileOptions, 1, -1 do profileOptions[i] = nil end
        for _, profile in ipairs(ns.ListProfiles()) do
            profileOptions[#profileOptions + 1] = { value = profile, label = profile }
        end
    end

    local status, nameField, importName = "", "", ""
    local exportBox, importBox

    local function Report(message)
        status = message or ""
        if status ~= "" then print(ns.PREFIX .. status) end
        ns.RefreshOptions()
    end

    StaticPopupDialogs["MODITOOLS_CONFIRM"] = {
        text = "%s",
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, onAccept) if onAccept then onAccept() end end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local pfb = MakePage("profiles", L["Profiles"], L["Save, switch and share your configuration."], nil)
    pfb.refreshers[#pfb.refreshers + 1] = RefreshProfileOptions
    pfb:Header(L["Profile"])
    pfb:Cycle(L["Active profile"], profileOptions,
        function() return ns.profileName end,
        function(v)
            local ok, err = ns.SetProfile(v)
            Report(ok and string.format(L["Profile '%s' is now active."], v) or err)
        end)
    pfb:Header(L["Manage"])
    pfb:Input(L["Profile name"], function() return nameField end, function(v) nameField = v end)
    pfb:Button(L["Create profile"], function()
        local ok, res = ns.CreateProfile(nameField)
        if ok then nameField = "" end
        Report(ok and string.format(L["Profile '%s' created."], res) or res)
    end)
    pfb:Button(L["Rename profile"], function()
        local ok, res = ns.RenameProfile(nameField)
        if ok then nameField = "" end
        Report(ok and string.format(L["Profile renamed to '%s'."], res) or res)
    end)
    pfb:Button(L["Delete profile"], function()
        local target = ns.profileName
        StaticPopup_Show("MODITOOLS_CONFIRM", string.format(L["Delete profile '%s'?"], target), nil, function()
            local ok, err = ns.DeleteProfile(target)
            Report(ok and string.format(L["Profile '%s' deleted."], target) or err)
        end)
    end)
    pfb:Button(L["Reset profile"], function()
        local target = ns.profileName
        StaticPopup_Show("MODITOOLS_CONFIRM", string.format(L["Reset profile '%s' to defaults?"], target), nil, function()
            ns.ResetProfile()
            Report(string.format(L["Profile '%s' reset."], target))
        end)
    end)
    pfb:NewColumn()
    pfb:Header(L["Share"])
    pfb:Info(function() return status end, 2)
    pfb:Button(L["Export current profile"], function()
        local code = ns.ExportProfile()
        if not code then return end
        exportBox:SetText(code)
        exportBox:SetFocus()
        exportBox:HighlightText()
        Report(string.format(L["Exported '%s'. Copy the code with Ctrl+C."], ns.profileName))
    end)
    exportBox = pfb:Code(L["Export code"])
    pfb:Header(L["Import"])
    importBox = pfb:Code(L["Import code"])
    pfb:Input(L["Name for the imported profile (optional)"], function() return importName end, function(v) importName = v end)
    pfb:Button(L["Import profile"], function()
        local name, err = ns.ImportProfile(importBox:GetText(), importName)
        if name then
            importBox:SetText("")
            importName = ""
            ns.SetProfile(name)
            Report(string.format(L["Imported as '%s'."], name))
        else
            Report(err)
        end
    end)

    -- Entrada en el menú de AddOns de Blizzard: solo abre la ventana propia.
    local stub = CreateFrame("Frame")
    stub.name = "ModiTools"
    local stubTitle = Label(stub, "ModiTools", 24, C.accent)
    stubTitle:SetPoint("TOPLEFT", 16, -16)
    local stubText = Label(stub, L["Settings live in ModiTools' own window."], 12, C.text)
    stubText:SetPoint("TOPLEFT", stubTitle, "BOTTOMLEFT", 0, -12)
    local open = CreateButton(stub, L["Open ModiTools"], 180, 28, function()
        pcall(function() if SettingsPanel then SettingsPanel:Hide() end end)
        ns.OpenWindow()
    end)
    open:SetPoint("TOPLEFT", stubText, "BOTTOMLEFT", 0, -16)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(stub, stub.name)
        Settings.RegisterAddOnCategory(category)
        ns.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(stub)
    end

    SelectPage("home")
end
