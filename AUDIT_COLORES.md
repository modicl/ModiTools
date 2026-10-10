# Auditoría de colores — ModiTools 0.9

Fase 1 (solo lectura). No se modificó ningún archivo existente; este informe y `contrast.py` (en el scratchpad) son lo único creado.

## 1. Resumen ejecutivo

- **`Palette.lua` no existe** en el proyecto (ni en el `.toc`). La "paleta base" real hoy es la tabla local `C` al inicio de `Options.lua:12-23` (tema "Steam clásico" verde oliva, texto blanco puro). Propongo en la sección 4 una paleta oscura completa que conserva la identidad oliva/dorado, y la usaría para crear `Palette.lua` en la Fase 2.
- Los colores del cromo propio están casi todos en `Options.lua` (97 usos de `C.*`) y `Changelog.lua` (6). Ambos pasan por `Skin`, `Label`, `CreateButton` y `ns.UI.C`, así que centralizar es barato.
- Hay **15 literales fuera de la tabla `C`** (hex en chat, grises sueltos, blanco/dorado en tooltips, tinte de desbloqueo).
- **Problemas de contraste en la paleta actual**: `muted` sobre `bg` 3.11:1, sobre `hover` 2.36:1; `accent` sobre `hover/select` 2.7:1; `light` (bordes) 1.7-2.3:1. Texto blanco puro (`#FFFFFF`) en toda la UI.
- **Negro/blanco puro**: texto `{1,1,1}` en `Options` (`C.text`), `Changelog` (`|cffffffff`), Yards, tooltips; fondos/bordes `{0,0,0}` en defaults de FocusCast, MarkedCasts, Prepot, Timeline, ThreatAlert.
- **Estado solo por color**: el punto de la barra lateral (módulo activo/inactivo) y la barra de cast (normal / canal / no interrumpible). El resto ya tiene texto o forma.
- La paleta propuesta pasa **0 fallas** de contraste (sección 5).

## 2. Mapa del proyecto

`ModiTools.toc` carga: Locales, Core, Glow, Secrets, Profiles, Yards, Sounds, FocusCast, MarkedCasts, Prepot, ThreatAlert, BrezKey, Timeline, TankDebuffs, Options, Changelog, Minimap. No hay XML, no hay `Libs/`. Media: `dwarf.tga`, `dwarf_home.tga` (arte, categoría E), 4 `.mp3`.

## 3. Hallazgos

### A) Cromo de UI propio (debe migrar)

| Archivo:línea | Valor actual | Rol | Token propuesto |
|---|---|---|---|
| Options.lua:13 `C.bg` (`#4C5844`) | fondo ventana (1160), páginas (1304), botones (75/256/387), hover-reset (79/260/398) | superficie | ventana → `bg0`; páginas → `bg1`; botones/tarjetas → `bg2` |
| Options.lua:14 `C.bgDark` (`#3E4637`) | sidebar 1204, contenido 1209, lista 1348, menú scroll 306, vista changelog (Changelog:170) | panel | `bg1` |
| Options.lua:15 `C.bgDarker` (`#2A3025`) | inputs, cajas, sliders, menú, scroll, check, búsqueda (246, 373, 481, 498, 622, 644, 685, 717, 873, 1004, 1008, 1334, 1370, 1393; Changelog:187) | superficie hundida | `bg0` (hundido, más oscuro que el panel) |
| Options.lua:21 `C.hover` (`#5C6B52`) | hover botones/filas (78, 259, 270, 391, 1007, 1033, 1357) | hover | `bg3` |
| Options.lua:22 `C.select` (`#5A6A50`) | fila/nav seleccionado (280, 281, 1029) | selección | `select` (nuevo) |
| Options.lua:16 `C.light` | bisel claro (40-45), líneas separadoras (449, 1065), punto nav apagado (943) | borde/separador | bisel → `border`; contorno de controles → `borderHi`; punto apagado → ver 6 |
| Options.lua:17 `C.dark` | bisel oscuro (40-45) | borde | `bg0` |
| Options.lua:18 `C.text` (blanco puro) | todo el texto (66, 76, 411, 653, 683, 776, 991, 1332, 1008…) | texto | `text` |
| Options.lua:19 `C.muted` | texto secundario, thumbs de scroll (190, 309, 484, 871, 1396; Changelog:190) | texto secundario / thumb | texto → `textSub`; placeholder/thumb → `textMute` |
| Options.lua:20 `C.accent` | marca de check (377), hover/seleccionado (176, 180, 410, 497, 652, 772, 991), barra nav (1038), marca fila (1374) | acento | `accent` |
| Options.lua:393-394 | `SetText(…,1,0.82,0)` / `AddLine(…,1,1,1)` en tooltip del "?" | tooltip propio | título → `gold`; cuerpo → `text` |
| Options.lua:605 | `SetText(L["Play"],1,1,1)` | tooltip del play | `text` |
| Options.lua:626 | `SetColorTexture(0.35,0.35,0.35,1)` | muestra de preview del glow | `bg3` |
| Options.lua:848 | `\|cffa0aa95` | texto atenuado en lista | `textSub` |
| Options.lua:1495, 1664 | `\|cffc4b550` | resalte en texto de ayuda | `accent` |
| Changelog.lua:122 | `\|cffc4b550`, `\|cffa0aa95`, `\|cffffffff` | acento / atenuado / texto | `accent`, `textSub`, `text` |
| Minimap.lua:74-75 | `1,1,1` y `0.7,0.7,0.7` en `GameTooltip` | líneas de tooltip | `text`, `textSub` |
| Core.lua:87 | `SetColorTexture(0,0.4,0.8,0.35)` | tinte de "desbloqueado" (todos los módulos) | `info` con alfa 0.35 (azul saturado → desaturado) |
| Core.lua:15 | `\|cff33aaff` | prefijo de chat | `info` |
| Yards.lua:179, 187 | `1,1,1` / `0.7,0.7,0.7` | texto HUD de yardas (activo / "-- yd") | `text` / `textSub` |
| Timeline.lua:203 | `1,0.82,0,0.6` | resplandor de icono | `gold` (alfa 0.6) |
| FocusCast.lua:115, MarkedCasts.lua:83 | `0.5,0.5,0.5` | textura de "bloqueado" | `disabled` |
| TankDebuffs.lua:75 | `1,1,1,1` | máscara neutra, luego teñida con `SetVertexColor` | **no cambia** (técnica, el color final lo pone otra línea) |

### B) Semántico propio

| Archivo:línea | Valor | Rol | Token |
|---|---|---|---|
| MarkedCasts.lua:343 | `\|cff33ff55` | "interrumpido" en chat | `success` |
| MarkedCasts.lua:345 | `\|cffff3333` | "NO interrumpido" en chat | `danger` |
| Changelog.lua:127 | `\|cff6fd36f` | etiqueta [Nuevo] | `success` |
| BrezKey.lua:136 | `\|cff7fe07f` / `\|cffff6060` / `\|cffa0aa95` | ok / error / neutro | `success` / `danger` / `textSub` |
| BrezKey.lua:158 | `\|cffffd060` | "se aplicará tras el combate" | `warning` |

### C) Significado del juego (solo se reporta, no se toca)

- `TankDebuffs.lua:166-168` `DISPEL_COLORS` (Magic/Curse/Disease/Poison/Bleed) y `:180`: colores de tipo de debuff **hardcodeados**, no vienen de `DebuffTypeColor` de Blizzard. Fuera de alcance migrarlos a la paleta; sugiero (como mejora aparte) usar la tabla de Blizzard para respetar accesibilidad. En 12.0 la ruta principal ya usa `GetAuraDispelTypeColor` (API de Blizzard).
- No hay uso de `RAID_CLASS_COLORS`, `ITEM_QUALITY_COLORS` ni `NORMAL_FONT_COLOR`.

### D) Colores que elige el usuario (valores guardados intactos; solo defaults)

Selector: `Options.lua:96-130` (`ColorPickerFrame`, compatible con API nueva y vieja; no se cambia). Defaults (solo afectan instalaciones nuevas o "Restaurar valores"):

| Archivo:línea | Default | Observación |
|---|---|---|
| FocusCast.lua:24-29 / MarkedCasts.lua:18-24 | cast `{1,.8,.1}`, canal `{.2,.9,.3}`, bloqueado `{.6,.6,.6}`, fallo/no interrumpido `{.9,.2,.2}`, interrumpido `{.2,.85,.3}` | son colores de gameplay sobre el HUD (cast/canal/fallo). Propongo **mantenerlos** (distinguibilidad en combate > armonía) |
| FocusCast.lua:28-29, MarkedCasts.lua:23-24, Prepot.lua:26, Timeline.lua:33, ThreatAlert.lua:25 | fondo `{0,0,0,.6}` / borde `{0,0,0,1}` | negro puro. Propongo `bg0` (fondo) y `border` (borde) como nuevos defaults |
| Prepot.lua:24-25, TankDebuffs.lua:32, Timeline.lua:31 | texto blanco `{1,1,1}` | → `text` |
| Prepot.lua:25, ThreatAlert.lua:24 | rojo `{1,.2,.2}` | alerta; → `danger` (más claro y desaturado) |
| Timeline.lua:30-32, TankDebuffs.lua:31, 34 | línea `{.08,.08,.1,.75}`, ahora `{1,.82,0}`, borde `{.75,.1,.1}`, glow `{1,.82,0}` | → `bg0`, `gold`, `danger`, `gold` |

### E) Texturas con color horneado

`Media/dwarf.tga`, `Media/dwarf_home.tga` (retrato del enano, arte; no recolorable). Texturas de Blizzard usadas: `UI-Minimap-Background`, `MiniMap-TrackingBorder`, `Arrow-Down-Up`, `UI-SpellbookIcon-NextPage-Up` (botón play): no son nuestras.

## 4. Paleta propuesta (a guardar en `Palette.lua`)

Se conserva el tono oliva y el dorado existente, más oscuro y sin negro/blanco puros.

| Token | Hex | Uso |
|---|---|---|
| bg0 | `#1C201A` | ventana, campos hundidos, fondo de HUD |
| bg1 | `#242920` | paneles (sidebar, contenido, páginas) |
| bg2 | `#2D3328` | tarjetas, botones |
| bg3 | `#353E2E` | hover / elevado, muestra de preview |
| border | `#4B5544` | bisel decorativo, bordes de HUD |
| **borderHi** (nuevo) | `#7C8872` | contorno de controles y separadores (≥3:1) |
| text | `#E6E8DD` | texto principal |
| textSub | `#B8BFAC` | texto secundario |
| textMute | `#A3AB97` | placeholder, thumbs de scroll |
| disabled | `#6B7360` | deshabilitado / bloqueado (exento de contraste) |
| accent | `#CDBE5E` | acento (antes `#C4B550`, +luminancia para pasar sobre `select`) |
| gold | `#E0C46A` | resplandor, marcador "ahora", títulos de tooltip |
| **select** (nuevo) | `#384330` | fila / nav seleccionado |
| success | `#84C784` | ok, [Nuevo], interrumpido |
| warning | `#DDB05A` | pendiente |
| danger | `#EE8E8E` | error, no interrumpido, alerta |
| info | `#92BCE2` | prefijo de chat, tinte de desbloqueo |

Tokens nuevos: `borderHi` (los controles necesitan ≥3:1 y `border` solo da 1.7-2.1:1, por eso `border` queda como bisel decorativo) y `select` (el hover y la selección actuales eran casi iguales, 5C6B52 vs 5A6A50).

## 5. Contraste WCAG (script ejecutado: `contrast.py`)

Resumen (valores completos en `contrast_out.txt`):

| Par | Mínimo | Peor caso | Resultado |
|---|---|---|---|
| text / textSub / textMute sobre bg0-bg3 | 4.5 | textMute en bg3: 4.70 | OK |
| accent, gold, success, warning, danger, info (texto) sobre bg0-bg3 | 4.5 | danger en bg3: 4.73 | OK |
| text, textSub, accent, gold sobre `select` | 4.5 | textSub: 5.51 | OK |
| borderHi, accent, gold (controles) sobre bg0-bg2 | 3.0 | borderHi en bg2: 3.48 | OK |
| Prefijos de chat propuestos sobre `#1C1C1C` | 4.5 | danger 7.22 | OK |
| **Informativos** | — | `border` 1.66-2.11 (decorativo); `disabled` 2.26-3.34 (exento) | n/a |

Paleta **actual**, para comparar: `muted` sobre `bg` 3.11, sobre `hover` 2.36; `accent` sobre `bg` 3.61, `hover` 2.74, `select` 2.79; `light` (bordes) 1.74-2.30. Además `|cffff3333` (no interrumpido) da 4.69 sobre fondo de chat oscuro típico, el justo.

Jerarquía de superficies: bg0→bg1 1.11, bg1→bg2 1.14, bg2→bg3 1.16 (escalones sutiles, intencional para baja fatiga; los bordes `border`/`borderHi` hacen la separación visible).

Nota: el fondo real del chat y del mundo detrás del HUD no se puede medir; los cálculos de chat usan `#1C1C1C` como referencia.

## 6. Problemas detectados

1. **Duplicación**: `#C4B550`, `#A0AA95` y `#FFFFFF` están repetidos como literales hex en 4 archivos además de `C`. `C` ya se exporta como `ns.UI.C`, pero Changelog usa strings sueltos.
2. **Solo color**:
   - Punto de la barra lateral (`Options.lua:943`): activo = acento opaco, inactivo = gris al 40%. Propuesta: activo = punto **relleno**, inactivo = **anillo/guion** (forma distinta) además del color, y `tooltip`/texto "Activado/Desactivado" en el título de página si no lo tiene ya.
   - Barra de cast (FocusCast:188, 242, 272): cast / canal / no interrumpible / fallo se distinguen solo por color. FocusCast y MarkedCasts ya muestran texto del hechizo; propuesta: agregar un icono de candado (textura de Blizzard) para "no interrumpible" y texto "Falló"/"Interrumpido" en el estado de fallo (si no existe ya; lo verifico en la Fase 2 sin cambiar lógica).
   - BrezKey, MarkedCasts, Changelog: ya llevan texto, OK.
3. **Blanco/negro puros**: ver B y D; todos tienen sustituto.
4. **Midnight 12.0 (valores secretos)**: ningún color propio depende de valores secretos. `TankDebuffs.lua:200` pasa un color devuelto por la API de Blizzard directo al widget (`pcall`), no se toca.
5. **Posible regresión visual**: `Skin()` usa `C.bg` tanto para ventana como para botones; al mapear a bg0/bg2 hay que decidir el color por rol, no por token antiguo (ver plan).

## 7. Plan de cambios por archivo (Fase 2, un componente por commit)

1. `Palette.lua` (nuevo) + `.toc` (tras `Core.lua`, antes de `Glow.lua`): `ns.Palette` con los tokens (`{r,g,b}` + helper `ns.Palette.rgb(token, alpha)` y `ns.Palette.hex(token)` para `|cff…|r`). Sin globales.
2. `Options.lua`: `C` pasa a ser alias de `ns.Palette` con los nombres nuevos; reasignar por rol (tabla de la sección 3A); dot activo/inactivo con forma; tooltips.
3. `Changelog.lua`: strings hex → `ns.Palette.hex(...)`.
4. `Core.lua`: prefijo y tinte de desbloqueo.
5. `Yards.lua`, `Minimap.lua`, `BrezKey.lua`, `MarkedCasts.lua` (chat + `locked`), `Timeline.lua` (glow + defaults), `FocusCast.lua`, `Prepot.lua`, `ThreatAlert.lua`, `TankDebuffs.lua`: literales A/B → tokens; defaults D → tokens (solo instalaciones nuevas; `Profiles`/SavedVariables no se tocan).
6. Redundancias no cromáticas (sección 6.2).
7. Verificación: grep de literales fuera de `Palette.lua`, `luac -p`, orden del `.toc`, contraste final.

## 8. Riesgos

- Cambiar defaults de color de HUD no afecta perfiles existentes, pero sí "Restaurar valores" y perfiles nuevos.
- Oscurecer la ventana cambia bastante la identidad visual (de oliva medio a oliva muy oscuro); conviene verlo en el juego.
- Los tooltips de `GameTooltip` usan el estilo de Blizzard; solo se cambia el color del texto que ModiTools agrega.
- Nada de esto se puede validar sin ejecutar el juego (ver lista final en Fase 2).

## 9. Fuera de alcance (anotado, no se arregla)

- `DISPEL_COLORS` hardcodeado en `TankDebuffs.lua:166` en vez de la tabla de Blizzard.
- `Options.lua` tiene 2105 líneas; conviene partirlo en archivos por página.
- La versión se lee con un fallback `"0.9"` hardcodeado en `Options.lua:935`.
