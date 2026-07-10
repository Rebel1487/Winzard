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
