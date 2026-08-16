# Winzard v1.3.0 — the minimum-privilege release *(app build v7.4)*

**Winzard no longer asks for administrator rights just to open.**

This is a **security and trust release**. No new features: everything you already had, asked for more honestly — plus an integrity fix that matters if you verify hashes before running things (and you should).

## 🔐 Minimum privilege

Up to v1.2.0 both launchers self-elevated on startup. You had to grant administrator rights over the whole program before you could even look at the app catalogue. That was development debt, and it's gone.

Now Winzard **starts as a standard user**, and these work with no permissions at all:

> the app catalogue (browse, search, select) · global search · installed-app detection · save/load profile · winget search · hardware and driver info · system summary · guides · **all the manuals** · the log viewer · theme and language

Operations that genuinely need administrator rights — installing apps, tweaks, debloat, Windows Update control, the Repair Suite, the ISO builder — **ask for elevation at the moment you run them, and tell you what it's for**.

**Saying no is a valid answer.** Decline the Windows prompt and Winzard tells you calmly and carries on. No nagging, no retry loops.

**And no warning at startup either.** Winzard says nothing about permissions when it opens — the window title just shows *Standard user* or *Administrator*. One less window between you and the app.

## 🌍 Pick your language when you open it

Winzard used to start in Spanish on a first run regardless of your system — an English speaker opened it and found an interface they couldn't read. Now a quick one-click card lets you choose **English or Spanish every time you launch**, with your previous choice already highlighted. Interface, manuals, logs and even the startup splash load in that language.

A side effect worth having: because the language is known from the very start, **no dialog is duplicated in two languages any more**. Everything you read is half as long.

## 🎨 Premium dialogs

Windows message boxes are gone from the startup flow. Winzard now uses its own WPF dialog — rounded card, accent gradient, large buttons, draggable from anywhere, Escape to dismiss.

## 📖 A privilege model you can actually audit

[SECURITY.md](SECURITY.md) now documents the whole thing: what works without admin, what asks for it and why, **every scheduled task Winzard can create** (including the fact that the first-boot one deletes itself), why `ExecutionPolicy Bypass` is necessary, and an explicit list of what Winzard **never** does:

- ❌ Never modifies your UAC configuration (`EnableLUA`, `ConsentPromptBehaviorAdmin`, `PromptOnSecureDesktop`).
- ❌ Never uses UAC bypass techniques.
- ❌ Never installs a service, driver or background agent.
- ❌ No telemetry, no accounts, no network callbacks.

## 🔏 Integrity fix — please re-verify

`HASHES.sha256` in **both** Repair Suites declared stale hashes for **8 shipped files** (the all-in-one launcher plus phases 01, 05 and 14, in each language). If you verified integrity as the README instructs, those 8 would have shown a mismatch. Both manifests have been regenerated from the real files.

Nothing malicious ever happened — the files had been improved after the last hash refresh and the manifests were never regenerated — but in a tool that runs as administrator, a hash that doesn't match is not something to leave lying around.

```powershell
Get-FileHash .\WPI_Moderno.ps1 -Algorithm SHA256
```

## 🧱 Also fixed

- **36 stale build artifacts** in `build/out` of both suites, missing the v3.2 `SELF` fix. The files you actually run were always correct, but regenerating from `build/out` would have reintroduced the bug. Both suites fully regenerated.
- **`Manuales/generar_manual_completo.ps1`** had non-ASCII characters without a BOM — Windows PowerShell 5.1 mangled its accents.
- **Developer paths removed** from public documentation.

## 🏷️ Authorship and attribution

New in the repository: `NOTICE`, `AUTHORS`, `CITATION.cff` (GitHub's "Cite this repository" button), `TRADEMARK.md` and `THIRD_PARTY_NOTICES.md` — which records that **Winzard bundles no third-party code and has no dependencies**, and credits WinUtil, Winhance, Sophia Script and Win11Debloat as the inspiration they are.

SPDX headers are now on 100 % of the project's own PowerShell sources.

**Winzard stays free and open source, with no paid tiers and no locked features.** Always.

## ✅ Verification

| Check | v1.2.0 | v1.3.0 |
|---|---|---|
| `Verificar_Proyecto.ps1` | 22 OK · 1 warn · **5 FAIL** | **28 OK · 0 warn · 0 FAIL** |
| `-ConsoleSmoke` (both suites + GUI) | — | **38 OK · 0 FAIL** |

Full details in [CHANGELOG.md](CHANGELOG.md).
