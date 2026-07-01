# Changelog

All notable changes to **Winzard** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

---

## [1.0.0] — 2026-06-29

First stable public release.

### Added
- 🛒 **360+ app catalog** organized in 22 categories, installable with winget.
- 🔍 **Automatic detection** of installed apps, current version and latest available.
- 🔄 **Update center** based on `winget upgrade`, with **real post-update verification** (checks the actual installed version and warns if it didn't change).
- 🌐 **Global winget search** to install any package outside the catalog.
- 🧬 **Clone PC / Snapshot** (export/import of installed apps).
- ⚙️ **40+ tweaks** for privacy, performance and experience, with state detection and reversal.
- 🎚️ **Graduated tweak presets** (Safe 🟢 / Balanced 🟠 / Aggressive 🔴), by real risk level, color-coded and counted — they only mark; you review and apply.
- 🧹 **Appx debloat** for the current user and the system image, with per-app state detection.
- 🛡️ **Windows Update control** (defer / pause / restore defaults / fully disable: services + SoftwareDistribution + scheduled tasks).
- 🩹 **Bilingual 17-phase Repair Suite** with an anti-false-OK philosophy and multiple modes (`/triage`, `/auto`, `/dry`, `/fases`, `/manual`, `/plan`, `/selftest`…).
- 💿 **Custom ISO builder** with a guided 8-step wizard (offline debloat, driver injection, WPI + offline winget, `autounattend.xml`, reassembly with oscdimg).
- 🖥️ **Drivers & hardware panel** with spec detection and driver backup; GPU drivers for NVIDIA/AMD/Intel always available.
- 🧩 **Windows features management** (Hyper-V, WSL2, .NET…).
- 🌍 **Bilingual EN/ES interface** and **3 themes** (Light, Dark, Blue).
- 💬 **Descriptive tooltip system** on every control.
- 📋 **Log viewer** and per-session forensic logging.
- ✅ **Full project verifier** (`Verificar_Proyecto.ps1`) with checks for parsing, hashes, encoding (mojibake/BOM) and translation coverage.
- 🔎 **ISO verifier** (`Verificar_ISO.ps1`).

### Quality
- 🔡 **Correct encoding policy for PowerShell 5.1**: `.ps1` scripts with non-ASCII characters carry a **BOM** (so 5.1 reads them as UTF-8 and doesn't corrupt accents/symbols); **data** files (json/settings) are written **without BOM** for interoperability. The verifier enforces both rules.
- 🖥️ **Repair Suite console** left clean and legible (default Consolas) in ES and EN.
- 🌎 **Translation coverage** verified automatically: zero Spanish text leaking into the English version.
- 🔢 **Per-language number formatting** (correct decimal separator for ES/EN).
- 🧪 **GitHub Actions CI** that runs the full verifier on every push/PR.

---

## Versioning notes

- **MAJOR** (1.x.x): incompatible changes or large rewrites.
- **MINOR** (x.1.x): new backward-compatible features.
- **PATCH** (x.x.1): fixes and minor improvements.

[1.0.0]: https://github.com/Rebel1487/Winzard/releases/tag/v1.0.0
