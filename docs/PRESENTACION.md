<div align="center">

# ⚡ Winzard

### Set up your Windows 10/11 in an afternoon. Install, optimize, clean, repair — and even build your own ISO. All from a single app.

**PowerShell + WPF · Async winget engine · Bilingual EN/ES · 3 themes · No telemetry · Open source**

</div>

---

## 🎯 What is Winzard?

You just installed Windows (or want to tune up the one you have) and the usual ritual begins: download the browser, the media player, the archiver, remove bloatware, tweak a thousand privacy settings, update everything, fight with drivers… hours.

**Winzard turns all of that into clicks.** It's a single command center, with a modern dashboard-style interface, that gathers **everything you'd do after formatting** — and plenty you didn't know you could — with no command line, no loose scripts and **nothing shady installed**: under the hood it uses **Microsoft's official winget**.

It's not just another installer. It's **an installer + optimizer + cleaner + repair tool + ISO builder**, all integrated, in English and Spanish, and designed so **you stay in control** (mark, review, apply — it never makes changes behind your back).

> 💡 **The difference:** inspired by the best of the genre (a nod to Chris Titus's WinUtil with its "Blue" theme), but taken to another level: **real** verification that things actually get applied, per-option state detection, step-by-step guided wizards, and a professional 17-phase repair suite.

---

## 🧩 The sections, one by one

### 🛒 1. 360+ app catalog *(Install)*
The heart of WPI. A curated catalog of **more than 360 applications** organized into **22 categories** (Browsers, Media, Development, Security, Office, Gaming, Utilities…).

- **Check whatever you want and hit INSTALL (N)** — it installs itself, in a chain, via winget.
- **One-click presets:** *Gaming*, *Developer*, *Multimedia*, *Essential*… select the recommended pack instantly.
- **Detect installed:** scans your PC and marks in green what you already have, with its version.
- **Save / Load profile** and **"Last session"**: recover your usual selection.
- **Instant search** by name, category or winget ID.
- Also: **uninstall**, **download the raw .exe/.msi** installer, **validate IDs**, and choose **scope** (whole machine or just your user) and **threads** (1 safe → several in parallel, with automatic retries when two installers clash).

### 🔄 2. Available updates
An honest update center, powered by `winget upgrade`, **split into two groups** so nothing gets mixed:

- **Group 1 — WPI-catalog apps**
- **Group 2 — Other programs on your PC**

You press **"Check updates"** (now also **inside the section**, visible on entry) and see what's available for each group. Each button updates **only its group**.

> ✅ **REAL post-update verification:** WPI doesn't just say "done" because the process finished. After updating, it **checks the installed version** and warns you if it **didn't actually change** (typical of apps that self-update or are running). No more "it says updated but it's still the same."

### 🌐 3. Search all of winget · Clone PC / Snapshot
- **Search winget:** an app outside the catalog? Find it across all of winget and install it from here.
- **Clone PC / Snapshot:** **export** everything installed to a file and **import** it on another PC (or after formatting) to make it identical. Ideal for migrations and building several matching machines.

### ⚙️ 4. Tweaks & settings
More than **40 tweaks** for **privacy, performance and experience**, with a clean **2-column** layout (Chris Titus style, taken further):

- **Graduated presets by real risk:** 🟢 **Safe** · 🟠 **Balanced** · 🔴 **Aggressive** (and *None*). They only **mark**; you review and apply.
- **Per-tweak state detection:** a colored dot tells you at a glance whether it's **already applied** on your PC (green) or not (grey), with a **counter up top** ("● N applied · ● M not applied").
- **Reversible:** almost everything has an undo via **"Revert selected"**.
- **"Apply recommended for MY PC":** WPI looks at your hardware (laptop/desktop, SSD, RAM, GPU) and marks what makes sense for you.
- Every action runs through the **real engine with a forensic log**, and creates a **restore point** if you leave that on.

### 🧹 5. Remove bloatware (Appx)
Removes preinstalled apps (Xbox, Copilot, promotional…) **for your user and from the system image**.

- **Per-app state detection:** amber = **still installed** (removable), green = **already gone**, with a **counter** up top.
- They're **reinstallable** Appx from the Store: nothing irreversible.

### 🛡️ 6. Windows Update control
Four cards to decide **how and when** Windows updates — replicating what WinUtil does, but with **real evidence in the log**:

- **Recommended configuration:** defers feature updates ~1 year and security updates 4 days ("Pro" style).
- **Pause all for 5 weeks.**
- **Restore defaults:** undoes everything and re-enables services and tasks.
- 🔴 **Fully disable:** stops and disables the services (BITS, wuauserv, UsoSvc…), clears `SoftwareDistribution` and disables the scheduled tasks. Reversible with "Restore defaults".

### 🩹 7. Repair · 17-phase Emergency Suite
A **professional repair suite** built in (bilingual EN/ES), with an **anti-false-OK** philosophy. It opens as an interactive administrator console with a clear menu:

- **Full automatic repair**, **Smart repair (auto-triage — only what's needed)**, **Quick inspection**, **Manual mode** (one command per phase), **Guided plan**, **pick specific phases**, and **simulation (dry-run)** that touches nothing.
- **17 phases:** diagnosis & triage, restore point, cleanup, CHKDSK, disk optimization (TRIM/defrag), DISM, SFC, WMI repair, Store apps & startup, index & caches, certificates & time, network reset, GPO policies, Windows Update, winget, devices/drivers, and final cleanup with an **HTML report**.
- From the GUI you can **launch the full console** or **individual phases** in a grid, with nothing to open by hand.

### 🧩 8. Windows features
Enable or disable **optional components** (Hyper-V, **WSL2**, .NET, Sandbox…) via **DISM**, with **detected state**, a forensic log and reversible. It warns you if a feature needs a reboot or only exists on Pro/Enterprise.

### 🖥️ 9. Drivers & hardware
A panel that **detects your machine** (CPU, RAM, disks with **SMART temperatures**, motherboard, displays, battery and health) and gives you useful shortcuts:

- **GPU drivers:** detects the vendor and **always offers all three** — **NVIDIA** (NVIDIA App), **AMD** (Adrenalin) and **Intel** (DSA) — highlighting the one you have.
- **Backup of your current drivers** (.inf) to reinstall them or inject them into an ISO.
- **Hardware-based recommendations** (e.g. GPU-Z, Afterburner, CrystalDiskInfo, HWiNFO…).

### 💿 10. Build a custom Windows ISO
The expert level, now **guided step by step** so you never get lost:

- **8-step wizard** with a **visual breadcrumb** (you always know where you are and what's left) and a **"NOW:"** banner that tells you exactly what to do in each step.
- **Choose your ISO → detect editions → pick one (faster) or all → output and name.**
- Integrates **offline**: **debloat** before installing, **driver injection**, your **apps + tweaks** for first boot, **offline winget**, and an **`autounattend.xml`** for unattended install (local account, Win11 requirement bypass, etc.).
- Reassembles the image with **oscdimg** and includes an **ISO verifier** plus **Rufus** and **virtual machine** guides.
- **Smart reminders:** warns you about the consequences (drivers baked-in vs. manual, the "VM mode" that **wipes disk 0**, how to leave Rufus…). Nothing is touched until the last step, where you confirm.

---

## ✨ What makes it feel premium (everywhere)

- 🌍 **Truly bilingual EN/ES:** interface, dialogs, tooltips and the repair suite.
- 🎨 **3 themes:** Light, Dark and **Blue (Chris Titus)**.
- 💬 **Descriptive tooltips** on every control: you're never left wondering what a button does.
- 📋 **Live log + forensic log** per session: watch what happens in real time, and it's saved.
- 🔒 **You're in charge:** WPI **marks and proposes**, but **only applies when you click**. It creates a restore point when appropriate.
- 🛠️ **Async engine** that **never freezes the window**: parallel installs, per-app *watchdog*, retries on clashes, optional Chocolatey *fallback*.
- 🔡 **Built with rigor:** a full verifier (parsing, suite hashes, encoding, translation coverage) that runs in **CI on every change**. Zero Spanish text leaking into the English version, zero mojibake.
- 🔐 **No telemetry, no accounts, nothing hidden.** Open source (MIT). It self-elevates to Administrator only for what genuinely needs it.

---

## 🚀 Getting started is trivial

1. Download the project.
2. Double-click **`Iniciar_WPI.bat`** (it just asks for administrator permission).
3. Mark what you want, review, and click. **Done.**

> Requirements: Windows 10/11, PowerShell 5.1+ (ships with Windows) and winget (App Installer, already included in modern Windows). To **build an ISO**, optionally Windows ADK (oscdimg) — WPI installs it from within the app.

---

<div align="center">

**Winzard** — because tuning up Windows shouldn't cost you an afternoon.

⭐ If it saves you time, leave a star on the repo.

</div>
