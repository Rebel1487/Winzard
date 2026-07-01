<#
.SYNOPSIS
    Verificacion integral no destructiva del proyecto WPI.

.DESCRIPTION
    Ejecuta las comprobaciones estaticas principales antes de distribuir:
    parseo PowerShell, presencia de lanzadores, sincronizacion de suites,
    HASHES.sha256, artefactos cruzados ES/EN y avisos linguisticos basicos.

    Con -ConsoleSmoke ejecuta ademas pruebas seguras de consola sobre ambas
    suites: /help, /version, /selftest y /dry. Son no destructivas, pero mas
    lentas que la verificacion estatica.
#>
[CmdletBinding()]
param(
    [switch]$ConsoleSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:Total = 0
$script:Passed = 0
$script:Warnings = 0
$script:Failures = 0

function Write-Section {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ''
    Write-Host ('=== ' + $Text + ' ===') -ForegroundColor Cyan
}

function Add-Result {
    param(
        [Parameter(Mandatory)][ValidateSet('OK','WARN','FAIL')][string]$Status,
        [Parameter(Mandatory)][string]$Message
    )
    $script:Total++
    switch ($Status) {
        'OK'   { $script:Passed++;   Write-Host ('[OK]   ' + $Message) -ForegroundColor Green }
        'WARN' { $script:Warnings++; Write-Host ('[WARN] ' + $Message) -ForegroundColor Yellow }
        'FAIL' { $script:Failures++; Write-Host ('[FAIL] ' + $Message) -ForegroundColor Red }
    }
}

function Test-RequiredFile {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Add-Result OK "Presente: $RelativePath"
    } else {
        Add-Result FAIL "Falta archivo requerido: $RelativePath"
    }
}

function Test-PowerShellParse {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Result FAIL "No se puede parsear porque falta: $RelativePath"
        return
    }

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        Add-Result FAIL ("Parse PowerShell falla: {0} ({1} error(es))" -f $RelativePath, $errors.Count)
        foreach ($err in $errors | Select-Object -First 5) {
            Write-Host ('       linea {0}: {1}' -f $err.Extent.StartLineNumber, $err.Message) -ForegroundColor DarkRed
        }
    } else {
        Add-Result OK "Parse PowerShell OK: $RelativePath"
    }
}

function Invoke-GeneratorCheck {
    param(
        [Parameter(Mandatory)][string]$SuiteDir,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Mode,
        [string[]]$ExtraArgs = @()
    )

    $scriptPath = Join-Path $SuiteDir 'build\generar.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Add-Result FAIL ("Falta generador {0}: {1}" -f $Label, $scriptPath)
        return
    }

    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath,'-Check') + $ExtraArgs
    $output = & powershell.exe @args 2>&1
    if ($LASTEXITCODE -eq 0) {
        Add-Result OK "Generador $Label sincronizado ($Mode)"
    } else {
        Add-Result FAIL "Generador $Label detecta divergencias ($Mode)"
        foreach ($line in $output | Select-Object -First 20) {
            Write-Host ('       ' + $line) -ForegroundColor DarkRed
        }
    }
}

function Test-HashManifest {
    param(
        [Parameter(Mandatory)][string]$SuiteDir,
        [Parameter(Mandatory)][string]$Label
    )

    $hashFile = Join-Path $SuiteDir 'HASHES.sha256'
    if (-not (Test-Path -LiteralPath $hashFile -PathType Leaf)) {
        Add-Result FAIL "Falta HASHES.sha256 en $Label"
        return
    }

    $issues = New-Object System.Collections.Generic.List[string]
    $lines = [System.IO.File]::ReadAllLines($hashFile) | Where-Object { $_.Trim() -ne '' }
    foreach ($line in $lines) {
        if ($line -notmatch '^([0-9a-fA-F]{64})\s+\*(.+)$') {
            $issues.Add("Linea de hash invalida: $line")
            continue
        }
        $expected = $matches[1].ToLowerInvariant()
        $name = $matches[2]
        $path = Join-Path $SuiteDir $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $issues.Add("Falta archivo listado: $name")
            continue
        }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            $issues.Add("Hash distinto: $name")
        }
    }

    if ($issues.Count -eq 0) {
        Add-Result OK "HASHES.sha256 correcto en $Label ($($lines.Count) archivo(s))"
    } else {
        Add-Result FAIL "HASHES.sha256 falla en $Label ($($issues.Count) incidencia(s))"
        foreach ($issue in $issues | Select-Object -First 20) {
            Write-Host ('       ' + $issue) -ForegroundColor DarkRed
        }
    }
}

function Test-CrossArtifacts {
    param(
        [Parameter(Mandatory)][string]$SuiteDir,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string[]]$BadPatterns
    )

    $found = @()
    foreach ($pattern in $BadPatterns) {
        $found += @(Get-ChildItem -LiteralPath $SuiteDir -Filter $pattern -File -ErrorAction SilentlyContinue)
        $outDir = Join-Path $SuiteDir 'build\out'
        if (Test-Path -LiteralPath $outDir -PathType Container) {
            $found += @(Get-ChildItem -LiteralPath $outDir -Filter $pattern -File -ErrorAction SilentlyContinue)
        }
    }

    if ($found.Count -eq 0) {
        Add-Result OK "Sin artefactos cruzados en $Label"
    } else {
        Add-Result FAIL ("Artefactos cruzados en {0}: {1}" -f $Label, $found.Count)
        foreach ($item in $found | Select-Object -First 20) {
            Write-Host ('       ' + $item.FullName) -ForegroundColor DarkRed
        }
    }
}

function Test-LanguageHints {
    param(
        [Parameter(Mandatory)][string]$SuiteDir,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    $files = @(Get-ChildItem -LiteralPath $SuiteDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.bat', '.cmd', '.txt' })
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($file in $files) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        foreach ($pattern in $Patterns) {
            if ($text -match $pattern) {
                $hits.Add(("{0}: {1}" -f $file.Name, $pattern))
                break
            }
        }
    }

    if ($hits.Count -eq 0) {
        Add-Result OK "Sin restos linguisticos obvios en $Label"
    } else {
        Add-Result WARN ("Posibles restos linguisticos en {0}: {1} (heuristica muy laxa)" -f $Label, $hits.Count)
        foreach ($hit in $hits | Select-Object -First 20) {
            Write-Host ('       ' + $hit) -ForegroundColor DarkYellow
        }
    }
}

function Test-IsoVerifierExpectedLang {
    $rootVerifier = Join-Path $Root 'Verificar_ISO.ps1'
    $wpiScript = Join-Path $Root 'WPI_Moderno.ps1'
    $issues = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path -LiteralPath $rootVerifier -PathType Leaf)) {
        $issues.Add('Falta Verificar_ISO.ps1')
    } else {
        $text = [System.IO.File]::ReadAllText($rootVerifier)
        foreach ($needle in @('$ExpectedLang', "ExpectedLang debe ser ES o EN", 'Suite_Reparacion_ES\Suite_Reparacion_TodoEnUno.bat', 'Suite_Reparacion_EN\Repair_Suite_AllInOne.bat', "`$ExpectedLang -eq 'ES'", "`$ExpectedLang -eq 'EN'")) {
            if ($text -notlike ("*{0}*" -f $needle)) { $issues.Add("Verificar_ISO.ps1 no contiene: $needle") }
        }
    }

    if (-not (Test-Path -LiteralPath $wpiScript -PathType Leaf)) {
        $issues.Add('Falta WPI_Moderno.ps1')
    } else {
        $text = [System.IO.File]::ReadAllText($wpiScript)
        foreach ($needle in @('$ExpectedLang', "ExpectedLang debe ser ES o EN", 'Suite_Reparacion_ES\Suite_Reparacion_TodoEnUno.bat', 'Suite_Reparacion_EN\Repair_Suite_AllInOne.bat', "`$ExpectedLang -eq 'ES'", "`$ExpectedLang -eq 'EN'")) {
            if ($text -notlike ("*{0}*" -f $needle)) { $issues.Add("WPI_Moderno.ps1 no contiene en su verificador ISO: $needle") }
        }
    }

    if ($issues.Count -eq 0) {
        Add-Result OK 'Verificador ISO soporta -ExpectedLang ES/EN en raiz y WPI'
    } else {
        Add-Result FAIL "Verificador ISO no esta sincronizado con -ExpectedLang ($($issues.Count) incidencia(s))"
        foreach ($issue in $issues | Select-Object -First 20) {
            Write-Host ('       ' + $issue) -ForegroundColor DarkRed
        }
    }
}

function Invoke-ConsoleCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$Argument,
        [int]$TimeoutSeconds = 180
    )

    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    $process = $null
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'cmd.exe'
        $psi.Arguments = ('/d /c ""{0}" {1}"' -f $FilePath, $Argument)
        $psi.WorkingDirectory = Split-Path -Parent $FilePath
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $false
        $psi.RedirectStandardError = $false
        $psi.StandardOutputEncoding = [System.Text.Encoding]::Default
        $psi.StandardErrorEncoding = [System.Text.Encoding]::Default
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()

        $outTask = $process.StandardOutput.ReadToEndAsync()
        $errTask = $process.StandardError.ReadToEndAsync()
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $finished) {
            try { $process.Kill() } catch {}
            return [pscustomobject]@{ TimedOut = $true; ExitCode = $null; Output = ''; ErrorOutput = '' }
        }

        $process.WaitForExit()
        return [pscustomobject]@{
            TimedOut = $false
            ExitCode = $process.ExitCode
            Output = [string]$outTask.Result
            ErrorOutput = [string]$errTask.Result
        }
    } finally {
        if ($process) { $process.Dispose() }
        Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
    }
}

function Test-ConsoleSmokeCommand {
    param(
        [Parameter(Mandatory)][string]$SuiteLabel,
        [Parameter(Mandatory)][string]$Launcher,
        [Parameter(Mandatory)][string]$Argument,
        [Parameter(Mandatory)][int[]]$AllowedExitCodes,
        [Parameter(Mandatory)][string[]]$RequiredPatterns,
        [string[]]$ForbiddenPatterns = @('Elige una opcion:', 'Choose an option:'),
        [int]$TimeoutSeconds = 180
    )

    if (-not (Test-Path -LiteralPath $Launcher -PathType Leaf)) {
        Add-Result FAIL "Smoke $SuiteLabel ${Argument}: falta lanzador"
        return
    }

    $result = Invoke-ConsoleCommand -FilePath $Launcher -Argument $Argument -TimeoutSeconds $TimeoutSeconds
    if ($result.TimedOut) {
        Add-Result FAIL "Smoke $SuiteLabel ${Argument}: timeout tras $TimeoutSeconds s"
        return
    }

    $combined = ($result.Output + "`n" + $result.ErrorOutput)
    $issues = New-Object System.Collections.Generic.List[string]
    if ($AllowedExitCodes -notcontains [int]$result.ExitCode) {
        $issues.Add("codigo de salida inesperado: $($result.ExitCode)")
    }
    foreach ($pattern in $RequiredPatterns) {
        if ($combined -notmatch $pattern) { $issues.Add("no aparece patron requerido: $pattern") }
    }
    foreach ($pattern in $ForbiddenPatterns) {
        if ($combined -match $pattern) { $issues.Add("aparece patron interactivo prohibido: $pattern") }
    }

    if ($issues.Count -eq 0) {
        Add-Result OK "Smoke $SuiteLabel ${Argument} OK"
    } else {
        Add-Result FAIL "Smoke $SuiteLabel ${Argument} falla ($($issues.Count) incidencia(s))"
        foreach ($issue in $issues | Select-Object -First 10) {
            Write-Host ('       ' + $issue) -ForegroundColor DarkRed
        }
        foreach ($line in (($combined -split "`r?`n") | Where-Object { $_.Trim() -ne '' } | Select-Object -First 12)) {
            Write-Host ('       > ' + $line) -ForegroundColor DarkRed
        }
    }
}

function Test-ConsoleSmokeSuite {
    param(
        [Parameter(Mandatory)][string]$SuiteLabel,
        [Parameter(Mandatory)][string]$Launcher,
        [Parameter(Mandatory)][string]$HelpPattern,
        [Parameter(Mandatory)][string]$VersionPattern,
        [Parameter(Mandatory)][string]$SelfTestPattern,
        [Parameter(Mandatory)][string]$DrySummaryPattern
    )

    Test-ConsoleSmokeCommand -SuiteLabel $SuiteLabel -Launcher $Launcher -Argument '/help' -AllowedExitCodes @(0) -RequiredPatterns @($HelpPattern, 'OPTIONS|OPCIONES') -TimeoutSeconds 30
    Test-ConsoleSmokeCommand -SuiteLabel $SuiteLabel -Launcher $Launcher -Argument '/version' -AllowedExitCodes @(0) -RequiredPatterns @($VersionPattern, 'version 3\.1') -TimeoutSeconds 30
    Test-ConsoleSmokeCommand -SuiteLabel $SuiteLabel -Launcher $Launcher -Argument '/selftest' -AllowedExitCodes @(0) -RequiredPatterns @($SelfTestPattern) -TimeoutSeconds 120
    Test-ConsoleSmokeCommand -SuiteLabel $SuiteLabel -Launcher $Launcher -Argument '/dry' -AllowedExitCodes @(0,1,2) -RequiredPatterns @($DrySummaryPattern, 'Global result|Resultado global') -TimeoutSeconds 240
}

function Test-WpiSelfTestGui {
    $wpi = Join-Path $Root 'WPI_Moderno.ps1'
    if (-not (Test-Path -LiteralPath $wpi -PathType Leaf)) {
        Add-Result FAIL 'SelfTestGui WPI: falta WPI_Moderno.ps1'
        return
    }

    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',$wpi,'-SelfTestGui')
    $output = & powershell.exe @args 2>&1
    if ($LASTEXITCODE -eq 0 -and (($output -join "`n") -match 'SelfTestGui: .*correctamente')) {
        Add-Result OK 'SelfTestGui WPI OK'
    } else {
        Add-Result FAIL 'SelfTestGui WPI falla'
        foreach ($line in $output | Select-Object -First 20) {
            Write-Host ('       ' + $line) -ForegroundColor DarkRed
        }
    }
}

function Test-IsoReadiness {
    $oscdimg = $null
    try { $oscdimg = (Get-Command oscdimg.exe -ErrorAction Stop).Source } catch {}
    if ($oscdimg -and (Test-Path -LiteralPath $oscdimg -PathType Leaf)) {
        Add-Result OK "ISO readiness: oscdimg disponible"
    } else {
        Add-Result WARN 'ISO readiness: falta oscdimg/Windows ADK'
    }

    $isos = @(Get-ChildItem -LiteralPath $Root -Filter '*.iso' -File -Recurse -ErrorAction SilentlyContinue)
    if ($isos.Count -gt 0) {
        Add-Result OK "ISO readiness: ISO origen localizada ($($isos.Count))"
    } else {
        Add-Result WARN 'ISO readiness: no hay ISO origen .iso dentro del proyecto'
    }

    $kits = @(Get-ChildItem -LiteralPath $Root -Filter 'kit-config.json' -File -Recurse -ErrorAction SilentlyContinue)
    if ($kits.Count -gt 0) {
        Add-Result OK "ISO readiness: kit generado localizado ($($kits.Count))"
    } else {
        Add-Result WARN 'ISO readiness: no hay kit generado (kit-config.json)'
    }
}

function Test-CmdAntiPatterns {
    param(
        [Parameter(Mandatory)][string]$SuiteDir,
        [Parameter(Mandatory)][string]$Label
    )
    if (-not (Test-Path -LiteralPath $SuiteDir)) {
        Add-Result FAIL "Anti-regresion: falta carpeta $Label"
        return
    }
    $files = Get-ChildItem -LiteralPath $SuiteDir -Recurse -Include *.bat,*.cmd -File -ErrorAction SilentlyContinue
    $brokenExit = @()
    $brokenPsh  = @()
    foreach ($f in $files) {
        $n = 0
        foreach ($line in Get-Content -LiteralPath $f.FullName) {
            $n++
            # Ignorar lineas de comentario (::, ::SRC, rem). El generador descarta ::SRC;
            # ademas los comentarios describen el idiom y darian falsos positivos.
            $t = $line.TrimStart()
            if ($t -match '^(::|rem\b)') { continue }
            # Bug A: 'endlocal & exit /b !VAR!' -> tras endlocal la expansion retardada se pierde y sale 0
            if ($line -match 'endlocal\s*&\s*exit\s*/b\s*!\w+!') {
                $brokenExit += ('{0}:{1}' -f $f.FullName, $n)
            }
            # Bug B: 'call :psh <accion> -Arg ...' -> :psh espera <accion> <arg>; el -Arg literal rompe el paso de argumentos
            if ($line -match 'call\s*:psh\s+\S+\s+-Arg\b') {
                $brokenPsh += ('{0}:{1}' -f $f.FullName, $n)
            }
        }
    }
    $issues = @($brokenExit) + @($brokenPsh)
    if ($issues.Count -eq 0) {
        Add-Result OK "Anti-regresion CMD en $Label (sin 'endlocal & exit /b !VAR!' ni ':psh ... -Arg')"
    } else {
        Add-Result FAIL ("Anti-regresion CMD en {0}: {1} incidencia(s)" -f $Label, $issues.Count)
        foreach ($issue in $issues | Select-Object -First 20) {
            Write-Host ('       ' + $issue) -ForegroundColor DarkRed
        }
    }
}

# ---------------------------------------------------------------------------
# Heuristica de "esto parece espanol": acentos/signos o palabras frecuentes.
# Se usa para detectar texto en espanol que se filtraria a la version EN.
# ---------------------------------------------------------------------------
# Clase de acentos construida por code-point para mantener este fichero ASCII-puro
# (asi el propio verificador no contiene caracteres que un parser pudiera malinterpretar).
$script:SpanishAccentCodes = @(0x00E1, 0x00E9, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00BF, 0x00A1,
                               0x00C1, 0x00C9, 0x00CD, 0x00D3, 0x00DA, 0x00D1)
$script:SpanishAccents = '[' + (($script:SpanishAccentCodes | ForEach-Object { [char]$_ }) -join '') + ']'
$script:SpanishWords = '\b(de|la|el|los|las|un|una|para|con|sin|que|por|del|al|aplicar|aplicado|instalad\w*|quitar|quitad\w*|desinstalar|deshabilitar|habilitar|sistema|usuario|tarjeta|procesador|memoria|placa|salud|tema|punto|restauracion|proteccion|nucleos|hilos|disco|caracteristicas|directivas|reparacion|aviso|abrir|cerrar|guardar|cargar|buscar|actualizar|version|estado|reinicio|seleccion|edicion|ediciones|elige|pulsa|configuracion|primero|carpeta|salida|origen|ninguna|todas|equipo|ajustes|copia|valores|defecto|fallo|cancelad\w*|termin\w*|correctas|fallidas)\b'

function Test-LooksSpanish {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    if ($Text -cmatch $script:SpanishAccents) { return $true }
    if ($Text -imatch $script:SpanishWords) { return $true }
    return $false
}

# ---------------------------------------------------------------------------
# Encoding: detecta mojibake literal y BOM UTF-8 en las fuentes.
# Las "agujas" de mojibake se construyen por code-point para que este propio
# fichero no se autodetecte como corrupto.
# ---------------------------------------------------------------------------
function Test-WpiSourceEncoding {
    param([Parameter(Mandatory)][string]$Root)

    $exts = @('.ps1', '.psm1', '.psd1', '.bat', '.cmd', '.json', '.txt', '.md', '.xml', '.csv')
    # Agujas mojibake por code-point (sin literales corruptos en este fichero):
    #   C2 B7 = middle-dot;  E2 80A6 = ellipsis;  C3 xx = vocales/n acentuadas mal decodificadas.
    $needles = @(
        ([string][char]0x00C2 + [string][char]0x00B7),
        ([string][char]0x00E2 + [string][char]0x20AC + [string][char]0x00A6),
        ([string][char]0x00C3 + [string][char]0x00A1),
        ([string][char]0x00C3 + [string][char]0x00A9),
        ([string][char]0x00C3 + [string][char]0x00AD),
        ([string][char]0x00C3 + [string][char]0x00B3),
        ([string][char]0x00C3 + [string][char]0x00BA),
        ([string][char]0x00C3 + [string][char]0x00B1)
    )

    # Artefactos de runtime (gitignored): no son fuente, se regeneran al ejecutar.
    $runtimeRx = '\\WPI_Suite\\|\\logs\\|(^|\\)(wpi_settings|wpi_baseline|estado)\.json$'
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { ($exts -contains $_.Extension.ToLower()) -and ($_.FullName -notmatch $runtimeRx) })

    $scriptExts = @('.ps1', '.psm1', '.psd1')
    $mojibakeHits = New-Object System.Collections.Generic.List[string]
    $scriptNeedBom = New-Object System.Collections.Generic.List[string]   # .ps1 con no-ASCII y SIN BOM (corrompe en 5.1)
    $dataBomHits = New-Object System.Collections.Generic.List[string]     # ficheros de datos CON BOM (interop)

    foreach ($file in $files) {
        $rel = $file.FullName.Substring($Root.Length).TrimStart('\')
        $isScript = $scriptExts -contains $file.Extension.ToLower()
        try {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            # Hay bytes no-ASCII (>= 0x80) fuera del BOM?
            $start = if ($hasBom) { 3 } else { 0 }
            $hasNonAscii = $false
            for ($i = $start; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -ge 0x80) { $hasNonAscii = $true; break } }

            if ($isScript) {
                # Politica: un script PowerShell con caracteres no-ASCII DEBE tener BOM,
                # o Windows PowerShell 5.1 lo leera como ANSI y corrompera tildes/simbolos.
                if ($hasNonAscii -and -not $hasBom) { $scriptNeedBom.Add($rel) }
            } else {
                # Datos: se prefiere SIN BOM por interoperabilidad.
                if ($hasBom) { $dataBomHits.Add($rel) }
            }
        } catch {}
        # Mojibake (secuencias ya corruptas) en cualquier fichero
        try {
            $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
            foreach ($n in $needles) {
                if ($text.Contains($n)) { $mojibakeHits.Add($rel); break }
            }
        } catch {}
    }

    if ($mojibakeHits.Count -eq 0) {
        Add-Result OK 'Sin mojibake literal en las fuentes'
    } else {
        Add-Result FAIL ("Mojibake literal en {0} fichero(s)" -f $mojibakeHits.Count)
        foreach ($h in $mojibakeHits | Select-Object -First 20) { Write-Host ('       ' + $h) -ForegroundColor Red }
    }

    if ($scriptNeedBom.Count -eq 0) {
        Add-Result OK 'Scripts .ps1 con no-ASCII llevan BOM (lectura UTF-8 correcta en PS 5.1)'
    } else {
        Add-Result FAIL ("{0} script(s) .ps1 con caracteres no-ASCII SIN BOM (se corromperan en PowerShell 5.1)" -f $scriptNeedBom.Count)
        foreach ($h in $scriptNeedBom | Select-Object -First 20) { Write-Host ('       ' + $h) -ForegroundColor Red }
    }

    if ($dataBomHits.Count -eq 0) {
        Add-Result OK 'Ficheros de datos sin BOM (interoperabilidad)'
    } else {
        Add-Result WARN ("BOM UTF-8 en {0} fichero(s) de datos (se prefiere sin BOM)" -f $dataBomHits.Count)
        foreach ($h in $dataBomHits | Select-Object -First 20) { Write-Host ('       ' + $h) -ForegroundColor DarkYellow }
    }
}

# ---------------------------------------------------------------------------
# Fugas EN: cadenas en espanol que llegarian a la version inglesa de WPI.
#   (a) literales envueltos en Tr() que NO estan en $script:TrMap.
#   (b) literales de UI hardcodeados (.Text/.Content/.Header y atributos XAML)
#       en espanol que NO estan en $script:TrMap (los traduce Translate-Tree).
# Se ignoran las concatenaciones `Tr ('prefijo ' + $var)`, cuyo string final
# se compone en runtime (las formas compuestas deben estar en TrMap aparte).
# ---------------------------------------------------------------------------
function Test-WpiEnglishLeaks {
    param([Parameter(Mandatory)][string]$ScriptPath)

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        Add-Result FAIL ("No se encontro para auditar: {0}" -f $ScriptPath)
        return
    }
    $src = [System.IO.File]::ReadAllText($ScriptPath, [System.Text.Encoding]::UTF8)

    # --- Claves de TrMap (comillas simples y dobles) ---
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($m in [regex]::Matches($src, '\$script:TrMap\[''((?:[^'']|'''')*)''\]')) {
        [void]$keys.Add(($m.Groups[1].Value -replace "''", "'"))
    }
    foreach ($m in [regex]::Matches($src, '\$script:TrMap\["((?:[^"`]|`.)*)"\]')) {
        [void]$keys.Add($m.Groups[1].Value)
    }

    $leaks = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'

    function Get-LineNumber([string]$text, [int]$index) {
        return (($text.Substring(0, $index) -split "`n").Count)
    }

    # --- (a) Literales pasados a Tr ---
    # Comillas simples, capturando si va seguido de ' +' (concatenacion -> skip)
    foreach ($m in [regex]::Matches($src, '\bTr\s*\(?\s*''((?:[^'']|'''')*)''(\s*\+)?')) {
        if ($m.Groups[2].Success) { continue }           # concatenacion: el string final se compone en runtime
        $lit = ($m.Groups[1].Value -replace "''", "'")
        if ($keys.Contains($lit)) { continue }
        if (-not (Test-LooksSpanish $lit)) { continue }
        if (-not $seen.Add($lit)) { continue }
        $leaks.Add(("L{0} [Tr]: {1}" -f (Get-LineNumber $src $m.Index), ($lit -replace '\s+', ' ')))
    }
    # Comillas dobles
    foreach ($m in [regex]::Matches($src, '\bTr\s*\(?\s*"((?:[^"`]|`.)*)"')) {
        $lit = $m.Groups[1].Value
        if ($keys.Contains($lit)) { continue }
        if (-not (Test-LooksSpanish $lit)) { continue }
        if (-not $seen.Add($lit)) { continue }
        $leaks.Add(("L{0} [Tr]: {1}" -f (Get-LineNumber $src $m.Index), ($lit -replace '\s+', ' ')))
    }

    # --- (b) Literales de UI hardcodeados ---
    # .Text/.Content/.Header = 'literal' puro al final de la sentencia
    foreach ($m in [regex]::Matches($src, '\.(?:Text|Content|Header)\s*=\s*''((?:[^'']|'''')*)''\s*;?\s*(?:\r?\n|$)')) {
        $line = ($src.Substring(0, $m.Index) -split "`n")[-1]
        if ($line -match '\$isEn' -or $line -match '\bif \(' -or $line -match '\bTr ') { continue }
        $lit = ($m.Groups[1].Value -replace "''", "'")
        if ($keys.Contains($lit)) { continue }
        if (-not (Test-LooksSpanish $lit)) { continue }
        if (-not $seen.Add($lit)) { continue }
        $leaks.Add(("L{0} [UI]: {1}" -f (Get-LineNumber $src $m.Index), ($lit -replace '\s+', ' ')))
    }
    # Atributos XAML: ToolTip/Content/Text/Header="literal"
    foreach ($m in [regex]::Matches($src, '\b(?:ToolTip|Content|Text|Header)="([^"]*)"')) {
        $lit = $m.Groups[1].Value
        if ($keys.Contains($lit)) { continue }
        if (-not (Test-LooksSpanish $lit)) { continue }
        if (-not $seen.Add($lit)) { continue }
        $leaks.Add(("L{0} [XAML]: {1}" -f (Get-LineNumber $src $m.Index), ($lit -replace '\s+', ' ')))
    }

    if ($leaks.Count -eq 0) {
        Add-Result OK ("Sin fugas de espanol en la version EN ({0} claves TrMap)" -f $keys.Count)
    } else {
        Add-Result FAIL ("{0} cadena(s) en espanol se filtrarian a la version EN" -f $leaks.Count)
        foreach ($l in $leaks | Select-Object -First 30) { Write-Host ('       ' + $l) -ForegroundColor Red }
    }
}

Write-Host ''
Write-Host 'WPI - Verificacion integral del proyecto' -ForegroundColor Cyan
Write-Host ('Raiz: ' + $Root) -ForegroundColor DarkCyan

$suiteEs = Join-Path $Root 'Suite_Reparacion_ES'
$suiteEn = Join-Path $Root 'Suite_Reparacion_EN'

Write-Section 'Archivos principales'
Test-RequiredFile 'WPI_Moderno.ps1'
Test-RequiredFile 'Verificar_ISO.ps1'
Test-RequiredFile 'Iniciar_WPI.bat'
Test-RequiredFile 'Suite_Reparacion_ES\Suite_Reparacion_TodoEnUno.bat'
Test-RequiredFile 'Suite_Reparacion_EN\Repair_Suite_AllInOne.bat'

Write-Section 'Parseo PowerShell'
Test-PowerShellParse 'WPI_Moderno.ps1'
Test-PowerShellParse 'Verificar_ISO.ps1'
Test-PowerShellParse 'Suite_Reparacion_ES\build\generar.ps1'
Test-PowerShellParse 'Suite_Reparacion_EN\build\generar.ps1'
Test-PowerShellParse 'Suite_Reparacion_ES\src\suite_helper.ps1'
Test-PowerShellParse 'Suite_Reparacion_EN\src\suite_helper.ps1'

Write-Section 'Suites generadas'
Invoke-GeneratorCheck -SuiteDir $suiteEs -Label 'ES' -Mode 'raiz'
Invoke-GeneratorCheck -SuiteDir $suiteEn -Label 'EN' -Mode 'raiz'
Invoke-GeneratorCheck -SuiteDir $suiteEs -Label 'ES' -Mode 'build/out' -ExtraArgs @('-OutDir', (Join-Path $suiteEs 'build\out'))
Invoke-GeneratorCheck -SuiteDir $suiteEn -Label 'EN' -Mode 'build/out' -ExtraArgs @('-OutDir', (Join-Path $suiteEn 'build\out'))

Write-Section 'Hashes'
Test-HashManifest -SuiteDir $suiteEs -Label 'ES'
Test-HashManifest -SuiteDir $suiteEn -Label 'EN'

Write-Section 'Cruces ES/EN'
Test-CrossArtifacts -SuiteDir $suiteEn -Label 'EN' -BadPatterns @('Fase_*.bat','Suite_Reparacion_TodoEnUno.bat')
Test-CrossArtifacts -SuiteDir $suiteEs -Label 'ES' -BadPatterns @('Phase_*.bat','Repair_Suite_AllInOne.bat')

Write-Section 'Verificador ISO'
Test-IsoVerifierExpectedLang

Write-Section 'Anti-regresion CMD (exit code y :psh)'
Test-CmdAntiPatterns -SuiteDir $suiteEs -Label 'ES'
Test-CmdAntiPatterns -SuiteDir $suiteEn -Label 'EN'

Write-Section 'Idioma visible basico'
Test-LanguageHints -SuiteDir $suiteEn -Label 'EN' -Patterns @('\bDiagnostico\b','\bPunto de restauracion\b','\bLimpieza inicial\b','\bNo se pudo\b','\bQuieres\b','\bTermino\b','\bHecho\b')
Test-LanguageHints -SuiteDir $suiteEs -Label 'ES' -Patterns @('\bDiagnosis and triage\b','\bRestore point\b','\bInitial cleanup\b','\bDo you want\b','\bDone\b')

Write-Section 'Encoding (mojibake / BOM)'
Test-WpiSourceEncoding -Root $Root

Write-Section 'Fugas de espanol en version EN (cobertura i18n)'
Test-WpiEnglishLeaks -ScriptPath (Join-Path $Root 'WPI_Moderno.ps1')

if ($ConsoleSmoke) {
    Write-Section 'Smoke consola seguro'
    Test-ConsoleSmokeSuite -SuiteLabel 'ES' -Launcher (Join-Path $suiteEs 'Suite_Reparacion_TodoEnUno.bat') -HelpPattern 'Suite de Reparacion de Emergencia' -VersionPattern 'Suite de Reparacion de Emergencia' -SelfTestPattern 'SELF-TEST: TODO CORRECTO' -DrySummaryPattern 'RESUMEN'
    Test-ConsoleSmokeSuite -SuiteLabel 'EN' -Launcher (Join-Path $suiteEn 'Repair_Suite_AllInOne.bat') -HelpPattern 'Emergency Repair Suite' -VersionPattern 'Emergency Repair Suite' -SelfTestPattern 'SELF-TEST: ALL PASSED' -DrySummaryPattern 'SUMMARY'

    Write-Section 'Smoke GUI WPI'
    Test-WpiSelfTestGui

    Write-Section 'Preparacion ISO real'
    Test-IsoReadiness
}

Write-Section 'Resumen'
Write-Host ("Checks: {0}  OK: {1}  WARN: {2}  FAIL: {3}" -f $script:Total, $script:Passed, $script:Warnings, $script:Failures)

if ($script:Failures -gt 0) {
    Write-Host 'RESULTADO: FALLA. Corrige los puntos [FAIL] antes de distribuir.' -ForegroundColor Red
    exit 1
}

if ($script:Warnings -gt 0) {
    Write-Host 'RESULTADO: OK con avisos. Revisa los [WARN] si buscas limpieza total.' -ForegroundColor Yellow
    exit 0
}

Write-Host 'RESULTADO: OK. Proyecto verificado estaticamente.' -ForegroundColor Green
exit 0
