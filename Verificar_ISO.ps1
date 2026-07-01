param([string]$Iso, [string]$ExpectedLang = '')
try { $Host.UI.RawUI.WindowTitle = 'WPI - Verificador de ISO' } catch {}
$ErrorActionPreference = 'SilentlyContinue'
$mnt = 'C:\_wpichk'
$score = 0; $max = 0; $fatal = 0
function Line($c){ if (-not $c){ $c = '=' }; ('  ' + ($c * 62)) }
function Hdr($t){ Write-Host ''; Write-Host (Line '=') -ForegroundColor DarkCyan; Write-Host ('   ' + $t) -ForegroundColor Cyan; Write-Host (Line '=') -ForegroundColor DarkCyan }
function OK($m){ Write-Host ('   [OK] ' + $m) -ForegroundColor Green }
function NO($m){ Write-Host ('   [X]  ' + $m) -ForegroundColor Red }
function WN($m){ Write-Host ('   [!]  ' + $m) -ForegroundColor Yellow }
function IN($m){ Write-Host ('        ' + $m) -ForegroundColor Gray }
function Chk($cond,$okMsg,$noMsg,$warn){
    $script:max++
    if ($cond){ $script:score++; OK $okMsg }
    elseif ($warn){ WN $noMsg }
    else { NO $noMsg; $script:fatal++ }
}
function Cleanup {
    Get-WindowsImage -Mounted 2>$null | Where-Object { $_.Path -eq $mnt } | ForEach-Object { Dismount-WindowsImage -Path $mnt -Discard 2>$null | Out-Null }
    if ($Iso) { Dismount-DiskImage -ImagePath $Iso 2>$null | Out-Null }
}

try { Clear-Host } catch {}
Write-Host ''
Write-Host '   ==============================================================' -ForegroundColor DarkCyan
Write-Host '            W P I   -   V E R I F I C A D O R   D E   I S O' -ForegroundColor Cyan
Write-Host '            Comprueba que la ISO lo lleva TODO antes de Rufus' -ForegroundColor Gray
Write-Host '   ==============================================================' -ForegroundColor DarkCyan

$adm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $adm) { NO 'Ejecuta esta comprobacion como ADMINISTRADOR (montar la imagen lo requiere).'; Read-Host '   Enter para salir'; exit 1 }

if (-not $Iso) {
    $cands = @(Get-ChildItem -Path $PSScriptRoot -Filter *.iso -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    if ($cands.Count -gt 0) { $Iso = $cands[-1].FullName; IN ('ISO autodetectada (mas reciente de la carpeta): ' + $Iso) }
    else { NO ('No se ha indicado -Iso y no hay ningun .iso en la carpeta: ' + $PSScriptRoot); Read-Host '   Enter para salir'; exit 1 }
}
$Iso = $Iso.Trim('"')
if (-not (Test-Path $Iso)) { NO ('No existe la ISO: ' + $Iso); Read-Host '   Enter para salir'; exit 1 }
$ExpectedLang = $ExpectedLang.Trim().ToUpperInvariant()
if ($ExpectedLang -and $ExpectedLang -notin @('ES','EN')) { NO 'ExpectedLang debe ser ES o EN.'; Read-Host '   Enter para salir'; exit 1 }
IN ('ISO    : ' + $Iso)
IN ('Tamano : ' + ('{0:N2} GB' -f ((Get-Item $Iso).Length / 1GB)))
if ($ExpectedLang) { IN ('Idioma esperado de suite: ' + $ExpectedLang) } else { IN 'Idioma esperado de suite: cualquiera (ES o EN)' }
Cleanup

Hdr 'MONTAJE'
$vol = Mount-DiskImage -ImagePath $Iso -PassThru | Get-Volume
if (-not $vol -or -not $vol.DriveLetter) { NO 'No se pudo montar la ISO.'; Read-Host '   Enter para salir'; exit 1 }
$drv = ([string]$vol.DriveLetter + ':')
OK ('ISO montada en ' + $drv)
$wim = ($drv + '\sources\install.wim'); $fmt = 'WIM'
if (-not (Test-Path $wim)) { $wim = ($drv + '\sources\install.esd'); $fmt = 'ESD' }
Chk (Test-Path $wim) ('Imagen de Windows encontrada (' + $fmt + ')') 'No hay install.wim/esd en \sources.' $false
if (-not (Test-Path $wim)) { Cleanup; Read-Host '   Enter para salir'; exit 1 }

Hdr 'AUTOUNATTEND  (instalacion desatendida)'
$au = ($drv + '\autounattend.xml')
if (Test-Path $au) {
    OK 'autounattend.xml presente en la raiz de la ISO.'
    $xml = Get-Content $au -Raw
    Chk ($xml -match 'WPI_Moderno\.ps1') 'El primer arranque lanza WPI_Moderno.ps1.' 'El autounattend NO llama a WPI_Moderno.ps1.' $false
    Chk ($xml -match '-FirstBoot') 'Marca -FirstBoot (aplica todo y reinicia al final).' 'No aparece -FirstBoot (no reiniciaria solo).' $true
    if ($xml -match 'LabConfig') { IN 'Bypass de requisitos de Windows 11: SI' } else { IN 'Bypass de requisitos de Windows 11: no' }
} else { NO 'No hay autounattend.xml en la raiz: la instalacion NO seria automatica.' }

Hdr 'EDICIONES EN LA IMAGEN'
$imgs = @(Get-WindowsImage -ImagePath $wim)
foreach ($im in $imgs) { IN ('[' + $im.ImageIndex + ']  ' + $im.ImageName) }
IN ('Total de ediciones: ' + $imgs.Count)
if (-not (Test-Path $mnt)) { New-Item -ItemType Directory -Path $mnt -Force | Out-Null }

foreach ($im in $imgs) {
    Hdr ('EDICION [' + $im.ImageIndex + ']  ' + $im.ImageName)
    Mount-WindowsImage -ImagePath $wim -Index $im.ImageIndex -Path $mnt -ReadOnly | Out-Null
    $wpi = Join-Path $mnt 'WPI'
    Chk (Test-Path (Join-Path $wpi 'WPI_Moderno.ps1')) 'C:\WPI\WPI_Moderno.ps1 (motor)' 'FALTA C:\WPI\WPI_Moderno.ps1: no se aplicaria nada.' $false
    Chk (Test-Path (Join-Path $wpi 'Iniciar_WPI.bat')) 'C:\WPI\Iniciar_WPI.bat (lanzador)' 'Falta Iniciar_WPI.bat.' $true
    $suiteEsBat = Join-Path $wpi 'Suite_Reparacion_ES\Suite_Reparacion_TodoEnUno.bat'
    $suiteEnBat = Join-Path $wpi 'Suite_Reparacion_EN\Repair_Suite_AllInOne.bat'
    if ($ExpectedLang -eq 'ES') {
        Chk (Test-Path $suiteEsBat) 'C:\WPI\Suite_Reparacion_ES (suite + launcher)' 'Falta el lanzador principal de la suite espanola.' $true
    } elseif ($ExpectedLang -eq 'EN') {
        Chk (Test-Path $suiteEnBat) 'C:\WPI\Suite_Reparacion_EN (suite + launcher)' 'Falta el lanzador principal de la suite inglesa.' $true
    } else {
        $hasSuite = (Test-Path $suiteEsBat) -or (Test-Path $suiteEnBat)
        Chk ($hasSuite) 'C:\WPI\Suite_Reparacion_XX (suite + launcher)' 'Falta el lanzador principal de la suite de reparacion (ES o EN).' $true
    }
    $pa = Join-Path $wpi 'preset_apps.txt'
    if (Test-Path $pa) { $na = @(Get-Content $pa | Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') }).Count; OK ('preset_apps.txt  (' + $na + ' apps a instalar)') } else { WN 'Sin preset_apps.txt (no instalaria apps).' }
    $pt = Join-Path $wpi 'preset_tweaks.txt'
    if (Test-Path $pt) { $nt = @(Get-Content $pt | Where-Object { $_.Trim() -ne '' }).Count; OK ('preset_tweaks.txt  (' + $nt + ' tweaks a aplicar)') } else { WN 'Sin preset_tweaks.txt.' }
    $wg = Join-Path $wpi 'winget'
    if (Test-Path $wg) { $nb = @(Get-ChildItem $wg -Filter *.msixbundle).Count; OK ('winget OFFLINE integrado  (' + $nb + ' bundle)') } else { WN 'Sin winget offline (usaria modo online en el 1er arranque).' }
    $drvs = @(Get-WindowsDriver -Path $mnt | Where-Object { -not $_.Inbox })
    if ($drvs.Count -gt 0) { OK ('Drivers de terceros inyectados: ' + $drvs.Count) } else { IN 'Drivers de terceros: 0 (no inyectaste, o esta edicion no los lleva).' }
    Dismount-WindowsImage -Path $mnt -Discard | Out-Null
}
Cleanup

Hdr 'VEREDICTO'
IN ('Comprobaciones superadas: ' + $score + ' / ' + $max)
Write-Host ''
if ($fatal -eq 0) {
    Write-Host '   ##############################################################' -ForegroundColor Green
    Write-Host '   #            ISO LISTA PARA GRABAR EN RUFUS                  #' -ForegroundColor Green
    Write-Host '   ##############################################################' -ForegroundColor Green
} else {
    Write-Host ('   !!! HAY ' + $fatal + ' PROBLEMA(S) CRITICO(S). Revisa lo marcado con [X]. !!!') -ForegroundColor Red
    Write-Host '   No grabes hasta corregirlo (recrea la ISO desde cero).' -ForegroundColor Yellow
}
Write-Host ''
Write-Host '   RUFUS: en el dialogo "Experiencia de usuario de Windows" NO marques' -ForegroundColor Yellow
Write-Host '   NINGUNA casilla. Esquema GPT, destino UEFI. Asi se respeta el WPI.' -ForegroundColor Yellow
Write-Host ''
Read-Host '   Pulsa Enter para salir'
