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
