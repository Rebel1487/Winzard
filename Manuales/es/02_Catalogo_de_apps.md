# 02 · Catálogo de apps e instalación

## Qué es
El instalador masivo de Winzard: más de **350 aplicaciones** organizadas por categorías en la barra lateral (Navegadores, Imprescindibles, Multimedia, Gaming, Emuladores, Desarrollo, IA Local, Red y Remoto, Oficina, Self-Hosted, Utilidades, Seguridad, Productividad, Discos y Backup, Nube y Sync…). Usa el **motor oficial winget** de Microsoft: los enlaces los gestiona el repositorio de winget, así que nunca caducan.

## Fila superior (siempre visible)
| Elemento | Qué hace |
|---|---|
| **Buscar** | Filtra el catálogo en vivo por nombre, ID o descripción. |
| **Presets: Gaming / Desarrollador / Multimedia / Esencial** | Marca de golpe un conjunto curado de apps para ese perfil. El preset **sustituye** la selección anterior (no se mezclan perfiles sin querer). |
| **Última sesión** | Recupera la selección que tenías la última vez. Esta sí **suma** a lo que tengas marcado. |
| **Guardar / Cargar** | Guarda tu selección actual en un archivo, o carga una guardada. "Cargar" acepta listas `.txt` (un ID por línea) y también `.json` — incluidos los exports de winget que genera "Clonar equipo / Snapshot". |
| **Detectar instaladas** | Detecta qué apps del catálogo ya están en tu PC y las señala. |
| **Limpiar selección** | Desmarca todo. |

## Barra inferior (acciones)
| Botón | Qué hace |
|---|---|
| **Hilos** | Instalaciones simultáneas: "1x seguro" = secuencial (recomendado); 2-3 acelera, con reintento automático si dos instaladores chocan. |
| **Ámbito** | Instalación por máquina o por usuario (Auto decide lo mejor por app). |
| **Fallback Choco** | Si winget falla con una app, reintenta con Chocolatey (opcional). |
| *(Los tres ajustes anteriores se **recuerdan entre sesiones**: los dejas a tu gusto una vez y ya.)* | |
| **Marcar visibles / Desmarcar** | Marca todo lo que hay filtrado en pantalla / limpia la selección. |
| **Marcar instaladas** | Marca las apps que ya tienes instaladas (útil para actualizar o clonar). |
| **Desinstalar** | Desinstala las apps marcadas (con confirmación). |
| **Descargar .exe/.msi** | No instala: descarga los instaladores originales a la carpeta Descargas de Winzard. |
| **Validar IDs** | Comprueba contra winget que cada ID marcado existe (evita sorpresas). |
| **Buscar updates / Actualizar TODO** | Busca actualizaciones de lo instalado / actualiza todo de una vez. "Actualizar TODO" comprueba antes que los servicios de Windows Update estén disponibles, vigila que la tanda no se quede colgada y al final te dice la verdad: si algún instalador interno falló, lo verás como fallo (no como éxito de mentira). |
| **INSTALAR (n)** | Instala las *n* apps marcadas, con progreso, reintentos y log en vivo. Cada instalación lleva **vigilante anticuelgues** (si winget se queda clavado con una app, se corta con aviso y se sigue con la siguiente) y, si alguna cae por un corte de red, el motor **espera a que vuelva la conexión y reintenta solo esas** una vez. |
| **REGISTRO EN VIVO** | Despliega la consola en vivo con el detalle de cada operación. |

## Secciones hermanas de la barra lateral
- **Buscar en winget (todo)**: busca e instala cualquier app del repositorio completo de winget, aunque no esté en el catálogo.
- **Actualizaciones disponibles**: dos grupos — apps del catálogo con update pendiente y otros programas de tu PC.
- **Clonar equipo / Snapshot**: ver manual 12.

## Paso a paso típico
1. Elige un preset (o busca y marca a mano).
2. Pulsa **Validar IDs** si has marcado muchas.
3. Pulsa **INSTALAR (n)** y sigue el progreso en el REGISTRO EN VIVO.
4. Si algo falla, el motor lo reintenta al final y te lo cuenta con claridad; el log forense queda en `logs\`.

## Ejemplos prácticos
- **"PC de gaming recién formateado"**: preset **Gaming** → **Validar IDs** → **INSTALAR (n)**. Discord, Steam y compañía se instalan solos mientras miras el REGISTRO EN VIVO.
- **"Quiero pasar los instaladores a un PC sin internet"**: marca las apps → **Descargar .exe/.msi**: te deja los instaladores originales en la carpeta Descargas de Winzard, sin instalar nada.
- **"Tengo el PC lleno de versiones viejas"**: **Detectar instaladas** → **Buscar updates** → repasa la lista → **Actualizar TODO**. El resumen final te dice la verdad de cada una.
- **"Una app no está en el catálogo"**: barra lateral → **Buscar en winget (todo)**: busca el repositorio completo de winget e instala desde ahí mismo.
- **"Quiero repetir esta selección cada vez que formateo"**: **Guardar** → te llevas el archivo; el día de mañana **Cargar** (vale el `.txt` o un `.json` de winget) y a instalar.

## Notas
- Algunas apps de emuladores incluyen **mini-guías** (panel "Guías"): el catálogo lo indica.
- Nada se instala sin que pulses INSTALAR; la selección nunca viene marcada de fábrica.
