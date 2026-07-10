# manifest.psd1 | Manifiesto de configuracion canonico de la Suite (Task 1.4, Req 14.1).
# Fuente unica de verdad para constantes (version, retencion de logs, validez de checkpoint,
# nivel de terminal virtual deseado) y para los titulos/"por que" de las 17 fases (de :title_of).
# Lo consume el generador (build/generar.ps1, Task 2). NO se distribuye ni se ejecuta directamente.
@{
    WPI_VERSION             = '3.1'
    LOG_RETENTION           = 10
    CHECKPOINT_MAX_AGE_DAYS = 7
    VT_LEVEL_DESIRED        = 1

    # Titulos y "por que" de las 17 fases (00..16), VERBATIM de :title_of en lib_wpi.cmd.
    PHASES = @(
        @{ Id = '00'; Title = 'Diagnostics and triage'; Why = 'Checks disks, space and events, and finds the root cause.' }
        @{ Id = '01'; Title = 'Restore point'; Why = 'Creates a restore point and backs up the registry so you can roll back.' }
        @{ Id = '02'; Title = 'Initial cleanup'; Why = 'Clears temp files, recycle bin and caches to free up the disk.' }
        @{ Id = '03'; Title = 'CHKDSK'; Why = 'Checks the C: drive file system for errors.' }
        @{ Id = '04'; Title = 'Disk optimization'; Why = 'TRIM for SSDs or defragment for HDDs, depending on the disk type.' }
        @{ Id = '05'; Title = 'DISM'; Why = 'Repairs the Windows component image (the source SFC relies on).' }
        @{ Id = '06'; Title = 'SFC and verification'; Why = 'Repairs system files and verifies the result after DISM.' }
        @{ Id = '07'; Title = 'Repair WMI'; Why = 'Checks and repairs the WMI repository (a broken one causes odd failures).' }
        @{ Id = '08'; Title = 'Store apps and Startup'; Why = 'Re-registers Store apps and repairs the Start menu.' }
        @{ Id = '09'; Title = 'Search and caches'; Why = 'Rebuilds the Search index, icon/font caches and the spooler.' }
        @{ Id = '10'; Title = 'Certificates and time'; Why = 'Refreshes root certificates and syncs the clock (fixes WU/Store/cert).' }
        @{ Id = '11'; Title = 'Network'; Why = 'Resets winsock, IP, DNS and proxy, and checks the hosts file.' }
        @{ Id = '12'; Title = 'Policies (GPO)'; Why = 'Re-applies group policies to undo misapplied settings.' }
        @{ Id = '13'; Title = 'Windows Update'; Why = 'Repairs Windows Update (services and cache). Honors /keepwu.' }
        @{ Id = '14'; Title = 'Winget'; Why = 'Repairs winget and updates the package manager.' }
        @{ Id = '15'; Title = 'Devices'; Why = 'Lists drivers/devices with errors so you know what to check.' }
        @{ Id = '16'; Title = 'Final cleanup and report'; Why = 'Deep cleanup, recomputes health and generates the HTML report.' }
    )
}
