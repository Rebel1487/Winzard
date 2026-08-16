@echo off
chcp 65001 >nul
setlocal enableextensions
title Winzard - Lanzador
set "WPIDIR=%~dp0"
set "PS1=%WPIDIR%WPI_Moderno.ps1"
if not exist "%PS1%" (
    echo [X] No se encuentra WPI_Moderno.ps1 junto a este .bat.
    echo     WPI_Moderno.ps1 was not found next to this .bat file.
    pause & exit /b 1
)
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [X] PowerShell no esta disponible en este sistema. WPI lo necesita.
    echo     PowerShell is not available on this system. WPI requires it.
    pause & exit /b 1
)
REM ---------------------------------------------------------------------------
REM  MINIMO PRIVILEGIO (v1.3.0): Winzard arranca como USUARIO NORMAL.
REM  Ya NO se auto-eleva al abrir. Cada operacion que necesite permisos de
REM  administrador (DISM, SFC, tweaks en HKLM, debloat, creador de ISO...) los
REM  pedira en su momento, explicando antes para que los necesita.
REM  Minimum privilege (v1.3.0): Winzard starts as a STANDARD USER. It no longer
REM  self-elevates on launch; each operation that needs administrator rights asks
REM  for them when you run it, telling you first exactly what it is for.
REM ---------------------------------------------------------------------------
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1%" %*
set "EC=%errorlevel%"
if not "%EC%"=="0" (
    echo.
    echo [!] WPI termino con codigo %EC%. / WPI finished with exit code %EC%.
    echo     Revisa el mensaje de arriba o la carpeta de logs junto al script.
    pause
)
endlocal
