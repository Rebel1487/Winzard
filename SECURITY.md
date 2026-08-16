# Security Policy

> 🇪🇸 *¿Prefieres español?* La app es bilingüe; el manual está en [README_ES.md](README_ES.md).

## Winzard security philosophy

Winzard performs system operations (installing software, applying tweaks, repairing Windows, creating ISOs). That's why transparency is a core pillar:

- ✅ **No pirated software.** All apps are installed via **winget** from official Microsoft and developer manifests.
- ✅ **Open and auditable code.** Winzard is 100 % plain PowerShell — no compiled binaries, no obfuscation. You can read exactly what every button does before running it.
- ✅ **Action logging.** Relevant operations leave logs.
- ✅ **Minimum privilege.** Winzard starts as a **standard user** and only asks for administrator rights for the operations that genuinely need them — telling you first what they are for. See the full model below.
- ✅ **Reversible tweaks** whenever possible, with an optional restore point before applying.
- ✅ **No telemetry, no accounts, no network callbacks.** Winzard never phones home.

---

## 🔐 Privilege model (since v1.3.0)

This section exists because a Windows tweaking tool that asks for administrator rights deserves to explain itself in detail. **Nothing here is hidden.**

### What changed in v1.3.0

Up to v1.2.0, both `Iniciar_WPI.bat` and `WPI_Moderno.ps1` **self-elevated on launch**: you had to grant administrator rights to the whole program before you could even browse the app catalog. That was development debt, and it has been removed.

Winzard now starts with whatever privileges you give it and **never relaunches itself elevated on its own**.

### What works without administrator rights

The app catalog (browse, search, select), global search, installed-app detection, save/load profile, winget search, hardware and driver information, system summary, guides, the manuals, the log viewer, and theme/language switching.

### What asks for administrator rights, and when

Elevation is requested **at the moment you run the operation**, never up front:

| Operation | Why it needs administrator |
|---|---|
| Install / uninstall / update apps (machine scope) | winget writes outside your user profile |
| Tweaks and settings | Writes to `HKLM` and manages services |
| Remove bloatware (Appx) | Removes provisioned packages from the system image |
| Windows Update control | Manages services and the SoftwareDistribution cache |
| Windows features | Enables/disables optional OS components |
| Repair Suite (17 phases) | DISM, SFC, CHKDSK, network stack, WMI repository |
| Custom ISO builder | Mounts and services Windows images with DISM |

If you decline the Windows prompt, Winzard **accepts the refusal**, tells you calmly and carries on as a standard user. It never loops or nags.

Winzard also shows **no permission warning at startup**. The window title simply reads *Standard user* or *Administrator*. If you want a fully elevated session, launch it with right-click → *Run as administrator*.

### Scheduled tasks Winzard can create

Full disclosure, because scheduled tasks with elevated privileges deserve it:

| Task | When it is created | Elevated | Self-removes | Purpose |
|---|---|---|---|---|
| `WPI_ReintentoApps` | **Only** on the first boot of an ISO you built with Winzard | Yes | ✅ Yes, on completion | Installs apps that fail when run as SYSTEM (e.g. Discord) in your real user session |
| `WPI_ReintentoManual` | Same context, alongside the desktop retry script | Yes | Manual | One-click retry for apps that failed on first boot |
| `WPI_Mantenimiento_Mensual` | **Only** if you explicitly apply the "monthly maintenance" tweak | Yes (SYSTEM) | Via the tweak's Undo | Clears temp files, recycle bin and DNS cache every 4 weeks |

**These tasks run without an additional UAC prompt by design of Windows** — creating them already required administrator consent that you granted for an operation you requested. This is documented Windows behaviour, not a UAC bypass.

### What Winzard never does

- ❌ **Never modifies your UAC configuration.** No `EnableLUA`, no `ConsentPromptBehaviorAdmin`, no `PromptOnSecureDesktop`.
- ❌ **Never uses UAC bypass techniques** (`fodhelper`, `eventvwr`, `computerdefaults`, `sdclt`, `CMSTPLUA` or any other).
- ❌ **Never installs a service, driver or background agent.** Close Winzard and nothing of it keeps running.
- ❌ **Never sends anything over the network** except the app downloads that winget performs from official sources.
- ❌ **Never bundles or redistributes Windows.** You supply Microsoft's official ISO; customisation happens locally and the result never leaves your machine.

### About `ExecutionPolicy Bypass`

The launchers use `-ExecutionPolicy Bypass`. This is **necessary**, not a shortcut: Winzard is an unsigned PowerShell script and a freshly installed Windows would otherwise refuse to run it. The flag applies **only to the Winzard process being launched** — it does not change your system's execution policy, and nothing persists after the process exits.

### About code signing

Winzard is **not signed with a code-signing certificate**, so Windows SmartScreen may warn you the first time. This is honest and expected for a free, independent project: certificates cost several hundred euros a year. Your protection instead is that **the source is fully readable** and every release publishes SHA-256 hashes in `HASHES.sha256`. Verify with:

```powershell
Get-FileHash .\WPI_Moderno.ps1 -Algorithm SHA256
```

---

## User best practices

1. **Download only from the official source** ([this repository](https://github.com/Rebel1487/Winzard) and its Releases).
2. **Verify the hashes** against `HASHES.sha256`.
3. **Review the code** if in doubt: it's readable PowerShell.
4. **Test in a virtual machine** before applying heavy changes to your main PC.
5. **Create a restore point** before applying tweaks or debloat (Winzard offers this).
6. **Don't upload** ISOs, personal logs or internal reports to public repos.

## Supported versions

| Version | Supported |
|---|---|
| 1.3.x | ✅ Yes |
| 1.2.x | ⚠️ Superseded — upgrade recommended (see the v1.3.0 integrity fixes) |
| < 1.2 | ❌ No |

## Reporting a vulnerability

If you find a security issue, **do not post it in a public Issue**. Instead:

1. Open a private **Security Advisory** on GitHub (*Security* tab → *Report a vulnerability*), **or**
2. Contact the maintainer privately.

Include: description, reproduction steps, potential impact and, if possible, a proposed fix. We'll get back to you as soon as possible.

Reports about **attribution or licensing** (e.g. someone redistributing Winzard without credit) are also welcome — see [TRADEMARK.md](TRADEMARK.md).
