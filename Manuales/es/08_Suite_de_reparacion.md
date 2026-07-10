# 08 · Suite de reparación

## Qué es
Las herramientas de reparación de Windows **todo en uno**. El panel tiene tres zonas:
1. **Consola interactiva (menú completo)**: la suite de 17 fases con su propio menú.
2. **Fases individuales (00-16)**: cada fase con su tarjeta y su botón **Lanzar** — diagnóstico, punto de restauración, limpieza, CHKDSK, optimización de disco, DISM, SFC, WMI, Store e Inicio, búsqueda y cachés, certificados y hora, red, directivas GPO, Windows Update, winget, dispositivos e informe final. Antes de lanzar nada te sale una **confirmación centrada sobre Winzard**.
3. **Herramientas rápidas del sistema**: reparaciones de un clic que no necesitan la consola (tabla de abajo). Corren de una en una en el motor asíncrono, con log completo y botón Cancelar.

Requiere permisos de administrador (Winzard se eleva solo).

## Herramientas rápidas del sistema
| Herramienta | Qué hace |
|---|---|
| **Comprobar archivos del sistema (SFC)** | `sfc /scannow`: verifica y repara archivos de sistema dañados. |
| **Reparar imagen de Windows (DISM RestoreHealth)** | Repara el almacén de componentes del que bebe SFC. Lo lógico: DISM primero si SFC no pudo. |
| **Restablecer la red (Winsock/TCP-IP/DNS)** | Resetea la pila de red y limpia el DNS: la solución clásica a "internet raro". |
| **Reparar Windows Update (limpiar caché)** | Detiene los servicios de update, limpia su caché y los relanza. |
| **Limpiar la caché de Microsoft Store** | `wsreset` y arreglos asociados para una Store que no descarga. |
| **Reconstruir el índice de búsqueda** | Windows Search desde cero: para búsquedas rotas o incompletas. |
| **Reparar / Resetear winget** | Deja el motor de instalación como nuevo si winget se atasca. |
| **Programar mantenimiento mensual** | Crea una tarea programada de limpieza + informe una vez al mes. |
| **DNS: Cloudflare / Quad9 / Google / OpenDNS** | Cambia tus DNS a un proveedor rápido o con filtro (Quad9 filtra malware; OpenDNS tiene filtro familiar opcional). |
| **DNS: volver a automático** | Devuelve los DNS al DHCP del router (deshace cualquiera de los anteriores). |
| **Silenciar Microsoft Edge** | Quita los arranques automáticos y accesos directos de Edge, y desactiva su arranque en segundo plano por política. Edge sigue instalado; reversible. |

## Paso a paso típico (sistema inestable)
1. **DISM RestoreHealth** → espera a que termine.
2. **SFC** → repite si reparó algo.
3. Reinicia. Si el problema era de red: **Restablecer la red** y reinicia.

## Ejemplos prácticos
- **"Windows va raro y no sé por qué"**: lanza la **Fase 00 (Diagnóstico y triage)** — es inocua, mira discos, espacio y eventos y te dice por dónde empezar. Si quieres el repaso completo, la **Consola interactiva** en modo automático recorre las 17 fases y te deja un informe HTML con la salud antes/después.
- **"Las páginas tardan en resolver"**: Herramientas rápidas → **DNS: Cloudflare** (o Quad9 si quieres filtro de malware). ¿Arrepentido? **DNS: volver a automático** y como estaba.
- **"La Store no descarga"**: **Limpiar la caché de Microsoft Store** y prueba de nuevo; si el enfermo es winget, **Reparar / Resetear winget**.
- **"Quiero que el PC se cuide solo"**: **Programar mantenimiento mensual**: una tarea al mes con limpieza e informe, sin que te acuerdes.
- **"Edge se me cuela por todas partes"**: **Silenciar Microsoft Edge** — fuera autoarranques y accesos directos, reversible con su propio botón.

## La suite integrada en la ISO
El asistente "Crear ISO" incluye la **Suite de reparación** en `C:\WPI_Suite` del Windows instalado (versión ES o EN según el idioma), con menú propio para usarla sin Winzard.

## Seguridad
Todas son herramientas oficiales de Windows orquestadas con verificación; los cambios de DNS y Edge son reversibles con su propio botón.
