# ModiTools

Conjunto de utilidades para World of Warcraft (Retail), cada una con activación independiente y
personalización propia. Se configuran en **Opciones → AddOns → ModiTools** o con `/modi`.

| Herramienta | Qué hace |
|---|---|
| **Yardas** | Muestra la distancia en yardas hasta tu target. |
| **Cast del focus** | Barra con el casteo de tu focus: colores, textura, chispa, resplandor y sonidos. |
| **Casteos marcados** | Barras con el casteo de los mobs marcados (calavera, estrella, etc.) e indicación de si fueron interrumpidos. |
| **Alerta de threat** | Muestra un texto (personalizable, con sonido) cuando estás perdiendo el threat de un mob. |
| **Brez en una tecla** | Convierte una tecla (aunque ya la uses) en el brez de tu clase mientras el mouse está sobre un aliado muerto. |
| **Prepot** | Ícono con el tiempo restante de la poción que usaste. |

## Instalación

Copia (o clona) esta carpeta como `World of Warcraft\_retail_\Interface\AddOns\ModiTools` y haz `/reload`.

## Comandos

```
/modi                              abrir opciones
/modi yards|focus|marked|threat|brez|prepot    activar/desactivar una herramienta
/modi unlock|lock <herramienta|all>  desbloquear (vista previa y mover) / fijar
/modi reset                        restablecer posiciones
/modi size <10-72>                 tamaño del texto de yardas
/modi focus sound <id|ruta>        sonido personalizado para el focus
/modi threat test|text <texto>|sound <id|ruta>
/modi brez key <tecla>|status
/modi prepot test|add <id>|remove <id>
/modi minimap                      mostrar/ocultar el ícono del minimapa
/modi lang en|es                   idioma de la interfaz (English / Español MX)
/modi debug                        mostrar eventos de casteo en el chat
```

## Notas

- Los casteos marcados se detectan por nameplates: el mob debe tener su barra de nombre visible.
- Si una poción no se detecta sola, agrégala con `/modi prepot add <spellID>`.
