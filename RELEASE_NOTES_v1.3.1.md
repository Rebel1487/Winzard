# Winzard v1.3.1 — the honest results release *(app build v7.4)*

An external audit of the published v1.3.0 found that Winzard **claimed success in several places without having verified it**. That is precisely the opposite of what this project says about itself, so it gets fixed before anything else does.

Every finding was reproduced in the code before being touched, and every fix was tested against the specific failure it addresses. **No new features. Nothing rewritten.** About fifty lines, all in the direction of not saying things that aren't true.

---

## 🔴 An incomplete ISO could be declared ready to burn

Two separate defects formed one chain:

- **The copies were not checked.** All **five** `robocopy` calls piped to `Out-Null` without reading `$LASTEXITCODE`. (robocopy doesn't use 0=success: 0-7 are success variants, ≥8 is a real failure — so even a naive `-ne 0` check would have been wrong.) A failed copy of the WPI payload passed unnoticed.
- **The verifier then approved the result.** A missing `autounattend.xml` was reported through a function that *only prints*, so it never counted as fatal, and the final verdict still read **"ISO LISTA PARA GRABAR EN RUFUS"** for an image that would never install unattended.

So a copy could fail in silence, an incomplete ISO got built, the verifier gave it a green light, and you burned it.

Both ends are now checked. The same two defects existed in the verifier copy that ships inside every generated kit — **both copies are fixed identically**.

The verifier also **never set an exit code** on its content checks, returning 0 even with critical problems. It now exits 1, and skips its final keypress when stdin is redirected instead of hanging forever under a scheduler.

## 🔴 `-DryRun` was not dry

Startup ran the self-update path and `winget source update` **before any mode guard**. A run advertised as *"nothing changes"* still used the network and mutated the state of the winget sources.

Now skipped for `-DryRun`, `-SelfTestGui` and `-ExportCatalog` — guarded both at the call site and inside the function itself, so no other path can slip through.

## 🔴 A typo could trigger a real repair

The repair suites parsed arguments as a series of bare `if` statements with no validation, so anything unmatched fell through in silence:

```
Suite_Reparacion.bat /auto /drry
```

The `/drry` typo was ignored and `/auto` carried on — **a real repair, when the user believed they had asked for a simulation.**

Unknown arguments now stop the suite with exit code 2 and a list of what is valid, without running anything.

## 🟠 A typo could update every program on the machine

`-Update` was a free string, dispatching *"recommended → Windows Update, **anything else** → `winget upgrade --all`"*. So `-Update recomendadoo` updated your entire machine instead of reporting the mistake. It now has a closed `ValidateSet`.

## 🟠 Self-update disabled

It downloaded text over the network, **overwrote `WPI_Moderno.ps1` with it** and relaunched — no hash, no signature, no host allowlist, no downgrade protection. It was dormant, since the URL ships empty, but one config string away from being armed. Re-enabling it requires implementing artifact verification first.

## 🏷️ A destructive ISO now identifies itself

The wizard already guarded VM Mode heavily — a red checkbox reading "BORRA EL DISCO 0", a matching tooltip, and a mandatory confirmation dialog. But **all of that vanishes once the image exists**, and the resulting file looked like any other ISO. If that USB ends up in a drawer and gets booted months later on the wrong machine, nothing warns anybody.

Now the filename carries `_BORRA-DISCO0` and the ISO root gets a `LEEME-ATENCION-BORRA-DISCO-0.txt`.

**The option itself is deliberately kept.** It is what makes the zero-keystroke unattended install possible, it is off by default, and removing it would mean withdrawing that claim from the documentation. Making the artifact honest about itself is the better trade.

## 🔑 The unattended password was silently stored in clear text

It always was — in `kit-config.json` and in the `autounattend.xml` that travels inside the ISO — and nothing in the app said so. Anyone with the USB or the kit folder can read it. The wizard now spells it out and advises against reusing an important password.

## 🧹 Temp files no longer accumulate forever

Each suite run left **three** files in `WPI_Suite` and never removed them; **96** had piled up in normal use. They are now swept on the next run, deleting only entries older than a day so a run in progress is never disturbed.

---

## ✅ Verification

| | |
|---|---|
| `Verificar_Proyecto.ps1 -ConsoleSmoke` | **40 checks · 38 OK · 0 failures** (the 2 warnings are the expected "no ISO inside the project" notices) |
| Console smoke on both suites | `/help` `/version` `/selftest` `/dry` — **8/8** |
| Typo rejection | `/auto /drry` → exit 2, nothing executed · `/help` and `/version` → exit 0, no regression |
| `-Update recomendadoo` | Rejected before execution, valid values listed |
| Dry run | Confirmed by running it: no network, no source refresh |
| ISO filename marker | 6 cases exercised, including not double-marking an already-marked name |
| Temp cleanup | 96 leftovers backdated two days → dropped to 3 per suite, 0 old entries remaining |

Full detail in [CHANGELOG.md](CHANGELOG.md).

---

## 🔎 Still open, and deliberately not touched

Honesty applies here too. The audit raised further points that **could not be validated without a virtual machine and destructive testing**, so they were recorded rather than turned into rushed changes:

- Whether the `/source:` argument passed through `cmd.exe /c` to DISM is genuinely exploitable *(note: that value is supplied by the same user who is elevating the tool)*
- TOCTOU races and script substitution, which depend on the real ACLs of a given machine
- Behaviour of an actually-booted ISO

Fixing what cannot yet be reproduced would be guessing. These stay on the list.
