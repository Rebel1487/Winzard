# 14 · Resumen del sistema, visor de logs y diario

## Resumen del sistema
El panel de estado de tu equipo, de un vistazo:
| Tarjeta | Qué muestra |
|---|---|
| **Disco C: / Memoria RAM** | GB libres/en uso, con porcentaje. |
| **Apps del catálogo** | Cuántas tienes disponibles para instalar. |
| **Tweaks aplicados** | Cuántos detecta aplicados de los comprobables. |
| **Bloatware presente** | Cuántas apps de la lista siguen instaladas. |
| **Punto de restauración** | Si la protección está activada (y aviso claro si no lo está). |

### Botones del Resumen
| Botón | Qué hace |
|---|---|
| **Guardar diagnóstico** | Exporta un informe del estado del equipo. |
| **Exportar perfil maestro** | Guarda en un JSON toda tu configuración (apps + tweaks + debloat + update) para reproducirla en otro PC o por CLI (`-Profile`). |
| **Foto del sistema / Comparar con la foto** | Instantánea de servicios, procesos, arranques y RAM ANTES de tus cambios; después, la comparativa te dice qué cambió de verdad. |
| **Cambiar tema** | Rota entre los 3 temas (se aplica al reiniciar la app). |

## Visor de logs
Consulta los **registros forenses** de Winzard (carpeta `logs\`): elige un archivo en el desplegable y ve sus últimas líneas. Botones **Refrescar** y **Abrir carpeta de logs**.

## El diario de cambios (wpi_journal)
Cada tweak aplicado/revertido, cada sesión de Modo Juego y cada acción relevante queda anotada con fecha en `logs\wpi_journal.jsonl`. Es la base de "Deshacer lo de hoy" y del paquete de rescate.

## Ejemplos prácticos
1. **"¿De verdad mejora algo con los tweaks?"**: **Foto del sistema** → aplica tu tanda → **Comparar con la foto**: servicios, procesos, arranques y RAM antes/después. Datos, no humo.
2. **"Quiero llevarme MI Winzard configurado a otro PC"**: **Exportar perfil maestro** → en el otro equipo `powershell -File WPI_Moderno.ps1 -Profile mi_perfil.json` (o pruébalo antes con `-DryRun` para ver el plan sin tocar nada).
3. **"Algo falló y quiero saber qué pasó exactamente"**: Visor de logs → elige el log de esa operación (instalación, tweaks, debloat…) y lee el detalle línea a línea; **Abrir carpeta de logs** si quieres el archivo entero.
4. **"¿Tengo el equipo protegido?"**: la tarjeta de **Punto de restauración** te lo dice en grande; si está desactivada, el aviso te lleva a arreglarlo en un clic.
