# Third-Party Notices — Winzard

## Summary

**Winzard bundles no third-party code.** It has no package dependencies (no npm, PyPI, NuGet or similar), no vendored directories, and no copied source files. Every line in `WPI_Moderno.ps1`, `Verificar_Proyecto.ps1`, `Verificar_ISO.ps1` and the two Repair Suites is original work by the project author.

This file exists for **full transparency** about the relationship between Winzard and the projects that inspired it, and about the external components it *invokes* at runtime.

## Projects that inspired Winzard (no code reused)

Winzard was written from scratch, but several tweaks and debloat entries were designed **after studying the publicly documented registry keys** used by these projects. Registry paths and value names are factual information about Windows, not copyrightable expression; the implementation, structure, bilingual logging and per-tweak undo logic in Winzard are original.

Credit is given here and in the README because these projects set the standard for the genre:

| Project | Author | Licence | Relationship |
|---|---|---|---|
| [WinUtil](https://github.com/ChrisTitusTech/winutil) | Chris Titus Tech | MIT | Genre reference and main inspiration. Winzard's "Blue" theme is a declared visual tribute. Some tweak registry keys were cross-checked against it. |
| [Winhance](https://github.com/memstechtips/Winhance) | Memory (memstechtips) | MIT | Inspiration for focused optimisation/debloating UX. Some tweak keys cross-checked. |
| [Sophia Script for Windows](https://github.com/farag2/Sophia-Script-for-Windows) | farag2 & Team Sophia | MIT | Inspiration for the reversibility-first standard. Some tweak keys cross-checked. |
| [Win11Debloat](https://github.com/Raphire/Win11Debloat) | Raphire | MIT | Inspiration for the "remove only what you choose" philosophy. Some registry keys verified against its published Regfiles (see the code comments marked *"auditoría contra Win11Debloat"*). |

All four are MIT-licensed, so even direct reuse would be permitted with attribution. **No such reuse took place**; this notice records the intellectual debt, which is stronger than the licence requires.

## External components invoked at runtime (not distributed)

Winzard calls these tools; it never bundles, hosts or redistributes them:

| Component | Provider | Note |
|---|---|---|
| `winget` (App Installer) | Microsoft | Ships with modern Windows. All app installs go through it, from official manifests. |
| `DISM`, `SFC`, `CHKDSK`, `gpupdate`, `schtasks`, `powercfg`, `netsh` | Microsoft | Built-in Windows system tools. |
| `oscdimg` (Windows ADK) | Microsoft | Optional, only for the ISO builder. Installed by the user. |
| Chocolatey | Chocolatey Software | Optional fallback only; used if present, never installed silently. |
| Rufus | Pete Batard | Optional; only launched if the user has it, to write a built ISO to USB. |
| Windows installation images | Microsoft | **Never included.** The user supplies their own official Microsoft ISO; customisation happens locally and the result never leaves the user's machine. |

## Reporting an attribution problem

If you believe any part of Winzard reproduces your work without proper credit, please open an issue or contact the maintainer. Attribution errors will be corrected promptly — a project that asks for its own authorship to be respected must be impeccable about respecting everyone else's.
