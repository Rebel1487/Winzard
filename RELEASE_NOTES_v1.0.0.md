# 🚀 WPI Moderno v1.0.0 — Primer lanzamiento público

> Borrador profesional de Release Notes (español). Cópialo en la descripción del Release de GitHub al publicar la `v1.0.0`.

---

## 🪟 Tu Windows ideal, montado en minutos

**WPI Moderno** es un centro de mando todo-en-uno para Windows 10/11. Desde una sola ventana puedes **instalar cientos de programas legales con winget**, **optimizar y limpiar** el sistema, **repararlo** con una suite profesional de 17 fases y —la función estrella— **crear tu propia ISO de Windows personalizada** con tus apps, tus ajustes y tu cuenta ya integrados.

Todo en **español o inglés**, con **tres temas visuales**, y **100% transparente**: nada de pirateo, todo vía winget desde fuentes oficiales.

---

## ✨ Lo que incluye esta versión

### 🛒 Instalación de software inteligente
- Catálogo curado de **+360 programas** en **22 categorías**.
- **Detección automática**: WPI sabe qué tienes instalado, tu versión actual y la última disponible.
- **Presets de un clic**: Gaming, Desarrollador, Multimedia, Esencial, Última sesión.
- Búsqueda global en todo el repositorio de winget.
- Centro de actualizaciones (`winget upgrade`).
- Clonado de equipo / Snapshot para migrar tu entorno.

### ⚙️ Optimización y limpieza
- **40+ tweaks** de privacidad, rendimiento y experiencia, con estado y reversión.
- **Debloat** de apps preinstaladas (usuario + imagen del sistema).
- Gestión de características de Windows (Hyper-V, WSL2, .NET…).

### 🩹 Reparación profesional
- **Suite de Reparación bilingüe de 17 fases** con filosofía *anti falsos OK*.
- Modos `/triage`, `/auto`, `/dry`, `/fases`, `/manual`, `/plan`, `/selftest` y menú interactivo.
- Funciona incluso fuera de la interfaz gráfica.

### 💿 Creador de ISO personalizada (la joya)
- Asistente en **8 pasos** que transforma una ISO oficial de Windows en la tuya.
- Debloat offline, inyección de drivers, WPI + winget offline, `autounattend.xml` a medida y reensamblado con oscdimg.
- Verificador de ISO incluido.

### 🌍 Experiencia
- Interfaz **bilingüe ES/EN** completa (incluido el registro en vivo).
- **3 temas**: Claro, Oscuro y Azul.
- Tooltips descriptivos en todos los controles.

### ✅ Calidad
- UTF-8 sin BOM garantizado, cobertura de traducción verificada y formato numérico por idioma.
- Verificador integral del proyecto + CI en GitHub Actions.

---

## 📥 Cómo empezar

1. Descarga **`WPI-Moderno-v1.0.0.zip`** de los *Assets* de abajo.
2. Extráelo en una carpeta local (por ejemplo `C:\WPI`).
3. Ejecuta **`Iniciar_WPI.bat`** y acepta la elevación UAC.
4. Elige idioma y tema, ¡y a montar tu Windows!

📖 Manual completo: [README](README.md) · [English](README_EN.md)

---

## ⚠️ Notas importantes

- WPI **no incluye ninguna ISO de Windows**. Para crear una ISO personalizada, tú aportas la ISO oficial de Microsoft; WPI solo la personaliza en tu equipo.
- Las operaciones de sistema requieren **permisos de administrador**.
- Para tweaks/debloat/reparación, se recomienda probar antes en una **máquina virtual** y crear un **punto de restauración**.

---

## 🙏 Inspiración

Hecho con respeto al ecosistema de herramientas de post-instalación de Windows, en especial a **[Chris Titus Tech / WinUtil](https://github.com/ChrisTitusTech/winutil)** (de ahí el tema "Azul").

---

## 📝 Changelog

Consulta el [CHANGELOG.md](CHANGELOG.md) completo.

**Licencia:** MIT · **Plataforma:** Windows 10/11 x64 · **Requiere:** PowerShell 5.1+ y winget

---

*Si WPI Moderno te ahorra tiempo, deja una ⭐ en el repositorio. ¡Gracias por probarlo!* 💜
