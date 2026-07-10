# 10 · Drivers and hardware

## What it is
The section to keep your **drivers up to date and backed up**, with GPU detection and hardware-based recommendations.

## Button by button
| Element | What it does |
|---|---|
| **Detected GPU + its official app** | Detects your graphics card and offers the right button: **NVIDIA App** (official site), **AMD Software: Adrenalin** (official site; AMD doesn't ship via winget) or **Intel Driver & Support Assistant** (winget). |
| **Open official driver page** | Goes to the detected vendor's download page. |
| **Other vendors** | Always-available buttons for NVIDIA / AMD / Intel even if the GPU isn't identified. |
| **Export this PC's drivers** | Copies every installed driver (.inf with its folders) to a folder of your choice: your safety net before formatting and the raw material to inject into an ISO. |
| **Hardware recommendations** | Marks recommended catalog apps for your machine (e.g. vendor utilities). |

## Relation to "Create ISO"
The official **`Drivers`** folder in Winzard's directory is what the ISO wizard uses to **inject drivers** into the image: export your PC's drivers there and your freshly installed Windows will boot with network and chipset ready.

## Practical examples
- **"Formatting this weekend"**: **Export this PC's drivers** to a USB. After formatting, Windows gets network and chipset with zero hunting — and if you build your ISO with Winzard, inject them and skip even that.
- **"No idea which graphics card I have"**: the section detects it and gives you the EXACT button for its official software (NVIDIA App / Adrenalin / Intel DSA). No fake "driver booster" sites.
- **"Work laptop acting weird after a driver"**: always download from the official vendor button; never third parties.

## Safety
- Downloading/installing drivers always goes through the vendor's **official** sites or installers.
- Exporting changes nothing: it only copies.
