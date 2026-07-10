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
