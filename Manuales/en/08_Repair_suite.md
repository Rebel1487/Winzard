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
