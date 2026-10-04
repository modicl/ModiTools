-- Panel de opciones: panel principal + subpáneles de personalización.

local _, ns = ...

local ROW = 26
local COLX = { 16, 330 }
local MAXROWS = 15
local builders = {}

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

local ITEM_H = 20
local TITLE_H = 22
local MAX_ROWS = 9
local MENU_W = 210
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
            if entry.hasCurrent then item.text:SetTextColor(0.3, 1, 0.4) else item.text:SetTextColor(1, 0.82, 0) end
        else
            item.arrow:Hide()
            item.play:SetShown(m.preview ~= nil)
            if entry.value == m.current then item.text:SetTextColor(0.3, 1, 0.4) else item.text:SetTextColor(1, 1, 1) end
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

    local rightInset = 1 + (scrollable and SCROLL_W or 0)
    for i = 1, MAX_ROWS do
        local item = m.items[i]
        item:SetPoint("TOPLEFT", 1, -1 - top - (i - 1) * ITEM_H)
        item:SetPoint("TOPRIGHT", -rightInset, -1 - top - (i - 1) * ITEM_H)
    end
    m.scroll:ClearAllPoints()
    m.scroll:SetPoint("TOPRIGHT", -2, -2 - top)
    m.scroll:SetPoint("BOTTOMRIGHT", -2, 2)
    m.scroll:SetShown(scrollable)

    m.offset = 0
    if focusValue ~= nil then
        for i, e in ipairs(entries) do
            if e.value == focusValue then m.offset = i - math.floor(rows / 2) end
        end
    end

    m:SetSize(MENU_W, top + rows * ITEM_H + 2)
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
    menu = CreateFrame("Frame", "ModiToolsDropdownMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    menu:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.08, 0.08, 0.1, 0.97)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    menu.items = {}
    menu.entries = {}
    menu.offset = 0

    -- barra superior para volver a las categorías
    local bar = CreateFrame("Button", nil, menu)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    local barBG = bar:CreateTexture(nil, "BACKGROUND")
    barBG:SetAllPoints()
    barBG:SetColorTexture(1, 1, 1, 0.08)
    local barHL = bar:CreateTexture(nil, "HIGHLIGHT")
    barHL:SetAllPoints()
    barHL:SetColorTexture(1, 1, 1, 0.15)
    bar.text = bar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bar.text:SetPoint("LEFT", 8, 0)
    bar:SetScript("OnClick", function() ShowCategories(menu) end)
    bar:Hide()
    menu.titleBar = bar

    for i = 1, MAX_ROWS do
        local item = CreateFrame("Button", nil, menu)
        item:SetHeight(ITEM_H)
        item.hl = item:CreateTexture(nil, "HIGHLIGHT")
        item.hl:SetAllPoints()
        item.hl:SetColorTexture(1, 1, 1, 0.15)
        item.text = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        item.text:SetPoint("LEFT", 10, 0)
        item.arrow = item:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        item.arrow:SetPoint("RIGHT", -8, 0)
        item.arrow:SetText(">")

        -- botón de prueba dentro de la fila: no selecciona el elemento
        local play = CreateFrame("Button", nil, item)
        play:SetSize(PLAY_W, ITEM_H - 4)
        play:SetPoint("RIGHT", -2, 0)
        local pbg = play:CreateTexture(nil, "BACKGROUND")
        pbg:SetAllPoints()
        pbg:SetColorTexture(0.2, 0.5, 0.9, 0.55)
        local phl = play:CreateTexture(nil, "HIGHLIGHT")
        phl:SetAllPoints()
        phl:SetColorTexture(1, 1, 1, 0.25)
        local ptxt = play:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ptxt:SetPoint("CENTER")
        ptxt:SetText("Probar")
        play:SetScript("OnClick", function()
            if item.entry and menu.preview then menu.preview(item.entry.value) end
        end)
        item.play = play
        item.text:SetPoint("RIGHT", play, "LEFT", -4, 0)
        item.text:SetJustifyH("LEFT")

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
    local track = menu.scroll:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.08)
    menu.scroll:SetThumbTexture("Interface/Buttons/WHITE8x8")
    menu.scroll:GetThumbTexture():SetSize(10, 28)
    menu.scroll:GetThumbTexture():SetVertexColor(0.6, 0.6, 0.65, 1)
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
-- Constructor de controles
---------------------------------------------------------------------------

local function NewBuilder(panel)
    local b = { panel = panel, col = 1, row = 0, refreshers = {} }

    -- Siguiente posición libre; pasa a la segunda columna al llenar la primera.
    function b:Next()
        if self.row >= MAXROWS then
            self.col = self.col + 1
            self.row = 0
        end
        local x = COLX[self.col] or COLX[#COLX]
        local y = -56 - self.row * ROW
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
        local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", x, y - 6)
        h:SetText(text)
    end

    function b:Check(text, get, set)
        local x, y = self:Next()
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y + 4)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetText(text)
        cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
        self.refreshers[#self.refreshers + 1] = function() cb:SetChecked(get()) end
    end

    function b:Slider(text, min, max, step, get, set)
        local x, y = self:Next()
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y - 4)
        label:SetWidth(130)
        label:SetJustifyH("LEFT")
        label:SetText(text)

        local s = CreateFrame("Slider", nil, panel)
        s:SetPoint("TOPLEFT", x + 135, y - 6)
        s:SetSize(120, 16)
        s:SetOrientation("HORIZONTAL")
        s:EnableMouse(true)
        local track = s:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        track:SetHeight(4)
        track:SetColorTexture(0.35, 0.35, 0.35, 1)
        s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        s:GetThumbTexture():SetSize(14, 22)
        s:SetMinMaxValues(min, max)
        s:SetValueStep(step)
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

        local value = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        value:SetPoint("LEFT", s, "RIGHT", 8, 0)

        local fmt = step < 1 and "%.2f" or "%d"
        local loading = false
        s:SetScript("OnValueChanged", function(_, v)
            v = math.floor(v / step + 0.5) * step
            value:SetText(string.format(fmt, v))
            if loading then return end
            set(v)
        end)
        self.refreshers[#self.refreshers + 1] = function()
            loading = true
            s:SetValue(get())
            loading = false
        end
    end

    function b:Cycle(text, options, get, set)
        local x, y = self:Next()
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y - 4)
        label:SetWidth(130)
        label:SetJustifyH("LEFT")
        label:SetText(text)

        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", x + 135, y)
        btn:SetSize(140, 22)
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface/Buttons/Arrow-Down-Up")
        arrow:SetSize(16, 16)
        arrow:SetPoint("RIGHT", -4, -2)

        local function labelOf(value)
            for _, o in ipairs(options) do
                if o.value == value then return o.label end
            end
            return tostring(value)
        end
        btn:SetScript("OnClick", function(self)
            OpenMenu(self, options, get(), function(value)
                set(value)
                btn:SetText(labelOf(value))
            end)
        end)
        self.refreshers[#self.refreshers + 1] = function() btn:SetText(labelOf(get())) end
    end

    -- Muestra de color. withAlpha agrega el control de transparencia.
    function b:Color(text, key, field, withAlpha)
        local x, y = self:Next()
        local btn = CreateFrame("Button", nil, panel)
        btn:SetPoint("TOPLEFT", x + 4, y)
        btn:SetSize(22, 22)
        local edge = btn:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints()
        edge:SetColorTexture(1, 1, 1, 1)
        local swatch = btn:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("TOPLEFT", 2, -2)
        swatch:SetPoint("BOTTOMRIGHT", -2, 2)

        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", btn, "RIGHT", 8, 0)
        label:SetText(text)

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

    function b:Button(text, onClick)
        local x, y = self:Next()
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", x + 4, y)
        btn:SetSize(160, 22)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
    end

    builders[#builders + 1] = b
    return b
end

function ns.RefreshOptions()
    for _, b in ipairs(builders) do b:Refresh() end
end

---------------------------------------------------------------------------
-- Paneles
---------------------------------------------------------------------------

local function MakePanel(name, parentName, description)
    local panel = CreateFrame("Frame")
    panel.name = name
    panel.parent = parentName
    if parentName then
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("ModiTools - " .. name)
        if description then
            local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
            desc:SetTextColor(0.7, 0.7, 0.7)
            desc:SetText(description)
        end
    end
    local b = NewBuilder(panel)
    panel:SetScript("OnShow", function() b:Refresh() end)
    panel:SetScript("OnHide", function() if menu then menu:Hide() end end)
    return panel, b
end

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

-- Bloque común al inicio de cada subpanel: activar y vista previa.
local function GeneralSection(b, key)
    b:Header("General")
    b:Check("Activar", Bind(key, "enabled"))
    b:Check("Vista previa / desbloquear para mover", Bind(key, "unlocked"))
end

function ns.CreateOptions()
    -- Portada
    local main = MakePanel("ModiTools")
    local bigTitle = main:CreateFontString(nil, "ARTWORK")
    bigTitle:SetFont(STANDARD_TEXT_FONT, 40, "OUTLINE")
    bigTitle:SetPoint("TOPLEFT", 16, -16)
    bigTitle:SetTextColor(1, 0.82, 0)
    bigTitle:SetText("ModiTools")

    local version = main:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    version:SetPoint("TOPLEFT", bigTitle, "BOTTOMLEFT", 2, -6)
    version:SetText("Versión 0.5")

    local art = main:CreateTexture(nil, "ARTWORK")
    art:SetTexture("Interface\\AddOns\\ModiTools\\Media\\dwarf")
    art:SetSize(200, 200)
    art:SetPoint("TOPRIGHT", -16, -16)

    local intro = main:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -24)
    intro:SetWidth(380)
    intro:SetJustifyH("LEFT")
    intro:SetText("Cada herramienta se configura en su propia subcategoría, a la izquierda:\n\n"
        .. "- Yardas: distancia al target.\n"
        .. "- Cast del focus: barra de casteo del focus.\n"
        .. "- Casteos marcados: casteos de los mobs con marca (calavera, estrella...).\n"
        .. "- Prepot: duración de la poción usada.\n\n"
        .. "En cada una puedes activarla, ver la vista previa para moverla y personalizarla.")
    local help = main:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", 16, 16)
    help:SetText("Comandos: /modi yards|focus|marked|prepot, /modi unlock|lock <...|all>, /modi reset, /modi prepot test|add <id>")

    -- Yardas
    local yards, yb = MakePanel("Yardas", "ModiTools", "Muestra la distancia en yardas hasta tu target.")
    GeneralSection(yb, "yards")
    yb:Header("Apariencia")
    yb:Slider("Tamaño del texto", 10, 72, 1, Bind("yards", "fontSize"))

    -- Barra de casteo del focus
    local focus, fb = MakePanel("Cast del focus", "ModiTools", "Barra con el casteo de tu focus, con colores y sonidos personalizables.")
    local textureOptions = {}
    for _, n in ipairs(ns.FocusTextures) do
        textureOptions[#textureOptions + 1] = { value = n, label = n }
    end
    ns.FocusSounds.preview = ns.PlayFocusSound
    GeneralSection(fb, "focus")
    fb:Header("Apariencia")
    fb:Slider("Ancho", 100, 600, 5, Bind("focus", "width"))
    fb:Slider("Alto", 10, 60, 1, Bind("focus", "height"))
    fb:Slider("Opacidad", 0.2, 1, 0.05, Bind("focus", "alpha"))
    fb:Slider("Tamaño de fuente", 8, 24, 1, Bind("focus", "fontSize"))
    fb:Cycle("Textura", textureOptions, Bind("focus", "texture"))
    fb:Header("Sonidos")
    fb:Check("Sonido al iniciar casteo", Bind("focus", "soundStart"))
    fb:Cycle("Sonido de inicio", ns.FocusSounds, SoundBind("soundStartKey"))
    fb:Check("Solo si es interrumpible", Bind("focus", "soundOnlyInterruptible"))
    fb:Check("Sonido al ser interrumpido", Bind("focus", "soundInterrupt"))
    fb:Cycle("Sonido de interrupción", ns.FocusSounds, SoundBind("soundInterruptKey"))
    fb:NewColumn()
    fb:Header("Elementos")
    fb:Check("Mostrar ícono", Bind("focus", "showIcon"))
    fb:Check("Mostrar nombre del hechizo", Bind("focus", "showName"))
    fb:Check("Mostrar tiempo", Bind("focus", "showTime"))
    fb:Check("Mostrar borde", Bind("focus", "showBorder"))
    fb:Check("Chispa (brillo en el avance)", Bind("focus", "showSpark"))
    fb:Check("Resplandor alrededor", Bind("focus", "showGlow"))
    fb:Header("Colores")
    fb:Color("Casteo normal", "focus", "colorCast")
    fb:Color("Canalizado (channel)", "focus", "colorChannel")
    fb:Color("No interrumpible", "focus", "colorLocked")
    fb:Color("Interrumpido", "focus", "colorFailed")
    fb:Color("Fondo", "focus", "colorBG", true)
    fb:Color("Borde", "focus", "colorBorder", true)
    fb:Button("Restaurar valores", function() ns.ResetModule("focus") end)

    -- Casteos de mobs marcados
    local marked, mb = MakePanel("Casteos marcados", "ModiTools", "Barras con el casteo de los mobs marcados e indicación de si fueron interrumpidos.")
    GeneralSection(mb, "marked")
    mb:Header("Apariencia")
    mb:Slider("Ancho", 100, 500, 5, Bind("marked", "width"))
    mb:Slider("Alto", 10, 50, 1, Bind("marked", "height"))
    mb:Slider("Separación", 0, 20, 1, Bind("marked", "spacing"))
    mb:Slider("Máx. de barras", 1, 8, 1, Bind("marked", "maxBars"))
    mb:Slider("Opacidad", 0.2, 1, 0.05, Bind("marked", "alpha"))
    mb:Slider("Tamaño de fuente", 8, 24, 1, Bind("marked", "fontSize"))
    mb:Cycle("Textura", textureOptions, Bind("marked", "texture"))
    mb:Check("Crecer hacia arriba", Bind("marked", "growUp"))
    mb:Button("Restaurar valores", function() ns.ResetModule("marked") end)
    mb:NewColumn()
    mb:Header("Resultado")
    mb:Check("Mostrar resultado en la barra", Bind("marked", "showResult"))
    mb:Check("Avisar en el chat", Bind("marked", "chatMessage"))
    mb:Slider("Duración resultado (s)", 0.5, 5, 0.5, Bind("marked", "resultSeconds"))
    mb:Check("Mostrar tiempo", Bind("marked", "showTime"))
    mb:Check("Mostrar borde", Bind("marked", "showBorder"))
    mb:Header("Colores")
    mb:Color("Casteo normal", "marked", "colorCast")
    mb:Color("Canalizado (channel)", "marked", "colorChannel")
    mb:Color("No interrumpible", "marked", "colorLocked")
    mb:Color("Interrumpido", "marked", "colorInterrupted")
    mb:Color("No interrumpido", "marked", "colorNotInterrupted")
    mb:Color("Fondo", "marked", "colorBG", true)
    mb:Color("Borde", "marked", "colorBorder", true)

    -- Prepot
    local prepot, pb = MakePanel("Prepot", "ModiTools", "Ícono con el tiempo restante de la poción que usaste.")
    local posOptions = {
        { value = "CENTER", label = "Centro" },
        { value = "BOTTOM", label = "Abajo" },
        { value = "TOP", label = "Arriba" },
    }
    GeneralSection(pb, "prepot")
    pb:Header("Apariencia")
    pb:Slider("Tamaño del ícono", 24, 128, 2, Bind("prepot", "iconSize"))
    pb:Slider("Opacidad", 0.2, 1, 0.05, Bind("prepot", "alpha"))
    pb:Slider("Tamaño de fuente", 8, 40, 1, Bind("prepot", "fontSize"))
    pb:Slider("Avisar al quedar (s)", 0, 30, 1, Bind("prepot", "warnAt"))
    pb:Cycle("Posición del tiempo", posOptions, Bind("prepot", "textPos"))
    pb:Button("Probar (30 s)", function() ns.modules.prepot.Slash("test") end)
    pb:Button("Restaurar valores", function() ns.ResetModule("prepot") end)
    pb:NewColumn()
    pb:Header("Elementos")
    pb:Check("Mostrar tiempo", Bind("prepot", "showText"))
    pb:Check("Remolino de cooldown", Bind("prepot", "showSwirl"))
    pb:Check("Mostrar borde", Bind("prepot", "showBorder"))
    pb:Header("Colores")
    pb:Color("Texto", "prepot", "colorText")
    pb:Color("Texto en aviso", "prepot", "colorWarn")
    pb:Color("Borde", "prepot", "colorBorder", true)

    local subs = { yards, focus, marked, prepot }
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(main, main.name)
        Settings.RegisterAddOnCategory(category)
        for _, sub in ipairs(subs) do
            Settings.RegisterCanvasLayoutSubcategory(category, sub, sub.name)
        end
        ns.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(main)
        for _, sub in ipairs(subs) do InterfaceOptions_AddCategory(sub) end
    end
    ns.RefreshOptions()
end
