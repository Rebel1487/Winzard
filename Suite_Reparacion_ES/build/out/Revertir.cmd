@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
color 1F
cls

:: Verificar administrador
net session >nul 2>&1
if !errorLevel! neq 0 (
    echo Solicitando privilegios de Administrador para restaurar el sistema...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/k \"%~f0\"' -Verb RunAs"
    exit /b
)

:: Mostrar banner
echo ============================================================
echo   WPI SUITE - SCRIPT DE RETORNO / ROLLBACK
echo ============================================================
echo.

:menu
echo Selecciona una opcion:
echo  1] Ver puntos de restauracion y abrir rstrui.exe
echo  2] Reimportar copias del registro (.reg) desde Backups\
echo  3] Salir
echo.
choice /C 123 /M "Elige una opcion (1-3):"
if !errorlevel! equ 1 goto :restore_point
if !errorlevel! equ 2 goto :registry_restore
if !errorlevel! equ 3 goto :eof

:restore_point
echo.
echo Listando puntos de restauracion disponibles...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ComputerRestorePoint | Select-Object SequenceNumber, CreationTime, Description | Format-Table"
echo.
choice /C SN /M "Quieres abrir la utilidad grafica de restauracion de Windows (rstrui.exe)?"
if !errorlevel! equ 1 (
    echo Abriendo rstrui.exe...
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
    echo [X] ERROR: No se encuentra la carpeta de copias de seguridad (WPI_Suite\Backups o Backups).
    pause
    goto :menu
)

echo Buscando copias del registro en: %BKDIR%
echo.
set "count=0"
for %%F in ("%BKDIR%\*.reg") do (
    set /a count+=1
    set "file[!count!]=%%~nxF"
    set "filepath[!count!]=%%F"
    echo  !count!] %%~nxF
)

if !count! equ 0 (
    echo [!] No se encontraron archivos .reg en la carpeta de Backups.
    pause
    goto :menu
)

echo.
set /p "choice=Selecciona el numero del archivo .reg que deseas importar (o 'C' para cancelar): "
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
    echo [X] Opcion no valida.
    pause
    goto :registry_restore
)

echo.
echo [!] ATENCION: Vas a importar '!selected_file!' al registro de Windows.
choice /C SN /M "Estas seguro de que deseas continuar?"
if !errorlevel! equ 2 goto :menu

echo Importando !selected_path! ...
reg import "!selected_path!"
if !errorlevel! equ 0 (
    echo [OK] Importacion exitosa.
) else (
    echo [X] Error al importar el archivo.
)
pause
goto :menu
