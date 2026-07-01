<div align="center">

# ⚡ WPI Moderno

### Tu Windows 10/11, listo en una tarde. Instala, optimiza, limpia, repara y hasta crea tu propia ISO — todo desde una sola app.

**PowerShell + WPF · Motor winget asíncrono · Bilingüe ES/EN · 3 temas · Sin telemetría · Código abierto**

</div>

---

## 🎯 ¿Qué es WPI Moderno?

Acabas de instalar Windows (o quieres poner a punto el que ya tienes) y empieza el ritual de siempre: descargar el navegador, el reproductor, el compresor, quitar el bloatware, tocar mil ajustes de privacidad, actualizarlo todo, pelearte con los drivers… horas.

**WPI Moderno lo convierte en clics.** Es un centro de mando único, con una interfaz moderna tipo panel, que reúne **todo lo que harías tras formatear** — y bastante que ni sabías que podías hacer — sin líneas de comando, sin scripts sueltos y **sin instalar nada raro**: por debajo usa el **winget oficial de Microsoft**.

No es un instalador más. Es **un instalador + optimizador + limpiador + reparador + creador de ISO**, todo integrado, en español e inglés, y pensado para que **tú tengas el control** (marca, revisa y aplica — nunca hace cambios a tus espaldas).

> 💡 **La diferencia:** inspirado en lo mejor del género (guiño a WinUtil de Chris Titus con su tema "Azul"), pero llevado a otro nivel: verificación **real** de que las cosas se aplican, detección de estado en cada opción, asistentes guiados paso a paso y una Suite de reparación profesional de 17 fases.

---

## 🧩 Las secciones, una a una

### 🛒 1. Catálogo de +360 apps *(Instalar)*
El corazón de WPI. Un catálogo curado de **más de 360 aplicaciones** organizado en **22 categorías** (Navegadores, Multimedia, Desarrollo, Seguridad, Ofimática, Gaming, Utilidades…).

- **Marca lo que quieras y pulsa INSTALAR (N)** — se instala solo, en cadena, con winget.
- **Presets de un clic:** *Gaming*, *Desarrollador*, *Multimedia*, *Esencial*… seleccionan el pack recomendado al instante.
- **Detectar instaladas:** escanea tu PC y marca en verde lo que ya tienes, con su versión.
- **Guardar / Cargar perfil** y **"Última sesión"**: recupera tu selección de siempre.
- **Buscador instantáneo** por nombre, categoría o ID de winget.
- Además: **desinstalar**, **descargar el instalador .exe/.msi** suelto, **validar IDs**, y elegir **ámbito** (todo el equipo o solo tu usuario) e **hilos** (1 seguro → varios en paralelo, con reintentos automáticos si dos instaladores chocan).

### 🔄 2. Actualizaciones disponibles
Un centro de actualizaciones honesto, basado en `winget upgrade`, **dividido en dos grupos** para no mezclar nada:

- **Grupo 1 — Apps del catálogo WPI**
- **Grupo 2 — Otros programas de tu PC**

Pulsas **"Buscar updates"** (ahora también **dentro de la sección**, visible al entrar) y verás qué hay para cada grupo. Cada botón actualiza **solo su grupo**.

> ✅ **Verificación REAL post-actualización:** WPI no se limita a decir "listo" porque el proceso terminó. Tras actualizar, **comprueba la versión instalada** y te avisa si en realidad **no cambió** (típico de apps que se auto-actualizan o están en uso). Se acabó el "dice que actualiza pero sigue igual".

### 🌐 3. Buscar en winget (todo) · Clonar equipo / Snapshot
- **Buscar en winget:** ¿una app fuera del catálogo? Búscala en todo winget e instálala desde aquí.
- **Clonar equipo / Snapshot:** **exporta** todo lo instalado a un archivo y **impórtalo** en otro PC (o tras formatear) para dejarlo idéntico. Ideal para migraciones y para montar varios equipos iguales.

### ⚙️ 4. Tweaks y ajustes
Más de **40 tweaks** de **privacidad, rendimiento y experiencia**, con diseño limpio a **2 columnas** (estilo Chris Titus, llevado más allá):

- **Presets graduados por riesgo real:** 🟢 **Seguro** · 🟠 **Equilibrado** · 🔴 **Agresivo** (y *Ninguno*). Solo **marcan**; tú revisas y aplicas.
- **Detección de estado por cada tweak:** un punto de color te dice de un vistazo si **ya está aplicado** en tu PC (verde) o no (gris), y un **contador arriba** ("● N aplicados · ● M sin aplicar").
- **Reversible:** casi todo tiene su vuelta atrás con **"Revertir seleccionados"**.
- **"Aplicar recomendado para MI equipo":** WPI mira tu hardware (portátil/sobremesa, SSD, RAM, GPU) y marca lo que tiene sentido para ti.
- Cada acción corre por el **motor real con log forense**, y crea un **punto de restauración** si lo dejas activado.

### 🧹 5. Quitar bloatware (Appx)
Elimina apps preinstaladas (Xbox, Copilot, promocionadas…) **para tu usuario y de la imagen del sistema**.

- **Detección de estado por app:** ámbar = **sigue instalada** (se puede quitar), verde = **ya no está**, con **contador** arriba.
- Son Appx **reinstalables** desde la Store: nada irreversible.

### 🛡️ 6. Control de Windows Update
Cuatro tarjetas para decidir **cómo y cuándo** se actualiza Windows — replicando lo que hace WinUtil, pero con **constancia real en el log**:

- **Configuración recomendada:** retrasa las de características ~1 año y las de seguridad 4 días (estilo "Pro").
- **Pausar todas 5 semanas.**
- **Valores por defecto:** deshace todo y reactiva servicios y tareas.
- 🔴 **Desactivar por completo:** detiene y deshabilita los servicios (BITS, wuauserv, UsoSvc…), limpia `SoftwareDistribution` y desactiva las tareas programadas. Reversible con "Valores por defecto".

### 🩹 7. Reparación · Suite de Emergencia de 17 fases
Una **Suite de reparación profesional** integrada (bilingüe ES/EN), con filosofía **anti falsos "OK"**. Se abre como consola interactiva de administrador con un menú claro:

- **Reparación COMPLETA automática**, **Reparación inteligente (auto-triage — solo lo necesario)**, **Inspección rápida**, **Modo manual** (un comando por fase), **Plan guiado**, **elegir fases concretas** y **simulación (dry-run)** que no toca nada.
- **17 fases:** diagnóstico y triage, punto de restauración, limpieza, CHKDSK, optimización de disco (TRIM/desfrag), DISM, SFC, reparar WMI, apps de Store e inicio, índice y cachés, certificados y hora, reset de red, directivas GPO, Windows Update, winget, dispositivos/drivers y limpieza final con **informe HTML**.
- Desde la GUI puedes **lanzar la consola completa** o **fases sueltas** en una cuadrícula, sin abrir nada a mano.

### 🧩 8. Características de Windows
Activa o desactiva **componentes opcionales** (Hyper-V, **WSL2**, .NET, Sandbox…) por **DISM**, con **estado detectado**, log forense y reversible. Avisa si una característica pide reinicio o si solo existe en Pro/Enterprise.

### 🖥️ 9. Drivers y hardware
Un panel que **detecta tu equipo** (CPU, RAM, discos con **temperaturas SMART**, placa, pantallas, batería y salud) y te da accesos directos útiles:

- **Drivers de GPU:** detecta el fabricante y **siempre ofrece los tres** — **NVIDIA** (NVIDIA App), **AMD** (Adrenalin) e **Intel** (DSA) — resaltando el que tienes.
- **Copia de seguridad de tus drivers** actuales (.inf) para reinstalarlos o inyectarlos en una ISO.
- **Recomendaciones según tu hardware** (p. ej. GPU-Z, Afterburner, CrystalDiskInfo, HWiNFO…).

### 💿 10. Crear ISO de Windows a medida
El nivel experto, ahora **guiado paso a paso** para que no te pierdas:

- **Asistente de 8 pasos** con **breadcrumb visual** (sabes dónde estás y qué falta) y un banner **"AHORA:"** que te dice exactamente qué hacer en cada paso.
- **Elige tu ISO → detecta ediciones → elige una (más rápido) o todas → salida y nombre.**
- Integra **offline**: **debloat** antes de instalar, **inyección de drivers**, tus **apps + tweaks** para el primer arranque, **winget offline**, y un **`autounattend.xml`** para instalación desatendida (cuenta local, bypass de requisitos de Win11, etc.).
- Reensambla la imagen con **oscdimg** y trae **verificador de ISO** + guía de **Rufus** y de **máquina virtual**.
- **Recordatorios inteligentes:** te avisa de las consecuencias (drivers dentro vs. a mano, el "Modo VM" que **formatea el disco 0**, cómo dejar Rufus…). Nada se toca hasta el último paso, donde confirmas.

---

## ✨ Lo que hace que se sienta premium (en todo)

- 🌍 **Bilingüe ES/EN** de verdad: interfaz, avisos, tooltips y la Suite de reparación.
- 🎨 **3 temas**: Claro, Oscuro y **Azul (Chris Titus)**.
- 💬 **Tooltips descriptivos** en cada control: nunca te quedas con la duda de qué hace un botón.
- 📋 **Registro en vivo + log forense** por sesión: ves en tiempo real lo que ocurre y queda guardado.
- 🔒 **Tú mandas:** WPI **marca y propone**, pero **aplica solo cuando tú pulsas**. Crea punto de restauración cuando toca.
- 🛠️ **Motor asíncrono** que **nunca congela la ventana**: instalaciones en paralelo, *watchdog* por app, reintentos ante choques y *fallback* opcional a Chocolatey.
- 🔡 **Hecho con rigor:** verificador integral (parseo, hashes de la Suite, encoding, cobertura de traducción) que corre en **CI en cada cambio**. Cero texto español filtrado a la versión inglesa, cero mojibake.
- 🔐 **Sin telemetría, sin cuentas, sin nada oculto.** Código abierto (MIT). Se auto-eleva a Administrador solo para lo que de verdad lo necesita.

---

## 🚀 Empezar es trivial

1. Descarga el proyecto.
2. Doble clic en **`Iniciar_WPI.bat`** (pide permisos de administrador solo).
3. Marca lo que quieras, revisa y pulsa. **Listo.**

> Requisitos: Windows 10/11, PowerShell 5.1+ (viene con Windows) y winget (App Installer, ya incluido en Windows moderno). Para **crear ISO**, opcionalmente Windows ADK (oscdimg) — WPI te lo instala desde la propia app.

---

<div align="center">

**WPI Moderno** — porque poner a punto Windows no debería costar una tarde.

⭐ Si te ahorra tiempo, deja una estrella en el repo.

</div>
