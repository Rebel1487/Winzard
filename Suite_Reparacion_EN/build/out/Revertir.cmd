@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
color 1F
cls

:: Verificar administrador
net session >nul 2>&1
if !errorLevel! neq 0 (
    echo Requesting Administrator privileges to restore the system...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/k \"%~f0\"' -Verb RunAs"
    exit /b
)

:: Mostrar banner
echo ============================================================
echo   WPI SUITE - ROLLBACK / RESTORE SCRIPT
echo ============================================================
echo.

:menu
echo Choose an option:
echo  1] View restore points and open rstrui.exe
echo  2] Re-import registry backups (.reg) from Backups\
echo  3] Exit
echo.
choice /C 123 /M "Choose an option (1-3):"
if !errorlevel! equ 1 goto :restore_point
if !errorlevel! equ 2 goto :registry_restore
if !errorlevel! equ 3 goto :eof

:restore_point
echo.
echo Listing available restore points...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ComputerRestorePoint | Select-Object SequenceNumber, CreationTime, Description | Format-Table"
echo.
choice /C YN /M "Do you want to open the Windows System Restore tool (rstrui.exe)?"
if !errorlevel! equ 1 (
    echo Opening rstrui.exe...
    start rstrui.exe
)
goto :menu

:registry_restore
echo.
set "BKDIR=%~dp0WPI_Suite\Backups"
if not exist "%BKDIR%" (
    set "BKDIR=%~dp0Backups"
)
if not exist "%BKDIR%" (
    echo [X] ERROR: Backup folder not found (WPI_Suite\Backups or Backups).
    pause
    goto :menu
)

echo Looking for registry backups in: %BKDIR%
echo.
set "count=0"
for %%F in ("%BKDIR%\*.reg") do (
    set /a count+=1
    set "file[!count!]=%%~nxF"
    set "filepath[!count!]=%%F"
    echo  !count!] %%~nxF
)

if !count! equ 0 (
    echo [!] No .reg files found in the Backups folder.
    pause
    goto :menu
)

echo.
set /p "choice=Select the number of the .reg file you want to import (or 'C' to cancel): "
if /i "%choice%"=="C" goto :menu
if /i "%choice%"=="" goto :menu

:: Validar entrada
set "valid=0"
for /l %%i in (1,1,!count!) do (
    if "%choice%"=="%%i" (
        set "valid=1"
        set "selected_file=!file[%%i]!"
        set "selected_path=!filepath[%%i]!"
    )
)

if "!valid!"=="0" (
    echo [X] Invalid option.
    pause
    goto :registry_restore
)

echo.
echo [!] WARNING: You are about to import '!selected_file!' into the Windows registry.
choice /C YN /M "Are you sure you want to continue?"
if !errorlevel! equ 2 goto :menu

echo Importing !selected_path! ...
reg import "!selected_path!"
if !errorlevel! equ 0 (
    echo [OK] Import successful.
) else (
    echo [X] Error importing the file.
)
pause
goto :menu
