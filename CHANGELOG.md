# Changelog

Todos los cambios notables de **WPI Moderno** se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

> 🇬🇧 *All notable changes to WPI Moderno are documented here, following Keep a Changelog and Semantic Versioning.*

---

## [1.0.0] — 2026-06-29

Primera versión pública estable. · *First stable public release.*

### Añadido · Added
- 🛒 **Catálogo de +360 apps** organizado en 22 categorías, instalables con winget.
- 🔍 **Detección automática** de apps instaladas, versión actual y última disponible.
- 🔄 **Centro de actualizaciones** basado en `winget upgrade`.
- 🌐 **Búsqueda global en winget** para instalar cualquier paquete fuera del catálogo.
- 🧬 **Clonado de equipo / Snapshot** (export/import de lo instalado).
- ⚙️ **40+ tweaks** de privacidad, rendimiento y experiencia, con estado y reversión.
- 🎚️ **Presets graduados de tweaks** (Seguro 🟢 / Equilibrado 🟠 / Agresivo 🔴), por nivel de riesgo real, con color y conteo — solo marcan, tú revisas y aplicas.
- 🧹 **Debloat de Appx** para usuario actual e imagen del sistema.
- 🩹 **Suite de Reparación bilingüe de 17 fases** con filosofía anti falsos OK y múltiples modos (`/triage`, `/auto`, `/dry`, `/fases`, `/manual`, `/plan`, `/selftest`…).
- 💿 **Creador de ISO personalizada** en 8 pasos (debloat offline, inyección de drivers, WPI + winget offline, `autounattend.xml`, reensamblado con oscdimg).
- 🖥️ **Panel de drivers y hardware** con detección de specs y backup de controladores.
- 🧩 **Gestión de características de Windows** (Hyper-V, WSL2, .NET…).
- 🌍 **Interfaz bilingüe ES/EN** y **3 temas** (Claro, Oscuro, Azul).
- 💬 **Sistema de tooltips** descriptivos en todos los controles.
- 📋 **Visor de logs** y registro forense por sesión.
- ✅ **Verificador integral** (`Verificar_Proyecto.ps1`) con checks de parseo, hashes, encoding (mojibake/BOM) y cobertura de traducción.
- 🔎 **Verificador de ISO** (`Verificar_ISO.ps1`).

### Calidad · Quality
- 🔡 **Política de encoding correcta para PowerShell 5.1**: los scripts `.ps1` con caracteres no-ASCII llevan **BOM** (para que 5.1 los lea como UTF-8 y no corrompa tildes/símbolos); los ficheros de **datos** (json/settings) se escriben **sin BOM** por interoperabilidad. El verificador valida ambas reglas y falla si un script con no-ASCII no tiene BOM.
- 🖥️ **Consolas de la Suite más amplias y legibles** (estilo premium) en ES y EN.
- 🌎 **Cobertura de traducción** verificada automáticamente: cero texto español filtrado a la versión inglesa.
- 🔢 **Formato numérico por idioma** (punto/coma decimal correcto según ES/EN).
- 🧪 **CI en GitHub Actions** que ejecuta el verificador integral en cada push/PR.

---

## Notas de versionado

- **MAJOR** (1.x.x): cambios incompatibles o reescrituras grandes.
- **MINOR** (x.1.x): nuevas funcionalidades compatibles.
- **PATCH** (x.x.1): correcciones y mejoras menores.

[1.0.0]: https://github.com/Rebel1487/WPI-Moderno/releases/tag/v1.0.0
