-- Idiomas de ModiTools.
-- El código usa el texto en inglés como clave: L["Text"]. Si no hay traducción se muestra el inglés.
-- Español: latino (MX) con jerga del juego (aggro, prepota, brez, cast, focus, mobs...).

local _, ns = ...

local es = {
    -- Comandos y mensajes (Core)
    ["%s enabled."] = "%s activado.",
    ["%s disabled."] = "%s desactivado.",
    ["Usage: /modi %s <yards|focus|marked|threat|brez|timeline|prepot|all>"] = "Uso: /modi %s <yards|focus|marked|threat|brez|timeline|prepot|all>",
    ["unlocked. Drag with left click to move."] = "desbloqueado. Arrastra con click izquierdo para moverlo.",
    ["locked."] = "bloqueado.",
    ["positions reset."] = "posiciones restablecidas.",
    ["Usage: /modi size <10-72>"] = "Uso: /modi size <10-72>",
    ["Minimap icon hidden."] = "Ícono del minimapa oculto.",
    ["Minimap icon shown."] = "Ícono del minimapa visible.",
    ["Debug enabled."] = "Depuración activada.",
    ["Debug disabled."] = "Depuración desactivada.",
    ["Usage: /modi lang en|es"] = "Uso: /modi lang en|es",
    ["Language changed. Reload the interface to apply it?"] = "Idioma cambiado. ¿Recargar la interfaz para aplicarlo?",
    ["Reload"] = "Recargar",
    ["Later"] = "Después",

    -- Minimapa
    ["Click: open / close the window"] = "Click: abrir / cerrar la ventana",
    ["Drag: move the icon"] = "Arrastrar: mover el ícono",

    -- Cast del focus y sonidos
    ["Focus cast"] = "Cast del focus",
    ["Interrupted"] = "Interrumpido",
    ["Could not read the focus cast: %s"] = "No se pudo leer el cast del focus: %s",
    ["Event not available: %s"] = "Evento no disponible: %s",
    ["Custom sound: %s"] = "Sonido personalizado: %s",
    ["Could not play the sound file. If you just added it, restart the game (a /reload is not enough)."] = "No se pudo reproducir el archivo de sonido. Si lo acabas de agregar, reinicia el juego (un /reload no basta).",
    ["Usage: /modi focus sound <soundkitID or file path>"] = "Uso: /modi focus sound <soundkitID o ruta del archivo>",
    ["Classic"] = "Clásicos",
    ["Raid warning"] = "Aviso de banda",
    ["Ready check"] = "Ready check",
    ["Alarm"] = "Alarma",
    ["Map ping"] = "Ping del mapa",
    ["Whisper"] = "Susurro",
    ["Quest complete"] = "Misión completada",
    ["Level up"] = "Subida de nivel",
    ["Other"] = "Otros",
    ["Custom"] = "Personalizado",
    ["Animals"] = "Animales",
    ["Devices"] = "Dispositivos",
    ["Impacts"] = "Impactos",
    ["Instruments"] = "Instrumentos",
    ["Short"] = "Cortos",
    ["Warcraft II"] = "Warcraft II",
    ["Warcraft III"] = "Warcraft III",

    -- Casteos marcados
    ["Sample cast"] = "Cast de ejemplo",
    ["Not interrupted"] = "No interrumpido",
    ["interrupted"] = "interrumpido",
    ["NOT interrupted"] = "NO interrumpido",
    ["Could not read a marked mob's cast: %s"] = "No se pudo leer el cast de un mob marcado: %s",

    -- Prepota
    ["Prepot test: 30 s."] = "Prueba de prepota: 30 s.",
    ["spellID %d added as a potion."] = "spellID %d agregado como poción.",
    ["spellID %d removed."] = "spellID %d quitado.",
    ["Usage: /modi prepot test | add <spellID> | remove <spellID> | sound <soundkitID or file path>"] = "Uso: /modi prepot test | add <spellID> | remove <spellID> | sound <soundkitID o ruta del archivo>",
    ["Sound when the potion is ready"] = "Sonido cuando la poción está lista",
    ["Potion ready (voice)"] = "Poción lista (voz)",
    ["Trinket ready (voice)"] = "Trinket listo (voz)",
    ["Healing potion ready (voice)"] = "Poción de HP lista (voz)",
    ["HP potion"] = "Poción de HP",
    ["Plays a sound when your healing potion is ready again."] = "Suena cuando tu poción de HP vuelve a estar lista.",
    ["Plays a sound when your healing potion is ready again. Its cooldown is separate from your other potions."] = "Suena cuando tu poción de HP vuelve a estar lista. Su cooldown es aparte del de tus otras pociones.",
    ["Healing potion ready sound"] = "Sonido de poción de HP lista",
    ["Sound when the healing potion is ready"] = "Sonido cuando la poción de HP está lista",
    ["Which potions are healing potions"] = "Cuáles son tus pociones de HP",
    ["Choose healing potions"] = "Elegir pociones de HP",
    ["Healing potions are detected by their name. If yours is not detected (or a combat potion is mistaken for one), pick it here."] = "Las pociones de HP se detectan por su nombre. Si la tuya no se detecta (o una poción de combate se confunde con una), elígela aquí.",
    ["Healing potions have their own cooldown, separate from your other potions."] = "Las pociones de HP tienen su propio cooldown, aparte del de tus otras pociones.",
    ["Choose your healing potions"] = "Elige tus pociones de HP",
    ["Click a potion to mark it as a healing potion, or click again to unmark it."] = "Haz click en una poción para marcarla como poción de HP, o de nuevo para desmarcarla.",
    ["'%s' marked as a healing potion."] = "'%s' marcada como poción de HP.",
    ["'%s' marked as a combat potion."] = "'%s' marcada como poción de combate.",
    ["%d potions marked as healing"] = "%d pociones marcadas como HP",
    ["No potions found yet. Keep a potion in your bags."] = "Aún no hay pociones. Ten una poción en tus bolsas.",
    ["Trinket ready sound"] = "Sonido de trinket listo",
    ["Sound when a trinket is ready"] = "Sonido cuando un trinket está listo",
    ["Trinket %d: %s"] = "Trinket %d: %s",
    ["(empty)"] = "(vacío)",
    ["(no on-use effect)"] = "(sin efecto de uso)",

    -- Alerta de threat
    ["LOSING AGGRO!"] = "¡PERDIENDO AGGRO!",
    ["Mob name"] = "Nombre del mob",
    ["Test mob"] = "Mob de prueba",
    ["Could not read threat: %s"] = "No se pudo leer el threat: %s",
    ["Threat alert test."] = "Prueba de la alerta de threat.",
    ["Usage: /modi threat test | text <text> | sound <soundkitID or file path>"] = "Uso: /modi threat test | text <texto> | sound <soundkitID o ruta del archivo>",

    -- Brez
    ["Class: %s"] = "Clase: %s",
    ["Your class has no combat res."] = "Tu clase no tiene brez.",
    ["ID %s is not a valid spell."] = "El ID %s no es un hechizo válido.",
    ["Spell: %s (ID %d)"] = "Hechizo: %s (ID %d)",
    [" custom"] = " personalizado",
    ["Spell: %s (ID %d, not learned yet)"] = "Hechizo: %s (ID %d, aún no lo aprendes)",
    ["Status: disabled"] = "Estado: desactivado",
    ["Status: choose a key"] = "Estado: elige una tecla",
    ["Status: will apply after combat"] = "Estado: se aplicará al salir de combate",
    ["Status: active on %s"] = "Estado: activo en %s",
    ["Status: inactive"] = "Estado: inactivo",
    ["Brez key: %s"] = "Tecla del brez: %s",
    [" (will apply after combat)"] = " (se aplicará al salir de combate)",
    ["Usage: /modi brez key <key> | status"] = "Uso: /modi brez key <tecla> | status",

    -- Interfaz: general
    ["Home"] = "Inicio",
    ["Yards"] = "Yardas",
    ["Marked casts"] = "Casteos marcados",
    ["Threat alert"] = "Alerta de threat",
    ["Brez on a key"] = "Brez en una tecla",
    ["Prepot"] = "Prepota",
    ["Prepot/Trinket"] = "Prepota/Trinket",
    ["General"] = "General",
    ["Enable"] = "Activar",
    ["Preview / unlock to move"] = "Vista previa / desbloquear para mover",
    ["Appearance"] = "Apariencia",
    ["Elements"] = "Elementos",
    ["Colors"] = "Colores",
    ["Behavior"] = "Comportamiento",
    ["Sounds"] = "Sonidos",
    ["Sound"] = "Sonido",
    ["Text"] = "Texto",
    ["Result"] = "Resultado",
    ["Key"] = "Tecla",
    ["Status"] = "Estado",
    ["Advanced"] = "Avanzado",
    ["How to read it"] = "Cómo interpretarlo",
    ["Restore defaults"] = "Restaurar valores",
    ["Play"] = "Probar",
    ["Press a key..."] = "Presiona una tecla...",
    ["Unassigned"] = "Sin asignar",

    -- Interfaz: inicio
    ["Version %s"] = "Versión %s",
    ["Utilities for your interface, each with its own page in the sidebar:"] = "Utilidades para tu interfaz, cada una con su propia página en la barra lateral:",
    ["Yards: distance to your target."] = "Yardas: distancia a tu target.",
    ["Focus cast: your focus' cast bar."] = "Cast del focus: barra con el cast de tu focus.",
    ["Marked casts: casts of marked mobs."] = "Casteos marcados: casts de los mobs con marca.",
    ["Threat alert: warning when you lose aggro."] = "Alerta de threat: aviso cuando pierdes aggro.",
    ["Brez: combat res on a key."] = "Brez: tu resurrección de combate en una tecla.",
    ["Prepot/Trinket: potion timer, plus ready sounds for potions and trinkets."] = "Prepota/Trinket: tiempo de la poción y sonidos cuando tu poción o tus trinkets están listos.",
    ["The dot next to each tool shows whether it is enabled."] = "El punto junto a cada herramienta indica si está activada.",
    ["Show minimap icon"] = "Mostrar ícono en el minimapa",
    ["Commands:"] = "Comandos:",
    ["<tool|all>"] = "<herramienta|all>",

    -- Interfaz: yardas
    ["Shows the distance in yards to your target."] = "Muestra la distancia en yardas hasta tu target.",
    ["Text size"] = "Tamaño del texto",
    ["WoW does not give the exact distance to an enemy: the addon estimates it."] = "WoW no da la distancia exacta a un enemigo: el addon la estima.",
    ["more than 15 and up to 20."] = "más de 15 y hasta 20.",
    ["less than 5."] = "menos de 5.",
    ["more than 80."] = "más de 80.",
    ["exact (party members only)."] = "exacta (solo miembros de la party).",

    -- Interfaz: cast del focus
    ["Bar with your focus' cast, with customizable colors and sounds."] = "Barra con el cast de tu focus, con colores y sonidos personalizables.",
    ["Width"] = "Ancho",
    ["Height"] = "Alto",
    ["Opacity"] = "Opacidad",
    ["Font size"] = "Tamaño de fuente",
    ["Texture"] = "Textura",
    ["Flat"] = "Plana",
    ["Skills"] = "Habilidades",
    ["Sound when a cast starts"] = "Sonido al iniciar un cast",
    ["Start sound"] = "Sonido de inicio",
    ["Only if it can be interrupted"] = "Solo si se puede interrumpir",
    ["Sound when interrupted"] = "Sonido al interrumpirlo",
    ["Interrupt sound"] = "Sonido de interrupción",
    ["Show icon"] = "Mostrar ícono",
    ["Show spell name"] = "Mostrar nombre del hechizo",
    ["Show time"] = "Mostrar tiempo",
    ["Show border"] = "Mostrar borde",
    ["Spark (glow on the progress edge)"] = "Chispa (brillo en el avance)",
    ["Glow around the bar"] = "Resplandor alrededor",
    ["Normal cast"] = "Cast normal",
    ["Channel"] = "Channel",
    ["Uninterruptible"] = "No interrumpible",
    ["Background"] = "Fondo",
    ["Border"] = "Borde",

    -- Interfaz: casteos marcados
    ["Bars with the casts of marked mobs, showing whether they were interrupted."] = "Barras con el cast de los mobs marcados, indicando si los interrumpieron.",
    ["Spacing"] = "Separación",
    ["Max bars"] = "Máx. de barras",
    ["Grow upward"] = "Crecer hacia arriba",
    ["Show the result on the bar"] = "Mostrar el resultado en la barra",
    ["Announce in chat"] = "Avisar en el chat",
    ["Result duration (s)"] = "Duración del resultado (s)",

    -- Interfaz: alerta de threat
    ["Shows text when you are losing aggro on a mob."] = "Muestra un texto cuando estás perdiendo el aggro de un mob.",
    ["Alert text"] = "Texto de la alerta",
    ["Size"] = "Tamaño",
    ["Font"] = "Fuente",
    ["Outline"] = "Contorno",
    ["Default"] = "Por defecto",
    ["No outline"] = "Sin contorno",
    ["Thick outline"] = "Contorno grueso",
    ["Only if I am the tank"] = "Solo si soy tank",
    ["Flash"] = "Parpadeo",
    ["Show mob name"] = "Mostrar nombre del mob",
    ["Duration (s)"] = "Duración (s)",
    ["Sound when losing aggro"] = "Sonido al perder aggro",
    ["Show background"] = "Mostrar fondo",
    ["Test alert"] = "Probar alerta",

    -- Interfaz: brez
    ["Your key casts your class's combat res when you hover over a dead ally."] = "Tu tecla lanza el brez de tu clase al pasar el mouse sobre un aliado muerto.",
    ["Combat only"] = "Solo en combate",
    ["It can be a key you already use: it only becomes brez while your mouse is over a dead ally. The rest of the time it does what it always does."] = "Puede ser una tecla que ya uses: solo se convierte en brez mientras tengas el mouse sobre un aliado muerto. El resto del tiempo hace lo de siempre.",
    ["Spell ID (optional)"] = "ID del hechizo (opcional)",
    ["Only if your brez is not detected: enter the numeric spell ID (the number in its wowhead.com page, e.g. /spell=20484)."] = "Solo si tu brez no se detecta: escribe el ID numérico del hechizo (el número de su página en wowhead.com, por ejemplo /spell=20484).",
    ["Changes apply after combat."] = "Los cambios se aplican al salir de combate.",

    -- Interfaz: prepota
    ["Two tools in one: a potion timer with a ready sound, and a ready sound for your trinkets."] = "Dos herramientas en una: el cronómetro de tu poción con sonido de listo, y un sonido de listo para tus trinkets.",
    ["What's inside"] = "Qué incluye",
    ["Shows an icon with the time left on the potion you used, and plays a sound when the potion is ready again."] = "Muestra un ícono con el tiempo restante de la poción que usaste, y suena cuando la poción vuelve a estar lista.",
    ["Plays a sound when the trinkets you choose are ready again. It has no icon."] = "Suena cuando los trinkets que elijas vuelven a estar listos. No tiene ícono.",
    ["Open each one with the + next to Prepot/Trinket on the left."] = "Abre cada una con el + junto a Prepota/Trinket, a la izquierda.",
    ["Trinket"] = "Trinket",
    ["Icon with the time left on the potion you used, and a sound when the potion is ready again."] = "Ícono con el tiempo restante de la poción que usaste, y un sonido cuando la poción vuelve a estar lista.",
    ["Plays a sound when the trinkets you choose are ready again."] = "Suena cuando los trinkets que elijas vuelven a estar listos.",
    ["Icon"] = "Ícono",
    ["Preview / unlock to move the icon"] = "Vista previa / desbloquear para mover el ícono",
    ["Potion ready sound"] = "Sonido de poción lista",
    ["Which trinkets to watch"] = "Qué trinkets vigilar",
    ["Pick the trinkets to watch. When you use one, the sound plays as soon as its cooldown ends. Only trinkets with an on-use effect work."] = "Elige qué trinkets vigilar. Al usar uno, el sonido suena apenas termina su cooldown. Solo funcionan los trinkets con efecto de uso.",
    ["Icon size"] = "Tamaño del ícono",
    ["Warn at (s)"] = "Avisar al quedar (s)",
    ["Time position"] = "Posición del tiempo",
    ["Center"] = "Centro",
    ["Below"] = "Abajo",
    ["Above"] = "Arriba",
    ["Test (30 s)"] = "Probar (30 s)",
    ["Cooldown swirl"] = "Remolino de cooldown",
    ["Warning text"] = "Texto en aviso",


    -- Perfiles
    ["Profiles"] = "Perfiles",
    ["Save, switch and share your configuration."] = "Guarda, cambia y comparte tu configuración.",
    ["Profile"] = "Perfil",
    ["Active profile"] = "Perfil activo",
    ["Manage"] = "Administrar",
    ["Profile name"] = "Nombre del perfil",
    ["Create profile"] = "Crear perfil",
    ["Rename profile"] = "Renombrar perfil",
    ["Delete profile"] = "Eliminar perfil",
    ["Reset profile"] = "Restablecer perfil",
    ["Share"] = "Compartir",
    ["Export current profile"] = "Exportar perfil actual",
    ["Export code"] = "Código de exportación",
    ["Import"] = "Importar",
    ["Import code"] = "Código a importar",
    ["Name for the imported profile (optional)"] = "Nombre del perfil importado (opcional)",
    ["Import profile"] = "Importar perfil",
    ["Profile '%s' created."] = "Perfil '%s' creado.",
    ["Profile '%s' is now active."] = "Perfil '%s' activado.",
    ["Profile renamed to '%s'."] = "Perfil renombrado a '%s'.",
    ["Profile '%s' deleted."] = "Perfil '%s' eliminado.",
    ["Profile '%s' reset."] = "Perfil '%s' restablecido.",
    ["Exported '%s'. Copy the code with Ctrl+C."] = "'%s' exportado. Copia el código con Ctrl+C.",
    ["Imported as '%s'."] = "Importado como '%s'.",
    ["Invalid profile code."] = "Código de perfil inválido.",
    ["Type a name first."] = "Escribe un nombre primero.",
    ["A profile with that name already exists."] = "Ya existe un perfil con ese nombre.",
    ["You cannot delete the only profile."] = "No puedes eliminar el único perfil.",
    ["Profile not found."] = "Perfil no encontrado.",
    ["Paste a code first."] = "Pega un código primero.",
    ["Delete profile '%s'?"] = "¿Eliminar el perfil '%s'?",
    ["Reset profile '%s' to defaults?"] = "¿Restablecer el perfil '%s' a sus valores por defecto?",
    ["Profiles: %s (active: %s)"] = "Perfiles: %s (activo: %s)",
    ["Usage: /modi profile use <name>"] = "Uso: /modi profile use <nombre>",


    -- Línea de cooldowns
    ["Style"] = "Estilo",
    ["Timeline style"] = "Estilo de la línea",
    ["A timeline of the cooldowns you choose, showing when they come back."] = "Una línea de tiempo con los cooldowns que elijas, para ver cuándo vuelven.",
    ["Orientation, size and colors of the timeline."] = "Orientación, tamaño y colores de la línea.",
    ["CD Timeline: upcoming cooldowns of your spells."] = "CD Timeline: los cooldowns que vienen de tus hechizos.",
    ["Add to the timeline"] = "Agregar a la línea",
    ["ID"] = "ID",
    ["Add"] = "Agregar",
    ["Type"] = "Tipo",
    ["Item"] = "Objeto",
    ["Trinket"] = "Trinket",
    ["Potion"] = "Poción",
    ["Invalid item ID."] = "ID de objeto inválido.",
    ["Item '%s' added."] = "Objeto '%s' agregado.",
    ["Pick from the list, or type a spell or item ID (the number in its wowhead.com page) and press Add."] = "Elige de la lista, o escribe el ID de un hechizo u objeto (el número de su página en wowhead.com) y presiona Agregar.",
    ["Pick from my spells and items"] = "Elegir de mis hechizos y objetos",
    ["Click an entry to add or remove it."] = "Haz click en un elemento para agregarlo o quitarlo.",
    ["Search..."] = "Buscar...",
    ["No spells found."] = "No se encontraron hechizos.",
    ["Cooldown: %s"] = "Cooldown: %s",
    ["%d of %d on the timeline"] = "%d de %d en la línea",
    ["Done"] = "Listo",
    ["Timing"] = "Tiempos",
    ["Appear within (s)"] = "Aparece a los (s)",
    ["Ignore cooldowns under (s)"] = "Ignorar CDs menores a (s)",
    ["Always show the line"] = "Mostrar siempre la línea",
    ["Only in combat"] = "Solo en combate",
    ["The timeline is only shown while you are in combat, and its sounds (warning and ready) are muted outside of combat. Cooldowns keep being tracked, so everything works as soon as you enter combat. The preview (unlocked) is always visible so you can move it."] = "La línea solo se muestra mientras estás en combate, y sus sonidos (aviso y listo) se silencian fuera de combate. Los cooldowns se siguen registrando, así que todo funciona en cuanto entras en combate. La vista previa (desbloqueada) siempre se ve para que puedas moverla.",
    ["Visibility"] = "Visibilidad",
    ["On the timeline"] = "En la línea",
    ["No spells yet."] = "Aún no hay hechizos.",
    ["Unknown spell"] = "Hechizo desconocido",
    ["Layout"] = "Distribución",
    ["Orientation"] = "Orientación",
    ["Horizontal"] = "Horizontal",
    ["Vertical"] = "Vertical",
    ["Reverse direction"] = "Invertir dirección",
    ["Length"] = "Largo",
    ["Thickness"] = "Grosor",
    ["Show ticks"] = "Mostrar marcas de tiempo",
    ["Show now marker"] = "Mostrar marcador de ahora",
    ["Flash when ready"] = "Destello al estar listo",
    ["Icon border"] = "Borde de los íconos",
    ["Line"] = "Línea",
    ["Ticks"] = "Marcas",
    ["Now marker"] = "Marcador de ahora",
    ["Spell '%s' added."] = "Hechizo '%s' agregado.",
    ["Removed from the timeline."] = "Quitado de la línea.",
    ["Invalid spell ID."] = "ID de hechizo inválido.",
    ["That spell is already on the list."] = "Ese hechizo ya está en la lista.",
    ["The list is full (%d entries)."] = "La lista está llena (%d elementos).",
    ["On the timeline: %s"] = "En la línea: %s",
    ["Usage: /modi timeline pick | add <spellID> | addItem <itemID> | remove <spellID> | removeItem <itemID> | list | sound <soundkitID or file path>"] = "Uso: /modi timeline pick | add <spellID> | addItem <itemID> | remove <spellID> | removeItem <itemID> | list | sound <soundkitID o ruta del archivo>",


    -- Sonidos de la línea de cooldowns
    ["Timeline sounds"] = "Sonidos de la línea",
    ["Sounds for when your cooldowns are about to end or are ready."] = "Sonidos para cuando tus cooldowns estén por terminar o ya estén listos.",
    ["All spells"] = "Todos los hechizos",
    ["Sound when a cooldown is about to end"] = "Sonido cuando un cooldown está por terminar",
    ["Warning sound"] = "Sonido de aviso",
    ["Sound when ready"] = "Sonido al estar listo",
    ["Ready sound"] = "Sonido de listo",
    ["Choose \"Custom\" in a sound list and set it with /modi timeline sound <soundkitID or file path>."] = "Elige «Personalizado» en una lista de sonidos y defínelo con /modi timeline sound <soundkitID o ruta del archivo>.",
    ["Per spell or item"] = "Por hechizo u objeto",
    ["Spell"] = "Hechizo",
    ["Spell or item"] = "Hechizo u objeto",
    ["Add something to the timeline first."] = "Primero agrega algo a la línea.",
    ["Choose a spell or item to give it its own sounds. \"Use the global sound\" keeps the shared one."] = "Elige un hechizo u objeto para darle sus propios sonidos. «Usar el sonido global» mantiene el compartido.",
    ["Warn at (s), 0 = global"] = "Avisar a los (s), 0 = global",
    ["Options"] = "Opciones",
    ["Use the global sound"] = "Usar el sonido global",
    ["No sound"] = "Sin sonido",

    -- Menú de AddOns de Blizzard
    ["Settings live in ModiTools' own window."] = "La configuración está en la ventana propia de ModiTools.",
    ["Open ModiTools"] = "Abrir ModiTools",
}

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L
ns.Locales = { es = es }

local current = "en"

function ns.DetectLanguage()
    local locale = GetLocale and GetLocale() or "enUS"
    return locale:sub(1, 2) == "es" and "es" or "en"
end

-- Cambia las traducciones activas (L es la misma tabla, así que el cambio es inmediato
-- para todo texto que se construya a partir de ahora).
function ns.SetLanguage(lang)
    current = (lang == "es") and "es" or "en"
    for key in pairs(L) do L[key] = nil end
    if current == "es" then
        for key, text in pairs(es) do L[key] = text end
    end
end

function ns.GetLanguage()
    return current
end

-- Los textos de la interfaz se crean al cargar, así que el cambio requiere recargar.
StaticPopupDialogs["MODITOOLS_RELOAD"] = {
    text = "Language changed. Reload the interface to apply it?\nIdioma cambiado. ¿Recargar la interfaz para aplicarlo?",
    button1 = "Reload / Recargar",
    button2 = "Later / Después",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.ChangeLanguage(lang)
    if lang == current and ns.global.language == lang then return end
    ns.global.language = lang
    StaticPopup_Show("MODITOOLS_RELOAD")
end
