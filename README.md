# ModiTools

Conjunto de utilidades para World of Warcraft (Retail), cada una con activación independiente y
personalización propia. Se configuran con `/modi` (ventana propia) o desde el ícono del minimapa.

Interfaz en **English** y **Español (MX)**, perfiles exportables por código y versión 0.7.

| Herramienta | Qué hace |
|---|---|
| **Yardas** | Muestra la distancia en yardas hasta tu target. |
| **Cast del focus** | Barra con el casteo de tu focus: colores, textura, chispa, resplandor y sonidos. |
| **Casteos marcados** | Barras con el casteo de los mobs marcados (calavera, estrella, etc.) e indicación de si fueron interrumpidos. |
| **Alerta de threat** | Muestra un texto (personalizable, con sonido) cuando estás perdiendo el aggro de un mob. |
| **Brez en una tecla** | Convierte una tecla (aunque ya la uses) en el brez de tu clase mientras el mouse está sobre un aliado muerto. |
| **CD Timeline** | Línea de tiempo (horizontal o vertical) con los cooldowns que elijas: hechizos, trinkets y pociones. Detecta los de tu clase, con avisos y sonidos por elemento. |
| **Prepot** | Ícono con el tiempo restante de la poción que usaste, y un sonido (voz) cuando su cooldown vuelve a estar listo. |
| **Perfiles** | Guarda, cambia y comparte tu configuración por código (importar / exportar con nombre). |

## Instalación

Copia (o clona) esta carpeta como `World of Warcraft\_retail_\Interface\AddOns\ModiTools` y haz `/reload`.

## Comandos

```
/modi                                  abrir la ventana de opciones
/modi yards|focus|marked|threat|brez|timeline|prepot   activar/desactivar una herramienta
/modi unlock|lock <herramienta|all>    desbloquear (vista previa y mover) / fijar
/modi reset                            restablecer posiciones
/modi size <10-72>                     tamaño del texto de yardas
/modi focus sound <id|ruta>            sonido personalizado para el focus
/modi threat test|text <texto>|sound <id|ruta>
/modi brez key <tecla>|status
/modi timeline pick|add <id>|addItem <id>|remove <id>|removeItem <id>|list|sound <id|ruta>
/modi prepot test|add <id>|remove <id>|sound <id|ruta>
/modi profile [use <nombre>]           listar / cambiar de perfil
/modi minimap                          mostrar/ocultar el ícono del minimapa
/modi lang en|es                       idioma de la interfaz
/modi debug                            mostrar eventos de casteo en el chat
```

## Notas

- Las vistas previas (desbloqueado) se apagan solas al cargar el addon.
- Los casteos marcados se detectan por nameplates: el mob debe tener su barra de nombre visible.
- Si una poción no se detecta sola, agrégala con `/modi prepot add <spellID>`.
- En Midnight el juego puede ocultar cooldowns en combate: la línea de tiempo estima el fin con el
  cooldown base al lanzar el hechizo o usar el objeto.
