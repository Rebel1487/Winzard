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
