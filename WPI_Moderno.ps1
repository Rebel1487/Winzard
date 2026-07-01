# ============================================================
# WPI MODERNO v3.5 "OBRA MAESTRA" - Post-instalador de Windows
# GUI WPF de nueva generacion + motor winget asincrono.
#
# USO:
#   Iniciar_WPI.bat                   -> interfaz grafica
#   Iniciar_WPI.bat -Preset lista.txt -> instala el preset sin GUI
#   Iniciar_WPI.bat -Tweaks recommended  -> aplica tweaks seguros sin GUI
#   Iniciar_WPI.bat -Debloat all         -> quita el bloatware sin GUI
#   Iniciar_WPI.bat -Update all          -> winget upgrade --all sin GUI
#   Iniciar_WPI.bat -Profile perfil.json -> aplica un PERFIL MAESTRO completo
#   Iniciar_WPI.bat -Profile perfil.json -DryRun -> muestra el PLAN sin aplicar
#   (se pueden combinar: -Preset l.txt -Tweaks recommended -Debloat all)
#
# NOVEDADES v6.9 "FIX ISO OOBE + COMBOS LEGIBLES + CARPETAS + GUIAS":
#  - ISO: los tweaks van a preset_tweaks.txt; el autounattend pasa solo la RUTA
#    (-Tweaks "C:\WPI\preset_tweaks.txt"). Elimina el fallo de OOBE 0x8030000C
#    por <CommandLine> >1024 chars y comillas en los nombres. Split-CliTokens lee
#    rutas; match exacto de tweaks. Escape de comillas/apostrofes en cuenta/pass.
#  - Combos Tema/Idioma: el ToggleButton ahora recibe Background/BorderBrush del
#    ComboBox (antes salia gris ilegible cerrado en los 3 temas).
#  - Carpetas organizadas: Get-WpiDir -> Descargas\, Drivers\, ISO\.
#  - Paso "Origen": botones de descarga oficial de Windows (Microsoft).
#  - Paso "Resumen": guia rapida VM/Rufus (ES/EN) + aviso Modo VM borra disco 0.
#  - Primer arranque deja C:\WPI\primer_arranque_OK.txt (diagnostico).
#
# NOVEDADES v6.8 "ROBUSTEZ ISO + AVISOS EN INGLES + FIXES":
#  - ISO 100% instalable: autounattend.xml lleva ya <Password> en la cuenta local
#    y en AutoLogon (causa del error "Windows no puede completar la instalacion" en
#    el OOBE de Win11). Contrasena opcional real de punta a punta (campo en el paso
#    Desatendido). Ademas el NOMBRE de cuenta se escapa en XML (un '&'/'<'/'>' ya no
#    rompe la imagen). Validacion: ISO salida != origen y aviso si hay <25 GB libres.
#  - Avisos (MessageBox) traducibles: nuevo envoltorio Show-WpiMessage que pasa
#    texto y titulo por Tr; 91 avisos migrados (estaticos y dinamicos -f). Ademas
#    se traducen tooltips, la barra de estado y el CATALOGO (categorias, nombres y
#    descripciones de tweaks/debloat/caracteristicas + "evitalo si"). En English la
#    interfaz queda practicamente entera en ingles (diccionario ~290 entradas).
#  - Robustez (P4): fallback de $PSScriptRoot si se ejecuta sin el .bat; el mutex de
#    instancia unica se libera al cerrar; "Marcar visibles" usa busqueda de ancestro
#    (VisualTreeHelper) en vez de .Parent.Parent.Parent fragil; ajustes corruptos no
#    bloquean (copia .corrupt.bak + aviso suave); limpieza de temporales del worker
#    en finally; el parametro -Profile pasa a -ProfilePath (ya no sombrea $Profile).
#
# NOVEDADES v6.7 "CREAR ISO: apps por seccion + crear .inf de drivers":
#  - Paso de Apps del asistente de ISO: ahora las apps salen DIVIDIDAS POR SECCION
#    (Navegadores, Multimedia, Desarrollo, etc.) con su cabecera, igual que el
#    catalogo, para diferenciar mejor la seleccion. El buscador filtra y oculta las
#    secciones sin coincidencias.
#  - Paso de Drivers: ademas de elegir una carpeta con .inf, si NO tienes una, un
#    boton "crear copia (.inf) de mis drivers actuales" exporta tus drivers
#    instalados (Export-WindowsDriver) en una consola elevada con progreso y deja
#    esa carpeta ya puesta para inyectarla.
#  - Aclaracion: NO hace falta "Generar kit" antes de crear la ISO; "Confirmar y
#    CREAR la ISO" prepara el kit solo. "Generar kit" es opcional.
#
# NOVEDADES v6.6 "INGLES EN TODA LA INTERFAZ + desplegables legibles":
#  - Traductor por recorrido del arbol (Translate-Tree + Tr + diccionario ES->EN):
#    al elegir English se traduce TODA la interfaz visible (bloques, entradas,
#    titulos y descripciones de cada panel, botones, asistente ISO, modo facil,
#    buscador, visor de logs) y los contadores dinamicos (INSTALL (N), Selected: N).
#    Se aplica a la ventana y a cada panel al abrirse. Cambiar idioma reinicia.
#  - Desplegables (tema/idioma): cada opcion tiene fondo y texto propios, legible
#    de serie en los 3 temas (antes salian casi en blanco sin pasar el raton).
#
# NOVEDADES v6.5 "IDIOMA ES/EN (C2) + SENSORES (C5) + fixes de legibilidad":
#  - Legibilidad: el TEXTO de los botones se lee SIEMPRE de serie en los 3 temas
#    (los botones cian/ambar del claro ya no salen blanco sobre blanco); el hover
#    solo anade enfasis. El desplegable de tema en oscuro/azul ahora muestra cada
#    opcion legible (estilo de ComboBoxItem con texto oscuro + resaltado).
#  - C2 idioma: selector Espanol/English en la cabecera. Traduce la navegacion,
#    cabeceras, descripciones de tweaks/debloat/features, datos de hardware,
#    dialogos, ISO Creator y guias (via TrMap + Get-GuideUiText). Solo los
#    nombres propios de apps del catalogo se mantienen. Se aplica al reiniciar.
#  - C5 sensores: en "Drivers y hardware" se anade "Sensores y temperaturas"
#    (zona termica ACPI, temperatura de discos SMART, bateria) con aviso de usar
#    HWiNFO/HWMonitor para sensores completos.
#
# NOVEDADES v6.4 "MODO FACIL (C3) + BUSCAR EN TODO (C4) + aviso Fallback Choco":
#  - Nuevo bloque "INICIO" (es la pantalla de bienvenida): "Inicio rapido (modo
#    facil)" guia en 2 clics (instalar, optimizar, limpiar, reparar, crear ISO,
#    resumen); la barra izquierda sigue siendo el modo experto.
#  - "Buscar en todo (global)": encuentra cualquier app, tweak, bloatware o
#    caracteristica y salta a su seccion con un clic (para apps, ademas filtra).
#  - "Fallback Choco": al activarlo sale un mensaje claro de QUE hace y que pasara
#    (reintenta con Chocolatey si winget falla; avisa si choco no esta instalado).
#
# NOVEDADES v6.3 "VISOR DE LOGS (Fase C - C6) + verificacion total":
#  - Nuevo panel "Visor de logs" (@LOGVIEWER, bloque INFORMACION): desplegable con
#    los .log de la carpeta logs (mas reciente primero), muestra las ultimas lineas
#    del seleccionado, con "Refrescar" y "Abrir carpeta de logs".
#  - Verificacion integral: smoke-test que construye TODOS los paneles + los 8 pasos
#    del asistente ISO sin un solo error de runtime; carga completa sin errores de
#    wiring/null; XAML valido en los 3 temas; 39 detectores; lockstep 16==16.
#
# NOVEDADES v6.2 "TEMA CLARO MAS SUAVE Y BONITO + botones con color":
#  - Paleta clara rehecha: fondos mas suaves (gris-azulado claro), texto oscuro
#    suave (no negro puro) y acentos menos chillones.
#  - Los BOTONES vuelven a tener color solido (texto blanco) como en los demas
#    temas, cada uno con su intencion: instalar azul, desinstalar rojo, validar
#    violeta, actualizar verde, crear ISO naranja, etc. Bordes a juego.
#  - El desplegable de tema en violeta para que destaque; casillas con hover claro.
#
# NOVEDADES v6.1 "SELECTOR DE TEMA + HOVER + BARRA INFERIOR":
#  - El tema se elige con un DESPLEGABLE (ComboBox) en la cabecera, con color
#    propio (violeta) para que destaque: Oscuro / Claro / Azul (Chris Titus).
#  - Casillas (apps, debloat, tweaks, features, ISO) con HOVER claro: al pasar el
#    raton se resaltan con fondo + borde de acento y la letra cambia de color
#    (muy visible en tema claro). Indicador de marcado tipo cuadro relleno.
#  - Barra inferior reorganizada en 2 filas con los botones en panel que se ajusta
#    (WrapPanel): ya no se "comen"/cortan los botones junto a Fallback.
#
# NOVEDADES v6.0 "3 TEMAS (Oscuro / Claro / Azul Chris Titus) + legibilidad":
#  - Tres temas: Oscuro (base), Claro y AZUL estilo Chris Titus (navy con acentos
#    azules). Boton "Tema" SIEMPRE visible arriba a la izquierda (bajo el logo) que
#    CICLA Oscuro -> Claro -> Azul; tambien en Resumen (APARIENCIA). Se guarda en
#    wpi_settings.json y se aplica al reiniciar.
#  - Arreglos de legibilidad del tema claro: los textos de botones, casillas y
#    barra lateral ya no quedan en blanco (los 'White' fijos se mapean al color del
#    tema). El hover ya no "borra" las letras.
#  - La ventana se ajusta al area de trabajo de la pantalla al abrir, para que NUNCA
#    se corten los botones de abajo en pantallas pequenas o con escalado alto.
#
# NOVEDADES v5.9 "TEMA CLARO / OSCURO (Fase C - C1)":
#  - Tema visual conmutable. La paleta OSCURA sigue siendo la base (por defecto,
#    comportamiento identico). El tema CLARO se obtiene mapeando cada color a su
#    equivalente claro, tanto en el XAML (antes de cargarlo) como en el codigo
#    (Get-ThemeBrush sustituye a $bc.ConvertFromString en toda la GUI).
#  - Boton "Cambiar a tema claro/oscuro" en Resumen del sistema (APARIENCIA). La
#    eleccion se guarda en wpi_settings.json (Theme) y se aplica al reiniciar.
#
# NOVEDADES v5.8 "ASISTENTE ISO: VALIDACION POR PASOS":
#  - El asistente de creacion de ISO ahora NO deja pasar al siguiente paso si
#    falta algo imprescindible: muestra un aviso con el MOTIVO claro y te
#    mantiene en el paso. Validaciones: ISO origen (existe, es archivo y es .iso),
#    carpeta de salida (valida o creable), indice de edicion (numerico), carpeta
#    de drivers si marcas inyectar (existe y con .inf -> aviso si no hay), y
#    nombre de cuenta no vacio. En "Requisitos" avisa si falta Windows ADK.
#  - "Atras" siempre funciona y NO pierde lo elegido (guardado sin validar).
#
# NOVEDADES v5.7 "ASISTENTE DE CREACION DE ISO (paso a paso)":
#  - El apartado "Crear ISO" pasa a ser un ASISTENTE guiado de 8 pasos con
#    navegacion Atras/Siguiente y confirmacion final. Cada paso muestra la
#    seleccion real en HORIZONTAL (mas opciones en menos espacio):
#    1 Requisitos · 2 Origen y salida · 3 Tweaks (rejilla de checkboxes, se
#    aplican en el primer arranque con el motor real -Tweaks) · 4 Bloatware
#    (rejilla, se quita offline) · 5 Apps (rejilla con buscador y "usar mi
#    seleccion de Apps", se instalan en el primer arranque) · 6 Drivers ·
#    7 Desatendido · 8 Resumen y confirmacion ("Confirmar y CREAR la ISO").
#  - Se puede volver atras en cualquier paso sin perder lo elegido (el estado
#    se guarda en $script:Wiz). Botones "Marcar recomendados/todos" y "Quitar
#    todos" en tweaks y debloat.
#  - Mapeo fiel: debloat -> offline (Appx aprovisionadas); tweaks + apps ->
#    primer arranque via autounattend -> Iniciar_WPI.bat -Tweaks "..." -Preset.
#    Se aclara que es el "kit" en el paso final.
#
# NOVEDADES v5.6 "CREADOR DE ISO A MEDIDA (estrella del WPI)":
#  - Nuevo apartado "Crear ISO de Windows (avanzado)" (panel @CREATEISO, bloque
#    propio "CREAR ISO" con acento naranja). Flujo guiado y numerado (1-6) para
#    construir una ISO de Windows personalizada: drivers inyectados, debloat y
#    tweaks aplicados OFFLINE sobre la imagen, WPI + preset de apps para el primer
#    arranque, e instalacion DESATENDIDA opcional (autounattend.xml) con cuenta
#    local, saltar OOBE, bypass de requisitos de Windows 11 y "modo VM" (particiona
#    el disco para pruebas en maquina virtual).
#  - Arquitectura segura: la GUI solo DETECTA requisitos (oscdimg/ADK, DISM, disco)
#    y GENERA un "kit" (carpeta WPI_ISO_Kit con kit-config.json, autounattend.xml,
#    Crear_ISO_WPI.ps1, preset_apps.txt, copia de WPI y guias GUIA_ISO/GUIA_VM).
#    El trabajo pesado (montar install.wim, DISM /Add-Driver, quitar Appx
#    aprovisionadas, reg load offline, oscdimg) lo hace el script generado, que TU
#    lanzas como administrador en su propia consola y deja log. No toca tu Windows.
#  - Guia paso a paso integrada y guia para probar la ISO en maquina virtual
#    (Hyper-V / VirtualBox / VMware), ambas exportables. Boton "Instalar Windows
#    ADK" (winget Microsoft.WindowsADK) si falta oscdimg.
#  - Cambio aditivo: panel nuevo con la regla de siempre (SideMap+Items en lockstep
#    15==15, ScrollViewer, FindName, caso en Apply-Filter, builder). El motor de
#    instalacion de apps NO se toca.
#
# NOVEDADES v5.5 "CATALOGO VIVO 350+ (Fase B - B5)":
#  - $catalog ampliado a 362 apps curadas (todas con ID de winget validado en
#    bloque junio 2026). Nuevas categorias: Seguridad, Productividad, Discos y
#    Backup, Nube y Sync; y ampliacion fuerte de Desarrollo/CLI, Multimedia,
#    Utilidades, Oficina, Gaming y Comunicacion.
#  - Categorias plegables: cada categoria del panel de apps es ahora un Expander
#    (desplegado por defecto). Al buscar, las categorias con coincidencias se
#    auto-despliegan para que veas el resultado sin clicar.
#  - Catalogo VIVO: nuevo boton "Cargar catalogo remoto (URL https)" (en Snapshot)
#    que descarga un catalogo.json desde una URL https, lo valida (Cat/Name/Id),
#    lo guarda junto al script y reinicia. Sigue existiendo "Validar IDs" para
#    comprobar cada entrada contra winget. Cambio aditivo: el motor no se toca.
#
# NOVEDADES v5.4 "FALLBACKS DE INSTALACION (Fase B - B4)":
#  - Selector de AMBITO (--scope) en la barra: Auto (por defecto, sin --scope) /
#    Este usuario (--scope user) / Todo el equipo (--scope machine).
#  - Fallback a Chocolatey OPT-IN ("Fallback Choco"): si winget falla al instalar
#    una app y Chocolatey esta instalado, se reintenta con choco (best-effort, el
#    metodo queda en el log). Por defecto desactivado -> el motor se comporta
#    EXACTAMENTE igual que antes (cambio aditivo, sin tocar el flujo por defecto).
#
# NOVEDADES v7.4 "INGLES COMPLETO + EMULADORES ORGANIZADOS + WPI ACCESIBLE":
#  - Modo Ingles ahora 100%: titulo de ventana, version del lateral, combo de
#    tema, estadisticas, seccion de updates (grupos), descripciones de TODAS las
#    secciones y textos dinamicos (-f) traducidos. Se arreglo el titulo de las
#    tarjetas (el prefijo numerico rompia el match del traductor por arbol).
#  - Emuladores subdivididos por marca dentro de su propia seccion: Multi-sistema,
#    Nintendo, PlayStation y Xbox y PC (subcabeceras; sin ensuciar el lateral).
#    El panel de categorias soporta ahora un campo 'Sub' generico y reutilizable.
#  - Carpeta WPI VISIBLE en la raiz de la ISO/USB (con LEEME.txt) para abrir el
#    WPI facilmente desde el USB cuando se quiera, ademas de la copia en C:\WPI.
#  - Primer arranque: accesos directos del WPI (lanzador + carpeta) en el
#    Escritorio del usuario y el Publico, antes del reinicio. Si se borra C:\WPI
#    o el log, siempre se puede volver al USB y abrir la misma carpeta.
#  - Log mas limpio: el borrado de la clave Run de OneDrive consulta antes de
#    borrar; powercfg/schtasks ya no filtran stderr al transcript del log.
#
# NOVEDADES v5.3 "BACKUP/RESTORE DE DRIVERS (Fase B - B3)":
#  - En "Drivers y hardware", subseccion "COPIA DE SEGURIDAD DE DRIVERS":
#    "Hacer copia de drivers" (Export-WindowsDriver -Online a una carpeta que
#    elijas; solo lectura del sistema) y "Restaurar drivers desde carpeta"
#    (pnputil /add-driver *.inf /subdirs /install, para un equipo recien
#    reinstalado). Ambas corren por el motor con log; eleccion de carpeta con
#    FolderBrowserDialog. Joya post-formateo.
#
# NOVEDADES v5.2 "DEBLOAT AMPLIADO (Fase B - B2)":
#  - $DebloatCatalog ampliado con mas Appx curadas (Movies&TV, Groove, Visor 3D,
#    Office Hub, Dev Home, Whiteboard, Journal, LinkedIn, Widgets), reinstalables
#    desde la Store. La deteccion (usuario + provisioned) ya las cubre.
#  - Accion especial reversible "Quitar OneDrive" en el panel debloat: usa el
#    desinstalador propio de OneDrive (no Appx), por el motor con log; reinstalable
#    con winget Microsoft.OneDrive. Copilot/Cortana ya estan en el catalogo y
#    Recall se gestiona en Tweaks/Caracteristicas. Edge se excluye a proposito
#    (su eliminacion no es segura ni limpia de revertir).
#
# NOVEDADES v5.1 "CARACTERISTICAS DE WINDOWS (Fase B - B1)":
#  - Nuevo panel "Caracteristicas de Windows" (@FEATURES, bloque MANTENER):
#    catalogo $FeaturesCatalog de caracteristicas opcionales (feature, DISM
#    *-WindowsOptionalFeature) y capabilities (capability, DISM *-WindowsCapability):
#    .NET 3.5, Telnet, XPS, Hyper-V, WSL, VM Platform, Sandbox, WordPad, OpenSSH...
#  - Deteccion de estado solo lectura (Get-WindowsOptionalFeature/Capability):
#    HABILITADO / deshabilitado / no presente, con contador.
#  - Acciones reversibles por el motor: Habilitar/Deshabilitar (Enable/Disable y
#    Add/Remove). Aviso de las que piden reinicio.
#
# NOVEDADES v5.0 "ANTES/DESPUES (cierra Fase A)":
#  - A5: comparativa antes/despues. Get-WpiSnapshotMetrics (solo lectura:
#    arranque, servicios en ejecucion, procesos, RAM en uso, apps de inicio).
#    Botones "Tomar foto del sistema" (guarda wpi_baseline.json) y "Comparar con
#    la foto" (muestra el delta) en Resumen del sistema. La comparativa tambien
#    se incluye en el diagnostico exportable. Con esto la FASE A queda completa.
#
# NOVEDADES v4.9 "RECOMENDADO PARA MI EQUIPO":
#  - A4: deteccion de contexto (Get-WpiContext: portatil/SSD/RAM/edicion/GPU) y
#    boton "Aplicar recomendado para MI equipo" en Tweaks: marca el set 'Seguro'
#    adaptado al equipo (en portatil excluye apagar hibernacion y plan Maximo
#    Rendimiento). NO aplica solo: marca, y el usuario revisa y pulsa APLICAR.
#
# NOVEDADES v4.8 "REPARACION UNIFICADA + UI":
#  - Seccion unica "Reparacion" (@REPAIR, bloque MANTENER) que reune TODO: la
#    SUITE en 17 fases (00-16, motor externo) con la 00 siempre, mas las
#    herramientas rapidas de un clic (SFC/DISM/red/WU/winget), O&O y paneles.
#    Se elimina la entrada duplicada "Reparar y herramientas".
#  - La suite lanza Suite_Reparacion_TodoEnUno.bat como administrador en su
#    propia consola (/auto /noreboot [/fases:NN,NN]); el WPI solo selecciona y
#    lanza. Si el .bat no esta junto al WPI, avisa. No reinicia solo (/noreboot).
#  - El .bat muestra cada fase como "NN - Nombre" en el menu y en "Fases
#    seleccionadas" (antes solo el numero).
#  - UI: cabeceras de grupo del lateral con RELIEVE (fondo + barra de acento) para
#    ver claramente el cambio de seccion; INFORMACION ahora en violeta propio.
#
# NOVEDADES v4.6 "GUI PREMIUM":
#  - Barra lateral agrupada en bloques con cabecera de color por intencion:
#    INSTALAR (azul), OPTIMIZAR (cian), LIMPIAR (ambar), MANTENER (verde),
#    INFORMACION (neutro). Las cabeceras no son seleccionables (lockstep intacto).
#  - Paleta central $Theme (base para el futuro tema claro/oscuro).
#  - Distincion clara de acciones fuertes: Debloat (rojo) y Reparar (ambar)
#    marcados como "ACCION FUERTE" para no confundirlos con Tweaks/Resumen.
#  - Solo capa visual: no cambia el motor ni la funcionalidad.
#
# NOVEDADES v4.5 "CAVEATS":
#  - "Cuando NO usarlo" por tweak: clave opcional Caveat= en los tweaks que lo
#    necesitan (hibernacion, indexacion, Game Bar, inicio rapido, plan de energia,
#    aceleracion del raton, pantalla de bloqueo, efectos visuales). Se pinta una
#    linea ambar "Evitalo si: ..." en la tarjeta y se refleja en el plan (dry-run).
#
# NOVEDADES v4.4 "VER PLAN / DRY-RUN":
#  - DRY-RUN del perfil maestro: -Profile x.json -DryRun lista en consola que
#    se haria (debloat/tweaks/update/apps) SIN ejecutar ni cambiar nada.
#  - GUI: boton "Ver plan del perfil" (ventana desplazable, solo lectura) y
#    "Aplicar perfil completo" ahora muestra el plan -> confirmar -> aplicar.
#    El plan se puede exportar a .txt/.md.
#  - Pulido A1: Export-MasterProfile fuerza la deteccion de tweaks y debloat
#    aunque no se hayan abierto esos paneles (perfil completo y correcto).
#
# NOVEDADES v4.3 "PERFIL MAESTRO":
#  - PERFIL MAESTRO UNIFICADO (wpi-master-profile-1.0): un solo JSON con
#    apps + tweaks + debloat + update. Boton "Exportar perfil maestro" (captura
#    el estado actual) y "Aplicar perfil completo" en el panel Resumen.
#  - "Aplicar perfil completo" valida el $schema, crea punto de restauracion y
#    relanza el WPI como administrador en modo desatendido (-Profile).
#  - CLI: -Profile perfil.json orquesta debloat -> tweaks -> update -> apps
#    reutilizando el mismo Code de cada accion. Punto de restauracion robusto
#    (si falla por estar desactivado o el limite 24h, avisa y continua).
#
# NOVEDADES v4.1 "PRO":
#  - DETECTOR de estado de DEBLOAT: al entrar a "Quitar bloatware" marca
#    cada app como INSTALADA (ambar) o ya quitada (verde), con contador
#  - PERFILES de debloat: guardar/cargar en JSON portable + "marcar solo
#    las instaladas" para igualar varios equipos
#  - Barra de progreso con % REAL de la app en curso (modo seguro 1x),
#    con fallback al avance por apps/total si winget no reporta %
#  - +12 tweaks de alto consenso (Fast Startup, tema oscuro, Cortana,
#    ubicacion, apps en segundo plano, indexacion, etc.) con Undo+detector
#  - Modo desatendido total por CLI: -Tweaks / -Debloat / -Update,
#    combinables con -Preset, reutilizando el mismo Code de cada accion
#  - Tras aplicar tweaks/debloat se re-detecta el estado automaticamente
#
# NOVEDADES v4.0 "SUITE":
#  - Sistema de TWEAKS v2: categorias, nivel de riesgo y REVERTIR (undo)
#  - Punto de restauracion automatico antes de aplicar tweaks
#  - Panel CONTROL DE WINDOWS UPDATE (pausar, retrasar, reanudar, reset)
#  - Panel REPARAR Y HERRAMIENTAS (SFC/DISM, reset de red, reparar WU,
#    limpiar Store, reconstruir busqueda) + accesos a paneles clasicos
#  - Reparacion de winget en 1 clic + lanzar O&O ShutUp10++
#  - Progreso muestra la app en curso; auto-desmarca lo instalado OK
#  - Exportar el informe de hardware a archivo
#  - Ventana no se abre fuera de pantalla si cambia el monitor
#  - DETECTOR de estado de tweaks: al entrar a Tweaks marca cuales ya
#    estan aplicados en tu PC (verde) y cuales no, con recomendacion
#  - PERFILES de tweaks: guardar/cargar el estado en JSON portable y
#    "marcar lo recomendado que falta" para igualar equipos
#  - Paneles "Control de Windows Update" y "Reparar y herramientas"
#    completos (SFC/DISM, red, WU, Store, indice) + O&O ShutUp10++
#
# NOVEDADES v3.5:
#  - Deteccion de apps YA INSTALADAS (se marcan en verde al abrir)
#  - Boton DESINSTALAR masivo (mismo motor asincrono, en paralelo)
#  - WATCHDOG: mata instaladores colgados (timeout configurable)
#  - Selector de velocidad 1x/2x/3x en la propia barra (persistente)
#  - Ajustes persistentes en wpi_settings.json + preset "Ultima sesion"
#  - Exportar seleccion a JSON oficial de "winget import"
#  - Resumen final en ventana al terminar instalar/desinstalar
#
# NOVEDADES v3:
#  - Catalogo masivo (+200 apps) organizado en 13 categorias
#  - Sidebar de navegacion por categorias + buscador en vivo
#  - Instalacion ASINCRONA dentro de la ventana (la UI no se congela)
#  - Log forense en vivo con colores, codigos hex y archivo .log
#  - Paralelizacion configurable (1-3 instalaciones simultaneas)
#  - Presets rapidos de un clic: Gaming / Dev / Multimedia / Esencial
#  - Pestana de Tweaks & Debloat (telemetria, limpieza, energia...)
#  - Validador de IDs del catalogo contra el repositorio de winget
#  - Se mantiene: presets .txt, autoupdate de fuentes, self-update
# ============================================================
param(
    [string]$Preset,
    [string]$Tweaks,
    [string]$Debloat,
    [string]$Update,
    [string]$ProfilePath,
    [switch]$FirstBoot,
    [switch]$NoReboot,
    [switch]$DryRun,
    [switch]$SelfTestGui,
    [switch]$BuildIsoKit,
    [string]$IsoPath,
    [string]$IsoOutDir,
    [string]$IsoName = 'WPI_Custom.iso'
)

$ErrorActionPreference = 'Continue'
$WpiVersion = '7.4'

[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 'utf8NoBOM' solo existe en PowerShell 6+. En Windows PowerShell 5.1 hay que
# escribir sin BOM via .NET (ver Set-WpiContent); fijar 'utf8NoBOM' como default
# en 5.1 no sirve y -Encoding UTF8 anadiria BOM. Por eso el default solo se
# aplica en 6+, y todas las escrituras importantes usan Set-WpiContent.
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
    $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
}

# Escribe texto en UTF-8 de forma fiable en 5.1 y 6+/7.
#   -Bom  : con BOM. Necesario SOLO para ficheros .ps1 que contienen caracteres
#           no-ASCII y que Windows PowerShell 5.1 debe leer como UTF-8 (sin BOM
#           los leeria como ANSI y corromperia las tildes/simbolos). Para datos
#           (json, settings, txt) NO se usa BOM por interoperabilidad.
function Set-WpiContent {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [switch]$Bom
    )
    $enc = New-Object System.Text.UTF8Encoding($Bom.IsPresent)
    [System.IO.File]::WriteAllText($Path, $Value, $enc)
}

$script:Sep = [char]0x00B7
$script:SepText = ('  {0}  ' -f $script:Sep)
$script:MojibakeMiddleDot = ([string]([char]0x00C2) + [string]$script:Sep)
$script:MojibakeAltMiddleDot = ([string]([char]0x00C2) + [string]([char]0x02C7))
$script:MojibakeEllipsisA = ([string]([char]0x00E2) + [string]([char]0x20AC) + [string]([char]0x00A6))
$script:MojibakeEllipsisB = ([string]([char]0x00E2) + [string]([char]0x0080) + [string]([char]0x00A6))

function Repair-WpiText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    return $Text.Replace($script:MojibakeMiddleDot, [string]$script:Sep).Replace($script:MojibakeAltMiddleDot, [string]$script:Sep).Replace($script:MojibakeEllipsisA, '...').Replace($script:MojibakeEllipsisB, '...')
}

# Si se ejecuta el .ps1 directamente (sin el .bat), $PSScriptRoot puede venir
# vacio y romperia las rutas de $Config (logs, ajustes...). Fallback robusto.
if (-not $PSScriptRoot) {
    try { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path } catch {}
    if (-not $PSScriptRoot) { $PSScriptRoot = (Get-Location).Path }
}

# --- AUTO-ELEVACION: WPI SIEMPRE debe correr como Administrador ---
# Tweaks, debloat, Control de Windows Update y reparaciones tocan HKLM y
# servicios: sin admin fallan. El lanzador Iniciar_WPI.bat ya eleva, pero si se
# abre el .ps1 directamente (doble clic, acceso directo al .ps1) tambien debe
# elevarse. Si no es admin, se relanza elevado conservando los argumentos y se
# cierra esta instancia. NO se eleva en -SelfTestGui (prueba headless). Si el
# usuario cancela el UAC, se continua sin admin con el aviso de mas abajo.
if (-not $SelfTestGui) {
    $__isAdminBoot = $false
    try { $__isAdminBoot = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}
    if (-not $__isAdminBoot) {
        $__selfPath = $PSCommandPath
        if (-not $__selfPath) { try { $__selfPath = $MyInvocation.MyCommand.Path } catch {} }
        if ($__selfPath -and (Test-Path $__selfPath)) {
            $__argStr = '-NoProfile -ExecutionPolicy Bypass -STA -File "{0}"' -f $__selfPath
            foreach ($__kv in $PSBoundParameters.GetEnumerator()) {
                $__val = $__kv.Value
                if ($__val -is [System.Management.Automation.SwitchParameter]) {
                    if ($__val.IsPresent) { $__argStr += (' -{0}' -f $__kv.Key) }
                } else {
                    $__argStr += (' -{0} "{1}"' -f $__kv.Key, ([string]$__val))
                }
            }
            try {
                Start-Process -FilePath 'powershell.exe' -ArgumentList $__argStr -Verb RunAs | Out-Null
                exit 0
            } catch {}
        }
    }
}

# ===================== CONFIGURACION ========================
$Config = @{
    # Refrescar el catalogo/enlaces de winget cada vez que se abre
    AutoUpdateSources = $true
    # Ejecutar 'winget upgrade --all' automaticamente al abrir
    AutoUpgradeApps   = $false
    # URL del WPI_Moderno.ps1 mas reciente para autoactualizarse
    # (ej. un raw de GitHub). Vacio = desactivado.
    SelfUpdateUrl     = ''
    # Instalaciones simultaneas (1 = secuencial y 100% seguro).
    # 2-3 acelera mucho, pero dos instaladores MSI a la vez pueden
    # chocar (codigo 1618). El motor reintenta esos choques al final.
    ParallelInstalls  = 1
    # Detectar al abrir que apps del catalogo ya estan instaladas
    # (se marcan en verde; usa 'winget export', tarda unos segundos)
    AutoDetectInstalled = $true
    # WATCHDOG: minutos maximos por instalacion antes de matar al
    # instalador colgado y marcarlo como fallo (0 = sin limite)
    InstallTimeoutMin = 25
    # Carpeta de logs forenses (se crea junto al script)
    LogDir            = (Join-Path $PSScriptRoot 'logs')
    # Ajustes persistentes (velocidad, ultima seleccion...)
    SettingsFile      = (Join-Path $PSScriptRoot 'wpi_settings.json')
    # Carpeta por defecto para descargar instaladores (se crea al usarla)
    DownloadDir       = (Join-Path $PSScriptRoot 'Descargas')
}
if ($SelfTestGui -or $BuildIsoKit) {
    $Config.AutoUpdateSources = $false
    $Config.AutoUpgradeApps = $false
    $Config.AutoDetectInstalled = $false
}
# ============================================================

# Helper de carpetas de salida: crea (si hace falta) y devuelve <raiz WPI>\<sub>.
# Centraliza la estructura de salidas: Descargas, Drivers, ISO, logs.
function Get-WpiDir([string]$sub) {
    $p = Join-Path $PSScriptRoot $sub
    if (-not (Test-Path $p)) { try { New-Item -ItemType Directory -Path $p -Force | Out-Null } catch {} }
    return $p
}

# ===================== CATALOGO DE APPS =====================
# IDs unificados del repositorio oficial de winget.
# Busca/verifica IDs con:  winget search <nombre>
# o usa el boton [Validar IDs] de la propia interfaz, que comprueba
# cada entrada contra los servidores de winget.
$catalog = @(
    # ------------------ NAVEGADORES ------------------
    @{Cat='Navegadores';      Name='Brave';                  Id='Brave.Brave'}
    @{Cat='Navegadores';      Name='Chromium';               Id='Hibbiki.Chromium'}
    @{Cat='Navegadores';      Name='Firefox';                Id='Mozilla.Firefox'}
    @{Cat='Navegadores';      Name='Firefox ESR';            Id='Mozilla.Firefox.ESR'}
    @{Cat='Navegadores';      Name='Floorp';                 Id='Ablaze.Floorp'}
    @{Cat='Navegadores';      Name='Google Chrome';          Id='Google.Chrome'}
    @{Cat='Navegadores';      Name='Helium';                 Id='ImputNet.Helium'}
    @{Cat='Navegadores';      Name='LibreWolf';              Id='LibreWolf.LibreWolf'}
    @{Cat='Navegadores';      Name='Microsoft Edge';         Id='Microsoft.Edge'}
    @{Cat='Navegadores';      Name='Mullvad Browser';        Id='MullvadVPN.MullvadBrowser'}
    @{Cat='Navegadores';      Name='Tor Browser';            Id='TorProject.TorBrowser'}
    @{Cat='Navegadores';      Name='Vivaldi';                Id='Vivaldi.Vivaldi'}
    @{Cat='Navegadores';      Name='Waterfox';               Id='Waterfox.Waterfox'}
    @{Cat='Navegadores';      Name='Zen Browser';            Id='Zen-Team.Zen-Browser'}

    # ---------------- IMPRESCINDIBLES ----------------
    @{Cat='Imprescindibles';  Name='7-Zip';                  Id='7zip.7zip'}
    @{Cat='Imprescindibles';  Name='WinRAR';                 Id='RARLab.WinRAR'}
    @{Cat='Imprescindibles';  Name='Notepad++';              Id='Notepad++.Notepad++'}
    @{Cat='Imprescindibles';  Name='Everything (buscador)';  Id='voidtools.Everything'}
    @{Cat='Imprescindibles';  Name='PowerToys';              Id='Microsoft.PowerToys'}
    @{Cat='Imprescindibles';  Name='Rufus (USB booteable)';  Id='Rufus.Rufus'}

    # ------------- MULTIMEDIA Y DISENO ---------------
    @{Cat='Multimedia';       Name='AIMP (reproductor)';     Id='AIMP.AIMP'}
    @{Cat='Multimedia';       Name='Apollo (GameStream)';    Id='ClassicOldSong.Apollo'}
    @{Cat='Multimedia';       Name='Audacity';               Id='Audacity.Audacity'}
    @{Cat='Multimedia';       Name='AviSynth+';              Id='AviSynth.AviSynthPlus'}
    @{Cat='Multimedia';       Name='Blender (3D)';           Id='BlenderFoundation.Blender'}
    @{Cat='Multimedia';       Name='CapCut';                 Id='ByteDance.CapCut'}
    @{Cat='Multimedia';       Name='GIMP';                   Id='GIMP.GIMP'}
    @{Cat='Multimedia';       Name='HandBrake';              Id='HandBrake.HandBrake'}
    @{Cat='Multimedia';       Name='ImageGlass (visor)';     Id='DuongDieuPhap.ImageGlass'}
    @{Cat='Multimedia';       Name='IrfanView';              Id='IrfanSkiljan.IrfanView'}
    @{Cat='Multimedia';       Name='iTunes';                 Id='Apple.iTunes'}
    @{Cat='Multimedia';       Name='K-Lite Mega Codec Pack'; Id='CodecGuide.K-LiteCodecPack.Mega'}
    @{Cat='Multimedia';       Name='MakeMKV';                Id='GuinpinSoft.MakeMKV'}
    @{Cat='Multimedia';       Name='MKVToolNix';             Id='MoritzBunkus.MKVToolNix'}
    @{Cat='Multimedia';       Name='MPC-HC (clsid2)';        Id='clsid2.mpc-hc'}
    @{Cat='Multimedia';       Name='mpc-qt';                 Id='mpc-qt.mpc-qt'}
    @{Cat='Multimedia';       Name='OBS Studio';             Id='OBSProject.OBSStudio'}
    @{Cat='Multimedia';       Name='Paint.NET';              Id='dotPDN.PaintDotNet'}
    @{Cat='Multimedia';       Name='ShareX (capturas)';      Id='ShareX.ShareX'}
    @{Cat='Multimedia';       Name='Spotify';                Id='Spotify.Spotify'}
    @{Cat='Multimedia';       Name='VLC';                    Id='VideoLAN.VLC'}

    # -------------- GAMING Y STREAMING ---------------
    @{Cat='Gaming';           Name='Steam';                  Id='Valve.Steam'}
    @{Cat='Gaming';           Name='Discord';                Id='Discord.Discord'}
    @{Cat='Gaming';           Name='Epic Games Launcher';    Id='EpicGames.EpicGamesLauncher'}
    @{Cat='Gaming';           Name='Playnite';               Id='Playnite.Playnite'}
    @{Cat='Gaming';           Name='DLSS Swapper';           Id='beeradmoore.dlss-swapper'}
    @{Cat='Gaming';           Name='EA App';                 Id='ElectronicArts.EADesktop'}
    @{Cat='Gaming';           Name='GeForce NOW';            Id='Nvidia.GeForceNow'}
    @{Cat='Gaming';           Name='GOG Galaxy';             Id='GOG.Galaxy'}
    @{Cat='Gaming';           Name='Heroic Games Launcher';  Id='HeroicGamesLauncher.HeroicGamesLauncher'}
    @{Cat='Gaming';           Name='Itch.io';                Id='ItchIo.Itch'}
    @{Cat='Gaming';           Name='Modrinth App';           Id='Modrinth.ModrinthApp'}
    @{Cat='Gaming';           Name='Nvidia Profile Inspector'; Id='Orbmu2k.nvidiaProfileInspector'}
    @{Cat='Gaming';           Name='Prism Launcher';         Id='PrismLauncher.PrismLauncher'}
    @{Cat='Gaming';           Name='Sunshine (servidor)';    Id='LizardByte.Sunshine'}
    @{Cat='Gaming';           Name='Ubisoft Connect';        Id='Ubisoft.Connect'}
    @{Cat='Gaming';           Name='Virtual Desktop Streamer'; Id='VirtualDesktop.Streamer'}
    @{Cat='Gaming';           Name='Battle.net';             Id='Blizzard.BattleNet'}
    @{Cat='Gaming';           Name='DS4Windows (mandos PS)'; Id='Ryochan7.DS4Windows'}
    @{Cat='Gaming';           Name='ViGEmBus (driver mandos)'; Id='ViGEm.ViGEmBus'}
    @{Cat='Gaming';           Name='HidHide (ocultar mandos)'; Id='Nefarius.HidHide'}
    @{Cat='Gaming';           Name='Special K (SKIF)';       Id='SpecialK.SpecialK'}
    @{Cat='Gaming';           Name='MSI Afterburner';        Id='Guru3D.Afterburner'}
    @{Cat='Gaming';           Name='RivaTuner Statistics';   Id='Guru3D.RTSS'}
    @{Cat='Gaming';           Name='CapFrameX (benchmark)';  Id='CXWorld.CapFrameX'}

    # ----------------- EMULADORES --------------------
    # Los mejor valorados y mantenidos (junio 2026). Algunos IDs pueden
    # variar entre versiones de winget: usa [Validar IDs] tras anadir o
    # si alguno no instala. (yuzu/Citra/Ryujinx originales se cerraron;
    # se incluyen alternativas vivas y emuladores que siguen activos.)
    @{Cat='Emuladores'; Sub='Multi-sistema'; Name='RetroArch (multi-sistema)'; Id='Libretro.RetroArch'}
    @{Cat='Emuladores'; Sub='Multi-sistema'; Name='BizHawk (TAS/multi)';       Id='TASEmulators.BizHawk'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='Dolphin (GameCube/Wii)';    Id='DolphinEmulator.Dolphin'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='Cemu (Wii U)';              Id='Cemu.Cemu'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='Project64 (Nintendo 64)';   Id='Project64.Project64'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='Snes9x (Super Nintendo)';   Id='Snes9x.Snes9x'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='Mesen (NES/SNES/GB)';       Id='SourMesen.Mesen'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='mGBA (Game Boy Advance)';   Id='JeffreyPfau.mGBA'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='melonDS (Nintendo DS)';     Id='melonDS.melonDS'}
    @{Cat='Emuladores'; Sub='Nintendo';      Name='DeSmuME (Nintendo DS)';     Id='DeSmuMETeam.DeSmuME'}
    @{Cat='Emuladores'; Sub='PlayStation';   Name='DuckStation (PlayStation 1)'; Id='Stenzek.DuckStation'}
    @{Cat='Emuladores'; Sub='PlayStation';   Name='PCSX2 (PlayStation 2)';     Id='PCSX2Team.PCSX2'}
    @{Cat='Emuladores'; Sub='PlayStation';   Name='RPCS3 (PlayStation 3)';     Id='RPCS3.RPCS3'}
    @{Cat='Emuladores'; Sub='PlayStation';   Name='PPSSPP (PSP)';              Id='PPSSPPTeam.PPSSPP'}
    @{Cat='Emuladores'; Sub='PlayStation';   Name='Vita3K (PS Vita)';          Id='Vita3K.Vita3K'}
    @{Cat='Emuladores'; Sub='Xbox y PC';     Name='xemu (Xbox clasica)';       Id='xemu-project.xemu'}
    @{Cat='Emuladores'; Sub='Xbox y PC';     Name='ScummVM (aventuras)';       Id='ScummVM.ScummVM'}
    @{Cat='Emuladores'; Sub='Xbox y PC';     Name='DOSBox-X (MS-DOS)';         Id='joncampbell123.DOSBox-X'}

    # ------------- DESARROLLO Y TERMINAL -------------
    @{Cat='Desarrollo';       Name='Visual Studio Code';     Id='Microsoft.VisualStudioCode'}
    @{Cat='Desarrollo';       Name='VS Codium';              Id='VSCodium.VSCodium'}
    @{Cat='Desarrollo';       Name='Visual Studio 2022 Community'; Id='Microsoft.VisualStudio.2022.Community'}
    @{Cat='Desarrollo';       Name='Visual Studio 2022 Community'; Id='Microsoft.VisualStudio.2022.Community'}
    @{Cat='Desarrollo';       Name='Git';                    Id='Git.Git'}
    @{Cat='Desarrollo';       Name='GitHub Desktop';         Id='GitHub.GitHubDesktop'}
    @{Cat='Desarrollo';       Name='Lazygit';                Id='JesseDuffield.lazygit'}
    @{Cat='Desarrollo';       Name='Python 3.12';            Id='Python.Python.3.12'}
    @{Cat='Desarrollo';       Name='uv (gestor Python)';     Id='astral-sh.uv'}
    @{Cat='Desarrollo';       Name='Node.js LTS';            Id='OpenJS.NodeJS.LTS'}
    @{Cat='Desarrollo';       Name='Yarn';                   Id='Yarn.Yarn'}
    @{Cat='Desarrollo';       Name='Go';                     Id='GoLang.Go'}
    @{Cat='Desarrollo';       Name='Rust (rustup)';          Id='Rustlang.Rustup'}
    @{Cat='Desarrollo';       Name='Ruby 3.4';               Id='RubyInstallerTeam.Ruby.3.4'}
    @{Cat='Desarrollo';       Name='Lua';                    Id='DEVCOM.Lua'}
    @{Cat='Desarrollo';       Name='Amazon Corretto 8 (LTS)';  Id='Amazon.Corretto.8.JDK'}
    @{Cat='Desarrollo';       Name='Amazon Corretto 21 (LTS)'; Id='Amazon.Corretto.21.JDK'}
    @{Cat='Desarrollo';       Name='Amazon Corretto 25 (LTS)'; Id='Amazon.Corretto.25.JDK'}
    @{Cat='Desarrollo';       Name='CMake';                  Id='Kitware.CMake'}
    @{Cat='Desarrollo';       Name='Windows Terminal';       Id='Microsoft.WindowsTerminal'}
    @{Cat='Desarrollo';       Name='PowerShell 7';           Id='Microsoft.PowerShell'}
    @{Cat='Desarrollo';       Name='Oh My Posh (prompt)';    Id='JanDeDobbeleer.OhMyPosh'}
    @{Cat='Desarrollo';       Name='Neovim';                 Id='Neovim.Neovim'}
    @{Cat='Desarrollo';       Name='Sublime Text 4';         Id='SublimeHQ.SublimeText.4'}
    @{Cat='Desarrollo';       Name='Zed';                    Id='ZedIndustries.Zed'}
    @{Cat='Desarrollo';       Name='Cursor';                 Id='Anysphere.Cursor'}
    @{Cat='Desarrollo';       Name='Antigravity IDE';        Id='Google.Antigravity'}
    @{Cat='Desarrollo';       Name='OpenCode';               Id='SST.opencode'}
    @{Cat='Desarrollo';       Name='JetBrains Toolbox';      Id='JetBrains.Toolbox'}
    @{Cat='Desarrollo';       Name='Docker Desktop';         Id='Docker.DockerDesktop'}
    @{Cat='Desarrollo';       Name='Unity Hub (Unity Engine)'; Id='Unity.UnityHub'}
    @{Cat='Desarrollo';       Name='Ubuntu 24.04 (WSL)';     Id='Canonical.Ubuntu.2404'}
    @{Cat='Desarrollo';       Name='System Informer';        Id='WinsiderSS.SystemInformer'}

    # ------------------- IA LOCAL --------------------
    @{Cat='IA Local';         Name='Ollama';                 Id='Ollama.Ollama'}
    @{Cat='IA Local';         Name='LM Studio';              Id='ElementLabs.LMStudio'}

    # ------------ RED, VPN Y DESCARGAS ---------------
    @{Cat='Red y Remoto';     Name='Tailscale';              Id='Tailscale.Tailscale'}
    @{Cat='Red y Remoto';     Name='RustDesk';               Id='RustDesk.RustDesk'}
    @{Cat='Red y Remoto';     Name='WireGuard';              Id='WireGuard.WireGuard'}
    @{Cat='Red y Remoto';     Name='qBittorrent';            Id='qBittorrent.qBittorrent'}
    @{Cat='Red y Remoto';     Name='uTorrent';               Id='uTorrent.uTorrent'}
    @{Cat='Red y Remoto';     Name='eMule (Community)';      Id='eMuleCommunity.eMule'}
    @{Cat='Red y Remoto';     Name='Advanced IP Scanner';    Id='Famatech.AdvancedIPScanner'}
    @{Cat='Red y Remoto';     Name='Angry IP Scanner';       Id='angryziber.AngryIPScanner'}
    @{Cat='Red y Remoto';     Name='Cloudflare One (WARP)';  Id='Cloudflare.Warp'}
    @{Cat='Red y Remoto';     Name='FileZilla Client';       Id='TimKosse.FileZilla.Client'}
    @{Cat='Red y Remoto';     Name='JDownloader 2';          Id='AppWork.JDownloader'}
    @{Cat='Red y Remoto';     Name='Moonlight (cliente)';    Id='MoonlightGameStreamingProject.Moonlight'}
    @{Cat='Red y Remoto';     Name='Mullvad VPN';            Id='MullvadVPN.MullvadVPN'}
    @{Cat='Red y Remoto';     Name='Nmap';                   Id='Insecure.Nmap'}
    @{Cat='Red y Remoto';     Name='OpenVPN Connect';        Id='OpenVPNTechnologies.OpenVPNConnect'}
    @{Cat='Red y Remoto';     Name='Proton VPN';             Id='Proton.ProtonVPN'}
    @{Cat='Red y Remoto';     Name='PuTTY';                  Id='PuTTY.PuTTY'}
    @{Cat='Red y Remoto';     Name='Simplewall (firewall)';  Id='Henry++.simplewall'}
    @{Cat='Red y Remoto';     Name='Ventoy';                 Id='Ventoy.Ventoy'}
    @{Cat='Red y Remoto';     Name='WinSCP';                 Id='WinSCP.WinSCP'}
    @{Cat='Red y Remoto';     Name='Wireshark';              Id='WiresharkFoundation.Wireshark'}

    # ----------------- COMUNICACION ------------------
    @{Cat='Comunicacion';     Name='Telegram Desktop';       Id='Telegram.TelegramDesktop'}
    @{Cat='Comunicacion';     Name='WhatsApp';               Id='9NKSQGP7F2NH'}
    @{Cat='Comunicacion';     Name='Betterbird';             Id='Betterbird.Betterbird'}
    @{Cat='Comunicacion';     Name='Chatterino';             Id='ChatterinoTeam.Chatterino'}
    @{Cat='Comunicacion';     Name='Dorion';                 Id='SpikeHD.Dorion'}
    @{Cat='Comunicacion';     Name='Element';                Id='Element.Element'}
    @{Cat='Comunicacion';     Name='Proton Mail';            Id='Proton.ProtonMail'}
    @{Cat='Comunicacion';     Name='qTox';                   Id='Tox.qTox'}
    @{Cat='Comunicacion';     Name='Signal';                 Id='OpenWhisperSystems.Signal'}
    @{Cat='Comunicacion';     Name='Slack';                  Id='SlackTechnologies.Slack'}
    @{Cat='Comunicacion';     Name='Microsoft Teams';        Id='Microsoft.Teams'}
    @{Cat='Comunicacion';     Name='TeamSpeak 3';            Id='TeamSpeakSystems.TeamSpeakClient'}
    @{Cat='Comunicacion';     Name='Thunderbird';            Id='Mozilla.Thunderbird'}
    @{Cat='Comunicacion';     Name='Vesktop';                Id='Vencord.Vesktop'}
    @{Cat='Comunicacion';     Name='Viber';                  Id='Rakuten.Viber'}
    @{Cat='Comunicacion';     Name='Zoom';                   Id='Zoom.Zoom'}

    # ----------- MONITORIZACION Y RENDIMIENTO --------
    @{Cat='Monitorizacion';   Name='CrystalDiskInfo';        Id='CrystalDewWorld.CrystalDiskInfo'}
    @{Cat='Monitorizacion';   Name='CPU-Z';                  Id='CPUID.CPU-Z'}
    @{Cat='Monitorizacion';   Name='GPU-Z';                  Id='TechPowerUp.GPU-Z'}
    @{Cat='Monitorizacion';   Name='HWiNFO';                 Id='REALiX.HWiNFO'}
    @{Cat='Monitorizacion';   Name='HWMonitor';              Id='CPUID.HWMonitor'}
    @{Cat='Monitorizacion';   Name='Display Driver Uninstaller (DDU)'; Id='Wagnardsoft.DisplayDriverUninstaller'}

    # ------------- RUNTIMES Y LIBRERIAS --------------
    @{Cat='Runtimes';         Name='VC++ Redist 2015-2022 x64'; Id='Microsoft.VCRedist.2015+.x64'}
    @{Cat='Runtimes';         Name='VC++ Redist 2015-2022 x86'; Id='Microsoft.VCRedist.2015+.x86'}
    @{Cat='Runtimes';         Name='.NET Desktop Runtime 6';    Id='Microsoft.DotNet.DesktopRuntime.6'}
    @{Cat='Runtimes';         Name='.NET Desktop Runtime 8';    Id='Microsoft.DotNet.DesktopRuntime.8'}
    @{Cat='Runtimes';         Name='.NET Desktop Runtime 9';    Id='Microsoft.DotNet.DesktopRuntime.9'}
    @{Cat='Runtimes';         Name='.NET Desktop Runtime 10';   Id='Microsoft.DotNet.DesktopRuntime.10'}
    @{Cat='Runtimes';         Name='NuGet';                     Id='Microsoft.NuGet'}
    @{Cat='Runtimes';         Name='DirectX End-User Runtime';  Id='Microsoft.DirectX'}

    # --------- SISTEMA / MICROSOFT (NUEVA) -----------
    @{Cat='Sistema';          Name='Autoruns (Sysinternals)';   Id='Microsoft.Sysinternals.Autoruns'}
    @{Cat='Sistema';          Name='Process Explorer';          Id='Microsoft.Sysinternals.ProcessExplorer'}
    @{Cat='Sistema';          Name='Process Monitor';           Id='Microsoft.Sysinternals.ProcessMonitor'}
    @{Cat='Sistema';          Name='TCPView (Sysinternals)';    Id='Microsoft.Sysinternals.TCPView'}
    @{Cat='Sistema';          Name='RDCMan (Sysinternals)';     Id='Microsoft.Sysinternals.RDCMan'}
    @{Cat='Sistema';          Name='DISMTools';                 Id='CodingWondersSoftware.DISMTools.Stable'}
    @{Cat='Sistema';          Name='NTLite';                    Id='Nlitesoft.NTLite'}
    @{Cat='Sistema';          Name='OneDrive';                  Id='Microsoft.OneDrive'}

    # ------- OFICINA, NOTAS Y LECTURA (NUEVA) --------
    @{Cat='Oficina';          Name='Adobe Acrobat Reader';      Id='Adobe.Acrobat.Reader.64-bit'}
    @{Cat='Oficina';          Name='Calibre';                   Id='calibre.calibre'}
    @{Cat='Oficina';          Name='LibreOffice';               Id='TheDocumentFoundation.LibreOffice'}
    @{Cat='Oficina';          Name='Obsidian';                  Id='Obsidian.Obsidian'}
    @{Cat='Oficina';          Name='ONLYOFFICE Desktop';        Id='ONLYOFFICE.DesktopEditors'}

    # ----- SERVIDORES Y SELF-HOSTED (NUEVA) ----------
    @{Cat='SelfHosted';       Name='Jellyfin Media Player';     Id='Jellyfin.JellyfinMediaPlayer'}
    @{Cat='SelfHosted';       Name='Jellyfin Server';           Id='Jellyfin.Server'}
    @{Cat='SelfHosted';       Name='Kodi Media Center';         Id='XBMCFoundation.Kodi'}
    @{Cat='SelfHosted';       Name='LocalSend';                 Id='LocalSend.LocalSend'}
    @{Cat='SelfHosted';       Name='NetBird';                   Id='Netbird.Netbird'}
    @{Cat='SelfHosted';       Name='Plex Desktop';              Id='Plex.Plex'}
    @{Cat='SelfHosted';       Name='Plex Media Server';         Id='Plex.PlexMediaServer'}

    # ----- UTILIDADES Y OPTIMIZADORES (NUEVA) --------
    @{Cat='Utilidades';       Name='1Password';                 Id='AgileBits.1Password'}
    @{Cat='Utilidades';       Name='AnyDesk';                   Id='AnyDesk.AnyDesk'}
    @{Cat='Utilidades';       Name='AutoHotkey';                Id='AutoHotkey.AutoHotkey'}
    @{Cat='Utilidades';       Name='Bitwarden';                 Id='Bitwarden.Bitwarden'}
    @{Cat='Utilidades';       Name='BleachBit';                 Id='BleachBit.BleachBit'}
    @{Cat='Utilidades';       Name='Bulk Crap Uninstaller';     Id='Klocman.BulkCrapUninstaller'}
    @{Cat='Utilidades';       Name='CrystalDiskMark';           Id='CrystalDewWorld.CrystalDiskMark'}
    @{Cat='Utilidades';       Name='Deskflow (KVM software)';   Id='Deskflow.Deskflow'}
    @{Cat='Utilidades';       Name='EarTrumpet (audio)';        Id='File-New-Project.EarTrumpet'}
    @{Cat='Utilidades';       Name='Ente Photos';               Id='ente-io.photos-desktop'}
    @{Cat='Utilidades';       Name='Files (explorador)';        Id='FilesCommunity.Files'}
    @{Cat='Utilidades';       Name='f.lux';                     Id='flux.flux'}
    @{Cat='Utilidades';       Name='GlazeWM';                   Id='glzr-io.glazewm'}
    @{Cat='Utilidades';       Name='Google Drive';              Id='Google.GoogleDrive'}
    @{Cat='Utilidades';       Name='Hugo (extended)';           Id='Hugo.Hugo.Extended'}
    @{Cat='Utilidades';       Name='HxD Hex Editor';            Id='MHNexus.HxD'}
    @{Cat='Utilidades';       Name='JPEGView';                  Id='sylikc.JPEGView'}
    @{Cat='Utilidades';       Name='MSEdgeRedirect';            Id='rcmaehl.MSEdgeRedirect'}
    @{Cat='Utilidades';       Name='NAPS2 (escaner docs)';      Id='Cyanfish.NAPS2'}
    @{Cat='Utilidades';       Name='NanaZip';                   Id='M2Team.NanaZip'}
    @{Cat='Utilidades';       Name='Nilesoft Shell';            Id='Nilesoft.Shell'}
    @{Cat='Utilidades';       Name='NVCleanstall';              Id='TechPowerUp.NVCleanstall'}
    @{Cat='Utilidades';       Name='OFGB (quitar ads W11)';     Id='xM4ddy.OFGB'}
    @{Cat='Utilidades';       Name='OPAutoClicker';             Id='OPAutoClicker.OPAutoClicker'}
    @{Cat='Utilidades';       Name='OpenRGB';                   Id='OpenRGB.OpenRGB'}
    @{Cat='Utilidades';       Name='Oracle VirtualBox';         Id='Oracle.VirtualBox'}
    @{Cat='Utilidades';       Name='Parsec';                    Id='Parsec.Parsec'}
    @{Cat='Utilidades';       Name='PeaZip';                    Id='Giorgiotani.Peazip'}
    @{Cat='Utilidades';       Name='Policy Plus';               Id='Fleex255.PolicyPlus'}
    @{Cat='Utilidades';       Name='Process Lasso';             Id='BitSum.ProcessLasso'}
    @{Cat='Utilidades';       Name='Proton Authenticator';      Id='Proton.ProtonAuthenticator'}
    @{Cat='Utilidades';       Name='Proton Drive';              Id='Proton.ProtonDrive'}
    @{Cat='Utilidades';       Name='Proton Pass';               Id='Proton.ProtonPass'}
    @{Cat='Utilidades';       Name='Revo Uninstaller';          Id='RevoUninstaller.RevoUninstaller'}
    @{Cat='Utilidades';       Name='SignalRGB';                 Id='WhirlwindFX.SignalRgb'}
    @{Cat='Utilidades';       Name='Snappy Driver Installer Origin'; Id='GlennDelahoy.SnappyDriverInstallerOrigin'}
    @{Cat='Utilidades';       Name='TeamViewer';                Id='TeamViewer.TeamViewer'}
    @{Cat='Utilidades';       Name='TightVNC';                  Id='GlavSoft.TightVNC'}
    @{Cat='Utilidades';       Name='Total Commander';           Id='Ghisler.TotalCommander'}
    @{Cat='Utilidades';       Name='TranslucentTB';             Id='CharlesMilette.TranslucentTB'}
    @{Cat='Utilidades';       Name='TreeSize Free';             Id='JAMSoftware.TreeSize.Free'}
    @{Cat='Utilidades';       Name='UniGetUI';                  Id='MartiCliment.UniGetUI.Pre-Release'}
    @{Cat='Utilidades';       Name='Wise Program Uninstaller';  Id='WiseCleaner.WiseProgramUninstaller'}
    @{Cat='Utilidades';       Name='WizTree';                   Id='AntibodySoftware.WizTree'}

    # ===== AMPLIACION B5 (catalogo vivo 350+) - junio 2026 =====
    # Bloque curado con IDs fiables de winget. Validados en bloque con
    # [Validar IDs]; si alguno deja de existir, marcalo o quitalo.

    # ----------- SEGURIDAD Y CIFRADO (NUEVA) ---------
    @{Cat='Seguridad';        Name='Malwarebytes';              Id='Malwarebytes.Malwarebytes'}
    @{Cat='Seguridad';        Name='KeePass';                   Id='DominikReichl.KeePass'}
    @{Cat='Seguridad';        Name='KeePassXC';                 Id='KeePassXCTeam.KeePassXC'}
    @{Cat='Seguridad';        Name='Cryptomator';               Id='Cryptomator.Cryptomator'}
    @{Cat='Seguridad';        Name='VeraCrypt';                 Id='IDRIX.VeraCrypt'}
    @{Cat='Seguridad';        Name='Gpg4win';                   Id='GnuPG.Gpg4win'}
    @{Cat='Seguridad';        Name='O&O ShutUp10++';            Id='OO-Software.ShutUp10'}
    @{Cat='Seguridad';        Name='Windows Firewall Control';  Id='BiniSoft.WindowsFirewallControl'}
    @{Cat='Seguridad';        Name='ClamAV';                    Id='Cisco.ClamAV'}

    # ----------- PRODUCTIVIDAD Y NOTAS (NUEVA) -------
    @{Cat='Productividad';    Name='Notion';                    Id='Notion.Notion'}
    @{Cat='Productividad';    Name='Joplin';                    Id='Joplin.Joplin'}
    @{Cat='Productividad';    Name='Logseq';                    Id='Logseq.Logseq'}
    @{Cat='Productividad';    Name='Anytype';                   Id='AnyAssociation.Anytype'}
    @{Cat='Productividad';    Name='Standard Notes';            Id='StandardNotes.StandardNotes'}
    @{Cat='Productividad';    Name='Todoist';                   Id='Doist.Todoist'}
    @{Cat='Productividad';    Name='Zotero';                    Id='DigitalScholar.Zotero'}
    @{Cat='Productividad';    Name='XMind';                     Id='Xmind.Xmind'}
    @{Cat='Productividad';    Name='Freeplane';                 Id='Freeplane.Freeplane'}
    @{Cat='Productividad';    Name='draw.io';                   Id='JGraph.Draw'}
    @{Cat='Productividad';    Name='MarkText';                  Id='MarkText.MarkText'}
    @{Cat='Productividad';    Name='Zettlr';                    Id='Zettlr.Zettlr'}
    @{Cat='Productividad';    Name='Typora';                    Id='appmakes.Typora'}
    @{Cat='Productividad';    Name='Flow Launcher';             Id='Flow-Launcher.Flow-Launcher'}
    @{Cat='Productividad';    Name='Ditto (portapapeles)';      Id='Ditto.Ditto'}

    # ----------- OFICINA / PDF (amplia) --------------
    @{Cat='Oficina';          Name='SumatraPDF';                Id='SumatraPDF.SumatraPDF'}
    @{Cat='Oficina';          Name='Foxit PDF Reader';          Id='Foxit.FoxitReader'}
    @{Cat='Oficina';          Name='PDF24 Creator';             Id='geeksoftwareGmbH.PDF24Creator'}
    @{Cat='Oficina';          Name='PDFsam Basic';              Id='PDFsam.PDFsam'}
    @{Cat='Oficina';          Name='Okular';                    Id='KDE.Okular'}

    # ----------- DISCOS Y BACKUP (NUEVA) -------------
    @{Cat='Discos y Backup';  Name='Duplicati';                 Id='Duplicati.Duplicati'}
    @{Cat='Discos y Backup';  Name='restic';                    Id='restic.restic'}
    @{Cat='Discos y Backup';  Name='Rclone';                    Id='Rclone.Rclone'}
    @{Cat='Discos y Backup';  Name='WinDirStat';                Id='WinDirStat.WinDirStat'}
    @{Cat='Discos y Backup';  Name='balenaEtcher';              Id='Balena.Etcher'}
    @{Cat='Discos y Backup';  Name='Recuva';                    Id='Piriform.Recuva'}
    @{Cat='Discos y Backup';  Name='CCleaner';                  Id='Piriform.CCleaner'}
    @{Cat='Discos y Backup';  Name='Speccy';                    Id='Piriform.Speccy'}
    @{Cat='Discos y Backup';  Name='Defraggler';                Id='Piriform.Defraggler'}
    @{Cat='Discos y Backup';  Name='Glary Utilities';           Id='Glarysoft.GlaryUtilities'}
    @{Cat='Discos y Backup';  Name='Wise Disk Cleaner';         Id='WiseCleaner.WiseDiskCleaner'}
    @{Cat='Discos y Backup';  Name='Wise Registry Cleaner';     Id='WiseCleaner.WiseRegistryCleaner'}

    # ----------- MULTIMEDIA Y DISENO (amplia) --------
    @{Cat='Multimedia';       Name='Inkscape';                  Id='Inkscape.Inkscape'}
    @{Cat='Multimedia';       Name='Krita';                     Id='KDE.Krita'}
    @{Cat='Multimedia';       Name='darktable';                 Id='darktable.darktable'}
    @{Cat='Multimedia';       Name='Shotcut';                   Id='Meltytech.Shotcut'}
    @{Cat='Multimedia';       Name='Kdenlive';                  Id='KDE.Kdenlive'}
    @{Cat='Multimedia';       Name='OpenShot';                  Id='OpenShot.OpenShot'}
    @{Cat='Multimedia';       Name='FreeCAD';                   Id='FreeCAD.FreeCAD'}
    @{Cat='Multimedia';       Name='Ultimaker Cura';            Id='Ultimaker.Cura'}
    @{Cat='Multimedia';       Name='PrusaSlicer';               Id='Prusa3D.PrusaSlicer'}
    @{Cat='Multimedia';       Name='OrcaSlicer';                Id='SoftFever.OrcaSlicer'}
    @{Cat='Multimedia';       Name='foobar2000';                Id='PeterPawlowski.foobar2000'}
    @{Cat='Multimedia';       Name='MediaInfo';                 Id='MediaArea.MediaInfo'}
    @{Cat='Multimedia';       Name='Subtitle Edit';             Id='Nikse.SubtitleEdit'}
    @{Cat='Multimedia';       Name='Stremio';                   Id='Stremio.Stremio'}
    @{Cat='Multimedia';       Name='XnView MP';                 Id='XnSoft.XnViewMP'}
    @{Cat='Multimedia';       Name='ScreenToGif';               Id='NickeManarin.ScreenToGif'}
    @{Cat='Multimedia';       Name='Greenshot';                 Id='Greenshot.Greenshot'}
    @{Cat='Multimedia';       Name='Flameshot';                 Id='Flameshot.Flameshot'}

    # ----------- DESARROLLO Y TERMINAL (amplia) ------
    @{Cat='Desarrollo';       Name='Postman';                   Id='Postman.Postman'}
    @{Cat='Desarrollo';       Name='Insomnia';                  Id='Insomnia.Insomnia'}
    @{Cat='Desarrollo';       Name='HeidiSQL';                  Id='HeidiSQL.HeidiSQL'}
    @{Cat='Desarrollo';       Name='DB Browser for SQLite';     Id='DBBrowserForSQLite.DBBrowserForSQLite'}
    @{Cat='Desarrollo';       Name='MongoDB Compass';           Id='MongoDB.Compass.Full'}
    @{Cat='Desarrollo';       Name='Sourcetree';                Id='Atlassian.Sourcetree'}
    @{Cat='Desarrollo';       Name='GitKraken';                 Id='Axosoft.GitKraken'}
    @{Cat='Desarrollo';       Name='Deno';                      Id='DenoLand.Deno'}
    @{Cat='Desarrollo';       Name='.NET SDK 8';                Id='Microsoft.DotNet.SDK.8'}
    @{Cat='Desarrollo';       Name='Eclipse Temurin 21 JDK';    Id='EclipseAdoptium.Temurin.21.JDK'}
    @{Cat='Desarrollo';       Name='MSYS2';                     Id='MSYS2.MSYS2'}
    @{Cat='Desarrollo';       Name='Miniconda3';                Id='Anaconda.Miniconda3'}
    @{Cat='Desarrollo';       Name='PyCharm Community';         Id='JetBrains.PyCharm.Community'}
    @{Cat='Desarrollo';       Name='IntelliJ IDEA Community';   Id='JetBrains.IntelliJIDEA.Community'}
    @{Cat='Desarrollo';       Name='Android Studio';            Id='Google.AndroidStudio'}
    @{Cat='Desarrollo';       Name='Godot Engine';              Id='GodotEngine.GodotEngine'}
    @{Cat='Desarrollo';       Name='jq';                        Id='jqlang.jq'}
    @{Cat='Desarrollo';       Name='GitHub CLI';                Id='GitHub.cli'}
    @{Cat='Desarrollo';       Name='Terraform';                 Id='Hashicorp.Terraform'}
    @{Cat='Desarrollo';       Name='kubectl';                   Id='Kubernetes.kubectl'}
    @{Cat='Desarrollo';       Name='Helm';                      Id='Helm.Helm'}
    @{Cat='Desarrollo';       Name='AWS CLI';                   Id='Amazon.AWSCLI'}
    @{Cat='Desarrollo';       Name='Azure CLI';                 Id='Microsoft.AzureCLI'}
    @{Cat='Desarrollo';       Name='Google Cloud SDK';          Id='Google.CloudSDK'}
    @{Cat='Desarrollo';       Name='WinMerge';                  Id='WinMerge.WinMerge'}

    # ----------- UTILIDADES (amplia) -----------------
    @{Cat='Utilidades';       Name='ImageMagick';               Id='ImageMagick.ImageMagick'}
    @{Cat='Utilidades';       Name='FFmpeg (Gyan)';             Id='Gyan.FFmpeg'}
    @{Cat='Utilidades';       Name='yt-dlp';                    Id='yt-dlp.yt-dlp'}
    @{Cat='Utilidades';       Name='Speedtest CLI';             Id='Ookla.Speedtest.CLI'}
    @{Cat='Utilidades';       Name='FanControl';                Id='Rem0o.FanControl'}
    @{Cat='Utilidades';       Name='Logitech G HUB';            Id='Logitech.GHUB'}
    @{Cat='Utilidades';       Name='Wox (lanzador)';            Id='Wox.Wox'}
    @{Cat='Utilidades';       Name='QuickLook';                 Id='QL-Win.QuickLook'}

    # ----------- GAMING (amplia) ---------------------
    @{Cat='Gaming';           Name='Vortex (Nexus Mods)';       Id='NexusMods.Vortex'}
    @{Cat='Gaming';           Name='r2modman';                  Id='ebkr.r2modman'}

    # ----------- COMUNICACION (amplia) ---------------
    @{Cat='Comunicacion';     Name='Ferdium';                   Id='Ferdium.Ferdium'}
    @{Cat='Comunicacion';     Name='Mailspring';                Id='Foundry376.Mailspring'}
    @{Cat='Comunicacion';     Name='WeChat';                    Id='Tencent.WeChat'}

    # ----------- DESARROLLO / CLI (amplia 2) ---------
    @{Cat='Desarrollo';       Name='.NET SDK 9';                Id='Microsoft.DotNet.SDK.9'}
    @{Cat='Desarrollo';       Name='Eclipse Temurin 17 JDK';    Id='EclipseAdoptium.Temurin.17.JDK'}
    @{Cat='Desarrollo';       Name='Wget';                      Id='JernejSimoncic.Wget'}
    @{Cat='Desarrollo';       Name='cURL';                      Id='cURL.cURL'}
    @{Cat='Desarrollo';       Name='Starship (prompt)';         Id='Starship.Starship'}
    @{Cat='Desarrollo';       Name='bat (cat moderno)';         Id='sharkdp.bat'}
    @{Cat='Desarrollo';       Name='fd (find moderno)';         Id='sharkdp.fd'}
    @{Cat='Desarrollo';       Name='ripgrep';                   Id='BurntSushi.ripgrep.MSVC'}
    @{Cat='Desarrollo';       Name='fzf';                       Id='junegunn.fzf'}
    @{Cat='Desarrollo';       Name='zoxide';                    Id='ajeetdsouza.zoxide'}
    @{Cat='Desarrollo';       Name='eza (ls moderno)';          Id='eza-community.eza'}
    @{Cat='Desarrollo';       Name='delta (git diff)';          Id='dandavison.delta'}
    @{Cat='Desarrollo';       Name='gsudo';                     Id='gerardog.gsudo'}
    @{Cat='Desarrollo';       Name='fnm (Node manager)';        Id='Schniz.fnm'}
    @{Cat='Desarrollo';       Name='nvm for Windows';           Id='CoreyButler.NVMforWindows'}
    @{Cat='Desarrollo';       Name='Nushell';                   Id='Nushell.Nushell'}
    @{Cat='Desarrollo';       Name='Ninja';                     Id='Ninja-build.Ninja'}
    @{Cat='Desarrollo';       Name='LLVM / Clang';              Id='LLVM.LLVM'}
    @{Cat='Desarrollo';       Name='Strawberry Perl';           Id='StrawberryPerl.StrawberryPerl'}
    @{Cat='Desarrollo';       Name='SQL Server Mgmt Studio';    Id='Microsoft.SQLServerManagementStudio'}
    @{Cat='Desarrollo';       Name='Anaconda3';                 Id='Anaconda.Anaconda3'}
    @{Cat='Desarrollo';       Name='Windows ADK';               Id='Microsoft.WindowsADK'}

    # ----------- NUBE Y SINCRONIZACION (NUEVA) -------
    @{Cat='Nube y Sync';      Name='Dropbox';                   Id='Dropbox.Dropbox'}
    @{Cat='Nube y Sync';      Name='MEGAsync';                  Id='Mega.MEGASync'}
    @{Cat='Nube y Sync';      Name='Nextcloud Desktop';         Id='Nextcloud.NextcloudDesktop'}
    @{Cat='Nube y Sync';      Name='Syncthing';                 Id='Syncthing.Syncthing'}
)
# --- NO DISPONIBLES EN EL REPOSITORIO DE WINGET (junio 2026) ---
# Estas apps de tu lista no tienen manifiesto fiable en winget y se
# excluyen a proposito para no romper instalaciones masivas:
#   * BD3D2MK3D            -> descarga manual (videohelp.com)
#   * BlurAutoClicker      -> descarga manual
#   * Z-Library Desktop    -> no esta en winget
# Si algun dia aparecen, anade su linea @{Cat=...;Name=...;Id=...}
# y pulsa [Validar IDs] para confirmarla.
# ============================================================

# ---- CATALOGO EXTERNO EDITABLE (catalogo.json junto al script) ----
# Si existe un catalogo.json valido al lado del .ps1, SUSTITUYE al
# catalogo interno. Asi puedes anadir/quitar apps sin tocar el codigo.
# Formato: [ { "Cat":"Categoria", "Name":"Nombre", "Id":"Editor.App" }, ... ]
$CatalogFile = (Join-Path $PSScriptRoot 'catalogo.json')
$CatalogSource = 'interno'
function Import-ExternalCatalog {
    if (-not (Test-Path $script:CatalogFile)) { return $null }
    try {
        $raw = Get-Content $script:CatalogFile -Raw -Encoding UTF8
        $data = $raw | ConvertFrom-Json
        $list = @()
        foreach ($e in @($data)) {
            if ($e.Id -and $e.Name -and $e.Cat) {
                $list += @{ Cat = [string]$e.Cat; Name = [string]$e.Name; Id = [string]$e.Id }
            }
        }
        if ($list.Count -gt 0) { return $list }
    } catch {
        Write-Warning ("catalogo.json no se pudo leer: {0}" -f $_.Exception.Message)
    }
    return $null
}
$ext = Import-ExternalCatalog
if ($ext) { $catalog = $ext; $CatalogSource = ('externo ({0})' -f (Split-Path $CatalogFile -Leaf)) }

# Exporta el catalogo interno a catalogo.json (plantilla para editar)
function Export-CatalogTemplate {
    try {
        $arr = @($catalog | ForEach-Object { [ordered]@{ Cat = $_.Cat; Name = $_.Name; Id = $_.Id } })
        Set-WpiContent -Path $script:CatalogFile -Value ($arr | ConvertTo-Json -Depth 4)
        return $true
    } catch { return $false }
}

# ================== PRESETS RAPIDOS (1 clic) =================
$QuickPresets = @{
    'Gaming' = @(
        'Valve.Steam','Discord.Discord','EpicGames.EpicGamesLauncher','GOG.Galaxy',
        'ElectronicArts.EADesktop','Ubisoft.Connect','HeroicGamesLauncher.HeroicGamesLauncher',
        'PrismLauncher.PrismLauncher','Playnite.Playnite','beeradmoore.dlss-swapper',
        'Nvidia.GeForceNow','CodecGuide.K-LiteCodecPack.Mega','Microsoft.VCRedist.2015+.x64',
        'Microsoft.VCRedist.2015+.x86','Microsoft.DirectX'
    )
    'Desarrollador' = @(
        'Microsoft.VisualStudioCode','Git.Git','GitHub.GitHubDesktop','Python.Python.3.12',
        'astral-sh.uv','OpenJS.NodeJS.LTS','Microsoft.WindowsTerminal','Microsoft.PowerShell',
        'JanDeDobbeleer.OhMyPosh','Kitware.CMake','Neovim.Neovim','Docker.DockerDesktop',
        'JesseDuffield.lazygit'
    )
    'Multimedia' = @(
        'VideoLAN.VLC','OBSProject.OBSStudio','GIMP.GIMP','Audacity.Audacity',
        'HandBrake.HandBrake','BlenderFoundation.Blender','ShareX.ShareX',
        'dotPDN.PaintDotNet','clsid2.mpc-hc','CodecGuide.K-LiteCodecPack.Mega',
        'DuongDieuPhap.ImageGlass','MoritzBunkus.MKVToolNix'
    )
    'Esencial' = @(
        '7zip.7zip','Notepad++.Notepad++','voidtools.Everything','Microsoft.PowerToys',
        'Mozilla.Firefox','VideoLAN.VLC','Microsoft.VCRedist.2015+.x64',
        'Microsoft.VCRedist.2015+.x86','Microsoft.DotNet.DesktopRuntime.8'
    )
}
# ============================================================

# ================ TWEAKS Y DEBLOAT (opt-in) ==================
# Cada tweak es codigo PowerShell que se ejecuta en segundo plano
# con privilegios de administrador. W 'tipo' 'mensaje' escribe en
# el log en vivo y en el archivo forense.
$TweaksCatalog = @(
    # ---------------- SISTEMA / MANTENIMIENTO ----------------
    @{ Name='Crear punto de restauracion del sistema'; Cat='Sistema'; Risk='Seguro'
       Desc='MUY recomendado antes de aplicar el resto de tweaks.'
       Code=@'
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "WPI Moderno - antes de tweaks" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    W ok "Punto de restauracion creado correctamente."
} catch {
    W warn ("No se pudo crear el punto de restauracion: {0} (Windows limita a 1 cada 24h)." -f $_.Exception.Message)
}
'@
       Undo=@'
W dim "Crear un punto de restauracion no tiene reversion (puedes borrarlo desde Propiedades del sistema)."
'@ }
    @{ Name='Limpieza profunda de temporales'; Cat='Sistema'; Risk='Seguro'
       Desc='%TEMP%, Windows\Temp, papelera de reciclaje y cache DNS.'
       Code=@'
$before = (Get-PSDrive C).Free
Remove-Item "$env:TEMP\*"            -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
ipconfig /flushdns | Out-Null
$freed = [math]::Round(((Get-PSDrive C).Free - $before) / 1MB, 1)
W ok ("Limpieza completada. Espacio liberado aprox.: {0} MB." -f [math]::Max($freed,0))
'@
       Undo=@'
W dim "Una limpieza de temporales no se puede deshacer."
'@ }
    @{ Name='Plan de energia Maximo Rendimiento'; Cat='Sistema'; Risk='Seguro'
       Desc='Activa el plan Ultimate Performance (ideal para GPUs de gama alta).'
       Caveat='es un portatil a bateria: este plan consume mas energia.'
       Code=@'
$dup = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa66-ad3aa851f8f7 2>&1 | Out-String)
if ($dup -match '([a-f0-9-]{36})') {
    powercfg /setactive $Matches[1] | Out-Null
    W ok "Plan Ultimate Performance creado y activado."
} else {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
    W ok "Ultimate no disponible en esta edicion; activado plan Alto Rendimiento."
}
'@
       Undo=@'
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
W ok "Plan de energia Equilibrado restaurado."
'@ }
    @{ Name='Desactivar hibernacion (libera hiberfil.sys)'; Cat='Sistema'; Risk='Seguro'
       Desc='Recupera varios GB del disco. Mantiene suspension normal.'
       Caveat='es un portatil o usas "Hibernar" para guardar la sesion al apagar.'
       Code=@'
powercfg /hibernate off | Out-Null
W ok "Hibernacion desactivada (hiberfil.sys eliminado)."
'@
       Undo=@'
powercfg /hibernate on | Out-Null
W ok "Hibernacion reactivada."
'@ }

    # ---------------------- PRIVACIDAD -----------------------
    @{ Name='Desactivar telemetria innecesaria'; Cat='Privacidad'; Risk='Seguro'
       Desc='Servicio DiagTrack, tareas CEIP/Compatibilidad y AllowTelemetry=0.'
       Code=@'
Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
Set-Service  DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
$tasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
)
foreach ($t in $tasks) { schtasks /Change /TN $t /Disable 2>&1 | Out-Null }
W ok "Telemetria basica desactivada (DiagTrack + tareas programadas)."
'@
       Undo=@'
Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service DiagTrack -ErrorAction SilentlyContinue
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f 2>$null | Out-Null
$tasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
)
foreach ($t in $tasks) { schtasks /Change /TN $t /Enable 2>$null | Out-Null }
W ok "Telemetria reactivada a los valores de Windows."
'@ }
    @{ Name='Desactivar Bing, sugerencias y apps promocionadas'; Cat='Privacidad'; Risk='Seguro'
       Desc='Quita la web de la busqueda de Inicio y el contenido patrocinado.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled   /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
W ok "Bing/sugerencias/ID de publicidad desactivados."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 1 /f | Out-Null
W ok "Bing y sugerencias reactivados."
'@ }
    @{ Name='Desactivar historial de actividad (Timeline)'; Cat='Privacidad'; Risk='Seguro'
       Desc='Windows deja de recopilar y enviar tu actividad reciente.'
       Code=@'
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f | Out-Null
W ok "Historial de actividad desactivado."
'@
       Undo=@'
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /f 2>$null | Out-Null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /f 2>$null | Out-Null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /f 2>$null | Out-Null
W ok "Historial de actividad restaurado."
'@ }
    @{ Name='Quitar anuncios de la pantalla de bloqueo e Inicio'; Cat='Privacidad'; Risk='Seguro'
       Desc='Desactiva el contenido rotativo y los "datos curiosos" patrocinados.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353698Enabled /t REG_DWORD /d 0 /f | Out-Null
W ok "Anuncios de pantalla de bloqueo e Inicio desactivados."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 1 /f | Out-Null
W ok "Contenido de pantalla de bloqueo restaurado."
'@ }
    @{ Name='Desactivar sugerencias en Configuracion'; Cat='Privacidad'; Risk='Seguro'
       Desc='Quita las "recomendaciones" patrocinadas dentro de Ajustes.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f | Out-Null
W ok "Sugerencias de Configuracion desactivadas."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 1 /f | Out-Null
W ok "Sugerencias de Configuracion restauradas."
'@ }
    @{ Name='Desactivar Copilot por politica'; Cat='Privacidad'; Risk='Seguro'
       Desc='Apaga el boton/atajo de Copilot. (No desinstala la app: usa Debloat.)'
       Code=@'
reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f | Out-Null
W ok "Copilot desactivado por politica."
'@
       Undo=@'
reg delete "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f 2>$null | Out-Null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f 2>$null | Out-Null
W ok "Copilot reactivado."
'@ }
    @{ Name='Desactivar analisis de IA / Recall'; Cat='Privacidad'; Risk='Avanzado'
       Desc='Bloquea la recopilacion de datos para funciones de IA (Recall).'
       Code=@'
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f | Out-Null
W ok "Analisis de IA (Recall) desactivado por politica."
'@
       Undo=@'
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /f 2>$null | Out-Null
W ok "Analisis de IA restaurado."
'@ }

    # ----------------------- INTERFAZ ------------------------
    @{ Name='Explorador: extensiones y archivos ocultos visibles'; Cat='Interfaz'; Risk='Seguro'
       Desc='Muestra extensiones de archivo, ocultos, y abre en Este Equipo.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden      /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo    /t REG_DWORD /d 1 /f | Out-Null
W ok "Explorador configurado (reinicia el Explorador o la sesion para verlo)."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden      /t REG_DWORD /d 2 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo    /t REG_DWORD /d 2 /f | Out-Null
W ok "Explorador restaurado a valores de Windows."
'@ }
    @{ Name='Menu contextual clasico (Windows 11)'; Cat='Interfaz'; Risk='Avanzado'
       Desc='Restaura el menu de clic derecho completo de Windows 10.'
       Code=@'
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 2
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
W ok "Menu contextual clasico activado (Explorador reiniciado)."
'@
       Undo=@'
reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null | Out-Null
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 2
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
W ok "Menu contextual moderno de Windows 11 restaurado."
'@ }
    @{ Name='Barra de tareas alineada a la izquierda (Windows 11)'; Cat='Interfaz'; Risk='Seguro'
       Desc='Mueve el boton Inicio a la esquina clasica.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f | Out-Null
W ok "Barra de tareas alineada a la izquierda."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 1 /f | Out-Null
W ok "Barra de tareas centrada (valor por defecto)."
'@ }
    @{ Name='Mostrar segundos en el reloj de la barra'; Cat='Interfaz'; Risk='Seguro'
       Desc='Anade los segundos al reloj de la barra de tareas.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSecondsInSystemClock /t REG_DWORD /d 1 /f | Out-Null
W ok "Segundos activados en el reloj (reinicia el Explorador)."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSecondsInSystemClock /t REG_DWORD /d 0 /f | Out-Null
W ok "Segundos ocultos en el reloj."
'@ }
    @{ Name='Quitar el boton de Widgets'; Cat='Interfaz'; Risk='Seguro'
       Desc='Oculta el icono de Widgets de la barra de tareas.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f | Out-Null
W ok "Boton de Widgets oculto."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 1 /f | Out-Null
W ok "Boton de Widgets restaurado."
'@ }
    @{ Name='Quitar el boton de Chat/Teams de la barra'; Cat='Interfaz'; Risk='Seguro'
       Desc='Oculta el icono de Chat (Teams de consumo).'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f | Out-Null
W ok "Boton de Chat oculto."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 1 /f | Out-Null
W ok "Boton de Chat restaurado."
'@ }
    @{ Name='Quitar el boton Vista de tareas'; Cat='Interfaz'; Risk='Seguro'
       Desc='Oculta el icono de Task View de la barra de tareas.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f | Out-Null
W ok "Boton Vista de tareas oculto."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 1 /f | Out-Null
W ok "Boton Vista de tareas restaurado."
'@ }
    @{ Name='Anadir "Finalizar tarea" al boton derecho de la barra'; Cat='Interfaz'; Risk='Seguro'
       Desc='Permite matar una app desde la barra de tareas (clic derecho).'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /t REG_DWORD /d 1 /f | Out-Null
W ok "Opcion 'Finalizar tarea' activada en la barra de tareas."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /t REG_DWORD /d 0 /f | Out-Null
W ok "Opcion 'Finalizar tarea' desactivada."
'@ }

    # ---------------------- RENDIMIENTO ----------------------
    @{ Name='Aceleracion de GPU por hardware (HAGS)'; Cat='Rendimiento'; Risk='Avanzado'
       Desc='Activa Hardware-Accelerated GPU Scheduling. Requiere reiniciar.'
       Code=@'
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
W ok "HAGS activado. Reinicia el equipo para aplicarlo."
'@
       Undo=@'
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 1 /f | Out-Null
W ok "HAGS desactivado (valor por defecto). Reinicia el equipo."
'@ }
    @{ Name='Ajustar efectos visuales para mejor rendimiento'; Cat='Rendimiento'; Risk='Seguro'
       Desc='Reduce animaciones y sombras para una respuesta mas agil.'
       Caveat='prefieres una interfaz con animaciones y sombras (es solo estetico).'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
W ok "Efectos visuales ajustados a 'mejor rendimiento' (reinicia la sesion)."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 0 /f | Out-Null
W ok "Efectos visuales: Windows decide (valor por defecto)."
'@ }
    @{ Name='Menus instantaneos (sin retardo)'; Cat='Rendimiento'; Risk='Seguro'
       Desc='Quita el retardo al abrir menus.'
       Code=@'
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f | Out-Null
W ok "Retardo de menus a 0 ms (reinicia la sesion)."
'@
       Undo=@'
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 400 /f | Out-Null
W ok "Retardo de menus a 400 ms (valor por defecto)."
'@ }

    # ----------------------- SEGURIDAD -----------------------
    @{ Name='Activar restauracion del sistema en C:'; Cat='Seguridad'; Risk='Seguro'
       Desc='Habilita la proteccion del sistema para poder crear puntos.'
       Code=@'
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    W ok "Restauracion del sistema activada en $env:SystemDrive."
} catch { W warn ("No se pudo activar: {0}" -f $_.Exception.Message) }
'@
       Undo=@'
try { Disable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop; W ok "Restauracion del sistema desactivada." }
catch { W warn ("No se pudo desactivar: {0}" -f $_.Exception.Message) }
'@ }
    @{ Name='Desactivar ejecucion automatica de USB/medios'; Cat='Seguridad'; Risk='Seguro'
       Desc='Evita que USBs y discos lancen programas solos (Autorun).'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f | Out-Null
W ok "Autorun/Autoplay desactivado para todas las unidades."
'@
       Undo=@'
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /f 2>$null | Out-Null
W ok "Autorun/Autoplay restaurado al valor de Windows."
'@ }

    # -------------------------- RED --------------------------
    @{ Name='Optimizar red para juegos/streaming'; Cat='Red'; Risk='Avanzado'
       Desc='Quita el throttling de red y prioriza respuesta multimedia.'
       Code=@'
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f | Out-Null
W ok "Network throttling desactivado y respuesta del sistema priorizada."
'@
       Undo=@'
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 10 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f | Out-Null
W ok "Valores de red/multimedia restaurados (10 / 20)."
'@ }

    # ------------------------- GAMING ------------------------
    @{ Name='Activar Modo Juego (Game Mode)'; Cat='Gaming'; Risk='Seguro'
       Desc='Prioriza recursos para los juegos en primer plano.'
       Code=@'
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
W ok "Modo Juego activado."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f | Out-Null
W ok "Modo Juego desactivado."
'@ }
    @{ Name='Desactivar Game Bar y grabacion en segundo plano'; Cat='Gaming'; Risk='Seguro'
       Desc='Apaga Xbox Game Bar y la captura DVR (ahorra recursos).'
       Caveat='usas Game Bar para grabar la pantalla o ver los FPS en juegos.'
       Code=@'
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
W ok "Game Bar y grabacion DVR desactivadas."
'@
       Undo=@'
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 1 /f | Out-Null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /f 2>$null | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 1 /f | Out-Null
W ok "Game Bar y grabacion DVR restauradas."
'@ }
    @{ Name='Desactivar aceleracion del raton (precision para juegos)'; Cat='Gaming'; Risk='Avanzado'
       Desc='Movimiento de raton 1:1, ideal para shooters. Reinicia la sesion.'
       Caveat='usas el raton sobre todo para escritorio/diseno y no para juegos.'
       Code=@'
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f | Out-Null
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null
W ok "Aceleracion del raton desactivada (reinicia la sesion)."
'@
       Undo=@'
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 1 /f | Out-Null
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 6 /f | Out-Null
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 10 /f | Out-Null
W ok "Aceleracion del raton restaurada (valores por defecto)."
'@ }
    @{ Name='Desactivar notificaciones del sistema'; Cat='Privacidad'; Risk='Seguro'
       Desc='Apaga las notificaciones toast y los avisos emergentes de Windows.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_TOASTS_ENABLED /t REG_DWORD /d 0 /f | Out-Null
W ok "Notificaciones del sistema desactivadas."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 1 /f | Out-Null
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_TOASTS_ENABLED /f 2>$null | Out-Null
W ok "Notificaciones del sistema reactivadas."
'@ }

    # --------- AMPLIACION v4.1 (mas tweaks de alto consenso) ---------
    @{ Name='Desactivar Inicio rapido (Fast Startup)'; Cat='Sistema'; Risk='Avanzado'
       Desc='Apaga el hibernado parcial al arrancar. Evita problemas de drivers y apagados "fantasma"; el equipo arranca completamente limpio.'
       Caveat='valoras unos segundos menos de arranque por encima de un apagado completo y limpio.'
       Code=@'
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f | Out-Null
W ok "Inicio rapido desactivado (arranque limpio)."
'@
       Undo=@'
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f | Out-Null
W ok "Inicio rapido reactivado (valor por defecto)."
'@ }
    @{ Name='Mostrar mensajes detallados al iniciar/apagar'; Cat='Sistema'; Risk='Seguro'
       Desc='Muestra que esta haciendo Windows al encender o apagar (util para diagnosticar cuelgues).'
       Code=@'
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v VerboseStatus /t REG_DWORD /d 1 /f | Out-Null
W ok "Mensajes detallados de inicio/apagado activados."
'@
       Undo=@'
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v VerboseStatus /f 2>$null | Out-Null
W ok "Mensajes detallados desactivados (valor por defecto)."
'@ }
    @{ Name='Acelerar el apagado del sistema'; Cat='Sistema'; Risk='Avanzado'
       Desc='Reduce el tiempo de espera para cerrar servicios y apps al apagar. Apagado mas rapido.'
       Code=@'
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v WaitToKillServiceTimeout /t REG_SZ /d 2000 /f | Out-Null
reg add "HKCU\Control Panel\Desktop" /v WaitToKillAppTimeout /t REG_SZ /d 2000 /f | Out-Null
reg add "HKCU\Control Panel\Desktop" /v HungAppTimeout /t REG_SZ /d 2000 /f | Out-Null
W ok "Tiempos de apagado reducidos a 2 s."
'@
       Undo=@'
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v WaitToKillServiceTimeout /t REG_SZ /d 5000 /f | Out-Null
reg delete "HKCU\Control Panel\Desktop" /v WaitToKillAppTimeout /f 2>$null | Out-Null
reg delete "HKCU\Control Panel\Desktop" /v HungAppTimeout /f 2>$null | Out-Null
W ok "Tiempos de apagado restaurados (valores por defecto)."
'@ }
    @{ Name='Desactivar Cortana'; Cat='Privacidad'; Risk='Seguro'
       Desc='Impide que Cortana se ejecute por politica del sistema.'
       Code=@'
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f | Out-Null
W ok "Cortana desactivada por politica."
'@
       Undo=@'
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /f 2>$null | Out-Null
W ok "Cortana restaurada (valor por defecto)."
'@ }
    @{ Name='Desactivar seguimiento de ubicacion'; Cat='Privacidad'; Risk='Avanzado'
       Desc='Deniega el acceso global a la ubicacion. Algunas apps de mapas/clima dejaran de localizarte.'
       Code=@'
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" /v Status /t REG_DWORD /d 0 /f | Out-Null
W ok "Seguimiento de ubicacion desactivado."
'@
       Undo=@'
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" /v Status /t REG_DWORD /d 1 /f | Out-Null
W ok "Seguimiento de ubicacion reactivado."
'@ }
    @{ Name='Desactivar apps en segundo plano'; Cat='Privacidad'; Risk='Avanzado'
       Desc='Impide que las apps de la Store se ejecuten en segundo plano (ahorra RAM y bateria).'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f | Out-Null
W ok "Apps en segundo plano desactivadas."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 0 /f | Out-Null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /f 2>$null | Out-Null
W ok "Apps en segundo plano reactivadas."
'@ }
    @{ Name='Activar tema oscuro de Windows'; Cat='Interfaz'; Risk='Seguro'
       Desc='Pone el modo oscuro en el sistema y en las aplicaciones.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f | Out-Null
W ok "Tema oscuro activado."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 1 /f | Out-Null
W ok "Tema claro restaurado."
'@ }
    @{ Name='Desactivar transparencia (rendimiento)'; Cat='Interfaz'; Risk='Seguro'
       Desc='Quita los efectos de transparencia de la barra y menus. Algo mas de rendimiento.'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
W ok "Transparencia desactivada."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f | Out-Null
W ok "Transparencia reactivada."
'@ }
    @{ Name='Quitar el cuadro de busqueda de la barra'; Cat='Interfaz'; Risk='Seguro'
       Desc='Oculta la caja de busqueda de la barra de tareas (queda mas limpia).'
       Code=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f | Out-Null
W ok "Cuadro de busqueda oculto en la barra de tareas."
'@
       Undo=@'
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f | Out-Null
W ok "Cuadro de busqueda restaurado."
'@ }
    @{ Name='Desactivar la pantalla de bloqueo'; Cat='Interfaz'; Risk='Seguro'
       Desc='Salta directamente a la pantalla de inicio de sesion sin la pantalla de bloqueo previa.'
       Caveat='te gusta ver el reloj y las notificaciones en la pantalla de bloqueo.'
       Code=@'
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f | Out-Null
W ok "Pantalla de bloqueo desactivada."
'@
       Undo=@'
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /f 2>$null | Out-Null
W ok "Pantalla de bloqueo restaurada."
'@ }
    @{ Name='Desactivar teclas especiales (Sticky/Filter/Toggle)'; Cat='Gaming'; Risk='Seguro'
       Desc='Evita los avisos al pulsar 5 veces Shift o mantener Shift. Imprescindible para juegos.'
       Code=@'
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f | Out-Null
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
W ok "Teclas especiales (sticky/filter/toggle) desactivadas."
'@
       Undo=@'
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 510 /f | Out-Null
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 126 /f | Out-Null
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 62 /f | Out-Null
W ok "Teclas especiales restauradas (valores por defecto)."
'@ }
    @{ Name='Desactivar la indexacion de busqueda (Windows Search)'; Cat='Rendimiento'; Risk='Avanzado'
       Desc='Detiene el servicio de indexado. Reduce uso de disco; la busqueda en el menu Inicio sera mas lenta.'
       Caveat='buscas archivos a menudo desde el menu Inicio (sera mas lento).'
       Code=@'
Stop-Service WSearch -Force -ErrorAction SilentlyContinue
Set-Service  WSearch -StartupType Disabled -ErrorAction SilentlyContinue
W ok "Servicio de indexacion (Windows Search) detenido y desactivado."
'@
       Undo=@'
Set-Service   WSearch -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service WSearch -ErrorAction SilentlyContinue
W ok "Servicio de indexacion (Windows Search) reactivado."
'@ }
)
# ============================================================

# ============== DEBLOAT DE APPS PREINSTALADAS ===============
# Apps Appx que vienen de fabrica en Windows y suele querer quitarse.
# Pkg = patron de nombre para Get-AppxPackage -Name "<Pkg>".
# Se eliminan SOLO las que marques. Son reinstalables desde la Store.
# Ninguna esta preseleccionada y no se incluyen componentes criticos
# (Store, .NET, VCLibs, etc.) para no romper el sistema.
$DebloatCatalog = @(
    @{ Name = 'Xbox (apps y overlay de juego)'; Pkg = 'Microsoft.GamingApp*|Microsoft.Xbox*'; Desc = 'Apps de Xbox y Game Bar (incluye la nueva GamingApp). Quitalo si no usas Xbox.' }
    @{ Name = 'Copilot';                        Pkg = 'Microsoft.Copilot*|Microsoft.Windows.Ai.Copilot.Provider*'; Desc = 'Asistente Copilot (app + proveedor de IA 25H2).' }
    @{ Name = 'Cortana';                        Pkg = 'Microsoft.549981C3F5F10*';        Desc = 'Asistente de voz Cortana.' }
    @{ Name = 'Tu telefono / Vincular al movil';Pkg = 'Microsoft.YourPhone*';            Desc = 'Phone Link.' }
    @{ Name = 'Noticias (Microsoft News)';      Pkg = 'Microsoft.BingNews*';             Desc = 'App de noticias.' }
    @{ Name = 'El Tiempo (Bing Weather)';       Pkg = 'Microsoft.BingWeather*';          Desc = 'App del tiempo.' }
    @{ Name = 'Bing Search (widget de busqueda)';Pkg= 'Microsoft.BingSearch*';           Desc = 'Busqueda web de Bing.' }
    @{ Name = 'Solitario Collection';           Pkg = 'Microsoft.MicrosoftSolitaireCollection*'; Desc = 'Juego con anuncios.' }
    @{ Name = 'Get Help (Obtener ayuda)';       Pkg = 'Microsoft.GetHelp*';              Desc = 'Asistencia de Windows.' }
    @{ Name = 'Tips / Sugerencias';             Pkg = 'Microsoft.Getstarted*';           Desc = 'Consejos de Windows.' }
    @{ Name = 'Mapas (Windows Maps)';           Pkg = 'Microsoft.WindowsMaps*';          Desc = 'App de mapas.' }
    @{ Name = 'Grabadora de voz';               Pkg = 'Microsoft.WindowsSoundRecorder*'; Desc = 'Grabadora de sonido.' }
    @{ Name = 'Clipchamp (editor de video)';    Pkg = 'Clipchamp.Clipchamp*';            Desc = 'Editor de video preinstalado.' }
    @{ Name = 'Skype / Meet Now';               Pkg = 'Microsoft.SkypeApp*';             Desc = 'Skype preinstalado.' }
    @{ Name = 'To Do (Microsoft To Do)';        Pkg = 'Microsoft.Todos*';                Desc = 'Lista de tareas.' }
    @{ Name = 'Family (Seguridad familiar)';    Pkg = 'MicrosoftCorporationII.MicrosoftFamily*'; Desc = 'Control parental.' }
    @{ Name = 'Quick Assist';                   Pkg = 'MicrosoftCorporationII.QuickAssist*'; Desc = 'Asistencia remota.' }
    @{ Name = 'Teams (personal / Chat)';        Pkg = 'MSTeams*|MicrosoftTeams*';        Desc = 'Teams de consumo 25H2 (MSTeams) + compatibilidad con el nombre antiguo. No afecta al Teams de empresa.' }
    @{ Name = 'Outlook (nuevo, preinstalado)';  Pkg = 'Microsoft.OutlookForWindows*';    Desc = 'Nuevo Outlook web-app.' }
    @{ Name = 'Paint 3D';                       Pkg = 'Microsoft.MSPaint*';              Desc = 'Paint 3D (no el Paint clasico).' }
    @{ Name = 'Mixed Reality Portal';           Pkg = 'Microsoft.MixedReality.Portal*';  Desc = 'Portal de realidad mixta.' }
    @{ Name = 'Feedback Hub';                   Pkg = 'Microsoft.WindowsFeedbackHub*';   Desc = 'Comentarios a Microsoft.' }
    @{ Name = 'People (Contactos)';             Pkg = 'Microsoft.People*';               Desc = 'App de contactos.' }
    @{ Name = 'Power Automate (preinstalado)';  Pkg = 'Microsoft.PowerAutomateDesktop*'; Desc = 'Automatizacion.' }
    # --- Ampliacion B2 (mas Appx curadas, reinstalables desde la Store) ---
    @{ Name = 'Peliculas y TV (Movies & TV)';   Pkg = 'Microsoft.ZuneVideo*';            Desc = 'Reproductor de video de Microsoft.' }
    @{ Name = 'Groove Musica';                  Pkg = 'Microsoft.ZuneMusic*';            Desc = 'Reproductor de musica de Microsoft.' }
    @{ Name = 'Visor 3D (3D Viewer)';           Pkg = 'Microsoft.Microsoft3DViewer*';    Desc = 'Visor de modelos 3D.' }
    @{ Name = 'Office Hub (Microsoft 365)';     Pkg = 'Microsoft.MicrosoftOfficeHub*';   Desc = 'Lanzadera/anuncio de Microsoft 365 (no es Office).' }
    @{ Name = 'Dev Home';                       Pkg = 'Microsoft.Windows.DevHome*';      Desc = 'Panel para desarrolladores.' }
    @{ Name = 'Whiteboard (Pizarra)';           Pkg = 'Microsoft.Whiteboard*';           Desc = 'Pizarra colaborativa.' }
    @{ Name = 'Microsoft Journal';              Pkg = 'Microsoft.MicrosoftJournal*';     Desc = 'App de notas a mano.' }
    @{ Name = 'LinkedIn';                       Pkg = '7EE7776C.LinkedInforWindows*';    Desc = 'App de LinkedIn preinstalada.' }
    @{ Name = 'Widgets (Web Experience)';       Pkg = 'MicrosoftWindows.Client.WebExperience*'; Desc = 'Panel de Widgets de la barra de tareas. Reinstalable.' }
    # --- Ampliacion 25H2 (nombres validos estilo Chris Titus WinUtil) ---
    @{ Name = 'Alarmas y reloj';                Pkg = 'Microsoft.WindowsAlarms*';        Desc = 'Alarmas, temporizador y reloj. Reinstalable desde la Store.' }
    @{ Name = 'Noticias Bing (Finanzas/Deportes)'; Pkg = 'Microsoft.BingFinance*|Microsoft.BingSports*'; Desc = 'Apps de finanzas y deportes de Bing.' }
)

# Devuelve los patrones individuales de un campo Pkg del catalogo, que puede
# contener varios patrones separados por '|' (p. ej. 'MSTeams*|MicrosoftTeams*').
# Para un Pkg con un solo patron, devuelve ese patron como unico elemento; nunca
# devuelve cadenas vacias. Lo usan TODOS los consumidores de .Pkg (CLI, GUI,
# detector y derivacion de la lista de la ISO) para tratar cada patron por separado.
function Get-DebloatPatterns {
    param([string]$Pkg)
    return @(($Pkg -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
# ============================================================

# ============== CONTROL DE WINDOWS UPDATE ===================
# Acciones que se ejecutan por el motor de tweaks (Name+Code).
$WindowsUpdateActions = @(
    @{ Name='Configuracion recomendada (retrasar updates)'; Risk='Seguro'
       Desc='Retrasa las actualizaciones de caracteristicas ~1 ano y las de seguridad 4 dias (estilo "Pro").'
       Code=@'
if (-not $isAdmin) { throw (L2 'Requiere ejecutar WPI como administrador (clic derecho > Ejecutar como administrador).' 'Requires running WPI as administrator (right-click > Run as administrator).') }
$k="HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
reg add $k /v DeferFeatureUpdates /t REG_DWORD /d 1 /f | Out-Null
reg add $k /v DeferFeatureUpdatesPeriodInDays /t REG_DWORD /d 365 /f | Out-Null
reg add $k /v DeferQualityUpdates /t REG_DWORD /d 1 /f | Out-Null
reg add $k /v DeferQualityUpdatesPeriodInDays /t REG_DWORD /d 4 /f | Out-Null
reg add $k /v BranchReadinessLevel /t REG_DWORD /d 20 /f | Out-Null
W dim (L2 '  registro UX\Settings actualizado (Defer* + BranchReadinessLevel).' '  UX\Settings registry updated (Defer* + BranchReadinessLevel).')
W ok (L2 'Updates de caracteristicas retrasadas 365 dias y de seguridad 4 dias (estilo Pro).' 'Feature updates deferred 365 days and security updates 4 days (Pro style).')
'@ }
    @{ Name='Pausar todas las actualizaciones 5 semanas'; Risk='Seguro'
       Desc='Pausa updates hasta dentro de 35 dias. Reanudable con "Valores por defecto".'
       Code=@'
if (-not $isAdmin) { throw (L2 'Requiere ejecutar WPI como administrador (clic derecho > Ejecutar como administrador).' 'Requires running WPI as administrator (right-click > Run as administrator).') }
$k="HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$now=(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$end=(Get-Date).AddDays(35).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
reg add $k /v PauseUpdatesStartTime /t REG_SZ /d $now /f | Out-Null
reg add $k /v PauseUpdatesExpiryTime /t REG_SZ /d $end /f | Out-Null
reg add $k /v PauseFeatureUpdatesStartTime /t REG_SZ /d $now /f | Out-Null
reg add $k /v PauseFeatureUpdatesEndTime /t REG_SZ /d $end /f | Out-Null
reg add $k /v PauseQualityUpdatesStartTime /t REG_SZ /d $now /f | Out-Null
reg add $k /v PauseQualityUpdatesEndTime /t REG_SZ /d $end /f | Out-Null
W dim (L2 '  6 marcas de pausa escritas en el registro.' '  6 pause markers written to the registry.')
W ok (L2 ("Actualizaciones pausadas hasta {0} (UTC)." -f $end) ("Updates paused until {0} (UTC)." -f $end))
'@ }
    @{ Name='Valores por defecto de Windows Update'; Risk='Seguro'
       Desc='Quita todos los retrasos/pausas, reactiva servicios y tareas. Vuelve al comportamiento normal.'
       Code=@'
if (-not $isAdmin) { throw (L2 'Requiere ejecutar WPI como administrador (clic derecho > Ejecutar como administrador).' 'Requires running WPI as administrator (right-click > Run as administrator).') }
$k="HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
foreach ($val in 'DeferFeatureUpdates','DeferFeatureUpdatesPeriodInDays','DeferQualityUpdates','DeferQualityUpdatesPeriodInDays','BranchReadinessLevel','PauseUpdatesStartTime','PauseUpdatesExpiryTime','PauseFeatureUpdatesStartTime','PauseFeatureUpdatesEndTime','PauseQualityUpdatesStartTime','PauseQualityUpdatesEndTime') {
    reg delete $k /v $val /f 2>$null | Out-Null
}
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f 2>$null | Out-Null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /f 2>$null | Out-Null
W dim (L2 '  registro de retrasos/pausas/politicas eliminado.' '  defer/pause/policy registry removed.')
# Servicios a su arranque por defecto (Start: 2=Auto, 3=Manual). Se fija por
# registro (robusto incluso para servicios protegidos) y ademas Set-Service.
$svcDefaults = @{ wuauserv=3; UsoSvc=2; BITS=3; DoSvc=2; WaaSMedicSvc=3 }
foreach ($svc in $svcDefaults.Keys) {
    reg add ("HKLM\SYSTEM\CurrentControlSet\Services\{0}" -f $svc) /v Start /t REG_DWORD /d $svcDefaults[$svc] /f 2>$null | Out-Null
    $stype = if ($svcDefaults[$svc] -eq 2) { 'Automatic' } else { 'Manual' }
    Set-Service $svc -StartupType $stype -ErrorAction SilentlyContinue
}
foreach ($svc in 'BITS','wuauserv','UsoSvc') { Start-Service $svc -ErrorAction SilentlyContinue }
W dim (L2 '  servicios BITS/wuauserv/UsoSvc/DoSvc/WaaSMedicSvc restaurados.' '  services BITS/wuauserv/UsoSvc/DoSvc/WaaSMedicSvc restored.')
# Re-habilitar tareas programadas de Windows Update
foreach ($tp in '\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\','\Microsoft\Windows\WaaSMedic\') {
    try { Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null } catch {}
}
W dim (L2 '  tareas programadas de Windows Update rehabilitadas.' '  Windows Update scheduled tasks re-enabled.')
W ok (L2 'Windows Update restaurado a los valores por defecto. Reinicia para aplicarlo del todo.' 'Windows Update restored to defaults. Reboot to fully apply.')
'@ }
    @{ Name='Desactivar Windows Update por completo'; Risk='Avanzado'
       Warn='AVISO: desactivar las actualizaciones deja tu PC SIN parches de seguridad. Hazlo solo de forma temporal y reactivalo con "Valores por defecto". Continuar?'
       Desc='Detiene y deshabilita los servicios de actualizacion. Solo temporal y bajo tu responsabilidad.'
       Code=@'
if (-not $isAdmin) { throw (L2 'Requiere ejecutar WPI como administrador (clic derecho > Ejecutar como administrador).' 'Requires running WPI as administrator (right-click > Run as administrator).') }
# 1) Registro: politica NoAutoUpdate + ocultar updates de Configuracion (como WinUtil).
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 1 /f | Out-Null
W dim (L2 '  registro: NoAutoUpdate=1 y updates ocultas de Configuracion.' '  registry: NoAutoUpdate=1 and updates hidden from Settings.')
# 2) Servicios: detener y deshabilitar (Start=4 por registro para los protegidos).
foreach ($svc in 'BITS','wuauserv','UsoSvc','DoSvc','WaaSMedicSvc') {
    try { Stop-Service $svc -Force -ErrorAction SilentlyContinue } catch {}
    reg add ("HKLM\SYSTEM\CurrentControlSet\Services\{0}" -f $svc) /v Start /t REG_DWORD /d 4 /f 2>$null | Out-Null
    Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
    W dim (L2 ('  servicio {0} detenido y deshabilitado.' -f $svc) ('  service {0} stopped and disabled.' -f $svc))
}
# 3) Limpiar la cache de descargas (SoftwareDistribution).
$sd = Join-Path $env:WINDIR 'SoftwareDistribution'
try { Remove-Item (Join-Path $sd '*') -Recurse -Force -ErrorAction SilentlyContinue; W dim (L2 '  carpeta SoftwareDistribution limpiada.' '  SoftwareDistribution folder cleared.') } catch {}
# 4) Deshabilitar tareas programadas relacionadas con Windows Update.
foreach ($tp in '\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\','\Microsoft\Windows\WaaSMedic\') {
    try { Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null } catch {}
}
W dim (L2 '  tareas programadas de Windows Update deshabilitadas.' '  Windows Update scheduled tasks disabled.')
W warn (L2 'Windows Update DESACTIVADO (registro + servicios + cache + tareas). Reinicia para que surta efecto total. Reactivalo con "Valores por defecto".' 'Windows Update DISABLED (registry + services + cache + tasks). Reboot to fully apply. Re-enable it with "Windows Update defaults".')
'@ }
)
$WindowsUpdateLinks = @(
    @{ Name='Abrir Windows Update'; Uri='ms-settings:windowsupdate' }
    @{ Name='Buscar actualizaciones ahora'; Uri='ms-settings:windowsupdate-action' }
)
# ============================================================

# ============== REPARAR Y HERRAMIENTAS ======================
# Comandos de reparacion que corren por el motor de tweaks (con log).
$RepairTools = @(
    @{ Name='Comprobar archivos del sistema (SFC)'; Risk='Seguro'
       Desc='Ejecuta sfc /scannow para reparar archivos de Windows danados. Puede tardar.'
       Code=@'
W info "Ejecutando sfc /scannow (puede tardar varios minutos)..."
$o = (& sfc /scannow 2>&1 | Out-String)
foreach ($ln in ($o -split "[`r`n]+")) { $ln=$ln.Trim(); if ($ln) { W dim ('  '+$ln) } }
W ok "SFC terminado."
'@ }
    @{ Name='Reparar imagen de Windows (DISM RestoreHealth)'; Risk='Seguro'
       Desc='DISM /Online /Cleanup-Image /RestoreHealth. Repara el almacen de componentes. Puede tardar.'
       Code=@'
W info "Ejecutando DISM RestoreHealth (puede tardar)..."
$o = (& dism /online /cleanup-image /restorehealth 2>&1 | Out-String)
foreach ($ln in ($o -split "[`r`n]+")) { $ln=$ln.Trim(); if ($ln) { W dim ('  '+$ln) } }
W ok "DISM terminado."
'@ }
    @{ Name='Restablecer la red (Winsock/TCP-IP/DNS)'; Risk='Avanzado'
       Warn='Esto reinicia la pila de red. Perderas la conexion un momento y conviene REINICIAR despues. Continuar?'
       Desc='netsh winsock reset + int ip reset + flush DNS + renovar IP. Requiere reiniciar.'
       Code=@'
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
ipconfig /flushdns | Out-Null
ipconfig /release | Out-Null
ipconfig /renew | Out-Null
W ok "Pila de red restablecida. REINICIA el equipo para terminar."
'@ }
    @{ Name='Reparar Windows Update (limpiar cache)'; Risk='Seguro'
       Desc='Para los servicios, renombra SoftwareDistribution y catroot2, y reinicia. Arregla updates atascadas.'
       Code=@'
foreach ($s in 'wuauserv','cryptSvc','bits','msiserver') { Stop-Service $s -Force -ErrorAction SilentlyContinue }
$sd="$env:SystemRoot\SoftwareDistribution"; $cr="$env:SystemRoot\System32\catroot2"
if (Test-Path $sd) { Rename-Item $sd ($sd+'.old') -Force -ErrorAction SilentlyContinue }
if (Test-Path $cr) { Rename-Item $cr ($cr+'.old') -Force -ErrorAction SilentlyContinue }
foreach ($s in 'wuauserv','cryptSvc','bits','msiserver') { Start-Service $s -ErrorAction SilentlyContinue }
W ok "Cache de Windows Update limpiada. Vuelve a buscar actualizaciones."
'@ }
    @{ Name='Limpiar la cache de Microsoft Store'; Risk='Seguro'
       Desc='Ejecuta wsreset para arreglar la Store y descargas atascadas.'
       Code=@'
Start-Process wsreset.exe -WindowStyle Hidden
W ok "wsreset lanzado: la Store se limpiara en unos segundos."
'@ }
    @{ Name='Reconstruir el indice de busqueda'; Risk='Seguro'
       Desc='Fuerza a Windows a reindexar (arregla la busqueda lenta o sin resultados).'
       Code=@'
reg add "HKLM\SOFTWARE\Microsoft\Windows Search" /v SetupCompletedSuccessfully /t REG_DWORD /d 0 /f | Out-Null
Restart-Service WSearch -Force -ErrorAction SilentlyContinue
W ok "Reindexado iniciado. Puede tardar un rato en completarse en segundo plano."
'@ }
    @{ Name='Reparar/Resetear winget'; Risk='Seguro'
       Desc='Resetea las fuentes de winget y acepta acuerdos. Arregla errores de catalogo y descargas.'
       Code=@'
try { winget source reset --force 2>&1 | Out-Null } catch {}
try { winget source update 2>&1 | Out-Null } catch {}
try { winget list --accept-source-agreements 2>&1 | Out-Null } catch {}
W ok "Fuentes de winget reseteadas y actualizadas."
'@ }
)
# ============================================================
# B1: CARACTERISTICAS OPCIONALES Y CAPABILITIES DE WINDOWS
# Kind = 'feature'    -> Enable/Disable-WindowsOptionalFeature (DISM)
# Kind = 'capability' -> Add/Remove-WindowsCapability (DISM)
# Reboot = $true para las que piden reiniciar. Risk 'Avanzado' = mayor impacto.
# ============================================================
$FeaturesCatalog = @(
    @{ Name='.NET Framework 3.5 (incluye 2.0 y 3.0)'; Kind='feature'; Id='NetFx3'; Risk='Seguro'; Reboot=$false
       Desc='Runtime necesario para muchos programas antiguos. Descarga componentes de Windows Update.' }
    @{ Name='Cliente Telnet'; Kind='feature'; Id='TelnetClient'; Risk='Seguro'; Reboot=$false
       Desc='Cliente de linea de comandos Telnet para diagnostico de red.' }
    @{ Name='Visor de XPS'; Kind='feature'; Id='Printing-XPSServices-Features'; Risk='Seguro'; Reboot=$false
       Desc='Soporte para documentos XPS (impresion y visor).' }
    @{ Name='Plataforma del hipervisor de Windows'; Kind='feature'; Id='HypervisorPlatform'; Risk='Avanzado'; Reboot=$true
       Desc='API de virtualizacion usada por emuladores y sandboxes. Pide reinicio.' }
    @{ Name='Plataforma de maquina virtual (WSL2)'; Kind='feature'; Id='VirtualMachinePlatform'; Risk='Avanzado'; Reboot=$true
       Desc='Necesaria para WSL2 y contenedores. Pide reinicio.' }
    @{ Name='Subsistema de Windows para Linux (WSL)'; Kind='feature'; Id='Microsoft-Windows-Subsystem-Linux'; Risk='Avanzado'; Reboot=$true
       Desc='Ejecuta distribuciones Linux dentro de Windows. Pide reinicio.' }
    @{ Name='Plataforma Hyper-V (completa)'; Kind='feature'; Id='Microsoft-Hyper-V-All'; Risk='Avanzado'; Reboot=$true
       Desc='Hipervisor y herramientas de Hyper-V (solo Pro/Enterprise). Pide reinicio.' }
    @{ Name='Sandbox de Windows'; Kind='feature'; Id='Containers-DisposableClientVM'; Risk='Avanzado'; Reboot=$true
       Desc='Escritorio desechable y aislado para probar software (solo Pro/Enterprise). Pide reinicio.' }
    @{ Name='WordPad'; Kind='capability'; Id='Microsoft.Windows.WordPad~~~~0.0.1.0'; Risk='Seguro'; Reboot=$false
       Desc='Editor de texto enriquecido clasico de Windows.' }
    @{ Name='Bloc de notas (clasico)'; Kind='capability'; Id='Microsoft.Windows.Notepad.System~~~~0.0.1.0'; Risk='Seguro'; Reboot=$false
       Desc='Version de sistema del Bloc de notas.' }
    @{ Name='Cliente OpenSSH'; Kind='capability'; Id='OpenSSH.Client~~~~0.0.1.0'; Risk='Seguro'; Reboot=$false
       Desc='Cliente SSH oficial para conexiones seguras desde la consola.' }
)
# Paneles clasicos de Windows (se abren con su comando).
$SystemPanels = @(
    @{ Name='Panel de control'; Cmd='control' }
    @{ Name='Programas y caracteristicas'; Cmd='appwiz.cpl' }
    @{ Name='Propiedades del sistema'; Cmd='sysdm.cpl' }
    @{ Name='Opciones de energia'; Cmd='powercfg.cpl' }
    @{ Name='Conexiones de red'; Cmd='ncpa.cpl' }
    @{ Name='Sonido'; Cmd='mmsys.cpl' }
    @{ Name='Servicios'; Cmd='services.msc' }
    @{ Name='Administrador de dispositivos'; Cmd='devmgmt.msc' }
    @{ Name='Administrador de discos'; Cmd='diskmgmt.msc' }
    @{ Name='Editor de directivas (gpedit)'; Cmd='gpedit.msc' }
    @{ Name='Liberador de espacio'; Cmd='cleanmgr' }
    @{ Name='Informacion del sistema'; Cmd='msinfo32' }
)
# ============================================================

# ===================== GUIAS (es-ES) ========================
# Mini-tutoriales en espanol de Espana. Key = Id de winget del
# programa (para avisar al instalar/descargar) o un nombre libre
# para herramientas que NO estan en winget. 'Win' = $true si el
# programa esta en el catalogo winget; si es $false, la guia
# explica de donde bajarlo (GitHub/web) porque no esta en winget.
$Guides = [ordered]@{
  'Libretro.RetroArch' = @{ Title = 'RetroArch (multi-emulador)'; Win = $true; Steps = @'
RetroArch funciona con "cores" (nucleos), uno por sistema.
1) Abrelo y ve a "Online Updater" > "Core Downloader".
2) Descarga el core del sistema que quieras (ej: "Beetle PSX", "Snes9x").
3) "Online Updater" > actualiza assets, info de cores y bases de datos.
4) Carga juegos con "Load Content". Para discos/BIOS, copia tus
   archivos a la carpeta "system" de RetroArch.
5) Configura el mando en "Settings" > "Input".
Nota: las BIOS y los juegos debes obtenerlos de tus propios equipos/copias.
'@ }
  'PCSX2Team.PCSX2' = @{ Title = 'PCSX2 (PlayStation 2)'; Win = $true; Steps = @'
PCSX2 NECESITA la BIOS de tu propia PS2.
1) En tu PS2, vuelca la BIOS (homebrew como "BIOS Dumper") a un USB.
2) Abre PCSX2 > asistente inicial > pestana BIOS > anade la carpeta
   donde pusiste el volcado y seleccionala.
3) Configura el mando en Settings > Controllers.
4) Carga el juego (ISO de tu propio disco) con "Start File".
Recomendado: renderer Vulkan o Direct3D 12 si tu GPU lo soporta.
'@ }
  'RPCS3.RPCS3' = @{ Title = 'RPCS3 (PlayStation 3)'; Win = $true; Steps = @'
RPCS3 necesita el firmware OFICIAL de PS3.
1) Descarga "PS3UPDAT.PUP" desde la web oficial de PlayStation.
2) En RPCS3: File > Install Firmware > selecciona el .PUP.
3) Anade juegos con File > Add Games (de tus propias copias).
4) Ajusta CPU/GPU en Configuration; Vulkan suele ir mejor.
Consejo: revisa la wiki de compatibilidad de cada juego.
'@ }
  'DolphinEmulator.Dolphin' = @{ Title = 'Dolphin (GameCube / Wii)'; Win = $true; Steps = @'
Dolphin no necesita BIOS.
1) Abre Dolphin > "Config" > pestana "Paths" > anade la carpeta de juegos.
2) Configura el mando o el de Wii en "Controllers".
3) Para Wii, en "Wii" puedes ajustar idioma y sensor.
4) Carga el juego (de tus propias copias) haciendo doble clic.
Consejo: backend Vulkan o D3D12 para mejor rendimiento.
'@ }
  'Stenzek.DuckStation' = @{ Title = 'DuckStation (PlayStation 1)'; Win = $true; Steps = @'
DuckStation necesita la BIOS de PS1.
1) Coloca tu BIOS de PS1 (de tu propia consola) en la carpeta "bios".
2) Asistente inicial > selecciona la carpeta de BIOS y la de juegos.
3) Configura el mando en Settings > Controllers.
4) Carga el juego (de tus copias). Activa "PGXP" para mejor 3D.
'@ }
  'Cemu.Cemu' = @{ Title = 'Cemu (Wii U)'; Win = $true; Steps = @'
1) Coloca tu "keys.txt" (claves de tu propia consola) junto a Cemu.
2) Anade la carpeta de juegos en Options > General.
3) Instala actualizaciones/DLC de tus juegos con File > Install update/DLC.
4) Usa "Graphic Packs" para mejoras (resolucion, FPS).
5) Configura el mando en Options > Input settings.
'@ }
  'PPSSPPTeam.PPSSPP' = @{ Title = 'PPSSPP (PSP)'; Win = $true; Steps = @'
No necesita BIOS.
1) Abrelo y en "Juegos" anade la carpeta con tus ISO/CSO propios.
2) Ajustes > Graficos: sube la resolucion de render (x2, x3...).
3) Ajustes > Controles: configura el mando o el tactil.
Sencillo y muy compatible.
'@ }
  'Vita3K.Vita3K' = @{ Title = 'Vita3K (PS Vita) - experimental'; Win = $true; Steps = @'
Vita3K es experimental; compatibilidad variable.
1) Primera ejecucion: te pedira el firmware de PS Vita (de la web oficial).
2) Instala el firmware y luego tus juegos/copias propias.
3) Revisa la lista de compatibilidad del proyecto antes de esperar que
   un juego funcione perfecto.
'@ }
  'EDEN_SWITCH' = @{ Title = 'Emulador de Switch (Eden / Citron) - NO esta en winget'; Win = $false; Steps = @'
Tras el cierre de yuzu/Ryujinx (2024) los forks vivos como EDEN o
CITRON NO se distribuyen por winget. Como conseguir la ultima version:
1) Busca el proyecto vigente (Eden / Citron) en su pagina oficial o
   repositorio (GitHub/GitLab). Descarga la "release" mas reciente para
   Windows (suele ser un .zip o .7z portable).
2) Descomprimelo en una carpeta (por ejemplo dentro de "Descargas").
3) NECESITAS las claves (prod.keys) y el firmware de TU PROPIA Switch,
   volcados con tu consola. Sin ellos no arranca nada.
4) En el emulador: File > Open/Install Keys y carga prod.keys; instala
   el firmware. Anade la carpeta de tus juegos (volcados propios).
5) Configura el mando y el backend grafico (Vulkan recomendado).
Aviso: la escena cambia rapido; usa siempre la web oficial del proyecto
y desconfia de copias en sitios raros.
'@ }
  'ANDROID_EMU' = @{ Title = 'Emuladores de Android (los mas top)'; Win = $false; Steps = @'
Opciones mas recomendadas segun para que lo quieras:
- Google Play Games en PC (oficial de Google): lo mas limpio para jugar
  a moviles compatibles. Descargalo de la web oficial de Google.
- Android Studio (emulador oficial AVD): ideal para desarrollo/pruebas;
  ese SI esta en winget (busca "Android Studio" en el buscador).
- Waydroid: solo Linux.
- BlueStacks / LDPlayer / MEmu / MuMu: muy usados para juegos, pero
  REVISA bien el instalador (algunos meten "extras"/publicidad). Bajalos
  solo de su web oficial y desmarca lo que no quieras durante la
  instalacion.
Consejo: para rendimiento, activa la virtualizacion (VT-x/AMD-V) en la
BIOS de tu placa.
'@ }
}
# Web oficial por guia (para el boton "Abrir web oficial")
$GuideWeb = @{
  'Libretro.RetroArch'             = 'https://www.retroarch.com'
  'PCSX2Team.PCSX2'                = 'https://pcsx2.net'
  'RPCS3.RPCS3'                    = 'https://rpcs3.net'
  'DolphinEmulator.Dolphin'        = 'https://dolphin-emu.org'
  'Stenzek.DuckStation'            = 'https://www.duckstation.org'
  'Cemu.Cemu'                      = 'https://cemu.info'
  'PPSSPPTeam.PPSSPP'              = 'https://www.ppsspp.org'
  'Vita3K.Vita3K'                  = 'https://vita3k.org'
}
# --- GUIAS EXTERNAS EDITABLES (guias.json junto al script) ---
# Si existe, anade o sustituye guias sin tocar el codigo.
# Formato: [ { "Key":"Editor.App", "Title":"...", "Win":true,
#              "Web":"https://...", "Steps":"linea1\nlinea2..." }, ... ]
$GuidesFile = (Join-Path $PSScriptRoot 'guias.json')
function Import-ExternalGuides {
    if (-not (Test-Path $script:GuidesFile)) { return }
    try {
        $data = Get-Content $script:GuidesFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($e in @($data)) {
            if ($e.Key -and $e.Title -and $e.Steps) {
                $script:Guides[[string]$e.Key] = @{ Title = [string]$e.Title; Win = [bool]$e.Win; Steps = [string]$e.Steps }
                if ($e.Web) { $script:GuideWeb[[string]$e.Key] = [string]$e.Web }
            }
        }
    } catch { Write-Warning ("guias.json no se pudo leer: {0}" -f $_.Exception.Message) }
}
Import-ExternalGuides
function Export-GuidesTemplate {
    try {
        $arr = @()
        foreach ($k in $script:Guides.Keys) {
            $g = $script:Guides[$k]
            $arr += [ordered]@{ Key = $k; Title = $g.Title; Win = [bool]$g.Win; Web = ([string]$script:GuideWeb[$k]); Steps = $g.Steps }
        }
        Set-WpiContent -Path $script:GuidesFile -Value ($arr | ConvertTo-Json -Depth 4)
        return $true
    } catch { return $false }
}
# ============================================================
function Get-CodeMeaning {
    param([int]$Code)
    $hex = '0x{0:X8}' -f $Code
    switch ($hex) {
        '0x00000000' { return @{Ok=$true;  Msg='instalada correctamente'} }
        '0x00000BBA' { return @{Ok=$true;  Msg='instalada (3010: requiere reiniciar el equipo)'} }
        '0x00000669' { return @{Ok=$true;  Msg='instalada (1641: el instalador inicio un reinicio)'} }
        '0x8A15002B' { return @{Ok=$true;  Msg='ya estaba instalada / sin actualizacion aplicable'} }
        '0x8A15002C' { return @{Ok=$true;  Msg='ya estaba actualizada a la ultima version'} }
        '0x8A150014' { return @{Ok=$false; Msg='ID no encontrado en el repositorio de winget'} }
        '0x8A150044' { return @{Ok=$false; Msg='se requiere aceptar acuerdos de la fuente'} }
        '0x8A15010B' { return @{Ok=$false; Msg='requiere una version de Windows superior'} }
        '0x8A150056' { return @{Ok=$false; Msg='descarga interrumpida (red)'; Retry=$true} }
        '0x8A150201' { return @{Ok=$false; Msg='el instalador devolvio error'} }
        '0x80072EE7' { return @{Ok=$false; Msg='sin conexion / DNS (red)'; Retry=$true} }
        '0x80072EFD' { return @{Ok=$false; Msg='no se pudo conectar al servidor (red)'; Retry=$true} }
        '0x00000643' { return @{Ok=$false; Msg='1603: error fatal del instalador MSI'} }
        '0x00000652' { return @{Ok=$false; Msg='1618: otra instalacion MSI en curso (reintentable)'; Retry=$true} }
        '0x00000642' { return @{Ok=$false; Msg='1602: instalacion cancelada por el usuario'} }
        '0x000003E5' { return @{Ok=$false; Msg='1001: operacion en curso, reintentar'; Retry=$true} }
        '0xFFFFFFFF' { return @{Ok=$false; Msg='el proceso fue terminado (watchdog o cancelacion)'} }
        default      { return @{Ok=$false; Msg=('fallo con codigo {0}' -f $hex)} }
    }
}

function Resolve-Winget {
    # Activa winget en cascada, con TODO reflejado en consola. Orden pedido:
    # 1) lo que ya hay en Windows (rapido)  2) ONLINE (descarga de Microsoft)
    # 3) OFFLINE (bundle inyectado en C:\WPI\winget, la opcion segura).
    $findExe = {
        try {
            Get-ChildItem (Join-Path $env:ProgramFiles 'WindowsApps') -Filter 'Microsoft.DesktopAppInstaller_*' -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'winget.exe' } |
                Where-Object { Test-Path $_ } | Select-Object -First 1
        } catch { $null }
    }
    $ok = { if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }; $e = & $findExe; if ($e) { $env:Path = (Split-Path $e) + ';' + $env:Path }; [bool](Get-Command winget -ErrorAction SilentlyContinue) }

    if (& $ok) { Write-Host '[OK] winget ya esta disponible.' -ForegroundColor Green; return $true }

    # 1) Registrar el App Installer que Windows 11 ya trae (lo normal en primer arranque)
    Write-Host '[~] Activando winget: registrando el App Installer de Windows...' -ForegroundColor DarkCyan
    try {
        Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | ForEach-Object {
            $man = Join-Path $_.InstallLocation 'AppXManifest.xml'
            if (Test-Path $man) { Add-AppxPackage -DisableDevelopmentMode -Register $man -ErrorAction SilentlyContinue }
        }
    } catch {}
    if (& $ok) { Write-Host '[OK] winget activado (registro del App Installer).' -ForegroundColor Green; return $true }

    # 1b) Reintentos: el aprovisionamiento del sistema puede estar terminando
    Write-Host '[~] winget aun no responde; esperando a que Windows termine de prepararlo...' -ForegroundColor DarkCyan
    for ($i = 1; $i -le 4; $i++) {
        Start-Sleep -Seconds 8
        Write-Host ('    reintento {0}/4...' -f $i) -ForegroundColor DarkGray
        if (& $ok) { Write-Host '[OK] winget activado tras la espera.' -ForegroundColor Green; return $true }
    }

    # 2) ONLINE: descargar de Microsoft (preferente si hay internet)
    try {
        Write-Host '[~] ONLINE: descargando winget de Microsoft (aka.ms/getwinget)...' -ForegroundColor DarkCyan
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
        $tmp = Join-Path $env:TEMP 'AppInstaller.msixbundle'
        Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $tmp -UseBasicParsing -TimeoutSec 180
        Write-Host '    descargado; instalando...' -ForegroundColor DarkGray
        Add-AppxPackage -Path $tmp -ErrorAction Stop
        Start-Sleep -Seconds 4
        if (& $ok) { Write-Host '[OK] winget instalado (descarga online).' -ForegroundColor Green; return $true }
    } catch { Write-Host ('    online fallo: {0}' -f $_.Exception.Message) -ForegroundColor DarkYellow }

    # 3) OFFLINE: bundle inyectado en C:\WPI\winget (la opcion segura)
    try {
        $local = Join-Path $PSScriptRoot 'winget'
        if (Test-Path $local) {
            Write-Host '[~] OFFLINE: instalando winget desde C:\WPI\winget (inyectado en la ISO)...' -ForegroundColor DarkCyan
            foreach ($ext in @('*.appx','*.msix','*.msixbundle')) {
                Get-ChildItem $local -Filter $ext -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Host ('    instalando ' + $_.Name + ' ...') -ForegroundColor DarkGray
                    Add-AppxPackage -Path $_.FullName -ErrorAction SilentlyContinue
                }
            }
            Start-Sleep -Seconds 3
            if (& $ok) { Write-Host '[OK] winget instalado (offline desde la ISO).' -ForegroundColor Green; return $true }
        } else {
            Write-Host '[~] No hay bundle offline en C:\WPI\winget.' -ForegroundColor DarkYellow
        }
    } catch { Write-Host ('    offline fallo: {0}' -f $_.Exception.Message) -ForegroundColor DarkYellow }

    return $false
}

function Test-Winget {
    # YA NO mata el script: intenta activar winget y devuelve si lo logro.
    if (Resolve-Winget) { return $true }
    Write-Host '[X] winget no se pudo activar en este arranque.' -ForegroundColor Red
    Write-Host '    Las APPS se omiten; tweaks, modo oscuro y debloat SI se aplican.' -ForegroundColor Yellow
    return $false
}

function Invoke-SelfUpdate {
    if (-not $Config.SelfUpdateUrl) { return }
    try {
        Write-Host '[+] Comprobando si hay una version nueva del propio WPI...' -ForegroundColor DarkCyan
        $remote = (Invoke-WebRequest -Uri $Config.SelfUpdateUrl -UseBasicParsing -TimeoutSec 10).Content
        $rx = '\$WpiVersion\s*=\s*''([0-9\.]+)'''
        if ($remote -match $rx) {
            $rv = [version]$Matches[1]
            if ($rv -gt [version]$WpiVersion) {
                Write-Host ('[+] Nueva version {0} disponible (tienes la {1}). Actualizando...' -f $rv, $WpiVersion) -ForegroundColor Yellow
                Copy-Item -Path $PSCommandPath -Destination "$PSCommandPath.bak" -Force
                Set-WpiContent -Path $PSCommandPath -Value $remote -Bom
                Write-Host '[OK] WPI actualizado. Reiniciando...' -ForegroundColor Green
                Start-Process powershell -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath)
                exit 0
            } else {
                Write-Host ('[OK] El WPI ya esta en su ultima version ({0}).' -f $WpiVersion) -ForegroundColor DarkGreen
            }
        }
    } catch {
        Write-Host '[~] No se pudo comprobar la actualizacion del WPI (sin conexion o URL no valida).' -ForegroundColor DarkYellow
    }
}

function Update-WingetSources {
    if (-not $Config.AutoUpdateSources) { return }
    Write-Host '[+] Refrescando el catalogo y los enlaces de winget...' -ForegroundColor DarkCyan
    winget source update | Out-Null
    Write-Host '[OK] Fuentes de winget al dia.' -ForegroundColor DarkGreen
}

# Instalacion secuencial en consola (modo -Preset desatendido)
function Invoke-WingetInstall {
    param([string[]]$Ids)
    if (-not $Ids -or @($Ids).Count -eq 0) {
        Write-Host '[~] No hay aplicaciones seleccionadas.' -ForegroundColor Yellow
        return
    }
    $ok = @(); $fail = @()
    $i = 0
    foreach ($id in $Ids) {
        $i++
        Write-Host ''
        Write-Host ('==[ {0}/{1} ]== Instalando {2} ...' -f $i, @($Ids).Count, $id) -ForegroundColor Cyan
        winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
        $m = Get-CodeMeaning -Code $LASTEXITCODE
        if ($m.Ok) {
            $ok += ('{0} - {1}' -f $id, $m.Msg)
            Write-Host ('[OK] {0} - {1}' -f $id, $m.Msg) -ForegroundColor Green
            if ($id -eq 'Discord.Discord') {
                try {
                    $sh = New-Object -ComObject WScript.Shell
                    $shortcuts = @(
                        (Join-Path $env:USERPROFILE "Desktop\Discord.lnk"),
                        (Join-Path $env:USERPROFILE "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc\Discord.lnk")
                    )
                    foreach ($path in $shortcuts) {
                        if (Test-Path $path) {
                            $lnk = $sh.CreateShortcut($path)
                            $lnk.Arguments = '--processStart Discord.exe --process-start-args "--no-sandbox"'
                            $lnk.Save()
                            Write-Host ("  [+] Parcheado acceso directo de Discord: {0}" -f (Split-Path $path -Leaf)) -ForegroundColor Green
                        }
                    }
                } catch {}
            }
        } else {
            $fail += ('{0} - {1}' -f $id, $m.Msg)
            Write-Host ('[X] {0} - {1}' -f $id, $m.Msg) -ForegroundColor Red
        }
    }
    Write-Host ''
    Write-Host '====================================================' -ForegroundColor Cyan
    Write-Host ('  RESUMEN: {0} correctas, {1} fallidas' -f @($ok).Count, @($fail).Count) -ForegroundColor Cyan
    Write-Host '====================================================' -ForegroundColor Cyan
    foreach ($o in $ok)   { Write-Host ('  [OK] {0}' -f $o) -ForegroundColor Green }
    foreach ($f in $fail) { Write-Host ('  [X]  {0}' -f $f) -ForegroundColor Red }
    if (@($fail).Count -gt 0) {
        Write-Host ''
        Write-Host '  Sugerencia: las que fallen con --silent suelen instalarse' -ForegroundColor Yellow
        Write-Host '  bien repitiendo a mano: winget install --id <ID> -e' -ForegroundColor Yellow
    }
}

# ============================================================
#  Cambio 6 - Reintento diferido de apps problematicas (RunOnce, contexto usuario)
# ============================================================
# Algunas apps (p. ej. Discord) NO soportan instalarse en el contexto SYSTEM/elevado
# del primer logon desatendido: el instalador se cuelga con 0xC0000005 (codigo
# 3221225477) y la app no queda instalada. Para esas apps, en el primer arranque
# (-FirstBoot) se DIFIERE la instalacion a un RunOnce en HKCU del usuario que ha
# iniciado sesion (Rebel via autologon): se ejecutara en su proximo inicio de sesion
# interactivo tras el reinicio, en contexto de usuario (no elevado). Fuera del primer
# arranque (GUI/CLI normal) NO se difiere nada (comportamiento actual).
# Lista extensible: agrega aqui mas IDs si aparecen otras apps con el mismo problema.
$script:DeferredFirstLogonAppIds = @('Discord.Discord')

# Apps que deben instalarse SIEMPRE en ambito de usuario (--scope user) aunque el
# selector de ambito este en "Auto": en ambito machine entran en un bucle de
# actualizacion / se cuelgan al arrancar (caso tipico de Discord). Forzar user
# evita el clasico "Update Failed" y que la app no llegue a abrir.
$script:UserScopeAppIds = @('Discord.Discord')

# Escribe <Root>\reintento_apps.ps1 con los IDs diferidos y registra un RunOnce en
# HKCU que lo lance en el primer inicio de sesion del usuario. Devuelve $true si se
# registro correctamente, $false en caso de error (para poder hacer fallback).
function Register-DeferredAppRetry {
    param([string[]]$Ids, [string]$RootDir)
    if (-not $Ids -or @($Ids).Count -eq 0) { return $false }
    try {
        $scriptPath = Join-Path $RootDir 'reintento_apps.ps1'
        $logDirDef  = Join-Path $RootDir 'logs'
        # Lista de IDs como literales PowerShell, con comillas simples escapadas.
        $idList = ($Ids | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ', '
        # Contenido del script de reintento. Las variables con backtick (`$) quedan
        # LITERALES en el archivo generado; $idList y $logDirDef se interpolan ahora.
        $retryText = @"
# WPI - Reintento diferido de apps problematicas en contexto de usuario.
# Generado automaticamente por el primer arranque (lanzado via RunOnce en HKCU).
# Estas apps (p. ej. Discord) se cuelgan al instalarse como SYSTEM/admin en el
# primer logon (0xC0000005 / 3221225477); aqui se instalan ya en sesion de usuario.
`$ErrorActionPreference = 'Continue'
`$ids    = @($idList)
`$logDir = '$logDirDef'
try { if (-not (Test-Path `$logDir)) { New-Item -ItemType Directory -Path `$logDir -Force | Out-Null } } catch {}
`$log = Join-Path `$logDir ('reintento_apps_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
function RLog(`$m) { `$s = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), `$m); Write-Host `$s; try { Add-Content -Path `$log -Value `$s } catch {} }
RLog ('Reintento diferido de apps: {0}' -f (`$ids -join ', '))
foreach (`$id in `$ids) {
    RLog ('==[ Instalando {0} ]==' -f `$id)
    try {
        winget install --id `$id -e --silent --scope user --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { RLog `$_ }
        RLog ('Resultado winget para {0}: codigo {1}' -f `$id, `$LASTEXITCODE)
    } catch {
        RLog ('[X] Error instalando {0}: {1}' -f `$id, `$_.Exception.Message)
    }
}
# Parchear accesos directos de Discord tras la instalacion diferida
try {
    `$sh = New-Object -ComObject WScript.Shell
    `$shortcuts = @(
        (Join-Path `$env:USERPROFILE "Desktop\Discord.lnk"),
        (Join-Path `$env:USERPROFILE "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc\Discord.lnk")
    )
    foreach (`$path in `$shortcuts) {
        if (Test-Path `$path) {
            `$lnk = `$sh.CreateShortcut(`$path)
            `$lnk.Arguments = '--processStart Discord.exe --process-start-args \"--no-sandbox\"'
            `$lnk.Save()
            RLog ("Parcheado acceso directo de Discord: " + `$path)
        }
    }
} catch {
    RLog ("Error al parchear acceso directo de Discord: " + `$_.Exception.Message)
}
RLog 'Reintento diferido finalizado.'
"@
        Set-WpiContent -Path $scriptPath -Value $retryText -Bom
        $runOnceCmd = ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $scriptPath)
        reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce' /v 'WPI_ReintentoApps' /t REG_SZ /d $runOnceCmd /f 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'reg add devolvio un codigo de error al registrar el RunOnce.' }
        return $true
    } catch {
        Write-Host ('[X] No se pudo registrar el reintento diferido: {0}' -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# ---- Modo desatendido (CLI): tweaks / debloat / update sin GUI ----
# W: equivalente de consola del logger del motor, para que el mismo Code de
# cada tweak (que usa "W ok/err/...") funcione tal cual fuera de la GUI.
function W {
    param([string]$t, [string]$m)
    $c = switch ([string]$t) {
        'ok'   { 'Green' }    'err'  { 'Red' }
        'warn' { 'Yellow' }   'head' { 'Cyan' }
        'info' { 'White' }    'dim'  { 'DarkGray' }
        default { 'Gray' }
    }
    Write-Host ('  [{0,-4}] {1}' -f ([string]$t).ToUpper(), $m) -ForegroundColor $c
}

function Show-WpiBanner {
    param([string]$Subtitle = '')
    $line = ('=' * 60)
    Write-Host ''
    Write-Host ('  ' + $line) -ForegroundColor DarkCyan
    Write-Host '              W P I   M O D E R N O' -ForegroundColor Cyan
    Write-Host ('        Post-instalacion automatica   -   v' + $WpiVersion) -ForegroundColor Cyan
    Write-Host ('  ' + $line) -ForegroundColor DarkCyan
    if ($Subtitle) { Write-Host ('   ' + $Subtitle) -ForegroundColor Gray }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs = Get-CimInstance Win32_ComputerSystem  -ErrorAction SilentlyContinue
        if ($os) { Write-Host ('   Sistema : {0} (build {1})' -f ([string]$os.Caption).Trim(), $os.BuildNumber) -ForegroundColor DarkGray }
        if ($cs) { Write-Host ('   Equipo  : {0}  -  {1:N1} GB RAM' -f $cs.Model, ($cs.TotalPhysicalMemory/1GB)) -ForegroundColor DarkGray }
        Write-Host ('   Fecha   : {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
    } catch {}
    Write-Host ''
}

function Write-WpiPhase {
    param([string]$Title)
    $script:WpiCur = ([int]$script:WpiCur) + 1
    Write-Host ''
    Write-Host ('  ===== FASE {0}/{1}: {2} =====' -f $script:WpiCur, $script:WpiTot, $Title) -ForegroundColor Cyan
    try { Write-Progress -Activity 'WPI - primer arranque' -Status $Title -PercentComplete ([int]((($script:WpiCur - 1) * 100) / [Math]::Max([int]$script:WpiTot, 1))) } catch {}
}

function Split-CliTokens {
    param([string]$Spec)
    # Si el argumento es la RUTA a un archivo (p.ej. C:\WPI\preset_tweaks.txt), leemos sus
    # lineas (un nombre por linea). Asi el autounattend pasa solo la ruta y evitamos el
    # limite de 1024 caracteres y las comillas en los nombres (causa del fallo de OOBE).
    if ($Spec -and (Test-Path -LiteralPath $Spec -PathType Leaf)) {
        return @(Get-Content -LiteralPath $Spec -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }
    return @($Spec -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

# Aplica tweaks por consola. -Tweaks all | recommended | <texto del nombre>,...
function Invoke-CliTweaks {
    param([string]$Spec)
    $tokens = Split-CliTokens $Spec
    $all  = ($tokens -contains 'all'  -or $tokens -contains 'todos')
    $reco = ($tokens -contains 'recommended' -or $tokens -contains 'recomendado' -or $tokens -contains 'recomendados')
    $sel = @()
    foreach ($t in $TweaksCatalog) {
        $name = [string]$t.Name
        $match = $false
        if ($all) { $match = $true }
        elseif ($reco) { $match = ($t.Risk -eq 'Seguro') }
        else {
            # Coincidencia EXACTA primero (nombres completos desde preset_tweaks.txt);
            # si no hay exacta, por subcadena (compatibilidad con -Tweaks "texto").
            foreach ($tok in $tokens) { if ($name.ToLower() -eq $tok.ToLower()) { $match = $true; break } }
            if (-not $match) { foreach ($tok in $tokens) { if ($name.ToLower().Contains($tok.ToLower())) { $match = $true; break } } }
        }
        # En modos masivos (all/reco) excluimos acciones puntuales no idempotentes
        if ($match -and ($all -or $reco) -and ($name -like 'Crear punto de restauracion*' -or $name -like 'Limpieza profunda*')) { $match = $false }
        if ($match) { $sel += $t }
    }
    if (@($sel).Count -eq 0) { W warn ('No hay tweaks que coincidan con: {0}' -f $Spec); return }
    W head ('Aplicando {0} tweaks en modo desatendido...' -f @($sel).Count)
    foreach ($t in $sel) {
        W info ('>>> {0}' -f $t.Name)
        try { & ([scriptblock]::Create([string]$t.Code)) } catch { W err ('[X] {0} fallo: {1}' -f $t.Name, $_.Exception.Message) }
    }
    W head 'Tweaks desatendidos terminados.'
}

# Quita bloatware por consola. -Debloat all | <texto del nombre/paquete>,...
function Invoke-CliDebloat {
    param([string]$Spec)
    $tokens = Split-CliTokens $Spec
    $all = ($tokens -contains 'all' -or $tokens -contains 'todos')
    $sel = @()
    foreach ($d in $DebloatCatalog) {
        $m = $false
        if ($all) { $m = $true }
        else { foreach ($tok in $tokens) { if (([string]$d.Name).ToLower().Contains($tok.ToLower()) -or ([string]$d.Pkg).ToLower().Contains($tok.ToLower())) { $m = $true; break } } }
        if ($m) { $sel += $d }
    }
    if (@($sel).Count -eq 0) { W warn ('No hay apps de debloat que coincidan con: {0}' -f $Spec); return }
    W head ('Quitando {0} apps preinstaladas en modo desatendido...' -f @($sel).Count)
    foreach ($d in $sel) {
        W info ('>>> Quitando: {0}' -f $d.Name)
        try {
            $patterns = Get-DebloatPatterns $d.Pkg
            $matched = 0; $removed = 0; $failed = 0
            # Usuario actual (Get-AppxPackage / Remove-AppxPackage)
            $found = @($patterns | ForEach-Object { Get-AppxPackage -Name $_ -ErrorAction SilentlyContinue })
            foreach ($pkg in $found) {
                $matched++
                try { $pkg | Remove-AppxPackage -ErrorAction Stop; $removed++; W ok ('    quitado: {0}' -f $pkg.Name) }
                catch { $failed++; W err ('    fallo: {0} :: {1}' -f $pkg.Name, $_.Exception.Message) }
            }
            # Provisionado para nuevos usuarios (Remove-AppxProvisionedPackage -Online)
            try {
                $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                    Where-Object { $dn = $_.DisplayName; @($patterns | Where-Object { $dn -like $_ }).Count -gt 0 })
                foreach ($pp in $prov) {
                    $matched++
                    try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null; $removed++; W ok ('    quitado: {0}' -f $pp.DisplayName) }
                    catch { $failed++; W err ('    fallo: {0} :: {1}' -f $pp.DisplayName, $_.Exception.Message) }
                }
            } catch {}
            # Registro uniforme por item: quitado / no estaba presente / fallo
            if ($matched -eq 0) { W dim ('    no estaba presente: {0}' -f $d.Name) }
            elseif ($failed -eq 0) { W ok ('[OK] {0}' -f $d.Name) }
            else { W warn ('[!] {0}: {1} quitado(s), {2} con fallo.' -f $d.Name, $removed, $failed) }
        } catch { W err ('[X] "{0}" fallo: {1}' -f $d.Name, $_.Exception.Message) }
    }
    W head 'Debloat desatendido terminado.'
}

# Desinstala OneDrive (instalador Win32, NO Appx) de forma idempotente. Cubre:
# proceso en ejecucion, desinstalador de 64/32 bits, entrada de arranque (Run) en
# HKCU y HKLM, y carpetas residuales. Si OneDrive no esta, no lanza error: solo
# registra "OneDrive no estaba presente". Cada bloque va envuelto en try/catch.
function Remove-OneDrive {
    W head 'Quitando OneDrive (Win32)...'
    $huboAlgo = $false

    # 1) Cerrar el proceso si esta corriendo (ignorar error si no corre)
    try {
        $proc = Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue
        if ($proc) {
            taskkill /f /im OneDrive.exe 2>$null | Out-Null
            W info '   proceso OneDrive.exe detenido.'
            $huboAlgo = $true
        }
    } catch { W warn ('   aviso al detener OneDrive.exe: {0}' -f $_.Exception.Message) }

    # 2) Ejecutar el desinstalador que exista (64 y 32 bits)
    foreach ($setup in @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe")) {
        try {
            if (Test-Path -LiteralPath $setup) {
                W info ('   ejecutando desinstalador: {0}' -f $setup)
                Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -ErrorAction Stop
                W ok ('   desinstalador completado: {0}' -f $setup)
                $huboAlgo = $true
            }
        } catch { W warn ('   aviso en desinstalador {0}: {1}' -f $setup, $_.Exception.Message) }
    }

    # 3) Quitar la entrada de arranque (Run) en HKCU y HKLM (ignorar si no existe)
    foreach ($root in @('HKCU', 'HKLM')) {
        foreach ($valName in @('OneDrive', 'OneDriveSetup')) {
            try {
                $key = ('{0}\Software\Microsoft\Windows\CurrentVersion\Run' -f $root)
                $exists = $false
                try { reg query $key /v $valName 2>&1 | Out-Null; $exists = ($LASTEXITCODE -eq 0) } catch {}
                if ($exists) {
                    reg delete $key /v $valName /f 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) { W info ('   entrada de arranque eliminada: {0}!{1}' -f $key, $valName); $huboAlgo = $true }
                }
            } catch { W warn ('   aviso al limpiar arranque {0}!{1}: {2}' -f $root, $valName, $_.Exception.Message) }
        }
    }

    # 4) Limpiar carpetas residuales si existen
    foreach ($dir in @("$env:UserProfile\OneDrive", "$env:LocalAppData\Microsoft\OneDrive", "$env:ProgramData\Microsoft OneDrive")) {
        try {
            if (Test-Path -LiteralPath $dir) {
                Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
                W info ('   carpeta residual eliminada: {0}' -f $dir)
                $huboAlgo = $true
            }
        } catch { W warn ('   aviso al borrar {0}: {1}' -f $dir, $_.Exception.Message) }
    }

    if ($huboAlgo) { W ok '[OK] OneDrive desinstalado.' }
    else { W dim 'OneDrive no estaba presente.' }
}

# Actualiza por consola. -Update all (winget upgrade --all) | recommended
# (aplica la configuracion recomendada de Windows Update).
function Invoke-CliUpdate {
    param([string]$Spec)
    $s = ([string]$Spec).ToLower()
    if ($s -eq 'recommended' -or $s -eq 'recomendado') {
        $act = $WindowsUpdateActions | Where-Object { [string]$_.Name -like 'Configuracion recomendada*' } | Select-Object -First 1
        if ($act) { W head ('Aplicando: {0}' -f $act.Name); try { & ([scriptblock]::Create([string]$act.Code)) } catch { W err ('[X] fallo: {0}' -f $_.Exception.Message) } }
        else { W warn 'No se encontro la accion recomendada de Windows Update.' }
    } else {
        W head 'Actualizando todas las apps instaladas (winget upgrade --all)...'
        winget upgrade --all --silent --include-unknown --accept-package-agreements --accept-source-agreements
        W head ('Actualizacion global finalizada (codigo {0}).' -f $LASTEXITCODE)
    }
}

# Construye (SOLO LECTURA) el texto del PLAN de un perfil maestro ya parseado:
# enumera exactamente que se haria (debloat, tweaks, update, apps) resolviendo
# contra los catalogos, SIN ejecutar ni cambiar absolutamente nada. Lo usan el
# dry-run de consola (-Profile -DryRun) y el boton "Ver plan" de la GUI.
function Get-MasterProfilePlanText {
    param($Data)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# PLAN DEL PERFIL MAESTRO  (solo lectura: no se aplica nada)')
    [void]$sb.AppendLine(('Generado: {0}  -  WPI {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [string]$WpiVersion))
    if ($Data.machine) { [void]$sb.AppendLine(('Perfil creado en: {0}  ({1})' -f [string]$Data.machine, [string]$Data.created)) }
    [void]$sb.AppendLine('')

    # 1) DEBLOAT
    $delPkgs = @()
    foreach ($e in @($Data.debloat)) { if ($e.pkg -and ($e.remove -eq $true -or [string]$e.remove -eq 'True')) { $delPkgs += [string]$e.pkg } }
    [void]$sb.AppendLine(('## 1) Debloat: quitar {0} app(s) preinstalada(s)' -f @($delPkgs).Count))
    if (@($delPkgs).Count -eq 0) { [void]$sb.AppendLine('   (ninguna)') }
    foreach ($pkg in $delPkgs) {
        $nm = $pkg
        $d = @($DebloatCatalog | Where-Object { ([string]$_.Pkg -eq $pkg) -or ((Get-DebloatPatterns $_.Pkg) -contains $pkg) }) | Select-Object -First 1
        if ($d) { $nm = ('{0}   [{1}]' -f [string]$d.Name, $pkg) }
        [void]$sb.AppendLine(('   - {0}' -f $nm))
    }
    [void]$sb.AppendLine('')

    # 2) TWEAKS
    $applyNames = @{}
    foreach ($e in @($Data.tweaks)) { if ($e.name -and ($e.apply -eq $true -or [string]$e.apply -eq 'True')) { $applyNames[[string]$e.name] = $true } }
    $tw = @($TweaksCatalog | Where-Object { $applyNames.ContainsKey([string]$_.Name) })
    [void]$sb.AppendLine(('## 2) Tweaks: aplicar {0} ajuste(s)' -f @($tw).Count))
    if (@($tw).Count -eq 0) { [void]$sb.AppendLine('   (ninguno)') }
    foreach ($t in $tw) {
        [void]$sb.AppendLine(('   - {0}  [{1}/{2}]' -f [string]$t.Name, [string]$t.Cat, [string]$t.Risk))
        if ($t.Desc) { [void]$sb.AppendLine(('       {0}' -f [string]$t.Desc)) }
        if ($t.Caveat) { [void]$sb.AppendLine(('       Evitalo si: {0}' -f [string]$t.Caveat)) }
    }
    # tweaks del perfil que NO existen en el catalogo de este WPI (se omitiran)
    $missing = @()
    foreach ($n in $applyNames.Keys) { if (@($TweaksCatalog | Where-Object { [string]$_.Name -eq $n }).Count -eq 0) { $missing += $n } }
    if (@($missing).Count -gt 0) {
        [void]$sb.AppendLine(('   (!) {0} tweak(s) del perfil no existen en este WPI y se OMITIRAN:' -f @($missing).Count))
        foreach ($m in $missing) { [void]$sb.AppendLine(('       - {0}' -f $m)) }
    }
    [void]$sb.AppendLine('')

    # 3) WINDOWS UPDATE
    $upd = [string]$Data.update
    [void]$sb.AppendLine('## 3) Windows Update')
    if (-not $upd -or $upd -eq '' -or $upd.ToLower() -eq 'none') { [void]$sb.AppendLine('   (sin cambios)') }
    else { [void]$sb.AppendLine(('   - Politica: {0}' -f $upd)) }
    [void]$sb.AppendLine('')

    # 4) APPS
    $ids = @()
    foreach ($a in @($Data.apps)) { if ([string]$a -ne '') { $ids += [string]$a } }
    [void]$sb.AppendLine(('## 4) Apps: instalar {0} programa(s) desde winget (salta las ya instaladas)' -f @($ids).Count))
    if (@($ids).Count -eq 0) { [void]$sb.AppendLine('   (ninguna)') }
    foreach ($id in $ids) {
        $nm = $id
        $c = @($catalog | Where-Object { [string]$_.Id -eq $id }) | Select-Object -First 1
        if ($c) { $nm = ('{0}   [{1}]' -f [string]$c.Name, $id) }
        [void]$sb.AppendLine(('   - {0}' -f $nm))
    }
    return $sb.ToString()
}

# Dry-run de consola: valida el $schema y MUESTRA el plan, sin aplicar nada.
function Show-MasterProfilePlanConsole {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path)) { W err ('[X] No existe el perfil maestro: {0}' -f $Path); return }
    $data = $null
    try { $data = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
        W err ('[X] No se pudo leer el perfil (JSON no valido): {0}' -f $_.Exception.Message); return
    }
    if ([string]$data.'$schema' -ne 'wpi-master-profile-1.0') {
        W err ('[X] El archivo no es un perfil maestro valido (schema="{0}"). No se muestra nada.' -f [string]$data.'$schema'); return
    }
    Write-Host ''
    Write-Host (Get-MasterProfilePlanText -Data $data) -ForegroundColor Gray
    Write-Host '[i] Dry-run: no se ha aplicado ni cambiado nada.' -ForegroundColor Cyan
}

# Aplica un PERFIL MAESTRO (apps+tweaks+debloat+update) por consola, en orden
# seguro y reutilizando el mismo Code/logica de cada accion. Crea un punto de
# restauracion (robusto: si falla, avisa y continua). Valida el $schema antes de
# tocar nada. Lo usa el flag -Profile (incluido el relanzamiento desde la GUI).
function Apply-MasterProfileCli {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path)) { W err ('[X] No existe el perfil maestro: {0}' -f $Path); return }
    $data = $null
    try { $data = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
        W err ('[X] No se pudo leer el perfil (JSON no valido): {0}' -f $_.Exception.Message); return
    }
    $schema = [string]$data.'$schema'
    if ($schema -ne 'wpi-master-profile-1.0') {
        W err ('[X] El archivo no es un perfil maestro valido (schema="{0}"). No se aplica nada.' -f $schema); return
    }
    W head ('Aplicando perfil maestro: {0}' -f $Path)

    # Punto de restauracion (robusto: NO aborta si falla por estar desactivado o
    # por el limite de 1 cada 24h de Windows; solo lo registra y continua).
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "WPI Moderno - antes de aplicar perfil maestro" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        W ok "Punto de restauracion creado."
    } catch { W warn ("Punto de restauracion no creado: {0} (continuo igualmente)." -f $_.Exception.Message) }

    # 1) DEBLOAT (quitar Appx marcadas con remove:true)
    $delPkgs = @()
    foreach ($e in @($data.debloat)) { if ($e.pkg -and ($e.remove -eq $true -or [string]$e.remove -eq 'True')) { $delPkgs += [string]$e.pkg } }
    if (@($delPkgs).Count -gt 0) {
        W head ('Debloat: quitando {0} apps preinstaladas...' -f @($delPkgs).Count)
        foreach ($pkg in $delPkgs) {
            W info ('>>> Quitando: {0}' -f $pkg)
            try {
                $patterns = Get-DebloatPatterns $pkg
                $found = @($patterns | ForEach-Object { Get-AppxPackage -Name $_ -ErrorAction SilentlyContinue })
                if ($found.Count -eq 0) { W dim ('    No estaba instalada ({0}).' -f $pkg) }
                else { foreach ($p in $found) { try { $p | Remove-AppxPackage -ErrorAction Stop } catch { W warn ('    No se pudo quitar {0}: {1}' -f $p.Name, $_.Exception.Message) } } }
                try {
                    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                        Where-Object { $dn = $_.DisplayName; @($patterns | Where-Object { $dn -like $_ }).Count -gt 0 } |
                        ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
                } catch {}
                W ok ('[OK] {0}' -f $pkg)
            } catch { W err ('[X] "{0}" fallo: {1}' -f $pkg, $_.Exception.Message) }
        }
    }

    # 2) TWEAKS (apply:true) -> match exacto contra el catalogo, mismo Code
    $applyNames = @{}
    foreach ($e in @($data.tweaks)) { if ($e.name -and ($e.apply -eq $true -or [string]$e.apply -eq 'True')) { $applyNames[[string]$e.name] = $true } }
    $tw = @($TweaksCatalog | Where-Object { $applyNames.ContainsKey([string]$_.Name) })
    if (@($tw).Count -gt 0) {
        W head ('Tweaks: aplicando {0} ajustes...' -f @($tw).Count)
        foreach ($t in $tw) {
            W info ('>>> {0}' -f $t.Name)
            try { & ([scriptblock]::Create([string]$t.Code)) } catch { W err ('[X] {0} fallo: {1}' -f $t.Name, $_.Exception.Message) }
        }
    }

    # 3) WINDOWS UPDATE (reutiliza Invoke-CliUpdate)
    $upd = [string]$data.update
    if ($upd -and $upd -ne '' -and $upd.ToLower() -ne 'none') {
        Write-Host ''
        Invoke-CliUpdate -Spec $upd
    }

    # 4) APPS (winget; deja que winget salte las ya instaladas)
    $ids = @()
    foreach ($a in @($data.apps)) { if ([string]$a -ne '') { $ids += [string]$a } }
    if (@($ids).Count -gt 0) {
        Write-Host ''
        W head ('Apps: instalando {0} programas desde winget...' -f @($ids).Count)
        Invoke-WingetInstall -Ids @($ids)
    }

    W head 'Perfil maestro aplicado.'
}

# ===================== ARRANQUE EN CONSOLA ==================
Write-Host ''
Write-Host ('  WPI MODERNO v{0}  -  motor winget asincrono' -f $WpiVersion) -ForegroundColor Cyan
Write-Host '  --------------------------------------------' -ForegroundColor DarkGray
$script:WingetOK = Test-Winget
Invoke-SelfUpdate
if ($script:WingetOK) { Update-WingetSources }
if (-not (Test-Path $Config.LogDir)) { New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null }
if ($script:WingetOK -and $Config.AutoUpgradeApps) {
    Write-Host '[+] Auto-actualizando todas las apps instaladas (configurable en el script)...' -ForegroundColor DarkCyan
    winget upgrade --all --silent --include-unknown --accept-package-agreements --accept-source-agreements
    Write-Host '[OK] Auto-actualizacion finalizada.' -ForegroundColor DarkGreen
}

# ===================== MODO DESATENDIDO =====================
if ($Preset -or $Tweaks -or $Debloat -or $Update -or $ProfilePath) {
    # ---- LOG detallado de TODO el primer arranque (transcript completo) ----
    $logDir = Join-Path $PSScriptRoot 'logs'
    try { if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } } catch {}
    $logFile = Join-Path $logDir ('primer_arranque_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    try { Start-Transcript -Path $logFile -Force | Out-Null } catch {}

    Show-WpiBanner -Subtitle 'Aplicando tu configuracion automaticamente. No cierres esta ventana.'

    # Plan de fases
    $steps = New-Object System.Collections.Generic.List[string]
    if ($ProfilePath) { $steps.Add('Perfil maestro') | Out-Null }
    if ($Preset)  { $steps.Add('Aplicaciones (winget)') | Out-Null }
    if ($Tweaks)  { $steps.Add('Ajustes / tweaks + modo oscuro') | Out-Null }
    if ($Debloat) { $steps.Add('Quitar bloatware') | Out-Null }
    if ($Update)  { $steps.Add('Actualizaciones') | Out-Null }
    $script:WpiTot = $steps.Count; $script:WpiCur = 0
    Write-Host ('   Plan: {0} fase(s)  ->  {1}' -f $script:WpiTot, ($steps -join ', ')) -ForegroundColor White

    if ($ProfilePath) {
        Write-WpiPhase 'Perfil maestro'
        if ($DryRun) { Show-MasterProfilePlanConsole -Path $ProfilePath }
        else { Apply-MasterProfileCli -Path $ProfilePath }
    }
    if ($Preset) {
        Write-WpiPhase 'Aplicaciones (winget)'
        if (-not (Test-Path $Preset)) {
            Write-Host ('[~] No existe el archivo de preset (se omiten apps): {0}' -f $Preset) -ForegroundColor Yellow
        } else {
            $ids = Get-Content $Preset | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }
            Write-Host ('[i] {0} aplicaciones en el preset.' -f @($ids).Count) -ForegroundColor White
            if ($script:WingetOK) {
                # ---- Cambio 6: diferir apps problematicas (Discord) a RunOnce en el primer arranque ----
                # En -FirstBoot, instalar Discord como SYSTEM/admin se cuelga con 0xC0000005
                # (3221225477). Esas apps se separan del resto y se difieren a un RunOnce en HKCU
                # que se ejecuta en el primer inicio de sesion interactivo del usuario tras el
                # reinicio. El resto de apps (Brave, Firefox, WinRAR, Audacity, EA...) se instalan
                # igual que siempre. Fuera del primer arranque (GUI/CLI normal) NO se difiere nada.
                if ($FirstBoot) {
                    $deferredIds = @($ids | Where-Object { $script:DeferredFirstLogonAppIds -contains $_ })
                    $normalIds   = @($ids | Where-Object { $script:DeferredFirstLogonAppIds -notcontains $_ })
                    if (@($normalIds).Count -gt 0) { Invoke-WingetInstall -Ids @($normalIds) }
                    if (@($deferredIds).Count -gt 0) {
                        Write-Host ''
                        if (Register-DeferredAppRetry -Ids @($deferredIds) -RootDir $PSScriptRoot) {
                            Write-Host ('  Discord diferido a RunOnce (se instalara en el primer inicio de sesion): {0}' -f ($deferredIds -join ', ')) -ForegroundColor Cyan
                        } else {
                            Write-Host '  [~] No se pudo diferir; se intenta instalar ahora como respaldo.' -ForegroundColor Yellow
                            Invoke-WingetInstall -Ids @($deferredIds)
                        }
                    }
                } else {
                    Invoke-WingetInstall -Ids @($ids)
                }
            }
            else { Write-Host '[~] Apps OMITIDAS: winget no se pudo activar. Abre luego Iniciar_WPI.bat para instalarlas.' -ForegroundColor Yellow }
        }
    }
    if ($Tweaks)  { Write-WpiPhase 'Ajustes / tweaks + modo oscuro'; Invoke-CliTweaks  -Spec $Tweaks }
    if ($Debloat) { Write-WpiPhase 'Quitar bloatware'; Invoke-CliDebloat -Spec $Debloat }
    if ($Update)  { Write-WpiPhase 'Actualizaciones'; if ($script:WingetOK) { Invoke-CliUpdate -Spec $Update } else { Write-Host '[~] Update omitido: winget no disponible.' -ForegroundColor Yellow } }

    # ---- LIMPIEZA: desinstalar OneDrive en el PRIMER ARRANQUE (Win32, no Appx) ----
    # Solo en el flujo desatendido de primer arranque (-FirstBoot) o si el usuario
    # marco OneDrive en el debloat. Queda registrado en el transcript del primer arranque.
    if ($FirstBoot -or ($Debloat -and (Split-CliTokens $Debloat | Where-Object { $_.ToLower().Contains('onedrive') }))) {
        Write-Host ''
        Write-Host '  ===== LIMPIEZA: OneDrive =====' -ForegroundColor Cyan
        try { Remove-OneDrive } catch { W err ('[X] Remove-OneDrive fallo: {0}' -f $_.Exception.Message) }
    }

    # ---- REFUERZO CDM (HKCU): desactivar Content Delivery Manager del usuario actual ----
    # Complementa la desactivacion offline del hive Default (Cambio 5): asegura que el usuario
    # que ya inicio sesion tampoco reciba apps sugeridas ni anclajes fantasma. Las mismas claves
    # que se fijan offline en WPIDEF se fijan aqui en HKCU. Queda en el transcript del arranque.
    if ($FirstBoot -or $Debloat) {
        Write-Host ''
        Write-Host '  ===== REFUERZO: Content Delivery Manager (HKCU) =====' -ForegroundColor Cyan
        $cdmKeyHkcu  = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        $cdmValsHkcu = @(
            'ContentDeliveryAllowed','SilentInstalledAppsEnabled','PreInstalledAppsEnabled',
            'PreInstalledAppsEverEnabled','OemPreInstalledAppsEnabled','SubscribedContentEnabled',
            'SubscribedContent-338388Enabled','SubscribedContent-338389Enabled',
            'SubscribedContent-310093Enabled','SubscribedContent-353698Enabled',
            'SystemPaneSuggestionsEnabled','FeatureManagementEnabled'
        )
        foreach ($v in $cdmValsHkcu) {
            try {
                reg add "$cdmKeyHkcu" /v $v /t REG_DWORD /d 0 /f 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { W ok ('CDM HKCU {0}=0' -f $v) }
                else { W warn ('No se pudo escribir CDM HKCU {0}' -f $v) }
            } catch { W err ('[X] CDM HKCU {0} fallo: {1}' -f $v, $_.Exception.Message) }
        }
    }

    try { Write-Progress -Activity 'WPI - primer arranque' -Completed } catch {}

    # ---- RESUMEN FINAL ----
    Write-Host ''
    Write-Host ('  ' + ('=' * 60)) -ForegroundColor DarkCyan
    Write-Host '   RESUMEN DEL PRIMER ARRANQUE' -ForegroundColor Cyan
    Write-Host ('  ' + ('=' * 60)) -ForegroundColor DarkCyan
    Write-Host ('   winget : {0}' -f $(if ($script:WingetOK) {'activado'} else {'NO disponible (apps omitidas)'})) -ForegroundColor $(if ($script:WingetOK) {'Green'} else {'Yellow'})
    Write-Host ('   Fases  : {0}' -f ($steps -join ', ')) -ForegroundColor White
    Write-Host ('   Log    : {0}' -f $logFile) -ForegroundColor White
    Write-Host ('  ' + ('=' * 60)) -ForegroundColor DarkCyan

    # Marcador de diagnostico
    try {
        $mk = Join-Path $PSScriptRoot 'primer_arranque_OK.txt'
        Set-WpiContent -Path $mk -Value ('WPI desatendido completado: {0} (winget: {1}) | log: {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $(if ($script:WingetOK) {'OK'} else {'NO disponible'}), $logFile)
    } catch {}

    try { Stop-Transcript | Out-Null } catch {}

    # ---- COPIA ADICIONAL DEL LOG (visible para el usuario) ----
    # El original en C:\WPI\logs\primer_arranque_*.log y el marcador siguen intactos;
    # esta copia es ADICIONAL y un fallo aqui NO debe impedir el reinicio.
    if (Test-Path $logFile) {
        # Escritorio del usuario actual
        try {
            $userDesktop = [Environment]::GetFolderPath('Desktop')
            if ([string]::IsNullOrWhiteSpace($userDesktop)) { $userDesktop = Join-Path $env:USERPROFILE 'Desktop' }
            if (-not (Test-Path $userDesktop)) { New-Item -ItemType Directory -Path $userDesktop -Force | Out-Null }
            $destUser = Join-Path $userDesktop (Split-Path $logFile -Leaf)
            Copy-Item $logFile $destUser -Force
            Write-Host ('  Log copiado al Escritorio: {0}' -f $destUser) -ForegroundColor Green
        } catch { Write-Host ('  [X] No se pudo copiar el log al Escritorio del usuario: {0}' -f $_.Exception.Message) -ForegroundColor Yellow }

        # Public Desktop (respaldo)
        try {
            $publicDesktop = Join-Path $env:PUBLIC 'Desktop'
            if (-not (Test-Path $publicDesktop)) { New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null }
            $destPublic = Join-Path $publicDesktop (Split-Path $logFile -Leaf)
            Copy-Item $logFile $destPublic -Force
            Write-Host ('  Log copiado al Escritorio publico: {0}' -f $destPublic) -ForegroundColor Green
        } catch { Write-Host ('  [X] No se pudo copiar el log al Escritorio publico: {0}' -f $_.Exception.Message) -ForegroundColor Yellow }
    }

    # ---- ACCESO AL WPI EN EL ESCRITORIO (para seguir usandolo tras el reinicio) ----
    # Deja accesos directos al lanzador y a la carpeta C:\WPI en el Escritorio del
    # usuario y en el Publico. Si el usuario borra C:\WPI o el log, siempre puede
    # abrir el WPI desde el USB (carpeta WPI en la raiz). Un fallo aqui NO bloquea el reinicio.
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $targets = @()
        try { $du = [Environment]::GetFolderPath('Desktop'); if ([string]::IsNullOrWhiteSpace($du)) { $du = Join-Path $env:USERPROFILE 'Desktop' }; $targets += $du } catch {}
        try { $targets += (Join-Path $env:PUBLIC 'Desktop') } catch {}
        foreach ($dt in ($targets | Select-Object -Unique)) {
            if ([string]::IsNullOrWhiteSpace($dt)) { continue }
            if (-not (Test-Path $dt)) { try { New-Item -ItemType Directory -Path $dt -Force | Out-Null } catch { continue } }
            try {
                $lnk = $wsh.CreateShortcut((Join-Path $dt 'WPI Moderno.lnk'))
                if (Test-Path 'C:\WPI\Iniciar_WPI.bat') {
                    $lnk.TargetPath = 'C:\WPI\Iniciar_WPI.bat'
                } else {
                    $lnk.TargetPath = 'powershell.exe'
                    $lnk.Arguments  = '-NoProfile -ExecutionPolicy Bypass -File "C:\WPI\WPI_Moderno.ps1"'
                }
                $lnk.WorkingDirectory = 'C:\WPI'
                $lnk.IconLocation = 'powershell.exe,0'
                $lnk.Description = 'Abrir WPI Moderno'
                $lnk.Save()
            } catch {}
            try {
                $lnkF = $wsh.CreateShortcut((Join-Path $dt 'WPI (carpeta).lnk'))
                $lnkF.TargetPath = 'C:\WPI'
                $lnkF.Description = 'Carpeta del WPI (apps, tweaks, suite, log, winget)'
                $lnkF.Save()
            } catch {}
        }
        Write-Host '  Accesos directos del WPI creados en el Escritorio (lanzador + carpeta).' -ForegroundColor Green
    } catch { Write-Host ('  [!] No se pudieron crear accesos del WPI en el Escritorio: ' + $_.Exception.Message) -ForegroundColor Yellow }

    # ---- REINICIO (solo en primer arranque real; -NoReboot lo evita) ----
    if ($FirstBoot -and -not $NoReboot) {
        Write-Host ''
        Write-Host '  Todo aplicado. El equipo se REINICIARA para dejar los cambios finos.' -ForegroundColor Yellow
        Write-Host '  (cierra esta ventana en los proximos 30s para cancelar el reinicio)' -ForegroundColor DarkGray
        for ($s = 30; $s -ge 1; $s--) { Write-Host ("`r  Reiniciando en {0:D2}s...   " -f $s) -NoNewline -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        Write-Host ''
        try { Restart-Computer -Force } catch { Write-Host ('[X] No se pudo reiniciar: {0}' -f $_.Exception.Message) -ForegroundColor Red }
    } else {
        Write-Host ''
        Write-Host '  Proceso terminado.' -ForegroundColor Green
        if (-not $FirstBoot) { Read-Host '  Pulsa Enter para salir' }
    }
    exit 0
}

# ============================================================
#                    INTERFAZ GRAFICA v3
# ============================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# --- Instancia unica: evita abrir dos ventanas a la vez ---
$script:SingleInstance = New-Object System.Threading.Mutex($false, 'Global\WPI_Moderno_v3')
$gotMutex = $false
try { $gotMutex = $script:SingleInstance.WaitOne(0, $false) } catch { $gotMutex = $true }
if (-not $gotMutex) {
    if ($SelfTestGui) {
        Write-Host '[FAIL] SelfTestGui: WPI ya esta abierto o el mutex esta bloqueado.' -ForegroundColor Red
        exit 1
    }
    [System.Windows.MessageBox]::Show('WPI Moderno ya esta abierto. Solo puede haber una ventana a la vez.', 'WPI Moderno', 'OK', 'Information') | Out-Null
    exit 0
}

# --- Aviso si no se ejecuta como Administrador ---
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin -and -not $SelfTestGui) {
        [System.Windows.MessageBox]::Show('Atencion: NO se esta ejecutando como Administrador (se rechazo el aviso de permisos). Muchas instalaciones, tweaks, el Control de Windows Update y el debloat fallaran. Cierra y vuelve a abrir WPI aceptando el aviso de Control de cuentas de usuario (UAC).', 'WPI Moderno', 'OK', 'Warning') | Out-Null
    }
} catch {}

# ----------- WORKER ASINCRONO (corre en otro hilo) ----------
# Toda operacion pesada (instalar, validar, actualizar, tweaks)
# se ejecuta aqui para que la ventana NUNCA se congele. La UI
# lee la cola $Q con un DispatcherTimer.
$WorkerScript = {
    param($Q, $S, $Mode, $Ids, $Parallel, $LogFile, $TweakList, $Names, $TimeoutMin, $Query, $Scope, $Fallback, $Lang)

    # P4: registro de TODOS los temporales que crea el worker, para limpiarlos
    # en el finally aunque un proceso se mate (watchdog/cancelacion) y deje su
    # stdout/stderr huerfano en %TEMP%.
    $script:WpiTempFiles = New-Object System.Collections.ArrayList

    # El runspace es aislado: recalculamos aqui si la sesion es Administrador,
    # para que los Code de tweaks (registro/servicios/HKLM) puedan avisar con
    # claridad cuando faltan permisos en lugar de fallar en silencio.
    $isAdmin = $false
    try { $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}

    # i18n del Live Log: el worker corre en un runspace aislado sin acceso a Tr/TrMap,
    # asi que recibe $Lang y elige texto ES/EN en el momento de construir el mensaje.
    function L2([string]$es, [string]$en) { if ($Lang -eq 'en') { return $en } else { return $es } }

    function W([string]$t, [string]$m) {
        $line = '[{0}] [{1,-4}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $t.ToUpper(), $m
        try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
        $Q.Enqueue([pscustomobject]@{T = $t; M = $m})
    }
    function NameOf([string]$id) {
        if ($Names.ContainsKey($id)) { return ('{0}  [{1}]' -f $Names[$id], $id) } else { return $id }
    }
    function CodeMeaning([int]$Code) {
        $hex = '0x{0:X8}' -f $Code
        switch ($hex) {
            '0x00000000' { return @{Ok=$true;  Msg=(L2 'instalada correctamente' 'installed successfully')} }
            '0x00000BBA' { return @{Ok=$true;  Msg=(L2 'instalada (3010: requiere reiniciar el equipo)' 'installed (3010: a restart is required)')} }
            '0x00000669' { return @{Ok=$true;  Msg=(L2 'instalada (1641: el instalador inicio un reinicio)' 'installed (1641: the installer triggered a restart)')} }
            '0x8A15002B' { return @{Ok=$true;  Msg=(L2 'ya estaba instalada / sin actualizacion aplicable' 'already installed / no applicable update')} }
            '0x8A15002C' { return @{Ok=$true;  Msg=(L2 'ya estaba actualizada a la ultima version' 'already up to date with the latest version')} }
            '0x8A150014' { return @{Ok=$false; Msg=(L2 'ID no encontrado en el repositorio de winget' 'ID not found in the winget repository')} }
            '0x8A150044' { return @{Ok=$false; Msg=(L2 'se requiere aceptar acuerdos de la fuente' 'source agreements must be accepted')} }
            '0x8A15010B' { return @{Ok=$false; Msg=(L2 'requiere una version de Windows superior' 'requires a newer version of Windows')} }
            '0x8A150056' { return @{Ok=$false; Msg=(L2 'descarga interrumpida (red)' 'download interrupted (network)'); Retry=$true} }
            '0x80072EE7' { return @{Ok=$false; Msg=(L2 'sin conexion / DNS (red)' 'no connection / DNS (network)'); Retry=$true} }
            '0x80072EFD' { return @{Ok=$false; Msg=(L2 'no se pudo conectar al servidor (red)' 'could not connect to the server (network)'); Retry=$true} }
            '0x00000643' { return @{Ok=$false; Msg=(L2 '1603: error fatal del instalador MSI' '1603: fatal MSI installer error')} }
            '0x00000652' { return @{Ok=$false; Msg=(L2 '1618: otra instalacion MSI en curso' '1618: another MSI installation in progress'); Retry=$true} }
            '0x8A150201' { return @{Ok=$false; Msg=(L2 'el instalador devolvio error' 'the installer returned an error')} }
            '0x00000642' { return @{Ok=$false; Msg=(L2 '1602: instalacion cancelada' '1602: installation cancelled')} }
            '0x000003E5' { return @{Ok=$false; Msg=(L2 '1001: operacion en curso' '1001: operation in progress'); Retry=$true} }
            '0xFFFFFFFF' { return @{Ok=$false; Msg=(L2 'proceso terminado (watchdog/cancelacion)' 'process terminated (watchdog/cancellation)')} }
            default      { return @{Ok=$false; Msg=(L2 ('fallo con codigo {0}' -f $hex) ('failed with code {0}' -f $hex))} }
        }
    }
    # Lee lo nuevo del stdout de un proceso en marcha (tail forense)
    function TailRead($r) {
        try {
            $fs = [IO.File]::Open($r.Out, 'Open', 'Read', 'ReadWrite')
            $fs.Position = $r.Pos
            $sr = New-Object IO.StreamReader($fs)
            $txt = $sr.ReadToEnd()
            $r.Pos = $fs.Position
            $sr.Close(); $fs.Close()
            # T2: extrae el ultimo porcentaje del progreso de winget (si lo hay).
            # Si no se parsea, CurPercent queda como estaba y la barra avanza
            # como antes (por apps hechas/total). Fallback seguro.
            try {
                $pm = [regex]::Matches($txt, '(\d{1,3})\s*%')
                if ($pm.Count -gt 0) {
                    $val = [int]$pm[$pm.Count - 1].Groups[1].Value
                    if ($val -ge 0 -and $val -le 100) { $S.CurPercent = $val }
                }
            } catch {}
            foreach ($ln in ($txt -split "[`r`n]+")) {
                $ln = $ln.Trim()
                if ($ln -and $ln.Length -lt 220 -and $ln -notmatch '^[\s\\\|/\-\.,0-9%KMGiB]+$') { W dim ('    ' + $ln) }
            }
        } catch {}
    }
    # Parser generico y robusto de la tabla de winget. Devuelve filas como
    # arrays de celdas. No depende del idioma. Tolera separadores ASCII o
    # unicode y, si la cabecera no alinea bien, parte por 2+ espacios.
    function Parse-WingetTable([string]$raw) {
        $rows = New-Object System.Collections.ArrayList
        if (-not $raw) { return $rows }
        $dash = [char[]]('-', '=', [char]0x2500, [char]0x2501, [char]0x2502, [char]0x2014, [char]0x2015, [char]0x2550)
        function Is-Sep([string]$s) {
            $t = $s.Trim()
            if ($t.Length -lt 6) { return $false }
            foreach ($ch in $t.ToCharArray()) { if ($dash -notcontains $ch) { return $false } }
            return $true
        }
        $lines = $raw -split "`r?`n"
        $sep = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if (Is-Sep $lines[$i]) { $sep = $i; break } }
        if ($sep -lt 1) { return $rows }
        # Cabecera: ultima linea no vacia antes del separador
        $h = $sep - 1
        while ($h -ge 0 -and $lines[$h].Trim() -eq '') { $h-- }
        if ($h -lt 0) { return $rows }
        $hdr = $lines[$h]
        $cols = New-Object System.Collections.ArrayList
        [void]$cols.Add(0)
        for ($j = 2; $j -lt $hdr.Length; $j++) {
            if ($hdr[$j] -ne ' ' -and $hdr[$j-1] -eq ' ' -and $hdr[$j-2] -eq ' ') { [void]$cols.Add($j) }
        }
        for ($i = $sep + 1; $i -lt $lines.Count; $i++) {
            $ln = $lines[$i]
            if ($ln.Trim() -eq '') { break }       # fin de la tabla principal
            if (Is-Sep $ln) { continue }            # separadores intermedios
            $cells = New-Object System.Collections.ArrayList
            if ($cols.Count -ge 2) {
                for ($c = 0; $c -lt $cols.Count; $c++) {
                    $a = $cols[$c]
                    $b = if ($c -lt $cols.Count - 1) { $cols[$c + 1] } else { $ln.Length }
                    if ($a -ge $ln.Length) { [void]$cells.Add(''); continue }
                    if ($b -gt $ln.Length) { $b = $ln.Length }
                    [void]$cells.Add($ln.Substring($a, $b - $a).Trim())
                }
            } else {
                foreach ($p in ($ln -split '\s{2,}')) { if ($p.Trim() -ne '') { [void]$cells.Add($p.Trim()) } }
            }
            [void]$rows.Add($cells)
        }
        return $rows
    }
    # Consulta la version REALMENTE instalada de un paquete (post-verificacion).
    # Independiente de idioma: localiza la celda exacta del Id y devuelve la
    # celda de Version contigua. Cadena vacia si no se puede determinar.
    function Get-InstalledVer([string]$id) {
        if (-not $id) { return '' }
        $raw = ''
        try { $raw = (& winget list --id $id -e --accept-source-agreements --disable-interactivity 2>&1 | Out-String) } catch { return '' }
        $rows = Parse-WingetTable $raw
        foreach ($row in $rows) {
            for ($k = 0; $k -lt $row.Count; $k++) {
                if (([string]$row[$k]).Trim() -eq $id) {
                    if (($k + 1) -lt $row.Count) { return ([string]$row[$k + 1]).Trim() }
                }
            }
        }
        return ''
    }
    function DumpFileTail([string]$path, [int]$n = 12) {
        try {
            if (Test-Path $path) {
                Get-Content $path -Tail $n -ErrorAction SilentlyContinue | ForEach-Object {
                    $ln = $_.Trim(); if ($ln) { W dim ('    | ' + $ln) }
                }
            }
        } catch {}
    }
    function Start-One([string]$Exe, [string]$Arguments) {
        $out = [IO.Path]::GetTempFileName(); $err = "$out.err"
        try { [void]$script:WpiTempFiles.Add($out); [void]$script:WpiTempFiles.Add($err) } catch {}
        $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru -WindowStyle Hidden `
             -RedirectStandardOutput $out -RedirectStandardError $err
        return @{P = $p; Out = $out; Err = $err; Pos = [long]0; T0 = (Get-Date); Killed = $false}
    }
    function Patch-DiscordShortcuts {
        try {
            $sh = New-Object -ComObject WScript.Shell
            $userProfile = $env:USERPROFILE
            $shortcuts = @(
                (Join-Path $userProfile "Desktop\Discord.lnk"),
                (Join-Path $userProfile "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc\Discord.lnk")
            )
            foreach ($path in $shortcuts) {
                if (Test-Path $path) {
                    $lnk = $sh.CreateShortcut($path)
                    $oldArgs = $lnk.Arguments
                    if ($oldArgs -notmatch '--no-sandbox') {
                        $lnk.Arguments = '--processStart Discord.exe --process-start-args "--no-sandbox"'
                        $lnk.Save()
                        W ok ((L2 'Parcheado acceso directo de Discord: ' 'Patched Discord shortcut: ') + (Split-Path $path -Leaf))
                    }
                }
            }
        } catch {
            W warn ((L2 'No se pudo parchear el acceso directo de Discord: ' 'Could not patch the Discord shortcut: ') + $_.Exception.Message)
        }
    }

    try {
        switch ($Mode) {

            {$_ -in @('install','uninstall','upgradeids','download')} {
                $inst = ($Mode -eq 'install')
                $upg  = ($Mode -eq 'upgradeids')
                $dl   = ($Mode -eq 'download')
                $S.Total = @($Ids).Count
                $title = if ($inst) { L2 'INSTALACION' 'INSTALLATION' } elseif ($upg) { L2 'ACTUALIZACION SELECTIVA' 'SELECTIVE UPDATE' } elseif ($dl) { L2 'DESCARGA DE INSTALADORES' 'INSTALLER DOWNLOAD' } else { L2 'DESINSTALACION' 'UNINSTALLATION' }
                W head ((L2 '{0} MASIVA: {1} aplicaciones | paralelismo: {2} | log: {3}' '{0} (BATCH): {1} apps | parallelism: {2} | log: {3}') -f $title, $S.Total, $Parallel, $LogFile)
                if ($dl) { W dim ((L2 '    Carpeta de destino: {0}' '    Destination folder: {0}') -f $Query) }
                if ($TimeoutMin -gt 0) { W dim ((L2 '    Watchdog activo: maximo {0} min por aplicacion.' '    Watchdog active: max {0} min per app.') -f $TimeoutMin) }
                $pendQ = New-Object System.Collections.Queue
                foreach ($id in $Ids) { $pendQ.Enqueue(@{Id = $id; Try = 1}) }
                $running = New-Object System.Collections.ArrayList

                while (($pendQ.Count -gt 0 -and -not $S.Cancel) -or $running.Count -gt 0) {
                    while ($pendQ.Count -gt 0 -and $running.Count -lt $Parallel -and -not $S.Cancel) {
                        $it = $pendQ.Dequeue()
                        $a = if ($inst) {
                            $base = 'install --id "{0}" -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity' -f $it.Id
                            if ($Scope -eq 'user' -or $Scope -eq 'machine') {
                                $base += (' --scope {0}' -f $Scope)
                            } elseif ($script:UserScopeAppIds -contains $it.Id) {
                                # Auto + app problematica en machine (Discord): forzamos ambito de usuario.
                                $base += ' --scope user'
                            }
                            $base
                        } elseif ($upg) {
                            'upgrade --id "{0}" -e --silent --include-unknown --accept-package-agreements --accept-source-agreements --disable-interactivity' -f $it.Id
                        } elseif ($dl) {
                            'download --id "{0}" -e --accept-package-agreements --accept-source-agreements --disable-interactivity --download-directory "{1}"' -f $it.Id, $Query
                        } else {
                            'uninstall --id "{0}" -e --silent --disable-interactivity' -f $it.Id
                        }
                        # P2: para verificacion post-actualizacion, captura la version
                        # instalada ANTES de lanzar el upgrade (solo en modo upgrade).
                        $verBefore = ''
                        if ($upg) { try { $verBefore = (Get-InstalledVer $it.Id) } catch {} }
                        $r = Start-One 'winget' $a
                        $r.Id = $it.Id; $r.Try = $it.Try; $r.VerBefore = $verBefore
                        [void]$running.Add($r)
                        $tag = if ($it.Try -gt 1) { L2 ' (reintento)' ' (retry)' } else { '' }
                        $verb = if ($inst) { L2 'Instalando' 'Installing' } elseif ($upg) { L2 'Actualizando' 'Updating' } elseif ($dl) { L2 'Descargando' 'Downloading' } else { L2 'Desinstalando' 'Uninstalling' }
                        $S.CurName = (NameOf $it.Id)
                        $S.CurPercent = 0
                        W info ('>>> {0} {1}{2} ...' -f $verb, (NameOf $it.Id), $tag)
                    }
                    foreach ($r in @($running)) {
                        if ($Parallel -eq 1) { TailRead $r }
                        if (-not $r.P.HasExited -and -not $r.Killed -and $TimeoutMin -gt 0 -and ((Get-Date) - $r.T0).TotalMinutes -ge $TimeoutMin) {
                            W err ((L2 '[X]  WATCHDOG: {0} lleva mas de {1} min. Se fuerza el cierre del instalador colgado.' '[X]  WATCHDOG: {0} has been running for over {1} min. Forcing the hung installer to close.') -f (NameOf $r.Id), $TimeoutMin)
                            $r.Killed = $true
                            try { Start-Process taskkill -ArgumentList ('/PID {0} /T /F' -f $r.P.Id) -WindowStyle Hidden -Wait } catch {}
                            Start-Sleep -Milliseconds 500
                        }
                        if ($r.P.HasExited) {
                            Start-Sleep -Milliseconds 120
                            if ($Parallel -eq 1) { TailRead $r }
                            $m = CodeMeaning $r.P.ExitCode
                            if ($upg  -and $m.Ok) { $m.Msg = (L2 'actualizada correctamente' 'updated successfully') }
                            if ($dl   -and $m.Ok) { $m.Msg = (L2 'instalador descargado' 'installer downloaded') }
                            if (-not $inst -and -not $upg -and -not $dl -and $m.Ok) { $m.Msg = (L2 'desinstalada correctamente' 'uninstalled successfully') }
                            if (-not $m.Ok -and $m.Retry -and $r.Try -lt 3) {
                                $wait = 4 * $r.Try
                                W warn ((L2 '[~] {0}: {1}. Reintento {2}/3 en {3}s.' '[~] {0}: {1}. Retry {2}/3 in {3}s.') -f (NameOf $r.Id), $m.Msg, ($r.Try + 1), $wait)
                                Start-Sleep -Seconds $wait
                                $pendQ.Enqueue(@{Id = $r.Id; Try = ($r.Try + 1)})
                            } elseif ($m.Ok) {
                                $S.Ok++; $S.Done++
                                if ($m.Msg -match 'reinici') { $S.Reboot++ }
                                # P2/P4: VERIFICACION REAL post-actualizacion. winget puede
                                # devolver exito (exit 0) sin que la version instalada cambie
                                # (app en ejecucion, auto-actualizacion propia, paquete pinneado...).
                                # Solo para upgrade y exit 0 limpio (los codigos "ya actualizada"
                                # no son 0, asi que no entran aqui): comprobamos la version final.
                                $verifiedMsg = $m.Msg
                                if ($upg -and $r.P.ExitCode -eq 0) {
                                    $verAfter = ''
                                    try { $verAfter = (Get-InstalledVer $r.Id) } catch {}
                                    if ($verAfter -and $r.VerBefore -and ($verAfter -eq $r.VerBefore)) {
                                        W warn ('[!] ' + ((L2 'VERIFICACION: winget informo exito, pero {0} sigue en la version {1}. No se ha actualizado de verdad: cierra la app si esta abierta, reinicia el equipo, o puede que la app se auto-actualice por su cuenta.' 'VERIFICATION: winget reported success, but {0} is still version {1}. It was NOT actually updated: close the app if it is open, reboot, or the app may self-update on its own.') -f (NameOf $r.Id), $verAfter))
                                        [void]$S.VerifyWarn.Add(((L2 '{0}: sigue en {1} (winget dijo OK pero no cambio)' '{0}: still {1} (winget said OK but it did not change)') -f (NameOf $r.Id), $verAfter))
                                    } elseif ($verAfter) {
                                        $verifiedMsg = ((L2 'actualizada y verificada: ahora {0}' 'updated and verified: now {0}') -f $verAfter)
                                    }
                                }
                                W ok ('[OK] {0} - {1}' -f (NameOf $r.Id), $verifiedMsg)
                                if ($r.Id -eq 'Discord.Discord') { Patch-DiscordShortcuts }
                                # (mensaje ya traducido via CodeMeaning / override $m.Msg)
                            } else {
                                $okFb = $false
                                if ($inst -and $Fallback) {
                                    if (Get-Command choco -ErrorAction SilentlyContinue) {
                                        W warn ((L2 '[~] {0}: winget fallo. Probando con Chocolatey (best-effort)...' '[~] {0}: winget failed. Trying Chocolatey (best-effort)...') -f (NameOf $r.Id))
                                        try {
                                            $cp = Start-Process choco -ArgumentList ('install ' + $r.Id + ' -y --no-progress') -WindowStyle Hidden -Wait -PassThru
                                            if ($cp -and $cp.ExitCode -eq 0) { $okFb = $true }
                                        } catch {}
                                        if (-not $okFb) { W warn ((L2 '    Chocolatey no pudo instalar {0} (puede que el ID no exista en choco).' '    Chocolatey could not install {0} (the ID may not exist on choco).') -f $r.Id) }
                                    } else {
                                        W warn (L2 '    Fallback Choco activado, pero Chocolatey no esta instalado (instalalo para usarlo).' '    Choco fallback enabled, but Chocolatey is not installed (install it to use this).')
                                    }
                                }
                                if ($okFb) {
                                    $S.Ok++; $S.Done++
                                    W ok ((L2 '[OK] {0} - instalada via Chocolatey (fallback)' '[OK] {0} - installed via Chocolatey (fallback)') -f (NameOf $r.Id))
                                } else {
                                    $S.Fail++; $S.Done++
                                    W err ('[X]  {0} - {1}' -f (NameOf $r.Id), $m.Msg)
                                    W dim (L2 '    Ultimas lineas del instalador:' '    Last lines of the installer:')
                                    DumpFileTail $r.Out 10
                                    DumpFileTail $r.Err 6
                                    [void]$S.FailList.Add(('{0} - {1}' -f $r.Id, $m.Msg))
                                }
                            }
                            Remove-Item $r.Out, $r.Err -Force -ErrorAction SilentlyContinue
                            $running.Remove($r)
                            $S.CurPercent = 0
                        }
                    }
                    Start-Sleep -Milliseconds 250
                }
                if ($S.Cancel) { W warn (L2 'Proceso cancelado: no se lanzaron mas operaciones (las en curso se respetaron hasta terminar).' 'Process cancelled: no more operations were launched (running ones were left to finish).') }
                W head ((L2 'RESUMEN FINAL: {0} correctas | {1} fallidas | {2} procesadas de {3}' 'FINAL SUMMARY: {0} succeeded | {1} failed | {2} processed of {3}') -f $S.Ok, $S.Fail, $S.Done, $S.Total)
                foreach ($f in $S.FailList) { W err ((L2 '   fallo: ' '   failed: ') + $f) }
                if ($inst -and $S.Fail -gt 0) { W warn (L2 'Sugerencia: lo que falle en --silent suele entrar a mano con: winget install --id <ID> -e' 'Tip: anything failing under --silent usually installs manually with: winget install --id <ID> -e') }
            }

            'validate' {
                $S.Total = @($Ids).Count
                W head ((L2 'VALIDANDO {0} IDs contra el repositorio oficial de winget (4 hilos)...' 'VALIDATING {0} IDs against the official winget repository (4 threads)...') -f $S.Total)
                $pendQ = New-Object System.Collections.Queue
                foreach ($id in $Ids) { $pendQ.Enqueue($id) }
                $running = New-Object System.Collections.ArrayList
                $vLimit = 4
                while (($pendQ.Count -gt 0 -and -not $S.Cancel) -or $running.Count -gt 0) {
                    while ($pendQ.Count -gt 0 -and $running.Count -lt $vLimit -and -not $S.Cancel) {
                        $id = $pendQ.Dequeue()
                        $a = 'show --id "{0}" -e --accept-source-agreements --disable-interactivity' -f $id
                        $r = Start-One 'winget' $a
                        $r.Id = $id
                        [void]$running.Add($r)
                    }
                    foreach ($r in @($running)) {
                        if ($r.P.HasExited) {
                            if ($r.P.ExitCode -eq 0) {
                                $S.Ok++; $S.Done++
                                W ok ((L2 '[OK] ID valido: {0}' '[OK] valid ID: {0}') -f (NameOf $r.Id))
                            } else {
                                # Si winget show fallo, leemos el error de stderr para ver que ocurrio
                                $errTxt = ''
                                if (Test-Path $r.Err) { $errTxt = (Get-Content $r.Err -Raw -ErrorAction SilentlyContinue) }
                                if ($errTxt) { $errTxt = $errTxt.Trim() }

                                # Comprobamos si el ID es valido mediante 'winget search' exacto
                                $searchRaw = ''
                                try {
                                    $searchRaw = (& winget search -q $r.Id -e --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
                                } catch {}

                                $idFoundInSearch = $false
                                if ($searchRaw) {
                                    foreach ($c in (Parse-WingetTable $searchRaw)) {
                                        if ($c.Count -ge 2 -and ($c[1] -ieq $r.Id)) {
                                            $idFoundInSearch = $true
                                            break
                                        }
                                    }
                                }

                                if ($idFoundInSearch) {
                                    $S.Ok++; $S.Done++
                                    $reasonMsg = if ($errTxt) { L2 " (motivo del fallo de show: $errTxt)" " (reason for show failure: $errTxt)" } else { "" }
                                    W ok ((L2 '[OK] ID valido: {0} (verificado via search; show fallo temporalmente{1})' '[OK] valid ID: {0} (verified via search; show failed temporarily{1})') -f (NameOf $r.Id), $reasonMsg)
                                } else {
                                    $S.Fail++; $S.Done++
                                    $reasonMsg = if ($errTxt) { L2 " (motivo: $errTxt)" " (reason: $errTxt)" } else { "" }
                                    W err ((L2 '[X]  ID NO encontrado: {0}{1}  (corrige con: winget search <nombre>)' '[X]  ID NOT found: {0}{1}  (fix with: winget search <name>)') -f (NameOf $r.Id), $reasonMsg)
                                    [void]$S.FailList.Add($r.Id)
                                }
                            }
                            Remove-Item $r.Out, $r.Err -Force -ErrorAction SilentlyContinue
                            $running.Remove($r)
                        }
                    }
                    Start-Sleep -Milliseconds 200
                }
                W head ((L2 'VALIDACION TERMINADA: {0} validos, {1} invalidos de {2}.' 'VALIDATION FINISHED: {0} valid, {1} invalid of {2}.') -f $S.Ok, $S.Fail, $S.Done)
                if ($S.Fail -gt 0) {
                    W warn (L2 'IDs a corregir en el bloque $catalog del script:' 'IDs to fix in the script''s $catalog block:')
                    foreach ($f in $S.FailList) { W err ('   ' + $f) }
                    # Mejora: en vez de solo decir "no encontrado", proponemos Ids reales
                    # consultando 'winget search' por el nombre del paquete y mostrando candidatos.
                    W head (L2 'BUSCANDO IDs alternativos sugeridos (winget search)...' 'SEARCHING for suggested alternative IDs (winget search)...')
                    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
                    foreach ($f in $S.FailList) {
                        # Extraer solo el nombre de la app (ej. "Discord" de $Names o de "Discord.Discord")
                        $term = if ($Names.ContainsKey($f)) { $Names[$f] } else { ($f -split '\.')[-1] }
                        W info ((L2 '>>> Sugerencias para "{0}" (busqueda: {1}) ...' '>>> Suggestions for "{0}" (search: {1}) ...') -f $f, $term)
                        $raw = ''
                        try { $raw = (& winget search "$term" --accept-source-agreements --disable-interactivity 2>&1 | Out-String) } catch { $raw = '' }
                        $cands = @()
                        foreach ($c in (Parse-WingetTable $raw)) {
                            if ($c.Count -lt 2) { continue }
                            $cid = [string]$c[1]
                            if (-not $cid -or $cid -match '\s') { continue }
                            $cands += [pscustomobject]@{ Name = [string]$c[0]; Id = $cid }
                        }
                        if ($cands.Count -gt 0) {
                            foreach ($cd in ($cands | Select-Object -First 5)) {
                                $mark = if ($cd.Id -ieq $f) { L2 '  (coincide!)' '  (match!)' } else { '' }
                                W ok ('     -> {0}   [{1}]{2}' -f $cd.Name, $cd.Id, $mark)
                            }
                            $best = ($cands | Select-Object -First 1)
                            W dim ((L2 '        Sugerencia: usa el Id  {0}  en el catalogo.' '        Suggestion: use the ID  {0}  in the catalog.') -f $best.Id)
                        } else {
                            W warn ((L2 '     Sin candidatos para "{0}". Prueba un termino mas corto en el panel "Buscar en winget".' '     No candidates for "{0}". Try a shorter term in the "Search winget" panel.') -f $term)
                        }
                    }
                }
            }

            'detect' {
                $S.Total = 1
                W head (L2 'DETECTANDO aplicaciones del catalogo ya instaladas (winget export)...' 'DETECTING catalog apps already installed (winget export)...')
                $tmp = [IO.Path]::GetTempFileName()
                $r = Start-One 'winget' ('export -o "{0}" --accept-source-agreements --disable-interactivity' -f $tmp)
                while (-not $r.P.HasExited -and -not $S.Cancel) { Start-Sleep -Milliseconds 300 }
                if (-not $r.P.HasExited) { try { $r.P.Kill() } catch {} }
                $found = @()
                try {
                    $json = Get-Content $tmp -Raw -ErrorAction Stop | ConvertFrom-Json
                    $instMap = @{}
                    foreach ($src in @($json.Sources)) {
                        foreach ($p in @($src.Packages)) {
                            if ($p.PackageIdentifier) { $instMap[([string]$p.PackageIdentifier).ToLower()] = $true }
                        }
                    }
                    foreach ($id in $Ids) {
                        if ($instMap[$id.ToLower()]) { $found += $id; [void]$S.DetectList.Add($id) }
                    }
                } catch {
                    W warn ((L2 'No se pudo leer el export de winget: {0}' 'Could not read the winget export: {0}') -f $_.Exception.Message)
                }
                Remove-Item $tmp, $r.Out, $r.Err -Force -ErrorAction SilentlyContinue
                $S.Done = 1; $S.Ok = 1
                W head ((L2 'DETECCION TERMINADA: {0} de {1} apps del catalogo ya estan instaladas (se marcan en verde).' 'DETECTION FINISHED: {0} of {1} catalog apps are already installed (marked in green).') -f $found.Count, @($Ids).Count)
                foreach ($f in $found) { W ok ('   [Y] ' + (NameOf $f)) }
            }

            'upgrade' {
                $S.Total = 1
                W head (L2 'ACTUALIZANDO TODAS las aplicaciones instaladas (winget upgrade --all)...' 'UPDATING ALL installed applications (winget upgrade --all)...')
                $r = Start-One 'winget' 'upgrade --all --silent --include-unknown --accept-package-agreements --accept-source-agreements --disable-interactivity'
                while (-not $r.P.HasExited) { TailRead $r; Start-Sleep -Milliseconds 400 }
                TailRead $r
                $S.Done = 1; if ($r.P.ExitCode -eq 0) { $S.Ok = 1 } else { $S.Fail = 1 }
                Remove-Item $r.Out, $r.Err -Force -ErrorAction SilentlyContinue
                W head ((L2 'Actualizacion global finalizada (codigo 0x{0:X8}).' 'Global update finished (code 0x{0:X8}).') -f $r.P.ExitCode)
            }

            'scanupgrades' {
                $S.Total = 1
                W head (L2 'Buscando actualizaciones disponibles en TU equipo (winget upgrade)...' 'Searching for available updates on YOUR PC (winget upgrade)...')
                W dim (L2 '    winget detecta todos los programas instalados que reconoce.' '    winget detects every installed program it recognizes.')
                try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
                $raw = ''
                try { $raw = (& winget upgrade --include-unknown --accept-source-agreements --disable-interactivity 2>&1 | Out-String) } catch { $raw = '' }

                $count = 0
                foreach ($c in (Parse-WingetTable $raw)) {
                    if ($c.Count -lt 4) { continue }
                    $id = [string]$c[1]; $av = [string]$c[3]
                    if ($id -and $av -and $id -notmatch '\s') {
                        $src = if ($c.Count -ge 5) { [string]$c[4] } else { 'winget' }
                        [void]$S.Upgrades.Add([pscustomobject]@{ Name=[string]$c[0]; Id=$id; Cur=[string]$c[2]; Av=$av; Src=$src })
                        $count++
                    }
                }
                $S.Done = 1; $S.Ok = 1
                if ($count -eq 0) {
                    W head (L2 'No se han encontrado actualizaciones pendientes.' 'No pending updates were found.')
                    if ($raw -and $raw.Trim()) {
                        W warn (L2 'Si esperabas updates, esto es lo que winget devolvio (para diagnostico):' 'If you expected updates, this is what winget returned (for diagnostics):')
                        foreach ($ln in (($raw -split "`r?`n") | Select-Object -First 30)) { if ($ln.Trim()) { W dim ('  | ' + $ln) } }
                    } else {
                        W warn (L2 'winget no devolvio salida. Abre una consola y prueba: winget upgrade' 'winget returned no output. Open a console and try: winget upgrade')
                    }
                } else {
                    W head ((L2 '{0} actualizaciones disponibles. Revisa el panel "Actualizaciones".' '{0} updates available. Check the "Updates" panel.') -f $count)
                    foreach ($u in $S.Upgrades) { W ok ('   {0}  {1} -> {2}  [{3}]' -f $u.Name, $u.Cur, $u.Av, $u.Id) }
                }
            }

            'search' {
                $S.Total = 1
                W head ((L2 'Buscando "{0}" en todo el repositorio de winget...' 'Searching "{0}" across the entire winget repository...') -f $Query)
                try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
                $raw = ''
                try { $raw = (& winget search $Query --accept-source-agreements --disable-interactivity 2>&1 | Out-String) } catch { $raw = '' }

                $count = 0
                foreach ($c in (Parse-WingetTable $raw)) {
                    if ($c.Count -lt 2) { continue }
                    $id = [string]$c[1]
                    if (-not $id -or $id -match '\s') { continue }
                    $ver = if ($c.Count -ge 3) { [string]$c[2] } else { '' }
                    $src = [string]$c[$c.Count - 1]
                    [void]$S.SearchResults.Add([pscustomobject]@{ Name=[string]$c[0]; Id=$id; Ver=$ver; Src=$src })
                    $count++
                }
                $S.Done = 1; $S.Ok = 1
                if ($count -eq 0) {
                    W head ((L2 'Sin resultados para "{0}".' 'No results for "{0}".') -f $Query)
                    if ($raw -and $raw.Trim()) {
                        foreach ($ln in (($raw -split "`r?`n") | Select-Object -First 20)) { if ($ln.Trim()) { W dim ('  | ' + $ln) } }
                    }
                } else {
                    W head ((L2 '{0} resultados. Marca en el panel cuales instalar.' '{0} results. Check in the panel which ones to install.') -f $count)
                    foreach ($u in $S.SearchResults) { W ok ('   {0}  [{1}]  {2}' -f $u.Name, $u.Id, $u.Ver) }
                }
            }

            'tweaks' {
                $S.Total = @($TweakList).Count
                W head ((L2 'APLICANDO {0} TWEAKS seleccionados...' 'APPLYING {0} selected TWEAKS...') -f $S.Total)
                foreach ($t in $TweakList) {
                    if ($S.Cancel) { W warn (L2 'Cancelado: no se aplicaran mas tweaks.' 'Cancelled: no more tweaks will be applied.'); break }
                    W info ('>>> Tweak: {0}' -f $t.Name)
                    try {
                        # IMPORTANTE: el Code se ejecuta en un AMBITO HIJO (& scriptblock) y
                        # NO con Invoke-Expression. Asi las variables que defina el Code
                        # (p.ej. 'foreach ($s in ...)') no pisan las del motor: en PowerShell
                        # los nombres son insensibles a mayusculas, y '$s' colisionaria con
                        # '$S' (el objeto State), corrompiendolo y dejando la app inservible.
                        & ([scriptblock]::Create([string]$t.Code))
                        $S.Ok++
                    } catch {
                        $S.Fail++
                        W err ((L2 '[X] Tweak "{0}" fallo: {1}' '[X] Tweak "{0}" failed: {1}') -f $t.Name, $_.Exception.Message)
                    }
                    $S.Done++
                }
                W head ((L2 'TWEAKS TERMINADOS: {0} aplicados, {1} con error.' 'TWEAKS FINISHED: {0} applied, {1} with errors.') -f $S.Ok, $S.Fail)
            }

            'debloat' {
                $S.Total = @($TweakList).Count
                W head ((L2 'QUITANDO {0} apps preinstaladas seleccionadas...' 'REMOVING {0} selected preinstalled apps...') -f $S.Total)
                W dim (L2 '    Se eliminan para el usuario actual; son reinstalables desde la Store.' '    They are removed for the current user; they can be reinstalled from the Store.')
                foreach ($t in $TweakList) {
                    if ($S.Cancel) { W warn (L2 'Cancelado: no se quitaran mas apps.' 'Cancelled: no more apps will be removed.'); break }
                    W info ((L2 '>>> Quitando: {0}' '>>> Removing: {0}') -f $t.Name)
                    try {
                        $patterns = @(($t.Pkg -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                        $matched = 0; $removed = 0; $failed = 0
                        # Usuario actual (Get-AppxPackage / Remove-AppxPackage)
                        $found = @($patterns | ForEach-Object { Get-AppxPackage -Name $_ -ErrorAction SilentlyContinue })
                        foreach ($pkg in $found) {
                            $matched++
                            try { $pkg | Remove-AppxPackage -ErrorAction Stop; $removed++; W ok ((L2 '    quitado: {0}' '    removed: {0}') -f $pkg.Name) }
                            catch { $failed++; W warn ((L2 '    fallo: {0} :: {1}' '    failed: {0} :: {1}') -f $pkg.Name, $_.Exception.Message) }
                        }
                        # Provisionado para nuevos usuarios (Remove-AppxProvisionedPackage -Online)
                        try {
                            $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                                Where-Object { $dn = $_.DisplayName; @($patterns | Where-Object { $dn -like $_ }).Count -gt 0 })
                            foreach ($pp in $prov) {
                                $matched++
                                try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null; $removed++; W ok ((L2 '    quitado: {0}' '    removed: {0}') -f $pp.DisplayName) }
                                catch { $failed++; W warn ((L2 '    fallo: {0} :: {1}' '    failed: {0} :: {1}') -f $pp.DisplayName, $_.Exception.Message) }
                            }
                        } catch {}
                        # Registro uniforme por item: quitado / no estaba presente / fallo
                        if ($matched -eq 0) { W dim ((L2 '    no estaba presente: {0}' '    was not present: {0}') -f $t.Name); $S.Ok++ }
                        elseif ($failed -eq 0) { $S.Ok++; W ok ((L2 '[OK] {0} eliminada.' '[OK] {0} removed.') -f $t.Name) }
                        else { $S.Fail++; W err ((L2 '[X]  {0} no se pudo eliminar del todo ({1} quitado(s), {2} con fallo).' '[X]  {0} could not be fully removed ({1} removed, {2} failed).') -f $t.Name, $removed, $failed) }
                    } catch {
                        $S.Fail++
                        W err ((L2 '[X] "{0}" fallo: {1}' '[X] "{0}" failed: {1}') -f $t.Name, $_.Exception.Message)
                    }
                    $S.Done++
                }
                W head ((L2 'DEBLOAT TERMINADO: {0} ok, {1} con error.' 'DEBLOAT FINISHED: {0} ok, {1} with errors.') -f $S.Ok, $S.Fail)
            }

            'snapexport' {
                $S.Total = 1
                W head ((L2 'Exportando TODO el equipo a: {0}' 'Exporting the WHOLE PC to: {0}') -f $Query)
                try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
                $out = ''
                try { $out = (& winget export -o $Query --accept-source-agreements --disable-interactivity 2>&1 | Out-String) } catch {}
                if (Test-Path $Query) {
                    $S.Ok = 1
                    W ok (L2 'Exportado correctamente. Ya puedes llevar ese archivo a otro PC e Importarlo.' 'Exported successfully. You can now take that file to another PC and Import it.')
                } else {
                    $S.Fail = 1
                    W err (L2 'No se pudo exportar.' 'Export failed.')
                    if ($out.Trim()) { foreach ($ln in (($out -split "`r?`n") | Select-Object -First 12)) { if ($ln.Trim()) { W dim ('  | ' + $ln) } } }
                }
                $S.Done = 1
            }

            'snapimport' {
                $S.Total = 1
                W head ((L2 'Importando e instalando desde: {0}' 'Importing and installing from: {0}') -f $Query)
                W dim (L2 '    Puede tardar: instala lo que falte del archivo (omite lo no disponible).' '    May take a while: installs whatever is missing from the file (skips unavailable items).')
                try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
                try {
                    & winget import -i $Query --accept-source-agreements --accept-package-agreements --disable-interactivity --ignore-unavailable --no-upgrade 2>&1 |
                        ForEach-Object { $t = [string]$_; if ($t.Trim()) { W dim ('    ' + $t) } }
                    $S.Ok = 1
                } catch { $S.Fail = 1; W err $_.Exception.Message }
                $S.Done = 1
                W head (L2 'Importacion terminada. Revisa arriba el detalle de winget.' 'Import finished. Check the winget detail above.')
            }
        }
    } catch {
        W err ((L2 'Error inesperado del motor: {0}' 'Unexpected engine error: {0}') -f $_.Exception.Message)
    } finally {
        # P4: limpiar temporales huerfanos (stdout/stderr de instaladores) que
        # puedan haber quedado si un proceso se mato a media instalacion.
        try {
            foreach ($f in @($script:WpiTempFiles)) {
                if ($f -and (Test-Path $f)) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
            }
        } catch {}
        $S.Running = $false
    }
}

# --------------------- TEMA (claro/oscuro) ------------------
# C1: sistema de tema. La paleta OSCURA es la base (sin cambios). El tema CLARO
# se obtiene mapeando cada color oscuro a su equivalente claro, tanto en el XAML
# (Convert-XamlTheme, antes de cargarlo) como en el codigo (Get-ThemeBrush, que
# sustituye a $bc.ConvertFromString). Con tema Oscuro el mapeo es identidad, asi
# que el comportamiento por defecto es IDENTICO al de siempre. Se cambia por
# ajuste persistente (wpi_settings.json -> Theme) y relanzando la app.
$script:ThemeName = 'Dark'
try {
    if (Test-Path $Config.SettingsFile) {
        $____s = Get-Content $Config.SettingsFile -Raw | ConvertFrom-Json
        $____tn = [string]$____s.Theme
        if ($____tn -eq 'Light' -or $____tn -eq 'Blue') { $script:ThemeName = $____tn }
    }
} catch {}
$script:LightMap = @{
    # --- Fondos suaves (pagina y superficies) ---
    '#FF0B0B11'='#FFEDF0F6'; '#FF0F0F17'='#FFEDF0F6'; '#FF101018'='#FFEDF0F6'; '#FF101A2B'='#FFE8EEF7'
    '#FF12121A'='#FFF2F4F9'; '#FF15151F'='#FFFFFFFF'; '#FF1B1B25'='#FFF7F9FC'; '#FF1C1C2A'='#FFF2F4F9'
    '#FF20202E'='#FFE7EDF7'
    # --- Superficies con tinte por intencion (texto oscuro) ---
    '#FF160F26'='#FFF0EAFB'; '#FF3A2A6E'='#FFEDE7FB'; '#FF13414F'='#FF1F7A8C'; '#FF134B52'='#FF1F7A8C'
    '#FF0A4D5E'='#FFE0F2F6'; '#FF1F3A4F'='#FFE8F0F9'; '#FF1F4F1F'='#FFE2F3E8'; '#FF55471A'='#FF8A6512'
    '#FF4F1F1F'='#FFFBE5E5'
    # --- BOTONES (relleno solido de color, texto blanco) ---
    '#FF22222C'='#FF64779B'; '#FF2C2C3C'='#FF4E6390'; '#FF24303F'='#FF4C7CB8'; '#FF243042'='#FF4C7CB8'
    '#FF2A3F4F'='#FF4C7CB8'; '#FF2B3A4F'='#FF5687BE'; '#FF2F4A2A'='#FF56A06A'; '#FF1F3A2E'='#FF56A06A'
    '#FF3A2A4F'='#FF8267BE'; '#FF4F2A2A'='#FFC15F5C'; '#FF4A2F12'='#FFE5862F'; '#FF0A84FF'='#FF2979D6'
    # --- Bordes (tarjetas y botones) ---
    '#FF2C2C3A'='#FFD6DAE4'; '#FF3A3A48'='#FFC6CBD6'; '#FF55555F'='#FFAAB0BE'; '#FF3C5876'='#FF3568A0'
    '#FF4477AA'='#FF3568A0'; '#FF3F5E80'='#FF3568A0'; '#FF3F6E9E'='#FF3568A0'; '#FF6B4D9E'='#FF6A4DA8'
    '#FF4F7B44'='#FF3E8A50'; '#FF3E6B54'='#FF3E8A50'; '#FF6B5A1F'='#FFB8943A'; '#FF7B4444'='#FF9E4542'
    '#FF5A2222'='#FFB94B4B'; '#FF35A0FF'='#FF1E62B5'
    # --- Texto (oscuro suave, no negro puro) ---
    '#FFE6E6EC'='#FF2A2E3A'; '#FFEDEDF2'='#FF2A2E3A'; '#FFC9C9D4'='#FF4A4E5A'; '#FFCFCFD8'='#FF4A4E5A'
    '#FFB0B0BC'='#FF5A5E6A'; '#FF8A8A95'='#FF6E7280'; '#FF9A9AA5'='#FF7A7E8C'; '#FF6F6F7A'='#FF6E7280'
    # --- Acentos por intencion (suaves, no chillones) ---
    '#FF00E5FF'='#FF1397B0'; '#FF76E0FF'='#FF2BA6C4'; '#FF3F9EFF'='#FF2E72C8'; '#FF5CFF8F'='#FF3A9D5E'
    '#FF4F9E4F'='#FF3A9D5E'; '#FFFFD166'='#FFC2912A'; '#FFFF6B6B'='#FFD0504E'; '#FFB388FF'='#FF7E5BC4'
    '#FF7C4DFF'='#FF6A45C0'; '#FF9D7BFF'='#FF7E5BC4'; '#FFFF9E64'='#FFE57A2E'
}
# Tema AZUL estilo Chris Titus (WinUtil): navy oscuro con acentos azules.
$script:BlueMap = @{
    '#FF00E5FF'='#FF36C7F0'; '#FF0A4D5E'='#FF123A5E'; '#FF0A84FF'='#FF2E8BFF'; '#FF0B0B11'='#FF0A1424'
    '#FF0F0F17'='#FF0A1424'; '#FF101018'='#FF0A1424'; '#FF101A2B'='#FF0C1B33'; '#FF12121A'='#FF0E1A2E'
    '#FF13414F'='#FF123A5E'; '#FF134B52'='#FF123A5E'; '#FF15151F'='#FF112038'; '#FF160F26'='#FF14233E'
    '#FF1B1B25'='#FF13243E'; '#FF1C1C2A'='#FF13243E'; '#FF1F3A2E'='#FF12402F'; '#FF1F3A4F'='#FF173456'
    '#FF1F4F1F'='#FF12402F'; '#FF20202E'='#FF15273F'; '#FF22222C'='#FF15273F'; '#FF24303F'='#FF173456'
    '#FF243042'='#FF173456'; '#FF2A3F4F'='#FF1B3C5E'; '#FF2B3A4F'='#FF1B3C5E'; '#FF2C2C3A'='#FF274A72'
    '#FF2C2C3C'='#FF274A72'; '#FF2F4A2A'='#FF184A34'; '#FF35A0FF'='#FF54A6FF'; '#FF3A2A4F'='#FF1E3357'
    '#FF3A2A6E'='#FF223B6B'; '#FF3A3A48'='#FF2C507A'; '#FF3C5876'='#FF3A6CA0'; '#FF3E6B54'='#FF2E6E84'
    '#FF3F5E80'='#FF3A6CA0'; '#FF3F6E9E'='#FF3A6CA0'; '#FF3F9EFF'='#FF54A6FF'; '#FF4477AA'='#FF4A86C4'
    '#FF4A2F12'='#FF3A2F14'; '#FF4F1F1F'='#FF4A1F24'; '#FF4F2A2A'='#FF4A1F24'; '#FF4F7B44'='#FF2E6E84'
    '#FF4F9E4F'='#FF3FA06A'; '#FF55471A'='#FF44391A'; '#FF55555F'='#FF2C507A'; '#FF5A2222'='#FF6A2A30'
    '#FF5CFF8F'='#FF49E59B'; '#FF6B4D9E'='#FF3F6BB0'; '#FF6B5A1F'='#FF6B5A1F'; '#FF6F6F7A'='#FF8AA6CC'
    '#FF76E0FF'='#FF5AD0F5'; '#FF7B4444'='#FF8A4450'; '#FF7C4DFF'='#FF4D8BFF'; '#FF8A8A95'='#FF8AA6CC'
    '#FF9A9AA5'='#FF94AFD2'; '#FF9D7BFF'='#FF6FA8FF'; '#FFB0B0BC'='#FFAEC6E6'; '#FFB388FF'='#FF6FA8FF'
    '#FFC9C9D4'='#FFC2D6EF'; '#FFCFCFD8'='#FFC2D6EF'; '#FFE6E6EC'='#FFEAF2FF'; '#FFEDEDF2'='#FFEAF2FF'
    '#FFFF6B6B'='#FFFF7A7A'; '#FFFF9E64'='#FFFFA869'; '#FFFFD166'='#FFFFD98A'
}
# Devuelve el mapa de color del tema activo (o $null si es Oscuro = identidad).
function Get-ThemeMap {
    if ($script:ThemeName -eq 'Light') { return $script:LightMap }
    if ($script:ThemeName -eq 'Blue')  { return $script:BlueMap }
    return $null
}
function Convert-XamlTheme([string]$s) {
    $m = Get-ThemeMap
    if (-not $m) { return $s }
    foreach ($k in $m.Keys) {
        $s = [regex]::Replace($s, [regex]::Escape($k), $m[$k], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $s
}

# --------------------- IDIOMA (i18n, C2) --------------------
# Base de internacionalizacion. La navegacion y cabeceras se traducen con T();
# el resto de la interfaz (descripciones, estados, hardware, dialogos, ISO,
# guias) se traduce ES->EN por recorrido del arbol con Tr()/$script:TrMap. Solo
# los nombres propios de apps del catalogo se mantienen. Se cambia por ajuste
# persistente (wpi_settings.json -> Lang) y relanzando, como el tema.
$script:Lang = 'es'
try {
    if (Test-Path $Config.SettingsFile) {
        $____s2 = Get-Content $Config.SettingsFile -Raw | ConvertFrom-Json
        if ([string]$____s2.Lang -eq 'en') { $script:Lang = 'en' }
    }
} catch {}
$script:Strings = @{
    es = @{
        blk_inicio='INICIO'; blk_instalar='INSTALAR'; blk_optimizar='OPTIMIZAR'; blk_limpiar='LIMPIAR'
        blk_mantener='MANTENER'; blk_iso='CREAR ISO'; blk_info='INFORMACION'
        nav_quick='Inicio rapido (modo facil)'; nav_find='Buscar en todo (global)'; nav_allapps='Todas las apps'
        nav_search='Buscar en winget (todo)'; nav_snapshot='Clonar equipo / Snapshot'; nav_upgrades='Actualizaciones disponibles'
        nav_tweaks='Tweaks y ajustes'; nav_winupdate='Windows Update'; nav_debloat='Quitar bloatware (Appx)'
        nav_repair='Reparacion'; nav_features='Caracteristicas de Windows'; nav_drivers='Drivers y hardware'
        nav_createiso='Crear ISO de Windows (avanzado)'; nav_summary='Resumen del sistema'; nav_guides='Guias en espanol'
        nav_logs='Visor de logs'; lbl_lang='Idioma'
    }
    en = @{
        blk_inicio='START'; blk_instalar='INSTALL'; blk_optimizar='OPTIMIZE'; blk_limpiar='CLEAN'
        blk_mantener='MAINTAIN'; blk_iso='CREATE ISO'; blk_info='INFORMATION'
        nav_quick='Quick start (easy mode)'; nav_find='Search everything (global)'; nav_allapps='All apps'
        nav_search='Search in winget (all)'; nav_snapshot='Clone PC / Snapshot'; nav_upgrades='Available updates'
        nav_tweaks='Tweaks and settings'; nav_winupdate='Windows Update'; nav_debloat='Remove bloatware (Appx)'
        nav_repair='Repair'; nav_features='Windows features'; nav_drivers='Drivers and hardware'
        nav_createiso='Create Windows ISO (advanced)'; nav_summary='System summary'; nav_guides='Guides'
        nav_logs='Log viewer'; lbl_lang='Language'
    }
}
function T([string]$k) {
    $tbl = $script:Strings[$script:Lang]
    if ($tbl -and $tbl.ContainsKey($k)) { return [string]$tbl[$k] }
    $es = $script:Strings['es']
    if ($es -and $es.ContainsKey($k)) { return [string]$es[$k] }
    return $k
}

# Mapa de frases ES->EN para traducir TODA la interfaz por recorrido del arbol.
$script:TrMap = @{}
# << TRMAP_ENTRIES >>
$script:TrMap['motor winget asincrono']='async winget engine'
$script:TrMap['Instalador Post-Windows']='Post-Windows Installer'
$script:TrMap['Tema: Oscuro']='Theme: Dark'
$script:TrMap['Tema: Claro']='Theme: Light'
$script:TrMap['Tema: Azul (Chris Titus)']='Theme: Blue (Chris Titus)'
$script:TrMap['Libre en {0} {1} GB']='Free on {0} {1} GB'
$script:TrMap['{0} apps en catalogo  ·  {1} tweaks']='{0} apps in catalog  ·  {1} tweaks'
$script:TrMap['GRUPO 1 - Apps del catalogo WPI']='GROUP 1 - WPI catalog apps'
$script:TrMap['GRUPO 2 - Otros programas de TU PC']='GROUP 2 - Other programs on YOUR PC'
$script:TrMap['GRUPO 1 - Apps del catalogo WPI  ({0})']='GROUP 1 - WPI catalog apps  ({0})'
$script:TrMap['GRUPO 2 - Otros programas de TU PC  ({0})']='GROUP 2 - Other programs on YOUR PC  ({0})'
$script:TrMap['GRUPO 1 - Apps del catalogo WPI  (0: ninguna del catalogo necesita update)']='GROUP 1 - WPI catalog apps  (0: none of the catalog needs an update)'
$script:TrMap['ACTUALIZAR OTROS PROGRAMAS DE MI PC ({0})']='UPDATE OTHER PROGRAMS ON MY PC ({0})'
$script:TrMap['ACTUALIZAR APPS DEL CATALOGO WPI ({0})']='UPDATE WPI CATALOG APPS ({0})'
$script:TrMap['DESCARGAR INSTALADOR ({0})']='DOWNLOAD INSTALLER ({0})'
$script:TrMap['Presets (de mas seguro a mas agresivo):']='Presets (safest to most aggressive):'
$script:TrMap['Buscar tweak por nombre o descripcion...']='Search tweaks by name or description...'
$script:TrMap['Buscar app preinstalada...']='Search preinstalled app...'
$script:TrMap['Seguro']='Safe'
$script:TrMap['Equilibrado']='Balanced'
$script:TrMap['Agresivo']='Aggressive'
$script:TrMap['Preset {0}: marcados {1} ajustes. Revisa la seleccion y pulsa APLICAR SELECCIONADOS.']='Preset {0}: {1} settings checked. Review the selection and press APPLY SELECTED.'
$script:TrMap['Marca solo los ajustes de bajo riesgo, reversibles y recomendados para cualquier PC.']='Checks only the low-risk, reversible settings recommended for any PC.'
$script:TrMap['Marca los seguros + avanzados de uso general (sin advertencias de hardware). Buen equilibrio rendimiento/seguridad.']='Checks the safe ones + general-purpose advanced ones (no hardware warnings). A good performance/safety balance.'
$script:TrMap['Marca TODOS los ajustes, incluidos los avanzados mas fuertes. Maximo impacto: revisa antes de aplicar.']='Checks ALL settings, including the strongest advanced ones. Maximum impact: review before applying.'
$script:TrMap['Quita todas las marcas.']='Clears all checks.'
$script:TrMap['IMPORTANTE: antes de grabar con Rufus, comprueba que la ISO lo lleva todo (C:\WPI, autounattend, ediciones, drivers, winget). Pulsa el boton; abre una consola como administrador, monta la ISO y te da un veredicto claro.']='IMPORTANT: before burning with Rufus, check that the ISO contains everything (C:\WPI, autounattend, editions, drivers, winget). Press the button; it opens a console as administrator, mounts the ISO and gives you a clear verdict.'
$script:TrMap['Aun no has escaneado. Pulsa "Buscar updates" (el boton azul de aqui arriba) para empezar.']='Not scanned yet. Click "Check updates" (the blue button just above) to start.'
$script:TrMap['Pulsa "Buscar updates" (el boton de aqui arriba, o en la barra inferior) para escanear. Los resultados se separan en dos grupos para no mezclar nada. Cada boton actualiza SOLO su grupo. Nota: winget no guarda copias propias aparte; en ambos casos se actualizan programas instalados en tu equipo. La ventaja es que el Grupo 1 nunca toca nada que no sea del catalogo WPI.']='Click "Check updates" (the button just above, or in the bottom bar) to scan. Results are split into two groups so nothing gets mixed. Each button updates ONLY its group. Note: winget does not keep separate copies; in both cases it updates programs installed on your PC. The advantage is that Group 1 never touches anything outside the WPI catalog.'
$script:TrMap['Buscar updates ahora']='Check for updates now'
$script:TrMap['Buscando actualizaciones...']='Checking for updates...'
$script:TrMap['VERIFICACION POST-ACTUALIZACION: estas NO se actualizaron de verdad (winget informo exito, pero la version instalada no cambio):']='POST-UPDATE VERIFICATION: these were NOT actually updated (winget reported success, but the installed version did not change):'
$script:TrMap['Cierra esas apps si estan abiertas, reinicia el equipo, o puede que se auto-actualicen por su cuenta. Vuelve a pulsar Buscar updates para reconfirmar.']='Close those apps if they are open, reboot, or they may self-update on their own. Click Check updates again to re-confirm.'
$script:TrMap['{0}  Marcados {1} ajustes recomendados para tu equipo (revisa y pulsa APLICAR SELECCIONADOS).']='{0}  Marked {1} recommended tweaks for your PC (review and click APPLY SELECTED).'
$script:TrMap['INSTALAR SELECCIONADAS ({0})']='INSTALL SELECTED ({0})'
$script:TrMap['QUITAR SELECCIONADAS ({0})']='REMOVE SELECTED ({0})'
$script:TrMap['GPU detectada: {0}.  Para tener el driver al dia, instala su app oficial:']='GPU detected: {0}.  To keep the driver up to date, install its official app:'
$script:TrMap['Abrir web oficial de drivers ({0})']='Open official driver website ({0})'
$script:TrMap['GPU no identificada. Elige tu fabricante para descargar el driver oficial:']='GPU not identified. Choose your vendor to download the official driver:'
$script:TrMap['Otros fabricantes (siempre disponibles):']='Other vendors (always available):'
$script:TrMap['RECORDATORIO: si lo dejas MARCADO, los drivers van DENTRO de la ISO y Windows arrancara con red/chipset listos. Si lo DESMARCAS, tendras que instalar los drivers A MANO despues de instalar Windows.']='REMINDER: if you leave it CHECKED, the drivers go INSIDE the ISO and Windows boots with network/chipset ready. If you UNCHECK it, you will have to install the drivers BY HAND after installing Windows.'
$script:TrMap['Usar mi seleccion de Apps']='Use my app selection'
$script:TrMap['No tienes ninguna app marcada en la pestana Apps. Marca alli las que quieras incluir en la ISO y vuelve a pulsar este boton.']='You have no apps checked in the Apps tab. Check the ones you want to include in the ISO there, then click this button again.'
$script:TrMap['Marcadas {0} apps de tu seleccion de la pestana Apps.']='Checked {0} apps from your selection in the Apps tab.'
$script:TrMap['RECORDATORIO: marca "Modo VM" SOLO en maquina virtual o disco desechable (formatea el disco 0 sin preguntar). En un PC fisico con tus datos, dejalo DESACTIVADO y elige el disco a mano durante la instalacion. Te lo recordare al pasar de paso.']='REMINDER: check "VM Mode" ONLY on a virtual machine or a disposable disk (it wipes disk 0 without asking). On a physical PC with your data, leave it OFF and pick the disk by hand during setup. I will remind you when you move on.'
$script:TrMap['AMD distribuye su software Adrenalin desde su web (no por winget); usa el boton de arriba.']='AMD distributes its Adrenalin software from its website (not via winget); use the button above.'
$script:TrMap['La NVIDIA App (sustituye a GeForce Experience) se descarga de la web oficial; instala el driver "Game Ready" o "Studio" desde ella.']='The NVIDIA App (replaces GeForce Experience) downloads from the official site; install the "Game Ready" or "Studio" driver from it.'
$script:TrMap['Estado detectado en este PC: {0} de {1} ajustes ya aplicados ({2} comprobables, el resto son acciones puntuales). Verde = aplicado.']='Detected status on this PC: {0} of {1} tweaks already applied ({2} checkable, the rest are one-off actions). Green = applied.'
$script:TrMap['Estado en este PC: {0} de {1} apps de la lista siguen instaladas. Ambar = instalada (se puede quitar); verde = ya no esta.']='Status on this PC: {0} of {1} listed apps are still installed. Amber = installed (can be removed); green = already gone.'
$script:TrMap['Estado en este PC: {0} de {1} caracteristicas habilitadas/instaladas. Verde = activa; ambar = disponible para activar.']='Status on this PC: {0} of {1} features enabled/installed. Green = active; amber = available to enable.'
$script:TrMap['Sin resultados para "{0}".']='No results for "{0}".'
$script:TrMap['No se pudo leer el log: ']='Could not read the log: '
$script:TrMap['Usando catalogo EXTERNO: {0} ({1} apps). Editalo y recarga para aplicar cambios.']='Using EXTERNAL catalog: {0} ({1} apps). Edit it and reload to apply changes.'
$script:TrMap['Ahora mismo usas el catalogo interno ({0} apps). Crea catalogo.json para personalizarlo sin tocar el codigo.']='You are currently using the internal catalog ({0} apps). Create catalogo.json to customize it without touching the code.'
$script:TrMap['Multi-sistema']='Multi-system'
$script:TrMap['Nintendo']='Nintendo'
$script:TrMap['PlayStation']='PlayStation'
$script:TrMap['Xbox y PC']='Xbox & PC'
$script:TrMap['Ver guia en espanol']='View guide (Spanish)'
$script:TrMap['Estado: pulsa "Re-detectar estado" o entra a esta seccion para escanear que ajustes ya estan aplicados.']='Status: click "Re-detect status" or open this section to scan which tweaks are already applied.'
$script:TrMap['Programas que winget ha detectado instalados en tu PC y NO estan en el catalogo WPI (los instalaste tu a mano, la Store, etc.). Tu decides si tocar algo aqui.']='Programs that winget detected installed on your PC and are NOT in the WPI catalog (you installed them manually, the Store, etc.). You decide whether to touch anything here.'
$script:TrMap['No se han encontrado actualizaciones pendientes. Tu equipo esta al dia.']='No pending updates found. Your PC is up to date.'
$script:TrMap['Busca cualquier programa en TODO el repositorio de winget (no solo en el catalogo WPI de 200). Escribe un nombre y pulsa Buscar; marca lo que quieras e instalalo con el mismo motor (paralelismo, reintentos y log).']='Search for any program across the ENTIRE winget repository (not just the WPI catalog of 200). Type a name and click Search; mark what you want and install it with the same engine (parallelism, retries and log).'
$script:TrMap['Escribe un nombre (ej: "obs", "7zip", "blender") y pulsa Buscar en winget.']='Type a name (e.g. "obs", "7zip", "blender") and click Search on winget.'
$script:TrMap['Elimina la basura que trae Windows de fabrica. Marca solo lo que quieras quitar (nada viene preseleccionado). Se borra para tu usuario y se evita que vuelva; todo es reinstalable desde la Microsoft Store. No se incluyen componentes criticos del sistema.']='Removes the junk Windows ships from the factory. Mark only what you want to remove (nothing is preselected). It is removed for your user and prevented from coming back; everything is reinstallable from the Microsoft Store. Critical system components are not included.'
$script:TrMap['Estado: entra a esta seccion o pulsa "Re-detectar estado" para ver que apps siguen instaladas.']='Status: open this section or click "Re-detect status" to see which apps are still installed.'
$script:TrMap['Exporta TODO lo que tienes instalado (que winget reconozca) a un archivo, y reimportalo en otro PC para dejarlo igual de un golpe. Ideal si formateas a menudo o montas varias maquinas. Usa el formato oficial de winget import.']='Exports EVERYTHING you have installed (that winget recognizes) to a file, and re-imports it on another PC to set it up identically in one go. Ideal if you reformat often or build several machines. Uses the official winget import format.'
$script:TrMap['Pasos para dejar listos los programas que necesitan algo extra (BIOS, firmware, claves...) y para los emuladores que NO estan en winget (Switch, Android). Pulsa cada titulo para desplegarlo. Al instalar o descargar una app con guia, la consola te avisa.']='Steps to get ready the programs that need something extra (BIOS, firmware, keys...) and the emulators that are NOT on winget (Switch, Android). Click each title to expand it. When you install or download an app with a guide, the console warns you.'
$script:TrMap['Detecta tus piezas y el driver de la grafica que tienes ahora. Para actualizar drivers, lo seguro es la herramienta OFICIAL del fabricante (no usamos programas de "drivers todo en uno", suelen traer publicidad y drivers erroneos). Tambien tienes acceso directo a Windows Update opcional y al soporte de tu placa.']='Detects your parts and the graphics driver you have right now. To update drivers, the safe way is the manufacturer''s OFFICIAL tool (we do not use "all-in-one driver" programs, they usually bring ads and wrong drivers). You also get a direct link to optional Windows Update and to your motherboard support.'
$script:TrMap['Exporta TODOS los drivers de terceros antes de formatear y reinyectalos despues (joya post-formateo). La copia es solo lectura del sistema; la restauracion es para un equipo recien reinstalado. Ambas corren por el motor con log.']='Exports ALL third-party drivers before reformatting and re-injects them afterwards (a post-format gem). The backup is read-only on the system; the restore is for a freshly reinstalled PC. Both run through the engine with a log.'
$script:TrMap['Apps gratuitas del catalogo utiles para el hardware que se ha detectado:']='Free catalog apps useful for the hardware that was detected:'
$script:TrMap['Foto del estado actual de tu PC segun lo que gestiona el WPI. Solo lectura: no cambia nada. Se actualiza cada vez que entras aqui.']='Snapshot of your PC''s current state according to what WPI manages. Read-only: it changes nothing. It refreshes every time you enter here.'
$script:TrMap['Captura todo tu PC en un solo JSON y replicalo en otro equipo. "Aplicar perfil completo" crea un punto de restauracion y relanza el WPI como administrador en modo desatendido.']='Captures your whole PC into a single JSON and replicates it on another machine. "Apply full profile" creates a restore point and relaunches WPI as administrator in unattended mode.'
$script:TrMap['Mide el impacto real de tus cambios. Toma una "foto" del sistema (servicios, procesos, apps de inicio, RAM, arranque), aplica tweaks/debloat, y compara para ver el delta. La foto se guarda en wpi_baseline.json junto al WPI.']='Measures the real impact of your changes. Takes a "snapshot" of the system (services, processes, startup apps, RAM, boot), applies tweaks/debloat, and compares to see the delta. The snapshot is saved in wpi_baseline.json next to WPI.'
$script:TrMap['Decide como y cuando se actualiza Windows. Cada accion se aplica al pulsar su boton y queda en el log forense. "Valores por defecto" deshace cualquier cambio de esta lista.']='Decide how and when Windows updates. Each action is applied when you click its button and stays in the forensic log. "Default values" undoes any change from this list.'
$script:TrMap['Marca las apps que se instalaran solas en el primer arranque (via winget), DIVIDIDAS POR SECCION (Navegadores, Multimedia, etc.). Usa el buscador para filtrar. Por defecto se traen las que tengas marcadas en la pestana Apps.']='Mark the apps that will install themselves on first boot (via winget), SPLIT BY SECTION (Browsers, Multimedia, etc.). Use the search box to filter. By default it brings the ones you marked on the Apps tab.'
$script:TrMap['Inyecta drivers (.inf) en la imagen para que el equipo arranque con red/chipset. Elige una carpeta con .inf, o si NO tienes ninguna, crea ahora mismo una copia de los drivers que tienes instalados con el boton de abajo.']='Injects drivers (.inf) into the image so the PC boots with network/chipset. Pick a folder with .inf files, or if you do NOT have any, create a backup of your currently installed drivers right now with the button below.'
$script:TrMap['No tengo: crear copia (.inf) de mis drivers actuales']='I do not have any: create a backup (.inf) of my current drivers'
$script:TrMap['Que es el "kit": una carpeta (WPI_ISO_Kit) con todo lo necesario: tu configuracion, el autounattend.xml, el script que crea la ISO, el preset de apps, una copia de WPI y las guias. NO hace falta generar el kit antes de crear la ISO: el boton "Confirmar y CREAR la ISO" ya lo prepara solo y lanza el proceso como administrador. "Generar kit" es OPCIONAL, solo si quieres revisar o editar esos archivos antes.']='What the "kit" is: a folder (WPI_ISO_Kit) with everything needed: your configuration, the autounattend.xml, the script that creates the ISO, the apps preset, a copy of WPI and the guides. You do NOT need to generate the kit before creating the ISO: the "Confirm and CREATE the ISO" button prepares it on its own and launches the process as administrator. "Generate kit" is OPTIONAL, only if you want to review or edit those files first.'
$script:TrMap['Activa o desactiva componentes opcionales de Windows (DISM). Cada accion corre por el motor con log forense y es reversible (Habilitar/Deshabilitar). Las marcadas "pide reinicio" requieren reiniciar para completarse. Algunas solo existen en Windows Pro/Enterprise.']='Enables or disables optional Windows components (DISM). Each action runs through the engine with a forensic log and is reversible (Enable/Disable). Those marked "needs restart" require a restart to complete. Some only exist on Windows Pro/Enterprise.'
$script:TrMap['Todo lo de reparacion en un solo sitio: la SUITE completa en 17 fases (motor externo) y, debajo, herramientas rapidas de un clic. Son acciones fuertes: corren con log forense y algunas piden reinicio.']='Everything about repair in one place: the complete 17-phase SUITE (external engine) and, below, quick one-click tools. These are strong actions: they run with a forensic log and some ask for a restart.'
$script:TrMap['Acciones sueltas de un clic (SFC, DISM, red, Windows Update, winget...). Cada una corre por el motor con log forense.']='One-click standalone actions (SFC, DISM, network, Windows Update, winget...). Each one runs through the engine with a forensic log.'
$script:TrMap['O&O ShutUp10++ es una herramienta gratuita y portable para ajustar al detalle la telemetria y la privacidad de Windows con su propia interfaz. Se abre su pagina oficial para descargarla.']='O&O ShutUp10++ is a free, portable tool to fine-tune Windows telemetry and privacy with its own interface. Its official page opens so you can download it.'
$script:TrMap['Estado: escaneando caracteristicas...']='Status: scanning features...'
$script:TrMap['< Atras']='< Back'
$script:TrMap['1x seguro']='1x safe'
$script:TrMap['3x turbo']='3x turbo'
$script:TrMap['Abrir actualizaciones opcionales de Windows (incluye drivers)']='Open optional Windows updates (includes drivers)'
$script:TrMap['Abrir carpeta de logs']='Open logs folder'
$script:TrMap['Abrir log forense']='Open forensic log'
$script:TrMap['Abrir web oficial']='Open official website'
$script:TrMap['Actualizar TODO']='Update ALL'
$script:TrMap['Ambito:']='Scope:'
$script:TrMap['Aplicar']='Apply'
$script:TrMap['Aplicar este plan']='Apply this plan'
$script:TrMap['Aplicar perfil completo']='Apply full profile'
$script:TrMap['Aplicar recomendado para MI equipo']='Apply recommended for MY PC'
$script:TrMap['APLICAR SELECCIONADOS']='APPLY SELECTED'
$script:TrMap['Detectando que ajustes ya tienes aplicados...']='Detecting which settings you already have applied...'
$script:TrMap['Detectando que apps siguen instaladas en tu PC...']='Detecting which apps are still installed on your PC...'
$script:TrMap['instaladas (se pueden quitar)']='installed (can be removed)'
$script:TrMap['ya quitadas']='already removed'
$script:TrMap['ambar = sigue instalada, verde = ya no esta']='amber = still installed, green = already gone'
$script:TrMap['aplicados']='applied'
$script:TrMap['sin aplicar']='not applied'
$script:TrMap['verde = ya aplicado en tu PC']='green = already applied on your PC'
$script:TrMap['Buscar']='Search'
$script:TrMap['Buscar en winget']='Search in winget'
$script:TrMap['Buscar soporte/drivers de mi placa base']='Find support/drivers for my motherboard'
$script:TrMap['Buscar updates']='Check updates'
$script:TrMap['Buscar:']='Search:'
$script:TrMap['Cancelar proceso']='Cancel process'
$script:TrMap['Cargando informacion del sistema...']='Loading system information...'
$script:TrMap['Cargar']='Load'
$script:TrMap['Cargar catalogo remoto (URL https)']='Load remote catalog (https URL)'
$script:TrMap['Cargar perfil']='Load profile'
$script:TrMap['Carpeta de logs']='Logs folder'
$script:TrMap['Comparar con la foto']='Compare with snapshot'
$script:TrMap['Comprobar']='Check'
$script:TrMap['Confirmar y CREAR la ISO (administrador)']='Confirm and CREATE the ISO (administrator)'
$script:TrMap['Copiar informe']='Copy report'
$script:TrMap['Copiar pasos']='Copy steps'
$script:TrMap['Crear catalogo.json editable']='Create editable catalogo.json'
$script:TrMap['Crear un punto de restauracion antes de aplicar (recomendado)']='Create a restore point before applying (recommended)'
$script:TrMap['Desarrollador']='Developer'
$script:TrMap['Descargar .exe/.msi']='Download .exe/.msi'
$script:TrMap['Descargar NVIDIA App (web oficial)']='Download NVIDIA App (official site)'
$script:TrMap['Descargar AMD Software: Adrenalin (web oficial)']='Download AMD Software: Adrenalin (official site)'
$script:TrMap['Descargar O&O ShutUp10++ (web oficial)']='Download O&O ShutUp10++ (official site)'
$script:TrMap['Deshabilitar']='Disable'
$script:TrMap['Desinstalar']='Uninstall'
$script:TrMap['Desmarcar']='Unmark'
$script:TrMap['Detectar instaladas']='Detect installed'
$script:TrMap['Detectar mi hardware']='Detect my hardware'
$script:TrMap['Ejecutar']='Run'
$script:TrMap['Ejecutar fases seleccionadas']='Run selected phases'
$script:TrMap['Ejecutar TODAS las fases']='Run ALL phases'
$script:TrMap['Elegir...']='Choose...'
$script:TrMap['En espera.']='Idle.'
$script:TrMap['Esencial']='Essential'
$script:TrMap['Este usuario']='This user'
$script:TrMap['Exportar a archivo']='Export to file'
$script:TrMap['Exportar diagnostico completo']='Export full diagnostic'
$script:TrMap['Exportar perfil maestro']='Export master profile'
$script:TrMap['Exportar plan']='Export plan'
$script:TrMap['Exportar TODO mi equipo a un archivo...']='Export my WHOLE PC to a file...'
$script:TrMap['Generar kit (preparar archivos)']='Generate kit (prepare files)'
$script:TrMap['Generar kit (opcional: solo revisar archivos)']='Generate kit (optional: just review files)'
$script:TrMap['Si NO tienes una ISO de Windows, descarga la oficial de Microsoft y luego eligela abajo en "ISO origen".']='If you do NOT have a Windows ISO, download the official one from Microsoft and then pick it below in "Source ISO".'
$script:TrMap['Descargar Windows 11 (Microsoft)']='Download Windows 11 (Microsoft)'
$script:TrMap['Descargar Windows 10 (Microsoft)']='Download Windows 10 (Microsoft)'
$script:TrMap['Abrir Rufus (rufus.ie) para grabar la ISO al USB']='Open Rufus (rufus.ie) to write the ISO to USB'
$script:TrMap['GUIA RAPIDA: Si vas a PROBAR en maquina virtual (VirtualBox/VMware): activa EFI/UEFI, asigna 4+ GB de RAM, 2+ nucleos y disco de 64+ GB, y habilita TPM o usa el bypass de WPI. Si es una instalacion NORMAL en un PC fisico: cuando la ISO este creada, graba la ISO a un USB con Rufus (esquema GPT, destino UEFI), arranca desde el USB y listo. IMPORTANTE: el "Modo VM" formatea el disco 0 automaticamente; usalo SOLO en maquinas virtuales. En un PC fisico dejalo DESACTIVADO y elige el disco a mano.']='QUICK GUIDE: If you will TEST in a virtual machine (VirtualBox/VMware): enable EFI/UEFI, assign 4+ GB RAM, 2+ cores and a 64+ GB disk, and enable TPM or use the WPI bypass. For a NORMAL install on a physical PC: once the ISO is built, write it to a USB with Rufus (GPT scheme, UEFI target), boot from the USB and you are done. IMPORTANT: "VM mode" wipes disk 0 automatically; use it ONLY in virtual machines. On a physical PC leave it OFF and pick the disk manually.'
$script:TrMap['Elige el tema visual (se aplica al reiniciar)']='Choose the visual theme (applies after restart)'
$script:TrMap['Idioma de la interfaz / UI language (restart to apply)']='UI language / Idioma de la interfaz (restart to apply)'
$script:TrMap['Instalaciones simultaneas. 1x = seguro; 2x-3x acelera, los choques MSI se reintentan solos.']='Simultaneous installations. 1x = safe; 2x-3x is faster, MSI clashes retry by themselves.'
$script:TrMap['Para quien se instala. Auto = como decida winget; usuario o todo el equipo (--scope).']='Who it installs for. Auto = whatever winget decides; current user or the whole machine (--scope).'
$script:TrMap["Auto = sin --scope (recomendado). 'Este usuario' o 'Todo el equipo' fuerzan --scope user/machine."]="Auto = no --scope (recommended). 'This user' or 'Whole machine' force --scope user/machine."
$script:TrMap['Si winget falla al instalar una app, intentar con Chocolatey (si esta instalado). Best-effort: el ID puede no existir en choco. Queda en el log.']='If winget fails to install an app, try Chocolatey (if installed). Best-effort: the ID may not exist on choco. It is recorded in the log.'
$script:TrMap['Todas las ediciones (mas lento; todas quedan personalizadas)']='All editions (slower; every edition gets customized)'
$script:TrMap['(solo esta edicion; mas rapido)']='(this edition only; faster)'
$script:TrMap['En que edicion aplicar la configuracion']='Which edition to apply the configuration to'
$script:TrMap['Detectar ediciones']='Detect editions'
$script:TrMap['Primero elige arriba la ISO origen de Windows.']='First choose the source Windows ISO above.'
$script:TrMap['Detectando ediciones de la ISO (puede tardar unos segundos)...']='Detecting ISO editions (this may take a few seconds)...'
$script:TrMap['No se pudieron detectar ediciones. Se usara "Todas las ediciones".']='Could not detect editions. "All editions" will be used.'
$script:TrMap['Detectadas {0} ediciones en la ISO.']='Detected {0} editions in the ISO.'
$script:TrMap['Pulsa "Detectar ediciones" para listar los Windows de tu ISO. Si eliges una concreta, la ISO final tendra SOLO esa edicion (mas rapido). "Todas" personaliza cada edicion (mas lento).']='Press "Detect editions" to list the Windows versions in your ISO. If you pick a specific one, the final ISO will contain ONLY that edition (faster). "All" customizes every edition (slower).'
$script:TrMap['AVISO IMPORTANTE (Rufus): cuando grabes la ISO al USB y aparezca la ventana "Experiencia de usuario de Windows", NO marques NINGUNA casilla (ni quitar TPM, ni cuenta local, ni mejoras QoL). Dejalas todas vacias y pulsa Aceptar. Si marcas algo, Rufus crea su propio autounattend y SOBREESCRIBE el de WPI: no se aplicarian tus apps, ni los tweaks, ni el modo oscuro. Todo eso ya lo hace WPI por si solo.']='IMPORTANT NOTICE (Rufus): when you write the ISO to USB and the "Windows User Experience" window appears, do NOT tick ANY checkbox (no removing TPM, no local account, no QoL tweaks). Leave them all empty and press OK. If you tick anything, Rufus creates its own autounattend and OVERWRITES the WPI one: your apps, tweaks and dark mode would not be applied. WPI already does all of that on its own.'
$script:TrMap['  IMPORTANTE  -  COMPROBAR la ISO antes de Rufus  ']='  IMPORTANT  -  CHECK the ISO before Rufus  '
$script:TrMap['Los ajustes estaban danados y se han restaurado a los valores por defecto (copia en wpi_settings.json.corrupt.bak).']='Settings were corrupted and have been restored to their default values (backup in wpi_settings.json.corrupt.bak).'
$script:TrMap['Guardar']='Save'
$script:TrMap['Guardar perfil']='Save profile'
$script:TrMap['Guia maquina virtual']='Virtual machine guide'
$script:TrMap['Habilitar']='Enable'
$script:TrMap['Hacer copia de drivers']='Back up drivers'
$script:TrMap['Hilos:']='Threads:'
$script:TrMap['Importar un archivo e instalar todo...']='Import a file and install everything...'
$script:TrMap['Instalar Intel Driver & Support Assistant (winget)']='Install Intel Driver & Support Assistant (winget)'
$script:TrMap['INSTALAR SELECCIONADAS (0)']='INSTALL SELECTED (0)'
$script:TrMap['Instalar Windows ADK']='Install Windows ADK'
$script:TrMap['Limpiar seleccion']='Clear selection'
$script:TrMap['Los enlaces los gestiona el repositorio oficial de winget: nunca caducan.']='Links are managed by the official winget repository: they never expire.'
$script:TrMap['Marcar estas apps en el catalogo']='Mark these apps in the catalog'
$script:TrMap['Marcar lo recomendado que falta']='Mark missing recommended'
$script:TrMap['Marcar recomendados']='Mark recommended'
$script:TrMap['Marcar solo las instaladas']='Mark only installed'
$script:TrMap['Marcar todas']='Mark all'
$script:TrMap['Marcar todo']='Mark all'
$script:TrMap['Marcar todos']='Mark all'
$script:TrMap['Marcar visibles']='Mark visible'
$script:TrMap['Ninguna']='None'
$script:TrMap['Ninguno']='None'
$script:TrMap['Presets:']='Presets:'
$script:TrMap['Quitar OneDrive (reversible)']='Remove OneDrive (reversible)'
$script:TrMap['QUITAR SELECCIONADAS (0)']='REMOVE SELECTED (0)'
$script:TrMap['Quitar todas']='Unmark all'
$script:TrMap['Quitar todos']='Unmark all'
$script:TrMap['Recargar catalogo.json (reinicia la app)']='Reload catalogo.json (restarts the app)'
$script:TrMap['Re-detectar estado']='Re-detect status'
$script:TrMap['Refrescar']='Refresh'
$script:TrMap['REGISTRO EN VIVO']='LIVE LOG'
$script:TrMap['Restaurar drivers desde carpeta']='Restore drivers from folder'
$script:TrMap['REVERTIR SELECCIONADOS']='REVERT SELECTED'
$script:TrMap['Siguiente >']='Next >'
$script:TrMap['Todo el equipo']='Whole machine'
$script:TrMap['Tomar foto del sistema']='Take system snapshot'
$script:TrMap['Ultima sesion']='Last session'
$script:TrMap['Usar mi seleccion de Apps']='Use my Apps selection'
$script:TrMap['Validar IDs']='Validate IDs'
$script:TrMap['Ver ->']='View ->'
$script:TrMap['Ver guia completa']='View full guide'
$script:TrMap['Ver plan del perfil']='View profile plan'
$script:TrMap['ACTUALIZACIONES DISPONIBLES']='AVAILABLE UPDATES'
$script:TrMap['APARIENCIA']='APPEARANCE'
$script:TrMap['CATALOGO']='CATALOG'
$script:TrMap['CLONAR EQUIPO / SNAPSHOT']='CLONE PC / SNAPSHOT'
$script:TrMap['COMPARATIVA ANTES / DESPUES']='BEFORE / AFTER COMPARISON'
$script:TrMap['CONTROL DE WINDOWS UPDATE']='WINDOWS UPDATE CONTROL'
$script:TrMap['COPIA DE SEGURIDAD DE DRIVERS']='DRIVER BACKUP'
$script:TrMap['CARACTERISTICAS DE WINDOWS  ·  ACCIONES FUERTES (DISM)']='WINDOWS FEATURES  ·  STRONG ACTIONS (DISM)'
$script:TrMap['DRIVERS Y HARDWARE']='DRIVERS AND HARDWARE'
$script:TrMap['GUIAS DE INSTALACION (en espanol)']='INSTALLATION GUIDES'
$script:TrMap['HERRAMIENTAS RAPIDAS  ·  ACCIONES SUELTAS']='QUICK TOOLS  ·  INDIVIDUAL ACTIONS'
$script:TrMap['OTRAS FUENTES DE DRIVERS']='OTHER DRIVER SOURCES'
$script:TrMap['PANELES CLASICOS DE WINDOWS']='CLASSIC WINDOWS PANELS'
$script:TrMap['PERFIL MAESTRO (apps + tweaks + debloat + update)']='MASTER PROFILE (apps + tweaks + debloat + update)'
$script:TrMap['PLAN (solo lectura) - no se aplica nada hasta que confirmes']='PLAN (read-only) - nothing is applied until you confirm'
$script:TrMap['PRIVACIDAD AVANZADA']='ADVANCED PRIVACY'
$script:TrMap['QUITAR APPS PREINSTALADAS (DEBLOAT)  ·  ACCION FUERTE']='REMOVE PREINSTALLED APPS (DEBLOAT)  ·  STRONG ACTION'
$script:TrMap['RECOMENDADO PARA TU EQUIPO']='RECOMMENDED FOR YOUR PC'
$script:TrMap['REPARACION  ·  ACCIONES FUERTES']='REPAIR  ·  STRONG ACTIONS'
$script:TrMap['RESUMEN DEL SISTEMA']='SYSTEM SUMMARY'
$script:TrMap['BUSCAR E INSTALAR DESDE WINGET']='SEARCH AND INSTALL FROM WINGET'
$script:TrMap['BUSCAR EN TODO']='SEARCH EVERYTHING'
$script:TrMap['BIENVENIDO - MODO FACIL (en 2 clics)']='WELCOME - EASY MODE (in 2 clicks)'
$script:TrMap['VISOR DE LOGS']='LOG VIEWER'
$script:TrMap['TWEAKS Y AJUSTES (se aplican solo los marcados; casi todos reversibles)']='TWEAKS AND SETTINGS (only marked ones apply; almost all reversible)'
$script:TrMap['Instala tus programas']='Install your programs'
$script:TrMap['Optimiza Windows (Tweaks)']='Optimize Windows (Tweaks)'
$script:TrMap['Quita el bloatware']='Remove bloatware'
$script:TrMap['Repara Windows']='Repair Windows'
$script:TrMap['Crea tu ISO a medida']='Create your custom ISO'
$script:TrMap['Mira el estado de tu equipo']='Check your PC status'
$script:TrMap['Ir a Programas ->']='Go to Programs ->'
$script:TrMap['Ir a Tweaks ->']='Go to Tweaks ->'
$script:TrMap['Ir a Limpiar ->']='Go to Clean ->'
$script:TrMap['Ir a Reparacion ->']='Go to Repair ->'
$script:TrMap['Ir a Crear ISO ->']='Go to Create ISO ->'
$script:TrMap['Ir a Resumen ->']='Go to Summary ->'
$script:TrMap['Resumen del sistema, foto antes/despues y diagnostico exportable.']='System summary, before/after snapshot and exportable diagnostic.'
$script:TrMap['Suite de reparacion (SFC, DISM, red, Windows Update...) y herramientas, todo en uno.']='Repair suite (SFC, DISM, network, Windows Update...) and tools, all in one.'
$script:TrMap['Asistente paso a paso para una ISO con tus apps, tweaks, debloat y drivers ya integrados.']='Step-by-step wizard for an ISO with your apps, tweaks, debloat and drivers already integrated.'
$script:TrMap['Elige entre 360+ apps (navegadores, multimedia, desarrollo, juegos...) y pulsa INSTALAR. Marca varias a la vez.']='Choose from 360+ apps (browsers, multimedia, development, games...) and press INSTALL. Mark several at once.'
$script:TrMap['Ajustes de privacidad y rendimiento, reversibles. Dentro tienes "Aplicar recomendado para MI equipo" que marca lo seguro segun tu PC.']='Privacy and performance settings, reversible. Inside you have "Apply recommended for MY PC" which marks what is safe for your machine.'
$script:TrMap['Elimina apps preinstaladas que no usas (Xbox, noticias, etc.). Son reinstalables desde la Store.']='Removes preinstalled apps you do not use (Xbox, news, etc.). They are reinstallable from the Store.'
$script:TrMap['Encuentra cualquier app, tweak, bloatware o caracteristica de Windows y salta a su seccion con un clic.']='Find any app, tweak, bloatware or Windows feature and jump to its section with one click.'
$script:TrMap['BUSCAR EN TODO']='SEARCH EVERYTHING'
$script:TrMap['Escribe al menos 2 letras y pulsa Buscar (o Enter).']='Type at least 2 letters and press Search (or Enter).'
$script:TrMap['Sin resultados. Prueba con otro termino o revisa la ortografia.']='No results. Try another term or check the spelling.'
$script:TrMap['No hay logs todavia. Se crean automaticamente al usar el WPI (instalar, tweaks, reparar, etc.).']='No logs yet. They are created automatically when you use WPI (install, tweaks, repair, etc.).'
$script:TrMap['Consulta los registros forenses del WPI (carpeta logs). Elige un archivo del desplegable para ver su contenido (ultimas lineas).']='View the WPI forensic logs (logs folder). Pick a file from the dropdown to see its contents (last lines).'
$script:TrMap['Sigue los pasos en orden. Cada boton te lleva a su seccion; alli eliges y confirmas. La barra de la izquierda es el "modo experto" con todo el control: usa lo que necesites.']='Follow the steps in order. Each button takes you to its section; there you choose and confirm. The left bar is "expert mode" with full control: use what you need.'
$script:TrMap['Te guio seccion a seccion: elige y pulsa "Siguiente". Puedes volver "Atras" para cambiar algo. No se toca nada hasta el ultimo paso, donde confirmas y se crea la ISO.']='I guide you section by section: choose and press "Next". You can go "Back" to change something. Nothing is touched until the last step, where you confirm and the ISO is created.'
$script:TrMap['Necesitas Windows ADK (aporta oscdimg), DISM y espacio libre. Para crear la ISO de verdad, abre el WPI como administrador. Aqui tambien tienes las guias.']='You need Windows ADK (provides oscdimg), DISM and free space. To actually create the ISO, open WPI as administrator. The guides are here too.'
$script:TrMap['Elige los tweaks. Se aplican en el PRIMER ARRANQUE con el motor real de WPI (fieles a los de la pestana Tweaks). Empiezan marcados los seguros recomendados.']='Choose the tweaks. They are applied on FIRST BOOT with the real WPI engine (matching the Tweaks tab). Safe recommended tweaks start checked.'
$script:TrMap['Marca el bloatware a quitar DE FABRICA (offline, antes de instalar). Son Appx reinstalables desde la Store. Empieza todo marcado.']='Mark the factory bloatware to remove offline before installation. These Appx packages can be reinstalled from the Store. Everything starts checked.'
$script:TrMap['Marca las apps que se instalaran solas en el primer arranque (via winget), DIVIDIDAS POR SECCION (Navegadores, Multimedia, etc.). Usa el buscador para filtrar. Por defecto se traen las que tengas marcadas en la pestana Apps.']='Mark the apps that will install automatically on first boot via winget, split by section (Browsers, Multimedia, etc.). Use search to filter. By default it imports what you checked in the Apps tab.'
$script:TrMap['Inyecta drivers (.inf) en la imagen para que el equipo arranque con red/chipset. Elige una carpeta con .inf, o si NO tienes ninguna, crea ahora mismo una copia de los drivers que tienes instalados con el boton de abajo.']='Inject drivers (.inf) into the image so the PC boots with network/chipset support. Choose a folder with .inf files, or create a backup of your installed drivers with the button below.'
$script:TrMap['Automatiza la instalacion. "Bypass W11" instala en equipos sin TPM/Secure Boot. "Modo VM" PARTICIONA Y BORRA el disco 0: usalo SOLO en maquina virtual o disco desechable.']='Automates installation. "Bypass W11" installs on PCs without TPM/Secure Boot. "VM mode" PARTITIONS AND WIPES disk 0: use it ONLY on a virtual machine or disposable disk.'
$script:TrMap['Comprobar']='Check'
$script:TrMap['Marcar recomendados']='Mark recommended'
$script:TrMap['Quitar todos']='Unmark all'
$script:TrMap['Marcar todos']='Mark all'
$script:TrMap['Quitar todas']='Unmark all'
$script:TrMap['Inyectar drivers desde una carpeta']='Inject drivers from a folder'
$script:TrMap['Carpeta de drivers (.inf)']='Drivers folder (.inf)'
$script:TrMap['Crear cuenta local y saltar pantallas de cuenta online (OOBE)']='Create local account and skip online account screens (OOBE)'
$script:TrMap['Bypass de requisitos de Windows 11 (TPM / Secure Boot / RAM / CPU)']='Bypass Windows 11 requirements (TPM / Secure Boot / RAM / CPU)'
$script:TrMap['Modo VM: particionar el disco automaticamente (BORRA EL DISCO 0)']='VM mode: automatically partition the disk (WIPES DISK 0)'
$script:TrMap['Idioma / locale']='Language / locale'
$script:TrMap['Nombre de cuenta']='Account name'
$script:TrMap['Contrasena de la cuenta (opcional, recomendada en Win11)']='Account password (optional, recommended on Win11)'
$script:TrMap['Confirmar y CREAR la ISO (administrador)']='Confirm and CREATE the ISO (administrator)'
$script:TrMap['Marca el bloatware a quitar DE FABRICA (offline, antes de instalar). Son Appx reinstalables desde la Store. Empieza todo marcado.']='Mark the bloatware to remove FROM FACTORY (offline, before installing). They are Appx reinstallable from the Store. Everything starts marked.'
$script:TrMap['Marca las apps que se instalaran solas en el primer arranque (via winget). Usa el buscador para filtrar. Por defecto se traen las que tengas marcadas en la pestana Apps.']='Mark the apps that will install themselves on first boot (via winget). Use the search box to filter. By default it brings those marked in the Apps tab.'
$script:TrMap['Elige los tweaks. Se aplican en el PRIMER ARRANQUE con el motor real de WPI (fieles a los de la pestana Tweaks). Empiezan marcados los seguros recomendados.']='Choose the tweaks. They apply on FIRST BOOT with the real WPI engine (faithful to the Tweaks tab). The recommended safe ones start marked.'
$script:TrMap['Automatiza la instalacion. "Bypass W11" instala en equipos sin TPM/Secure Boot. "Modo VM" PARTICIONA Y BORRA el disco 0: usalo SOLO en maquina virtual o disco desechable.']='Automates installation. "Bypass W11" installs on PCs without TPM/Secure Boot. "VM mode" PARTITIONS AND WIPES disk 0: use it ONLY on a virtual machine or a disposable disk.'
$script:TrMap['Inyecta drivers (.inf) en la imagen para que el equipo arranque con red/chipset. Puedes usar la copia de "Drivers y hardware" (Export-WindowsDriver).']='Injects drivers (.inf) into the image so the PC boots with network/chipset. You can use the backup from "Drivers and hardware" (Export-WindowsDriver).'
$script:TrMap['Iniciando...']='Starting...'
$script:TrMap['Detectando hardware...']='Detecting hardware...'
$script:TrMap['Hardware detectado.']='Hardware detected.'
$script:TrMap['Re-escaneando caracteristicas...']='Re-scanning features...'
$script:TrMap['Kit de ISO generado.']='ISO kit generated.'
$script:TrMap['Creacion de ISO lanzada en consola elevada.']='ISO creation launched in an elevated console.'
$script:TrMap['Primero pulsa "Detectar mi hardware".']='First press "Detect my hardware".'
$script:TrMap['Cargando informacion del sistema...']='Loading system information...'
$script:TrMap['Seleccionadas:']='Selected:'
$script:TrMap['INSTALAR']='INSTALL'
$script:TrMap['Seleccionadas: 0']='Selected: 0'
$script:TrMap['INSTALAR (0)']='INSTALL (0)'
# --- P3a: titulos de avisos (MessageBox) ---
$script:TrMap['Apariencia']='Appearance'
$script:TrMap['Caracteristicas de Windows']='Windows Features'
$script:TrMap['Carpeta de descarga']='Download folder'
$script:TrMap['Catalogo remoto']='Remote catalog'
$script:TrMap['Comparativa']='Comparison'
$script:TrMap['Comparativa antes / despues']='Before / after comparison'
$script:TrMap['Crear ISO']='Create ISO'
$script:TrMap['Desinstalacion masiva']='Mass uninstall'
$script:TrMap['Fallback a Chocolatey']='Chocolatey fallback'
$script:TrMap['Falta algo imprescindible']='Something required is missing'
$script:TrMap['Falta Windows ADK']='Windows ADK missing'
$script:TrMap['Importar equipo']='Import machine'
$script:TrMap['Instalar desde winget']='Install from winget'
$script:TrMap['Poco espacio']='Low disk space'
$script:TrMap['Quitar bloatware']='Remove bloatware'
$script:TrMap['Quitar OneDrive']='Remove OneDrive'
$script:TrMap['Recomendado para mi equipo']='Recommended for my PC'
$script:TrMap['Restaurar drivers']='Restore drivers'
$script:TrMap['Resumen y confirmacion']='Summary and confirmation'
$script:TrMap['Revertir tweaks']='Revert tweaks'
$script:TrMap['Sin drivers .inf']='No .inf drivers'
$script:TrMap['Suite de Reparacion']='Repair Suite'
$script:TrMap['Tweaks avanzados']='Advanced tweaks'
$script:TrMap['Validar IDs']='Validate IDs'
$script:TrMap['Actualizar TODO el equipo']='Update the WHOLE machine'
# --- P3a: cuerpos de avisos estaticos ---
$script:TrMap['Aun no hay ninguna sesion guardada. Se guarda automaticamente cada vez que pulsas INSTALAR.']='There is no saved session yet. It is saved automatically every time you press INSTALL.'
$script:TrMap['El archivo no es un perfil maestro valido (falta "$schema": "wpi-master-profile-1.0").']='The file is not a valid master profile (missing "$schema": "wpi-master-profile-1.0").'
$script:TrMap['El archivo no es un perfil maestro valido (falta "$schema": "wpi-master-profile-1.0"). No se aplica nada.']='The file is not a valid master profile (missing "$schema": "wpi-master-profile-1.0"). Nothing is applied.'
$script:TrMap['El archivo wpi_baseline.json no es una foto valida.']='The wpi_baseline.json file is not a valid snapshot.'
$script:TrMap['El contenido descargado no es JSON valido.']='The downloaded content is not valid JSON.'
$script:TrMap['El JSON no tiene entradas validas con Cat/Name/Id.']='The JSON has no valid entries with Cat/Name/Id.'
$script:TrMap['Escribe al menos 2 caracteres para buscar.']='Type at least 2 characters to search.'
$script:TrMap['Falta la carpeta de salida (paso "Origen y salida").']='The output folder is missing (step "Source and output").'
$script:TrMap['Falta la ISO de Windows origen (paso "Origen y salida"). Vuelve atras y eligela.']='The source Windows ISO is missing (step "Source and output"). Go back and choose it.'
$script:TrMap['Hay un proceso en marcha. Si cierras ahora, las instalaciones en curso seguiran en segundo plano sin supervision. Cerrar igualmente?']='A process is running. If you close now, the installations in progress will keep running in the background unsupervised. Close anyway?'
$script:TrMap['Marca primero las apps cuyo instalador quieres descargar (sin instalarlas).']='First mark the apps whose installer you want to download (without installing them).'
$script:TrMap['No has marcado ningun ajuste reversible.']='You have not selected any reversible tweak.'
$script:TrMap['No has marcado ningun resultado.']='You have not selected any result.'
$script:TrMap['No has marcado ningun tweak.']='You have not selected any tweak.'
$script:TrMap['No has marcado ninguna actualizacion en este grupo.']='You have not selected any update in this group.'
$script:TrMap['No has marcado ninguna aplicacion que desinstalar.']='You have not selected any application to uninstall.'
$script:TrMap['No has marcado ninguna aplicacion que guardar.']='You have not selected any application to save.'
$script:TrMap['No has marcado ninguna aplicacion.']='You have not selected any application.'
$script:TrMap['No has marcado ninguna app para quitar.']='You have not selected any app to remove.'
$script:TrMap['No has marcado ninguna fase (ademas de la 00, que va siempre). Marca al menos una.']='You have not selected any phase (besides 00, which always runs). Select at least one.'
$script:TrMap['No se encuentra "Suite_Reparacion_TodoEnUno.bat" junto al WPI. Copialo a esta carpeta.']='Cannot find "Suite_Reparacion_TodoEnUno.bat" next to WPI. Copy it to this folder.'
$script:TrMap['No se ha detectado Windows ADK (oscdimg), necesario para CREAR la ISO al final. Puedes instalarlo con el boton "Instalar Windows ADK" ahora, o seguir configurando e instalarlo antes de crearla. Continuar de todas formas?']='Windows ADK (oscdimg) was not detected; it is required to CREATE the ISO at the end. You can install it with the "Install Windows ADK" button now, or keep configuring and install it before creating it. Continue anyway?'
$script:TrMap['No se pudo crear el archivo.']='The file could not be created.'
$script:TrMap['No se pudo crear la carpeta de salida.']='The output folder could not be created.'
$script:TrMap['No se pudo leer el perfil (formato no valido).']='The profile could not be read (invalid format).'
$script:TrMap['No se pudo leer el perfil (JSON no valido).']='The profile could not be read (invalid JSON).'
$script:TrMap['No se pudo leer el perfil (JSON no valido). No se aplica nada.']='The profile could not be read (invalid JSON). Nothing is applied.'
$script:TrMap['No se pudo leer wpi_baseline.json (formato no valido).']='wpi_baseline.json could not be read (invalid format).'
$script:TrMap['Para cargar el catalogo nuevo hay que reiniciar la app. Reiniciar ahora?']='To load the new catalog the app must restart. Restart now?'
$script:TrMap['Para cargar las guias nuevas hay que reiniciar la app. Reiniciar ahora?']='To load the new guides the app must restart. Restart now?'
$script:TrMap['Por seguridad solo se permiten URLs https://.']='For security only https:// URLs are allowed.'
$script:TrMap['Todavia no hay ninguna foto. Pulsa primero "Tomar foto del sistema".']='There is no snapshot yet. First press "Take system snapshot".'
$script:TrMap['Vas a integrar todo lo elegido y CREAR la ISO. Se lanzara como ADMINISTRADOR en una consola aparte; monta la imagen y puede tardar 15-40 min. No cierres la consola. Confirmas?']='You are about to integrate everything chosen and CREATE the ISO. It will run as ADMINISTRATOR in a separate console; it mounts the image and may take 15-40 min. Do not close the console. Confirm?'
$script:TrMap['Ya existe una foto previa. Sobrescribirla con el estado actual?']='A previous snapshot already exists. Overwrite it with the current state?'
# --- P3a: plantillas de avisos dinamicos (-f) y estaticos por concatenacion ---
$script:TrMap['Tema seleccionado: {0}. Se aplica al reiniciar la app. Reiniciar ahora?']='Theme selected: {0}. It applies after restarting the app. Restart now?'
$script:TrMap['Tema cambiado a {0}. Se aplica al reiniciar la app. Reiniciar ahora?']='Theme changed to {0}. It applies after restarting the app. Restart now?'
$script:TrMap['Diagnostico guardado en: {0}']='Diagnostics saved to: {0}'
$script:TrMap['No se pudo relanzar como administrador: {0}']='Could not relaunch as administrator: {0}'
$script:TrMap['No se pudo lanzar la suite como administrador: {0}']='Could not launch the suite as administrator: {0}'
$script:TrMap['No se pudo generar el kit: {0}']='Could not generate the kit: {0}'
$script:TrMap['No se pudo lanzar la exportacion: {0}']='Could not launch the export: {0}'
$script:TrMap['No se pudo lanzar la creacion: {0}']='Could not launch the creation: {0}'
$script:TrMap['Ya existe {0}. Sobrescribir con el catalogo interno actual?']='{0} already exists. Overwrite it with the current internal catalog?'
$script:TrMap['No hay {0}. Crea primero la plantilla.']='There is no {0}. Create the template first.'
$script:TrMap['Ya existe {0}. Sobrescribir con las guias actuales?']='{0} already exists. Overwrite it with the current guides?'
$script:TrMap['No se pudo descargar el catalogo: {0}']='Could not download the catalog: {0}'
$script:TrMap['No se pudo guardar el catalogo remoto: {0}']='Could not save the remote catalog: {0}'
$script:TrMap['Catalogo remoto valido: {0} apps. Se guardara como catalogo.json (sustituye al interno) y se reiniciara la app para aplicarlo. Revisa luego los IDs con "Validar IDs". Continuar?']='Valid remote catalog: {0} apps. It will be saved as catalog.json (replacing the internal one) and the app will restart to apply it. Then check the IDs with "Validate IDs". Continue?'
$script:TrMap["{0}`n`nMarcados {1} tweaks recomendados. NO se ha aplicado nada: revisa la seleccion y pulsa APLICAR SELECCIONADOS.{2}"]="{0}`n`nMarked {1} recommended tweaks. NOTHING has been applied: review the selection and press APPLY SELECTED.{2}"
$script:TrMap["Perfil de tweaks guardado:`n{0}`n`nGuarda los ajustes ya aplicados en este PC. Cargalo en otro momento o en otro equipo para igualarlo."]="Tweaks profile saved:`n{0}`n`nIt saves the tweaks already applied on this PC. Load it later or on another PC to match it."
$script:TrMap["Perfil cargado.`n`nMarcados para aplicar: {0}`nDe esos, ya aplicados en este PC: {1}`n`nRevisa la seleccion y pulsa APLICAR SELECCIONADOS para igualar este equipo al perfil."]="Profile loaded.`n`nMarked to apply: {0}`nOf those, already applied on this PC: {1}`n`nReview the selection and press APPLY SELECTED to match this PC to the profile."
$script:TrMap["Perfil de debloat guardado:`n{0}`n`nRegistra que apps preinstaladas ya quitaste. Cargalo en otro equipo para dejarlo igual de limpio."]="Debloat profile saved:`n{0}`n`nIt records which preinstalled apps you already removed. Load it on another PC to leave it just as clean."
$script:TrMap["Perfil de debloat cargado.`n`nApps quitadas en el perfil: {0}`nDe esas, aun instaladas en este PC (marcadas): {1}`n`nRevisa la seleccion y pulsa QUITAR SELECCIONADAS para igualar este equipo."]="Debloat profile loaded.`n`nApps removed in the profile: {0}`nOf those, still installed on this PC (marked): {1}`n`nReview the selection and press REMOVE SELECTED to match this PC."
$script:TrMap["Perfil maestro guardado:`n{0}`n`nApps marcadas: {1}  ·  Tweaks aplicados: {2}  ·  Debloat quitado: {3}`n`nAplicalo en otro equipo con 'Aplicar perfil completo' o con -Profile en la linea de comandos."]="Master profile saved:`n{0}`n`nMarked apps: {1}  ·  Applied tweaks: {2}  ·  Removed debloat: {3}`n`nApply it on another PC with 'Apply full profile' or with -Profile on the command line."
$script:TrMap["Foto del sistema guardada en:`n{0}`n`nServicios: {1}  ·  Procesos: {2}  ·  Inicio: {3}  ·  RAM: {4} MB`n`nAplica tus cambios y luego pulsa 'Comparar con la foto'."]="System snapshot saved to:`n{0}`n`nServices: {1}  ·  Processes: {2}  ·  Startup: {3}  ·  RAM: {4} MB`n`nApply your changes and then press 'Compare with snapshot'."
$script:TrMap["Comparativa (foto del {0}):`n`n{1}"]="Comparison (snapshot from {0}):`n`n{1}"
$script:TrMap["Se lanzara la Suite de Reparacion como ADMINISTRADOR en una consola aparte:`n`n - {0}`n`nNO reiniciara sola (/noreboot): reinicia tu al terminar si se indica. Veras el progreso en la consola. Continuar?"]="The Repair Suite will run as ADMINISTRATOR in a separate console:`n`n - {0}`n`nIt will NOT reboot by itself (/noreboot): reboot yourself when done if indicated. You will see the progress in the console. Continue?"
$script:TrMap["Kit generado en:`n{0}`n`nContiene config, autounattend.xml, el script de creacion, el preset de apps, una copia de WPI y las guias. Abrir la carpeta?"]="Kit generated in:`n{0}`n`nIt contains config, autounattend.xml, the creation script, the apps preset, a copy of WPI and the guides. Open the folder?"
$script:TrMap["Exportadas {0} apps en formato winget.`nUso en cualquier PC:`nwinget import -i `"{1}`""]="Exported {0} apps in winget format.`nUse on any PC:`nwinget import -i `"{1}`""
$script:TrMap["Preset guardado: {0} apps.`nUso desatendido:`nIniciar_WPI.bat -Preset `"{1}`""]="Preset saved: {0} apps.`nUnattended use:`nIniciar_WPI.bat -Preset `"{1}`""
$script:TrMap["Los instaladores se guardaran en:`n{0}`n(cada app en su subcarpeta)`n`nSi   = usar esa carpeta`nNo   = elegir otra carpeta`nCancelar = no descargar"]="The installers will be saved in:`n{0}`n(each app in its subfolder)`n`nYes   = use that folder`nNo   = choose another folder`nCancel = do not download"
$script:TrMap["No se pudo crear la carpeta:`n{0}"]="Could not create the folder:`n{0}"
$script:TrMap["Vas a DESINSTALAR {0} aplicaciones de este equipo:`n`n - {1}`n`nEsta accion no se puede deshacer desde aqui. Continuar?"]="You are about to UNINSTALL {0} applications from this PC:`n`n - {1}`n`nThis action cannot be undone from here. Continue?"
$script:TrMap["{0}`n`n - {1}`n`nEl resto se queda EXACTAMENTE como esta. Continuar?"]="{0}`n`n - {1}`n`nThe rest stays EXACTLY as it is. Continue?"
$script:TrMap["Se instalaran estos {0} programas desde winget:`n`n - {1}`n`nContinuar?"]="These {0} programs will be installed from winget:`n`n - {1}`n`nContinue?"
$script:TrMap["Se quitaran estas {0} apps preinstaladas:`n`n - {1}`n`nSon reinstalables desde la Store. Continuar?"]="These {0} preinstalled apps will be removed:`n`n - {1}`n`nThey are reinstallable from the Store. Continue?"
$script:TrMap["Se instalara TODO lo que falte segun el archivo:`n{0}`n`nPuede tardar bastante. Continuar?"]="Everything missing according to the file will be installed:`n{0}`n`nIt may take a while. Continue?"
$script:TrMap["Creado:`n{0}`n`nEditalo (anade/quita lineas) y pulsa 'Recargar catalogo.json'."]="Created:`n{0}`n`nEdit it (add/remove lines) and press 'Reload catalog.json'."
$script:TrMap["Creado:`n{0}`n`nEditalo (anade/cambia guias) y pulsa 'Recargar guias.json'."]="Created:`n{0}`n`nEdit it (add/change guides) and press 'Reload guias.json'."
$script:TrMap["No hay apps marcadas: se validara el catalogo COMPLETO ({0} IDs).`nPuede tardar varios minutos. Continuar?"]="No apps marked: the FULL catalog will be validated ({0} IDs).`nIt may take several minutes. Continue?"
$script:TrMap["Has marcado {0} tweak(s) AVANZADOS (mayor impacto en el sistema). Casi todos se pueden revertir, pero asegurate. Continuar?"]="You marked {0} ADVANCED tweak(s) (greater impact on the system). Almost all can be reverted, but make sure. Continue?"
$script:TrMap["Se revertiran {0} ajuste(s) a su valor por defecto de Windows. Continuar?"]="{0} tweak(s) will be reverted to their Windows default value. Continue?"
$script:TrMap["Se desinstalara Microsoft OneDrive (no es una Appx, usa su propio desinstalador).`n`nEs REVERSIBLE: se reinstala con 'Buscar en winget' -> Microsoft.OneDrive, o desde onedrive.com. Tus archivos en la nube no se borran. Continuar?"]="Microsoft OneDrive will be uninstalled (it is not an Appx, it uses its own uninstaller).`n`nIt is REVERSIBLE: reinstall it with 'Search in winget' -> Microsoft.OneDrive, or from onedrive.com. Your files in the cloud are not deleted. Continue?"
$script:TrMap['Esto reinyecta drivers (.inf) desde una carpeta usando pnputil. Esta pensado para un equipo RECIEN reinstalado, usando una copia hecha con "Hacer copia de drivers". Continuar?']='This reinjects drivers (.inf) from a folder using pnputil. It is meant for a freshly reinstalled PC, using a copy made with "Back up drivers". Continue?'
$script:TrMap["Esto ejecutara 'winget upgrade --all': actualiza DE GOLPE todos los programas de tu equipo que winget reconozca (los instalaras como los instalaras), no solo los del catalogo.`n`nSi prefieres elegir uno a uno, cancela y usa 'Buscar updates'.`n`nContinuar con la actualizacion completa?"]="This will run 'winget upgrade --all': it updates ALL programs on your PC that winget recognizes AT ONCE (however you installed them), not just those in the catalog.`n`nIf you prefer to choose one by one, cancel and use 'Check updates'.`n`nContinue with the full update?"
# --- P3b: textos de la barra de estado ---
$script:TrMap['{0} ajustes recomendados sin aplicar marcados. Revisa y pulsa APLICAR SELECCIONADOS.']='{0} recommended tweaks not yet applied have been marked. Review and press APPLY SELECTED.'
$script:TrMap['{0} apps recomendadas marcadas. Ve al catalogo, revisa y pulsa INSTALAR.']='{0} recommended apps marked. Go to the catalog, review and press INSTALL.'
$script:TrMap['Cancelando (se respetan las instalaciones en curso)...']='Cancelling (installations in progress are respected)...'
$script:TrMap['Caracteristicas: {0} de {1} activas.']='Features: {0} of {1} active.'
$script:TrMap['Comprobando que ajustes ya estan aplicados...']='Checking which tweaks are already applied...'
$script:TrMap['Creacion de ISO lanzada en consola elevada.']='ISO creation launched in an elevated console.'
$script:TrMap['Debloat: {0} de {1} apps instaladas.']='Debloat: {0} of {1} apps installed.'
$script:TrMap['Detectando hardware...']='Detecting hardware...'
$script:TrMap['Exportando tus drivers en una consola (admin)...']='Exporting your drivers in a console (admin)...'
$script:TrMap['Hardware detectado.']='Hardware detected.'
$script:TrMap['Informe de hardware guardado en {0}']='Hardware report saved to {0}'
$script:TrMap['Iniciando...']='Starting...'
$script:TrMap['Kit de ISO generado.']='ISO kit generated.'
$script:TrMap['No se pudo cargar el perfil de debloat.']='Could not load the debloat profile.'
$script:TrMap['No se pudo cargar el perfil.']='Could not load the profile.'
$script:TrMap['No se pudo comprobar el estado de los tweaks.']='Could not check the tweaks state.'
$script:TrMap['No se pudo detectar el estado del bloatware.']='Could not detect the bloatware state.'
$script:TrMap['No se pudo detectar parte del hardware.']='Could not detect part of the hardware.'
$script:TrMap['No se pudo exportar el perfil maestro.']='Could not export the master profile.'
$script:TrMap['No se pudo guardar el diagnostico.']='Could not save the diagnostics.'
$script:TrMap['No se pudo guardar el informe.']='Could not save the report.'
$script:TrMap['No se pudo guardar el perfil de debloat.']='Could not save the debloat profile.'
$script:TrMap['No se pudo guardar el perfil maestro.']='Could not save the master profile.'
$script:TrMap['No se pudo guardar el perfil.']='Could not save the profile.'
$script:TrMap['No se pudo guardar la foto del sistema.']='Could not save the system snapshot.'
$script:TrMap['Pasos de la guia copiados.']='Guide steps copied.'
$script:TrMap['Primero pulsa "Detectar mi hardware".']='First press "Detect my hardware".'
$script:TrMap['Re-escaneando caracteristicas...']='Rescanning features...'
$script:TrMap['Suite de Reparacion lanzada ({0}). Sigue el progreso en la consola.']='Repair Suite launched ({0}). Follow the progress in the console.'
$script:TrMap['TERMINADO  ·  OK: {0}  ·  Fallos: {1}']='DONE  ·  OK: {0}  ·  Failures: {1}'
$script:TrMap['Tweaks: {0} de {1} ya aplicados.']='Tweaks: {0} of {1} already applied.'
# --- P3b: tooltips ---
$script:TrMap['{0}   ·   YA INSTALADA']='{0}   ·   ALREADY INSTALLED'
$script:TrMap['{0}   -   tiene guia en espanol (clic derecho > Ver guia)']='{0}   -   has a Spanish guide (right-click > View guide)'
$script:TrMap['Buscar app por nombre o ID']='Search app by name or ID'
$script:TrMap['Deteccion: ninguna app del catalogo esta instalada todavia.']='Detection: no catalog app is installed yet.'
$script:TrMap['Deteccion: {0} apps del catalogo ya instaladas (nombre en verde).']='Detection: {0} catalog apps already installed (name in green).'
# --- P3c: categorias (apps + tweaks/debloat/features) ---
$script:TrMap['Comunicacion']='Communication'
$script:TrMap['Desarrollo']='Development'
$script:TrMap['Discos y Backup']='Disks & Backup'
$script:TrMap['Emuladores']='Emulators'
$script:TrMap['Gaming']='Gaming'
$script:TrMap['IA Local']='Local AI'
$script:TrMap['Imprescindibles']='Essentials'
$script:TrMap['Interfaz']='Interface'
$script:TrMap['Monitorizacion']='Monitoring'
$script:TrMap['Multimedia']='Multimedia'
$script:TrMap['Navegadores']='Browsers'
$script:TrMap['Nube y Sync']='Cloud & Sync'
$script:TrMap['Oficina']='Office'
$script:TrMap['Privacidad']='Privacy'
$script:TrMap['Productividad']='Productivity'
$script:TrMap['Red']='Network'
$script:TrMap['Red y Remoto']='Network & Remote'
$script:TrMap['Rendimiento']='Performance'
$script:TrMap['Runtimes']='Runtimes'
$script:TrMap['Seguridad']='Security'
$script:TrMap['SelfHosted']='Self-Hosted'
$script:TrMap['Sistema']='System'
$script:TrMap['Utilidades']='Utilities'
# --- P3c: descripciones de tweaks/debloat/caracteristicas/reparacion ---
$script:TrMap['%TEMP%, Windows\Temp, papelera de reciclaje y cache DNS.']='%TEMP%, Windows\Temp, recycle bin and DNS cache.'
$script:TrMap['Activa el plan Ultimate Performance (ideal para GPUs de gama alta).']='Enables the Ultimate Performance plan (ideal for high-end GPUs).'
$script:TrMap['Activa Hardware-Accelerated GPU Scheduling. Requiere reiniciar.']='Enables Hardware-Accelerated GPU Scheduling. Requires a restart.'
$script:TrMap['Anade los segundos al reloj de la barra de tareas.']='Adds seconds to the taskbar clock.'
$script:TrMap['Apaga el boton/atajo de Copilot. (No desinstala la app: usa Debloat.)']='Turns off the Copilot button/shortcut. (Does not uninstall the app: use Debloat.)'
$script:TrMap['Apaga el hibernado parcial al arrancar. Evita problemas de drivers y apagados "fantasma"; el equipo arranca completamente limpio.']='Turns off partial hibernation at boot. Avoids driver issues and "ghost" shutdowns; the PC boots completely clean.'
$script:TrMap['Apaga las notificaciones toast y los avisos emergentes de Windows.']='Turns off toast notifications and Windows pop-up alerts.'
$script:TrMap['Apaga Xbox Game Bar y la captura DVR (ahorra recursos).']='Turns off Xbox Game Bar and DVR capture (saves resources).'
$script:TrMap['API de virtualizacion usada por emuladores y sandboxes. Pide reinicio.']='Virtualization API used by emulators and sandboxes. Requires a restart.'
$script:TrMap['App de contactos.']='Contacts app.'
$script:TrMap['App de LinkedIn preinstalada.']='Preinstalled LinkedIn app.'
$script:TrMap['App de mapas.']='Maps app.'
$script:TrMap['App de notas a mano.']='Handwritten notes app.'
$script:TrMap['App de noticias.']='News app.'
$script:TrMap['App del tiempo.']='Weather app.'
$script:TrMap['Apps de Xbox y Game Bar. Quitalo si no usas Xbox.']='Xbox and Game Bar apps. Remove it if you do not use Xbox.'
$script:TrMap['Apps de Xbox y Game Bar (incluye la nueva GamingApp). Quitalo si no usas Xbox.']='Xbox and Game Bar apps (includes the new GamingApp). Remove if you do not use Xbox.'
$script:TrMap['Asistencia de Windows.']='Windows assistance.'
$script:TrMap['Asistencia remota.']='Remote assistance.'
$script:TrMap['Asistente Copilot.']='Copilot assistant.'
$script:TrMap['Asistente Copilot (app + proveedor de IA 25H2).']='Copilot Assistant (app + AI provider 25H2).'
$script:TrMap['Asistente de voz Cortana.']='Cortana voice assistant.'
$script:TrMap['Automatizacion.']='Automation.'
$script:TrMap['Bloquea la recopilacion de datos para funciones de IA (Recall).']='Blocks data collection for AI features (Recall).'
$script:TrMap['Borra archivos temporales y caches para liberar espacio.']='Deletes temporary files and caches to free up space.'
$script:TrMap['Busqueda web de Bing.']='Bing web search.'
$script:TrMap['Cliente de linea de comandos Telnet para diagnostico de red.']='Telnet command-line client for network diagnostics.'
$script:TrMap['Cliente SSH oficial para conexiones seguras desde la consola.']='Official SSH client for secure connections from the console.'
$script:TrMap['Comentarios a Microsoft.']='Feedback to Microsoft.'
$script:TrMap['Comprueba SMART de discos, espacio libre y reinicios pendientes. Solo lectura.']='Checks disk SMART, free space and pending restarts. Read-only.'
$script:TrMap['Consejos de Windows.']='Windows tips.'
$script:TrMap['Control parental.']='Parental controls.'
$script:TrMap['Crea un punto de restauracion del sistema antes de tocar nada.']='Creates a system restore point before touching anything.'
$script:TrMap['Deniega el acceso global a la ubicacion. Algunas apps de mapas/clima dejaran de localizarte.']='Denies global location access. Some maps/weather apps will no longer locate you.'
$script:TrMap['Desactiva el contenido rotativo y los "datos curiosos" patrocinados.']='Disables rotating content and sponsored "fun facts".'
$script:TrMap['Detiene el servicio de indexado. Reduce uso de disco; la busqueda en el menu Inicio sera mas lenta.']='Stops the indexing service. Reduces disk usage; Start menu search will be slower.'
$script:TrMap['Detiene y deshabilita los servicios de actualizacion. Solo temporal y bajo tu responsabilidad.']='Stops and disables the update services. Temporary and at your own risk.'
$script:TrMap['DISM /Online /Cleanup-Image /RestoreHealth. Repara el almacen de componentes. Puede tardar.']='DISM /Online /Cleanup-Image /RestoreHealth. Repairs the component store. May take a while.'
$script:TrMap['DISM /RestoreHealth: repara el almacen de componentes de Windows.']='DISM /RestoreHealth: repairs the Windows component store.'
$script:TrMap['Editor de texto enriquecido clasico de Windows.']='Classic Windows rich text editor.'
$script:TrMap['Editor de video preinstalado.']='Preinstalled video editor.'
$script:TrMap['Ejecuta distribuciones Linux dentro de Windows. Pide reinicio.']='Runs Linux distributions inside Windows. Requires a restart.'
$script:TrMap['Ejecuta sfc /scannow para reparar archivos de Windows danados. Puede tardar.']='Runs sfc /scannow to repair damaged Windows files. May take a while.'
$script:TrMap['Ejecuta wsreset para arreglar la Store y descargas atascadas.']='Runs wsreset to fix the Store and stuck downloads.'
$script:TrMap['Escritorio desechable y aislado para probar software (solo Pro/Enterprise). Pide reinicio.']='Disposable, isolated desktop to test software (Pro/Enterprise only). Requires a restart.'
$script:TrMap['Evita los avisos al pulsar 5 veces Shift o mantener Shift. Imprescindible para juegos.']='Prevents the prompts when pressing Shift 5 times or holding Shift. Essential for gaming.'
$script:TrMap['Evita que USBs y discos lancen programas solos (Autorun).']='Prevents USBs and disks from launching programs on their own (Autorun).'
$script:TrMap['Fuerza a Windows a reindexar (arregla la busqueda lenta o sin resultados).']='Forces Windows to reindex (fixes slow or empty search).'
$script:TrMap['Grabadora de sonido.']='Sound recorder.'
$script:TrMap['Habilita la proteccion del sistema para poder crear puntos.']='Enables system protection so restore points can be created.'
$script:TrMap['Hipervisor y herramientas de Hyper-V (solo Pro/Enterprise). Pide reinicio.']='Hyper-V hypervisor and tools (Pro/Enterprise only). Requires a restart.'
$script:TrMap['Impide que Cortana se ejecute por politica del sistema.']='Prevents Cortana from running via system policy.'
$script:TrMap['Impide que las apps de la Store se ejecuten en segundo plano (ahorra RAM y bateria).']='Prevents Store apps from running in the background (saves RAM and battery).'
$script:TrMap['Juego con anuncios.']='Game with ads.'
$script:TrMap['Lanzadera/anuncio de Microsoft 365 (no es Office).']='Microsoft 365 launcher/ad (not Office).'
$script:TrMap['Limpia la cache de Windows Update (SoftwareDistribution/catroot2).']='Clears the Windows Update cache (SoftwareDistribution/catroot2).'
$script:TrMap['Limpieza final y cierre de la suite.']='Final cleanup and suite shutdown.'
$script:TrMap['Lista de tareas.']='To-do list.'
$script:TrMap['Movimiento de raton 1:1, ideal para shooters. Reinicia la sesion.']='Mouse movement 1:1, ideal for shooters. Restarts the session.'
$script:TrMap['Muestra extensiones de archivo, ocultos, y abre en Este Equipo.']='Shows file extensions, hidden items, and opens to This PC.'
$script:TrMap['Muestra que esta haciendo Windows al encender o apagar (util para diagnosticar cuelgues).']='Shows what Windows is doing on startup or shutdown (useful to diagnose hangs).'
$script:TrMap['Mueve el boton Inicio a la esquina clasica.']='Moves the Start button to the classic corner.'
$script:TrMap['MUY recomendado antes de aplicar el resto de tweaks.']='HIGHLY recommended before applying the rest of the tweaks.'
$script:TrMap['Necesaria para WSL2 y contenedores. Pide reinicio.']='Required for WSL2 and containers. Requires a restart.'
$script:TrMap['netsh winsock reset + int ip reset + flush DNS + renovar IP. Requiere reiniciar.']='netsh winsock reset + int ip reset + flush DNS + renew IP. Requires a restart.'
$script:TrMap['Nuevo Outlook web-app.']='New Outlook web app.'
$script:TrMap['Oculta el icono de Chat (Teams de consumo).']='Hides the Chat icon (consumer Teams).'
$script:TrMap['Oculta el icono de Task View de la barra de tareas.']='Hides the Task View icon from the taskbar.'
$script:TrMap['Oculta el icono de Widgets de la barra de tareas.']='Hides the Widgets icon from the taskbar.'
$script:TrMap['Oculta la caja de busqueda de la barra de tareas (queda mas limpia).']='Hides the taskbar search box (cleaner look).'
$script:TrMap['Paint 3D (no el Paint clasico).']='Paint 3D (not classic Paint).'
$script:TrMap['Panel de Widgets de la barra de tareas. Reinstalable.']='Taskbar Widgets panel. Reinstallable.'
$script:TrMap['Panel para desarrolladores.']='Developer panel.'
$script:TrMap['Para los servicios, renombra SoftwareDistribution y catroot2, y reinicia. Arregla updates atascadas.']='Stops the services, renames SoftwareDistribution and catroot2, and restarts. Fixes stuck updates.'
$script:TrMap['Pausa updates hasta dentro de 35 dias. Reanudable con "Valores por defecto".']='Pauses updates for up to 35 days. Resumable with "Defaults".'
$script:TrMap['Permite matar una app desde la barra de tareas (clic derecho).']='Allows killing an app from the taskbar (right-click).'
$script:TrMap['Phone Link.']='Phone Link.'
$script:TrMap['Pizarra colaborativa.']='Collaborative whiteboard.'
$script:TrMap['Pone el modo oscuro en el sistema y en las aplicaciones.']='Sets dark mode for the system and apps.'
$script:TrMap['Portal de realidad mixta.']='Mixed reality portal.'
$script:TrMap['Prioriza recursos para los juegos en primer plano.']='Prioritizes resources for foreground games.'
$script:TrMap['Quita el retardo al abrir menus.']='Removes the delay when opening menus.'
$script:TrMap['Quita el throttling de red y prioriza respuesta multimedia.']='Removes network throttling and prioritizes multimedia responsiveness.'
$script:TrMap['Quita la web de la busqueda de Inicio y el contenido patrocinado.']='Removes web results from Start search and sponsored content.'
$script:TrMap['Quita las "recomendaciones" patrocinadas dentro de Ajustes.']='Removes sponsored "recommendations" inside Settings.'
$script:TrMap['Quita los efectos de transparencia de la barra y menus. Algo mas de rendimiento.']='Removes transparency effects from the taskbar and menus. A bit more performance.'
$script:TrMap['Quita todos los retrasos/pausas y reactiva el servicio. Vuelve al comportamiento normal.']='Removes all delays/pauses and re-enables the service. Returns to normal behavior.'
$script:TrMap['Recupera varios GB del disco. Mantiene suspension normal.']='Recovers several GB of disk. Keeps normal sleep.'
$script:TrMap['Reduce animaciones y sombras para una respuesta mas agil.']='Reduces animations and shadows for a snappier response.'
$script:TrMap['Reduce el tiempo de espera para cerrar servicios y apps al apagar. Apagado mas rapido.']='Reduces the timeout to close services and apps on shutdown. Faster shutdown.'
$script:TrMap['Reproductor de musica de Microsoft.']='Microsoft music player.'
$script:TrMap['Reproductor de video de Microsoft.']='Microsoft video player.'
$script:TrMap['Resetea la pila de red y sincroniza la hora. Requiere reinicio.']='Resets the network stack and syncs the time. Requires a restart.'
$script:TrMap['Resetea las fuentes de winget y acepta acuerdos. Arregla errores de catalogo y descargas.']='Resets winget sources and accepts agreements. Fixes catalog and download errors.'
$script:TrMap['Resetea las fuentes de winget y arregla errores de catalogo/descarga.']='Resets winget sources and fixes catalog/download errors.'
$script:TrMap['Restablece las politicas de grupo locales a su valor por defecto.']='Resets local group policies to their default value.'
$script:TrMap['Restaura el menu de clic derecho completo de Windows 10.']='Restores the full Windows 10 right-click menu.'
$script:TrMap['Retrasa las actualizaciones de caracteristicas ~1 ano y las de seguridad 4 dias (estilo "Pro").']='Delays feature updates ~1 year and security updates 4 days ("Pro" style).'
$script:TrMap['Revisa el disco en busca de errores del sistema de archivos.']='Checks the disk for file system errors.'
$script:TrMap['Runtime necesario para muchos programas antiguos. Descarga componentes de Windows Update.']='Runtime needed by many older programs. Downloads components from Windows Update.'
$script:TrMap['Salta directamente a la pantalla de inicio de sesion sin la pantalla de bloqueo previa.']='Goes straight to the sign-in screen without the lock screen first.'
$script:TrMap['Servicio DiagTrack, tareas CEIP/Compatibilidad y AllowTelemetry=0.']='DiagTrack service, CEIP/Compatibility tasks and AllowTelemetry=0.'
$script:TrMap['sfc /scannow: repara archivos de sistema danados.']='sfc /scannow: repairs damaged system files.'
$script:TrMap['Skype preinstalado.']='Preinstalled Skype.'
$script:TrMap['Soporte para documentos XPS (impresion y visor).']='Support for XPS documents (printing and viewer).'
$script:TrMap['Teams de consumo (no el de empresa).']='Consumer Teams (not the business one).'
$script:TrMap['Version de sistema del Bloc de notas.']='System version of Notepad.'
$script:TrMap['Visor de modelos 3D.']='3D model viewer.'
$script:TrMap['Windows deja de recopilar y enviar tu actividad reciente.']='Windows stops collecting and sending your recent activity.'
# --- P3c: caveats (Evitalo si: ...) ---
$script:TrMap['buscas archivos a menudo desde el menu Inicio (sera mas lento).']='you often search for files from the Start menu (it will be slower).'
$script:TrMap['es un portatil a bateria: este plan consume mas energia.']='it is a laptop on battery: this plan uses more power.'
$script:TrMap['es un portatil o usas "Hibernar" para guardar la sesion al apagar.']='it is a laptop or you use "Hibernate" to save the session on shutdown.'
$script:TrMap['prefieres una interfaz con animaciones y sombras (es solo estetico).']='you prefer an interface with animations and shadows (purely cosmetic).'
$script:TrMap['te gusta ver el reloj y las notificaciones en la pantalla de bloqueo.']='you like seeing the clock and notifications on the lock screen.'
$script:TrMap['usas el raton sobre todo para escritorio/diseno y no para juegos.']='you use the mouse mainly for desktop/design and not for gaming.'
$script:TrMap['usas Game Bar para grabar la pantalla o ver los FPS en juegos.']='you use Game Bar to record the screen or see FPS in games.'
$script:TrMap['valoras unos segundos menos de arranque por encima de un apagado completo y limpio.']='you value a few seconds less boot time over a complete, clean shutdown.'
# --- P3c: decoraciones y textos del panel de tweaks ---
$script:TrMap['[avanzado]']='[advanced]'
$script:TrMap['  (sin reversion)']='  (no revert)'
$script:TrMap['Evitalo si:']='Avoid it if:'
$script:TrMap['estado: sin comprobar']='state: not checked'
$script:TrMap['accion puntual (sin estado)']='one-time action (stateless)'
$script:TrMap['no comprobable']='not checkable'
$script:TrMap['YA APLICADO']='ALREADY APPLIED'
$script:TrMap['no aplicado']='not applied'
$script:TrMap['recomendado para la mayoria']='recommended for most users'
$script:TrMap['avanzado: aplica solo si lo necesitas']='advanced: apply only if you need it'
$script:TrMap['INSTALADA']='INSTALLED'
$script:TrMap['INSTALADA  (solo en la imagen del sistema)']='INSTALLED  (system image only)'
$script:TrMap['INSTALADA  (usuario + sistema)']='INSTALLED  (user + system)'
$script:TrMap['ya quitada / no presente']='already removed / not present'
$script:TrMap['estado: no comprobable']='status: not checkable'
$script:TrMap['estado: HABILITADO']='status: ENABLED'
$script:TrMap['estado: deshabilitado']='status: disabled'
$script:TrMap['estado: no presente en esta edicion']='status: not present in this edition'
$script:TrMap['estado: HABILITADO (instalada)']='status: ENABLED (installed)'
$script:TrMap['estado: no instalada']='status: not installed'
$script:TrMap['estado: no presente']='status: not present'
$script:TrMap['Crear un punto de restauracion antes de aplicar (recomendado)']='Create a restore point before applying (recommended)'
$script:TrMap['Marca los ajustes y pulsa APLICAR. Los marcados en ambar son "avanzados" (mayor impacto). REVERTIR deshace los que tengan vuelta atras. Antes de aplicar se crea un punto de restauracion si dejas la casilla activada.']='Mark the tweaks and press APPLY. Those marked in amber are "advanced" (greater impact). REVERT undoes the ones that can be undone. Before applying, a restore point is created if you leave the box checked.'
# --- P3c: nombres de tweaks ---
$script:TrMap['Aceleracion de GPU por hardware (HAGS)']='Hardware GPU acceleration (HAGS)'
$script:TrMap['Acelerar el apagado del sistema']='Speed up system shutdown'
$script:TrMap['Activar Modo Juego (Game Mode)']='Enable Game Mode'
$script:TrMap['Activar restauracion del sistema en C:']='Enable System Restore on C:'
$script:TrMap['Activar tema oscuro de Windows']='Enable Windows dark theme'
$script:TrMap['Ajustar efectos visuales para mejor rendimiento']='Adjust visual effects for better performance'
$script:TrMap['Anadir "Finalizar tarea" al boton derecho de la barra']='Add "End task" to the taskbar right-click menu'
$script:TrMap['Barra de tareas alineada a la izquierda (Windows 11)']='Left-aligned taskbar (Windows 11)'
$script:TrMap['Crear punto de restauracion del sistema']='Create a system restore point'
$script:TrMap['Desactivar aceleracion del raton (precision para juegos)']='Disable mouse acceleration (precision for gaming)'
$script:TrMap['Desactivar analisis de IA / Recall']='Disable AI analysis / Recall'
$script:TrMap['Desactivar apps en segundo plano']='Disable background apps'
$script:TrMap['Desactivar Bing, sugerencias y apps promocionadas']='Disable Bing, suggestions and promoted apps'
$script:TrMap['Desactivar Copilot por politica']='Disable Copilot via policy'
$script:TrMap['Desactivar Cortana']='Disable Cortana'
$script:TrMap['Desactivar ejecucion automatica de USB/medios']='Disable USB/media autorun'
$script:TrMap['Desactivar Game Bar y grabacion en segundo plano']='Disable Game Bar and background recording'
$script:TrMap['Desactivar hibernacion (libera hiberfil.sys)']='Disable hibernation (frees hiberfil.sys)'
$script:TrMap['Desactivar historial de actividad (Timeline)']='Disable activity history (Timeline)'
$script:TrMap['Desactivar Inicio rapido (Fast Startup)']='Disable Fast Startup'
$script:TrMap['Desactivar la indexacion de busqueda (Windows Search)']='Disable search indexing (Windows Search)'
$script:TrMap['Desactivar la pantalla de bloqueo']='Disable the lock screen'
$script:TrMap['Desactivar notificaciones del sistema']='Disable system notifications'
$script:TrMap['Desactivar seguimiento de ubicacion']='Disable location tracking'
$script:TrMap['Desactivar sugerencias en Configuracion']='Disable suggestions in Settings'
$script:TrMap['Desactivar teclas especiales (Sticky/Filter/Toggle)']='Disable special keys (Sticky/Filter/Toggle)'
$script:TrMap['Desactivar telemetria innecesaria']='Disable unnecessary telemetry'
$script:TrMap['Desactivar transparencia (rendimiento)']='Disable transparency (performance)'
$script:TrMap['Explorador: extensiones y archivos ocultos visibles']='Explorer: show extensions and hidden files'
$script:TrMap['Limpieza profunda de temporales']='Deep cleanup of temporary files'
$script:TrMap['Menu contextual clasico (Windows 11)']='Classic context menu (Windows 11)'
$script:TrMap['Menus instantaneos (sin retardo)']='Instant menus (no delay)'
$script:TrMap['Mostrar mensajes detallados al iniciar/apagar']='Show detailed messages on startup/shutdown'
$script:TrMap['Mostrar segundos en el reloj de la barra']='Show seconds in the taskbar clock'
$script:TrMap['Optimizar red para juegos/streaming']='Optimize network for gaming/streaming'
$script:TrMap['Plan de energia Maximo Rendimiento']='Maximum Performance power plan'
$script:TrMap['Quitar anuncios de la pantalla de bloqueo e Inicio']='Remove ads from the lock screen and Start'
$script:TrMap['Quitar el boton de Chat/Teams de la barra']='Remove the Chat/Teams button from the taskbar'
$script:TrMap['Quitar el boton de Widgets']='Remove the Widgets button'
$script:TrMap['Quitar el boton Vista de tareas']='Remove the Task View button'
$script:TrMap['Quitar el cuadro de busqueda de la barra']='Remove the taskbar search box'
# --- P3c: nombres de debloat / acciones de reparacion y update ---
$script:TrMap['Abrir Windows Update']='Open Windows Update'
$script:TrMap['Bing Search (widget de busqueda)']='Bing Search (search widget)'
$script:TrMap['Buscar actualizaciones ahora']='Check for updates now'
$script:TrMap['Clipchamp (editor de video)']='Clipchamp (video editor)'
$script:TrMap['Comprobar archivos del sistema (SFC)']='Check system files (SFC)'
$script:TrMap['Configuracion recomendada (retrasar updates)']='Recommended configuration (delay updates)'
$script:TrMap['Desactivar Windows Update por completo']='Disable Windows Update completely'
$script:TrMap['El Tiempo (Bing Weather)']='Weather (Bing Weather)'
$script:TrMap['Family (Seguridad familiar)']='Family (Family Safety)'
$script:TrMap['Get Help (Obtener ayuda)']='Get Help'
$script:TrMap['Grabadora de voz']='Voice Recorder'
$script:TrMap['Groove Musica']='Groove Music'
$script:TrMap['Limpiar la cache de Microsoft Store']='Clear the Microsoft Store cache'
$script:TrMap['Mapas (Windows Maps)']='Maps (Windows Maps)'
$script:TrMap['Noticias (Microsoft News)']='News (Microsoft News)'
$script:TrMap['Outlook (nuevo, preinstalado)']='Outlook (new, preinstalled)'
$script:TrMap['Pausar todas las actualizaciones 5 semanas']='Pause all updates for 5 weeks'
$script:TrMap['Peliculas y TV (Movies & TV)']='Movies & TV'
$script:TrMap['People (Contactos)']='People (Contacts)'
$script:TrMap['Power Automate (preinstalado)']='Power Automate (preinstalled)'
$script:TrMap['Reconstruir el indice de busqueda']='Rebuild the search index'
$script:TrMap['Reparar imagen de Windows (DISM RestoreHealth)']='Repair Windows image (DISM RestoreHealth)'
$script:TrMap['Reparar Windows Update (limpiar cache)']='Repair Windows Update (clear cache)'
$script:TrMap['Reparar/Resetear winget']='Repair/Reset winget'
$script:TrMap['Restablecer la red (Winsock/TCP-IP/DNS)']='Reset the network (Winsock/TCP-IP/DNS)'
$script:TrMap['Solitario Collection']='Solitaire Collection'
$script:TrMap['Tips / Sugerencias']='Tips / Suggestions'
$script:TrMap['Tu telefono / Vincular al movil']='Phone Link / Link to phone'
$script:TrMap['Valores por defecto de Windows Update']='Windows Update defaults'
$script:TrMap['Visor 3D (3D Viewer)']='3D Viewer'
$script:TrMap['Whiteboard (Pizarra)']='Whiteboard'
$script:TrMap['Xbox (apps y overlay de juego)']='Xbox (apps and game overlay)'
# --- P3c: nombres de caracteristicas de Windows y paneles clasicos ---
$script:TrMap['.NET Framework 3.5 (incluye 2.0 y 3.0)']='.NET Framework 3.5 (includes 2.0 and 3.0)'
$script:TrMap['Cliente Telnet']='Telnet Client'
$script:TrMap['Visor de XPS']='XPS Viewer'
$script:TrMap['Plataforma del hipervisor de Windows']='Windows Hypervisor Platform'
$script:TrMap['Plataforma de maquina virtual (WSL2)']='Virtual Machine Platform (WSL2)'
$script:TrMap['Subsistema de Windows para Linux (WSL)']='Windows Subsystem for Linux (WSL)'
$script:TrMap['Plataforma Hyper-V (completa)']='Hyper-V Platform (full)'
$script:TrMap['Sandbox de Windows']='Windows Sandbox'
$script:TrMap['Bloc de notas (clasico)']='Notepad (classic)'
$script:TrMap['Cliente OpenSSH']='OpenSSH Client'
$script:TrMap['Panel de control']='Control Panel'
$script:TrMap['Programas y caracteristicas']='Programs and Features'
$script:TrMap['Propiedades del sistema']='System Properties'
$script:TrMap['Opciones de energia']='Power Options'
$script:TrMap['Conexiones de red']='Network Connections'
$script:TrMap['Sonido']='Sound'
$script:TrMap['Servicios']='Services'
$script:TrMap['Administrador de dispositivos']='Device Manager'
$script:TrMap['Administrador de discos']='Disk Management'
$script:TrMap['Editor de directivas (gpedit)']='Policy Editor (gpedit)'
$script:TrMap['Liberador de espacio']='Disk Cleanup'
$script:TrMap['Informacion del sistema']='System Information'
$script:TrMap['Sistema']='System'
$script:TrMap['Equipo']='PC'
$script:TrMap['principal']='primary'
$script:TrMap['dedicada']='dedicated'
$script:TrMap['integrada']='integrated'
$script:TrMap['en uso']='in use'
$script:TrMap['asignada']='assigned'
$script:TrMap['memoria compartida con la RAM']='shared with RAM'
$script:TrMap['hace ~{0} meses: conviene revisar si hay uno mas nuevo']='~{0} months old: consider checking for a newer one'
$script:TrMap['Adaptadores virtuales: {0}']='Virtual adapters: {0}'
$script:TrMap['Tarjeta grafica (GPU)']='Graphics card (GPU)'
$script:TrMap['No se detectaron tarjetas graficas.']='No graphics cards detected.'
$script:TrMap['No se pudo leer la informacion de la GPU.']='Could not read GPU information.'
$script:TrMap['Procesador (CPU)']='Processor (CPU)'
$script:TrMap['{0} nucleos / {1} hilos']='{0} cores / {1} threads'
$script:TrMap['cache L3 {0}']='L3 cache {0}'
$script:TrMap['Memoria RAM']='RAM Memory'
$script:TrMap['perfil XMP/EXPO activo']='XMP/EXPO profile active'
$script:TrMap['XMP/EXPO sin activar, nominal {0} MHz']='XMP/EXPO not enabled, rated {0} MHz'
$script:TrMap['{0} / {1} modulos']='{0} / {1} modules'
$script:TrMap['{0} modulos']='{0} modules'
$script:TrMap['sin modulos']='no modules'
$script:TrMap['totales']='total'
$script:TrMap['Placa base']='Motherboard'
$script:TrMap['version']='version'
$script:TrMap['externo']='external'
$script:TrMap['salud OK']='health OK'
$script:TrMap['SALUD: {0}']='HEALTH: {0}'
$script:TrMap['Discos']='Storage / Disks'
$script:TrMap['desgaste {0}%']='wear {0}%'
$script:TrMap['{0} h encendido']='{0} h powered on'
$script:TrMap['Bateria']='Battery'
$script:TrMap['descargando']='discharging'
$script:TrMap['enchufado (CA)']='plugged in (AC)'
$script:TrMap['cargada']='charged'
$script:TrMap['baja']='low'
$script:TrMap['critica']='critical'
$script:TrMap['cargando']='charging'
$script:TrMap['cargando (alta)']='charging (high)'
$script:TrMap['cargando (baja)']='charging (low)'
$script:TrMap['cargando (critica)']='charging (critical)'
$script:TrMap['{0}% de carga']='{0}% charge'
$script:TrMap['salud de la bateria: {0}%{1}{2} de {3} mWh de diseno']='battery health: {0}%{1}{2} of {3} design mWh'
$script:TrMap['Tema actual: {0}']='Current theme: {0}'
$script:TrMap['Cambiar tema (siguiente: {0})']='Change theme (next: {0})'
$script:TrMap['Oscuro']='Dark'
$script:TrMap['Claro']='Light'
$script:TrMap['Azul']='Blue'
$script:TrMap['{0} disponibles para instalar']='{0} available to install'
$script:TrMap['{0} de {1} comprobables']='{0} of {1} verifiable'
$script:TrMap['{0} de {1} apps de la lista siguen instaladas']='{0} of {1} apps on the list are still installed'
$script:TrMap['{0} GB libres de {1} GB']='{0} GB free of {1} GB'
$script:TrMap['{0} GB en uso de {1} GB ({2}%)']='{0} GB in use of {1} GB ({2}%)'
$script:TrMap['Proteccion activada']='Protection active'
$script:TrMap['Desactivada (recomendable activarla antes de tocar tweaks)']='Disabled (recommended to enable before applying tweaks)'
$script:TrMap['no detectado']='not detected'
$script:TrMap['Apps del catalogo']='Apps in catalog'
$script:TrMap['Tweaks aplicados']='Applied tweaks'
$script:TrMap['Bloatware presente']='Bloatware present'
$script:TrMap['Disco C:']='C: Drive'
$script:TrMap['Punto de restauracion']='Restore point'
$script:TrMap['Emulador de Switch (Eden / Citron) - NO esta en winget']='Switch Emulator (Eden / Citron) - NOT on winget'
$script:TrMap['Emuladores de Android (los mas top)']='Android Emulators (top picks)'
$script:TrMap['Crear guias.json editable']='Create editable guides.json'
$script:TrMap['Recargar guias.json (reinicia)']='Reload guides.json (restarts)'
# << TRMAP_ENTRIES >>
# Traduce una frase exacta (si Lang=en y esta en el mapa); si no, la deja igual.
function Tr([string]$s) {
    $s = Repair-WpiText $s
    if ($script:Lang -ne 'en' -or [string]::IsNullOrEmpty($s)) { return $s }
    if ($script:TrMap.ContainsKey($s)) { return [string]$script:TrMap[$s] }
    $t = $s.Trim()
    if ($t -ne $s -and $script:TrMap.ContainsKey($t)) { return [string]$script:TrMap[$t] }
    return (Repair-WpiText $s)
}
# Aviso traducido: envoltorio de MessageBox que pasa texto y titulo por Tr.
# Acepta tambien una sola llamada con parentesis (array) para el reemplazo global.
function Show-WpiMessage {
    param($Text, $Title = 'WPI Moderno', $Buttons = 'OK', $Icon = 'Information')
    if ($Text -is [array]) {
        $a = $Text
        $Text = $(if ($a.Count -ge 1) { $a[0] } else { '' })
        if ($a.Count -ge 2) { $Title = $a[1] }
        if ($a.Count -ge 3) { $Buttons = $a[2] }
        if ($a.Count -ge 4) { $Icon = $a[3] }
    }
    $mb = [System.Windows.MessageBox]
    return $mb::Show((Tr (Repair-WpiText ([string]$Text))), (Tr (Repair-WpiText ([string]$Title))), $Buttons, $Icon)
}
# Recorre el arbol logico y traduce textos de TextBlock, botones, casillas, etc.
function Translate-Tree($node) {
    if ($script:Lang -ne 'en' -or $null -eq $node) { return }
    try {
        if ($node -is [Windows.Controls.TextBlock]) { $node.Text = Tr ([string]$node.Text) }
        elseif ($node -is [Windows.Controls.HeaderedContentControl]) { if ($node.Header -is [string]) { $node.Header = Tr ([string]$node.Header) } }
        elseif ($node -is [Windows.Controls.ContentControl]) { if ($node.Content -is [string]) { $node.Content = Tr ([string]$node.Content) } }
        elseif ($node -is [Windows.Controls.TextBox] -and $node.IsReadOnly) { $node.Text = Tr ([string]$node.Text) }
    } catch {}
    try { foreach ($c in [Windows.LogicalTreeHelper]::GetChildren($node)) { if ($c -is [Windows.DependencyObject]) { Translate-Tree $c } } } catch {}
}

$script:ToolTipText = @{
    es = @{
        CboTheme='Elige el tema visual. El cambio se aplica al reiniciar la app.'
        CboLang='Cambia el idioma de la interfaz. Se aplica al reiniciar la app.'
        SearchBox='Filtra rápidamente apps por nombre, categoría o ID de winget.'
        BtnPresetGaming='Selecciona automáticamente el pack de apps recomendadas para gaming.'
        BtnPresetDev='Selecciona el pack de herramientas de desarrollo.'
        BtnPresetMedia='Selecciona apps de edición de vídeo, audio e imagen.'
        BtnPresetClean='Selecciona las apps básicas recomendadas para cualquier PC.'
        BtnPresetLast='Recupera la selección de la última vez que usaste WPI.'
        BtnSave='Guarda tu selección actual en un perfil para usarla después.'
        BtnLoad='Carga una selección guardada previamente.'
        BtnDetect='Busca en tu PC qué apps del catálogo ya están instaladas y las marca.'
        BtnClearSel='Quita todas las selecciones actuales.'
        SpeedBox='Número de instalaciones paralelas. Más hilos = más velocidad pero más carga del sistema.'
        ScopeBox='Instala para todos los usuarios, solo el tuyo, o deja que winget decida automáticamente.'
        ChkChoco='Si una app falla con winget, intenta instalarla con Chocolatey si está disponible.'
        BtnAll='Selecciona todas las apps visibles en la lista actual.'
        BtnNone='Quita la marca de todas las apps seleccionadas.'
        BtnUninstall='Desinstala del sistema las apps marcadas. Acción irreversible.'
        BtnDownload='Descarga el instalador .exe o .msi directamente, sin usar winget.'
        BtnValidate='Comprueba que los IDs de winget de las apps seleccionadas son válidos y existen.'
        BtnList='Busca si hay actualizaciones disponibles para las apps instaladas.'
        BtnUpgrade='Actualiza todas tus apps instaladas a la última versión disponible.'
        BtnInstall='Instala las apps marcadas con winget. Puedes marcar varias a la vez.'
        LogExpander='Muestra en tiempo real lo que está haciendo WPI: instalaciones, errores y progreso.'
        LogList='Registro en vivo con la salida del motor de instalación y mantenimiento.'
        Prog='Progreso global de la operación actual.'
        BtnOpenLog='Abre el log forense de la sesión actual.'
        BtnOpenLogs='Abre la carpeta donde WPI guarda los logs.'
        BtnCancel='Cancela el proceso en curso cuando sea posible.'
        ChkRestore='Crea un punto de restauración antes de aplicar ajustes.'
        APLICAR_SELECCIONADOS='Aplica los ajustes marcados. Se crea un punto de restauración si está activada la opción.'
        REVERTIR_SELECCIONADOS='Deshace los ajustes que tienen vuelta atrás.'
        Habilitar='Activa este componente opcional de Windows. Puede requerir reinicio.'
        Deshabilitar='Desactiva este componente opcional de Windows. Es reversible.'
        'Detectar mi hardware'='Escanea y muestra las specs de tu PC: GPU, CPU, RAM, disco y placa.'
        'Copiar informe'='Copia el informe de hardware al portapapeles.'
        'Exportar a archivo'='Guarda el informe de hardware en un archivo de texto.'
        'Lanzar Consola Interactiva (Menu Completo)'='Abre la suite de reparación de Windows en modo consola con sus 17 fases.'
        'Descargar O&O ShutUp10++ (web oficial)'='Abre la web oficial de O&O ShutUp10++ para descargar la herramienta de privacidad.'
        'REGISTRO EN VIVO'='Muestra en tiempo real instalaciones, errores y progreso.'
    }
    en = @{
        CboTheme='Choose the visual theme. The change applies after restarting the app.'
        CboLang='Changes the UI language. It applies after restarting the app.'
        SearchBox='Quickly filters apps by name, category, or winget ID.'
        BtnPresetGaming='Auto-selects the recommended gaming app pack.'
        BtnPresetDev='Auto-selects the developer tools pack.'
        BtnPresetMedia='Auto-selects video, audio, and image editing apps.'
        BtnPresetClean='Auto-selects the basic apps recommended for any PC.'
        BtnPresetLast='Restores the selection from the last time you used WPI.'
        BtnSave='Saves your current selection to a profile for later use.'
        BtnLoad='Loads a previously saved selection.'
        BtnDetect='Scans your PC for already-installed apps from the catalog and marks them.'
        BtnClearSel='Removes all current selections.'
        SpeedBox='Number of parallel installations. More threads = faster but more system load.'
        ScopeBox='Installs for all users, only your user, or lets winget decide automatically.'
        ChkChoco='If an app fails with winget, tries Chocolatey when available.'
        BtnAll='Selects all apps currently visible in the list.'
        BtnNone='Unchecks all currently selected apps.'
        BtnUninstall='Uninstalls the checked apps from the system. This action is irreversible.'
        BtnDownload='Downloads the .exe or .msi installer directly, bypassing winget.'
        BtnValidate='Checks that the winget IDs of selected apps are valid and exist.'
        BtnList='Searches for available updates for your installed apps.'
        BtnUpgrade='Updates all your installed apps to the latest available version.'
        BtnInstall='Installs the checked apps via winget. You can select multiple at once.'
        LogExpander='Shows in real time what WPI is doing: installations, errors, and progress.'
        LogList='Live log with output from the installation and maintenance engine.'
        Prog='Overall progress of the current operation.'
        BtnOpenLog='Opens the forensic log for the current session.'
        BtnOpenLogs='Opens the folder where WPI stores logs.'
        BtnCancel='Cancels the running process when possible.'
        ChkRestore='Creates a restore point before applying tweaks.'
        APLICAR_SELECCIONADOS='Applies the checked tweaks. A restore point is created first if the option is enabled.'
        REVERTIR_SELECCIONADOS='Undoes the tweaks that support reverting.'
        Habilitar='Enables this optional Windows component. May require a restart.'
        Deshabilitar='Disables this optional Windows component. Reversible.'
        'Detectar mi hardware'='Scans and displays your PC specs: GPU, CPU, RAM, disk, and motherboard.'
        'Copiar informe'='Copies the hardware report to the clipboard.'
        'Exportar a archivo'='Saves the hardware report to a text file.'
        'Launch Interactive Console (Full Menu)'='Opens the Windows repair suite in console mode with its 17 phases.'
        'Download O&O ShutUp10++ (Official Site)'='Opens the official O&O ShutUp10++ website to download the privacy tool.'
        'LIVE LOG'='Shows installations, errors, and progress in real time.'
    }
}

function Get-WpiToolTipText([string]$Key) {
    if ([string]::IsNullOrWhiteSpace($Key)) { return '' }
    $lang = if ($script:Lang -eq 'en') { 'en' } else { 'es' }
    $tbl = $script:ToolTipText[$lang]
    if ($tbl -and $tbl.ContainsKey($Key)) { return [string]$tbl[$Key] }
    $es = $script:ToolTipText['es']
    if ($es -and $es.ContainsKey($Key)) { return (Tr ([string]$es[$Key])) }
    return ''
}

function Set-WpiToolTip($Control, [string]$Key, [string]$Fallback = '') {
    if (-not $Control) { return }
    $tip = Get-WpiToolTipText $Key
    if (-not $tip -and $Fallback) { $tip = if ($script:Lang -eq 'en') { $Fallback } else { $Fallback } }
    if (-not $tip) { return }
    try {
        $Control.ToolTip = Repair-WpiText (Tr $tip)
        [Windows.Controls.ToolTipService]::SetInitialShowDelay($Control, 700)
        [Windows.Controls.ToolTipService]::SetShowDuration($Control, 5500)
        [Windows.Controls.ToolTipService]::SetBetweenShowDelay($Control, 250)
    } catch {}
}

function Apply-WpiToolTips($node) {
    if ($null -eq $node) { return }
    try {
        $name = ''
        try { $name = [string]$node.Name } catch {}
        if ($name) { Set-WpiToolTip $node $name }

        $textKey = ''
        if ($node -is [Windows.Controls.Button] -and $node.Content -is [string]) { $textKey = [string]$node.Content }
        elseif ($node -is [Windows.Controls.CheckBox] -and $node.Content -is [string]) { $textKey = [string]$node.Content }
        elseif ($node -is [Windows.Controls.Expander]) {
            if ($node.Header -is [string]) { $textKey = [string]$node.Header }
            elseif ($node.Header -is [Windows.Controls.TextBlock]) { $textKey = [string]$node.Header.Text }
        }
        if ($textKey -and -not $node.ToolTip) { Set-WpiToolTip $node $textKey }
        elseif ($node.ToolTip -is [string]) { $node.ToolTip = Repair-WpiText (Tr ([string]$node.ToolTip)) }

        if (($node -is [Windows.Controls.Button]) -and -not $node.ToolTip -and $textKey) {
            $fallback = if ($script:Lang -eq 'en') { ('Runs this action: {0}' -f $textKey) } else { ('Ejecuta esta accion: {0}' -f $textKey) }
            Set-WpiToolTip $node '' $fallback
        } elseif (($node -is [Windows.Controls.CheckBox]) -and -not $node.ToolTip -and $textKey) {
            $fallback = if ($script:Lang -eq 'en') { ('Selects or clears this option: {0}' -f $textKey) } else { ('Marca o desmarca esta opcion: {0}' -f $textKey) }
            Set-WpiToolTip $node '' $fallback
        } elseif (($node -is [Windows.Controls.MenuItem]) -and -not $node.ToolTip) {
            $hdr = ''; try { if ($node.Header -is [string]) { $hdr = [string]$node.Header } } catch {}
            if ($hdr) {
                $fallback = if ($script:Lang -eq 'en') { ('Opens this menu action: {0}' -f $hdr) } else { ('Abre esta accion de menu: {0}' -f $hdr) }
                Set-WpiToolTip $node '' $fallback
            }
        } elseif (($node -is [Windows.Controls.Expander]) -and -not $node.ToolTip) {
            $fallback = if ($script:Lang -eq 'en') { 'Expands or collapses this section.' } else { 'Despliega o contrae esta seccion.' }
            Set-WpiToolTip $node '' $fallback
        } elseif (($node -is [Windows.Controls.TextBox]) -and -not $node.ToolTip) {
            $fallback = if ($script:Lang -eq 'en') { 'Type here to filter or enter the requested value.' } else { 'Escribe aqui para filtrar o introducir el valor solicitado.' }
            Set-WpiToolTip $node '' $fallback
        } elseif (($node -is [Windows.Controls.ComboBox]) -and -not $node.ToolTip) {
            $fallback = if ($script:Lang -eq 'en') { 'Choose one of the available options.' } else { 'Elige una de las opciones disponibles.' }
            Set-WpiToolTip $node '' $fallback
        } elseif (($node -is [Windows.Controls.ListBox]) -and -not $node.ToolTip) {
            $fallback = if ($script:Lang -eq 'en') { 'Interactive list. Select an item to open or inspect it.' } else { 'Lista interactiva. Selecciona un elemento para abrirlo o revisarlo.' }
            Set-WpiToolTip $node '' $fallback
        }
    } catch {}
    try { foreach ($c in [Windows.LogicalTreeHelper]::GetChildren($node)) { if ($c -is [Windows.DependencyObject]) { Apply-WpiToolTips $c } } } catch {}
}

# --------------------------- XAML ---------------------------
$script:XamlRaw = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WPI Moderno"
        Width="1480" Height="880" MinWidth="1180" MinHeight="700"
        WindowStartupLocation="CenterScreen">
  <Window.Background>
    <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#FF0B0B11" Offset="0"/>
      <GradientStop Color="#FF101A2B" Offset="0.6"/>
      <GradientStop Color="#FF160F26" Offset="1"/>
    </LinearGradientBrush>
  </Window.Background>
  <Window.Resources>
    <Style TargetType="ToolTip">
      <Setter Property="Background" Value="#EE101018"/>
      <Setter Property="Foreground" Value="#FFF2F6FA"/>
      <Setter Property="BorderBrush" Value="#FF00E5FF"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="MaxWidth" Value="420"/>
      <Setter Property="Placement" Value="Mouse"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToolTip">
            <Border Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="8"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#FFF7FAFF"/>
      <Setter Property="Background" Value="#FF22222C"/>
      <Setter Property="BorderBrush" Value="#FF3A3A48"/>
      <Setter Property="Padding" Value="13,7"/>
      <Setter Property="Margin" Value="8,0,0,0"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="10"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="#FF00E5FF"/>
                <Setter TargetName="Bd" Property="Background" Value="#FF2C2C3C"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#FF101018"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#FFEDEDF2"/>
      <Setter Property="Margin" Value="6,3,6,3"/>
      <Setter Property="MinWidth" Value="250"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="cbBd" Background="Transparent" BorderBrush="Transparent"
                    BorderThickness="1" CornerRadius="7" Padding="7,5">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="box" Width="16" Height="16" CornerRadius="4" Margin="0,0,9,0"
                        BorderBrush="#FF55555F" BorderThickness="2" Background="Transparent"
                        VerticalAlignment="Center"/>
                <ContentPresenter VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="box" Property="Background" Value="#FF00E5FF"/>
                <Setter TargetName="box" Property="BorderBrush" Value="#FF00E5FF"/>
                <Setter Property="Foreground" Value="#FF9D7BFF"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="cbBd" Property="Background" Value="#FF20202E"/>
                <Setter TargetName="cbBd" Property="BorderBrush" Value="#FF00E5FF"/>
                <Setter Property="Foreground" Value="#FF00E5FF"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#FF1B1B25"/>
      <Setter Property="Foreground" Value="#FFE6E6EC"/>
      <Setter Property="BorderBrush" Value="#FF3A3A48"/>
      <Setter Property="CaretBrush" Value="#FF00E5FF"/>
      <Setter Property="Padding" Value="9,6"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Height" Value="30"/>
      <Setter Property="Foreground" Value="#FFE6E6EC"/>
      <Setter Property="Background" Value="#FF1B1B25"/>
      <Setter Property="BorderBrush" Value="#FF3A3A48"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton Focusable="False" ClickMode="Press"
                  Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="tb" Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8">
                      <Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,9,0"
                            Data="M0,0 L4,4 L8,0 Z" Fill="#FFE6E6EC"/>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="tb" Property="BorderBrush" Value="#FF00E5FF"/>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}"
                                TextElement.Foreground="{TemplateBinding Foreground}"
                                Margin="10,0,26,0" VerticalAlignment="Center" HorizontalAlignment="Left"/>
              <Popup Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True" Focusable="False">
                <Border Background="#FF15151F" BorderBrush="#FF3A3A48" BorderThickness="1" CornerRadius="8" Margin="0,2,0,0"
                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}">
                  <ScrollViewer><ItemsPresenter/></ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="#FFE6E6EC"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="ib" Background="#FF15151F" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="ib" Property="Background" Value="#FF3F9EFF"/>
                <Setter Property="Foreground" Value="#FFFFFFFF"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True"><Setter Property="FontWeight" Value="SemiBold"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SideItem" TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="#FFC9C9D4"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border x:Name="Bd" CornerRadius="9" Margin="6,2" Padding="12,8" Background="Transparent">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#FF20202E"/>
                <Setter Property="Foreground" Value="#FFE6E6EC"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Foreground" Value="#FFE6E6EC"/>
                <Setter Property="FontWeight" Value="Bold"/>
                <Setter TargetName="Bd" Property="Background">
                  <Setter.Value>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                      <GradientStop Color="#FF0A4D5E" Offset="0"/>
                      <GradientStop Color="#FF3A2A6E" Offset="1"/>
                    </LinearGradientBrush>
                  </Setter.Value>
                </Setter>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ProgressBar">
      <Setter Property="Height" Value="12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Grid>
              <Border x:Name="PART_Track" Background="#FF1B1B25" CornerRadius="6"
                      BorderBrush="#FF2C2C3A" BorderThickness="1"/>
              <Border x:Name="PART_Indicator" HorizontalAlignment="Left" CornerRadius="6">
                <Border.Background>
                  <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#FF00E5FF" Offset="0"/>
                    <GradientStop Color="#FF7C4DFF" Offset="1"/>
                  </LinearGradientBrush>
                </Border.Background>
              </Border>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="14">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="248"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Border Grid.Column="0" Background="#FF12121A" BorderBrush="#FF2C2C3A"
            BorderThickness="1" CornerRadius="14" Margin="0,0,14,0">
      <DockPanel Margin="8,14,8,10">
        <StackPanel DockPanel.Dock="Top" Margin="10,0,10,12">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="WPI " FontSize="27" FontWeight="Bold" Foreground="#FF00E5FF"/>
            <TextBlock Text="MODERNO" FontSize="27" FontWeight="Bold" Foreground="#FF7C4DFF"/>
          </StackPanel>
          <TextBlock x:Name="VerText" FontSize="12" Foreground="#FF8A8A95"/>
          <ComboBox x:Name="CboTheme" HorizontalAlignment="Left" Margin="0,8,0,0" Width="170" FontSize="12"
                    Background="#FF3A2A6E" BorderBrush="#FF9D7BFF" Foreground="#FFE6E6EC"
                    ToolTip="Elige el tema visual (se aplica al reiniciar)">
            <ComboBoxItem Content="Tema: Oscuro"/>
            <ComboBoxItem Content="Tema: Claro"/>
            <ComboBoxItem Content="Tema: Azul (Chris Titus)"/>
          </ComboBox>
          <ComboBox x:Name="CboLang" HorizontalAlignment="Left" Margin="0,6,0,0" Width="170" FontSize="12"
                    Background="#FF1F3A2E" BorderBrush="#FF5CFF8F" Foreground="#FFE6E6EC"
                    ToolTip="Idioma de la interfaz / UI language (restart to apply)">
            <ComboBoxItem Content="Idioma: Espanol"/>
            <ComboBoxItem Content="Language: English"/>
          </ComboBox>
          <Border x:Name="SysBox" Background="#FF15151F" BorderBrush="#FF2C2C3A" BorderThickness="1"
                  CornerRadius="9" Padding="10,7" Margin="0,10,0,0">
            <TextBlock x:Name="SysInfo" FontSize="11" Foreground="#FF9A9AA5" TextWrapping="Wrap"
                       Text="Cargando informacion del sistema..."/>
          </Border>
        </StackPanel>
        <TextBlock DockPanel.Dock="Bottom" Foreground="#FF55555F" FontSize="11" Margin="10,8,10,0"
                   TextWrapping="Wrap"
                   Text="Los enlaces los gestiona el repositorio oficial de winget: nunca caducan."/>
        <ListBox x:Name="SideList" Background="Transparent" BorderThickness="0"
                 ItemContainerStyle="{StaticResource SideItem}"
                 ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
      </DockPanel>
    </Border>

    <Grid Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <StackPanel Grid.Row="0" Margin="0,0,0,8">
        <DockPanel>
          <TextBlock Text="Buscar:" Foreground="#FF9A9AA5" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <TextBox x:Name="SearchBox"/>
        </DockPanel>
        <DockPanel Margin="0,8,0,0">
          <TextBlock Text="Presets:" Foreground="#FF9A9AA5" VerticalAlignment="Center" Margin="0,0,4,0"/>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="BtnPresetGaming" Content="Gaming"        Background="#FF24303F" BorderBrush="#FF3C5876"/>
            <Button x:Name="BtnPresetDev"    Content="Desarrollador" Background="#FF24303F" BorderBrush="#FF3C5876"/>
            <Button x:Name="BtnPresetMedia"  Content="Multimedia"    Background="#FF24303F" BorderBrush="#FF3C5876"/>
            <Button x:Name="BtnPresetClean"  Content="Esencial"      Background="#FF24303F" BorderBrush="#FF3C5876"/>
            <Button x:Name="BtnPresetLast"   Content="Ultima sesion" Background="#FF24303F" BorderBrush="#FF3C5876"/>
            <Button x:Name="BtnSave"         Content="Guardar"/>
            <Button x:Name="BtnLoad"         Content="Cargar"/>
            <Button x:Name="BtnDetect"       Content="Detectar instaladas" Background="#FF1F3A2E" BorderBrush="#FF3E6B54"/>
            <Button x:Name="BtnClearSel"     Content="Limpiar seleccion"/>
          </StackPanel>
        </DockPanel>
      </StackPanel>

      <Grid Grid.Row="1">
        <ScrollViewer x:Name="AppsScroll" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="Lists" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="TweaksScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="TweaksList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="UpgradesScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="UpgradesList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="WingetSearchScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="WingetSearchList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="DebloatScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="DebloatList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="SnapshotScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="SnapshotList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="GuidesScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="GuidesList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="DriversScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="DriversList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="WinUpdateScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="WinUpdateList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="RepairScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="RepairList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="SummaryScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="SummaryList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="FeaturesScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="FeaturesList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="CreateIsoScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="CreateIsoList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="LogViewerScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="LogViewerList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="QuickStartScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="QuickStartList" Margin="0,0,6,0"/>
        </ScrollViewer>
        <ScrollViewer x:Name="FindAllScroll" VerticalScrollBarVisibility="Auto" Visibility="Collapsed">
          <StackPanel x:Name="FindAllList" Margin="0,0,6,0"/>
        </ScrollViewer>
      </Grid>

      <StackPanel Grid.Row="2" Margin="0,10,0,0">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,8">
          <TextBlock x:Name="CounterText" Foreground="#FF00E5FF" FontSize="13"
                     VerticalAlignment="Center" Text="Seleccionadas: 0"/>
          <TextBlock Text="Hilos:" Foreground="#FF9A9AA5" Margin="14,0,6,0" VerticalAlignment="Center"
                     ToolTip="Instalaciones simultaneas. 1x = seguro; 2x-3x acelera, los choques MSI se reintentan solos."/>
          <ComboBox x:Name="SpeedBox" Width="104" VerticalAlignment="Center"
                    ToolTip="Instalaciones simultaneas. 1x = seguro; 2x-3x acelera, los choques MSI se reintentan solos.">
            <ComboBoxItem Content="1x seguro"/>
            <ComboBoxItem Content="2x"/>
            <ComboBoxItem Content="3x turbo"/>
          </ComboBox>
          <TextBlock Text="Ambito:" Foreground="#FF9A9AA5" Margin="14,0,6,0" VerticalAlignment="Center"
                     ToolTip="Para quien se instala. Auto = como decida winget; usuario o todo el equipo (--scope)."/>
          <ComboBox x:Name="ScopeBox" Width="128" VerticalAlignment="Center"
                    ToolTip="Auto = sin --scope (recomendado). 'Este usuario' o 'Todo el equipo' fuerzan --scope user/machine.">
            <ComboBoxItem Content="Auto"/>
            <ComboBoxItem Content="Este usuario"/>
            <ComboBoxItem Content="Todo el equipo"/>
          </ComboBox>
          <CheckBox x:Name="ChkChoco" Content="Fallback Choco" Foreground="#FF9A9AA5" Margin="14,0,0,0" VerticalAlignment="Center"
                    ToolTip="Si winget falla al instalar una app, intentar con Chocolatey (si esta instalado). Best-effort: el ID puede no existir en choco. Queda en el log."/>
        </StackPanel>
        <WrapPanel HorizontalAlignment="Left">
          <Button x:Name="BtnAll"       Content="Marcar visibles" Margin="0,4,8,0"/>
          <Button x:Name="BtnNone"      Content="Desmarcar" Margin="0,4,8,0"/>
          <Button x:Name="BtnUninstall" Content="Desinstalar"        Background="#FF4F2A2A" BorderBrush="#FF7B4444" Margin="0,4,8,0"/>
          <Button x:Name="BtnDownload"  Content="Descargar .exe/.msi" Background="#FF2A3F4F" BorderBrush="#FF4477AA" Margin="0,4,8,0"/>
          <Button x:Name="BtnValidate"  Content="Validar IDs"        Background="#FF3A2A4F" BorderBrush="#FF6B4D9E" Margin="0,4,8,0"/>
          <Button x:Name="BtnList"      Content="Buscar updates"    Background="#FF2B3A4F" BorderBrush="#FF3F5E80" Margin="0,4,8,0"/>
          <Button x:Name="BtnUpgrade"   Content="Actualizar TODO"    Background="#FF2F4A2A" BorderBrush="#FF4F7B44" Margin="0,4,8,0"/>
          <Button x:Name="BtnInstall"   Content="INSTALAR (0)" FontWeight="Bold"
                  Background="#FF0A84FF" BorderBrush="#FF35A0FF" Padding="18,8" Margin="0,4,0,0"/>
        </WrapPanel>
      </StackPanel>

      <Expander x:Name="LogExpander" Grid.Row="3" IsExpanded="False" Margin="0,10,0,0"
                Foreground="#FF9A9AA5">
        <Expander.Header>
          <TextBlock Text="REGISTRO EN VIVO" FontWeight="Bold" Foreground="#FF00E5FF"/>
        </Expander.Header>
        <Border Background="#FF101018" BorderBrush="#FF2C2C3A" BorderThickness="1"
                CornerRadius="12" Padding="12" Margin="0,6,0,0">
          <StackPanel>
            <DockPanel Margin="0,0,0,8">
              <TextBlock x:Name="StatusText" DockPanel.Dock="Right" Foreground="#FFC9C9D4"
                         FontSize="12" Margin="12,0,0,0" VerticalAlignment="Center" Text="En espera."/>
              <ProgressBar x:Name="Prog" Minimum="0" Maximum="100" Value="0"/>
            </DockPanel>
            <ListBox x:Name="LogList" Height="185" Background="#FF0B0B11" BorderBrush="#FF22222C"
                     FontFamily="Consolas" FontSize="12"
                     ScrollViewer.HorizontalScrollBarVisibility="Auto"/>
            <DockPanel Margin="0,8,0,0">
              <TextBlock x:Name="LogPathText" Foreground="#FF55555F" FontSize="11" VerticalAlignment="Center"/>
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="BtnOpenLog" Content="Abrir log forense"/>
                <Button x:Name="BtnOpenLogs" Content="Carpeta de logs"/>
                <Button x:Name="BtnCancel"  Content="Cancelar proceso" Background="#FF4F2A2A" BorderBrush="#FF7B4444" IsEnabled="False"/>
              </StackPanel>
            </DockPanel>
          </StackPanel>
        </Border>
      </Expander>
    </Grid>
  </Grid>
</Window>
'@

# ----------------------- CODE-BEHIND ------------------------
$script:XamlRaw = Convert-XamlTheme $script:XamlRaw
[xml]$xaml = $script:XamlRaw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
# Ajusta la ventana al area de trabajo de la pantalla para que NUNCA se corten
# los botones de abajo en pantallas pequenas o con escalado alto.
try {
    $wa = [System.Windows.SystemParameters]::WorkArea
    if ($window.Height -gt $wa.Height) { $window.Height = [math]::Max(600, $wa.Height - 10) }
    if ($window.Width  -gt $wa.Width)  { $window.Width  = [math]::Max(1000, $wa.Width - 10) }
} catch {}

$bc = New-Object Windows.Media.BrushConverter
$script:Bconv = $bc
# Devuelve un Brush mapeando el color por el tema activo (identidad en Oscuro).
# Sustituye a $bc.ConvertFromString en todo el codigo (C1: tema claro/oscuro).
function Get-ThemeBrush([string]$c) {
    $key = $c
    $m = Get-ThemeMap
    if ($m -and $c -and $c.StartsWith('#')) {
        $u = $c.ToUpper()
        if ($m.ContainsKey($u)) { $key = $m[$u] }
    }
    return $script:Bconv.ConvertFromString($key)
}
# Ciclo de temas: Oscuro -> Claro -> Azul -> Oscuro.
function Get-NextTheme([string]$t) {
    switch ($t) { 'Dark' { return 'Light' } 'Light' { return 'Blue' } default { return 'Dark' } }
}
function Get-ThemeLabel([string]$t) {
    switch ($t) { 'Light' { return 'Claro' } 'Blue' { return 'Azul' } default { return 'Oscuro' } }
}
# ---- Paleta central (GUI-PREMIUM). Acentos por intencion; base para tema claro/oscuro futuro ----
$Theme = @{
    Bg         = '#FF0F0F17'
    Card       = '#FF15151F'
    CardBorder = '#FF2C2C3A'
    Text       = '#FFE6E6EC'
    Sub        = '#FF8A8A95'
    Install    = '#FF3F9EFF'   # azul   - instalar
    Optimize   = '#FF00E5FF'   # cian   - optimizar
    Clean      = '#FFFFD166'   # ambar  - limpiar / aviso
    Danger     = '#FFFF6B6B'   # rojo   - destructivo fuerte
    Maintain   = '#FF5CFF8F'   # verde  - mantener
    Info       = '#FFB388FF'   # violeta - informacion
    Iso        = '#FFFF9E64'   # naranja - creador de ISO (estrella)
}
$panel = $window.FindName('Lists')
$window.FindName('VerText').Text = (('v{0}{1}' -f $WpiVersion, $script:SepText) + (Tr 'motor winget asincrono'))
$window.Title = (('WPI Moderno v{0}  -  ' -f $WpiVersion) + (Tr 'Instalador Post-Windows'))
$script:CboTheme = $window.FindName('CboTheme')
if ($script:CboTheme) {
    foreach ($it in $script:CboTheme.Items) { if ($it -and ($it.Content -is [string])) { $it.Content = Tr ([string]$it.Content) } }
    $script:CboTheme.SelectedIndex = $(switch ($script:ThemeName) { 'Light' { 1 } 'Blue' { 2 } default { 0 } })
    $script:CboTheme.Add_SelectionChanged({
        $new = $(switch ($script:CboTheme.SelectedIndex) { 1 { 'Light' } 2 { 'Blue' } default { 'Dark' } })
        if ($new -eq $script:ThemeName) { return }
        $script:ThemeName = $new
        Save-Settings
        $r = Show-WpiMessage(((Tr 'Tema seleccionado: {0}. Se aplica al reiniciar la app. Reiniciar ahora?') -f (Get-ThemeLabel $new).ToUpper()), 'Apariencia', 'YesNo', 'Question')
        if ($r -eq 'Yes') {
            try { Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) } catch {}
            $script:Skip_Closing_Save = $true
            $window.Close()
        }
    })
}
$script:CboLang = $window.FindName('CboLang')
if ($script:CboLang) {
    $script:CboLang.SelectedIndex = $(if ($script:Lang -eq 'en') { 1 } else { 0 })
    $script:CboLang.Add_SelectionChanged({
        $new = $(if ($script:CboLang.SelectedIndex -eq 1) { 'en' } else { 'es' })
        if ($new -eq $script:Lang) { return }
        $script:Lang = $new
        Save-Settings
        $m = $(if ($new -eq 'en') { 'Language set to English. It applies after restarting the app. Restart now?' } else { 'Idioma cambiado a Espanol. Se aplica al reiniciar la app. Reiniciar ahora?' })
        $r = Show-WpiMessage($m, 'Idioma / Language', 'YesNo', 'Question')
        if ($r -eq 'Yes') {
            try { Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) } catch {}
            $script:Skip_Closing_Save = $true
            $window.Close()
        }
    })
}

$script:LblCount   = $window.FindName('CounterText')
$script:BtnInstall = $window.FindName('BtnInstall')
$script:SideList   = $window.FindName('SideList')
$script:AppsScroll = $window.FindName('AppsScroll')
$script:TweaksScroll = $window.FindName('TweaksScroll')
$script:UpgradesScroll = $window.FindName('UpgradesScroll')
$script:UpgradesList = $window.FindName('UpgradesList')
$script:WingetSearchScroll = $window.FindName('WingetSearchScroll')
$script:WingetSearchList = $window.FindName('WingetSearchList')
$script:DebloatScroll = $window.FindName('DebloatScroll')
$script:DebloatList = $window.FindName('DebloatList')
$script:SnapshotScroll = $window.FindName('SnapshotScroll')
$script:SnapshotList = $window.FindName('SnapshotList')
$script:GuidesScroll = $window.FindName('GuidesScroll')
$script:GuidesList = $window.FindName('GuidesList')
$script:DriversScroll = $window.FindName('DriversScroll')
$script:DriversList = $window.FindName('DriversList')
$script:WinUpdateScroll = $window.FindName('WinUpdateScroll')
$script:WinUpdateList = $window.FindName('WinUpdateList')
$script:RepairScroll = $window.FindName('RepairScroll')
$script:RepairList = $window.FindName('RepairList')
$script:SummaryScroll = $window.FindName('SummaryScroll')
$script:SummaryList = $window.FindName('SummaryList')
$script:FeaturesScroll = $window.FindName('FeaturesScroll')
$script:FeaturesList = $window.FindName('FeaturesList')
$script:CreateIsoScroll = $window.FindName('CreateIsoScroll')
$script:CreateIsoList = $window.FindName('CreateIsoList')
$script:LogViewerScroll = $window.FindName('LogViewerScroll')
$script:LogViewerList = $window.FindName('LogViewerList')
$script:QuickStartScroll = $window.FindName('QuickStartScroll')
$script:QuickStartList = $window.FindName('QuickStartList')
$script:FindAllScroll = $window.FindName('FindAllScroll')
$script:FindAllList = $window.FindName('FindAllList')
$script:LogList    = $window.FindName('LogList')
$script:Prog       = $window.FindName('Prog')
$script:StatusText = $window.FindName('StatusText')
$script:LogExpander= $window.FindName('LogExpander')
$script:BtnCancel  = $window.FindName('BtnCancel')
$script:LogPathTxt = $window.FindName('LogPathText')
$script:Checks = @()
$script:Cards  = @()
$script:TweakChecks = @()

function Update-Count {
    $n = @($script:Checks | Where-Object { $_.IsChecked }).Count
    $script:LblCount.Text = (Tr 'Seleccionadas:') + (' {0}' -f $n)
    $script:BtnInstall.Content = ((Tr 'INSTALAR') + (' ({0})' -f $n))
}

# Contador del boton "APLICAR SELECCIONADOS" de Tweaks (mismo patron que Update-Count)
function Update-TweakCount {
    if (-not $script:TweakChecks) { return }
    $n = @($script:TweakChecks | Where-Object { $_.IsChecked }).Count
    if ($script:BtnTweaks) { $script:BtnTweaks.Content = ((Tr 'APLICAR SELECCIONADOS') + (' ({0})' -f $n)) }
}

# ---- Marcado visual de apps ya instaladas (texto en verde) ----
function Mark-One($cb) {
    $cb.Foreground = Get-ThemeBrush('#FF5CFF8F')
    $cb.ToolTip = ((Tr '{0}   ·   YA INSTALADA') -f $cb.Tag)
}
function Mark-Installed([string[]]$ids) {
    if (-not $ids -or $ids.Count -eq 0) {
        $script:StatusText.Text = (Tr 'Deteccion: ninguna app del catalogo esta instalada todavia.')
        return
    }
    $set = @{}
    foreach ($i in $ids) { $set[$i.ToLower()] = $true }
    $n = 0
    foreach ($cb in $script:Checks) {
        if ($set[([string]$cb.Tag).ToLower()]) { Mark-One $cb; $n++ }
    }
    $script:StatusText.Text = ((Tr 'Deteccion: {0} apps del catalogo ya instaladas (nombre en verde).') -f $n)
}

# ---- Construccion de tarjetas de categorias ----
$cats = $catalog | ForEach-Object { $_.Cat } | Select-Object -Unique
foreach ($cat in $cats) {
    $card = New-Object Windows.Controls.Border
    $card.Background      = Get-ThemeBrush('#FF15151F')
    $card.BorderBrush     = Get-ThemeBrush('#FF2C2C3A')
    $card.BorderThickness = New-Object Windows.Thickness(1)
    $card.CornerRadius    = New-Object Windows.CornerRadius(13)
    $card.Margin          = New-Object Windows.Thickness(0,10,0,0)
    $card.Padding         = New-Object Windows.Thickness(15,11,15,13)

    $inner = New-Object Windows.Controls.StackPanel
    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = ('{0}  ({1})' -f (Tr $cat).ToUpper(), @($catalog | Where-Object { $_.Cat -eq $cat }).Count)
    $hdr.FontSize = 14
    $hdr.FontWeight = 'Bold'
    $hdr.Foreground = Get-ThemeBrush($Theme.Optimize)
    $exp = New-Object Windows.Controls.Expander
    $exp.IsExpanded = $true
    $exp.Header = $hdr
    $inner.Children.Add($exp) | Out-Null

    $cardChecks = @()
    # Constructor de checkbox de app (reutilizable para vista normal y agrupada por marca)
    $mkcb = {
        param($app)
        $cb = New-Object Windows.Controls.CheckBox
        $hasGuide = $Guides.Contains([string]$app.Id)
        $cb.Content = if ($hasGuide) { $app.Name + '  (i)' } else { $app.Name }
        $cb.Tag = $app.Id
        if ($script:Lang -eq 'en') {
            $cb.ToolTip = if ($hasGuide) { ('{0} - winget ID: {1}. Includes a guide; right-click to open it.' -f $app.Name, $app.Id) } else { ('{0} - winget ID: {1}. Check it to include it in the selected action.' -f $app.Name, $app.Id) }
        } else {
            $cb.ToolTip = if ($hasGuide) { ('{0} - ID winget: {1}. Tiene guia; clic derecho para abrirla.' -f $app.Name, $app.Id) } else { ('{0} - ID winget: {1}. Marcala para incluirla en la accion seleccionada.' -f $app.Name, $app.Id) }
        }
        $cb.Add_Checked({ Update-Count })
        $cb.Add_Unchecked({ Update-Count })
        if ($hasGuide) {
            $cm = New-Object Windows.Controls.ContextMenu
            $mi = New-Object Windows.Controls.MenuItem
            $mi.Header = (Tr 'Ver guia en espanol')
            $mi.Tag = [string]$app.Id
            $mi.Add_Click({ Show-Guide ([string]$this.Tag) })
            [void]$cm.Items.Add($mi)
            $cb.ContextMenu = $cm
        }
        $script:Checks += $cb
        return $cb
    }
    $catItems = @($catalog | Where-Object { $_.Cat -eq $cat })
    $hasSub = (@($catItems | Where-Object { $_.Sub }).Count -gt 0)
    if ($hasSub) {
        # Agrupado por marca/subcategoria: una subcabecera + su rejilla por cada Sub
        $subStack = New-Object Windows.Controls.StackPanel
        foreach ($sname in (@($catItems | ForEach-Object { [string]$_.Sub } | Select-Object -Unique))) {
            $sh = New-Object Windows.Controls.TextBlock
            $sh.Text = (Tr $sname)
            $sh.FontSize = 11.5; $sh.FontWeight = 'Bold'
            $sh.Foreground = Get-ThemeBrush($Theme.Iso)
            $sh.Margin = New-Object Windows.Thickness(2,9,0,3)
            $subStack.Children.Add($sh) | Out-Null
            $w2 = New-Object Windows.Controls.WrapPanel
            foreach ($app in ($catItems | Where-Object { [string]$_.Sub -eq $sname })) {
                $cb = & $mkcb $app
                $w2.Children.Add($cb) | Out-Null
                $cardChecks += $cb
            }
            $subStack.Children.Add($w2) | Out-Null
        }
        $exp.Content = $subStack
    } else {
        $wrap = New-Object Windows.Controls.WrapPanel
        foreach ($app in $catItems) {
            $cb = & $mkcb $app
            $wrap.Children.Add($cb) | Out-Null
            $cardChecks += $cb
        }
        $exp.Content = $wrap
    }
    $card.Child = $inner
    $panel.Children.Add($card) | Out-Null
    $script:Cards += [pscustomobject]@{ Cat = $cat; Card = $card; Checks = $cardChecks; Exp = $exp }
}

# ---- A4: Contexto del equipo (solo lectura) y set recomendado segun hardware ----
function Get-WpiContext {
    $ctx = @{ IsLaptop = $false; IsSSD = $false; RamGB = 0; Edition = ''; Gpu = '' }
    try {
        $batt = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        $isLap = ($batt.Count -gt 0)
        try {
            $ench = @(Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue)
            foreach ($e in $ench) { foreach ($c in @($e.ChassisTypes)) { if (@(8,9,10,11,12,14,18,21,30,31,32) -contains [int]$c) { $isLap = $true } } }
        } catch {}
        $ctx.IsLaptop = $isLap
    } catch {}
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $ctx.Edition = [string]$os.Caption
            if ($os.TotalVisibleMemorySize -gt 0) { $ctx.RamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 0) }
        }
    } catch {}
    try {
        $pd = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
        if (@($pd | Where-Object { [string]$_.MediaType -eq 'SSD' }).Count -gt 0) { $ctx.IsSSD = $true }
    } catch {}
    try {
        $vn = ''
        foreach ($g in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
            $nm = [string]$g.Name
            if ($nm -match 'NVIDIA') { $vn = 'NVIDIA' }
            elseif (($nm -match 'AMD' -or $nm -match 'Radeon') -and $vn -eq '') { $vn = 'AMD' }
            elseif ($nm -match 'Intel' -and $vn -eq '') { $vn = 'Intel' }
        }
        $ctx.Gpu = $vn
    } catch {}
    return $ctx
}

# Devuelve el set de tweaks recomendado para ESTE equipo (nombres a marcar) y los
# excluidos por el contexto. Base: tweaks 'Seguro' (sin acciones puntuales).
function Get-RecommendedTweaks {
    param($Ctx)
    $names = @{}
    foreach ($t in $TweaksCatalog) {
        if ([string]$t.Risk -ne 'Seguro') { continue }
        $n = [string]$t.Name
        if ($n -like 'Crear punto de restauracion*' -or $n -like 'Limpieza profunda*') { continue }
        $names[$n] = $true
    }
    $excl = @()
    if ($Ctx.IsLaptop) {
        foreach ($x in @('Desactivar hibernacion (libera hiberfil.sys)', 'Plan de energia Maximo Rendimiento')) {
            if ($names.ContainsKey($x)) { [void]$names.Remove($x); $excl += $x }
        }
    }
    return @{ Names = $names; Excluded = $excl }
}

# ---- Construccion del panel de Tweaks (v2: categorias, riesgo, revertir) ----
$tw = $window.FindName('TweaksList')
$twHdr = New-Object Windows.Controls.TextBlock
$twHdr.Text = 'TWEAKS Y AJUSTES (se aplican solo los marcados; casi todos reversibles)'
$twHdr.FontSize = 14; $twHdr.FontWeight = 'Bold'
$twHdr.Foreground = Get-ThemeBrush('#FF7C4DFF')
$twHdr.Margin = New-Object Windows.Thickness(2,10,0,2)
$tw.Children.Add($twHdr) | Out-Null

$twInfo = New-Object Windows.Controls.TextBlock
$twInfo.Text = 'Marca los ajustes y pulsa APLICAR. Los marcados en ambar son "avanzados" (mayor impacto). REVERTIR deshace los que tengan vuelta atras. Antes de aplicar se crea un punto de restauracion si dejas la casilla activada.'
$twInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$twInfo.FontSize = 12; $twInfo.TextWrapping = 'Wrap'
$twInfo.Margin = New-Object Windows.Thickness(2,0,0,8)
$tw.Children.Add($twInfo) | Out-Null

$script:ChkRestore = New-Object Windows.Controls.CheckBox
$script:ChkRestore.Content = 'Crear un punto de restauracion antes de aplicar (recomendado)'
$script:ChkRestore.IsChecked = $true
$script:ChkRestore.Margin = New-Object Windows.Thickness(2,0,0,6)
$tw.Children.Add($script:ChkRestore) | Out-Null

# ---- Presets graduados de tweaks (de mas seguro a mas agresivo) ----
# Estilo "recomendaciones de Chris Titus" pero mejor: 3 niveles por riesgo real,
# con color (verde/ambar/rojo) y conteo. No aplican nada: solo MARCAN la seleccion.
function Set-TweakPreset([string]$level) {
    $n = 0
    foreach ($cb in $script:TweakChecks) {
        $t = $cb.Tag
        $risk = [string]$t.Risk
        $cav  = [bool]$t.Caveat
        $sel = switch ($level) {
            'seguro'      { $risk -eq 'Seguro' }
            'equilibrado' { ($risk -eq 'Seguro') -or (($risk -eq 'Avanzado') -and (-not $cav)) }
            'agresivo'    { $true }
            default       { $false }
        }
        $cb.IsChecked = [bool]$sel
        if ($sel) { $n++ }
    }
    try { Update-Count } catch {}
    $lbl = switch ($level) { 'seguro' { 'Seguro' } 'equilibrado' { 'Equilibrado' } 'agresivo' { 'Agresivo' } default { '' } }
    try { $script:TweakSummary.Text = ((Tr 'Preset {0}: marcados {1} ajustes. Revisa la seleccion y pulsa APLICAR SELECCIONADOS.') -f (Tr $lbl), $n) } catch {}
}

$twPreLbl = New-Object Windows.Controls.TextBlock
$twPreLbl.Text = 'Presets (de mas seguro a mas agresivo):'
$twPreLbl.Foreground = Get-ThemeBrush('#FF8A8A95'); $twPreLbl.FontSize = 12; $twPreLbl.FontWeight = 'Bold'
$twPreLbl.Margin = New-Object Windows.Thickness(2,6,0,2)
$tw.Children.Add($twPreLbl) | Out-Null

$twPreRow = New-Object Windows.Controls.StackPanel
$twPreRow.Orientation = 'Horizontal'
$twPreRow.Margin = New-Object Windows.Thickness(2,0,0,4)

$btnPSafe = New-Object Windows.Controls.Button
$btnPSafe.Content = 'Seguro'; $btnPSafe.FontWeight = 'Bold'
$btnPSafe.Margin = New-Object Windows.Thickness(0,0,8,0); $btnPSafe.Padding = New-Object Windows.Thickness(14,5,14,5)
$btnPSafe.Background = Get-ThemeBrush('#FF153026'); $btnPSafe.BorderBrush = Get-ThemeBrush('#FF5CFF8F'); $btnPSafe.Foreground = Get-ThemeBrush('#FF5CFF8F')
$btnPSafe.ToolTip = 'Marca solo los ajustes de bajo riesgo, reversibles y recomendados para cualquier PC.'
$btnPSafe.Add_Click({ Set-TweakPreset 'seguro' })
$twPreRow.Children.Add($btnPSafe) | Out-Null

$btnPBal = New-Object Windows.Controls.Button
$btnPBal.Content = 'Equilibrado'; $btnPBal.FontWeight = 'Bold'
$btnPBal.Margin = New-Object Windows.Thickness(0,0,8,0); $btnPBal.Padding = New-Object Windows.Thickness(14,5,14,5)
$btnPBal.Background = Get-ThemeBrush('#FF332B12'); $btnPBal.BorderBrush = Get-ThemeBrush('#FFFFD166'); $btnPBal.Foreground = Get-ThemeBrush('#FFFFD166')
$btnPBal.ToolTip = 'Marca los seguros + avanzados de uso general (sin advertencias de hardware). Buen equilibrio rendimiento/seguridad.'
$btnPBal.Add_Click({ Set-TweakPreset 'equilibrado' })
$twPreRow.Children.Add($btnPBal) | Out-Null

$btnPAggr = New-Object Windows.Controls.Button
$btnPAggr.Content = 'Agresivo'; $btnPAggr.FontWeight = 'Bold'
$btnPAggr.Margin = New-Object Windows.Thickness(0,0,8,0); $btnPAggr.Padding = New-Object Windows.Thickness(14,5,14,5)
$btnPAggr.Background = Get-ThemeBrush('#FF3A1B1B'); $btnPAggr.BorderBrush = Get-ThemeBrush('#FFFF6B6B'); $btnPAggr.Foreground = Get-ThemeBrush('#FFFF8A8A')
$btnPAggr.ToolTip = 'Marca TODOS los ajustes, incluidos los avanzados mas fuertes. Maximo impacto: revisa antes de aplicar.'
$btnPAggr.Add_Click({ Set-TweakPreset 'agresivo' })
$twPreRow.Children.Add($btnPAggr) | Out-Null

$btnPNone = New-Object Windows.Controls.Button
$btnPNone.Content = 'Ninguno'
$btnPNone.Margin = New-Object Windows.Thickness(0,0,8,0); $btnPNone.Padding = New-Object Windows.Thickness(14,5,14,5)
$btnPNone.ToolTip = 'Quita todas las marcas.'
$btnPNone.Add_Click({ foreach ($cb in $script:TweakChecks) { $cb.IsChecked = $false }; try { Update-Count } catch {} })
$twPreRow.Children.Add($btnPNone) | Out-Null

$tw.Children.Add($twPreRow) | Out-Null

$script:TweakStatusLabels = @{}
$script:TweakDetected = $false

# --- Buscador en vivo de tweaks (filtra al instante por nombre/descripcion) ---
$script:TweakSearchCats = @()
$twSearchBorder = New-Object Windows.Controls.Border
$twSearchBorder.Background = Get-ThemeBrush('#FF12121A')
$twSearchBorder.BorderBrush = Get-ThemeBrush('#FF3A3A4A')
$twSearchBorder.BorderThickness = New-Object Windows.Thickness(1)
$twSearchBorder.CornerRadius = New-Object Windows.CornerRadius(8)
$twSearchBorder.Margin = New-Object Windows.Thickness(2,6,6,6)
$twSearchGrid = New-Object Windows.Controls.Grid
$script:TwSearchBox = New-Object Windows.Controls.TextBox
$script:TwSearchBox.Background = [Windows.Media.Brushes]::Transparent
$script:TwSearchBox.BorderThickness = New-Object Windows.Thickness(0)
$script:TwSearchBox.Foreground = Get-ThemeBrush($Theme.Text)
$script:TwSearchBox.Padding = New-Object Windows.Thickness(10,6,10,6)
$script:TwSearchBox.FontSize = 13
$script:TwSearchBox.CaretBrush = Get-ThemeBrush('#FF00E5FF')
$script:TwSearchHint = New-Object Windows.Controls.TextBlock
$script:TwSearchHint.Text = (Tr 'Buscar tweak por nombre o descripcion...')
$script:TwSearchHint.Foreground = Get-ThemeBrush('#FF6A6A78')
$script:TwSearchHint.FontSize = 13
$script:TwSearchHint.IsHitTestVisible = $false
$script:TwSearchHint.VerticalAlignment = 'Center'
$script:TwSearchHint.Margin = New-Object Windows.Thickness(11,0,0,0)
$twSearchGrid.Children.Add($script:TwSearchBox) | Out-Null
$twSearchGrid.Children.Add($script:TwSearchHint) | Out-Null
$twSearchBorder.Child = $twSearchGrid
$tw.Children.Add($twSearchBorder) | Out-Null
$script:TwSearchBox.Add_TextChanged({
    $q = ([string]$script:TwSearchBox.Text).Trim().ToLower()
    $script:TwSearchHint.Visibility = $(if ($q) { 'Collapsed' } else { 'Visible' })
    foreach ($cat in $script:TweakSearchCats) {
        $any = $false
        foreach ($c in $cat.Cards) {
            $m = (($q -eq '') -or ($c.Text.Contains($q)))
            $c.El.Visibility = $(if ($m) { 'Visible' } else { 'Collapsed' })
            if ($m) { $any = $true }
        }
        $cat.Header.Visibility = $(if ($any) { 'Visible' } else { 'Collapsed' })
    }
})

# --- Rejilla de 2 columnas con balanceo automatico (estilo masonry) ---
$twGrid = New-Object Windows.Controls.Grid
$twGrid.Margin = New-Object Windows.Thickness(0,2,0,0)
$twColDef0 = New-Object Windows.Controls.ColumnDefinition; $twColDef0.Width = New-Object Windows.GridLength(1, ([Windows.GridUnitType]::Star))
$twColDef1 = New-Object Windows.Controls.ColumnDefinition; $twColDef1.Width = New-Object Windows.GridLength(1, ([Windows.GridUnitType]::Star))
$twGrid.ColumnDefinitions.Add($twColDef0); $twGrid.ColumnDefinitions.Add($twColDef1)
$twColL = New-Object Windows.Controls.StackPanel; $twColL.Margin = New-Object Windows.Thickness(2,0,7,0)
$twColR = New-Object Windows.Controls.StackPanel; $twColR.Margin = New-Object Windows.Thickness(7,0,6,0)
[Windows.Controls.Grid]::SetColumn($twColL, 0); [Windows.Controls.Grid]::SetColumn($twColR, 1)
$twGrid.Children.Add($twColL) | Out-Null; $twGrid.Children.Add($twColR) | Out-Null

$twHL = 0.0; $twHR = 0.0
$twCats = $TweaksCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
foreach ($tcat in $twCats) {
    $catTweaks = @($TweaksCatalog | Where-Object { $_.Cat -eq $tcat })
    $w = 0.9
    foreach ($t in $catTweaks) { $w += 1.0; if ($t.Caveat) { $w += 0.4 } }
    if ($twHL -le $twHR) { $col = $twColL; $twHL += $w } else { $col = $twColR; $twHR += $w }

    $tch = New-Object Windows.Controls.TextBlock
    $tch.Text = (Tr ([string]$tcat)).ToUpper() + ('   (' + $catTweaks.Count + ')')
    $tch.FontSize = 12.5; $tch.FontWeight = 'Bold'
    $tch.Foreground = Get-ThemeBrush('#FF00E5FF')
    $tch.Margin = New-Object Windows.Thickness(2,11,0,3)
    $col.Children.Add($tch) | Out-Null

    $catCardRefs = @()
    foreach ($t in $catTweaks) {
        $adv = ($t.Risk -eq 'Avanzado')
        # Fila plana de UNA linea: punto de estado + checkbox (info en el tooltip).
        $row = New-Object Windows.Controls.StackPanel
        $row.Orientation = 'Horizontal'
        $row.Margin = New-Object Windows.Thickness(2,2,0,2)
        $dot = New-Object Windows.Controls.TextBlock
        $dot.Text = [string][char]0x25CF
        $dot.FontSize = 13
        $dot.Foreground = Get-ThemeBrush('#FF4A4A56')
        $dot.VerticalAlignment = 'Center'
        $dot.Margin = New-Object Windows.Thickness(0,0,7,0)
        $dot.ToolTip = (Tr 'estado: sin comprobar')
        $script:TweakStatusLabels[[string]$t.Name] = $dot
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Content = $(if ($adv) { (Tr ([string]$t.Name)) + '   ' + (Tr '[avanzado]') } else { (Tr ([string]$t.Name)) })
        $cb.FontSize = 13
        $cb.VerticalAlignment = 'Center'
        $cb.Tag = $t
        $cb.Add_Checked({ try { Update-TweakCount } catch {} }); $cb.Add_Unchecked({ try { Update-TweakCount } catch {} })
        if ($adv) { $cb.Foreground = Get-ThemeBrush('#FFFFD166') }
        $rev = $(if ($t.Undo) { '' } else { '  (sin reversion)' })
        $tip = (Tr ([string]$t.Desc)) + (Tr $rev)
        if ($t.Caveat) { $tip += ("`n" + (Tr 'Evitalo si:') + ' ' + (Tr ([string]$t.Caveat))) }
        $cb.ToolTip = $tip
        $row.Children.Add($dot) | Out-Null
        $row.Children.Add($cb)  | Out-Null
        $col.Children.Add($row) | Out-Null
        $script:TweakChecks += $cb
        $catCardRefs += @{ El = $row; Text = ((([string]$t.Name) + ' ' + ([string]$t.Desc)).ToLower()) }
    }
    $script:TweakSearchCats += @{ Header = $tch; Cards = $catCardRefs }
}
$tw.Children.Add($twGrid) | Out-Null

# Banner breve de estado JUSTO ENCIMA de los botones: "X aplicados / Y sin aplicar"
# con colores (verde = ya aplicado en este PC). Se rellena en Detect-TweakStates.
$script:TweakStatusBanner = New-Object Windows.Controls.Border
$script:TweakStatusBanner.Background = Get-ThemeBrush('#FF15202A')
$script:TweakStatusBanner.BorderBrush = Get-ThemeBrush('#FF2C4A57')
$script:TweakStatusBanner.BorderThickness = New-Object Windows.Thickness(1)
$script:TweakStatusBanner.CornerRadius = New-Object Windows.CornerRadius(7)
$script:TweakStatusBanner.Padding = New-Object Windows.Thickness(11,6,11,6)
$script:TweakStatusBanner.Margin = New-Object Windows.Thickness(2,12,0,2)
$script:TweakStatusBanner.HorizontalAlignment = 'Left'
$script:TweakStatusInline = New-Object Windows.Controls.TextBlock
$script:TweakStatusInline.FontSize = 12.5
$script:TweakStatusInline.TextWrapping = 'Wrap'
$script:TweakStatusInline.Foreground = Get-ThemeBrush('#FF76E0FF')
$script:TweakStatusInline.Text = (Tr 'Detectando que ajustes ya tienes aplicados...')
$script:TweakStatusBanner.Child = $script:TweakStatusInline
$tw.Children.Add($script:TweakStatusBanner) | Out-Null

$twBtnRow = New-Object Windows.Controls.StackPanel
$twBtnRow.Orientation = 'Horizontal'
$twBtnRow.Margin = New-Object Windows.Thickness(0,8,0,4)
$twBtn = New-Object Windows.Controls.Button
$twBtn.Content = 'APLICAR SELECCIONADOS'
$twBtn.FontWeight = 'Bold'
$twBtn.Background  = Get-ThemeBrush('#FF3A2A6E')
$twBtn.BorderBrush = Get-ThemeBrush('#FF7C4DFF')
$twBtnRow.Children.Add($twBtn) | Out-Null
$script:BtnTweaksUndo = New-Object Windows.Controls.Button
$script:BtnTweaksUndo.Content = 'REVERTIR SELECCIONADOS'
$script:BtnTweaksUndo.Background  = Get-ThemeBrush('#FF4F2A2A')
$script:BtnTweaksUndo.BorderBrush = Get-ThemeBrush('#FF7B4444')
$twBtnRow.Children.Add($script:BtnTweaksUndo) | Out-Null
$script:BtnTweakDetect = New-Object Windows.Controls.Button
$script:BtnTweakDetect.Content = 'Re-detectar estado'
$script:BtnTweakDetect.Background  = Get-ThemeBrush('#FF13414F')
$script:BtnTweakDetect.BorderBrush = Get-ThemeBrush('#FF76E0FF')
$twBtnRow.Children.Add($script:BtnTweakDetect) | Out-Null
$script:BtnTweakMissing = New-Object Windows.Controls.Button
$script:BtnTweakMissing.Content = 'Marcar lo recomendado que falta'
$twBtnRow.Children.Add($script:BtnTweakMissing) | Out-Null
$script:BtnTweakReco = New-Object Windows.Controls.Button
$script:BtnTweakReco.Content = 'Aplicar recomendado para MI equipo'
$script:BtnTweakReco.Background  = Get-ThemeBrush('#FF13414F')
$script:BtnTweakReco.BorderBrush = Get-ThemeBrush('#FF76E0FF')
$script:BtnTweakReco.Add_Click({
    $ctx = Get-WpiContext
    $reco = Get-RecommendedTweaks $ctx
    $n = 0
    foreach ($cb in $script:TweakChecks) {
        $name = [string]$cb.Tag.Name
        if ($reco.Names.ContainsKey($name)) { $cb.IsChecked = $true; $n++ } else { $cb.IsChecked = $false }
    }
    try { Update-Count } catch {}
    $tipo  = $(if ($ctx.IsLaptop) { 'portatil' } else { 'sobremesa' })
    $disco = $(if ($ctx.IsSSD) { 'SSD' } else { 'disco no-SSD' })
    $gpu   = $(if ($ctx.Gpu -ne '') { $ctx.Gpu } else { 'GPU n/d' })
    $frase = ('Detectado: {0} con {1}, {2} GB de RAM y {3}.' -f $tipo, $disco, $ctx.RamGB, $gpu)
    $script:TweakSummary.Text = ((Tr '{0}  Marcados {1} ajustes recomendados para tu equipo (revisa y pulsa APLICAR SELECCIONADOS).') -f $frase, $n)
    $exclTxt = $(if (@($reco.Excluded).Count -gt 0) { ("`n`nExcluidos por tu equipo:`n - " + ((@($reco.Excluded)) -join "`n - ")) } else { '' })
    Show-WpiMessage(((Tr "{0}`n`nMarcados {1} tweaks recomendados. NO se ha aplicado nada: revisa la seleccion y pulsa APLICAR SELECCIONADOS.{2}") -f $frase, $n, $exclTxt), 'Recomendado para mi equipo', 'OK', 'Information') | Out-Null
})
$twBtnRow.Children.Add($script:BtnTweakReco) | Out-Null
$script:BtnTweakSave = New-Object Windows.Controls.Button
$script:BtnTweakSave.Content = 'Guardar perfil'
$twBtnRow.Children.Add($script:BtnTweakSave) | Out-Null
$script:BtnTweakLoad = New-Object Windows.Controls.Button
$script:BtnTweakLoad.Content = 'Cargar perfil'
$twBtnRow.Children.Add($script:BtnTweakLoad) | Out-Null
$tw.Children.Add($twBtnRow) | Out-Null
$script:TweakSummary = New-Object Windows.Controls.TextBlock
$script:TweakSummary.Text = 'Estado: pulsa "Re-detectar estado" o entra a esta seccion para escanear que ajustes ya estan aplicados.'
$script:TweakSummary.Foreground = Get-ThemeBrush('#FF76E0FF')
$script:TweakSummary.FontSize = 12
$script:TweakSummary.TextWrapping = 'Wrap'
$script:TweakSummary.Margin = New-Object Windows.Thickness(2,8,0,0)
$tw.Children.Add($script:TweakSummary) | Out-Null
$script:BtnTweaks = $twBtn

# ---- Construccion del panel de Actualizaciones (dos grupos) ----
# Conjunto de IDs del catalogo WPI (en minusculas) para clasificar
$script:CatIdSet = @{}
foreach ($a in $catalog) { $script:CatIdSet[([string]$a.Id).ToLower()] = $true }

$script:UpgChecksWpi   = @()
$script:UpgChecksOther = @()
$ug = $script:UpgradesList

$ugHdr = New-Object Windows.Controls.TextBlock
$ugHdr.Text = 'ACTUALIZACIONES DISPONIBLES'
$ugHdr.FontSize = 14; $ugHdr.FontWeight = 'Bold'
$ugHdr.Foreground = Get-ThemeBrush('#FF3F9EFF')
$ugHdr.Margin = New-Object Windows.Thickness(2,10,0,2)
$ug.Children.Add($ugHdr) | Out-Null

$ugInfo = New-Object Windows.Controls.TextBlock
$ugInfo.Text = (Tr 'Pulsa "Buscar updates" (el boton de aqui arriba, o en la barra inferior) para escanear. Los resultados se separan en dos grupos para no mezclar nada. Cada boton actualiza SOLO su grupo. Nota: winget no guarda copias propias aparte; en ambos casos se actualizan programas instalados en tu equipo. La ventaja es que el Grupo 1 nunca toca nada que no sea del catalogo WPI.')
$ugInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$ugInfo.FontSize = 12; $ugInfo.TextWrapping = 'Wrap'
$ugInfo.Margin = New-Object Windows.Thickness(2,0,0,8)
$ug.Children.Add($ugInfo) | Out-Null

# Boton de escaneo DENTRO de la propia seccion (visible nada mas entrar). Hace lo
# mismo que "Buscar updates" de la barra inferior; este se mantiene tambien abajo.
$script:BtnUpgScan = New-Object Windows.Controls.Button
$script:BtnUpgScan.Content = (Tr 'Buscar updates ahora')
$script:BtnUpgScan.FontWeight = 'Bold'
$script:BtnUpgScan.Background  = Get-ThemeBrush('#FF134B52')
$script:BtnUpgScan.BorderBrush = Get-ThemeBrush('#FF00E5FF')
$script:BtnUpgScan.Foreground  = Get-ThemeBrush('#FFEAF6FF')
$script:BtnUpgScan.Margin  = New-Object Windows.Thickness(2,0,0,10)
$script:BtnUpgScan.Padding = New-Object Windows.Thickness(16,7,16,7)
$script:BtnUpgScan.HorizontalAlignment = 'Left'
$script:BtnUpgScan.Add_Click({ Start-Worker -Mode 'scanupgrades' })
$ug.Children.Add($script:BtnUpgScan) | Out-Null

$script:UpgEmpty = New-Object Windows.Controls.TextBlock
$script:UpgEmpty.Text = (Tr 'Aun no has escaneado. Pulsa "Buscar updates" (el boton azul de aqui arriba) para empezar.')
$script:UpgEmpty.Foreground = Get-ThemeBrush('#FF6F6F7A')
$script:UpgEmpty.FontStyle = 'Italic'; $script:UpgEmpty.Margin = New-Object Windows.Thickness(2,6,0,10)
$ug.Children.Add($script:UpgEmpty) | Out-Null

# ----- GRUPO 1: apps del catalogo WPI -----
$script:WpiHdr = New-Object Windows.Controls.TextBlock
$script:WpiHdr.FontSize = 13; $script:WpiHdr.FontWeight = 'Bold'
$script:WpiHdr.Foreground = Get-ThemeBrush('#FF00E5FF')
$script:WpiHdr.Margin = New-Object Windows.Thickness(2,4,0,2)
$script:WpiHdr.Text = (Tr 'GRUPO 1 - Apps del catalogo WPI')
$script:WpiHdr.Visibility = 'Collapsed'
$ug.Children.Add($script:WpiHdr) | Out-Null
$script:WpiSelRow = New-Object Windows.Controls.StackPanel
$script:WpiSelRow.Orientation = 'Horizontal'
$script:WpiSelRow.Visibility = 'Collapsed'
$bWpiAll = New-Object Windows.Controls.Button; $bWpiAll.Content = 'Marcar todas'
$bWpiNon = New-Object Windows.Controls.Button; $bWpiNon.Content = 'Ninguna'
$bWpiAll.Add_Click({ foreach ($c in $script:UpgChecksWpi) { $c.IsChecked = $true };  Update-UpgCount })
$bWpiNon.Add_Click({ foreach ($c in $script:UpgChecksWpi) { $c.IsChecked = $false }; Update-UpgCount })
$script:WpiSelRow.Children.Add($bWpiAll) | Out-Null
$script:WpiSelRow.Children.Add($bWpiNon) | Out-Null
$ug.Children.Add($script:WpiSelRow) | Out-Null
$script:UpgRowsWpi = New-Object Windows.Controls.StackPanel
$ug.Children.Add($script:UpgRowsWpi) | Out-Null
$script:BtnUpgWpi = New-Object Windows.Controls.Button
$script:BtnUpgWpi.Content = ((Tr 'ACTUALIZAR APPS DEL CATALOGO WPI ({0})') -f 0)
$script:BtnUpgWpi.FontWeight = 'Bold'
$script:BtnUpgWpi.Background  = Get-ThemeBrush('#FF134B52')
$script:BtnUpgWpi.BorderBrush = Get-ThemeBrush('#FF00E5FF')
$script:BtnUpgWpi.Margin = New-Object Windows.Thickness(0,10,0,4)
$script:BtnUpgWpi.HorizontalAlignment = 'Left'
$script:BtnUpgWpi.IsEnabled = $false
$ug.Children.Add($script:BtnUpgWpi) | Out-Null

# ----- GRUPO 2: otros programas del PC -----
$script:OthHdr = New-Object Windows.Controls.TextBlock
$script:OthHdr.FontSize = 13; $script:OthHdr.FontWeight = 'Bold'
$script:OthHdr.Foreground = Get-ThemeBrush('#FFFFD166')
$script:OthHdr.Margin = New-Object Windows.Thickness(2,16,0,2)
$script:OthHdr.Text = (Tr 'GRUPO 2 - Otros programas de TU PC')
$script:OthHdr.Visibility = 'Collapsed'
$ug.Children.Add($script:OthHdr) | Out-Null
$script:OthInfo = New-Object Windows.Controls.TextBlock
$script:OthInfo.Text = 'Programas que winget ha detectado instalados en tu PC y NO estan en el catalogo WPI (los instalaste tu a mano, la Store, etc.). Tu decides si tocar algo aqui.'
$script:OthInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$script:OthInfo.FontSize = 11.5; $script:OthInfo.TextWrapping = 'Wrap'
$script:OthInfo.Margin = New-Object Windows.Thickness(2,0,0,2)
$script:OthInfo.Visibility = 'Collapsed'
$ug.Children.Add($script:OthInfo) | Out-Null
$script:OthSelRow = New-Object Windows.Controls.StackPanel
$script:OthSelRow.Orientation = 'Horizontal'
$script:OthSelRow.Visibility = 'Collapsed'
$bOthAll = New-Object Windows.Controls.Button; $bOthAll.Content = 'Marcar todos'
$bOthNon = New-Object Windows.Controls.Button; $bOthNon.Content = 'Ninguno'
$bOthAll.Add_Click({ foreach ($c in $script:UpgChecksOther) { $c.IsChecked = $true };  Update-UpgCount })
$bOthNon.Add_Click({ foreach ($c in $script:UpgChecksOther) { $c.IsChecked = $false }; Update-UpgCount })
$script:OthSelRow.Children.Add($bOthAll) | Out-Null
$script:OthSelRow.Children.Add($bOthNon) | Out-Null
$ug.Children.Add($script:OthSelRow) | Out-Null
$script:UpgRowsOther = New-Object Windows.Controls.StackPanel
$ug.Children.Add($script:UpgRowsOther) | Out-Null
$script:BtnUpgOther = New-Object Windows.Controls.Button
$script:BtnUpgOther.Content = ((Tr 'ACTUALIZAR OTROS PROGRAMAS DE MI PC ({0})') -f 0)
$script:BtnUpgOther.FontWeight = 'Bold'
$script:BtnUpgOther.Background  = Get-ThemeBrush('#FF55471A')
$script:BtnUpgOther.BorderBrush = Get-ThemeBrush('#FFFFD166')
$script:BtnUpgOther.Margin = New-Object Windows.Thickness(0,10,0,4)
$script:BtnUpgOther.HorizontalAlignment = 'Left'
$script:BtnUpgOther.IsEnabled = $false
$ug.Children.Add($script:BtnUpgOther) | Out-Null

function Set-UpgSidebarCount([int]$n) {
    $i = $script:SideMap.IndexOf('@UPGRADES')
    if ($i -ge 0) {
        $txt = if ($n -gt 0) { ('Actualizaciones disponibles ({0})' -f $n) } else { 'Actualizaciones disponibles' }
        $script:SideList.Items[$i] = $txt
    }
}
function Update-UpgCount {
    $nw = @($script:UpgChecksWpi   | Where-Object { $_.IsChecked }).Count
    $no = @($script:UpgChecksOther | Where-Object { $_.IsChecked }).Count
    $script:BtnUpgWpi.Content   = ((Tr 'ACTUALIZAR APPS DEL CATALOGO WPI ({0})') -f $nw)
    $script:BtnUpgOther.Content = ((Tr 'ACTUALIZAR OTROS PROGRAMAS DE MI PC ({0})') -f $no)
}

# Crea una ficha-checkbox para una actualizacion y la mete en su panel
function New-UpgRow($u, $panel) {
    $card = New-Object Windows.Controls.Border
    $card.Background      = Get-ThemeBrush('#FF15151F')
    $card.BorderBrush     = Get-ThemeBrush('#FF2C2C3A')
    $card.BorderThickness = New-Object Windows.Thickness(1)
    $card.CornerRadius    = New-Object Windows.CornerRadius(11)
    $card.Margin          = New-Object Windows.Thickness(0,6,0,0)
    $card.Padding         = New-Object Windows.Thickness(13,8,13,9)
    $row = New-Object Windows.Controls.StackPanel
    $cb = New-Object Windows.Controls.CheckBox
    $cb.Content = $u.Name
    $cb.FontSize = 13.5
    $cb.Tag = $u.Id
    $cb.Add_Checked({ Update-UpgCount })
    $cb.Add_Unchecked({ Update-UpgCount })
    $det = New-Object Windows.Controls.TextBlock
    $det.Inlines.Add((New-Object Windows.Documents.Run(('{0}  ->  ' -f $u.Cur)))) | Out-Null
    $runAv = New-Object Windows.Documents.Run($u.Av)
    $runAv.Foreground = Get-ThemeBrush('#FF5CFF8F'); $runAv.FontWeight = 'Bold'
    $det.Inlines.Add($runAv) | Out-Null
    $det.Inlines.Add((New-Object Windows.Documents.Run(('     {0}   ·   [{1}]' -f $u.Src, $u.Id)))) | Out-Null
    $det.Foreground = Get-ThemeBrush('#FF9A9AA5')
    $det.FontSize = 12; $det.Margin = New-Object Windows.Thickness(30,1,0,0); $det.TextWrapping = 'Wrap'
    $row.Children.Add($cb)  | Out-Null
    $row.Children.Add($det) | Out-Null
    $card.Child = $row
    $panel.Children.Add($card) | Out-Null
    return $cb
}

function Build-Upgrades {
    $script:UpgRowsWpi.Children.Clear()
    $script:UpgRowsOther.Children.Clear()
    $script:UpgChecksWpi   = @()
    $script:UpgChecksOther = @()
    $list = @($script:State.Upgrades)

    if ($list.Count -eq 0) {
        $script:UpgEmpty.Text = 'No se han encontrado actualizaciones pendientes. Tu equipo esta al dia.'
        $script:UpgEmpty.Visibility = 'Visible'
        foreach ($h in @($script:WpiHdr,$script:OthHdr,$script:OthInfo,$script:WpiSelRow,$script:OthSelRow)) { $h.Visibility = 'Collapsed' }
        $script:BtnUpgWpi.IsEnabled = $false; $script:BtnUpgOther.IsEnabled = $false
        $script:BtnUpgWpi.Visibility = 'Collapsed'; $script:BtnUpgOther.Visibility = 'Collapsed'
        Set-UpgSidebarCount 0
        Update-UpgCount
        return
    }
    $script:UpgEmpty.Visibility = 'Collapsed'

    foreach ($u in $list) {
        if ($script:CatIdSet[([string]$u.Id).ToLower()]) {
            $script:UpgChecksWpi += (New-UpgRow $u $script:UpgRowsWpi)
        } else {
            $script:UpgChecksOther += (New-UpgRow $u $script:UpgRowsOther)
        }
    }

    $hasWpi = $script:UpgChecksWpi.Count -gt 0
    $hasOth = $script:UpgChecksOther.Count -gt 0
    $script:WpiHdr.Text = ((Tr 'GRUPO 1 - Apps del catalogo WPI  ({0})') -f $script:UpgChecksWpi.Count)
    $script:OthHdr.Text = ((Tr 'GRUPO 2 - Otros programas de TU PC  ({0})') -f $script:UpgChecksOther.Count)
    $script:WpiHdr.Visibility    = $(if ($hasWpi) { 'Visible' } else { 'Collapsed' })
    $script:WpiSelRow.Visibility = $(if ($hasWpi) { 'Visible' } else { 'Collapsed' })
    $script:BtnUpgWpi.Visibility = $(if ($hasWpi) { 'Visible' } else { 'Collapsed' })
    $script:OthHdr.Visibility    = $(if ($hasOth) { 'Visible' } else { 'Collapsed' })
    $script:OthInfo.Visibility   = $(if ($hasOth) { 'Visible' } else { 'Collapsed' })
    $script:OthSelRow.Visibility = $(if ($hasOth) { 'Visible' } else { 'Collapsed' })
    $script:BtnUpgOther.Visibility = $(if ($hasOth) { 'Visible' } else { 'Collapsed' })
    $script:BtnUpgWpi.IsEnabled   = $hasWpi
    $script:BtnUpgOther.IsEnabled = $hasOth
    if (-not $hasWpi) {
        $script:WpiHdr.Text = (Tr 'GRUPO 1 - Apps del catalogo WPI  (0: ninguna del catalogo necesita update)')
        $script:WpiHdr.Visibility = 'Visible'
    }
    Set-UpgSidebarCount $list.Count
    Update-UpgCount
}

# ---- Construccion del panel "Buscar en winget" (instalar lo que no esta en el catalogo) ----
$script:SearchChecks = @()
$ws = $script:WingetSearchList

$wsHdr = New-Object Windows.Controls.TextBlock
$wsHdr.Text = 'BUSCAR E INSTALAR DESDE WINGET'
$wsHdr.FontSize = 14; $wsHdr.FontWeight = 'Bold'
$wsHdr.Foreground = Get-ThemeBrush('#FF7C4DFF')
$wsHdr.Margin = New-Object Windows.Thickness(2,10,0,2)
$ws.Children.Add($wsHdr) | Out-Null

$wsInfo = New-Object Windows.Controls.TextBlock
$wsInfo.Text = 'Busca cualquier programa en TODO el repositorio de winget (no solo en el catalogo WPI de 200). Escribe un nombre y pulsa Buscar; marca lo que quieras e instalalo con el mismo motor (paralelismo, reintentos y log).'
$wsInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$wsInfo.FontSize = 12; $wsInfo.TextWrapping = 'Wrap'
$wsInfo.Margin = New-Object Windows.Thickness(2,0,0,8)
$ws.Children.Add($wsInfo) | Out-Null

$wsBar = New-Object Windows.Controls.DockPanel
$wsBar.Margin = New-Object Windows.Thickness(0,0,0,4)
$script:WgSearchBox = New-Object Windows.Controls.TextBox
$script:WgSearchBox.MinWidth = 260
$script:WgSearchBox.Margin = New-Object Windows.Thickness(0,0,8,0)
$wsGo = New-Object Windows.Controls.Button
$wsGo.Content = 'Buscar en winget'
$wsGo.Background  = Get-ThemeBrush('#FF3A2A6E')
$wsGo.BorderBrush = Get-ThemeBrush('#FF7C4DFF')
[Windows.Controls.DockPanel]::SetDock($wsGo, 'Right')
$wsBar.Children.Add($wsGo) | Out-Null
$wsBar.Children.Add($script:WgSearchBox) | Out-Null
$ws.Children.Add($wsBar) | Out-Null
$script:BtnWgSearch = $wsGo

$script:WgEmpty = New-Object Windows.Controls.TextBlock
$script:WgEmpty.Text = 'Escribe un nombre (ej: "obs", "7zip", "blender") y pulsa Buscar en winget.'
$script:WgEmpty.Foreground = Get-ThemeBrush('#FF6F6F7A')
$script:WgEmpty.FontStyle = 'Italic'; $script:WgEmpty.Margin = New-Object Windows.Thickness(2,8,0,0)
$ws.Children.Add($script:WgEmpty) | Out-Null

$script:WgRowsPanel = New-Object Windows.Controls.StackPanel
$ws.Children.Add($script:WgRowsPanel) | Out-Null

$wsBtnRow = New-Object Windows.Controls.StackPanel
$wsBtnRow.Orientation = 'Horizontal'
$wsBtnRow.Margin = New-Object Windows.Thickness(0,12,0,4)
$script:BtnWgInstall = New-Object Windows.Controls.Button
$script:BtnWgInstall.Content = 'INSTALAR SELECCIONADAS (0)'
$script:BtnWgInstall.FontWeight = 'Bold'
$script:BtnWgInstall.Background  = Get-ThemeBrush('#FF0A84FF')
$script:BtnWgInstall.BorderBrush = Get-ThemeBrush('#FF35A0FF')
$script:BtnWgInstall.IsEnabled = $false
$wsBtnRow.Children.Add($script:BtnWgInstall) | Out-Null
$script:BtnWgDownload = New-Object Windows.Controls.Button
$script:BtnWgDownload.Content = ((Tr 'DESCARGAR INSTALADOR ({0})') -f 0)
$script:BtnWgDownload.FontWeight = 'Bold'
$script:BtnWgDownload.Background  = Get-ThemeBrush('#FF2A3F4F')
$script:BtnWgDownload.BorderBrush = Get-ThemeBrush('#FF4477AA')
$script:BtnWgDownload.IsEnabled = $false
$wsBtnRow.Children.Add($script:BtnWgDownload) | Out-Null
$ws.Children.Add($wsBtnRow) | Out-Null

function Update-WgCount {
    $n = @($script:SearchChecks | Where-Object { $_.IsChecked }).Count
    $script:BtnWgInstall.Content = ((Tr 'INSTALAR SELECCIONADAS ({0})') -f $n)
    $script:BtnWgDownload.Content = ((Tr 'DESCARGAR INSTALADOR ({0})') -f $n)
    $script:BtnWgInstall.IsEnabled = ($n -gt 0)
    $script:BtnWgDownload.IsEnabled = ($n -gt 0)
}
function Build-Search {
    $script:WgRowsPanel.Children.Clear()
    $script:SearchChecks = @()
    $list = @($script:State.SearchResults)
    if ($list.Count -eq 0) {
        $script:WgEmpty.Text = 'Sin resultados. Prueba con otro termino o revisa la ortografia.'
        $script:WgEmpty.Visibility = 'Visible'
        Update-WgCount
        return
    }
    $script:WgEmpty.Visibility = 'Collapsed'
    foreach ($u in $list) {
        $inCat = $script:CatIdSet[([string]$u.Id).ToLower()]
        $card = New-Object Windows.Controls.Border
        $card.Background      = Get-ThemeBrush('#FF15151F')
        $card.BorderBrush     = Get-ThemeBrush('#FF2C2C3A')
        $card.BorderThickness = New-Object Windows.Thickness(1)
        $card.CornerRadius    = New-Object Windows.CornerRadius(11)
        $card.Margin          = New-Object Windows.Thickness(0,6,0,0)
        $card.Padding         = New-Object Windows.Thickness(13,8,13,9)
        $row = New-Object Windows.Controls.StackPanel
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Content = $u.Name
        $cb.FontSize = 13.5
        $cb.Tag = $u.Id
        $cb.Add_Checked({ Update-WgCount })
        $cb.Add_Unchecked({ Update-WgCount })
        $det = New-Object Windows.Controls.TextBlock
        $extra = if ($inCat) { '   ·   YA en el catalogo WPI' } else { '' }
        $det.Text = ('[{0}]   v{1}   {2}{3}' -f $u.Id, $u.Ver, $u.Src, $extra)
        $det.Foreground = Get-ThemeBrush($(if ($inCat) { '#FF5CFF8F' } else { '#FF9A9AA5' }))
        $det.FontSize = 12; $det.Margin = New-Object Windows.Thickness(30,1,0,0); $det.TextWrapping = 'Wrap'
        $row.Children.Add($cb)  | Out-Null
        $row.Children.Add($det) | Out-Null
        $card.Child = $row
        $script:WgRowsPanel.Children.Add($card) | Out-Null
        $script:SearchChecks += $cb
    }
    Update-WgCount
}

# ---- Panel DEBLOAT (quitar apps preinstaladas) ----
$script:DebloatChecks = @()
$db = $script:DebloatList
$dbHdr = New-Object Windows.Controls.TextBlock
$dbHdr.Text = 'QUITAR APPS PREINSTALADAS (DEBLOAT)  ·  ACCION FUERTE'
$dbHdr.FontSize = 14; $dbHdr.FontWeight = 'Bold'
$dbHdr.Foreground = Get-ThemeBrush('#FFFF6B6B')
$dbHdr.Margin = New-Object Windows.Thickness(2,10,0,2)
$db.Children.Add($dbHdr) | Out-Null
$dbInfo = New-Object Windows.Controls.TextBlock
$dbInfo.Text = 'Elimina la basura que trae Windows de fabrica. Marca solo lo que quieras quitar (nada viene preseleccionado). Se borra para tu usuario y se evita que vuelva; todo es reinstalable desde la Microsoft Store. No se incluyen componentes criticos del sistema.'
$dbInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$dbInfo.FontSize = 12; $dbInfo.TextWrapping = 'Wrap'
$dbInfo.Margin = New-Object Windows.Thickness(2,0,0,8)
$db.Children.Add($dbInfo) | Out-Null
$dbSel = New-Object Windows.Controls.StackPanel; $dbSel.Orientation = 'Horizontal'
$dbAll = New-Object Windows.Controls.Button; $dbAll.Content = 'Marcar todo'
$dbNon = New-Object Windows.Controls.Button; $dbNon.Content = 'Ninguno'
$dbAll.Add_Click({ foreach ($c in $script:DebloatChecks) { $c.IsChecked = $true };  Update-DebloatCount })
$dbNon.Add_Click({ foreach ($c in $script:DebloatChecks) { $c.IsChecked = $false }; Update-DebloatCount })
$dbSel.Children.Add($dbAll) | Out-Null; $dbSel.Children.Add($dbNon) | Out-Null
$db.Children.Add($dbSel) | Out-Null
$script:DebloatStatusLabels = @{}
$script:DebloatDetected = $false

# --- Buscador en vivo de bloatware ---
$script:DbSearchItems = @()
$dbSearchBorder = New-Object Windows.Controls.Border
$dbSearchBorder.Background = Get-ThemeBrush('#FF12121A')
$dbSearchBorder.BorderBrush = Get-ThemeBrush('#FF3A3A4A')
$dbSearchBorder.BorderThickness = New-Object Windows.Thickness(1)
$dbSearchBorder.CornerRadius = New-Object Windows.CornerRadius(8)
$dbSearchBorder.Margin = New-Object Windows.Thickness(2,6,6,6)
$dbSearchGrid = New-Object Windows.Controls.Grid
$script:DbSearchBox = New-Object Windows.Controls.TextBox
$script:DbSearchBox.Background = [Windows.Media.Brushes]::Transparent
$script:DbSearchBox.BorderThickness = New-Object Windows.Thickness(0)
$script:DbSearchBox.Foreground = Get-ThemeBrush($Theme.Text)
$script:DbSearchBox.Padding = New-Object Windows.Thickness(10,6,10,6)
$script:DbSearchBox.FontSize = 13
$script:DbSearchBox.CaretBrush = Get-ThemeBrush('#FF00E5FF')
$script:DbSearchHint = New-Object Windows.Controls.TextBlock
$script:DbSearchHint.Text = (Tr 'Buscar app preinstalada...')
$script:DbSearchHint.Foreground = Get-ThemeBrush('#FF6A6A78')
$script:DbSearchHint.FontSize = 13
$script:DbSearchHint.IsHitTestVisible = $false
$script:DbSearchHint.VerticalAlignment = 'Center'
$script:DbSearchHint.Margin = New-Object Windows.Thickness(11,0,0,0)
$dbSearchGrid.Children.Add($script:DbSearchBox) | Out-Null
$dbSearchGrid.Children.Add($script:DbSearchHint) | Out-Null
$dbSearchBorder.Child = $dbSearchGrid
$db.Children.Add($dbSearchBorder) | Out-Null
$script:DbSearchBox.Add_TextChanged({
    $q = ([string]$script:DbSearchBox.Text).Trim().ToLower()
    $script:DbSearchHint.Visibility = $(if ($q) { 'Collapsed' } else { 'Visible' })
    foreach ($it in $script:DbSearchItems) {
        $it.El.Visibility = $(if (($q -eq '') -or ($it.Text.Contains($q))) { 'Visible' } else { 'Collapsed' })
    }
})

# --- 2 columnas ---
$dbGrid = New-Object Windows.Controls.Grid
$dbGrid.Margin = New-Object Windows.Thickness(0,2,0,0)
$dbCol0 = New-Object Windows.Controls.ColumnDefinition; $dbCol0.Width = New-Object Windows.GridLength(1, ([Windows.GridUnitType]::Star))
$dbCol1 = New-Object Windows.Controls.ColumnDefinition; $dbCol1.Width = New-Object Windows.GridLength(1, ([Windows.GridUnitType]::Star))
$dbGrid.ColumnDefinitions.Add($dbCol0); $dbGrid.ColumnDefinitions.Add($dbCol1)
$dbColL = New-Object Windows.Controls.StackPanel; $dbColL.Margin = New-Object Windows.Thickness(2,0,7,0)
$dbColR = New-Object Windows.Controls.StackPanel; $dbColR.Margin = New-Object Windows.Thickness(7,0,6,0)
[Windows.Controls.Grid]::SetColumn($dbColL, 0); [Windows.Controls.Grid]::SetColumn($dbColR, 1)
$dbGrid.Children.Add($dbColL) | Out-Null; $dbGrid.Children.Add($dbColR) | Out-Null

$dbItems = @($DebloatCatalog)
$dbHalf = [math]::Ceiling($dbItems.Count / 2.0)
for ($di = 0; $di -lt $dbItems.Count; $di++) {
    $d = $dbItems[$di]
    $dcol = $(if ($di -lt $dbHalf) { $dbColL } else { $dbColR })
    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.Margin = New-Object Windows.Thickness(2,2,0,2)
    $dot = New-Object Windows.Controls.TextBlock
    $dot.Text = [string][char]0x25CF
    $dot.FontSize = 13
    $dot.Foreground = Get-ThemeBrush('#FF4A4A56')
    $dot.VerticalAlignment = 'Center'
    $dot.Margin = New-Object Windows.Thickness(0,0,7,0)
    $dot.ToolTip = (Tr 'estado: sin comprobar')
    $cb = New-Object Windows.Controls.CheckBox
    $cb.Content = $d.Name; $cb.FontSize = 13; $cb.Tag = $d.Pkg; $cb.VerticalAlignment = 'Center'
    $cb.ToolTip = (Tr ([string]$d.Desc))
    $cb.Add_Checked({ Update-DebloatCount }); $cb.Add_Unchecked({ Update-DebloatCount })
    $row.Children.Add($dot) | Out-Null
    $row.Children.Add($cb)  | Out-Null
    $dcol.Children.Add($row) | Out-Null
    $script:DebloatChecks += $cb
    $script:DebloatStatusLabels[[string]$d.Pkg] = $dot
    $script:DbSearchItems += @{ El = $row; Text = ((([string]$d.Name) + ' ' + ([string]$d.Desc)).ToLower()) }
}
$db.Children.Add($dbGrid) | Out-Null

# Banner breve de estado JUSTO ENCIMA del boton: "X instaladas / Y ya quitadas"
# con colores (ambar = sigue instalada; verde = ya no esta). Lo rellena Detect-DebloatStates.
$script:DebloatStatusBanner = New-Object Windows.Controls.Border
$script:DebloatStatusBanner.Background = Get-ThemeBrush('#FF15202A')
$script:DebloatStatusBanner.BorderBrush = Get-ThemeBrush('#FF2C4A57')
$script:DebloatStatusBanner.BorderThickness = New-Object Windows.Thickness(1)
$script:DebloatStatusBanner.CornerRadius = New-Object Windows.CornerRadius(7)
$script:DebloatStatusBanner.Padding = New-Object Windows.Thickness(11,6,11,6)
$script:DebloatStatusBanner.Margin = New-Object Windows.Thickness(2,12,0,2)
$script:DebloatStatusBanner.HorizontalAlignment = 'Left'
$script:DebloatStatusInline = New-Object Windows.Controls.TextBlock
$script:DebloatStatusInline.FontSize = 12.5
$script:DebloatStatusInline.TextWrapping = 'Wrap'
$script:DebloatStatusInline.Foreground = Get-ThemeBrush('#FF76E0FF')
$script:DebloatStatusInline.Text = (Tr 'Detectando que apps siguen instaladas en tu PC...')
$script:DebloatStatusBanner.Child = $script:DebloatStatusInline
$db.Children.Add($script:DebloatStatusBanner) | Out-Null

$script:BtnDebloat = New-Object Windows.Controls.Button
$script:BtnDebloat.Content = 'QUITAR SELECCIONADAS (0)'
$script:BtnDebloat.FontWeight = 'Bold'
$script:BtnDebloat.Background  = Get-ThemeBrush('#FF5A2222')
$script:BtnDebloat.BorderBrush = Get-ThemeBrush('#FFFF6B6B')
$script:BtnDebloat.Margin = New-Object Windows.Thickness(0,12,0,4)
$script:BtnDebloat.HorizontalAlignment = 'Left'
$script:BtnDebloat.IsEnabled = $false
$db.Children.Add($script:BtnDebloat) | Out-Null
$dbBtnRow = New-Object Windows.Controls.StackPanel
$dbBtnRow.Orientation = 'Horizontal'
$dbBtnRow.Margin = New-Object Windows.Thickness(0,8,0,4)
$script:BtnDebloatDetect = New-Object Windows.Controls.Button
$script:BtnDebloatDetect.Content = 'Re-detectar estado'
$script:BtnDebloatDetect.Background  = Get-ThemeBrush('#FF13414F')
$script:BtnDebloatDetect.BorderBrush = Get-ThemeBrush('#FF76E0FF')
$script:BtnDebloatDetect.Add_Click({ try { Detect-DebloatStates } catch { $script:StatusText.Text = (Tr 'No se pudo detectar el estado del bloatware.') } })
$dbBtnRow.Children.Add($script:BtnDebloatDetect) | Out-Null
$script:BtnDebloatInstalled = New-Object Windows.Controls.Button
$script:BtnDebloatInstalled.Content = 'Marcar solo las instaladas'
$script:BtnDebloatInstalled.Add_Click({
    if (-not $script:DebloatDetected) { try { Detect-DebloatStates } catch {} }
    foreach ($cb in $script:DebloatChecks) {
        $lbl = $script:DebloatStatusLabels[[string]$cb.Tag]
        $cb.IsChecked = ($lbl -and ([string]$lbl.Text).StartsWith('INSTALADA'))
    }
    Update-DebloatCount
})
$dbBtnRow.Children.Add($script:BtnDebloatInstalled) | Out-Null
$script:BtnDebloatSave = New-Object Windows.Controls.Button
$script:BtnDebloatSave.Content = 'Guardar perfil'
$script:BtnDebloatSave.Add_Click({ try { Save-DebloatProfile } catch { $script:StatusText.Text = (Tr 'No se pudo guardar el perfil de debloat.') } })
$dbBtnRow.Children.Add($script:BtnDebloatSave) | Out-Null
$script:BtnDebloatLoad = New-Object Windows.Controls.Button
$script:BtnDebloatLoad.Content = 'Cargar perfil'
$script:BtnDebloatLoad.Add_Click({ try { Load-DebloatProfile } catch { $script:StatusText.Text = (Tr 'No se pudo cargar el perfil de debloat.') } })
$dbBtnRow.Children.Add($script:BtnDebloatLoad) | Out-Null
$script:BtnDebloatOneDrive = New-Object Windows.Controls.Button
$script:BtnDebloatOneDrive.Content = 'Quitar OneDrive (reversible)'
$script:BtnDebloatOneDrive.Background = Get-ThemeBrush('#FF4F2A2A'); $script:BtnDebloatOneDrive.BorderBrush = Get-ThemeBrush('#FF7B4444')
$script:BtnDebloatOneDrive.Add_Click({
    $r = Show-WpiMessage(
        ("Se desinstalara Microsoft OneDrive (no es una Appx, usa su propio desinstalador)." + "`n`n" + "Es REVERSIBLE: se reinstala con 'Buscar en winget' -> Microsoft.OneDrive, o desde onedrive.com. Tus archivos en la nube no se borran. Continuar?"),
        'Quitar OneDrive', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    $code = @'
taskkill /f /im OneDrive.exe 2>$null | Out-Null
$od = "$env:SystemRoot\System32\OneDriveSetup.exe"
if (-not (Test-Path $od)) { $od = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" }
if (Test-Path $od) {
    Start-Process $od -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
    W ok "OneDrive desinstalado. Reinstalable con winget Microsoft.OneDrive."
} else {
    W warn "No se encontro OneDriveSetup.exe (quiza ya no esta instalado)."
}
'@
    Start-Worker -Mode 'tweaks' -Tweaks @(@{ Name = 'Quitar OneDrive'; Code = $code })
})
$dbBtnRow.Children.Add($script:BtnDebloatOneDrive) | Out-Null
$db.Children.Add($dbBtnRow) | Out-Null
$script:DebloatSummary = New-Object Windows.Controls.TextBlock
$script:DebloatSummary.Text = 'Estado: entra a esta seccion o pulsa "Re-detectar estado" para ver que apps siguen instaladas.'
$script:DebloatSummary.Foreground = Get-ThemeBrush('#FF76E0FF')
$script:DebloatSummary.FontSize = 12
$script:DebloatSummary.TextWrapping = 'Wrap'
$script:DebloatSummary.Margin = New-Object Windows.Thickness(2,8,0,0)
$db.Children.Add($script:DebloatSummary) | Out-Null
function Update-DebloatCount {
    $n = @($script:DebloatChecks | Where-Object { $_.IsChecked }).Count
    $script:BtnDebloat.Content = ((Tr 'QUITAR SELECCIONADAS ({0})') -f $n)
    $script:BtnDebloat.IsEnabled = ($n -gt 0)
}

# ---- Panel CLONAR / SNAPSHOT ----
$sn = $script:SnapshotList
$snHdr = New-Object Windows.Controls.TextBlock
$snHdr.Text = 'CLONAR EQUIPO / SNAPSHOT'
$snHdr.FontSize = 14; $snHdr.FontWeight = 'Bold'
$snHdr.Foreground = Get-ThemeBrush('#FF5CFF8F')
$snHdr.Margin = New-Object Windows.Thickness(2,10,0,6)
$sn.Children.Add($snHdr) | Out-Null
$snInfo = New-Object Windows.Controls.TextBlock
$snInfo.Text = 'Exporta TODO lo que tienes instalado (que winget reconozca) a un archivo, y reimportalo en otro PC para dejarlo igual de un golpe. Ideal si formateas a menudo o montas varias maquinas. Usa el formato oficial de winget import.'
$snInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$snInfo.FontSize = 12; $snInfo.TextWrapping = 'Wrap'
$snInfo.Margin = New-Object Windows.Thickness(2,0,0,10)
$sn.Children.Add($snInfo) | Out-Null
$script:BtnSnapExport = New-Object Windows.Controls.Button
$script:BtnSnapExport.Content = 'Exportar TODO mi equipo a un archivo...'
$script:BtnSnapExport.Background = Get-ThemeBrush('#FF1F3A2E'); $script:BtnSnapExport.BorderBrush = Get-ThemeBrush('#FF3E6B54')
$script:BtnSnapExport.HorizontalAlignment = 'Left'; $script:BtnSnapExport.Margin = New-Object Windows.Thickness(0,0,0,8)
$sn.Children.Add($script:BtnSnapExport) | Out-Null
$script:BtnSnapImport = New-Object Windows.Controls.Button
$script:BtnSnapImport.Content = 'Importar un archivo e instalar todo...'
$script:BtnSnapImport.Background = Get-ThemeBrush('#FF24303F'); $script:BtnSnapImport.BorderBrush = Get-ThemeBrush('#FF3C5876')
$script:BtnSnapImport.HorizontalAlignment = 'Left'; $script:BtnSnapImport.Margin = New-Object Windows.Thickness(0,0,0,18)
$sn.Children.Add($script:BtnSnapImport) | Out-Null
$snHdr2 = New-Object Windows.Controls.TextBlock
$snHdr2.Text = 'CATALOGO'
$snHdr2.FontSize = 13; $snHdr2.FontWeight = 'Bold'
$snHdr2.Foreground = Get-ThemeBrush('#FF00E5FF')
$snHdr2.Margin = New-Object Windows.Thickness(2,0,0,6)
$sn.Children.Add($snHdr2) | Out-Null
$script:SnapCatInfo = New-Object Windows.Controls.TextBlock
$script:SnapCatInfo.Foreground = Get-ThemeBrush('#FF8A8A95'); $script:SnapCatInfo.FontSize = 12
$script:SnapCatInfo.TextWrapping = 'Wrap'; $script:SnapCatInfo.Margin = New-Object Windows.Thickness(2,0,0,8)
$sn.Children.Add($script:SnapCatInfo) | Out-Null
$script:BtnCatTemplate = New-Object Windows.Controls.Button
$script:BtnCatTemplate.Content = 'Crear catalogo.json editable'
$script:BtnCatTemplate.HorizontalAlignment = 'Left'; $script:BtnCatTemplate.Margin = New-Object Windows.Thickness(0,0,0,6)
$sn.Children.Add($script:BtnCatTemplate) | Out-Null
$script:BtnCatReload = New-Object Windows.Controls.Button
$script:BtnCatReload.Content = 'Recargar catalogo.json (reinicia la app)'
$script:BtnCatReload.HorizontalAlignment = 'Left'
$sn.Children.Add($script:BtnCatReload) | Out-Null
$script:BtnCatRemote = New-Object Windows.Controls.Button
$script:BtnCatRemote.Content = 'Cargar catalogo remoto (URL https)'
$script:BtnCatRemote.HorizontalAlignment = 'Left'; $script:BtnCatRemote.Margin = New-Object Windows.Thickness(0,6,0,0)
$sn.Children.Add($script:BtnCatRemote) | Out-Null

# ---- Panel GUIAS (mini-tutoriales ES/EN) ----
function Get-GuideUiText([string]$Key, $Guide) {
    if ($script:Lang -ne 'en') { return @{ Title = [string]$Guide.Title; Steps = [string]$Guide.Steps } }
    switch ($Key) {
        'Libretro.RetroArch' { return @{ Title='RetroArch (multi-emulator)'; Steps=@'
RetroArch works with "cores", one per system.
1) Open it and go to "Online Updater" > "Core Downloader".
2) Download the core for the system you want (for example "Beetle PSX" or "Snes9x").
3) In "Online Updater", update assets, core info files and databases.
4) Load games with "Load Content". For discs/BIOS, copy your files to RetroArch's "system" folder.
5) Configure your controller in "Settings" > "Input".
Note: BIOS files and games must come from your own hardware/copies.
'@ } }
        'PCSX2Team.PCSX2' { return @{ Title='PCSX2 (PlayStation 2)'; Steps=@'
PCSX2 needs the BIOS from your own PS2.
1) On your PS2, dump the BIOS to USB using homebrew such as "BIOS Dumper".
2) Open PCSX2 > initial wizard > BIOS tab, add the dump folder and select it.
3) Configure your controller in Settings > Controllers.
4) Load the game (ISO from your own disc) with "Start File".
Recommended: Vulkan or Direct3D 12 renderer if your GPU supports it.
'@ } }
        'RPCS3.RPCS3' { return @{ Title='RPCS3 (PlayStation 3)'; Steps=@'
RPCS3 needs the official PS3 firmware.
1) Download "PS3UPDAT.PUP" from the official PlayStation website.
2) In RPCS3: File > Install Firmware > select the .PUP file.
3) Add games with File > Add Games (from your own copies).
4) Tune CPU/GPU settings in Configuration; Vulkan usually works best.
Tip: check each game's compatibility wiki.
'@ } }
        'DolphinEmulator.Dolphin' { return @{ Title='Dolphin (GameCube / Wii)'; Steps=@'
Dolphin does not need a BIOS.
1) Open Dolphin > Config > Paths tab and add your games folder.
2) Configure the GameCube controller or Wii remote in Controllers.
3) For Wii, adjust language and sensor options in the Wii tab.
4) Load a game from your own copies by double-clicking it.
Tip: Vulkan or D3D12 backend usually gives better performance.
'@ } }
        'Stenzek.DuckStation' { return @{ Title='DuckStation (PlayStation 1)'; Steps=@'
DuckStation needs a PS1 BIOS.
1) Place your PS1 BIOS from your own console in the "bios" folder.
2) Initial wizard: select the BIOS folder and the games folder.
3) Configure your controller in Settings > Controllers.
4) Load games from your own copies. Enable "PGXP" for improved 3D.
'@ } }
        'Cemu.Cemu' { return @{ Title='Cemu (Wii U)'; Steps=@'
1) Place your own console "keys.txt" next to Cemu.
2) Add your games folder in Options > General.
3) Install game updates/DLC with File > Install update/DLC.
4) Use Graphic Packs for enhancements such as resolution and FPS.
5) Configure your controller in Options > Input settings.
'@ } }
        'PPSSPPTeam.PPSSPP' { return @{ Title='PPSSPP (PSP)'; Steps=@'
No BIOS required.
1) Open it and add the folder containing your own ISO/CSO files under Games.
2) Settings > Graphics: increase render resolution (x2, x3...).
3) Settings > Controls: configure controller or touch controls.
Simple and highly compatible.
'@ } }
        'Vita3K.Vita3K' { return @{ Title='Vita3K (PS Vita) - experimental'; Steps=@'
Vita3K is experimental; compatibility varies.
1) First run: it will ask for PS Vita firmware from the official website.
2) Install the firmware and then your own games/copies.
3) Check the project's compatibility list before expecting a game to work perfectly.
'@ } }
        'EDEN_SWITCH' { return @{ Title='Switch Emulator (Eden / Citron) - NOT on winget'; Steps=@'
After yuzu/Ryujinx shut down in 2024, active forks such as Eden or Citron are not distributed through winget. To get the latest version:
1) Find the current project on its official website or repository (GitHub/GitLab). Download the latest Windows release, usually a portable .zip or .7z.
2) Extract it to a folder, for example inside Downloads.
3) You NEED prod.keys and firmware dumped from YOUR OWN Switch. Without them nothing will boot.
4) In the emulator: File > Open/Install Keys and load prod.keys; install firmware. Add your own dumped games folder.
5) Configure controller and graphics backend (Vulkan recommended).
Warning: the scene changes quickly; always use the project's official website and avoid suspicious copies.
'@ } }
        'ANDROID_EMU' { return @{ Title='Android Emulators (top picks)'; Steps=@'
Recommended options depending on your use case:
- Google Play Games on PC (official Google): cleanest option for compatible mobile games. Download it from Google's official website.
- Android Studio (official AVD emulator): ideal for development/testing; it is available on winget (search "Android Studio").
- Waydroid: Linux only.
- BlueStacks / LDPlayer / MEmu / MuMu: popular for games, but review the installer carefully because some include extras/ads. Download only from the official website and uncheck anything unwanted during setup.
Tip: for performance, enable virtualization (VT-x/AMD-V) in your motherboard BIOS.
'@ } }
    }
    return @{ Title = (Tr ([string]$Guide.Title)); Steps = (Tr ([string]$Guide.Steps)) }
}
$gp = $script:GuidesList
$gpHdr = New-Object Windows.Controls.TextBlock
$gpHdr.Text = 'GUIAS DE INSTALACION (en espanol)'
$gpHdr.FontSize = 14; $gpHdr.FontWeight = 'Bold'
$gpHdr.Foreground = Get-ThemeBrush('#FFFFD166')
$gpHdr.Margin = New-Object Windows.Thickness(2,10,0,2)
$gp.Children.Add($gpHdr) | Out-Null
$gpInfo = New-Object Windows.Controls.TextBlock
$gpInfo.Text = 'Pasos para dejar listos los programas que necesitan algo extra (BIOS, firmware, claves...) y para los emuladores que NO estan en winget (Switch, Android). Pulsa cada titulo para desplegarlo. Al instalar o descargar una app con guia, la consola te avisa.'
$gpInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$gpInfo.FontSize = 12; $gpInfo.TextWrapping = 'Wrap'
$gpInfo.Margin = New-Object Windows.Thickness(2,0,0,8)
$gp.Children.Add($gpInfo) | Out-Null
$gpTools = New-Object Windows.Controls.StackPanel; $gpTools.Orientation = 'Horizontal'
$gpTools.Margin = New-Object Windows.Thickness(0,0,0,6)
$script:BtnGuidesTemplate = New-Object Windows.Controls.Button
$script:BtnGuidesTemplate.Content = 'Crear guias.json editable'
$gpTools.Children.Add($script:BtnGuidesTemplate) | Out-Null
$script:BtnGuidesReload = New-Object Windows.Controls.Button
$script:BtnGuidesReload.Content = 'Recargar guias.json (reinicia)'
$gpTools.Children.Add($script:BtnGuidesReload) | Out-Null
$gp.Children.Add($gpTools) | Out-Null
$script:GuideExpanders = @{}
foreach ($gk in $Guides.Keys) {
    $g = $Guides[$gk]
    $gui = Get-GuideUiText $gk $g
    $exp = New-Object Windows.Controls.Expander
    $tag = if ($g.Win) { '' } else { $(if ($script:Lang -eq 'en') { '   [not on winget]' } else { '   [no esta en winget]' }) }
    $exp.Header = ([string]$gui.Title + $tag)
    $exp.Foreground = Get-ThemeBrush('#FFE6E6EC')
    $exp.Margin = New-Object Windows.Thickness(0,4,0,0)
    $bd = New-Object Windows.Controls.Border
    $bd.Background = Get-ThemeBrush('#FF15151F')
    $bd.BorderBrush = Get-ThemeBrush('#FF2C2C3A')
    $bd.BorderThickness = New-Object Windows.Thickness(1)
    $bd.CornerRadius = New-Object Windows.CornerRadius(9)
    $bd.Padding = New-Object Windows.Thickness(12,8,12,10)
    $bd.Margin = New-Object Windows.Thickness(0,4,0,2)
    $inner = New-Object Windows.Controls.StackPanel
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = [string]$gui.Steps
    $tb.Foreground = Get-ThemeBrush('#FFCFCFD8')
    $tb.FontSize = 12.5; $tb.TextWrapping = 'Wrap'
    $inner.Children.Add($tb) | Out-Null
    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'
    $btnRow.Margin = New-Object Windows.Thickness(0,8,0,0)
    $url = [string]$GuideWeb[$gk]
    if ($url) {
        $bWeb = New-Object Windows.Controls.Button
        $bWeb.Content = 'Abrir web oficial'
        $bWeb.Tag = $url
        $bWeb.Add_Click({ try { Start-Process ([string]$this.Tag) } catch {} })
        $btnRow.Children.Add($bWeb) | Out-Null
    }
    $bCopy = New-Object Windows.Controls.Button
    $bCopy.Content = 'Copiar pasos'
    $bCopy.Tag = [string]$gui.Steps
    $bCopy.Add_Click({
        $s = [string]$this.Tag
        try { Set-Clipboard -Value $s } catch { try { [System.Windows.Clipboard]::SetText($s) } catch {} }
        $script:StatusText.Text = (Tr 'Pasos de la guia copiados.')
    })
    $btnRow.Children.Add($bCopy) | Out-Null
    $inner.Children.Add($btnRow) | Out-Null
    $bd.Child = $inner
    $exp.Content = $bd
    $gp.Children.Add($exp) | Out-Null
    $script:GuideExpanders[$gk] = $exp
}
function Show-Guide([string]$id) {
    $gi = $script:SideMap.IndexOf('@GUIDES')
    if ($gi -ge 0) { $script:SideList.SelectedIndex = $gi }
    if ($script:GuideExpanders.ContainsKey($id)) {
        $script:GuideExpanders[$id].IsExpanded = $true
        try { $script:GuideExpanders[$id].BringIntoView() } catch {}
    }
}

# ---- Panel DRIVERS Y HARDWARE ----
$dv = $script:DriversList
$dvHdr = New-Object Windows.Controls.TextBlock
$dvHdr.Text = 'DRIVERS Y HARDWARE'
$dvHdr.FontSize = 14; $dvHdr.FontWeight = 'Bold'
$dvHdr.Foreground = Get-ThemeBrush('#FF76E0FF')
$dvHdr.Margin = New-Object Windows.Thickness(2,10,0,2)
$dv.Children.Add($dvHdr) | Out-Null
$dvInfo = New-Object Windows.Controls.TextBlock
$dvInfo.Text = 'Detecta tus piezas y el driver de la grafica que tienes ahora. Para actualizar drivers, lo seguro es la herramienta OFICIAL del fabricante (no usamos programas de "drivers todo en uno", suelen traer publicidad y drivers erroneos). Tambien tienes acceso directo a Windows Update opcional y al soporte de tu placa.'
$dvInfo.Foreground = Get-ThemeBrush('#FF8A8A95')
$dvInfo.FontSize = 12; $dvInfo.TextWrapping = 'Wrap'
$dvInfo.Margin = New-Object Windows.Thickness(2,0,0,8)
$dv.Children.Add($dvInfo) | Out-Null

$script:BtnHwScan = New-Object Windows.Controls.Button
$script:BtnHwScan.Content = 'Detectar mi hardware'
$script:BtnHwScan.Background  = Get-ThemeBrush('#FF13414F')
$script:BtnHwScan.BorderBrush = Get-ThemeBrush('#FF76E0FF')
$script:BtnHwScan.HorizontalAlignment = 'Left'
$dvScanRow = New-Object Windows.Controls.StackPanel
$dvScanRow.Orientation = 'Horizontal'
$dvScanRow.Margin = New-Object Windows.Thickness(0,0,0,10)
$dvScanRow.Children.Add($script:BtnHwScan) | Out-Null
$script:BtnHwCopy = New-Object Windows.Controls.Button
$script:BtnHwCopy.Content = 'Copiar informe'
$dvScanRow.Children.Add($script:BtnHwCopy) | Out-Null
$script:BtnHwExport = New-Object Windows.Controls.Button
$script:BtnHwExport.Content = 'Exportar a archivo'
$dvScanRow.Children.Add($script:BtnHwExport) | Out-Null
$dv.Children.Add($dvScanRow) | Out-Null

$script:HwReportPanel = New-Object Windows.Controls.StackPanel
$dv.Children.Add($script:HwReportPanel) | Out-Null

# Bloque de acciones de driver de GPU (se rellena tras detectar)
$script:GpuActionPanel = New-Object Windows.Controls.StackPanel
$script:GpuActionPanel.Margin = New-Object Windows.Thickness(0,4,0,0)
$dv.Children.Add($script:GpuActionPanel) | Out-Null

# Bloque de recomendaciones segun hardware (se rellena tras detectar)
$script:RecoPanel = New-Object Windows.Controls.StackPanel
$script:RecoPanel.Margin = New-Object Windows.Thickness(0,4,0,0)
$dv.Children.Add($script:RecoPanel) | Out-Null

$dvHdr2 = New-Object Windows.Controls.TextBlock
$dvHdr2.Text = 'OTRAS FUENTES DE DRIVERS'
$dvHdr2.FontSize = 13; $dvHdr2.FontWeight = 'Bold'
$dvHdr2.Foreground = Get-ThemeBrush('#FF00E5FF')
$dvHdr2.Margin = New-Object Windows.Thickness(2,16,0,6)
$dv.Children.Add($dvHdr2) | Out-Null
$script:BtnWinUpd = New-Object Windows.Controls.Button
$script:BtnWinUpd.Content = 'Abrir actualizaciones opcionales de Windows (incluye drivers)'
$script:BtnWinUpd.HorizontalAlignment = 'Left'; $script:BtnWinUpd.Margin = New-Object Windows.Thickness(0,0,0,6)
$dv.Children.Add($script:BtnWinUpd) | Out-Null
$script:BtnMoboSupport = New-Object Windows.Controls.Button
$script:BtnMoboSupport.Content = 'Buscar soporte/drivers de mi placa base'
$script:BtnMoboSupport.HorizontalAlignment = 'Left'
$dv.Children.Add($script:BtnMoboSupport) | Out-Null

# --- B3: Copia de seguridad / restauracion de drivers ---
$dvHdr3 = New-Object Windows.Controls.TextBlock
$dvHdr3.Text = 'COPIA DE SEGURIDAD DE DRIVERS'
$dvHdr3.FontSize = 13; $dvHdr3.FontWeight = 'Bold'
$dvHdr3.Foreground = Get-ThemeBrush($Theme.Maintain)
$dvHdr3.Margin = New-Object Windows.Thickness(2,16,0,4)
$dv.Children.Add($dvHdr3) | Out-Null
$dvInfo3 = New-Object Windows.Controls.TextBlock
$dvInfo3.Text = 'Exporta TODOS los drivers de terceros antes de formatear y reinyectalos despues (joya post-formateo). La copia es solo lectura del sistema; la restauracion es para un equipo recien reinstalado. Ambas corren por el motor con log.'
$dvInfo3.Foreground = Get-ThemeBrush($Theme.Sub); $dvInfo3.FontSize = 12; $dvInfo3.TextWrapping = 'Wrap'
$dvInfo3.Margin = New-Object Windows.Thickness(2,0,0,6)
$dv.Children.Add($dvInfo3) | Out-Null

$script:BtnDrvBackup = New-Object Windows.Controls.Button
$script:BtnDrvBackup.Content = 'Hacer copia de drivers'; $script:BtnDrvBackup.HorizontalAlignment = 'Left'
$script:BtnDrvBackup.Margin = New-Object Windows.Thickness(0,0,0,6)
$script:BtnDrvBackup.Background = Get-ThemeBrush('#FF1F3A2E'); $script:BtnDrvBackup.BorderBrush = Get-ThemeBrush('#FF3E6B54')
$script:BtnDrvBackup.Add_Click({
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = 'Elige la carpeta donde guardar la copia de drivers'
    try { $fb.UseDescriptionForTitle = $true } catch {}
    if ($fb.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $dest = $fb.SelectedPath
    if (-not $dest) { return }
    $destEsc = $dest -replace "'", "''"
    $code = ("`$d='{0}'; if (-not (Test-Path `$d)) {{ New-Item -ItemType Directory -Path `$d -Force | Out-Null }}; W info ('Exportando drivers de terceros a ' + `$d + ' (puede tardar)...'); try {{ Export-WindowsDriver -Online -Destination `$d -ErrorAction Stop | Out-Null; W ok 'Copia de drivers completada.'; Start-Process explorer.exe `$d }} catch {{ W err ('Fallo al exportar drivers: ' + `$_.Exception.Message) }}" -f $destEsc)
    Start-Worker -Mode 'tweaks' -Tweaks @(@{ Name = 'Copia de drivers'; Code = $code })
})
$dv.Children.Add($script:BtnDrvBackup) | Out-Null

$script:BtnDrvRestore = New-Object Windows.Controls.Button
$script:BtnDrvRestore.Content = 'Restaurar drivers desde carpeta'; $script:BtnDrvRestore.HorizontalAlignment = 'Left'
$script:BtnDrvRestore.Background = Get-ThemeBrush('#FF4F2A2A'); $script:BtnDrvRestore.BorderBrush = Get-ThemeBrush('#FF7B4444')
$script:BtnDrvRestore.Add_Click({
    $r = Show-WpiMessage(
        ('Esto reinyecta drivers (.inf) desde una carpeta usando pnputil. Esta pensado para un equipo RECIEN reinstalado, usando una copia hecha con "Hacer copia de drivers". Continuar?'),
        'Restaurar drivers', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = 'Elige la carpeta con la copia de drivers (.inf)'
    try { $fb.UseDescriptionForTitle = $true } catch {}
    if ($fb.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $src = $fb.SelectedPath
    if (-not $src) { return }
    $srcEsc = $src -replace "'", "''"
    $code = ("W info ('Reinstalando drivers desde ' + '{0}' + ' ...'); pnputil /add-driver '{0}\*.inf' /subdirs /install 2>&1 | Out-Null; W ok 'Restauracion de drivers lanzada (revisa el log de pnputil).'" -f $srcEsc)
    Start-Worker -Mode 'tweaks' -Tweaks @(@{ Name = 'Restaurar drivers'; Code = $code })
})
$dv.Children.Add($script:BtnDrvRestore) | Out-Null

# Estado detectado
$script:GpuVendor = ''
$script:MoboQuery = ''

# ============================================================
# DETECCION DE HARDWARE UNIVERSAL (CIM/WMI + registro, sin instalar nada)
# Disenada para ser exacta en CUALQUIER PC: 1 o varias GPU, NVIDIA/AMD/
# Intel, dedicadas o integradas, portatiles con grafica hibrida y con
# adaptadores virtuales presentes. Todo con multiples metodos y fallbacks.
# ============================================================

# Formatea un numero respetando el idioma activo: en EN usa el punto decimal
# (InvariantCulture), en ES respeta la cultura del sistema (coma). Evita que la
# version inglesa muestre "4,20 GHz" o "16,0 GB" en un Windows en espanol.
function Format-WpiDec([string]$Format, [double]$Value) {
    $ci = if ($script:Lang -eq 'en') { [System.Globalization.CultureInfo]::InvariantCulture } else { [System.Globalization.CultureInfo]::CurrentCulture }
    return [string]::Format($ci, $Format, $Value)
}

# Formatea bytes a un texto de tamano legible (KB/MB/GB/TB), con separador decimal
# acorde al idioma (ver Format-WpiDec).
function Format-WpiSize {
    param([double]$Bytes)
    if ($Bytes -le 0) { return '' }
    if ($Bytes -ge 1PB) { return (Format-WpiDec '{0:N1} PB' ($Bytes/1PB)) }
    if ($Bytes -ge 1TB) { return (Format-WpiDec '{0:N1} TB' ($Bytes/1TB)) }
    $gb = $Bytes / 1GB
    if ($gb -ge 10)  { return (Format-WpiDec '{0:N0} GB' $gb) }
    if ($gb -ge 1)   { return (Format-WpiDec '{0:N1} GB' $gb) }
    $mb = $Bytes / 1MB
    return (Format-WpiDec '{0:N0} MB' $mb)
}

# Traduce la version de driver de Windows (p.ej. 32.0.16.1052) a la
# version comercial de NVIDIA (p.ej. 610.52), que es la que se ve en su
# web. Regla: ultimos 5 digitos de los dos ultimos bloques -> XXX.XX
function Get-NvidiaDriverVersion {
    param([string]$WinVer)
    try {
        $p = [string]$WinVer -split '\.'
        if ($p.Count -ge 2) {
            $digits = ($p[$p.Count-2] + $p[$p.Count-1]) -replace '\D',''
            if ($digits.Length -ge 5) {
                $l5 = $digits.Substring($digits.Length-5,5)
                return ('{0}.{1}' -f $l5.Substring(0,3), $l5.Substring(3,2))
            }
        }
    } catch {}
    return ''
}

# Lee la VRAM REAL de cada GPU desde el registro (qwMemorySize, 64 bits).
# Imprescindible: Win32_VideoController.AdapterRAM es de 32 bits y se topa
# en ~4 GB, por lo que una RTX 4090 (24 GB) saldria como "4 GB". Devuelve
# una tabla  nombre-de-driver -> bytes  y tambien  VEN&DEV -> bytes.
function Get-WpiVramMap {
    $byName = @{}; $byVenDev = @{}
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    try {
        # SilentlyContinue: algunas subclaves (p.ej. 'Properties') dan
        # "Acceso denegado"; no deben abortar la lectura de las 0000..NNNN.
        $subs = Get-ChildItem $base -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
        foreach ($s in $subs) {
            $p = Get-ItemProperty -Path $s.PSPath -ErrorAction SilentlyContinue
            if (-not $p -or -not $p.DriverDesc) { continue }
            $desc = [string]$p.DriverDesc
            [int64]$bytes = 0
            $qw = $p.'HardwareInformation.qwMemorySize'
            if ($qw) { try { $bytes = [int64]$qw } catch {} }
            if ($bytes -le 0) {
                $ms = $p.'HardwareInformation.MemorySize'
                if ($null -ne $ms) {
                    if ($ms -is [byte[]]) {
                        $buf = New-Object byte[] 8
                        for ($i=0; $i -lt [math]::Min(8,$ms.Length); $i++) { $buf[$i] = $ms[$i] }
                        try { $bytes = [System.BitConverter]::ToInt64($buf,0) } catch {}
                    } else { try { $bytes = [int64]$ms } catch {} }
                }
            }
            if ($bytes -gt 0) {
                if (-not $byName.ContainsKey($desc)) { $byName[$desc] = $bytes }
                $mid = [string]$p.MatchingDeviceId
                if ($mid -match 'VEN_([0-9A-Fa-f]{4}).*DEV_([0-9A-Fa-f]{4})') {
                    $k = ('{0}_{1}' -f $Matches[1], $Matches[2]).ToUpper()
                    if (-not $byVenDev.ContainsKey($k)) { $byVenDev[$k] = $bytes }
                }
            }
        }
    } catch {}
    return @{ ByName = $byName; ByVenDev = $byVenDev }
}

# Clasifica una GPU: vendor, tipo (dedicada/integrada/virtual) y VRAM.
function Get-WpiGpuInfo {
    param($Gpu, $VramMap)
    $nm  = [string]$Gpu.Name
    $pnp = [string]$Gpu.PNPDeviceID
    $info = [ordered]@{ Name=$nm; Vendor=''; Kind='dedicada'; Bytes=[int64]0;
                        Virtual=$false; Active=$false; Driver=[string]$Gpu.DriverVersion; Date=$null }

    # ¿Adaptador virtual? (Virtual Desktop, spacedesk, IddSample, RDP, etc.)
    if ($pnp -notmatch '^PCI\\') { $info.Virtual = $true }
    if ($nm -match 'Virtual|Basic Display|Basic Render|Remote Display|RDP|Citrix|Parsec|DameWare|spacedesk|IddSample|Meta |Oculus|Mirror') { $info.Virtual = $true }

    # Vendor: lo mas fiable es el VEN_ del PNPDeviceID; si no, por nombre.
    $ven = ''; $dev = ''
    if ($pnp -match 'VEN_([0-9A-Fa-f]{4})') { $ven = $Matches[1].ToUpper() }
    if ($pnp -match 'DEV_([0-9A-Fa-f]{4})') { $dev = $Matches[1].ToUpper() }
    switch ($ven) {
        '10DE' { $info.Vendor = 'NVIDIA' }
        '1002' { $info.Vendor = 'AMD' }
        '8086' { $info.Vendor = 'Intel' }
        default {
            if     ($nm -match 'NVIDIA|GeForce|RTX|GTX|Quadro|TITAN|Tesla') { $info.Vendor = 'NVIDIA' }
            elseif ($nm -match 'AMD|Radeon|FirePro|ATI')                    { $info.Vendor = 'AMD' }
            elseif ($nm -match 'Intel|Arc|UHD|Iris|HD Graphics')            { $info.Vendor = 'Intel' }
        }
    }

    # VRAM: registro primero (exacto); si no, AdapterRAM solo si NO esta topado.
    [int64]$bytes = 0
    if ($ven -and $dev -and $VramMap.ByVenDev.ContainsKey(($ven+'_'+$dev))) { $bytes = $VramMap.ByVenDev[($ven+'_'+$dev)] }
    elseif ($VramMap.ByName.ContainsKey($nm)) { $bytes = $VramMap.ByName[$nm] }
    elseif ($Gpu.AdapterRAM -and [int64]$Gpu.AdapterRAM -gt 0 -and [int64]$Gpu.AdapterRAM -lt 4000000000) { $bytes = [int64]$Gpu.AdapterRAM }
    $info.Bytes = $bytes

    # ¿Activa? (esta pintando una pantalla ahora mismo)
    if ($Gpu.CurrentHorizontalResolution -and $Gpu.CurrentHorizontalResolution -gt 0) { $info.Active = $true }

    # ¿Integrada o dedicada?
    if (-not $info.Virtual) {
        if ($nm -match 'RTX|GTX|Radeon RX|Radeon Pro|FirePro|Quadro|TITAN|Tesla|Arc A\d|Arc B\d|Arc Pro') { $info.Kind = 'dedicada' }
        elseif ($nm -match 'Radeon\(TM\) Graphics|Radeon Graphics|UHD Graphics|HD Graphics|Iris|Vega.*Graphics|Graphics$|integrated') { $info.Kind = 'integrada' }
        elseif ($bytes -ge 2GB) { $info.Kind = 'dedicada' }
        else { $info.Kind = 'integrada' }
    } else { $info.Kind = 'virtual' }

    try { if ($Gpu.DriverDate) { $info.Date = [System.Management.ManagementDateTimeConverter]::ToDateTime($Gpu.DriverDate) } } catch {
        try { $info.Date = [datetime]$Gpu.DriverDate } catch {}
    }
    return $info
}

function Get-HardwareReport {
    $rep = [ordered]@{}
    $gpuVendor = ''
    $script:HasSSD = $false
    $script:GpuPrimaryKind = ''

    # ---------- SISTEMA / EQUIPO ----------
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs0 = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $sl = @()
        $sl += ('{0} ({1})' -f $os.Caption.Trim(), $os.OSArchitecture)
        $modelo = (('{0} {1}' -f $cs0.Manufacturer, $cs0.Model)).Trim()
        if ($modelo -and $modelo -notmatch 'System manufacturer|System Product Name|To Be Filled|Default string|O\.E\.M\.|Not Applicable') { $sl += ((Tr 'Equipo') + (': {0}' -f $modelo)) }
        $rep[(Tr 'Sistema')] = $sl
    } catch {}

    # ---------- GPU ----------
    try {
        $vmap = Get-WpiVramMap
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop)
        $infos = @(); foreach ($g in $gpus) { $infos += (Get-WpiGpuInfo -Gpu $g -VramMap $vmap) }

        $reales  = @($infos | Where-Object { -not $_.Virtual })
        $virtual = @($infos | Where-Object { $_.Virtual })

        # GPU principal = mayor puntuacion (dedicada + activa + mas VRAM)
        $principal = $null; $best = -1
        foreach ($i in $reales) {
            $score = 0
            if ($i.Kind -eq 'dedicada') { $score += 100000 }
            if ($i.Active) { $score += 50000 }
            $score += [int]($i.Bytes / 1MB)
            if ($score -gt $best) { $best = $score; $principal = $i }
        }

        $glines = @()
        $orden = @($reales | Sort-Object @{E={ if ($_ -eq $principal) {0} elseif ($_.Kind -eq 'dedicada') {1} else {2} }}, @{E={ -$_.Bytes }})
        foreach ($i in $orden) {
            $tags = @()
            if ($i -eq $principal) { $tags += (Tr 'principal') }
            $tags += (Tr ([string]$i.Kind))
            if ($i.Active) { $tags += (Tr 'en uso') }
            $glines += ('{0}   [{1}]' -f $i.Name, ($tags -join ', '))
            $det = @()
            $vt = Format-WpiSize -Bytes $i.Bytes
            if ($vt) { $det += $(if ($i.Kind -eq 'integrada') { "$vt $(Tr 'asignada')" } else { "$vt VRAM" }) }
            elseif ($i.Kind -eq 'integrada') { $det += (Tr 'memoria compartida con la RAM') }
            $g0 = $gpus | Where-Object { [string]$_.Name -eq $i.Name } | Select-Object -First 1
            if ($g0 -and $g0.CurrentHorizontalResolution -gt 0) {
                $res = ('{0} x {1}' -f $g0.CurrentHorizontalResolution, $g0.CurrentVerticalResolution)
                if ($g0.CurrentRefreshRate -gt 0) { $res += (' @ {0} Hz' -f $g0.CurrentRefreshRate) }
                $det += $res
            }
            if ($det.Count) { $glines += ('   ' + ($det -join $script:SepText)) }
            $drvtxt = ('   driver {0}' -f $i.Driver)
            if ($i.Vendor -eq 'NVIDIA') {
                $nv = Get-NvidiaDriverVersion $i.Driver
                if ($nv) { $drvtxt += (' (NVIDIA {0})' -f $nv) } else { $drvtxt += ' (NVIDIA)' }
            } elseif ($i.Vendor) { $drvtxt += (' ({0})' -f $i.Vendor) }
            if ($i.Date)   {
                $drvtxt += ($script:SepText + ('{0}' -f $i.Date.ToString('dd/MM/yyyy')))
                $meses = [int]([math]::Floor((((Get-Date) - $i.Date).TotalDays) / 30.4))
                if ($i.Kind -eq 'dedicada' -and $meses -ge 4) { $drvtxt += ($script:SepText + ((Tr 'hace ~{0} meses: conviene revisar si hay uno mas nuevo') -f $meses)) }
            }
            $glines += $drvtxt
        }
        if ($virtual.Count) {
            $glines += ((Tr 'Adaptadores virtuales: {0}') -f (($virtual | ForEach-Object { $_.Name }) -join ', '))
        }
        if (-not $glines.Count) { $glines = @((Tr 'No se detectaron tarjetas graficas.')) }
        $rep[(Tr 'Tarjeta grafica (GPU)')] = $glines

        if ($principal) { $gpuVendor = $principal.Vendor; $script:GpuPrimaryKind = $principal.Kind }
        elseif ($reales.Count) { $gpuVendor = $reales[0].Vendor }
    } catch { $rep[(Tr 'Tarjeta grafica (GPU)')] = @((Tr 'No se pudo leer la informacion de la GPU.')) }

    # ---------- CPU ----------
    try {
        $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)[0]
        $cl = @(); $cl += $cpu.Name.Trim()
        $d2 = @()
        $d2 += ((Tr '{0} nucleos / {1} hilos') -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
        if ($cpu.MaxClockSpeed -gt 0) { $d2 += (Format-WpiDec '{0:N2} GHz' ($cpu.MaxClockSpeed/1000)) }
        if ($cpu.SocketDesignation) { $d2 += ('socket {0}' -f $cpu.SocketDesignation) }
        if ($cpu.L3CacheSize -gt 0) { $d2 += ((Tr 'cache L3 {0}') -f (Format-WpiSize -Bytes ($cpu.L3CacheSize*1KB))) }
        $cl += ('   ' + ($d2 -join $script:SepText))
        $rep[(Tr 'Procesador (CPU)')] = $cl
    } catch {}

    # ---------- RAM ----------
    try {
        $mods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
        if ($mods.Count) {
            [int64]$tot = 0; foreach ($m in $mods) { $tot += [int64]$m.Capacity }
            $tipo = ''
            $smb = [int]($mods[0].SMBIOSMemoryType)
            switch ($smb) { 20 {$tipo='DDR'} 21 {$tipo='DDR2'} 24 {$tipo='DDR3'} 26 {$tipo='DDR4'} 34 {$tipo='DDR5'} default {$tipo=''} }
            $clk = ($mods | ForEach-Object { if ($_.ConfiguredClockSpeed -gt 0) { $_.ConfiguredClockSpeed } else { $_.Speed } } | Sort-Object -Descending | Select-Object -First 1)
            $jedec = ($mods | ForEach-Object { $_.Speed } | Sort-Object -Descending | Select-Object -First 1)
            # Velocidad "nominal" grabada en el part number (p.ej. ...5600...)
            $ratedPart = 0
            foreach ($m in $mods) {
                $pn = [string]$m.PartNumber
                $mm = [regex]::Matches($pn, '\d{4}')
                foreach ($x in $mm) { $v = [int]$x.Value; if ($v -ge 2000 -and $v -le 9000 -and $v -gt $ratedPart) { $ratedPart = $v } }
            }
            $slots = 0; try { $slots = (Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction Stop | Measure-Object -Property MemoryDevices -Sum).Sum } catch {}
            $fab = (($mods | ForEach-Object { ([string]$_.Manufacturer).Trim() } | Where-Object { $_ -and $_ -ne 'Unknown' } | Select-Object -Unique) -join ', ')
            $linea1 = (Format-WpiSize -Bytes $tot)
            if ($tipo) { $linea1 += " $tipo" }
            $rl = @($linea1)
            $d3 = @()
            if ($clk) {
                $velTxt = ('{0} MHz' -f $clk)
                if ($jedec -and $clk -gt ($jedec + 100)) { $velTxt += (' (' + (Tr 'perfil XMP/EXPO activo') + ')') }
                elseif ($ratedPart -gt 0 -and $clk -lt ($ratedPart - 100)) { $velTxt += (' - ' + ((Tr 'XMP/EXPO sin activar, nominal {0} MHz') -f $ratedPart)) }
                $d3 += $velTxt
            }
            if ($slots -gt 0) { $d3 += ((Tr '{0} / {1} modulos') -f $mods.Count, $slots) } else { $d3 += ((Tr '{0} modulos') -f $mods.Count) }
            if ($fab) { $d3 += $fab }
            if ($d3.Count) { $rl += ('   ' + ($d3 -join $script:SepText)) }
            $rep[(Tr 'Memoria RAM')] = $rl
        } else { throw (Tr 'sin modulos') }
    } catch {
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $rep[(Tr 'Memoria RAM')] = @((Format-WpiSize -Bytes $cs.TotalPhysicalMemory) + ' ' + (Tr 'totales'))
        } catch {}
    }

    # ---------- PLACA BASE ----------
    try {
        $mb = Get-CimInstance Win32_BaseBoard -ErrorAction Stop
        $rep[(Tr 'Placa base')] = @((('{0} {1}' -f $mb.Manufacturer, $mb.Product)).Trim())
        $script:MoboQuery = ('{0} {1} drivers' -f $mb.Manufacturer, $mb.Product)
    } catch {}

    # ---------- BIOS / UEFI ----------
    try {
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $bl = ('{0}{1}{2} {3}' -f $bios.Manufacturer, $script:SepText, (Tr 'version'), ($bios.SMBIOSBIOSVersion))
        try { if ($bios.ReleaseDate) { $bl += ($script:SepText + ('{0}' -f ([System.Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)).ToString('dd/MM/yyyy'))) } } catch {}
        $rep['BIOS / UEFI'] = @($bl)
    } catch {}

    # ---------- DISCOS ----------
    try {
        $busOrder = @{ 'NVMe'=0; 'RAID'=1; 'SATA'=2; 'SAS'=3; 'SCSI'=4; 'ATA'=5; 'USB'=6 }
        $pd = @(Get-PhysicalDisk -ErrorAction Stop)
        $dl = @()
        $pdSorted = $pd | Sort-Object @{E={ $b=[string]$_.BusType; if ($busOrder.ContainsKey($b)){$busOrder[$b]}else{9} }}, @{E={ -([int64]$_.Size) }}
        foreach ($d in $pdSorted) {
            $media = [string]$d.MediaType
            $bus = [string]$d.BusType
            $tag = ''
            if ($media -eq 'SSD' -or $media -eq 'HDD') { $tag = $media }
            elseif ($media -match 'SCM') { $tag = 'SSD' }
            if ($bus) { if ($tag) { $tag = "$tag $bus" } else { $tag = $bus } }
            if ($bus -eq 'USB') { $tag = ($tag + ' (' + (Tr 'externo') + ')').Trim() }
            $hs = [string]$d.HealthStatus
            if ($hs -eq 'Healthy') { if ($tag) { $tag += ($script:SepText + (Tr 'salud OK')) } else { $tag = (Tr 'salud OK') } }
            elseif ($hs) { if ($tag) { $tag += ($script:SepText + ((Tr 'SALUD: {0}') -f $hs)) } else { $tag = ((Tr 'SALUD: {0}') -f $hs) } }
            if ($media -eq 'SSD' -or $media -match 'SCM') { $script:HasSSD = $true }
            $nombre = ([string]$d.FriendlyName).Trim()
            $dl += ('{0}{1}{2}{3}' -f $nombre, $script:SepText, (Format-WpiSize -Bytes ([double]$d.Size)), $(if($tag){$script:SepText + $tag}else{''}))
            # Detalle SMART (solo si el disco expone contadores de fiabilidad)
            try {
                $rc = $d | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                if ($rc) {
                    $sd = @()
                    if ($null -ne $rc.Wear -and $rc.Wear -gt 0) { $sd += ((Tr 'desgaste {0}%') -f $rc.Wear) }
                    if ($rc.Temperature -gt 0) { $sd += ('{0} C' -f $rc.Temperature) }
                    if ($rc.PowerOnHours -gt 0) { $sd += ((Tr '{0} h encendido') -f $rc.PowerOnHours) }
                    if ($sd.Count) { $dl += ('   ' + ($sd -join $script:SepText)) }
                }
            } catch {}
        }
        if ($dl.Count) { $rep[(Tr 'Discos')] = $dl }
    } catch {
        try {
            $disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop)
            $dl = @()
            foreach ($d in $disks) { $dl += ('{0}{1}{2}' -f $d.Model, $script:SepText, (Format-WpiSize -Bytes ([double]$d.Size))) }
            if ($dl.Count) { $rep[(Tr 'Discos')] = $dl }
        } catch {}
    }

    # ---------- RED ----------
    try {
        $na = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true })
        $nl = @()
        foreach ($net in $na) {
            $tipo = 'Ethernet'
            if ([string]$net.PhysicalMediaType -match '802\.11|Wireless|Wi-?Fi') { $tipo = 'Wi-Fi' }
            $vel = [string]$net.LinkSpeed
            $nl += ('{0}{1}{2}{1}{3}' -f $net.InterfaceDescription, $script:SepText, $tipo, $vel)
        }
        if ($nl.Count) { $rep['Red'] = $nl }
    } catch {
        try {
            $nets = @(Get-CimInstance Win32_NetworkAdapter -ErrorAction Stop | Where-Object { $_.PhysicalAdapter -and $_.NetEnabled })
            $nl = @(); foreach ($net in $nets) { $nl += ([string]$net.Name) }
            if ($nl.Count) { $rep['Red'] = $nl }
        } catch {}
    }

    # ---------- BATERIA (solo portatiles) ----------
    try {
        $bat = @(Get-CimInstance Win32_Battery -ErrorAction Stop)
        if ($bat.Count) {
            $bl = @()
            $b0 = $bat[0]
            $estado = switch ([int]$b0.BatteryStatus) {
                1 {Tr 'descargando'} 2 {Tr 'enchufado (CA)'} 3 {Tr 'cargada'} 4 {Tr 'baja'} 5 {Tr 'critica'}
                6 {Tr 'cargando'} 7 {Tr 'cargando (alta)'} 8 {Tr 'cargando (baja)'} 9 {Tr 'cargando (critica)'} default {''}
            }
            $l = ((Tr '{0}% de carga') -f $b0.EstimatedChargeRemaining)
            if ($estado) { $l += ($script:SepText + ('{0}' -f $estado)) }
            $bl += $l
            # Salud = capacidad a plena carga / capacidad de diseno
            try {
                $design = (@(Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop)[0]).DesignedCapacity
                $full   = (@(Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop)[0]).FullChargedCapacity
                if ($design -gt 0 -and $full -gt 0) {
                    $salud = [math]::Round(($full/$design)*100)
                    $bl += ((Tr 'salud de la bateria: {0}%{1}{2} de {3} mWh de diseno') -f $salud, $script:SepText, $full, $design)
                }
            } catch {}
            $rep[(Tr 'Bateria')] = $bl
        }
    } catch {}

    # ---------- PANTALLAS ----------
    try {
        # Codigos PnP de 3 letras (EDID) -> nombre de fabricante legible.
        $pnpVendor = @{ 'AUS'='ASUS'; 'ACR'='Acer'; 'SAM'='Samsung'; 'GSM'='LG'; 'LGD'='LG';
            'DEL'='Dell'; 'BNQ'='BenQ'; 'AOC'='AOC'; 'MSI'='MSI'; 'HPN'='HP'; 'HWP'='HP';
            'LEN'='Lenovo'; 'PHL'='Philips'; 'VSC'='ViewSonic'; 'GIG'='Gigabyte'; 'NEC'='NEC';
            'APP'='Apple'; 'SNY'='Sony'; 'HEI'='Hisense'; 'TCL'='TCL'; 'IVM'='iiyama'; 'ENC'='Eizo' }
        $mons = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop)
        $ml = @()
        foreach ($mon in $mons) {
            $fab = ''; $nombre = ''
            try { if ($mon.ManufacturerName) { $fab = ((($mon.ManufacturerName | Where-Object { $_ -gt 0 }) | ForEach-Object { [char]$_ }) -join '') } } catch {}
            try { if ($mon.UserFriendlyName) { $nombre = ((($mon.UserFriendlyName | Where-Object { $_ -gt 0 }) | ForEach-Object { [char]$_ }) -join '') } } catch {}
            if ($fab -and $pnpVendor.ContainsKey($fab.ToUpper())) { $fab = $pnpVendor[$fab.ToUpper()] }
            $txt = (('{0} {1}' -f $fab, $nombre)).Trim()
            if ($txt) { $ml += $txt }
        }
        if ($ml.Count) { $rep['Pantallas'] = $ml }
    } catch {}

    # ---------- RECOMENDACIONES SEGUN HARDWARE ----------
    $recs = New-Object System.Collections.Specialized.OrderedDictionary
    if ($gpuVendor -eq 'NVIDIA') { $recs['beeradmoore.dlss-swapper'] = 'cambiar/actualizar la version de DLSS en tus juegos (GPU NVIDIA)' }
    if ($script:GpuPrimaryKind -eq 'dedicada') {
        $recs['TechPowerUp.GPU-Z'] = 'ver al detalle el chip, relojes y sensores de tu GPU'
        $recs['Guru3D.Afterburner'] = 'overclock, curvas de ventilador y limites de tu GPU'
        $recs['Guru3D.RTSS'] = 'overlay de FPS y limitador de framerate (RivaTuner)'
    }
    if ($script:HasSSD) { $recs['CrystalDewWorld.CrystalDiskInfo'] = 'vigilar la salud SMART y temperatura de tus discos' }
    $recs['REALiX.HWiNFO'] = 'monitor completo de sensores (CPU/GPU/placa) en tiempo real'
    $script:HwRecommendations = $recs

    # ---------- SENSORES Y TEMPERATURAS (C5) ----------
    try {
        $sl = @()
        try {
            $tz = @(Get-CimInstance -Namespace 'root/WMI' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop)
            foreach ($z in $tz) {
                if ($z.CurrentTemperature -gt 0) {
                    $cgr = [math]::Round(($z.CurrentTemperature / 10) - 273.15, 1)
                    if ($cgr -gt 0 -and $cgr -lt 130) { $sl += ('Zona termica del sistema (ACPI): {0} C' -f $cgr) }
                }
            }
        } catch {}
        try {
            foreach ($pd in @(Get-PhysicalDisk -ErrorAction Stop)) {
                $rc = $pd | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                if ($rc -and $rc.Temperature -gt 0) { $sl += ('Disco "{0}": {1} C' -f $pd.FriendlyName, $rc.Temperature) }
            }
        } catch {}
        try {
            foreach ($b in @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)) {
                if ($b.EstimatedChargeRemaining) { $sl += ('Bateria: {0}% de carga' -f $b.EstimatedChargeRemaining) }
            }
        } catch {}
        if ($sl.Count -eq 0) { $sl += 'No se pudieron leer sensores por WMI (depende del equipo y de los permisos; algunos requieren admin).' }
        $sl += 'Para sensores completos (CPU/GPU por nucleo, ventiladores, voltajes) en tiempo real, instala HWiNFO o HWMonitor desde el catalogo (categoria Monitorizacion).'
        $rep['Sensores y temperaturas'] = $sl
    } catch {}

    $script:GpuVendor = $gpuVendor
    return $rep
}

function Build-GpuActions {
    $script:GpuActionPanel.Children.Clear()
    $vendor = [string]$script:GpuVendor
    $lbl = New-Object Windows.Controls.TextBlock
    if ($vendor) { $lbl.Text = ((Tr 'GPU detectada: {0}.  Para tener el driver al dia, instala su app oficial:') -f $vendor) }
    else         { $lbl.Text = (Tr 'GPU no identificada. Elige tu fabricante para descargar el driver oficial:') }
    $lbl.Foreground = Get-ThemeBrush('#FFE6E6EC'); $lbl.FontSize = 12.5
    $lbl.TextWrapping = 'Wrap'; $lbl.Margin = New-Object Windows.Thickness(2,8,0,6)
    $script:GpuActionPanel.Children.Add($lbl) | Out-Null

    # Crea el boton de descarga oficial de un fabricante. $primary lo resalta
    # (es el detectado). Las apps NVIDIA/AMD no estan en winget (van por web);
    # Intel si esta en winget.
    $mkVendorBtn = {
        param($v, $primary)
        $b = New-Object Windows.Controls.Button
        switch ($v) {
            'NVIDIA' { $b.Content = (Tr 'Descargar NVIDIA App (web oficial)'); $b.Tag = 'nv' }
            'AMD'    { $b.Content = (Tr 'Descargar AMD Software: Adrenalin (web oficial)'); $b.Tag = 'amd' }
            'Intel'  { $b.Content = (Tr 'Instalar Intel Driver & Support Assistant (winget)'); $b.Tag = 'intel' }
        }
        if ($primary) {
            $accent = if ($v -eq 'AMD') { '#FF5A1F1F' } else { '#FF1F4F1F' }
            $brd    = if ($v -eq 'AMD') { '#FFE0454E' } else { '#FF6FE08F' }
            $b.Background = Get-ThemeBrush($accent); $b.BorderBrush = Get-ThemeBrush($brd); $b.FontWeight = 'Bold'
        } else {
            $b.Background = Get-ThemeBrush('#FF20202E'); $b.BorderBrush = Get-ThemeBrush('#FF3A3A4A')
        }
        $b.Margin = New-Object Windows.Thickness(0,0,8,6)
        $b.Add_Click({
            switch ([string]$this.Tag) {
                'nv'    { try { Start-Process 'https://www.nvidia.com/en-us/software/nvidia-app/' } catch {} }
                'amd'   { try { Start-Process 'https://www.amd.com/en/support/download/drivers.html' } catch {} }
                'intel' { Start-Worker -Mode 'install' -Ids @('Intel.IntelDriverAndSupportAssistant') }
            }
        })
        return $b
    }

    # Fila principal: app del fabricante detectado (resaltada) + su web de drivers.
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'
    if ($vendor -in @('NVIDIA','AMD','Intel')) { $row.Children.Add((& $mkVendorBtn $vendor $true)) | Out-Null }
    $bWeb = New-Object Windows.Controls.Button
    $bWeb.Content = ((Tr 'Abrir web oficial de drivers ({0})') -f $(if ($vendor) { $vendor } else { 'NVIDIA / AMD / Intel' }))
    $bWeb.Margin = New-Object Windows.Thickness(0,0,8,6)
    $bWeb.Add_Click({
        $u = switch ($script:GpuVendor) {
            'NVIDIA' { 'https://www.nvidia.com/en-us/geforce/drivers/' }
            'AMD'    { 'https://www.amd.com/en/support' }
            'Intel'  { 'https://www.intel.com/content/www/us/en/download/18002/intel-driver-support-assistant.html' }
            default  { 'https://www.google.com/search?q=descargar+driver+grafica' }
        }
        try { Start-Process $u } catch {}
    })
    $row.Children.Add($bWeb) | Out-Null
    $script:GpuActionPanel.Children.Add($row) | Out-Null

    # Fila SIEMPRE presente: el resto de fabricantes, para que AMD/NVIDIA/Intel
    # esten disponibles aunque la deteccion no coincida, falle o haya 2 GPUs.
    $others = @('NVIDIA','AMD','Intel') | Where-Object { $_ -ne $vendor }
    if (@($others).Count -gt 0) {
        $lblOth = New-Object Windows.Controls.TextBlock
        $lblOth.Text = (Tr 'Otros fabricantes (siempre disponibles):')
        $lblOth.Foreground = Get-ThemeBrush('#FF8A8A95'); $lblOth.FontSize = 11.5
        $lblOth.Margin = New-Object Windows.Thickness(2,6,0,3)
        $script:GpuActionPanel.Children.Add($lblOth) | Out-Null
        $rowOth = New-Object Windows.Controls.WrapPanel; $rowOth.Orientation = 'Horizontal'
        foreach ($ov in $others) { $rowOth.Children.Add((& $mkVendorBtn $ov $false)) | Out-Null }
        $script:GpuActionPanel.Children.Add($rowOth) | Out-Null
    }
    $notaTxt = ''
    if ($script:GpuVendor -eq 'AMD')    { $notaTxt = (Tr 'AMD distribuye su software Adrenalin desde su web (no por winget); usa el boton de arriba.') }
    elseif ($script:GpuVendor -eq 'NVIDIA') { $notaTxt = (Tr 'La NVIDIA App (sustituye a GeForce Experience) se descarga de la web oficial; instala el driver "Game Ready" o "Studio" desde ella.') }
    if ($notaTxt) {
        $n = New-Object Windows.Controls.TextBlock
        $n.Text = $notaTxt
        $n.Foreground = Get-ThemeBrush('#FF8A8A95'); $n.FontSize = 11.5
        $n.TextWrapping = 'Wrap'; $n.Margin = New-Object Windows.Thickness(2,6,0,0)
        $script:GpuActionPanel.Children.Add($n) | Out-Null
    }
}

function Build-HwRecommendations {
    $script:RecoPanel.Children.Clear()
    if (-not $script:HwRecommendations -or $script:HwRecommendations.Count -eq 0) { return }
    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = 'RECOMENDADO PARA TU EQUIPO'
    $hdr.FontSize = 13; $hdr.FontWeight = 'Bold'
    $hdr.Foreground = Get-ThemeBrush('#FF00E5FF')
    $hdr.Margin = New-Object Windows.Thickness(2,16,0,4)
    $script:RecoPanel.Children.Add($hdr) | Out-Null
    $sub = New-Object Windows.Controls.TextBlock
    $sub.Text = 'Apps gratuitas del catalogo utiles para el hardware que se ha detectado:'
    $sub.Foreground = Get-ThemeBrush('#FF8A8A95'); $sub.FontSize = 11.5
    $sub.TextWrapping = 'Wrap'; $sub.Margin = New-Object Windows.Thickness(2,0,0,4)
    $script:RecoPanel.Children.Add($sub) | Out-Null
    foreach ($id in $script:HwRecommendations.Keys) {
        $nombre = ($catalog | Where-Object { $_.Id -eq $id } | Select-Object -First 1).Name
        if (-not $nombre) { $nombre = $id }
        $t = New-Object Windows.Controls.TextBlock
        $bullet = [string][char]0x2022
        $t.Text = ('{0} {1} — {2}' -f $bullet, $nombre, $script:HwRecommendations[$id])
        $t.Foreground = Get-ThemeBrush('#FFCFCFD8'); $t.FontSize = 12.5
        $t.TextWrapping = 'Wrap'; $t.Margin = New-Object Windows.Thickness(6,1,0,0)
        $script:RecoPanel.Children.Add($t) | Out-Null
    }
    $b = New-Object Windows.Controls.Button
    $b.Content = 'Marcar estas apps en el catalogo'
    $b.HorizontalAlignment = 'Left'; $b.Margin = New-Object Windows.Thickness(2,8,0,0)
    $b.Background = Get-ThemeBrush('#FF13414F'); $b.BorderBrush = Get-ThemeBrush('#FF76E0FF')
    $b.Add_Click({
        $ids = @($script:HwRecommendations.Keys)
        $n = 0
        foreach ($c in $script:Checks) { if ($ids -contains [string]$c.Tag) { $c.IsChecked = $true; $n++ } }
        try { Update-Count } catch {}
        try { $script:StatusText.Text = ((Tr '{0} apps recomendadas marcadas. Ve al catalogo, revisa y pulsa INSTALAR.') -f $n) } catch {}
    })
    $script:RecoPanel.Children.Add($b) | Out-Null
}

function Build-HardwareUI {
    $script:HwReportPanel.Children.Clear()
    $rep = Get-HardwareReport
    $txt = New-Object System.Text.StringBuilder
    [void]$txt.AppendLine('== Informe de hardware (WPI Moderno) ==')
    foreach ($sec in $rep.Keys) {
        $card = New-Object Windows.Controls.Border
        $card.Background = Get-ThemeBrush('#FF15151F'); $card.BorderBrush = Get-ThemeBrush('#FF2C2C3A')
        $card.BorderThickness = New-Object Windows.Thickness(1); $card.CornerRadius = New-Object Windows.CornerRadius(11)
        $card.Margin = New-Object Windows.Thickness(0,6,0,0); $card.Padding = New-Object Windows.Thickness(13,8,13,9)
        $sp = New-Object Windows.Controls.StackPanel
        $h = New-Object Windows.Controls.TextBlock
        $h.Text = $sec; $h.FontWeight = 'Bold'; $h.FontSize = 13
        $h.Foreground = Get-ThemeBrush('#FF76E0FF')
        $sp.Children.Add($h) | Out-Null
        [void]$txt.AppendLine(''); [void]$txt.AppendLine('[' + $sec + ']')
        foreach ($linea in $rep[$sec]) {
            $t = New-Object Windows.Controls.TextBlock
            $t.Text = $linea; $t.Foreground = Get-ThemeBrush('#FFCFCFD8')
            $t.FontSize = 12.5; $t.TextWrapping = 'Wrap'; $t.Margin = New-Object Windows.Thickness(4,1,0,0)
            $sp.Children.Add($t) | Out-Null
            [void]$txt.AppendLine($linea)
        }
        $card.Child = $sp
        $script:HwReportPanel.Children.Add($card) | Out-Null
    }
    $script:HwReportText = $txt.ToString()
    Build-GpuActions
    Build-HwRecommendations
}

# ---- Sidebar (GUI-PREMIUM: agrupada por bloques con cabeceras no seleccionables) ----
function Add-SideHeader([string]$Text, [string]$ColorHex) {
    $it = New-Object Windows.Controls.ListBoxItem
    $bd = New-Object Windows.Controls.Border
    $bd.Background = Get-ThemeBrush('#FF1C1C2A')
    $bd.BorderBrush = Get-ThemeBrush($ColorHex)
    $bd.BorderThickness = New-Object Windows.Thickness(4,0,0,0)
    $bd.CornerRadius = New-Object Windows.CornerRadius(5)
    $bd.Margin = New-Object Windows.Thickness(0,12,0,2)
    $bd.Padding = New-Object Windows.Thickness(9,5,9,5)
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = 10.5; $tb.FontWeight = 'Bold'
    $tb.Foreground = Get-ThemeBrush($ColorHex)
    $bd.Child = $tb
    $it.Content = $bd
    $it.IsEnabled = $false
    $it.Focusable = $false
    [void]$script:SideList.Items.Add($it)
    $script:SideMap += '@HDR'
}
$script:SideMap = @()

Add-SideHeader (T 'blk_inicio') $Theme.Maintain
[void]$script:SideList.Items.Add((T 'nav_quick'))
$script:SideMap += '@QUICKSTART'
[void]$script:SideList.Items.Add((T 'nav_find'))
$script:SideMap += '@FINDALL'

Add-SideHeader (T 'blk_instalar') $Theme.Install
[void]$script:SideList.Items.Add(('{0}  ({1})' -f (T 'nav_allapps'), @($catalog).Count))
$script:SideMap += '@ALL'
foreach ($cat in $cats) {
    $n = @($catalog | Where-Object { $_.Cat -eq $cat }).Count
    [void]$script:SideList.Items.Add(('{0}  ({1})' -f (Tr $cat), $n))
    $script:SideMap += $cat
}
[void]$script:SideList.Items.Add((T 'nav_search'))
$script:SideMap += '@SEARCH'
[void]$script:SideList.Items.Add((T 'nav_snapshot'))
$script:SideMap += '@SNAPSHOT'
[void]$script:SideList.Items.Add((T 'nav_upgrades'))
$script:SideMap += '@UPGRADES'

Add-SideHeader (T 'blk_optimizar') $Theme.Optimize
[void]$script:SideList.Items.Add((T 'nav_tweaks'))
$script:SideMap += '@TWEAKS'
[void]$script:SideList.Items.Add((T 'nav_winupdate'))
$script:SideMap += '@WINUPDATE'

Add-SideHeader (T 'blk_limpiar') $Theme.Clean
[void]$script:SideList.Items.Add((T 'nav_debloat'))
$script:SideMap += '@DEBLOAT'

Add-SideHeader (T 'blk_mantener') $Theme.Maintain
[void]$script:SideList.Items.Add((T 'nav_repair'))
$script:SideMap += '@REPAIR'
[void]$script:SideList.Items.Add((T 'nav_features'))
$script:SideMap += '@FEATURES'
[void]$script:SideList.Items.Add((T 'nav_drivers'))
$script:SideMap += '@DRIVERS'

Add-SideHeader (T 'blk_iso') $Theme.Iso
[void]$script:SideList.Items.Add((T 'nav_createiso'))
$script:SideMap += '@CREATEISO'

Add-SideHeader (T 'blk_info') $Theme.Info
[void]$script:SideList.Items.Add((T 'nav_summary'))
$script:SideMap += '@SUMMARY'
[void]$script:SideList.Items.Add(('{0}  ({1})' -f (T 'nav_guides'), $Guides.Count))
$script:SideMap += '@GUIDES'
[void]$script:SideList.Items.Add((T 'nav_logs'))
$script:SideMap += '@LOGVIEWER'

$script:SideAllIndex = $script:SideMap.IndexOf('@ALL')
if ($script:SideAllIndex -lt 0) { $script:SideAllIndex = 1 }
$script:QuickIndex = $script:SideMap.IndexOf('@QUICKSTART')
if ($script:QuickIndex -ge 0) { $script:SideList.SelectedIndex = $script:QuickIndex } else { $script:SideList.SelectedIndex = $script:SideAllIndex }

# ---- Filtro combinado: categoria del sidebar + buscador ----
$script:search = $window.FindName('SearchBox')
if ($script:search) {
    try { $script:search.ToolTip = if ($script:Lang -eq 'en') { 'Search everything: apps, tweaks, bloatware and Windows features.' } else { 'Busca en todo: apps, tweaks, bloatware y caracteristicas de Windows.' } } catch {}
}
function Get-WpiRegValue {
    param([string]$Path, [string]$Name)
    try { return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

# Detectores de estado por NOMBRE de tweak (solo lectura). Devuelven $true
# si el tweak ya esta aplicado en este PC. Si una clave no existe, el valor
# es $null y la comparacion da $false (= "no aplicado"), que es lo correcto.
$TweakDetectors = @{
    'Plan de energia Maximo Rendimiento' = @'
@((powercfg /getactivescheme 2>$null) -match '8c5e7fda|e9a42b02|ltimate').Count -gt 0
'@
    'Desactivar hibernacion (libera hiberfil.sys)' = @'
(Get-WpiRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -eq 0
'@
    'Desactivar telemetria innecesaria' = @'
(Get-WpiRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry') -eq 0
'@
    'Desactivar Bing, sugerencias y apps promocionadas' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled') -eq 0
'@
    'Desactivar historial de actividad (Timeline)' = @'
(Get-WpiRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed') -eq 0
'@
    'Quitar anuncios de la pantalla de bloqueo e Inicio' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenOverlayEnabled') -eq 0
'@
    'Desactivar sugerencias en Configuracion' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled') -eq 0
'@
    'Desactivar Copilot por politica' = @'
(Get-WpiRegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot') -eq 1
'@
    'Desactivar analisis de IA / Recall' = @'
(Get-WpiRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis') -eq 1
'@
    'Desactivar notificaciones del sistema' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled') -eq 0
'@
    'Explorador: extensiones y archivos ocultos visibles' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt') -eq 0
'@
    'Menu contextual clasico (Windows 11)' = @'
Test-Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
'@
    'Barra de tareas alineada a la izquierda (Windows 11)' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl') -eq 0
'@
    'Mostrar segundos en el reloj de la barra' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSecondsInSystemClock') -eq 1
'@
    'Quitar el boton de Widgets' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa') -eq 0
'@
    'Quitar el boton de Chat/Teams de la barra' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn') -eq 0
'@
    'Quitar el boton Vista de tareas' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton') -eq 0
'@
    'Anadir "Finalizar tarea" al boton derecho de la barra' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask') -eq 1
'@
    'Aceleracion de GPU por hardware (HAGS)' = @'
(Get-WpiRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode') -eq 2
'@
    'Ajustar efectos visuales para mejor rendimiento' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting') -eq 2
'@
    'Menus instantaneos (sin retardo)' = @'
[string](Get-WpiRegValue 'HKCU:\Control Panel\Desktop' 'MenuShowDelay') -eq '0'
'@
    'Activar restauracion del sistema en C:' = @'
[int](Get-WpiRegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'RPSessionInterval') -ge 1
'@
    'Desactivar ejecucion automatica de USB/medios' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun') -eq 255
'@
    'Optimizar red para juegos/streaming' = @'
(Get-WpiRegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness') -eq 0
'@
    'Activar Modo Juego (Game Mode)' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -eq 1
'@
    'Desactivar Game Bar y grabacion en segundo plano' = @'
(Get-WpiRegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled') -eq 0
'@
    'Desactivar aceleracion del raton (precision para juegos)' = @'
[string](Get-WpiRegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed') -eq '0'
'@
    'Desactivar Inicio rapido (Fast Startup)' = @'
(Get-WpiRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled') -eq 0
'@
    'Mostrar mensajes detallados al iniciar/apagar' = @'
(Get-WpiRegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'VerboseStatus') -eq 1
'@
    'Acelerar el apagado del sistema' = @'
[string](Get-WpiRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout') -eq '2000'
'@
    'Desactivar Cortana' = @'
(Get-WpiRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana') -eq 0
'@
    'Desactivar seguimiento de ubicacion' = @'
[string](Get-WpiRegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value') -eq 'Deny'
'@
    'Desactivar apps en segundo plano' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled') -eq 1
'@
    'Activar tema oscuro de Windows' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme') -eq 0
'@
    'Desactivar transparencia (rendimiento)' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency') -eq 0
'@
    'Quitar el cuadro de busqueda de la barra' = @'
(Get-WpiRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode') -eq 0
'@
    'Desactivar la pantalla de bloqueo' = @'
(Get-WpiRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreen') -eq 1
'@
    'Desactivar teclas especiales (Sticky/Filter/Toggle)' = @'
[string](Get-WpiRegValue 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags') -eq '506'
'@
    'Desactivar la indexacion de busqueda (Windows Search)' = @'
@(Get-Service WSearch -ErrorAction SilentlyContinue | Where-Object { $_.StartType -eq 'Disabled' }).Count -gt 0
'@
}

# Escanea (solo lectura) que tweaks estan aplicados y actualiza la UI.
function Detect-TweakStates {
    $applied = 0; $total = 0; $checkable = 0
    foreach ($cb in $script:TweakChecks) {
        $t = $cb.Tag; $name = [string]$t.Name
        $lbl = $script:TweakStatusLabels[$name]
        if (-not $lbl) { continue }
        $total++
        $reco = $(if ($t.Risk -eq 'Avanzado') { Tr 'avanzado: aplica solo si lo necesitas' } else { Tr 'recomendado para la mayoria' })
        if (-not $TweakDetectors.ContainsKey($name)) {
            $lbl.ToolTip = ('{0}   {1}   {2}' -f (Tr 'accion puntual (sin estado)'), $script:Sep, $reco)
            $lbl.Foreground = Get-ThemeBrush('#FF8A8A95')
            continue
        }
        $checkable++
        $ok = $true; $state = $false
        try { $state = [bool](Invoke-Expression $TweakDetectors[$name]) } catch { $ok = $false }
        if (-not $ok) {
            $lbl.ToolTip = ('{0}   {1}   {2}' -f (Tr 'no comprobable'), $script:Sep, $reco)
            $lbl.Foreground = Get-ThemeBrush('#FF6F6F7A')
        } elseif ($state) {
            $applied++
            $lbl.ToolTip = ('{0}   {1}   {2}' -f (Tr 'YA APLICADO'), $script:Sep, $reco)
            $lbl.Foreground = Get-ThemeBrush('#FF5CFF8F')
        } else {
            $lbl.ToolTip = ('{0}   {1}   {2}' -f (Tr 'no aplicado'), $script:Sep, $reco)
            $lbl.Foreground = Get-ThemeBrush('#FFB0B0BC')
        }
    }
    $script:TweakDetected = $true
    if ($script:TweakSummary) {
        $script:TweakSummary.Text = ((Tr 'Estado detectado en este PC: {0} de {1} ajustes ya aplicados ({2} comprobables, el resto son acciones puntuales). Verde = aplicado.') -f $applied, $total, $checkable)
    }
    # Banner breve y a color encima de los botones.
    if ($script:TweakStatusInline) {
        $pending = [math]::Max(0, $checkable - $applied)
        $dotc = [string][char]0x25CF
        $script:TweakStatusInline.Text = ''
        $script:TweakStatusInline.Inlines.Clear()
        $rA = New-Object Windows.Documents.Run -ArgumentList ('{0} {1} ' -f $dotc, $applied)
        $rA.Foreground = Get-ThemeBrush('#FF5CFF8F'); $rA.FontWeight = 'Bold'
        $rA2 = New-Object Windows.Documents.Run -ArgumentList (Tr 'aplicados')
        $rA2.Foreground = Get-ThemeBrush('#FF5CFF8F')
        $rSep = New-Object Windows.Documents.Run -ArgumentList '     '
        $rB = New-Object Windows.Documents.Run -ArgumentList ('{0} {1} ' -f $dotc, $pending)
        $rB.Foreground = Get-ThemeBrush('#FFB0B0BC'); $rB.FontWeight = 'Bold'
        $rB2 = New-Object Windows.Documents.Run -ArgumentList (Tr 'sin aplicar')
        $rB2.Foreground = Get-ThemeBrush('#FFB0B0BC')
        $rL = New-Object Windows.Documents.Run -ArgumentList ('      ' + (Tr 'verde = ya aplicado en tu PC'))
        $rL.Foreground = Get-ThemeBrush('#FF8A8A95'); $rL.FontSize = 11
        $script:TweakStatusInline.Inlines.Add($rA); $script:TweakStatusInline.Inlines.Add($rA2)
        $script:TweakStatusInline.Inlines.Add($rSep)
        $script:TweakStatusInline.Inlines.Add($rB); $script:TweakStatusInline.Inlines.Add($rB2)
        $script:TweakStatusInline.Inlines.Add($rL)
    }
    try { $script:StatusText.Text = ((Tr 'Tweaks: {0} de {1} ya aplicados.') -f $applied, $total) } catch {}
}

# Guarda el estado actual de los tweaks a un perfil JSON portable.
function Save-TweakProfile {
    if (-not $script:TweakDetected) { Detect-TweakStates }
    $items = @()
    foreach ($cb in $script:TweakChecks) {
        $t = $cb.Tag; $name = [string]$t.Name
        $st = 'action'
        if ($TweakDetectors.ContainsKey($name)) {
            $st = 'unknown'
            try { $st = $(if ([bool](Invoke-Expression $TweakDetectors[$name])) { 'applied' } else { 'notapplied' }) } catch { $st = 'unknown' }
        }
        $items += [ordered]@{ name = $name; cat = [string]$t.Cat; risk = [string]$t.Risk; state = $st }
    }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.FileName = ('perfil_tweaks_{0}.json' -f (Get-Date -Format 'yyyyMMdd'))
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Perfil de tweaks WPI (*.json)|*.json'
    if ($dlg.ShowDialog()) {
        $doc = [ordered]@{
            '$schema' = 'wpi-tweaks-profile-1.0'
            created   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
            machine   = $env:COMPUTERNAME
            wpi       = $WpiVersion
            tweaks    = $items
        }
        try {
            Set-WpiContent -Path $dlg.FileName -Value ($doc | ConvertTo-Json -Depth 5)
            Show-WpiMessage(((Tr "Perfil de tweaks guardado:`n{0}`n`nGuarda los ajustes ya aplicados en este PC. Cargalo en otro momento o en otro equipo para igualarlo.") -f $dlg.FileName), 'WPI Moderno') | Out-Null
        } catch { $script:StatusText.Text = (Tr 'No se pudo guardar el perfil.') }
    }
}

# Carga un perfil y MARCA los tweaks que el perfil tiene como aplicados,
# para que el usuario revise y pulse APLICAR. No aplica nada por si solo.
function Load-TweakProfile {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Perfil de tweaks WPI (*.json)|*.json|Todos (*.*)|*.*'
    if (-not $dlg.ShowDialog()) { return }
    $data = $null
    try { $data = Get-Content $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
        Show-WpiMessage('No se pudo leer el perfil (formato no valido).', 'WPI Moderno') | Out-Null; return
    }
    $want = @{}
    foreach ($e in @($data.tweaks)) { if ($e.name -and [string]$e.state -eq 'applied') { $want[[string]$e.name] = $true } }
    $n = 0; $already = 0
    foreach ($cb in $script:TweakChecks) {
        $name = [string]$cb.Tag.Name
        if ($want.ContainsKey($name)) {
            $cb.IsChecked = $true; $n++
            if ($TweakDetectors.ContainsKey($name)) { try { if ([bool](Invoke-Expression $TweakDetectors[$name])) { $already++ } } catch {} }
        } else { $cb.IsChecked = $false }
    }
    if (-not $script:TweakDetected) { Detect-TweakStates }
    try { Update-Count } catch {}
    Show-WpiMessage(((Tr "Perfil cargado.`n`nMarcados para aplicar: {0}`nDe esos, ya aplicados en este PC: {1}`n`nRevisa la seleccion y pulsa APLICAR SELECCIONADOS para igualar este equipo al perfil.") -f $n, $already), 'WPI Moderno', 'OK', 'Information') | Out-Null
}

# ---- DETECTOR DE ESTADO DE DEBLOAT (Appx) ----
# Escanea (solo lectura) que apps de la lista siguen instaladas en este PC.
# Mira tanto el usuario actual (Get-AppxPackage) como la imagen del sistema
# (Get-AppxProvisionedPackage), para no dar falsos "ya quitada".
function Detect-DebloatStates {
    $all = @()
    try { $all = @(Get-AppxPackage -ErrorAction SilentlyContinue) } catch {}
    $prov = @()
    try { $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue) } catch {}
    $installed = 0; $total = 0
    foreach ($cb in $script:DebloatChecks) {
        $pkg = [string]$cb.Tag
        $lbl = $script:DebloatStatusLabels[$pkg]
        if (-not $lbl) { continue }
        $total++
        $isUser = $false; $isProv = $false
        $patterns = Get-DebloatPatterns $pkg
        try { $isUser = (@($all  | Where-Object { $n = $_.Name;        @($patterns | Where-Object { $n -like $_ }).Count -gt 0 }).Count -gt 0) } catch {}
        try { $isProv = (@($prov | Where-Object { $dn = $_.DisplayName; @($patterns | Where-Object { $dn -like $_ }).Count -gt 0 }).Count -gt 0) } catch {}
        if ($isUser -or $isProv) {
            $installed++
            $extra = $(if ($isProv -and -not $isUser) { '  (solo en la imagen del sistema)' } elseif ($isProv) { '  (usuario + sistema)' } else { '' })
            $lbl.ToolTip = (Tr ('INSTALADA' + $extra))
            $lbl.Foreground = Get-ThemeBrush('#FFFFD166')
        } else {
            $lbl.ToolTip = (Tr 'ya quitada / no presente')
            $lbl.Foreground = Get-ThemeBrush('#FF5CFF8F')
        }
    }
    $script:DebloatDetected = $true
    if ($script:DebloatSummary) {
        $script:DebloatSummary.Text = ((Tr 'Estado en este PC: {0} de {1} apps de la lista siguen instaladas. Ambar = instalada (se puede quitar); verde = ya no esta.') -f $installed, $total)
    }
    # Banner breve y a color encima del boton.
    if ($script:DebloatStatusInline) {
        $gone = [math]::Max(0, $total - $installed)
        $dotc = [string][char]0x25CF
        $script:DebloatStatusInline.Text = ''
        $script:DebloatStatusInline.Inlines.Clear()
        $rA = New-Object Windows.Documents.Run -ArgumentList ('{0} {1} ' -f $dotc, $installed)
        $rA.Foreground = Get-ThemeBrush('#FFFFD166'); $rA.FontWeight = 'Bold'
        $rA2 = New-Object Windows.Documents.Run -ArgumentList (Tr 'instaladas (se pueden quitar)')
        $rA2.Foreground = Get-ThemeBrush('#FFFFD166')
        $rSep = New-Object Windows.Documents.Run -ArgumentList '     '
        $rB = New-Object Windows.Documents.Run -ArgumentList ('{0} {1} ' -f $dotc, $gone)
        $rB.Foreground = Get-ThemeBrush('#FF5CFF8F'); $rB.FontWeight = 'Bold'
        $rB2 = New-Object Windows.Documents.Run -ArgumentList (Tr 'ya quitadas')
        $rB2.Foreground = Get-ThemeBrush('#FF5CFF8F')
        $rL = New-Object Windows.Documents.Run -ArgumentList ('      ' + (Tr 'ambar = sigue instalada, verde = ya no esta'))
        $rL.Foreground = Get-ThemeBrush('#FF8A8A95'); $rL.FontSize = 11
        $script:DebloatStatusInline.Inlines.Add($rA); $script:DebloatStatusInline.Inlines.Add($rA2)
        $script:DebloatStatusInline.Inlines.Add($rSep)
        $script:DebloatStatusInline.Inlines.Add($rB); $script:DebloatStatusInline.Inlines.Add($rB2)
        $script:DebloatStatusInline.Inlines.Add($rL)
    }
    try { $script:StatusText.Text = ((Tr 'Debloat: {0} de {1} apps instaladas.') -f $installed, $total) } catch {}
}

# Guarda a un perfil JSON que apps de la lista estaban quitadas en este PC.
function Save-DebloatProfile {
    if (-not $script:DebloatDetected) { Detect-DebloatStates }
    $items = @()
    foreach ($cb in $script:DebloatChecks) {
        $pkg = [string]$cb.Tag
        $lbl = $script:DebloatStatusLabels[$pkg]
        $st = 'unknown'
        if ($lbl) { $st = $(if (([string]$lbl.Text).StartsWith('INSTALADA')) { 'installed' } else { 'removed' }) }
        $items += [ordered]@{ name = [string]$cb.Content; pkg = $pkg; state = $st }
    }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.FileName = ('perfil_debloat_{0}.json' -f (Get-Date -Format 'yyyyMMdd'))
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Perfil de debloat WPI (*.json)|*.json'
    if ($dlg.ShowDialog()) {
        $doc = [ordered]@{
            '$schema' = 'wpi-debloat-profile-1.0'
            created   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
            machine   = $env:COMPUTERNAME
            wpi       = $WpiVersion
            debloat   = $items
        }
        try {
            Set-WpiContent -Path $dlg.FileName -Value ($doc | ConvertTo-Json -Depth 5)
            Show-WpiMessage(((Tr "Perfil de debloat guardado:`n{0}`n`nRegistra que apps preinstaladas ya quitaste. Cargalo en otro equipo para dejarlo igual de limpio.") -f $dlg.FileName), 'WPI Moderno') | Out-Null
        } catch { $script:StatusText.Text = (Tr 'No se pudo guardar el perfil de debloat.') }
    }
}

# Carga un perfil y MARCA las apps que el perfil tenia como quitadas y que
# AQUI siguen instaladas, para que el usuario revise y pulse QUITAR. No quita
# nada por si solo.
function Load-DebloatProfile {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Perfil de debloat WPI (*.json)|*.json|Todos (*.*)|*.*'
    if (-not $dlg.ShowDialog()) { return }
    $data = $null
    try { $data = Get-Content $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
        Show-WpiMessage('No se pudo leer el perfil (formato no valido).', 'WPI Moderno') | Out-Null; return
    }
    if (-not $script:DebloatDetected) { try { Detect-DebloatStates } catch {} }
    $want = @{}
    foreach ($e in @($data.debloat)) { if ($e.pkg -and [string]$e.state -eq 'removed') { $want[[string]$e.pkg] = $true } }
    $n = 0; $stillHere = 0
    foreach ($cb in $script:DebloatChecks) {
        $pkg = [string]$cb.Tag
        if ($want.ContainsKey($pkg)) {
            $lbl = $script:DebloatStatusLabels[$pkg]
            $here = ($lbl -and ([string]$lbl.Text).StartsWith('INSTALADA'))
            $cb.IsChecked = [bool]$here
            $n++
            if ($here) { $stillHere++ }
        } else { $cb.IsChecked = $false }
    }
    try { Update-DebloatCount } catch {}
    Show-WpiMessage(((Tr "Perfil de debloat cargado.`n`nApps quitadas en el perfil: {0}`nDe esas, aun instaladas en este PC (marcadas): {1}`n`nRevisa la seleccion y pulsa QUITAR SELECCIONADAS para igualar este equipo.") -f $n, $stillHere), 'WPI Moderno', 'OK', 'Information') | Out-Null
}

# Exporta un PERFIL MAESTRO (apps+tweaks+debloat+update) que captura el estado
# actual del PC: apps marcadas en el catalogo, tweaks ya aplicados (segun el
# detector), bloatware ya quitado y politica de update recomendada. Se aplica
# con "Aplicar perfil completo" o con -Profile en la linea de comandos.
function Export-MasterProfile {
    # Apps: las marcadas en el catalogo (winget saltara las ya instaladas)
    $apps = @()
    try { $apps = @($script:Checks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag }) } catch {}

    # Tweaks: los que el detector marca como aplicados -> apply:true
    # (forzamos la deteccion aunque no se haya abierto el panel de Tweaks)
    try { Detect-TweakStates } catch {}
    $tw = @()
    foreach ($cb in $script:TweakChecks) {
        $name = [string]$cb.Tag.Name
        $applied = $false
        if ($TweakDetectors.ContainsKey($name)) {
            try { $applied = [bool](Invoke-Expression $TweakDetectors[$name]) } catch { $applied = $false }
        } else {
            $applied = [bool]$cb.IsChecked
        }
        if ($applied) { $tw += [ordered]@{ name = $name; apply = $true } }
    }

    # Debloat: las apps que YA estan quitadas -> remove:true (para igualar otro PC)
    # (forzamos la deteccion aunque no se haya abierto el panel de Debloat; si no,
    #  las etiquetas valen 'estado: sin comprobar' y saldrian todas como quitadas)
    try { Detect-DebloatStates } catch {}
    $db = @()
    foreach ($cb in $script:DebloatChecks) {
        $pkg = [string]$cb.Tag
        $lbl = $script:DebloatStatusLabels[$pkg]
        if ($lbl -and -not ([string]$lbl.Text).StartsWith('INSTALADA')) { $db += [ordered]@{ pkg = $pkg; remove = $true } }
    }

    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.FileName = ('perfil_maestro_{0}.json' -f (Get-Date -Format 'yyyyMMdd'))
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Perfil maestro WPI (*.json)|*.json'
    if ($dlg.ShowDialog()) {
        $doc = [ordered]@{
            '$schema' = 'wpi-master-profile-1.0'
            created   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
            machine   = $env:COMPUTERNAME
            wpi       = $WpiVersion
            apps      = $apps
            tweaks    = $tw
            debloat   = $db
            update    = 'recommended'
        }
        try {
            Set-WpiContent -Path $dlg.FileName -Value ($doc | ConvertTo-Json -Depth 6)
            Show-WpiMessage(((Tr "Perfil maestro guardado:`n{0}`n`nApps marcadas: {1}  ·  Tweaks aplicados: {2}  ·  Debloat quitado: {3}`n`nAplicalo en otro equipo con 'Aplicar perfil completo' o con -Profile en la linea de comandos.") -f $dlg.FileName, @($apps).Count, @($tw).Count, @($db).Count), 'WPI Moderno') | Out-Null
        } catch { $script:StatusText.Text = (Tr 'No se pudo guardar el perfil maestro.') }
    }
}

# Muestra el PLAN de un perfil en una ventana desplazable (solo lectura).
# Permite exportarlo y, si $AllowApply, ofrece "Aplicar este plan". Devuelve
# $true solo si el usuario pulsa "Aplicar este plan".
function Show-PlanDialog {
    param([string]$PlanText, [bool]$AllowApply = $false)
    $script:WpiPlanApply = $false
    $win = New-Object Windows.Window
    $win.Title = 'Plan del perfil maestro'
    $win.Width = 760; $win.Height = 580
    $win.WindowStartupLocation = 'CenterScreen'
    $win.Background = Get-ThemeBrush('#FF0F0F17')
    $script:WpiPlanWin = $win

    $dock = New-Object Windows.Controls.DockPanel
    $dock.Margin = New-Object Windows.Thickness(12)
    $dock.LastChildFill = $true

    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = 'PLAN (solo lectura) - no se aplica nada hasta que confirmes'
    $hdr.Foreground = Get-ThemeBrush('#FF00E5FF'); $hdr.FontWeight = 'Bold'; $hdr.FontSize = 14
    $hdr.Margin = New-Object Windows.Thickness(0,0,0,8)
    [Windows.Controls.DockPanel]::SetDock($hdr, 'Top')
    $dock.Children.Add($hdr) | Out-Null

    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'
    $row.Margin = New-Object Windows.Thickness(0,8,0,0)
    [Windows.Controls.DockPanel]::SetDock($row, 'Bottom')
    $dock.Children.Add($row) | Out-Null

    $bExport = New-Object Windows.Controls.Button
    $bExport.Content = 'Exportar plan'; $bExport.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bExport.Padding = New-Object Windows.Thickness(10,4,10,4)
    $bExport.Tag = $PlanText
    $bExport.Add_Click({
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.FileName = ('plan_perfil_{0}.md' -f (Get-Date -Format 'yyyyMMdd'))
        $dlg.InitialDirectory = $PSScriptRoot
        $dlg.Filter = 'Markdown (*.md)|*.md|Texto (*.txt)|*.txt'
        if ($dlg.ShowDialog()) {
            try { Set-WpiContent -Path $dlg.FileName -Value ([string]$this.Tag) } catch {}
        }
    })
    $row.Children.Add($bExport) | Out-Null

    if ($AllowApply) {
        $bApply = New-Object Windows.Controls.Button
        $bApply.Content = 'Aplicar este plan'; $bApply.Margin = New-Object Windows.Thickness(0,0,8,0)
        $bApply.Padding = New-Object Windows.Thickness(10,4,10,4)
        $bApply.Background = Get-ThemeBrush('#FF4F1F1F'); $bApply.BorderBrush = Get-ThemeBrush('#FFFF6B6B')
        $bApply.Add_Click({ $script:WpiPlanApply = $true; $script:WpiPlanWin.Close() })
        $row.Children.Add($bApply) | Out-Null
    }

    $bClose = New-Object Windows.Controls.Button
    $bClose.Content = $(if ($AllowApply) { 'Cancelar' } else { 'Cerrar' })
    $bClose.Padding = New-Object Windows.Thickness(10,4,10,4)
    $bClose.Add_Click({ $script:WpiPlanWin.Close() })
    $row.Children.Add($bClose) | Out-Null

    $tb = New-Object Windows.Controls.TextBox
    $tb.Text = $PlanText; $tb.IsReadOnly = $true
    $tb.TextWrapping = 'NoWrap'
    $tb.VerticalScrollBarVisibility = 'Auto'; $tb.HorizontalScrollBarVisibility = 'Auto'
    $tb.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
    $tb.FontSize = 12.5
    $tb.Background = Get-ThemeBrush('#FF15151F'); $tb.Foreground = Get-ThemeBrush('#FFE6E6EC')
    $tb.BorderBrush = Get-ThemeBrush('#FF2C2C3A')
    $dock.Children.Add($tb) | Out-Null

    $win.Content = $dock
    [void]$win.ShowDialog()
    return $script:WpiPlanApply
}

function Add-WpiStatCard {
    param($Panel, [string]$Title, [string]$Value, [string]$Color)
    $card = New-Object Windows.Controls.Border
    $card.Background = Get-ThemeBrush('#FF15151F'); $card.BorderBrush = Get-ThemeBrush('#FF2C2C3A')
    $card.BorderThickness = New-Object Windows.Thickness(1); $card.CornerRadius = New-Object Windows.CornerRadius(11)
    $card.Margin = New-Object Windows.Thickness(0,6,0,0); $card.Padding = New-Object Windows.Thickness(13,9,13,11)
    $sp = New-Object Windows.Controls.StackPanel
    $tt = New-Object Windows.Controls.TextBlock; $tt.Text = $Title; $tt.Foreground = Get-ThemeBrush('#FF8A8A95'); $tt.FontSize = 12
    $vv = New-Object Windows.Controls.TextBlock; $vv.Text = $Value; $vv.Foreground = Get-ThemeBrush($Color); $vv.FontSize = 15; $vv.FontWeight = 'Bold'; $vv.TextWrapping = 'Wrap'
    $sp.Children.Add($tt) | Out-Null; $sp.Children.Add($vv) | Out-Null
    $card.Child = $sp
    $Panel.Children.Add($card) | Out-Null
}

# Panel RESUMEN DEL SISTEMA (solo lectura): reune el estado de todo lo que
# gestiona el WPI en una sola pantalla y permite exportar un diagnostico.
# ---- A5: Comparativa antes/despues (metricas de solo lectura) ----
$script:BaselineFile = (Join-Path $PSScriptRoot 'wpi_baseline.json')

function Get-WpiSnapshotMetrics {
    $m = [ordered]@{ boot = ''; ramUsedMB = 0; services = 0; processes = 0; startup = 0 }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            try { $m.boot = (Get-Date $os.LastBootUpTime -Format 'yyyy-MM-dd HH:mm') } catch { $m.boot = [string]$os.LastBootUpTime }
            $tot = [double]$os.TotalVisibleMemorySize; $free = [double]$os.FreePhysicalMemory
            if ($tot -gt 0) { $m.ramUsedMB = [int](($tot - $free) / 1024) }
        }
    } catch {}
    try { $m.services  = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }).Count } catch {}
    try { $m.processes = @(Get-Process -ErrorAction SilentlyContinue).Count } catch {}
    try { $m.startup   = @(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue).Count } catch {}
    return $m
}

# Texto de la comparativa baseline (foto) vs actual. $Base = .metrics del JSON.
function Get-WpiCompareText {
    param($Base, $Now)
    $fmtDelta = {
        param($label, $b, $n, $unit)
        $d = [int]$n - [int]$b
        $signo = $(if ($d -gt 0) { ('+{0}' -f $d) } elseif ($d -lt 0) { [string]$d } else { '0' })
        ('  - {0}: antes {1}{3}{5}ahora {2}{3}{5}cambio {4}{3}' -f $label, $b, $n, $unit, $signo, $script:SepText)
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine((& $fmtDelta 'Servicios en ejecucion' $Base.services $Now.services ''))
    [void]$sb.AppendLine((& $fmtDelta 'Procesos'               $Base.processes $Now.processes ''))
    [void]$sb.AppendLine((& $fmtDelta 'Apps de inicio'         $Base.startup $Now.startup ''))
    [void]$sb.AppendLine((& $fmtDelta 'RAM en uso'             $Base.ramUsedMB $Now.ramUsedMB ' MB'))
    [void]$sb.AppendLine(('  - Ultimo arranque: antes {0}{2}ahora {1}' -f [string]$Base.boot, [string]$Now.boot, $script:SepText))
    return $sb.ToString()
}

function Build-SummaryUI {
    $p = $script:SummaryList
    $p.Children.Clear()
    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = 'RESUMEN DEL SISTEMA'
    $hdr.FontSize = 15; $hdr.FontWeight = 'Bold'; $hdr.Foreground = Get-ThemeBrush('#FF00E5FF')
    $hdr.Margin = New-Object Windows.Thickness(2,10,0,2)
    $p.Children.Add($hdr) | Out-Null
    $info = New-Object Windows.Controls.TextBlock
    $info.Text = 'Foto del estado actual de tu PC segun lo que gestiona el WPI. Solo lectura: no cambia nada. Se actualiza cada vez que entras aqui.'
    $info.Foreground = Get-ThemeBrush('#FF8A8A95'); $info.FontSize = 12; $info.TextWrapping = 'Wrap'
    $info.Margin = New-Object Windows.Thickness(2,0,0,8)
    $p.Children.Add($info) | Out-Null

    # --- C1: Apariencia (tema claro/oscuro) ---
    $apCard = New-Object Windows.Controls.Border
    $apCard.Background = Get-ThemeBrush('#FF15151F'); $apCard.BorderBrush = Get-ThemeBrush('#FF2C2C3A')
    $apCard.BorderThickness = New-Object Windows.Thickness(1); $apCard.CornerRadius = New-Object Windows.CornerRadius(11)
    $apCard.Margin = New-Object Windows.Thickness(0,4,0,0); $apCard.Padding = New-Object Windows.Thickness(13,9,13,11)
    $apSp = New-Object Windows.Controls.StackPanel
    $apT = New-Object Windows.Controls.TextBlock; $apT.Text = 'APARIENCIA'; $apT.FontSize = 12; $apT.Foreground = Get-ThemeBrush('#FF8A8A95')
    $apSp.Children.Add($apT) | Out-Null
    $apRow = New-Object Windows.Controls.StackPanel; $apRow.Orientation = 'Horizontal'; $apRow.Margin = New-Object Windows.Thickness(0,4,0,0)
    $apLbl = New-Object Windows.Controls.TextBlock; $apLbl.VerticalAlignment = 'Center'; $apLbl.Margin = New-Object Windows.Thickness(0,0,10,0)
    $apLbl.Foreground = Get-ThemeBrush('#FFE6E6EC')
    $apLbl.Text = ((Tr 'Tema actual: {0}') -f (Tr (Get-ThemeLabel $script:ThemeName)))
    $apRow.Children.Add($apLbl) | Out-Null
    $apBtn = New-Object Windows.Controls.Button
    $apBtn.Content = ((Tr 'Cambiar tema (siguiente: {0})') -f (Tr (Get-ThemeLabel (Get-NextTheme $script:ThemeName))))
    $apBtn.Padding = New-Object Windows.Thickness(12,5,12,5)
    $apBtn.Background = Get-ThemeBrush('#FF243042'); $apBtn.BorderBrush = Get-ThemeBrush('#FF3C5876')
    $apBtn.Add_Click({
        $new = Get-NextTheme $script:ThemeName
        $script:ThemeName = $new
        Save-Settings
        $r = Show-WpiMessage(((Tr 'Tema cambiado a {0}. Se aplica al reiniciar la app. Reiniciar ahora?') -f (Get-ThemeLabel $new).ToUpper()), 'Apariencia', 'YesNo', 'Question')
        if ($r -eq 'Yes') {
            try { Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) } catch {}
            $script:Skip_Closing_Save = $true
            $window.Close()
        }
    })
    $apRow.Children.Add($apBtn) | Out-Null
    $apSp.Children.Add($apRow) | Out-Null
    $apCard.Child = $apSp
    $p.Children.Add($apCard) | Out-Null

    $twApplied = 0; $twCheckable = 0
    foreach ($t in $TweaksCatalog) {
        $n = [string]$t.Name
        if ($TweakDetectors.ContainsKey($n)) {
            $twCheckable++
            try { if ([bool](Invoke-Expression $TweakDetectors[$n])) { $twApplied++ } } catch {}
        }
    }
    $appx = @(); try { $appx = @(Get-AppxPackage -ErrorAction SilentlyContinue) } catch {}
    $blInstalled = 0; $blTotal = @($DebloatCatalog).Count
    foreach ($d in $DebloatCatalog) {
        $patterns = Get-DebloatPatterns $d.Pkg
        try { if (@($appx | Where-Object { $n = $_.Name; @($patterns | Where-Object { $n -like $_ }).Count -gt 0 }).Count -gt 0) { $blInstalled++ } } catch {}
    }
    $diskTxt = 'n/d'
    try {
        $dk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        if ($dk) { $diskTxt = ((Tr '{0} GB libres de {1} GB') -f (Format-WpiDec '{0:N0}' ($dk.FreeSpace/1GB)), (Format-WpiDec '{0:N0}' ($dk.Size/1GB))) }
    } catch {}
    $ramTxt = 'n/d'
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os -and $os.TotalVisibleMemorySize -gt 0) {
            $totGB = $os.TotalVisibleMemorySize/1MB; $freeGB = $os.FreePhysicalMemory/1MB
            $usedPct = [int]((($totGB - $freeGB) / $totGB) * 100)
            $ramTxt = ((Tr '{0} GB en uso de {1} GB ({2}%)') -f (Format-WpiDec '{0:N1}' ($totGB - $freeGB)), (Format-WpiDec '{0:N1}' $totGB), $usedPct)
        }
    } catch {}
    $rp = $false
    try { $rp = ([int](Get-WpiRegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'RPSessionInterval') -ge 1) } catch {}
    $wg = (Tr 'no detectado')
    try { $vv = (winget --version) 2>$null; if ($vv) { $wg = [string]$vv } } catch {}

    Add-WpiStatCard $p (Tr 'Apps del catalogo') ((Tr '{0} disponibles para instalar') -f @($catalog).Count) '#FFE6E6EC'
    Add-WpiStatCard $p (Tr 'Tweaks aplicados') ((Tr '{0} de {1} comprobables') -f $twApplied, $twCheckable) $(if ($twApplied -gt 0) { '#FF5CFF8F' } else { '#FFB0B0BC' })
    Add-WpiStatCard $p (Tr 'Bloatware presente') ((Tr '{0} de {1} apps de la lista siguen instaladas') -f $blInstalled, $blTotal) $(if ($blInstalled -eq 0) { '#FF5CFF8F' } else { '#FFFFD166' })
    Add-WpiStatCard $p (Tr 'Disco C:') $diskTxt '#FFE6E6EC'
    Add-WpiStatCard $p (Tr 'Memoria RAM') $ramTxt '#FFE6E6EC'
    Add-WpiStatCard $p (Tr 'Punto de restauracion') $(if ($rp) { Tr 'Proteccion activada' } else { Tr 'Desactivada (recomendable activarla antes de tocar tweaks)' }) $(if ($rp) { '#FF5CFF8F' } else { '#FFFFD166' })
    Add-WpiStatCard $p 'winget (App Installer)' $wg $(if ($wg -eq (Tr 'no detectado')) { '#FFFF6B6B' } else { '#FFE6E6EC' })

    $bExp = New-Object Windows.Controls.Button
    $bExp.Content = 'Exportar diagnostico completo'; $bExp.HorizontalAlignment = 'Left'
    $bExp.Margin = New-Object Windows.Thickness(0,14,0,0)
    $bExp.Background = Get-ThemeBrush('#FF13414F'); $bExp.BorderBrush = Get-ThemeBrush('#FF76E0FF')
    $bExp.Tag = [ordered]@{ tw = $twApplied; twc = $twCheckable; bl = $blInstalled; blt = $blTotal; disk = $diskTxt; ram = $ramTxt; rp = $rp; wg = $wg }
    $bExp.Add_Click({
        $m = $this.Tag
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.FileName = ('diagnostico_{0}_{1}.md' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd'))
        $dlg.InitialDirectory = $PSScriptRoot
        $dlg.Filter = 'Markdown (*.md)|*.md|Texto (*.txt)|*.txt'
        if (-not $dlg.ShowDialog()) { return }
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('# Diagnostico WPI - ' + $env:COMPUTERNAME)
        [void]$sb.AppendLine('Fecha: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + $script:SepText + 'WPI ' + [string]$WpiVersion)
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('## Resumen')
        [void]$sb.AppendLine(('- Tweaks aplicados: {0} de {1}' -f $m.tw, $m.twc))
        [void]$sb.AppendLine(('- Bloatware presente: {0} de {1}' -f $m.bl, $m.blt))
        [void]$sb.AppendLine(('- Disco C: {0}' -f $m.disk))
        [void]$sb.AppendLine(('- RAM: {0}' -f $m.ram))
        [void]$sb.AppendLine(('- Punto de restauracion: {0}' -f $(if ($m.rp) { 'activado' } else { 'desactivado' })))
        [void]$sb.AppendLine(('- winget: {0}' -f $m.wg))
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('## Tweaks por estado')
        foreach ($t in $TweaksCatalog) {
            $n = [string]$t.Name; $estado = 'accion puntual'
            if ($TweakDetectors.ContainsKey($n)) {
                $estado = 'no aplicado'
                try { if ([bool](Invoke-Expression $TweakDetectors[$n])) { $estado = 'APLICADO' } } catch { $estado = 'no comprobable' }
            }
            [void]$sb.AppendLine(('- [{0}] {1}' -f $estado, $n))
        }
        if ($script:HwReportText) {
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('## Hardware')
            [void]$sb.AppendLine('```')
            [void]$sb.AppendLine([string]$script:HwReportText)
            [void]$sb.AppendLine('```')
        }
        if (Test-Path $script:BaselineFile) {
            try {
                $bl = Get-Content $script:BaselineFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ([string]$bl.'$schema' -eq 'wpi-baseline-1.0' -and $bl.metrics) {
                    [void]$sb.AppendLine('')
                    [void]$sb.AppendLine('## Antes / Despues')
                    [void]$sb.AppendLine(('Foto tomada: {0}' -f [string]$bl.created))
                    [void]$sb.AppendLine('```')
                    [void]$sb.AppendLine((Get-WpiCompareText -Base $bl.metrics -Now (Get-WpiSnapshotMetrics)))
                    [void]$sb.AppendLine('```')
                }
            } catch {}
        }
        try {
            Set-WpiContent -Path $dlg.FileName -Value $sb.ToString()
            Show-WpiMessage(((Tr 'Diagnostico guardado en: {0}') -f $dlg.FileName), 'WPI Moderno') | Out-Null
        } catch { $script:StatusText.Text = (Tr 'No se pudo guardar el diagnostico.') }
    })
    $p.Children.Add($bExp) | Out-Null

    # --- PERFIL MAESTRO (A1): exportar el estado actual y aplicar un perfil completo ---
    $mpHdr = New-Object Windows.Controls.TextBlock
    $mpHdr.Text = 'PERFIL MAESTRO (apps + tweaks + debloat + update)'
    $mpHdr.FontSize = 13; $mpHdr.FontWeight = 'Bold'; $mpHdr.Foreground = Get-ThemeBrush('#FF00E5FF')
    $mpHdr.Margin = New-Object Windows.Thickness(2,18,0,2)
    $p.Children.Add($mpHdr) | Out-Null
    $mpInfo = New-Object Windows.Controls.TextBlock
    $mpInfo.Text = 'Captura todo tu PC en un solo JSON y replicalo en otro equipo. "Aplicar perfil completo" crea un punto de restauracion y relanza el WPI como administrador en modo desatendido.'
    $mpInfo.Foreground = Get-ThemeBrush('#FF8A8A95'); $mpInfo.FontSize = 12; $mpInfo.TextWrapping = 'Wrap'
    $mpInfo.Margin = New-Object Windows.Thickness(2,0,0,4)
    $p.Children.Add($mpInfo) | Out-Null

    $bExpMP = New-Object Windows.Controls.Button
    $bExpMP.Content = 'Exportar perfil maestro'; $bExpMP.HorizontalAlignment = 'Left'
    $bExpMP.Margin = New-Object Windows.Thickness(0,6,0,0)
    $bExpMP.Background = Get-ThemeBrush('#FF1F4F1F'); $bExpMP.BorderBrush = Get-ThemeBrush('#FF4F9E4F')
    $bExpMP.Add_Click({ try { Export-MasterProfile } catch { $script:StatusText.Text = (Tr 'No se pudo exportar el perfil maestro.') } })
    $p.Children.Add($bExpMP) | Out-Null

    $bPlanMP = New-Object Windows.Controls.Button
    $bPlanMP.Content = 'Ver plan del perfil'; $bPlanMP.HorizontalAlignment = 'Left'
    $bPlanMP.Margin = New-Object Windows.Thickness(0,8,0,0)
    $bPlanMP.Background = Get-ThemeBrush('#FF13414F'); $bPlanMP.BorderBrush = Get-ThemeBrush('#FF76E0FF')
    $bPlanMP.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.InitialDirectory = $PSScriptRoot
        $dlg.Filter = 'Perfil maestro WPI (*.json)|*.json|Todos (*.*)|*.*'
        if (-not $dlg.ShowDialog()) { return }
        $data = $null
        try { $data = Get-Content $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
            Show-WpiMessage('No se pudo leer el perfil (JSON no valido).', 'WPI Moderno') | Out-Null; return
        }
        if ([string]$data.'$schema' -ne 'wpi-master-profile-1.0') {
            Show-WpiMessage('El archivo no es un perfil maestro valido (falta "$schema": "wpi-master-profile-1.0").', 'WPI Moderno') | Out-Null; return
        }
        $plan = Get-MasterProfilePlanText -Data $data
        [void](Show-PlanDialog -PlanText $plan -AllowApply $false)
    })
    $p.Children.Add($bPlanMP) | Out-Null

    $bAppMP = New-Object Windows.Controls.Button
    $bAppMP.Content = 'Aplicar perfil completo'; $bAppMP.HorizontalAlignment = 'Left'
    $bAppMP.Margin = New-Object Windows.Thickness(0,8,0,0)
    $bAppMP.Background = Get-ThemeBrush('#FF4F1F1F'); $bAppMP.BorderBrush = Get-ThemeBrush('#FFFF6B6B')
    $bAppMP.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.InitialDirectory = $PSScriptRoot
        $dlg.Filter = 'Perfil maestro WPI (*.json)|*.json|Todos (*.*)|*.*'
        if (-not $dlg.ShowDialog()) { return }
        $f = $dlg.FileName
        # Validar el esquema ANTES de tocar nada (como Load-TweakProfile)
        $data = $null
        try { $data = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
            Show-WpiMessage('No se pudo leer el perfil (JSON no valido). No se aplica nada.', 'WPI Moderno') | Out-Null; return
        }
        if ([string]$data.'$schema' -ne 'wpi-master-profile-1.0') {
            Show-WpiMessage('El archivo no es un perfil maestro valido (falta "$schema": "wpi-master-profile-1.0"). No se aplica nada.', 'WPI Moderno') | Out-Null; return
        }
        # Ver plan -> confirmar -> aplicar. Si el usuario no pulsa "Aplicar", se sale.
        $plan = Get-MasterProfilePlanText -Data $data
        $go = Show-PlanDialog -PlanText $plan -AllowApply $true
        if (-not $go) { return }
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Profile "{1}"' -f $PSCommandPath, $f)
            $script:Skip_Closing_Save = $true
            $window.Close()
        } catch {
            Show-WpiMessage(((Tr 'No se pudo relanzar como administrador: {0}') -f $_.Exception.Message), 'WPI Moderno') | Out-Null
        }
    })
    $p.Children.Add($bAppMP) | Out-Null

    # --- A5: Comparativa antes/despues ---
    $cmpHdr = New-Object Windows.Controls.TextBlock
    $cmpHdr.Text = 'COMPARATIVA ANTES / DESPUES'
    $cmpHdr.FontSize = 13; $cmpHdr.FontWeight = 'Bold'; $cmpHdr.Foreground = Get-ThemeBrush($Theme.Info)
    $cmpHdr.Margin = New-Object Windows.Thickness(2,18,0,2)
    $p.Children.Add($cmpHdr) | Out-Null
    $cmpInfo = New-Object Windows.Controls.TextBlock
    $cmpInfo.Text = 'Mide el impacto real de tus cambios. Toma una "foto" del sistema (servicios, procesos, apps de inicio, RAM, arranque), aplica tweaks/debloat, y compara para ver el delta. La foto se guarda en wpi_baseline.json junto al WPI.'
    $cmpInfo.Foreground = Get-ThemeBrush($Theme.Sub); $cmpInfo.FontSize = 12; $cmpInfo.TextWrapping = 'Wrap'
    $cmpInfo.Margin = New-Object Windows.Thickness(2,0,0,4)
    $p.Children.Add($cmpInfo) | Out-Null

    $bSnap = New-Object Windows.Controls.Button
    $bSnap.Content = 'Tomar foto del sistema'; $bSnap.HorizontalAlignment = 'Left'
    $bSnap.Margin = New-Object Windows.Thickness(0,6,0,0)
    $bSnap.Background = Get-ThemeBrush('#FF13414F'); $bSnap.BorderBrush = Get-ThemeBrush('#FF76E0FF')
    $bSnap.Add_Click({
        if (Test-Path $script:BaselineFile) {
            $r = Show-WpiMessage('Ya existe una foto previa. Sobrescribirla con el estado actual?', 'Comparativa', 'YesNo', 'Question')
            if ($r -ne 'Yes') { return }
        }
        $m = Get-WpiSnapshotMetrics
        $doc = [ordered]@{ '$schema' = 'wpi-baseline-1.0'; created = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'); machine = $env:COMPUTERNAME; metrics = $m }
        try {
            Set-WpiContent -Path $script:BaselineFile -Value ($doc | ConvertTo-Json -Depth 5)
            Show-WpiMessage(((Tr "Foto del sistema guardada en:`n{0}`n`nServicios: {1}  ·  Procesos: {2}  ·  Inicio: {3}  ·  RAM: {4} MB`n`nAplica tus cambios y luego pulsa 'Comparar con la foto'.") -f $script:BaselineFile, $m.services, $m.processes, $m.startup, $m.ramUsedMB), 'Comparativa') | Out-Null
        } catch { $script:StatusText.Text = (Tr 'No se pudo guardar la foto del sistema.') }
    })
    $p.Children.Add($bSnap) | Out-Null

    $bCmp = New-Object Windows.Controls.Button
    $bCmp.Content = 'Comparar con la foto'; $bCmp.HorizontalAlignment = 'Left'
    $bCmp.Margin = New-Object Windows.Thickness(0,8,0,0)
    $bCmp.Background = Get-ThemeBrush('#FF1F4F1F'); $bCmp.BorderBrush = Get-ThemeBrush('#FF4F9E4F')
    $bCmp.Add_Click({
        if (-not (Test-Path $script:BaselineFile)) {
            Show-WpiMessage('Todavia no hay ninguna foto. Pulsa primero "Tomar foto del sistema".', 'Comparativa') | Out-Null; return
        }
        $base = $null
        try { $base = Get-Content $script:BaselineFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
            Show-WpiMessage('No se pudo leer wpi_baseline.json (formato no valido).', 'Comparativa') | Out-Null; return
        }
        if ([string]$base.'$schema' -ne 'wpi-baseline-1.0' -or -not $base.metrics) {
            Show-WpiMessage('El archivo wpi_baseline.json no es una foto valida.', 'Comparativa') | Out-Null; return
        }
        $now = Get-WpiSnapshotMetrics
        $txt = Get-WpiCompareText -Base $base.metrics -Now $now
        Show-WpiMessage(((Tr "Comparativa (foto del {0}):`n`n{1}") -f [string]$base.created, $txt), 'Comparativa antes / despues', 'OK', 'Information') | Out-Null
    })
    $p.Children.Add($bCmp) | Out-Null
}

function Build-WinUpdateUI {
    $p = $script:WinUpdateList
    $p.Children.Clear()
    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = 'CONTROL DE WINDOWS UPDATE'
    $hdr.FontSize = 14; $hdr.FontWeight = 'Bold'
    $hdr.Foreground = Get-ThemeBrush('#FF3F9EFF')
    $hdr.Margin = New-Object Windows.Thickness(2,10,0,2)
    $p.Children.Add($hdr) | Out-Null
    $info = New-Object Windows.Controls.TextBlock
    $info.Text = 'Decide como y cuando se actualiza Windows. Cada accion se aplica al pulsar su boton y queda en el log forense. "Valores por defecto" deshace cualquier cambio de esta lista.'
    $info.Foreground = Get-ThemeBrush('#FF8A8A95'); $info.FontSize = 12; $info.TextWrapping = 'Wrap'
    $info.Margin = New-Object Windows.Thickness(2,0,0,8)
    $p.Children.Add($info) | Out-Null
    $linkRow = New-Object Windows.Controls.StackPanel; $linkRow.Orientation = 'Horizontal'
    $linkRow.Margin = New-Object Windows.Thickness(0,0,0,6)
    foreach ($l in $WindowsUpdateLinks) {
        $lb = New-Object Windows.Controls.Button
        $lb.Content = $l.Name; $lb.Tag = $l.Uri
        $lb.Add_Click({ try { Start-Process ([string]$this.Tag) } catch {} })
        $linkRow.Children.Add($lb) | Out-Null
    }
    $p.Children.Add($linkRow) | Out-Null
    $wuWrap = New-Object Windows.Controls.WrapPanel
    $wuWrap.Orientation = 'Horizontal'
    $wuWrap.Margin = New-Object Windows.Thickness(0,4,0,0)
    foreach ($a in $WindowsUpdateActions) {
        $adv = ($a.Risk -eq 'Avanzado')
        $accent = $(if ($adv) { '#FFFF6B6B' } else { '#FF3F9EFF' })
        $card = New-Object Windows.Controls.Border
        $card.Width = 332
        $card.Background = Get-ThemeBrush('#FF14141D')
        $card.BorderBrush = Get-ThemeBrush($accent)
        $card.BorderThickness = New-Object Windows.Thickness(4,1,1,1)
        $card.CornerRadius = New-Object Windows.CornerRadius(11)
        $card.Margin = New-Object Windows.Thickness(0,10,14,0)
        $card.Padding = New-Object Windows.Thickness(16,13,16,14)
        $card.VerticalAlignment = 'Top'
        $sp = New-Object Windows.Controls.StackPanel
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = $a.Name; $t.FontWeight = 'Bold'; $t.FontSize = 14
        $t.Foreground = Get-ThemeBrush($accent)
        $t.TextWrapping = 'Wrap'
        $sp.Children.Add($t) | Out-Null
        $d = New-Object Windows.Controls.TextBlock
        $d.Text = $a.Desc; $d.Foreground = Get-ThemeBrush('#FF9A9AA8'); $d.FontSize = 12; $d.TextWrapping = 'Wrap'
        $d.Margin = New-Object Windows.Thickness(0,5,0,11)
        $d.MinHeight = 54
        $sp.Children.Add($d) | Out-Null
        $b = New-Object Windows.Controls.Button
        $b.Content = (Tr 'Aplicar'); $b.HorizontalAlignment = 'Stretch'; $b.FontWeight = 'Bold'; $b.Tag = $a
        $b.Padding = New-Object Windows.Thickness(10,6,10,6)
        if ($adv) { $b.Background = Get-ThemeBrush('#FF4F2A2A'); $b.BorderBrush = Get-ThemeBrush('#FF7B4444') }
        else { $b.Background = Get-ThemeBrush('#FF1F3A4F'); $b.BorderBrush = Get-ThemeBrush('#FF3F6E9E') }
        $b.Add_Click({
            $act = $this.Tag
            if ($act.Warn) {
                $r = Show-WpiMessage([string]$act.Warn, 'WPI Moderno', 'YesNo', 'Warning')
                if ($r -ne 'Yes') { return }
            }
            Start-Worker -Mode 'tweaks' -Tweaks @(@{ Name = [string]$act.Name; Code = [string]$act.Code })
        })
        $sp.Children.Add($b) | Out-Null
        $card.Child = $sp
        $wuWrap.Children.Add($card) | Out-Null
    }
    $p.Children.Add($wuWrap) | Out-Null
}

# Seccion SUITE (@REPAIR): selector/lanzador del .bat externo
# Suite_Reparacion_TodoEnUno.bat. El WPI NO reimplementa las fases: solo elige
# cuales y lanza el .bat como administrador en su propia consola (con log).
# Seccion SUITE (17 fases) que se anade al panel de Reparacion unificado.
# Lanza el motor externo Suite_Reparacion_TodoEnUno.bat; el WPI solo selecciona.
# Lanza la suite de reparacion (.bat) como administrador en su propia consola de forma interactiva.
function Start-RepairSuite {
    $isEn = ($script:Lang -eq 'en')
    $titleMsg = if ($isEn) { 'Repair Suite' } else { 'Suite de Reparacion' }
    $suiteBat = Resolve-SuiteReparacionPath
    if (-not $suiteBat) {
        $noMsg = if ($isEn) { 'Could not find the Repair Suite for the current language. Check the suite folder.' } else { 'No se pudo encontrar la Suite de Reparacion del idioma actual. Revisa la carpeta de la suite.' }
        Show-WpiMessage($noMsg, $titleMsg) | Out-Null
        return
    }

    $confirmMsg = if ($isEn) {
        "The Interactive Repair Suite Console will open in a separate window. You will have access to the full menu of options, diagnostics, triage, and manual modes.`n`nContinue?"
    } else {
        "Se abrira la consola interactiva de la Suite de Reparacion en una ventana aparte. Podras usar su menu completo de opciones, auto-triage de diagnostico, planificacion y modos manuales.`n`nContinuar?"
    }
    $r = Show-WpiMessage($confirmMsg, $titleMsg, 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    try {
        # Se lanza el .bat directo, igual que la suite de referencia (DEFINITIVO
        # ULTIMATE): hereda la consola normal de Windows (Consolas TrueType limpio).
        # La causa real de que se viera pequena/fea era 'chcp 65001' en la cabecera
        # de la suite, que reseteaba la fuente a la raster "Terminal" de 12 px; ya
        # se ha quitado (la suite es 100% ASCII, chcp no aportaba nada). No se fuerza
        # fuente ni 'mode con' (esos intentos recortaban la ventana).
        Start-Process -FilePath $suiteBat -Verb RunAs
        $statusMsg = if ($isEn) { 'Interactive Repair Suite Console launched.' } else { 'Consola interactiva de la Suite de Reparacion lanzada.' }
        $script:StatusText.Text = $statusMsg
    } catch {
        $errMsg = if ($isEn) { ('Could not launch the console: {0}') -f $_.Exception.Message } else { ('No se pudo lanzar la consola: {0}') -f $_.Exception.Message }
        Show-WpiMessage($errMsg, $titleMsg) | Out-Null
    }
}

# ---- B1: Deteccion de estado de caracteristicas/capabilities (solo lectura) ----
function Detect-FeatureStates {
    $feats = @(); $caps = @()
    try { $feats = @(Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue) } catch {}
    try { $caps  = @(Get-WindowsCapability -Online -ErrorAction SilentlyContinue) } catch {}
    $enabled = 0; $total = 0
    foreach ($f in $FeaturesCatalog) {
        $lbl = $script:FeatureStatusLabels[[string]$f.Id]
        if (-not $lbl) { continue }
        $total++
        $state = 'no comprobable'; $col = '#FF8A8A95'
        if ([string]$f.Kind -eq 'feature') {
            $hit = $feats | Where-Object { [string]$_.FeatureName -eq [string]$f.Id } | Select-Object -First 1
            if ($hit) {
                if ([string]$hit.State -eq 'Enabled') { $state = 'HABILITADO'; $col = '#FF5CFF8F'; $enabled++ }
                elseif ([string]$hit.State -like 'Disable*') { $state = 'deshabilitado'; $col = '#FFFFD166' }
                else { $state = [string]$hit.State; $col = '#FF8A8A95' }
            } else { $state = 'no presente en esta edicion'; $col = '#FF8A8A95' }
        } else {
            $hit = $caps | Where-Object { [string]$_.Name -eq [string]$f.Id } | Select-Object -First 1
            if ($hit) {
                if ([string]$hit.State -eq 'Installed') { $state = 'HABILITADO (instalada)'; $col = '#FF5CFF8F'; $enabled++ }
                else { $state = 'no instalada'; $col = '#FFFFD166' }
            } else { $state = 'no presente'; $col = '#FF8A8A95' }
        }
        $lbl.Text = (Tr ('estado: ' + $state))
        $lbl.Foreground = Get-ThemeBrush($col)
    }
    $script:FeatDetected = $true
    if ($script:FeatSummary) { $script:FeatSummary.Text = ((Tr 'Estado en este PC: {0} de {1} caracteristicas habilitadas/instaladas. Verde = activa; ambar = disponible para activar.') -f $enabled, $total) }
    try { $script:StatusText.Text = ((Tr 'Caracteristicas: {0} de {1} activas.') -f $enabled, $total) } catch {}
}

# Construye el comando reversible (Code) para habilitar/deshabilitar una feature
# o capability. $On = $true habilita/instala; $false deshabilita/quita.
function Get-FeatureCode {
    param($F, [bool]$On)
    $nm = ([string]$F.Name) -replace "'", ''
    if ([string]$F.Kind -eq 'feature') {
        if ($On) { return ("Enable-WindowsOptionalFeature -Online -FeatureName '{0}' -All -NoRestart -ErrorAction Stop | Out-Null; W ok 'Habilitado: {1}'" -f $F.Id, $nm) }
        else     { return ("Disable-WindowsOptionalFeature -Online -FeatureName '{0}' -NoRestart -ErrorAction Stop | Out-Null; W ok 'Deshabilitado: {1}'" -f $F.Id, $nm) }
    } else {
        if ($On) { return ("Add-WindowsCapability -Online -Name '{0}' -ErrorAction Stop | Out-Null; W ok 'Instalado: {1}'" -f $F.Id, $nm) }
        else     { return ("Remove-WindowsCapability -Online -Name '{0}' -ErrorAction Stop | Out-Null; W ok 'Quitado: {1}'" -f $F.Id, $nm) }
    }
}

# ============================================================
# ============  CREADOR DE ISO DE WINDOWS (@CREATEISO)  ======
# Flujo guiado y unico: prepara una ISO de Windows a medida con apps
# automatizadas, debloat/tweaks predefinidos y drivers inyectados. El
# trabajo pesado (montar WIM, DISM, oscdimg) lo hace un script GENERADO
# que se lanza como administrador y deja log; la GUI solo configura y
# genera el "kit". Cambio aditivo: no toca el motor de instalacion.
# ============================================================

# Detecta requisitos (solo lectura): admin, oscdimg (ADK), DISM, espacio.
function Get-IsoPrereqs {
    $r = [ordered]@{ Admin=$false; Oscdimg=''; Dism=$false; FreeGB=0 }
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        $r.Admin = $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {}
    $cands = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    )
    foreach ($c in $cands) { if (Test-Path $c) { $r.Oscdimg = $c; break } }
    try { if (Get-Command dism.exe -ErrorAction SilentlyContinue) { $r.Dism = $true } } catch {}
    try {
        $sysDrive = ($env:SystemDrive)
        $d = Get-PSDrive -Name ($sysDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
        if ($d) { $r.FreeGB = [math]::Round($d.Free / 1GB, 1) }
    } catch {}
    return $r
}

function Get-IsoPrereqText {
    $p = Get-IsoPrereqs
    $isEn = ($script:Lang -eq 'en')
    $lines = @()
    if ($isEn) {
        $lines += $(if ($p.Admin) { '[OK]  This session IS running as administrator' } else { '[ ! ]  You are NOT admin (the real creation will request elevation)' })
        $lines += $(if ($p.Oscdimg) { '[OK]  oscdimg found (Windows ADK installed)' } else { '[ X ]  Missing oscdimg / Windows ADK -> click "Install Windows ADK"' })
        $lines += $(if ($p.Dism)    { '[OK]  DISM available' } else { '[ X ]  DISM not found' })
        $freeGbEn = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $p.FreeGB)
        $lines += ('[i]   Free space on {0} : {1} GB  (25+ GB recommended)' -f $env:SystemDrive, $freeGbEn)
    } else {
        $lines += $(if ($p.Admin) { '[OK]  Esta sesion ES administrador' } else { '[ ! ]  NO eres admin (la creacion real pedira elevacion)' })
        $lines += $(if ($p.Oscdimg) { '[OK]  oscdimg encontrado (Windows ADK instalado)' } else { '[ X ]  Falta oscdimg / Windows ADK -> pulsa "Instalar Windows ADK"' })
        $lines += $(if ($p.Dism)    { '[OK]  DISM disponible' } else { '[ X ]  DISM no encontrado' })
        $lines += ('[i]   Espacio libre en {0} : {1} GB  (se recomiendan 25+ GB)' -f $env:SystemDrive, $p.FreeGB)
    }
    return ($lines -join "`r`n")
}

function Update-IsoPrereqText {
    if ($script:IsoPrereqText) { try { $script:IsoPrereqText.Text = (Get-IsoPrereqText) } catch {} }
}

# Texto de la guia paso a paso (se muestra y se guarda en el kit).
function Get-IsoGuideText {
@'
================================================================
  CREAR UNA ISO DE WINDOWS A MEDIDA CON WPI - GUIA PASO A PASO
================================================================

QUE HACE ESTE APARTADO
  Prepara una imagen de instalacion de Windows (ISO) personalizada:
   - con tus DRIVERS inyectados (para que el equipo arranque con red/chipset),
   - con el BLOATWARE ya quitado de fabrica (offline, antes de instalar),
   - con TWEAKS de privacidad/rendimiento ya aplicados,
   - con WPI y tu lista de APPS lista para instalarse sola en el 1er arranque,
   - y con instalacion DESATENDIDA opcional (autounattend.xml).

  La GUI NO modifica tu Windows actual: genera un "kit" (una carpeta con
  todo) y un script que crea la ISO. La ISO se construye cuando TU pulsas
  "Crear la ISO ahora", que se ejecuta como administrador y deja un log.

REQUISITOS (apartado "1. Requisitos")
  - Windows ADK instalado (aporta oscdimg.exe, que ensambla la ISO).
    Si falta, pulsa "Instalar Windows ADK" (winget Microsoft.WindowsADK).
  - 25+ GB libres en disco para el espacio de trabajo.
  - Una ISO ORIGINAL de Windows 10/11 (de Microsoft) como base.
  - Ejecutar como administrador para el paso de creacion real.

PASOS EN ORDEN
  1) Requisitos: pulsa "Comprobar" hasta ver oscdimg y DISM en [OK].
  2) Origen: elige tu ISO original de Windows (boton "Elegir ISO...").
  3) Salida: elige la carpeta donde dejar la ISO final y su nombre.
  4) Trabajo: carpeta temporal grande (se borra al final). Por defecto
     se crea dentro de la carpeta de salida.
  5) Edicion: indice de la edicion dentro de install.wim (0 = la mayor /
     normalmente "Pro"). El script lista las ediciones disponibles.
  6) Drivers: marca "Inyectar drivers" y elige la carpeta. Por defecto
     usa la copia que hiciste en "Drivers y hardware" (Export-WindowsDriver).
  7) Debloat: marca para quitar de fabrica las Appx de tu lista de bloat.
  8) Tweaks: marca para aplicar un set seguro de privacidad/rendimiento
     directamente sobre la imagen (offline, sin tocar tu PC).
  9) Apps: marca "Instalar mis apps en el primer arranque". Se usa la
     seleccion ACTUAL de la pestana de apps (marca antes lo que quieras).
 10) Desatendido: cuenta local sin conexion, saltar OOBE, bypass de
     requisitos de Windows 11 (TPM/SecureBoot/RAM) y, opcional, "modo VM"
     que PARTICIONA el disco automaticamente (solo para maquinas virtuales
     o discos que puedas borrar).
 11) "2. Generar kit de creacion": crea la carpeta del kit con
     autounattend.xml, los scripts, el preset de apps, una copia de WPI,
     esta guia y la guia de maquina virtual.
 12) "3. Crear la ISO ahora (administrador)": lanza el script generado en
     una consola elevada. Montara la imagen, inyectara/limpiara, volvera a
     ensamblar la ISO y la dejara en tu carpeta de salida. Tarda bastante.

================================================================
  !!! MUY IMPORTANTE: GRABAR LA ISO EN USB CON RUFUS !!!
================================================================
  Tu ISO YA incluye su propio autounattend.xml (cuenta local, saltar OOBE,
  bypass de TPM/Secure Boot y el arranque de WPI con tus apps y tweaks).

  >> EN RUFUS, EN LA VENTANA "Experiencia de usuario de Windows", NO MARQUES
     NINGUNA CASILLA. Dejalas TODAS vacias y pulsa "Aceptar". <<

  Por que: si marcas cualquier opcion de esa ventana (quitar TPM, crear
  cuenta local, mejoras "QoL", etc.), Rufus genera SU PROPIO autounattend.xml
  y SOBREESCRIBE el de WPI en el USB. Resultado: al instalar NO se aplican
  tus apps, ni los tweaks, ni el modo oscuro (es justo lo que falla si
  marcas algo). Todo eso ya lo hace el autounattend de WPI por si solo.

  Resumen de Rufus:
   - Dispositivo: tu USB.
   - Eleccion de arranque: tu ISO (WPI_Custom.iso).
   - Esquema de particion: GPT  /  Sistema destino: UEFI (no CSM).
   - Pulsa EMPEZAR. Cuando salga "Experiencia de usuario de Windows":
     NO marques nada -> Aceptar.
   - Al instalar, elige la edicion que quieras (si la ISO tiene varias,
     todas van personalizadas) y la particion a mano.
   - En el PRIMER ARRANQUE conecta INTERNET: las apps se instalan con winget.
================================================================

QUE GENERA EL KIT (carpeta WPI_ISO_Kit)
  - kit-config.json     -> todas tus elecciones (lo lee el script).
  - autounattend.xml    -> respuesta desatendida (idioma, cuenta, OOBE,
                           bypass W11, primer arranque -> WPI).
  - Crear_ISO_WPI.ps1   -> el motor real (montaje WIM, DISM, oscdimg) con log.
  - preset_apps.txt     -> IDs winget de tus apps marcadas.
  - payload\WPI\        -> copia de WPI_Moderno.ps1 + Iniciar_WPI.bat.
  - GUIA_ISO.md / GUIA_VM.md -> esta guia y la de maquina virtual.

CONSEJOS / ACLARACIONES
  - install.esd vs install.wim: si tu ISO trae install.esd, el script lo
    convierte a .wim automaticamente (necesita mas espacio y tiempo).
  - "0" en Edicion = la imagen mas completa encontrada. Si quieres una
    concreta, mira la lista que imprime el script y pon su numero.
  - Los drivers se inyectan con DISM /Add-Driver /Recurse: usa una carpeta
    con los .inf (la copia de "Drivers y hardware" vale tal cual).
  - El debloat offline quita Appx APROVISIONADAS (las que se instalan a cada
    usuario nuevo); son reinstalables desde la Store si te arrepientes.
  - Nada de esto toca tu Windows actual: todo ocurre sobre la imagen montada
    y la ISO de salida.
================================================================
'@
}

# Guia para probar la ISO en una maquina virtual.
function Get-IsoVmGuideText {
@'
================================================================
  PROBAR TU ISO EN UNA MAQUINA VIRTUAL (recomendado antes de usarla)
================================================================

POR QUE EN VM
  Probar la ISO en una maquina virtual evita riesgos: no tocas tu equipo
  real y puedes repetir hasta que quede perfecta. Si activaste "modo VM"
  (particionado automatico), la instalacion sera 100% desatendida.

OPCION A - HYPER-V (incluido en Windows Pro/Enterprise)
  1) Activa Hyper-V: WPI -> "Caracteristicas de Windows" -> Hyper-V ->
     Habilitar (pide reinicio). O: Habilitar caracteristica desde Windows.
  2) Abre "Administrador de Hyper-V" -> Accion -> Nueva -> Maquina virtual.
  3) Generacion 2 (UEFI). RAM 4096+ MB. Crea un disco virtual de 64 GB.
  4) En "Opciones de instalacion" elige tu ISO recien creada.
  5) IMPORTANTE (Windows 11): en la VM -> Configuracion -> Seguridad ->
     activa "Modulo de plataforma segura" (TPM) y Secure Boot (plantilla
     "Microsoft Windows"). Si usaste bypass W11, puedes dejarlo sin TPM.
  6) Arranca. Si pide "Pulsa una tecla para arrancar del DVD", pulsala.

OPCION B - VIRTUALBOX (gratuito)
  IMPORTANTE: tu ISO YA lleva su propio autounattend.xml. VirtualBox, al detectarlo,
  intenta hacer SU PROPIA "instalacion desatendida" y CHOCA (error VERR_ALREADY_EXISTS
  con autounattend.xml / aux-iso.viso, la VM se aborta). Para evitarlo, hay que
  OMITIR la instalacion desatendida de VirtualBox:
  1) Instalalo con WPI (Utilidades -> Oracle VirtualBox).
  2) Nueva -> nombre + elige tu ISO. En la pantalla de instalacion desatendida marca
     "Omitir instalacion desatendida" / "Skip Unattended Installation" (CLAVE).
     (Alternativa: crea la VM SIN elegir la ISO y luego anadela en Almacenamiento.)
  3) Tipo Windows 11/10 64-bit. RAM 4096+ MB, disco 64 GB. Habilita EFI en Sistema.
  4) Almacenamiento -> controladora IDE/SATA -> tu ISO como disco optico.
  5) En Windows 11 sin TPM: usa el bypass que ya incluye tu ISO.
  6) Arranca la VM (usara el autounattend.xml de DENTRO de tu ISO).

OPCION C - VMWARE WORKSTATION PLAYER (gratuito uso personal)
  1) New Virtual Machine -> Installer disc image (iso) -> tu ISO.
  2) IMPORTANTE: si VMware ofrece "Easy Install", DESACTIVALO (tu ISO ya es
     desatendida); si no, chocaria igual que VirtualBox.
  3) Firmware UEFI, 4 GB RAM, 64 GB disco. Enciende.

COMPROBACIONES TRAS INSTALAR
  - Que arranca sin pedir cuenta Microsoft (si pusiste cuenta local).
  - Que el bloatware elegido NO esta.
  - Que en el primer inicio de sesion WPI arranca e instala tus apps
    (ventana de WPI o consola con winget). Dale tiempo y red.
  - Que los drivers inyectados aparecen (Administrador de dispositivos).

SI ALGO FALLA
  - Revisa el log del creador: WPI_ISO_Kit\logs\crear_iso_*.log
  - Vuelve a generar el kit cambiando lo que falle y reconstruye la ISO.
  - Para Windows 11 en VM antigua: asegura UEFI + (TPM o bypass activado).
  - VirtualBox aborta con "autounattend.xml / aux-iso.viso VERR_ALREADY_EXISTS":
    estas dejando que VirtualBox haga SU desatendido. Recrea la VM marcando
    "Omitir instalacion desatendida" (tu ISO ya trae el suyo).
  - PANTALLA NEGRA tras instalar (en VM):
    * Si la CPU de la VM esta alta y/o hay cursor: es NORMAL. Windows hace el primer
      arranque y el WPI instala tus apps con winget en segundo plano (10-20 min).
      Mueve el raton para despertar la pantalla y espera.
    * Si sigue negra >15 min, sin cursor y CPU a 0: es el bug de video de VirtualBox
      con Windows 11. Apaga la VM y pon: Pantalla -> Memoria de video 128 MB +
      Controlador VBoxSVGA + sin Aceleracion 3D. Enciende de nuevo.
================================================================
'@
}

# Genera el contenido de autounattend.xml a partir de la config elegida.
function New-IsoAutounattendXml {
    param($Cfg)
    $locale = [string]$Cfg.Locale; if (-not $locale) { $locale = 'es-ES' }
    $acct   = [string]$Cfg.AccountName; if (-not $acct) { $acct = 'Usuario' }
    $idx    = [int]$Cfg.EditionIndex; if ($idx -lt 1) { $idx = 1 }
    $pass = ''
    if ($Cfg.AccountPassword) { $pass = [string]$Cfg.AccountPassword }
    $passEsc = $pass -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
    # Escapar tambien el nombre de cuenta: un '&', '<', '>', comilla o apostrofe crudo
    # rompe el XML del autounattend y vuelve a provocar el fallo de instalacion.
    $acctEsc = $acct -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'

    $labConfig = ''
    if ($Cfg.BypassW11) {
        $labConfig = @"
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add"><Order>1</Order><Path>reg add HKLM\System\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add"><Order>2</Order><Path>reg add HKLM\System\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add"><Order>3</Order><Path>reg add HKLM\System\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add"><Order>4</Order><Path>reg add HKLM\System\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add"><Order>5</Order><Path>reg add HKLM\System\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
            </RunSynchronous>
"@
    }

    $diskAndImage = ''
    if ($Cfg.VmMode) {
        $diskAndImage = @"
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                    <CreatePartitions>
                        <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>300</Size></CreatePartition>
                        <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition>
                        <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition>
                        <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID></ModifyPartition>
                        <ModifyPartition wcm:action="add"><Order>3</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>
                    </ModifyPartitions>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>
                    <InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/INDEX</Key><Value>$idx</Value></MetaData></InstallFrom>
                </OSImage>
            </ImageInstall>
"@
    }

    $firstLogon = ''
    $wpiArgs = ''
    if ($Cfg.InstallApps) { $wpiArgs += ' -Preset "C:\WPI\preset_apps.txt"' }
    if ($Cfg.TweakNames -and @($Cfg.TweakNames).Count -gt 0) {
        # P0: pasamos la RUTA del preset, no los nombres en linea. Evita el limite de
        # 1024 caracteres del <CommandLine> y las comillas en los nombres (OOBE 0x8030000C).
        $wpiArgs += ' -Tweaks "C:\WPI\preset_tweaks.txt"'
    }
    if ($wpiArgs) {
        # Llamamos a PowerShell DIRECTAMENTE sobre el .ps1 (no dependemos del .bat, que
        # podria faltar). start "" lanza async para que el setup no se quede esperando.
        $cmd = 'cmd /c start "" powershell -NoProfile -ExecutionPolicy Bypass -File "C:\WPI\WPI_Moderno.ps1"' + $wpiArgs + ' -FirstBoot'
        # Red de seguridad: Windows Setup limita <CommandLine> a 1024 caracteres. Con rutas
        # (no nombres) nunca deberia acercarse; si pasara, avisamos en el log forense.
        if ($cmd.Length -gt 1000) { try { W warn ('CommandLine del autounattend muy largo ({0} chars).' -f $cmd.Length) } catch {} }
        $cmdEsc = $cmd -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
        $firstLogon = @"
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>$cmdEsc</CommandLine>
                    <Description>WPI: apps y tweaks elegidos</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
"@
    }

@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SetupUILanguage><UILanguage>$locale</UILanguage></SetupUILanguage>
            <InputLocale>$locale</InputLocale>
            <SystemLocale>$locale</SystemLocale>
            <UILanguage>$locale</UILanguage>
            <UserLocale>$locale</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
$labConfig
$diskAndImage
            <UserData><AcceptEula>true</AcceptEula></UserData>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>$([string]([bool]$Cfg.LocalAccount).ToString().ToLower())</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>$acctEsc</Name>
                        <Group>Administrators</Group>
                        <DisplayName>$acctEsc</DisplayName>
                        <Password>
                            <Value>$passEsc</Value>
                            <PlainText>true</PlainText>
                        </Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Enabled>true</Enabled>
                <Username>$acctEsc</Username>
                <LogonCount>1</LogonCount>
                <Password>
                    <Value>$passEsc</Value>
                    <PlainText>true</PlainText>
                </Password>
            </AutoLogon>
$firstLogon
        </component>
    </settings>
</unattend>
"@
}

# Devuelve el TEXTO del script motor (Crear_ISO_WPI.ps1) que hace el trabajo
# real: montar la imagen, inyectar/limpiar y reensamblar la ISO con oscdimg.
# Se entrega como here-string literal: lee kit-config.json del propio kit.
function New-IsoBuildScriptText {
@'
# ============================================================
#  Crear_ISO_WPI.ps1  -  Motor de creacion de ISO (generado por WPI)
#  Lee kit-config.json (junto a este script) y construye la ISO.
#  Ejecutar COMO ADMINISTRADOR. Deja log en .\logs\crear_iso_*.log
# ============================================================
param([string]$ConfigPath = (Join-Path $PSScriptRoot 'kit-config.json'))
$ErrorActionPreference = 'Stop'

$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir ('crear_iso_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
function Log($m) { $s = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m); Write-Host $s; Add-Content -Path $logFile -Value $s }
function Die($m) { Log ('ERROR: ' + $m); Write-Host ''; Write-Host 'La creacion se detuvo. Revisa el log.' -ForegroundColor Red; Read-Host 'Pulsa Enter para salir'; exit 1 }
function Prog($p, $s) { try { Write-Progress -Activity 'Creando ISO WPI a medida' -Status $s -PercentComplete ([math]::Min(100, [math]::Max(0, [int]$p))) } catch {} }

# --- Admin ---
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Die 'Hay que ejecutar este script como administrador.' }

if (-not (Test-Path $ConfigPath)) { Die ('No se encuentra ' + $ConfigPath) }
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
Log '== CREADOR DE ISO WPI =='
Log ('ISO origen   : ' + $cfg.SourceIso)
Log ('ISO salida   : ' + $cfg.OutputIso)
Log ('Trabajo      : ' + $cfg.WorkDir)

# --- oscdimg ---
$oscdimg = [string]$cfg.OscdimgPath
if (-not $oscdimg -or -not (Test-Path $oscdimg)) {
    foreach ($c in @("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe","${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe")) { if (Test-Path $c) { $oscdimg = $c; break } }
}
if (-not $oscdimg -or -not (Test-Path $oscdimg)) { Die 'No se encuentra oscdimg.exe. Instala Windows ADK.' }
if (-not (Test-Path $cfg.SourceIso)) { Die ('No se encuentra la ISO origen: ' + $cfg.SourceIso) }

$work   = [string]$cfg.WorkDir
$isoDir = Join-Path $work 'iso'
$mount  = Join-Path $work 'mount'
foreach ($d in @($work, $mount)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (Test-Path $isoDir) { Log 'Limpiando carpeta de trabajo previa...'; attrib -r ($isoDir + '\*.*') /s /d 2>$null; Remove-Item $isoDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $isoDir -Force | Out-Null

# --- 1) Copiar contenido de la ISO origen ---
Log 'Montando la ISO origen y copiando su contenido...'
$di = Mount-DiskImage -ImagePath $cfg.SourceIso -PassThru
Start-Sleep -Seconds 2
$vol = ($di | Get-Volume).DriveLetter
if (-not $vol) { Die 'No se pudo montar la ISO origen.' }
$src = ($vol + ':\')
robocopy $src $isoDir /e /np /r:1 /w:1 | Out-Null
Dismount-DiskImage -ImagePath $cfg.SourceIso | Out-Null
attrib -r ($isoDir + '\*.*') /s /d 2>$null
Log 'Contenido copiado.'
Prog 6 'Contenido de la ISO copiado. Preparando ediciones...'

# --- 2) Localizar/convertir la imagen de instalacion ---
$wim = Join-Path $isoDir 'sources\install.wim'
$esd = Join-Path $isoDir 'sources\install.esd'
if (-not (Test-Path $wim) -and (Test-Path $esd)) {
    Log 'install.esd detectado: convirtiendo a install.wim (TODAS las ediciones, tarda)...'
    try {
        $esdImgs = @(Get-WindowsImage -ImagePath $esd)
        foreach ($im in $esdImgs) {
            Log ('   exportando edicion ' + $im.ImageIndex + ' (' + $im.ImageName + ')...')
            dism /Export-Image /SourceImageFile:"$esd" /SourceIndex:$($im.ImageIndex) /DestinationImageFile:"$wim" /Compress:max /CheckIntegrity | Out-Null
        }
    } catch { Die ('No se pudo convertir install.esd: ' + $_.Exception.Message) }
    Remove-Item $esd -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path $wim)) { Die 'No se encuentra sources\install.wim ni install.esd en la ISO.' }
Log 'Ediciones disponibles en la imagen:'
(dism /Get-WimInfo /WimFile:"$wim") | ForEach-Object { Log ('   ' + $_) }

# --- 2b) Decidir SOBRE QUE ediciones se aplica la personalizacion ---
# Por defecto se aplica a TODAS las ediciones detectadas: asi, elijas la que
# elijas en la instalacion, siempre ira personalizada (debloat, drivers, C:\WPI).
# Si SingleEdition es true, se reduce a una sola (EditionIndex, o la mayor si 0).
attrib -r "$wim" 2>$null
$allImgs = @(Get-WindowsImage -ImagePath $wim)
if ($cfg.SingleEdition -eq $true) {
    $pick = [int]$cfg.EditionIndex
    if ($pick -lt 1) {
        $pick = 1; $bestSize = 0
        foreach ($im in $allImgs) { if ([long]$im.ImageSize -gt $bestSize) { $bestSize = [long]$im.ImageSize; $pick = [int]$im.ImageIndex } }
    }
    Log ('Modo EDICION UNICA: se conservara solo el indice ' + $pick + '.')
    $wimSingle = Join-Path $isoDir 'sources\install_single.wim'
    if (Test-Path $wimSingle) { Remove-Item $wimSingle -Force -ErrorAction SilentlyContinue }
    dism /Export-Image /SourceImageFile:"$wim" /SourceIndex:$pick /DestinationImageFile:"$wimSingle" /Compress:max /CheckIntegrity | Out-Null
    if (-not (Test-Path $wimSingle)) { Die 'No se pudo exportar la edicion unica (install_single.wim).' }
    Remove-Item $wim -Force -ErrorAction SilentlyContinue
    Rename-Item $wimSingle $wim
    attrib -r "$wim" 2>$null
    $indices = @(1)
} else {
    $indices = @($allImgs | ForEach-Object { [int]$_.ImageIndex })
    Log ('Modo TODAS LAS EDICIONES: se personalizaran ' + $indices.Count + ' ediciones.')
}

# --- 2c) winget OFFLINE: integrar el instalador en payload\winget (autosuficiencia) ---
$payload = Join-Path $PSScriptRoot 'payload\WPI'
$wgDir = Join-Path $payload 'winget'
$tieneWg = $false
if (Test-Path $wgDir) { $tieneWg = (@(Get-ChildItem $wgDir -Filter *.msixbundle -ErrorAction SilentlyContinue).Count -gt 0) }
if ($tieneWg) {
    Log 'winget offline: ya hay instalador en payload\winget; no se descarga.'
} else {
    Log 'winget offline: descargando el instalador de winget para integrarlo en la ISO...'
    if (-not (Test-Path $wgDir)) { New-Item -ItemType Directory -Path $wgDir -Force | Out-Null }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $okWg = $false
    try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -Headers @{ 'User-Agent' = 'WPI' } -TimeoutSec 60
        foreach ($a in $rel.assets) {
            $nm = [string]$a.name
            if ($nm -like '*.msixbundle' -or $nm -like '*License*.xml' -or $nm -like '*Dependencies*.zip') {
                Log ('   bajando ' + $nm + ' ...')
                Invoke-WebRequest -Uri $a.browser_download_url -OutFile (Join-Path $wgDir $nm) -UseBasicParsing -TimeoutSec 900
            }
        }
        $zip = Get-ChildItem $wgDir -Filter '*Dependencies*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($zip) {
            try {
                $tmpx = Join-Path $env:TEMP ('wgdep_' + [guid]::NewGuid().ToString('N'))
                Expand-Archive -Path $zip.FullName -DestinationPath $tmpx -Force
                Get-ChildItem $tmpx -Recurse -Include '*.appx','*.msix' -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match '\\x64\\' } |
                    ForEach-Object { Log ('   dependencia ' + $_.Name); Copy-Item $_.FullName (Join-Path $wgDir $_.Name) -Force }
                Remove-Item $tmpx -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item $zip.FullName -Force -ErrorAction SilentlyContinue
            } catch { Log ('   aviso: no se pudieron extraer dependencias: ' + $_.Exception.Message) }
        }
        $okWg = (@(Get-ChildItem $wgDir -Filter *.msixbundle -ErrorAction SilentlyContinue).Count -gt 0)
    } catch { Log ('   aviso: fallo la descarga via GitHub: ' + $_.Exception.Message) }
    if (-not $okWg) {
        try {
            Log '   probando aka.ms/getwinget ...'
            Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile (Join-Path $wgDir 'Microsoft.DesktopAppInstaller.msixbundle') -UseBasicParsing -TimeoutSec 900
            $okWg = $true
        } catch { Log ('   aviso: tampoco via aka.ms: ' + $_.Exception.Message) }
    }
    if ($okWg) { Log 'winget offline: instalador integrado (ira a C:\WPI\winget en cada edicion).' }
    else { Log '*** AVISO: no se pudo descargar winget. La ISO usara solo el modo online en el primer arranque. ***' }
}

# --- 3 a 8) Personalizar CADA edicion seleccionada (montar, drivers, debloat, WPI, guardar) ---
$nEd = $indices.Count; $kEd = 0
foreach ($ei in $indices) {
    $kEd++
    $p0 = 10 + [int]((($kEd - 1) * 80) / $nEd); $pPer = [int](80 / $nEd)
    Log ('================ Edicion ' + $kEd + '/' + $nEd + ' (indice ' + $ei + ') ================')
    Prog $p0 ('Edicion ' + $kEd + '/' + $nEd + ': montando imagen (tarda)...')
    Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $mount } | ForEach-Object { Dismount-WindowsImage -Path $mount -Discard -ErrorAction SilentlyContinue | Out-Null }
    Log 'Montando la edicion (puede tardar)...'
    Mount-WindowsImage -ImagePath $wim -Index $ei -Path $mount | Out-Null

    # Drivers
    Prog ($p0 + [int]($pPer * 0.25)) ('Edicion ' + $kEd + '/' + $nEd + ': inyectando drivers...')
    if ($cfg.InjectDrivers -and $cfg.DriversDir -and (Test-Path $cfg.DriversDir)) {
        $infs = @(Get-ChildItem -Path $cfg.DriversDir -Filter *.inf -Recurse -ErrorAction SilentlyContinue)
        Log ('Inyectando drivers desde ' + $cfg.DriversDir + '  (' + $infs.Count + ' archivos .inf encontrados)...')
        $nMostrar = [Math]::Min($infs.Count, 40)
        for ($di = 0; $di -lt $nMostrar; $di++) { Log ('   driver: ' + $infs[$di].Name) }
        if ($infs.Count -gt $nMostrar) { Log ('   ... y ' + ($infs.Count - $nMostrar) + ' mas') }
        try {
            Add-WindowsDriver -Path $mount -Driver $cfg.DriversDir -Recurse -ForceUnsigned -ErrorAction Stop | Out-Null
            $inj = @(Get-WindowsDriver -Path $mount -ErrorAction SilentlyContinue | Where-Object { -not $_.Inbox })
            Log ('[OK] Drivers inyectados. La edicion contiene ahora ' + $inj.Count + ' paquetes de terceros.')
        } catch { Log ('Aviso: fallo parcial al inyectar drivers: ' + $_.Exception.Message) }
    } else { Log 'Sin inyeccion de drivers (no seleccionado o carpeta vacia).' }

    # Debloat offline (Appx aprovisionadas)
    Prog ($p0 + [int]($pPer * 0.45)) ('Edicion ' + $kEd + '/' + $nEd + ': quitando bloatware...')
    if ($cfg.Debloat -and $cfg.DebloatPkgs) {
        Log 'Quitando Appx aprovisionadas (debloat offline)...'
        $prov = Get-AppxProvisionedPackage -Path $mount
        $nPat = 0
        foreach ($pat in $cfg.DebloatPkgs) {
            $nPat++
            $patt = ([string]$pat).TrimEnd('*')
            $hits = @($prov | Where-Object { $_.DisplayName -like ($patt + '*') })
            if ($hits.Count -eq 0) {
                Log ('   no estaba presente: ' + $pat)
            } else {
                foreach ($pp in $hits) {
                    try { Remove-AppxProvisionedPackage -Path $mount -PackageName $pp.PackageName -ErrorAction Stop | Out-Null; Log ('   quitado: ' + $pp.DisplayName) }
                    catch { Log ('   fallo: ' + $pp.DisplayName + ' :: ' + $_.Exception.Message) }
                }
            }
        }
        Log ('Debloat offline: ' + $nPat + ' patrones procesados.')
    } else { Log 'Sin debloat offline.' }

    # ---- Politica offline anti-reinstalacion de OneDrive (hive SOFTWARE de la imagen) ----
    # Carga el hive SOFTWARE de la imagen montada como WPISOFT (nombre unico para no
    # colisionar con otros hives cargados, p.ej. WPIDEF del NTUSER.DAT Default) y fija
    # DisableFileSyncNGSC=1 a nivel de MAQUINA de la imagen, NO del host.
    try {
        $oneDriveHive = "$mount\Windows\System32\config\SOFTWARE"
        if (Test-Path $oneDriveHive) {
            Log 'OneDrive: aplicando politica offline DisableFileSyncNGSC (hive WPISOFT)...'
            reg load HKLM\WPISOFT "$oneDriveHive" 2>$null | Out-Null
            try {
                reg add "HKLM\WPISOFT\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { Log '   [OK] DisableFileSyncNGSC=1 aplicado en la imagen.' }
                else { Log '   aviso: no se pudo escribir DisableFileSyncNGSC.' }
            } finally {
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                reg unload HKLM\WPISOFT 2>$null | Out-Null
            }
        } else { Log 'OneDrive: no se encontro el hive SOFTWARE de la imagen; se omite la politica offline.' }
    } catch { Log ('OneDrive: aviso al aplicar politica offline: ' + $_.Exception.Message) }

    # ---- Desactivar CDM en el hive del usuario Default (Cambio 5, offline) ----
    # Carga el NTUSER.DAT del usuario Default como WPIDEF (nombre unico para NO colisionar
    # con WPISOFT, el hive SOFTWARE de la imagen). Desactiva las claves del Content Delivery
    # Manager, de modo que los usuarios NUEVOS no reciban apps sugeridas ni anclajes fantasma.
    try {
        $defHive = "$mount\Users\Default\NTUSER.DAT"
        if (Test-Path $defHive) {
            Log 'CDM: desactivando Content Delivery Manager en el hive Default (WPIDEF)...'
            reg load HKLM\WPIDEF "$defHive" 2>$null | Out-Null
            try {
                $cdmKey = 'HKLM\WPIDEF\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                $cdmVals = @(
                    'ContentDeliveryAllowed','SilentInstalledAppsEnabled','PreInstalledAppsEnabled',
                    'PreInstalledAppsEverEnabled','OemPreInstalledAppsEnabled','SubscribedContentEnabled',
                    'SubscribedContent-338388Enabled','SubscribedContent-338389Enabled',
                    'SubscribedContent-310093Enabled','SubscribedContent-353698Enabled',
                    'SystemPaneSuggestionsEnabled','FeatureManagementEnabled'
                )
                foreach ($v in $cdmVals) {
                    reg add "$cdmKey" /v $v /t REG_DWORD /d 0 /f 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) { Log ('   [OK] CDM ' + $v + '=0') }
                    else { Log ('   aviso: no se pudo escribir CDM ' + $v) }
                }
            } finally {
                # Libera handles del hive antes de descargarlo (unload garantizado).
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                reg unload HKLM\WPIDEF 2>$null | Out-Null
            }
        } else { Log 'CDM: no se encontro el NTUSER.DAT del usuario Default; se omite la desactivacion offline.' }
    } catch { Log ('CDM: aviso al desactivar Content Delivery Manager: ' + $_.Exception.Message) }

    # ---- Politica de MAQUINA: desactivar funciones de consumidor (CloudContent) ----
    # El bloque de OneDrive ya cargo y DESCARGO WPISOFT antes; aqui se vuelve a cargar y
    # descargar de forma autocontenida (sin dejar el hive montado ni duplicar un load sin
    # su unload). DisableWindowsConsumerFeatures + DisableConsumerAccountStateContent.
    try {
        $cloudHive = "$mount\Windows\System32\config\SOFTWARE"
        if (Test-Path $cloudHive) {
            Log 'CloudContent: aplicando politica de maquina (hive WPISOFT)...'
            reg load HKLM\WPISOFT "$cloudHive" 2>$null | Out-Null
            try {
                $ccKey = 'HKLM\WPISOFT\Policies\Microsoft\Windows\CloudContent'
                reg add "$ccKey" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { Log '   [OK] DisableWindowsConsumerFeatures=1' }
                else { Log '   aviso: no se pudo escribir DisableWindowsConsumerFeatures.' }
                reg add "$ccKey" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { Log '   [OK] DisableConsumerAccountStateContent=1' }
                else { Log '   aviso: no se pudo escribir DisableConsumerAccountStateContent.' }
            } finally {
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                reg unload HKLM\WPISOFT 2>$null | Out-Null
            }
        } else { Log 'CloudContent: no se encontro el hive SOFTWARE; se omite la politica de maquina.' }
    } catch { Log ('CloudContent: aviso al aplicar politica de maquina: ' + $_.Exception.Message) }

    # ---- Limpiar anclajes del menu Inicio del usuario Default (start2.bin) ----
    try {
        $start2 = "$mount\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
        if (Test-Path $start2) {
            Remove-Item $start2 -Force -ErrorAction Stop
            Log 'Inicio: start2.bin del usuario Default eliminado (anclajes limpiados).'
        } else { Log 'Inicio: no existe start2.bin en el perfil Default; nada que limpiar.' }
    } catch { Log ('Inicio: aviso al limpiar start2.bin del usuario Default: ' + $_.Exception.Message) }

    # Tweaks: se aplican en el PRIMER ARRANQUE (autounattend -> WPI -Tweaks)
    Log 'Tweaks: se aplicaran en el primer arranque via WPI (-Tweaks). No se tocan hives offline.'

    # Copiar WPI + presets al interior de la edicion (C:\WPI)
    Prog ($p0 + [int]($pPer * 0.65)) ('Edicion ' + $kEd + '/' + $nEd + ': copiando WPI y presets...')
    if (Test-Path $payload) {
        $dstWpi = Join-Path $mount 'WPI'
        if (-not (Test-Path $dstWpi)) { New-Item -ItemType Directory -Path $dstWpi -Force | Out-Null }
        robocopy $payload $dstWpi /e /np /r:1 /w:1 | Out-Null
        $preset = Join-Path $PSScriptRoot 'preset_apps.txt'
        if (Test-Path $preset) { Copy-Item $preset (Join-Path $dstWpi 'preset_apps.txt') -Force }
        $presetTw = Join-Path $PSScriptRoot 'preset_tweaks.txt'
        if (Test-Path $presetTw) { Copy-Item $presetTw (Join-Path $dstWpi 'preset_tweaks.txt') -Force }
        Log 'WPI y presets (apps + tweaks) copiados a C:\WPI dentro de la edicion.'
        if (-not (Test-Path (Join-Path $dstWpi 'WPI_Moderno.ps1'))) { Log '*** AVISO GRAVE: WPI_Moderno.ps1 NO quedo en C:\WPI; el primer arranque NO aplicara apps/tweaks. ***' }
        if (-not (Test-Path (Join-Path $dstWpi 'preset_tweaks.txt'))) { Log 'Aviso: preset_tweaks.txt no esta en C:\WPI (no habia tweaks elegidos, o no se copio).' }
    } else { Log '*** AVISO GRAVE: no existe la carpeta payload\WPI; la edicion quedara SIN C:\WPI. ***' }

    Prog ($p0 + [int]($pPer * 0.80)) ('Edicion ' + $kEd + '/' + $nEd + ': guardando cambios (tarda varios minutos)...')
    Log 'Guardando cambios y desmontando la edicion (tarda)...'
    Dismount-WindowsImage -Path $mount -Save | Out-Null
}

# --- 9) Copiar autounattend.xml a la raiz de la ISO ---
$auf = Join-Path $PSScriptRoot 'autounattend.xml'
if (Test-Path $auf) { Copy-Item $auf (Join-Path $isoDir 'autounattend.xml') -Force; Log 'autounattend.xml incluido.' }

# --- 9b) Carpeta WPI VISIBLE en la raiz de la ISO/USB (acceso facil al explorar el USB) ---
try {
    $rootWpi = Join-Path $isoDir 'WPI'
    if (-not (Test-Path $rootWpi)) { New-Item -ItemType Directory -Path $rootWpi -Force | Out-Null }
    if (Test-Path $payload) { robocopy $payload $rootWpi /e /np /r:1 /w:1 | Out-Null }
    $rp1 = Join-Path $PSScriptRoot 'preset_apps.txt';   if (Test-Path $rp1) { Copy-Item $rp1 (Join-Path $rootWpi 'preset_apps.txt') -Force }
    $rp2 = Join-Path $PSScriptRoot 'preset_tweaks.txt'; if (Test-Path $rp2) { Copy-Item $rp2 (Join-Path $rootWpi 'preset_tweaks.txt') -Force }
    $leeme = @(
        'WPI - Carpeta de la aplicacion (acceso directo desde el USB)',
        '===========================================================',
        '',
        'Para ABRIR el WPI: doble clic en  Iniciar_WPI.bat  (pedira permisos de administrador).',
        'Alternativa: clic derecho en WPI_Moderno.ps1 > Ejecutar con PowerShell (como administrador).',
        '',
        'Esta es una copia accesible incluida en el USB. La instalacion tambien deja',
        'una copia en C:\WPI y accesos directos en el Escritorio tras la primera',
        'configuracion. Si borras C:\WPI, siempre puedes volver aqui (al USB) y abrir',
        'esta misma carpeta para seguir usando el WPI.'
    ) -join "`r`n"
    Set-WpiContent -Path (Join-Path $rootWpi 'LEEME.txt') -Value $leeme
    Log 'Carpeta WPI visible anadida a la raiz de la ISO (acceso facil desde el USB).'
} catch { Log ('Aviso: no se pudo crear la carpeta WPI visible en la raiz: ' + $_.Exception.Message) }

# --- 10) Reensamblar la ISO con oscdimg (UEFI + BIOS) ---
$etfs = Join-Path $isoDir 'boot\etfsboot.com'
$efisys = Join-Path $isoDir 'efi\microsoft\boot\efisys.bin'
if (-not (Test-Path $efisys)) { $efisys = Join-Path $isoDir 'efi\boot\efisys.bin' }
$outIso = [string]$cfg.OutputIso
$outDir = Split-Path $outIso -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
Log 'Ensamblando la ISO final con oscdimg...'
Prog 95 'Ensamblando la ISO final (oscdimg)...'
if ((Test-Path $etfs) -and (Test-Path $efisys)) {
    $bootData = '-bootdata:2#p0,e,b"' + $etfs + '"#pEF,e,b"' + $efisys + '"'
} elseif (Test-Path $efisys) {
    $bootData = '-bootdata:1#pEF,e,b"' + $efisys + '"'
} else { Die 'No se encontraron los sectores de arranque (etfsboot/efisys) en la ISO.' }
$cmdLine = '"' + $oscdimg + '" -m -o -u2 -udfver102 ' + $bootData + ' "' + $isoDir + '" "' + $outIso + '"'
$cmdFile = Join-Path $work '_oscdimg.cmd'
Set-Content -Path $cmdFile -Value $cmdLine -Encoding Ascii
$p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', ('"' + $cmdFile + '"') -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0) { Die ('oscdimg fallo con codigo ' + $p.ExitCode) }

Log ''
Log ('LISTO. ISO creada en: ' + $outIso)
Prog 100 'ISO creada correctamente.'
try { Write-Progress -Activity 'Creando ISO WPI a medida' -Completed } catch {}
Log 'Puedes probarla en una maquina virtual (ver GUIA_VM.md).'
Write-Host ''
Write-Host '====================================================' -ForegroundColor Green
Write-Host (' ISO creada: ' + $outIso) -ForegroundColor Green
Write-Host '====================================================' -ForegroundColor Green
Read-Host 'Pulsa Enter para salir'
'@
}

# Genera el KIT completo (carpeta con config, scripts, payload y guias).
# Devuelve la ruta del kit, o $null si falta algo obligatorio.
function Get-IniciarBatText {
    return @'
@echo off
chcp 65001 >nul
setlocal enableextensions
title WPI Moderno - Lanzador
set "WPIDIR=%~dp0"
set "PS1=%WPIDIR%WPI_Moderno.ps1"
if not exist "%PS1%" ( echo No se encuentra WPI_Moderno.ps1 junto a este .bat. & pause & exit /b 1 )
net session >nul 2>&1
if errorlevel 1 (
    if "%~1"=="" ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs" ) else ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs" )
    exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1%" %*
set "EC=%errorlevel%"
if not "%EC%"=="0" ( echo. & echo WPI termino con codigo %EC%. & pause )
endlocal
'@
}
function Resolve-SuiteReparacionPath {
    # Devuelve la ruta al .bat principal de la suite del idioma activo, o $null si no existe.
    # ES -> Suite_Reparacion_ES\Suite_Reparacion_TodoEnUno.bat
    # EN -> Suite_Reparacion_EN\Repair_Suite_AllInOne.bat
    $folderName = if ($script:Lang -eq 'en') { 'Suite_Reparacion_EN' } else { 'Suite_Reparacion_ES' }
    $batName    = if ($script:Lang -eq 'en') { 'Repair_Suite_AllInOne.bat' } else { 'Suite_Reparacion_TodoEnUno.bat' }
    $path = Join-Path $PSScriptRoot (Join-Path $folderName $batName)
    if (Test-Path $path) { return $path }
    return $null
}

function Test-SuiteReparacionReady {
    # Checks the active language suite folder and its main launcher.
    $folderName = if ($script:Lang -eq 'en') { 'Suite_Reparacion_EN' } else { 'Suite_Reparacion_ES' }
    $batName    = if ($script:Lang -eq 'en') { 'Repair_Suite_AllInOne.bat' } else { 'Suite_Reparacion_TodoEnUno.bat' }
    $folderPath = Join-Path $PSScriptRoot $folderName
    $batPath    = Join-Path $folderPath $batName
    [pscustomobject]@{
        FolderName = $folderName
        BatName    = $batName
        FolderPath = $folderPath
        BatPath    = $batPath
        FolderOk   = (Test-Path $folderPath)
        BatOk      = (Test-Path $batPath)
    }
}

function Get-IsoVerifyScriptText {
    return @'
param([string]$Iso, [string]$ExpectedLang = '')
try { $Host.UI.RawUI.WindowTitle = 'WPI - Verificador de ISO' } catch {}
$ErrorActionPreference = 'SilentlyContinue'
$mnt = 'C:\_wpichk'
$score = 0; $max = 0; $fatal = 0
function Line($c){ if (-not $c){ $c = '=' }; ('  ' + ($c * 62)) }
function Hdr($t){ Write-Host ''; Write-Host (Line '=') -ForegroundColor DarkCyan; Write-Host ('   ' + $t) -ForegroundColor Cyan; Write-Host (Line '=') -ForegroundColor DarkCyan }
function OK($m){ Write-Host ('   [OK] ' + $m) -ForegroundColor Green }
function NO($m){ Write-Host ('   [X]  ' + $m) -ForegroundColor Red }
function WN($m){ Write-Host ('   [!]  ' + $m) -ForegroundColor Yellow }
function IN($m){ Write-Host ('        ' + $m) -ForegroundColor Gray }
function Chk($cond,$okMsg,$noMsg,$warn){
    $script:max++
    if ($cond){ $script:score++; OK $okMsg }
    elseif ($warn){ WN $noMsg }
    else { NO $noMsg; $script:fatal++ }
}
function Cleanup {
    Get-WindowsImage -Mounted 2>$null | Where-Object { $_.Path -eq $mnt } | ForEach-Object { Dismount-WindowsImage -Path $mnt -Discard 2>$null | Out-Null }
    if ($Iso) { Dismount-DiskImage -ImagePath $Iso 2>$null | Out-Null }
}

try { Clear-Host } catch {}
Write-Host ''
Write-Host '   ==============================================================' -ForegroundColor DarkCyan
Write-Host '            W P I   -   V E R I F I C A D O R   D E   I S O' -ForegroundColor Cyan
Write-Host '            Comprueba que la ISO lo lleva TODO antes de Rufus' -ForegroundColor Gray
Write-Host '   ==============================================================' -ForegroundColor DarkCyan

$adm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $adm) { NO 'Ejecuta esta comprobacion como ADMINISTRADOR (montar la imagen lo requiere).'; Read-Host '   Enter para salir'; exit 1 }

if (-not $Iso) {
    $cands = @(Get-ChildItem -Path $PSScriptRoot -Filter *.iso -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    if ($cands.Count -gt 0) { $Iso = $cands[-1].FullName; IN ('ISO autodetectada (mas reciente de la carpeta): ' + $Iso) }
    else { NO ('No se ha indicado -Iso y no hay ningun .iso en la carpeta: ' + $PSScriptRoot); Read-Host '   Enter para salir'; exit 1 }
}
$Iso = $Iso.Trim('"')
if (-not (Test-Path $Iso)) { NO ('No existe la ISO: ' + $Iso); Read-Host '   Enter para salir'; exit 1 }
$ExpectedLang = $ExpectedLang.Trim().ToUpperInvariant()
if ($ExpectedLang -and $ExpectedLang -notin @('ES','EN')) { NO 'ExpectedLang debe ser ES o EN.'; Read-Host '   Enter para salir'; exit 1 }
IN ('ISO    : ' + $Iso)
IN ('Tamano : ' + ('{0:N2} GB' -f ((Get-Item $Iso).Length / 1GB)))
if ($ExpectedLang) { IN ('Idioma esperado de suite: ' + $ExpectedLang) } else { IN 'Idioma esperado de suite: cualquiera (ES o EN)' }
Cleanup

Hdr 'MONTAJE'
$vol = Mount-DiskImage -ImagePath $Iso -PassThru | Get-Volume
if (-not $vol -or -not $vol.DriveLetter) { NO 'No se pudo montar la ISO.'; Read-Host '   Enter para salir'; exit 1 }
$drv = ([string]$vol.DriveLetter + ':')
OK ('ISO montada en ' + $drv)
$wim = ($drv + '\sources\install.wim'); $fmt = 'WIM'
if (-not (Test-Path $wim)) { $wim = ($drv + '\sources\install.esd'); $fmt = 'ESD' }
Chk (Test-Path $wim) ('Imagen de Windows encontrada (' + $fmt + ')') 'No hay install.wim/esd en \sources.' $false
if (-not (Test-Path $wim)) { Cleanup; Read-Host '   Enter para salir'; exit 1 }

Hdr 'AUTOUNATTEND  (instalacion desatendida)'
$au = ($drv + '\autounattend.xml')
if (Test-Path $au) {
    OK 'autounattend.xml presente en la raiz de la ISO.'
    $xml = Get-Content $au -Raw
    Chk ($xml -match 'WPI_Moderno\.ps1') 'El primer arranque lanza WPI_Moderno.ps1.' 'El autounattend NO llama a WPI_Moderno.ps1.' $false
    Chk ($xml -match '-FirstBoot') 'Marca -FirstBoot (aplica todo y reinicia al final).' 'No aparece -FirstBoot (no reiniciaria solo).' $true
    if ($xml -match 'LabConfig') { IN 'Bypass de requisitos de Windows 11: SI' } else { IN 'Bypass de requisitos de Windows 11: no' }
} else { NO 'No hay autounattend.xml en la raiz: la instalacion NO seria automatica.' }

Hdr 'EDICIONES EN LA IMAGEN'
$imgs = @(Get-WindowsImage -ImagePath $wim)
foreach ($im in $imgs) { IN ('[' + $im.ImageIndex + ']  ' + $im.ImageName) }
IN ('Total de ediciones: ' + $imgs.Count)
if (-not (Test-Path $mnt)) { New-Item -ItemType Directory -Path $mnt -Force | Out-Null }

foreach ($im in $imgs) {
    Hdr ('EDICION [' + $im.ImageIndex + ']  ' + $im.ImageName)
    Mount-WindowsImage -ImagePath $wim -Index $im.ImageIndex -Path $mnt -ReadOnly | Out-Null
    $wpi = Join-Path $mnt 'WPI'
    Chk (Test-Path (Join-Path $wpi 'WPI_Moderno.ps1')) 'C:\WPI\WPI_Moderno.ps1 (motor)' 'FALTA C:\WPI\WPI_Moderno.ps1: no se aplicaria nada.' $false
    Chk (Test-Path (Join-Path $wpi 'Iniciar_WPI.bat')) 'C:\WPI\Iniciar_WPI.bat (lanzador)' 'Falta Iniciar_WPI.bat.' $true
    $suiteEsBat = Join-Path $wpi 'Suite_Reparacion_ES\Suite_Reparacion_TodoEnUno.bat'
    $suiteEnBat = Join-Path $wpi 'Suite_Reparacion_EN\Repair_Suite_AllInOne.bat'
    if ($ExpectedLang -eq 'ES') {
        Chk (Test-Path $suiteEsBat) 'C:\WPI\Suite_Reparacion_ES (suite + launcher)' 'Falta el lanzador principal de la suite espanola.' $true
    } elseif ($ExpectedLang -eq 'EN') {
        Chk (Test-Path $suiteEnBat) 'C:\WPI\Suite_Reparacion_EN (suite + launcher)' 'Falta el lanzador principal de la suite inglesa.' $true
    } else {
        $hasSuite = (Test-Path $suiteEsBat) -or (Test-Path $suiteEnBat)
        Chk ($hasSuite) 'C:\WPI\Suite_Reparacion_XX (suite + launcher)' 'Falta el lanzador principal de la suite de reparacion (ES o EN).' $true
    }
    $pa = Join-Path $wpi 'preset_apps.txt'
    if (Test-Path $pa) { $na = @(Get-Content $pa | Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') }).Count; OK ('preset_apps.txt  (' + $na + ' apps a instalar)') } else { WN 'Sin preset_apps.txt (no instalaria apps).' }
    $pt = Join-Path $wpi 'preset_tweaks.txt'
    if (Test-Path $pt) { $nt = @(Get-Content $pt | Where-Object { $_.Trim() -ne '' }).Count; OK ('preset_tweaks.txt  (' + $nt + ' tweaks a aplicar)') } else { WN 'Sin preset_tweaks.txt.' }
    $wg = Join-Path $wpi 'winget'
    if (Test-Path $wg) { $nb = @(Get-ChildItem $wg -Filter *.msixbundle).Count; OK ('winget OFFLINE integrado  (' + $nb + ' bundle)') } else { WN 'Sin winget offline (usaria modo online en el 1er arranque).' }
    $drvs = @(Get-WindowsDriver -Path $mnt | Where-Object { -not $_.Inbox })
    if ($drvs.Count -gt 0) { OK ('Drivers de terceros inyectados: ' + $drvs.Count) } else { IN 'Drivers de terceros: 0 (no inyectaste, o esta edicion no los lleva).' }
    Dismount-WindowsImage -Path $mnt -Discard | Out-Null
}
Cleanup

Hdr 'VEREDICTO'
IN ('Comprobaciones superadas: ' + $score + ' / ' + $max)
Write-Host ''
if ($fatal -eq 0) {
    Write-Host '   ##############################################################' -ForegroundColor Green
    Write-Host '   #            ISO LISTA PARA GRABAR EN RUFUS                  #' -ForegroundColor Green
    Write-Host '   ##############################################################' -ForegroundColor Green
} else {
    Write-Host ('   !!! HAY ' + $fatal + ' PROBLEMA(S) CRITICO(S). Revisa lo marcado con [X]. !!!') -ForegroundColor Red
    Write-Host '   No grabes hasta corregirlo (recrea la ISO desde cero).' -ForegroundColor Yellow
}
Write-Host ''
Write-Host '   RUFUS: en el dialogo "Experiencia de usuario de Windows" NO marques' -ForegroundColor Yellow
Write-Host '   NINGUNA casilla. Esquema GPT, destino UEFI. Asi se respeta el WPI.' -ForegroundColor Yellow
Write-Host ''
Read-Host '   Pulsa Enter para salir'
'@
}

function New-IsoBuildKit {
    $w = $script:Wiz
    if (-not $w) { Init-IsoWizard; $w = $script:Wiz }
    $srcIso = [string]$w.SrcIso
    $outDir = [string]$w.OutDir
    if (-not $srcIso -or -not (Test-Path $srcIso)) { Show-WpiMessage('Falta la ISO de Windows origen (paso "Origen y salida"). Vuelve atras y eligela.', 'Crear ISO') | Out-Null; return $null }
    if (-not $outDir) { Show-WpiMessage('Falta la carpeta de salida (paso "Origen y salida").', 'Crear ISO') | Out-Null; return $null }
    if (-not (Test-Path $outDir)) { try { New-Item -ItemType Directory -Path $outDir -Force | Out-Null } catch { Show-WpiMessage('No se pudo crear la carpeta de salida.', 'Crear ISO') | Out-Null; return $null } }

    $isoName = [string]$w.IsoName; if (-not $isoName) { $isoName = 'WPI_Custom.iso' }
    if ($isoName -notmatch '\.iso$') { $isoName = $isoName + '.iso' }
    $workDir = [string]$w.WorkDir; if (-not $workDir) { $workDir = (Join-Path $outDir '_work') }
    $editionIdx = 0
    if (([string]$w.Idx) -match '^\d+$') { $editionIdx = [int]$w.Idx }
    $allEditions = $true
    if ($w.ContainsKey('AllEditions')) { $allEditions = [bool]$w.AllEditions }

    $pr = Get-IsoPrereqs
    $selIds = @($w.AppIds)
    $tweakNames = @($w.TweakNames)

    $cfg = [ordered]@{
        SourceIso     = $srcIso
        OutputIso     = (Join-Path $outDir $isoName)
        WorkDir       = $workDir
        EditionIndex  = $editionIdx
        SingleEdition = (-not $allEditions)
        InjectDrivers = [bool]$w.InjectDrivers
        DriversDir    = [string]$w.DriversDir
        Debloat       = [bool](@($w.DebloatPkgs).Count -gt 0)
        DebloatPkgs   = @(@($w.DebloatPkgs) | ForEach-Object { ([string]$_) -split '\|' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        TweakNames    = $tweakNames
        InstallApps   = [bool](@($selIds).Count -gt 0)
        LocalAccount  = [bool]$w.LocalAccount
        BypassW11     = [bool]$w.BypassW11
        VmMode        = [bool]$w.VmMode
        Locale        = $(if ($w.Locale) { [string]$w.Locale } else { 'es-ES' })
        AccountName   = $(if ($w.AccountName) { [string]$w.AccountName } else { 'Usuario' })
        AccountPassword = [string]$w.AccountPassword
        OscdimgPath   = $pr.Oscdimg
    }

    $kit = Join-Path $outDir 'WPI_ISO_Kit'
    try {
        if (-not (Test-Path $kit)) { New-Item -ItemType Directory -Path $kit -Force | Out-Null }
        $payload = Join-Path $kit 'payload\WPI'
        if (-not (Test-Path $payload)) { New-Item -ItemType Directory -Path $payload -Force | Out-Null }
        Set-WpiContent -Path (Join-Path $kit 'kit-config.json') -Value ($cfg | ConvertTo-Json -Depth 5)
        Set-WpiContent -Path (Join-Path $kit 'autounattend.xml') -Value (New-IsoAutounattendXml -Cfg $cfg)
        Set-WpiContent -Path (Join-Path $kit 'Crear_ISO_WPI.ps1') -Value (New-IsoBuildScriptText)
        Set-WpiContent -Path (Join-Path $kit 'GUIA_ISO.md') -Value (Get-IsoGuideText)
        Set-WpiContent -Path (Join-Path $kit 'GUIA_VM.md') -Value (Get-IsoVmGuideText)
        Set-WpiContent -Path (Join-Path $kit 'preset_apps.txt') -Value ($selIds -join "`r`n")
        # P0: los tweaks van a un archivo (un nombre por linea); el autounattend pasa solo la ruta.
        Set-WpiContent -Path (Join-Path $kit 'preset_tweaks.txt') -Value (@($w.TweakNames) -join "`r`n")
        # El propio script en ejecucion (robusto aunque se renombre).
        $wpiPs = if ($PSCommandPath) { $PSCommandPath } else { Join-Path $PSScriptRoot 'WPI_Moderno.ps1' }
        if (Test-Path $wpiPs) { Copy-Item $wpiPs (Join-Path $payload 'WPI_Moderno.ps1') -Force }
        else { Show-WpiMessage('No se encuentra WPI_Moderno.ps1 para incluir en la ISO. Operacion abortada.', 'Crear ISO') | Out-Null; return $null }
        # El lanzador .bat DEBE existir en C:\WPI. Si no esta junto al script, lo generamos
        # aqui mismo para que NUNCA falte (era la causa del fallo "no son correctos" al instalar).
        $wpiBat = (Join-Path $PSScriptRoot 'Iniciar_WPI.bat')
        $batDst = (Join-Path $payload 'Iniciar_WPI.bat')
        if (Test-Path $wpiBat) { Copy-Item $wpiBat $batDst -Force }
        else { Set-Content -Path $batDst -Value (Get-IniciarBatText) -Encoding Ascii }
        # Extras opcionales para que la ISO sea AUTOSUFICIENTE: si estan junto al
        # script, viajan a C:\WPI dentro de la imagen (suite de reparacion, winget offline...).
        # Inyectar la carpeta de la suite de reparacion segun idioma (Suite_Reparacion_ES / Suite_Reparacion_EN).
        $suiteInfo = Test-SuiteReparacionReady
        $suiteSrc = $suiteInfo.FolderPath
        $suiteDst = Join-Path $payload $suiteInfo.FolderName
        if ($suiteInfo.FolderOk -and $suiteInfo.BatOk) {
            # Limpiar el destino si ya existe, para evitar mezclas entre idiomas
            if (Test-Path $suiteDst) { Remove-Item $suiteDst -Recurse -Force | Out-Null }
            robocopy $suiteSrc $suiteDst /e /np /r:1 /w:1 | Out-Null
        } else {
            Write-Host ('*** AVISO: falta la suite de reparacion o su lanzador principal: ' + $suiteInfo.FolderName + '\' + $suiteInfo.BatName) -ForegroundColor Yellow
        }
        # Verificador de ISO junto a la salida (para comprobar antes de Rufus)
        try { Set-WpiContent -Path (Join-Path $outDir 'Verificar_ISO.ps1') -Value (Get-IsoVerifyScriptText) } catch {}
        $wgSrc = Join-Path $PSScriptRoot 'winget'
        if (Test-Path $wgSrc) { robocopy $wgSrc (Join-Path $payload 'winget') /e /np /r:1 /w:1 | Out-Null }
        $script:IsoKitPath = $kit
        return $kit
    } catch {
        Show-WpiMessage(((Tr 'No se pudo generar el kit: {0}') -f $_.Exception.Message), 'Crear ISO') | Out-Null
        return $null
    }
}

# Panel @FINDALL: busqueda global (apps, tweaks, debloat, caracteristicas).
function Add-FindRow {
    param($Parent, [string]$Label, [string]$PanelKey, [string]$Query, [string]$Accent)
    $b = New-Object Windows.Controls.Border
    $b.Background = Get-ThemeBrush($Theme.Card); $b.BorderBrush = Get-ThemeBrush($Theme.CardBorder)
    $b.BorderThickness = New-Object Windows.Thickness(1); $b.CornerRadius = New-Object Windows.CornerRadius(8)
    $b.Margin = New-Object Windows.Thickness(0,4,0,0); $b.Padding = New-Object Windows.Thickness(10,6,10,6)
    $dock = New-Object Windows.Controls.DockPanel; $dock.LastChildFill = $true
    $btn = New-Object Windows.Controls.Button; $btn.Content = 'Ver ->'; $btn.Padding = New-Object Windows.Thickness(10,3,10,3)
    [Windows.Controls.DockPanel]::SetDock($btn, 'Right')
    $btn.Background = Get-ThemeBrush('#FF243042'); $btn.BorderBrush = Get-ThemeBrush($Accent)
    $btn.Tag = [pscustomobject]@{ Panel = $PanelKey; Query = $Query }
    $btn.Add_Click({
        $t = $this.Tag
        $i = $script:SideMap.IndexOf([string]$t.Panel)
        if ($i -ge 0) { $script:SideList.SelectedIndex = $i }
        if ($t.Query) { $sb = $window.FindName('SearchBox'); if ($sb) { $sb.Text = [string]$t.Query } }
    })
    $dock.Children.Add($btn) | Out-Null
    $tb = New-Object Windows.Controls.TextBlock; $tb.Text = $Label; $tb.Foreground = Get-ThemeBrush($Theme.Text)
    $tb.VerticalAlignment = 'Center'; $tb.TextTrimming = 'CharacterEllipsis'
    $dock.Children.Add($tb) | Out-Null
    $b.Child = $dock
    $Parent.Children.Add($b) | Out-Null
}
function Do-FindAll {
    $q = ''
    if ($script:FindBox) { $q = $script:FindBox.Text.Trim() }
    $rp = $script:FindResults
    if (-not $rp) { return }
    $rp.Children.Clear()
    if ($q.Length -lt 2) {
        $h = New-Object Windows.Controls.TextBlock; $h.Text = (Tr 'Escribe al menos 2 letras y pulsa Buscar (o Enter).'); $h.Foreground = Get-ThemeBrush($Theme.Sub); $h.Margin = New-Object Windows.Thickness(0,6,0,0)
        $rp.Children.Add($h) | Out-Null; return
    }
    $ql = $q.ToLower()
    $total = 0
    $isEn = ($script:Lang -eq 'en')
    # Apps
    $apps = @($catalog | Where-Object { ([string]$_.Name).ToLower().Contains($ql) -or ([string]$_.Id).ToLower().Contains($ql) })
    if ($apps.Count -gt 0) {
        $hdr = New-Object Windows.Controls.TextBlock; $hdr.Text = ($(if ($isEn) { 'PROGRAMS  ({0})' } else { 'PROGRAMAS  ({0})' }) -f $apps.Count); $hdr.FontWeight='Bold'; $hdr.Foreground = Get-ThemeBrush($Theme.Install); $hdr.Margin = New-Object Windows.Thickness(0,10,0,2); $rp.Children.Add($hdr) | Out-Null
        foreach ($a in ($apps | Select-Object -First 40)) { Add-FindRow $rp (('{0}   [{1}]  -  {2}' -f $a.Name, $a.Cat, $a.Id)) '@ALL' ([string]$a.Name) $Theme.Install; $total++ }
    }
    # Tweaks
    $tw = @($TweaksCatalog | Where-Object { ([string]$_.Name).ToLower().Contains($ql) })
    if ($tw.Count -gt 0) {
        $hdr = New-Object Windows.Controls.TextBlock; $hdr.Text = ('TWEAKS  ({0})' -f $tw.Count); $hdr.FontWeight='Bold'; $hdr.Foreground = Get-ThemeBrush($Theme.Optimize); $hdr.Margin = New-Object Windows.Thickness(0,10,0,2); $rp.Children.Add($hdr) | Out-Null
        foreach ($t in ($tw | Select-Object -First 40)) { Add-FindRow $rp ([string]$t.Name) '@TWEAKS' '' $Theme.Optimize; $total++ }
    }
    # Debloat
    $db = @($DebloatCatalog | Where-Object { ([string]$_.Name).ToLower().Contains($ql) -or ([string]$_.Pkg).ToLower().Contains($ql) })
    if ($db.Count -gt 0) {
        $hdr = New-Object Windows.Controls.TextBlock; $hdr.Text = ('BLOATWARE  ({0})' -f $db.Count); $hdr.FontWeight='Bold'; $hdr.Foreground = Get-ThemeBrush($Theme.Clean); $hdr.Margin = New-Object Windows.Thickness(0,10,0,2); $rp.Children.Add($hdr) | Out-Null
        foreach ($x in ($db | Select-Object -First 40)) { Add-FindRow $rp ([string]$x.Name) '@DEBLOAT' '' $Theme.Clean; $total++ }
    }
    # Caracteristicas
    if ($FeaturesCatalog) {
        $ft = @($FeaturesCatalog | Where-Object { ([string]$_.Name).ToLower().Contains($ql) })
        if ($ft.Count -gt 0) {
            $hdr = New-Object Windows.Controls.TextBlock; $hdr.Text = ($(if ($isEn) { 'FEATURES  ({0})' } else { 'CARACTERISTICAS  ({0})' }) -f $ft.Count); $hdr.FontWeight='Bold'; $hdr.Foreground = Get-ThemeBrush($Theme.Maintain); $hdr.Margin = New-Object Windows.Thickness(0,10,0,2); $rp.Children.Add($hdr) | Out-Null
            foreach ($f in ($ft | Select-Object -First 40)) { Add-FindRow $rp ([string]$f.Name) '@FEATURES' '' $Theme.Maintain; $total++ }
        }
    }
    if ($total -eq 0) {
        $h = New-Object Windows.Controls.TextBlock; $h.Text = ((Tr 'Sin resultados para "{0}".') -f $q); $h.Foreground = Get-ThemeBrush($Theme.Sub); $h.Margin = New-Object Windows.Thickness(0,8,0,0)
        $rp.Children.Add($h) | Out-Null
    }
}
function Build-FindAllUI {
    $p = $script:FindAllList
    $p.Children.Clear()
    $head = New-IsoCard $p 'BUSCAR EN TODO' $Theme.Optimize 'Encuentra cualquier app, tweak, bloatware o caracteristica de Windows y salta a su seccion con un clic.'
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = New-Object Windows.Thickness(0,6,0,0)
    $script:FindBox = New-Object Windows.Controls.TextBox; $script:FindBox.Width = 380; $script:FindBox.Padding = New-Object Windows.Thickness(6,4,6,4); $script:FindBox.Margin = New-Object Windows.Thickness(0,0,8,0)
    $script:FindBox.Add_KeyDown({ if ($_.Key -eq 'Return') { Do-FindAll } })
    $row.Children.Add($script:FindBox) | Out-Null
    $bGo = New-Object Windows.Controls.Button; $bGo.Content = 'Buscar'; $bGo.Padding = New-Object Windows.Thickness(14,4,14,4)
    $bGo.Background = Get-ThemeBrush('#FF243042'); $bGo.BorderBrush = Get-ThemeBrush($Theme.Optimize)
    $bGo.Add_Click({ Do-FindAll })
    $row.Children.Add($bGo) | Out-Null
    $head.Children.Add($row) | Out-Null
    $script:FindResults = New-Object Windows.Controls.StackPanel
    $p.Children.Add($script:FindResults) | Out-Null
    Do-FindAll
}

# Panel @QUICKSTART: modo facil (2 clics) que guia al usuario nuevo.
function Add-QuickCard {
    param($Parent, [string]$Num, [string]$Title, [string]$Desc, [string]$PanelKey, [string]$BtnText, [string]$Accent)
    $sp = New-IsoCard $Parent ($Num + '.  ' + (Tr $Title)) $Accent $Desc
    $btn = New-Object Windows.Controls.Button
    $btn.Content = $BtnText; $btn.Tag = $PanelKey
    $btn.HorizontalAlignment = 'Left'; $btn.Margin = New-Object Windows.Thickness(0,4,0,0); $btn.Padding = New-Object Windows.Thickness(14,6,14,6)
    $btn.Background = Get-ThemeBrush('#FF243042'); $btn.BorderBrush = Get-ThemeBrush($Accent)
    $btn.Add_Click({ $k = [string]$this.Tag; $i = $script:SideMap.IndexOf($k); if ($i -ge 0) { $script:SideList.SelectedIndex = $i } })
    $sp.Children.Add($btn) | Out-Null
}
function Build-QuickStartUI {
    $p = $script:QuickStartList
    $p.Children.Clear()
    $head = New-IsoCard $p 'BIENVENIDO - MODO FACIL (en 2 clics)' $Theme.Maintain 'Sigue los pasos en orden. Cada boton te lleva a su seccion; alli eliges y confirmas. La barra de la izquierda es el "modo experto" con todo el control: usa lo que necesites.'
    Add-QuickCard $p '1' 'Instala tus programas' 'Elige entre 360+ apps (navegadores, multimedia, desarrollo, juegos...) y pulsa INSTALAR. Marca varias a la vez.' '@ALL' 'Ir a Programas ->' $Theme.Install
    Add-QuickCard $p '2' 'Optimiza Windows (Tweaks)' 'Ajustes de privacidad y rendimiento, reversibles. Dentro tienes "Aplicar recomendado para MI equipo" que marca lo seguro segun tu PC.' '@TWEAKS' 'Ir a Tweaks ->' $Theme.Optimize
    Add-QuickCard $p '3' 'Quita el bloatware' 'Elimina apps preinstaladas que no usas (Xbox, noticias, etc.). Son reinstalables desde la Store.' '@DEBLOAT' 'Ir a Limpiar ->' $Theme.Clean
    Add-QuickCard $p '4' 'Repara Windows' 'Suite de reparacion (SFC, DISM, red, Windows Update...) y herramientas, todo en uno.' '@REPAIR' 'Ir a Reparacion ->' $Theme.Maintain
    Add-QuickCard $p '5' 'Crea tu ISO a medida' 'Asistente paso a paso para una ISO con tus apps, tweaks, debloat y drivers ya integrados.' '@CREATEISO' 'Ir a Crear ISO ->' $Theme.Iso
    Add-QuickCard $p '6' 'Mira el estado de tu equipo' 'Resumen del sistema, foto antes/despues y diagnostico exportable.' '@SUMMARY' 'Ir a Resumen ->' $Theme.Info
}

# Panel @LOGVIEWER: visor de los logs forenses del WPI.
function Refresh-LogViewer {
    if (-not $script:LogCombo) { return }
    $sel = [string]$script:LogCombo.SelectedItem
    $script:LogCombo.Items.Clear()
    $files = @()
    try { $files = @(Get-ChildItem -Path $Config.LogDir -Filter *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) } catch {}
    if (@($files).Count -eq 0) {
        if ($script:LogContent) { $script:LogContent.Text = 'No hay logs todavia. Se crean automaticamente al usar el WPI (instalar, tweaks, reparar, etc.).' }
        return
    }
    foreach ($f in $files) { [void]$script:LogCombo.Items.Add($f.Name) }
    $idx = 0
    if ($sel) { $found = $script:LogCombo.Items.IndexOf($sel); if ($found -ge 0) { $idx = $found } }
    $script:LogCombo.SelectedIndex = $idx
}
function Build-LogViewerUI {
    $p = $script:LogViewerList
    $p.Children.Clear()
    $head = New-IsoCard $p 'VISOR DE LOGS' $Theme.Info 'Consulta los registros forenses del WPI (carpeta logs). Elige un archivo del desplegable para ver su contenido (ultimas lineas).'
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = New-Object Windows.Thickness(0,6,0,0)
    $bR = New-Object Windows.Controls.Button; $bR.Content = 'Refrescar'; $bR.Padding = New-Object Windows.Thickness(10,4,10,4); $bR.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bR.Add_Click({ Refresh-LogViewer })
    $row.Children.Add($bR) | Out-Null
    $bO = New-Object Windows.Controls.Button; $bO.Content = 'Abrir carpeta de logs'; $bO.Padding = New-Object Windows.Thickness(10,4,10,4); $bO.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bO.Add_Click({ try { if (-not (Test-Path $Config.LogDir)) { New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null }; Start-Process explorer.exe $Config.LogDir } catch {} })
    $row.Children.Add($bO) | Out-Null
    $script:LogCombo = New-Object Windows.Controls.ComboBox
    $script:LogCombo.Width = 430; $script:LogCombo.VerticalAlignment = 'Center'
    $script:LogCombo.Add_SelectionChanged({
        $name = [string]$script:LogCombo.SelectedItem
        if (-not $name -or -not $script:LogContent) { return }
        $full = Join-Path $Config.LogDir $name
        try { $script:LogContent.Text = ((Get-Content $full -Tail 800 -ErrorAction Stop) -join "`r`n") }
        catch { $script:LogContent.Text = ((Tr 'No se pudo leer el log: ') + $_.Exception.Message) }
        try { $script:LogContent.ScrollToEnd() } catch {}
    })
    $row.Children.Add($script:LogCombo) | Out-Null
    $head.Children.Add($row) | Out-Null

    $card = New-Object Windows.Controls.Border
    $card.Background = Get-ThemeBrush($Theme.Card); $card.BorderBrush = Get-ThemeBrush($Theme.CardBorder)
    $card.BorderThickness = New-Object Windows.Thickness(1); $card.CornerRadius = New-Object Windows.CornerRadius(13)
    $card.Margin = New-Object Windows.Thickness(0,10,0,0); $card.Padding = New-Object Windows.Thickness(10,10,10,10)
    $script:LogContent = New-Object Windows.Controls.TextBox
    $script:LogContent.IsReadOnly = $true; $script:LogContent.TextWrapping = 'NoWrap'
    $script:LogContent.VerticalScrollBarVisibility = 'Auto'; $script:LogContent.HorizontalScrollBarVisibility = 'Auto'
    $script:LogContent.Height = 460
    $script:LogContent.FontFamily = New-Object Windows.Media.FontFamily('Consolas'); $script:LogContent.FontSize = 12
    $script:LogContent.Background = Get-ThemeBrush('#FF0B0B11'); $script:LogContent.Foreground = Get-ThemeBrush('#FFE6E6EC')
    $script:LogContent.BorderThickness = New-Object Windows.Thickness(0)
    $card.Child = $script:LogContent
    $p.Children.Add($card) | Out-Null
    Refresh-LogViewer
}

# Helpers visuales del panel de ISO (tarjeta + fila de texto con explorador).
function New-IsoCard {
    param($Parent, [string]$Title, [string]$Accent, [string]$Desc = '')
    $card = New-Object Windows.Controls.Border
    $card.Background = Get-ThemeBrush($Theme.Card); $card.BorderBrush = Get-ThemeBrush($Theme.CardBorder)
    $card.BorderThickness = New-Object Windows.Thickness(1); $card.CornerRadius = New-Object Windows.CornerRadius(13)
    $card.Margin = New-Object Windows.Thickness(0,10,0,0); $card.Padding = New-Object Windows.Thickness(15,12,15,14)
    $sp = New-Object Windows.Controls.StackPanel
    if ($Title) {
        $t = New-Object Windows.Controls.TextBlock; $t.Text = $Title; $t.FontSize = 15; $t.FontWeight = 'Bold'; $t.Foreground = Get-ThemeBrush($Accent)
        $sp.Children.Add($t) | Out-Null
    }
    if ($Desc) { $d = New-Object Windows.Controls.TextBlock; $d.Text = $Desc; $d.FontSize = 12; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.TextWrapping = 'Wrap'; $d.Margin = New-Object Windows.Thickness(0,2,0,6); $sp.Children.Add($d) | Out-Null }
    $card.Child = $sp
    $Parent.Children.Add($card) | Out-Null
    return $sp
}
function Add-IsoTextRow {
    param($Parent, [string]$Label, [string]$Default, [string]$BrowseMode = '', [string]$Filter = '')
    $row = New-Object Windows.Controls.DockPanel; $row.Margin = New-Object Windows.Thickness(0,6,0,0); $row.LastChildFill = $true
    $lb = New-Object Windows.Controls.TextBlock; $lb.Text = $Label; $lb.Width = 150; $lb.Foreground = Get-ThemeBrush($Theme.Text); $lb.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($lb, 'Left'); $row.Children.Add($lb) | Out-Null
    $tb = New-Object Windows.Controls.TextBox; $tb.Text = $Default; $tb.Margin = New-Object Windows.Thickness(6,0,0,0); $tb.Padding = New-Object Windows.Thickness(5,3,5,3)
    $tb.Background = Get-ThemeBrush('#FF0F0F17'); $tb.Foreground = Get-ThemeBrush($Theme.Text); $tb.BorderBrush = Get-ThemeBrush($Theme.CardBorder)
    if ($BrowseMode) {
        $btn = New-Object Windows.Controls.Button; $btn.Content = 'Elegir...'; $btn.Margin = New-Object Windows.Thickness(6,0,0,0); $btn.Padding = New-Object Windows.Thickness(10,3,10,3)
        [Windows.Controls.DockPanel]::SetDock($btn, 'Right')
        $btn.Tag = [pscustomobject]@{ Box = $tb; Mode = $BrowseMode; Filter = $Filter }
        $btn.Add_Click({
            $t = $this.Tag
            if ($t.Mode -eq 'file') {
                $dlg = New-Object Microsoft.Win32.OpenFileDialog; if ($t.Filter) { $dlg.Filter = $t.Filter }
                if ($dlg.ShowDialog()) { $t.Box.Text = $dlg.FileName }
            } else {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                $fb = New-Object System.Windows.Forms.FolderBrowserDialog
                if ($fb.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $t.Box.Text = $fb.SelectedPath }
            }
        })
        $row.Children.Add($btn) | Out-Null
    }
    $row.Children.Add($tb) | Out-Null
    $Parent.Children.Add($row) | Out-Null
    return $tb
}
function Add-IsoCheck {
    param($Parent, [string]$Text, [bool]$Checked = $false, [string]$Tint = '')
    $cb = New-Object Windows.Controls.CheckBox; $cb.Content = $Text; $cb.IsChecked = $Checked
    $cb.Margin = New-Object Windows.Thickness(0,6,0,0)
    if ($Tint) { $cb.Foreground = Get-ThemeBrush($Tint) } else { $cb.Foreground = Get-ThemeBrush($Theme.Text) }
    $Parent.Children.Add($cb) | Out-Null
    return $cb
}

# Panel @CREATEISO: flujo guiado para crear una ISO de Windows a medida.
$script:WizTotal = 8

# Inicializa el estado del asistente (una vez). Recupera la seleccion actual de
# Apps y un set de tweaks 'Seguro' recomendados como punto de partida.
# Detecta las ediciones (indice + nombre) dentro de la ISO de Windows origen.
# Monta la ISO, lee sources\install.wim|esd y la desmonta. La GUI corre elevada.
function Get-IsoEditions {
    param([string]$IsoPath)
    $res = @()
    if (-not $IsoPath -or -not (Test-Path $IsoPath)) { return $res }
    $mounted = $false
    try {
        $di = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
        Start-Sleep -Milliseconds 900
        $mounted = $true
        $vol = ($di | Get-Volume).DriveLetter
        if ($vol) {
            $img = $null
            $wim = ($vol + ':\sources\install.wim'); $esd = ($vol + ':\sources\install.esd')
            if (Test-Path $wim) { $img = $wim } elseif (Test-Path $esd) { $img = $esd }
            if ($img) {
                foreach ($i in (Get-WindowsImage -ImagePath $img -ErrorAction Stop)) {
                    $res += [pscustomobject]@{ Index = [int]$i.ImageIndex; Name = [string]$i.ImageName }
                }
            }
        }
    } catch { } finally {
        if ($mounted) { try { Dismount-DiskImage -ImagePath $IsoPath | Out-Null } catch { } }
    }
    return $res
}

# Rellena el ComboBox de edicion con "Todas" + las ediciones detectadas.
function Fill-IsoEditionCombo {
    param($combo)
    if (-not $combo) { return }
    $combo.Items.Clear()
    $itAll = New-Object Windows.Controls.ComboBoxItem
    $itAll.Content = (Tr 'Todas las ediciones (mas lento; todas quedan personalizadas)')
    $itAll.Tag = 'ALL'
    [void]$combo.Items.Add($itAll)
    foreach ($e in @($script:Wiz.EdList)) {
        $it = New-Object Windows.Controls.ComboBoxItem
        $it.Content = ('' + $e.Index + ' - ' + $e.Name + '  ' + (Tr '(solo esta edicion; mas rapido)'))
        $it.Tag = [string]$e.Index
        [void]$combo.Items.Add($it)
    }
    if ($script:Wiz.AllEditions -or @($script:Wiz.EdList).Count -eq 0) {
        $combo.SelectedIndex = 0
    } else {
        $sel = 0
        for ($i = 0; $i -lt $combo.Items.Count; $i++) { if ([string]$combo.Items[$i].Tag -eq [string]$script:Wiz.Idx) { $sel = $i; break } }
        $combo.SelectedIndex = $sel
    }
}

function Init-IsoWizard {
    $reco = @()
    foreach ($t in $TweaksCatalog) {
        $n = [string]$t.Name
        if ([string]$t.Risk -eq 'Seguro' -and ($n -notlike 'Crear punto de restauracion*') -and ($n -notlike 'Limpieza profunda*')) { $reco += $n }
    }
    $curApps = @()
    foreach ($cb in $script:Checks) { if ($cb.IsChecked) { $curApps += [string]$cb.Tag } }
    $script:Wiz = @{
        Step = 0
        SrcIso = ''
        OutDir = (Get-WpiDir 'ISO')
        IsoName = 'WPI_Custom.iso'
        WorkDir = (Join-Path (Get-WpiDir 'ISO') '_work')
        Idx = '0'
        AllEditions = $false
        EdList = @()
        TweakNames = $reco
        DebloatPkgs = @($DebloatCatalog | ForEach-Object { [string]$_.Pkg })
        AppIds = $curApps
        InjectDrivers = $false
        DriversDir = (Get-WpiDir 'Drivers')
        LocalAccount = $true
        BypassW11 = $true
        VmMode = $false
        Locale = 'es-ES'
        AccountName = 'Usuario'
        AccountPassword = ''
    }
}

# Punto de entrada del panel: inicializa (si hace falta) y dibuja el paso actual.
function Build-CreateIsoUI {
    if (-not $script:Wiz) { Init-IsoWizard }
    Render-IsoWizard
}

# Crea un WrapPanel horizontal de checkboxes; devuelve la lista de checkboxes.
function Add-IsoCheckGrid {
    param($Parent, $Items, [string]$LabelKey, [string]$TagKey, $SelectedSet, [string]$TipKey = '')
    $wrap = New-Object Windows.Controls.WrapPanel
    $wrap.Margin = New-Object Windows.Thickness(0,6,0,0)
    $checks = @()
    foreach ($it in $Items) {
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Content = [string]$it.$LabelKey
        $cb.Tag = [string]$it.$TagKey
        $cb.Width = 268
        $cb.Margin = New-Object Windows.Thickness(0,4,10,0)
        $cb.Foreground = Get-ThemeBrush($Theme.Text)
        if ($TipKey -and $it.$TipKey) { $cb.ToolTip = [string]$it.$TipKey }
        $cb.IsChecked = ($SelectedSet -contains [string]$it.$TagKey)
        $wrap.Children.Add($cb) | Out-Null
        $checks += $cb
    }
    $Parent.Children.Add($wrap) | Out-Null
    return $checks
}

# ---- Builders de cada paso (rellenan el panel de contenido $c) ----
function Build-WizReq {
    param($c)
    $d = New-Object Windows.Controls.TextBlock; $d.TextWrapping = 'Wrap'; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.FontSize = 12
    $d.Text = (Tr 'Necesitas Windows ADK (aporta oscdimg), DISM y espacio libre. Para crear la ISO de verdad, abre el WPI como administrador. Aqui tambien tienes las guias.')
    $c.Children.Add($d) | Out-Null
    $script:IsoPrereqText = New-Object Windows.Controls.TextBlock
    $script:IsoPrereqText.FontFamily = New-Object Windows.Media.FontFamily('Consolas'); $script:IsoPrereqText.FontSize = 12.5
    $script:IsoPrereqText.Foreground = Get-ThemeBrush($Theme.Text); $script:IsoPrereqText.Text = (Get-IsoPrereqText)
    $script:IsoPrereqText.Margin = New-Object Windows.Thickness(0,8,0,0)
    $c.Children.Add($script:IsoPrereqText) | Out-Null
    $r = New-Object Windows.Controls.StackPanel; $r.Orientation = 'Horizontal'; $r.Margin = New-Object Windows.Thickness(0,10,0,0)
    $bChk = New-Object Windows.Controls.Button; $bChk.Content = 'Comprobar'; $bChk.Padding = New-Object Windows.Thickness(10,4,10,4); $bChk.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bChk.Add_Click({ Update-IsoPrereqText })
    $r.Children.Add($bChk) | Out-Null
    $bAdk = New-Object Windows.Controls.Button; $bAdk.Content = 'Instalar Windows ADK'; $bAdk.Padding = New-Object Windows.Thickness(10,4,10,4); $bAdk.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bAdk.Background = Get-ThemeBrush('#FF1F3A2E'); $bAdk.BorderBrush = Get-ThemeBrush('#FF3E6B54')
    $bAdk.Add_Click({
        $en = ($script:Lang -eq 'en')
        $msg = $(if ($en) {
            "WHAT IS WINDOWS ADK?" + "`n`n" +
            "It is Microsoft's Assessment and Deployment Kit. WPI needs ONE tool from it: oscdimg.exe, which ASSEMBLES your custom Windows ISO (the 'Create ISO' section)." + "`n`n" +
            "It is a one-time install (a few hundred MB) and may take 5-15 minutes. A console will open with an explanation and a progress indicator. Do not close it until it finishes." + "`n`n" +
            "Install Windows ADK now?"
        } else {
            "QUE ES WINDOWS ADK?" + "`n`n" +
            "Es el Kit de Evaluacion e Implementacion de Microsoft. El WPI solo necesita UNA herramienta suya: oscdimg.exe, que ENSAMBLA tu ISO de Windows a medida (la seccion 'Crear ISO')." + "`n`n" +
            "Es una instalacion de una sola vez (unos cientos de MB) y puede tardar 5-15 minutos. Se abrira una consola con la explicacion y un indicador de progreso. No la cierres hasta que termine." + "`n`n" +
            "Instalar Windows ADK ahora?"
        })
        $r = Show-WpiMessage($msg, 'Windows ADK', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
        $sc = @'
$ErrorActionPreference = 'Continue'
$lang = 'LANGFLAG'
function L($es, $en) { if ($lang -eq 'en') { return $en } else { return $es } }
try { $Host.UI.RawUI.WindowTitle = 'WPI - Windows ADK' } catch {}
Clear-Host
Write-Host ''
Write-Host (L '  INSTALACION DE WINDOWS ADK' '  INSTALLING WINDOWS ADK') -ForegroundColor Cyan
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host (L '  Que es : Kit de Evaluacion e Implementacion de Windows.' '  What   : Windows Assessment and Deployment Kit.')
Write-Host (L '  Para que: aporta oscdimg.exe, la herramienta que ENSAMBLA' '  Why    : it provides oscdimg.exe, the tool that ASSEMBLES')
Write-Host (L '            tu ISO de Windows a medida (seccion Crear ISO).' '            your custom Windows ISO (Create ISO section).')
Write-Host (L '  Tamano : unos cientos de MB. Instalacion de una sola vez.' '  Size   : a few hundred MB. One-time install.')
Write-Host (L '  Tiempo : 5-15 minutos aprox. NO cierres esta ventana.' '  Time   : about 5-15 minutes. Do NOT close this window.')
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host ''
Write-Host (L '  La descarga real va en segundo plano (winget no muestra %).' '  The real download runs in the background (winget shows no %).')
Write-Host (L '  Veras un indicador girando mientras trabaja:' '  You will see a spinner while it works:') -ForegroundColor Gray
Write-Host ''
$job = Start-Job { winget install --id Microsoft.WindowsADK -e --accept-source-agreements --accept-package-agreements }
$spin = '|/-\'
$i = 0; $t0 = Get-Date
while ($job.State -eq 'Running') {
    $el = [int]((Get-Date) - $t0).TotalSeconds
    $bar = ('#' * [math]::Min(40, [int]($el / 3))).PadRight(40, '.')
    Write-Host -NoNewline ("`r  [{0}] {1} {2}s   " -f $spin[$i % 4], $bar, $el) -ForegroundColor Cyan
    Start-Sleep -Milliseconds 350; $i++
}
$out = Receive-Job $job 2>&1 | Out-String
Remove-Job $job -Force
Write-Host ''
Write-Host ''
$ok = $false
foreach ($c in @("${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe", "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe")) { if (Test-Path $c) { $ok = $true } }
if ($ok) {
    Write-Host (L '  [OK] Windows ADK instalado. oscdimg disponible.' '  [OK] Windows ADK installed. oscdimg is available.') -ForegroundColor Green
    Write-Host (L '       Vuelve al WPI -> Crear ISO -> pulsa "Comprobar".' '       Go back to WPI -> Create ISO -> press "Check".') -ForegroundColor Green
} else {
    Write-Host (L '  [!] No se detecto oscdimg. Resultado de winget:' '  [!] oscdimg not detected. winget output:') -ForegroundColor Yellow
    Write-Host $out -ForegroundColor Gray
}
Write-Host ''
Read-Host (L '  Pulsa Enter para cerrar' '  Press Enter to close')
'@
        $sc = $sc.Replace('LANGFLAG', $script:Lang)
        $f = Join-Path $env:TEMP 'wpi_adk_install.ps1'
        try {
            Set-WpiContent -Path $f -Value $sc
            Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File', ('"' + $f + '"')
        } catch {
            try { Start-Process powershell.exe -ArgumentList '-NoExit','-NoProfile','-Command','winget install --id Microsoft.WindowsADK -e --accept-source-agreements --accept-package-agreements' } catch {}
        }
    })
    $r.Children.Add($bAdk) | Out-Null
    $bG = New-Object Windows.Controls.Button; $bG.Content = 'Ver guia completa'; $bG.Padding = New-Object Windows.Thickness(10,4,10,4); $bG.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bG.Add_Click({ Show-PlanDialog -PlanText (Get-IsoGuideText) | Out-Null })
    $r.Children.Add($bG) | Out-Null
    $bV = New-Object Windows.Controls.Button; $bV.Content = 'Guia maquina virtual'; $bV.Padding = New-Object Windows.Thickness(10,4,10,4)
    $bV.Add_Click({ Show-PlanDialog -PlanText (Get-IsoVmGuideText) | Out-Null })
    $r.Children.Add($bV) | Out-Null
    $c.Children.Add($r) | Out-Null
}
function Build-WizSource {
    param($c)
    $dl = New-Object Windows.Controls.TextBlock; $dl.TextWrapping = 'Wrap'; $dl.Foreground = Get-ThemeBrush($Theme.Sub); $dl.FontSize = 12
    $dl.Text = (Tr 'Si NO tienes una ISO de Windows, descarga la oficial de Microsoft y luego eligela abajo en "ISO origen".')
    $c.Children.Add($dl) | Out-Null
    $dlrow = New-Object Windows.Controls.StackPanel; $dlrow.Orientation = 'Horizontal'; $dlrow.Margin = New-Object Windows.Thickness(0,6,0,6)
    $b11 = New-Object Windows.Controls.Button; $b11.Content = (Tr 'Descargar Windows 11 (Microsoft)'); $b11.Padding = New-Object Windows.Thickness(10,4,10,4); $b11.Margin = New-Object Windows.Thickness(0,0,8,0)
    $b11.Background = Get-ThemeBrush('#FF243042'); $b11.BorderBrush = Get-ThemeBrush('#FF3C5876')
    $b11.Add_Click({ try { Start-Process 'https://www.microsoft.com/software-download/windows11' } catch {} })
    $dlrow.Children.Add($b11) | Out-Null
    $b10 = New-Object Windows.Controls.Button; $b10.Content = (Tr 'Descargar Windows 10 (Microsoft)'); $b10.Padding = New-Object Windows.Thickness(10,4,10,4)
    $b10.Background = Get-ThemeBrush('#FF243042'); $b10.BorderBrush = Get-ThemeBrush('#FF3C5876')
    $b10.Add_Click({ try { Start-Process 'https://www.microsoft.com/software-download/windows10' } catch {} })
    $dlrow.Children.Add($b10) | Out-Null
    $c.Children.Add($dlrow) | Out-Null
    $script:WizCtl.Src  = Add-IsoTextRow $c 'ISO origen' $script:Wiz.SrcIso 'file' 'Imagenes ISO (*.iso)|*.iso'
    $script:WizCtl.Out  = Add-IsoTextRow $c 'Carpeta de salida' $script:Wiz.OutDir 'folder'
    $script:WizCtl.Name = Add-IsoTextRow $c 'Nombre ISO final' $script:Wiz.IsoName
    $script:WizCtl.Work = Add-IsoTextRow $c 'Carpeta de trabajo' $script:Wiz.WorkDir 'folder'
    # --- Selector de edicion (detecta las ediciones reales de la ISO) ---
    $edLbl = New-Object Windows.Controls.TextBlock; $edLbl.Text = (Tr 'En que edicion aplicar la configuracion'); $edLbl.Foreground = Get-ThemeBrush($Theme.Text); $edLbl.FontSize = 12; $edLbl.Margin = New-Object Windows.Thickness(0,8,0,2)
    $c.Children.Add($edLbl) | Out-Null
    $edRow = New-Object Windows.Controls.DockPanel; $edRow.LastChildFill = $true
    $bDet = New-Object Windows.Controls.Button; $bDet.Content = (Tr 'Detectar ediciones'); [Windows.Controls.DockPanel]::SetDock($bDet, 'Right'); $bDet.Margin = New-Object Windows.Thickness(8,0,0,0); $bDet.Padding = New-Object Windows.Thickness(10,4,10,4)
    $bDet.Background = Get-ThemeBrush('#FF243042'); $bDet.BorderBrush = Get-ThemeBrush('#FF3C5876')
    $edCombo = New-Object Windows.Controls.ComboBox
    $bDet.Add_Click({
        $src = $script:WizCtl.Src.Text.Trim()
        if (-not $src -or -not (Test-Path $src)) { Show-WpiMessage((Tr 'Primero elige arriba la ISO origen de Windows.'), 'Crear ISO') | Out-Null; return }
        if ($script:StatusText) { $script:StatusText.Text = (Tr 'Detectando ediciones de la ISO (puede tardar unos segundos)...') }
        $eds = @()
        try { $eds = @(Get-IsoEditions -IsoPath $src) } catch { $eds = @() }
        $script:Wiz.EdList = $eds
        if ($eds.Count -eq 0) { Show-WpiMessage((Tr 'No se pudieron detectar ediciones. Se usara "Todas las ediciones".'), 'Crear ISO') | Out-Null }
        Fill-IsoEditionCombo $script:WizCtl.Idx
        if ($script:StatusText) { $script:StatusText.Text = ((Tr 'Detectadas {0} ediciones en la ISO.') -f $eds.Count) }
    })
    $edRow.Children.Add($bDet) | Out-Null
    $edRow.Children.Add($edCombo) | Out-Null
    $c.Children.Add($edRow) | Out-Null
    $edHint = New-Object Windows.Controls.TextBlock; $edHint.TextWrapping = 'Wrap'; $edHint.Foreground = Get-ThemeBrush($Theme.Sub); $edHint.FontSize = 11; $edHint.Margin = New-Object Windows.Thickness(0,3,0,0)
    $edHint.Text = (Tr 'Pulsa "Detectar ediciones" para listar los Windows de tu ISO. Si eliges una concreta, la ISO final tendra SOLO esa edicion (mas rapido). "Todas" personaliza cada edicion (mas lento).')
    $c.Children.Add($edHint) | Out-Null
    $script:WizCtl.Idx = $edCombo
    Fill-IsoEditionCombo $edCombo
}
function Build-WizTweaks {
    param($c)
    $d = New-Object Windows.Controls.TextBlock; $d.TextWrapping = 'Wrap'; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.FontSize = 12
    $d.Text = (Tr 'Elige los tweaks. Se aplican en el PRIMER ARRANQUE con el motor real de WPI (fieles a los de la pestana Tweaks). Empiezan marcados los seguros recomendados.')
    $c.Children.Add($d) | Out-Null
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = New-Object Windows.Thickness(0,6,0,0)
    $bR = New-Object Windows.Controls.Button; $bR.Content = 'Marcar recomendados'; $bR.Padding = New-Object Windows.Thickness(8,3,8,3); $bR.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bR.Add_Click({ foreach ($cb in $script:WizCtl.TweakChecks) { $nm = [string]$cb.Tag; $isSafe = $false; foreach ($t in $TweaksCatalog) { if ([string]$t.Name -eq $nm -and [string]$t.Risk -eq 'Seguro' -and ($nm -notlike 'Crear punto*') -and ($nm -notlike 'Limpieza profunda*')) { $isSafe = $true } }; $cb.IsChecked = $isSafe } })
    $row.Children.Add($bR) | Out-Null
    $bN = New-Object Windows.Controls.Button; $bN.Content = 'Quitar todos'; $bN.Padding = New-Object Windows.Thickness(8,3,8,3)
    $bN.Add_Click({ foreach ($cb in $script:WizCtl.TweakChecks) { $cb.IsChecked = $false } })
    $row.Children.Add($bN) | Out-Null
    $c.Children.Add($row) | Out-Null
    $script:WizCtl.TweakChecks = Add-IsoCheckGrid $c $TweaksCatalog 'Name' 'Name' $script:Wiz.TweakNames 'Risk'
}
function Build-WizDebloat {
    param($c)
    $d = New-Object Windows.Controls.TextBlock; $d.TextWrapping = 'Wrap'; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.FontSize = 12
    $d.Text = (Tr 'Marca el bloatware a quitar DE FABRICA (offline, antes de instalar). Son Appx reinstalables desde la Store. Empieza todo marcado.')
    $c.Children.Add($d) | Out-Null
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = New-Object Windows.Thickness(0,6,0,0)
    $bA = New-Object Windows.Controls.Button; $bA.Content = 'Marcar todos'; $bA.Padding = New-Object Windows.Thickness(8,3,8,3); $bA.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bA.Add_Click({ foreach ($cb in $script:WizCtl.DebloatChecks) { $cb.IsChecked = $true } })
    $row.Children.Add($bA) | Out-Null
    $bN = New-Object Windows.Controls.Button; $bN.Content = 'Quitar todos'; $bN.Padding = New-Object Windows.Thickness(8,3,8,3)
    $bN.Add_Click({ foreach ($cb in $script:WizCtl.DebloatChecks) { $cb.IsChecked = $false } })
    $row.Children.Add($bN) | Out-Null
    $c.Children.Add($row) | Out-Null
    $script:WizCtl.DebloatChecks = Add-IsoCheckGrid $c $DebloatCatalog 'Name' 'Pkg' $script:Wiz.DebloatPkgs 'Desc'
}
function Build-WizApps {
    param($c)
    $d = New-Object Windows.Controls.TextBlock; $d.TextWrapping = 'Wrap'; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.FontSize = 12
    $d.Text = (Tr 'Marca las apps que se instalaran solas en el primer arranque (via winget), DIVIDIDAS POR SECCION (Navegadores, Multimedia, etc.). Usa el buscador para filtrar. Por defecto se traen las que tengas marcadas en la pestana Apps.')
    $c.Children.Add($d) | Out-Null
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = New-Object Windows.Thickness(0,6,0,0)
    $sb = New-Object Windows.Controls.TextBox; $sb.Width = 240; $sb.Padding = New-Object Windows.Thickness(5,3,5,3); $sb.Margin = New-Object Windows.Thickness(0,0,8,0)
    $sb.Background = Get-ThemeBrush('#FF0F0F17'); $sb.Foreground = Get-ThemeBrush($Theme.Text); $sb.BorderBrush = Get-ThemeBrush($Theme.CardBorder)
    $sb.ToolTip = (Tr 'Buscar app por nombre o ID')
    $sb.Add_TextChanged({
        $q = $script:WizCtl.AppSearch.Text.Trim()
        foreach ($g in $script:WizCtl.AppGroups) {
            $anyVis = $false
            foreach ($cb in $g.Checks) {
                $vis = ($q -eq '' -or ([string]$cb.Content -like ('*' + $q + '*')) -or ([string]$cb.Tag -like ('*' + $q + '*')))
                $cb.Visibility = $(if ($vis) { 'Visible' } else { 'Collapsed' })
                if ($vis) { $anyVis = $true }
            }
            $g.Header.Visibility = $(if ($anyVis) { 'Visible' } else { 'Collapsed' })
        }
    })
    $row.Children.Add($sb) | Out-Null
    $script:WizCtl.AppSearch = $sb
    $bUse = New-Object Windows.Controls.Button; $bUse.Content = 'Usar mi seleccion de Apps'; $bUse.Padding = New-Object Windows.Thickness(8,3,8,3); $bUse.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bUse.Add_Click({
        # Copia la seleccion actual de la pestana Apps a las casillas del asistente.
        $cur = @{}
        foreach ($x in $script:Checks) { if ($x.IsChecked) { $cur[([string]$x.Tag).ToLower()] = $true } }
        $marked = 0
        foreach ($cb in $script:WizCtl.AppChecks) {
            $on = $cur.ContainsKey(([string]$cb.Tag).ToLower())
            $cb.IsChecked = $on
            if ($on) { $marked++ }
        }
        # Feedback claro: cuantas se han marcado (o aviso si no hay ninguna).
        if ($cur.Count -eq 0) {
            Show-WpiMessage((Tr 'No tienes ninguna app marcada en la pestana Apps. Marca alli las que quieras incluir en la ISO y vuelve a pulsar este boton.'), (Tr 'Usar mi seleccion de Apps')) | Out-Null
        } else {
            $script:StatusText.Text = ((Tr 'Marcadas {0} apps de tu seleccion de la pestana Apps.') -f $marked)
        }
    })
    $row.Children.Add($bUse) | Out-Null
    $bClr = New-Object Windows.Controls.Button; $bClr.Content = 'Quitar todas'; $bClr.Padding = New-Object Windows.Thickness(8,3,8,3)
    $bClr.Add_Click({ foreach ($cb in $script:WizCtl.AppChecks) { $cb.IsChecked = $false } })
    $row.Children.Add($bClr) | Out-Null
    $c.Children.Add($row) | Out-Null
    # Apps divididas por seccion (categoria), con cabecera por cada una
    $cats = $catalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    $allChecks = @(); $groups = @()
    foreach ($cat in $cats) {
        $h = New-Object Windows.Controls.TextBlock
        $h.Text = ('{0}  ({1})' -f (Tr $cat).ToUpper(), @($catalog | Where-Object { $_.Cat -eq $cat }).Count)
        $h.FontWeight = 'Bold'; $h.FontSize = 13; $h.Foreground = Get-ThemeBrush($Theme.Install)
        $h.Margin = New-Object Windows.Thickness(2,12,0,0)
        $c.Children.Add($h) | Out-Null
        $items = @($catalog | Where-Object { $_.Cat -eq $cat } | ForEach-Object { [pscustomobject]@{ Disp = $_.Name; Id = $_.Id } })
        $checks = Add-IsoCheckGrid $c $items 'Disp' 'Id' $script:Wiz.AppIds ''
        $allChecks += $checks
        $groups += [pscustomobject]@{ Header = $h; Checks = $checks }
    }
    $script:WizCtl.AppChecks = $allChecks
    $script:WizCtl.AppGroups = $groups
}
function Build-WizDrivers {
    param($c)
    $d = New-Object Windows.Controls.TextBlock; $d.TextWrapping = 'Wrap'; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.FontSize = 12
    $d.Text = (Tr 'Inyecta drivers (.inf) en la imagen para que el equipo arranque con red/chipset. Elige una carpeta con .inf, o si NO tienes ninguna, crea ahora mismo una copia de los drivers que tienes instalados con el boton de abajo.')
    $c.Children.Add($d) | Out-Null
    $script:WizCtl.Drv = Add-IsoCheck $c 'Inyectar drivers desde una carpeta' $script:Wiz.InjectDrivers $Theme.Maintain
    $drvNote = New-Object Windows.Controls.TextBlock; $drvNote.TextWrapping = 'Wrap'; $drvNote.FontSize = 11.5; $drvNote.Margin = New-Object Windows.Thickness(0,4,0,0)
    $drvNote.Foreground = Get-ThemeBrush('#FFFFD166')
    $drvNote.Text = (Tr 'RECORDATORIO: si lo dejas MARCADO, los drivers van DENTRO de la ISO y Windows arrancara con red/chipset listos. Si lo DESMARCAS, tendras que instalar los drivers A MANO despues de instalar Windows.')
    $c.Children.Add($drvNote) | Out-Null
    $script:WizCtl.DrvDir = Add-IsoTextRow $c 'Carpeta de drivers (.inf)' $script:Wiz.DriversDir 'folder'
    $bExp = New-Object Windows.Controls.Button
    $bExp.Content = 'No tengo: crear copia (.inf) de mis drivers actuales'
    $bExp.HorizontalAlignment = 'Left'; $bExp.Margin = New-Object Windows.Thickness(0,8,0,0); $bExp.Padding = New-Object Windows.Thickness(12,6,12,6)
    $bExp.Background = Get-ThemeBrush('#FF1F3A2E'); $bExp.BorderBrush = Get-ThemeBrush('#FF3E6B54')
    $bExp.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $fb = New-Object System.Windows.Forms.FolderBrowserDialog
        $fb.Description = 'Elige donde guardar la copia de tus drivers (.inf)'
        try { $fb.SelectedPath = $PSScriptRoot } catch {}
        if ($fb.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $dest = Join-Path $fb.SelectedPath 'Drivers'
        try { $script:WizCtl.DrvDir.Text = $dest } catch {}
        try { $script:WizCtl.Drv.IsChecked = $true } catch {}
        $sc = @'
$ErrorActionPreference = 'Continue'
$lang = 'LANGFLAG'
$dest = 'DESTFOLDER'
function L($es, $en) { if ($lang -eq 'en') { return $en } else { return $es } }
try { $Host.UI.RawUI.WindowTitle = 'WPI - Drivers .inf' } catch {}
Clear-Host
Write-Host ''
Write-Host (L '  COPIA DE TUS DRIVERS ACTUALES (.inf)' '  BACKUP OF YOUR CURRENT DRIVERS (.inf)') -ForegroundColor Cyan
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host (L ('  Carpeta destino: ' + $dest) ('  Destination: ' + $dest))
Write-Host (L '  Guarda los drivers de terceros instalados para inyectarlos' '  Saves your installed third-party drivers so you can inject')
Write-Host (L '  en tu ISO. Puede tardar 1-3 minutos. NO cierres la ventana.' '  them into your ISO. May take 1-3 minutes. Do NOT close.')
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host ''
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
$job = Start-Job -ArgumentList $dest { param($d) Export-WindowsDriver -Online -Destination $d }
$spin = '|/-\'
$i = 0; $t0 = Get-Date
while ($job.State -eq 'Running') { $el = [int]((Get-Date) - $t0).TotalSeconds; Write-Host -NoNewline ("`r  {0} [{1}] {2}s   " -f (L 'exportando...' 'exporting...'), $spin[$i % 4], $el) -ForegroundColor Cyan; Start-Sleep -Milliseconds 350; $i++ }
$res = Receive-Job $job 2>&1 | Out-String
Remove-Job $job -Force
$n = 0; try { $n = @(Get-ChildItem -Path $dest -Filter *.inf -Recurse -ErrorAction SilentlyContinue).Count } catch {}
Write-Host ''
Write-Host ''
if ($n -gt 0) { Write-Host (L ('  [OK] ' + $n + ' drivers .inf exportados. Esa carpeta ya esta puesta en el WPI para inyectarla.') ('  [OK] ' + $n + ' .inf drivers exported. That folder is already set in WPI to inject it.')) -ForegroundColor Green }
else { Write-Host (L '  [!] No se exportaron drivers (hace falta admin o no hay de terceros).' '  [!] No drivers exported (needs admin or there are no third-party ones).') -ForegroundColor Yellow; Write-Host $res -ForegroundColor Gray }
Write-Host ''
Read-Host (L '  Pulsa Enter para cerrar' '  Press Enter to close')
'@
        $sc = $sc.Replace('LANGFLAG', $script:Lang).Replace('DESTFOLDER', ($dest -replace "'", "''"))
        $f = Join-Path $env:TEMP 'wpi_drv_export.ps1'
        try {
            Set-WpiContent -Path $f -Value $sc
            Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File', ('"' + $f + '"')
            $script:StatusText.Text = (Tr 'Exportando tus drivers en una consola (admin)...')
        } catch { Show-WpiMessage(((Tr 'No se pudo lanzar la exportacion: {0}') -f $_.Exception.Message), 'Crear ISO') | Out-Null }
    })
    $c.Children.Add($bExp) | Out-Null
}
function Build-WizUnattend {
    param($c)
    $d = New-Object Windows.Controls.TextBlock; $d.TextWrapping = 'Wrap'; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.FontSize = 12
    $d.Text = (Tr 'Automatiza la instalacion. "Bypass W11" instala en equipos sin TPM/Secure Boot. "Modo VM" PARTICIONA Y BORRA el disco 0: usalo SOLO en maquina virtual o disco desechable.')
    $c.Children.Add($d) | Out-Null
    $script:WizCtl.Local  = Add-IsoCheck $c 'Crear cuenta local y saltar pantallas de cuenta online (OOBE)' $script:Wiz.LocalAccount
    $script:WizCtl.Bypass = Add-IsoCheck $c 'Bypass de requisitos de Windows 11 (TPM / Secure Boot / RAM / CPU)' $script:Wiz.BypassW11 $Theme.Optimize
    $script:WizCtl.Vm     = Add-IsoCheck $c 'Modo VM: particionar el disco automaticamente (BORRA EL DISCO 0)' $script:Wiz.VmMode $Theme.Danger
    $vmNote = New-Object Windows.Controls.TextBlock; $vmNote.TextWrapping = 'Wrap'; $vmNote.FontSize = 11.5; $vmNote.Margin = New-Object Windows.Thickness(0,4,0,8)
    $vmNote.Foreground = Get-ThemeBrush('#FFFF8A8A')
    $vmNote.Text = (Tr 'RECORDATORIO: marca "Modo VM" SOLO en maquina virtual o disco desechable (formatea el disco 0 sin preguntar). En un PC fisico con tus datos, dejalo DESACTIVADO y elige el disco a mano durante la instalacion. Te lo recordare al pasar de paso.')
    $c.Children.Add($vmNote) | Out-Null
    $script:WizCtl.Locale = Add-IsoTextRow $c 'Idioma / locale' $script:Wiz.Locale
    $script:WizCtl.Acct   = Add-IsoTextRow $c 'Nombre de cuenta' $script:Wiz.AccountName
    $script:WizCtl.Pass   = Add-IsoTextRow $c 'Contrasena de la cuenta (opcional, recomendada en Win11)' $script:Wiz.AccountPassword
}
function Build-WizSummary {
    param($c)
    $w = $script:Wiz
    $lines = @()
    $lines += ('ORIGEN      : ' + $(if ($w.SrcIso) { $w.SrcIso } else { '(SIN ELEGIR - vuelve al paso 2)' }))
    $lines += ('SALIDA      : ' + (Join-Path $w.OutDir $w.IsoName))
    $lines += ('TRABAJO     : ' + $w.WorkDir)
    $edTxt = if ($w.AllEditions) { 'TODAS las ediciones detectadas (cada una personalizada)' } else { ('solo la edicion indice ' + $w.Idx) }
    $lines += ('EDICION     : ' + $edTxt)
    $lines += ('DRIVERS     : ' + $(if ($w.InjectDrivers) { 'inyectar desde ' + $w.DriversDir } else { 'no' }))
    $lines += ('DEBLOAT     : ' + @($w.DebloatPkgs).Count + ' apps a quitar de fabrica (offline)')
    $lines += ('TWEAKS      : ' + @($w.TweakNames).Count + ' tweaks (se aplican en el primer arranque)')
    $lines += ('APPS        : ' + @($w.AppIds).Count + ' apps (se instalan en el primer arranque)')
    $lines += ('DESATENDIDO : cuenta local/OOBE=' + $w.LocalAccount + ' · bypassW11=' + $w.BypassW11 + ' · modoVM=' + $w.VmMode)
    $lines += ('IDIOMA/CTA  : ' + $w.Locale + ' · ' + $w.AccountName)
    $tb = New-Object Windows.Controls.TextBlock; $tb.FontFamily = New-Object Windows.Media.FontFamily('Consolas'); $tb.FontSize = 12.5
    $tb.Foreground = Get-ThemeBrush($Theme.Text); $tb.Text = ($lines -join "`r`n"); $tb.Margin = New-Object Windows.Thickness(0,4,0,0)
    $c.Children.Add($tb) | Out-Null
    $guide = New-Object Windows.Controls.TextBlock; $guide.TextWrapping = 'Wrap'; $guide.Foreground = Get-ThemeBrush($Theme.Text); $guide.FontSize = 12; $guide.Margin = New-Object Windows.Thickness(0,10,0,0)
    $guide.Text = (Tr 'GUIA RAPIDA: Si vas a PROBAR en maquina virtual (VirtualBox/VMware): activa EFI/UEFI, asigna 4+ GB de RAM, 2+ nucleos y disco de 64+ GB, y habilita TPM o usa el bypass de WPI. Si es una instalacion NORMAL en un PC fisico: cuando la ISO este creada, graba la ISO a un USB con Rufus (esquema GPT, destino UEFI), arranca desde el USB y listo. IMPORTANTE: el "Modo VM" formatea el disco 0 automaticamente; usalo SOLO en maquinas virtuales. En un PC fisico dejalo DESACTIVADO y elige el disco a mano.')
    $c.Children.Add($guide) | Out-Null
    $rufWarn = New-Object Windows.Controls.TextBlock; $rufWarn.TextWrapping = 'Wrap'; $rufWarn.FontSize = 12.5; $rufWarn.FontWeight = 'Bold'; $rufWarn.Foreground = Get-ThemeBrush('#FFFFD166'); $rufWarn.Margin = New-Object Windows.Thickness(0,10,0,0)
    $rufWarn.Text = ([string][char]0x270B + '  ' + (Tr 'AVISO IMPORTANTE (Rufus): cuando grabes la ISO al USB y aparezca la ventana "Experiencia de usuario de Windows", NO marques NINGUNA casilla (ni quitar TPM, ni cuenta local, ni mejoras QoL). Dejalas todas vacias y pulsa Aceptar. Si marcas algo, Rufus crea su propio autounattend y SOBREESCRIBE el de WPI: no se aplicarian tus apps, ni los tweaks, ni el modo oscuro. Todo eso ya lo hace WPI por si solo.'))
    $c.Children.Add($rufWarn) | Out-Null
    $rufus = New-Object Windows.Controls.Button; $rufus.Content = (Tr 'Abrir Rufus (rufus.ie) para grabar la ISO al USB'); $rufus.HorizontalAlignment = 'Left'; $rufus.Margin = New-Object Windows.Thickness(0,6,0,0); $rufus.Padding = New-Object Windows.Thickness(10,4,10,4)
    $rufus.Background = Get-ThemeBrush('#FF243042'); $rufus.BorderBrush = Get-ThemeBrush('#FF3C5876')
    $rufus.Add_Click({ try { Start-Process 'https://rufus.ie' } catch {} })
    $c.Children.Add($rufus) | Out-Null
    # ----- Boton IMPORTANTE: comprobar la ISO antes de grabarla -----
    $verWarn = New-Object Windows.Controls.TextBlock; $verWarn.TextWrapping = 'Wrap'; $verWarn.FontSize = 12.5; $verWarn.FontWeight = 'Bold'
    $verWarn.Foreground = Get-ThemeBrush($Theme.Iso); $verWarn.Margin = New-Object Windows.Thickness(0,14,0,0)
    $verWarn.Text = (Tr 'IMPORTANTE: antes de grabar con Rufus, comprueba que la ISO lo lleva todo (C:\WPI, autounattend, ediciones, drivers, winget). Pulsa el boton; abre una consola como administrador, monta la ISO y te da un veredicto claro.')
    $c.Children.Add($verWarn) | Out-Null
    $bVer = New-Object Windows.Controls.Button
    $bVer.Content = (Tr '  IMPORTANTE  -  COMPROBAR la ISO antes de Rufus  ')
    $bVer.HorizontalAlignment = 'Left'; $bVer.Margin = New-Object Windows.Thickness(0,6,0,0); $bVer.Padding = New-Object Windows.Thickness(12,6,12,6); $bVer.FontWeight = 'Bold'
    $bVer.Background = Get-ThemeBrush('#FF4A2F12'); $bVer.BorderBrush = Get-ThemeBrush($Theme.Iso); $bVer.Foreground = Get-ThemeBrush($Theme.Clean)
    $bVer.Add_Click({
        $ww = $script:Wiz
        $iso = (Join-Path $ww.OutDir $ww.IsoName)
        $verPs = (Join-Path $ww.OutDir 'Verificar_ISO.ps1')
        try { Set-WpiContent -Path $verPs -Value (Get-IsoVerifyScriptText) } catch {}
        $cmd = ('& "{0}" -Iso "{1}"' -f $verPs, $iso)
        if (-not (Test-Path $iso)) {
            Show-WpiMessage((("Aun no existe la ISO:`n{0}`n`nCrea primero la ISO y vuelve a pulsar este boton.`n`nTambien puedes comprobarla a mano en PowerShell (administrador) con:`n`n{1}") -f $iso, $cmd), 'Comprobar ISO') | Out-Null
            return
        }
        $r = Show-WpiMessage((("Se comprobara la ISO como ADMINISTRADOR en una consola aparte: monta la imagen y revisa C:\WPI, autounattend, ediciones, drivers y winget. Tarda 1-3 min.`n`nComando equivalente para hacerlo a mano:`n{0}`n`nComprobar ahora?") -f $cmd), 'Comprobar ISO', 'YesNo', 'Information')
        if ($r -ne 'Yes') { return }
        try { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $verPs + '"'),'-Iso',('"' + $iso + '"') }
        catch { Show-WpiMessage((('No se pudo lanzar la comprobacion: ' + $_.Exception.Message)), 'Comprobar ISO') | Out-Null }
    })
    $c.Children.Add($bVer) | Out-Null
    $note = New-Object Windows.Controls.TextBlock; $note.TextWrapping = 'Wrap'; $note.Foreground = Get-ThemeBrush($Theme.Sub); $note.FontSize = 12; $note.Margin = New-Object Windows.Thickness(0,8,0,0)
    $note.Text = (Tr 'Que es el "kit": una carpeta (WPI_ISO_Kit) con todo lo necesario: tu configuracion, el autounattend.xml, el script que crea la ISO, el preset de apps, una copia de WPI y las guias. NO hace falta generar el kit antes de crear la ISO: el boton "Confirmar y CREAR la ISO" ya lo prepara solo y lanza el proceso como administrador. "Generar kit" es OPCIONAL, solo si quieres revisar o editar esos archivos antes.')
    $c.Children.Add($note) | Out-Null
    $r = New-Object Windows.Controls.StackPanel; $r.Orientation = 'Horizontal'; $r.Margin = New-Object Windows.Thickness(0,10,0,0)
    $bKit = New-Object Windows.Controls.Button; $bKit.Content = (Tr 'Generar kit (opcional: solo revisar archivos)'); $bKit.Padding = New-Object Windows.Thickness(12,5,12,5); $bKit.Margin = New-Object Windows.Thickness(0,0,8,0)
    $bKit.Background = Get-ThemeBrush('#FF243042'); $bKit.BorderBrush = Get-ThemeBrush('#FF3C5876')
    $bKit.Add_Click({
        $k = New-IsoBuildKit
        if ($k) {
            $script:StatusText.Text = (Tr 'Kit de ISO generado.')
            $r = Show-WpiMessage(((Tr ('Kit generado en:' + "`n" + '{0}' + "`n`n" + 'Contiene config, autounattend.xml, el script de creacion, el preset de apps, una copia de WPI y las guias. Abrir la carpeta?')) -f $k), 'Crear ISO', 'YesNo', 'Information')
            if ($r -eq 'Yes') { try { Start-Process explorer.exe $k } catch {} }
        }
    })
    $r.Children.Add($bKit) | Out-Null
    $bRun = New-Object Windows.Controls.Button; $bRun.Content = 'Confirmar y CREAR la ISO (administrador)'; $bRun.Padding = New-Object Windows.Thickness(12,5,12,5)
    $bRun.Background = Get-ThemeBrush('#FF4A2F12'); $bRun.BorderBrush = Get-ThemeBrush($Theme.Iso); $bRun.Foreground = Get-ThemeBrush($Theme.Text)
    $bRun.Add_Click({
        $kit = New-IsoBuildKit
        if (-not $kit) { return }
        $script:IsoKitPath = $kit
        $r = Show-WpiMessage('Vas a integrar todo lo elegido y CREAR la ISO. Se lanzara como ADMINISTRADOR en una consola aparte; monta la imagen y puede tardar 15-40 min. No cierres la consola. Confirmas?', 'Crear ISO', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        $scriptPath = (Join-Path $kit 'Crear_ISO_WPI.ps1')
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $scriptPath + '"')
            $script:StatusText.Text = (Tr 'Creacion de ISO lanzada en consola elevada.')
        } catch { Show-WpiMessage(((Tr 'No se pudo lanzar la creacion: {0}') -f $_.Exception.Message), 'Crear ISO') | Out-Null }
    })
    $r.Children.Add($bRun) | Out-Null
    $c.Children.Add($r) | Out-Null
}

# Guarda en el estado lo elegido en el paso actual (sin validar, para "Atras").
function Save-IsoStep {
    $step = [int]$script:Wiz.Step
    switch ($step) {
        1 {
            $script:Wiz.SrcIso  = $script:WizCtl.Src.Text.Trim()
            $script:Wiz.OutDir  = $script:WizCtl.Out.Text.Trim()
            $script:Wiz.IsoName = $script:WizCtl.Name.Text.Trim()
            $script:Wiz.WorkDir = $script:WizCtl.Work.Text.Trim()
            $cbo = $script:WizCtl.Idx
            if ($cbo -and ($cbo -is [Windows.Controls.ComboBox]) -and $cbo.SelectedIndex -ge 0) {
                $selIt = $cbo.SelectedItem
                if ($cbo.SelectedIndex -eq 0 -or -not $selIt -or [string]$selIt.Tag -eq 'ALL') {
                    $script:Wiz.AllEditions = $true; $script:Wiz.Idx = '0'
                } else {
                    $script:Wiz.AllEditions = $false; $script:Wiz.Idx = [string]$selIt.Tag
                }
            }
        }
        2 { $s = @(); foreach ($cb in $script:WizCtl.TweakChecks) { if ($cb.IsChecked) { $s += [string]$cb.Tag } }; $script:Wiz.TweakNames = $s }
        3 { $s = @(); foreach ($cb in $script:WizCtl.DebloatChecks) { if ($cb.IsChecked) { $s += [string]$cb.Tag } }; $script:Wiz.DebloatPkgs = $s }
        4 { $s = @(); foreach ($cb in $script:WizCtl.AppChecks) { if ($cb.IsChecked) { $s += [string]$cb.Tag } }; $script:Wiz.AppIds = $s }
        5 { $script:Wiz.InjectDrivers = [bool]$script:WizCtl.Drv.IsChecked; $script:Wiz.DriversDir = $script:WizCtl.DrvDir.Text.Trim() }
        6 {
            $script:Wiz.LocalAccount = [bool]$script:WizCtl.Local.IsChecked
            $script:Wiz.BypassW11    = [bool]$script:WizCtl.Bypass.IsChecked
            $script:Wiz.VmMode       = [bool]$script:WizCtl.Vm.IsChecked
            $script:Wiz.Locale       = $script:WizCtl.Locale.Text.Trim()
            $script:Wiz.AccountName  = $script:WizCtl.Acct.Text.Trim()
            $script:Wiz.AccountPassword = $script:WizCtl.Pass.Text
        }
    }
}

# Muestra un aviso claro y devuelve $false (no se puede avanzar).
function Deny-IsoStep([string]$Msg) {
    Show-WpiMessage($Msg, 'Falta algo imprescindible', 'OK', 'Warning') | Out-Null
    return $false
}

# Valida lo IMPRESCINDIBLE del paso actual antes de pasar al siguiente.
# Devuelve $true si se puede avanzar; si no, avisa con el motivo y devuelve $false.
function Test-IsoStep {
    $w = $script:Wiz
    $step = [int]$w.Step
    switch ($step) {
        0 {
            $pr = Get-IsoPrereqs
            if (-not $pr.Oscdimg) {
                $r = Show-WpiMessage('No se ha detectado Windows ADK (oscdimg), necesario para CREAR la ISO al final. Puedes instalarlo con el boton "Instalar Windows ADK" ahora, o seguir configurando e instalarlo antes de crearla. Continuar de todas formas?', 'Falta Windows ADK', 'YesNo', 'Warning')
                if ($r -ne 'Yes') { return $false }
            }
            return $true
        }
        1 {
            $iso = [string]$w.SrcIso
            if (-not $iso) { return (Deny-IsoStep 'Falta la ISO de Windows origen. Pulsa "Elegir..." y selecciona el archivo .iso de Windows que usaras como base.') }
            if (-not (Test-Path $iso)) { return (Deny-IsoStep ('La ruta indicada no existe:' + "`n" + $iso + "`n`n" + 'Comprueba que el archivo sigue ahi o vuelve a elegirlo.')) }
            if (Test-Path $iso -PathType Container) { return (Deny-IsoStep ('Has indicado una CARPETA, no un archivo:' + "`n" + $iso + "`n`n" + 'Elige el archivo .iso de Windows.')) }
            if ($iso -notmatch '\.iso$') { return (Deny-IsoStep ('El archivo elegido no es una imagen ISO (.iso):' + "`n" + $iso + "`n`n" + 'Selecciona una ISO original de Windows.')) }
            $out = [string]$w.OutDir
            if (-not $out) { return (Deny-IsoStep 'Falta la carpeta de salida donde se dejara la ISO final. Pulsa "Elegir..." y selecciona una carpeta.') }
            if (-not (Test-Path $out)) {
                try { New-Item -ItemType Directory -Path $out -Force | Out-Null }
                catch { return (Deny-IsoStep ('No se puede usar/crear la carpeta de salida:' + "`n" + $out + "`n`n" + 'Elige otra carpeta valida.')) }
            }
            if (([string]$w.Idx) -ne '' -and ([string]$w.Idx) -notmatch '^\d+$') { return (Deny-IsoStep 'El "indice de edicion" debe ser un numero entero (0 = la edicion mas completa).') }
            $isoName = [string]$w.IsoName; if (-not $isoName) { $isoName = 'WPI_Custom.iso' }
            if ($isoName -notmatch '\.iso$') { $isoName = $isoName + '.iso' }
            $outIso = (Join-Path $out $isoName)
            try { if ([IO.Path]::GetFullPath($outIso) -eq [IO.Path]::GetFullPath($iso)) { return (Deny-IsoStep 'La ISO de SALIDA no puede ser el mismo archivo que la ISO de ORIGEN. Cambia el nombre o la carpeta de salida.') } } catch {}
            try {
                $drv = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($out))
                $di = Get-PSDrive -Name ($drv.TrimEnd('\').TrimEnd(':')) -ErrorAction SilentlyContinue
                if ($di -and $di.Free -gt 0) {
                    $freeGB = [math]::Round($di.Free / 1GB, 1)
                    if ($freeGB -lt 25) {
                        $rr = Show-WpiMessage(('Espacio libre en la unidad de salida: ' + $freeGB + ' GB. Crear la ISO (montar install.wim + oscdimg) necesita varios GB temporales; se recomiendan 25+ GB. Continuar de todas formas?'), 'Poco espacio', 'YesNo', 'Warning')
                        if ($rr -ne 'Yes') { return $false }
                    }
                }
            } catch {}
            return $true
        }
        5 {
            if ($w.InjectDrivers) {
                $dir = [string]$w.DriversDir
                if (-not $dir) { return (Deny-IsoStep 'Marcaste "Inyectar drivers" pero no has elegido la carpeta. Pulsa "Elegir..." y selecciona la carpeta con los drivers (.inf), o desmarca la opcion.') }
                if (-not (Test-Path $dir -PathType Container)) { return (Deny-IsoStep ('La carpeta de drivers no existe o no es una carpeta:' + "`n" + $dir + "`n`n" + 'Elige una carpeta valida o desmarca "Inyectar drivers".')) }
                $infs = 0
                try { $infs = @(Get-ChildItem -Path $dir -Filter *.inf -Recurse -ErrorAction SilentlyContinue).Count } catch {}
                if ($infs -eq 0) {
                    $r = Show-WpiMessage(('En esa carpeta no se han encontrado archivos .inf (drivers):' + "`n" + $dir + "`n`n" + 'Quizas no es la carpeta correcta. Continuar igualmente?'), 'Sin drivers .inf', 'YesNo', 'Warning')
                    if ($r -ne 'Yes') { return $false }
                }
            }
            return $true
        }
        6 {
            if (-not [string]$w.AccountName) { return (Deny-IsoStep 'El nombre de la cuenta no puede estar vacio: se usa para crear el usuario y el autoarranque de WPI. Escribe un nombre (ej. Usuario).') }
            if (-not [string]$w.Locale) { $script:Wiz.Locale = 'es-ES' }
            # Recordatorio FUERTE: el Modo VM es destructivo (formatea el disco 0).
            if ($w.VmMode) {
                $vmMsg = if ($script:Lang -eq 'en') {
                    "You enabled VM MODE.`n`nDuring install it will AUTOMATICALLY WIPE and partition DISK 0 without asking. Use it ONLY in a virtual machine or a disposable disk.`n`nOn a physical PC with your data, do NOT enable it: leave VM Mode OFF and pick the disk by hand during setup.`n`nContinue with VM Mode ENABLED?"
                } else {
                    "Has activado el MODO VM.`n`nAl instalar, BORRARA y particionara automaticamente el DISCO 0 sin preguntar. Usalo SOLO en una maquina virtual o un disco desechable.`n`nEn un PC fisico con tus datos, NO lo actives: deja el Modo VM desactivado y elige el disco a mano durante la instalacion.`n`nContinuar con el Modo VM ACTIVADO?"
                }
                $rv = Show-WpiMessage($vmMsg, 'Modo VM', 'YesNo', 'Warning')
                if ($rv -ne 'Yes') { return $false }
            }
            return $true
        }
    }
    return $true
}

# Barra de progreso (breadcrumb) del asistente: chips numerados. Los completados
# salen en verde con tic, el actual resaltado con su titulo, los futuros atenuados.
function New-IsoStepBar {
    param($Parent, [int]$Current, [string[]]$Titles)
    $bar = New-Object Windows.Controls.WrapPanel
    $bar.Orientation = 'Horizontal'
    $bar.Margin = New-Object Windows.Thickness(0,8,0,2)
    $tick = [string][char]0x2714
    $arrow = [string][char]0x25B8
    for ($i = 0; $i -lt $Titles.Count; $i++) {
        $chip = New-Object Windows.Controls.Border
        $chip.CornerRadius = New-Object Windows.CornerRadius(13)
        $chip.Margin = New-Object Windows.Thickness(0,4,7,4)
        $chip.Padding = New-Object Windows.Thickness(11,3,12,4)
        $tb = New-Object Windows.Controls.TextBlock; $tb.FontSize = 11.5
        if ($i -lt $Current) {
            $chip.Background = Get-ThemeBrush('#FF173A26'); $chip.BorderBrush = Get-ThemeBrush('#FF3E8E5E'); $chip.BorderThickness = New-Object Windows.Thickness(1)
            $tb.Text = ('{0} {1}' -f $tick, ($i + 1)); $tb.Foreground = Get-ThemeBrush('#FF5CFF8F'); $tb.FontWeight = 'Bold'
        } elseif ($i -eq $Current) {
            $chip.Background = Get-ThemeBrush('#FF23344A'); $chip.BorderBrush = Get-ThemeBrush($Theme.Iso); $chip.BorderThickness = New-Object Windows.Thickness(2)
            $tb.Text = ('{0} {1}. {2}' -f $arrow, ($i + 1), $Titles[$i]); $tb.Foreground = Get-ThemeBrush('#FFFFFFFF'); $tb.FontWeight = 'Bold'
        } else {
            $chip.Background = Get-ThemeBrush('#FF181820'); $chip.BorderBrush = Get-ThemeBrush('#FF2C2C3A'); $chip.BorderThickness = New-Object Windows.Thickness(1)
            $tb.Text = ([string]($i + 1)); $tb.Foreground = Get-ThemeBrush('#FF6F6F7A')
        }
        $chip.Child = $tb
        $bar.Children.Add($chip) | Out-Null
    }
    $Parent.Children.Add($bar) | Out-Null
}

# Dibuja el paso actual del asistente: cabecera + contenido + navegacion.
function Render-IsoWizard {
    $p = $script:CreateIsoList
    $p.Children.Clear()
    $script:WizCtl = @{}
    $step = [int]$script:Wiz.Step
    $titles  = if ($script:Lang -eq 'en') { @('Requirements', 'Source and output', 'Tweaks (privacy and performance)', 'Bloatware to remove', 'Apps to install', 'Drivers to inject', 'Unattended installation', 'Summary and confirmation') } else { @('Requisitos', 'Origen y salida', 'Tweaks (privacidad y rendimiento)', 'Bloatware a quitar', 'Apps a instalar', 'Drivers a inyectar', 'Instalacion desatendida', 'Resumen y confirmacion') }
    $accents = @($Theme.Install, $Theme.Install, $Theme.Optimize, $Theme.Clean, $Theme.Install, $Theme.Maintain, $Theme.Info, $Theme.Iso)

    $isoTitle = if ($script:Lang -eq 'en') { '[ISO]  ISO CREATOR - Wizard   {0}   Step {1} of {2}: {3}' } else { '[ISO]  CREADOR DE ISO - Asistente   {0}   Paso {1} de {2}: {3}' }
    $isoDesc = if ($script:Lang -eq 'en') { 'I guide you section by section: choose options and click "Next". You can go "Back" to change anything. Nothing is touched until the last step, where you confirm and the ISO is created.' } else { 'Te guio seccion a seccion: elige y pulsa "Siguiente". Puedes volver "Atras" para cambiar algo. No se toca nada hasta el ultimo paso, donde confirmas y se crea la ISO.' }
    $head = New-IsoCard $p ($isoTitle -f $script:Sep, ($step + 1), $script:WizTotal, $titles[$step]) $Theme.Iso $isoDesc

    # Breadcrumb visual: en que paso estoy y cuales quedan.
    New-IsoStepBar $p $step $titles

    # Banner "AHORA:" con la accion concreta de este paso (guia activa).
    $ctas = if ($script:Lang -eq 'en') { @(
        'NOW: make sure Windows ADK (oscdimg) is installed, then click "Next >".',
        'NOW: 1) Choose your Windows .iso   2) click "Detect editions"   3) pick ONE edition (faster) or "All"   4) set the output folder and ISO name.',
        'NOW: review the tweaks (safe ones are pre-checked) and click "Next >".',
        'NOW: pick the bloatware to remove from the factory image, then "Next >".',
        'NOW: choose the apps to auto-install on first boot, then "Next >".',
        'NOW: optionally inject drivers from a folder of .inf files, then "Next >".',
        'NOW: set the unattended options (local account, Win11 bypass, VM mode), then "Next >".',
        'NOW: review the summary and click "Confirm and CREATE the ISO".'
    ) } else { @(
        'AHORA: asegurate de tener Windows ADK (oscdimg) instalado y pulsa "Siguiente >".',
        'AHORA: 1) Elige tu .iso de Windows   2) pulsa "Detectar ediciones"   3) elige UNA edicion (mas rapido) o "Todas"   4) define la carpeta de salida y el nombre de la ISO.',
        'AHORA: revisa los tweaks (los seguros vienen marcados) y pulsa "Siguiente >".',
        'AHORA: marca el bloatware a quitar de fabrica y pulsa "Siguiente >".',
        'AHORA: elige las apps que se instalaran solas en el primer arranque y pulsa "Siguiente >".',
        'AHORA: si quieres, inyecta drivers desde una carpeta con archivos .inf y pulsa "Siguiente >".',
        'AHORA: ajusta el desatendido (cuenta local, bypass Win11, modo VM) y pulsa "Siguiente >".',
        'AHORA: revisa el resumen y pulsa "Confirmar y CREAR la ISO".'
    ) }
    $ctaBar = New-Object Windows.Controls.Border
    $ctaBar.Background = Get-ThemeBrush('#FF1A2E22'); $ctaBar.BorderBrush = Get-ThemeBrush('#FF3E8E5E')
    $ctaBar.BorderThickness = New-Object Windows.Thickness(0,0,0,0)
    $ctaBar.CornerRadius = New-Object Windows.CornerRadius(8)
    $ctaBar.Padding = New-Object Windows.Thickness(12,7,12,7); $ctaBar.Margin = New-Object Windows.Thickness(0,4,0,0)
    $ctaBar.BorderThickness = New-Object Windows.Thickness(4,1,1,1)
    $ctaTb = New-Object Windows.Controls.TextBlock
    $ctaTb.Text = $ctas[$step]; $ctaTb.TextWrapping = 'Wrap'; $ctaTb.FontSize = 12.5; $ctaTb.FontWeight = 'Bold'
    $ctaTb.Foreground = Get-ThemeBrush('#FF9DF5B8')
    $ctaBar.Child = $ctaTb
    $p.Children.Add($ctaBar) | Out-Null

    $content = New-IsoCard $p '' $accents[$step] ''
    switch ($step) {
        0 { Build-WizReq $content }
        1 { Build-WizSource $content }
        2 { Build-WizTweaks $content }
        3 { Build-WizDebloat $content }
        4 { Build-WizApps $content }
        5 { Build-WizDrivers $content }
        6 { Build-WizUnattend $content }
        7 { Build-WizSummary $content }
    }

    $nav = New-Object Windows.Controls.StackPanel; $nav.Orientation = 'Horizontal'; $nav.Margin = New-Object Windows.Thickness(0,12,0,6)
    if ($step -gt 0) {
        $bBack = New-Object Windows.Controls.Button; $bBack.Content = '< Atras'; $bBack.Padding = New-Object Windows.Thickness(16,6,16,6); $bBack.Margin = New-Object Windows.Thickness(0,0,8,0)
        $bBack.Add_Click({ Save-IsoStep; $script:Wiz.Step = [int]$script:Wiz.Step - 1; Render-IsoWizard })
        $nav.Children.Add($bBack) | Out-Null
    }
    if ($step -lt ($script:WizTotal - 1)) {
        $bNext = New-Object Windows.Controls.Button; $bNext.Content = 'Siguiente >'; $bNext.Padding = New-Object Windows.Thickness(18,6,18,6); $bNext.FontWeight = 'Bold'
        $bNext.Background = Get-ThemeBrush('#FF1F3A2E'); $bNext.BorderBrush = Get-ThemeBrush('#FF3E8E5E'); $bNext.Foreground = Get-ThemeBrush('#FFEAFBF0')
        $bNext.Add_Click({ Save-IsoStep; if (Test-IsoStep) { $script:Wiz.Step = [int]$script:Wiz.Step + 1; Render-IsoWizard } })
        $nav.Children.Add($bNext) | Out-Null
    }
    $p.Children.Add($nav) | Out-Null
}

# Panel @FEATURES: caracteristicas opcionales + capabilities (DISM), con estado.
function Build-FeaturesUI {
    $p = $script:FeaturesList
    $p.Children.Clear()
    $script:FeatureStatusLabels = @{}

    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = 'CARACTERISTICAS DE WINDOWS  ·  ACCIONES FUERTES (DISM)'
    $hdr.FontSize = 15; $hdr.FontWeight = 'Bold'; $hdr.Foreground = Get-ThemeBrush($Theme.Clean)
    $hdr.Margin = New-Object Windows.Thickness(2,10,0,2)
    $p.Children.Add($hdr) | Out-Null
    $info = New-Object Windows.Controls.TextBlock
    $info.Text = 'Activa o desactiva componentes opcionales de Windows (DISM). Cada accion corre por el motor con log forense y es reversible (Habilitar/Deshabilitar). Las marcadas "pide reinicio" requieren reiniciar para completarse. Algunas solo existen en Windows Pro/Enterprise.'
    $info.Foreground = Get-ThemeBrush($Theme.Sub); $info.FontSize = 12; $info.TextWrapping = 'Wrap'
    $info.Margin = New-Object Windows.Thickness(2,0,0,8)
    $p.Children.Add($info) | Out-Null

    $script:FeatSummary = New-Object Windows.Controls.TextBlock
    $script:FeatSummary.Text = 'Estado: escaneando caracteristicas...'
    $script:FeatSummary.Foreground = Get-ThemeBrush('#FF76E0FF'); $script:FeatSummary.FontSize = 12; $script:FeatSummary.TextWrapping = 'Wrap'
    $script:FeatSummary.Margin = New-Object Windows.Thickness(2,0,0,8)
    $p.Children.Add($script:FeatSummary) | Out-Null

    foreach ($f in $FeaturesCatalog) {
        $adv = ([string]$f.Risk -eq 'Avanzado')
        $card = New-Object Windows.Controls.Border
        $card.Background = Get-ThemeBrush($Theme.Card); $card.BorderBrush = Get-ThemeBrush($Theme.CardBorder)
        $card.BorderThickness = New-Object Windows.Thickness(1); $card.CornerRadius = New-Object Windows.CornerRadius(11)
        $card.Margin = New-Object Windows.Thickness(0,6,0,0); $card.Padding = New-Object Windows.Thickness(13,9,13,11)
        $sp = New-Object Windows.Controls.StackPanel
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = $(if ($adv) { [string]$f.Name + '   [avanzado]' } else { [string]$f.Name }) + $(if ($f.Reboot) { '   (pide reinicio)' } else { '' })
        $t.FontWeight = 'Bold'; $t.FontSize = 13
        $t.Foreground = Get-ThemeBrush($(if ($adv) { '#FFFFD166' } else { '#FFE6E6EC' }))
        $t.TextWrapping = 'Wrap'
        $sp.Children.Add($t) | Out-Null
        $d = New-Object Windows.Controls.TextBlock
        $d.Text = [string]$f.Desc; $d.Foreground = Get-ThemeBrush($Theme.Sub); $d.FontSize = 12; $d.TextWrapping = 'Wrap'
        $d.Margin = New-Object Windows.Thickness(0,2,0,2)
        $sp.Children.Add($d) | Out-Null
        $st = New-Object Windows.Controls.TextBlock
        $st.Text = 'estado: sin comprobar'; $st.FontSize = 11.5; $st.Foreground = Get-ThemeBrush($Theme.Sub)
        $st.Margin = New-Object Windows.Thickness(0,1,0,6); $st.TextWrapping = 'Wrap'
        $sp.Children.Add($st) | Out-Null
        $script:FeatureStatusLabels[[string]$f.Id] = $st
        $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'
        $bEn = New-Object Windows.Controls.Button
        $bEn.Content = 'Habilitar'; $bEn.Tag = $f; $bEn.Margin = New-Object Windows.Thickness(0,0,8,0)
        $bEn.Background = Get-ThemeBrush('#FF1F3A2E'); $bEn.BorderBrush = Get-ThemeBrush('#FF3E6B54')
        $bEn.Add_Click({
            $f = $this.Tag
            $msg = ('Vas a HABILITAR: {0}.' -f [string]$f.Name)
            if ($f.Reboot) { $msg += ' Esta caracteristica pide REINICIAR despues para completarse.' }
            $msg += ' Se puede revertir con "Deshabilitar". Continuar?'
            $r = Show-WpiMessage($msg, 'Caracteristicas de Windows', 'YesNo', 'Warning')
            if ($r -ne 'Yes') { return }
            $code = Get-FeatureCode -F $f -On $true
            Start-Worker -Mode 'tweaks' -Tweaks @(@{ Name = ('Habilitar: ' + [string]$f.Name); Code = $code })
        })
        $btnRow.Children.Add($bEn) | Out-Null
        $bDis = New-Object Windows.Controls.Button
        $bDis.Content = 'Deshabilitar'; $bDis.Tag = $f
        $bDis.Background = Get-ThemeBrush('#FF4F2A2A'); $bDis.BorderBrush = Get-ThemeBrush('#FF7B4444')
        $bDis.Add_Click({
            $f = $this.Tag
            $msg = ('Vas a DESHABILITAR/QUITAR: {0}.' -f [string]$f.Name)
            if ($f.Reboot) { $msg += ' Pide REINICIAR despues.' }
            $msg += ' Se puede volver a activar con "Habilitar". Continuar?'
            $r = Show-WpiMessage($msg, 'Caracteristicas de Windows', 'YesNo', 'Warning')
            if ($r -ne 'Yes') { return }
            $code = Get-FeatureCode -F $f -On $false
            Start-Worker -Mode 'tweaks' -Tweaks @(@{ Name = ('Deshabilitar: ' + [string]$f.Name); Code = $code })
        })
        $btnRow.Children.Add($bDis) | Out-Null
        $sp.Children.Add($btnRow) | Out-Null
        $card.Child = $sp
        $p.Children.Add($card) | Out-Null
    }

    $bRe = New-Object Windows.Controls.Button
    $bRe.Content = 'Re-detectar estado'; $bRe.HorizontalAlignment = 'Left'
    $bRe.Margin = New-Object Windows.Thickness(0,12,0,0)
    $bRe.Background = Get-ThemeBrush('#FF13414F'); $bRe.BorderBrush = Get-ThemeBrush('#FF76E0FF')
    $bRe.Add_Click({ $script:StatusText.Text = (Tr 'Re-escaneando caracteristicas...'); try { Detect-FeatureStates } catch {} })
    $p.Children.Add($bRe) | Out-Null

    try { Detect-FeatureStates } catch {}
}

# Helper para lanzar una fase individual de la suite como Administrador
function Launch-SinglePhase {
    param([string]$phaseNum)
    $isEn = ($script:Lang -eq 'en')
    $titleMsg = if ($isEn) { 'Launch Phase' } else { 'Lanzar Fase' }
    
    $folderName = if ($isEn) { 'Suite_Reparacion_EN' } else { 'Suite_Reparacion_ES' }
    $suitePath = Join-Path $PSScriptRoot $folderName
    if (-not (Test-Path $suitePath)) {
        $errFolder = if ($isEn) { 'Repair suite folder not found!' } else { 'No se encuentra la carpeta de la suite!' }
        Show-WpiMessage($errFolder, $titleMsg) | Out-Null
        return
    }

    # Busca el archivo .bat que empiece con "Fase_NN" o "Phase_NN" (para ingles)
    $pattern = if ($isEn) { ("Phase_{0}*.bat" -f $phaseNum) } else { ("Fase_{0}*.bat" -f $phaseNum) }
    $bat = Get-ChildItem -Path $suitePath -Filter $pattern | Select-Object -First 1
    if (-not $bat) {
        $patternFallback = ("Fase_{0}*.bat" -f $phaseNum)
        $bat = Get-ChildItem -Path $suitePath -Filter $patternFallback | Select-Object -First 1
    }
    if (-not $bat) {
        $patternFallback2 = ("Phase_{0}*.bat" -f $phaseNum)
        $bat = Get-ChildItem -Path $suitePath -Filter $patternFallback2 | Select-Object -First 1
    }

    if (-not $bat) {
        $errBat = if ($isEn) { ('Could not find the file for Phase {0} in the suite folder.') -f $phaseNum } else { ('No se pudo encontrar el archivo de la Fase {0} en la carpeta de la suite.') -f $phaseNum }
        Show-WpiMessage($errBat, $titleMsg) | Out-Null
        return
    }

    $confirmMsg = if ($isEn) {
        ("Are you sure you want to launch Phase {0} ({1}) independently as ADMINISTRATOR?") -f $phaseNum, $bat.BaseName
    } else {
        ("¿Estás seguro de que deseas lanzar la Fase {0} ({1}) por separado como ADMINISTRADOR?") -f $phaseNum, $bat.BaseName
    }
    $r = Show-WpiMessage($confirmMsg, $titleMsg, 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }

    try {
        Start-Process -FilePath $bat.FullName -Verb RunAs
        $statusMsg = if ($isEn) { ('Phase {0} launched.') -f $phaseNum } else { ('Fase {0} lanzada.') -f $phaseNum }
        $script:StatusText.Text = $statusMsg
    } catch {
        $errMsg = if ($isEn) { ('Could not launch Phase: {0}') -f $_.Exception.Message } else { ('No se pudo lanzar la Fase: {0}') -f $_.Exception.Message }
        Show-WpiMessage($errMsg, $titleMsg) | Out-Null
    }
}

function Open-SystemPanel {
    param([string]$Cmd, [string]$Name)

    $isEn = ($script:Lang -eq 'en')
    if ($Cmd -eq 'gpedit.msc') {
        $gpEditPath = Join-Path $env:SystemRoot 'System32\gpedit.msc'
        if (Test-Path -LiteralPath $gpEditPath) {
            try {
                Start-Process -FilePath 'mmc.exe' -ArgumentList ('/s "{0}"' -f $gpEditPath)
                try { $script:StatusText.Text = if ($isEn) { 'Policy Editor launched.' } else { 'Editor de directivas abierto.' } } catch {}
            } catch {
                $msg = if ($isEn) { ('Could not open gpedit.msc: {0}' -f $_.Exception.Message) } else { ('No se pudo abrir gpedit.msc: {0}' -f $_.Exception.Message) }
                Show-WpiMessage $msg 'gpedit.msc' 'OK' 'Warning' | Out-Null
            }
        } else {
            if ($isEn) {
                $msg  = "The Group Policy Editor (gpedit.msc) is not available on Windows Home.`n`n"
                $msg += "Alternatives:`n"
                $msg += "  $script:Sep Install the community version (unofficial)`n"
                $msg += "  $script:Sep Use Registry Editor (regedit) for manual changes`n"
                $msg += "  $script:Sep Upgrade to Windows Pro"
                Show-WpiMessage $msg 'gpedit.msc not available' 'OK' 'Information' | Out-Null
            } else {
                $msg  = "El Editor de directivas de grupo (gpedit.msc) no esta disponible en Windows Home.`n`n"
                $msg += "Alternativas:`n"
                $msg += "  $script:Sep Instalar la version de la comunidad (no oficial)`n"
                $msg += "  $script:Sep Usar el Editor del Registro (regedit) para cambios manuales`n"
                $msg += "  $script:Sep Actualizar a Windows Pro"
                Show-WpiMessage $msg 'gpedit.msc no disponible' 'OK' 'Information' | Out-Null
            }
            try { $script:StatusText.Text = if ($isEn) { 'gpedit.msc is not available on this Windows edition.' } else { 'gpedit.msc no esta disponible en esta edicion de Windows.' } } catch {}
        }
        return
    }

    try {
        if ($Cmd -like '*.msc') {
            $mscPath = Join-Path $env:SystemRoot ('System32\{0}' -f $Cmd)
            if (Test-Path -LiteralPath $mscPath) { Start-Process -FilePath 'mmc.exe' -ArgumentList ('/s "{0}"' -f $mscPath) }
            else { Start-Process -FilePath $Cmd }
        } elseif ($Cmd -like '*.cpl') {
            Start-Process -FilePath 'control.exe' -ArgumentList $Cmd
        } elseif ($Cmd -eq 'control') {
            Start-Process -FilePath 'control.exe'
        } else {
            Start-Process -FilePath $Cmd
        }
        try { $script:StatusText.Text = if ($isEn) { ('Opened: {0}' -f $Name) } else { ('Abierto: {0}' -f $Name) } } catch {}
    } catch {
        $msg = if ($isEn) { ('Could not open {0}: {1}' -f $Name, $_.Exception.Message) } else { ('No se pudo abrir {0}: {1}' -f $Name, $_.Exception.Message) }
        Show-WpiMessage $msg 'WPI Moderno' 'OK' 'Warning' | Out-Null
    }
}

function Build-RepairUI {
    $p = $script:RepairList
    $p.Children.Clear()

    $isEn = ($script:Lang -eq 'en')

    # Header Principal
    $hdr = New-Object Windows.Controls.TextBlock
    $hdr.Text = if ($isEn) { 'SYSTEM REPAIR  ·  EMERGENCY CONSOLE' } else { 'REPARACION DEL SISTEMA  ·  CONSOLA DE EMERGENCIA' }
    $hdr.FontSize = 15; $hdr.FontWeight = 'Bold'
    $hdr.Foreground = Get-ThemeBrush($Theme.Danger)
    $hdr.Margin = New-Object Windows.Thickness(2,10,0,2)
    $p.Children.Add($hdr) | Out-Null

    $info = New-Object Windows.Controls.TextBlock
    $info.Text = if ($isEn) { 'Deep Windows repair using the integrated 17-phase command-line console. Contains advanced automated and manual troubleshooting methodologies.' } else { 'Reparacion profunda de Windows mediante la consola de comandos integrada en 17 fases. Contiene metodologias avanzadas de diagnostico, triage y reparacion automatica o manual.' }
    $info.Foreground = Get-ThemeBrush($Theme.Sub); $info.FontSize = 12; $info.TextWrapping = 'Wrap'
    $info.Margin = New-Object Windows.Thickness(2,0,0,12)
    $p.Children.Add($info) | Out-Null

    # Card Principal de la Suite
    $card = New-Object Windows.Controls.Border
    $card.Background = Get-ThemeBrush($Theme.Card); $card.BorderBrush = Get-ThemeBrush($Theme.CardBorder)
    $card.BorderThickness = New-Object Windows.Thickness(1); $card.CornerRadius = New-Object Windows.CornerRadius(11)
    $card.Padding = New-Object Windows.Thickness(16,14,16,16)
    $card.Margin = New-Object Windows.Thickness(0,0,0,8)

    $sp = New-Object Windows.Controls.StackPanel

    $suiteHdr = New-Object Windows.Controls.TextBlock
    $suiteHdr.Text = if ($isEn) { 'EMERGENCY REPAIR SUITE (17 PHASES)' } else { 'SUITE DE REPARACION DE EMERGENCIA (17 FASES)' }
    $suiteHdr.FontWeight = 'Bold'; $suiteHdr.FontSize = 13.5; $suiteHdr.Foreground = Get-ThemeBrush($Theme.Text)
    $sp.Children.Add($suiteHdr) | Out-Null

    $suiteDesc = New-Object Windows.Controls.TextBlock
    $suiteDesc.Text = if ($isEn) { 'Launches the interactive terminal as Administrator. You will have access to the complete menu, triage recommendation engine, simulation mode, and logs generation.' } else { 'Abre la terminal interactiva como Administrador. Tendras acceso al menu completo, motor de recomendacion por triage, modo simulacion y generacion de reportes e informes.' }
    $suiteDesc.Foreground = Get-ThemeBrush($Theme.Sub); $suiteDesc.FontSize = 12; $suiteDesc.TextWrapping = 'Wrap'
    $suiteDesc.Margin = New-Object Windows.Thickness(0,4,0,12)
    $sp.Children.Add($suiteDesc) | Out-Null

    # Deteccion de carpeta, lanzador e idioma
    $suiteInfo = Test-SuiteReparacionReady
    $note = New-Object Windows.Controls.TextBlock
    if ($suiteInfo.FolderOk -and $suiteInfo.BatOk) {
        $note.Text = if ($isEn) { '[OK] English Suite engine active.' } else { '[OK] Motor de la Suite en Espanol activo.' }
        $note.Foreground = Get-ThemeBrush($Theme.Maintain)
    } elseif ($suiteInfo.FolderOk) {
        $note.Text = if ($isEn) { ('[ERROR] Main launcher missing: {0}') -f $suiteInfo.BatName } else { ('[ERROR] Falta el lanzador principal: {0}') -f $suiteInfo.BatName }
        $note.Foreground = Get-ThemeBrush($Theme.Danger)
    } else {
        $note.Text = if ($isEn) { '[ERROR] Repair suite folder (Suite_Reparacion_EN) not found!' } else { '[ERROR] No se encuentra la carpeta de la suite (Suite_Reparacion_ES)!' }
        $note.Foreground = Get-ThemeBrush($Theme.Danger)
    }
    $note.FontSize = 12; $note.Margin = New-Object Windows.Thickness(0,0,0,12)
    $sp.Children.Add($note) | Out-Null

    # Boton Lila Principal
    $btnConsole = New-Object Windows.Controls.Button
    $btnConsole.Content = if ($isEn) { 'Launch Interactive Console (Full Menu)' } else { 'Lanzar Consola Interactiva (Menu Completo)' }
    $btnConsole.Background = Get-ThemeBrush('#FF2A1F4F'); $btnConsole.BorderBrush = Get-ThemeBrush('#FF9076FF')
    $btnConsole.Foreground = Get-ThemeBrush($Theme.Text)
    $btnConsole.FontSize = 13.5; $btnConsole.FontWeight = 'Bold'
    $btnConsole.Padding = New-Object Windows.Thickness(18,10,18,10)
    $btnConsole.HorizontalAlignment = 'Left'
    $btnConsole.Cursor = [Windows.Input.Cursors]::Hand
    $btnConsole.Add_Click({ Start-RepairSuite })
    $sp.Children.Add($btnConsole) | Out-Null

    $card.Child = $sp
    $p.Children.Add($card) | Out-Null

    # --- Seccion: Ejecutar Fases Individuales (Colapsable) ---
    $exp = New-Object Windows.Controls.Expander
    $exp.Header = if ($isEn) { 'RUN INDIVIDUAL PHASES (ADVANCED)' } else { 'EJECUTAR FASES INDIVIDUALES (AVANZADO)' }
    $exp.Foreground = Get-ThemeBrush($Theme.Info)
    $exp.FontWeight = 'Bold'; $exp.FontSize = 12.5
    $exp.Margin = New-Object Windows.Thickness(0,0,0,16)

    $scroll = New-Object Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.MaxHeight = 540
    $scroll.Margin = New-Object Windows.Thickness(0,6,0,0)

    # Cuadricula de 2 columnas (estilo Tweaks): menos scroll, todas las fases de un vistazo.
    $spFases = New-Object Windows.Controls.Primitives.UniformGrid
    $spFases.Columns = 2

    if ($isEn) {
        $phases = @(
            @{ N='00'; Name='Diagnosis and Triage';       Desc='Checks SMART, space, and pending reboots.' }
            @{ N='01'; Name='Restore Point';             Desc='Creates a system restore point and registry backup.' }
            @{ N='02'; Name='Initial Cleanup';           Desc='Deletes temp files, Recycle Bin, and caches.' }
            @{ N='03'; Name='Disk Check (Chkdsk)';       Desc='Scans the C: drive for file system corruption.' }
            @{ N='04'; Name='Disk Optimization';         Desc='TRIM for SSDs or defragmentation for HDDs.' }
            @{ N='05'; Name='DISM Repair';               Desc='Repairs the Windows component store image.' }
            @{ N='06'; Name='SFC Verification';          Desc='Scans and restores corrupted Windows system files.' }
            @{ N='07'; Name='Repair WMI';                Desc='Rebuilds and fixes the WMI repository.' }
            @{ N='08'; Name='Store Apps & Startup';      Desc='Re-registers Store apps and optimizes startup items.' }
            @{ N='09'; Name='Search & Caches';           Desc='Rebuilds index and clears spooler/icon caches.' }
            @{ N='10'; Name='Certificates & Time';       Desc='Syncs time and updates root certificates.' }
            @{ N='11'; Name='Network Reset';             Desc='Resets Winsock, TCP/IP stack, and DNS.' }
            @{ N='12'; Name='GPO Policies';              Desc='Resets local Group Policy objects to defaults.' }
            @{ N='13'; Name='Windows Update';            Desc='Clears SoftwareDistribution cache and restarts services.' }
            @{ N='14'; Name='Winget Repair';             Desc='Resets winget sources and updates catalog.' }
            @{ N='15'; Name='Devices & Drivers';         Desc='Scans device manager and troubleshoots driver errors.' }
            @{ N='16'; Name='Final Cleanup';             Desc='Cleans remaining logs and generates HTML report.' }
        )
    } else {
        $phases = @(
            @{ N='00'; Name='Diagnostico y Triage';        Desc='Comprueba SMART, espacio libre y reinicios pendientes.' }
            @{ N='01'; Name='Punto de Restauracion';       Desc='Crea un punto de restauracion y respalda el registro.' }
            @{ N='02'; Name='Limpieza Inicial';            Desc='Borra temporales, papelera y caches de entrega.' }
            @{ N='03'; Name='Comprobacion de Disco (Chkdsk)'; Desc='Revisa el disco C: en busca de errores de archivos.' }
            @{ N='04'; Name='Optimizacion de Disco';       Desc='TRIM si es SSD o desfragmentacion si es HDD.' }
            @{ N='05'; Name='Reparacion DISM';             Desc='Repara el almacen de componentes de Windows (SFC source).' }
            @{ N='06'; Name='Comprobacion SFC';            Desc='sfc /scannow: repara archivos de sistema danados.' }
            @{ N='07'; Name='Reparar WMI';                 Desc='Repara y reconstruye el repositorio WMI de Windows.' }
            @{ N='08'; Name='Apps de Store e Inicio';      Desc='Restablece apps de la Tienda y optimiza inicio.' }
            @{ N='09'; Name='Busqueda y Caches';           Desc='Reconstruye el indice de busqueda y limpia caches.' }
            @{ N='10'; Name='Certificados y Hora';         Desc='Sincroniza la hora y repara certificados raiz.' }
            @{ N='11'; Name='Restablecer Red';             Desc='Resetea winsock, pila TCP/IP, DNS y proxy.' }
            @{ N='12'; Name='Directivas GPO';              Desc='Restablece politicas de grupo locales a valores de fabrica.' }
            @{ N='13'; Name='Windows Update';              Desc='Limpia la cache y reinicia los servicios de actualizaciones.' }
            @{ N='14'; Name='Reparacion de WinGet';        Desc='Resetea fuentes de winget y arregla catalogo.' }
            @{ N='15'; Name='Dispositivos y Drivers';      Desc='Muestra errores de drivers y Administrador de Dispositivos.' }
            @{ N='16'; Name='Limpieza Final e Informe';    Desc='Limpieza profunda de logs y genera informe HTML final.' }
        )
    }

    foreach ($ph in $phases) {
        $fBorder = New-Object Windows.Controls.Border
        $fBorder.Background = Get-ThemeBrush('#FF15151F'); $fBorder.BorderBrush = Get-ThemeBrush('#FF2C2C3A')
        $fBorder.BorderThickness = New-Object Windows.Thickness(1); $fBorder.CornerRadius = New-Object Windows.CornerRadius(8)
        $fBorder.Margin = New-Object Windows.Thickness(0,0,8,8); $fBorder.Padding = New-Object Windows.Thickness(10,6,10,6)
        $fBorder.VerticalAlignment = 'Stretch'

        $dp = New-Object Windows.Controls.DockPanel
        $dp.LastChildFill = $true

        # Badge numerico
        $badgeBorder = New-Object Windows.Controls.Border
        $badgeBorder.Width = 24; $badgeBorder.Height = 24
        $badgeBorder.Background = Get-ThemeBrush($(if ($ph.N -eq '00') { $Theme.Info } else { '#FF2A2A3E' }))
        $badgeBorder.CornerRadius = New-Object Windows.CornerRadius(12)
        $badgeBorder.Margin = New-Object Windows.Thickness(0,0,10,0)
        
        $badgeText = New-Object Windows.Controls.TextBlock
        $badgeText.Text = $ph.N; $badgeText.FontSize = 11; $badgeText.FontWeight = 'Bold'
        $badgeText.Foreground = Get-ThemeBrush($Theme.Text)
        $badgeText.HorizontalAlignment = 'Center'; $badgeText.VerticalAlignment = 'Center'
        $badgeBorder.Child = $badgeText
        [Windows.Controls.DockPanel]::SetDock($badgeBorder, [Windows.Controls.Dock]::Left)
        $dp.Children.Add($badgeBorder) | Out-Null

        # Boton Lanzar
        $btnLaunch = New-Object Windows.Controls.Button
        $btnLaunch.Content = if ($isEn) { 'Launch' } else { 'Lanzar' }
        $btnLaunch.Tag = $ph.N
        $btnLaunch.Background = Get-ThemeBrush('#FF1F3A2E'); $btnLaunch.BorderBrush = Get-ThemeBrush('#FF3E6B54')
        $btnLaunch.Foreground = Get-ThemeBrush($Theme.Text)
        $btnLaunch.FontSize = 11; $btnLaunch.FontWeight = 'Bold'
        $btnLaunch.Padding = New-Object Windows.Thickness(10,3,10,3)
        $btnLaunch.Cursor = [Windows.Input.Cursors]::Hand
        $btnLaunch.Add_Click({ Launch-SinglePhase ($this.Tag) })
        [Windows.Controls.DockPanel]::SetDock($btnLaunch, [Windows.Controls.Dock]::Right)
        $dp.Children.Add($btnLaunch) | Out-Null

        # Info central
        $infoSp = New-Object Windows.Controls.StackPanel
        
        $fName = New-Object Windows.Controls.TextBlock
        $fName.Text = $ph.Name; $fName.FontWeight = 'Bold'; $fName.FontSize = 12
        $fName.Foreground = Get-ThemeBrush($Theme.Text)
        $infoSp.Children.Add($fName) | Out-Null

        $fDesc = New-Object Windows.Controls.TextBlock
        $fDesc.Text = $ph.Desc; $fDesc.Foreground = Get-ThemeBrush($Theme.Sub); $fDesc.FontSize = 11
        $fDesc.TextWrapping = 'Wrap'
        $infoSp.Children.Add($fDesc) | Out-Null

        $dp.Children.Add($infoSp) | Out-Null
        $fBorder.Child = $dp
        $spFases.Children.Add($fBorder) | Out-Null
    }

    $scroll.Content = $spFases
    $exp.Content = $scroll
    $p.Children.Add($exp) | Out-Null

    # --- Seccion: Privacidad Avanzada ---
    $hdr2 = New-Object Windows.Controls.TextBlock
    $hdr2.Text = if ($isEn) { 'ADVANCED PRIVACY' } else { 'PRIVACIDAD AVANZADA' }
    $hdr2.FontSize = 13.5; $hdr2.FontWeight = 'Bold'; $hdr2.Foreground = Get-ThemeBrush($Theme.Optimize)
    $hdr2.Margin = New-Object Windows.Thickness(2,6,0,4)
    $p.Children.Add($hdr2) | Out-Null

    $oo = New-Object Windows.Controls.TextBlock
    $oo.Text = if ($isEn) { 'O&O ShutUp10++ is a free portable tool to fine-tune Windows telemetry and privacy settings via its own interface. Opens the official website for download.' } else { 'O&O ShutUp10++ es una herramienta gratuita y portable para ajustar al detalle la telemetria y la privacidad de Windows con su propia interfaz. Se abre su pagina oficial para descargarla.' }
    $oo.Foreground = Get-ThemeBrush($Theme.Sub); $oo.FontSize = 12; $oo.TextWrapping = 'Wrap'
    $oo.Margin = New-Object Windows.Thickness(2,0,0,8)
    $p.Children.Add($oo) | Out-Null

    $bOO = New-Object Windows.Controls.Button
    $bOO.Content = if ($isEn) { 'Download O&O ShutUp10++ (Official Site)' } else { 'Descargar O&O ShutUp10++ (web oficial)' }
    $bOO.HorizontalAlignment = 'Left'
    $bOO.Background = Get-ThemeBrush('#FF3A2A6E'); $bOO.BorderBrush = Get-ThemeBrush('#FF7C4DFF')
    $bOO.Foreground = Get-ThemeBrush($Theme.Text)
    $bOO.FontSize = 12.5; $bOO.FontWeight = 'Bold'
    $bOO.Padding = New-Object Windows.Thickness(14,8,14,8)
    $bOO.Cursor = [Windows.Input.Cursors]::Hand
    $bOO.Add_Click({ try { Start-Process 'https://www.oo-software.com/en/shutup10' } catch {} })
    $p.Children.Add($bOO) | Out-Null

    # --- Seccion: Paneles Clasicos ---
    $hdr3 = New-Object Windows.Controls.TextBlock
    $hdr3.Text = if ($isEn) { 'CLASSIC WINDOWS PANELS' } else { 'PANELES CLASICOS DE WINDOWS' }
    $hdr3.FontSize = 13.5; $hdr3.FontWeight = 'Bold'; $hdr3.Foreground = Get-ThemeBrush($Theme.Optimize)
    $hdr3.Margin = New-Object Windows.Thickness(2,20,0,4)
    $p.Children.Add($hdr3) | Out-Null

    $infoPanels = New-Object Windows.Controls.TextBlock
    $infoPanels.Text = if ($isEn) { 'Quick access to legacy Windows system utility consoles (these shortcuts are not available in the command terminal).' } else { 'Accesos rapidos a consolas de administracion clasicas de Windows (estas utilidades no se encuentran dentro de la suite de comandos).' }
    $infoPanels.Foreground = Get-ThemeBrush($Theme.Sub); $infoPanels.FontSize = 12; $infoPanels.TextWrapping = 'Wrap'
    $infoPanels.Margin = New-Object Windows.Thickness(2,0,0,8)
    $p.Children.Add($infoPanels) | Out-Null

    $wrap = New-Object Windows.Controls.WrapPanel
    $wrap.Margin = New-Object Windows.Thickness(0,2,0,0)
    
    # Adaptar los nombres de paneles de control al idioma seleccionado
    $panelsList = @()
    foreach ($panelDef in $SystemPanels) {
        $pName = [string]$panelDef.Name
        if ($isEn) {
            switch ($pName) {
                'Panel de control' { $pName = 'Control Panel' }
                'Programas y caracteristicas' { $pName = 'Programs and Features' }
                'Propiedades del sistema' { $pName = 'System Properties' }
                'Opciones de energia' { $pName = 'Power Options' }
                'Conexiones de red' { $pName = 'Network Connections' }
                'Sonido' { $pName = 'Sound' }
                'Servicios' { $pName = 'Services' }
                'Administrador de dispositivos' { $pName = 'Device Manager' }
                'Administrador de discos' { $pName = 'Disk Management' }
                'Editor de directivas (gpedit)' { $pName = 'Policy Editor (gpedit)' }
                'Visor de eventos' { $pName = 'Event Viewer' }
                'Editor del Registro' { $pName = 'Registry Editor' }
            }
        }
        $panelsList += @{ Name = $pName; Cmd = $panelDef.Cmd }
    }

    foreach ($panelDef in $panelsList) {
        $pb = New-Object Windows.Controls.Button
        $pb.Content = $panelDef.Name; $pb.Tag = $panelDef
        $pb.Margin = New-Object Windows.Thickness(0,6,8,0)
        $pb.Background = Get-ThemeBrush('#FF1A2B3C'); $pb.BorderBrush = Get-ThemeBrush('#FF3A5B7C')
        $pb.Foreground = Get-ThemeBrush($Theme.Text)
        $pb.Padding = New-Object Windows.Thickness(12,6,12,6)
        $pb.Cursor = [Windows.Input.Cursors]::Hand
        $pb.Add_Click({ Open-SystemPanel ([string]$this.Tag.Cmd) ([string]$this.Tag.Name) })
        $wrap.Children.Add($pb) | Out-Null
    }
    $p.Children.Add($wrap) | Out-Null
}

function Apply-Filter {
    $idx = $script:SideList.SelectedIndex
    if ($idx -lt 0) { $idx = $script:SideAllIndex }
    $sel = $script:SideMap[$idx]
    if ($sel -eq '@HDR') { return }   # cabecera de grupo: no es un panel
    $script:AppsScroll.Visibility     = 'Collapsed'
    $script:TweaksScroll.Visibility   = 'Collapsed'
    $script:UpgradesScroll.Visibility = 'Collapsed'
    $script:WingetSearchScroll.Visibility = 'Collapsed'
    $script:DebloatScroll.Visibility   = 'Collapsed'
    $script:SnapshotScroll.Visibility  = 'Collapsed'
    $script:GuidesScroll.Visibility    = 'Collapsed'
    $script:DriversScroll.Visibility   = 'Collapsed'
    $script:WinUpdateScroll.Visibility = 'Collapsed'
    $script:RepairScroll.Visibility    = 'Collapsed'
    $script:SummaryScroll.Visibility   = 'Collapsed'
    $script:FeaturesScroll.Visibility  = 'Collapsed'
    $script:CreateIsoScroll.Visibility = 'Collapsed'
    $script:LogViewerScroll.Visibility = 'Collapsed'
    $script:QuickStartScroll.Visibility = 'Collapsed'
    $script:FindAllScroll.Visibility = 'Collapsed'
    if ($sel -eq '@TWEAKS')   { $script:TweaksScroll.Visibility   = 'Visible'; if (-not $script:TweakDetected) { try { Detect-TweakStates } catch {} }; return }
    if ($sel -eq '@UPGRADES') { $script:UpgradesScroll.Visibility = 'Visible'; return }
    if ($sel -eq '@SEARCH')   { $script:WingetSearchScroll.Visibility = 'Visible'; return }
    if ($sel -eq '@DEBLOAT')  { $script:DebloatScroll.Visibility  = 'Visible'; if (-not $script:DebloatDetected) { try { Detect-DebloatStates } catch {} }; return }
    if ($sel -eq '@SNAPSHOT') { $script:SnapshotScroll.Visibility = 'Visible'; return }
    if ($sel -eq '@GUIDES')   { $script:GuidesScroll.Visibility   = 'Visible'; return }
    if ($sel -eq '@WINUPDATE') { $script:WinUpdateScroll.Visibility = 'Visible'; if (-not $script:WuBuilt) { $script:WuBuilt=$true; try { Build-WinUpdateUI } catch {}; try { Translate-Tree $script:WinUpdateScroll; Apply-WpiToolTips $script:WinUpdateScroll } catch {} }; return }
    if ($sel -eq '@REPAIR')    { $script:RepairScroll.Visibility = 'Visible'; if (-not $script:RepBuilt) { $script:RepBuilt=$true; try { Build-RepairUI } catch {}; try { Translate-Tree $script:RepairScroll; Apply-WpiToolTips $script:RepairScroll } catch {} }; return }
    if ($sel -eq '@FEATURES')  { $script:FeaturesScroll.Visibility = 'Visible'; if (-not $script:FeatBuilt) { $script:FeatBuilt=$true; try { Build-FeaturesUI } catch {}; try { Translate-Tree $script:FeaturesScroll; Apply-WpiToolTips $script:FeaturesScroll } catch {} } else { try { Detect-FeatureStates; Apply-WpiToolTips $script:FeaturesScroll } catch {} }; return }
    if ($sel -eq '@CREATEISO') { $script:CreateIsoScroll.Visibility = 'Visible'; if (-not $script:IsoBuilt) { $script:IsoBuilt=$true; try { Build-CreateIsoUI } catch {}; try { Translate-Tree $script:CreateIsoScroll; Apply-WpiToolTips $script:CreateIsoScroll } catch {} } else { try { Update-IsoPrereqText; Apply-WpiToolTips $script:CreateIsoScroll } catch {} }; return }
    if ($sel -eq '@LOGVIEWER') { $script:LogViewerScroll.Visibility = 'Visible'; if (-not $script:LogViewerBuilt) { $script:LogViewerBuilt=$true; try { Build-LogViewerUI } catch {}; try { Translate-Tree $script:LogViewerScroll; Apply-WpiToolTips $script:LogViewerScroll } catch {} } else { try { Refresh-LogViewer; Apply-WpiToolTips $script:LogViewerScroll } catch {} }; return }
    if ($sel -eq '@QUICKSTART') { $script:QuickStartScroll.Visibility = 'Visible'; if (-not $script:QuickBuilt) { $script:QuickBuilt=$true; try { Build-QuickStartUI } catch {}; try { Translate-Tree $script:QuickStartScroll; Apply-WpiToolTips $script:QuickStartScroll } catch {} }; return }
    if ($sel -eq '@FINDALL') { $script:FindAllScroll.Visibility = 'Visible'; if (-not $script:FindAllBuilt) { $script:FindAllBuilt=$true; try { Build-FindAllUI } catch {}; try { Translate-Tree $script:FindAllScroll; Apply-WpiToolTips $script:FindAllScroll } catch {} }; return }
    if ($sel -eq '@SUMMARY')   { $script:SummaryScroll.Visibility = 'Visible'; try { Build-SummaryUI } catch {} ; try { Translate-Tree $script:SummaryScroll; Apply-WpiToolTips $script:SummaryScroll } catch {} ; return }
    if ($sel -eq '@DRIVERS')  {
        $script:DriversScroll.Visibility = 'Visible'
        if (-not $script:HwScanned) { $script:HwScanned = $true; try { Build-HardwareUI } catch {}; try { Translate-Tree $script:DriversScroll; Apply-WpiToolTips $script:DriversScroll } catch {} }
        return
    }
    $script:AppsScroll.Visibility = 'Visible'
    $q = $script:search.Text.Trim()
    foreach ($entry in $script:Cards) {
        if ($sel -ne '@ALL' -and $entry.Cat -ne $sel) {
            $entry.Card.Visibility = 'Collapsed'
            continue
        }
        $any = $false
        foreach ($cb in $entry.Checks) {
            $vis = ($q -eq '' -or ($cb.Content -like "*$q*") -or ($cb.Tag -like "*$q*"))
            $cb.Visibility = $(if ($vis) { 'Visible' } else { 'Collapsed' })
            if ($vis) { $any = $true }
        }
        $entry.Card.Visibility = $(if ($any) { 'Visible' } else { 'Collapsed' })
        if ($q -ne '' -and $any) { try { $entry.Exp.IsExpanded = $true } catch {} }
    }
}
# Buscador superior: en la vista de Apps filtra in situ; en cualquier otra
# seccion (Inicio facil, Tweaks, Reparacion, etc.) enruta a la busqueda GLOBAL
# (@FINDALL) para que escribir arriba SIEMPRE encuentre algo. Funciona igual en
# ES y EN: la busqueda global compara contra Name/Id (no contra texto traducido).
function Invoke-TopSearch {
    $q = ''
    try { $q = ([string]$script:search.Text).Trim() } catch {}
    $idx = $script:SideList.SelectedIndex
    if ($idx -lt 0) { $idx = $script:SideAllIndex }
    $sel = [string]$script:SideMap[$idx]
    $appsView = ($sel -eq '@ALL') -or (-not $sel.StartsWith('@'))
    if ($appsView) { Apply-Filter; return }
    if ($q.Length -lt 2) {
        # En el panel global, vaciar el cuadro vuelve a mostrar la ayuda inicial.
        if ($sel -eq '@FINDALL' -and $script:FindBox) { $script:FindBox.Text = $q; try { Do-FindAll } catch {} }
        return
    }
    $fi = $script:SideMap.IndexOf('@FINDALL')
    if ($fi -ge 0 -and $script:SideList.SelectedIndex -ne $fi) {
        $script:SideList.SelectedIndex = $fi   # dispara Apply-Filter -> construye y muestra el panel global
    }
    if ($script:FindBox) { $script:FindBox.Text = $q }
    try { Do-FindAll } catch {}
}
$script:search.Add_TextChanged({ Invoke-TopSearch })
$script:SideList.Add_SelectionChanged({ Apply-Filter })
Apply-Filter

# --------- AJUSTES PERSISTENTES (wpi_settings.json) ---------
$script:LastSelection = @()
$script:WinGeom = $null
function Load-Settings {
    try {
        if (Test-Path $Config.SettingsFile) {
            $rawSettings = Get-Content $Config.SettingsFile -Raw
            $s = $null
            try { $s = $rawSettings | ConvertFrom-Json }
            catch {
                # Ajustes corruptos: no bloquear el arranque. Guardamos copia del
                # archivo danado, arrancamos con defaults y dejamos aviso suave.
                try { Copy-Item $Config.SettingsFile ($Config.SettingsFile + '.corrupt.bak') -Force } catch {}
                try { W warn ('Ajustes corruptos (' + $_.Exception.Message + '). Se arranca con valores por defecto; copia en wpi_settings.json.corrupt.bak') } catch {}
                $script:SettingsRestored = $true
                return
            }
            if ($s.ParallelInstalls) { $Config.ParallelInstalls = [math]::Max(1, [math]::Min(3, [int]$s.ParallelInstalls)) }
            if ($null -ne $s.PSObject.Properties['AutoDetectInstalled']) { $Config.AutoDetectInstalled = [bool]$s.AutoDetectInstalled }
            if ($null -ne $s.PSObject.Properties['InstallTimeoutMin']) { $Config.InstallTimeoutMin = [math]::Max(0, [int]$s.InstallTimeoutMin) }
            if ($s.LastSelection) { $script:LastSelection = @($s.LastSelection) }
            if ($s.WinGeom -and $s.WinGeom.W) {
                $script:WinGeom = @{ W=[double]$s.WinGeom.W; H=[double]$s.WinGeom.H; T=[double]$s.WinGeom.T; L=[double]$s.WinGeom.L }
            }
        }
    } catch {}
}
function Save-Settings {
    try {
        $sel = @($script:Checks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
        if ($sel.Count -eq 0 -and $script:LastSelection.Count -gt 0) { $sel = $script:LastSelection }
        $geom = @{ W=0; H=0; T=-1; L=-1 }
        try {
            if ($window.WindowState -eq 'Normal') {
                $geom = @{ W=[int]$window.Width; H=[int]$window.Height; T=[int]$window.Top; L=[int]$window.Left }
            } elseif ($script:WinGeom) { $geom = $script:WinGeom }
        } catch {}
        [pscustomobject]@{
            ParallelInstalls    = [int]$Config.ParallelInstalls
            AutoDetectInstalled = [bool]$Config.AutoDetectInstalled
            InstallTimeoutMin   = [int]$Config.InstallTimeoutMin
            LastSelection       = $sel
            WinGeom             = $geom
            Theme               = [string]$script:ThemeName
            Lang                = [string]$script:Lang
        } | ConvertTo-Json | ForEach-Object { Set-WpiContent -Path $Config.SettingsFile -Value $_ }
    } catch {}
}
Load-Settings

$script:SpeedBox = $window.FindName('SpeedBox')
$script:SpeedBox.SelectedIndex = [int]$Config.ParallelInstalls - 1
$script:SpeedBox.Add_SelectionChanged({
    $Config.ParallelInstalls = $script:SpeedBox.SelectedIndex + 1
    Save-Settings
})

# B4: ambito de instalacion (--scope) y fallback a Chocolatey (opt-in).
# Por defecto Auto/desactivado -> comportamiento identico al actual.
$script:InstallScope = ''
$script:ChocoFallback = $false
$script:ScopeBox = $window.FindName('ScopeBox')
if ($script:ScopeBox) {
    $script:ScopeBox.SelectedIndex = 0
    $script:ScopeBox.Add_SelectionChanged({
        switch ($script:ScopeBox.SelectedIndex) {
            1 { $script:InstallScope = 'user' }
            2 { $script:InstallScope = 'machine' }
            default { $script:InstallScope = '' }
        }
    })
}
$script:ChkChoco = $window.FindName('ChkChoco')
if ($script:ChkChoco) {
    $script:ChkChoco.Add_Checked({
        $script:ChocoFallback = $true
        $hasChoco = $false
        try { if (Get-Command choco.exe -ErrorAction SilentlyContinue) { $hasChoco = $true } } catch {}
        $msg = 'FALLBACK A CHOCOLATEY (activado)' + "`n`n"
        $msg += 'Que hace: por defecto el WPI instala con winget. Con esta opcion, si winget FALLA al instalar una app concreta, el WPI reintentara ESA app con Chocolatey (choco install).' + "`n`n"
        $msg += 'Detalles:' + "`n"
        $msg += ' - Solo actua cuando winget falla; si winget instala bien, no se usa.' + "`n"
        $msg += ' - Es "best-effort": esa app puede no existir en Chocolatey con el mismo nombre.' + "`n"
        $msg += ' - El metodo usado (winget o choco) queda registrado en el log.' + "`n"
        $msg += ' - No instala Chocolatey por ti.' + "`n`n"
        if ($hasChoco) { $msg += 'Chocolatey DETECTADO en este equipo: el fallback podra usarse.' }
        else { $msg += 'AVISO: Chocolatey NO esta instalado. Mientras no lo instales, el fallback no hara nada (winget seguira siendo el unico metodo).' }
        Show-WpiMessage($msg, 'Fallback a Chocolatey', 'OK', 'Information') | Out-Null
    })
    $script:ChkChoco.Add_Unchecked({ $script:ChocoFallback = $false })
}

# ---------------- MOTOR ASINCRONO: lanzador -----------------
$script:State = [hashtable]::Synchronized(@{
    Running = $false; Cancel = $false
    Done = 0; Total = 0; Ok = 0; Fail = 0; Reboot = 0; CurName = ''; CurPercent = 0
    FailList   = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    DetectList = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    Upgrades   = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    SearchResults = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    VerifyWarn = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
})
$script:Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[psobject]'
$script:NameMap = @{}
foreach ($a in $catalog) { $script:NameMap[$a.Id] = $a.Name }
$script:WorkerPS = $null; $script:WorkerHandle = $null; $script:WorkerRS = $null
$script:CurrentLog = ''
$script:Skip_Closing_Save = $false
$script:LastDownloadDir = ''
$script:LastMode = ''
$script:LastBatchIds = @()
$script:HwScanned = $false
$script:HwReportText = ''

$script:ActionButtons = @('BtnInstall','BtnUpgrade','BtnList','BtnValidate','BtnAll','BtnNone','BtnSave','BtnLoad',
                          'BtnPresetGaming','BtnPresetDev','BtnPresetMedia','BtnPresetClean','BtnPresetLast',
                          'BtnClearSel','BtnDetect','BtnUninstall') |
                        ForEach-Object { $window.FindName($_) }
$script:ActionButtons += $script:BtnTweaks
$script:ActionButtons += $script:BtnTweaksUndo
$script:ActionButtons += $script:BtnTweakDetect
$script:ActionButtons += $script:BtnTweakMissing
$script:ActionButtons += $script:BtnTweakSave
$script:ActionButtons += $script:BtnTweakLoad
$script:ActionButtons += $script:BtnUpgScan
$script:ActionButtons += $script:BtnUpgWpi
$script:ActionButtons += $script:BtnUpgOther
$script:ActionButtons += $script:BtnWgSearch
$script:ActionButtons += $script:BtnWgInstall
$script:ActionButtons += $script:BtnWgDownload
$script:ActionButtons += $script:BtnDebloat
$script:ActionButtons += $script:BtnDebloatDetect
$script:ActionButtons += $script:BtnDebloatInstalled
$script:ActionButtons += $script:BtnDebloatSave
$script:ActionButtons += $script:BtnDebloatLoad
$script:ActionButtons += $script:BtnDebloatOneDrive
$script:ActionButtons += $script:BtnSnapExport
$script:ActionButtons += $script:BtnSnapImport
$script:ActionButtons += $script:BtnHwScan
$script:ActionButtons += $script:BtnHwCopy
$script:ActionButtons += $script:BtnHwExport
$script:ActionButtons += $script:BtnDrvBackup
$script:ActionButtons += $script:BtnDrvRestore
$script:ActionButtons += $script:BtnGuidesTemplate
$script:ActionButtons += $script:BtnGuidesReload
$script:ActionButtons += ($window.FindName('BtnDownload'))

function Set-Busy([bool]$busy) {
    foreach ($b in $script:ActionButtons) { $b.IsEnabled = -not $busy }
    $script:BtnCancel.IsEnabled = $busy
}

function Start-Worker {
    param([string]$Mode, [string[]]$Ids = @(), [array]$Tweaks = @(), [string]$Query = '')
    if ($script:State.Running) { return }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:CurrentLog = Join-Path $Config.LogDir ('wpi_{0}_{1}.log' -f $Mode, $stamp)
    $script:LogPathTxt.Text = $script:CurrentLog
    $script:State.Running = $true
    $script:State.Cancel  = $false
    $script:State.Done = 0; $script:State.Total = 0; $script:State.Ok = 0; $script:State.Fail = 0; $script:State.Reboot = 0; $script:State.CurName = ''; $script:State.CurPercent = 0
    $script:State.FailList.Clear()
    $script:State.DetectList.Clear()
    $script:State.Upgrades.Clear()
    $script:State.SearchResults.Clear()
    $script:State.VerifyWarn.Clear()
    $script:LastMode = $Mode
    $script:LastBatchIds = @($Ids)
    $script:LogExpander.IsExpanded = ($Mode -notin @('detect','scanupgrades','search'))
    $script:Prog.Value = 0
    $script:StatusText.Text = (Tr 'Iniciando...')
    Set-Busy $true

    $script:WorkerRS = [runspacefactory]::CreateRunspace()
    $script:WorkerRS.ApartmentState = 'MTA'
    $script:WorkerRS.Open()
    $script:WorkerPS = [powershell]::Create()
    $script:WorkerPS.Runspace = $script:WorkerRS
    [void]$script:WorkerPS.AddScript($WorkerScript.ToString()).
        AddArgument($script:Queue).AddArgument($script:State).AddArgument($Mode).
        AddArgument($Ids).AddArgument([math]::Max(1, [math]::Min(3, [int]$Config.ParallelInstalls))).
        AddArgument($script:CurrentLog).AddArgument($Tweaks).AddArgument($script:NameMap).
        AddArgument([math]::Max(0, [int]$Config.InstallTimeoutMin)).AddArgument($Query).
        AddArgument([string]$script:InstallScope).AddArgument([bool]$script:ChocoFallback).
        AddArgument([string]$script:Lang)
    $script:WorkerHandle = $script:WorkerPS.BeginInvoke()
}

# ---- DispatcherTimer: vuelca la cola del worker en la UI ----
$LogColors = @{
    head = '#FF00E5FF'; ok = '#FF5CFF8F'; err = '#FFFF6B6B'
    warn = '#FFFFD166'; info = '#FFC9C9D4'; dim = '#FF8A8A95'
}
$script:Timer = New-Object Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(200)
$script:Timer.Add_Tick({
    $msg = $null; $added = $false; $n = 0
    while ($n -lt 250 -and $script:Queue.TryDequeue([ref]$msg)) {
        $n++
        $tb = New-Object Windows.Controls.TextBlock
        $tb.Text = $msg.M
        $color = $LogColors[$msg.T]; if (-not $color) { $color = '#FFC9C9D4' }
        $tb.Foreground = Get-ThemeBrush($color)
        if ($msg.T -eq 'head') { $tb.FontWeight = 'Bold' }
        [void]$script:LogList.Items.Add($tb)
        $added = $true
    }
    while ($script:LogList.Items.Count -gt 1500) { $script:LogList.Items.RemoveAt(0) }
    if ($added) { $script:LogList.ScrollIntoView($script:LogList.Items[$script:LogList.Items.Count - 1]) }

    $S = $script:State
    if ($S.Total -gt 0) {
        # T2: barra con % real de la app en curso. Si CurPercent es 0 (no se
        # pudo parsear, o modo paralelo), la barra avanza por apps/total como antes.
        $prog = 100 * $S.Done / [math]::Max(1, $S.Total)
        $cp = [double]$S.CurPercent
        if ($S.Running -and $cp -gt 0 -and $cp -le 100 -and $S.Done -lt $S.Total) {
            $prog = 100 * ($S.Done + ($cp / 100)) / $S.Total
        }
        $script:Prog.Value = [math]::Min(100, $prog)
        $cur = [string]$S.CurName
        $base = ('{0}/{1}  ·  OK: {2}  ·  Fallos: {3}' -f $S.Done, $S.Total, $S.Ok, $S.Fail)
        if ($cur -and $S.Running) {
            if ($cp -gt 0 -and $cp -lt 100) { $base += ('  ·  {0}  ({1}%)' -f $cur, [int]$cp) }
            else { $base += ('  ·  {0}' -f $cur) }
        }
        $script:StatusText.Text = $base
    }
    if (-not $S.Running -and $script:WorkerPS) {
        try { $script:WorkerPS.EndInvoke($script:WorkerHandle) } catch {}
        try { $script:WorkerPS.Dispose(); $script:WorkerRS.Close(); $script:WorkerRS.Dispose() } catch {}
        $script:WorkerPS = $null; $script:WorkerHandle = $null; $script:WorkerRS = $null
        $script:Prog.Value = 100
        $script:StatusText.Text = ((Tr 'TERMINADO  ·  OK: {0}  ·  Fallos: {1}') -f $S.Ok, $S.Fail)
        Set-Busy $false

        $relaunchScan = $false
        if ($script:LastMode -eq 'detect') {
            Mark-Installed @($S.DetectList)
        } elseif ($script:LastMode -eq 'scanupgrades') {
            Build-Upgrades
            try { Translate-Tree $script:UpgradesScroll; Apply-WpiToolTips $script:UpgradesScroll } catch {}
            $i = $script:SideMap.IndexOf('@UPGRADES')
            if ($i -ge 0) { $script:SideList.SelectedIndex = $i }
        } elseif ($script:LastMode -eq 'search') {
            Build-Search
            try { Translate-Tree $script:WingetSearchScroll; Apply-WpiToolTips $script:WingetSearchScroll } catch {}
        } elseif ($script:LastMode -eq 'debloat') {
            try { Detect-DebloatStates } catch {}
        } elseif ($script:LastMode -eq 'tweaks') {
            try { Detect-TweakStates } catch {}
        } elseif ($script:LastMode -in @('install','uninstall','upgradeids','download')) {
            $modoPrev = $script:LastMode
            $verbo = if ($modoPrev -eq 'install') { 'Instalacion' } elseif ($modoPrev -eq 'upgradeids') { 'Actualizacion' } elseif ($modoPrev -eq 'download') { 'Descarga' } else { 'Desinstalacion' }
            $txt = ("{0} terminada.`n`nCorrectas:  {1}`nFallidas:    {2}`nProcesadas: {3} de {4}" -f $verbo, $S.Ok, $S.Fail, $S.Done, $S.Total)
            if ($S.Reboot -gt 0) {
                $txt += ("`n`nNOTA: {0} aplicacion(es) requieren REINICIAR el equipo para terminar de aplicarse." -f $S.Reboot)
            }
            if ($S.Fail -gt 0) {
                $txt += "`n`nFallos (detalle completo en el log forense):`n - " + ((@($S.FailList) | Select-Object -First 12) -join "`n - ")
            }
            # P2/P4: avisos de verificacion (winget dijo OK pero la version no cambio)
            $verifyN = @($S.VerifyWarn).Count
            if ($verifyN -gt 0) {
                $txt += "`n`n" + (Tr 'VERIFICACION POST-ACTUALIZACION: estas NO se actualizaron de verdad (winget informo exito, pero la version instalada no cambio):') + "`n - " + ((@($S.VerifyWarn) | Select-Object -First 12) -join "`n - ")
                $txt += "`n`n" + (Tr 'Cierra esas apps si estan abiertas, reinicia el equipo, o puede que se auto-actualicen por su cuenta. Vuelve a pulsar Buscar updates para reconfirmar.')
            }
            $icon = if ($S.Fail -gt 0 -or $verifyN -gt 0) { 'Warning' } else { 'Information' }
            # Aviso si alguna app procesada tiene mini-guia en espanol
            $conGuia = @()
            if ($modoPrev -in @('install','download')) {
                foreach ($bid in $script:LastBatchIds) {
                    if ($Guides.Contains([string]$bid)) { $conGuia += $Guides[[string]$bid].Title }
                }
            }
            $jumpGuide = $false
            if ($conGuia.Count -gt 0) {
                $txt += ("`n`nTUTORIAL: estas tienen mini-guia en espanol:`n - {0}`n`nMiralas en el panel 'Guias en espanol'." -f (($conGuia | Select-Object -Unique) -join "`n - "))
                $rg = Show-WpiMessage($txt + "`n`nVer las guias ahora?", 'WPI Moderno', 'YesNo', $icon)
                if ($rg -eq 'Yes') { $jumpGuide = $true }
            } else {
                Show-WpiMessage($txt, 'WPI Moderno', 'OK', $icon) | Out-Null
            }
            if ($modoPrev -eq 'install') {
                foreach ($cb in $script:Checks) {
                    $tag = [string]$cb.Tag
                    if (($script:LastBatchIds -contains $tag) -and -not (@($S.FailList) -like ($tag + ' - *'))) {
                        Mark-One $cb
                        $cb.IsChecked = $false
                    }
                }
                try { Update-Count } catch {}
            }
            # Tras actualizar solo unas pocas, refresca la lista (lo aplicado ya no debe salir)
            if ($modoPrev -eq 'upgradeids' -and $S.Fail -lt $S.Total) { $relaunchScan = $true }
            # Tras descargar, abre la carpeta para que veas los instaladores
            if ($modoPrev -eq 'download' -and $S.Ok -gt 0 -and $script:LastDownloadDir) {
                try { if (Test-Path $script:LastDownloadDir) { Start-Process explorer.exe $script:LastDownloadDir } } catch {}
            }
            if ($jumpGuide) {
                $gi = $script:SideMap.IndexOf('@GUIDES')
                if ($gi -ge 0) { $script:SideList.SelectedIndex = $gi }
                foreach ($bid in $script:LastBatchIds) {
                    if ($script:GuideExpanders.ContainsKey([string]$bid)) { $script:GuideExpanders[[string]$bid].IsExpanded = $true }
                }
            }
        }
        $script:LastMode = ''
        if ($relaunchScan) { Start-Worker -Mode 'scanupgrades' }
    }
})
$script:Timer.Start()

# ------------------------- EVENTOS --------------------------
# Sube por el arbol visual hasta encontrar un ancestro del tipo dado (o $null).
# Mas robusto que encadenar .Parent.Parent.Parent (que se rompe en silencio si
# se anade un contenedor intermedio).
function Get-WpiAncestor($el, [type]$t) {
    while ($el -and -not ($el -is $t)) {
        try { $el = [Windows.Media.VisualTreeHelper]::GetParent($el) } catch { return $null }
    }
    return $el
}
$window.FindName('BtnAll').Add_Click({
    foreach ($c in $script:Checks) {
        if ($c.Visibility -ne 'Visible') { continue }
        # Solo marcar las visibles cuya categoria (Expander) este visible. Si no
        # encontramos Expander ancestro, basta con que el propio check sea visible.
        $exp = Get-WpiAncestor $c ([Windows.Controls.Expander])
        if (-not $exp -or $exp.Visibility -eq 'Visible') { $c.IsChecked = $true }
    }
    Update-Count
})
$window.FindName('BtnNone').Add_Click({
    foreach ($c in $script:Checks) { $c.IsChecked = $false }
    Update-Count
})
$window.FindName('BtnClearSel').Add_Click({
    foreach ($c in $script:Checks) { $c.IsChecked = $false }
    Update-Count
})

function Add-PresetSelection([string]$name) {
    $ids = $QuickPresets[$name]
    foreach ($c in $script:Checks) { if ($ids -contains $c.Tag) { $c.IsChecked = $true } }
    Update-Count
}
$window.FindName('BtnPresetGaming').Add_Click({ Add-PresetSelection 'Gaming' })
$window.FindName('BtnPresetDev').Add_Click({    Add-PresetSelection 'Desarrollador' })
$window.FindName('BtnPresetMedia').Add_Click({  Add-PresetSelection 'Multimedia' })
$window.FindName('BtnPresetClean').Add_Click({  Add-PresetSelection 'Esencial' })
$window.FindName('BtnPresetLast').Add_Click({
    if ($script:LastSelection.Count -eq 0) {
        Show-WpiMessage('Aun no hay ninguna sesion guardada. Se guarda automaticamente cada vez que pulsas INSTALAR.', 'WPI Moderno') | Out-Null
        return
    }
    foreach ($c in $script:Checks) { if ($script:LastSelection -contains [string]$c.Tag) { $c.IsChecked = $true } }
    Update-Count
})

$window.FindName('BtnSave').Add_Click({
    $sel = @($script:Checks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    if ($sel.Count -eq 0) {
        Show-WpiMessage('No has marcado ninguna aplicacion que guardar.', 'WPI Moderno') | Out-Null
        return
    }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.FileName = 'wpi_preset.txt'
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Preset WPI (*.txt)|*.txt|winget import (*.json)|*.json'
    if ($dlg.ShowDialog()) {
        if ([IO.Path]::GetExtension($dlg.FileName) -ieq '.json') {
            # Formato oficial de "winget import": portable a cualquier PC con winget
            $doc = [pscustomobject]@{
                '$schema'    = 'https://aka.ms/winget-packages.schema.2.0.json'
                CreationDate = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fff-00:00')
                Sources      = @([pscustomobject]@{
                    SourceDetails = [pscustomobject]@{
                        Name = 'winget'; Identifier = 'Microsoft.Winget.Source_8wekyb3d8bbwe'
                        Argument = 'https://cdn.winget.microsoft.com/cache'; Type = 'Microsoft.PreIndexed.Package'
                    }
                    Packages = @($sel | ForEach-Object { [pscustomobject]@{ PackageIdentifier = $_ } })
                })
            }
            Set-WpiContent -Path $dlg.FileName -Value ($doc | ConvertTo-Json -Depth 6)
            Show-WpiMessage(((Tr "Exportadas {0} apps en formato winget.`nUso en cualquier PC:`nwinget import -i `"{1}`"") -f $sel.Count, $dlg.FileName), 'WPI Moderno') | Out-Null
        } else {
            Set-WpiContent -Path $dlg.FileName -Value $sel
            Show-WpiMessage(((Tr "Preset guardado: {0} apps.`nUso desatendido:`nIniciar_WPI.bat -Preset `"{1}`"") -f $sel.Count, $dlg.FileName), 'WPI Moderno') | Out-Null
        }
    }
})
$window.FindName('BtnLoad').Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Preset WPI (*.txt)|*.txt'
    if ($dlg.ShowDialog()) {
        $ids = Get-Content $dlg.FileName | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }
        foreach ($c in $script:Checks) { $c.IsChecked = ($ids -contains $c.Tag) }
        Update-Count
    }
})

$window.FindName('BtnInstall').Add_Click({
    $ids = @($script:Checks | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    if ($ids.Count -eq 0) {
        Show-WpiMessage('No has marcado ninguna aplicacion.', 'WPI Moderno') | Out-Null
        return
    }
    $script:LastSelection = @($ids | ForEach-Object { [string]$_ })
    Save-Settings
    Start-Worker -Mode 'install' -Ids $ids
})
$window.FindName('BtnDetect').Add_Click({
    Start-Worker -Mode 'detect' -Ids @($catalog | ForEach-Object { $_.Id })
})

# Selector de carpeta reutilizable (devuelve ruta o $null)
function Select-DownloadFolder {
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = 'Elige donde guardar los instaladores descargados'
    try { $fb.UseDescriptionForTitle = $true } catch {}
    try { $fb.SelectedPath = $Config.DownloadDir } catch {}
    if ($fb.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $fb.SelectedPath }
    return $null
}
# Decide carpeta destino: por defecto <raiz WPI>\Descargas, con opcion
# a elegir otra. Crea la carpeta. Devuelve la ruta o $null si se cancela.
function Get-DownloadTarget {
    $def = $Config.DownloadDir
    $r = Show-WpiMessage(
        ((Tr "Los instaladores se guardaran en:`n{0}`n(cada app en su subcarpeta)`n`nSi   = usar esa carpeta`nNo   = elegir otra carpeta`nCancelar = no descargar") -f $def),
        'Carpeta de descarga', 'YesNoCancel', 'Question')
    if ($r -eq 'Cancel') { return $null }
    $folder = $def
    if ($r -eq 'No') {
        $picked = Select-DownloadFolder
        if (-not $picked) { return $null }
        $folder = $picked
    }
    try {
        if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    } catch {
        Show-WpiMessage(((Tr "No se pudo crear la carpeta:`n{0}") -f $folder), 'WPI Moderno', 'OK', 'Error') | Out-Null
        return $null
    }
    $script:LastDownloadDir = $folder
    return $folder
}
$window.FindName('BtnDownload').Add_Click({
    $ids = @($script:Checks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    if ($ids.Count -eq 0) {
        Show-WpiMessage('Marca primero las apps cuyo instalador quieres descargar (sin instalarlas).', 'WPI Moderno') | Out-Null
        return
    }
    $folder = Get-DownloadTarget
    if (-not $folder) { return }
    Start-Worker -Mode 'download' -Ids $ids -Query $folder
})
$window.FindName('BtnUninstall').Add_Click({
    $ids = @($script:Checks | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    if ($ids.Count -eq 0) {
        Show-WpiMessage('No has marcado ninguna aplicacion que desinstalar.', 'WPI Moderno') | Out-Null
        return
    }
    $r = Show-WpiMessage(
        ((Tr "Vas a DESINSTALAR {0} aplicaciones de este equipo:`n`n - {1}`n`nEsta accion no se puede deshacer desde aqui. Continuar?") -f $ids.Count, (($ids | Select-Object -First 15) -join "`n - ")),
        'Desinstalacion masiva', 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Start-Worker -Mode 'uninstall' -Ids $ids }
})
$window.FindName('BtnUpgrade').Add_Click({
    $r = Show-WpiMessage(
        ("Esto ejecutara 'winget upgrade --all': actualiza DE GOLPE todos los programas de tu equipo que winget reconozca (los instalaras como los instalaras), no solo los del catalogo." + "`n`nSi prefieres elegir uno a uno, cancela y usa 'Buscar updates'." + "`n`nContinuar con la actualizacion completa?"),
        'Actualizar TODO el equipo', 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Start-Worker -Mode 'upgrade' }
})
$window.FindName('BtnList').Add_Click({ Start-Worker -Mode 'scanupgrades' })

function Confirm-UpgradeSelection($checks, $titulo, $intro) {
    $ids = @($checks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    if ($ids.Count -eq 0) {
        Show-WpiMessage('No has marcado ninguna actualizacion en este grupo.', 'WPI Moderno') | Out-Null
        return
    }
    $r = Show-WpiMessage(
        ((Tr "{0}`n`n - {1}`n`nEl resto se queda EXACTAMENTE como esta. Continuar?") -f $intro, (($ids | Select-Object -First 18) -join "`n - ")),
        $titulo, 'YesNo', 'Question')
    if ($r -eq 'Yes') { Start-Worker -Mode 'upgradeids' -Ids $ids }
}
$script:BtnUpgWpi.Add_Click({
    Confirm-UpgradeSelection $script:UpgChecksWpi 'Actualizar apps del catalogo WPI' `
        ('Se actualizaran SOLO estas apps del catalogo WPI. No se tocara ningun otro programa de tu PC:')
})
$script:BtnUpgOther.Add_Click({
    Confirm-UpgradeSelection $script:UpgChecksOther 'Actualizar otros programas de tu PC' `
        ('Se actualizaran SOLO estos programas tuyos (fuera del catalogo WPI). Nada del catalogo se tocara:')
})

# Buscador de winget en vivo
$doWgSearch = {
    $q = $script:WgSearchBox.Text.Trim()
    if ($q.Length -lt 2) {
        Show-WpiMessage('Escribe al menos 2 caracteres para buscar.', 'WPI Moderno') | Out-Null
        return
    }
    Start-Worker -Mode 'search' -Query $q
}
$script:BtnWgSearch.Add_Click($doWgSearch)
$script:WgSearchBox.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq 'Return') { & $doWgSearch }
})
$script:BtnWgInstall.Add_Click({
    $ids = @($script:SearchChecks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    if ($ids.Count -eq 0) {
        Show-WpiMessage('No has marcado ningun resultado.', 'WPI Moderno') | Out-Null
        return
    }
    $r = Show-WpiMessage(
        ((Tr "Se instalaran estos {0} programas desde winget:`n`n - {1}`n`nContinuar?") -f $ids.Count, (($ids | Select-Object -First 18) -join "`n - ")),
        'Instalar desde winget', 'YesNo', 'Question')
    if ($r -eq 'Yes') { Start-Worker -Mode 'install' -Ids $ids }
})
$script:BtnWgDownload.Add_Click({
    $ids = @($script:SearchChecks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    if ($ids.Count -eq 0) {
        Show-WpiMessage('No has marcado ningun resultado.', 'WPI Moderno') | Out-Null
        return
    }
    $folder = Get-DownloadTarget
    if (-not $folder) { return }
    Start-Worker -Mode 'download' -Ids $ids -Query $folder
})
$script:BtnDebloat.Add_Click({
    $sel = @($script:DebloatChecks | Where-Object { $_.IsChecked })
    if ($sel.Count -eq 0) { Show-WpiMessage('No has marcado ninguna app para quitar.', 'WPI Moderno') | Out-Null; return }
    $items = @()
    foreach ($cb in $sel) { $items += @{ Name = [string]$cb.Content; Pkg = [string]$cb.Tag } }
    $r = Show-WpiMessage(
        ((Tr "Se quitaran estas {0} apps preinstaladas:`n`n - {1}`n`nSon reinstalables desde la Store. Continuar?") -f $items.Count, (($items.Name | Select-Object -First 18) -join "`n - ")),
        'Quitar bloatware', 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Start-Worker -Mode 'debloat' -Tweaks $items }
})
$script:BtnSnapExport.Add_Click({
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.FileName = ('mi_equipo_{0}.json' -f (Get-Date -Format 'yyyyMMdd'))
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'winget import (*.json)|*.json'
    if ($dlg.ShowDialog()) { Start-Worker -Mode 'snapexport' -Query $dlg.FileName }
})
$script:BtnSnapImport.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'winget import (*.json)|*.json|Todos (*.*)|*.*'
    if ($dlg.ShowDialog()) {
        $r = Show-WpiMessage(
            ((Tr "Se instalara TODO lo que falte segun el archivo:`n{0}`n`nPuede tardar bastante. Continuar?") -f $dlg.FileName),
            'Importar equipo', 'YesNo', 'Question')
        if ($r -eq 'Yes') { Start-Worker -Mode 'snapimport' -Query $dlg.FileName }
    }
})
$script:BtnCatTemplate.Add_Click({
    if (Test-Path $CatalogFile) {
        $r = Show-WpiMessage(((Tr 'Ya existe {0}. Sobrescribir con el catalogo interno actual?') -f (Split-Path $CatalogFile -Leaf)), 'WPI Moderno', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    if (Export-CatalogTemplate) {
        Show-WpiMessage(((Tr "Creado:`n{0}`n`nEditalo (anade/quita lineas) y pulsa 'Recargar catalogo.json'.") -f $CatalogFile), 'WPI Moderno') | Out-Null
        Start-Process notepad.exe $CatalogFile
    } else {
        Show-WpiMessage('No se pudo crear el archivo.', 'WPI Moderno') | Out-Null
    }
})
$script:BtnCatReload.Add_Click({
    if (-not (Test-Path $CatalogFile)) {
        Show-WpiMessage(((Tr 'No hay {0}. Crea primero la plantilla.') -f (Split-Path $CatalogFile -Leaf)), 'WPI Moderno') | Out-Null
        return
    }
    $r = Show-WpiMessage('Para cargar el catalogo nuevo hay que reiniciar la app. Reiniciar ahora?', 'WPI Moderno', 'YesNo', 'Question')
    if ($r -eq 'Yes') {
        try { Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) } catch {}
        $script:Skip_Closing_Save = $true
        $window.Close()
    }
})
$script:BtnCatRemote.Add_Click({
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    $url = ''
    try { $url = [Microsoft.VisualBasic.Interaction]::InputBox('Pega la URL (https) de un catalogo JSON con formato [ {"Cat":"..","Name":"..","Id":".."}, ... ]:', 'Catalogo remoto', 'https://') } catch { return }
    if (-not $url -or $url -eq 'https://') { return }
    if ($url -notmatch '^https://') { Show-WpiMessage('Por seguridad solo se permiten URLs https://.', 'Catalogo remoto') | Out-Null; return }
    $raw = $null
    try { $raw = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20).Content } catch {
        Show-WpiMessage(((Tr 'No se pudo descargar el catalogo: {0}') -f $_.Exception.Message), 'Catalogo remoto') | Out-Null; return
    }
    $data = $null
    try { $data = $raw | ConvertFrom-Json } catch {
        Show-WpiMessage('El contenido descargado no es JSON valido.', 'Catalogo remoto') | Out-Null; return
    }
    $valid = @($data | Where-Object { $_.Id -and $_.Name -and $_.Cat })
    if (@($valid).Count -eq 0) {
        Show-WpiMessage('El JSON no tiene entradas validas con Cat/Name/Id.', 'Catalogo remoto') | Out-Null; return
    }
    $r = Show-WpiMessage(((Tr 'Catalogo remoto valido: {0} apps. Se guardara como catalogo.json (sustituye al interno) y se reiniciara la app para aplicarlo. Revisa luego los IDs con "Validar IDs". Continuar?') -f @($valid).Count), 'Catalogo remoto', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    try {
        Set-WpiContent -Path $CatalogFile -Value $raw
        try { Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) } catch {}
        $script:Skip_Closing_Save = $true
        $window.Close()
    } catch {
        Show-WpiMessage(((Tr 'No se pudo guardar el catalogo remoto: {0}') -f $_.Exception.Message), 'Catalogo remoto') | Out-Null
    }
})
$script:BtnHwScan.Add_Click({
    $script:StatusText.Text = (Tr 'Detectando hardware...')
    try { Build-HardwareUI; Translate-Tree $script:DriversScroll; Apply-WpiToolTips $script:DriversScroll; $script:StatusText.Text = (Tr 'Hardware detectado.') }
    catch { $script:StatusText.Text = (Tr 'No se pudo detectar parte del hardware.') }
})
$script:BtnGuidesTemplate.Add_Click({
    if (Test-Path $GuidesFile) {
        $r = Show-WpiMessage(((Tr 'Ya existe {0}. Sobrescribir con las guias actuales?') -f (Split-Path $GuidesFile -Leaf)), 'WPI Moderno', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    if (Export-GuidesTemplate) {
        Show-WpiMessage(((Tr "Creado:`n{0}`n`nEditalo (anade/cambia guias) y pulsa 'Recargar guias.json'.") -f $GuidesFile), 'WPI Moderno') | Out-Null
        try { Start-Process notepad.exe $GuidesFile } catch {}
    } else {
        Show-WpiMessage('No se pudo crear el archivo.', 'WPI Moderno') | Out-Null
    }
})
$script:BtnGuidesReload.Add_Click({
    if (-not (Test-Path $GuidesFile)) {
        Show-WpiMessage(((Tr 'No hay {0}. Crea primero la plantilla.') -f (Split-Path $GuidesFile -Leaf)), 'WPI Moderno') | Out-Null
        return
    }
    $r = Show-WpiMessage('Para cargar las guias nuevas hay que reiniciar la app. Reiniciar ahora?', 'WPI Moderno', 'YesNo', 'Question')
    if ($r -eq 'Yes') {
        try { Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) } catch {}
        $script:Skip_Closing_Save = $true
        $window.Close()
    }
})
$script:BtnHwCopy.Add_Click({
    if (-not $script:HwReportText) { try { Build-HardwareUI } catch {} }
    if ($script:HwReportText) {
        $ok = $false
        try { Set-Clipboard -Value $script:HwReportText; $ok = $true } catch {}
        if (-not $ok) { try { [System.Windows.Clipboard]::SetText($script:HwReportText); $ok = $true } catch {} }
        $script:StatusText.Text = if ($ok) { 'Informe de hardware copiado al portapapeles.' } else { 'No se pudo copiar.' }
    }
})
$script:BtnHwExport.Add_Click({
    if (-not $script:HwReportText) { try { Build-HardwareUI } catch {} }
    if (-not $script:HwReportText) { $script:StatusText.Text = (Tr 'Primero pulsa "Detectar mi hardware".'); return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.FileName = ('hardware_{0}.txt' -f (Get-Date -Format 'yyyyMMdd'))
    $dlg.InitialDirectory = $PSScriptRoot
    $dlg.Filter = 'Texto (*.txt)|*.txt|Markdown (*.md)|*.md'
    if ($dlg.ShowDialog()) {
        try {
            Set-WpiContent -Path $dlg.FileName -Value $script:HwReportText
            $script:StatusText.Text = ((Tr 'Informe de hardware guardado en {0}') -f $dlg.FileName)
        } catch {
            $script:StatusText.Text = (Tr 'No se pudo guardar el informe.')
        }
    }
})
$script:BtnWinUpd.Add_Click({
    try { Start-Process 'ms-settings:windowsupdate-optionalupdates' } catch {
        try { Start-Process 'ms-settings:windowsupdate' } catch {}
    }
})
$script:BtnMoboSupport.Add_Click({
    $q = if ($script:MoboQuery) { $script:MoboQuery } else { 'drivers placa base' }
    try { Start-Process ('https://www.google.com/search?q={0}' -f [Uri]::EscapeDataString($q)) } catch {}
})
$window.FindName('BtnValidate').Add_Click({
    $ids = @($script:Checks | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    if ($ids.Count -eq 0) {
        $r = Show-WpiMessage(
            ((Tr "No hay apps marcadas: se validara el catalogo COMPLETO ({0} IDs).`nPuede tardar varios minutos. Continuar?") -f @($catalog).Count),
            'Validar IDs', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
        $ids = @($catalog | ForEach-Object { $_.Id })
    }
    Start-Worker -Mode 'validate' -Ids $ids
})
$script:BtnTweaks.Add_Click({
    $sel = @($script:TweakChecks | Where-Object { $_.IsChecked } | ForEach-Object {
        [pscustomobject]@{ Name = $_.Tag.Name; Code = $_.Tag.Code }
    })
    if ($sel.Count -eq 0) {
        Show-WpiMessage('No has marcado ningun tweak.', 'WPI Moderno') | Out-Null
        return
    }
    $adv = @($script:TweakChecks | Where-Object { $_.IsChecked -and $_.Tag.Risk -eq 'Avanzado' })
    if ($adv.Count -gt 0) {
        $r = Show-WpiMessage(
            ((Tr "Has marcado {0} tweak(s) AVANZADOS (mayor impacto en el sistema). Casi todos se pueden revertir, pero asegurate. Continuar?") -f $adv.Count),
            'Tweaks avanzados', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    if ($script:ChkRestore.IsChecked) {
        $rp = [pscustomobject]@{ Name = 'Punto de restauracion previo'; Code = @'
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "WPI Moderno - antes de tweaks" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    W ok "Punto de restauracion creado."
} catch { W warn ("Punto de restauracion no creado: {0} (Windows limita 1 cada 24h)." -f $_.Exception.Message) }
'@ }
        $sel = @($rp) + $sel
    }
    Start-Worker -Mode 'tweaks' -Tweaks $sel
})
$script:BtnTweaksUndo.Add_Click({
    $sel = @($script:TweakChecks | Where-Object { $_.IsChecked -and $_.Tag.Undo } | ForEach-Object {
        [pscustomobject]@{ Name = ('Revertir: ' + $_.Tag.Name); Code = $_.Tag.Undo }
    })
    if ($sel.Count -eq 0) {
        Show-WpiMessage('No has marcado ningun ajuste reversible.', 'WPI Moderno') | Out-Null
        return
    }
    $r = Show-WpiMessage(
        ((Tr "Se revertiran {0} ajuste(s) a su valor por defecto de Windows. Continuar?") -f $sel.Count),
        'Revertir tweaks', 'YesNo', 'Question')
    if ($r -eq 'Yes') { Start-Worker -Mode 'tweaks' -Tweaks $sel }
})
$script:BtnTweakDetect.Add_Click({
    $script:StatusText.Text = (Tr 'Comprobando que ajustes ya estan aplicados...')
    try { Detect-TweakStates } catch { $script:StatusText.Text = (Tr 'No se pudo comprobar el estado de los tweaks.') }
})
$script:BtnTweakMissing.Add_Click({
    if (-not $script:TweakDetected) { try { Detect-TweakStates } catch {} }
    $n = 0
    foreach ($cb in $script:TweakChecks) {
        $name = [string]$cb.Tag.Name
        if ($cb.Tag.Risk -eq 'Seguro' -and $TweakDetectors.ContainsKey($name)) {
            $applied = $false
            try { $applied = [bool](Invoke-Expression $TweakDetectors[$name]) } catch {}
            if (-not $applied) { $cb.IsChecked = $true; $n++ }
        }
    }
    try { Update-Count } catch {}
    $script:StatusText.Text = ((Tr '{0} ajustes recomendados sin aplicar marcados. Revisa y pulsa APLICAR SELECCIONADOS.') -f $n)
})
$script:BtnTweakSave.Add_Click({ try { Save-TweakProfile } catch { $script:StatusText.Text = (Tr 'No se pudo guardar el perfil.') } })
$script:BtnTweakLoad.Add_Click({ try { Load-TweakProfile } catch { $script:StatusText.Text = (Tr 'No se pudo cargar el perfil.') } })
$script:BtnCancel.Add_Click({
    $script:State.Cancel = $true
    $script:BtnCancel.IsEnabled = $false
    $script:StatusText.Text = (Tr 'Cancelando (se respetan las instalaciones en curso)...')
})
$window.FindName('BtnOpenLog').Add_Click({
    if ($script:CurrentLog -and (Test-Path $script:CurrentLog)) {
        Start-Process notepad.exe $script:CurrentLog
    } else {
        if (Test-Path $Config.LogDir) { Start-Process explorer.exe $Config.LogDir }
    }
})
$window.FindName('BtnOpenLogs').Add_Click({
    if (-not (Test-Path $Config.LogDir)) { New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null }
    Start-Process explorer.exe $Config.LogDir
})

# ---- Informacion del sistema en el panel lateral ----
function Set-SysInfo {
    $parts = @()
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $parts += ('{0}  (build {1})' -f ($os.Caption -replace '^Microsoft ', ''), $os.BuildNumber)
    } catch { $parts += 'Windows (version desconocida)' }
    try {
        $wv = (& winget --version) 2>$null
        if ($wv) { $parts += ('winget {0}' -f ($wv | Select-Object -First 1)) }
        else     { $parts += 'winget: NO detectado' }
    } catch { $parts += 'winget: NO detectado' }
    try {
        $sys = $env:SystemDrive
        $d = Get-PSDrive ($sys.TrimEnd(':')) -ErrorAction Stop
        $freeGB = [math]::Round($d.Free / 1GB, 1)
        $parts += ((Tr 'Libre en {0} {1} GB') -f $sys, $freeGB)
    } catch {}
    $parts += ((Tr '{0} apps en catalogo  ·  {1} tweaks') -f @($catalog).Count, @($TweaksCatalog).Count)
    $window.FindName('SysInfo').Text = ($parts -join "`n")
}
Set-SysInfo

# Texto informativo del catalogo (origen interno/externo)
if (Test-Path $CatalogFile) {
    $script:SnapCatInfo.Text = ((Tr 'Usando catalogo EXTERNO: {0} ({1} apps). Editalo y recarga para aplicar cambios.') -f (Split-Path $CatalogFile -Leaf), @($catalog).Count)
} else {
    $script:SnapCatInfo.Text = ((Tr 'Ahora mismo usas el catalogo interno ({0} apps). Crea catalogo.json para personalizarlo sin tocar el codigo.') -f @($catalog).Count)
}
Update-DebloatCount

# Restaurar tamano/posicion de ventana guardados
try {
    if ($script:WinGeom -and $script:WinGeom.W -gt 400) {
        $window.Width  = [double]$script:WinGeom.W
        $window.Height = [double]$script:WinGeom.H
        if ($script:WinGeom.T -ge 0 -and $script:WinGeom.L -ge 0) {
            # Guard anti fuera-de-pantalla: recorta a la pantalla virtual actual
            $vx = [System.Windows.SystemParameters]::VirtualScreenLeft
            $vy = [System.Windows.SystemParameters]::VirtualScreenTop
            $vw = [System.Windows.SystemParameters]::VirtualScreenWidth
            $vh = [System.Windows.SystemParameters]::VirtualScreenHeight
            $top  = [double]$script:WinGeom.T
            $left = [double]$script:WinGeom.L
            $maxL = $vx + $vw - 120
            $maxT = $vy + $vh - 80
            if ($left -lt $vx) { $left = $vx }; if ($left -gt $maxL) { $left = $maxL }
            if ($top  -lt $vy) { $top  = $vy }; if ($top  -gt $maxT) { $top  = $maxT }
            $window.WindowStartupLocation = 'Manual'
            $window.Top  = $top
            $window.Left = $left
        }
    }
} catch {}

$window.Add_Closing({
    param($s, $e)
    if ($script:State.Running) {
        $r = Show-WpiMessage(
            'Hay un proceso en marcha. Si cierras ahora, las instalaciones en curso seguiran en segundo plano sin supervision. Cerrar igualmente?',
            'WPI Moderno', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $e.Cancel = $true; return }
        $script:State.Cancel = $true
    }
    if (-not $script:Skip_Closing_Save) { Save-Settings }
    $script:Timer.Stop()
    # Liberar el mutex de instancia unica (el SO lo reclama igual, pero es lo correcto).
    try { $script:SingleInstance.ReleaseMutex() } catch {}
})

# Deteccion automatica de apps ya instaladas nada mas abrir
$window.Add_ContentRendered({
    if ($Config.AutoDetectInstalled -and -not $script:State.Running) {
        Start-Worker -Mode 'detect' -Ids @($catalog | ForEach-Object { $_.Id })
    }
})

# C2: si el idioma es ingles, traduce toda la interfaz ya construida (chrome,
# barra inferior, panel inicial). Los paneles perezosos se traducen al abrirse.
try { Translate-Tree $window; Apply-WpiToolTips $window } catch {}
# Tras traducir: fija el contador "(0)" del boton de aplicar tweaks (usa Tr, no filtra)
try { Update-TweakCount } catch {}

if ($SelfTestGui) {
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($name in @(
        'SideList','AppsScroll','Lists','TweaksScroll','TweaksList','UpgradesScroll','UpgradesList',
        'DebloatScroll','DebloatList','DriversScroll','DriversList','WinUpdateScroll','WinUpdateList',
        'RepairScroll','RepairList','CreateIsoScroll','CreateIsoList','SummaryScroll','SummaryList',
        'QuickStartScroll','QuickStartList','LogList','Prog','StatusText','BtnInstall','BtnCancel','CboLang','CboTheme'
    )) {
        try { if (-not $window.FindName($name)) { $missing.Add($name) } } catch { $missing.Add($name) }
    }

    if ($missing.Count -gt 0) {
        Write-Host ('[FAIL] SelfTestGui: faltan controles: {0}' -f ($missing -join ', ')) -ForegroundColor Red
        exit 1
    }

    try { Build-RepairUI; Translate-Tree $script:RepairScroll; Apply-WpiToolTips $script:RepairScroll } catch { Write-Host ('[FAIL] SelfTestGui: Repair UI: {0}' -f $_.Exception.Message) -ForegroundColor Red; exit 1 }
    try { Build-CreateIsoUI; Translate-Tree $script:CreateIsoScroll; Apply-WpiToolTips $script:CreateIsoScroll } catch { Write-Host ('[FAIL] SelfTestGui: Create ISO UI: {0}' -f $_.Exception.Message) -ForegroundColor Red; exit 1 }

    Write-Host '[OK] SelfTestGui: ventana WPF, controles criticos y paneles Reparacion/Crear ISO construidos correctamente.' -ForegroundColor Green
    exit 0
}

if ($BuildIsoKit) {
    if (-not $IsoPath -or -not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
        Write-Host ('[FAIL] BuildIsoKit: no existe la ISO origen: {0}' -f $IsoPath) -ForegroundColor Red
        exit 1
    }
    if (-not $IsoOutDir) { $IsoOutDir = Get-WpiDir 'ISO' }
    try { if (-not (Test-Path -LiteralPath $IsoOutDir -PathType Container)) { New-Item -ItemType Directory -Path $IsoOutDir -Force | Out-Null } } catch {
        Write-Host ('[FAIL] BuildIsoKit: no se pudo crear la carpeta de salida: {0}' -f $_.Exception.Message) -ForegroundColor Red
        exit 1
    }

    Init-IsoWizard
    $script:Wiz.SrcIso = (Resolve-Path -LiteralPath $IsoPath).Path
    $script:Wiz.OutDir = (Resolve-Path -LiteralPath $IsoOutDir).Path
    $script:Wiz.IsoName = $IsoName
    $script:Wiz.WorkDir = Join-Path $script:Wiz.OutDir '_work'
    $script:Wiz.AppIds = @()
    $script:Wiz.AllEditions = $false
    $script:Wiz.Locale = 'es-ES'
    $script:Wiz.AccountName = 'Usuario'
    $script:Wiz.AccountPassword = ''

    $kit = New-IsoBuildKit
    if ($kit -and (Test-Path -LiteralPath (Join-Path $kit 'kit-config.json') -PathType Leaf)) {
        Write-Host ('[OK] BuildIsoKit: kit generado en {0}' -f $kit) -ForegroundColor Green
        exit 0
    }
    Write-Host '[FAIL] BuildIsoKit: no se genero el kit.' -ForegroundColor Red
    exit 1
}

# P4: aviso suave (no bloqueante) si los ajustes estaban corruptos y se restauraron.
if ($script:SettingsRestored) {
    try { $script:StatusText.Text = (Tr 'Los ajustes estaban danados y se han restaurado a los valores por defecto (copia en wpi_settings.json.corrupt.bak).') } catch {}
}

[void]$window.ShowDialog()
Write-Host ''
Write-Host ('[OK] WPI Moderno v{0} cerrado. Logs forenses en: {1}' -f $WpiVersion, $Config.LogDir) -ForegroundColor Green
