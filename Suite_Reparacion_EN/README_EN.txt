====================================================================
  REPAIR SUITE WPI  v3.1  -  ENGLISH VERSION
  Windows 10/11  -  no external dependencies
====================================================================

WHAT IT IS
  A set of 18 self-contained .bat files to diagnose and repair
  Windows 10/11. Use the ALL-IN-ONE or each phase on its own.

HOW TO USE
  - ALL-IN-ONE:  right-click  Repair_Suite_AllInOne.bat  ->
                 "Run as administrator".
                 You get a MENU with the modes (full, smart, quick,
                 manual, plan, pick phases, simulation, guide).
  - SINGLE PHASE: right-click any  Phase_NN_*.bat  ->
                 "Run as administrator".
  - Expert:      add  /cmd  to see the exact command behind each option.
                 e.g.  Repair_Suite_AllInOne.bat /cmd /manual

WHAT'S NEW IN THIS REVISION (important)
  1) ROBUST STARTUP: Windows version detection no longer relies on WMI
     alone. If the WMI repository is damaged (something this suite
     repairs), the Registry is used as a fallback and, if the version
     still cannot be determined, the tool WARNS and CONTINUES instead
     of stopping. Previously it could get stuck on "(build )".
  2) BACK TO MENU: when a mode or a phase finishes -even if you answer
     NO to "Do you want to reboot now?"- the app no longer closes: it
     takes you back to the MENU. It only closes when YOU choose "Exit"
     in the menu (or if you decide to reboot the PC).
     In single phases, after each option you return to the phase menu;
     choose 0 to close.

USABILITY (this version)
  - The menu suggests what to pick if you are unsure (1 or 2).
  - Each mode and each phase show an approximate time and impact
    (safe / makes changes).
  - Before a real repair you are asked for CONFIRMATION (except in
    /auto, simulation or manual mode).
  - Single phases tag options [quick]=light/scan and [deep]=repair,
    and return to their menu after each option.

SAFETY
  - Creates a restore point (Phase 01) before heavy changes.
  - Simulation mode (/dry) shows what it would do without touching it.
  - Revertir.cmd helps open System Restore if needed.
  - Test it first in a virtual machine: it makes real changes.

FINAL FIXES (after real-Windows validation)
  - Uptime is computed even if WMI is broken (uses TickCount64
    as a fallback).
  - Help and all texts 100%% in their language.

INTEGRITY
  HASHES.sha256 holds the hash of each .bat. The src/ and build/
  folders let you regenerate the .bat identically with Python.
====================================================================
