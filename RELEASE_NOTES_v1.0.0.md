# 🚀 Winzard v1.0.0 — First public release

> Paste this into the GitHub Release description when publishing the `v1.0.0` tag.

---

## 🪟 Set up your ideal Windows in an afternoon — install, optimize, clean, repair, and even build your own ISO. All from one app.

**Winzard** is an all-in-one command center for Windows 10/11 (PowerShell + WPF). It brings together **everything you do after a fresh install** — and a lot you didn't know you could — with **no command line, no loose scripts, and nothing shady**: under the hood it uses **Microsoft's official winget**.

Bilingual **English/Spanish**, three themes, **no telemetry, no accounts**, open source (MIT). And most importantly: **you're in control** — WPI marks and proposes, but only applies when *you* click.

---

## ⭐ Highlights

### 🔄 Always up to date — for real
A two-group update center powered by `winget upgrade`: **WPI-catalog apps** and **the rest of your PC**, kept separate so nothing gets mixed. One click keeps your programs current — and here's the difference: **WPI verifies the actual installed version after updating** and warns you if it *didn't really change* (typical of self-updating or running apps). No more "it says updated but it's still the old version."

### 🔎 It knows what you already have (smart auto-detection)
- **Installed programs:** scans your PC and marks what's already installed **in green, with its version**.
- **Tweaks:** each tweak shows a **colored dot** — green = *already applied on your PC*, grey = not — plus a live counter ("● N applied · ● M not applied").
- **Bloatware:** each app shows **amber = still installed** (removable) or **green = already gone**, with its own counter.

### 💿 Build your own custom Windows ISO (the star feature)
The expert-level section, now **guided step by step**: an **8-step wizard** with a **visual breadcrumb** and a green **"NOW:"** banner telling you exactly what to do. It integrates **offline**: debloat before install, **driver injection**, your **apps + tweaks** for first boot, **offline winget**, and a tailored **`autounattend.xml`**. Reassembles with **oscdimg**, includes an **ISO verifier** and **smart reminders** about each choice (drivers baked-in vs. manual, the disk-wiping "VM mode", how to leave Rufus…).

### 🎨 Three themes + fully bilingual
Light, Dark, and **Blue (Chris Titus)**. The whole UI, tooltips, dialogs and the repair suite are available in **English and Spanish**.

---

## 🧩 Everything else it does

- **🛒 360+ app catalog** in 22 categories — one-click presets (Gaming, Dev, Multimedia, Essential), save/load profiles, uninstall, download raw .exe/.msi, scope & parallel threads with auto-retry.
- **⚙️ 40+ tweaks** with graduated risk presets (🟢 Safe / 🟠 Balanced / 🔴 Aggressive), reversible, "recommended for *my* PC" based on your hardware.
- **🧹 Appx debloat** for the current user and the system image.
- **🛡️ Windows Update control** — defer / pause 5 weeks / restore defaults / fully disable (services + SoftwareDistribution + scheduled tasks).
- **🩹 17-phase Repair Suite** (bilingual) with auto-triage, manual, plan and dry-run modes.
- **🧩 Windows features** (Hyper-V, WSL2, .NET…) via DISM with detected state.
- **🖥️ Drivers & hardware** — full spec detection (temps included), GPU drivers with **NVIDIA/AMD/Intel always available**, driver backup, hardware-based recommendations.
- **🌐 Search all of winget · Clone PC / Snapshot** to replicate a machine.

---

## 📥 Getting started

1. Download **`Winzard-v1.0.0.zip`** from the Assets below.
2. Extract it to a local folder (e.g. `C:\WPI`).
3. Run **`Iniciar_WPI.bat`** and accept the UAC prompt.
4. Pick your language and theme, mark what you want, review, and click. Done.

📖 Full guide: [README](README.md) · [Español](README_ES.md)

---

## ⚠️ Notes

- WPI **does not bundle any Windows ISO**. To build a custom ISO, you provide the official Microsoft ISO; WPI only personalizes it on your machine.
- System operations require **administrator rights** (WPI self-elevates).
- For tweaks/debloat/repair, testing first in a **virtual machine** and creating a **restore point** is recommended.

**License:** MIT · **Platform:** Windows 10/11 x64 · **Requires:** PowerShell 5.1+ and winget

See the full [CHANGELOG.md](CHANGELOG.md).

---

*If Winzard saves you time, drop a ⭐ on the repo. Thanks for trying it!* 💜
