# 04 · Tweaks and settings

## What it is
**86 Windows settings** (privacy, performance, UI, network, gaming, system) that can be applied and **reverted one by one**. Every tweak has its toggle, its state color and its real-state detector: Winzard checks in your Windows whether the setting is truly applied — it never assumes.

## The color code (legend at the bottom of the list)
- **Green + toggle on** = already applied on this PC (truly detected).
- **Amber** = advanced tweak, not applied (apply with care; its tooltip explains why).
- **Gray** = one-shot action with no state (e.g. a cleanup).
- **Normal color** = safe tweak, not applied.

The toggle is also your **selection**: turn on what you want to apply, turn off what you don't. "APPLY" skips (with a notice) whatever is already applied, so nothing ever re-runs by mistake.

## Button by button
| Button | What it does |
|---|---|
| **Search box** | Live-filters the 86 tweaks. |
| **Safe / Balanced / Aggressive presets** | Mark sets with different impact levels (nothing applies until you press APPLY). |
| **APPLY SELECTED (n)** | Runs only what is marked and still missing. Each tweak reports its result. |
| **REVERT SELECTED** | Runs each marked tweak's official "undo" and returns it to its default value. |
| **Re-detect state** | Re-reads the REAL state of every tweak in your Windows and refreshes colors and toggles. |
| **Verify all** | Generates an HTML report verifying every setting, detector by detector. |
| **Mark missing recommended** | Marks the recommended safe tweaks that are not applied yet. |
| **Apply recommended for MY PC** | Analyzes your hardware (laptop/desktop, GPU, disk…) and applies only what is safe for YOUR specific case. |
| **Export catalog** | Saves the full tweak list (Markdown + JSON) under `logs\`, describing what each one does. |

## Typical walkthrough
1. Press **Re-detect state** to see your PC's real picture.
2. Press **Mark missing recommended** (or pick a preset, or mark by hand).
3. Review anything amber: its tooltip and ℹ expander explain what it does and when to avoid it.
4. Press **APPLY SELECTED** and read the summary.
5. Changed your mind? Mark it and press **REVERT SELECTED**: it returns to the Windows default.

## Practical examples
- **"I want more privacy without risk"**: Re-detect state → **Mark missing recommended** → APPLY. In a minute, telemetry, ads and suggestions are gone — all reversible.
- **"It's my mum's PC and I want zero trouble"**: press **Apply recommended for MY PC** and that's it — Winzard checks whether it's a laptop or desktop, which GPU and disk it has, and applies only what's safe for that hardware.
- **"I applied something and now I don't like the context menu"**: search "menu" in the search box, switch that tweak on and press **REVERT SELECTED** — back to the exact Windows factory value.
- **"Is this really applied?"**: press **Verify all** and open the HTML report: every setting with its detector, expected value and real value, in green or red.
- **"I want the whole list to read calmly"**: **Export catalog** drops a Markdown and a JSON with all 86 tweaks and their explanations under `logs\`.

## Reversibility and safety
- Almost every tweak has an official 1:1 undo (the REVERT button itself). The few that don't (a temp cleanup, a restore point) say so clearly.
- Everything is recorded in the **change journal**, and the "Rescue pack" (Recovery hub) stores your tweak profile with the real detected state.
- Tip: create a restore point before a big batch (the first tweak in the list does it for you).
