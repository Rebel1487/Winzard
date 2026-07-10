# 11 · Entorno de recuperación

## Qué es
Tu **red de seguridad**. Aquí no se "repara el sistema" (para eso está la Suite de reparación): aquí se **vuelve atrás** con tus copias. Cada opción explica qué es, cómo funciona y qué pasará antes de que pulses nada.

## Botón a botón
| Elemento | Qué hace |
|---|---|
| **PAQUETE DE RESCATE (un clic)** | Congela AHORA todas tus redes de seguridad en una carpeta `Rescate_<fecha>` dentro de `Restauracion\`: punto de restauración del sistema, perfil de tweaks con el estado REAL, lista completa de apps (winget export), copia del diario de cambios y de los arranques aparcados, y un LEEME con instrucciones. Tarda 30-90 s, **no cambia nada** (solo crea copias) y VERIFICA el contenido antes de dar el OK. |
| **ESTADO DE TUS REDES DE SEGURIDAD (en vivo)** | Muestra en vivo si tienes punto de restauración, protección del sistema, diario, etc. |
| **Cargar perfil de tweaks** | Restaura una selección/estado de tweaks guardado (por ejemplo, del paquete de rescate). |
| **Restaurar arranques aparcados** | Devuelve y verifica los arranques automáticos que se hubieran desactivado. |
| **Restauración del sistema (rstrui)** | Abre la herramienta oficial de Windows para volver a un punto anterior. |
| **Abrir carpeta de copias** | Abre `Restauracion\` en el Explorador. |

## Cómo usar un paquete de rescate
1. `perfil_tweaks.json` → se carga desde **Cargar perfil de tweaks**.
2. `apps_winget.json` → se importa con `winget import -i apps_winget.json` (o desde Clonar equipo).
3. El punto de restauración → desde **Restauración del sistema**.
4. `wpi_journal.jsonl` y `autoruns_desactivados.json` → copias del diario y de los arranques aparcados.

## Ejemplos prácticos
- **"Voy a hacer una tanda grande de tweaks"**: antes, **PAQUETE DE RESCATE** (30-90 s). Si algo no te gusta después, tienes el estado exacto anterior para volver.
- **"Deshice tweaks pero quiero mi configuración de la semana pasada"**: **Cargar perfil de tweaks** y elige el `perfil_tweaks.json` del rescate de ese día → APLICAR en la sección Tweaks.
- **"Formateé y quiero mis programas de vuelta"**: del paquete de rescate, `winget import -i apps_winget.json` (o Clonar equipo → importar): tus apps se instalan solas.
- **"Windows raro tras un driver"**: **Restauración del sistema (rstrui)** → elige el punto anterior al driver. Lo oficial de Windows, a un botón.

## Consejo
Crea un paquete de rescate **antes de tocar nada importante** (tandas grandes de tweaks, debloat agresivo, pruebas). Es un clic y te da marcha atrás total.
