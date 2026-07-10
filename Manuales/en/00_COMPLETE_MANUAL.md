# WINZARD — COMPLETE MANUAL (English)

All the Winzard manuals in a single document. Each section explains what it is, what every button does and how to use it step by step. Each manual is also available separately in this folder — and you can read them all INSIDE Winzard, from the Quick start buttons.

## Index
- [01 · Quick start (easy mode)](#01-quick-start-easy-mode)
- [02 · Apps catalog & installation](#02-apps-catalog-installation)
- [03 · Search everything (global)](#03-search-everything-global)
- [04 · Tweaks and settings](#04-tweaks-and-settings)
- [05 · Gaming Optimizer](#05-gaming-optimizer)
- [06 · Windows Update control](#06-windows-update-control)
- [07 · Remove bloatware (Appx)](#07-remove-bloatware-appx)
- [08 · Repair suite](#08-repair-suite)
- [09 · Windows features](#09-windows-features)
- [10 · Drivers and hardware](#10-drivers-and-hardware)
- [11 · Recovery hub](#11-recovery-hub)
- [12 · Clone PC / Snapshot](#12-clone-pc-snapshot)
- [13 · Create a custom Windows ISO (advanced)](#13-create-a-custom-windows-iso-advanced)
- [14 · System summary, log viewer and journal](#14-system-summary-log-viewer-and-journal)
- [15 · Themes, language, guides and command line](#15-themes-language-guides-and-command-line)

---

# 01 · Quick start (easy mode)

## What it is
Winzard's welcome screen. It sums up everything you can do in **7 guided steps**, designed so anyone — with no technical background — can get their Windows ready in a few clicks. The left sidebar is the "expert mode": it contains every section with full control. Quick start never runs anything on its own: each button takes you to its section, where you choose and confirm.

When Winzard opens you'll first see a **loading screen with a progress bar**: the app is preparing the catalog, the detectors and the install engine. Once it disappears, Winzard is fully ready to use (no half-drawn windows).

## Button by button
| Element | What it does when pressed |
|---|---|
| **Winzard manuals (button row)** | Every manual has its own small button ("01 · Quick start", "02 · Apps catalog"…) and the **Complete manual** stands out. Clicking one opens the manual in a **premium reading window inside Winzard**: you read without leaving the app or opening folders. The viewer has "Close" and, if you need it, "Open the manuals folder". |
| **1. Install your programs → "Go to Programs"** | Takes you to the catalog of 350+ apps. Mark the ones you want and press INSTALL. |
| **2. Optimize Windows (Tweaks) → "Go to Tweaks"** | Takes you to the 86 privacy and performance settings, all reversible. Inside you have "Apply recommended for MY PC". |
| **3. Get your PC ready to play (Gaming) → "Go to Gaming"** | Opens the Gaming Optimizer: honest pre-check, 100 % reversible per-session Game Mode, overlay radar and real measurement. No FPS promises. |
| **4. Remove bloatware → "Go to Clean"** | Opens the section to remove preinstalled apps (reinstallable from the Store). |
| **5. Repair Windows → "Go to Repair"** | Opens the repair suite (SFC, DISM, network, Windows Update, DNS…). |
| **6. Create your custom ISO → "Go to Create ISO"** | Opens the step-by-step wizard to build a Windows ISO with your apps, tweaks, debloat and drivers already integrated. |
| **7. Check your PC status → "Go to Summary"** | Opens the system summary: disk and RAM status, protection, before/after snapshot and exportable diagnostic. |

## Recommended first-time walkthrough
1. Press **"Go to Summary"** and create a restore point if the panel warns you that protection is off.
2. Come back to Quick start and follow steps 1 → 2 → 3 → 4 in order.
3. Steps 5-7 are there for when you need them: repairing, building an ISO or checking status.

## Practical examples
- **"Just installed Winzard — where do I start?"**: wait for the loading bar to finish, press the highlighted **Complete manual** button and skim it in the reading window; then follow steps 1 → 2 → 3 → 4.
- **"I only want to install my programs"**: **"Go to Programs →"**, mark yours and press INSTALL. You don't need anything else.
- **"I don't get what the Gaming section does"**: press its small **"05 · Gaming Optimizer"** button in the manuals row: its manual opens inside Winzard, every button explained.

## Safety
Nothing on this screen changes the system. Everything you run afterwards is reversible, gets recorded in the change journal and can be undone from its own section or from the Recovery hub.

---

# 02 · Apps catalog & installation

## What it is
Winzard's bulk installer: **350+ applications** organized by sidebar categories (Browsers, Essentials, Multimedia, Gaming, Emulators, Development, Local AI, Network & Remote, Office, Self-Hosted, Utilities, Security, Productivity, Disks & Backup, Cloud & Sync…). It uses Microsoft's **official winget engine**: links are managed by the winget repository, so they never expire.

## Top row (always visible)
| Element | What it does |
|---|---|
| **Search** | Live-filters the catalog by name, ID or description. |
| **Presets: Gaming / Developer / Multimedia / Essential** | Marks a curated set of apps for that profile at once. A preset **replaces** the previous selection (profiles never mix by accident). |
| **Last session** | Restores the selection you had last time. This one **adds** to whatever you have marked. |
| **Save / Load** | Saves your current selection to a file, or loads a saved one. "Load" accepts `.txt` lists (one ID per line) and also `.json` — including the winget exports produced by "Clone PC / Snapshot". |
| **Detect installed** | Detects which catalog apps are already on your PC and highlights them. |
| **Clear selection** | Unmarks everything. |

## Bottom bar (actions)
| Button | What it does |
|---|---|
| **Threads** | Simultaneous installs: "1x safe" = sequential (recommended); 2-3 speeds things up, with automatic retry if two installers collide. |
| **Scope** | Per-machine or per-user install (Auto picks the best per app). |
| **Fallback Choco** | If winget fails for an app, retries with Chocolatey (optional). |
| *(The three settings above are **remembered between sessions**: set them once to your liking and you're done.)* | |
| **Mark visible / Unmark** | Marks everything currently filtered on screen / clears the selection. |
| **Mark installed** | Marks the apps you already have (useful for updating or cloning). |
| **Uninstall** | Uninstalls the marked apps (with confirmation). |
| **Download .exe/.msi** | Doesn't install: downloads the original installers to Winzard's Downloads folder. |
| **Validate IDs** | Checks against winget that every marked ID exists (avoids surprises). |
| **Check updates / Update ALL** | Looks for updates of what's installed / updates everything at once. "Update ALL" first checks that the Windows Update services are available, watches the batch so it can't hang forever, and tells you the truth at the end: if an inner installer failed, you'll see it as a failure (no fake successes). |
| **INSTALL (n)** | Installs the *n* marked apps, with progress, retries and live log. Every install has an **anti-hang watchdog** (if winget gets stuck on an app, it's cut off with a notice and the batch moves on) and, if any app fails due to a network drop, the engine **waits for connectivity and retries just those** once. |
| **LIVE LOG** | Expands the live console with the detail of every operation. |

## Sibling sidebar sections
- **Search in winget (all)**: search and install any app from the full winget repository, even outside the catalog.
- **Available updates**: two groups — catalog apps with a pending update, and other programs on your PC.
- **Clone PC / Snapshot**: see manual 12.

## Typical walkthrough
1. Pick a preset (or search and mark by hand).
2. Press **Validate IDs** if you marked a lot of apps.
3. Press **INSTALL (n)** and follow the progress in the LIVE LOG.
4. If something fails, the engine retries it at the end and reports honestly; the forensic log is saved under `logs\`.

## Practical examples
- **"Freshly formatted gaming PC"**: **Gaming** preset → **Validate IDs** → **INSTALL (n)**. Discord, Steam and friends install themselves while you watch the LIVE LOG.
- **"I need installers for a PC with no internet"**: mark the apps → **Download .exe/.msi**: the original installers land in Winzard's Downloads folder, nothing gets installed.
- **"My PC is full of old versions"**: **Detect installed** → **Check updates** → review the list → **Update ALL**. The final summary tells you the truth about each one.
- **"An app isn't in the catalog"**: sidebar → **Search in winget (all)**: search the entire winget repository and install right there.
- **"I want to repeat this selection every time I format"**: **Save** → keep the file; some day later, **Load** (a `.txt` or a winget `.json` both work) and install.

## Notes
- Some emulator apps include **mini-guides** (the "Guides" panel): the catalog flags them.
- Nothing installs until you press INSTALL; the selection never comes pre-marked.

---

# 03 · Search everything (global)

## What it is
A global finder that locates **anything inside Winzard** — catalog apps, tweaks, bloatware or Windows features — and jumps to its section with one click.

## How to use it
1. Type at least **2 letters** and press **Search** (or Enter).
2. Results appear grouped by type (app, tweak, bloatware, feature).
3. Click a result: Winzard jumps to its section and highlights it.

## Useful examples
- "telemetry" → lists the related privacy tweaks.
- "xbox" → catalog apps + Xbox bloatware + Game Bar tweaks.
- "hyper-v" → the matching Windows feature.

## Notes
- If there are no results, try another term or check the spelling (search in Spanish or English depending on the interface language).
- The finder never runs anything: it only navigates.

---

# 04 · Tweaks and settings

## What it is
**86 Windows settings** (privacy, performance, UI, network, gaming, system) that can be applied and **reverted one by one**. Every tweak has its toggle, its state color and its real-state detector: Winzard checks in your Windows whether the setting is truly applied — it never assumes.

## The color code (legend at the bottom of the list)
- **Green + toggle on** = already applied on this PC (truly detected).
- **Amber** = advanced tweak, not applied (apply with care; its tooltip explains why).
- **Gray** = one-shot action with no state (e.g. a cleanup).
- **Normal color** = safe tweak, not applied.

The toggle is also your **selection**: turn on what you want to apply, turn off what you don't. "APPLY" skips (with a notice) whatever is already applied, so nothing ever re-runs by mistake.

## Button by button
| Button | What it does |
|---|---|
| **Search box** | Live-filters the 86 tweaks. |
| **Safe / Balanced / Aggressive presets** | Mark sets with different impact levels (nothing applies until you press APPLY). |
| **APPLY SELECTED (n)** | Runs only what is marked and still missing. Each tweak reports its result. |
| **REVERT SELECTED** | Runs each marked tweak's official "undo" and returns it to its default value. |
| **Re-detect state** | Re-reads the REAL state of every tweak in your Windows and refreshes colors and toggles. |
| **Verify all** | Generates an HTML report verifying every setting, detector by detector. |
| **Mark missing recommended** | Marks the recommended safe tweaks that are not applied yet. |
| **Apply recommended for MY PC** | Analyzes your hardware (laptop/desktop, GPU, disk…) and applies only what is safe for YOUR specific case. |
| **Export catalog** | Saves the full tweak list (Markdown + JSON) under `logs\`, describing what each one does. |

## Typical walkthrough
1. Press **Re-detect state** to see your PC's real picture.
2. Press **Mark missing recommended** (or pick a preset, or mark by hand).
3. Review anything amber: its tooltip and ℹ expander explain what it does and when to avoid it.
4. Press **APPLY SELECTED** and read the summary.
5. Changed your mind? Mark it and press **REVERT SELECTED**: it returns to the Windows default.

## Practical examples
- **"I want more privacy without risk"**: Re-detect state → **Mark missing recommended** → APPLY. In a minute, telemetry, ads and suggestions are gone — all reversible.
- **"It's my mum's PC and I want zero trouble"**: press **Apply recommended for MY PC** and that's it — Winzard checks whether it's a laptop or desktop, which GPU and disk it has, and applies only what's safe for that hardware.
- **"I applied something and now I don't like the context menu"**: search "menu" in the search box, switch that tweak on and press **REVERT SELECTED** — back to the exact Windows factory value.
- **"Is this really applied?"**: press **Verify all** and open the HTML report: every setting with its detector, expected value and real value, in green or red.
- **"I want the whole list to read calmly"**: **Export catalog** drops a Markdown and a JSON with all 86 tweaks and their explanations under `logs\`.

## Reversibility and safety
- Almost every tweak has an official 1:1 undo (the REVERT button itself). The few that don't (a temp cleanup, a restore point) say so clearly.
- Everything is recorded in the **change journal**, and the "Rescue pack" (Recovery hub) stores your tweak profile with the real detected state.
- Tip: create a restore point before a big batch (the first tweak in the list does it for you).

---

# 05 · Gaming Optimizer

## What it is
The **honest** way to get a PC game-ready. No FPS promises here: we work on stability, latency, frametimes and micro-stutter, with everything reversible and verified. It is organized in 4 sub-sections (pills): **Prepare · Play · Automate · Measure**, plus a one-click button on top.

## At the very top
| Element | What it does |
|---|---|
| **Optimize for gaming (easy mode)** | One safe click: refreshes the check-up, reviews Windows Game Mode and delegates ProBalance to Process Lasso if installed. |
| **View plan (nothing is changed)** | Shows EXACTLY what enabling (or restoring) Game Mode would do: power plan and processes with their PIDs. Changes nothing. |

## PREPARE
- **Pre-check (read-only):** GPU, CPU, RAM, disk, HAGS and VRR, state of the catalog's gaming tweaks (green = applied). It analyzes and recommends; it changes nothing.
- **Overlay radar:** detects Game Bar, Discord, NVIDIA Overlay, OBS, RivaTuner and the Steam overlay (green/amber dots); tooltips tell you where each one is switched off. Winzard never touches them.
- **Network for online play → "Measure network (10 s)":** 10 real pings to 1.1.1.1 in the background; you get average, min, max, jitter and loss with an honest verdict. The UI never freezes.

## PLAY
- **Per-session Game Mode (100 % reversible):** enabling it switches the power plan to maximum and PAUSES (never kills) the processes on YOUR list; disabling it returns everything exactly as it was.
  - **Pause list:** you pick the processes; nothing comes pre-checked; critical system processes are protected and cannot be paused.
  - **Mute notifications during the session:** optional toggle; stores your exact previous value and restores it on exit.
  - If the app were closed mid-session, on reopening it detects the pending session and offers **"Restore everything"**.
- **Real-time engine (delegated):** real-time work (ProBalance, priorities) is delegated to **Process Lasso**; Winzard deliberately ships no scheduler of its own.
- **Presets:** *Competitive* (max power plan + ProBalance + your pause list) and *Balanced* (ProBalance only). They only mark options: nothing runs until you enable the session.

## AUTOMATE
- **Automatic game detection (off by default):** with the master switch on, it watches your associated games (light check every 5 s) and enables/reverts Game Mode by itself.
- **Detected installed games:** scans Steam, Epic, GOG, Ubisoft, Xbox/Game Pass, Riot, EA, Battle.net and any game ever launched (Windows registry). One-click **Associate** button per game.
- **Detected launchers:** their background processes are candidates for the pause list; nothing comes pre-checked.

## MEASURE
- **Honest measurement:** with PresentMon's CONSOLE edition it captures 60 s of frametimes to `logs\frametimes_<date>.csv` and reports average, p95 and p99. If the binary is missing, it says so clearly and links the official downloads.
- Buttons to install **PresentMon / CapFrameX** via winget (trusted external measurement).

## Practical examples
- **"I'm playing NOW and don't want to configure anything"**: press **Optimize for gaming (easy mode)** — fresh check, Game Mode reviewed and ProBalance delegated if you have Process Lasso. One click and play.
- **"I want game mode to kick in ONLY when I open my shooter"**: under AUTOMATE press **Associate** next to your detected game, pick the *Competitive* preset, flip the master switch… and forget: the session activates when the game opens and everything reverts when it closes.
- **"It stutters and I don't know if it's the network"**: under PREPARE press **Measure network (10 s)** — if jitter and loss look fine, your connection isn't the problem; go to MEASURE and capture 60 s of frametimes with PresentMon to see the microstutter in real data (average, p95, p99).
- **"What EXACTLY will a session touch?"**: press **View plan (touch nothing)**: it lists the power plan and every process (with PID) that would be paused. Full transparency before deciding.
- **"Power went out mid-session"**: reopen Winzard — it detects the pending session and offers **Restore everything**, leaving the power plan and processes exactly as they were.

## Rules of this section (by design)
No FPS promises · no "RAM cleaners" · no custom scheduler · no automated CPU affinity · pausing means suspending with Windows' native mechanism and ALWAYS resuming · everything reversible and recorded in the journal.

---

# 06 · Windows Update control

## What it is
The update control center: **you decide how and when Windows updates**, through real system policies. Every action runs when you press its button, is verified, and gets recorded in the forensic log. Nothing is permanent: the defaults button reverts everything. Requires administrator rights.

## The cards (each with its "Apply" button)
| Action | What it does | Risk |
|---|---|---|
| **Recommended configuration (defer updates)** | Defers updates by a sensible margin: you still get patches, just a few days after release, avoiding day-one Microsoft bugs. | Safe |
| **Pause all updates for 5 weeks** | Full temporary pause (the maximum Windows allows by policy). | Safe |
| **Windows Update defaults** | Removes any policy applied from this list and returns Windows Update to factory behavior. | Safe |
| **Disable Windows Update completely** | Turns off the service and its policies. Asks for confirmation with a clear warning: leaving Windows without security patches is risky; use it only if you know what you are doing (lab machines, test VMs…). | Advanced (red border) |

## Quick links
Buttons that open the relevant Windows Update Settings pages directly.

## Typical walkthrough
1. Press **Apply** on "Recommended configuration": the sweet spot for most people.
2. Launch weekend or travelling? "Pause for 5 weeks".
3. Want everything back as it was? **Defaults** and done.

## Practical examples
- **"Windows updated me mid-match"**: apply **Recommended configuration** — patches still arrive, just with a few days' rest and never by surprise.
- **"Travelling with the laptop, no surprises please"**: **Pause for 5 weeks** before leaving; when you're back, **Defaults** and Windows catches up.
- **"I changed something months ago and don't remember what"**: press **Windows Update defaults** — it wipes ANY policy from this list and returns Windows Update to factory behaviour, no memory required.
- **"It's a test VM and must never update"**: **Disable completely** (confirm the red warning). Only for machines that truly don't need security patches.

## Reversibility
Every action in this section is reverted by "Windows Update defaults". Everything is recorded under `logs\`.

---

# 07 · Remove bloatware (Appx)

## What it is
Cleaning up Windows' **preinstalled apps** (Xbox, news, maps, promos…). They are Appx packages: removing them frees space and noise, and **all of them are reinstallable from the Microsoft Store**.

## How to read the list
- **Toggle on + green** = that app is ALREADY removed from your PC (real detected state).
- **Toggle off** = still installed.
- The **REMOVE (n)** button counts only what is actionable: marked AND still installed. It never acts twice on something already removed.

## Button by button
| Button | What it does |
|---|---|
| **Mark recommended** | Marks the typical safe set (promos, casual games, news…). |
| **Mark all / Unmark** | Quick-select the whole list / clear it. |
| **REMOVE (n)** | Uninstalls the marked-and-installed packages, with live log. |
| **Restore** | Reinstalls what is recoverable (via Store/Provisioned) of what you removed. |
| **Save / Load profile** | Saves your debloat selection with the real state, or loads a saved one. |

## Typical walkthrough
1. Press **Mark recommended** and review the list (every entry has its description).
2. Press **REMOVE (n)** and confirm.
3. Missing something? Find it in the Microsoft Store and reinstall it, or use **Restore**.

## Practical examples
- **"New PC full of junk"**: **Mark recommended** → **REMOVE (n)** → confirm. Two clicks and promotions, news and filler games are gone; everything reinstallable.
- **"I removed Sound Recorder and now I need it"**: press **Restore** (or find it in the Microsoft Store): back in seconds.
- **"I want my brother's PC cleaned the same way"**: on your PC, **Save profile**; on his, **Load profile** → REMOVE. Identical cleanup on both.
- **"I'm a gamer — should I remove the Xbox stuff?"**: if you use Game Bar or Game Pass, do NOT mark the Xbox group (the list describes it); if you never game through the Store, mark away — reinstallable like everything else.

## Safety
- Nothing comes pre-marked.
- No system components are touched: only reinstallable user Appx apps.
- Everything is recorded in the change journal and the forensic log.

---

# 08 · Repair suite

## What it is
Windows repair tools **all in one place**. The panel has three areas:
1. **Interactive console (full menu)**: the 17-phase suite with its own menu.
2. **Individual phases (00-16)**: each phase with its card and its **Launch** button — diagnosis, restore point, cleanup, CHKDSK, disk optimization, DISM, SFC, WMI, Store & Start menu, search & caches, certificates & time, network, GPO policies, Windows Update, winget, devices and final report. Before anything launches you get a **confirmation centered over Winzard**.
3. **Quick system tools**: one-click repairs that don't need the console (table below). They run one at a time in the async engine, with a full log and a Cancel button.

Requires administrator rights (Winzard elevates itself).

## Quick system tools
| Tool | What it does |
|---|---|
| **Check system files (SFC)** | `sfc /scannow`: verifies and repairs damaged system files. |
| **Repair Windows image (DISM RestoreHealth)** | Repairs the component store SFC relies on. The logical order: DISM first if SFC couldn't fix things. |
| **Reset the network (Winsock/TCP-IP/DNS)** | Resets the network stack and flushes DNS: the classic fix for "weird internet". |
| **Repair Windows Update (clear cache)** | Stops the update services, clears their cache and restarts them. |
| **Clear the Microsoft Store cache** | `wsreset` and related fixes for a Store that won't download. |
| **Rebuild the search index** | Windows Search from scratch: for broken or incomplete searches. |
| **Repair / Reset winget** | Restores the install engine to a clean state if winget gets stuck. |
| **Schedule monthly maintenance** | Creates a scheduled task for cleanup + report once a month. |
| **DNS: Cloudflare / Quad9 / Google / OpenDNS** | Switches your DNS to a fast or filtered provider (Quad9 filters malware; OpenDNS has an optional family filter). |
| **DNS: back to automatic** | Returns DNS to the router's DHCP (undoes any of the above). |
| **Silence Microsoft Edge** | Removes Edge auto-starts and shortcuts and disables its background startup by policy. Edge stays installed; reversible. |

## Typical walkthrough (unstable system)
1. **DISM RestoreHealth** → wait for it to finish.
2. **SFC** → repeat if it repaired something.
3. Reboot. If the problem was network-related: **Reset the network** and reboot.

## Practical examples
- **"Windows is acting weird and I don't know why"**: launch **Phase 00 (Diagnosis & triage)** — it's harmless, checks disks, space and events and tells you where to start. For the full treatment, the **Interactive console** in auto mode walks the 17 phases and leaves an HTML report with before/after health.
- **"Pages take ages to resolve"**: Quick tools → **DNS: Cloudflare** (or Quad9 for malware filtering). Regret it? **DNS: back to automatic** and done.
- **"The Store won't download"**: **Clear the Microsoft Store cache** and try again; if winget is the sick one, **Repair / Reset winget**.
- **"I want the PC to look after itself"**: **Schedule monthly maintenance**: one task a month with cleanup and a report, no remembering required.
- **"Edge keeps popping up everywhere"**: **Silence Microsoft Edge** — auto-starts and shortcuts gone, reversible with its own button.

## The suite embedded in the ISO
The "Create ISO" wizard ships the **Repair suite** at `C:\WPI_Suite` of the installed Windows (ES or EN version depending on language), with its own menu so you can use it without Winzard.

## Safety
All of them are official Windows tools orchestrated with verification; the DNS and Edge changes are reversible with their own button.

---

# 09 · Windows features

## What it is
The manager for Windows **optional features** (Hyper-V, Windows Subsystem for Linux, .NET 3.5, Sandbox, SMB…), with each one's real state detected on your machine.

## How it works
- Every feature shows its current state (enabled / disabled) genuinely read via DISM.
- **Enable** and **Disable** buttons per feature: these are **one-shot actions with confirmation and verification** (by design this section uses buttons, not toggles: each change may require a reboot and deserves individual confirmation).
- After each action the panel **re-scans** and shows you the resulting real state.

## Typical walkthrough
1. Find the feature (or arrive from "Search everything").
2. Press **Enable** or **Disable** and confirm.
3. If Windows needs a reboot, the panel tells you clearly.

## Practical examples
- **"I want to try Linux without leaving Windows"**: enable **Windows Subsystem for Linux (WSL)** → reboot if asked → install a distro from the Store.
- **"I need a quick virtual machine"**: enable **Hyper-V** (needs Windows Pro) or **Windows Sandbox** to test programs without dirtying your PC.
- **"An old program asks for .NET 3.5"**: enable it here and done — no shady installers from the internet.
- **"What do I actually have enabled?"**: just look: every feature's state is read from your Windows with DISM, not guessed.

## Safety
- No batch changes: each feature is handled individually and verified.
- Disabling a feature deletes no data: you can re-enable it whenever you want.

---

# 10 · Drivers and hardware

## What it is
The section to keep your **drivers up to date and backed up**, with GPU detection and hardware-based recommendations.

## Button by button
| Element | What it does |
|---|---|
| **Detected GPU + its official app** | Detects your graphics card and offers the right button: **NVIDIA App** (official site), **AMD Software: Adrenalin** (official site; AMD doesn't ship via winget) or **Intel Driver & Support Assistant** (winget). |
| **Open official driver page** | Goes to the detected vendor's download page. |
| **Other vendors** | Always-available buttons for NVIDIA / AMD / Intel even if the GPU isn't identified. |
| **Export this PC's drivers** | Copies every installed driver (.inf with its folders) to a folder of your choice: your safety net before formatting and the raw material to inject into an ISO. |
| **Hardware recommendations** | Marks recommended catalog apps for your machine (e.g. vendor utilities). |

## Relation to "Create ISO"
The official **`Drivers`** folder in Winzard's directory is what the ISO wizard uses to **inject drivers** into the image: export your PC's drivers there and your freshly installed Windows will boot with network and chipset ready.

## Practical examples
- **"Formatting this weekend"**: **Export this PC's drivers** to a USB. After formatting, Windows gets network and chipset with zero hunting — and if you build your ISO with Winzard, inject them and skip even that.
- **"No idea which graphics card I have"**: the section detects it and gives you the EXACT button for its official software (NVIDIA App / Adrenalin / Intel DSA). No fake "driver booster" sites.
- **"Work laptop acting weird after a driver"**: always download from the official vendor button; never third parties.

## Safety
- Downloading/installing drivers always goes through the vendor's **official** sites or installers.
- Exporting changes nothing: it only copies.

---

# 11 · Recovery hub

## What it is
Your **safety net**. This is not "repairing the system" (that's the Repair suite): this is **going back** using your copies. Every option explains what it is, how it works and what will happen before you press anything.

## Button by button
| Element | What it does |
|---|---|
| **RESCUE PACK (one click)** | Freezes ALL your safety nets NOW into a `Rescate_<date>` folder inside `Restauracion\`: a system restore point, the tweak profile with the REAL detected state, the full app list (winget export), copies of the change journal and parked autoruns, plus a README with instructions. Takes 30-90 s, **changes nothing** (only creates copies) and VERIFIES the content before giving the OK. |
| **STATE OF YOUR SAFETY NETS (live)** | Shows live whether you have a restore point, system protection, journal, etc. |
| **Load tweak profile** | Restores a saved tweak selection/state (e.g. from a rescue pack). |
| **Restore parked autoruns** | Returns and verifies any auto-start entries that had been parked. |
| **System Restore (rstrui)** | Opens Windows' official tool to roll back to a previous point. |
| **Open copies folder** | Opens `Restauracion\` in Explorer. |

## How to use a rescue pack
1. `perfil_tweaks.json` → load it from **Load tweak profile**.
2. `apps_winget.json` → import it with `winget import -i apps_winget.json` (or from Clone PC).
3. The restore point → from **System Restore**.
4. `wpi_journal.jsonl` and `autoruns_desactivados.json` → copies of the journal and parked autoruns.

## Practical examples
- **"About to run a big tweak batch"**: first, **RESCUE PACK** (30-90 s). If you don't like the result, you have the exact previous state to go back to.
- **"I reverted tweaks but want last week's setup"**: **Load tweak profile** and pick the `perfil_tweaks.json` from that day's rescue pack → APPLY in the Tweaks section.
- **"I formatted and want my programs back"**: from the rescue pack, `winget import -i apps_winget.json` (or Clone PC → import): your apps install themselves.
- **"Windows got weird after a driver"**: **System Restore (rstrui)** → pick the point before the driver. Windows' official tool, one button away.

## Tip
Create a rescue pack **before touching anything important** (big tweak batches, aggressive debloat, experiments). It's one click and gives you a full way back.

---

# 12 · Clone PC / Snapshot

## What it is
A **logical clone** of your machine in a file: it exports the COMPLETE list of programs winget recognizes on your PC, in the **official `winget import` format** (compatible with any standard tool). Perfect for making two machines identical or recovering your software after formatting, without going program by program.

## Button by button
| Button | What it does |
|---|---|
| **Export ALL my PC to a file…** | Generates the export file with every winget-recognized program. |
| **Import a file and install everything…** | Reads an export file and Winzard's engine installs each program in one go, with parallelism, automatic retries and forensic log. |
| **Create editable catalogo.json** | Creates a template of the apps catalog so you can customize it (add/remove apps from Winzard's catalog). |
| **Reload catalogo.json** | Reloads your customized catalog (restarts the app). |
| **Load remote catalog (https URL)** | Loads a catalog published at a URL (e.g. your team's or community's). |

## Walkthrough: moving to a new PC
1. On the old PC: **Export ALL my PC** → save the file to a USB drive or cloud.
2. On the new PC: install Winzard, press **Import a file and install everything** and pick the file.
3. Follow progress in the live log; failures are retried at the end and reported honestly.

## More practical examples
- **"Setting up 5 identical office PCs"**: configure one by hand, **Export EVERYTHING**, and on the other four **Import & install everything**. Coffee while winget works.
- **"I want my own catalog for the family"**: **Create editable catalogo.json**, keep only the apps you want them to see, publish it on your Drive/site and at each home **Load remote catalog (https URL)**.
- **"What if another tool made the file?"**: as long as it's the standard `winget export` format, Winzard imports it just the same (and vice versa: Winzard's file works in any standard tool).

## Notes
- The file is standard winget JSON: it also works with a manual `winget import -i file.json`.
- The "Rescue pack" (Recovery hub) includes this export automatically.

---

# 13 · Create a custom Windows ISO (advanced)

## What it is
A **step-by-step wizard** that turns an official Windows ISO into YOUR ISO: with your apps, your tweaks, your debloat, your drivers and unattended install already integrated. The result installs Windows and leaves it just how you like it, by itself.

## Requirements (step 1)
- **Windows ADK** (provides `oscdimg`, the ISO assembler): download button included.
- **DISM** (ships with Windows), **administrator** rights and several GB of free space.
- The **"Check again"** button re-verifies everything.

## Step by step (the wizard's 7 steps)
1. **Requirements**: check ADK, DISM, permissions and space.
2. **Source**: choose the **official ISO** (buttons to download Windows 10/11 from Microsoft), the output folder, the final ISO name and the work folder. Press **Detect editions** and pick ONE edition (much faster) or all of them.
3. **Tweaks**: mark the settings that will apply on FIRST BOOT with Winzard's real engine (safe ones come pre-marked; amber = advanced).
4. **Debloat**: mark the bloatware to remove FROM FACTORY (offline, before install). All reinstallable from the Store.
5. **Apps**: mark what will install itself on first boot (via winget), by sections. Buttons **Use my Apps selection**, **Mark installed** and **Validate IDs**.
6. **Drivers**: if you check "Inject drivers", the .inf files of the chosen folder go INSIDE the ISO (network/chipset ready at boot). Buttons to use the official `Drivers` folder or **export your current PC's drivers**.
7. **Unattended**: local account skipping Microsoft screens (OOBE), **Windows 11 requirements bypass** (TPM/Secure Boot/CPU), language, user name and password. The resulting install is **truly 100 % unattended**: no product-key screen (it carries a generic setup key; Windows activates normally afterwards), no region/keyboard pages, not a single keystroke from booting the ISO to the desktop. If you leave the password empty, the summary warns you clearly. ⚠️ **"VM mode" FORMATS disk 0 without asking: only for virtual machines or disposable disks.**

## Final summary and creation
- The **SUMMARY OF YOUR CUSTOM ISO** lists everything chosen before confirming.
- **Confirm and CREATE the ISO**: launches the process in an admin console (15-30 min with one edition).
- **Check the ISO** (recommended): mounts the created ISO and verifies it carries C:\WPI, autounattend, editions, drivers and winget.
- **Open Rufus**: to write the ISO to USB (GPT scheme, UEFI target). ⚠️ On Rufus' "Windows User Experience" screen, **check NO boxes**: Winzard already does all of it, and Rufus' boxes would overwrite your configuration.
- **Generate kit (optional)**: a `WPI_ISO_Kit` folder with the configuration, the autounattend and the scripts, in case you want to review them first.

## Practical examples
- **"The family PC, ready without me babysitting"**: official ISO + Home edition + your safe tweaks + recommended debloat + Brave/VLC/WhatsApp in Apps → burn with Rufus → boot the PC → come back in an hour: Windows installed, clean, with its programs and its restore point. **Zero questions on screen.**
- **"I want to test my ISO without burning a USB"**: check **VM mode** (virtual machines only), build the ISO and boot it in VirtualBox/Hyper-V: you'll watch the whole cycle, including first boot installing the apps one by one.
- **"Shop technician: 10 different machines"**: export each model's drivers to its folder (manual 10), build one base ISO with your standard apps and inject the model's drivers at step 6. Every machine boots with network and chipset ready.
- **"What exactly did my colleague choose?"**: open their `WPI_ISO_Kit\kit-config.json` (Generate kit): it's all there — edition, tweaks, debloat, apps, unattended credentials.

## First boot, in detail
- Apps install **one by one, with a clean desktop** (every installer closes itself) and with an **anti-hang watchdog**: if winget gets stuck on an app, it's cut off with a notice and the batch moves on.
- If any app fails due to a **network drop**, the engine waits for connectivity and **retries just those** automatically.
- Problematic apps (e.g. Discord) are **deferred to the first sign-in** and install themselves through an **elevated task: no UAC prompts at all**.
- When it finishes you get the **First boot report (HTML)** on the desktop and, if anything failed, **`Reintentar_apps_fallidas.cmd`**: double-click and it retries — **also without UAC prompts**.
- A **"Freshly installed" restore point** is created and the PC reboots itself to integrate everything.

## What the resulting Windows ships with
Local account ready · installed without a single keystroke · your tweaks applied on first boot · bloatware removed from factory · your apps installing themselves (with anti-hang watchdog and network retry) · drivers integrated · the **Repair suite** at `C:\WPI_Suite` · HTML report + initial restore point · everything logged.

---

# 14 · System summary, log viewer and journal

## System summary
Your machine's status panel at a glance:
| Card | What it shows |
|---|---|
| **Disk C: / RAM** | Free/used GB, with percentage. |
| **Catalog apps** | How many are available to install. |
| **Applied tweaks** | How many are detected as applied among the checkable ones. |
| **Bloatware present** | How many apps from the list are still installed. |
| **Restore point** | Whether protection is on (clear warning if it isn't). |

### Summary buttons
| Button | What it does |
|---|---|
| **Save diagnostic** | Exports a machine status report. |
| **Export master profile** | Saves your whole configuration (apps + tweaks + debloat + update) to a JSON, reproducible on another PC or via CLI (`-Profile`). |
| **System snapshot / Compare with snapshot** | Snapshot of services, processes, autoruns and RAM BEFORE your changes; afterwards, the comparison tells you what truly changed. |
| **Change theme** | Rotates the 3 themes (applies on app restart). |

## Log viewer
Browse Winzard's **forensic logs** (`logs\` folder): pick a file in the dropdown and read its latest lines. **Refresh** and **Open logs folder** buttons.

## The change journal (wpi_journal)
Every applied/reverted tweak, every Game Mode session and every relevant action is recorded with a timestamp in `logs\wpi_journal.jsonl`. It powers "Undo today" and the rescue pack.

## Practical examples
1. **"Do the tweaks actually improve anything?"**: **System snapshot** → apply your batch → **Compare with snapshot**: services, processes, autoruns and RAM before/after. Data, not smoke.
2. **"I want MY configured Winzard on another PC"**: **Export master profile** → on the other machine `powershell -File WPI_Moderno.ps1 -Profile my_profile.json` (or try `-DryRun` first to see the plan without touching anything).
3. **"Something failed and I want to know exactly what"**: Log viewer → pick that operation's log (install, tweaks, debloat…) and read it line by line; **Open logs folder** for the whole file.
4. **"Is my PC protected?"**: the **Restore point** card tells you outright; if protection is off, the warning takes you to fix it in one click.

---

# 15 · Themes, language, guides and command line

## Themes
Three complete themes: **Dark**, **Light** and **Blue (Chris Titus)**. Switch them from the sidebar's top dropdown (or from the Summary); they apply on app restart. The setting is stored in `wpi_settings.json`.

## Language
Winzard is **fully bilingual**: Spanish and English, at parity in every text, tooltip and message. Change the language in the sidebar dropdown; the setting is saved and the interface reloads in the chosen language on relaunch.

## Guides (mini-tutorials)
The **Guides** panel ships step-by-step mini-tutorials for apps that need them (emulators like RetroArch, PCSX2, RPCS3, Dolphin…): BIOS, cores, controllers. The catalog flags which apps have a guide. You can add your own via `guias.json`.

## Remembered settings
`wpi_settings.json` (next to the WPI) stores theme, language, your Gaming pause list, associated games, notification muting and the last selection. Delete it to start fresh.

## Command line (CLI)
Winzard also works without the UI, for automation:
| Parameter | What it does |
|---|---|
| `-Tweaks` | Applies tweaks from the console. |
| `-Debloat` | Runs debloat from the console. |
| `-Preset path.txt` | Installs a list of apps (one winget ID per line). |
| `-Update all\|recommended` | Updates apps from the console. |
| `-Profile path.json` | Applies a full master profile (apps+tweaks+debloat+update). |
| `-DryRun` | **Blocks EVERYTHING**: with any combination of parameters it shows the exact PLAN without touching anything (you'll see the "DRY-RUN MODE" banner at the start). |
| `-BuildIsoKit` | Builds the ISO kit without the GUI. It comes out **neutral** (no tweaks, no debloat) unless you add `-IsoTweaksAll` and/or `-IsoDebloatAll`. |
| `-ExportCatalog` | Exports the tweak catalog to `logs\` (Markdown + JSON). |
| `-SelfTestGui` | Interface self-test (for verification). |

Example: `powershell -File WPI_Moderno.ps1 -Profile my_profile.json -DryRun`

Fine details for automation: the unattended console **respects the language saved** in `wpi_settings.json` (ES or EN messages), and when it finishes it **won't sit waiting for an Enter** if you launch it from a script (it only asks for Enter in an interactive console).

## Practical examples (automation)
- **"See what my profile would do without touching anything"**: `powershell -File WPI_Moderno.ps1 -Profile my_profile.json -DryRun` → full plan with the DRY-RUN MODE banner, zero changes.
- **"Install my app list on a new PC, no GUI"**: `powershell -File WPI_Moderno.ps1 -Preset my_apps.txt -NoReboot` (elevated). Progress bar, anti-hang watchdog and an honest summary.
- **"Build the ISO kit from a script"**: `powershell -File WPI_Moderno.ps1 -BuildIsoKit -IsoPath "D:\isos\Win11.iso" -IsoOutDir "D:\out"` — add `-IsoTweaksAll -IsoDebloatAll` for the full package.
- **"Update the home PCs every Sunday"**: a scheduled task running `-Update recommended`; the console respects your language and never sits waiting for an Enter.

## Other pieces
- **Self-elevation**: Winzard asks for administrator rights at startup (it needs them to apply system settings); this is its standard mechanism.
- **Single instance**: if a Winzard is already open, the second one tells you and won't duplicate.

