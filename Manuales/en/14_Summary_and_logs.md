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
