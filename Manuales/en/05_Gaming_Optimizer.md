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
