# Changelog

All notable changes to **Winzard** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

---

## [1.1.0] — 2026-07-10  *(app build v7.4)*

The **verified release**: every section, every button, both languages, exercised one by one on a real PC **twice** (two full verification passes), plus a live-fire test — a custom ISO installed 100 % unattended in a VM with **18/18 apps installing themselves** on first boot. Every bug found on the way was fixed and re-verified.

### Added
- 📖 **In-app manual viewer**: every manual now has its own small button on Quick start (plus a highlighted **Complete manual**) and opens in a **premium reading window inside Winzard** — no folders, no browser. Bilingual, all 3 themes.
- 📚 **Manuals, doubled down**: 16 manuals per language rewritten with button-by-button detail and **practical examples** ("I want X → press Y") so any user can follow them.
- ⏳ **Startup splash with progress bar**: Winzard shows a loading screen from the first second and reveals the app fully ready (it also warms up the async install engine, killing the first-action lag).
- 🛠️ **Quick system tools** in Repair: 14 one-click repairs (SFC, DISM, network reset, WU cache, Store, search index, winget, monthly task, DNS presets, silence Edge) wired to the async engine with full logging and Cancel.
- 🥇 **Premium first boot** (custom ISO): per-app progress bar + live window title + per-app timing; **anti-hang watchdog** (a stuck winget can't freeze the batch); **automatic network retry** (apps that failed due to a network drop are retried once connectivity returns); problematic apps deferred to first sign-in via an **elevated task — zero UAC prompts**; `Reintentar_apps_fallidas.cmd` also runs **without UAC**; apps resolve from the winget source directly (immune to an uninitialized msstore).
- 🤖 **Truly 100 % unattended installs**: the 25H2 OOBE region/keyboard pages are suppressed and a generic setup key is embedded — from booting the ISO to the desktop, **not a single keystroke**.
- 🧰 **CLI, expanded**: documented `-Preset` / `-Update`; global **fail-closed `-DryRun`** with an unmistakable banner; `-BuildIsoKit` now neutral by default with `-IsoTweaksAll` / `-IsoDebloatAll` opt-ins; the unattended console respects the saved language and never blocks waiting for Enter under automation.
- 💿 **ISO wizard niceties**: output/work folder proposed on the disk with the most free space; honest summary row when the unattended password is empty; multi-partition ISOs mount correctly; single-edition WIMs get the right autounattend image index.

### Fixed
- 💾 Saving an app preset as `.txt` never wrote the file (silent data loss) — fixed and verified in ES/EN GUI runs.
- 🧹 Five debloat-panel bugs (stale label readers + missing count refresh + master profile marking installed apps for removal) — fixed and validated in real GUI passes.
- 🗔 **Dialogs now center over Winzard** (they could open at a screen corner on 4K/DPI setups and go unnoticed).
- 🐌 **winget exit codes read reliably** (a PS 5.1 quirk could turn real failures into fake `[OK]`s) and inner-installer failures always surface as failures, in GUI, CLI and first boot.
- 🧵 `Update ALL` got a WU-services preflight, an inactivity watchdog and a content-based verdict; busy-state now also covers theme/language switching and the verify/undo buttons.
- 🌐 i18n: theme labels, search-result buttons, debloat catalog entries and the whole unattended console honor the selected language; translation audit stays at zero leaks.
- 🖥️ Window geometry restores correctly on multi-monitor setups with negative coordinates; scope/threads/choco preferences persist across sessions.
- 🚑 **Repair Suite works from folders with spaces** (unquoted `for /f` paths broke phase verdicts) — fixed across ES/EN and sources, re-verified with full 17-phase runs.
- ⏎ The unattended console no longer hangs on a final `Read-Host` when stdin is redirected (automation-safe).

### Quality
- ✅ Two complete verification passes (every section, every button, ES+EN, 3 themes) on a real PC, with forensic evidence for each check, plus a VM fire test: unattended install → first boot → **18/18 apps OK**.

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
