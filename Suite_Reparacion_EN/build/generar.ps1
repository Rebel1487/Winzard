<#
.SYNOPSIS
    Generador de build de la Suite de Reparacion de Windows (v3.0 "WPI").
    Tareas 2.1 y 2.2 - Genera los 18 .bat autonomos desde la fuente unica de verdad
    (src/), calcula hashes de los bloques embebidos (manifest.lock.json) y ofrece un
    modo de verificacion -Check.

.DESCRIPTION
    Ensambla cada .bat distribuible concatenando, en este orden:

        cabecera (header.cmd) + cuerpo (orquestador/fase NN) + libreria (lib_wpi.cmd) + bloque HLP

    El bloque HLP se construye codificando src/suite_helper.ps1 en base64, troceandolo
    en lineas y anteponiendo "HLP:" a cada una. El batch lo decodifica de vuelta tomando
    todo lo que va tras el primer ':' de cada linea HLP y aplicando FromBase64String, por
    lo que el round-trip reproduce byte a byte el cerebro original.

    Las lineas de documentacion ::SRC de los ficheros .cmd de src/ se descartan antes de
    ensamblar. La salida se escribe en ASCII, con saltos de linea CRLF y sin BOM, igual
    que los .bat originales.

    HASHING Y LOCK (Tarea 2.2):
    Al generar, se calcula el SHA-256 del bloque LIBRERIA y del bloque CEREBRO (HLP)
    embebidos en cada .bat, asi como el hash del cerebro canonico (suite_helper.ps1) y de
    la libreria canonica. El resultado se escribe en build/manifest.lock.json e incluye la
    version, los hashes canonicos, la longitud de linea HLP usada y la lista de los 18
    ficheros objetivo con el hash de sus bloques embebidos.

    MODO -Check (Tarea 2.2):
    Con -Check el generador NO escribe nada. Reconstruye en memoria lo que generaria desde
    src/, extrae de cada .bat EXISTENTE su bloque libreria (desde ":wpi_initcolors" hasta
    antes del primer "HLP:") y su bloque HLP (lineas "HLP:"), y los compara por hash contra
    la fuente canonica. Asi verifica la equivalencia exigida por el Requisito 14.3: los 18
    ficheros comparten exactamente el mismo bloque de libreria y el mismo bloque cerebro, e
    identicos a la fuente canonica. Si algun .bat diverge (o falta), imprime que
    fichero/bloque difiere y devuelve un codigo de salida != 0. Si todo coincide, imprime
    OK y devuelve 0.

    NOTA: este script es una herramienta de mantenimiento. Los .bat generados son
    autonomos (libreria + cerebro embebidos) y no dependen de src/ ni de este generador
    para ejecutarse.

.PARAMETER OutDir
    Carpeta donde se generan (o, con -Check, donde se buscan) los .bat. En generacion, por
    defecto "build/out" (no sobrescribe la raiz). En -Check, si se indica se verifica esa
    carpeta; si no, se verifica la raiz del repositorio.

.PARAMETER InPlace
    Si se indica, escribe (o verifica) los .bat directamente en la raiz del repositorio,
    sobrescribiendo los de produccion. La regeneracion definitiva sobre la raiz es la
    tarea 11.1.

.PARAMETER HlpLineLength
    Longitud (en caracteres) de cada linea base64 del bloque HLP. Por defecto 200, igual
    que los .bat originales. Cualquier valor produce un bloque decodificable.

.PARAMETER Check
    No escribe nada. Compara los .bat existentes contra lo que se generaria y devuelve un
    codigo de salida != 0 si hay divergencia (uso en CI y self-test, Req 14.3).

.EXAMPLE
    pwsh -File build/generar.ps1
    Genera los 18 .bat en build/out/ y actualiza build/manifest.lock.json.

.EXAMPLE
    pwsh -File build/generar.ps1 -Check -OutDir build/out
    Verifica que los .bat de build/out coinciden con la fuente canonica (exit 0 si OK).

.EXAMPLE
    pwsh -File build/generar.ps1 -InPlace
    Regenera los 18 .bat sobre la raiz (uso previsto en la tarea 11.1).

.NOTES
    Funciones reutilizables: Build-HlpBlock, Assemble-Bat, Get-PhaseFileName,
    Get-SourceBody, Write-BatFile (Tarea 2.1) y, para el hashing/verificacion,
    Get-Sha256OfLines, Get-EmbeddedLibraryBlock, Get-EmbeddedHlpBlock,
    Get-AllTargets (Tarea 2.2).
#>
[CmdletBinding()]
param(
    [string]$OutDir,
    [switch]$InPlace,
    [int]$HlpLineLength = 200,
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Rutas base (relativas al propio script para no depender del cwd) -----------------
$BuildDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $BuildDir
$SrcDir   = Join-Path $RepoRoot 'src'
$LockPath = Join-Path $BuildDir 'manifest.lock.json'

# =====================================================================================
# Funciones reutilizables
# =====================================================================================

function Get-PhaseFileName {
    <#
        Devuelve el nombre de fichero .bat de produccion para un id de fase de 2 digitos.
        Respeta los nombres existentes en la raiz del repositorio.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PhaseId)

    $names = @{
        '00' = 'Phase_00_Diagnosis_and_triage.bat'
        '01' = 'Phase_01_Restore_point.bat'
        '02' = 'Phase_02_Initial_cleanup.bat'
        '03' = 'Phase_03_CHKDSK.bat'
        '04' = 'Phase_04_Disk_optimization.bat'
        '05' = 'Phase_05_DISM.bat'
        '06' = 'Phase_06_SFC_and_verify.bat'
        '07' = 'Phase_07_Repair_WMI.bat'
        '08' = 'Phase_08_Store_apps_and_Start.bat'
        '09' = 'Phase_09_Search_and_caches.bat'
        '10' = 'Phase_10_Certificates_and_time.bat'
        '11' = 'Phase_11_Network.bat'
        '12' = 'Phase_12_GPO_policies.bat'
        '13' = 'Phase_13_Windows_Update.bat'
        '14' = 'Phase_14_Winget.bat'
        '15' = 'Phase_15_Devices.bat'
        '16' = 'Phase_16_Final_cleanup_and_report.bat'
    }

    if (-not $names.ContainsKey($PhaseId)) {
        throw "Id de fase desconocido: '$PhaseId' (se esperaba 00..16)."
    }
    return $names[$PhaseId]
}

function Get-AllTargets {
    <#
        Devuelve los 18 objetivos (orquestador + fases 00..16) en orden, cada uno con su
        nombre de fichero .bat y la ruta del cuerpo correspondiente en src/.
    #>
    [CmdletBinding()]
    param()

    $targets = New-Object System.Collections.Generic.List[object]
    $targets.Add([pscustomobject]@{
        Name     = 'Repair_Suite_AllInOne.bat'
        BodyPath = (Join-Path $SrcDir 'orquestador.body.cmd')
    })
    foreach ($n in 0..16) {
        $id = '{0:D2}' -f $n
        $targets.Add([pscustomobject]@{
            Name     = (Get-PhaseFileName -PhaseId $id)
            BodyPath = (Join-Path $SrcDir "fase_$id.body.cmd")
        })
    }
    return $targets.ToArray()
}

function Get-SourceBody {
    <#
        Lee un fichero .cmd de src/ y devuelve sus lineas como array, descartando las
        lineas de documentacion con centinela ::SRC. Acepta cualquier EOL de entrada
        (se reensambla con CRLF mas adelante).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encuentra el fichero de origen: $Path"
    }
    $lines = [System.IO.File]::ReadAllLines($Path)
    return @($lines | Where-Object { $_ -notmatch '^\s*::SRC' })
}

function Build-HlpBlock {
    <#
        Codifica el cerebro PowerShell (suite_helper.ps1) en base64 y lo trocea en lineas
        con prefijo "HLP:". El batch reconstruye el base64 concatenando lo que va tras el
        primer ':' de cada linea HLP y aplica FromBase64String.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HelperPath,
        [int]$LineLength = 200
    )

    if (-not (Test-Path -LiteralPath $HelperPath)) {
        throw "No se encuentra el cerebro: $HelperPath"
    }
    if ($LineLength -lt 1) { throw "HlpLineLength debe ser >= 1." }

    $bytes  = [System.IO.File]::ReadAllBytes($HelperPath)
    $base64 = [System.Convert]::ToBase64String($bytes)

    $lines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $base64.Length; $i += $LineLength) {
        $len   = [System.Math]::Min($LineLength, $base64.Length - $i)
        $chunk = $base64.Substring($i, $len)
        $lines.Add("HLP:$chunk")
    }
    return $lines.ToArray()
}

function Assemble-Bat {
    <#
        Ensambla un .bat completo: cabecera + cuerpo + libreria + bloque HLP.
        Devuelve el texto final con saltos de linea CRLF (sin escribir a disco).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$HeaderLines,
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$BodyLines,
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$LibraryLines,
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$HlpLines
    )

    $all = New-Object System.Collections.Generic.List[string]
    $all.AddRange([string[]]$HeaderLines)
    $all.AddRange([string[]]$BodyLines)
    $all.AddRange([string[]]$LibraryLines)
    $all.AddRange([string[]]$HlpLines)

    # CRLF entre todas las lineas y un CRLF final (igual que los .bat originales).
    return ([string]::Join("`r`n", $all.ToArray()) + "`r`n")
}

function Write-BatFile {
    <#
        Escribe el texto del .bat en ASCII, con CRLF y sin BOM.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Content)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

# =====================================================================================
# Hashing y extraccion de bloques (Tarea 2.2)
# =====================================================================================

function Get-Sha256Hex {
    <#
        SHA-256 (hex en minusculas) de un array de bytes.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha.Dispose()
    }
}

function Get-Sha256OfLines {
    <#
        SHA-256 de un bloque de lineas. Se normaliza uniendo con LF para que el hash sea
        independiente del estilo de salto de linea (CRLF en el .bat vs LF en memoria) y
        compare solo el contenido logico del bloque.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines)

    $text = [string]::Join("`n", $Lines)
    return (Get-Sha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes($text)))
}

function Get-EmbeddedLibraryBlock {
    <#
        Extrae el bloque LIBRERIA de un .bat ya ensamblado: desde la primera subrutina de
        la libreria (":wpi_initcolors") hasta la linea anterior al primer "HLP:".
        Devuelve un array de lineas, o $null si no se localizan ambos limites.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines)

    $libStart = -1
    $hlpStart = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($libStart -lt 0 -and $Lines[$i] -match '^:wpi_initcolors\s*$') { $libStart = $i }
        if ($Lines[$i] -match '^HLP:') { $hlpStart = $i; break }
    }
    if ($libStart -lt 0 -or $hlpStart -lt 0 -or $libStart -ge $hlpStart) { return $null }
    return @($Lines[$libStart..($hlpStart - 1)])
}

function Get-EmbeddedHlpBlock {
    <#
        Extrae el bloque CEREBRO de un .bat: todas las lineas que empiezan por "HLP:".
        Devuelve un array de lineas, o $null si no hay ninguna.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines)

    $hlp = @($Lines | Where-Object { $_ -match '^HLP:' })
    if ($hlp.Count -eq 0) { return $null }
    return $hlp
}

function Get-ManifestVersion {
    <#
        Lee WPI_VERSION del manifiesto canonico (src/manifest.psd1). Si falla, '0.0'.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ManifestPath)

    try {
        $data = Import-PowerShellDataFile -Path $ManifestPath
        if ($data.ContainsKey('WPI_VERSION')) { return [string]$data['WPI_VERSION'] }
    } catch {}
    return '0.0'
}

# =====================================================================================
# Preparacion comun: leer src/ y construir los bloques canonicos (ambos modos)
# =====================================================================================

Write-Host "Generador WPI - fuente: $SrcDir"

$headerLines  = Get-SourceBody -Path (Join-Path $SrcDir 'header.cmd')
$libraryLines = Get-SourceBody -Path (Join-Path $SrcDir 'lib_wpi.cmd')
$helperPath   = Join-Path $SrcDir 'suite_helper.ps1'
$hlpLines     = Build-HlpBlock -HelperPath $helperPath -LineLength $HlpLineLength

# Bloques canonicos tal y como se extraerian de un .bat generado (concatenando libreria +
# HLP y aplicando las mismas funciones de extraccion garantizamos comparaciones 1:1).
$canonicalCombined = @($libraryLines + $hlpLines)
$canonLibBlock = Get-EmbeddedLibraryBlock -Lines $canonicalCombined
$canonHlpBlock = Get-EmbeddedHlpBlock     -Lines $canonicalCombined

if ($null -eq $canonLibBlock) {
    throw "No se localizo ':wpi_initcolors' en la libreria canonica (src/lib_wpi.cmd)."
}
if ($null -eq $canonHlpBlock) {
    throw "No se genero ningun bloque HLP desde el cerebro canonico (src/suite_helper.ps1)."
}

$canonLibHash   = Get-Sha256OfLines -Lines $canonLibBlock
$canonHlpHash   = Get-Sha256OfLines -Lines $canonHlpBlock
$canonBrainHash = Get-Sha256Hex     -Bytes ([System.IO.File]::ReadAllBytes($helperPath))
$wpiVersion     = Get-ManifestVersion -ManifestPath (Join-Path $SrcDir 'manifest.psd1')

$targets = Get-AllTargets

# =====================================================================================
# MODO -Check : verificar, sin escribir, que los .bat existentes coinciden (Req 14.3)
# =====================================================================================

if ($Check) {
    if ($InPlace)      { $checkDir = $RepoRoot }
    elseif ($OutDir)   { $checkDir = if ([System.IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path (Get-Location).Path $OutDir } }
    else               { $checkDir = $RepoRoot }

    Write-Host "Modo -Check: verificando $checkDir contra la fuente canonica."
    Write-Host "  Libreria canonica SHA-256: $canonLibHash"
    Write-Host "  Cerebro (HLP)    SHA-256: $canonHlpHash"
    Write-Host ""

    $divergences = New-Object System.Collections.Generic.List[string]

    foreach ($t in $targets) {
        $path = Join-Path $checkDir $t.Name
        if (-not (Test-Path -LiteralPath $path)) {
            $divergences.Add("FALTA   $($t.Name): el fichero no existe en $checkDir")
            Write-Host "  [FALTA] $($t.Name)"
            continue
        }

        $lines    = [System.IO.File]::ReadAllLines($path)
        $libBlock = Get-EmbeddedLibraryBlock -Lines $lines
        $hlpBlock = Get-EmbeddedHlpBlock     -Lines $lines

        $issues = New-Object System.Collections.Generic.List[string]

        if ($null -eq $libBlock) {
            $issues.Add("bloque LIBRERIA ausente o ilegible (no se hallo ':wpi_initcolors' antes de 'HLP:')")
        } else {
            $h = Get-Sha256OfLines -Lines $libBlock
            if ($h -ne $canonLibHash) {
                $issues.Add("bloque LIBRERIA difiere (esperado $canonLibHash, hallado $h)")
            }
        }

        if ($null -eq $hlpBlock) {
            $issues.Add("bloque CEREBRO (HLP) ausente")
        } else {
            $h = Get-Sha256OfLines -Lines $hlpBlock
            if ($h -ne $canonHlpHash) {
                $issues.Add("bloque CEREBRO (HLP) difiere (esperado $canonHlpHash, hallado $h)")
            }
        }

        if ($issues.Count -gt 0) {
            foreach ($i in $issues) { $divergences.Add("DIVERGE $($t.Name): $i") }
            Write-Host "  [DIFF]  $($t.Name): $([string]::Join('; ', $issues))"
        } else {
            Write-Host "  [OK]    $($t.Name)"
        }
    }

    Write-Host ""
    if ($divergences.Count -gt 0) {
        Write-Host "RESULTADO: DIVERGENCIA ($($divergences.Count) incidencia(s))." -ForegroundColor Red
        foreach ($d in $divergences) { Write-Host "  - $d" }
        Write-Host "Los .bat verificados NO coinciden con la fuente canonica (Req 14.3)."
        exit 1
    } else {
        Write-Host "RESULTADO: OK. Los $($targets.Count) ficheros comparten la misma libreria y el mismo cerebro, identicos a la fuente canonica (Req 14.3)."
        exit 0
    }
}

# =====================================================================================
# MODO GENERACION : escribir los 18 .bat y el lock de hashes
# =====================================================================================

if ($InPlace) {
    $targetDir = $RepoRoot
} elseif ($OutDir) {
    $targetDir = if ([System.IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path (Get-Location).Path $OutDir }
} else {
    $targetDir = Join-Path $BuildDir 'out'
}

Write-Host "Salida: $targetDir$(if ($InPlace) { '  (IN-PLACE: sobrescribe produccion)' })"

$fileEntries = New-Object System.Collections.Generic.List[object]
$generated   = New-Object System.Collections.Generic.List[string]

foreach ($t in $targets) {
    $bodyLines = Get-SourceBody -Path $t.BodyPath
    $text      = Assemble-Bat -HeaderLines $headerLines -BodyLines $bodyLines -LibraryLines $libraryLines -HlpLines $hlpLines
    $path      = Join-Path $targetDir $t.Name
    Write-BatFile -Path $path -Content $text
    $generated.Add($path)

    # Hashes de los bloques realmente embebidos (extraidos del texto generado).
    $genLines = [System.IO.File]::ReadAllLines($path)
    $libBlock = Get-EmbeddedLibraryBlock -Lines $genLines
    $hlpBlock = Get-EmbeddedHlpBlock     -Lines $genLines
    $fileEntries.Add([pscustomobject]@{
        name           = $t.Name
        librarySha256  = (Get-Sha256OfLines -Lines $libBlock)
        hlpBlockSha256 = (Get-Sha256OfLines -Lines $hlpBlock)
    })
    Write-Host "  [OK] $($t.Name)"
}

# --- Escribir build/manifest.lock.json ------------------------------------------------
$lock = [ordered]@{
    version        = $wpiVersion
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    hlpLineLength  = $HlpLineLength
    canonical      = [ordered]@{
        librarySha256  = $canonLibHash   # hash de la libreria canonica embebida
        brainSha256    = $canonBrainHash # hash del cerebro canonico (suite_helper.ps1 crudo)
        hlpBlockSha256 = $canonHlpHash   # hash del bloque HLP (cerebro embebido)
    }
    files          = $fileEntries.ToArray()
}

$json = $lock | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($LockPath, $json, (New-Object System.Text.UTF8Encoding($false)))

# --- Copiar Revertir.cmd (Req B1) ---
$revertirSrc = Join-Path $SrcDir "Revertir.cmd"
if (Test-Path $revertirSrc) {
    $revertirDst = Join-Path $targetDir "Revertir.cmd"
    Copy-Item $revertirSrc -Destination $revertirDst -Force | Out-Null
    Write-Host "  [OK] Copiado Revertir.cmd"
}

# --- Generar HASHES.sha256 (Req B5) ---
$hashesFile = Join-Path $targetDir "HASHES.sha256"
$hashesLines = New-Object System.Collections.Generic.List[string]
foreach ($t in $targets) {
    $path = Join-Path $targetDir $t.Name
    if (Test-Path $path) {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $hash = Get-Sha256Hex -Bytes $bytes
        $hashesLines.Add("$hash *$($t.Name)")
    }
}
if (Test-Path (Join-Path $targetDir "Revertir.cmd")) {
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $targetDir "Revertir.cmd"))
    $hash = Get-Sha256Hex -Bytes $bytes
    $hashesLines.Add("$hash *Revertir.cmd")
}
[System.IO.File]::WriteAllLines($hashesFile, $hashesLines.ToArray())

Write-Host ""
Write-Host "Generados $($generated.Count) ficheros .bat en $targetDir"
Write-Host "Lock de hashes: $LockPath"
Write-Host "Generados hashes SHA-256 en: $hashesFile"
Write-Host "  version=$wpiVersion  hlpLineLength=$HlpLineLength"
Write-Host "  libreria SHA-256: $canonLibHash"
Write-Host "  cerebro  SHA-256: $canonBrainHash"
Write-Host "  HLP      SHA-256: $canonHlpHash"
