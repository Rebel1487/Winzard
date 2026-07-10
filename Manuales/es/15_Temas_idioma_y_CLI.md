# 15 · Temas, idioma, guías y línea de comandos

## Temas
Tres temas completos: **Oscuro**, **Claro** y **Azul (Chris Titus)**. Se cambian desde el desplegable superior de la barra lateral (o desde el Resumen) y se aplican al reiniciar la app. El ajuste se guarda en `wpi_settings.json`.

## Idioma
Winzard es **bilingüe completo**: español e inglés, a la par en cada texto, tooltip y mensaje. Cambia el idioma en el desplegable de la barra lateral; el ajuste se guarda y la interfaz se recarga en el idioma elegido al relanzar.

## Guías (mini-tutoriales)
El panel **Guías** trae mini-tutoriales paso a paso de apps que lo necesitan (emuladores como RetroArch, PCSX2, RPCS3, Dolphin…): BIOS, cores, mandos. El catálogo señala qué apps tienen guía. Puedes añadir las tuyas con `guias.json`.

## Ajustes que se recuerdan
`wpi_settings.json` (junto al WPI) guarda tema, idioma, tu lista de pausa del Gaming, juegos asociados, silencio de notificaciones y la última selección. Bórralo si quieres empezar de cero.

## Línea de comandos (CLI)
Winzard también funciona sin interfaz, para automatizar:
| Parámetro | Qué hace |
|---|---|
| `-Tweaks` | Aplica tweaks desde consola. |
| `-Debloat` | Ejecuta el debloat desde consola. |
| `-Preset ruta.txt` | Instala una lista de apps (un ID de winget por línea). |
| `-Update all\|recommended` | Actualiza apps desde consola. |
| `-Profile ruta.json` | Aplica un perfil maestro completo (apps+tweaks+debloat+update). |
| `-DryRun` | **Bloquea TODO**: con cualquier combinación de parámetros te enseña el PLAN exacto sin tocar nada (verás el banner "MODO DRY-RUN" al empezar). |
| `-BuildIsoKit` | Genera el kit de la ISO sin GUI. Sale **neutro** (sin tweaks ni debloat) salvo que añadas `-IsoTweaksAll` y/o `-IsoDebloatAll`. |
| `-ExportCatalog` | Exporta el catálogo de tweaks a `logs\` (Markdown + JSON). |
| `-SelfTestGui` | Autotest de la interfaz (para verificación). |

Ejemplo: `powershell -File WPI_Moderno.ps1 -Profile mi_perfil.json -DryRun`

Detalles finos para automatizar: la consola desatendida **respeta el idioma guardado** en `wpi_settings.json` (mensajes en ES o EN), y al terminar **no se queda esperando un Enter** si la lanzas desde un script (solo pide Enter en consola interactiva).

## Ejemplos prácticos (automatización)
- **"Ver qué haría mi perfil sin tocar nada"**: `powershell -File WPI_Moderno.ps1 -Profile mi_perfil.json -DryRun` → plan completo con el banner MODO DRY-RUN, cero cambios.
- **"Instalar mi lista de apps en un PC nuevo, sin GUI"**: `powershell -File WPI_Moderno.ps1 -Preset mis_apps.txt -NoReboot` (elevado). Con barra de progreso, anticuelgues y resumen honesto.
- **"Generar el kit de la ISO desde un script"**: `powershell -File WPI_Moderno.ps1 -BuildIsoKit -IsoPath "D:\isos\Win11.iso" -IsoOutDir "D:\salida"` — añade `-IsoTweaksAll -IsoDebloatAll` si quieres el paquete completo.
- **"Actualizar los equipos de casa cada domingo"**: tarea programada que lance `-Update recommended`; la consola respeta tu idioma y no se queda esperando Enter.

## Otras piezas
- **Autoelevación**: Winzard pide permisos de administrador al arrancar (los necesita para aplicar ajustes del sistema); es su mecanismo estándar.
- **Instancia única**: si ya hay un Winzard abierto, el segundo te lo dice y no duplica.
