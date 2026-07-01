<div align="center">

# 🪟 WPI Moderno

### El centro de mando todo-en-uno para post-instalación, mantenimiento y personalización de Windows 10/11

**Instala apps con winget · Optimiza y limpia Windows · Repara el sistema por fases · Crea tu propia ISO personalizada**

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](#requisitos)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](#requisitos)
[![winget](https://img.shields.io/badge/winget-App%20Installer-2D7D9A)](#-instalar-programas-con-winget)
[![Licencia](https://img.shields.io/badge/Licencia-MIT-green.svg)](LICENSE)
[![Idiomas](https://img.shields.io/badge/Idiomas-ES%20%7C%20EN-orange)](#-dos-idiomas-y-tres-temas)
[![PRs welcome](https://img.shields.io/badge/PRs-bienvenidos-brightgreen.svg)](CONTRIBUTING.md)

**🌐 Idiomas:** **Español (estás aquí)** · [English](README_EN.md)

</div>

<p align="center">
  <img src="docs/img/wpi-hero.png" alt="WPI Moderno — vista principal" width="860">
</p>

<p align="center">
  <b>🛒 +360 apps</b> &nbsp;·&nbsp; <b>⚙️ 40+ tweaks</b> &nbsp;·&nbsp; <b>🧹 Debloat</b> &nbsp;·&nbsp; <b>🩹 Reparación 17 fases</b> &nbsp;·&nbsp; <b>💿 ISO a medida</b> &nbsp;·&nbsp; <b>🌍 ES / EN</b>
</p>

---

> **TL;DR** — WPI Moderno es una sola aplicación con interfaz gráfica que te deja **montar tu Windows ideal** en minutos: instala cientos de programas legales con winget, aplica ajustes de privacidad y rendimiento, quita el bloatware, repara el sistema con una suite profesional de 17 fases y, lo más potente, **fabrica una ISO de Windows personalizada** con tus apps, tus tweaks y tu cuenta local ya configurados. Todo en español o inglés, con tres temas visuales.

---

## 📑 Tabla de contenidos

- [¿Qué es WPI Moderno?](#-qué-es-wpi-moderno)
- [¿Por qué usarlo?](#-por-qué-usarlo)
- [Requisitos](#requisitos)
- [Instalación y primer uso](#-instalación-y-primer-uso)
- [Recorrido por la interfaz (sección a sección)](#-recorrido-por-la-interfaz-sección-a-sección)
- [Instalar programas con winget](#-instalar-programas-con-winget)
- [Botones principales explicados](#-botones-principales-explicados)
- [El creador de ISO personalizada (la joya)](#-el-creador-de-iso-personalizada-la-joya)
- [La Suite de Reparación (17 fases)](#-la-suite-de-reparación-17-fases)
- [Dos idiomas y tres temas](#-dos-idiomas-y-tres-temas)
- [Verificación y seguridad](#-verificación-y-seguridad)
- [Inspiración y créditos](#-inspiración-y-créditos)
- [Contribuir](#-contribuir)
- [Licencia](#-licencia)

---

## 🎯 ¿Qué es WPI Moderno?

**WPI** significa *Windows Post-Installer*: una herramienta para hacer todo lo que normalmente harías "a mano" después de instalar Windows, pero de forma **rápida, ordenada y reproducible**.

Imagina que acabas de formatear tu PC. Normalmente tendrías que:

- Buscar e instalar tus 30 programas favoritos uno a uno.
- Tocar decenas de ajustes de privacidad y rendimiento en menús escondidos.
- Desinstalar el bloatware que viene de fábrica.
- Cruzar los dedos para que Windows no se rompa.

WPI Moderno hace **todo eso desde una sola ventana**, y va mucho más allá: puede **reparar** un Windows dañado y puede **crear una ISO de instalación a tu medida** para que el próximo formateo ya venga con todo hecho.

Está construido en **PowerShell + WPF** (la interfaz gráfica nativa de Windows), no necesita instalación: se ejecuta directamente.

---

## 💡 ¿Por qué usarlo?

| | |
|---|---|
| 🛒 **+360 programas** | Catálogo curado y organizado en **22 categorías**, instalables con un clic vía winget. |
| 🔍 **Detección inteligente** | Sabe qué tienes ya instalado, **qué versión** tienes y **cuál es la última disponible**. |
| ⚙️ **40+ tweaks** | Privacidad, rendimiento, explorador, telemetría... explicados y, cuando se puede, **reversibles**. |
| 🧹 **Debloat transparente** | Quita apps preinstaladas y componentes promocionales, dejando registro de todo. |
| 🛠️ **Suite de reparación de 17 fases** | Bilingüe, autónoma, con filosofía *anti falsos OK*. |
| 💿 **Creador de ISO personalizada** | Tu Windows ideal en un `.iso` listo para grabar en un USB. |
| 🌍 **Bilingüe (ES/EN) + 3 temas** | Español o inglés, con tema Claro, Oscuro o Azul. |
| ✅ **100% legal y transparente** | Nada de pirateo: todo viene de **winget** y de fuentes oficiales. Acciones con logs. |

---

## Requisitos

- **Windows 10 o 11** (x64).
- **PowerShell 5.1 o superior** (viene de serie en Windows).
- **winget / App Installer** (incluido en Windows moderno; si falta, WPI te avisa).
- **Permisos de administrador** para las operaciones de sistema (Windows pedirá elevación UAC).
- *(Opcional)* **Windows ADK / oscdimg** únicamente si vas a **crear una ISO personalizada**.

---

## 🚀 Instalación y primer uso

WPI Moderno es *portable*: **no se instala**, se ejecuta.

```text
1. Descarga el ZIP del último release.
2. Extrae el contenido en una carpeta local — por ejemplo  C:\WPI
3. Ejecuta  Iniciar_WPI.bat
4. Acepta la elevación de permisos (UAC) cuando Windows la pida.
5. Elige idioma y tema, y empieza por la sección que necesites.
```

> 💡 **Consejo:** extrae la carpeta en una ruta **sin tildes ni espacios raros** (`C:\WPI` es ideal). El creador de ISO trabaja mejor así.

El lanzador `Iniciar_WPI.bat` se encarga de configurar la codificación UTF-8, pedir permisos de administrador y abrir la interfaz gráfica.

---

## 🧭 Recorrido por la interfaz (sección a sección)

Al abrir WPI verás un **menú lateral** con todas las áreas. Esto es lo que hace cada una:

### 🏠 Inicio rápido (modo fácil)
Pantalla de bienvenida pensada para quien quiere ir al grano: accesos directos a las acciones más comunes sin perderse entre opciones avanzadas.

### 🔎 Buscar en todo (global)
Un buscador transversal que filtra por **toda** la aplicación: apps, tweaks, secciones... Escribe lo que buscas y ve directo.

### 📦 Todas las apps
El corazón del catálogo: **+360 programas** organizados por categoría. Marca los que quieras, pulsa **INSTALAR** y winget hace el resto. Aquí están los **presets de un clic** (Gaming, Desarrollador, Multimedia, Esencial, Última sesión).

### 🌐 Buscar en winget (todo)
¿No está en el catálogo curado? Busca **cualquier paquete** del repositorio oficial de winget y márcalo para instalar. El universo entero de winget a tu alcance.

### 🧬 Clonar equipo / Snapshot
Exporta **todo lo que tienes instalado** a un archivo y reinstálalo en otro PC. Ideal para clonar tu entorno o migrar a una máquina nueva.

### 🔄 Actualizaciones disponibles
Centraliza `winget upgrade`. Ve **qué programas tienen actualización** (versión actual → versión disponible) y actualízalos desde la propia interfaz, en bloque o uno a uno.

### ⚙️ Tweaks y ajustes
Más de **40 ajustes** de privacidad, rendimiento, explorador, barra de tareas, telemetría y energía. Cada tweak indica su estado (aplicado / no aplicado / recomendado / avanzado) y, cuando procede, se puede **revertir**. Opción de crear **punto de restauración** antes de aplicar.

### 🪟 Windows Update
Gestión de actualizaciones del sistema desde un panel claro.

### 🧹 Quitar bloatware (Appx)
Elimina aplicaciones preinstaladas (Xbox, Copilot, apps promocionales...) tanto para el usuario actual como de la imagen del sistema. Detecta qué sigue instalado y marca en colores el estado.

### 🩹 Reparación
Acceso a reparaciones rápidas, a los **paneles clásicos de Windows** (Panel de control, Servicios, Administrador de dispositivos, gpedit...) y, sobre todo, a la **Suite de Reparación de 17 fases** ([ver abajo](#-la-suite-de-reparación-17-fases)).

### 🧩 Características de Windows
Activa o desactiva componentes opcionales de Windows (Hyper-V, WSL2, .NET, etc.) con su estado real detectado en vivo.

### 🖥️ Drivers y hardware
Detecta y muestra las specs de tu PC (GPU, CPU, RAM, discos, placa base, BIOS, batería, sensores) y permite **exportar/respaldar drivers** para reinstalarlos tras un formateo.

### 💿 Crear ISO de Windows (avanzado)
El asistente que fabrica tu **ISO personalizada** ([la joya, explicada abajo](#-el-creador-de-iso-personalizada-la-joya)).

### 📊 Resumen del sistema
Vista panorámica: tema actual, apps del catálogo, tweaks aplicados, bloatware presente, disco, RAM, punto de restauración, estado de winget...

### 📚 Guías
Mini-tutoriales integrados (por ejemplo, cómo configurar emuladores) que se muestran en el idioma activo.

### 📋 Visor de logs
Todo lo que hace WPI queda registrado. Aquí puedes revisar los logs forenses de cada sesión.

---

## 🛒 Instalar programas con winget

WPI **no aloja ni distribuye software**. Usa **winget** (el gestor de paquetes oficial de Microsoft) para instalar cada programa desde su **fuente oficial**. Esto significa:

- ✅ **100% legal**: nada de cracks ni repositorios turbios.
- ✅ **Siempre actualizado**: winget instala la última versión publicada por el desarrollador.
- ✅ **Seguro y auditable**: cada acción queda en el log.

### Detección automática inteligente

Una de las funciones estrella: WPI **mira tu PC y entiende qué tienes**.

```text
┌─ Para cada app del catálogo, WPI sabe:
│
├─ 🟢 ¿La tienes instalada?        → la marca automáticamente
├─ 🔢 ¿Qué versión tienes?         → la versión actual en tu equipo
├─ ⬆️  ¿Hay una versión más nueva?  → la última disponible en winget
└─ 🔁 ¿Quieres actualizar?         → un clic y listo
```

Así nunca instalas algo dos veces, y mantener todo al día es trivial.

### Catálogo organizado por categorías

Más de **360 programas** clasificados para que encuentres lo que buscas al instante:

| Categoría | Ejemplos de lo que encontrarás |
|---|---|
| 💻 **Desarrollo** (80) | Editores, IDEs, lenguajes, control de versiones, contenedores |
| 🔧 **Utilidades** (52) | Compresores, gestores, herramientas del día a día |
| 🎬 **Multimedia** (39) | Reproductores, edición de vídeo/audio/imagen |
| 🎮 **Gaming** (30) | Launchers, herramientas para jugar |
| 🕹️ **Emuladores** (18) | Retro y consolas modernas |
| 🌐 **Red y Remoto** (21) | VPN, acceso remoto, herramientas de red |
| 💬 **Comunicación** (19) | Mensajería, videollamadas |
| 🧱 **Sistema** (15) | Herramientas de sistema |
| 📈 **Productividad** (15) | Notas, gestión, organización |
| 🧭 **Navegadores** (14) | Los navegadores más populares |
| 🎨 **Interfaz** (12) | Personalización del escritorio |
| 💾 **Discos y Backup** (12) | Particiones, copias de seguridad |
| 🔒 **Seguridad** (11) | Antimalware, cifrado |
| 🕵️ **Privacidad** (11) | Herramientas de privacidad |
| 📄 **Oficina** (10) | Suites ofimáticas, PDF |
| ⚡ **Runtimes** (8) | .NET, Visual C++, Java… |
| 🏠 **SelfHosted** (7) | Servicios para auto-alojar |
| 📊 **Monitorización** (6) | Temperaturas, rendimiento |
| ⭐ **Imprescindibles** (6) | Lo básico para cualquier PC |
| 🚀 **Rendimiento** (4) | Optimización |
| ☁️ **Nube y Sync** (4) | Almacenamiento y sincronización |
| 🤖 **IA Local** (2) | Modelos de IA en tu equipo |

### Presets de un clic

¿Prisa? Pulsa un preset y WPI marca por ti el pack completo:

- 🎮 **Gaming** — lo recomendado para jugar.
- 👨‍💻 **Desarrollador** — herramientas de desarrollo.
- 🎬 **Multimedia** — edición de vídeo, audio e imagen.
- ⭐ **Esencial** — lo básico para cualquier PC.
- 🕘 **Última sesión** — recupera tu última selección.

---

## 🎛️ Botones principales explicados

En la sección de apps tienes una barra de acciones. Esto hace cada botón:

| Botón | Qué hace |
|---|---|
| **INSTALAR** | Instala con winget todas las apps marcadas (puedes marcar varias a la vez). |
| **Actualizar TODO** | Lanza `winget upgrade --all`: pone al día *todos* los programas que winget reconozca. |
| **Validar IDs** | Comprueba que los IDs de winget de las apps seleccionadas son válidos y existen. |
| **Buscar updates** | Busca actualizaciones disponibles para lo que ya tienes instalado. |
| **Desinstalar** | Desinstala del sistema las apps marcadas *(acción irreversible)*. |
| **Descargar .exe/.msi** | Descarga el instalador directamente, sin pasar por winget. |
| **Marcar visibles / Desmarcar** | Selecciona o limpia todo lo que se ve en la lista. |
| **Detectar instaladas** | Escanea tu PC y marca lo que ya tienes del catálogo. |
| **Guardar / Cargar perfil** | Guarda tu selección en un perfil para reutilizarla en otro equipo. |
| **Hilos** | Nº de instalaciones en paralelo (más rápido, más carga). |
| **Ámbito** | Instala para todos los usuarios o solo el tuyo. |
| **Fallback Choco** | Si winget falla con una app, intenta con Chocolatey. |

> 💬 **Tooltips por todas partes:** pasa el cursor sobre cualquier botón, casilla o control y WPI te explica qué hace, en tu idioma. No hace falta memorizar nada.

---

## 💿 El creador de ISO personalizada (la joya)

Esta es la función que eleva a WPI por encima de un simple instalador de apps. **¿Y si tu próxima instalación de Windows ya viniera con todo hecho?**

El **Creador de ISO** parte de una **ISO oficial de Windows** (la que descargas de Microsoft) y la transforma en **tu** ISO: misma base legítima, pero con tu software, tus ajustes y tu cuenta ya integrados. Cuando instales Windows con ella, arrancarás directamente en un sistema limpio, optimizado y **listo para usar**.

### La genialidad del proceso

En lugar de instalar Windows y *luego* configurarlo (lo de siempre), WPI **mete la configuración dentro de la propia imagen de instalación**. El trabajo se hace **una vez** y se reutiliza para siempre.

### Los 8 pasos del asistente

El asistente te guía paso a paso. Esto ocurre en cada uno:

```text
┌──────────────────────────────────────────────────────────────┐
│  ASISTENTE CREADOR DE ISO  ·  8 pasos                         │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  1️⃣  Requisitos                                                │
│      Comprueba que eres administrador, que oscdimg            │
│      (Windows ADK) está disponible, que DISM funciona y       │
│      que hay espacio libre suficiente en C:.                  │
│                                                                │
│  2️⃣  Origen y salida                                           │
│      Eliges la ISO oficial de origen, la carpeta de salida,   │
│      el nombre de la ISO final y la carpeta de trabajo.       │
│      Puedes detectar las EDICIONES reales de la ISO           │
│      (Home, Pro…) y elegir personalizar una o todas.          │
│                                                                │
│  3️⃣  Tweaks (privacidad y rendimiento)                         │
│      Marcas qué ajustes quieres que la ISO ya traiga          │
│      aplicados de fábrica.                                     │
│                                                                │
│  4️⃣  Bloatware a quitar                                        │
│      Eliges qué apps preinstaladas se eliminan OFFLINE         │
│      directamente de la imagen (no llegan ni a instalarse).   │
│                                                                │
│  5️⃣  Apps a instalar                                           │
│      Seleccionas qué programas del catálogo se instalarán     │
│      automáticamente en el primer arranque.                   │
│                                                                │
│  6️⃣  Drivers a inyectar                                        │
│      Inyectas los controladores de tu hardware para que       │
│      Windows arranque ya con todo reconocido.                 │
│                                                                │
│  7️⃣  Instalación desatendida                                   │
│      Configuras la cuenta local, el idioma, y los bypass de   │
│      Windows 11 (TPM/cuenta Microsoft) si los necesitas.      │
│      Se genera un autounattend.xml a tu medida.               │
│                                                                │
│  8️⃣  Resumen y confirmación                                    │
│      Revisas todo y generas el KIT. La ISO final se           │
│      reensambla con oscdimg como administrador.               │
│                                                                │
└──────────────────────────────────────────────────────────────┘
```

### ¿Qué hace por dentro?

- 🧹 **Debloat offline** sobre la imagen montada (las apps no llegan ni a existir).
- 🔌 **Inyección de drivers** con DISM.
- 🧰 **Integración de WPI** y de **winget offline** para que el primer arranque instale tus apps.
- 📝 **`autounattend.xml`** generado a medida (cuenta local, idioma, opciones de Windows 11).
- 🏗️ **Reensamblado** de la imagen final con `oscdimg`.

### Después de crear la ISO

WPI incluye `Verificar_ISO.ps1` para **comprobar que tu ISO lo lleva todo** (carpeta WPI, autounattend, ediciones, drivers, winget) antes de grabarla:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Verificar_ISO.ps1 -Iso "C:\ruta\WPI_Custom_ES.iso" -ExpectedLang ES
```

Para grabarla a un USB, WPI te recomienda **Rufus** (esquema GPT, destino UEFI) y te avisa de un detalle clave: cuando Rufus muestre la ventana de "Experiencia de usuario de Windows", **no marques ninguna casilla**, o sobrescribiría la configuración de WPI.

> ⚠️ **Nota legal:** WPI **no incluye ninguna ISO de Windows**. Tú aportas la ISO oficial de Microsoft; WPI solo la personaliza en tu equipo. La ISO final **no se sube** a ningún repositorio.

---

## 🛠️ La Suite de Reparación (17 fases)

Cuando Windows se porta mal —errores raros, Windows Update atascado, componentes corruptos— la **Suite de Reparación** es tu kit de emergencia. Es una **consola autónoma y bilingüe** que diagnostica y repara el sistema en **17 fases ordenadas**, con una filosofía clave: **nada de falsos "OK"**. Si una fase no puede arreglar algo, lo dice claramente.

Vive en dos lanzadores independientes (puedes usarla incluso sin abrir la interfaz gráfica):

```text
Suite_Reparacion_ES\Suite_Reparacion_TodoEnUno.bat      (español)
Suite_Reparacion_EN\Repair_Suite_AllInOne.bat           (inglés)
```

### Modos disponibles

| Modo | Qué hace |
|---|---|
| *(sin argumentos)* | **Menú interactivo**: eliges qué hacer paso a paso. |
| `/triage` | **Diagnostica** y ejecuta solo las fases recomendadas según lo que detecte. |
| `/auto` | **Ejecución desatendida** completa. |
| `/quick` | **Inspección rápida** sin reparación profunda. |
| `/dry` | **Simulación**: muestra qué haría, sin tocar nada. |
| `/fases:05,06,13` (ES) · `/phases:05,06,13` (EN) | Ejecuta **solo** las fases que indiques. |
| `/manual` | Selección **manual** de acciones. |
| `/plan` | Muestra un **plan guiado** antes de ejecutar. |
| `/selftest` | **Auto-test seguro** de la propia suite. |
| `/help` · `/version` | Ayuda y versión (no requieren administrador). |

### Las 17 fases (00–16)

| Fase | Nombre | Qué hace |
|:---:|---|---|
| **00** | Diagnóstico y triage | SMART de discos, espacio, reinicios pendientes, eventos, red, batería y RAM. |
| **01** | Punto de restauración | Crea restore point y copia de seguridad del registro. |
| **02** | Limpieza inicial | Temporales, papelera y cachés iniciales. |
| **03** | CHKDSK | Escaneo online del disco del sistema. |
| **04** | Optimización de disco | TRIM/defrag según el tipo de unidad (SSD/HDD). |
| **05** | DISM | `RestoreHealth` con origen offline local si existe. |
| **06** | SFC y verificación | Ejecuta SFC y clasifica el resultado sin depender del idioma (anti falsos OK). |
| **07** | Reparar WMI | Verifica y repara el repositorio WMI. |
| **08** | Apps de Store e Inicio | Re-registra Appx y repara el menú Inicio. |
| **09** | Búsqueda y cachés | Índice de búsqueda, iconos, fuentes y spooler. |
| **10** | Certificados y hora | Sincroniza hora y certificados raíz. |
| **11** | Red | Winsock, IP, DNS, proxy, ARP, rutas y hosts. |
| **12** | Directivas GPO | `gpupdate /force`. |
| **13** | Windows Update | Servicios, cachés, qmgr, DLLs, IDs WSUS y detección forzada. |
| **14** | Winget | Repara fuentes y operatividad de winget. |
| **15** | Dispositivos | Detecta dispositivos y drivers con problemas. |
| **16** | Limpieza final e informe | Limpieza final, comprobación de salud e **informe HTML**. |

> 🧠 **Filosofía anti falsos OK:** muchas herramientas dicen "reparado" cuando en realidad no han arreglado nada. La Suite clasifica los resultados de verdad (por ejemplo, leyendo los logs de CBS de SFC sin depender del idioma del sistema) para darte un veredicto honesto.

---

## 🌍 Dos idiomas y tres temas

WPI Moderno está pensado para todo el mundo:

### 🗣️ Idiomas
- **Español** 🇪🇸
- **English** 🇬🇧

Se cambia desde la cabecera y se aplica al reiniciar la app. **Toda** la interfaz se traduce: menús, descripciones, estados, datos de hardware, diálogos, el creador de ISO, las guías e incluso el **registro en vivo** del motor.

### 🎨 Temas
- 🌙 **Oscuro** (por defecto)
- ☀️ **Claro**
- 🔵 **Azul** — un guiño cariñoso al estilo de **Chris Titus**.

---

## ✅ Verificación y seguridad

WPI incluye un **verificador integral** que comprueba parseo de PowerShell, sincronización de las suites, hashes de integridad, codificación (sin mojibake ni BOM) y cobertura de traducción (sin texto español filtrado a la versión inglesa):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Verificar_Proyecto.ps1 -ConsoleSmoke
```

### Compromiso de transparencia

- 🚫 **Sin software pirata.** Todo se instala con winget desde manifiestos oficiales.
- 📜 **Logs de todo.** Las acciones relevantes dejan registro.
- 🔐 **Administrador solo cuando hace falta.** Las operaciones de sistema piden elevación.
- 🙈 **Nada privado al repo.** No subas ISOs, logs personales ni informes internos.

---

## 📸 Capturas

<table>
  <tr>
    <td width="50%"><img src="docs/img/wpi-apps.png" alt="Catálogo de apps"><br><sub><b>Catálogo de +360 apps con winget</b></sub></td>
    <td width="50%"><img src="docs/img/wpi-iso.png" alt="Creador de ISO"><br><sub><b>Creador de ISO personalizada (8 pasos)</b></sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/img/wpi-tweaks.png" alt="Tweaks"><br><sub><b>Tweaks de privacidad y rendimiento</b></sub></td>
    <td width="50%"><img src="docs/img/wpi-repair.png" alt="Suite de reparación"><br><sub><b>Suite de Reparación de 17 fases</b></sub></td>
  </tr>
</table>

> 🌍 WPI Moderno es bilingüe: <img src="docs/img/wpi-es.png" alt="Versión en español" width="49%"> <img src="docs/img/wpi-en.png" alt="English version" width="49%">

## 🙏 Inspiración y créditos

WPI Moderno nace, **con respeto y admiración**, del ecosistema de herramientas profesionales de post-instalación de Windows. En especial, rinde homenaje al trabajo de:

- **[Chris Titus Tech](https://github.com/ChrisTitusTech/winutil)** y su **WinUtil** — referencia absoluta del género (de ahí el tema "Azul" como guiño).
- La comunidad de scripts de *debloat*, *tweaks* y automatización de Windows que lleva años compartiendo conocimiento.

Sobre esa inspiración, WPI Moderno aporta su **propia visión**: interfaz **bilingüe**, **creador de ISO integrado**, catálogo **curado** de +360 apps, **perfiles** portables y una **suite de reparación por fases** con filosofía anti falsos OK.

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Consulta **[CONTRIBUTING.md](CONTRIBUTING.md)**. Ideas útiles:

- Nuevas apps para el catálogo (con su ID de winget).
- Mejoras de traducción ES/EN.
- Nuevos tweaks (reversibles y bien documentados).
- Pruebas en máquina virtual.
- Mejoras de documentación.
- Fixes en la Suite de Reparación.

---

## 📄 Licencia

Distribuido bajo licencia **MIT**. Consulta **[LICENSE](LICENSE)**. Eres libre de usar, modificar y compartir el proyecto.

---

<div align="center">

**Si WPI Moderno te ahorra tiempo, regálale una ⭐ — ayuda a que más gente lo encuentre.**

Hecho con ❤️ para la comunidad de Windows.

</div>
