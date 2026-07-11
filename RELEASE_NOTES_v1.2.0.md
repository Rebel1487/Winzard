# Winzard v1.2.0 — the polish release *(app build v7.4)*

Everything new in this release was **battle-tested in two live-fire installs** — Windows 11 *and* Windows 10 ISOs built by Winzard itself, installed 100 % unattended in VMs — plus runtime verification on a real PC.

## ✨ Highlights

- 🛡️ **Premium unattended first boot** — the console stays always-on-top, the screen never sleeps while it works (without touching your power settings: the lock evaporates on reboot), a framed status panel tells you exactly what is happening, and the window looks right on 1080p / 1440p / 4K at any DPI.
- ⚡ **Premium app opening** — installed-app detection runs under the startup splash; the window appears only when everything is truly loaded, ready to click instantly.
- 💿 **Rufus with your ISO preloaded** — the "Write to USB" button launches Rufus with the ISO already selected.
- 🍫 **Chocolatey fallback that actually lands** — derived-ID matching confirmed with `choco search --exact`, plus a 20-minute cap so a stuck choco can never hang the batch.

## 🐛 Fixes

- **`0x8A15003F` (corrupted winget cache on freshly installed Windows)** is now retryable: Winzard runs `winget source update` and retries those apps once — in the first-boot engine, the GUI worker and the deferred retry script.
- **Small screens**: saved or default window geometry is clamped to the real screen, so controls can never end up unreachable off-screen.
- **Xbox debloat protects `Microsoft.Xbox.TCUI`** (retired from the Store — removing it would be irreversible).
- **Calm desktop after deferred installs**: the deferred first-sign-in installer runs the same "serene experience" cleanup.

## 📸 Docs

- Seven fresh high-resolution README screenshots (hero, apps, tweaks, repair, ISO wizard, ES/EN side by side) captured with this exact build.
- New optional-donations section (GitHub Sponsors). Winzard stays 100 % free, always.

## 🔐 Integrity

`HASHES.sha256` contains the SHA-256 of every published artifact. Verify with:

```powershell
Get-FileHash .\WPI_Moderno.ps1 -Algorithm SHA256
```

Full details in [CHANGELOG.md](CHANGELOG.md).
