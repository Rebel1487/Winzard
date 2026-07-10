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
