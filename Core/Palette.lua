-- Paleta de colores de ModiTools: tonos oscuros y desaturados de bajo cansancio visual.
-- Es el unico lugar donde se definen colores propios de la interfaz. Los colores con
-- significado del juego (tipos de debuff, clases, calidad) no pasan por aqui.
-- Contraste WCAG verificado: texto >= 4.5:1 y controles >= 3:1 sobre las superficies de uso.

local _, ns = ...

local function hex(h)
    return {
        tonumber(h:sub(1, 2), 16) / 255,
        tonumber(h:sub(3, 4), 16) / 255,
        tonumber(h:sub(5, 6), 16) / 255,
    }
end

local P = {
    -- superficies: ventana < panel < tarjeta < hover/elevado
    bg0 = hex("1C201A"),
    bg1 = hex("242920"),
    bg2 = hex("2D3328"),
    bg3 = hex("353E2E"),
    select = hex("384330"),
    -- bordes
    border = hex("4B5544"),     -- bisel decorativo
    borderHi = hex("7C8872"),   -- contorno de controles y separadores
    -- texto
    text = hex("E6E8DD"),
    textSub = hex("B8BFAC"),
    textMute = hex("A3AB97"),
    disabled = hex("6B7360"),
    -- acentos y semanticos
    accent = hex("CDBE5E"),
    gold = hex("E0C46A"),
    success = hex("84C784"),
    warning = hex("DDB05A"),
    danger = hex("EE8E8E"),
    info = hex("92BCE2"),
}

local hexCache = {}

-- r, g, b, a de un token (para SetColorTexture / SetTextColor / SetVertexColor).
function P.rgb(token, alpha)
    local c = P[token]
    return c[1], c[2], c[3], alpha or 1
end

-- Tabla nueva { r, g, b, a } (para valores por defecto que luego edita el usuario).
function P.color(token, alpha)
    local c = P[token]
    return { c[1], c[2], c[3], alpha or 1 }
end

-- Prefijo "|cffRRGGBB" para texto con colores en cadenas (se cierra con "|r").
function P.hex(token)
    local s = hexCache[token]
    if not s then
        local c = P[token]
        s = string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
        hexCache[token] = s
    end
    return s
end

ns.Palette = P
