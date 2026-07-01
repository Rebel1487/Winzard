@echo off
chcp 65001 >nul
setlocal enableextensions
title WPI Moderno - Lanzador
set "WPIDIR=%~dp0"
set "PS1=%WPIDIR%WPI_Moderno.ps1"
if not exist "%PS1%" ( echo No se encuentra WPI_Moderno.ps1 junto a este .bat. & pause & exit /b 1 )
net session >nul 2>&1
if errorlevel 1 (
    if "%~1"=="" ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs" ) else ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs" )
    exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1%" %*
set "EC=%errorlevel%"
if not "%EC%"=="0" ( echo. & echo WPI termino con codigo %EC%. & pause )
endlocal
