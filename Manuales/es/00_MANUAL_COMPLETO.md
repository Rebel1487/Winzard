# WINZARD — MANUAL COMPLETO (español)

Todos los manuales de Winzard en un solo documento. Cada sección explica qué es, para qué sirve cada botón y cómo usarla paso a paso. También tienes cada manual por separado en esta misma carpeta — y puedes leerlos todos DENTRO de Winzard, desde los botones del Inicio rápido.

## Índice
- [01 · Inicio rápido (modo fácil)](#01-inicio-rpido-modo-fcil)
- [02 · Catálogo de apps e instalación](#02-catlogo-de-apps-e-instalacin)
- [03 · Buscar en todo (global)](#03-buscar-en-todo-global)
- [04 · Tweaks y ajustes](#04-tweaks-y-ajustes)
- [05 · Gaming Optimizer](#05-gaming-optimizer)
- [06 · Control de Windows Update](#06-control-de-windows-update)
- [07 · Quitar bloatware (Appx)](#07-quitar-bloatware-appx)
- [08 · Suite de reparación](#08-suite-de-reparacin)
- [09 · Características de Windows](#09-caractersticas-de-windows)
- [10 · Drivers y hardware](#10-drivers-y-hardware)
- [11 · Entorno de recuperación](#11-entorno-de-recuperacin)
- [12 · Clonar equipo / Snapshot](#12-clonar-equipo-snapshot)
- [13 · Crear ISO de Windows a medida (avanzado)](#13-crear-iso-de-windows-a-medida-avanzado)
- [14 · Resumen del sistema, visor de logs y diario](#14-resumen-del-sistema-visor-de-logs-y-diario)
- [15 · Temas, idioma, guías y línea de comandos](#15-temas-idioma-guas-y-lnea-de-comandos)

---

# 01 · Inicio rápido (modo fácil)

## Qué es
La pantalla de bienvenida de Winzard. Resume todo lo que puedes hacer en **7 pasos guiados**, pensados para que cualquier persona —sin conocimientos técnicos— deje su Windows listo en pocos clics. La barra lateral izquierda es el "modo experto": contiene todas las secciones con el control completo. El Inicio rápido no ejecuta nada por sí solo: cada botón te lleva a su sección, y allí eliges y confirmas.

Al abrir Winzard verás primero una **pantalla de carga con barra de progreso**: la app está preparando el catálogo, los detectores y el motor de instalación. Cuando desaparece, Winzard está listo para usar del tirón (nada de ventanas a medio dibujar).

## Botón a botón
| Elemento | Qué hace al pulsarlo |
|---|---|
| **Manuales de Winzard (botonera)** | Cada manual tiene su propio botón pequeño ("01 · Inicio rapido", "02 · Catalogo de apps"…) y el **Manual completo** va destacado. Al pulsar uno, el manual se abre en una **ventana de lectura premium dentro de Winzard**: lees sin salir de la app ni abrir carpetas. Dentro del visor tienes "Cerrar" y, si la necesitas, "Abrir la carpeta de manuales". |
| **1. Instala tus programas → "Ir a Programas"** | Te lleva al catálogo de más de 350 apps. Marcas las que quieras y pulsas INSTALAR. |
| **2. Optimiza Windows (Tweaks) → "Ir a Tweaks"** | Te lleva a los 86 ajustes de privacidad y rendimiento, reversibles. Dentro tienes "Aplicar recomendado para MI equipo". |
| **3. Prepara tu PC para jugar (Gaming) → "Ir a Gaming"** | Abre el Gaming Optimizer: chequeo honesto, Modo Juego por sesión 100 % reversible, radar de overlays y medición real. Sin promesas de FPS. |
| **4. Quita el bloatware → "Ir a Limpiar"** | Abre la sección para eliminar apps preinstaladas (reinstalables desde la Store). |
| **5. Repara Windows → "Ir a Reparación"** | Abre la suite de reparación (SFC, DISM, red, Windows Update, DNS…). |
| **6. Crea tu ISO a medida → "Ir a Crear ISO"** | Abre el asistente paso a paso para crear una ISO de Windows con tus apps, tweaks, debloat y drivers ya integrados. |
| **7. Mira el estado de tu equipo → "Ir a Resumen"** | Abre el resumen del sistema: estado de discos, RAM, protección, foto antes/después y diagnóstico exportable. |

## Paso a paso recomendado (primera vez)
1. Pulsa **"Ir a Resumen"** y crea un punto de restauración si el panel te avisa de que la protección está desactivada.
2. Vuelve al Inicio rápido y sigue los pasos 1 → 2 → 3 → 4 en orden.
3. Los pasos 5-7 son para cuando los necesites: reparar, crear una ISO o revisar el estado.

## Ejemplos prácticos
- **"Acabo de instalar Winzard, ¿por dónde empiezo?"**: espera a que la barra de carga termine, pulsa el botón del **Manual completo** (destacado) y hojéalo en la ventana de lectura; después sigue los pasos 1 → 2 → 3 → 4.
- **"Solo quiero instalar mis programas"**: botón **"Ir a Programas →"**, marca lo tuyo y pulsa INSTALAR. No necesitas nada más del resto.
- **"No entiendo qué hace la sección Gaming"**: pulsa su botón pequeño **"05 · Gaming Optimizer"** en la botonera de manuales: se abre su manual dentro de Winzard, con cada botón explicado.

## Seguridad
Nada de esta pantalla cambia el sistema. Todo lo que ejecutes después es reversible, queda registrado en el diario de cambios y se puede deshacer desde su propia sección o desde el Entorno de recuperación.

---

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

---

# 03 · Buscar en todo (global)

## Qué es
Un buscador global que encuentra **cualquier cosa dentro de Winzard** — apps del catálogo, tweaks, bloatware o características de Windows — y te lleva a su sección con un clic.

## Cómo se usa
1. Escribe al menos **2 letras** y pulsa **Buscar** (o Enter).
2. Los resultados aparecen agrupados por tipo (app, tweak, bloatware, característica).
3. Pulsa un resultado: Winzard salta a su sección y lo deja localizado.

## Ejemplos útiles
- "telemetría" → lista los tweaks de privacidad relacionados.
- "xbox" → apps del catálogo + bloatware de Xbox + tweaks de Game Bar.
- "hyper-v" → característica de Windows correspondiente.

## Notas
- Si no hay resultados, prueba otro término o revisa la ortografía (busca en español o en inglés según el idioma de la interfaz).
- El buscador no ejecuta nada: solo navega.

---

# 04 · Tweaks y ajustes

## Qué es
**86 ajustes de Windows** (privacidad, rendimiento, interfaz, red, gaming, sistema) aplicables y **reversibles uno a uno**. Cada tweak tiene su interruptor, su color de estado y su detector de estado real: Winzard comprueba en tu Windows si el ajuste está aplicado de verdad, no lo supone.

## El código de colores (leyenda al pie de la lista)
- **Verde + interruptor encendido** = ya aplicado en este PC (detectado de verdad).
- **Ámbar** = tweak avanzado sin aplicar (aplícalo con criterio; su tooltip lo explica).
- **Gris** = acción puntual sin estado (por ejemplo, una limpieza).
- **Color normal** = tweak seguro sin aplicar.

El interruptor es también tu **selección**: enciende los que quieras aplicar, apaga los que no. "APLICAR" omite con aviso lo que ya está aplicado, así que nunca re-ejecuta nada por error.

## Botón a botón
| Botón | Qué hace |
|---|---|
| **Buscador** | Filtra los 86 tweaks en vivo. |
| **Presets Seguro / Equilibrado / Agresivo** | Marca conjuntos con distinto nivel de impacto (nada se aplica hasta que pulses APLICAR). |
| **APLICAR SELECCIONADOS (n)** | Ejecuta solo lo marcado que falte por aplicar. Cada tweak informa de su resultado. |
| **REVERTIR SELECCIONADOS** | Ejecuta el "deshacer" oficial de cada tweak marcado y lo devuelve a su valor por defecto. |
| **Re-detectar estado** | Vuelve a leer el estado REAL de cada tweak en tu Windows y actualiza colores e interruptores. |
| **Verificar todo** | Genera un informe HTML con la verificación de cada ajuste, detector a detector. |
| **Marcar lo recomendado que falta** | Marca los tweaks seguros recomendados que aún no estén aplicados. |
| **Aplicar recomendado para MI equipo** | Analiza tu hardware (portátil/sobremesa, GPU, disco…) y aplica solo lo seguro para TU caso concreto. |
| **Exportar catálogo** | Guarda en `logs\` la lista completa de tweaks (Markdown + JSON) con lo que hace cada uno. |

## Paso a paso típico
1. Pulsa **Re-detectar estado** para ver la foto real de tu PC.
2. Pulsa **Marcar lo recomendado que falta** (o elige un preset, o marca a mano).
3. Revisa lo ámbar: su tooltip y su desplegable ℹ explican qué hace y cuándo evitarlo.
4. Pulsa **APLICAR SELECCIONADOS** y lee el resumen.
5. ¿Algo no te convence? Márcalo y pulsa **REVERTIR SELECCIONADOS**: vuelve al valor por defecto de Windows.

## Ejemplos prácticos
- **"Quiero más privacidad sin riesgo"**: Re-detectar estado → **Marcar lo recomendado que falta** → APLICAR. En un minuto tienes la telemetría, la publicidad y los sugeridos fuera, todo reversible.
- **"Es el PC de mi madre y no quiero líos"**: pulsa **Aplicar recomendado para MI equipo** y ya está — Winzard analiza si es portátil o sobremesa, qué GPU y qué disco tiene, y aplica solo lo seguro para ese hardware.
- **"Aplicué algo y ahora el menú contextual no me gusta"**: busca "menú" en el buscador, enciende ese tweak y pulsa **REVERTIR SELECCIONADOS** — vuelve exactamente al valor de fábrica de Windows.
- **"¿Esto está aplicado de verdad?"**: pulsa **Verificar todo** y abre el informe HTML: cada ajuste con su detector, su valor esperado y su valor real, en verde o rojo.
- **"Quiero la lista entera para leerla con calma"**: **Exportar catálogo** te deja en `logs\` un Markdown y un JSON con los 86 tweaks y su explicación.

## Reversibilidad y seguridad
- Casi todos los tweaks tienen reversión oficial 1:1 (el propio botón REVERTIR). Los pocos que no (una limpieza de temporales, un punto de restauración) lo dicen claramente.
- Todo queda anotado en el **diario de cambios** y el "Paquete de rescate" (Entorno de recuperación) guarda tu perfil de tweaks con el estado real.
- Consejo: crea un punto de restauración antes de una tanda grande (el primer tweak de la lista lo hace por ti).

---

# 05 · Gaming Optimizer

## Qué es
La preparación **honesta** del PC para jugar. Aquí no hay promesas de FPS: se trabaja con estabilidad, latencia, frametimes y microtirones, con todo reversible y verificado. Se organiza en 4 subsecciones (píldoras): **Preparar · Jugar · Automatizar · Medir**, más un botón de un clic arriba.

## Arriba del todo
| Elemento | Qué hace |
|---|---|
| **Optimizar para jugar (modo fácil)** | Un clic seguro: refresca el chequeo, revisa el Game Mode de Windows y delega ProBalance en Process Lasso si está instalado. |
| **Ver plan (sin tocar nada)** | Muestra EXACTAMENTE qué haría la activación (o la restauración) del Modo Juego: plan de energía y procesos con sus PID. No cambia nada. |

## PREPARAR
- **Chequeo previo (solo lectura):** GPU, CPU, RAM, disco, HAGS y VRR, estado de los tweaks gaming del catálogo (verde = aplicado). Analiza y recomienda; no cambia nada.
- **Radar de overlays:** detecta Game Bar, Discord, NVIDIA Overlay, OBS, RivaTuner y el overlay de Steam (puntos verde/ámbar); el tooltip te dice dónde se apaga cada uno. Winzard no los toca.
- **Red para online → "Medir red (10 s)":** 10 pings reales a 1.1.1.1 en segundo plano; te da media, mínimo, máximo, jitter y pérdida, con veredicto honesto. La interfaz no se congela.

## JUGAR
- **Modo Juego por sesión (100 % reversible):** al activarlo cambia el plan de energía al máximo y PAUSA (nunca cierra) los procesos de TU lista; al desactivarlo, todo vuelve exactamente como estaba.
  - **Lista de pausa:** tú eliges los procesos; nada viene marcado de fábrica; los procesos críticos del sistema están protegidos y no se pueden pausar.
  - **Silenciar notificaciones durante la sesión:** interruptor opcional; guarda tu valor previo exacto y lo restaura al salir.
  - Si la app se cerrara a mitad de sesión, al reabrirla detecta la sesión pendiente y ofrece **"Restaurar todo"**.
- **Motor en tiempo real (delegado):** el trabajo en tiempo real (ProBalance, prioridades) se delega en **Process Lasso**; Winzard no incluye un planificador propio a propósito.
- **Presets:** *Competitivo* (plan máximo + ProBalance + tu lista de pausa) y *Equilibrado* (solo ProBalance). Solo marcan opciones: nada se ejecuta hasta que actives la sesión.

## AUTOMATIZAR
- **Detección automática de juego (apagada por defecto):** con el interruptor maestro encendido, vigila tus juegos asociados (comprobación ligera cada 5 s) y activa/revierte el Modo Juego solo.
- **Juegos instalados detectados:** escanea Steam, Epic, GOG, Ubisoft, Xbox/Game Pass, Riot, EA, Battle.net y cualquier juego ya ejecutado (registro de Windows). Botón **Asociar** de un clic por juego.
- **Launchers detectados:** sus procesos de fondo son candidatos a la lista de pausa; nada viene marcado.

## MEDIR
- **Medición honesta:** con la edición de CONSOLA de PresentMon captura 60 s de frametimes a `logs\frametimes_<fecha>.csv` y te da media, p95 y p99. Si falta el binario, te lo dice claro y te lleva a las descargas oficiales.
- Botones para instalar **PresentMon / CapFrameX** vía winget (medición externa de confianza).

## Ejemplos prácticos
- **"Voy a jugar YA y no quiero configurar nada"**: pulsa **Optimizar para jugar (modo fácil)** — chequeo fresco, Game Mode revisado y ProBalance delegado si tienes Process Lasso. Un clic y a jugar.
- **"Quiero que el modo juego se active SOLO cuando abro mi shooter"**: en AUTOMATIZAR pulsa **Asociar** junto a tu juego detectado, elige el preset *Competitivo*, enciende el interruptor maestro… y olvídate: al abrir el juego se activa la sesión y al cerrarlo todo vuelve solo.
- **"Me va a tirones y no sé si es la red"**: en PREPARAR pulsa **Medir red (10 s)** — si el jitter y la pérdida salen bien, el problema no es tu conexión; pasa a MEDIR y captura 60 s de frametimes con PresentMon para ver los microtirones en datos reales (media, p95, p99).
- **"¿Qué me va a tocar exactamente si activo la sesión?"**: pulsa **Ver plan (sin tocar nada)**: te lista el plan de energía y cada proceso con su PID que se pausaría. Transparencia total antes de decidir.
- **"Se me fue la luz a mitad de sesión"**: reabre Winzard — detecta la sesión pendiente y te ofrece **Restaurar todo** para dejar el plan de energía y los procesos exactamente como estaban.

## Reglas de esta sección (por diseño)
Sin promesas de FPS · sin "liberadores de RAM" · sin planificador propio · sin afinidad automatizada de CPU · pausar significa suspender con el mecanismo nativo de Windows y reanudar SIEMPRE · todo reversible y anotado en el diario.

---

# 06 · Control de Windows Update

## Qué es
El centro de control de las actualizaciones: **tú decides cómo y cuándo se actualiza Windows**, mediante políticas reales del sistema. Cada acción se ejecuta al pulsar su botón, se verifica y queda anotada en el log forense. Nada es permanente: el botón de valores por defecto lo revierte todo. Requiere permisos de administrador.

## Las tarjetas (cada una con su botón "Aplicar")
| Acción | Qué hace | Riesgo |
|---|---|---|
| **Configuración recomendada (retrasar updates)** | Difiere las actualizaciones un margen prudente: recibes los parches con unos días de reposo, evitando estrenar fallos de Microsoft. | Seguro |
| **Pausar todas las actualizaciones 5 semanas** | Pausa completa temporal (el máximo que permite Windows por política). | Seguro |
| **Valores por defecto de Windows Update** | Borra cualquier política aplicada desde esta lista y devuelve Windows Update a su comportamiento de fábrica. | Seguro |
| **Desactivar Windows Update por completo** | Apaga el servicio y sus políticas. Pide confirmación con un aviso claro: dejar Windows sin parches de seguridad es arriesgado; úsalo solo si sabes lo que haces (equipos de laboratorio, VMs de prueba…). | Avanzado (borde rojo) |

## Enlaces rápidos
Botones que abren directamente las páginas relevantes de Configuración de Windows Update.

## Paso a paso típico
1. Pulsa **Aplicar** en "Configuración recomendada": es el punto dulce para la mayoría.
2. ¿Vas a jugar un fin de semana de lanzamiento o a un viaje? "Pausar 5 semanas".
3. ¿Quieres volver a como estaba todo? **Valores por defecto** y listo.

## Ejemplos prácticos
- **"Windows me actualizó a mitad de partida"**: aplica **Configuración recomendada** — los parches llegan igual, pero con unos días de reposo y sin pillarte por sorpresa.
- **"Me voy de viaje con el portátil y no quiero sustos"**: **Pausar 5 semanas** antes de salir; al volver, **Valores por defecto** y Windows se pone al día.
- **"Toqué algo hace meses y ahora no sé qué tengo"**: pulsa **Valores por defecto de Windows Update** — borra CUALQUIER política de esta lista y deja Windows Update de fábrica, sin que tengas que recordar qué aplicaste.
- **"Es una VM de pruebas y no quiero que se actualice nunca"**: **Desactivar por completo** (confirma el aviso rojo). Solo para equipos que de verdad no necesitan parches.

## Reversibilidad
Todas las acciones de esta sección se revierten con "Valores por defecto de Windows Update". Todo queda registrado en `logs\`.

---

# 07 · Quitar bloatware (Appx)

## Qué es
La limpieza de las **apps preinstaladas** de Windows (Xbox, noticias, mapas, ofertas…). Son paquetes Appx: quitarlos libera espacio y ruido, y **todos son reinstalables desde la Microsoft Store**.

## Cómo se lee la lista
- **Interruptor encendido + verde** = esa app YA está quitada de tu PC (estado real detectado).
- **Interruptor apagado** = sigue instalada.
- El botón **QUITAR (n)** cuenta solo lo accionable: lo marcado que además sigue instalado. Nunca actúa dos veces sobre lo ya quitado.

## Botón a botón
| Botón | Qué hace |
|---|---|
| **Marcar recomendado** | Marca el conjunto seguro típico (promociones, juegos ocasionales, noticias…). |
| **Marcar todo / Desmarcar** | Selección rápida de toda la lista / limpiarla. |
| **QUITAR (n)** | Desinstala los paquetes marcados e instalados, con registro en vivo. |
| **Restaurar** | Reinstala lo recuperable (vía Store/Provisioned) de lo que quitaste. |
| **Guardar / Cargar perfil** | Guarda tu selección de debloat con el estado real, o carga una guardada. |

## Paso a paso típico
1. Pulsa **Marcar recomendado** y repasa la lista (cada entrada tiene su descripción).
2. Pulsa **QUITAR (n)** y confirma.
3. ¿Echas algo de menos? Búscalo en la Microsoft Store y reinstálalo, o usa **Restaurar**.

## Ejemplos prácticos
- **"PC nuevo lleno de morralla"**: **Marcar recomendado** → **QUITAR (n)** → confirma. Dos clics y fuera promociones, noticias y juegos de relleno; todo reinstalable.
- **"Quité la Grabadora y ahora la necesito"**: pulsa **Restaurar** (o búscala en la Microsoft Store): vuelve en segundos.
- **"Quiero dejar igual el PC de mi hermano"**: en tu PC, **Guardar perfil**; en el suyo, **Cargar perfil** → QUITAR. Misma limpieza exacta en los dos.
- **"Soy gamer, ¿quito lo de Xbox?"**: si usas Game Bar o Game Pass, NO marques el grupo Xbox (la lista te lo describe); si no juegas desde la Store, márcalo sin miedo — reinstalable como todo.

## Seguridad
- Nada viene marcado de fábrica.
- No se tocan componentes del sistema: solo apps Appx de usuario reinstalables.
- Todo queda en el diario de cambios y en el log forense.

---

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

---

# 09 · Características de Windows

## Qué es
El gestor de las **características opcionales** de Windows (Hyper-V, Subsistema de Linux, .NET 3.5, Sandbox, SMB…), con el estado real de cada una detectado en tu equipo.

## Cómo funciona
- Cada característica muestra su estado actual (habilitada / deshabilitada) leído de verdad con DISM.
- Botones **Habilitar** y **Deshabilitar** por característica: son **acciones puntuales con confirmación y verificación** (por diseño, esta sección usa botones y no interruptores: cada cambio puede requerir reinicio y conviene confirmarlo de uno en uno).
- Tras cada acción, el panel **re-escanea** y te enseña el estado real resultante.

## Paso a paso típico
1. Localiza la característica (o llega desde "Buscar en todo").
2. Pulsa **Habilitar** o **Deshabilitar** y confirma.
3. Si Windows pide reinicio, el panel te lo dirá con claridad.

## Ejemplos prácticos
- **"Quiero probar Linux sin salir de Windows"**: habilita **Subsistema de Windows para Linux (WSL)** → reinicia si te lo pide → instala una distro desde la Store.
- **"Necesito una máquina virtual rápida"**: habilita **Hyper-V** (requiere Windows Pro) o **Windows Sandbox** para probar programas sin ensuciar tu equipo.
- **"Un programa antiguo pide .NET 3.5"**: habilítalo aquí y listo — sin buscar instaladores raros por internet.
- **"¿Qué tengo activado realmente?"**: entra y mira: el estado de cada característica está leído de tu Windows con DISM, no supuesto.

## Seguridad
- No hay cambios en lote: cada característica se toca individualmente y verificada.
- Deshabilitar una característica no borra datos: se puede volver a habilitar cuando quieras.

---

# 10 · Drivers y hardware

## Qué es
La sección para tener los **drivers al día y con copia de seguridad**, con detección de tu GPU y recomendaciones según tu hardware.

## Botón a botón
| Elemento | Qué hace |
|---|---|
| **GPU detectada + su app oficial** | Detecta tu tarjeta gráfica y te ofrece el botón correcto: **NVIDIA App** (web oficial), **AMD Software: Adrenalin** (web oficial; AMD no distribuye por winget) o **Intel Driver & Support Assistant** (winget). |
| **Abrir web oficial de drivers** | Va a la página de descargas del fabricante detectado. |
| **Otros fabricantes** | Botones siempre disponibles para NVIDIA / AMD / Intel aunque la GPU no se identifique. |
| **Exportar drivers de este PC** | Copia todos los drivers instalados (.inf con sus carpetas) a la carpeta que elijas: tu red de seguridad antes de formatear y la materia prima para inyectarlos en una ISO. |
| **Recomendaciones por hardware** | Marca en el catálogo apps recomendadas según tu equipo (p. ej. utilidades del fabricante). |

## Relación con "Crear ISO"
La carpeta oficial **`Drivers`** del directorio de Winzard es la que el asistente de ISO usa para **inyectar drivers** en la imagen: exporta aquí los de tu PC y tu Windows recién instalado arrancará con red y chipset listos.

## Ejemplos prácticos
- **"Voy a formatear este fin de semana"**: **Exportar drivers de este PC** a un USB. Tras formatear, Windows tendrá red y chipset sin buscar nada — y si creas tu ISO con Winzard, inyéctalos y ni eso.
- **"No sé qué gráfica tengo"**: la sección te la detecta y te pone el botón EXACTO de su software oficial (NVIDIA App / Adrenalin / Intel DSA). Sin webs falsas de "driver boosters".
- **"El portátil de mi trabajo va raro tras un driver"**: descarga siempre del botón de la web oficial del fabricante; nada de terceros.

## Seguridad
- Descargar/instalar drivers siempre pasa por las webs o instaladores **oficiales** del fabricante.
- La exportación no cambia nada: solo copia.

---

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

---

# 12 · Clonar equipo / Snapshot

## Qué es
El **clonado lógico** de tu equipo en un archivo: exporta la lista COMPLETA de programas que winget reconoce en tu PC, en el **formato oficial de `winget import`** (compatible con cualquier herramienta estándar). Ideal para dejar dos máquinas iguales o recuperar tu software tras formatear, sin ir programa por programa.

## Botón a botón
| Botón | Qué hace |
|---|---|
| **Exportar TODO mi equipo a un archivo…** | Genera el archivo de exportación con todos tus programas reconocidos por winget. |
| **Importar un archivo e instalar todo…** | Lee un archivo de exportación y el motor de Winzard instala cada programa de una tacada, con paralelismo, reintentos automáticos y log forense. |
| **Crear catalogo.json editable** | Crea una plantilla del catálogo de apps para que lo personalices (añadir/quitar apps del catálogo de Winzard). |
| **Recargar catalogo.json** | Recarga tu catálogo personalizado (reinicia la app). |
| **Cargar catálogo remoto (URL https)** | Carga un catálogo publicado en una URL (por ejemplo, el de tu equipo o comunidad). |

## Paso a paso: mudanza a un PC nuevo
1. En el PC viejo: **Exportar TODO mi equipo** → guarda el archivo en un USB o nube.
2. En el PC nuevo: instala Winzard, pulsa **Importar un archivo e instalar todo** y elige el archivo.
3. Sigue el progreso en el registro en vivo; los fallos se reintentan al final y se reportan honestos.

## Más ejemplos prácticos
- **"Montamos 5 PCs iguales en la oficina"**: configura uno a mano, **Exportar TODO**, y en los otros cuatro **Importar e instalar todo**. Cafés mientras winget trabaja.
- **"Quiero mi propio catálogo para la familia"**: **Crear catalogo.json editable**, deja solo las apps que quieres que vean, publícalo en tu Drive/web y en cada casa **Cargar catálogo remoto (URL https)**.
- **"¿Y si el archivo lo generó otro programa?"**: mientras sea el formato estándar de `winget export`, Winzard lo importa igual (y viceversa: el suyo vale en cualquier herramienta estándar).

## Notas
- El archivo es JSON estándar de winget: también sirve con `winget import -i archivo.json` a mano.
- El "Paquete de rescate" (Entorno de recuperación) incluye esta exportación automáticamente.

---

# 13 · Crear ISO de Windows a medida (avanzado)

## Qué es
Un **asistente paso a paso** que convierte una ISO oficial de Windows en TU ISO: con tus apps, tus tweaks, tu debloat, tus drivers y la instalación desatendida ya integrados. El resultado instala Windows y lo deja como a ti te gusta, solo.

## Requisitos (paso 1)
- **Windows ADK** (aporta `oscdimg`, el ensamblador de la ISO): botón de descarga incluido.
- **DISM** (viene con Windows), permisos de **administrador** y varios GB de espacio libre.
- El botón **"Volver a revisar"** re-comprueba todo.

## Paso a paso (los 7 pasos del asistente)
1. **Requisitos**: revisa ADK, DISM, permisos y espacio.
2. **Origen**: elige la **ISO oficial** (botones para descargar Windows 10/11 de Microsoft), la carpeta de salida, el nombre de la ISO final y la carpeta de trabajo. Pulsa **Detectar ediciones** y elige UNA edición (mucho más rápido) o todas.
3. **Tweaks**: marca los ajustes que se aplicarán en el PRIMER ARRANQUE con el motor real de Winzard (los seguros vienen marcados; ámbar = avanzado).
4. **Debloat**: marca el bloatware que se quita DE FÁBRICA (offline, antes de instalar). Todo reinstalable desde la Store.
5. **Apps**: marca las que se instalarán solas en el primer arranque (vía winget), por secciones. Botones **Usar mi selección de Apps**, **Marcar instaladas** y **Validar IDs**.
6. **Drivers**: si marcas "Inyectar drivers", los .inf de la carpeta elegida van DENTRO de la ISO (red/chipset listos al arrancar). Botones para usar la carpeta oficial `Drivers` o **exportar los drivers de tu PC actual**.
7. **Desatendida**: cuenta local sin pantallas de Microsoft (OOBE), **bypass de requisitos de Windows 11** (TPM/Secure Boot/CPU), idioma, nombre de usuario y contraseña. La instalación resultante es **100 % desatendida de verdad**: ni pantalla de clave de producto (lleva clave genérica de instalación; Windows se activa después con normalidad), ni región/teclado, ni una sola tecla desde que arranca la ISO hasta el escritorio. Si dejas la contraseña vacía, el resumen te lo avisa con claridad. ⚠️ **"Modo VM" FORMATEA el disco 0 sin preguntar: solo para máquina virtual o disco desechable.**

## Resumen final y creación
- El **RESUMEN DE TU ISO A MEDIDA** lista todo lo elegido antes de confirmar.
- **Confirmar y CREAR la ISO**: lanza el proceso en una consola de administrador (15-30 min con una edición).
- **Comprobar la ISO** (recomendado): monta la ISO creada y verifica que lleva C:\WPI, autounattend, ediciones, drivers y winget.
- **Abrir Rufus**: para grabar la ISO a un USB (esquema GPT, destino UEFI). ⚠️ En la pantalla "Experiencia de usuario de Windows" de Rufus **no marques NINGUNA casilla**: Winzard ya lo hace todo y las casillas de Rufus sobreescribirían tu configuración.
- **Generar kit (opcional)**: carpeta `WPI_ISO_Kit` con la configuración, el autounattend y los scripts, por si quieres revisarlos antes.

## Ejemplos prácticos
- **"El PC familiar, listo sin que yo esté delante"**: ISO oficial + edición Home + tus tweaks seguros + debloat recomendado + Brave/VLC/WhatsApp en Apps → grabar con Rufus → arrancar el PC → volver en una hora: Windows instalado, limpio, con sus programas y su punto de restauración. **Cero preguntas en pantalla.**
- **"Quiero probar mi ISO sin quemar un USB"**: marca **Modo VM** (solo para máquina virtual), crea la ISO y arráncala en VirtualBox/Hyper-V: verás el ciclo completo, incluido el primer arranque instalando las apps una a una.
- **"Técnico de tienda: 10 equipos distintos"**: exporta los drivers de cada modelo a su carpeta (manual 10), crea una ISO base con tus apps estándar e inyecta los drivers del modelo en el paso 6. Cada equipo arranca con red y chipset listos.
- **"¿Qué eligió exactamente mi compañero?"**: abre su `WPI_ISO_Kit\kit-config.json` (Generar kit): ahí está todo — edición, tweaks, debloat, apps, credenciales del desatendido.

## El primer arranque, en detalle
- Las apps se instalan **una a una, con el escritorio limpio** (cada instalador se cierra solo) y con **vigilante anticuelgues**: si winget se queda clavado con una app, se corta con aviso y se sigue con la siguiente.
- Si alguna app cae por un **corte de red**, el motor espera a que vuelva la conexión y **reintenta solo esas** automáticamente.
- Las apps problemáticas (p. ej. Discord) se **difieren al primer inicio de sesión** y se instalan solas mediante una **tarea elevada: sin ningún aviso de UAC**.
- Al terminar tienes en el Escritorio el **Informe del primer arranque (HTML)** y, si algo falló, **`Reintentar_apps_fallidas.cmd`**: doble clic y reintenta **también sin avisos de UAC**.
- Se crea un **punto de restauración "Recién instalado"** y el equipo se reinicia solo para integrarlo todo.

## Qué lleva el Windows resultante
Cuenta local lista · instalación sin una sola tecla · tus tweaks aplicados en el primer arranque · bloatware fuera de fábrica · tus apps instalándose solas (con anticuelgues y reintento de red) · drivers integrados · la **Suite de reparación** en `C:\WPI_Suite` · informe HTML + punto de restauración inicial · todo registrado.

---

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

---

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

