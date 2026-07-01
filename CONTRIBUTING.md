# Contributing to WPI Moderno

Thanks for your interest in improving **WPI Moderno**! This project grows with the community. Here's how to contribute effectively.

> 🇪🇸 *¿Prefieres español?* La app es bilingüe y el manual está en [README_ES.md](README_ES.md).

## Ways to contribute

| Type | Description |
|---|---|
| 🛒 **New apps** | Add programs to the catalog with their verified **winget ID**. |
| 🌍 **Translations** | Improve or fix ES/EN strings. |
| ⚙️ **Tweaks** | Propose new settings: **reversible** and well documented. |
| 🧪 **Testing** | Test in a virtual machine and report results. |
| 📖 **Documentation** | Improve the READMEs, guides or comments. |
| 🩹 **Repair Suite** | Fix or improve suite phases. |
| 🐛 **Bugs** | Report issues with clear reproduction steps. |

## Before opening a Pull Request

1. **Open an Issue** first for large changes, to agree on the approach.
2. **Run the verifier** and make sure it's green:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Verificar_Proyecto.ps1 -ConsoleSmoke
   ```
3. **Test in a VM** if you touch tweaks, debloat, repair or the ISO creator (these are system operations).
4. **Keep it bilingual**: any new UI-visible text must exist in both English **and** Spanish. The verifier fails if a Spanish string leaks into the EN version.
5. **UTF-8 encoding** with the project's rules (the verifier checks it): `.ps1` scripts with non-ASCII characters carry a **BOM** so Windows PowerShell 5.1 reads them as UTF-8; data files (json/settings) are written **without BOM**.

## How to add an app to the catalog

1. Find the exact ID:
   ```powershell
   winget search "program name"
   ```
2. Add it to the catalog with its category, name and ID.
3. Validate it with the **Validate IDs** button inside WPI or with `winget show --id <ID> -e`.

## Golden rules

- ✅ Only **legal** software from **official sources** (via winget).
- ✅ **Reversible** tweaks whenever possible.
- ✅ **Explained** and logged changes.
- ❌ No ISOs, personal logs, heavy binaries or private data in commits.

## Commit style

Use clear, descriptive messages, for example:

```text
catalog: add Obsidian to the Productivity group
i18n: fix drivers panel translation
repair: avoid infinite second SFC pass in phase 06
docs: expand the ISO creator section
```

---

Thanks for contributing! 💜
