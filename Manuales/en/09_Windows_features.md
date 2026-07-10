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
