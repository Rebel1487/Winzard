# Changelog

All notable changes to **Winzard** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

---

## [1.3.0] — 2026-08-16  *(app build v7.4)*

The **minimum-privilege release**. Winzard no longer asks for administrator rights just to open, and the integrity manifests of both Repair Suites are correct again. This is a **security and trust release**: no new features, everything you already had, asked for more honestly.

### Changed
- 🔐 **Winzard starts as a standard user.** The two global pre-emptive elevation points have been removed: `Iniciar_WPI.bat` no longer relaunches itself with `Start-Process -Verb RunAs`, and `WPI_Moderno.ps1` no longer re-spawns elevated and exits at boot. You can now browse the full app catalog, search, read the manuals, inspect hardware, view the system summary and read logs **without granting any permissions at all**.
- 🧾 **No permission warning at startup at all.** The old alarm dialog that told you to *"close and reopen accepting the UAC prompt"* is gone. Winzard now says nothing about permissions when it opens: the **window title** shows whether you are a *Standard user* or an *Administrator*, and each operation asks for elevation when it actually needs it. One less window between you and the app.
- 🌍 **Language picker on launch.** Winzard used to start in Spanish on a first run regardless of your system, so an English speaker opened it and found an interface they couldn't read. A quick one-click card now lets you choose English or Spanish every time you launch, with your previous choice (or your Windows language, on a first run) already highlighted. Everything — interface, manuals, logs and the startup splash — loads in that language.
- 🎨 **Premium dialogs instead of Windows message boxes.** Winzard's own WPF dialog: rounded card, accent gradient, large buttons, draggable, Escape to dismiss. Because the language is known from the start, **no dialog needs to be duplicated in two languages any more**.
- 📖 **README installation instructions** updated: there is no UAC prompt on launch any more.

### Added
- 🆕 **`Request-WpiElevation`**: elevation now happens **only** on an explicit user request. UAC refusal (exception 1223) is handled calmly instead of breaking the app.
- 📄 **`SECURITY.md` now documents the full privilege model**: what works without admin, what asks for it and why, **every scheduled task Winzard can create** (`WPI_ReintentoApps`, `WPI_ReintentoManual`, `WPI_Mantenimiento_Mensual` — with the fact that the first one deletes itself), the justification for `ExecutionPolicy Bypass`, and an explicit list of what Winzard **never** does: it never modifies your UAC settings, never uses UAC bypass techniques, never installs services or background agents, never sends telemetry.
- 🏷️ **Authorship and attribution files**: `NOTICE`, `AUTHORS`, `CITATION.cff` (enables GitHub's "Cite this repository"), `TRADEMARK.md` (bilingual trademark policy) and `THIRD_PARTY_NOTICES.md` (documents that Winzard bundles no third-party code, and credits the projects that inspired it).
- ✍️ **SPDX headers** (`SPDX-License-Identifier`) on 100 % of the project's own PowerShell sources.

### Fixed
- 🧪 **`/dry` really touches nothing now.** The dry-run mode is documented as *"shows what it would do, touching nothing"*, yet phase 16 still wrote an HTML report to disk **and opened it in your browser** — in four separate code paths, in both suites. A simulation that writes files and pops up windows is not a simulation. It now prints what it *would* have generated and writes nothing.
- 🔏 **Integrity of 8 distributed files.** `Suite_Reparacion_ES/HASHES.sha256` and `Suite_Reparacion_EN/HASHES.sha256` declared stale hashes for 4 + 4 shipped `.bat` files (`Suite_Reparacion_TodoEnUno` / `Repair_Suite_AllInOne`, phases 01, 05 and 14). A user verifying integrity as the README instructs would have got a mismatch. **Both manifests regenerated from the real files.**
- 🧱 **36 stale build artifacts.** The `build/out` `.bat` files of both suites carried LIBRARY and BRAIN blocks out of sync with the canonical `src/` — they were missing the v3.2 `set "SELF=%~f0"` fix. The shipped root files were always correct, but anyone regenerating from `build/out` would have reintroduced the bug. **Both suites fully regenerated.**
- 🔤 **`Manuales/generar_manual_completo.ps1`** contained non-ASCII characters **without a BOM**, so Windows PowerShell 5.1 read it as ANSI and mangled the accents. BOM added, per the project's own encoding rule.
- 🔤 **BOM removed** from `Manuales/en/00_COMPLETE_MANUAL.md` and `Manuales/es/00_MANUAL_COMPLETO.md` (data files must not carry one).
- 🕵️ **Developer paths removed** from `docs/lanzamiento/PASOS_PUBLICAR.md`, which exposed the developer's Windows username in public documentation.

### Verification
- ✅ `Verificar_Proyecto.ps1`: **28/28 OK, 0 warnings, 0 failures** (v1.2.0 shipped with **5 failures**).
- ✅ `Verificar_Proyecto.ps1 -ConsoleSmoke`: **38 OK, 0 failures** — including `/help`, `/version`, `/selftest` and `/dry` on both suites and the WPF GUI self-test.
- ✅ Full parse of `WPI_Moderno.ps1` clean after every change.

---

## [1.2.0] — 2026-07-11  *(app build v7.4)*

The **polish release**: everything new was battle-tested in two more live-fire installs (Windows 11 **and** Windows 10 ISOs built by Winzard itself, installed 100 % unattended in VMs) plus runtime verification on a real PC.

### Added
- 🛡️ **Premium unattended first boot**: the console is pinned **always-on-top** so nothing covers it; the **screen never sleeps and the PC never suspends** while it works (process-level `SetThreadExecutionState` — it evaporates on reboot and never touches your power settings); a **framed premium status panel** tells you exactly what is happening and what not to touch; the window is **centered and sized for 1080p/1440p/4K** at any DPI.
- ⚡ **Premium app opening**: installed-app detection now runs **under the startup splash** with its own stage texts — the window appears only when everything is truly loaded, ready to click instantly (measured: interactive in ~25 ms after reveal).
- 💿 **Rufus with the ISO preloaded**: the "Write to USB" button now launches Rufus with `-i <iso>` so your ISO is already selected (clipboard fallback for older Rufus builds).
- 🍫 **Chocolatey fallback that actually lands**: winget IDs are mapped to a derived choco candidate (`7zip.7zip` → `7zip`) confirmed with `choco search --exact` before installing, and the whole fallback has a **20-minute cap with process-tree kill** so a stuck choco can never hang the batch.
- 💜 **Optional donations**: `FUNDING.yml` (GitHub Sponsors) and a support section in both READMEs. Everything stays free, always.

### Fixed
- 🩹 **Corrupted winget cache on freshly installed Windows (`0x8A15003F`)**: now classified as retryable — Winzard runs `winget source update` and retries those apps once, in the first-boot engine, the GUI worker and the deferred retry script alike.
- 🖥️ **Window geometry on small screens**: saved (or default) window size is now clamped to the real screen — moving from a big monitor to a smaller display can no longer leave buttons unreachable off-screen (two-part fix, including the XAML minimum width).
- 🎮 **Xbox debloat protects `Microsoft.Xbox.TCUI`**: the framework was retired from the Store and cannot be reinstalled, so Winzard refuses to remove it (honest notice instead of an irreversible loss).
- 🧘 **Calm desktop after deferred installs**: the deferred first-sign-in installer (e.g. Discord) now runs the same "serene experience" cleanup, so the desktop ends clean too.

### Docs
- 📸 **Seven fresh README screenshots** (hero, apps, tweaks, repair, ISO wizard, ES/EN side-by-side) captured at high resolution with this exact build.

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
