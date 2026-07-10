# 06 · Windows Update control

## What it is
The update control center: **you decide how and when Windows updates**, through real system policies. Every action runs when you press its button, is verified, and gets recorded in the forensic log. Nothing is permanent: the defaults button reverts everything. Requires administrator rights.

## The cards (each with its "Apply" button)
| Action | What it does | Risk |
|---|---|---|
| **Recommended configuration (defer updates)** | Defers updates by a sensible margin: you still get patches, just a few days after release, avoiding day-one Microsoft bugs. | Safe |
| **Pause all updates for 5 weeks** | Full temporary pause (the maximum Windows allows by policy). | Safe |
| **Windows Update defaults** | Removes any policy applied from this list and returns Windows Update to factory behavior. | Safe |
| **Disable Windows Update completely** | Turns off the service and its policies. Asks for confirmation with a clear warning: leaving Windows without security patches is risky; use it only if you know what you are doing (lab machines, test VMs…). | Advanced (red border) |

## Quick links
Buttons that open the relevant Windows Update Settings pages directly.

## Typical walkthrough
1. Press **Apply** on "Recommended configuration": the sweet spot for most people.
2. Launch weekend or travelling? "Pause for 5 weeks".
3. Want everything back as it was? **Defaults** and done.

## Practical examples
- **"Windows updated me mid-match"**: apply **Recommended configuration** — patches still arrive, just with a few days' rest and never by surprise.
- **"Travelling with the laptop, no surprises please"**: **Pause for 5 weeks** before leaving; when you're back, **Defaults** and Windows catches up.
- **"I changed something months ago and don't remember what"**: press **Windows Update defaults** — it wipes ANY policy from this list and returns Windows Update to factory behaviour, no memory required.
- **"It's a test VM and must never update"**: **Disable completely** (confirm the red warning). Only for machines that truly don't need security patches.

## Reversibility
Every action in this section is reverted by "Windows Update defaults". Everything is recorded under `logs\`.
