# ============================================================================
#  WPI - Cerebro de la Suite de Reparacion (helper)
#  Invocado por el .bat: powershell -File suite_helper.ps1 -Action <accion> ...
#  Acciones: sysinfo | score | forensics | triage | restorepoint | mediatype
#            | devices | report | addphase | setbefore | setafter | finding
#            | resetstate | normalizefases | checkpoint | moveresult | vtlwrite
#            | mapexit | ramcheck | battery | netadvanced | diagfull
#            | logrotate | envcheck | selftestbrain | selftestresult
#            | sfcresult | jsonreport | supportpackage
#  Todo va a STDOUT en lineas KEY=VALUE (faciles de leer desde batch con FOR),
#  salvo 'report' que escribe un HTML. Sin dependencias externas.
# ============================================================================
param(
    [string]$Action = 'sysinfo',
    [string]$Work   = "$env:TEMP\WPI_Suite",
    [string]$Arg    = ''
)
$ErrorActionPreference = 'SilentlyContinue'
if (-not (Test-Path $Work)) { New-Item -ItemType Directory -Path $Work -Force | Out-Null }
$StateFile = Join-Path $Work 'estado.json'

# --- Constantes de configuracion (alineadas con manifest.psd1 / design) ---
$CheckpointFile          = Join-Path $Work 'checkpoint.json'
$WPI_VERSION             = '3.1'
$CHECKPOINT_MAX_AGE_DAYS = 7
$VT_LEVEL_DESIRED        = 1
$LOG_RETENTION           = 10

function Read-State {
    if (Test-Path $StateFile) { try { return (Get-Content $StateFile -Raw | ConvertFrom-Json) } catch {} }
    return [pscustomobject]@{ score_before = $null; score_after = $null; findings = @(); phases = @(); diag = $null }
}
function Write-State($s) { try { [System.IO.File]::WriteAllText($StateFile, ($s | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false))) } catch {} }

# Garantiza que el estado tiene el sub-objeto 'diag' (ram/battery/devices/network).
# Compatible con estados antiguos cargados de estado.json sin la propiedad 'diag'.
function Initialize-Diag($st) {
    if (-not ($st.PSObject.Properties.Name -contains 'diag') -or $null -eq $st.diag) {
        $diag = [pscustomobject]@{ ram = $null; battery = $null; devices = @(); network = $null; smart = $null; bcd = $null; processes = $null; startup = $null }
        $st | Add-Member -NotePropertyName diag -NotePropertyValue $diag -Force
    } else {
        foreach ($pp in 'smart','bcd','processes','startup') {
            if (-not ($st.diag.PSObject.Properties.Name -contains $pp)) {
                $st.diag | Add-Member -NotePropertyName $pp -NotePropertyValue $null -Force
            }
        }
    }
    return $st
}

function Get-SysInfo {
    $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs  = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1)
    $c   = Get-PSDrive C
    if ($os -and $os.LastBootUpTime) {
        $up = (Get-Date) - $os.LastBootUpTime
    } else {
        $ticks = [System.Environment]::TickCount64
        if ($null -eq $ticks) {
            $ticks = [System.Environment]::TickCount
            if ($ticks -lt 0) { $ticks = [uint32]$ticks }
        }
        $up = [TimeSpan]::FromMilliseconds($ticks)
    }
    $cpuName = ""
    if ($cpu -and $cpu.Name) { $cpuName = $cpu.Name.Trim() }
    $ramGB  = [math]::Round($cs.TotalPhysicalMemory/1GB,1)
    $freeGB = [math]::Round($c.Free/1GB,1)
    $totGB  = [math]::Round(($c.Free+$c.Used)/1GB,1)
    "OS=$($os.Caption) (build $($os.BuildNumber))"
    "EQUIPO=$($cs.Manufacturer) $($cs.Model)"
    "CPU=$cpuName"
    "RAM=$ramGB GB"
    "DISCO=C: $freeGB GB libres de $totGB GB"
    "UPTIME=$([int]$up.TotalDays)d $($up.Hours)h $($up.Minutes)m"
    "USUARIO=$env:USERNAME"
}

# --------------------------------------------------------------------------
# (5.2 / Req 15.6) Nucleo PURO de calculo del score.
# Recibe un hashtable de sintomas (flags/conteos) y devuelve un entero en
# [0,100]. Cada sintoma solo puede RESTAR puntos, por lo que anadir o agravar
# cualquier sintoma nunca sube el score (MONOTONIA), y el clamp garantiza el
# rango [0,100]. Es determinista respecto a su entrada (testeable de forma
# aislada para la Property 10).
function Compute-Score([hashtable]$sym) {
    if ($null -eq $sym) { $sym = @{} }
    $score = 100
    # --- Penalizaciones existentes (preservadas) ---
    if ($sym['smartBad'])       { $score -= 25 }
    if ($sym.ContainsKey('freeGB') -and $null -ne $sym['freeGB']) {
        $freeGB = [double]$sym['freeGB']
        if     ($freeGB -lt 5)  { $score -= 15 }
        elseif ($freeGB -lt 15) { $score -= 6 }
    }
    if ($sym['rebootPending'])          { $score -= 5 }
    if ([int]$sym['bsod'] -gt 0)        { $score -= 18 }
    if ([int]$sym['diskErr'] -gt 0)     { $score -= 12 }
    if ([int]$sym['whea'] -gt 0)        { $score -= 12 }
    if ([int]$sym['critCount'] -gt 25)  { $score -= 6 }
    if ([int]$sym['svcStopped'] -gt 0)  { $score -= 4 * [int]$sym['svcStopped'] }
    if ([int]$sym['devProblems'] -gt 0) { $score -= [math]::Min(12, [int]$sym['devProblems'] * 3) }
    # --- Nuevas penalizaciones del diagnostico ampliado (5.2) ---
    if ($sym['ramSuspect']) { $score -= 10 }   # RAM sospechosa
    if ($sym.ContainsKey('batteryHealthPct') -and $null -ne $sym['batteryHealthPct']) {
        $bp = [int]$sym['batteryHealthPct']
        if ($bp -ge 0 -and $bp -lt 50) { $score -= 8 }   # bateria muy degradada (<50%)
    }
    if ($sym['netProblem']) { $score -= 8 }   # problemas de red persistentes
    # --- Clamp al rango [0,100] ---
    if ($score -lt 0)   { $score = 0 }
    if ($score -gt 100) { $score = 100 }
    return [int]$score
}

# Puntuacion de salud 0-100: recolecta sintomas reales del sistema (incluido el
# diagnostico ampliado persistido en estado.diag) y delega el calculo en la
# funcion pura Compute-Score.
function Get-HealthScore {
    $reasons = @()
    $sym = @{}
    # Disco SMART
    $bad = @(Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne 'Healthy' })
    $sym['smartBad'] = ($bad.Count -gt 0)
    if ($sym['smartBad']) { $reasons += "Disco con SMART degradado (-25)" }
    # Espacio libre
    $c = Get-PSDrive C; $freeGB = [math]::Round($c.Free/1GB,1)
    $sym['freeGB'] = $freeGB
    if     ($freeGB -lt 5)  { $reasons += "Menos de 5 GB libres en C: (-15)" }
    elseif ($freeGB -lt 15) { $reasons += "Poco espacio libre en C: (-6)" }
    # Reinicio pendiente
    $pend = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or `
            (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    $sym['rebootPending'] = [bool]$pend
    if ($pend) { $reasons += "Reinicio pendiente (-5)" }
    # Eventos criticos recientes (48h)
    $since = (Get-Date).AddHours(-48)
    $crit = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue)
    $bsod = @($crit | Where-Object { $_.Id -in 41,1001,6008 }).Count
    $disk = @($crit | Where-Object { $_.ProviderName -match 'disk|Ntfs|volmgr' }).Count
    $whea = @($crit | Where-Object { $_.ProviderName -match 'WHEA' }).Count
    $sym['bsod'] = $bsod; $sym['diskErr'] = $disk; $sym['whea'] = $whea; $sym['critCount'] = $crit.Count
    if ($bsod -gt 0) { $reasons += "Apagones/BSOD recientes: $bsod (-18)" }
    if ($disk -gt 0) { $reasons += "Errores de disco/NTFS recientes: $disk (-12)" }
    if ($whea -gt 0) { $reasons += "Errores de hardware (WHEA): $whea (-12)" }
    if ($crit.Count -gt 25) { $reasons += "Muchos eventos criticos en 48h: $($crit.Count) (-6)" }
    # Servicios clave parados
    $svcStopped = 0
    foreach ($svc in 'wuauserv','BITS','Winmgmt','EventLog') {
        $s = Get-Service $svc -ErrorAction SilentlyContinue
        if ($s -and $s.Status -ne 'Running' -and $s.StartType -ne 'Disabled') { $svcStopped++; $reasons += "Servicio $svc parado (-4)" }
    }
    $sym['svcStopped'] = $svcStopped
    # Dispositivos con problema
    $prob = @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -gt 0 }).Count
    $sym['devProblems'] = $prob
    if ($prob -gt 0) { $reasons += "Dispositivos con error: $prob" }
    # --- Diagnostico ampliado persistido (5.2): RAM, bateria, red ---
    $st = Read-State
    if (($st.PSObject.Properties.Name -contains 'diag') -and $st.diag) {
        if ($st.diag.ram -and ([string]$st.diag.ram.status -eq 'suspect')) {
            $sym['ramSuspect'] = $true; $reasons += "RAM sospechosa (-10)"
        }
        if ($st.diag.battery -and $st.diag.battery.present) {
            $bpRaw = $st.diag.battery.health_pct
            if ($null -ne $bpRaw -and [string]$bpRaw -ne '') {
                $bp = $null; try { $bp = [int]$bpRaw } catch { $bp = $null }
                if ($null -ne $bp) {
                    $sym['batteryHealthPct'] = $bp
                    if ($bp -ge 0 -and $bp -lt 50) { $reasons += "Bateria muy degradada: $bp% (-8)" }
                }
            }
        }
        if ($st.diag.network -and (($st.diag.network.connected -eq $false) -or ($st.diag.network.dns_ok -eq $false))) {
            $sym['netProblem'] = $true; $reasons += "Problemas de red persistentes (-8)"
        }
    }
    $score = Compute-Score $sym
    return [pscustomobject]@{ score = [int]$score; reasons = $reasons }
}

# --------------------------------------------------------------------------
# Forense del registro de eventos: ultimos errores que explican la causa raiz.
function Get-Forensics {
    $since = (Get-Date).AddDays(-7)
    $out = @()
    $ev = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue | Select-Object -First 400)
    $groups = @(
        @{ k='ARRANQUE/APAGON'; ids=@(41,6008,1001); prov='' },
        @{ k='DISCO/NTFS';      ids=@();             prov='disk|Ntfs|volmgr|stornvme|storahci' },
        @{ k='HARDWARE (WHEA)'; ids=@();             prov='WHEA' },
        @{ k='SERVICIOS';       ids=@();             prov='Service Control Manager' },
        @{ k='APLICACION';      ids=@(1000,1002);    prov='Application Error|.NET Runtime' }
    )
    foreach ($g in $groups) {
        $sel = $ev | Where-Object {
            ($g.ids.Count -gt 0 -and $_.Id -in $g.ids) -or ($g.prov -ne '' -and $_.ProviderName -match $g.prov)
        } | Select-Object -First 3
        foreach ($e in $sel) {
            $msg = ($e.Message -split "`n")[0]; if ($msg.Length -gt 90) { $msg = $msg.Substring(0,90) }
            $out += ("{0}|{1}|{2}|{3}" -f $g.k, $e.Id, $e.TimeCreated.ToString('MM-dd HH:mm'), $msg.Trim())
        }
    }
    if ($out.Count -eq 0) { "OK|0|-|Sin errores criticos en los ultimos 7 dias." } else { $out }
}

# --------------------------------------------------------------------------
# Auto-triage: a partir del score y la forense, recomienda fases (lista de IDs).
function Get-Triage {
    $h = Get-HealthScore
    $rec = New-Object System.Collections.Generic.List[string]
    foreach ($x in '00','01','02') { $rec.Add($x) }  # diagnostico+restore+limpieza siempre
    $since = (Get-Date).AddDays(-7)
    $ev = @(Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue)
    if (@($ev | Where-Object { $_.ProviderName -match 'disk|Ntfs|volmgr' }).Count -gt 0) { $rec.Add('03') }
    $rec.Add('04'); $rec.Add('05'); $rec.Add('06')  # disco/DISM/SFC base
    if ((Get-Service Winmgmt).Status -ne 'Running') { $rec.Add('07') }
    # WU roto?
    $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
    if ($wu -and $wu.Status -ne 'Running' -and $wu.StartType -ne 'Disabled') { $rec.Add('13') }
    "SCORE=$($h.score)"
    "RECOMENDADAS=$([string]::Join(',', ($rec | Select-Object -Unique)))"
}

# --------------------------------------------------------------------------
function New-RestorePoint {
    try {
        Enable-ComputerRestore -Drive 'C:' -ErrorAction SilentlyContinue
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        $prev = (Get-ItemProperty $k -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue).SystemRestorePointCreationFrequency
        Set-ItemProperty $k -Name SystemRestorePointCreationFrequency -Value 0 -Type DWord -ErrorAction SilentlyContinue
        $name = "Suite_Reparacion_$((Get-Date).ToString('yyyy-MM-dd_HH-mm'))"
        Checkpoint-Computer -Description $name -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        if ($null -ne $prev) { Set-ItemProperty $k -Name SystemRestorePointCreationFrequency -Value $prev -Type DWord } else { Remove-ItemProperty $k -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue }
        $rp = Get-ComputerRestorePoint | Where-Object { $_.Description -eq $name }
        if ($rp) { "RESULT=OK"; "NAME=$name" } else { "RESULT=FAIL"; "NAME=$name" }
    } catch { "RESULT=FAIL"; "ERROR=$($_.Exception.Message)" }
}

function Save-HealthHistory($score) {
    $scriptDir = $null
    if ($PSScriptRoot) {
        $scriptDir = $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $baseDir = if ($scriptDir) { Join-Path (Split-Path -Parent $scriptDir) "WPI_Suite" } else { $Work }
    if ($scriptDir -and (Test-Path $scriptDir)) {
        if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir -Force | Out-Null }
    } else {
        $baseDir = $Work
    }
    $historyFile = Join-Path $baseDir "health_history.json"
    $history = @()
    if (Test-Path $historyFile) {
        try { $history = Get-Content $historyFile -Raw | ConvertFrom-Json } catch {}
    }
    $entry = [pscustomobject]@{
        date  = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        score = [int]$score
    }
    $history = @($history) + $entry
    if ($history.Count -gt 10) { $history = $history[-10..-1] }
    try {
        [System.IO.File]::WriteAllText($historyFile, ($history | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
}

function Install-WingetBootstrap {
    $tempFile = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    try {
        $url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Write-Host "Descargando App Installer desde: $url"
        $webClient = New-Object System.Net.WebClient
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $webClient.DownloadFile($url, $tempFile)
        
        Write-Host "Instalando App Installer con Add-AppxPackage..."
        Add-AppxPackage -Path $tempFile -ErrorAction Stop
        Write-Host "Instalacion exitosa."
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        return $true
    } catch {
        Write-Host "Error en bootstrap de winget: $($_.Exception.Message)"
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

# --------------------------------------------------------------------------
# (3.7 / Bug 5 / Req 7) Deteccion fiable del tipo de disco.
# ConvertTo-MediaClass: funcion PURA que mapea un MediaType (numero o texto)
# a la clase canonica {SSD,HDD,UNKNOWN}. SSD=4 o 'SSD'; HDD=3 o 'HDD';
# cualquier otro valor (Unspecified=0, vacio, nulo, SCM=5...) -> UNKNOWN.
function ConvertTo-MediaClass($mt) {
    if ($null -eq $mt) { return 'UNKNOWN' }
    $s = ([string]$mt).Trim()
    if ($s -eq '') { return 'UNKNOWN' }
    switch -regex ($s.ToUpper()) {
        '^(4|SSD)$' { return 'SSD' }
        '^(3|HDD)$' { return 'HDD' }
        default     { return 'UNKNOWN' }
    }
}

# Resolve-OptimizeAction: funcion PURA. TRIM solo si SSD, DEFRAG solo si HDD
# claro, NONE en cualquier otro caso (abstencion segura: nunca desfragmenta
# ante tipo incierto, evitando danar un posible SSD).
function Resolve-OptimizeAction($media) {
    $m = ([string]$media).Trim().ToUpper()
    if     ($m -eq 'SSD') { return 'TRIM' }
    elseif ($m -eq 'HDD') { return 'DEFRAG' }
    else                  { return 'NONE' }
}

# Get-MediaType: identifica el disco fisico del volumen del sistema de forma
# fiable (por DeviceId, respaldo por SerialNumber) y devuelve SSD|HDD|UNKNOWN.
function Get-MediaType {
    try {
        $sys  = ($env:SystemDrive).TrimEnd(':')
        $disk = Get-Partition -DriveLetter $sys -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue
        $pd = $null
        if ($disk) {
            $pd = Get-PhysicalDisk -ErrorAction SilentlyContinue |
                  Where-Object { $_.DeviceId -eq $disk.Number } | Select-Object -First 1
            if (-not $pd -and $disk.SerialNumber) {
                $pd = Get-PhysicalDisk -ErrorAction SilentlyContinue |
                      Where-Object { $_.SerialNumber -and ($_.SerialNumber.Trim() -eq ([string]$disk.SerialNumber).Trim()) } |
                      Select-Object -First 1
            }
        }
        if (-not $pd) { return 'UNKNOWN' }
        return (ConvertTo-MediaClass $pd.MediaType)
    } catch { return 'UNKNOWN' }
}

# --------------------------------------------------------------------------
function Get-DeviceProblems {
    $p = @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -gt 0 })
    if ($p.Count -eq 0) { "OK|Sin dispositivos con problema."; return }
    foreach ($d in ($p | Select-Object -First 12)) {
        "PROB|$($d.ConfigManagerErrorCode)|$($d.Name)"
    }
}

# --------------------------------------------------------------------------
# Informe HTML autocontenido y bonito (tema oscuro). -Arg = ruta de salida.
function New-HtmlReport($outPath) {
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    try {
        $st = Read-State
        $sysPairs = Get-SysInfo

        $enc = { param($t) [System.Web.HttpUtility]::HtmlEncode([string]$t) }
        $circ = 527.79
        $bandColor = { param($s) if ($s -eq '-' -or $null -eq $s -or [string]$s -eq '') { '#94a3b8' } else { $v=0; try { $v=[int]$s } catch { return '#94a3b8' }; if ($v -ge 80) {'#22c55e'} elseif ($v -ge 50) {'#f59e0b'} else {'#ef4444'} } }
        $bandLabel = { param($s) if ($s -eq '-' -or $null -eq $s -or [string]$s -eq '') { 'sin datos' } else { $v=0; try { $v=[int]$s } catch { return 'sin datos' }; if ($v -ge 80) {'Buena'} elseif ($v -ge 50) {'Regular'} else {'Critica'} } }
        $offsetOf = { param($s) $v=0; try { $v=[int]$s } catch { $v=0 }; if ($v -lt 0){$v=0}; if ($v -gt 100){$v=100}; [math]::Round($circ * (1 - ($v/100.0)), 2) }
        $statusIcon = {
            param($res)
            switch ([string]$res) {
                'OK'    { "<svg viewBox='0 0 24 24' class='svgico' role='img' aria-label='correcto'><circle cx='12' cy='12' r='11' fill='#22c55e'/><path d='M7 12.4l3.2 3.2L17 8.8' fill='none' stroke='#04210f' stroke-width='2.6' stroke-linecap='round' stroke-linejoin='round'/></svg>" }
                'WARN'  { "<svg viewBox='0 0 24 24' class='svgico' role='img' aria-label='aviso'><path d='M12 2.5L23 21.5H1z' fill='#f59e0b'/><rect x='11' y='8.5' width='2' height='7' rx='1' fill='#3a2400'/><circle cx='12' cy='18' r='1.3' fill='#3a2400'/></svg>" }
                'ERROR' { "<svg viewBox='0 0 24 24' class='svgico' role='img' aria-label='error'><circle cx='12' cy='12' r='11' fill='#ef4444'/><path d='M8 8l8 8M16 8l-8 8' stroke='#2a0606' stroke-width='2.6' stroke-linecap='round'/></svg>" }
                'SKIP'  { "<svg viewBox='0 0 24 24' class='svgico' role='img' aria-label='omitido'><circle cx='12' cy='12' r='11' fill='#64748b'/><rect x='6.5' y='11' width='11' height='2' rx='1' fill='#0b1220'/></svg>" }
                default { "<svg viewBox='0 0 24 24' class='svgico'><circle cx='12' cy='12' r='11' fill='#94a3b8'/></svg>" }
            }
        }

        $before = $st.score_before; if ($null -eq $before) { $before = '-' }
        $after  = $st.score_after;  if ($null -eq $after)  { $after  = '-' }
        $hasBoth = ($st.score_before -ne $null -and $st.score_after -ne $null)
        $delta = 0; $deltaTxt = 'sin comparacion'
        if ($hasBoth) { $delta = [int]$st.score_after - [int]$st.score_before; $sign = if ($delta -ge 0) {'+'} else {''}; $deltaTxt = "$sign$delta puntos" }
        $deltaColor = if ($delta -gt 0) {'#22c55e'} elseif ($delta -lt 0) {'#ef4444'} else {'#94a3b8'}
        $mainScore = if ($after -ne '-') { $after } elseif ($before -ne '-') { $before } else { '-' }
        $mainColor = & $bandColor $mainScore
        $mainOffset = & $offsetOf $mainScore
        $mainLabel = & $bandLabel $mainScore
        $beforeColor = & $bandColor $before
        $afterColor  = & $bandColor $after
        $beforeOffset = & $offsetOf $before
        $afterOffset  = & $offsetOf $after

        $scriptDir = $null
        if ($PSScriptRoot) {
            $scriptDir = $PSScriptRoot
        } elseif ($MyInvocation.MyCommand.Path) {
            $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $baseDir = if ($scriptDir) { Join-Path (Split-Path -Parent $scriptDir) "WPI_Suite" } else { $Work }
        $historyFile = Join-Path $baseDir "health_history.json"
        $history = @()
        if (Test-Path $historyFile) {
            try { $history = Get-Content $historyFile -Raw | ConvertFrom-Json } catch {}
        }
        $historyHtml = ''
        if ($history -and $history.Count -gt 0) {
            $historyHtml += "<div class='trend-title'>Historial de Salud (Ultimas ejecuciones)</div><div class='trend-list'>"
            foreach ($h in $history) {
                $col = & $bandColor $h.score
                $historyHtml += "<div class='trend-item'><span class='trend-date'>$($h.date)</span><span class='trend-score' style='color:$col'>$($h.score)/100</span></div>"
            }
            $historyHtml += "</div>"
        }

        $sysMap = @{}
        foreach ($p in $sysPairs) { $kv = $p -split '=',2; if ($kv.Count -eq 2) { $sysMap[$kv[0]] = $kv[1] } }
        $sysOrder = @(@('OS','Sistema operativo'),@('EQUIPO','Equipo'),@('CPU','Procesador'),@('RAM','Memoria RAM'),@('DISCO','Disco C:'),@('UPTIME','Tiempo encendido'),@('USUARIO','Usuario'))
        $sysCards = ''
        foreach ($o in $sysOrder) { if ($sysMap.ContainsKey($o[0])) { $sysCards += "<div class='sys'><div class='sys-k'>$(& $enc $o[1])</div><div class='sys-v'>$(& $enc $sysMap[$o[0]])</div></div>" } }
        $machine = $sysMap['EQUIPO']; if (-not $machine) { $machine = $env:COMPUTERNAME }

        $phases = @($st.phases)
        $cOK=0;$cWARN=0;$cERR=0;$cSKIP=0
        $maxSecs = 1
        foreach ($ph in $phases) { $sv=0; try { $sv=[int]$ph.secs } catch {}; if ($sv -gt $maxSecs) { $maxSecs = $sv } }
        $rows = ''
        $bars = ''
        foreach ($ph in $phases) {
            $res = [string]$ph.result
            switch ($res) { 'OK' {$cOK++} 'WARN' {$cWARN++} 'ERROR' {$cERR++} 'SKIP' {$cSKIP++} }
            $lc = $res.ToLower()
            $note = if ([string]$ph.note -ne '') { "<div class='ph-note'>$(& $enc $ph.note)</div>" } else { '' }
            $rows += "<div class='ph ph-$lc'><div class='ph-dot'>$(& $statusIcon $res)</div><div class='ph-main'><div class='ph-top'><span class='ph-num'>$(& $enc $ph.num)</span><span class='ph-title'>$(& $enc $ph.title)</span><span class='ph-badge b-$lc'>$res</span></div>$note</div><div class='ph-secs'>$(& $enc $ph.secs)s</div></div>"
            $sv=0; try { $sv=[int]$ph.secs } catch {}
            $w = [math]::Round(100.0 * $sv / [math]::Max(1,$maxSecs)); if ($w -lt 2 -and $sv -gt 0) { $w = 2 }
            $bcol = switch ($res) { 'OK' {'#22c55e'} 'WARN' {'#f59e0b'} 'ERROR' {'#ef4444'} default {'#64748b'} }
            $bars += "<div class='bar-row'><div class='bar-lbl'>$(& $enc $ph.num) $(& $enc $ph.title)</div><div class='bar-track'><span style='width:$w%;background:$bcol'></span></div><div class='bar-val'>$(& $enc $ph.secs)s</div></div>"
        }
        if (-not $rows) { $rows = "<div class='empty'>No se registraron fases en esta ejecucion.</div>" }
        if (-not $bars) { $bars = "<div class='empty'>Sin tiempos que mostrar.</div>" }
        $totalPh = $phases.Count

        $findings = @($st.findings)
        $findHtml = ''
        $stepsList = New-Object System.Collections.Generic.List[string]
        foreach ($f in $findings) {
            $txt = [string]$f
            $sev = 'info'; $sevTxt = 'Aviso'
            if ($txt -match '(?i)SMART|BSOD|apag|WHEA|hardware|no reparables|danad|repositorio|integridad') { $sev='high'; $sevTxt='Importante' }
            elseif ($txt -match '(?i)espacio|reinicio pendiente|\bred\b|bateria|driver|dispositivo|\bRAM\b|servicio') { $sev='med'; $sevTxt='Revisar' }
            $findHtml += "<li class='find find-$sev'><span class='sev sev-$sev'>$sevTxt</span><span class='find-txt'>$(& $enc $txt)</span></li>"
            # Derivar paso recomendado a partir del hallazgo
            if ($txt -match '(?i)SMART')          { $stepsList.Add('Haz copia de seguridad de tus datos cuanto antes: un disco con SMART degradado puede fallar. Valora reemplazarlo.') }
            elseif ($txt -match '(?i)espacio')    { $stepsList.Add('Libera espacio en C: (desinstala lo que no uses o usa el Sensor de almacenamiento). Conviene tener mas de 15 GB libres.') }
            elseif ($txt -match '(?i)\bRAM\b|memor') { $stepsList.Add('Ejecuta el Diagnostico de memoria de Windows (mdsched.exe) y reinicia para comprobar la RAM.') }
            elseif ($txt -match '(?i)bateria')    { $stepsList.Add('La bateria esta degradada. Revisa el informe de bateria (powercfg /batteryreport) y valora sustituirla.') }
            elseif ($txt -match '(?i)reinicio pendiente') { $stepsList.Add('Reinicia el equipo para aplicar cambios pendientes antes de seguir reparando.') }
            elseif ($txt -match '(?i)no reparables|repositorio|integridad') { $stepsList.Add('Quedan componentes danados. Ejecuta DISM con un origen valido (install.wim) y vuelve a pasar SFC.') }
            elseif ($txt -match '(?i)driver|dispositivo') { $stepsList.Add('Actualiza los drivers de los dispositivos con error desde la web del fabricante o Windows Update.') }
            elseif ($txt -match '(?i)\bred\b|DNS')        { $stepsList.Add('Revisa la conexion de red y el DNS. Si persiste, prueba con un DNS publico (1.1.1.1 / 8.8.8.8).') }
        }
        $noFind = ($findings.Count -eq 0)
        if ($noFind) { $findHtml = "<li class='find find-ok'><span class='sev sev-ok'>Todo OK</span><span class='find-txt'>No se detectaron problemas relevantes durante el diagnostico.</span></li>" }

        # --- Proximos pasos recomendados (deduplicados) ---
        $stepsHtml = ''
        $seen = @{}
        foreach ($s in $stepsList) { if (-not $seen.ContainsKey($s)) { $seen[$s]=$true; $stepsHtml += "<li class='step-li'><span class='step-ic'>&#10148;</span><span>$(& $enc $s)</span></li>" } }
        if ($cERR -gt 0) { $stepsHtml = "<li class='step-li'><span class='step-ic'>&#10148;</span><span>Hubo fases con error: revisa el registro detallado en la carpeta WPI_Suite\Logs.</span></li>" + $stepsHtml }
        if (-not $stepsHtml) { $stepsHtml = "<li class='step-li step-ok'><span class='step-ic'>&#10003;</span><span>No hay acciones pendientes. Reinicia el equipo para asegurar que todos los cambios queden aplicados.</span></li>" }

        # ====================== DIAGNOSTICO AMPLIADO ======================
        $diagCards = ''
        if (($st.PSObject.Properties.Name -contains 'diag') -and $st.diag) {
            $d = $st.diag
            if ($d.ram) {
                $rs = [string]$d.ram.status
                $rp = switch ($rs) { 'ok' {'good'} 'suspect' {'bad'} default {'unknown'} }
                $rt = switch ($rs) { 'ok' {'Sin errores detectados'} 'suspect' {'Sospechosa'} default {'No evaluada'} }
                $mds = if ($d.ram.recommend_mdsched) { "<div class='d-hint'>Recomendado: ejecutar el Diagnostico de memoria de Windows (mdsched).</div>" } else { '' }
                $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-ram'></span>Memoria RAM</div><div class='d-pill pill-$rp'>$rt</div>$mds</div>"
            }
            if ($d.battery) {
                if ($d.battery.present) {
                    $bpRaw = $d.battery.health_pct
                    if ($null -ne $bpRaw -and [string]$bpRaw -ne '') {
                        $bp = 0; try { $bp = [int]$bpRaw } catch { $bp = 0 }
                        $bpcol = if ($bp -ge 80) {'#22c55e'} elseif ($bp -ge 50) {'#f59e0b'} else {'#ef4444'}
                        $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-bat'></span>Bateria</div><div class='bat-bar'><span style='width:$bp%;background:$bpcol'></span></div><div class='d-sub'>Salud estimada: <b style='color:$bpcol'>$bp%</b></div></div>"
                    } else {
                        $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-bat'></span>Bateria</div><div class='d-pill pill-unknown'>Presente, salud desconocida</div></div>"
                    }
                } else {
                    $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-bat'></span>Bateria</div><div class='d-pill pill-unknown'>No presente (equipo de sobremesa)</div></div>"
                }
            }
            if ($d.network) {
                $cc = if ($d.network.connected) {'good'} else {'bad'}
                $ct = if ($d.network.connected) {'Conectado'} else {'Sin conexion'}
                $dc = if ($d.network.dns_ok) {'good'} else {'bad'}
                $dt = if ($d.network.dns_ok) {'DNS OK'} else {'DNS con fallos'}
                $det = & $enc $d.network.details
                $lat = ''
                if (($d.network.PSObject.Properties.Name -contains 'dns_ms') -and $null -ne $d.network.dns_ms -and [string]$d.network.dns_ms -ne '') {
                    $ms = 0; try { $ms = [int]$d.network.dns_ms } catch {}
                    $lc2 = if ($ms -lt 60) {'#22c55e'} elseif ($ms -lt 200) {'#f59e0b'} else {'#ef4444'}
                    $lat = "<div class='d-sub'>Latencia DNS: <b style='color:$lc2'>$ms ms</b></div>"
                }
                $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-net'></span>Red</div><div class='pill-row'><span class='d-pill pill-$cc'>$ct</span><span class='d-pill pill-$dc'>$dt</span></div><div class='d-sub'>$det</div>$lat</div>"
            }
            if (($d.PSObject.Properties.Name -contains 'smart') -and $d.smart -and $d.smart.available) {
                $sm = $d.smart
                $pf = if ($sm.predict_fail) { "<span class='d-pill pill-bad'>Predice fallo</span>" } else { "<span class='d-pill pill-good'>Sin alerta</span>" }
                $extra = ''
                if ($null -ne $sm.temp_c -and [string]$sm.temp_c -ne '') { $tc=0; try{$tc=[int]$sm.temp_c}catch{}; $tcol = if ($tc -lt 50){'#22c55e'} elseif ($tc -lt 65){'#f59e0b'} else {'#ef4444'}; $extra += "<div class='d-sub'>Temperatura: <b style='color:$tcol'>$tc &deg;C</b></div>" }
                if ($null -ne $sm.wear_pct -and [string]$sm.wear_pct -ne '') { $wp=0; try{$wp=[int]$sm.wear_pct}catch{}; $wcol = if ($wp -lt 50){'#22c55e'} elseif ($wp -lt 80){'#f59e0b'} else {'#ef4444'}; $extra += "<div class='d-sub'>Desgaste (SSD): <b style='color:$wcol'>$wp%</b></div>" }
                if ($null -ne $sm.poh -and [string]$sm.poh -ne '') { $extra += "<div class='d-sub'>Horas encendido: <b>$(& $enc $sm.poh)</b></div>" }
                $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-smart'></span>Salud del disco (SMART)</div><div class='pill-row'>$pf</div>$extra</div>"
            }
            if (($d.PSObject.Properties.Name -contains 'bcd') -and $d.bcd) {
                $bok = if ($d.bcd.ok) {'good'} else {'bad'}
                $btx = if ($d.bcd.ok) {'Configuracion de arranque correcta'} else {'Arranque con incidencias'}
                $bdet = if ([string]$d.bcd.details -ne '') { "<div class='d-sub'>$(& $enc $d.bcd.details)</div>" } else { '' }
                $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-boot'></span>Arranque (BCD)</div><div class='d-pill pill-$bok'>$btx</div>$bdet</div>"
            }
            if (($d.PSObject.Properties.Name -contains 'startup') -and $d.startup -and @($d.startup).Count -gt 0) {
                $items = ''
                foreach ($s in @($d.startup)) { $items += "<li>$(& $enc $s.name)<span class='muted'> &mdash; $(& $enc $s.command)</span></li>" }
                $diagCards += "<div class='dcard dcard-wide'><div class='d-h'><span class='d-ic ic-start'></span>Programas al iniciar Windows</div><ul class='dev-list'>$items</ul></div>"
            }
            if (($d.PSObject.Properties.Name -contains 'processes') -and $d.processes -and @($d.processes).Count -gt 0) {
                $items = ''
                foreach ($pr in @($d.processes)) { $items += "<li>$(& $enc $pr.name)<span class='muted'> &mdash; $(& $enc $pr.mem_mb) MB</span></li>" }
                $diagCards += "<div class='dcard'><div class='d-h'><span class='d-ic ic-proc'></span>Procesos que mas memoria usan</div><ul class='dev-list'>$items</ul></div>"
            }
            if ($d.devices -and @($d.devices).Count -gt 0) {
                $items = ''
                foreach ($dev in @($d.devices)) { $items += "<li>$(& $enc $dev.name) <span class='muted'>(codigo $(& $enc $dev.code))</span></li>" }
                $diagCards += "<div class='dcard dcard-wide'><div class='d-h'><span class='d-ic ic-dev'></span>Dispositivos con aviso</div><ul class='dev-list'>$items</ul></div>"
            }
        }
        $diagSection = ''
        if ($diagCards) { $diagSection = "<h2 id='diag' class='sec-h'>Diagnostico ampliado</h2><div class='dgrid'>$diagCards</div>" }

        $compareSection = ''
        if ($hasBoth) {
            $compareSection = @"
<div class='compare'>
  <div class='mini'>
    <svg viewBox='0 0 200 200' class='gauge gauge-sm'><circle class='track' cx='100' cy='100' r='84'/><circle class='fill' cx='100' cy='100' r='84' style='--circ:$circ;--target:$beforeOffset;stroke:$beforeColor'/><text x='100' y='108' class='g-num' style='fill:$beforeColor'>$before</text></svg>
    <div class='mini-cap'>ANTES</div>
  </div>
  <div class='arrow'><span style='color:$deltaColor'>&#8594;</span><div class='delta-chip' style='color:$deltaColor;border-color:$deltaColor'>$deltaTxt</div></div>
  <div class='mini'>
    <svg viewBox='0 0 200 200' class='gauge gauge-sm'><circle class='track' cx='100' cy='100' r='84'/><circle class='fill' cx='100' cy='100' r='84' style='--circ:$circ;--target:$afterOffset;stroke:$afterColor'/><text x='100' y='108' class='g-num' style='fill:$afterColor'>$after</text></svg>
    <div class='mini-cap'>DESPUES</div>
  </div>
</div>
"@
        }

        $now = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        $execVerdict = & $bandLabel $mainScore
        $html = @"
<!DOCTYPE html>
<html lang='es'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Informe de Reparacion - WPI Suite v3.1</title>
<style>
*{box-sizing:border-box}
:root{--bg:#0b0f17;--bg2:#0d1422;--card:#121a2b;--card2:#0e1626;--line:#1e293b;--txt:#e6edf6;--muted:#93a3ba;--accent:#38bdf8;--accent2:#818cf8;--shadow:0 14px 40px rgba(0,0,0,.40)}
html.light{--bg:#eef2f8;--bg2:#e7edf6;--card:#ffffff;--card2:#f5f8fc;--line:#dde5f0;--txt:#0f172a;--muted:#5a6b82;--accent:#0284c7;--accent2:#4f46e5;--shadow:0 10px 28px rgba(15,23,42,.12)}
body{margin:0;font-family:'Segoe UI',system-ui,-apple-system,Arial,sans-serif;line-height:1.55;color:var(--txt);background:radial-gradient(1200px 600px at 80% -10%,rgba(56,189,248,.10),transparent 60%),radial-gradient(900px 500px at -10% 10%,rgba(129,140,248,.10),transparent 55%),var(--bg)}
.wrap{max-width:1080px;margin:0 auto;padding:30px 22px 60px}
.topbar{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:14px}
.logo{width:46px;height:46px;border-radius:13px;background:linear-gradient(135deg,var(--accent),var(--accent2));display:flex;align-items:center;justify-content:center;box-shadow:var(--shadow)}
h1{font-size:22px;margin:0;letter-spacing:.2px}
.sub{color:var(--muted);font-size:13px;margin-top:2px}
.badge{display:inline-block;background:linear-gradient(135deg,var(--accent),var(--accent2));color:#04293b;font-weight:700;border-radius:999px;padding:3px 12px;font-size:11.5px;letter-spacing:.4px;vertical-align:middle;margin-left:8px}
.btns{display:flex;gap:8px;flex-wrap:wrap}
.toggle{cursor:pointer;border:1px solid var(--line);background:var(--card);color:var(--txt);border-radius:10px;padding:8px 14px;font-size:13px;font-weight:600;box-shadow:var(--shadow)}
.toggle:hover{border-color:var(--accent)}
.toc{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 22px}
.toc a{font-size:12.5px;font-weight:600;color:var(--muted);text-decoration:none;border:1px solid var(--line);background:var(--card2);border-radius:999px;padding:6px 13px}
.toc a:hover{color:var(--accent);border-color:var(--accent)}
.exec{display:flex;align-items:center;gap:18px;flex-wrap:wrap;background:linear-gradient(180deg,var(--card),var(--card2));border:1px solid var(--line);border-radius:18px;padding:18px 22px;margin-bottom:22px;box-shadow:var(--shadow)}
.exec-score{font-size:46px;font-weight:800;line-height:1}
.exec-mid{flex:1;min-width:200px}
.exec-verdict{font-size:18px;font-weight:700}
.exec-line{color:var(--muted);font-size:13px;margin-top:2px}
.exec-delta{font-size:13px;font-weight:700;border:1px solid;border-radius:999px;padding:4px 12px;white-space:nowrap}
.hero{display:grid;grid-template-columns:minmax(240px,320px) 1fr;gap:20px;margin-bottom:22px}
@media(max-width:760px){.hero{grid-template-columns:1fr}}
.card{background:linear-gradient(180deg,var(--card),var(--card2));border:1px solid var(--line);border-radius:18px;padding:22px;box-shadow:var(--shadow)}
.gaugewrap{display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}
.gauge{width:210px;height:210px}
.gauge-sm{width:120px;height:120px}
.gauge .track{fill:none;stroke:var(--line);stroke-width:14}
.gauge .fill{fill:none;stroke-width:14;stroke-linecap:round;transform:rotate(-90deg);transform-origin:50% 50%;stroke-dasharray:var(--circ);stroke-dashoffset:var(--circ);animation:fill 1.4s cubic-bezier(.22,1,.36,1) .2s forwards}
.g-num{font-size:54px;font-weight:800;text-anchor:middle;font-family:'Segoe UI',system-ui,Arial}
.gauge-sm .g-num{font-size:46px}
.g-label{margin-top:6px;font-weight:700;font-size:15px}
.g-cap{color:var(--muted);font-size:12px;letter-spacing:1.5px;margin-top:2px}
.compare{display:flex;align-items:center;justify-content:center;gap:8px;margin-top:14px;flex-wrap:wrap}
.mini{text-align:center}
.mini-cap{color:var(--muted);font-size:11px;letter-spacing:1.2px;margin-top:-6px}
.arrow{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:30px;font-weight:800}
.delta-chip{border:1px solid;border-radius:999px;padding:3px 12px;font-size:12.5px;font-weight:700;white-space:nowrap}
.hero-side{display:flex;flex-direction:column;gap:16px}
.chips{display:flex;gap:10px;flex-wrap:wrap}
.chip{flex:1;min-width:96px;background:var(--card2);border:1px solid var(--line);border-radius:14px;padding:12px 14px;text-align:center}
.chip .n{font-size:26px;font-weight:800;line-height:1}
.chip .l{color:var(--muted);font-size:11.5px;letter-spacing:.6px;margin-top:3px}
.c-ok{color:#22c55e}.c-warn{color:#f59e0b}.c-err{color:#ef4444}.c-skip{color:#94a3b8}
.sysgrid{display:grid;grid-template-columns:1fr 1fr;gap:1px;background:var(--line);border-radius:14px;overflow:hidden}
@media(max-width:520px){.sysgrid{grid-template-columns:1fr}}
.sys{background:var(--card);padding:11px 14px}
.sys-k{color:var(--muted);font-size:11.5px;letter-spacing:.4px}
.sys-v{font-weight:600;font-size:14px;margin-top:1px;word-break:break-word}
h2.sec-h{font-size:15px;letter-spacing:.6px;text-transform:uppercase;color:var(--accent);margin:30px 0 12px;display:flex;align-items:center;gap:10px;scroll-margin-top:14px}
h2.sec-h::after{content:'';flex:1;height:1px;background:var(--line)}
.timeline{position:relative;padding-left:8px}
.ph{display:flex;align-items:flex-start;gap:14px;padding:13px 16px;border:1px solid var(--line);border-radius:14px;margin-bottom:10px;background:var(--card);position:relative;overflow:hidden}
.ph::before{content:'';position:absolute;left:0;top:0;bottom:0;width:4px}
.ph-ok::before{background:#22c55e}.ph-warn::before{background:#f59e0b}.ph-error::before{background:#ef4444}.ph-skip::before{background:#64748b}
.ph-dot{flex:0 0 auto;margin-top:1px}
.svgico{width:26px;height:26px;display:block}
.ph-main{flex:1;min-width:0}
.ph-top{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.ph-num{font-variant-numeric:tabular-nums;color:var(--muted);font-size:12px;font-weight:700;border:1px solid var(--line);border-radius:7px;padding:1px 7px}
.ph-title{font-weight:600;font-size:15px}
.ph-badge{font-size:11px;font-weight:800;letter-spacing:.6px;border-radius:999px;padding:2px 10px}
.b-ok{background:rgba(34,197,94,.16);color:#22c55e}.b-warn{background:rgba(245,158,11,.16);color:#f59e0b}.b-error{background:rgba(239,68,68,.16);color:#ef4444}.b-skip{background:rgba(100,116,139,.18);color:#94a3b8}
.ph-note{color:var(--muted);font-size:13px;margin-top:3px}
.ph-secs{flex:0 0 auto;color:var(--muted);font-size:13px;font-variant-numeric:tabular-nums;align-self:center}
.empty{color:var(--muted);padding:18px;text-align:center}
.barchart{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 18px;margin-top:4px}
.bar-row{display:flex;align-items:center;gap:12px;padding:5px 0}
.bar-lbl{flex:0 0 220px;font-size:12.5px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media(max-width:600px){.bar-lbl{flex:0 0 120px}}
.bar-track{flex:1;height:10px;border-radius:999px;background:var(--line);overflow:hidden}
.bar-track span{display:block;height:100%;border-radius:999px}
.bar-val{flex:0 0 auto;font-size:12.5px;color:var(--muted);font-variant-numeric:tabular-nums;width:48px;text-align:right}
ul.finds{list-style:none;margin:0;padding:0}
.find{display:flex;align-items:flex-start;gap:12px;padding:12px 16px;border:1px solid var(--line);border-radius:13px;margin-bottom:9px;background:var(--card)}
.sev{flex:0 0 auto;font-size:11px;font-weight:800;letter-spacing:.5px;border-radius:8px;padding:3px 10px;margin-top:1px}
.sev-high{background:rgba(239,68,68,.16);color:#ef4444}.sev-med{background:rgba(245,158,11,.16);color:#f59e0b}.sev-info{background:rgba(56,189,248,.16);color:var(--accent)}.sev-ok{background:rgba(34,197,94,.16);color:#22c55e}
.find-txt{font-size:14px}
ul.steps{list-style:none;margin:0;padding:0}
.step-li{display:flex;gap:11px;align-items:flex-start;padding:11px 16px;border:1px solid var(--line);border-left:3px solid var(--accent);border-radius:12px;margin-bottom:9px;background:var(--card);font-size:14px}
.step-ok{border-left-color:#22c55e}
.step-ic{color:var(--accent);font-weight:800}
.step-ok .step-ic{color:#22c55e}
.dgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px}
.dcard{background:var(--card);border:1px solid var(--line);border-radius:15px;padding:16px 18px}
.dcard-wide{grid-column:1/-1}
.d-h{display:flex;align-items:center;gap:9px;font-weight:700;font-size:14px;margin-bottom:10px}
.d-ic{width:14px;height:14px;border-radius:5px;display:inline-block}
.ic-ram{background:linear-gradient(135deg,#38bdf8,#0ea5e9)}.ic-bat{background:linear-gradient(135deg,#22c55e,#15803d)}.ic-net{background:linear-gradient(135deg,#818cf8,#4f46e5)}.ic-dev{background:linear-gradient(135deg,#f59e0b,#d97706)}.ic-smart{background:linear-gradient(135deg,#f472b6,#db2777)}.ic-boot{background:linear-gradient(135deg,#2dd4bf,#0d9488)}.ic-start{background:linear-gradient(135deg,#a78bfa,#7c3aed)}.ic-proc{background:linear-gradient(135deg,#fb7185,#e11d48)}
.d-pill{display:inline-block;font-size:12.5px;font-weight:700;border-radius:999px;padding:4px 12px}
.pill-row{display:flex;gap:8px;flex-wrap:wrap}
.pill-good{background:rgba(34,197,94,.16);color:#22c55e}.pill-bad{background:rgba(239,68,68,.16);color:#ef4444}.pill-unknown{background:rgba(148,163,184,.16);color:#94a3b8}
.d-sub{color:var(--muted);font-size:12.5px;margin-top:8px}
.d-hint{color:#f59e0b;font-size:12.5px;margin-top:8px}
.bat-bar{height:12px;border-radius:999px;background:var(--line);overflow:hidden;margin-top:4px}
.bat-bar span{display:block;height:100%;border-radius:999px}
.dev-list{margin:4px 0 0;padding-left:18px;font-size:13.5px}
.dev-list li{margin:2px 0}
.muted{color:var(--muted)}
.foot{margin-top:34px;text-align:center;color:var(--muted);font-size:12px}
.section{animation:rise .5s ease both}
@keyframes fill{to{stroke-dashoffset:var(--target)}}
@keyframes rise{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
@media print{.toggle,.toc,.btns,.toast{display:none}body{background:#fff;color:#000}.card,.dcard,.ph,.find,.exec,.barchart,.step-li{box-shadow:none;backdrop-filter:none;-webkit-backdrop-filter:none;background:#fff!important}.gauge .fill{animation:none}.section{animation:none}a[href]{color:inherit;text-decoration:none}}
:root{--glass:rgba(18,26,43,.60);--glassbd:rgba(255,255,255,.07)}
html.light{--glass:rgba(255,255,255,.64);--glassbd:rgba(15,23,42,.08)}
.card,.exec,.dcard,.find,.barchart,.step-li{background:var(--glass)!important;backdrop-filter:blur(13px) saturate(140%);-webkit-backdrop-filter:blur(13px) saturate(140%);border:1px solid var(--glassbd)!important}
.toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:linear-gradient(135deg,var(--accent),var(--accent2));color:#04293b;font-weight:700;padding:10px 18px;border-radius:12px;box-shadow:var(--shadow);opacity:0;pointer-events:none;transition:opacity .25s;z-index:60;font-size:13px}
.toast.show{opacity:1}
.trend-title{margin-top:20px;font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:var(--muted)}
.trend-list{display:flex;flex-direction:column;gap:4px;width:100%;margin-top:8px;border-top:1px solid var(--line);padding-top:8px}
.trend-item{display:flex;justify-content:space-between;font-size:12px}
.trend-date{color:var(--muted)}
.trend-score{font-weight:700}
</style>
</head>
<body>
<div class='wrap'>
  <div class='topbar'>
    <div class='brand'>
      <div class='logo'><svg viewBox='0 0 24 24' width='26' height='26' role='img' aria-label='WPI'><path d='M12 2l7 3v6c0 4.6-3 8.3-7 9.6C8 19.3 5 15.6 5 11V5z' fill='#04293b'/><path d='M9 12l2 2 4-4.5' fill='none' stroke='#dff6ff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/></svg></div>
      <div>
        <h1>Informe de Reparacion <span class='badge'>WPI SUITE v3.1</span></h1>
        <div class='sub'>$(& $enc $machine) &nbsp;&middot;&nbsp; generado el $now</div>
      </div>
    </div>
    <div class='btns'>
      <button class='toggle' onclick="window.print()">Imprimir / PDF</button>
      <button class='toggle' id='copybtn' onclick="copyResumen()">Copiar resumen</button>
      <button class='toggle' id='themebtn' onclick="toggleTheme()">Tema claro/oscuro</button>
    </div>
  </div>

  <nav class='toc' aria-label='Indice'>
    <a href='#resumen'>Resumen</a>
    <a href='#fases'>Fases</a>
    <a href='#hallazgos'>Hallazgos</a>
    <a href='#pasos'>Proximos pasos</a>
    <a href='#diag'>Diagnostico</a>
  </nav>

  <div id='resumen' class='exec section'>
    <div class='exec-score' style='color:$mainColor'>$mainScore</div>
    <div class='exec-mid'>
      <div class='exec-verdict' style='color:$mainColor'>Salud del sistema: $execVerdict</div>
      <div class='exec-line'>$cOK correctas &middot; $cWARN avisos &middot; $cERR errores &middot; $cSKIP omitidas &middot; $totalPh fases en total</div>
    </div>
    <div class='exec-delta' style='color:$deltaColor;border-color:$deltaColor'>$deltaTxt</div>
  </div>

  <div class='hero section'>
    <div class='card gaugewrap'>
      <svg viewBox='0 0 200 200' class='gauge' role='img' aria-label='Puntuacion de salud $mainScore sobre 100'><circle class='track' cx='100' cy='100' r='84'/><circle class='fill' cx='100' cy='100' r='84' style='--circ:$circ;--target:$mainOffset;stroke:$mainColor'/><text x='100' y='112' class='g-num' style='fill:$mainColor'>$mainScore</text></svg>
      <div class='g-label' style='color:$mainColor'>Salud: $mainLabel</div>
      <div class='g-cap'>PUNTUACION SOBRE 100</div>
      $compareSection
      $historyHtml
    </div>
    <div class='hero-side'>
      <div class='card'>
        <div class='chips'>
          <div class='chip'><div class='n c-ok'>$cOK</div><div class='l'>OK</div></div>
          <div class='chip'><div class='n c-warn'>$cWARN</div><div class='l'>AVISOS</div></div>
          <div class='chip'><div class='n c-err'>$cERR</div><div class='l'>ERRORES</div></div>
          <div class='chip'><div class='n c-skip'>$cSKIP</div><div class='l'>OMITIDAS</div></div>
        </div>
      </div>
      <div class='card'>
        <div class='sysgrid'>$sysCards</div>
      </div>
    </div>
  </div>

  <div class='section'>
    <h2 id='fases' class='sec-h'>Linea de tiempo de fases ($totalPh)</h2>
    <div class='timeline'>$rows</div>
    <div class='barchart'>$bars</div>
  </div>

  <div class='section'>
    <h2 id='hallazgos' class='sec-h'>Hallazgos y causa raiz</h2>
    <ul class='finds'>$findHtml</ul>
  </div>

  <div class='section'>
    <h2 id='pasos' class='sec-h'>Proximos pasos recomendados</h2>
    <ul class='steps'>$stepsHtml</ul>
  </div>

  <div class='section'>$diagSection</div>

  <div class='foot'>
    WPI &middot; Suite de Reparacion de Emergencia para Windows 10/11 &middot; informe de solo lectura.<br>
    Las copias de seguridad y los registros estan en la carpeta WPI_Suite junto al programa.
  </div>
</div>
<script>
(function(){try{var s=localStorage.getItem('wpi-theme');var root=document.documentElement;if(s==='light'){root.classList.add('light');}else if(s==='dark'){root.classList.remove('light');}else if(window.matchMedia&&window.matchMedia('(prefers-color-scheme: light)').matches){root.classList.add('light');}}catch(e){}})();
function toggleTheme(){try{var l=document.documentElement.classList.toggle('light');localStorage.setItem('wpi-theme',l?'light':'dark');}catch(e){}}
function flash(m){try{var t=document.createElement('div');t.className='toast';t.textContent=m;document.body.appendChild(t);requestAnimationFrame(function(){t.classList.add('show');});setTimeout(function(){t.classList.remove('show');setTimeout(function(){t.remove();},300);},1600);}catch(e){}}
function fb(txt,ok){try{var a=document.createElement('textarea');a.value=txt;a.style.position='fixed';a.style.left='-9999px';document.body.appendChild(a);a.select();document.execCommand('copy');a.remove();ok();}catch(e){flash('No se pudo copiar');}}
function copyResumen(){var p=[];var t=document.querySelector('h1');if(t)p.push(t.innerText.trim());var s=document.querySelector('.sub');if(s)p.push(s.innerText.trim());var ex=document.querySelector('.exec');if(ex)p.push('\n'+ex.innerText.replace(/\n{2,}/g,'\n').trim());var h=document.getElementById('hallazgos');if(h&&h.parentNode)p.push('\n'+h.parentNode.innerText.trim());var txt=p.join('\n');function ok(){flash('Resumen copiado');}if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(txt).then(ok,function(){fb(txt,ok);});}else{fb(txt,ok);}}
</script>
</body>
</html>
"@
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($outPath, $html, $utf8)
        "RESULT=OK"
        "PATH=$outPath"
    } catch {
        "RESULT=FAIL"
        "ERROR=$($_.Exception.Message)"
    }
}

# --------------------------------------------------------------------------
# Registrar resultado de una fase en el estado (para el informe).
# -Arg = "num;title;result;secs;note"
function Add-PhaseResult($spec) {
    $st = Read-State
    $parts = $spec -split ';',5
    $ph = [pscustomobject]@{ num=$parts[0]; title=$parts[1]; result=$parts[2]; secs=$parts[3]; note=$parts[4] }
    $list = @($st.phases) + $ph
    $st.phases = $list
    Write-State $st
    "RESULT=OK"
}
function Set-Score($which, $val) {
    $st = Read-State
    if ($which -eq 'before') { 
        $st.score_before = [int]$val 
    } else { 
        $st.score_after = [int]$val 
        Save-HealthHistory [int]$val
    }
    Write-State $st; "RESULT=OK"
}
function Add-Finding($text) {
    $st = Read-State; $st.findings = @($st.findings) + $text; Write-State $st; "RESULT=OK"
}

# ==========================================================================
#  LOGICA PURA NUEVA / CORREGIDA (Bloque 3)
# ==========================================================================

# --- (3.1 / Bug 4 / Req 6) Normalizacion de la seleccion de fases ----------
# Entrada: cadena con IDs separados por comas (espacios arbitrarios, 1-2
# digitos, posibles invalidos). Salida: objeto con .norm (lista canonica,
# ordenada, unica de IDs de 2 digitos en {00..16}) y .invalid (los no validos).
# Nunca lanza excepcion ante entrada malformada o vacia.
function Normalize-Fases([string]$raw) {
    $valid   = New-Object System.Collections.Generic.List[string]
    $invalid = New-Object System.Collections.Generic.List[string]
    if ($null -ne $raw -and $raw.Trim().Length -gt 0) {
        foreach ($t in ($raw -split ',')) {
            if ($null -eq $t) { continue }
            $tok = ($t -replace '\s', '')          # quitar espacios internos y externos
            if ($tok -eq '') { continue }
            $canon = $tok
            if ($tok -match '^\d$') { $canon = $tok.PadLeft(2, '0') }   # 1 digito -> 2 digitos
            if ($canon -match '^\d{2}$' -and [int]$canon -ge 0 -and [int]$canon -le 16) {
                if (-not $valid.Contains($canon)) { $valid.Add($canon) }
            } else {
                $invalid.Add($tok)
            }
        }
    }
    $sorted = @($valid | Sort-Object)
    return [pscustomobject]@{ norm = $sorted; invalid = @($invalid) }
}

# --- (3.3 / Req 4) Checkpoint sobre checkpoint.json ------------------------
# Parser del -Arg con formato:
#   "save|selection=00,01,02|completed=00,01|mode=auto:1;dry:0|reason=chkdsk"
function Parse-CheckpointArg([string]$raw) {
    $res = [ordered]@{ sub = ''; selection = @(); completed = @(); mode = @{}; reason = '' }
    if ([string]::IsNullOrEmpty($raw)) { return $res }
    $segs = $raw -split '\|'
    $res.sub = $segs[0].Trim().ToLower()
    for ($i = 1; $i -lt $segs.Count; $i++) {
        $kv = $segs[$i] -split '=', 2
        if ($kv.Count -lt 2) { continue }
        $key = $kv[0].Trim().ToLower()
        $val = $kv[1]
        switch ($key) {
            'selection' { $res.selection = @($val -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) }
            'completed' { $res.completed = @($val -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) }
            'reason'    { $res.reason = $val.Trim() }
            'mode' {
                $m = @{}
                foreach ($pair in ($val -split ';')) {
                    $p = $pair -split ':', 2
                    if ($p.Count -eq 2) { $m[$p[0].Trim().ToLower()] = ($p[1].Trim() -eq '1') }
                }
                $res.mode = $m
            }
        }
    }
    return $res
}

# Construye y persiste checkpoint.json. Devuelve $true/$false (sin excepcion).
function Save-Checkpoint($parsed) {
    try {
        $mode = [pscustomobject]@{
            auto     = [bool]$parsed.mode['auto']
            noreboot = [bool]$parsed.mode['noreboot']
            keepwu   = [bool]$parsed.mode['keepwu']
            dry      = [bool]$parsed.mode['dry']
            triage   = [bool]$parsed.mode['triage']
        }
        $now = (Get-Date).ToString('yyyy-MM-dd_HH-mm')
        $cp = [pscustomobject]@{
            version        = $WPI_VERSION
            created        = $now
            mode           = $mode
            selection      = @($parsed.selection)
            completed      = @($parsed.completed)
            pending_reason = $parsed.reason
            timestamp_run  = $now
        }
        [System.IO.File]::WriteAllText($CheckpointFile, ($cp | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
        return $true
    } catch { return $false }
}

# Carga checkpoint.json. Devuelve el objeto o $null si no existe / malformado.
function Load-Checkpoint {
    if (-not (Test-Path $CheckpointFile)) { return $null }
    try { return (Get-Content $CheckpointFile -Raw | ConvertFrom-Json) } catch { return $null }
}

# Valida un checkpoint: existe + parseable + version compatible + completed
# subconjunto de selection + created dentro de la ventana. Devuelve booleano
# SIN lanzar excepcion ante JSON malformado o caducado.
function Test-CheckpointValid($cp) {
    try {
        if ($null -eq $cp) {
            if (-not (Test-Path $CheckpointFile)) { return $false }
            try { $cp = Get-Content $CheckpointFile -Raw | ConvertFrom-Json } catch { return $false }
        }
        if ($null -eq $cp) { return $false }
        if ([string]$cp.version -ne $WPI_VERSION) { return $false }
        $sel  = @($cp.selection)
        $comp = @($cp.completed)
        foreach ($c in $comp) { if ($sel -notcontains $c) { return $false } }
        $created = $null
        if ($cp.created) {
            try { $created = [datetime]::ParseExact([string]$cp.created, 'yyyy-MM-dd_HH-mm', $null) } catch { $created = $null }
        }
        if ($null -eq $created) { return $false }
        $age = (Get-Date) - $created
        if ($age.TotalDays -gt $CHECKPOINT_MAX_AGE_DAYS) { return $false }
        return $true
    } catch { return $false }
}

# Primera fase de 'selection' no presente en 'completed' (o '' si todas hechas).
function Get-NextPhase($cp) {
    if ($null -eq $cp) { return '' }
    $comp = @($cp.completed)
    foreach ($s in @($cp.selection)) { if ($comp -notcontains $s) { return $s } }
    return ''
}

# --- (3.9 / Bug 6 / Req 8) Reset de estado reutilizable --------------------
# Deja phases=@(), findings=@() y los scores (before/after) a null. El
# condicionado a /resume lo aplica el batch (tareas 8.4 / 9.1): solo invoca
# 'resetstate' cuando RESUME==0, conservando el estado previo en /resume.
function Reset-State {
    Write-State ([pscustomobject]@{ score_before = $null; score_after = $null; findings = @(); phases = @() })
}

# --- (3.11 / Bug 7 / Req 9) Honestidad del movimiento de caches ------------
# Exito (true) SI Y SOLO SI el origen esta ausente y el destino presente.
# Variante pura (booleanos) + variante que acepta rutas y hace Test-Path.
function Test-MoveResult([bool]$srcExists, [bool]$dstExists) {
    return ((-not $srcExists) -and $dstExists)
}
function Test-MoveResultPath([string]$src, [string]$dst) {
    return (Test-MoveResult ([bool](Test-Path $src)) ([bool](Test-Path $dst)))
}

# --- (3.11 / Bug 8 / Req 10) Idempotencia de VirtualTerminalLevel ----------
# Normaliza valores '0x1' / '1' / 1 a entero para comparar de forma robusta.
function ConvertTo-VtlInt($v) {
    if ($null -eq $v) { return $null }
    $s = ([string]$v).Trim().ToLower()
    if ($s -eq '') { return $null }
    try {
        if ($s.StartsWith('0x')) { return [Convert]::ToInt32($s, 16) }
        return [int]$s
    } catch { return $null }
}
# Devuelve $true (escribir) solo si el valor actual difiere del deseado.
function Resolve-VtlWrite($current, $desired) {
    return ((ConvertTo-VtlInt $current) -ne (ConvertTo-VtlInt $desired))
}

# --- (3.14 / Req 1.3) Mapeo TOTAL de codigo de salida a {OK,WARN,SKIP,ERROR}
# 0->OK, 1->WARN, 2->SKIP, 3->ERROR; cualquier otro entero (o no entero) -> ERROR.
function Map-ExitCode($code) {
    $n = $null
    try { $n = [int]$code } catch { return 'ERROR' }
    switch ($n) {
        0       { 'OK' }
        1       { 'WARN' }
        2       { 'SKIP' }
        3       { 'ERROR' }
        default { 'ERROR' }
    }
}

# ==========================================================================
#  DIAGNOSTICO AMPLIADO (5.1 / Req 15.1-15.5)
# ==========================================================================

# --- RAM (Req 15.1) -------------------------------------------------------
# Resolve-RamStatus: funcion PURA. A partir del conteo de errores de memoria
# WHEA y de fallos del diagnostico de memoria de Windows, decide el estado y
# si conviene recomendar mdsched.
function Resolve-RamStatus([int]$wheaMemErrors, [int]$memDiagFailures) {
    if ($wheaMemErrors -gt 0 -or $memDiagFailures -gt 0) {
        return [pscustomobject]@{ status = 'suspect'; recommend_mdsched = $true }
    }
    return [pscustomobject]@{ status = 'ok'; recommend_mdsched = $false }
}

# Get-RamCheck: lee eventos WHEA y resultados del Diagnostico de memoria de
# Windows. Degradacion elegante: si la consulta de eventos falla por completo,
# devuelve status='unknown' sin lanzar excepcion.
function Get-RamCheck {
    try {
        $queried = $false
        $wheaCount = 0
        $memDiagFail = 0
        # Errores de hardware WHEA relacionados con memoria
        $whea = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'} -MaxEvents 100 -ErrorAction SilentlyContinue)
        if ($null -ne $whea) { $queried = $true }
        $wheaCount = @($whea | Where-Object { ($_.Id -in 18,19,20,47) -or ($_.Message -match 'memor') }).Count
        # Resultados del Diagnostico de memoria de Windows (mdsched)
        $md = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'} -MaxEvents 50 -ErrorAction SilentlyContinue)
        if ($null -ne $md) { $queried = $true }
        $memDiagFail = @($md | Where-Object { ($_.Id -eq 1002) -or ($_.LevelDisplayName -eq 'Error') -or ($_.Message -match 'error|errores') }).Count
        return (Resolve-RamStatus $wheaCount $memDiagFail)
    } catch {
        return [pscustomobject]@{ status = 'unknown'; recommend_mdsched = $false }
    }
}

# --- Bateria (Req 15.2) ---------------------------------------------------
# Get-BatteryHealthPct: funcion PURA. % de salud = plena carga / diseno * 100.
function Get-BatteryHealthPct($design, $full) {
    try {
        $d = [double]$design; $f = [double]$full
        if ($d -gt 0) { return [int][math]::Round(($f / $d) * 100) }
    } catch {}
    return $null
}

# Get-BatteryHealth: si hay bateria, genera powercfg /batteryreport y extrae la
# salud (capacidad de diseno vs plena carga). Sin bateria -> present=$false.
# No falla si powercfg no esta disponible (health_pct queda vacio).
function Get-BatteryHealth {
    $present = $false; $healthPct = ''; $reportPath = ''
    try {
        $bat = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        if ($bat.Count -gt 0) {
            $present = $true
            $reportPath = Join-Path $Work 'battery-report.html'
            try { & powercfg /batteryreport /output "$reportPath" /duration 1 > $null 2>&1 } catch {}
            if (Test-Path $reportPath) {
                try {
                    $txt = Get-Content $reportPath -Raw
                    $design = $null; $full = $null
                    $m1 = [regex]::Match($txt, '(?is)DESIGN CAPACITY.*?([\d\.,]+)\s*mWh')
                    $m2 = [regex]::Match($txt, '(?is)FULL CHARGE CAPACITY.*?([\d\.,]+)\s*mWh')
                    if ($m1.Success) { $design = [double](($m1.Groups[1].Value -replace '[\.,]', '')) }
                    if ($m2.Success) { $full   = [double](($m2.Groups[1].Value -replace '[\.,]', '')) }
                    $pct = Get-BatteryHealthPct $design $full
                    if ($null -ne $pct) { $healthPct = $pct }
                } catch {}
            }
        }
    } catch {}
    return [pscustomobject]@{ present = $present; health_pct = $healthPct; report_path = $reportPath }
}

# --- Red avanzada (Req 15.5) ----------------------------------------------
# Get-NetAdvanced: conectividad (ping a 1.1.1.1), DNS (Resolve-DnsName con
# respaldo por ping a un host) y configuracion basica (IP/gateway).
# Degradacion elegante: nunca lanza excepcion.
function Get-NetAdvanced {
    $connected = $false; $dnsOk = $false; $details = ''
    try {
        # Conectividad
        $ping = $false
        try { $ping = [bool](Test-Connection -ComputerName '1.1.1.1' -Count 1 -Quiet -ErrorAction SilentlyContinue) } catch { $ping = $false }
        if (-not $ping) {
            try { & ping -n 1 -w 1500 1.1.1.1 > $null 2>&1; if ($LASTEXITCODE -eq 0) { $ping = $true } } catch {}
        }
        $connected = [bool]$ping
        # Resolucion DNS (con medida de latencia)
        $dns = $false; $dnsMs = $null
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $r = Resolve-DnsName -Name 'www.microsoft.com' -ErrorAction SilentlyContinue
            $sw.Stop()
            if ($r) { $dns = $true; $dnsMs = [int]$sw.ElapsedMilliseconds }
        } catch {}
        if (-not $dns) {
            try { & ping -n 1 -w 1500 www.microsoft.com > $null 2>&1; if ($LASTEXITCODE -eq 0) { $dns = $true } } catch {}
        }
        $dnsOk = [bool]$dns
        # Configuracion basica (IP / gateway)
        $ip = ''; $gw = ''
        try {
            $cfg = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway }) | Select-Object -First 1
            if ($cfg) {
                $ip = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
                $gw = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
            }
        } catch {}
        $details = "IP=$ip; GW=$gw"
    } catch {}
    return [pscustomobject]@{ connected = $connected; dns_ok = $dnsOk; details = $details; dns_ms = $dnsMs }
}

# --- Dispositivos para diag (Req 15.3/15.4) -------------------------------
# Get-DeviceList: lista estructurada de dispositivos con error para estado.diag.
# Devuelve $null si la identificacion de drivers falla (senal de "info no
# disponible" para degradacion elegante).
function Get-DeviceList {
    try {
        $p = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.ConfigManagerErrorCode -gt 0 })
        $list = @()
        foreach ($d in ($p | Select-Object -First 12)) {
            $list += [pscustomobject]@{ code = [int]$d.ConfigManagerErrorCode; name = [string]$d.Name }
        }
        return ,$list
    } catch { return $null }
}

# ==========================================================================
#  ROTACION DE LOGS (5.6 / Req 17.2)
# ==========================================================================
# Select-LogsToDelete: funcion PURA. De una coleccion de ficheros (con
# .LastWriteTime) y una retencion N, devuelve los que deben BORRARSE: todos
# menos los N mas recientes (es decir, los mas antiguos). Si hay <= N, ninguno.
function Select-LogsToDelete($files, [int]$retention) {
    $arr = @($files)
    if ($retention -lt 0) { $retention = 0 }
    if ($arr.Count -le $retention) { return @() }
    $sorted = @($arr | Sort-Object -Property LastWriteTime -Descending)
    return @($sorted | Select-Object -Skip $retention)
}

# Invoke-LogRotate: conserva los $retention logs mas recientes en $folder y
# borra el resto. Devuelve el numero de ficheros borrados.
function Invoke-LogRotate([string]$folder, [int]$retention) {
    if ([string]::IsNullOrWhiteSpace($folder)) { $folder = Join-Path $Work 'Logs' }
    $deleted = 0
    try {
        if (-not (Test-Path $folder)) { return 0 }
        $files = @(Get-ChildItem -Path $folder -Filter '*.log' -File -ErrorAction SilentlyContinue)
        $toDelete = Select-LogsToDelete $files $retention
        foreach ($f in $toDelete) {
            try { Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue; $deleted++ } catch {}
        }
    } catch {}
    return $deleted
}

# ==========================================================================
#  VALIDACION DE ENTORNO Y SELF-TEST (5.8 / Req 13.5,13.6,18.1,18.3,18.6)
# ==========================================================================
# Test-OsSupported: funcion PURA. Windows 10/11 => build >= 10240.
function Test-OsSupported([int]$build) {
    return ($build -ge 10240)
}

# Invoke-EnvValidate: comprueba la version del SO via CIM. La comprobacion se
# considera SIEMPRE realizada (check_done) aunque la version no sea compatible.
function Invoke-EnvValidate {
    $build = 0
    try { $build = [int](Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).BuildNumber } catch { $build = 0 }
    if ($build -le 0) { try { $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber -ErrorAction SilentlyContinue).CurrentBuildNumber } catch { $build = 0 } }
    if ($build -le 0) { try { $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild -ErrorAction SilentlyContinue).CurrentBuild } catch { $build = 0 } }
    return [pscustomobject]@{ os_ok = (Test-OsSupported $build); build = $build; check_done = $true }
}

# Invoke-SelfTest: agregador PURO. Exito (true) si y solo si TODAS las
# comprobaciones (booleanos) pasan. Coleccion vacia -> true (nada fallo).
function Invoke-SelfTest($results) {
    foreach ($r in @($results)) { if (-not [bool]$r) { return $false } }
    return $true
}

# Parse-BoolList: convierte "1,1,0,1" (o true/ok) en una lista de booleanos.
function Parse-BoolList([string]$raw) {
    $list = @()
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        foreach ($t in ($raw -split ',')) {
            $tok = $t.Trim().ToLower()
            if ($tok -eq '') { continue }
            $list += ($tok -eq '1' -or $tok -eq 'true' -or $tok -eq 'ok' -or $tok -eq 'pass')
        }
    }
    return ,$list
}

# ==========================================================================
# ==========================================================================
#  DIAGNOSTICO PROFUNDO v3.1 (SMART, arranque, BCD, procesos, SFC, JSON)
#  Todas las funciones degradan con elegancia: si algo falla, devuelven
#  estructuras vacias / 'unknown' en lugar de lanzar excepciones.
# ==========================================================================

# Get-SmartAttributes: salud fisica del disco de sistema (independiente del
# idioma de Windows). Usa MSStorageDriver_FailurePredictStatus + el contador
# de fiabilidad de almacenamiento. Devuelve available=$false si no hay datos.
function Get-SmartAttributes {
    $res = [pscustomobject]@{ available = $false; predict_fail = $false; temp_c = $null; wear_pct = $null; poh = $null }
    try {
        $pf = $null
        try { $pf = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSStorageDriver_FailurePredictStatus' -ErrorAction SilentlyContinue) } catch { $pf = $null }
        if ($pf -and $pf.Count -gt 0) {
            $res.available = $true
            foreach ($x in $pf) { if ($x.PredictFailure) { $res.predict_fail = $true } }
        }
        # Disco que contiene C: -> contador de fiabilidad
        try {
            $sysDisk = $null
            try { $sysDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -ne $null } | Select-Object -First 1 } catch {}
            $rc = $null
            if ($sysDisk) { $rc = $sysDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue }
            if (-not $rc) { $rc = Get-PhysicalDisk -ErrorAction SilentlyContinue | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if ($rc) {
                $res.available = $true
                if ($null -ne $rc.Temperature -and $rc.Temperature -gt 0) { $res.temp_c = [int]$rc.Temperature }
                if ($null -ne $rc.Wear)         { $res.wear_pct = [int]$rc.Wear }
                if ($null -ne $rc.PowerOnHours) { $res.poh = [int]$rc.PowerOnHours }
            }
            # Senal adicional de prediccion de fallo via estado de salud fisica
            try {
                $unhealthy = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.HealthStatus -and $_.HealthStatus -ne 'Healthy' })
                if ($unhealthy.Count -gt 0) { $res.available = $true; $res.predict_fail = $true }
            } catch {}
        } catch {}
    } catch {}
    return $res
}

# Get-StartupItems: programas que arrancan con Windows (top N), para que el
# usuario vea que ralentiza el inicio. Independiente del idioma.
function Get-StartupItems([int]$top = 8) {
    try {
        $items = @(Get-CimInstance Win32_StartupCommand -ErrorAction Stop |
            Where-Object { $_.Command } |
            Select-Object -First $top)
        $list = @()
        foreach ($i in $items) {
            $cmd = [string]$i.Command
            if ($cmd.Length -gt 80) { $cmd = $cmd.Substring(0,77) + '...' }
            $nm = [string]$i.Name; if (-not $nm) { $nm = [string]$i.Caption }
            $list += [pscustomobject]@{ name = $nm; command = $cmd }
        }
        return ,$list
    } catch { return @() }
}

# Get-BcdIntegrity: comprueba que la configuracion de arranque (BCD) tiene la
# entrada actual con osdevice/device. Las CLAVES de bcdedit son siempre en
# ingles, asi que es independiente del idioma de la interfaz.
function Get-BcdIntegrity {
    $res = [pscustomobject]@{ ok = $false; details = '' }
    try {
        $out = & bcdedit /enum '{current}' 2>$null
        $txt = ($out -join "`n")
        if ($LASTEXITCODE -eq 0 -and $txt -match '(?im)^\s*osdevice' -and $txt -match '(?im)^\s*device') {
            $res.ok = $true
            $res.details = 'Entrada de arranque actual integra (device/osdevice presentes).'
        } else {
            $res.ok = $false
            $res.details = 'No se pudo confirmar la entrada de arranque actual.'
        }
    } catch {
        $res.ok = $false
        $res.details = 'bcdedit no disponible o sin permisos.'
    }
    return $res
}

# Get-TopProcesses: procesos que mas memoria de trabajo consumen (top N).
function Get-TopProcesses([int]$top = 6) {
    try {
        $ps = @(Get-Process -ErrorAction SilentlyContinue |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First $top)
        $list = @()
        foreach ($p in $ps) {
            $mb = [math]::Round($p.WorkingSet64 / 1MB)
            $list += [pscustomobject]@{ name = [string]$p.ProcessName; mem_mb = [int]$mb }
        }
        return ,$list
    } catch { return @() }
}

# Get-SfcResult: clasifica el resultado de SFC leyendo CBS.log (SIEMPRE en
# ingles) en lugar de la salida traducida de la consola. Devuelve uno de:
# clean | repaired | unrepairable | unknown.
function Get-SfcResult {
    $log = Join-Path $env:windir 'Logs\CBS\CBS.log'
    if (-not (Test-Path $log)) { return 'unknown' }
    try {
        $tail = @(Get-Content -Path $log -Tail 4000 -ErrorAction SilentlyContinue)
        $sr = @($tail | Where-Object { $_ -match '\[SR\]' })
        if ($sr.Count -eq 0) { return 'unknown' }
        $joined = ($sr -join "`n")
        if ($joined -match '(?i)cannot repair') { return 'unrepairable' }
        if ($joined -match '(?i)repairing\s+([1-9]\d*)\s+components|successfully repaired|repaired file|repairing corrupted file') { return 'repaired' }
        if ($joined -match '(?i)verify complete|no .*integrity violations|cannot verify|verifying') { return 'clean' }
        return 'clean'
    } catch { return 'unknown' }
}

# New-JsonReport: vuelca el estado + resumen calculado a un fichero JSON
# (-Arg = ruta de salida). Util para automatizacion / MDM / inventario.
function New-JsonReport($outPath) {
    try {
        $st = Read-State
        $sysPairs = Get-SysInfo
        $sysMap = @{}
        foreach ($p in $sysPairs) { $kv = $p -split '=',2; if ($kv.Count -eq 2) { $sysMap[$kv[0]] = $kv[1] } }
        $phases = @($st.phases)
        $cOK=0;$cWARN=0;$cERR=0;$cSKIP=0
        foreach ($ph in $phases) { switch ([string]$ph.result) { 'OK' {$cOK++} 'WARN' {$cWARN++} 'ERROR' {$cERR++} 'SKIP' {$cSKIP++} } }
        $delta = $null
        if ($st.score_before -ne $null -and $st.score_after -ne $null) { $delta = [int]$st.score_after - [int]$st.score_before }
        $obj = [pscustomobject]@{
            schema       = 'wpi-report/1'
            version      = $WPI_VERSION
            generated    = (Get-Date).ToString('s')
            machine      = $env:COMPUTERNAME
            system       = $sysMap
            score_before = $st.score_before
            score_after  = $st.score_after
            score_delta  = $delta
            summary      = [pscustomobject]@{ ok=$cOK; warn=$cWARN; error=$cERR; skip=$cSKIP; total=$phases.Count }
            phases       = $phases
            findings     = @($st.findings)
            diag         = $st.diag
        }
        $json = $obj | ConvertTo-Json -Depth 8
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($outPath, $json, $utf8)
        "RESULT=OK"
        "PATH=$outPath"
    } catch {
        "RESULT=FAIL"
        "ERROR=$($_.Exception.Message)"
    }
}

# New-SupportPackage: empaqueta logs + informe + estado + battery-report en un
# ZIP (-Arg = ruta del zip) para enviar a soporte. Sin dependencias externas
# (usa Compress-Archive, incluido en Windows 10/11).
function New-SupportPackage($outPath) {
    try {
        $tmp = Join-Path $Work ('soporte_' + (Get-Date).ToString('yyyyMMdd_HHmmss'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        # estado.json
        if (Test-Path $StateFile) { Copy-Item $StateFile (Join-Path $tmp 'estado.json') -Force -ErrorAction SilentlyContinue }
        # Logs
        $logs = Join-Path $Work 'Logs'
        if (Test-Path $logs) {
            $dstLogs = Join-Path $tmp 'Logs'
            New-Item -ItemType Directory -Path $dstLogs -Force | Out-Null
            Get-ChildItem $logs -File -ErrorAction SilentlyContinue | Copy-Item -Destination $dstLogs -Force -ErrorAction SilentlyContinue
        }
        # Informes HTML/JSON existentes en Work
        Get-ChildItem $Work -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)^Informe.*\.(html|json)$' } |
            Copy-Item -Destination $tmp -Force -ErrorAction SilentlyContinue
        # battery report si existe
        $st = Read-State
        try { if ($st.diag -and $st.diag.battery -and $st.diag.battery.report_path -and (Test-Path $st.diag.battery.report_path)) { Copy-Item $st.diag.battery.report_path $tmp -Force -ErrorAction SilentlyContinue } } catch {}
        if (Test-Path $outPath) { Remove-Item $outPath -Force -ErrorAction SilentlyContinue }
        Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $outPath -Force -ErrorAction Stop
        try { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        "RESULT=OK"
        "PATH=$outPath"
    } catch {
        "RESULT=FAIL"
        "ERROR=$($_.Exception.Message)"
    }
}

switch ($Action.ToLower()) {
    'none'         { } # Usado para dot-sourcing
    'checkbackups' {
        $parts = $Arg -split '\|', 2
        if ($parts.Count -ne 2) { "RESULT=FAIL"; "ERROR=Argumentos invalidos"; exit 0 }
        $bkdir = $parts[0]
        $ts = $parts[1]
        $rp_ok = $false
        try {
            $rps = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
            foreach ($rp in $rps) {
                if ($rp.Description -like "Suite_Reparacion_*") { $rp_ok = $true; break }
            }
        } catch { $rp_ok = $false }
        $reg_ok = $true
        $soft = Join-Path $bkdir "SOFTWARE_$ts.reg"
        $sys = Join-Path $bkdir "SYSTEM_$ts.reg"
        if (-not (Test-Path $soft) -or (Get-Item $soft).Length -eq 0) { $reg_ok = $false }
        if (-not (Test-Path $sys) -or (Get-Item $sys).Length -eq 0) { $reg_ok = $false }
        "RP_OK=$(if ($rp_ok) {'1'} else {'0'})"
        "REG_OK=$(if ($reg_ok) {'1'} else {'0'})"
    }
    'bootstrapwinget' {
        $ok = Install-WingetBootstrap
        "BOOTSTRAP_OK=$(if ($ok) {'1'} else {'0'})"
    }
    'findlocalsource' {
        $drives = Get-PSDrive -PSProvider FileSystem
        $paths = @()
        $editionId = ''
        try { $editionId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID -ErrorAction Stop).EditionID } catch {}
        function Get-InstallImageSource([string]$kind, [string]$path, [string]$edition) {
            $index = 1
            try {
                $images = @(Get-WindowsImage -ImagePath $path -ErrorAction Stop)
                $match = $null
                if ($edition -match 'Professional') { $match = $images | Where-Object { $_.ImageName -match '\bPro\b|Professional' } | Select-Object -First 1 }
                elseif ($edition -match 'Enterprise') { $match = $images | Where-Object { $_.ImageName -match 'Enterprise' } | Select-Object -First 1 }
                elseif ($edition -match 'Education') { $match = $images | Where-Object { $_.ImageName -match 'Education' } | Select-Object -First 1 }
                elseif ($edition -match 'Core') { $match = $images | Where-Object { $_.ImageName -match '\bHome\b|Core' } | Select-Object -First 1 }
                if ($null -eq $match -and $images.Count -eq 1) { $match = $images[0] }
                if ($null -ne $match) { $index = [int]$match.ImageIndex }
            } catch {}
            return ("{0}:{1}:{2}" -f $kind, $path, $index)
        }
        foreach ($d in $drives) {
            $root = $d.Root
            $wim = Join-Path $root "sources\install.wim"
            $esd = Join-Path $root "sources\install.esd"
            $sxs = Join-Path $root "sources\sxs"
            if (Test-Path $wim) { $paths += (Get-InstallImageSource 'Wim' $wim $editionId) }
            if (Test-Path $esd) { $paths += (Get-InstallImageSource 'Esd' $esd $editionId) }
            if (Test-Path $sxs) { $paths += $sxs }
        }
        if ($paths.Count -gt 0) { "SOURCE=$($paths[0])" } else { "SOURCE=" }
    }
    'dismrestore' {
        $parts = @($Arg -split '\|', 2)
        $source = if ($parts.Count -ge 1) { $parts[0] } else { '' }
        $timeoutMinutes = 45
        if ($parts.Count -ge 2) { [void][int]::TryParse($parts[1], [ref]$timeoutMinutes) }
        if ($timeoutMinutes -lt 5) { $timeoutMinutes = 5 }

        function Quote-DismValue([string]$value) {
            if ([string]::IsNullOrWhiteSpace($value)) { return $value }
            return '"' + ($value -replace '"', '\"') + '"'
        }

        $arguments = '/Online /Cleanup-Image /RestoreHealth'
        if (-not [string]::IsNullOrWhiteSpace($source)) {
            $arguments += ' /Source:' + (Quote-DismValue $source) + ' /LimitAccess'
        }

        $timedOut = $false
        $exitCode = 3
        $outFile = Join-Path $Work ("dism_restore_{0}.out" -f ([guid]::NewGuid().ToString('N')))
        $errFile = Join-Path $Work ("dism_restore_{0}.err" -f ([guid]::NewGuid().ToString('N')))
        try {
            $psi = [Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = ('/c dism.exe {0} > "{1}" 2> "{2}"' -f $arguments, $outFile, $errFile)
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $p = [Diagnostics.Process]::new()
            $p.StartInfo = $psi
            [void]$p.Start()
            if (-not $p.WaitForExit($timeoutMinutes * 60 * 1000)) {
                $timedOut = $true
                try { $p.Kill() } catch {}
                $exitCode = 1460
            } else {
                try { $p.WaitForExit() } catch {}
                $exitCode = $p.ExitCode
                if ($null -eq $exitCode) { $exitCode = 3 }
            }
        } catch {
            "ERROR=$($_.Exception.Message)"
            $exitCode = 3
        }

        if (Test-Path $outFile) { Get-Content -LiteralPath $outFile -ErrorAction SilentlyContinue }
        if (Test-Path $errFile) { Get-Content -LiteralPath $errFile -ErrorAction SilentlyContinue }
        Remove-Item -LiteralPath $outFile,$errFile -Force -ErrorAction SilentlyContinue
        "TIMEDOUT=$(if ($timedOut) {'1'} else {'0'})"
        "EXITCODE=$exitCode"
    }
    'sysinfo'      { Get-SysInfo }
    'score'        { $h = Get-HealthScore; "SCORE=$($h.score)"; foreach ($r in $h.reasons) { "REASON=$r" } }
    'forensics'    { Get-Forensics }
    'triage'       { Get-Triage }
    'restorepoint' { New-RestorePoint }
    'mediatype'    { $media = Get-MediaType; "MEDIA=$media"; "OPTIMIZE=$(Resolve-OptimizeAction $media)" }
    'devices'      { Get-DeviceProblems }
    'report'       { Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue; New-HtmlReport $Arg }
    'addphase'     { Add-PhaseResult $Arg }
    'setbefore'    { Set-Score 'before' $Arg }
    'setafter'     { Set-Score 'after' $Arg }
    'finding'      { Add-Finding $Arg }
    'resetstate'   { Reset-State; "RESULT=OK" }
    'normalizefases' {
        $r = Normalize-Fases $Arg
        "NORM=$([string]::Join(',', @($r.norm)))"
        "INVALID=$([string]::Join(',', @($r.invalid)))"
    }
    'checkpoint' {
        $parsed = Parse-CheckpointArg $Arg
        switch ($parsed.sub) {
            'save' { if (Save-Checkpoint $parsed) { "RESULT=OK" } else { "RESULT=FAIL" } }
            'load' {
                $cp = Load-Checkpoint
                if ($null -eq $cp) { "RESULT=NONE" }
                else {
                    "RESULT=OK"
                    "VALID=$(if (Test-CheckpointValid $cp) {'1'} else {'0'})"
                    "VERSION=$($cp.version)"
                    "CREATED=$($cp.created)"
                    "SELECTION=$([string]::Join(',', @($cp.selection)))"
                    "COMPLETED=$([string]::Join(',', @($cp.completed)))"
                    "REASON=$($cp.pending_reason)"
                    "NEXT=$(Get-NextPhase $cp)"
                    "MODE_AUTO=$(if ($cp.mode.auto) {'1'} else {'0'})"
                    "MODE_NOREBOOT=$(if ($cp.mode.noreboot) {'1'} else {'0'})"
                    "MODE_KEEPWU=$(if ($cp.mode.keepwu) {'1'} else {'0'})"
                    "MODE_DRY=$(if ($cp.mode.dry) {'1'} else {'0'})"
                    "MODE_TRIAGE=$(if ($cp.mode.triage) {'1'} else {'0'})"
                }
            }
            'next' {
                $cp = Load-Checkpoint
                if ($null -ne $cp -and (Test-CheckpointValid $cp)) { "NEXT=$(Get-NextPhase $cp)" } else { "NEXT=" }
            }
            'clear' {
                if (Test-Path $CheckpointFile) {
                    try { Remove-Item $CheckpointFile -Force -ErrorAction Stop; "RESULT=OK" } catch { "RESULT=FAIL" }
                } else { "RESULT=OK" }
            }
            default { "RESULT=FAIL"; "ERROR=subaccion de checkpoint desconocida" }
        }
    }
    'moveresult' {
        $parts = $Arg -split '\|', 2
        if ($parts.Count -eq 2) {
            $ok = Test-MoveResultPath $parts[0] $parts[1]
        } else {
            $b  = $Arg -split ','
            $se = ($b.Count -ge 1 -and $b[0].Trim() -eq '1')
            $de = ($b.Count -ge 2 -and $b[1].Trim() -eq '1')
            $ok = Test-MoveResult $se $de
        }
        "MOVED=$(if ($ok) {'1'} else {'0'})"
    }
    'vtlwrite' {
        $p   = $Arg -split ','
        $cur = if ($p.Count -ge 1) { $p[0] } else { '' }
        $des = if ($p.Count -ge 2) { $p[1] } else { [string]$VT_LEVEL_DESIRED }
        "WRITE=$(if (Resolve-VtlWrite $cur $des) {'1'} else {'0'})"
    }
    'mapexit'      { "RES=$(Map-ExitCode $Arg)" }
    # --- (5.1 / Req 15) Diagnostico ampliado ---
    'ramcheck' {
        $r = Get-RamCheck
        $st = Initialize-Diag (Read-State)
        $st.diag.ram = [pscustomobject]@{ status = $r.status; recommend_mdsched = [bool]$r.recommend_mdsched }
        Write-State $st
        "RAM_STATUS=$($r.status)"
        "RAM_RECOMMEND_MDSCHED=$(if ($r.recommend_mdsched) {'1'} else {'0'})"
    }
    'battery' {
        $b = Get-BatteryHealth
        $st = Initialize-Diag (Read-State)
        $st.diag.battery = [pscustomobject]@{ present = [bool]$b.present; health_pct = $b.health_pct; report_path = $b.report_path }
        Write-State $st
        "BATTERY_PRESENT=$(if ($b.present) {'1'} else {'0'})"
        "BATTERY_HEALTH_PCT=$($b.health_pct)"
        "BATTERY_REPORT=$($b.report_path)"
    }
    'netadvanced' {
        $n = Get-NetAdvanced
        $st = Initialize-Diag (Read-State)
        $st.diag.network = [pscustomobject]@{ connected = [bool]$n.connected; dns_ok = [bool]$n.dns_ok; details = $n.details; dns_ms = $n.dns_ms }
        Write-State $st
        "NET_CONNECTED=$(if ($n.connected) {'1'} else {'0'})"
        "NET_DNS_OK=$(if ($n.dns_ok) {'1'} else {'0'})"
        "NET_DETAILS=$($n.details)"
        "NET_LATENCY_MS=$($n.dns_ms)"
    }
    'diagfull' {
        $st = Initialize-Diag (Read-State)
        $r = Get-RamCheck
        $st.diag.ram = [pscustomobject]@{ status = $r.status; recommend_mdsched = [bool]$r.recommend_mdsched }
        $b = Get-BatteryHealth
        $st.diag.battery = [pscustomobject]@{ present = [bool]$b.present; health_pct = $b.health_pct; report_path = $b.report_path }
        $n = Get-NetAdvanced
        $st.diag.network = [pscustomobject]@{ connected = [bool]$n.connected; dns_ok = [bool]$n.dns_ok; details = $n.details; dns_ms = $n.dns_ms }
        $dev = Get-DeviceList
        if ($null -eq $dev) {
            $st.diag.devices = @()
            $devLine = "DEVICES_STATUS=info no disponible"
        } else {
            $st.diag.devices = @($dev)
            $devLine = "DEVICES_COUNT=$(@($dev).Count)"
        }
        $sm = Get-SmartAttributes
        $st.diag.smart = [pscustomobject]@{ available = [bool]$sm.available; predict_fail = [bool]$sm.predict_fail; temp_c = $sm.temp_c; wear_pct = $sm.wear_pct; poh = $sm.poh }
        $stp = Get-StartupItems 8
        $st.diag.startup = @($stp)
        $bcd = Get-BcdIntegrity
        $st.diag.bcd = [pscustomobject]@{ ok = [bool]$bcd.ok; details = $bcd.details }
        $procs = Get-TopProcesses 6
        $st.diag.processes = @($procs)
        Write-State $st
        "RAM_STATUS=$($r.status)"
        "RAM_RECOMMEND_MDSCHED=$(if ($r.recommend_mdsched) {'1'} else {'0'})"
        "BATTERY_PRESENT=$(if ($b.present) {'1'} else {'0'})"
        "BATTERY_HEALTH_PCT=$($b.health_pct)"
        "NET_CONNECTED=$(if ($n.connected) {'1'} else {'0'})"
        "NET_DNS_OK=$(if ($n.dns_ok) {'1'} else {'0'})"
        "NET_LATENCY_MS=$($n.dns_ms)"
        "SMART_AVAILABLE=$(if ($sm.available) {'1'} else {'0'})"
        "SMART_PREDICT_FAIL=$(if ($sm.predict_fail) {'1'} else {'0'})"
        "BCD_OK=$(if ($bcd.ok) {'1'} else {'0'})"
        $devLine
    }
    # --- (v3.1) SFC independiente del idioma + JSON + paquete de soporte ---
    'sfcresult' {
        "SFC_RES=$(Get-SfcResult)"
    }
    'jsonreport' {
        $out = if ([string]::IsNullOrWhiteSpace($Arg)) { Join-Path $Work 'Informe.json' } else { $Arg }
        New-JsonReport $out
    }
    'supportpackage' {
        $out = if ([string]::IsNullOrWhiteSpace($Arg)) { Join-Path $Work 'Paquete_Soporte.zip' } else { $Arg }
        New-SupportPackage $out
    }
    # --- (5.6 / Req 17.2) Rotacion de logs ---
    'logrotate' {
        $folder = if ([string]::IsNullOrWhiteSpace($Arg)) { Join-Path $Work 'Logs' } else { $Arg }
        $n = Invoke-LogRotate $folder $LOG_RETENTION
        "DELETED=$n"
    }
    # --- (5.8 / Req 13,18) Validacion de entorno y self-test ---
    'envcheck' {
        $e = Invoke-EnvValidate
        "OS_OK=$(if ($e.os_ok) {'1'} else {'0'})"
        "OS_BUILD=$($e.build)"
        "OS_CHECK_DONE=1"
    }
    'selftestbrain' { "BRAIN_OK=1" }
    'selftestresult' {
        $pass = Invoke-SelfTest (Parse-BoolList $Arg)
        "SELFTEST_PASS=$(if ($pass) {'1'} else {'0'})"
    }
    default        { Get-SysInfo }
}
