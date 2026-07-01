# Contribuir a WPI Moderno · Contributing to WPI Moderno

> 🇪🇸 Español primero · 🇬🇧 [English below](#-english)

---

## 🇪🇸 Español

¡Gracias por tu interés en mejorar **WPI Moderno**! Este proyecto crece con la comunidad. Aquí tienes cómo aportar de forma útil.

### Formas de contribuir

| Tipo | Descripción |
|---|---|
| 🛒 **Nuevas apps** | Añade programas al catálogo con su **ID de winget** verificado. |
| 🌍 **Traducciones** | Mejora o corrige cadenas ES/EN. |
| ⚙️ **Tweaks** | Propón ajustes nuevos: **reversibles** y bien documentados. |
| 🧪 **Pruebas** | Testea en máquina virtual y reporta resultados. |
| 📖 **Documentación** | Mejora los README, guías o comentarios. |
| 🩹 **Suite de Reparación** | Corrige o mejora fases de la suite. |
| 🐛 **Bugs** | Reporta problemas con pasos claros para reproducirlos. |

### Antes de enviar un Pull Request

1. **Abre un Issue** primero si el cambio es grande, para acordar el enfoque.
2. **Ejecuta el verificador** y asegúrate de que pasa en verde:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Verificar_Proyecto.ps1 -ConsoleSmoke
   ```
3. **Prueba en una VM** si tocas tweaks, debloat, reparación o el creador de ISO (son operaciones de sistema).
4. **Mantén el bilingüismo**: cualquier texto nuevo visible en la interfaz debe existir en español **y** en inglés. El verificador falla si una cadena española se filtra a la versión EN.
5. **Codificación UTF-8 sin BOM** en todos los archivos fuente (el verificador lo comprueba).

### Cómo añadir una app al catálogo

1. Encuentra el ID exacto:
   ```powershell
   winget search "nombre del programa"
   ```
2. Añádela al catálogo con su categoría, nombre e ID.
3. Valídala con el botón **Validar IDs** dentro de WPI o con `winget show --id <ID> -e`.

### Reglas de oro

- ✅ Solo software **legal** y de **fuentes oficiales** (vía winget).
- ✅ Tweaks **reversibles** siempre que sea posible.
- ✅ Cambios **explicados** y con registro.
- ❌ Nada de ISOs, logs personales, binarios pesados ni datos privados en los commits.

### Estilo de commits

Usa mensajes claros y descriptivos, por ejemplo:

```text
catalog: añade Obsidian al grupo Productividad
i18n: corrige traducción del panel de drivers
repair: evita segunda pasada infinita de SFC en fase 06
docs: amplía la sección del creador de ISO
```

---

## 🇬🇧 English

Thanks for your interest in improving **WPI Moderno**! This project grows with the community. Here's how to contribute effectively.

### Ways to contribute

| Type | Description |
|---|---|
| 🛒 **New apps** | Add programs to the catalog with their verified **winget ID**. |
| 🌍 **Translations** | Improve or fix ES/EN strings. |
| ⚙️ **Tweaks** | Propose new settings: **reversible** and well documented. |
| 🧪 **Testing** | Test in a virtual machine and report results. |
| 📖 **Documentation** | Improve the READMEs, guides or comments. |
| 🩹 **Repair Suite** | Fix or improve suite phases. |
| 🐛 **Bugs** | Report issues with clear reproduction steps. |

### Before opening a Pull Request

1. **Open an Issue** first for large changes, to agree on the approach.
2. **Run the verifier** and make sure it's green:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Verificar_Proyecto.ps1 -ConsoleSmoke
   ```
3. **Test in a VM** if you touch tweaks, debloat, repair or the ISO creator (these are system operations).
4. **Keep it bilingual**: any new UI-visible text must exist in both Spanish **and** English. The verifier fails if a Spanish string leaks into the EN version.
5. **UTF-8 without BOM** for all source files (the verifier checks this).

### How to add an app to the catalog

1. Find the exact ID:
   ```powershell
   winget search "program name"
   ```
2. Add it to the catalog with its category, name and ID.
3. Validate it with the **Validate IDs** button inside WPI or with `winget show --id <ID> -e`.

### Golden rules

- ✅ Only **legal** software from **official sources** (via winget).
- ✅ **Reversible** tweaks whenever possible.
- ✅ **Explained** and logged changes.
- ❌ No ISOs, personal logs, heavy binaries or private data in commits.

### Commit style

Use clear, descriptive messages, for example:

```text
catalog: add Obsidian to the Productivity group
i18n: fix drivers panel translation
repair: avoid infinite second SFC pass in phase 06
docs: expand the ISO creator section
```

---

¡Gracias por contribuir! · Thanks for contributing! 💜
