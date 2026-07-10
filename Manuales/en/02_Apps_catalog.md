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
