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
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo    WINZARD se esta preparando... acepta el aviso de permisos para continuar.
    echo    WINZARD is getting ready... please accept the permissions prompt to continue.
    echo.
    if "%~1"=="" ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs" ) else ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs" )
    exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1%" %*
set "EC=%errorlevel%"
if not "%EC%"=="0" (
    echo.
    echo [!] WPI termino con codigo %EC%. / WPI finished with exit code %EC%.
    echo     Revisa el mensaje de arriba o la carpeta de logs junto al script.
    pause
)
endlocal
