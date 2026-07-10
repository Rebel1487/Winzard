# Genera el manual COMPLETO de cada idioma concatenando los manuales por seccion,
# con indice al principio. Ejecutalo tras editar cualquier manual individual.
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = @(
    @{ Dir = 'es'; Out = '00_MANUAL_COMPLETO.md'; Titulo = '# WINZARD — MANUAL COMPLETO (español)'
       Intro = 'Todos los manuales de Winzard en un solo documento. Cada sección explica qué es, para qué sirve cada botón y cómo usarla paso a paso. También tienes cada manual por separado en esta misma carpeta.'
       Indice = '## Índice' }
    @{ Dir = 'en'; Out = '00_COMPLETE_MANUAL.md'; Titulo = '# WINZARD — COMPLETE MANUAL (English)'
       Intro = 'Every Winzard manual in a single document. Each section explains what it is, what every button does and how to use it step by step. Each manual is also available separately in this folder.'
       Indice = '## Index' }
)
foreach ($c in $cfg) {
    $dir = Join-Path $base $c.Dir
    $files = Get-ChildItem $dir -Filter '*.md' | Where-Object { $_.Name -notmatch '^00_' } | Sort-Object Name
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine($c.Titulo)
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($c.Intro)
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($c.Indice)
    foreach ($f in $files) {
        $first = (Get-Content $f.FullName -TotalCount 1 -Encoding UTF8) -replace '^#\s*', ''
        $anchor = ($first.ToLower() -replace '[^a-z0-9áéíóúñü\s·-]', '' -replace '[\s·]+', '-' -replace '-+', '-').Trim('-')
        [void]$sb.AppendLine(('- [{0}](#{1})' -f $first, $anchor))
    }
    [void]$sb.AppendLine()
    foreach ($f in $files) {
        [void]$sb.AppendLine('---')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine((Get-Content $f.FullName -Raw -Encoding UTF8).TrimEnd())
        [void]$sb.AppendLine()
    }
    $outPath = Join-Path $dir $c.Out
    [System.IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ("{0}: {1} secciones -> {2}" -f $c.Dir, $files.Count, $c.Out)
}
