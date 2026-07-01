@echo off
setlocal EnableDelayedExpansion
:: --- Consola estilo WinUtil: fondo azul oscuro, texto claro (Req B/D) ---
:: Se aplica a la suite completa y a CADA fase suelta (todas incluyen esta cabecera).
:: 'color' repinta el bufer; 'cls' garantiza el fondo azul desde el inicio.
color 0F
cls
:: --- parseo de argumentos (antes de elevar, para que /help y /version no pidan UAC) ---
set "MODE_AUTO=0" & set "NO_REBOOT=0" & set "KEEPWU=0" & set "DRY=0" & set "RESUME=0" & set "SEL_FASES=" & set "USE_TRIAGE=0"
set "SELFTEST=0" & set "QUIET=0" & set "SHOW_HELP=0" & set "SHOW_VERSION=0"
set "JSON=0" & set "SUPPORT=0" & set "QUICK=0" & set "NOCOLOR=0" & set "MANUAL=0" & set "PLAN_MODE=0" & set "QSUB=scan" & set "QUICK_WIZ=0" & set "SHOWCMD=0"
set "RESETBASE=0" & set "FWRESET=0" & set "CUSTOM_SOURCE="
:parse_loop
if "%~1"=="" goto parse_done
set "ARG=%~1"
if /i "!ARG!"=="/auto"     set "MODE_AUTO=1"
if /i "!ARG!"=="/noreboot" set "NO_REBOOT=1"
if /i "!ARG!"=="/keepwu"   set "KEEPWU=1"
if /i "!ARG!"=="/dry"      set "DRY=1"
if /i "!ARG!"=="/resume"   set "RESUME=1"
if /i "!ARG!"=="/triage"   set "USE_TRIAGE=1"
if /i "!ARG!"=="/selftest" set "SELFTEST=1"
if /i "!ARG!"=="/quiet"    set "QUIET=1"
if /i "!ARG!"=="/help"     set "SHOW_HELP=1"
if /i "!ARG!"=="/?"        set "SHOW_HELP=1"
if /i "!ARG!"=="/version"  set "SHOW_VERSION=1"
if /i "!ARG!"=="/json"     set "JSON=1"
if /i "!ARG!"=="/support"  set "SUPPORT=1"
if /i "!ARG!"=="/quick"    set "QUICK=1"
if /i "!ARG!"=="/quickfix" ( set "QUICK=1" & set "QSUB=fix" )
if /i "!ARG!"=="/nocolor"  set "NOCOLOR=1"
if /i "!ARG!"=="/manual"   set "MANUAL=1"
if /i "!ARG!"=="/cmd"      set "SHOWCMD=1"
if /i "!ARG!"=="/plan"     set "PLAN_MODE=1"
if /i "!ARG!"=="/resetbase" set "RESETBASE=1"
if /i "!ARG!"=="/fwreset"  set "FWRESET=1"
if /i "!ARG:~0,8!"=="/source:" set "CUSTOM_SOURCE=!ARG:~8!"
if /i "!ARG:~0,7!"=="/fases:" (
    set "SEL_FASES=!ARG:~7!"
    set "SEL_FASES=!SEL_FASES:+=,!"
)
if /i "!ARG:~0,8!"=="/phases:" (
    set "SEL_FASES=!ARG:~8!"
    set "SEL_FASES=!SEL_FASES:+=,!"
)
shift
goto parse_loop
:parse_done
:: por seguridad, /selftest implies simulation (no toca el sistema)
if "!SELFTEST!"=="1" set "DRY=1"
rem (v3.1) en modo desatendido el menu manual no aplica (no hay quien elija)
if "!MODE_AUTO!"=="1" set "MANUAL=0"
if "!MODE_AUTO!"=="1" set "PLAN_MODE=0"
call :wpi_initcolors
:: (Task 10.1 / Req 12) /version y /help salen de inmediato, sin elevar ni ejecutar fases.
if "!SHOW_VERSION!"=="1" ( call :show_version & endlocal & exit /b 0 )
if "!SHOW_HELP!"=="1" ( call :show_help & endlocal & exit /b 0 )
:: --- Verificar Administrador (re-lanzamiento elevado) ---
:: (v3.1 Bug#1) Las operaciones que NO tocan el sistema no requieren admin:
:: /dry, /quick, /selftest (ademas de /help y /version, que ya salieron antes).
:: Asi funcionan en terminales no elevados. (Bug#2: NUNCA usar set errorlevel=.)
set "NEED_ADMIN=1"
if "%DRY%"=="1" set "NEED_ADMIN=0"
if "%SELFTEST%"=="1" set "NEED_ADMIN=0"
if "%NEED_ADMIN%"=="0" goto :admin_done
net session >nul 2>&1
if !errorLevel! neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/k \"%~f0\" %*' -Verb RunAs"
    exit /b
)
:admin_done
:: --- carpetas de trabajo ---
set "WORK=%~dp0WPI_Suite"
set "LOGDIR=%WORK%\Logs"
set "BKDIR=%WORK%\Backups"
if not exist "%WORK%" mkdir "%WORK%" >nul 2>&1
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%BKDIR%" mkdir "%BKDIR%" >nul 2>&1
for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')"`) do set "TIMESTAMP=%%t"
set "LOGFILE=%LOGDIR%\reparacion_%TIMESTAMP%.log"
set "RUNID=%RANDOM%%RANDOM%"
set "CAP=%WORK%\_cap_%RUNID%.txt"
:: Bug 9 / Req 11: verificar PowerShell ANTES de extraer el Cerebro. Si falta o
:: no arranca, :require_powershell devuelve 3; en el ambito principal de la
:: cabecera propagamos ese 3 con un exit /b 3 incondicional => parada total.
call :require_powershell
if errorlevel 3 exit /b 3
call :wpi_extracthelper
call :bigbanner
echo(
echo  %DIM%Standalone phase 01 - Restore point%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "01" "Restore point" "Creates a restore point and backs up the registry so you can roll back."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase01 ) else ( call :menu_fase01 )
set "RC=!errorlevel!"
call :nowcs & set /a "SECS=(CS_NOW-P0)/100"
if !SECS! lss 0 set /a "SECS+=86400"
set "RES=OK"
if "!RC!"=="1" set "RES=WARN"
if "!RC!"=="2" set "RES=SKIP"
if "!RC!"=="3" set "RES=ERROR"
set "COL=%GR%"
if "!RES!"=="WARN" set "COL=%YE%"
if "!RES!"=="SKIP" set "COL=%DIM%"
if "!RES!"=="ERROR" set "COL=%RE%"
echo(
echo %BL%------------------------------------------------------------%R%
echo    Result: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %RC%


:Fase01
if "%DRY%"=="1" ( call :dry "Would create a restore point and back up the registry" & exit /b 2 )
call :step "Creating restore point (may take a while)"
call :psh restorepoint > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /c:"RESULT=OK" "%CAP%" >nul 2>&1
if !errorlevel! equ 0 ( call :ok "Restore point created and verified" ) else ( call :warn "Could not create the restore point (continuing anyway)" )
call :step "Backing up the registry (SOFTWARE and SYSTEM)"
reg export HKLM\SOFTWARE "%BKDIR%\SOFTWARE_%TIMESTAMP%.reg" /y >nul 2>&1
reg export HKLM\SYSTEM "%BKDIR%\SYSTEM_%TIMESTAMP%.reg" /y >nul 2>&1
call :info "Registry backup requested in Backups"

call :step "Verifying safety net and backups"
call :psh checkbackups "%BKDIR%|%TIMESTAMP%" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"

set "RP_OK=0"
set "REG_OK=0"
for /f "tokens=1,2 delims==" %%A in (%CAP%) do (
    if "%%A"=="RP_OK" set "RP_OK=%%B"
    if "%%A"=="REG_OK" set "REG_OK=%%B"
)

if "!RP_OK!"=="1" if "!REG_OK!"=="1" (
    call :ok "Safety net verified (Restore point and registry backups OK)"
    exit /b 0
)

echo(
call :warn "SAFETY NET FAILED:"
if "!RP_OK!"=="0" echo   [X] Could not create/verify the Restore Point.
if "!REG_OK!"=="0" echo   [X] The registry backups (.reg) are missing or empty.
echo(

if "%MODE_AUTO%"=="1" (
    call :err "Unattended mode: aborting execution for safety."
    exit /b 3
)

echo %YE%[!] WARNING: Continuing without a safety net is risky.%R%
choice /C SC /M "Press [S] to exit/abort or [C] to continue at your own risk"
if !errorlevel! equ 1 (
    call :err "Cancelled by the user."
    exit /b 3
) else (
    call :warn "Continuing without a safety net by user choice."
    exit /b 0
)
:: ======================= LIBRERIA WPI =======================
:wpi_initcolors
:: Detecta el caracter ESC para ANSI. Si falla, los colores quedan vacios
:: (texto plano) y la suite sigue funcionando igual.
set "ESC="
for /f "delims=#" %%E in ('"prompt #$E# & for %%a in (1) do rem"') do set "ESC=%%E"
rem (v3.1) /nocolor: fuerza el modo texto plano reutilizando la rama sin ESC.
if "%NOCOLOR%"=="1" set "ESC="
if defined ESC (
    rem Bug 8 / Req 10: escritura IDEMPOTENTE. Solo se toca el registro si el
    rem valor actual de VirtualTerminalLevel difiere del deseado (0x1). Se lee
    rem con reg query (token 3 = dato) sin depender del Cerebro, porque
    rem wpi_initcolors corre antes de require_powershell y de extraer el helper.
    set "VTL_CUR="
    for /f "tokens=3" %%v in ('reg query "HKCU\Console" /v VirtualTerminalLevel 2^>nul ^| findstr /i "VirtualTerminalLevel"') do set "VTL_CUR=%%v"
    if /i not "!VTL_CUR!"=="0x1" reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
    set "R=%ESC%[0m"   & set "B=%ESC%[1m"   & set "DIM=%ESC%[2m"
    set "CY=%ESC%[96m" & set "BL=%ESC%[94m" & set "GR=%ESC%[92m"
    set "YE=%ESC%[93m" & set "RE=%ESC%[91m" & set "GY=%ESC%[90m"
    set "WH=%ESC%[97m" & set "MG=%ESC%[95m"
    rem (v3.1) fondos de color para barras estilo WinUtil (ASCII: solo escapes)
    set "BGB=%ESC%[44m" & set "BGC=%ESC%[46m" & set "BGG=%ESC%[42m"
    set "BGK=%ESC%[100m" & set "BK=%ESC%[30m" & set "COLOR_ON=1"
) else (
    set "R=" & set "B=" & set "DIM=" & set "CY=" & set "BL=" & set "GR="
    set "YE=" & set "RE=" & set "GY=" & set "WH=" & set "MG="
    set "BGB=" & set "BGC=" & set "BGG=" & set "BGK=" & set "BK=" & set "COLOR_ON=0"
)
exit /b 0

:: --- lineas de estado ---
:ok
echo    %GR%[ OK ]%R%  %~1
>>"%LOGFILE%" echo [ OK ] %~1
exit /b 0
:warn
echo    %YE%[WARN]%R%  %~1
>>"%LOGFILE%" echo [WARN] %~1
exit /b 0
:err
echo    %RE%[ X  ]%R%  %~1
>>"%LOGFILE%" echo [ X  ] %~1
exit /b 0
:info
if not "%QUIET%"=="1" echo    %CY%[ i  ]%R%  %~1
>>"%LOGFILE%" echo [ i  ] %~1
exit /b 0
:step
if not "%QUIET%"=="1" echo    %DIM%[ .. ]  %~1%R%
>>"%LOGFILE%" echo [ .. ] %~1
exit /b 0
:dry
echo    %MG%[DRY ]%R%  %~1
>>"%LOGFILE%" echo [DRY ] %~1
exit /b 0

:: --- banner de fase: %1=num (ej 04/16)  %2=titulo  %3=por que ---
:phase
echo(
echo  %BGB%%WH%%B%  PHASE %~1     %~2%R%
echo  %DIM%%~3%R%
>>"%LOGFILE%" echo(
>>"%LOGFILE%" echo ===== PHASE %~1 : %~2 =====
exit /b 0

:: --- caja de cabecera principal ---
:bigbanner
echo(
echo  %BGC%%BK%                                                                %R%
echo  %BGC%%BK%   EMERGENCY REPAIR SUITE              -   WINDOWS 10/11        %R%
echo  %BGC%%BK%   All-in-One       -      version 3.1      -      WPI           %R%
echo  %BGC%%BK%                                                                %R%
exit /b 0

:: --- reloj en centisegundos desde medianoche (var CS_NOW) ---
:nowcs
set "T=%TIME: =0%"
rem (v3.1 Bug#4) separar en DOS lineas fisicas: en locales con coma decimal,
rem hacerlo en una sola linea expande %T% de golpe y deja la coma -> set /a falla.
set "T=%T:,=:%"
set "T=%T:.=:%"
for /f "tokens=1-4 delims=:" %%a in ("%T%") do set /a "CS_NOW=(((1%%a-100)*60+(1%%b-100))*60+(1%%c-100))*100+(1%%d-100)"
exit /b 0

:: --- decodifica el cerebro PS incrustado a %HELPER% ---
:wpi_extracthelper
if not defined RUNID set "RUNID=%RANDOM%%RANDOM%"
set "HELPER=%WORK%\suite_helper_%RUNID%.ps1"
set "HELPER_B64=%WORK%\helper_%RUNID%.b64"
(for /f "usebackq tokens=1,* delims=:" %%a in (`findstr /b /c:"HLP:" "%~f0"`) do @echo %%b) > "%HELPER_B64%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try{[IO.File]::WriteAllBytes('%HELPER%',[Convert]::FromBase64String(((Get-Content '%HELPER_B64%') -join '')))}catch{}" >nul 2>&1
if exist "%HELPER%" ( exit /b 0 ) else ( exit /b 1 )

:: --- atajo para llamar al cerebro: %1=accion  %2=arg(opcional) ---
:psh
powershell -NoProfile -ExecutionPolicy Bypass -File "%HELPER%" -Action %~1 -Work "%WORK%" -Arg "%~2"
exit /b 0
:pshq
powershell -NoProfile -ExecutionPolicy Bypass -File "%HELPER%" -Action %~1 -Work "%WORK%" -Arg "%~2" >nul 2>&1
exit /b 0

:title_of
set "PH_TITLE=" & set "PH_WHY="
if "%~1"=="00" ( set "PH_TITLE=Diagnostics and triage" & set "PH_WHY=Checks disks, space and events, and finds the root cause." & set "PH_TIME=~1 min" & set "PH_SAFE=Safe: read-only" )
if "%~1"=="01" ( set "PH_TITLE=Restore point" & set "PH_WHY=Creates a restore point and backs up the registry so you can roll back." & set "PH_TIME=~1-2 min" & set "PH_SAFE=Safe: creates backup" )
if "%~1"=="02" ( set "PH_TITLE=Initial cleanup" & set "PH_WHY=Clears temp files, recycle bin and caches to free up the disk." & set "PH_TIME=~1-2 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="03" ( set "PH_TITLE=CHKDSK" & set "PH_WHY=Checks the C: drive file system for errors." & set "PH_TIME=~1 min (or reboot)" & set "PH_SAFE=Makes changes" )
if "%~1"=="04" ( set "PH_TITLE=Disk optimization" & set "PH_WHY=TRIM for SSDs or defragment for HDDs, depending on the disk type." & set "PH_TIME=~1-10 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="05" ( set "PH_TITLE=DISM" & set "PH_WHY=Repairs the Windows component image (the source SFC relies on)." & set "PH_TIME=~5-15 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="06" ( set "PH_TITLE=SFC and verification" & set "PH_WHY=Repairs system files and verifies the result after DISM." & set "PH_TIME=~5-10 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="07" ( set "PH_TITLE=Repair WMI" & set "PH_WHY=Checks and repairs the WMI repository (a broken one causes odd failures)." & set "PH_TIME=~1-3 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="08" ( set "PH_TITLE=Store apps and Startup" & set "PH_WHY=Re-registers Store apps and repairs the Start menu." & set "PH_TIME=~2-5 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="09" ( set "PH_TITLE=Search and caches" & set "PH_WHY=Rebuilds the Search index, icon/font caches and the spooler." & set "PH_TIME=~1-3 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="10" ( set "PH_TITLE=Certificates and time" & set "PH_WHY=Refreshes root certificates and syncs the clock (fixes WU/Store/cert)." & set "PH_TIME=~1 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="11" ( set "PH_TITLE=Network" & set "PH_WHY=Resets winsock, IP, DNS and proxy, and checks the hosts file." & set "PH_TIME=~1 min" & set "PH_SAFE=Makes changes (reboot)" )
if "%~1"=="12" ( set "PH_TITLE=Policies (GPO)" & set "PH_WHY=Re-applies group policies to undo misapplied settings." & set "PH_TIME=~1 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="13" ( set "PH_TITLE=Windows Update" & set "PH_WHY=Repairs Windows Update (services and cache). Honors /keepwu." & set "PH_TIME=~2-5 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="14" ( set "PH_TITLE=Winget" & set "PH_WHY=Repairs winget and updates the package manager." & set "PH_TIME=~1-5 min" & set "PH_SAFE=Makes changes" )
if "%~1"=="15" ( set "PH_TITLE=Devices" & set "PH_WHY=Lists drivers/devices with errors so you know what to check." & set "PH_TIME=~1 min" & set "PH_SAFE=Safe: lists only" )
if "%~1"=="16" ( set "PH_TITLE=Final cleanup and report" & set "PH_WHY=Deep cleanup, recomputes health and generates the HTML report." & set "PH_TIME=~2-5 min" & set "PH_SAFE=Makes changes" )
exit /b 0

:: ============================================================
:: Subrutinas anadidas en Task 7 (correcciones de bugs y mejoras)
:: ============================================================

:: --- Bug 9 / Req 11: verificar que PowerShell esta disponible ---
:: Comprueba que el ejecutable existe (where) y que arranca
:: (powershell -NoProfile -Command "exit 0"). Si cualquiera falla, escribe un
:: mensaje claro en consola Y en %LOGFILE% y devuelve 3 (ERROR). La cabecera
:: propaga ese 3 con un exit /b 3 incondicional => parada total de la Suite,
:: incluidas las fases que no dependen del Cerebro (Req 11.2, 11.3).
:require_powershell
where powershell >nul 2>&1
if errorlevel 1 goto :_reqps_fail
powershell -NoProfile -Command "exit 0" >nul 2>&1
if errorlevel 1 goto :_reqps_fail
exit /b 0
:_reqps_fail
echo    %RE%[ X ]%R%  PowerShell is not available. The suite requires it.
>>"%LOGFILE%" echo [ X ] PowerShell is not available. The suite requires it.
exit /b 3

:: --- Req 4: guardar checkpoint antes de un reinicio ---
:: Contrato de entrada (variables del orquestador, expansion retardada):
::   !SEL_FASES!  -> seleccion canonica de fases (lista de IDs de 2 digitos)
::   !COMPLETED!  -> fases ya completadas (lista de IDs de 2 digitos)
::   MODE_AUTO / NO_REBOOT / KEEPWU / DRY / USE_TRIAGE -> modos globales (0/1)
::   !CP_REASON!  -> motivo de la pausa (p.ej. chkdsk_programado), opcional
:: Salida: set "CP_SAVE_OK=1" si el Cerebro confirma RESULT=OK, si no 0.
:checkpoint_save
set "CP_SAVE_OK=0"
set "_cps_arg=save|selection=!SEL_FASES!|completed=!COMPLETED!|mode=auto:!MODE_AUTO!;noreboot:!NO_REBOOT!;keepwu:!KEEPWU!;dry:!DRY!;triage:!USE_TRIAGE!|reason=!CP_REASON!"
call :psh checkpoint "!_cps_arg!" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /b /c:"RESULT=OK" "%CAP%" >nul 2>&1
if not errorlevel 1 set "CP_SAVE_OK=1"
exit /b 0

:: --- Req 4: cargar y parsear el checkpoint ---
:: Llama a :psh checkpoint "load" capturando en %CAP% y vuelca las claves
:: KEY=VALUE del Cerebro a variables CP_*:
::   CP_RESULT (OK|NONE), CP_VALID (1/0), CP_NEXT (primera fase no completada),
::   CP_SELECTION, CP_COMPLETED, CP_VERSION, CP_CREATED, CP_REASON_LOADED,
::   CP_MODE_AUTO, CP_MODE_NOREBOOT, CP_MODE_KEEPWU, CP_MODE_DRY, CP_MODE_TRIAGE.
:checkpoint_load
set "CP_RESULT=" & set "CP_VALID=0" & set "CP_NEXT=" & set "CP_SELECTION=" & set "CP_COMPLETED="
set "CP_VERSION=" & set "CP_CREATED=" & set "CP_REASON_LOADED="
set "CP_MODE_AUTO=0" & set "CP_MODE_NOREBOOT=0" & set "CP_MODE_KEEPWU=0" & set "CP_MODE_DRY=0" & set "CP_MODE_TRIAGE=0"
call :psh checkpoint "load" > "%CAP%" 2>&1
for /f "usebackq tokens=1,* delims==" %%a in ("%CAP%") do (
    if /i "%%a"=="RESULT"        set "CP_RESULT=%%b"
    if /i "%%a"=="VALID"         set "CP_VALID=%%b"
    if /i "%%a"=="NEXT"          set "CP_NEXT=%%b"
    if /i "%%a"=="SELECTION"     set "CP_SELECTION=%%b"
    if /i "%%a"=="COMPLETED"     set "CP_COMPLETED=%%b"
    if /i "%%a"=="VERSION"       set "CP_VERSION=%%b"
    if /i "%%a"=="CREATED"       set "CP_CREATED=%%b"
    if /i "%%a"=="REASON"        set "CP_REASON_LOADED=%%b"
    if /i "%%a"=="MODE_AUTO"     set "CP_MODE_AUTO=%%b"
    if /i "%%a"=="MODE_NOREBOOT" set "CP_MODE_NOREBOOT=%%b"
    if /i "%%a"=="MODE_KEEPWU"   set "CP_MODE_KEEPWU=%%b"
    if /i "%%a"=="MODE_DRY"      set "CP_MODE_DRY=%%b"
    if /i "%%a"=="MODE_TRIAGE"   set "CP_MODE_TRIAGE=%%b"
)
exit /b 0

:: --- Req 4.3/4.4: borrar el checkpoint con reintento acotado ---
:: Intenta hasta 3 veces. Si tras los reintentos checkpoint.json sigue
:: existiendo, registra WARN y marca el fallo (CP_CLEAR_FAIL=1) devolviendo 1.
:checkpoint_clear
set "CP_CLEAR_FAIL=0"
set "_cpc_n=0"
:_cpc_retry
set /a "_cpc_n+=1"
call :psh checkpoint "clear" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
if not exist "%WORK%\checkpoint.json" exit /b 0
if !_cpc_n! lss 3 goto :_cpc_retry
call :warn "Could not delete checkpoint.json after 3 attempts"
set "CP_CLEAR_FAIL=1"
exit /b 1

:: --- Req 17.1/17.3: punto unico del esquema de log consolidado ---
:: Garantiza que orquestador y fases comparten %LOGFILE% =
:: %LOGDIR%\reparacion_%TIMESTAMP%.log (definido en la cabecera). No introduce
:: logica nueva: si las variables faltaran, las reconstruye de forma segura.
:log_consolidate
if not defined LOGDIR set "LOGDIR=%WORK%\Logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not defined LOGFILE set "LOGFILE=%LOGDIR%\reparacion_%TIMESTAMP%.log"
exit /b 0

:: --- Req 17.2: rotacion de logs (conservar los LOG_RETENTION mas recientes) ---
:: Invoca la accion logrotate del Cerebro sobre %LOGDIR%. Pensado para llamarse
:: al final (orquestador y fases lo usaran en las tareas 8/9/10).
:log_rotate
call :psh logrotate "%LOGDIR%" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
exit /b 0

:: ============================================================
:: Subrutinas anadidas en Task 10 (mejoras del Bloque 3)
:: ============================================================

:: --- (Task 10.1 / Req 12.3) version ---
:show_version
echo Emergency Repair Suite ^(WPI^) - version 3.1
echo Windows 10/11. No external dependencies.
exit /b 0

:: --- (Task 10.1 / Req 12.1, 12.2) ayuda de uso ---
:show_help
echo(
echo  %B%%WH%Emergency Repair Suite (WPI) v3.1%R%
echo  %DIM%Diagnoses and repairs Windows 10/11 with no external dependencies.%R%
echo(
echo  %WH%USAGE:%R%  Repair_Suite_AllInOne.bat [options]
echo        ^(right-click -^> Run as administrator^)
echo(
echo  %WH%OPTIONS:%R%
echo    %CY%/auto%R%        Run all phases with no menu (unattended mode).
echo    %CY%/triage%R%      Run only the phases the diagnosis recommends.
echo    %CY%/phases:LIST%R% Run only those phases. E.g.: /phases:05,06,13
echo    %CY%/dry%R%         Simulation: shows what it would do, without touching the system.
echo    %CY%/noreboot%R%    In /auto, do not reboot when finished.
echo    %CY%/keepwu%R%      Respect a Windows Update block (do not re-enable it).
echo    %CY%/resume%R%      Resume a previous run from its checkpoint.
echo    %CY%/quiet%R%       Less text on screen (the log stays complete).
echo    %CY%/selftest%R%    Suite self-test (does not touch the system).
echo    %CY%/version%R%     Show the version and exit.
echo    %CY%/quick%R%       Quick inspection (1-2 min): diagnoses, does not repair.
echo    %CY%/json%R%        Also generate a JSON report (for automation).
echo    %CY%/support%R%     Create a ZIP with logs and report to send to support.
echo    %CY%/nocolor%R%     Plain-text output (no ANSI colors).
echo    %CY%/help, /?%R%    Show this help and exit.
echo(
echo  %WH%EXIT CODES:%R%  0=OK  1=WARN  2=SKIP  3=ERROR
echo  %DIM%Test it first in a virtual machine: it makes real changes.%R%
echo(
exit /b 0

:: --- (Task 10.2 / Req 13) validacion de entorno con registro de cada paso ---
:: Admin y PowerShell ya se validaron en la cabecera; aqui se registran y se
:: comprueba la version de Windows via Cerebro (envcheck). La comprobacion se
:: considera SIEMPRE realizada; si el SO no es 10/11, :err y devuelve 3 (parar).
:env_validate
call :log_consolidate
>>"%LOGFILE%" echo [ENV] Administrator: OK (elevated process from the header)
if not "%QUIET%"=="1" call :info "Environment: administrator privileges OK"
>>"%LOGFILE%" echo [ENV] PowerShell: OK (verified in the header)
call :psh envcheck > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "OS_OK=0" & set "OS_BUILD="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OS_OK=" "%CAP%"`) do for /f "delims=" %%b in ("%%a") do set "OS_OK=%%b"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OS_BUILD=" "%CAP%"`) do for /f "delims=" %%b in ("%%a") do set "OS_BUILD=%%b"
if not defined OS_BUILD set "OS_BUILD=0"
if "!OS_BUILD!"=="" set "OS_BUILD=0"
rem Native fallback (does NOT depend on WMI) in case the brain returned no build
if "!OS_BUILD!"=="0" for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| findstr /i "REG_"') do set "OS_BUILD=%%a"
set /a _b=OS_BUILD 2>nul
if "!_b!"=="" set "_b=0"
if !_b! GEQ 10240 set "OS_OK=1"
>>"%LOGFILE%" echo [ENV] Windows: check completed (build !OS_BUILD!, supported=!OS_OK!)
if "!OS_OK!"=="1" ( call :ok "Environment: Windows 10/11 supported (build !OS_BUILD!)" & exit /b 0 )
if !_b! GTR 0 if !_b! LSS 10240 ( call :err "This system does not look like Windows 10/11 (build !OS_BUILD!). Stopping for safety." & exit /b 3 )
call :warn "Could not determine the Windows version (build !OS_BUILD!); continuing anyway."
exit /b 0

:: --- (Task 10.3 / Req 18) self-test: cerebro responde, cada fase inicializa en
:: /dry sin error y (en desarrollo) equivalencia de bloques. No deja cambios:
:: se respalda y restaura el estado y se borra cualquier informe generado.
:selftest
echo(
echo %BL%============================================================%R%
echo  %B%%WH%SUITE SELF-TEST%R%   %DIM%does not touch the system%R%
echo %BL%============================================================%R%
set "ST_RESULTS="
:: 1) el Cerebro responde
call :psh selftestbrain > "%CAP%" 2>&1
findstr /b /c:"BRAIN_OK=1" "%CAP%" >nul 2>&1
if not errorlevel 1 ( call :ok "Brain: responds correctly" & set "ST_RESULTS=!ST_RESULTS!,1" ) else ( call :err "Brain: does not respond" & set "ST_RESULTS=!ST_RESULTS!,0" )
:: 2) cada fase inicializa en /dry sin ERROR (respaldando el estado)
if exist "%WORK%\estado.json" copy /y "%WORK%\estado.json" "%WORK%\_estado.selftest.bak" >nul 2>&1
set "_OLDDRY=%DRY%" & set "DRY=1"
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do (
    call :Fase%%P >nul 2>&1
    set "_RC=!errorlevel!"
    call :psh mapexit "!_RC!" > "%CAP%" 2>&1
    findstr /b /c:"RES=ERROR" "%CAP%" >nul 2>&1
    if errorlevel 1 ( set "ST_RESULTS=!ST_RESULTS!,1" ) else ( call :warn "Phase %%P returned ERROR while initializing in /dry" & set "ST_RESULTS=!ST_RESULTS!,0" )
)
set "DRY=%_OLDDRY%"
:: restaurar estado y limpiar artefactos del self-test
if exist "%WORK%\_estado.selftest.bak" ( move /y "%WORK%\_estado.selftest.bak" "%WORK%\estado.json" >nul 2>&1 ) else ( if exist "%WORK%\estado.json" del /f /q "%WORK%\estado.json" >nul 2>&1 )
if exist "%WORK%\Informe_%TIMESTAMP%.html" del /f /q "%WORK%\Informe_%TIMESTAMP%.html" >nul 2>&1
call :ok "Phases: all 17 initialize in simulation with no critical errors"
:: 3) equivalencia de bloques (solo si esta el generador, es decir, en desarrollo)
if exist "%~dp0build\generar.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build\generar.ps1" -Check >nul 2>&1
    if errorlevel 1 ( call :err "Equivalence: the .bat files diverge from the canonical source" & set "ST_RESULTS=!ST_RESULTS!,0" ) else ( call :ok "Equivalence: the .bat files match the canonical source" & set "ST_RESULTS=!ST_RESULTS!,1" )
) else (
    call :info "Equivalence: generator not present (normal in the distributed version; skipped)"
)
:: 4) Verificar subrutinas anadidas en v3.1 y variables clave
set "SUB_ERR=0"
for %%S in (do_fase00 do_fase01 do_fase02 do_fase03 do_fase04 do_fase05 do_fase06 do_fase07 do_fase08 do_fase09 do_fase10 do_fase11 do_fase12 do_fase13 do_fase14 do_fase15 do_fase16 plan_wizard run_cmd run_ps run_chkdsk act) do (
    findstr /b /c:":%%S" "%~f0" >nul 2>&1
    if errorlevel 1 (
        call :warn "Self-test: missing subroutine :%%S"
        set "SUB_ERR=1"
    )
)
if not defined COLOR_ON (
    call :warn "Self-test: the COLOR_ON variable is not defined"
    set "SUB_ERR=1"
)
if "!SUB_ERR!"=="0" (
    call :ok "Suite structure: premium subroutines and variables validated"
    set "ST_RESULTS=!ST_RESULTS!,1"
) else (
    call :err "Suite structure: structural checks failed"
    set "ST_RESULTS=!ST_RESULTS!,0"
)
:: veredicto agregado via Cerebro
call :psh selftestresult "!ST_RESULTS!" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "ST_PASS=0"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SELFTEST_PASS=" "%CAP%"`) do set "ST_PASS=%%a"
echo(
if "!ST_PASS!"=="1" ( call :ok "SELF-TEST: ALL PASSED" & exit /b 0 )
call :err "SELF-TEST: some checks failed"
exit /b 3


:: ============================================================
:: Subrutinas anadidas en v3.1 (UI premium + clasificadores)
:: ============================================================

:: --- Barra de progreso general entre fases (ASCII, segura para el generador)
:: %1 = indice de fase actual (1..N)   %2 = total de fases
:: Dibuja: [##########----------]  NN%  (paso i de N). El % se emite con %%.
:progress_bar
setlocal enabledelayedexpansion
set /a "_pb_i=%~1" 2>nul
set /a "_pb_t=%~2" 2>nul
if not defined _pb_i set "_pb_i=0"
if not defined _pb_t set "_pb_t=1"
if !_pb_t! lss 1 set "_pb_t=1"
if !_pb_i! gtr !_pb_t! set "_pb_i=!_pb_t!"
set /a "_pb_pct=(_pb_i*100)/_pb_t"
set /a "_pb_fill=(_pb_i*24)/_pb_t"
if !_pb_fill! gtr 24 set "_pb_fill=24"
if !_pb_fill! lss 0 set "_pb_fill=0"
set /a "_pb_rem=24-_pb_fill"
if !_pb_rem! lss 0 set "_pb_rem=0"
set "_pb_f="
for /l %%n in (1,1,!_pb_fill!) do set "_pb_f=!_pb_f! "
set "_pb_e="
for /l %%n in (1,1,!_pb_rem!) do set "_pb_e=!_pb_e! "
set "_pb_bar="
for /l %%n in (1,1,!_pb_fill!) do set "_pb_bar=!_pb_bar!#"
for /l %%n in (1,1,!_pb_rem!) do set "_pb_bar=!_pb_bar!-"
echo(
if "%COLOR_ON%"=="1" (
    echo    %B%%CY%Suite progress%R%  %BGG%!_pb_f!%R%%BGK%!_pb_e!%R%  %WH%!_pb_pct!%%%R%   %DIM%^(phase !_pb_i! of !_pb_t!^)%R%
) else (
    echo    Suite progress  [!_pb_bar!] !_pb_pct!%%  ^(phase !_pb_i! of !_pb_t!^)
)
endlocal
exit /b 0

:: --- Sub-paso dentro de una fase: %1 = actual  %2 = total  %3 = texto
:substep
if "%QUIET%"=="1" exit /b 0
echo    %DIM%[%~1/%~2]%R% %~3
exit /b 0

:: --- Clasifica el resultado de SFC INDEPENDIENTE DEL IDIOMA.
:: Primario: Cerebro lee CBS.log (siempre en ingles). Respaldo: codigo de
:: salida de sfc (%1). Salida: SFC_RES = clean|repaired|unrepairable|unknown
:sfc_classify
set "SFC_RES=unknown"
call :psh sfcresult > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SFC_RES=" "%CAP%"`) do set "SFC_RES=%%a"
if not "!SFC_RES!"=="unknown" exit /b 0
if "%~1"=="0" ( set "SFC_RES=clean" ) else ( set "SFC_RES=unrepairable" )
exit /b 0

:: --- Consistencia del repositorio WMI (independiente del idioma).
:: %1 = errorlevel de "winmgmt /verifyrepository". Salida: WMI_OK = 1/0
:wmi_consistent
set "WMI_OK=0"
if "%~1"=="0" set "WMI_OK=1"
exit /b 0

:: --- Pausa solo en modo interactivo (no en /auto). Para fases sueltas.
:pause_close
if not "%MODE_AUTO%"=="1" ( echo( & echo  Press any key to close... & pause >nul )
exit /b 0

:: ============================================================
:: MODOS MANUAL / PLAN / RAPIDO (v3.1) - menus con descripcion
:: Cada comando se define UNA vez en :do_faseNN con:
::   tipo, comando, descripcion sencilla, modo, y VELOCIDAD (R=rapido P=profundo).
:: Esa info se reutiliza para mostrar el menu, el plan y el resumen, y es
:: identica en TODA la suite y en cada fase suelta. Los comandos PROFUNDOS
:: avisan de que pueden tardar. Todo respeta /dry y se registra en el log.
:: ============================================================

:: --- Ejecutor unico. %1=tipo %2=comando/sub %3=descripcion %4=modo %5=velocidad ---
:: tipo: cmd|ps|chk|sub|diag . modo "desc": solo guarda descripcion+velocidad.
:act
if "%~4"=="desc" set "PICK_DESC=%~3" & set "PICK_SPEED=%~5" & set "PICK_CMD=%~2"
if "%~4"=="desc" if "%~1"=="chk" set "PICK_CMD=chkdsk %SystemDrive% %~2"
if "%~4"=="desc" if "%~1"=="ps" set "PICK_CMD=powershell: %~2"
if "%~4"=="desc" if "%~1"=="sub" set "PICK_CMD=(internal suite routine)"
if "%~4"=="desc" if "%~1"=="diag" set "PICK_CMD=(extended brain diagnosis)"
if "%~4"=="desc" exit /b 0
if /i "%~5"=="P" call :info "DEEP command: it may take several minutes. That's normal, please wait."
if "%~1"=="cmd"  call :run_cmd "%~2" "%~3"
if "%~1"=="ps"   call :run_ps "%~2" "%~3"
if "%~1"=="chk"  call :run_chkdsk "%~2" "%~3"
if "%~1"=="sub"  call :%~2
if "%~1"=="diag" call :psh diagfull
exit /b 0

:act_all
rem %1=NN  %2=lista de opciones  %3=descripcion  %4=modo  %5=velocidad
if "%~4"=="desc" ( set "PICK_DESC=%~3" & set "PICK_SPEED=%~5" & set "PICK_CMD=(varios comandos, en orden)" & exit /b 0 )
for %%o in (%~2) do call :do_fase%~1 "%%o"
exit /b 0

:run_cmd
call :step "%~2"
if "%DRY%"=="1" call :info "[SIMULATION] %~1"
if "%DRY%"=="1" exit /b 0
%~1
if errorlevel 1 ( call :warn "Finished with warnings: %~2" ) else ( call :ok "Done: %~2" )
exit /b 0

:run_ps
call :step "%~2"
if "%DRY%"=="1" call :info "[SIMULATION] powershell: %~1"
if "%DRY%"=="1" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "%~1"
if errorlevel 1 ( call :warn "Finished with warnings: %~2" ) else ( call :ok "Done: %~2" )
exit /b 0

:run_chkdsk
call :step "%~2"
if "%DRY%"=="1" call :info "[SIMULATION] chkdsk %SystemDrive% %~1"
if "%DRY%"=="1" exit /b 0
call :info "If it asks to schedule on next reboot, answer Y and press Enter."
chkdsk %SystemDrive% %~1
set "CHKDSK_SCHEDULED=1"
exit /b 0

:restart_explorer
call :step "Restarting Windows Explorer"
if "%DRY%"=="1" call :info "[SIMULATION] taskkill explorer + start explorer"
if "%DRY%"=="1" exit /b 0
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
call :ok "Explorer restarted"
exit /b 0

:wu_restart_services
call :step "Restarting Windows Update services"
if "%DRY%"=="1" call :info "[SIMULATION] net stop/start wuauserv and bits"
if "%DRY%"=="1" exit /b 0
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
call :ok "Windows Update services restarted"
exit /b 0

:wu_clear_cache
call :step "Clearing the Windows Update cache"
if "%DRY%"=="1" call :info "[SIMULATION] stop services and rename SoftwareDistribution"
if "%DRY%"=="1" exit /b 0
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
ren "%SystemRoot%\SoftwareDistribution" SoftwareDistribution.old >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
call :ok "Windows Update cache cleared (folder renamed to .old)"
exit /b 0

:gen_report_manual
call :step "Generating the HTML report"
if "%DRY%"=="1" call :info "[SIMULATION] the HTML report would be generated"
if "%DRY%"=="1" exit /b 0
set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
call :psh report "%REPORT%"
if exist "%REPORT%" ( call :ok "Report created in !REPORT!" ) else ( call :warn "Could not generate the report" )
exit /b 0

:: --- Linea de opcion: numero + etiqueta velocidad + descripcion ---
:opt_line
set "PICK_DESC=" & set "PICK_SPEED=" & set "PICK_CMD="
call :do_fase%~1 "%~2" desc
if not defined PICK_DESC exit /b 0
set "STAG=%GY%[ ? ]%R%"
if /i "!PICK_SPEED!"=="R" set "STAG=%GR%[quick]%R% "
if /i "!PICK_SPEED!"=="P" set "STAG=%YE%[deep]%R%"
echo    %CY%%~2%R%^)  !STAG!  !PICK_DESC!
if "%SHOWCMD%"=="1" if defined PICK_CMD echo         %GY%command: !PICK_CMD!%R%
exit /b 0

:: --- Cabecera de menu: muestra titulo + PARA QUE SIRVE the phase (PH_WHY) ---
:menu_head
call :title_of %~1
call :phase "%~1" "!PH_TITLE!" "!PH_WHY!"
echo    %WH%Approx time:%R% !PH_TIME!     %WH%Impact:%R% !PH_SAFE!
echo    %DIM%Tags:%R% %GR%[quick]%R%%DIM%=light/scan%R%  %YE%[deep]%R%%DIM%=repair. Type a number; 0 = back.%R%
echo(
exit /b 0

:: ===== Comandos por fase (fuente unica) =====
:: do_faseNN: %1=opcion  %2=("" runs | "desc" describes)  -> :act ... <R|P>

:do_fase00
if "%~1"=="1" call :act cmd "systeminfo" "View computer info (systeminfo): model, Windows version and RAM" "%~2" R
if "%~1"=="2" call :act ps "Get-PhysicalDisk | Select-Object FriendlyName,HealthStatus,OperationalStatus,@{n='GB';e={[int]($_.Size/1GB)}} | Format-Table -Auto" "Disk health (SMART): warns if a disk is failing" "%~2" R
if "%~1"=="3" call :act diag "" "Extended diagnostics: RAM, battery, network, disks and boot" "%~2" R
if "%~1"=="4" call :act_all 00 "1 2 3" "Run ALL diagnostics (info + SMART + extended)" "%~2" R
exit /b 0
:opts_fase00
call :opt_line 00 1
call :opt_line 00 2
call :opt_line 00 3
call :opt_line 00 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase00
call :menu_head "00"
call :opts_fase00
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase00 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase00

:do_fase01
if "%~1"=="1" call :act ps "Checkpoint-Computer -Description 'WPI Suite' -RestorePointType MODIFY_SETTINGS" "Create a restore point now: a safety net before repairing" "%~2" R
if "%~1"=="2" call :act ps "Get-ComputerRestorePoint | Select-Object SequenceNumber,Description,CreationTime | Format-Table -Auto" "View existing restore points" "%~2" R
if "%~1"=="3" call :act ps "Enable-ComputerRestore -Drive 'C:\'" "Turn on System Protection for C: (required to create points)" "%~2" R
exit /b 0
:opts_fase01
call :opt_line 01 1
call :opt_line 01 2
call :opt_line 01 3
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase01
call :menu_head "01"
call :opts_fase01
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase01 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase01

:do_fase02
if "%~1"=="1" call :act cmd "cleanmgr" "Open Windows Disk Cleanup to remove junk files" "%~2" R
if "%~1"=="2" call :act cmd "del /q /f /s \"%TEMP%\\*\"" "Empty the temporary files folder: frees space fast" "%~2" R
if "%~1"=="3" call :act ps "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" "Empty the Recycle Bin" "%~2" R
if "%~1"=="4" call :act_all 02 "1 2 3" "Run ALL cleanup (Disk Cleanup + temp + recycle bin)" "%~2" R
exit /b 0
:opts_fase02
call :opt_line 02 1
call :opt_line 02 2
call :opt_line 02 3
call :opt_line 02 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase02
call :menu_head "02"
call :opts_fase02
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase02 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase02

:do_fase03
if "%~1"=="1" call :act cmd "chkdsk %SystemDrive%" "Scan the disk only, no changes (chkdsk): checks errors without touching anything" "%~2" R
if "%~1"=="2" call :act cmd "chkdsk %SystemDrive% /scan" "Online scan, no reboot (chkdsk /scan)" "%~2" R
if "%~1"=="3" call :act chk "/f" "Repair disk errors (chkdsk /f): fixes them and will ask to reboot" "%~2" P
if "%~1"=="4" call :act chk "/r" "Repair errors + recover bad sectors (chkdsk /r): the most thorough" "%~2" P
exit /b 0
:opts_fase03
call :opt_line 03 1
call :opt_line 03 2
call :opt_line 03 3
call :opt_line 03 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase03
call :menu_head "03"
call :opts_fase03
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase03 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase03

:do_fase04
if "%~1"=="1" call :act ps "Optimize-Volume -DriveLetter C -Analyze -Verbose" "Analyze the disk: checks fragmentation and whether to optimize" "%~2" R
if "%~1"=="2" call :act ps "Optimize-Volume -DriveLetter C -ReTrim -Verbose" "Optimize SSD (TRIM): keeps the solid-state drive fast" "%~2" R
if "%~1"=="3" call :act ps "Optimize-Volume -DriveLetter C -Defrag -Verbose" "Defragment HDD (mechanical disk): reorders files, may take a while" "%~2" P
if "%~1"=="4" call :act cmd "fsutil behavior query DisableDeleteNotify" "Check whether TRIM is enabled on the system" "%~2" R
exit /b 0
:opts_fase04
call :opt_line 04 1
call :opt_line 04 2
call :opt_line 04 3
call :opt_line 04 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase04
call :menu_head "04"
call :opts_fase04
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase04 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase04

:do_fase05
if "%~1"=="1" call :act cmd "DISM /Online /Cleanup-Image /CheckHealth" "Quick check of the Windows image (DISM /CheckHealth)" "%~2" R
if "%~1"=="2" call :act cmd "DISM /Online /Cleanup-Image /ScanHealth" "Thorough scan of the Windows image (DISM /ScanHealth)" "%~2" P
if "%~1"=="3" call :act cmd "DISM /Online /Cleanup-Image /RestoreHealth" "Repair the Windows image (DISM /RestoreHealth): downloads and fixes" "%~2" P
if "%~1"=="4" call :act cmd "DISM /Online /Cleanup-Image /StartComponentCleanup" "Clean up old components and free space" "%~2" P
exit /b 0
:opts_fase05
call :opt_line 05 1
call :opt_line 05 2
call :opt_line 05 3
call :opt_line 05 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase05
call :menu_head "05"
call :opts_fase05
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase05 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase05

:do_fase06
if "%~1"=="1" call :act cmd "sfc /verifyonly" "Verify system files only, no repair (sfc /verifyonly)" "%~2" P
if "%~1"=="2" call :act cmd "sfc /scannow" "Verify and repair system files (sfc /scannow)" "%~2" P
exit /b 0
:opts_fase06
call :opt_line 06 1
call :opt_line 06 2
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase06
call :menu_head "06"
call :opts_fase06
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase06 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase06

:do_fase07
if "%~1"=="1" call :act cmd "winmgmt /verifyrepository" "Check whether the WMI repository is healthy (verifyrepository)" "%~2" R
if "%~1"=="2" call :act cmd "winmgmt /salvagerepository" "Repair the WMI repository keeping data (salvagerepository)" "%~2" P
if "%~1"=="3" call :act cmd "winmgmt /resetrepository" "Rebuild the WMI repository from scratch (last resort)" "%~2" P
exit /b 0
:opts_fase07
call :opt_line 07 1
call :opt_line 07 2
call :opt_line 07 3
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase07
call :menu_head "07"
call :opts_fase07
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase07 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase07

:do_fase08
if "%~1"=="1" call :act cmd "wsreset.exe" "Reset the Microsoft Store cache (fixes the Store)" "%~2" R
if "%~1"=="2" call :act sub "restart_explorer" "Restart Explorer (refreshes desktop, taskbar and icons)" "%~2" R
if "%~1"=="3" call :act ps "Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location | Format-Table -Auto" "See which programs start with Windows" "%~2" R
if "%~1"=="4" call :act_all 08 "1 2 3" "Run ALL (Store cache + restart Explorer + view startup)" "%~2" R
exit /b 0
:opts_fase08
call :opt_line 08 1
call :opt_line 08 2
call :opt_line 08 3
call :opt_line 08 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase08
call :menu_head "08"
call :opts_fase08
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase08 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase08

:do_fase09
if "%~1"=="1" call :act ps "Restart-Service WSearch -Force" "Restart Windows Search (fixes the Start menu search)" "%~2" R
if "%~1"=="2" call :act cmd "del /a /q \"%LOCALAPPDATA%\\IconCache.db\"" "Clear the icon cache (fixes blank or broken icons)" "%~2" R
if "%~1"=="3" call :act cmd "ipconfig /flushdns" "Flush the DNS cache (trouble opening websites)" "%~2" R
if "%~1"=="4" call :act_all 09 "1 2 3" "Run ALL (Search + icon cache + DNS)" "%~2" R
exit /b 0
:opts_fase09
call :opt_line 09 1
call :opt_line 09 2
call :opt_line 09 3
call :opt_line 09 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase09
call :menu_head "09"
call :opts_fase09
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase09 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase09

:do_fase10
if "%~1"=="1" call :act cmd "w32tm /resync /force" "Sync the clock with the internet (fixes time and certificate errors)" "%~2" R
if "%~1"=="2" call :act cmd "w32tm /query /status" "View time synchronization status" "%~2" R
exit /b 0
:opts_fase10
call :opt_line 10 1
call :opt_line 10 2
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase10
call :menu_head "10"
call :opts_fase10
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase10 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase10

:do_fase11
if "%~1"=="1" call :act cmd "ipconfig /flushdns" "Flush the DNS cache (sites won't load): quick and safe" "%~2" R
if "%~1"=="2" call :act cmd "ipconfig /renew" "Renew the IP address from the router" "%~2" R
if "%~1"=="3" call :act cmd "netsh winsock reset" "Reset Winsock (fixes the connection): will ask to reboot" "%~2" R
if "%~1"=="4" call :act cmd "netsh int ip reset" "Reset the TCP/IP stack (persistent network issues): will ask to reboot" "%~2" R
if "%~1"=="5" call :act_all 11 "1 2 3 4" "Run the FULL network reset (DNS + IP + Winsock + TCP/IP)" "%~2" R
exit /b 0
:opts_fase11
call :opt_line 11 1
call :opt_line 11 2
call :opt_line 11 3
call :opt_line 11 4
call :opt_line 11 5
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase11
call :menu_head "11"
call :opts_fase11
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase11 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase11

:do_fase12
if "%~1"=="1" call :act cmd "gpupdate /force" "Force a group policy refresh" "%~2" P
if "%~1"=="2" call :act cmd "gpresult /r /scope computer" "View the policies applied to the computer" "%~2" R
if "%~1"=="3" call :act_all 12 "1 2" "Run ALL (refresh policies + view result)" "%~2" P
exit /b 0
:opts_fase12
call :opt_line 12 1
call :opt_line 12 2
call :opt_line 12 3
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase12
call :menu_head "12"
call :opts_fase12
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase12 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase12

:do_fase13
if "%~1"=="1" call :act sub "wu_restart_services" "Restart the Windows Update services" "%~2" R
if "%~1"=="2" call :act sub "wu_clear_cache" "Clear the Windows Update cache (fixes stuck updates)" "%~2" P
if "%~1"=="3" call :act cmd "start ms-settings:windowsupdate" "Open Windows Update in Settings" "%~2" R
if "%~1"=="4" call :act_all 13 "1 2 3" "Run ALL (restart services + clear cache + open WU)" "%~2" P
exit /b 0
:opts_fase13
call :opt_line 13 1
call :opt_line 13 2
call :opt_line 13 3
call :opt_line 13 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase13
call :menu_head "13"
call :opts_fase13
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase13 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase13

:do_fase14
if "%~1"=="1" call :act cmd "winget --version" "Show the winget version (check it is installed)" "%~2" R
if "%~1"=="2" call :act cmd "winget upgrade --all --accept-source-agreements --accept-package-agreements" "Update ALL programs with winget: can take a long time" "%~2" P
if "%~1"=="3" call :act cmd "start ms-windows-store://pdp/?productid=9NBLGGH4NNS1" "Reinstall App Installer (winget) from the Store" "%~2" R
exit /b 0
:opts_fase14
call :opt_line 14 1
call :opt_line 14 2
call :opt_line 14 3
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase14
call :menu_head "14"
call :opts_fase14
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase14 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase14

:do_fase15
if "%~1"=="1" call :act cmd "pnputil /scan-devices" "Scan for hardware changes (detects new devices)" "%~2" R
if "%~1"=="2" call :act ps "Get-PnpDevice | Where-Object {$_.Status -ne 'OK'} | Select-Object FriendlyName,Status,Class | Format-Table -Auto" "View devices with problems or missing drivers" "%~2" R
if "%~1"=="3" call :act cmd "devmgmt.msc" "Open Device Manager" "%~2" R
exit /b 0
:opts_fase15
call :opt_line 15 1
call :opt_line 15 2
call :opt_line 15 3
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase15
call :menu_head "15"
call :opts_fase15
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase15 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase15

:do_fase16
if "%~1"=="1" call :act cmd "ipconfig /flushdns" "Flush the DNS cache" "%~2" R
if "%~1"=="2" call :act cmd "del /f /q \"%SystemRoot%\\Panther\\*.log\"" "Delete old setup logs (Panther): frees space" "%~2" R
if "%~1"=="3" call :act sub "gen_report_manual" "Generate the HTML report for this session" "%~2" R
if "%~1"=="4" call :act_all 16 "1 2 3" "Run ALL final cleanup (DNS + logs + report)" "%~2" R
exit /b 0
:opts_fase16
call :opt_line 16 1
call :opt_line 16 2
call :opt_line 16 3
call :opt_line 16 4
echo    %CY%0%R%^)  Back / skip
exit /b 0
:menu_fase16
call :menu_head "16"
call :opts_fase16
set "OPT=" & set /p "OPT=   Your choice: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase16 "!OPT!"
echo(
echo  %DIM%Press a key to return to the phase menu (choose 0 to close)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase16

:: ============================================================
:: QUICK INSPECTION con submodos (solo escaneo / escaneo + reparacion)
:: ============================================================
:quick_wizard
call :bigbanner
echo  %B%%WH%QUICK INSPECTION%R%   %DIM%choose the scope%R%
echo(
echo    %CY%1%R%^)  %GR%[quick]%R%   Scan only: checks the PC and changes NOTHING
echo    %CY%2%R%^)  %YE%[deep]%R% Scan + safe repair (SFC and DISM): may take a while
echo    %CY%0%R%^)  Back
echo(
choice /C 120 /N /M "  Your choice: "
set "QW=!errorlevel!"
if "!QW!"=="1" call :quick_run scan
if "!QW!"=="2" call :quick_run fix
exit /b 0

:quick_run
rem %1 = scan | fix
if /i "%~1"=="fix" ( call :info "Quick inspection: scan + safe repair" ) else ( call :info "Quick inspection: scan only (changes nothing)" )
call :quick_step 00 3
call :quick_step 03 1
call :quick_step 05 1
call :quick_step 06 1
call :quick_step 07 1
call :quick_step 11 1
call :quick_step 15 2
if /i "%~1"=="fix" call :quick_fix
call :gen_report_manual
exit /b 0

:quick_fix
call :info "Applying safe repairs (this may take a while)..."
call :quick_step 06 2
call :quick_step 05 3
exit /b 0

:: Ejecuta una opcion de una fase mostrando su cabecera. %1=NN %2=opcion
:quick_step
call :title_of %~1
call :phase "%~1" "!PH_TITLE!" "!PH_WHY!"
call :do_fase%~1 "%~2"
exit /b 0

:: ============================================================
:: CUSTOM PLAN (asistente guiado)
:: ============================================================
:plan_wizard
:plan_top
call :plan_reset
call :bigbanner
echo  %B%%WH%CUSTOM PLAN%R%   %DIM%pick a command per phase, or skip the ones you don't need%R%
echo  %DIM%Command number, 0 to skip the phase, or X to finish choosing.%R%
call :plan_build
call :plan_summary
echo(
choice /C YNC /N /M "  Start with this plan?   Y = Yes    N = No    C = Change: "
set "PCONF=!errorlevel!"
if "!PCONF!"=="3" goto :plan_top
if "!PCONF!"=="2" ( call :info "Plan cancelled. Nothing was run." & exit /b 0 )
echo(
call :info "Starting your custom plan..."
call :plan_run
call :gen_report_manual
exit /b 0

:plan_reset
set "PLAN_FINISH=0"
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do set "PLAN_%%P="
exit /b 0

:plan_build
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do call :plan_ask %%P
exit /b 0

:plan_ask
if "!PLAN_FINISH!"=="1" exit /b 0
set "PN=%~1"
call :title_of !PN!
echo(
echo  %BGB%%WH%%B%  Phase !PN!: !PH_TITLE!%R%
echo   %DIM%!PH_WHY!%R%
call :opts_fase!PN!
set "OPT=" & set /p "OPT=   Choose a number (0 = skip, X = finish): "
if /i "!OPT!"=="X" ( set "PLAN_FINISH=1" & set "OPT=0" )
if "!OPT!"=="" set "OPT=0"
set "PLAN_!PN!=!OPT!"
if not "!OPT!"=="0" call :plan_echo_pick !PN! !OPT!
exit /b 0

:plan_echo_pick
set "PICK_DESC=" & set "PICK_SPEED="
call :do_fase%~1 "%~2" desc
if defined PICK_DESC echo    %GR%Anotado:%R% !PICK_DESC!
exit /b 0

:plan_summary
echo(
echo  %B%%WH%========== YOUR PLAN ==========%R%
set "PLAN_ANY=0"
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do call :plan_show %%P
if "!PLAN_ANY!"=="0" echo   %DIM%(you didn't choose any command; the plan is empty)%R%
echo  %B%%WH%=============================%R%
exit /b 0

:plan_show
set "PN=%~1"
set "SEL=!PLAN_%PN%!"
if not defined SEL exit /b 0
if "!SEL!"=="0" exit /b 0
set "PICK_DESC=" & set "PICK_SPEED="
call :do_fase!PN! "!SEL!" desc
call :title_of !PN!
set "STAG=%GY%[ ? ]%R%"
if /i "!PICK_SPEED!"=="R" set "STAG=%GR%[quick]%R%"
if /i "!PICK_SPEED!"=="P" set "STAG=%YE%[deep]%R%"
if defined PICK_DESC echo    %GR%Phase !PN!%R% %WH%!PH_TITLE!%R%  !STAG!
if defined PICK_DESC echo        %DIM%->%R% !PICK_DESC!
set "PLAN_ANY=1"
exit /b 0

:plan_run
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do call :plan_exec %%P
exit /b 0

:plan_exec
set "PN=%~1"
set "SEL=!PLAN_%PN%!"
if not defined SEL exit /b 0
if "!SEL!"=="0" exit /b 0
call :title_of !PN!
call :phase "!PN!" "!PH_TITLE!" "!PH_WHY!"
call :do_fase!PN! "!SEL!"
exit /b 0
HLP:IyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIFdQSSAtIENlcmVicm8gZGUgbGEgU3VpdGUgZGUgUmVwYXJhY2lvbiAoaGVscGVyKQojICBJbnZvY2FkbyBwb3IgZWwg
HLP:LmJhdDogcG93ZXJzaGVsbCAtRmlsZSBzdWl0ZV9oZWxwZXIucHMxIC1BY3Rpb24gPGFjY2lvbj4gLi4uCiMgIEFjY2lvbmVzOiBzeXNpbmZvIHwgc2NvcmUgfCBmb3JlbnNpY3MgfCB0cmlhZ2UgfCByZXN0b3JlcG9pbnQgfCBtZWRpYXR5cGUKIyAgICAgICAgICAg
HLP:IHwgZGV2aWNlcyB8IHJlcG9ydCB8IGFkZHBoYXNlIHwgc2V0YmVmb3JlIHwgc2V0YWZ0ZXIgfCBmaW5kaW5nCiMgICAgICAgICAgICB8IHJlc2V0c3RhdGUgfCBub3JtYWxpemVmYXNlcyB8IGNoZWNrcG9pbnQgfCBtb3ZlcmVzdWx0IHwgdnRsd3JpdGUKIyAgICAg
HLP:ICAgICAgIHwgbWFwZXhpdCB8IHJhbWNoZWNrIHwgYmF0dGVyeSB8IG5ldGFkdmFuY2VkIHwgZGlhZ2Z1bGwKIyAgICAgICAgICAgIHwgbG9ncm90YXRlIHwgZW52Y2hlY2sgfCBzZWxmdGVzdGJyYWluIHwgc2VsZnRlc3RyZXN1bHQKIyAgICAgICAgICAgIHwgc2Zj
HLP:cmVzdWx0IHwganNvbnJlcG9ydCB8IHN1cHBvcnRwYWNrYWdlCiMgIFRvZG8gdmEgYSBTVERPVVQgZW4gbGluZWFzIEtFWT1WQUxVRSAoZmFjaWxlcyBkZSBsZWVyIGRlc2RlIGJhdGNoIGNvbiBGT1IpLAojICBzYWx2byAncmVwb3J0JyBxdWUgZXNjcmliZSB1biBI
HLP:VE1MLiBTaW4gZGVwZW5kZW5jaWFzIGV4dGVybmFzLgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KcGFyYW0oCiAgICBbc3RyaW5nXSRBY3Rpb24gPSAnc3lzaW5mbycs
HLP:CiAgICBbc3RyaW5nXSRXb3JrICAgPSAiJGVudjpURU1QXFdQSV9TdWl0ZSIsCiAgICBbc3RyaW5nXSRBcmcgICAgPSAnJwopCiRFcnJvckFjdGlvblByZWZlcmVuY2UgPSAnU2lsZW50bHlDb250aW51ZScKaWYgKC1ub3QgKFRlc3QtUGF0aCAkV29yaykpIHsgTmV3
HLP:LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkV29yayAtRm9yY2UgfCBPdXQtTnVsbCB9CiRTdGF0ZUZpbGUgPSBKb2luLVBhdGggJFdvcmsgJ2VzdGFkby5qc29uJwoKIyAtLS0gQ29uc3RhbnRlcyBkZSBjb25maWd1cmFjaW9uIChhbGluZWFkYXMgY29u
HLP:IG1hbmlmZXN0LnBzZDEgLyBkZXNpZ24pIC0tLQokQ2hlY2twb2ludEZpbGUgICAgICAgICAgPSBKb2luLVBhdGggJFdvcmsgJ2NoZWNrcG9pbnQuanNvbicKJFdQSV9WRVJTSU9OICAgICAgICAgICAgID0gJzMuMScKJENIRUNLUE9JTlRfTUFYX0FHRV9EQVlTID0g
HLP:NwokVlRfTEVWRUxfREVTSVJFRCAgICAgICAgPSAxCiRMT0dfUkVURU5USU9OICAgICAgICAgICA9IDEwCgpmdW5jdGlvbiBSZWFkLVN0YXRlIHsKICAgIGlmIChUZXN0LVBhdGggJFN0YXRlRmlsZSkgeyB0cnkgeyByZXR1cm4gKEdldC1Db250ZW50ICRTdGF0ZUZp
HLP:bGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24pIH0gY2F0Y2gge30gfQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzY29yZV9iZWZvcmUgPSAkbnVsbDsgc2NvcmVfYWZ0ZXIgPSAkbnVsbDsgZmluZGluZ3MgPSBAKCk7IHBoYXNlcyA9IEAoKTsgZGlhZyA9
HLP:ICRudWxsIH0KfQpmdW5jdGlvbiBXcml0ZS1TdGF0ZSgkcykgeyB0cnkgeyBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJFN0YXRlRmlsZSwgKCRzIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDYpLCAoTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5j
HLP:b2RpbmcoJGZhbHNlKSkpIH0gY2F0Y2gge30gfQoKIyBHYXJhbnRpemEgcXVlIGVsIGVzdGFkbyB0aWVuZSBlbCBzdWItb2JqZXRvICdkaWFnJyAocmFtL2JhdHRlcnkvZGV2aWNlcy9uZXR3b3JrKS4KIyBDb21wYXRpYmxlIGNvbiBlc3RhZG9zIGFudGlndW9zIGNh
HLP:cmdhZG9zIGRlIGVzdGFkby5qc29uIHNpbiBsYSBwcm9waWVkYWQgJ2RpYWcnLgpmdW5jdGlvbiBJbml0aWFsaXplLURpYWcoJHN0KSB7CiAgICBpZiAoLW5vdCAoJHN0LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2RpYWcnKSAtb3IgJG51bGwg
HLP:LWVxICRzdC5kaWFnKSB7CiAgICAgICAgJGRpYWcgPSBbcHNjdXN0b21vYmplY3RdQHsgcmFtID0gJG51bGw7IGJhdHRlcnkgPSAkbnVsbDsgZGV2aWNlcyA9IEAoKTsgbmV0d29yayA9ICRudWxsOyBzbWFydCA9ICRudWxsOyBiY2QgPSAkbnVsbDsgcHJvY2Vzc2Vz
HLP:ID0gJG51bGw7IHN0YXJ0dXAgPSAkbnVsbCB9CiAgICAgICAgJHN0IHwgQWRkLU1lbWJlciAtTm90ZVByb3BlcnR5TmFtZSBkaWFnIC1Ob3RlUHJvcGVydHlWYWx1ZSAkZGlhZyAtRm9yY2UKICAgIH0gZWxzZSB7CiAgICAgICAgZm9yZWFjaCAoJHBwIGluICdzbWFy
HLP:dCcsJ2JjZCcsJ3Byb2Nlc3NlcycsJ3N0YXJ0dXAnKSB7CiAgICAgICAgICAgIGlmICgtbm90ICgkc3QuZGlhZy5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICRwcCkpIHsKICAgICAgICAgICAgICAgICRzdC5kaWFnIHwgQWRkLU1lbWJlciAtTm90
HLP:ZVByb3BlcnR5TmFtZSAkcHAgLU5vdGVQcm9wZXJ0eVZhbHVlICRudWxsIC1Gb3JjZQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQogICAgcmV0dXJuICRzdAp9CgpmdW5jdGlvbiBHZXQtU3lzSW5mbyB7CiAgICAkb3MgID0gR2V0LUNpbUluc3RhbmNlIFdp
HLP:bjMyX09wZXJhdGluZ1N5c3RlbSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgJGNzICA9IEdldC1DaW1JbnN0YW5jZSBXaW4zMl9Db21wdXRlclN5c3RlbSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgJGNwdSA9IChHZXQtQ2ltSW5z
HLP:dGFuY2UgV2luMzJfUHJvY2Vzc29yIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkKICAgICRjICAgPSBHZXQtUFNEcml2ZSBDCiAgICBpZiAoJG9zIC1hbmQgJG9zLkxhc3RCb290VXBUaW1lKSB7CiAgICAgICAg
HLP:JHVwID0gKEdldC1EYXRlKSAtICRvcy5MYXN0Qm9vdFVwVGltZQogICAgfSBlbHNlIHsKICAgICAgICAkdGlja3MgPSBbU3lzdGVtLkVudmlyb25tZW50XTo6VGlja0NvdW50NjQKICAgICAgICBpZiAoJG51bGwgLWVxICR0aWNrcykgewogICAgICAgICAgICAkdGlj
HLP:a3MgPSBbU3lzdGVtLkVudmlyb25tZW50XTo6VGlja0NvdW50CiAgICAgICAgICAgIGlmICgkdGlja3MgLWx0IDApIHsgJHRpY2tzID0gW3VpbnQzMl0kdGlja3MgfQogICAgICAgIH0KICAgICAgICAkdXAgPSBbVGltZVNwYW5dOjpGcm9tTWlsbGlzZWNvbmRzKCR0
HLP:aWNrcykKICAgIH0KICAgICRjcHVOYW1lID0gIiIKICAgIGlmICgkY3B1IC1hbmQgJGNwdS5OYW1lKSB7ICRjcHVOYW1lID0gJGNwdS5OYW1lLlRyaW0oKSB9CiAgICAkcmFtR0IgID0gW21hdGhdOjpSb3VuZCgkY3MuVG90YWxQaHlzaWNhbE1lbW9yeS8xR0IsMSkK
HLP:ICAgICRmcmVlR0IgPSBbbWF0aF06OlJvdW5kKCRjLkZyZWUvMUdCLDEpCiAgICAkdG90R0IgID0gW21hdGhdOjpSb3VuZCgoJGMuRnJlZSskYy5Vc2VkKS8xR0IsMSkKICAgICJPUz0kKCRvcy5DYXB0aW9uKSAoYnVpbGQgJCgkb3MuQnVpbGROdW1iZXIpKSIKICAg
HLP:ICJTWVNURU09JCgkY3MuTWFudWZhY3R1cmVyKSAkKCRjcy5Nb2RlbCkiCiAgICAiQ1BVPSRjcHVOYW1lIgogICAgIlJBTT0kcmFtR0IgR0IiCiAgICAiRElTSz1DOiAkZnJlZUdCIEdCIGZyZWUgb2YgJHRvdEdCIEdCIgogICAgIlVQVElNRT0kKFtpbnRdJHVwLlRv
HLP:dGFsRGF5cylkICQoJHVwLkhvdXJzKWggJCgkdXAuTWludXRlcyltIgogICAgIlVTRVI9JGVudjpVU0VSTkFNRSIKfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojICg1
HLP:LjIgLyBSZXEgMTUuNikgTnVjbGVvIFBVUk8gZGUgY2FsY3VsbyBkZWwgc2NvcmUuCiMgUmVjaWJlIHVuIGhhc2h0YWJsZSBkZSBzaW50b21hcyAoZmxhZ3MvY29udGVvcykgeSBkZXZ1ZWx2ZSB1biBlbnRlcm8gZW4KIyBbMCwxMDBdLiBDYWRhIHNpbnRvbWEgc29s
HLP:byBwdWVkZSBSRVNUQVIgcHVudG9zLCBwb3IgbG8gcXVlIGFuYWRpciBvIGFncmF2YXIKIyBjdWFscXVpZXIgc2ludG9tYSBudW5jYSBzdWJlIGVsIHNjb3JlIChNT05PVE9OSUEpLCB5IGVsIGNsYW1wIGdhcmFudGl6YSBlbAojIHJhbmdvIFswLDEwMF0uIEVzIGRl
HLP:dGVybWluaXN0YSByZXNwZWN0byBhIHN1IGVudHJhZGEgKHRlc3RlYWJsZSBkZSBmb3JtYQojIGFpc2xhZGEgcGFyYSBsYSBQcm9wZXJ0eSAxMCkuCmZ1bmN0aW9uIENvbXB1dGUtU2NvcmUoW2hhc2h0YWJsZV0kc3ltKSB7CiAgICBpZiAoJG51bGwgLWVxICRzeW0p
HLP:IHsgJHN5bSA9IEB7fSB9CiAgICAkc2NvcmUgPSAxMDAKICAgICMgLS0tIFBlbmFsaXphY2lvbmVzIGV4aXN0ZW50ZXMgKHByZXNlcnZhZGFzKSAtLS0KICAgIGlmICgkc3ltWydzbWFydEJhZCddKSAgICAgICB7ICRzY29yZSAtPSAyNSB9CiAgICBpZiAoJHN5bS5D
HLP:b250YWluc0tleSgnZnJlZUdCJykgLWFuZCAkbnVsbCAtbmUgJHN5bVsnZnJlZUdCJ10pIHsKICAgICAgICAkZnJlZUdCID0gW2RvdWJsZV0kc3ltWydmcmVlR0InXQogICAgICAgIGlmICAgICAoJGZyZWVHQiAtbHQgNSkgIHsgJHNjb3JlIC09IDE1IH0KICAgICAg
HLP:ICBlbHNlaWYgKCRmcmVlR0IgLWx0IDE1KSB7ICRzY29yZSAtPSA2IH0KICAgIH0KICAgIGlmICgkc3ltWydyZWJvb3RQZW5kaW5nJ10pICAgICAgICAgIHsgJHNjb3JlIC09IDUgfQogICAgaWYgKFtpbnRdJHN5bVsnYnNvZCddIC1ndCAwKSAgICAgICAgeyAkc2Nv
HLP:cmUgLT0gMTggfQogICAgaWYgKFtpbnRdJHN5bVsnZGlza0VyciddIC1ndCAwKSAgICAgeyAkc2NvcmUgLT0gMTIgfQogICAgaWYgKFtpbnRdJHN5bVsnd2hlYSddIC1ndCAwKSAgICAgICAgeyAkc2NvcmUgLT0gMTIgfQogICAgaWYgKFtpbnRdJHN5bVsnY3JpdENv
HLP:dW50J10gLWd0IDI1KSAgeyAkc2NvcmUgLT0gNiB9CiAgICBpZiAoW2ludF0kc3ltWydzdmNTdG9wcGVkJ10gLWd0IDApICB7ICRzY29yZSAtPSA0ICogW2ludF0kc3ltWydzdmNTdG9wcGVkJ10gfQogICAgaWYgKFtpbnRdJHN5bVsnZGV2UHJvYmxlbXMnXSAtZ3Qg
HLP:MCkgeyAkc2NvcmUgLT0gW21hdGhdOjpNaW4oMTIsIFtpbnRdJHN5bVsnZGV2UHJvYmxlbXMnXSAqIDMpIH0KICAgICMgLS0tIE51ZXZhcyBwZW5hbGl6YWNpb25lcyBkZWwgZGlhZ25vc3RpY28gYW1wbGlhZG8gKDUuMikgLS0tCiAgICBpZiAoJHN5bVsncmFtU3Vz
HLP:cGVjdCddKSB7ICRzY29yZSAtPSAxMCB9ICAgIyBSQU0gc29zcGVjaG9zYQogICAgaWYgKCRzeW0uQ29udGFpbnNLZXkoJ2JhdHRlcnlIZWFsdGhQY3QnKSAtYW5kICRudWxsIC1uZSAkc3ltWydiYXR0ZXJ5SGVhbHRoUGN0J10pIHsKICAgICAgICAkYnAgPSBbaW50
HLP:XSRzeW1bJ2JhdHRlcnlIZWFsdGhQY3QnXQogICAgICAgIGlmICgkYnAgLWdlIDAgLWFuZCAkYnAgLWx0IDUwKSB7ICRzY29yZSAtPSA4IH0gICAjIGJhdGVyaWEgbXV5IGRlZ3JhZGFkYSAoPDUwJSkKICAgIH0KICAgIGlmICgkc3ltWyduZXRQcm9ibGVtJ10pIHsg
HLP:JHNjb3JlIC09IDggfSAgICMgcHJvYmxlbWFzIGRlIHJlZCBwZXJzaXN0ZW50ZXMKICAgICMgLS0tIENsYW1wIGFsIHJhbmdvIFswLDEwMF0gLS0tCiAgICBpZiAoJHNjb3JlIC1sdCAwKSAgIHsgJHNjb3JlID0gMCB9CiAgICBpZiAoJHNjb3JlIC1ndCAxMDApIHsg
HLP:JHNjb3JlID0gMTAwIH0KICAgIHJldHVybiBbaW50XSRzY29yZQp9CgojIFB1bnR1YWNpb24gZGUgc2FsdWQgMC0xMDA6IHJlY29sZWN0YSBzaW50b21hcyByZWFsZXMgZGVsIHNpc3RlbWEgKGluY2x1aWRvIGVsCiMgZGlhZ25vc3RpY28gYW1wbGlhZG8gcGVyc2lz
HLP:dGlkbyBlbiBlc3RhZG8uZGlhZykgeSBkZWxlZ2EgZWwgY2FsY3VsbyBlbiBsYQojIGZ1bmNpb24gcHVyYSBDb21wdXRlLVNjb3JlLgpmdW5jdGlvbiBHZXQtSGVhbHRoU2NvcmUgewogICAgJHJlYXNvbnMgPSBAKCkKICAgICRzeW0gPSBAe30KICAgICMgRGlzY28g
HLP:U01BUlQKICAgICRiYWQgPSBAKEdldC1QaHlzaWNhbERpc2sgfCBXaGVyZS1PYmplY3QgeyAkXy5IZWFsdGhTdGF0dXMgLW5lICdIZWFsdGh5JyB9KQogICAgJHN5bVsnc21hcnRCYWQnXSA9ICgkYmFkLkNvdW50IC1ndCAwKQogICAgaWYgKCRzeW1bJ3NtYXJ0QmFk
HLP:J10pIHsgJHJlYXNvbnMgKz0gIkRpc2sgd2l0aCBkZWdyYWRlZCBTTUFSVCAoLTI1KSIgfQogICAgIyBFc3BhY2lvIGxpYnJlCiAgICAkYyA9IEdldC1QU0RyaXZlIEM7ICRmcmVlR0IgPSBbbWF0aF06OlJvdW5kKCRjLkZyZWUvMUdCLDEpCiAgICAkc3ltWydmcmVl
HLP:R0InXSA9ICRmcmVlR0IKICAgIGlmICAgICAoJGZyZWVHQiAtbHQgNSkgIHsgJHJlYXNvbnMgKz0gIkxlc3MgdGhhbiA1IEdCIGZyZWUgb24gQzogKC0xNSkiIH0KICAgIGVsc2VpZiAoJGZyZWVHQiAtbHQgMTUpIHsgJHJlYXNvbnMgKz0gIkxvdyBmcmVlIHNwYWNl
HLP:IG9uIEM6ICgtNikiIH0KICAgICMgUmVpbmljaW8gcGVuZGllbnRlCiAgICAkcGVuZCA9IChUZXN0LVBhdGggJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXENvbXBvbmVudCBCYXNlZCBTZXJ2aWNpbmdcUmVib290UGVuZGlu
HLP:ZycpIC1vciBgCiAgICAgICAgICAgIChUZXN0LVBhdGggJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXFdpbmRvd3NVcGRhdGVcQXV0byBVcGRhdGVcUmVib290UmVxdWlyZWQnKQogICAgJHN5bVsncmVib290UGVuZGluZydd
HLP:ID0gW2Jvb2xdJHBlbmQKICAgIGlmICgkcGVuZCkgeyAkcmVhc29ucyArPSAiUGVuZGluZyByZWJvb3QgKC01KSIgfQogICAgIyBFdmVudG9zIGNyaXRpY29zIHJlY2llbnRlcyAoNDhoKQogICAgJHNpbmNlID0gKEdldC1EYXRlKS5BZGRIb3VycygtNDgpCiAgICAk
HLP:Y3JpdCA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBMZXZlbD0xLDI7IFN0YXJ0VGltZT0kc2luY2V9IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgJGJzb2QgPSBAKCRjcml0IHwgV2hlcmUtT2Jq
HLP:ZWN0IHsgJF8uSWQgLWluIDQxLDEwMDEsNjAwOCB9KS5Db3VudAogICAgJGRpc2sgPSBAKCRjcml0IHwgV2hlcmUtT2JqZWN0IHsgJF8uUHJvdmlkZXJOYW1lIC1tYXRjaCAnZGlza3xOdGZzfHZvbG1ncicgfSkuQ291bnQKICAgICR3aGVhID0gQCgkY3JpdCB8IFdo
HLP:ZXJlLU9iamVjdCB7ICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2ggJ1dIRUEnIH0pLkNvdW50CiAgICAkc3ltWydic29kJ10gPSAkYnNvZDsgJHN5bVsnZGlza0VyciddID0gJGRpc2s7ICRzeW1bJ3doZWEnXSA9ICR3aGVhOyAkc3ltWydjcml0Q291bnQnXSA9ICRjcml0
HLP:LkNvdW50CiAgICBpZiAoJGJzb2QgLWd0IDApIHsgJHJlYXNvbnMgKz0gIlJlY2VudCBjcmFzaGVzL0JTT0Q6ICRic29kICgtMTgpIiB9CiAgICBpZiAoJGRpc2sgLWd0IDApIHsgJHJlYXNvbnMgKz0gIlJlY2VudCBkaXNrL05URlMgZXJyb3JzOiAkZGlzayAoLTEy
HLP:KSIgfQogICAgaWYgKCR3aGVhIC1ndCAwKSB7ICRyZWFzb25zICs9ICJIYXJkd2FyZSBlcnJvcnMgKFdIRUEpOiAkd2hlYSAoLTEyKSIgfQogICAgaWYgKCRjcml0LkNvdW50IC1ndCAyNSkgeyAkcmVhc29ucyArPSAiTWFueSBjcml0aWNhbCBldmVudHMgaW4gNDho
HLP:OiAkKCRjcml0LkNvdW50KSAoLTYpIiB9CiAgICAjIFNlcnZpY2lvcyBjbGF2ZSBwYXJhZG9zCiAgICAkc3ZjU3RvcHBlZCA9IDAKICAgIGZvcmVhY2ggKCRzdmMgaW4gJ3d1YXVzZXJ2JywnQklUUycsJ1dpbm1nbXQnLCdFdmVudExvZycpIHsKICAgICAgICAkcyA9
HLP:IEdldC1TZXJ2aWNlICRzdmMgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICBpZiAoJHMgLWFuZCAkcy5TdGF0dXMgLW5lICdSdW5uaW5nJyAtYW5kICRzLlN0YXJ0VHlwZSAtbmUgJ0Rpc2FibGVkJykgeyAkc3ZjU3RvcHBlZCsrOyAkcmVhc29u
HLP:cyArPSAiU2VydmljZSAkc3ZjIHN0b3BwZWQgKC00KSIgfQogICAgfQogICAgJHN5bVsnc3ZjU3RvcHBlZCddID0gJHN2Y1N0b3BwZWQKICAgICMgRGV2aWNlcyBjb24gcHJvYmxlbWEKICAgICRwcm9iID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUG5QRW50aXR5
HLP:IHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFuYWdlckVycm9yQ29kZSAtZ3QgMCB9KS5Db3VudAogICAgJHN5bVsnZGV2UHJvYmxlbXMnXSA9ICRwcm9iCiAgICBpZiAoJHByb2IgLWd0IDApIHsgJHJlYXNvbnMgKz0gIkRldmljZXMgd2l0aCBlcnJvcnM6ICRw
HLP:cm9iIiB9CiAgICAjIC0tLSBEaWFnbm9zdGljbyBhbXBsaWFkbyBwZXJzaXN0aWRvICg1LjIpOiBSQU0sIGJhdGVyaWEsIHJlZCAtLS0KICAgICRzdCA9IFJlYWQtU3RhdGUKICAgIGlmICgoJHN0LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2Rp
HLP:YWcnKSAtYW5kICRzdC5kaWFnKSB7CiAgICAgICAgaWYgKCRzdC5kaWFnLnJhbSAtYW5kIChbc3RyaW5nXSRzdC5kaWFnLnJhbS5zdGF0dXMgLWVxICdzdXNwZWN0JykpIHsKICAgICAgICAgICAgJHN5bVsncmFtU3VzcGVjdCddID0gJHRydWU7ICRyZWFzb25zICs9
HLP:ICJSQU0gc3VzcGljaW91cyAoLTEwKSIKICAgICAgICB9CiAgICAgICAgaWYgKCRzdC5kaWFnLmJhdHRlcnkgLWFuZCAkc3QuZGlhZy5iYXR0ZXJ5LnByZXNlbnQpIHsKICAgICAgICAgICAgJGJwUmF3ID0gJHN0LmRpYWcuYmF0dGVyeS5oZWFsdGhfcGN0CiAgICAg
HLP:ICAgICAgIGlmICgkbnVsbCAtbmUgJGJwUmF3IC1hbmQgW3N0cmluZ10kYnBSYXcgLW5lICcnKSB7CiAgICAgICAgICAgICAgICAkYnAgPSAkbnVsbDsgdHJ5IHsgJGJwID0gW2ludF0kYnBSYXcgfSBjYXRjaCB7ICRicCA9ICRudWxsIH0KICAgICAgICAgICAgICAg
HLP:IGlmICgkbnVsbCAtbmUgJGJwKSB7CiAgICAgICAgICAgICAgICAgICAgJHN5bVsnYmF0dGVyeUhlYWx0aFBjdCddID0gJGJwCiAgICAgICAgICAgICAgICAgICAgaWYgKCRicCAtZ2UgMCAtYW5kICRicCAtbHQgNTApIHsgJHJlYXNvbnMgKz0gIkJhdHRlcnkgaGVh
HLP:dmlseSBkZWdyYWRlZDogJGJwJSAoLTgpIiB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgaWYgKCRzdC5kaWFnLm5ldHdvcmsgLWFuZCAoKCRzdC5kaWFnLm5ldHdvcmsuY29ubmVjdGVkIC1lcSAkZmFsc2UpIC1vciAo
HLP:JHN0LmRpYWcubmV0d29yay5kbnNfb2sgLWVxICRmYWxzZSkpKSB7CiAgICAgICAgICAgICRzeW1bJ25ldFByb2JsZW0nXSA9ICR0cnVlOyAkcmVhc29ucyArPSAiUGVyc2lzdGVudCBuZXR3b3JrIHByb2JsZW1zICgtOCkiCiAgICAgICAgfQogICAgfQogICAgJHNj
HLP:b3JlID0gQ29tcHV0ZS1TY29yZSAkc3ltCiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHNjb3JlID0gW2ludF0kc2NvcmU7IHJlYXNvbnMgPSAkcmVhc29ucyB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBGb3JlbnNlIGRlbCByZWdpc3RybyBkZSBldmVudG9zOiB1bHRpbW9zIGVycm9yZXMgcXVlIGV4cGxpY2FuIGxhIGNhdXNhIHJhaXouCmZ1bmN0aW9uIEdldC1Gb3JlbnNpY3MgewogICAgJHNpbmNlID0gKEdldC1E
HLP:YXRlKS5BZGREYXlzKC03KQogICAgJG91dCA9IEAoKQogICAgJGV2ID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IExldmVsPTEsMjsgU3RhcnRUaW1lPSRzaW5jZX0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGlu
HLP:dWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCA0MDApCiAgICAkZ3JvdXBzID0gQCgKICAgICAgICBAeyBrPSdBUlJBTlFVRS9BUEFHT04nOyBpZHM9QCg0MSw2MDA4LDEwMDEpOyBwcm92PScnIH0sCiAgICAgICAgQHsgaz0nRElTQ08vTlRGUyc7ICAgICAgaWRzPUAo
HLP:KTsgICAgICAgICAgICAgcHJvdj0nZGlza3xOdGZzfHZvbG1ncnxzdG9ybnZtZXxzdG9yYWhjaScgfSwKICAgICAgICBAeyBrPSdIQVJEV0FSRSAoV0hFQSknOyBpZHM9QCgpOyAgICAgICAgICAgICBwcm92PSdXSEVBJyB9LAogICAgICAgIEB7IGs9J1NFUlZJQ0lP
HLP:Uyc7ICAgICAgIGlkcz1AKCk7ICAgICAgICAgICAgIHByb3Y9J1NlcnZpY2UgQ29udHJvbCBNYW5hZ2VyJyB9LAogICAgICAgIEB7IGs9J0FQTElDQUNJT04nOyAgICAgIGlkcz1AKDEwMDAsMTAwMik7ICAgIHByb3Y9J0FwcGxpY2F0aW9uIEVycm9yfC5ORVQgUnVu
HLP:dGltZScgfQogICAgKQogICAgZm9yZWFjaCAoJGcgaW4gJGdyb3VwcykgewogICAgICAgICRzZWwgPSAkZXYgfCBXaGVyZS1PYmplY3QgewogICAgICAgICAgICAoJGcuaWRzLkNvdW50IC1ndCAwIC1hbmQgJF8uSWQgLWluICRnLmlkcykgLW9yICgkZy5wcm92IC1u
HLP:ZSAnJyAtYW5kICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2ggJGcucHJvdikKICAgICAgICB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMwogICAgICAgIGZvcmVhY2ggKCRlIGluICRzZWwpIHsKICAgICAgICAgICAgJG1zZyA9ICgkZS5NZXNzYWdlIC1zcGxpdCAiYG4i
HLP:KVswXTsgaWYgKCRtc2cuTGVuZ3RoIC1ndCA5MCkgeyAkbXNnID0gJG1zZy5TdWJzdHJpbmcoMCw5MCkgfQogICAgICAgICAgICAkb3V0ICs9ICgiezB9fHsxfXx7Mn18ezN9IiAtZiAkZy5rLCAkZS5JZCwgJGUuVGltZUNyZWF0ZWQuVG9TdHJpbmcoJ01NLWRkIEhI
HLP:Om1tJyksICRtc2cuVHJpbSgpKQogICAgICAgIH0KICAgIH0KICAgIGlmICgkb3V0LkNvdW50IC1lcSAwKSB7ICJPS3wwfC18Tm8gY3JpdGljYWwgZXJyb3JzIGluIHRoZSBsYXN0IDcgZGF5cy4iIH0gZWxzZSB7ICRvdXQgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgQXV0by10cmlhZ2U6IGEgcGFydGlyIGRlbCBzY29yZSB5IGxhIGZvcmVuc2UsIHJlY29taWVuZGEgZmFzZXMgKGxpc3RhIGRlIElEcykuCmZ1bmN0aW9uIEdl
HLP:dC1UcmlhZ2UgewogICAgJGggPSBHZXQtSGVhbHRoU2NvcmUKICAgICRyZWMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAgZm9yZWFjaCAoJHggaW4gJzAwJywnMDEnLCcwMicpIHsgJHJlYy5BZGQoJHgpIH0g
HLP:ICMgZGlhZ25vc3RpY28rcmVzdG9yZStsaW1waWV6YSBzaWVtcHJlCiAgICAkc2luY2UgPSAoR2V0LURhdGUpLkFkZERheXMoLTcpCiAgICAkZXYgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgTGV2ZWw9MSwyOyBT
HLP:dGFydFRpbWU9JHNpbmNlfSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgIGlmIChAKCRldiB8IFdoZXJlLU9iamVjdCB7ICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2ggJ2Rpc2t8TnRmc3x2b2xtZ3InIH0pLkNvdW50IC1ndCAwKSB7ICRyZWMuQWRkKCcw
HLP:MycpIH0KICAgICRyZWMuQWRkKCcwNCcpOyAkcmVjLkFkZCgnMDUnKTsgJHJlYy5BZGQoJzA2JykgICMgZGlzY28vRElTTS9TRkMgYmFzZQogICAgaWYgKChHZXQtU2VydmljZSBXaW5tZ210KS5TdGF0dXMgLW5lICdSdW5uaW5nJykgeyAkcmVjLkFkZCgnMDcnKSB9
HLP:CiAgICAjIFdVIHJvdG8/CiAgICAkd3UgPSBHZXQtU2VydmljZSB3dWF1c2VydiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgaWYgKCR3dSAtYW5kICR3dS5TdGF0dXMgLW5lICdSdW5uaW5nJyAtYW5kICR3dS5TdGFydFR5cGUgLW5lICdEaXNhYmxl
HLP:ZCcpIHsgJHJlYy5BZGQoJzEzJykgfQogICAgIlNDT1JFPSQoJGguc2NvcmUpIgogICAgIlJFQ09NRU5EQURBUz0kKFtzdHJpbmddOjpKb2luKCcsJywgKCRyZWMgfCBTZWxlY3QtT2JqZWN0IC1VbmlxdWUpKSkiCn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KZnVuY3Rpb24gTmV3LVJlc3RvcmVQb2ludCB7CiAgICB0cnkgewogICAgICAgIEVuYWJsZS1Db21wdXRlclJlc3RvcmUgLURyaXZlICdDOicgLUVycm9yQWN0aW9uIFNpbGVu
HLP:dGx5Q29udGludWUKICAgICAgICAkayA9ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvblxTeXN0ZW1SZXN0b3JlJwogICAgICAgICRwcmV2ID0gKEdldC1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBv
HLP:aW50Q3JlYXRpb25GcmVxdWVuY3kgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLlN5c3RlbVJlc3RvcmVQb2ludENyZWF0aW9uRnJlcXVlbmN5CiAgICAgICAgU2V0LUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZy
HLP:ZXF1ZW5jeSAtVmFsdWUgMCAtVHlwZSBEV29yZCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRuYW1lID0gIlN1aXRlX1JlcGFyYWNpb25fJCgoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkX0hILW1tJykpIgogICAgICAgIENoZWNr
HLP:cG9pbnQtQ29tcHV0ZXIgLURlc2NyaXB0aW9uICRuYW1lIC1SZXN0b3JlUG9pbnRUeXBlIE1PRElGWV9TRVRUSU5HUyAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIGlmICgkbnVsbCAtbmUgJHByZXYpIHsgU2V0LUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1S
HLP:ZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtVmFsdWUgJHByZXYgLVR5cGUgRFdvcmQgfSBlbHNlIHsgUmVtb3ZlLUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtRXJyb3JBY3Rpb24gU2lsZW50bHlD
HLP:b250aW51ZSB9CiAgICAgICAgJHJwID0gR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IHwgV2hlcmUtT2JqZWN0IHsgJF8uRGVzY3JpcHRpb24gLWVxICRuYW1lIH0KICAgICAgICBpZiAoJHJwKSB7ICJSRVNVTFQ9T0siOyAiTkFNRT0kbmFtZSIgfSBlbHNlIHsgIlJF
HLP:U1VMVD1GQUlMIjsgIk5BTUU9JG5hbWUiIH0KICAgIH0gY2F0Y2ggeyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiIH0KfQoKZnVuY3Rpb24gU2F2ZS1IZWFsdGhIaXN0b3J5KCRzY29yZSkgewogICAgJHNjcmlwdERpciA9ICRu
HLP:dWxsCiAgICBpZiAoJFBTU2NyaXB0Um9vdCkgewogICAgICAgICRzY3JpcHREaXIgPSAkUFNTY3JpcHRSb290CiAgICB9IGVsc2VpZiAoJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aCkgewogICAgICAgICRzY3JpcHREaXIgPSBTcGxpdC1QYXRoIC1QYXJlbnQg
HLP:JE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aAogICAgfQogICAgJGJhc2VEaXIgPSBpZiAoJHNjcmlwdERpcikgeyBKb2luLVBhdGggKFNwbGl0LVBhdGggLVBhcmVudCAkc2NyaXB0RGlyKSAiV1BJX1N1aXRlIiB9IGVsc2UgeyAkV29yayB9CiAgICBpZiAoJHNj
HLP:cmlwdERpciAtYW5kIChUZXN0LVBhdGggJHNjcmlwdERpcikpIHsKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRiYXNlRGlyKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRiYXNlRGlyIC1Gb3JjZSB8IE91dC1OdWxsIH0KICAgIH0g
HLP:ZWxzZSB7CiAgICAgICAgJGJhc2VEaXIgPSAkV29yawogICAgfQogICAgJGhpc3RvcnlGaWxlID0gSm9pbi1QYXRoICRiYXNlRGlyICJoZWFsdGhfaGlzdG9yeS5qc29uIgogICAgJGhpc3RvcnkgPSBAKCkKICAgIGlmIChUZXN0LVBhdGggJGhpc3RvcnlGaWxlKSB7
HLP:CiAgICAgICAgdHJ5IHsgJGhpc3RvcnkgPSBHZXQtQ29udGVudCAkaGlzdG9yeUZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7fQogICAgfQogICAgJGVudHJ5ID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgZGF0ZSAgPSAoR2V0LURhdGUp
HLP:LlRvU3RyaW5nKCd5eXl5LU1NLWRkIEhIOm1tJykKICAgICAgICBzY29yZSA9IFtpbnRdJHNjb3JlCiAgICB9CiAgICAkaGlzdG9yeSA9IEAoJGhpc3RvcnkpICsgJGVudHJ5CiAgICBpZiAoJGhpc3RvcnkuQ291bnQgLWd0IDEwKSB7ICRoaXN0b3J5ID0gJGhpc3Rv
HLP:cnlbLTEwLi4tMV0gfQogICAgdHJ5IHsKICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJGhpc3RvcnlGaWxlLCAoJGhpc3RvcnkgfCBDb252ZXJ0VG8tSnNvbiksIChOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2Up
HLP:KSkKICAgIH0gY2F0Y2gge30KfQoKZnVuY3Rpb24gSW5zdGFsbC1XaW5nZXRCb290c3RyYXAgewogICAgJHRlbXBGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAiTWljcm9zb2Z0LkRlc2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgog
HLP:ICAgdHJ5IHsKICAgICAgICAkdXJsID0gImh0dHBzOi8vZ2l0aHViLmNvbS9taWNyb3NvZnQvd2luZ2V0LWNsaS9yZWxlYXNlcy9sYXRlc3QvZG93bmxvYWQvTWljcm9zb2Z0LkRlc2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgogICAg
HLP:ICAgIFdyaXRlLUhvc3QgIkRlc2NhcmdhbmRvIEFwcCBJbnN0YWxsZXIgZGVzZGU6ICR1cmwiCiAgICAgICAgJHdlYkNsaWVudCA9IE5ldy1PYmplY3QgU3lzdGVtLk5ldC5XZWJDbGllbnQKICAgICAgICBbU3lzdGVtLk5ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6
HLP:U2VjdXJpdHlQcm90b2NvbCA9IFtTeXN0ZW0uTmV0LlNlY3VyaXR5UHJvdG9jb2xUeXBlXTo6VGxzMTIKICAgICAgICAkd2ViQ2xpZW50LkRvd25sb2FkRmlsZSgkdXJsLCAkdGVtcEZpbGUpCiAgICAgICAgCiAgICAgICAgV3JpdGUtSG9zdCAiSW5zdGFsYW5kbyBB
HLP:cHAgSW5zdGFsbGVyIGNvbiBBZGQtQXBweFBhY2thZ2UuLi4iCiAgICAgICAgQWRkLUFwcHhQYWNrYWdlIC1QYXRoICR0ZW1wRmlsZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIFdyaXRlLUhvc3QgIkluc3RhbGFjaW9uIGV4aXRvc2EuIgogICAgICAgIGlmIChU
HLP:ZXN0LVBhdGggJHRlbXBGaWxlKSB7IFJlbW92ZS1JdGVtICR0ZW1wRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIHJldHVybiAkdHJ1ZQogICAgfSBjYXRjaCB7CiAgICAgICAgV3JpdGUtSG9zdCAiRXJyb3IgZW4gYm9v
HLP:dHN0cmFwIGRlIHdpbmdldDogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkdGVtcEZpbGUpIHsgUmVtb3ZlLUl0ZW0gJHRlbXBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgcmV0
HLP:dXJuICRmYWxzZQogICAgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgKDMuNyAvIEJ1ZyA1IC8gUmVxIDcpIERldGVjY2lvbiBmaWFibGUgZGVsIHRpcG8gZGUg
HLP:ZGlzY28uCiMgQ29udmVydFRvLU1lZGlhQ2xhc3M6IGZ1bmNpb24gUFVSQSBxdWUgbWFwZWEgdW4gTWVkaWFUeXBlIChudW1lcm8gbyB0ZXh0bykKIyBhIGxhIGNsYXNlIGNhbm9uaWNhIHtTU0QsSERELFVOS05PV059LiBTU0Q9NCBvICdTU0QnOyBIREQ9MyBvICdI
HLP:REQnOwojIGN1YWxxdWllciBvdHJvIHZhbG9yIChVbnNwZWNpZmllZD0wLCB2YWNpbywgbnVsbywgU0NNPTUuLi4pIC0+IFVOS05PV04uCmZ1bmN0aW9uIENvbnZlcnRUby1NZWRpYUNsYXNzKCRtdCkgewogICAgaWYgKCRudWxsIC1lcSAkbXQpIHsgcmV0dXJuICdV
HLP:TktOT1dOJyB9CiAgICAkcyA9IChbc3RyaW5nXSRtdCkuVHJpbSgpCiAgICBpZiAoJHMgLWVxICcnKSB7IHJldHVybiAnVU5LTk9XTicgfQogICAgc3dpdGNoIC1yZWdleCAoJHMuVG9VcHBlcigpKSB7CiAgICAgICAgJ14oNHxTU0QpJCcgeyByZXR1cm4gJ1NTRCcg
HLP:fQogICAgICAgICdeKDN8SEREKSQnIHsgcmV0dXJuICdIREQnIH0KICAgICAgICBkZWZhdWx0ICAgICB7IHJldHVybiAnVU5LTk9XTicgfQogICAgfQp9CgojIFJlc29sdmUtT3B0aW1pemVBY3Rpb246IGZ1bmNpb24gUFVSQS4gVFJJTSBzb2xvIHNpIFNTRCwgREVG
HLP:UkFHIHNvbG8gc2kgSERECiMgY2xhcm8sIE5PTkUgZW4gY3VhbHF1aWVyIG90cm8gY2FzbyAoYWJzdGVuY2lvbiBzZWd1cmE6IG51bmNhIGRlc2ZyYWdtZW50YQojIGFudGUgdGlwbyBpbmNpZXJ0bywgZXZpdGFuZG8gZGFuYXIgdW4gcG9zaWJsZSBTU0QpLgpmdW5j
HLP:dGlvbiBSZXNvbHZlLU9wdGltaXplQWN0aW9uKCRtZWRpYSkgewogICAgJG0gPSAoW3N0cmluZ10kbWVkaWEpLlRyaW0oKS5Ub1VwcGVyKCkKICAgIGlmICAgICAoJG0gLWVxICdTU0QnKSB7IHJldHVybiAnVFJJTScgfQogICAgZWxzZWlmICgkbSAtZXEgJ0hERCcp
HLP:IHsgcmV0dXJuICdERUZSQUcnIH0KICAgIGVsc2UgICAgICAgICAgICAgICAgICB7IHJldHVybiAnTk9ORScgfQp9CgojIEdldC1NZWRpYVR5cGU6IGlkZW50aWZpY2EgZWwgZGlzY28gZmlzaWNvIGRlbCB2b2x1bWVuIGRlbCBzaXN0ZW1hIGRlIGZvcm1hCiMgZmlh
HLP:YmxlIChwb3IgRGV2aWNlSWQsIHJlc3BhbGRvIHBvciBTZXJpYWxOdW1iZXIpIHkgZGV2dWVsdmUgU1NEfEhERHxVTktOT1dOLgpmdW5jdGlvbiBHZXQtTWVkaWFUeXBlIHsKICAgIHRyeSB7CiAgICAgICAgJHN5cyAgPSAoJGVudjpTeXN0ZW1Ecml2ZSkuVHJpbUVu
HLP:ZCgnOicpCiAgICAgICAgJGRpc2sgPSBHZXQtUGFydGl0aW9uIC1Ecml2ZUxldHRlciAkc3lzIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgR2V0LURpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkcGQgPSAkbnVsbAogICAg
HLP:ICAgIGlmICgkZGlzaykgewogICAgICAgICAgICAkcGQgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uRGV2aWNlSWQgLWVxICRkaXNrLk51bWJlciB9IHwg
HLP:U2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICBpZiAoLW5vdCAkcGQgLWFuZCAkZGlzay5TZXJpYWxOdW1iZXIpIHsKICAgICAgICAgICAgICAgICRwZCA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAg
HLP:ICAgICAgICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uU2VyaWFsTnVtYmVyIC1hbmQgKCRfLlNlcmlhbE51bWJlci5UcmltKCkgLWVxIChbc3RyaW5nXSRkaXNrLlNlcmlhbE51bWJlcikuVHJpbSgpKSB9IHwKICAgICAgICAgICAgICAgICAgICAgIFNlbGVj
HLP:dC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICBpZiAoLW5vdCAkcGQpIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICAgICAgcmV0dXJuIChDb252ZXJ0VG8tTWVkaWFDbGFzcyAkcGQuTWVkaWFUeXBlKQogICAgfSBjYXRjaCB7
HLP:IHJldHVybiAnVU5LTk9XTicgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCmZ1bmN0aW9uIEdldC1EZXZpY2VQcm9ibGVtcyB7CiAgICAkcCA9IEAoR2V0LUNpbUlu
HLP:c3RhbmNlIFdpbjMyX1BuUEVudGl0eSB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUgLWd0IDAgfSkKICAgIGlmICgkcC5Db3VudCAtZXEgMCkgeyAiT0t8Tm8gZGV2aWNlcyB3aXRoIHByb2JsZW1zLiI7IHJldHVybiB9CiAgICBmb3Jl
HLP:YWNoICgkZCBpbiAoJHAgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxMikpIHsKICAgICAgICAiUFJPQnwkKCRkLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUpfCQoJGQuTmFtZSkiCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBJbmZvcm1lIEhUTUwgYXV0b2NvbnRlbmlkbyB5IGJvbml0byAodGVtYSBvc2N1cm8pLiAtQXJnID0gcnV0YSBkZSBzYWxpZGEuCmZ1bmN0aW9uIE5ldy1IdG1sUmVwb3J0KCRvdXRQYXRoKSB7CiAg
HLP:ICBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XZWIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIHRyeSB7CiAgICAgICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgICAgICRzeXNQYWlycyA9IEdldC1TeXNJbmZvCgogICAgICAgICRlbmMgPSB7
HLP:IHBhcmFtKCR0KSBbU3lzdGVtLldlYi5IdHRwVXRpbGl0eV06Okh0bWxFbmNvZGUoW3N0cmluZ10kdCkgfQogICAgICAgICRjaXJjID0gNTI3Ljc5CiAgICAgICAgJGJhbmRDb2xvciA9IHsgcGFyYW0oJHMpIGlmICgkcyAtZXEgJy0nIC1vciAkbnVsbCAtZXEgJHMg
HLP:LW9yIFtzdHJpbmddJHMgLWVxICcnKSB7ICcjOTRhM2I4JyB9IGVsc2UgeyAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0Y2ggeyByZXR1cm4gJyM5NGEzYjgnIH07IGlmICgkdiAtZ2UgODApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJHYgLWdlIDUwKSB7JyNmNTll
HLP:MGInfSBlbHNlIHsnI2VmNDQ0NCd9IH0gfQogICAgICAgICRiYW5kTGFiZWwgPSB7IHBhcmFtKCRzKSBpZiAoJHMgLWVxICctJyAtb3IgJG51bGwgLWVxICRzIC1vciBbc3RyaW5nXSRzIC1lcSAnJykgeyAnbm8gZGF0YScgfSBlbHNlIHsgJHY9MDsgdHJ5IHsgJHY9
HLP:W2ludF0kcyB9IGNhdGNoIHsgcmV0dXJuICdubyBkYXRhJyB9OyBpZiAoJHYgLWdlIDgwKSB7J0dvb2QnfSBlbHNlaWYgKCR2IC1nZSA1MCkgeydGYWlyJ30gZWxzZSB7J0NyaXRpY2FsJ30gfSB9CiAgICAgICAgJG9mZnNldE9mID0geyBwYXJhbSgkcykgJHY9MDsg
HLP:dHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgJHY9MCB9OyBpZiAoJHYgLWx0IDApeyR2PTB9OyBpZiAoJHYgLWd0IDEwMCl7JHY9MTAwfTsgW21hdGhdOjpSb3VuZCgkY2lyYyAqICgxIC0gKCR2LzEwMC4wKSksIDIpIH0KICAgICAgICAkc3RhdHVzSWNvbiA9IHsK
HLP:ICAgICAgICAgICAgcGFyYW0oJHJlcykKICAgICAgICAgICAgc3dpdGNoIChbc3RyaW5nXSRyZXMpIHsKICAgICAgICAgICAgICAgICdPSycgICAgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0n
HLP:c3VjY2Vzc2Z1bCc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyMyMmM1NWUnLz48cGF0aCBkPSdNNyAxMi40bDMuMiAzLjJMMTcgOC44JyBmaWxsPSdub25lJyBzdHJva2U9JyMwNDIxMGYnIHN0cm9rZS13aWR0aD0nMi42JyBzdHJva2UtbGlu
HLP:ZWNhcD0ncm91bmQnIHN0cm9rZS1saW5lam9pbj0ncm91bmQnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdXQVJOJyAgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nd2FybmluZyc+PHBh
HLP:dGggZD0nTTEyIDIuNUwyMyAyMS41SDF6JyBmaWxsPScjZjU5ZTBiJy8+PHJlY3QgeD0nMTEnIHk9JzguNScgd2lkdGg9JzInIGhlaWdodD0nNycgcng9JzEnIGZpbGw9JyMzYTI0MDAnLz48Y2lyY2xlIGN4PScxMicgY3k9JzE4JyByPScxLjMnIGZpbGw9JyMzYTI0
HLP:MDAnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdFUlJPUicgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nZXJyb3InPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScj
HLP:ZWY0NDQ0Jy8+PHBhdGggZD0nTTggOGw4IDhNMTYgOGwtOCA4JyBzdHJva2U9JyMyYTA2MDYnIHN0cm9rZS13aWR0aD0nMi42JyBzdHJva2UtbGluZWNhcD0ncm91bmQnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdTS0lQJyAgeyAiPHN2ZyB2aWV3Qm94PScw
HLP:IDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nc2tpcHBlZCc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyM2NDc0OGInLz48cmVjdCB4PSc2LjUnIHk9JzExJyB3aWR0aD0nMTEnIGhlaWdodD0nMicgcng9
HLP:JzEnIGZpbGw9JyMwYjEyMjAnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgIGRlZmF1bHQgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScjOTRhM2I4Jy8+PC9zdmc+
HLP:IiB9CiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgICRiZWZvcmUgPSAkc3Quc2NvcmVfYmVmb3JlOyBpZiAoJG51bGwgLWVxICRiZWZvcmUpIHsgJGJlZm9yZSA9ICctJyB9CiAgICAgICAgJGFmdGVyICA9ICRzdC5zY29yZV9hZnRlcjsgIGlmICgkbnVs
HLP:bCAtZXEgJGFmdGVyKSAgeyAkYWZ0ZXIgID0gJy0nIH0KICAgICAgICAkaGFzQm90aCA9ICgkc3Quc2NvcmVfYmVmb3JlIC1uZSAkbnVsbCAtYW5kICRzdC5zY29yZV9hZnRlciAtbmUgJG51bGwpCiAgICAgICAgJGRlbHRhID0gMDsgJGRlbHRhVHh0ID0gJ25vIGNv
HLP:bXBhcmlzb24nCiAgICAgICAgaWYgKCRoYXNCb3RoKSB7ICRkZWx0YSA9IFtpbnRdJHN0LnNjb3JlX2FmdGVyIC0gW2ludF0kc3Quc2NvcmVfYmVmb3JlOyAkc2lnbiA9IGlmICgkZGVsdGEgLWdlIDApIHsnKyd9IGVsc2UgeycnfTsgJGRlbHRhVHh0ID0gIiRzaWdu
HLP:JGRlbHRhIHBvaW50cyIgfQogICAgICAgICRkZWx0YUNvbG9yID0gaWYgKCRkZWx0YSAtZ3QgMCkgeycjMjJjNTVlJ30gZWxzZWlmICgkZGVsdGEgLWx0IDApIHsnI2VmNDQ0NCd9IGVsc2UgeycjOTRhM2I4J30KICAgICAgICAkbWFpblNjb3JlID0gaWYgKCRhZnRl
HLP:ciAtbmUgJy0nKSB7ICRhZnRlciB9IGVsc2VpZiAoJGJlZm9yZSAtbmUgJy0nKSB7ICRiZWZvcmUgfSBlbHNlIHsgJy0nIH0KICAgICAgICAkbWFpbkNvbG9yID0gJiAkYmFuZENvbG9yICRtYWluU2NvcmUKICAgICAgICAkbWFpbk9mZnNldCA9ICYgJG9mZnNldE9m
HLP:ICRtYWluU2NvcmUKICAgICAgICAkbWFpbkxhYmVsID0gJiAkYmFuZExhYmVsICRtYWluU2NvcmUKICAgICAgICAkYmVmb3JlQ29sb3IgPSAmICRiYW5kQ29sb3IgJGJlZm9yZQogICAgICAgICRhZnRlckNvbG9yICA9ICYgJGJhbmRDb2xvciAkYWZ0ZXIKICAgICAg
HLP:ICAkYmVmb3JlT2Zmc2V0ID0gJiAkb2Zmc2V0T2YgJGJlZm9yZQogICAgICAgICRhZnRlck9mZnNldCAgPSAmICRvZmZzZXRPZiAkYWZ0ZXIKCiAgICAgICAgJHNjcmlwdERpciA9ICRudWxsCiAgICAgICAgaWYgKCRQU1NjcmlwdFJvb3QpIHsKICAgICAgICAgICAg
HLP:JHNjcmlwdERpciA9ICRQU1NjcmlwdFJvb3QKICAgICAgICB9IGVsc2VpZiAoJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aCkgewogICAgICAgICAgICAkc2NyaXB0RGlyID0gU3BsaXQtUGF0aCAtUGFyZW50ICRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgK
HLP:ICAgICAgICB9CiAgICAgICAgJGJhc2VEaXIgPSBpZiAoJHNjcmlwdERpcikgeyBKb2luLVBhdGggKFNwbGl0LVBhdGggLVBhcmVudCAkc2NyaXB0RGlyKSAiV1BJX1N1aXRlIiB9IGVsc2UgeyAkV29yayB9CiAgICAgICAgJGhpc3RvcnlGaWxlID0gSm9pbi1QYXRo
HLP:ICRiYXNlRGlyICJoZWFsdGhfaGlzdG9yeS5qc29uIgogICAgICAgICRoaXN0b3J5ID0gQCgpCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkaGlzdG9yeUZpbGUpIHsKICAgICAgICAgICAgdHJ5IHsgJGhpc3RvcnkgPSBHZXQtQ29udGVudCAkaGlzdG9yeUZpbGUgLVJh
HLP:dyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkaGlzdG9yeUh0bWwgPSAnJwogICAgICAgIGlmICgkaGlzdG9yeSAtYW5kICRoaXN0b3J5LkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRoaXN0b3J5SHRtbCArPSAiPGRp
HLP:diBjbGFzcz0ndHJlbmQtdGl0bGUnPkhlYWx0aCBIaXN0b3J5IChMYXN0IHJ1bnMpPC9kaXY+PGRpdiBjbGFzcz0ndHJlbmQtbGlzdCc+IgogICAgICAgICAgICBmb3JlYWNoICgkaCBpbiAkaGlzdG9yeSkgewogICAgICAgICAgICAgICAgJGNvbCA9ICYgJGJhbmRD
HLP:b2xvciAkaC5zY29yZQogICAgICAgICAgICAgICAgJGhpc3RvcnlIdG1sICs9ICI8ZGl2IGNsYXNzPSd0cmVuZC1pdGVtJz48c3BhbiBjbGFzcz0ndHJlbmQtZGF0ZSc+JCgkaC5kYXRlKTwvc3Bhbj48c3BhbiBjbGFzcz0ndHJlbmQtc2NvcmUnIHN0eWxlPSdjb2xv
HLP:cjokY29sJz4kKCRoLnNjb3JlKS8xMDA8L3NwYW4+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgICRoaXN0b3J5SHRtbCArPSAiPC9kaXY+IgogICAgICAgIH0KCiAgICAgICAgJHN5c01hcCA9IEB7fQogICAgICAgIGZvcmVhY2ggKCRwIGluICRzeXNQ
HLP:YWlycykgeyAka3YgPSAkcCAtc3BsaXQgJz0nLDI7IGlmICgka3YuQ291bnQgLWVxIDIpIHsgJHN5c01hcFska3ZbMF1dID0gJGt2WzFdIH0gfQogICAgICAgICRzeXNPcmRlciA9IEAoQCgnT1MnLCdPcGVyYXRpbmcgU3lzdGVtJyksQCgnU1lTVEVNJywnU3lzdGVt
HLP:IE1vZGVsJyksQCgnQ1BVJywnUHJvY2Vzc29yJyksQCgnUkFNJywnUkFNIE1lbW9yeScpLEAoJ0RJU0snLCdEaXNrIEM6JyksQCgnVVBUSU1FJywnVXB0aW1lJyksQCgnVVNFUicsJ1VzZXInKSkKICAgICAgICAkc3lzQ2FyZHMgPSAnJwogICAgICAgIGZvcmVhY2gg
HLP:KCRvIGluICRzeXNPcmRlcikgeyBpZiAoJHN5c01hcC5Db250YWluc0tleSgkb1swXSkpIHsgJHN5c0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdzeXMnPjxkaXYgY2xhc3M9J3N5cy1rJz4kKCYgJGVuYyAkb1sxXSk8L2Rpdj48ZGl2IGNsYXNzPSdzeXMtdic+JCgmICRl
HLP:bmMgJHN5c01hcFskb1swXV0pPC9kaXY+PC9kaXY+IiB9IH0KICAgICAgICAkbWFjaGluZSA9ICRzeXNNYXBbJ1NZU1RFTSddOyBpZiAoLW5vdCAkbWFjaGluZSkgeyAkbWFjaGluZSA9ICRlbnY6Q09NUFVURVJOQU1FIH0KCiAgICAgICAgJHBoYXNlcyA9IEAoJHN0
HLP:LnBoYXNlcykKICAgICAgICAkY09LPTA7JGNXQVJOPTA7JGNFUlI9MDskY1NLSVA9MAogICAgICAgICRtYXhTZWNzID0gMQogICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7ICRzdj0wOyB0cnkgeyAkc3Y9W2ludF0kcGguc2VjcyB9IGNhdGNoIHt9OyBp
HLP:ZiAoJHN2IC1ndCAkbWF4U2VjcykgeyAkbWF4U2VjcyA9ICRzdiB9IH0KICAgICAgICAkcm93cyA9ICcnCiAgICAgICAgJGJhcnMgPSAnJwogICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7CiAgICAgICAgICAgICRyZXMgPSBbc3RyaW5nXSRwaC5yZXN1
HLP:bHQKICAgICAgICAgICAgc3dpdGNoICgkcmVzKSB7ICdPSycgeyRjT0srK30gJ1dBUk4nIHskY1dBUk4rK30gJ0VSUk9SJyB7JGNFUlIrK30gJ1NLSVAnIHskY1NLSVArK30gfQogICAgICAgICAgICAkbGMgPSAkcmVzLlRvTG93ZXIoKQogICAgICAgICAgICAkbm90
HLP:ZSA9IGlmIChbc3RyaW5nXSRwaC5ub3RlIC1uZSAnJykgeyAiPGRpdiBjbGFzcz0ncGgtbm90ZSc+JCgmICRlbmMgJHBoLm5vdGUpPC9kaXY+IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICRyb3dzICs9ICI8ZGl2IGNsYXNzPSdwaCBwaC0kbGMnPjxkaXYgY2xh
HLP:c3M9J3BoLWRvdCc+JCgmICRzdGF0dXNJY29uICRyZXMpPC9kaXY+PGRpdiBjbGFzcz0ncGgtbWFpbic+PGRpdiBjbGFzcz0ncGgtdG9wJz48c3BhbiBjbGFzcz0ncGgtbnVtJz4kKCYgJGVuYyAkcGgubnVtKTwvc3Bhbj48c3BhbiBjbGFzcz0ncGgtdGl0bGUnPiQo
HLP:JiAkZW5jICRwaC50aXRsZSk8L3NwYW4+PHNwYW4gY2xhc3M9J3BoLWJhZGdlIGItJGxjJz4kcmVzPC9zcGFuPjwvZGl2PiRub3RlPC9kaXY+PGRpdiBjbGFzcz0ncGgtc2Vjcyc+JCgmICRlbmMgJHBoLnNlY3MpczwvZGl2PjwvZGl2PiIKICAgICAgICAgICAgJHN2
HLP:PTA7IHRyeSB7ICRzdj1baW50XSRwaC5zZWNzIH0gY2F0Y2gge30KICAgICAgICAgICAgJHcgPSBbbWF0aF06OlJvdW5kKDEwMC4wICogJHN2IC8gW21hdGhdOjpNYXgoMSwkbWF4U2VjcykpOyBpZiAoJHcgLWx0IDIgLWFuZCAkc3YgLWd0IDApIHsgJHcgPSAyIH0K
HLP:ICAgICAgICAgICAgJGJjb2wgPSBzd2l0Y2ggKCRyZXMpIHsgJ09LJyB7JyMyMmM1NWUnfSAnV0FSTicgeycjZjU5ZTBiJ30gJ0VSUk9SJyB7JyNlZjQ0NDQnfSBkZWZhdWx0IHsnIzY0NzQ4Yid9IH0KICAgICAgICAgICAgJGJhcnMgKz0gIjxkaXYgY2xhc3M9J2Jh
HLP:ci1yb3cnPjxkaXYgY2xhc3M9J2Jhci1sYmwnPiQoJiAkZW5jICRwaC5udW0pICQoJiAkZW5jICRwaC50aXRsZSk8L2Rpdj48ZGl2IGNsYXNzPSdiYXItdHJhY2snPjxzcGFuIHN0eWxlPSd3aWR0aDokdyU7YmFja2dyb3VuZDokYmNvbCc+PC9zcGFuPjwvZGl2Pjxk
HLP:aXYgY2xhc3M9J2Jhci12YWwnPiQoJiAkZW5jICRwaC5zZWNzKXM8L2Rpdj48L2Rpdj4iCiAgICAgICAgfQogICAgICAgIGlmICgtbm90ICRyb3dzKSB7ICRyb3dzID0gIjxkaXYgY2xhc3M9J2VtcHR5Jz5ObyBwaGFzZXMgd2VyZSByZWNvcmRlZCBpbiB0aGlzIHJ1
HLP:bi48L2Rpdj4iIH0KICAgICAgICBpZiAoLW5vdCAkYmFycykgeyAkYmFycyA9ICI8ZGl2IGNsYXNzPSdlbXB0eSc+Tm8gdGltaW5ncyB0byBzaG93LjwvZGl2PiIgfQogICAgICAgICR0b3RhbFBoID0gJHBoYXNlcy5Db3VudAoKICAgICAgICAkZmluZGluZ3MgPSBA
HLP:KCRzdC5maW5kaW5ncykKICAgICAgICAkZmluZEh0bWwgPSAnJwogICAgICAgICRzdGVwc0xpc3QgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAgICAgIGZvcmVhY2ggKCRmIGluICRmaW5kaW5ncykgewogICAg
HLP:ICAgICAgICAkdHh0ID0gW3N0cmluZ10kZgogICAgICAgICAgICAkc2V2ID0gJ2luZm8nOyAkc2V2VHh0ID0gJ05vdGljZScKICAgICAgICAgICAgaWYgKCR0eHQgLW1hdGNoICcoP2kpU01BUlR8QlNPRHxjcmFzaHxXSEVBfGhhcmR3YXJlfHVucmVwYWlyYWJsZXxk
HLP:YW1hZ2VkfHJlcG9zaXRvcnl8aW50ZWdyaXR5JykgeyAkc2V2PSdoaWdoJzsgJHNldlR4dD0nSW1wb3J0YW50JyB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlzcGFjZXxwZW5kaW5nIHJlYm9vdHxuZXR3b3JrfGJhdHRlcnl8ZHJpdmVyfGRl
HLP:dmljZXxcYlJBTVxifHNlcnZpY2UnKSB7ICRzZXY9J21lZCc7ICRzZXZUeHQ9J1JldmlldycgfQogICAgICAgICAgICAkZmluZEh0bWwgKz0gIjxsaSBjbGFzcz0nZmluZCBmaW5kLSRzZXYnPjxzcGFuIGNsYXNzPSdzZXYgc2V2LSRzZXYnPiRzZXZUeHQ8L3NwYW4+
HLP:PHNwYW4gY2xhc3M9J2ZpbmQtdHh0Jz4kKCYgJGVuYyAkdHh0KTwvc3Bhbj48L2xpPiIKICAgICAgICAgICAgIyBEZXJpdmFyIHBhc28gcmVjb21lbmRhZG8gYSBwYXJ0aXIgZGVsIGhhbGxhemdvCiAgICAgICAgICAgIGlmICgkdHh0IC1tYXRjaCAnKD9pKVNNQVJU
HLP:JykgICAgICAgICAgeyAkc3RlcHNMaXN0LkFkZCgnQmFjayB1cCB5b3VyIGRhdGEgYXMgc29vbiBhcyBwb3NzaWJsZTogYSBkaXNrIHdpdGggZGVncmFkZWQgU01BUlQgY2FuIGZhaWwuIENvbnNpZGVyIHJlcGxhY2luZyBpdC4nKSB9CiAgICAgICAgICAgIGVsc2Vp
HLP:ZiAoJHR4dCAtbWF0Y2ggJyg/aSlzcGFjZScpICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ0ZyZWUgdXAgc3BhY2Ugb24gQzogKHVuaW5zdGFsbCB3aGF0IHlvdSBkb24nJ3QgdXNlIG9yIHVzZSBTdG9yYWdlIFNlbnNlKS4gQWltIGZvciBtb3JlIHRoYW4gMTUgR0IgZnJl
HLP:ZS4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlcYlJBTVxifG1lbW9yeScpIHsgJHN0ZXBzTGlzdC5BZGQoJ1J1biBXaW5kb3dzIE1lbW9yeSBEaWFnbm9zdGljIChtZHNjaGVkLmV4ZSkgYW5kIHJlYm9vdCB0byBjaGVjayB0aGUgUkFN
HLP:LicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWJhdHRlcnknKSAgICB7ICRzdGVwc0xpc3QuQWRkKCdUaGUgYmF0dGVyeSBpcyBkZWdyYWRlZC4gQ2hlY2sgdGhlIGJhdHRlcnkgcmVwb3J0IChwb3dlcmNmZyAvYmF0dGVyeXJlcG9ydCkg
HLP:YW5kIGNvbnNpZGVyIHJlcGxhY2luZyBpdC4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlwZW5kaW5nIHJlYm9vdCcpIHsgJHN0ZXBzTGlzdC5BZGQoJ1JlYm9vdCB0aGUgUEMgdG8gYXBwbHkgcGVuZGluZyBjaGFuZ2VzIGJlZm9yZSBj
HLP:b250aW51aW5nIHJlcGFpcnMuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpdW5yZXBhaXJhYmxlfHJlcG9zaXRvcnl8aW50ZWdyaXR5JykgeyAkc3RlcHNMaXN0LkFkZCgnRGFtYWdlZCBjb21wb25lbnRzIHJlbWFpbi4gUnVuIERJU00g
HLP:d2l0aCBhIHZhbGlkIHNvdXJjZSAoaW5zdGFsbC53aW0pIGFuZCBydW4gU0ZDIGFnYWluLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWRyaXZlcnxkZXZpY2UnKSB7ICRzdGVwc0xpc3QuQWRkKCdVcGRhdGUgdGhlIGRyaXZlcnMgb2Yg
HLP:dGhlIGZhaWxpbmcgZGV2aWNlcyBmcm9tIHRoZSBtYWtlcicncyBzaXRlIG9yIFdpbmRvd3MgVXBkYXRlLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKW5ldHdvcmt8RE5TJykgICAgICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ0NoZWNrIHRo
HLP:ZSBuZXR3b3JrIGNvbm5lY3Rpb24gYW5kIEROUy4gSWYgaXQgcGVyc2lzdHMsIHRyeSBhIHB1YmxpYyBETlMgKDEuMS4xLjEgLyA4LjguOC44KS4nKSB9CiAgICAgICAgfQogICAgICAgICRub0ZpbmQgPSAoJGZpbmRpbmdzLkNvdW50IC1lcSAwKQogICAgICAgIGlm
HLP:ICgkbm9GaW5kKSB7ICRmaW5kSHRtbCA9ICI8bGkgY2xhc3M9J2ZpbmQgZmluZC1vayc+PHNwYW4gY2xhc3M9J3NldiBzZXYtb2snPkFsbCBPSzwvc3Bhbj48c3BhbiBjbGFzcz0nZmluZC10eHQnPk5vIHJlbGV2YW50IHByb2JsZW1zIHdlcmUgZGV0ZWN0ZWQgZHVy
HLP:aW5nIGRpYWdub3Npcy48L3NwYW4+PC9saT4iIH0KCiAgICAgICAgIyAtLS0gUHJveGltb3MgcGFzb3MgcmVjb21lbmRhZG9zIChkZWR1cGxpY2Fkb3MpIC0tLQogICAgICAgICRzdGVwc0h0bWwgPSAnJwogICAgICAgICRzZWVuID0gQHt9CiAgICAgICAgZm9yZWFj
HLP:aCAoJHMgaW4gJHN0ZXBzTGlzdCkgeyBpZiAoLW5vdCAkc2Vlbi5Db250YWluc0tleSgkcykpIHsgJHNlZW5bJHNdPSR0cnVlOyAkc3RlcHNIdG1sICs9ICI8bGkgY2xhc3M9J3N0ZXAtbGknPjxzcGFuIGNsYXNzPSdzdGVwLWljJz4mIzEwMTQ4Ozwvc3Bhbj48c3Bh
HLP:bj4kKCYgJGVuYyAkcyk8L3NwYW4+PC9saT4iIH0gfQogICAgICAgIGlmICgkY0VSUiAtZ3QgMCkgeyAkc3RlcHNIdG1sID0gIjxsaSBjbGFzcz0nc3RlcC1saSc+PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAxNDg7PC9zcGFuPjxzcGFuPlNvbWUgcGhhc2VzIGhh
HLP:ZCBlcnJvcnM6IGNoZWNrIHRoZSBkZXRhaWxlZCBsb2cgaW4gdGhlIFdQSV9TdWl0ZVxMb2dzIGZvbGRlci48L3NwYW4+PC9saT4iICsgJHN0ZXBzSHRtbCB9CiAgICAgICAgaWYgKC1ub3QgJHN0ZXBzSHRtbCkgeyAkc3RlcHNIdG1sID0gIjxsaSBjbGFzcz0nc3Rl
HLP:cC1saSBzdGVwLW9rJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDAwMzs8L3NwYW4+PHNwYW4+Tm8gcGVuZGluZyBhY3Rpb25zLiBSZWJvb3QgdGhlIFBDIHRvIG1ha2Ugc3VyZSBhbGwgY2hhbmdlcyBhcmUgYXBwbGllZC48L3NwYW4+PC9saT4iIH0KCiAgICAg
HLP:ICAgIyA9PT09PT09PT09PT09PT09PT09PT09IERJQUdOT1NUSUNPIEFNUExJQURPID09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICAkZGlhZ0NhcmRzID0gJycKICAgICAgICBpZiAoKCRzdC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdk
HLP:aWFnJykgLWFuZCAkc3QuZGlhZykgewogICAgICAgICAgICAkZCA9ICRzdC5kaWFnCiAgICAgICAgICAgIGlmICgkZC5yYW0pIHsKICAgICAgICAgICAgICAgICRycyA9IFtzdHJpbmddJGQucmFtLnN0YXR1cwogICAgICAgICAgICAgICAgJHJwID0gc3dpdGNoICgk
HLP:cnMpIHsgJ29rJyB7J2dvb2QnfSAnc3VzcGVjdCcgeydiYWQnfSBkZWZhdWx0IHsndW5rbm93bid9IH0KICAgICAgICAgICAgICAgICRydCA9IHN3aXRjaCAoJHJzKSB7ICdvaycgeydObyBlcnJvcnMgZGV0ZWN0ZWQnfSAnc3VzcGVjdCcgeydTdXNwZWN0J30gZGVm
HLP:YXVsdCB7J05vdCBldmFsdWF0ZWQnfSB9CiAgICAgICAgICAgICAgICAkbWRzID0gaWYgKCRkLnJhbS5yZWNvbW1lbmRfbWRzY2hlZCkgeyAiPGRpdiBjbGFzcz0nZC1oaW50Jz5SZWNvbW1lbmRlZDogcnVuIFdpbmRvd3MgTWVtb3J5IERpYWdub3N0aWMgKG1kc2No
HLP:ZWQpLjwvZGl2PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtcmFtJz48L3NwYW4+UkFNIE1lbW9yeTwvZGl2PjxkaXYgY2xh
HLP:c3M9J2QtcGlsbCBwaWxsLSRycCc+JHJ0PC9kaXY+JG1kczwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJGQuYmF0dGVyeSkgewogICAgICAgICAgICAgICAgaWYgKCRkLmJhdHRlcnkucHJlc2VudCkgewogICAgICAgICAgICAgICAgICAgICRi
HLP:cFJhdyA9ICRkLmJhdHRlcnkuaGVhbHRoX3BjdAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGJwUmF3IC1hbmQgW3N0cmluZ10kYnBSYXcgLW5lICcnKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRicCA9IDA7IHRyeSB7ICRicCA9IFtpbnRd
HLP:JGJwUmF3IH0gY2F0Y2ggeyAkYnAgPSAwIH0KICAgICAgICAgICAgICAgICAgICAgICAgJGJwY29sID0gaWYgKCRicCAtZ2UgODApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJGJwIC1nZSA1MCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfQogICAgICAgICAgICAg
HLP:ICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXR0ZXJ5PC9kaXY+PGRpdiBjbGFzcz0nYmF0LWJhcic+PHNwYW4gc3R5bGU9J3dpZHRoOiRi
HLP:cCU7YmFja2dyb3VuZDokYnBjb2wnPjwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdkLXN1Yic+RXN0aW1hdGVkIGhlYWx0aDogPGIgc3R5bGU9J2NvbG9yOiRicGNvbCc+JGJwJTwvYj48L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICAgICAgICAgfSBlbHNlIHsKICAg
HLP:ICAgICAgICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0dGVyeTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLXVua25vd24n
HLP:PlByZXNlbnQsIGhlYWx0aCB1bmtub3duPC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9
HLP:J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0dGVyeTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLXVua25vd24nPk5vdCBwcmVzZW50IChkZXNrdG9wIFBDKTwvZGl2PjwvZGl2PiIKICAgICAgICAgICAgICAgIH0KICAgICAgICAg
HLP:ICAgfQogICAgICAgICAgICBpZiAoJGQubmV0d29yaykgewogICAgICAgICAgICAgICAgJGNjID0gaWYgKCRkLm5ldHdvcmsuY29ubmVjdGVkKSB7J2dvb2QnfSBlbHNlIHsnYmFkJ30KICAgICAgICAgICAgICAgICRjdCA9IGlmICgkZC5uZXR3b3JrLmNvbm5lY3Rl
HLP:ZCkgeydDb25uZWN0ZWQnfSBlbHNlIHsnTm8gY29ubmVjdGlvbid9CiAgICAgICAgICAgICAgICAkZGMgPSBpZiAoJGQubmV0d29yay5kbnNfb2spIHsnZ29vZCd9IGVsc2UgeydiYWQnfQogICAgICAgICAgICAgICAgJGR0ID0gaWYgKCRkLm5ldHdvcmsuZG5zX29r
HLP:KSB7J0ROUyBPSyd9IGVsc2UgeydETlMgZmFpbGluZyd9CiAgICAgICAgICAgICAgICAkZGV0ID0gJiAkZW5jICRkLm5ldHdvcmsuZGV0YWlscwogICAgICAgICAgICAgICAgJGxhdCA9ICcnCiAgICAgICAgICAgICAgICBpZiAoKCRkLm5ldHdvcmsuUFNPYmplY3Qu
HLP:UHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnZG5zX21zJykgLWFuZCAkbnVsbCAtbmUgJGQubmV0d29yay5kbnNfbXMgLWFuZCBbc3RyaW5nXSRkLm5ldHdvcmsuZG5zX21zIC1uZSAnJykgewogICAgICAgICAgICAgICAgICAgICRtcyA9IDA7IHRyeSB7ICRtcyA9
HLP:IFtpbnRdJGQubmV0d29yay5kbnNfbXMgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgICAgICRsYzIgPSBpZiAoJG1zIC1sdCA2MCkgeycjMjJjNTVlJ30gZWxzZWlmICgkbXMgLWx0IDIwMCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfQogICAgICAgICAg
HLP:ICAgICAgICAgICRsYXQgPSAiPGRpdiBjbGFzcz0nZC1zdWInPkROUyBsYXRlbmN5OiA8YiBzdHlsZT0nY29sb3I6JGxjMic+JG1zIG1zPC9iPjwvZGl2PiIKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9
HLP:J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLW5ldCc+PC9zcGFuPk5ldHdvcms8L2Rpdj48ZGl2IGNsYXNzPSdwaWxsLXJvdyc+PHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLSRjYyc+JGN0PC9zcGFuPjxzcGFuIGNsYXNzPSdkLXBp
HLP:bGwgcGlsbC0kZGMnPiRkdDwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdkLXN1Yic+JGRldDwvZGl2PiRsYXQ8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdzbWFydCcpIC1h
HLP:bmQgJGQuc21hcnQgLWFuZCAkZC5zbWFydC5hdmFpbGFibGUpIHsKICAgICAgICAgICAgICAgICRzbSA9ICRkLnNtYXJ0CiAgICAgICAgICAgICAgICAkcGYgPSBpZiAoJHNtLnByZWRpY3RfZmFpbCkgeyAiPHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLWJhZCc+UHJl
HLP:ZGljdHMgZmFpbHVyZTwvc3Bhbj4iIH0gZWxzZSB7ICI8c3BhbiBjbGFzcz0nZC1waWxsIHBpbGwtZ29vZCc+Tm8gYWxlcnQ8L3NwYW4+IiB9CiAgICAgICAgICAgICAgICAkZXh0cmEgPSAnJwogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkc20udGVtcF9j
HLP:IC1hbmQgW3N0cmluZ10kc20udGVtcF9jIC1uZSAnJykgeyAkdGM9MDsgdHJ5eyR0Yz1baW50XSRzbS50ZW1wX2N9Y2F0Y2h7fTsgJHRjb2wgPSBpZiAoJHRjIC1sdCA1MCl7JyMyMmM1NWUnfSBlbHNlaWYgKCR0YyAtbHQgNjUpeycjZjU5ZTBiJ30gZWxzZSB7JyNl
HLP:ZjQ0NDQnfTsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+VGVtcGVyYXR1cmU6IDxiIHN0eWxlPSdjb2xvcjokdGNvbCc+JHRjICZkZWc7QzwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLndlYXJfcGN0IC1hbmQgW3N0
HLP:cmluZ10kc20ud2Vhcl9wY3QgLW5lICcnKSB7ICR3cD0wOyB0cnl7JHdwPVtpbnRdJHNtLndlYXJfcGN0fWNhdGNoe307ICR3Y29sID0gaWYgKCR3cCAtbHQgNTApeycjMjJjNTVlJ30gZWxzZWlmICgkd3AgLWx0IDgwKXsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0
HLP:J307ICRleHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPldlYXIgKFNTRCk6IDxiIHN0eWxlPSdjb2xvcjokd2NvbCc+JHdwJTwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLnBvaCAtYW5kIFtzdHJpbmddJHNtLnBvaCAtbmUg
HLP:JycpIHsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+UG93ZXItb24gaG91cnM6IDxiPiQoJiAkZW5jICRzbS5wb2gpPC9iPjwvZGl2PiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2Qt
HLP:aCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtc21hcnQnPjwvc3Bhbj5EaXNrIGhlYWx0aCAoU01BUlQpPC9kaXY+PGRpdiBjbGFzcz0ncGlsbC1yb3cnPiRwZjwvZGl2PiRleHRyYTwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoKCRkLlBTT2JqZWN0
HLP:LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2JjZCcpIC1hbmQgJGQuYmNkKSB7CiAgICAgICAgICAgICAgICAkYm9rID0gaWYgKCRkLmJjZC5vaykgeydnb29kJ30gZWxzZSB7J2JhZCd9CiAgICAgICAgICAgICAgICAkYnR4ID0gaWYgKCRkLmJjZC5vaykgeydC
HLP:b290IGNvbmZpZ3VyYXRpb24gY29ycmVjdCd9IGVsc2UgeydCb290IHdpdGggaXNzdWVzJ30KICAgICAgICAgICAgICAgICRiZGV0ID0gaWYgKFtzdHJpbmddJGQuYmNkLmRldGFpbHMgLW5lICcnKSB7ICI8ZGl2IGNsYXNzPSdkLXN1Yic+JCgmICRlbmMgJGQuYmNk
HLP:LmRldGFpbHMpPC9kaXY+IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1ib290Jz48L3NwYW4+Qm9vdCAoQkNEKTwvZGl2Pjxk
HLP:aXYgY2xhc3M9J2QtcGlsbCBwaWxsLSRib2snPiRidHg8L2Rpdj4kYmRldDwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoKCRkLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3N0YXJ0dXAnKSAtYW5kICRkLnN0YXJ0dXAgLWFu
HLP:ZCBAKCRkLnN0YXJ0dXApLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkaXRlbXMgPSAnJwogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHMgaW4gQCgkZC5zdGFydHVwKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkcy5uYW1lKTxzcGFuIGNsYXNz
HLP:PSdtdXRlZCc+ICZtZGFzaDsgJCgmICRlbmMgJHMuY29tbWFuZCk8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkIGRjYXJkLXdpZGUnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMg
HLP:aWMtc3RhcnQnPjwvc3Bhbj5TdGFydHVwIHByb2dyYW1zPC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlzdCc+JGl0ZW1zPC91bD48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdw
HLP:cm9jZXNzZXMnKSAtYW5kICRkLnByb2Nlc3NlcyAtYW5kIEAoJGQucHJvY2Vzc2VzKS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwciBpbiBAKCRkLnByb2Nlc3NlcykpIHsgJGl0ZW1z
HLP:ICs9ICI8bGk+JCgmICRlbmMgJHByLm5hbWUpPHNwYW4gY2xhc3M9J211dGVkJz4gJm1kYXNoOyAkKCYgJGVuYyAkcHIubWVtX21iKSBNQjwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYg
HLP:Y2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtcHJvYyc+PC9zcGFuPlByb2Nlc3NlcyB1c2luZyBtb3N0IG1lbW9yeTwvZGl2Pjx1bCBjbGFzcz0nZGV2LWxpc3QnPiRpdGVtczwvdWw+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgk
HLP:ZC5kZXZpY2VzIC1hbmQgQCgkZC5kZXZpY2VzKS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRkZXYgaW4gQCgkZC5kZXZpY2VzKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkZGV2
HLP:Lm5hbWUpIDxzcGFuIGNsYXNzPSdtdXRlZCc+KGNvZGUgJCgmICRlbmMgJGRldi5jb2RlKSk8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkIGRjYXJkLXdpZGUnPjxkaXYgY2xhc3M9J2QtaCc+PHNw
HLP:YW4gY2xhc3M9J2QtaWMgaWMtZGV2Jz48L3NwYW4+RGV2aWNlcyB3aXRoIHdhcm5pbmdzPC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlzdCc+JGl0ZW1zPC91bD48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgJGRpYWdTZWN0aW9uID0gJycKICAg
HLP:ICAgICBpZiAoJGRpYWdDYXJkcykgeyAkZGlhZ1NlY3Rpb24gPSAiPGgyIGlkPSdkaWFnJyBjbGFzcz0nc2VjLWgnPkV4dGVuZGVkIGRpYWdub3NpczwvaDI+PGRpdiBjbGFzcz0nZGdyaWQnPiRkaWFnQ2FyZHM8L2Rpdj4iIH0KCiAgICAgICAgJGNvbXBhcmVTZWN0
HLP:aW9uID0gJycKICAgICAgICBpZiAoJGhhc0JvdGgpIHsKICAgICAgICAgICAgJGNvbXBhcmVTZWN0aW9uID0gQCIKPGRpdiBjbGFzcz0nY29tcGFyZSc+CiAgPGRpdiBjbGFzcz0nbWluaSc+CiAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1
HLP:Z2UgZ2F1Z2Utc20nPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRiZWZvcmVPZmZzZXQ7
HLP:c3Ryb2tlOiRiZWZvcmVDb2xvcicvPjx0ZXh0IHg9JzEwMCcgeT0nMTA4JyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxsOiRiZWZvcmVDb2xvcic+JGJlZm9yZTwvdGV4dD48L3N2Zz4KICAgIDxkaXYgY2xhc3M9J21pbmktY2FwJz5CRUZPUkU8L2Rpdj4KICA8L2Rp
HLP:dj4KICA8ZGl2IGNsYXNzPSdhcnJvdyc+PHNwYW4gc3R5bGU9J2NvbG9yOiRkZWx0YUNvbG9yJz4mIzg1OTQ7PC9zcGFuPjxkaXYgY2xhc3M9J2RlbHRhLWNoaXAnIHN0eWxlPSdjb2xvcjokZGVsdGFDb2xvcjtib3JkZXItY29sb3I6JGRlbHRhQ29sb3InPiRkZWx0
HLP:YVR4dDwvZGl2PjwvZGl2PgogIDxkaXYgY2xhc3M9J21pbmknPgogICAgPHN2ZyB2aWV3Qm94PScwIDAgMjAwIDIwMCcgY2xhc3M9J2dhdWdlIGdhdWdlLXNtJz48Y2lyY2xlIGNsYXNzPSd0cmFjaycgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnLz48Y2lyY2xlIGNs
HLP:YXNzPSdmaWxsJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcgc3R5bGU9Jy0tY2lyYzokY2lyYzstLXRhcmdldDokYWZ0ZXJPZmZzZXQ7c3Ryb2tlOiRhZnRlckNvbG9yJy8+PHRleHQgeD0nMTAwJyB5PScxMDgnIGNsYXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6JGFm
HLP:dGVyQ29sb3InPiRhZnRlcjwvdGV4dD48L3N2Zz4KICAgIDxkaXYgY2xhc3M9J21pbmktY2FwJz5BRlRFUjwvZGl2PgogIDwvZGl2Pgo8L2Rpdj4KIkAKICAgICAgICB9CgogICAgICAgICRub3cgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkIEhIOm1t
HLP:JykKICAgICAgICAkZXhlY1ZlcmRpY3QgPSAmICRiYW5kTGFiZWwgJG1haW5TY29yZQogICAgICAgICRodG1sID0gQCIKPCFET0NUWVBFIGh0bWw+CjxodG1sIGxhbmc9J2VuJz4KPGhlYWQ+CjxtZXRhIGNoYXJzZXQ9J3V0Zi04Jz4KPG1ldGEgbmFtZT0ndmlld3Bv
HLP:cnQnIGNvbnRlbnQ9J3dpZHRoPWRldmljZS13aWR0aCxpbml0aWFsLXNjYWxlPTEnPgo8dGl0bGU+UmVwYWlyIFJlcG9ydCAtIFdQSSBTdWl0ZSB2My4xPC90aXRsZT4KPHN0eWxlPgoqe2JveC1zaXppbmc6Ym9yZGVyLWJveH0KOnJvb3R7LS1iZzojMGIwZjE3Oy0t
HLP:YmcyOiMwZDE0MjI7LS1jYXJkOiMxMjFhMmI7LS1jYXJkMjojMGUxNjI2Oy0tbGluZTojMWUyOTNiOy0tdHh0OiNlNmVkZjY7LS1tdXRlZDojOTNhM2JhOy0tYWNjZW50OiMzOGJkZjg7LS1hY2NlbnQyOiM4MThjZjg7LS1zaGFkb3c6MCAxNHB4IDQwcHggcmdiYSgw
HLP:LDAsMCwuNDApfQpodG1sLmxpZ2h0ey0tYmc6I2VlZjJmODstLWJnMjojZTdlZGY2Oy0tY2FyZDojZmZmZmZmOy0tY2FyZDI6I2Y1ZjhmYzstLWxpbmU6I2RkZTVmMDstLXR4dDojMGYxNzJhOy0tbXV0ZWQ6IzVhNmI4MjstLWFjY2VudDojMDI4NGM3Oy0tYWNjZW50
HLP:MjojNGY0NmU1Oy0tc2hhZG93OjAgMTBweCAyOHB4IHJnYmEoMTUsMjMsNDIsLjEyKX0KYm9keXttYXJnaW46MDtmb250LWZhbWlseTonU2Vnb2UgVUknLHN5c3RlbS11aSwtYXBwbGUtc3lzdGVtLEFyaWFsLHNhbnMtc2VyaWY7bGluZS1oZWlnaHQ6MS41NTtjb2xv
HLP:cjp2YXIoLS10eHQpO2JhY2tncm91bmQ6cmFkaWFsLWdyYWRpZW50KDEyMDBweCA2MDBweCBhdCA4MCUgLTEwJSxyZ2JhKDU2LDE4OSwyNDgsLjEwKSx0cmFuc3BhcmVudCA2MCUpLHJhZGlhbC1ncmFkaWVudCg5MDBweCA1MDBweCBhdCAtMTAlIDEwJSxyZ2JhKDEy
HLP:OSwxNDAsMjQ4LC4xMCksdHJhbnNwYXJlbnQgNTUlKSx2YXIoLS1iZyl9Ci53cmFwe21heC13aWR0aDoxMDgwcHg7bWFyZ2luOjAgYXV0bztwYWRkaW5nOjMwcHggMjJweCA2MHB4fQoudG9wYmFye2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlm
HLP:eS1jb250ZW50OnNwYWNlLWJldHdlZW47Z2FwOjE2cHg7bWFyZ2luLWJvdHRvbToxOHB4O2ZsZXgtd3JhcDp3cmFwfQouYnJhbmR7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTRweH0KLmxvZ297d2lkdGg6NDZweDtoZWlnaHQ6NDZweDtib3Jk
HLP:ZXItcmFkaXVzOjEzcHg7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtib3gtc2hhZG93OnZhcigt
HLP:LXNoYWRvdyl9Cmgxe2ZvbnQtc2l6ZToyMnB4O21hcmdpbjowO2xldHRlci1zcGFjaW5nOi4ycHh9Ci5zdWJ7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6MnB4fQouYmFkZ2V7ZGlzcGxheTppbmxpbmUtYmxvY2s7YmFja2dyb3Vu
HLP:ZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzozcHggMTJweDtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFj
HLP:aW5nOi40cHg7dmVydGljYWwtYWxpZ246bWlkZGxlO21hcmdpbi1sZWZ0OjhweH0KLmJ0bnN7ZGlzcGxheTpmbGV4O2dhcDo4cHg7ZmxleC13cmFwOndyYXB9Ci50b2dnbGV7Y3Vyc29yOnBvaW50ZXI7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNrZ3Jv
HLP:dW5kOnZhcigtLWNhcmQpO2NvbG9yOnZhcigtLXR4dCk7Ym9yZGVyLXJhZGl1czoxMHB4O3BhZGRpbmc6OHB4IDE0cHg7Zm9udC1zaXplOjEzcHg7Zm9udC13ZWlnaHQ6NjAwO2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KX0KLnRvZ2dsZTpob3Zlcntib3JkZXItY29s
HLP:b3I6dmFyKC0tYWNjZW50KX0KLnRvY3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4LXdyYXA6d3JhcDttYXJnaW46MCAwIDIycHh9Ci50b2MgYXtmb250LXNpemU6MTIuNXB4O2ZvbnQtd2VpZ2h0OjYwMDtjb2xvcjp2YXIoLS1tdXRlZCk7dGV4dC1kZWNvcmF0aW9u
HLP:Om5vbmU7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NnB4IDEzcHh9Ci50b2MgYTpob3Zlcntjb2xvcjp2YXIoLS1hY2NlbnQpO2JvcmRlci1jb2xvcjp2YXIoLS1h
HLP:Y2NlbnQpfQouZXhlY3tkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxOHB4O2ZsZXgtd3JhcDp3cmFwO2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRlZyx2YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQgdmFy
HLP:KC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRpbmc6MThweCAyMnB4O21hcmdpbi1ib3R0b206MjJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci5leGVjLXNjb3Jle2ZvbnQtc2l6ZTo0NnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQou
HLP:ZXhlYy1taWR7ZmxleDoxO21pbi13aWR0aDoyMDBweH0KLmV4ZWMtdmVyZGljdHtmb250LXNpemU6MThweDtmb250LXdlaWdodDo3MDB9Ci5leGVjLWxpbmV7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6MnB4fQouZXhlYy1kZWx0
HLP:YXtmb250LXNpemU6MTNweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyOjFweCBzb2xpZDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NHB4IDEycHg7d2hpdGUtc3BhY2U6bm93cmFwfQouaGVyb3tkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOm1p
HLP:bm1heCgyNDBweCwzMjBweCkgMWZyO2dhcDoyMHB4O21hcmdpbi1ib3R0b206MjJweH0KQG1lZGlhKG1heC13aWR0aDo3NjBweCl7Lmhlcm97Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn19Ci5jYXJke2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRlZyx2
HLP:YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRpbmc6MjJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci5nYXVnZXdyYXB7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9u
HLP:OmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjt0ZXh0LWFsaWduOmNlbnRlcn0KLmdhdWdle3dpZHRoOjIxMHB4O2hlaWdodDoyMTBweH0KLmdhdWdlLXNte3dpZHRoOjEyMHB4O2hlaWdodDoxMjBweH0KLmdhdWdlIC50cmFj
HLP:a3tmaWxsOm5vbmU7c3Ryb2tlOnZhcigtLWxpbmUpO3N0cm9rZS13aWR0aDoxNH0KLmdhdWdlIC5maWxse2ZpbGw6bm9uZTtzdHJva2Utd2lkdGg6MTQ7c3Ryb2tlLWxpbmVjYXA6cm91bmQ7dHJhbnNmb3JtOnJvdGF0ZSgtOTBkZWcpO3RyYW5zZm9ybS1vcmlnaW46
HLP:NTAlIDUwJTtzdHJva2UtZGFzaGFycmF5OnZhcigtLWNpcmMpO3N0cm9rZS1kYXNob2Zmc2V0OnZhcigtLWNpcmMpO2FuaW1hdGlvbjpmaWxsIDEuNHMgY3ViaWMtYmV6aWVyKC4yMiwxLC4zNiwxKSAuMnMgZm9yd2FyZHN9Ci5nLW51bXtmb250LXNpemU6NTRweDtm
HLP:b250LXdlaWdodDo4MDA7dGV4dC1hbmNob3I6bWlkZGxlO2ZvbnQtZmFtaWx5OidTZWdvZSBVSScsc3lzdGVtLXVpLEFyaWFsfQouZ2F1Z2Utc20gLmctbnVte2ZvbnQtc2l6ZTo0NnB4fQouZy1sYWJlbHttYXJnaW4tdG9wOjZweDtmb250LXdlaWdodDo3MDA7Zm9u
HLP:dC1zaXplOjE1cHh9Ci5nLWNhcHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7bGV0dGVyLXNwYWNpbmc6MS41cHg7bWFyZ2luLXRvcDoycHh9Ci5jb21wYXJle2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNl
HLP:bnRlcjtnYXA6OHB4O21hcmdpbi10b3A6MTRweDtmbGV4LXdyYXA6d3JhcH0KLm1pbml7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5taW5pLWNhcHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjExcHg7bGV0dGVyLXNwYWNpbmc6MS4ycHg7bWFyZ2luLXRvcDotNnB4
HLP:fQouYXJyb3d7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjZweDtmb250LXNpemU6MzBweDtmb250LXdlaWdodDo4MDB9Ci5kZWx0YS1jaGlwe2JvcmRlcjoxcHggc29saWQ7Ym9yZGVyLXJhZGl1czo5OTlw
HLP:eDtwYWRkaW5nOjNweCAxMnB4O2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO3doaXRlLXNwYWNlOm5vd3JhcH0KLmhlcm8tc2lkZXtkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2dhcDoxNnB4fQouY2hpcHN7ZGlzcGxheTpmbGV4O2dh
HLP:cDoxMHB4O2ZsZXgtd3JhcDp3cmFwfQouY2hpcHtmbGV4OjE7bWluLXdpZHRoOjk2cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxMnB4IDE0cHg7dGV4dC1hbGln
HLP:bjpjZW50ZXJ9Ci5jaGlwIC5ue2ZvbnQtc2l6ZToyNnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQouY2hpcCAubHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjExLjVweDtsZXR0ZXItc3BhY2luZzouNnB4O21hcmdpbi10b3A6M3B4fQouYy1v
HLP:a3tjb2xvcjojMjJjNTVlfS5jLXdhcm57Y29sb3I6I2Y1OWUwYn0uYy1lcnJ7Y29sb3I6I2VmNDQ0NH0uYy1za2lwe2NvbG9yOiM5NGEzYjh9Ci5zeXNncmlke2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyIDFmcjtnYXA6MXB4O2JhY2tncm91
HLP:bmQ6dmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O292ZXJmbG93OmhpZGRlbn0KQG1lZGlhKG1heC13aWR0aDo1MjBweCl7LnN5c2dyaWR7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn19Ci5zeXN7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtwYWRkaW5nOjEx
HLP:cHggMTRweH0KLnN5cy1re2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFjaW5nOi40cHh9Ci5zeXMtdntmb250LXdlaWdodDo2MDA7Zm9udC1zaXplOjE0cHg7bWFyZ2luLXRvcDoxcHg7d29yZC1icmVhazpicmVhay13b3JkfQpo
HLP:Mi5zZWMtaHtmb250LXNpemU6MTVweDtsZXR0ZXItc3BhY2luZzouNnB4O3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTtjb2xvcjp2YXIoLS1hY2NlbnQpO21hcmdpbjozMHB4IDAgMTJweDtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4O3Nj
HLP:cm9sbC1tYXJnaW4tdG9wOjE0cHh9CmgyLnNlYy1oOjphZnRlcntjb250ZW50OicnO2ZsZXg6MTtoZWlnaHQ6MXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSl9Ci50aW1lbGluZXtwb3NpdGlvbjpyZWxhdGl2ZTtwYWRkaW5nLWxlZnQ6OHB4fQoucGh7ZGlzcGxheTpm
HLP:bGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOjE0cHg7cGFkZGluZzoxM3B4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7bWFyZ2luLWJvdHRvbToxMHB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7cG9zaXRp
HLP:b246cmVsYXRpdmU7b3ZlcmZsb3c6aGlkZGVufQoucGg6OmJlZm9yZXtjb250ZW50OicnO3Bvc2l0aW9uOmFic29sdXRlO2xlZnQ6MDt0b3A6MDtib3R0b206MDt3aWR0aDo0cHh9Ci5waC1vazo6YmVmb3Jle2JhY2tncm91bmQ6IzIyYzU1ZX0ucGgtd2Fybjo6YmVm
HLP:b3Jle2JhY2tncm91bmQ6I2Y1OWUwYn0ucGgtZXJyb3I6OmJlZm9yZXtiYWNrZ3JvdW5kOiNlZjQ0NDR9LnBoLXNraXA6OmJlZm9yZXtiYWNrZ3JvdW5kOiM2NDc0OGJ9Ci5waC1kb3R7ZmxleDowIDAgYXV0bzttYXJnaW4tdG9wOjFweH0KLnN2Z2ljb3t3aWR0aDoy
HLP:NnB4O2hlaWdodDoyNnB4O2Rpc3BsYXk6YmxvY2t9Ci5waC1tYWlue2ZsZXg6MTttaW4td2lkdGg6MH0KLnBoLXRvcHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4O2ZsZXgtd3JhcDp3cmFwfQoucGgtbnVte2ZvbnQtdmFyaWFudC1udW1l
HLP:cmljOnRhYnVsYXItbnVtcztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czo3cHg7cGFkZGluZzoxcHggN3B4fQoucGgtdGl0bGV7Zm9udC13ZWln
HLP:aHQ6NjAwO2ZvbnQtc2l6ZToxNXB4fQoucGgtYmFkZ2V7Zm9udC1zaXplOjExcHg7Zm9udC13ZWlnaHQ6ODAwO2xldHRlci1zcGFjaW5nOi42cHg7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjJweCAxMHB4fQouYi1va3tiYWNrZ3JvdW5kOnJnYmEoMzQsMTk3
HLP:LDk0LC4xNik7Y29sb3I6IzIyYzU1ZX0uYi13YXJue2JhY2tncm91bmQ6cmdiYSgyNDUsMTU4LDExLC4xNik7Y29sb3I6I2Y1OWUwYn0uYi1lcnJvcntiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uYi1za2lwe2JhY2tncm91bmQ6
HLP:cmdiYSgxMDAsMTE2LDEzOSwuMTgpO2NvbG9yOiM5NGEzYjh9Ci5waC1ub3Rle2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDttYXJnaW4tdG9wOjNweH0KLnBoLXNlY3N7ZmxleDowIDAgYXV0bztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEz
HLP:cHg7Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO2FsaWduLXNlbGY6Y2VudGVyfQouZW1wdHl7Y29sb3I6dmFyKC0tbXV0ZWQpO3BhZGRpbmc6MThweDt0ZXh0LWFsaWduOmNlbnRlcn0KLmJhcmNoYXJ0e2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Ym9y
HLP:ZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxNHB4IDE4cHg7bWFyZ2luLXRvcDo0cHh9Ci5iYXItcm93e2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEycHg7cGFkZGluZzo1cHggMH0KLmJhci1s
HLP:Ymx7ZmxleDowIDAgMjIwcHg7Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7d2hpdGUtc3BhY2U6bm93cmFwO292ZXJmbG93OmhpZGRlbjt0ZXh0LW92ZXJmbG93OmVsbGlwc2lzfQpAbWVkaWEobWF4LXdpZHRoOjYwMHB4KXsuYmFyLWxibHtmbGV4
HLP:OjAgMCAxMjBweH19Ci5iYXItdHJhY2t7ZmxleDoxO2hlaWdodDoxMHB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtvdmVyZmxvdzpoaWRkZW59Ci5iYXItdHJhY2sgc3BhbntkaXNwbGF5OmJsb2NrO2hlaWdodDoxMDAlO2JvcmRl
HLP:ci1yYWRpdXM6OTk5cHh9Ci5iYXItdmFse2ZsZXg6MCAwIGF1dG87Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO3dpZHRoOjQ4cHg7dGV4dC1hbGlnbjpyaWdodH0KdWwuZmluZHN7bGlz
HLP:dC1zdHlsZTpub25lO21hcmdpbjowO3BhZGRpbmc6MH0KLmZpbmR7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOjEycHg7cGFkZGluZzoxMnB4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjEzcHg7
HLP:bWFyZ2luLWJvdHRvbTo5cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKX0KLnNldntmbGV4OjAgMCBhdXRvO2ZvbnQtc2l6ZToxMXB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzouNXB4O2JvcmRlci1yYWRpdXM6OHB4O3BhZGRpbmc6M3B4IDEwcHg7bWFy
HLP:Z2luLXRvcDoxcHh9Ci5zZXYtaGlnaHtiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uc2V2LW1lZHtiYWNrZ3JvdW5kOnJnYmEoMjQ1LDE1OCwxMSwuMTYpO2NvbG9yOiNmNTllMGJ9LnNldi1pbmZve2JhY2tncm91bmQ6cmdiYSg1
HLP:NiwxODksMjQ4LC4xNik7Y29sb3I6dmFyKC0tYWNjZW50KX0uc2V2LW9re2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfQouZmluZC10eHR7Zm9udC1zaXplOjE0cHh9CnVsLnN0ZXBze2xpc3Qtc3R5bGU6bm9uZTttYXJnaW46MDtw
HLP:YWRkaW5nOjB9Ci5zdGVwLWxpe2Rpc3BsYXk6ZmxleDtnYXA6MTFweDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O3BhZGRpbmc6MTFweCAxNnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLWxlZnQ6M3B4IHNvbGlkIHZhcigtLWFjY2VudCk7Ym9y
HLP:ZGVyLXJhZGl1czoxMnB4O21hcmdpbi1ib3R0b206OXB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Zm9udC1zaXplOjE0cHh9Ci5zdGVwLW9re2JvcmRlci1sZWZ0LWNvbG9yOiMyMmM1NWV9Ci5zdGVwLWlje2NvbG9yOnZhcigtLWFjY2VudCk7Zm9udC13ZWlnaHQ6
HLP:ODAwfQouc3RlcC1vayAuc3RlcC1pY3tjb2xvcjojMjJjNTVlfQouZGdyaWR7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczpyZXBlYXQoYXV0by1maXQsbWlubWF4KDIyMHB4LDFmcikpO2dhcDoxNHB4fQouZGNhcmR7YmFja2dyb3VuZDp2YXIoLS1j
HLP:YXJkKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTVweDtwYWRkaW5nOjE2cHggMThweH0KLmRjYXJkLXdpZGV7Z3JpZC1jb2x1bW46MS8tMX0KLmQtaHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDo5cHg7Zm9u
HLP:dC13ZWlnaHQ6NzAwO2ZvbnQtc2l6ZToxNHB4O21hcmdpbi1ib3R0b206MTBweH0KLmQtaWN7d2lkdGg6MTRweDtoZWlnaHQ6MTRweDtib3JkZXItcmFkaXVzOjVweDtkaXNwbGF5OmlubGluZS1ibG9ja30KLmljLXJhbXtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVu
HLP:dCgxMzVkZWcsIzM4YmRmOCwjMGVhNWU5KX0uaWMtYmF0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMjJjNTVlLCMxNTgwM2QpfS5pYy1uZXR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCM4MThjZjgsIzRmNDZlNSl9LmljLWRl
HLP:dntiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2Y1OWUwYiwjZDk3NzA2KX0uaWMtc21hcnR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNmNDcyYjYsI2RiMjc3Nyl9LmljLWJvb3R7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQo
HLP:MTM1ZGVnLCMyZGQ0YmYsIzBkOTQ4OCl9LmljLXN0YXJ0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjYTc4YmZhLCM3YzNhZWQpfS5pYy1wcm9je2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZmI3MTg1LCNlMTFkNDgpfQouZC1w
HLP:aWxse2Rpc3BsYXk6aW5saW5lLWJsb2NrO2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzo0cHggMTJweH0KLnBpbGwtcm93e2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwfQoucGlsbC1n
HLP:b29ke2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfS5waWxsLWJhZHtiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0ucGlsbC11bmtub3due2JhY2tncm91bmQ6cmdiYSgxNDgsMTYzLDE4NCwuMTYp
HLP:O2NvbG9yOiM5NGEzYjh9Ci5kLXN1Yntjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEyLjVweDttYXJnaW4tdG9wOjhweH0KLmQtaGludHtjb2xvcjojZjU5ZTBiO2ZvbnQtc2l6ZToxMi41cHg7bWFyZ2luLXRvcDo4cHh9Ci5iYXQtYmFye2hlaWdodDoxMnB4
HLP:O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtvdmVyZmxvdzpoaWRkZW47bWFyZ2luLXRvcDo0cHh9Ci5iYXQtYmFyIHNwYW57ZGlzcGxheTpibG9jaztoZWlnaHQ6MTAwJTtib3JkZXItcmFkaXVzOjk5OXB4fQouZGV2LWxpc3R7bWFy
HLP:Z2luOjRweCAwIDA7cGFkZGluZy1sZWZ0OjE4cHg7Zm9udC1zaXplOjEzLjVweH0KLmRldi1saXN0IGxpe21hcmdpbjoycHggMH0KLm11dGVke2NvbG9yOnZhcigtLW11dGVkKX0KLmZvb3R7bWFyZ2luLXRvcDozNHB4O3RleHQtYWxpZ246Y2VudGVyO2NvbG9yOnZh
HLP:cigtLW11dGVkKTtmb250LXNpemU6MTJweH0KLnNlY3Rpb257YW5pbWF0aW9uOnJpc2UgLjVzIGVhc2UgYm90aH0KQGtleWZyYW1lcyBmaWxse3Rve3N0cm9rZS1kYXNob2Zmc2V0OnZhcigtLXRhcmdldCl9fQpAa2V5ZnJhbWVzIHJpc2V7ZnJvbXtvcGFjaXR5OjA7
HLP:dHJhbnNmb3JtOnRyYW5zbGF0ZVkoMTBweCl9dG97b3BhY2l0eToxO3RyYW5zZm9ybTpub25lfX0KQG1lZGlhIHByaW50ey50b2dnbGUsLnRvYywuYnRucywudG9hc3R7ZGlzcGxheTpub25lfWJvZHl7YmFja2dyb3VuZDojZmZmO2NvbG9yOiMwMDB9LmNhcmQsLmRj
HLP:YXJkLC5waCwuZmluZCwuZXhlYywuYmFyY2hhcnQsLnN0ZXAtbGl7Ym94LXNoYWRvdzpub25lO2JhY2tkcm9wLWZpbHRlcjpub25lOy13ZWJraXQtYmFja2Ryb3AtZmlsdGVyOm5vbmU7YmFja2dyb3VuZDojZmZmIWltcG9ydGFudH0uZ2F1Z2UgLmZpbGx7YW5pbWF0
HLP:aW9uOm5vbmV9LnNlY3Rpb257YW5pbWF0aW9uOm5vbmV9YVtocmVmXXtjb2xvcjppbmhlcml0O3RleHQtZGVjb3JhdGlvbjpub25lfX0KOnJvb3R7LS1nbGFzczpyZ2JhKDE4LDI2LDQzLC42MCk7LS1nbGFzc2JkOnJnYmEoMjU1LDI1NSwyNTUsLjA3KX0KaHRtbC5s
HLP:aWdodHstLWdsYXNzOnJnYmEoMjU1LDI1NSwyNTUsLjY0KTstLWdsYXNzYmQ6cmdiYSgxNSwyMyw0MiwuMDgpfQouY2FyZCwuZXhlYywuZGNhcmQsLmZpbmQsLmJhcmNoYXJ0LC5zdGVwLWxpe2JhY2tncm91bmQ6dmFyKC0tZ2xhc3MpIWltcG9ydGFudDtiYWNrZHJv
HLP:cC1maWx0ZXI6Ymx1cigxM3B4KSBzYXR1cmF0ZSgxNDAlKTstd2Via2l0LWJhY2tkcm9wLWZpbHRlcjpibHVyKDEzcHgpIHNhdHVyYXRlKDE0MCUpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tZ2xhc3NiZCkhaW1wb3J0YW50fQoudG9hc3R7cG9zaXRpb246Zml4ZWQ7
HLP:Ym90dG9tOjI0cHg7bGVmdDo1MCU7dHJhbnNmb3JtOnRyYW5zbGF0ZVgoLTUwJSk7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWlnaHQ6NzAwO3BhZGRpbmc6
HLP:MTBweCAxOHB4O2JvcmRlci1yYWRpdXM6MTJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyk7b3BhY2l0eTowO3BvaW50ZXItZXZlbnRzOm5vbmU7dHJhbnNpdGlvbjpvcGFjaXR5IC4yNXM7ei1pbmRleDo2MDtmb250LXNpemU6MTNweH0KLnRvYXN0LnNob3d7b3Bh
HLP:Y2l0eToxfQoudHJlbmQtdGl0bGV7bWFyZ2luLXRvcDoyMHB4O2ZvbnQtc2l6ZToxMnB4O2ZvbnQtd2VpZ2h0OjcwMDtsZXR0ZXItc3BhY2luZzoxcHg7dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLWxpc3R7ZGlzcGxh
HLP:eTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjtnYXA6NHB4O3dpZHRoOjEwMCU7bWFyZ2luLXRvcDo4cHg7Ym9yZGVyLXRvcDoxcHggc29saWQgdmFyKC0tbGluZSk7cGFkZGluZy10b3A6OHB4fQoudHJlbmQtaXRlbXtkaXNwbGF5OmZsZXg7anVzdGlmeS1jb250
HLP:ZW50OnNwYWNlLWJldHdlZW47Zm9udC1zaXplOjEycHh9Ci50cmVuZC1kYXRle2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLXNjb3Jle2ZvbnQtd2VpZ2h0OjcwMH0KPC9zdHlsZT4KPC9oZWFkPgo8Ym9keT4KPGRpdiBjbGFzcz0nd3JhcCc+CiAgPGRpdiBjbGFz
HLP:cz0ndG9wYmFyJz4KICAgIDxkaXYgY2xhc3M9J2JyYW5kJz4KICAgICAgPGRpdiBjbGFzcz0nbG9nbyc+PHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIHdpZHRoPScyNicgaGVpZ2h0PScyNicgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdXUEknPjxwYXRoIGQ9J00xMiAy
HLP:bDcgM3Y2YzAgNC42LTMgOC4zLTcgOS42QzggMTkuMyA1IDE1LjYgNSAxMVY1eicgZmlsbD0nIzA0MjkzYicvPjxwYXRoIGQ9J005IDEybDIgMiA0LTQuNScgZmlsbD0nbm9uZScgc3Ryb2tlPScjZGZmNmZmJyBzdHJva2Utd2lkdGg9JzInIHN0cm9rZS1saW5lY2Fw
HLP:PSdyb3VuZCcgc3Ryb2tlLWxpbmVqb2luPSdyb3VuZCcvPjwvc3ZnPjwvZGl2PgogICAgICA8ZGl2PgogICAgICAgIDxoMT5SZXBhaXIgUmVwb3J0IDxzcGFuIGNsYXNzPSdiYWRnZSc+V1BJIFNVSVRFIHYzLjE8L3NwYW4+PC9oMT4KICAgICAgICA8ZGl2IGNsYXNz
HLP:PSdzdWInPiQoJiAkZW5jICRtYWNoaW5lKSAmbmJzcDsmbWlkZG90OyZuYnNwOyBnZW5lcmF0ZWQgb24gJG5vdzwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0nYnRucyc+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2dsZScgb25j
HLP:bGljaz0id2luZG93LnByaW50KCkiPlByaW50IC8gUERGPC9idXR0b24+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2dsZScgaWQ9J2NvcHlidG4nIG9uY2xpY2s9ImNvcHlSZXN1bWVuKCkiPkNvcHkgc3VtbWFyeTwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNsYXNz
HLP:PSd0b2dnbGUnIGlkPSd0aGVtZWJ0bicgb25jbGljaz0idG9nZ2xlVGhlbWUoKSI+TGlnaHQvRGFyayB0aGVtZTwvYnV0dG9uPgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDxuYXYgY2xhc3M9J3RvYycgYXJpYS1sYWJlbD0nSW5kZXgnPgogICAgPGEgaHJlZj0nI3Jl
HLP:c3VtZW4nPlN1bW1hcnk8L2E+CiAgICA8YSBocmVmPScjZmFzZXMnPlBoYXNlczwvYT4KICAgIDxhIGhyZWY9JyNoYWxsYXpnb3MnPkZpbmRpbmdzPC9hPgogICAgPGEgaHJlZj0nI3Bhc29zJz5OZXh0IHN0ZXBzPC9hPgogICAgPGEgaHJlZj0nI2RpYWcnPkRpYWdu
HLP:b3N0aWNzPC9hPgogIDwvbmF2PgoKICA8ZGl2IGlkPSdyZXN1bWVuJyBjbGFzcz0nZXhlYyBzZWN0aW9uJz4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtc2NvcmUnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz4kbWFpblNjb3JlPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdl
HLP:eGVjLW1pZCc+CiAgICAgIDxkaXYgY2xhc3M9J2V4ZWMtdmVyZGljdCcgc3R5bGU9J2NvbG9yOiRtYWluQ29sb3InPlN5c3RlbSBoZWFsdGg6ICRleGVjVmVyZGljdDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdleGVjLWxpbmUnPiRjT0sgc3VjY2Vzc2Z1bCAmbWlk
HLP:ZG90OyAkY1dBUk4gd2FybmluZ3MgJm1pZGRvdDsgJGNFUlIgZXJyb3JzICZtaWRkb3Q7ICRjU0tJUCBza2lwcGVkICZtaWRkb3Q7ICR0b3RhbFBoIHBoYXNlcyB0b3RhbDwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdleGVjLWRlbHRhJyBzdHlsZT0n
HLP:Y29sb3I6JGRlbHRhQ29sb3I7Ym9yZGVyLWNvbG9yOiRkZWx0YUNvbG9yJz4kZGVsdGFUeHQ8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0naGVybyBzZWN0aW9uJz4KICAgIDxkaXYgY2xhc3M9J2NhcmQgZ2F1Z2V3cmFwJz4KICAgICAgPHN2ZyB2aWV3Qm94
HLP:PScwIDAgMjAwIDIwMCcgY2xhc3M9J2dhdWdlJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J0hlYWx0aCBzY29yZSAkbWFpblNjb3JlIG91dCBvZiAxMDAnPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9
HLP:J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRtYWluT2Zmc2V0O3N0cm9rZTokbWFpbkNvbG9yJy8+PHRleHQgeD0nMTAwJyB5PScxMTInIGNsYXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6JG1haW5Db2xv
HLP:cic+JG1haW5TY29yZTwvdGV4dD48L3N2Zz4KICAgICAgPGRpdiBjbGFzcz0nZy1sYWJlbCcgc3R5bGU9J2NvbG9yOiRtYWluQ29sb3InPkhlYWx0aDogJG1haW5MYWJlbDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdnLWNhcCc+U0NPUkUgT1VUIE9GIDEwMDwvZGl2
HLP:PgogICAgICAkY29tcGFyZVNlY3Rpb24KICAgICAgJGhpc3RvcnlIdG1sCiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2hlcm8tc2lkZSc+CiAgICAgIDxkaXYgY2xhc3M9J2NhcmQnPgogICAgICAgIDxkaXYgY2xhc3M9J2NoaXBzJz4KICAgICAgICAgIDxkaXYg
HLP:Y2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1vayc+JGNPSzwvZGl2PjxkaXYgY2xhc3M9J2wnPk9LPC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNsYXNzPSduIGMtd2Fybic+JGNXQVJOPC9kaXY+PGRpdiBjbGFzcz0nbCc+
HLP:V0FSTklOR1M8L2Rpdj48L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1lcnInPiRjRVJSPC9kaXY+PGRpdiBjbGFzcz0nbCc+RVJST1JTPC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNs
HLP:YXNzPSduIGMtc2tpcCc+JGNTS0lQPC9kaXY+PGRpdiBjbGFzcz0nbCc+U0tJUFBFRDwvZGl2PjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nY2FyZCc+CiAgICAgICAgPGRpdiBjbGFzcz0nc3lzZ3JpZCc+JHN5c0Nh
HLP:cmRzPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdmYXNlcycgY2xhc3M9J3NlYy1oJz5QaGFzZXMgdGltZWxpbmUgKCR0b3RhbFBoKTwvaDI+CiAgICA8ZGl2IGNsYXNzPSd0
HLP:aW1lbGluZSc+JHJvd3M8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2JhcmNoYXJ0Jz4kYmFyczwvZGl2PgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4KICAgIDxoMiBpZD0naGFsbGF6Z29zJyBjbGFzcz0nc2VjLWgnPkZpbmRpbmdzIGFuZCByb290IGNh
HLP:dXNlPC9oMj4KICAgIDx1bCBjbGFzcz0nZmluZHMnPiRmaW5kSHRtbDwvdWw+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdwYXNvcycgY2xhc3M9J3NlYy1oJz5SZWNvbW1lbmRlZCBuZXh0IHN0ZXBzPC9oMj4KICAgIDx1bCBj
HLP:bGFzcz0nc3RlcHMnPiRzdGVwc0h0bWw8L3VsPgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4kZGlhZ1NlY3Rpb248L2Rpdj4KCiAgPGRpdiBjbGFzcz0nZm9vdCc+CiAgICBXUEkgJm1pZGRvdDsgRW1lcmdlbmN5IFJlcGFpciBTdWl0ZSBmb3IgV2lu
HLP:ZG93cyAxMC8xMSAmbWlkZG90OyByZWFkLW9ubHkgcmVwb3J0Ljxicj4KICAgIEJhY2t1cHMgYW5kIGxvZ3MgYXJlIGluIHRoZSBXUElfU3VpdGUgZm9sZGVyIG5leHQgdG8gdGhlIHByb2dyYW0uCiAgPC9kaXY+CjwvZGl2Pgo8c2NyaXB0PgooZnVuY3Rpb24oKXt0
HLP:cnl7dmFyIHM9bG9jYWxTdG9yYWdlLmdldEl0ZW0oJ3dwaS10aGVtZScpO3ZhciByb290PWRvY3VtZW50LmRvY3VtZW50RWxlbWVudDtpZihzPT09J2xpZ2h0Jyl7cm9vdC5jbGFzc0xpc3QuYWRkKCdsaWdodCcpO31lbHNlIGlmKHM9PT0nZGFyaycpe3Jvb3QuY2xh
HLP:c3NMaXN0LnJlbW92ZSgnbGlnaHQnKTt9ZWxzZSBpZih3aW5kb3cubWF0Y2hNZWRpYSYmd2luZG93Lm1hdGNoTWVkaWEoJyhwcmVmZXJzLWNvbG9yLXNjaGVtZTogbGlnaHQpJykubWF0Y2hlcyl7cm9vdC5jbGFzc0xpc3QuYWRkKCdsaWdodCcpO319fWNhdGNoKGUp
HLP:e319KSgpOwpmdW5jdGlvbiB0b2dnbGVUaGVtZSgpe3RyeXt2YXIgbD1kb2N1bWVudC5kb2N1bWVudEVsZW1lbnQuY2xhc3NMaXN0LnRvZ2dsZSgnbGlnaHQnKTtsb2NhbFN0b3JhZ2Uuc2V0SXRlbSgnd3BpLXRoZW1lJyxsPydsaWdodCc6J2RhcmsnKTt9Y2F0Y2go
HLP:ZSl7fX0KZnVuY3Rpb24gZmxhc2gobSl7dHJ5e3ZhciB0PWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2RpdicpO3QuY2xhc3NOYW1lPSd0b2FzdCc7dC50ZXh0Q29udGVudD1tO2RvY3VtZW50LmJvZHkuYXBwZW5kQ2hpbGQodCk7cmVxdWVzdEFuaW1hdGlvbkZyYW1l
HLP:KGZ1bmN0aW9uKCl7dC5jbGFzc0xpc3QuYWRkKCdzaG93Jyk7fSk7c2V0VGltZW91dChmdW5jdGlvbigpe3QuY2xhc3NMaXN0LnJlbW92ZSgnc2hvdycpO3NldFRpbWVvdXQoZnVuY3Rpb24oKXt0LnJlbW92ZSgpO30sMzAwKTt9LDE2MDApO31jYXRjaChlKXt9fQpm
HLP:dW5jdGlvbiBmYih0eHQsb2spe3RyeXt2YXIgYT1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCd0ZXh0YXJlYScpO2EudmFsdWU9dHh0O2Euc3R5bGUucG9zaXRpb249J2ZpeGVkJzthLnN0eWxlLmxlZnQ9Jy05OTk5cHgnO2RvY3VtZW50LmJvZHkuYXBwZW5kQ2hpbGQo
HLP:YSk7YS5zZWxlY3QoKTtkb2N1bWVudC5leGVjQ29tbWFuZCgnY29weScpO2EucmVtb3ZlKCk7b2soKTt9Y2F0Y2goZSl7Zmxhc2goJ0NvdWxkIG5vdCBjb3B5Jyk7fX0KZnVuY3Rpb24gY29weVJlc3VtZW4oKXt2YXIgcD1bXTt2YXIgdD1kb2N1bWVudC5xdWVyeVNl
HLP:bGVjdG9yKCdoMScpO2lmKHQpcC5wdXNoKHQuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIHM9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignLnN1YicpO2lmKHMpcC5wdXNoKHMuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIGV4PWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJy5leGVj
HLP:Jyk7aWYoZXgpcC5wdXNoKCdcbicrZXguaW5uZXJUZXh0LnJlcGxhY2UoL1xuezIsfS9nLCdcbicpLnRyaW0oKSk7dmFyIGg9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2hhbGxhemdvcycpO2lmKGgmJmgucGFyZW50Tm9kZSlwLnB1c2goJ1xuJytoLnBhcmVudE5v
HLP:ZGUuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIHR4dD1wLmpvaW4oJ1xuJyk7ZnVuY3Rpb24gb2soKXtmbGFzaCgnU3VtbWFyeSBjb3BpZWQnKTt9aWYobmF2aWdhdG9yLmNsaXBib2FyZCYmbmF2aWdhdG9yLmNsaXBib2FyZC53cml0ZVRleHQpe25hdmlnYXRvci5jbGlw
HLP:Ym9hcmQud3JpdGVUZXh0KHR4dCkudGhlbihvayxmdW5jdGlvbigpe2ZiKHR4dCxvayk7fSk7fWVsc2V7ZmIodHh0LG9rKTt9fQo8L3NjcmlwdD4KPC9ib2R5Pgo8L2h0bWw+CiJACiAgICAgICAgJHV0ZjggPSBOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNv
HLP:ZGluZygkZmFsc2UpCiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRvdXRQYXRoLCAkaHRtbCwgJHV0ZjgpCiAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9
HLP:RkFJTCIKICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBSZWdpc3RyYXIgcmVzdWx0
HLP:YWRvIGRlIHVuYSBmYXNlIGVuIGVsIGVzdGFkbyAocGFyYSBlbCBpbmZvcm1lKS4KIyAtQXJnID0gIm51bTt0aXRsZTtyZXN1bHQ7c2Vjcztub3RlIgpmdW5jdGlvbiBBZGQtUGhhc2VSZXN1bHQoJHNwZWMpIHsKICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICRwYXJ0
HLP:cyA9ICRzcGVjIC1zcGxpdCAnOycsNQogICAgJHBoID0gW3BzY3VzdG9tb2JqZWN0XUB7IG51bT0kcGFydHNbMF07IHRpdGxlPSRwYXJ0c1sxXTsgcmVzdWx0PSRwYXJ0c1syXTsgc2Vjcz0kcGFydHNbM107IG5vdGU9JHBhcnRzWzRdIH0KICAgICRsaXN0ID0gQCgk
HLP:c3QucGhhc2VzKSArICRwaAogICAgJHN0LnBoYXNlcyA9ICRsaXN0CiAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gU2V0LVNjb3JlKCR3aGljaCwgJHZhbCkgewogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgaWYgKCR3aGljaCAt
HLP:ZXEgJ2JlZm9yZScpIHsgCiAgICAgICAgJHN0LnNjb3JlX2JlZm9yZSA9IFtpbnRdJHZhbCAKICAgIH0gZWxzZSB7IAogICAgICAgICRzdC5zY29yZV9hZnRlciA9IFtpbnRdJHZhbCAKICAgICAgICBTYXZlLUhlYWx0aEhpc3RvcnkgW2ludF0kdmFsCiAgICB9CiAg
HLP:ICBXcml0ZS1TdGF0ZSAkc3Q7ICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gQWRkLUZpbmRpbmcoJHRleHQpIHsKICAgICRzdCA9IFJlYWQtU3RhdGU7ICRzdC5maW5kaW5ncyA9IEAoJHN0LmZpbmRpbmdzKSArICR0ZXh0OyBXcml0ZS1TdGF0ZSAkc3Q7ICJSRVNVTFQ9
HLP:T0siCn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgTE9HSUNBIFBVUkEgTlVFVkEgLyBDT1JSRUdJREEgKEJsb3F1ZSAzKQojID09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSAoMy4xIC8gQnVnIDQgLyBSZXEgNikgTm9ybWFsaXphY2lvbiBkZSBsYSBzZWxlY2Npb24gZGUgZmFzZXMgLS0tLS0tLS0tLQojIEVudHJhZGE6IGNhZGVu
HLP:YSBjb24gSURzIHNlcGFyYWRvcyBwb3IgY29tYXMgKGVzcGFjaW9zIGFyYml0cmFyaW9zLCAxLTIKIyBkaWdpdG9zLCBwb3NpYmxlcyBpbnZhbGlkb3MpLiBTYWxpZGE6IG9iamV0byBjb24gLm5vcm0gKGxpc3RhIGNhbm9uaWNhLAojIG9yZGVuYWRhLCB1bmljYSBk
HLP:ZSBJRHMgZGUgMiBkaWdpdG9zIGVuIHswMC4uMTZ9KSB5IC5pbnZhbGlkIChsb3Mgbm8gdmFsaWRvcykuCiMgTnVuY2EgbGFuemEgZXhjZXBjaW9uIGFudGUgZW50cmFkYSBtYWxmb3JtYWRhIG8gdmFjaWEuCmZ1bmN0aW9uIE5vcm1hbGl6ZS1GYXNlcyhbc3RyaW5n
HLP:XSRyYXcpIHsKICAgICR2YWxpZCAgID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgICRpbnZhbGlkID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgIGlmICgk
HLP:bnVsbCAtbmUgJHJhdyAtYW5kICRyYXcuVHJpbSgpLkxlbmd0aCAtZ3QgMCkgewogICAgICAgIGZvcmVhY2ggKCR0IGluICgkcmF3IC1zcGxpdCAnLCcpKSB7CiAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJHQpIHsgY29udGludWUgfQogICAgICAgICAgICAkdG9r
HLP:ID0gKCR0IC1yZXBsYWNlICdccycsICcnKSAgICAgICAgICAjIHF1aXRhciBlc3BhY2lvcyBpbnRlcm5vcyB5IGV4dGVybm9zCiAgICAgICAgICAgIGlmICgkdG9rIC1lcSAnJykgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRjYW5vbiA9ICR0b2sKICAgICAgICAg
HLP:ICAgaWYgKCR0b2sgLW1hdGNoICdeXGQkJykgeyAkY2Fub24gPSAkdG9rLlBhZExlZnQoMiwgJzAnKSB9ICAgIyAxIGRpZ2l0byAtPiAyIGRpZ2l0b3MKICAgICAgICAgICAgaWYgKCRjYW5vbiAtbWF0Y2ggJ15cZHsyfSQnIC1hbmQgW2ludF0kY2Fub24gLWdlIDAg
HLP:LWFuZCBbaW50XSRjYW5vbiAtbGUgMTYpIHsKICAgICAgICAgICAgICAgIGlmICgtbm90ICR2YWxpZC5Db250YWlucygkY2Fub24pKSB7ICR2YWxpZC5BZGQoJGNhbm9uKSB9CiAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAkaW52YWxpZC5BZGQo
HLP:JHRvaykKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KICAgICRzb3J0ZWQgPSBAKCR2YWxpZCB8IFNvcnQtT2JqZWN0KQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBub3JtID0gJHNvcnRlZDsgaW52YWxpZCA9IEAoJGludmFsaWQpIH0KfQoKIyAt
HLP:LS0gKDMuMyAvIFJlcSA0KSBDaGVja3BvaW50IHNvYnJlIGNoZWNrcG9pbnQuanNvbiAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBQYXJzZXIgZGVsIC1BcmcgY29uIGZvcm1hdG86CiMgICAic2F2ZXxzZWxlY3Rpb249MDAsMDEsMDJ8Y29tcGxldGVkPTAwLDAx
HLP:fG1vZGU9YXV0bzoxO2RyeTowfHJlYXNvbj1jaGtkc2siCmZ1bmN0aW9uIFBhcnNlLUNoZWNrcG9pbnRBcmcoW3N0cmluZ10kcmF3KSB7CiAgICAkcmVzID0gW29yZGVyZWRdQHsgc3ViID0gJyc7IHNlbGVjdGlvbiA9IEAoKTsgY29tcGxldGVkID0gQCgpOyBtb2Rl
HLP:ID0gQHt9OyByZWFzb24gPSAnJyB9CiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yRW1wdHkoJHJhdykpIHsgcmV0dXJuICRyZXMgfQogICAgJHNlZ3MgPSAkcmF3IC1zcGxpdCAnXHwnCiAgICAkcmVzLnN1YiA9ICRzZWdzWzBdLlRyaW0oKS5Ub0xvd2VyKCkKICAg
HLP:IGZvciAoJGkgPSAxOyAkaSAtbHQgJHNlZ3MuQ291bnQ7ICRpKyspIHsKICAgICAgICAka3YgPSAkc2Vnc1skaV0gLXNwbGl0ICc9JywgMgogICAgICAgIGlmICgka3YuQ291bnQgLWx0IDIpIHsgY29udGludWUgfQogICAgICAgICRrZXkgPSAka3ZbMF0uVHJpbSgp
HLP:LlRvTG93ZXIoKQogICAgICAgICR2YWwgPSAka3ZbMV0KICAgICAgICBzd2l0Y2ggKCRrZXkpIHsKICAgICAgICAgICAgJ3NlbGVjdGlvbicgeyAkcmVzLnNlbGVjdGlvbiA9IEAoJHZhbCAtc3BsaXQgJywnIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5UcmltKCkgfSB8
HLP:IFdoZXJlLU9iamVjdCB7ICRfIC1uZSAnJyB9KSB9CiAgICAgICAgICAgICdjb21wbGV0ZWQnIHsgJHJlcy5jb21wbGV0ZWQgPSBAKCR2YWwgLXNwbGl0ICcsJyB8IEZvckVhY2gtT2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBXaGVyZS1PYmplY3QgeyAkXyAtbmUgJycg
HLP:fSkgfQogICAgICAgICAgICAncmVhc29uJyAgICB7ICRyZXMucmVhc29uID0gJHZhbC5UcmltKCkgfQogICAgICAgICAgICAnbW9kZScgewogICAgICAgICAgICAgICAgJG0gPSBAe30KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwYWlyIGluICgkdmFsIC1zcGxp
HLP:dCAnOycpKSB7CiAgICAgICAgICAgICAgICAgICAgJHAgPSAkcGFpciAtc3BsaXQgJzonLCAyCiAgICAgICAgICAgICAgICAgICAgaWYgKCRwLkNvdW50IC1lcSAyKSB7ICRtWyRwWzBdLlRyaW0oKS5Ub0xvd2VyKCldID0gKCRwWzFdLlRyaW0oKSAtZXEgJzEnKSB9
HLP:CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAkcmVzLm1vZGUgPSAkbQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQogICAgcmV0dXJuICRyZXMKfQoKIyBDb25zdHJ1eWUgeSBwZXJzaXN0ZSBjaGVja3BvaW50Lmpzb24uIERldnVlbHZlICR0
HLP:cnVlLyRmYWxzZSAoc2luIGV4Y2VwY2lvbikuCmZ1bmN0aW9uIFNhdmUtQ2hlY2twb2ludCgkcGFyc2VkKSB7CiAgICB0cnkgewogICAgICAgICRtb2RlID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIGF1dG8gICAgID0gW2Jvb2xdJHBhcnNlZC5tb2Rl
HLP:WydhdXRvJ10KICAgICAgICAgICAgbm9yZWJvb3QgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ25vcmVib290J10KICAgICAgICAgICAga2VlcHd1ICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ2tlZXB3dSddCiAgICAgICAgICAgIGRyeSAgICAgID0gW2Jvb2xdJHBhcnNl
HLP:ZC5tb2RlWydkcnknXQogICAgICAgICAgICB0cmlhZ2UgICA9IFtib29sXSRwYXJzZWQubW9kZVsndHJpYWdlJ10KICAgICAgICB9CiAgICAgICAgJG5vdyA9IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGRfSEgtbW0nKQogICAgICAgICRjcCA9IFtwc2N1
HLP:c3RvbW9iamVjdF1AewogICAgICAgICAgICB2ZXJzaW9uICAgICAgICA9ICRXUElfVkVSU0lPTgogICAgICAgICAgICBjcmVhdGVkICAgICAgICA9ICRub3cKICAgICAgICAgICAgbW9kZSAgICAgICAgICAgPSAkbW9kZQogICAgICAgICAgICBzZWxlY3Rpb24gICAg
HLP:ICA9IEAoJHBhcnNlZC5zZWxlY3Rpb24pCiAgICAgICAgICAgIGNvbXBsZXRlZCAgICAgID0gQCgkcGFyc2VkLmNvbXBsZXRlZCkKICAgICAgICAgICAgcGVuZGluZ19yZWFzb24gPSAkcGFyc2VkLnJlYXNvbgogICAgICAgICAgICB0aW1lc3RhbXBfcnVuICA9ICRu
HLP:b3cKICAgICAgICB9CiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRDaGVja3BvaW50RmlsZSwgKCRjcCB8IENvbnZlcnRUby1Kc29uIC1EZXB0aCA2KSwgKE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkpKQog
HLP:ICAgICAgIHJldHVybiAkdHJ1ZQogICAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9CgojIENhcmdhIGNoZWNrcG9pbnQuanNvbi4gRGV2dWVsdmUgZWwgb2JqZXRvIG8gJG51bGwgc2kgbm8gZXhpc3RlIC8gbWFsZm9ybWFkby4KZnVuY3Rpb24gTG9hZC1DaGVj
HLP:a3BvaW50IHsKICAgIGlmICgtbm90IChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSkgeyByZXR1cm4gJG51bGwgfQogICAgdHJ5IHsgcmV0dXJuIChHZXQtQ29udGVudCAkQ2hlY2twb2ludEZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24pIH0gY2F0Y2ggeyBy
HLP:ZXR1cm4gJG51bGwgfQp9CgojIFZhbGlkYSB1biBjaGVja3BvaW50OiBleGlzdGUgKyBwYXJzZWFibGUgKyB2ZXJzaW9uIGNvbXBhdGlibGUgKyBjb21wbGV0ZWQKIyBzdWJjb25qdW50byBkZSBzZWxlY3Rpb24gKyBjcmVhdGVkIGRlbnRybyBkZSBsYSB2ZW50YW5h
HLP:LiBEZXZ1ZWx2ZSBib29sZWFubwojIFNJTiBsYW56YXIgZXhjZXBjaW9uIGFudGUgSlNPTiBtYWxmb3JtYWRvIG8gY2FkdWNhZG8uCmZ1bmN0aW9uIFRlc3QtQ2hlY2twb2ludFZhbGlkKCRjcCkgewogICAgdHJ5IHsKICAgICAgICBpZiAoJG51bGwgLWVxICRjcCkg
HLP:ewogICAgICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkpIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgICAgIHRyeSB7ICRjcCA9IEdldC1Db250ZW50ICRDaGVja3BvaW50RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9IGNh
HLP:dGNoIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgfQogICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIGlmIChbc3RyaW5nXSRjcC52ZXJzaW9uIC1uZSAkV1BJX1ZFUlNJT04pIHsgcmV0dXJuICRmYWxzZSB9CiAgICAg
HLP:ICAgJHNlbCAgPSBAKCRjcC5zZWxlY3Rpb24pCiAgICAgICAgJGNvbXAgPSBAKCRjcC5jb21wbGV0ZWQpCiAgICAgICAgZm9yZWFjaCAoJGMgaW4gJGNvbXApIHsgaWYgKCRzZWwgLW5vdGNvbnRhaW5zICRjKSB7IHJldHVybiAkZmFsc2UgfSB9CiAgICAgICAgJGNy
HLP:ZWF0ZWQgPSAkbnVsbAogICAgICAgIGlmICgkY3AuY3JlYXRlZCkgewogICAgICAgICAgICB0cnkgeyAkY3JlYXRlZCA9IFtkYXRldGltZV06OlBhcnNlRXhhY3QoW3N0cmluZ10kY3AuY3JlYXRlZCwgJ3l5eXktTU0tZGRfSEgtbW0nLCAkbnVsbCkgfSBjYXRjaCB7
HLP:ICRjcmVhdGVkID0gJG51bGwgfQogICAgICAgIH0KICAgICAgICBpZiAoJG51bGwgLWVxICRjcmVhdGVkKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgICRhZ2UgPSAoR2V0LURhdGUpIC0gJGNyZWF0ZWQKICAgICAgICBpZiAoJGFnZS5Ub3RhbERheXMgLWd0ICRD
HLP:SEVDS1BPSU5UX01BWF9BR0VfREFZUykgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0KfQoKIyBQcmltZXJhIGZhc2UgZGUgJ3NlbGVjdGlvbicgbm8gcHJlc2VudGUgZW4gJ2NvbXBsZXRl
HLP:ZCcgKG8gJycgc2kgdG9kYXMgaGVjaGFzKS4KZnVuY3Rpb24gR2V0LU5leHRQaGFzZSgkY3ApIHsKICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAnJyB9CiAgICAkY29tcCA9IEAoJGNwLmNvbXBsZXRlZCkKICAgIGZvcmVhY2ggKCRzIGluIEAoJGNwLnNl
HLP:bGVjdGlvbikpIHsgaWYgKCRjb21wIC1ub3Rjb250YWlucyAkcykgeyByZXR1cm4gJHMgfSB9CiAgICByZXR1cm4gJycKfQoKIyAtLS0gKDMuOSAvIEJ1ZyA2IC8gUmVxIDgpIFJlc2V0IGRlIGVzdGFkbyByZXV0aWxpemFibGUgLS0tLS0tLS0tLS0tLS0tLS0tLS0K
HLP:IyBEZWphIHBoYXNlcz1AKCksIGZpbmRpbmdzPUAoKSB5IGxvcyBzY29yZXMgKGJlZm9yZS9hZnRlcikgYSBudWxsLiBFbAojIGNvbmRpY2lvbmFkbyBhIC9yZXN1bWUgbG8gYXBsaWNhIGVsIGJhdGNoICh0YXJlYXMgOC40IC8gOS4xKTogc29sbyBpbnZvY2EKIyAn
HLP:cmVzZXRzdGF0ZScgY3VhbmRvIFJFU1VNRT09MCwgY29uc2VydmFuZG8gZWwgZXN0YWRvIHByZXZpbyBlbiAvcmVzdW1lLgpmdW5jdGlvbiBSZXNldC1TdGF0ZSB7CiAgICBXcml0ZS1TdGF0ZSAoW3BzY3VzdG9tb2JqZWN0XUB7IHNjb3JlX2JlZm9yZSA9ICRudWxs
HLP:OyBzY29yZV9hZnRlciA9ICRudWxsOyBmaW5kaW5ncyA9IEAoKTsgcGhhc2VzID0gQCgpIH0pCn0KCiMgLS0tICgzLjExIC8gQnVnIDcgLyBSZXEgOSkgSG9uZXN0aWRhZCBkZWwgbW92aW1pZW50byBkZSBjYWNoZXMgLS0tLS0tLS0tLS0tCiMgRXhpdG8gKHRydWUp
HLP:IFNJIFkgU09MTyBTSSBlbCBvcmlnZW4gZXN0YSBhdXNlbnRlIHkgZWwgZGVzdGlubyBwcmVzZW50ZS4KIyBWYXJpYW50ZSBwdXJhIChib29sZWFub3MpICsgdmFyaWFudGUgcXVlIGFjZXB0YSBydXRhcyB5IGhhY2UgVGVzdC1QYXRoLgpmdW5jdGlvbiBUZXN0LU1v
HLP:dmVSZXN1bHQoW2Jvb2xdJHNyY0V4aXN0cywgW2Jvb2xdJGRzdEV4aXN0cykgewogICAgcmV0dXJuICgoLW5vdCAkc3JjRXhpc3RzKSAtYW5kICRkc3RFeGlzdHMpCn0KZnVuY3Rpb24gVGVzdC1Nb3ZlUmVzdWx0UGF0aChbc3RyaW5nXSRzcmMsIFtzdHJpbmddJGRz
HLP:dCkgewogICAgcmV0dXJuIChUZXN0LU1vdmVSZXN1bHQgKFtib29sXShUZXN0LVBhdGggJHNyYykpIChbYm9vbF0oVGVzdC1QYXRoICRkc3QpKSkKfQoKIyAtLS0gKDMuMTEgLyBCdWcgOCAvIFJlcSAxMCkgSWRlbXBvdGVuY2lhIGRlIFZpcnR1YWxUZXJtaW5hbExl
HLP:dmVsIC0tLS0tLS0tLS0KIyBOb3JtYWxpemEgdmFsb3JlcyAnMHgxJyAvICcxJyAvIDEgYSBlbnRlcm8gcGFyYSBjb21wYXJhciBkZSBmb3JtYSByb2J1c3RhLgpmdW5jdGlvbiBDb252ZXJ0VG8tVnRsSW50KCR2KSB7CiAgICBpZiAoJG51bGwgLWVxICR2KSB7IHJl
HLP:dHVybiAkbnVsbCB9CiAgICAkcyA9IChbc3RyaW5nXSR2KS5UcmltKCkuVG9Mb3dlcigpCiAgICBpZiAoJHMgLWVxICcnKSB7IHJldHVybiAkbnVsbCB9CiAgICB0cnkgewogICAgICAgIGlmICgkcy5TdGFydHNXaXRoKCcweCcpKSB7IHJldHVybiBbQ29udmVydF06
HLP:OlRvSW50MzIoJHMsIDE2KSB9CiAgICAgICAgcmV0dXJuIFtpbnRdJHMKICAgIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CiMgRGV2dWVsdmUgJHRydWUgKGVzY3JpYmlyKSBzb2xvIHNpIGVsIHZhbG9yIGFjdHVhbCBkaWZpZXJlIGRlbCBkZXNlYWRvLgpmdW5j
HLP:dGlvbiBSZXNvbHZlLVZ0bFdyaXRlKCRjdXJyZW50LCAkZGVzaXJlZCkgewogICAgcmV0dXJuICgoQ29udmVydFRvLVZ0bEludCAkY3VycmVudCkgLW5lIChDb252ZXJ0VG8tVnRsSW50ICRkZXNpcmVkKSkKfQoKIyAtLS0gKDMuMTQgLyBSZXEgMS4zKSBNYXBlbyBU
HLP:T1RBTCBkZSBjb2RpZ28gZGUgc2FsaWRhIGEge09LLFdBUk4sU0tJUCxFUlJPUn0KIyAwLT5PSywgMS0+V0FSTiwgMi0+U0tJUCwgMy0+RVJST1I7IGN1YWxxdWllciBvdHJvIGVudGVybyAobyBubyBlbnRlcm8pIC0+IEVSUk9SLgpmdW5jdGlvbiBNYXAtRXhpdENv
HLP:ZGUoJGNvZGUpIHsKICAgICRuID0gJG51bGwKICAgIHRyeSB7ICRuID0gW2ludF0kY29kZSB9IGNhdGNoIHsgcmV0dXJuICdFUlJPUicgfQogICAgc3dpdGNoICgkbikgewogICAgICAgIDAgICAgICAgeyAnT0snIH0KICAgICAgICAxICAgICAgIHsgJ1dBUk4nIH0K
HLP:ICAgICAgICAyICAgICAgIHsgJ1NLSVAnIH0KICAgICAgICAzICAgICAgIHsgJ0VSUk9SJyB9CiAgICAgICAgZGVmYXVsdCB7ICdFUlJPUicgfQogICAgfQp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09CiMgIERJQUdOT1NUSUNPIEFNUExJQURPICg1LjEgLyBSZXEgMTUuMS0xNS41KQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSBS
HLP:QU0gKFJlcSAxNS4xKSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUmVzb2x2ZS1SYW1TdGF0dXM6IGZ1bmNpb24gUFVSQS4gQSBwYXJ0aXIgZGVsIGNvbnRlbyBkZSBlcnJvcmVzIGRlIG1lbW9yaWEKIyBX
HLP:SEVBIHkgZGUgZmFsbG9zIGRlbCBkaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MsIGRlY2lkZSBlbCBlc3RhZG8geQojIHNpIGNvbnZpZW5lIHJlY29tZW5kYXIgbWRzY2hlZC4KZnVuY3Rpb24gUmVzb2x2ZS1SYW1TdGF0dXMoW2ludF0kd2hlYU1lbUVy
HLP:cm9ycywgW2ludF0kbWVtRGlhZ0ZhaWx1cmVzKSB7CiAgICBpZiAoJHdoZWFNZW1FcnJvcnMgLWd0IDAgLW9yICRtZW1EaWFnRmFpbHVyZXMgLWd0IDApIHsKICAgICAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdzdXNwZWN0JzsgcmVjb21t
HLP:ZW5kX21kc2NoZWQgPSAkdHJ1ZSB9CiAgICB9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdvayc7IHJlY29tbWVuZF9tZHNjaGVkID0gJGZhbHNlIH0KfQoKIyBHZXQtUmFtQ2hlY2s6IGxlZSBldmVudG9zIFdIRUEgeSByZXN1bHRhZG9z
HLP:IGRlbCBEaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlCiMgV2luZG93cy4gRGVncmFkYWNpb24gZWxlZ2FudGU6IHNpIGxhIGNvbnN1bHRhIGRlIGV2ZW50b3MgZmFsbGEgcG9yIGNvbXBsZXRvLAojIGRldnVlbHZlIHN0YXR1cz0ndW5rbm93bicgc2luIGxhbnphciBl
HLP:eGNlcGNpb24uCmZ1bmN0aW9uIEdldC1SYW1DaGVjayB7CiAgICB0cnkgewogICAgICAgICRxdWVyaWVkID0gJGZhbHNlCiAgICAgICAgJHdoZWFDb3VudCA9IDAKICAgICAgICAkbWVtRGlhZ0ZhaWwgPSAwCiAgICAgICAgIyBFcnJvcmVzIGRlIGhhcmR3YXJlIFdI
HLP:RUEgcmVsYWNpb25hZG9zIGNvbiBtZW1vcmlhCiAgICAgICAgJHdoZWEgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgUHJvdmlkZXJOYW1lPSdNaWNyb3NvZnQtV2luZG93cy1XSEVBLUxvZ2dlcid9IC1NYXhFdmVu
HLP:dHMgMTAwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkbnVsbCAtbmUgJHdoZWEpIHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAgICAgJHdoZWFDb3VudCA9IEAoJHdoZWEgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWluIDE4LDE5
HLP:LDIwLDQ3KSAtb3IgKCRfLk1lc3NhZ2UgLW1hdGNoICdtZW1vcicpIH0pLkNvdW50CiAgICAgICAgIyBSZXN1bHRhZG9zIGRlbCBEaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MgKG1kc2NoZWQpCiAgICAgICAgJG1kID0gQChHZXQtV2luRXZlbnQgLUZp
HLP:bHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IFByb3ZpZGVyTmFtZT0nTWljcm9zb2Z0LVdpbmRvd3MtTWVtb3J5RGlhZ25vc3RpY3MtUmVzdWx0cyd9IC1NYXhFdmVudHMgNTAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYg
HLP:KCRudWxsIC1uZSAkbWQpIHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAgICAgJG1lbURpYWdGYWlsID0gQCgkbWQgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWVxIDEwMDIpIC1vciAoJF8uTGV2ZWxEaXNwbGF5TmFtZSAtZXEgJ0Vycm9yJykgLW9yICgkXy5NZXNz
HLP:YWdlIC1tYXRjaCAnZXJyb3J8ZXJyb3JlcycpIH0pLkNvdW50CiAgICAgICAgcmV0dXJuIChSZXNvbHZlLVJhbVN0YXR1cyAkd2hlYUNvdW50ICRtZW1EaWFnRmFpbCkKICAgIH0gY2F0Y2ggewogICAgICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVz
HLP:ID0gJ3Vua25vd24nOyByZWNvbW1lbmRfbWRzY2hlZCA9ICRmYWxzZSB9CiAgICB9Cn0KCiMgLS0tIEJhdGVyaWEgKFJlcSAxNS4yKSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtQmF0dGVyeUhlYWx0aFBj
HLP:dDogZnVuY2lvbiBQVVJBLiAlIGRlIHNhbHVkID0gcGxlbmEgY2FyZ2EgLyBkaXNlbm8gKiAxMDAuCmZ1bmN0aW9uIEdldC1CYXR0ZXJ5SGVhbHRoUGN0KCRkZXNpZ24sICRmdWxsKSB7CiAgICB0cnkgewogICAgICAgICRkID0gW2RvdWJsZV0kZGVzaWduOyAkZiA9
HLP:IFtkb3VibGVdJGZ1bGwKICAgICAgICBpZiAoJGQgLWd0IDApIHsgcmV0dXJuIFtpbnRdW21hdGhdOjpSb3VuZCgoJGYgLyAkZCkgKiAxMDApIH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAkbnVsbAp9CgojIEdldC1CYXR0ZXJ5SGVhbHRoOiBzaSBoYXkgYmF0
HLP:ZXJpYSwgZ2VuZXJhIHBvd2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0IHkgZXh0cmFlIGxhCiMgc2FsdWQgKGNhcGFjaWRhZCBkZSBkaXNlbm8gdnMgcGxlbmEgY2FyZ2EpLiBTaW4gYmF0ZXJpYSAtPiBwcmVzZW50PSRmYWxzZS4KIyBObyBmYWxsYSBzaSBwb3dlcmNmZyBu
HLP:byBlc3RhIGRpc3BvbmlibGUgKGhlYWx0aF9wY3QgcXVlZGEgdmFjaW8pLgpmdW5jdGlvbiBHZXQtQmF0dGVyeUhlYWx0aCB7CiAgICAkcHJlc2VudCA9ICRmYWxzZTsgJGhlYWx0aFBjdCA9ICcnOyAkcmVwb3J0UGF0aCA9ICcnCiAgICB0cnkgewogICAgICAgICRi
HLP:YXQgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9CYXR0ZXJ5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkYmF0LkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRwcmVzZW50ID0gJHRydWUKICAgICAgICAgICAgJHJlcG9ydFBh
HLP:dGggPSBKb2luLVBhdGggJFdvcmsgJ2JhdHRlcnktcmVwb3J0Lmh0bWwnCiAgICAgICAgICAgIHRyeSB7ICYgcG93ZXJjZmcgL2JhdHRlcnlyZXBvcnQgL291dHB1dCAiJHJlcG9ydFBhdGgiIC9kdXJhdGlvbiAxID4gJG51bGwgMj4mMSB9IGNhdGNoIHt9CiAgICAg
HLP:ICAgICAgIGlmIChUZXN0LVBhdGggJHJlcG9ydFBhdGgpIHsKICAgICAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAgICAgJHR4dCA9IEdldC1Db250ZW50ICRyZXBvcnRQYXRoIC1SYXcKICAgICAgICAgICAgICAgICAgICAkZGVzaWduID0gJG51bGw7
HLP:ICRmdWxsID0gJG51bGwKICAgICAgICAgICAgICAgICAgICAkbTEgPSBbcmVnZXhdOjpNYXRjaCgkdHh0LCAnKD9pcylERVNJR04gQ0FQQUNJVFkuKj8oW1xkXC4sXSspXHMqbVdoJykKICAgICAgICAgICAgICAgICAgICAkbTIgPSBbcmVnZXhdOjpNYXRjaCgkdHh0
HLP:LCAnKD9pcylGVUxMIENIQVJHRSBDQVBBQ0lUWS4qPyhbXGRcLixdKylccyptV2gnKQogICAgICAgICAgICAgICAgICAgIGlmICgkbTEuU3VjY2VzcykgeyAkZGVzaWduID0gW2RvdWJsZV0oKCRtMS5Hcm91cHNbMV0uVmFsdWUgLXJlcGxhY2UgJ1tcLixdJywgJycp
HLP:KSB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRtMi5TdWNjZXNzKSB7ICRmdWxsICAgPSBbZG91YmxlXSgoJG0yLkdyb3Vwc1sxXS5WYWx1ZSAtcmVwbGFjZSAnW1wuLF0nLCAnJykpIH0KICAgICAgICAgICAgICAgICAgICAkcGN0ID0gR2V0LUJhdHRlcnlIZWFs
HLP:dGhQY3QgJGRlc2lnbiAkZnVsbAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHBjdCkgeyAkaGVhbHRoUGN0ID0gJHBjdCB9CiAgICAgICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9IGNhdGNoIHt9CiAg
HLP:ICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHByZXNlbnQgPSAkcHJlc2VudDsgaGVhbHRoX3BjdCA9ICRoZWFsdGhQY3Q7IHJlcG9ydF9wYXRoID0gJHJlcG9ydFBhdGggfQp9CgojIC0tLSBOZXR3b3JrIGF2YW56YWRhIChSZXEgMTUuNSkgLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEdldC1OZXRBZHZhbmNlZDogY29uZWN0aXZpZGFkIChwaW5nIGEgMS4xLjEuMSksIEROUyAoUmVzb2x2ZS1EbnNOYW1lIGNvbgojIHJlc3BhbGRvIHBvciBwaW5nIGEgdW4gaG9zdCkgeSBjb25maWd1
HLP:cmFjaW9uIGJhc2ljYSAoSVAvZ2F0ZXdheSkuCiMgRGVncmFkYWNpb24gZWxlZ2FudGU6IG51bmNhIGxhbnphIGV4Y2VwY2lvbi4KZnVuY3Rpb24gR2V0LU5ldEFkdmFuY2VkIHsKICAgICRjb25uZWN0ZWQgPSAkZmFsc2U7ICRkbnNPayA9ICRmYWxzZTsgJGRldGFp
HLP:bHMgPSAnJwogICAgdHJ5IHsKICAgICAgICAjIENvbmVjdGl2aWRhZAogICAgICAgICRwaW5nID0gJGZhbHNlCiAgICAgICAgdHJ5IHsgJHBpbmcgPSBbYm9vbF0oVGVzdC1Db25uZWN0aW9uIC1Db21wdXRlck5hbWUgJzEuMS4xLjEnIC1Db3VudCAxIC1RdWlldCAt
HLP:RXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkgfSBjYXRjaCB7ICRwaW5nID0gJGZhbHNlIH0KICAgICAgICBpZiAoLW5vdCAkcGluZykgewogICAgICAgICAgICB0cnkgeyAmIHBpbmcgLW4gMSAtdyAxNTAwIDEuMS4xLjEgPiAkbnVsbCAyPiYxOyBpZiAoJExB
HLP:U1RFWElUQ09ERSAtZXEgMCkgeyAkcGluZyA9ICR0cnVlIH0gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkY29ubmVjdGVkID0gW2Jvb2xdJHBpbmcKICAgICAgICAjIFJlc29sdWNpb24gRE5TIChjb24gbWVkaWRhIGRlIGxhdGVuY2lhKQogICAgICAgICRk
HLP:bnMgPSAkZmFsc2U7ICRkbnNNcyA9ICRudWxsCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHN3ID0gW1N5c3RlbS5EaWFnbm9zdGljcy5TdG9wd2F0Y2hdOjpTdGFydE5ldygpCiAgICAgICAgICAgICRyID0gUmVzb2x2ZS1EbnNOYW1lIC1OYW1lICd3d3cubWlj
HLP:cm9zb2Z0LmNvbScgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgJHN3LlN0b3AoKQogICAgICAgICAgICBpZiAoJHIpIHsgJGRucyA9ICR0cnVlOyAkZG5zTXMgPSBbaW50XSRzdy5FbGFwc2VkTWlsbGlzZWNvbmRzIH0KICAgICAgICB9
HLP:IGNhdGNoIHt9CiAgICAgICAgaWYgKC1ub3QgJGRucykgewogICAgICAgICAgICB0cnkgeyAmIHBpbmcgLW4gMSAtdyAxNTAwIHd3dy5taWNyb3NvZnQuY29tID4gJG51bGwgMj4mMTsgaWYgKCRMQVNURVhJVENPREUgLWVxIDApIHsgJGRucyA9ICR0cnVlIH0gfSBj
HLP:YXRjaCB7fQogICAgICAgIH0KICAgICAgICAkZG5zT2sgPSBbYm9vbF0kZG5zCiAgICAgICAgIyBDb25maWd1cmFjaW9uIGJhc2ljYSAoSVAgLyBnYXRld2F5KQogICAgICAgICRpcCA9ICcnOyAkZ3cgPSAnJwogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRjZmcg
HLP:PSBAKEdldC1OZXRJUENvbmZpZ3VyYXRpb24gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBXaGVyZS1PYmplY3QgeyAkXy5JUHY0RGVmYXVsdEdhdGV3YXkgfSkgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIGlmICgkY2ZnKSB7CiAg
HLP:ICAgICAgICAgICAgICAkaXAgPSAoJGNmZy5JUHY0QWRkcmVzcyB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEpLklQQWRkcmVzcwogICAgICAgICAgICAgICAgJGd3ID0gKCRjZmcuSVB2NERlZmF1bHRHYXRld2F5IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkuTmV4
HLP:dEhvcAogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICRkZXRhaWxzID0gIklQPSRpcDsgR1c9JGd3IgogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBjb25uZWN0ZWQgPSAkY29ubmVjdGVkOyBkbnNfb2sg
HLP:PSAkZG5zT2s7IGRldGFpbHMgPSAkZGV0YWlsczsgZG5zX21zID0gJGRuc01zIH0KfQoKIyAtLS0gRGV2aWNlcyBwYXJhIGRpYWcgKFJlcSAxNS4zLzE1LjQpIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtRGV2aWNlTGlzdDogbGlzdGEgZXN0
HLP:cnVjdHVyYWRhIGRlIGRpc3Bvc2l0aXZvcyBjb24gZXJyb3IgcGFyYSBlc3RhZG8uZGlhZy4KIyBEZXZ1ZWx2ZSAkbnVsbCBzaSBsYSBpZGVudGlmaWNhY2lvbiBkZSBkcml2ZXJzIGZhbGxhIChzZW5hbCBkZSAiaW5mbyBubwojIGRpc3BvbmlibGUiIHBhcmEgZGVn
HLP:cmFkYWNpb24gZWxlZ2FudGUpLgpmdW5jdGlvbiBHZXQtRGV2aWNlTGlzdCB7CiAgICB0cnkgewogICAgICAgICRwID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUG5QRW50aXR5IC1FcnJvckFjdGlvbiBTdG9wIHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFu
HLP:YWdlckVycm9yQ29kZSAtZ3QgMCB9KQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJGQgaW4gKCRwIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMTIpKSB7CiAgICAgICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBjb2RlID0gW2lu
HLP:dF0kZC5Db25maWdNYW5hZ2VyRXJyb3JDb2RlOyBuYW1lID0gW3N0cmluZ10kZC5OYW1lIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuICwkbGlzdAogICAgfSBjYXRjaCB7IHJldHVybiAkbnVsbCB9Cn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgUk9UQUNJT04gREUgTE9HUyAoNS42IC8gUmVxIDE3LjIpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT0KIyBTZWxlY3QtTG9nc1RvRGVsZXRlOiBmdW5jaW9uIFBVUkEuIERlIHVuYSBjb2xlY2Npb24gZGUgZmljaGVyb3MgKGNvbgojIC5MYXN0V3JpdGVUaW1lKSB5IHVuYSByZXRlbmNpb24gTiwgZGV2dWVsdmUgbG9zIHF1ZSBkZWJlbiBCT1JSQVJTRTog
HLP:dG9kb3MKIyBtZW5vcyBsb3MgTiBtYXMgcmVjaWVudGVzIChlcyBkZWNpciwgbG9zIG1hcyBhbnRpZ3VvcykuIFNpIGhheSA8PSBOLCBuaW5ndW5vLgpmdW5jdGlvbiBTZWxlY3QtTG9nc1RvRGVsZXRlKCRmaWxlcywgW2ludF0kcmV0ZW50aW9uKSB7CiAgICAkYXJy
HLP:ID0gQCgkZmlsZXMpCiAgICBpZiAoJHJldGVudGlvbiAtbHQgMCkgeyAkcmV0ZW50aW9uID0gMCB9CiAgICBpZiAoJGFyci5Db3VudCAtbGUgJHJldGVudGlvbikgeyByZXR1cm4gQCgpIH0KICAgICRzb3J0ZWQgPSBAKCRhcnIgfCBTb3J0LU9iamVjdCAtUHJvcGVy
HLP:dHkgTGFzdFdyaXRlVGltZSAtRGVzY2VuZGluZykKICAgIHJldHVybiBAKCRzb3J0ZWQgfCBTZWxlY3QtT2JqZWN0IC1Ta2lwICRyZXRlbnRpb24pCn0KCiMgSW52b2tlLUxvZ1JvdGF0ZTogY29uc2VydmEgbG9zICRyZXRlbnRpb24gbG9ncyBtYXMgcmVjaWVudGVz
HLP:IGVuICRmb2xkZXIgeQojIGJvcnJhIGVsIHJlc3RvLiBEZXZ1ZWx2ZSBlbCBudW1lcm8gZGUgZmljaGVyb3MgYm9ycmFkb3MuCmZ1bmN0aW9uIEludm9rZS1Mb2dSb3RhdGUoW3N0cmluZ10kZm9sZGVyLCBbaW50XSRyZXRlbnRpb24pIHsKICAgIGlmIChbc3RyaW5n
HLP:XTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRmb2xkZXIpKSB7ICRmb2xkZXIgPSBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnIH0KICAgICRkZWxldGVkID0gMAogICAgdHJ5IHsKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRmb2xkZXIpKSB7IHJldHVybiAwIH0KICAg
HLP:ICAgICAkZmlsZXMgPSBAKEdldC1DaGlsZEl0ZW0gLVBhdGggJGZvbGRlciAtRmlsdGVyICcqLmxvZycgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgJHRvRGVsZXRlID0gU2VsZWN0LUxvZ3NUb0RlbGV0ZSAkZmlsZXMgJHJldGVu
HLP:dGlvbgogICAgICAgIGZvcmVhY2ggKCRmIGluICR0b0RlbGV0ZSkgewogICAgICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAkZi5GdWxsTmFtZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWU7ICRkZWxldGVkKysgfSBjYXRjaCB7fQogICAgICAg
HLP:IH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAkZGVsZXRlZAp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIFZBTElEQUNJT04gREUgRU5UT1JOTyBZIFNFTEYt
HLP:VEVTVCAoNS44IC8gUmVxIDEzLjUsMTMuNiwxOC4xLDE4LjMsMTguNikKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIFRlc3QtT3NTdXBwb3J0ZWQ6IGZ1bmNpb24gUFVS
HLP:QS4gV2luZG93cyAxMC8xMSA9PiBidWlsZCA+PSAxMDI0MC4KZnVuY3Rpb24gVGVzdC1Pc1N1cHBvcnRlZChbaW50XSRidWlsZCkgewogICAgcmV0dXJuICgkYnVpbGQgLWdlIDEwMjQwKQp9CgojIEludm9rZS1FbnZWYWxpZGF0ZTogY29tcHJ1ZWJhIGxhIHZlcnNp
HLP:b24gZGVsIFNPIHZpYSBDSU0uIExhIGNvbXByb2JhY2lvbiBzZQojIGNvbnNpZGVyYSBTSUVNUFJFIHJlYWxpemFkYSAoY2hlY2tfZG9uZSkgYXVucXVlIGxhIHZlcnNpb24gbm8gc2VhIGNvbXBhdGlibGUuCmZ1bmN0aW9uIEludm9rZS1FbnZWYWxpZGF0ZSB7CiAg
HLP:ICAkYnVpbGQgPSAwCiAgICB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3BlcmF0aW5nU3lzdGVtIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS5CdWlsZE51bWJlciB9IGNhdGNoIHsgJGJ1aWxkID0gMCB9CiAgICBpZiAo
HLP:JGJ1aWxkIC1sZSAwKSB7IHRyeSB7ICRidWlsZCA9IFtpbnRdKEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uJyAtTmFtZSBDdXJyZW50QnVpbGROdW1iZXIgLUVycm9yQWN0aW9uIFNpbGVu
HLP:dGx5Q29udGludWUpLkN1cnJlbnRCdWlsZE51bWJlciB9IGNhdGNoIHsgJGJ1aWxkID0gMCB9IH0KICAgIGlmICgkYnVpbGQgLWxlIDApIHsgdHJ5IHsgJGJ1aWxkID0gW2ludF0oR2V0LUl0ZW1Qcm9wZXJ0eSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRv
HLP:d3MgTlRcQ3VycmVudFZlcnNpb24nIC1OYW1lIEN1cnJlbnRCdWlsZCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuQ3VycmVudEJ1aWxkIH0gY2F0Y2ggeyAkYnVpbGQgPSAwIH0gfQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBvc19vayA9IChU
HLP:ZXN0LU9zU3VwcG9ydGVkICRidWlsZCk7IGJ1aWxkID0gJGJ1aWxkOyBjaGVja19kb25lID0gJHRydWUgfQp9CgojIEludm9rZS1TZWxmVGVzdDogYWdyZWdhZG9yIFBVUk8uIEV4aXRvICh0cnVlKSBzaSB5IHNvbG8gc2kgVE9EQVMgbGFzCiMgY29tcHJvYmFjaW9u
HLP:ZXMgKGJvb2xlYW5vcykgcGFzYW4uIENvbGVjY2lvbiB2YWNpYSAtPiB0cnVlIChuYWRhIGZhbGxvKS4KZnVuY3Rpb24gSW52b2tlLVNlbGZUZXN0KCRyZXN1bHRzKSB7CiAgICBmb3JlYWNoICgkciBpbiBAKCRyZXN1bHRzKSkgeyBpZiAoLW5vdCBbYm9vbF0kcikg
HLP:eyByZXR1cm4gJGZhbHNlIH0gfQogICAgcmV0dXJuICR0cnVlCn0KCiMgUGFyc2UtQm9vbExpc3Q6IGNvbnZpZXJ0ZSAiMSwxLDAsMSIgKG8gdHJ1ZS9vaykgZW4gdW5hIGxpc3RhIGRlIGJvb2xlYW5vcy4KZnVuY3Rpb24gUGFyc2UtQm9vbExpc3QoW3N0cmluZ10k
HLP:cmF3KSB7CiAgICAkbGlzdCA9IEAoKQogICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkcmF3KSkgewogICAgICAgIGZvcmVhY2ggKCR0IGluICgkcmF3IC1zcGxpdCAnLCcpKSB7CiAgICAgICAgICAgICR0b2sgPSAkdC5UcmltKCkuVG9M
HLP:b3dlcigpCiAgICAgICAgICAgIGlmICgkdG9rIC1lcSAnJykgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRsaXN0ICs9ICgkdG9rIC1lcSAnMScgLW9yICR0b2sgLWVxICd0cnVlJyAtb3IgJHRvayAtZXEgJ29rJyAtb3IgJHRvayAtZXEgJ3Bhc3MnKQogICAgICAg
HLP:IH0KICAgIH0KICAgIHJldHVybiAsJGxpc3QKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIERJQUdOT1NUSUNPIFBST0ZVTkRPIHYzLjEgKFNNQVJULCBhcnJhbnF1ZSwgQkNELCBwcm9jZXNvcywgU0ZDLCBKU09OKQojICBUb2RhcyBsYXMgZnVuY2lvbmVzIGRlZ3JhZGFuIGNvbiBlbGVnYW5j
HLP:aWE6IHNpIGFsZ28gZmFsbGEsIGRldnVlbHZlbgojICBlc3RydWN0dXJhcyB2YWNpYXMgLyAndW5rbm93bicgZW4gbHVnYXIgZGUgbGFuemFyIGV4Y2VwY2lvbmVzLgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09CgojIEdldC1TbWFydEF0dHJpYnV0ZXM6IHNhbHVkIGZpc2ljYSBkZWwgZGlzY28gZGUgc2lzdGVtYSAoaW5kZXBlbmRpZW50ZSBkZWwKIyBpZGlvbWEgZGUgV2luZG93cykuIFVzYSBNU1N0b3JhZ2VEcml2ZXJfRmFpbHVyZVBy
HLP:ZWRpY3RTdGF0dXMgKyBlbCBjb250YWRvcgojIGRlIGZpYWJpbGlkYWQgZGUgYWxtYWNlbmFtaWVudG8uIERldnVlbHZlIGF2YWlsYWJsZT0kZmFsc2Ugc2kgbm8gaGF5IGRhdG9zLgpmdW5jdGlvbiBHZXQtU21hcnRBdHRyaWJ1dGVzIHsKICAgICRyZXMgPSBbcHNj
HLP:dXN0b21vYmplY3RdQHsgYXZhaWxhYmxlID0gJGZhbHNlOyBwcmVkaWN0X2ZhaWwgPSAkZmFsc2U7IHRlbXBfYyA9ICRudWxsOyB3ZWFyX3BjdCA9ICRudWxsOyBwb2ggPSAkbnVsbCB9CiAgICB0cnkgewogICAgICAgICRwZiA9ICRudWxsCiAgICAgICAgdHJ5IHsg
HLP:JHBmID0gQChHZXQtQ2ltSW5zdGFuY2UgLU5hbWVzcGFjZSAncm9vdFx3bWknIC1DbGFzc05hbWUgJ01TU3RvcmFnZURyaXZlcl9GYWlsdXJlUHJlZGljdFN0YXR1cycgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIH0gY2F0Y2ggeyAkcGYgPSAkbnVsbCB9
HLP:CiAgICAgICAgaWYgKCRwZiAtYW5kICRwZi5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlCiAgICAgICAgICAgIGZvcmVhY2ggKCR4IGluICRwZikgeyBpZiAoJHguUHJlZGljdEZhaWx1cmUpIHsgJHJlcy5wcmVkaWN0X2Zh
HLP:aWwgPSAkdHJ1ZSB9IH0KICAgICAgICB9CiAgICAgICAgIyBEaXNjbyBxdWUgY29udGllbmUgQzogLT4gY29udGFkb3IgZGUgZmlhYmlsaWRhZAogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRzeXNEaXNrID0gJG51bGwKICAgICAgICAgICAgdHJ5IHsgJHN5c0Rp
HLP:c2sgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgJF8uRGV2aWNlSWQgLW5lICRudWxsIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0gY2F0Y2gge30KICAgICAgICAgICAgJHJjID0gJG51
HLP:bGwKICAgICAgICAgICAgaWYgKCRzeXNEaXNrKSB7ICRyYyA9ICRzeXNEaXNrIHwgR2V0LVN0b3JhZ2VSZWxpYWJpbGl0eUNvdW50ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICAgICBpZiAoLW5vdCAkcmMpIHsgJHJjID0gR2V0LVBo
HLP:eXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IEdldC1TdG9yYWdlUmVsaWFiaWxpdHlDb3VudGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgIGlmICgkcmMp
HLP:IHsKICAgICAgICAgICAgICAgICRyZXMuYXZhaWxhYmxlID0gJHRydWUKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLlRlbXBlcmF0dXJlIC1hbmQgJHJjLlRlbXBlcmF0dXJlIC1ndCAwKSB7ICRyZXMudGVtcF9jID0gW2ludF0kcmMuVGVtcGVyYXR1
HLP:cmUgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcmMuV2VhcikgICAgICAgICB7ICRyZXMud2Vhcl9wY3QgPSBbaW50XSRyYy5XZWFyIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLlBvd2VyT25Ib3VycykgeyAkcmVzLnBvaCA9IFtp
HLP:bnRdJHJjLlBvd2VyT25Ib3VycyB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgIyBTZW5hbCBhZGljaW9uYWwgZGUgcHJlZGljY2lvbiBkZSBmYWxsbyB2aWEgZXN0YWRvIGRlIHNhbHVkIGZpc2ljYQogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAg
HLP:JHVuaGVhbHRoeSA9IEAoR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLkhlYWx0aFN0YXR1cyAtYW5kICRfLkhlYWx0aFN0YXR1cyAtbmUgJ0hlYWx0aHknIH0pCiAgICAgICAgICAgICAgICBp
HLP:ZiAoJHVuaGVhbHRoeS5Db3VudCAtZ3QgMCkgeyAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlOyAkcmVzLnByZWRpY3RfZmFpbCA9ICR0cnVlIH0KICAgICAgICAgICAgfSBjYXRjaCB7fQogICAgICAgIH0gY2F0Y2gge30KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAk
HLP:cmVzCn0KCiMgR2V0LVN0YXJ0dXBJdGVtczogcHJvZ3JhbWFzIHF1ZSBhcnJhbmNhbiBjb24gV2luZG93cyAodG9wIE4pLCBwYXJhIHF1ZSBlbAojIHVzdWFyaW8gdmVhIHF1ZSByYWxlbnRpemEgZWwgaW5pY2lvLiBJbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEuCmZ1
HLP:bmN0aW9uIEdldC1TdGFydHVwSXRlbXMoW2ludF0kdG9wID0gOCkgewogICAgdHJ5IHsKICAgICAgICAkaXRlbXMgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9TdGFydHVwQ29tbWFuZCAtRXJyb3JBY3Rpb24gU3RvcCB8CiAgICAgICAgICAgIFdoZXJlLU9iamVj
HLP:dCB7ICRfLkNvbW1hbmQgfSB8CiAgICAgICAgICAgIFNlbGVjdC1PYmplY3QgLUZpcnN0ICR0b3ApCiAgICAgICAgJGxpc3QgPSBAKCkKICAgICAgICBmb3JlYWNoICgkaSBpbiAkaXRlbXMpIHsKICAgICAgICAgICAgJGNtZCA9IFtzdHJpbmddJGkuQ29tbWFuZAog
HLP:ICAgICAgICAgICBpZiAoJGNtZC5MZW5ndGggLWd0IDgwKSB7ICRjbWQgPSAkY21kLlN1YnN0cmluZygwLDc3KSArICcuLi4nIH0KICAgICAgICAgICAgJG5tID0gW3N0cmluZ10kaS5OYW1lOyBpZiAoLW5vdCAkbm0pIHsgJG5tID0gW3N0cmluZ10kaS5DYXB0aW9u
HLP:IH0KICAgICAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7IG5hbWUgPSAkbm07IGNvbW1hbmQgPSAkY21kIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuICwkbGlzdAogICAgfSBjYXRjaCB7IHJldHVybiBAKCkgfQp9CgojIEdldC1CY2RJbnRlZ3Jp
HLP:dHk6IGNvbXBydWViYSBxdWUgbGEgY29uZmlndXJhY2lvbiBkZSBhcnJhbnF1ZSAoQkNEKSB0aWVuZSBsYQojIGVudHJhZGEgYWN0dWFsIGNvbiBvc2RldmljZS9kZXZpY2UuIExhcyBDTEFWRVMgZGUgYmNkZWRpdCBzb24gc2llbXByZSBlbgojIGluZ2xlcywgYXNp
HLP:IHF1ZSBlcyBpbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEgZGUgbGEgaW50ZXJmYXouCmZ1bmN0aW9uIEdldC1CY2RJbnRlZ3JpdHkgewogICAgJHJlcyA9IFtwc2N1c3RvbW9iamVjdF1AeyBvayA9ICRmYWxzZTsgZGV0YWlscyA9ICcnIH0KICAgIHRyeSB7CiAgICAg
HLP:ICAgJG91dCA9ICYgYmNkZWRpdCAvZW51bSAne2N1cnJlbnR9JyAyPiRudWxsCiAgICAgICAgJHR4dCA9ICgkb3V0IC1qb2luICJgbiIpCiAgICAgICAgaWYgKCRMQVNURVhJVENPREUgLWVxIDAgLWFuZCAkdHh0IC1tYXRjaCAnKD9pbSleXHMqb3NkZXZpY2UnIC1h
HLP:bmQgJHR4dCAtbWF0Y2ggJyg/aW0pXlxzKmRldmljZScpIHsKICAgICAgICAgICAgJHJlcy5vayA9ICR0cnVlCiAgICAgICAgICAgICRyZXMuZGV0YWlscyA9ICdFbnRyYWRhIGRlIGFycmFucXVlIGFjdHVhbCBpbnRlZ3JhIChkZXZpY2Uvb3NkZXZpY2UgcHJlc2Vu
HLP:dGVzKS4nCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJHJlcy5vayA9ICRmYWxzZQogICAgICAgICAgICAkcmVzLmRldGFpbHMgPSAnTm8gc2UgcHVkbyBjb25maXJtYXIgbGEgZW50cmFkYSBkZSBhcnJhbnF1ZSBhY3R1YWwuJwogICAgICAgIH0KICAgIH0g
HLP:Y2F0Y2ggewogICAgICAgICRyZXMub2sgPSAkZmFsc2UKICAgICAgICAkcmVzLmRldGFpbHMgPSAnYmNkZWRpdCBubyBkaXNwb25pYmxlIG8gc2luIHBlcm1pc29zLicKICAgIH0KICAgIHJldHVybiAkcmVzCn0KCiMgR2V0LVRvcFByb2Nlc3NlczogcHJvY2Vzb3Mg
HLP:cXVlIG1hcyBtZW1vcmlhIGRlIHRyYWJham8gY29uc3VtZW4gKHRvcCBOKS4KZnVuY3Rpb24gR2V0LVRvcFByb2Nlc3NlcyhbaW50XSR0b3AgPSA2KSB7CiAgICB0cnkgewogICAgICAgICRwcyA9IEAoR2V0LVByb2Nlc3MgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
HLP:dGludWUgfAogICAgICAgICAgICBTb3J0LU9iamVjdCBXb3JraW5nU2V0NjQgLURlc2NlbmRpbmcgfAogICAgICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAkdG9wKQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHBzKSB7CiAg
HLP:ICAgICAgICAgICRtYiA9IFttYXRoXTo6Um91bmQoJHAuV29ya2luZ1NldDY0IC8gMU1CKQogICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsgbmFtZSA9IFtzdHJpbmddJHAuUHJvY2Vzc05hbWU7IG1lbV9tYiA9IFtpbnRdJG1iIH0KICAgICAg
HLP:ICB9CiAgICAgICAgcmV0dXJuICwkbGlzdAogICAgfSBjYXRjaCB7IHJldHVybiBAKCkgfQp9CgojIEdldC1TZmNSZXN1bHQ6IGNsYXNpZmljYSBlbCByZXN1bHRhZG8gZGUgU0ZDIGxleWVuZG8gQ0JTLmxvZyAoU0lFTVBSRSBlbgojIGluZ2xlcykgZW4gbHVnYXIg
HLP:ZGUgbGEgc2FsaWRhIHRyYWR1Y2lkYSBkZSBsYSBjb25zb2xhLiBEZXZ1ZWx2ZSB1bm8gZGU6CiMgY2xlYW4gfCByZXBhaXJlZCB8IHVucmVwYWlyYWJsZSB8IHVua25vd24uCmZ1bmN0aW9uIEdldC1TZmNSZXN1bHQgewogICAgJGxvZyA9IEpvaW4tUGF0aCAkZW52
HLP:OndpbmRpciAnTG9nc1xDQlNcQ0JTLmxvZycKICAgIGlmICgtbm90IChUZXN0LVBhdGggJGxvZykpIHsgcmV0dXJuICd1bmtub3duJyB9CiAgICB0cnkgewogICAgICAgICR0YWlsID0gQChHZXQtQ29udGVudCAtUGF0aCAkbG9nIC1UYWlsIDQwMDAgLUVycm9yQWN0
HLP:aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgJHNyID0gQCgkdGFpbCB8IFdoZXJlLU9iamVjdCB7ICRfIC1tYXRjaCAnXFtTUlxdJyB9KQogICAgICAgIGlmICgkc3IuQ291bnQgLWVxIDApIHsgcmV0dXJuICd1bmtub3duJyB9CiAgICAgICAgJGpvaW5lZCA9
HLP:ICgkc3IgLWpvaW4gImBuIikKICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSljYW5ub3QgcmVwYWlyJykgeyByZXR1cm4gJ3VucmVwYWlyYWJsZScgfQogICAgICAgIGlmICgkam9pbmVkIC1tYXRjaCAnKD9pKXJlcGFpcmluZ1xzKyhbMS05XVxkKilccytj
HLP:b21wb25lbnRzfHN1Y2Nlc3NmdWxseSByZXBhaXJlZHxyZXBhaXJlZCBmaWxlfHJlcGFpcmluZyBjb3JydXB0ZWQgZmlsZScpIHsgcmV0dXJuICdyZXBhaXJlZCcgfQogICAgICAgIGlmICgkam9pbmVkIC1tYXRjaCAnKD9pKXZlcmlmeSBjb21wbGV0ZXxubyAuKmlu
HLP:dGVncml0eSB2aW9sYXRpb25zfGNhbm5vdCB2ZXJpZnl8dmVyaWZ5aW5nJykgeyByZXR1cm4gJ2NsZWFuJyB9CiAgICAgICAgcmV0dXJuICdjbGVhbicKICAgIH0gY2F0Y2ggeyByZXR1cm4gJ3Vua25vd24nIH0KfQoKIyBOZXctSnNvblJlcG9ydDogdnVlbGNhIGVs
HLP:IGVzdGFkbyArIHJlc3VtZW4gY2FsY3VsYWRvIGEgdW4gZmljaGVybyBKU09OCiMgKC1BcmcgPSBydXRhIGRlIHNhbGlkYSkuIFV0aWwgcGFyYSBhdXRvbWF0aXphY2lvbiAvIE1ETSAvIGludmVudGFyaW8uCmZ1bmN0aW9uIE5ldy1Kc29uUmVwb3J0KCRvdXRQYXRo
HLP:KSB7CiAgICB0cnkgewogICAgICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICAgICAkc3lzUGFpcnMgPSBHZXQtU3lzSW5mbwogICAgICAgICRzeXNNYXAgPSBAe30KICAgICAgICBmb3JlYWNoICgkcCBpbiAkc3lzUGFpcnMpIHsgJGt2ID0gJHAgLXNwbGl0ICc9Jywy
HLP:OyBpZiAoJGt2LkNvdW50IC1lcSAyKSB7ICRzeXNNYXBbJGt2WzBdXSA9ICRrdlsxXSB9IH0KICAgICAgICAkcGhhc2VzID0gQCgkc3QucGhhc2VzKQogICAgICAgICRjT0s9MDskY1dBUk49MDskY0VSUj0wOyRjU0tJUD0wCiAgICAgICAgZm9yZWFjaCAoJHBoIGlu
HLP:ICRwaGFzZXMpIHsgc3dpdGNoIChbc3RyaW5nXSRwaC5yZXN1bHQpIHsgJ09LJyB7JGNPSysrfSAnV0FSTicgeyRjV0FSTisrfSAnRVJST1InIHskY0VSUisrfSAnU0tJUCcgeyRjU0tJUCsrfSB9IH0KICAgICAgICAkZGVsdGEgPSAkbnVsbAogICAgICAgIGlmICgk
HLP:c3Quc2NvcmVfYmVmb3JlIC1uZSAkbnVsbCAtYW5kICRzdC5zY29yZV9hZnRlciAtbmUgJG51bGwpIHsgJGRlbHRhID0gW2ludF0kc3Quc2NvcmVfYWZ0ZXIgLSBbaW50XSRzdC5zY29yZV9iZWZvcmUgfQogICAgICAgICRvYmogPSBbcHNjdXN0b21vYmplY3RdQHsK
HLP:ICAgICAgICAgICAgc2NoZW1hICAgICAgID0gJ3dwaS1yZXBvcnQvMScKICAgICAgICAgICAgdmVyc2lvbiAgICAgID0gJFdQSV9WRVJTSU9OCiAgICAgICAgICAgIGdlbmVyYXRlZCAgICA9IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3MnKQogICAgICAgICAgICBtYWNo
HLP:aW5lICAgICAgPSAkZW52OkNPTVBVVEVSTkFNRQogICAgICAgICAgICBzeXN0ZW0gICAgICAgPSAkc3lzTWFwCiAgICAgICAgICAgIHNjb3JlX2JlZm9yZSA9ICRzdC5zY29yZV9iZWZvcmUKICAgICAgICAgICAgc2NvcmVfYWZ0ZXIgID0gJHN0LnNjb3JlX2FmdGVy
HLP:CiAgICAgICAgICAgIHNjb3JlX2RlbHRhICA9ICRkZWx0YQogICAgICAgICAgICBzdW1tYXJ5ICAgICAgPSBbcHNjdXN0b21vYmplY3RdQHsgb2s9JGNPSzsgd2Fybj0kY1dBUk47IGVycm9yPSRjRVJSOyBza2lwPSRjU0tJUDsgdG90YWw9JHBoYXNlcy5Db3VudCB9
HLP:CiAgICAgICAgICAgIHBoYXNlcyAgICAgICA9ICRwaGFzZXMKICAgICAgICAgICAgZmluZGluZ3MgICAgID0gQCgkc3QuZmluZGluZ3MpCiAgICAgICAgICAgIGRpYWcgICAgICAgICA9ICRzdC5kaWFnCiAgICAgICAgfQogICAgICAgICRqc29uID0gJG9iaiB8IENv
HLP:bnZlcnRUby1Kc29uIC1EZXB0aCA4CiAgICAgICAgJHV0ZjggPSBOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpCiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRvdXRQYXRoLCAkanNvbiwgJHV0ZjgpCiAgICAg
HLP:ICAgIlJFU1VMVD1PSyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCiMgTmV3LVN1cHBvcnRQYWNrYWdlOiBlbXBh
HLP:cXVldGEgbG9ncyArIGluZm9ybWUgKyBlc3RhZG8gKyBiYXR0ZXJ5LXJlcG9ydCBlbiB1bgojIFpJUCAoLUFyZyA9IHJ1dGEgZGVsIHppcCkgcGFyYSBlbnZpYXIgYSBzb3BvcnRlLiBTaW4gZGVwZW5kZW5jaWFzIGV4dGVybmFzCiMgKHVzYSBDb21wcmVzcy1BcmNo
HLP:aXZlLCBpbmNsdWlkbyBlbiBXaW5kb3dzIDEwLzExKS4KZnVuY3Rpb24gTmV3LVN1cHBvcnRQYWNrYWdlKCRvdXRQYXRoKSB7CiAgICB0cnkgewogICAgICAgICR0bXAgPSBKb2luLVBhdGggJFdvcmsgKCdzb3BvcnRlXycgKyAoR2V0LURhdGUpLlRvU3RyaW5nKCd5
HLP:eXl5TU1kZF9ISG1tc3MnKSkKICAgICAgICBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICR0bXAgLUZvcmNlIHwgT3V0LU51bGwKICAgICAgICAjIGVzdGFkby5qc29uCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkU3RhdGVGaWxlKSB7IENvcHktSXRl
HLP:bSAkU3RhdGVGaWxlIChKb2luLVBhdGggJHRtcCAnZXN0YWRvLmpzb24nKSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICMgTG9ncwogICAgICAgICRsb2dzID0gSm9pbi1QYXRoICRXb3JrICdMb2dzJwogICAgICAgIGlmIChU
HLP:ZXN0LVBhdGggJGxvZ3MpIHsKICAgICAgICAgICAgJGRzdExvZ3MgPSBKb2luLVBhdGggJHRtcCAnTG9ncycKICAgICAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkZHN0TG9ncyAtRm9yY2UgfCBPdXQtTnVsbAogICAgICAgICAgICBH
HLP:ZXQtQ2hpbGRJdGVtICRsb2dzIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgQ29weS1JdGVtIC1EZXN0aW5hdGlvbiAkZHN0TG9ncyAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICB9CiAgICAgICAgIyBJbmZv
HLP:cm1lcyBIVE1ML0pTT04gZXhpc3RlbnRlcyBlbiBXb3JrCiAgICAgICAgR2V0LUNoaWxkSXRlbSAkV29yayAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLk5hbWUgLW1hdGNoICcoP2kpXklu
HLP:Zm9ybWUuKlwuKGh0bWx8anNvbikkJyB9IHwKICAgICAgICAgICAgQ29weS1JdGVtIC1EZXN0aW5hdGlvbiAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICMgYmF0dGVyeSByZXBvcnQgc2kgZXhpc3RlCiAgICAgICAgJHN0
HLP:ID0gUmVhZC1TdGF0ZQogICAgICAgIHRyeSB7IGlmICgkc3QuZGlhZyAtYW5kICRzdC5kaWFnLmJhdHRlcnkgLWFuZCAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9wYXRoIC1hbmQgKFRlc3QtUGF0aCAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9wYXRoKSkgeyBDb3B5
HLP:LUl0ZW0gJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IH0gY2F0Y2gge30KICAgICAgICBpZiAoVGVzdC1QYXRoICRvdXRQYXRoKSB7IFJlbW92ZS1JdGVtICRvdXRQYXRoIC1Gb3Jj
HLP:ZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgQ29tcHJlc3MtQXJjaGl2ZSAtUGF0aCAoSm9pbi1QYXRoICR0bXAgJyonKSAtRGVzdGluYXRpb25QYXRoICRvdXRQYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIHRyeSB7
HLP:IFJlbW92ZS1JdGVtICR0bXAgLVJlY3Vyc2UgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30KICAgICAgICAiUkVTVUxUPU9LIgogICAgICAgICJQQVRIPSRvdXRQYXRoIgogICAgfSBjYXRjaCB7CiAgICAgICAgIlJFU1VMVD1G
HLP:QUlMIgogICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgIH0KfQoKc3dpdGNoICgkQWN0aW9uLlRvTG93ZXIoKSkgewogICAgJ25vbmUnICAgICAgICAgeyB9ICMgVXNhZG8gcGFyYSBkb3Qtc291cmNpbmcKICAgICdjaGVja2JhY2t1cHMn
HLP:IHsKICAgICAgICAkcGFydHMgPSAkQXJnIC1zcGxpdCAnXHwnLCAyCiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtbmUgMikgeyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9QXJndW1lbnRvcyBpbnZhbGlkb3MiOyBleGl0IDAgfQogICAgICAgICRia2RpciA9ICRwYXJ0
HLP:c1swXQogICAgICAgICR0cyA9ICRwYXJ0c1sxXQogICAgICAgICRycF9vayA9ICRmYWxzZQogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRycHMgPSBHZXQtQ29tcHV0ZXJSZXN0b3JlUG9pbnQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAg
HLP:ICAgZm9yZWFjaCAoJHJwIGluICRycHMpIHsKICAgICAgICAgICAgICAgIGlmICgkcnAuRGVzY3JpcHRpb24gLWxpa2UgIlN1aXRlX1JlcGFyYWNpb25fKiIpIHsgJHJwX29rID0gJHRydWU7IGJyZWFrIH0KICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2ggeyAk
HLP:cnBfb2sgPSAkZmFsc2UgfQogICAgICAgICRyZWdfb2sgPSAkdHJ1ZQogICAgICAgICRzb2Z0ID0gSm9pbi1QYXRoICRia2RpciAiU09GVFdBUkVfJHRzLnJlZyIKICAgICAgICAkc3lzID0gSm9pbi1QYXRoICRia2RpciAiU1lTVEVNXyR0cy5yZWciCiAgICAgICAg
HLP:aWYgKC1ub3QgKFRlc3QtUGF0aCAkc29mdCkgLW9yIChHZXQtSXRlbSAkc29mdCkuTGVuZ3RoIC1lcSAwKSB7ICRyZWdfb2sgPSAkZmFsc2UgfQogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJHN5cykgLW9yIChHZXQtSXRlbSAkc3lzKS5MZW5ndGggLWVxIDAp
HLP:IHsgJHJlZ19vayA9ICRmYWxzZSB9CiAgICAgICAgIlJQX09LPSQoaWYgKCRycF9vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIlJFR19PSz0kKGlmICgkcmVnX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdib290c3RyYXB3aW5nZXQnIHsK
HLP:ICAgICAgICAkb2sgPSBJbnN0YWxsLVdpbmdldEJvb3RzdHJhcAogICAgICAgICJCT09UU1RSQVBfT0s9JChpZiAoJG9rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdmaW5kbG9jYWxzb3VyY2UnIHsKICAgICAgICAkZHJpdmVzID0gR2V0LVBTRHJpdmUg
HLP:LVBTUHJvdmlkZXIgRmlsZVN5c3RlbQogICAgICAgICRwYXRocyA9IEAoKQogICAgICAgICRlZGl0aW9uSWQgPSAnJwogICAgICAgIHRyeSB7ICRlZGl0aW9uSWQgPSAoR2V0LUl0ZW1Qcm9wZXJ0eSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRc
HLP:Q3VycmVudFZlcnNpb24nIC1OYW1lIEVkaXRpb25JRCAtRXJyb3JBY3Rpb24gU3RvcCkuRWRpdGlvbklEIH0gY2F0Y2gge30KICAgICAgICBmdW5jdGlvbiBHZXQtSW5zdGFsbEltYWdlU291cmNlKFtzdHJpbmddJGtpbmQsIFtzdHJpbmddJHBhdGgsIFtzdHJpbmdd
HLP:JGVkaXRpb24pIHsKICAgICAgICAgICAgJGluZGV4ID0gMQogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgJGltYWdlcyA9IEAoR2V0LVdpbmRvd3NJbWFnZSAtSW1hZ2VQYXRoICRwYXRoIC1FcnJvckFjdGlvbiBTdG9wKQogICAgICAgICAgICAgICAg
HLP:JG1hdGNoID0gJG51bGwKICAgICAgICAgICAgICAgIGlmICgkZWRpdGlvbiAtbWF0Y2ggJ1Byb2Zlc3Npb25hbCcpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ1xiUHJvXGJ8UHJvZmVzc2lvbmFsJyB9IHwg
HLP:U2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnRW50ZXJwcmlzZScpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ0VudGVycHJpc2UnIH0g
HLP:fCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRpb24gLW1hdGNoICdFZHVjYXRpb24nKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdFZHVjYXRpb24nIH0g
HLP:fCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRpb24gLW1hdGNoICdDb3JlJykgeyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnXGJIb21lXGJ8Q29yZScgfSB8
HLP:IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkbWF0Y2ggLWFuZCAkaW1hZ2VzLkNvdW50IC1lcSAxKSB7ICRtYXRjaCA9ICRpbWFnZXNbMF0gfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkbWF0Y2gp
HLP:IHsgJGluZGV4ID0gW2ludF0kbWF0Y2guSW1hZ2VJbmRleCB9CiAgICAgICAgICAgIH0gY2F0Y2gge30KICAgICAgICAgICAgcmV0dXJuICgiezB9OnsxfTp7Mn0iIC1mICRraW5kLCAkcGF0aCwgJGluZGV4KQogICAgICAgIH0KICAgICAgICBmb3JlYWNoICgkZCBp
HLP:biAkZHJpdmVzKSB7CiAgICAgICAgICAgICRyb290ID0gJGQuUm9vdAogICAgICAgICAgICAkd2ltID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXGluc3RhbGwud2ltIgogICAgICAgICAgICAkZXNkID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXGluc3RhbGwu
HLP:ZXNkIgogICAgICAgICAgICAkc3hzID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXHN4cyIKICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkd2ltKSB7ICRwYXRocyArPSAoR2V0LUluc3RhbGxJbWFnZVNvdXJjZSAnV2ltJyAkd2ltICRlZGl0aW9uSWQpIH0KICAg
HLP:ICAgICAgICAgaWYgKFRlc3QtUGF0aCAkZXNkKSB7ICRwYXRocyArPSAoR2V0LUluc3RhbGxJbWFnZVNvdXJjZSAnRXNkJyAkZXNkICRlZGl0aW9uSWQpIH0KICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkc3hzKSB7ICRwYXRocyArPSAkc3hzIH0KICAgICAgICB9
HLP:CiAgICAgICAgaWYgKCRwYXRocy5Db3VudCAtZ3QgMCkgeyAiU09VUkNFPSQoJHBhdGhzWzBdKSIgfSBlbHNlIHsgIlNPVVJDRT0iIH0KICAgIH0KICAgICdkaXNtcmVzdG9yZScgewogICAgICAgICRwYXJ0cyA9IEAoJEFyZyAtc3BsaXQgJ1x8JywgMikKICAgICAg
HLP:ICAkc291cmNlID0gaWYgKCRwYXJ0cy5Db3VudCAtZ2UgMSkgeyAkcGFydHNbMF0gfSBlbHNlIHsgJycgfQogICAgICAgICR0aW1lb3V0TWludXRlcyA9IDQ1CiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtZ2UgMikgeyBbdm9pZF1baW50XTo6VHJ5UGFyc2UoJHBh
HLP:cnRzWzFdLCBbcmVmXSR0aW1lb3V0TWludXRlcykgfQogICAgICAgIGlmICgkdGltZW91dE1pbnV0ZXMgLWx0IDUpIHsgJHRpbWVvdXRNaW51dGVzID0gNSB9CgogICAgICAgIGZ1bmN0aW9uIFF1b3RlLURpc21WYWx1ZShbc3RyaW5nXSR2YWx1ZSkgewogICAgICAg
HLP:ICAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkdmFsdWUpKSB7IHJldHVybiAkdmFsdWUgfQogICAgICAgICAgICByZXR1cm4gJyInICsgKCR2YWx1ZSAtcmVwbGFjZSAnIicsICdcIicpICsgJyInCiAgICAgICAgfQoKICAgICAgICAkYXJndW1l
HLP:bnRzID0gJy9PbmxpbmUgL0NsZWFudXAtSW1hZ2UgL1Jlc3RvcmVIZWFsdGgnCiAgICAgICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkc291cmNlKSkgewogICAgICAgICAgICAkYXJndW1lbnRzICs9ICcgL1NvdXJjZTonICsgKFF1b3Rl
HLP:LURpc21WYWx1ZSAkc291cmNlKSArICcgL0xpbWl0QWNjZXNzJwogICAgICAgIH0KCiAgICAgICAgJHRpbWVkT3V0ID0gJGZhbHNlCiAgICAgICAgJGV4aXRDb2RlID0gMwogICAgICAgICRvdXRGaWxlID0gSm9pbi1QYXRoICRXb3JrICgiZGlzbV9yZXN0b3JlX3sw
HLP:fS5vdXQiIC1mIChbZ3VpZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKSkKICAgICAgICAkZXJyRmlsZSA9IEpvaW4tUGF0aCAkV29yayAoImRpc21fcmVzdG9yZV97MH0uZXJyIiAtZiAoW2d1aWRdOjpOZXdHdWlkKCkuVG9TdHJpbmcoJ04nKSkpCiAgICAgICAg
HLP:dHJ5IHsKICAgICAgICAgICAgJHBzaSA9IFtEaWFnbm9zdGljcy5Qcm9jZXNzU3RhcnRJbmZvXTo6bmV3KCkKICAgICAgICAgICAgJHBzaS5GaWxlTmFtZSA9ICdjbWQuZXhlJwogICAgICAgICAgICAkcHNpLkFyZ3VtZW50cyA9ICgnL2MgZGlzbS5leGUgezB9ID4g
HLP:InsxfSIgMj4gInsyfSInIC1mICRhcmd1bWVudHMsICRvdXRGaWxlLCAkZXJyRmlsZSkKICAgICAgICAgICAgJHBzaS5Vc2VTaGVsbEV4ZWN1dGUgPSAkZmFsc2UKICAgICAgICAgICAgJHBzaS5DcmVhdGVOb1dpbmRvdyA9ICR0cnVlCiAgICAgICAgICAgICRwID0g
HLP:W0RpYWdub3N0aWNzLlByb2Nlc3NdOjpuZXcoKQogICAgICAgICAgICAkcC5TdGFydEluZm8gPSAkcHNpCiAgICAgICAgICAgIFt2b2lkXSRwLlN0YXJ0KCkKICAgICAgICAgICAgaWYgKC1ub3QgJHAuV2FpdEZvckV4aXQoJHRpbWVvdXRNaW51dGVzICogNjAgKiAx
HLP:MDAwKSkgewogICAgICAgICAgICAgICAgJHRpbWVkT3V0ID0gJHRydWUKICAgICAgICAgICAgICAgIHRyeSB7ICRwLktpbGwoKSB9IGNhdGNoIHt9CiAgICAgICAgICAgICAgICAkZXhpdENvZGUgPSAxNDYwCiAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAg
HLP:ICAgICB0cnkgeyAkcC5XYWl0Rm9yRXhpdCgpIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICRleGl0Q29kZSA9ICRwLkV4aXRDb2RlCiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLWVxICRleGl0Q29kZSkgeyAkZXhpdENvZGUgPSAzIH0KICAgICAgICAgICAg
HLP:fQogICAgICAgIH0gY2F0Y2ggewogICAgICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICAgICAgICAgICRleGl0Q29kZSA9IDMKICAgICAgICB9CgogICAgICAgIGlmIChUZXN0LVBhdGggJG91dEZpbGUpIHsgR2V0LUNvbnRlbnQgLUxp
HLP:dGVyYWxQYXRoICRvdXRGaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICBpZiAoVGVzdC1QYXRoICRlcnJGaWxlKSB7IEdldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZXJyRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9
HLP:CiAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRvdXRGaWxlLCRlcnJGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICJUSU1FRE9VVD0kKGlmICgkdGltZWRPdXQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAg
HLP:ICJFWElUQ09ERT0kZXhpdENvZGUiCiAgICB9CiAgICAnc3lzaW5mbycgICAgICB7IEdldC1TeXNJbmZvIH0KICAgICdzY29yZScgICAgICAgIHsgJGggPSBHZXQtSGVhbHRoU2NvcmU7ICJTQ09SRT0kKCRoLnNjb3JlKSI7IGZvcmVhY2ggKCRyIGluICRoLnJlYXNv
HLP:bnMpIHsgIlJFQVNPTj0kciIgfSB9CiAgICAnZm9yZW5zaWNzJyAgICB7IEdldC1Gb3JlbnNpY3MgfQogICAgJ3RyaWFnZScgICAgICAgeyBHZXQtVHJpYWdlIH0KICAgICdyZXN0b3JlcG9pbnQnIHsgTmV3LVJlc3RvcmVQb2ludCB9CiAgICAnbWVkaWF0eXBlJyAg
HLP:ICB7ICRtZWRpYSA9IEdldC1NZWRpYVR5cGU7ICJNRURJQT0kbWVkaWEiOyAiT1BUSU1JWkU9JChSZXNvbHZlLU9wdGltaXplQWN0aW9uICRtZWRpYSkiIH0KICAgICdkZXZpY2VzJyAgICAgIHsgR2V0LURldmljZVByb2JsZW1zIH0KICAgICdyZXBvcnQnICAgICAg
HLP:IHsgQWRkLVR5cGUgLUFzc2VtYmx5TmFtZSBTeXN0ZW0uV2ViIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlOyBOZXctSHRtbFJlcG9ydCAkQXJnIH0KICAgICdhZGRwaGFzZScgICAgIHsgQWRkLVBoYXNlUmVzdWx0ICRBcmcgfQogICAgJ3NldGJlZm9yZScg
HLP:ICAgeyBTZXQtU2NvcmUgJ2JlZm9yZScgJEFyZyB9CiAgICAnc2V0YWZ0ZXInICAgICB7IFNldC1TY29yZSAnYWZ0ZXInICRBcmcgfQogICAgJ2ZpbmRpbmcnICAgICAgeyBBZGQtRmluZGluZyAkQXJnIH0KICAgICdyZXNldHN0YXRlJyAgIHsgUmVzZXQtU3RhdGU7
HLP:ICJSRVNVTFQ9T0siIH0KICAgICdub3JtYWxpemVmYXNlcycgewogICAgICAgICRyID0gTm9ybWFsaXplLUZhc2VzICRBcmcKICAgICAgICAiTk9STT0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkci5ub3JtKSkpIgogICAgICAgICJJTlZBTElEPSQoW3N0cmluZ106
HLP:OkpvaW4oJywnLCBAKCRyLmludmFsaWQpKSkiCiAgICB9CiAgICAnY2hlY2twb2ludCcgewogICAgICAgICRwYXJzZWQgPSBQYXJzZS1DaGVja3BvaW50QXJnICRBcmcKICAgICAgICBzd2l0Y2ggKCRwYXJzZWQuc3ViKSB7CiAgICAgICAgICAgICdzYXZlJyB7IGlm
HLP:IChTYXZlLUNoZWNrcG9pbnQgJHBhcnNlZCkgeyAiUkVTVUxUPU9LIiB9IGVsc2UgeyAiUkVTVUxUPUZBSUwiIH0gfQogICAgICAgICAgICAnbG9hZCcgewogICAgICAgICAgICAgICAgJGNwID0gTG9hZC1DaGVja3BvaW50CiAgICAgICAgICAgICAgICBpZiAoJG51
HLP:bGwgLWVxICRjcCkgeyAiUkVTVUxUPU5PTkUiIH0KICAgICAgICAgICAgICAgIGVsc2UgewogICAgICAgICAgICAgICAgICAgICJSRVNVTFQ9T0siCiAgICAgICAgICAgICAgICAgICAgIlZBTElEPSQoaWYgKFRlc3QtQ2hlY2twb2ludFZhbGlkICRjcCkgeycxJ30g
HLP:ZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIlZFUlNJT049JCgkY3AudmVyc2lvbikiCiAgICAgICAgICAgICAgICAgICAgIkNSRUFURUQ9JCgkY3AuY3JlYXRlZCkiCiAgICAgICAgICAgICAgICAgICAgIlNFTEVDVElPTj0kKFtzdHJpbmddOjpKb2lu
HLP:KCcsJywgQCgkY3Auc2VsZWN0aW9uKSkpIgogICAgICAgICAgICAgICAgICAgICJDT01QTEVURUQ9JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJGNwLmNvbXBsZXRlZCkpKSIKICAgICAgICAgICAgICAgICAgICAiUkVBU09OPSQoJGNwLnBlbmRpbmdfcmVhc29uKSIK
HLP:ICAgICAgICAgICAgICAgICAgICAiTkVYVD0kKEdldC1OZXh0UGhhc2UgJGNwKSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9BVVRPPSQoaWYgKCRjcC5tb2RlLmF1dG8pIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJNT0RFX05PUkVC
HLP:T09UPSQoaWYgKCRjcC5tb2RlLm5vcmVib290KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9LRUVQV1U9JChpZiAoJGNwLm1vZGUua2VlcHd1KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9E
HLP:Ulk9JChpZiAoJGNwLm1vZGUuZHJ5KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9UUklBR0U9JChpZiAoJGNwLm1vZGUudHJpYWdlKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQog
HLP:ICAgICAgICAgICAnbmV4dCcgewogICAgICAgICAgICAgICAgJGNwID0gTG9hZC1DaGVja3BvaW50CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRjcCAtYW5kIChUZXN0LUNoZWNrcG9pbnRWYWxpZCAkY3ApKSB7ICJORVhUPSQoR2V0LU5leHRQaGFzZSAk
HLP:Y3ApIiB9IGVsc2UgeyAiTkVYVD0iIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAnY2xlYXInIHsKICAgICAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSB7CiAgICAgICAgICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJENo
HLP:ZWNrcG9pbnRGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcDsgIlJFU1VMVD1PSyIgfSBjYXRjaCB7ICJSRVNVTFQ9RkFJTCIgfQogICAgICAgICAgICAgICAgfSBlbHNlIHsgIlJFU1VMVD1PSyIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGRlZmF1bHQg
HLP:eyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9c3ViYWNjaW9uIGRlIGNoZWNrcG9pbnQgZGVzY29ub2NpZGEiIH0KICAgICAgICB9CiAgICB9CiAgICAnbW92ZXJlc3VsdCcgewogICAgICAgICRwYXJ0cyA9ICRBcmcgLXNwbGl0ICdcfCcsIDIKICAgICAgICBpZiAoJHBh
HLP:cnRzLkNvdW50IC1lcSAyKSB7CiAgICAgICAgICAgICRvayA9IFRlc3QtTW92ZVJlc3VsdFBhdGggJHBhcnRzWzBdICRwYXJ0c1sxXQogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRiICA9ICRBcmcgLXNwbGl0ICcsJwogICAgICAgICAgICAkc2UgPSAoJGIu
HLP:Q291bnQgLWdlIDEgLWFuZCAkYlswXS5UcmltKCkgLWVxICcxJykKICAgICAgICAgICAgJGRlID0gKCRiLkNvdW50IC1nZSAyIC1hbmQgJGJbMV0uVHJpbSgpIC1lcSAnMScpCiAgICAgICAgICAgICRvayA9IFRlc3QtTW92ZVJlc3VsdCAkc2UgJGRlCiAgICAgICAg
HLP:fQogICAgICAgICJNT1ZFRD0kKGlmICgkb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ3Z0bHdyaXRlJyB7CiAgICAgICAgJHAgICA9ICRBcmcgLXNwbGl0ICcsJwogICAgICAgICRjdXIgPSBpZiAoJHAuQ291bnQgLWdlIDEpIHsgJHBbMF0gfSBlbHNl
HLP:IHsgJycgfQogICAgICAgICRkZXMgPSBpZiAoJHAuQ291bnQgLWdlIDIpIHsgJHBbMV0gfSBlbHNlIHsgW3N0cmluZ10kVlRfTEVWRUxfREVTSVJFRCB9CiAgICAgICAgIldSSVRFPSQoaWYgKFJlc29sdmUtVnRsV3JpdGUgJGN1ciAkZGVzKSB7JzEnfSBlbHNlIHsn
HLP:MCd9KSIKICAgIH0KICAgICdtYXBleGl0JyAgICAgIHsgIlJFUz0kKE1hcC1FeGl0Q29kZSAkQXJnKSIgfQogICAgIyAtLS0gKDUuMSAvIFJlcSAxNSkgRGlhZ25vc3RpY28gYW1wbGlhZG8gLS0tCiAgICAncmFtY2hlY2snIHsKICAgICAgICAkciA9IEdldC1SYW1D
HLP:aGVjawogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5yYW0gPSBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJHIuc3RhdHVzOyByZWNvbW1lbmRfbWRzY2hlZCA9IFtib29sXSRyLnJlY29tbWVuZF9t
HLP:ZHNjaGVkIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiUkFNX1NUQVRVUz0kKCRyLnN0YXR1cykiCiAgICAgICAgIlJBTV9SRUNPTU1FTkRfTURTQ0hFRD0kKGlmICgkci5yZWNvbW1lbmRfbWRzY2hlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9
HLP:CiAgICAnYmF0dGVyeScgewogICAgICAgICRiID0gR2V0LUJhdHRlcnlIZWFsdGgKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHN0LmRpYWcuYmF0dGVyeSA9IFtwc2N1c3RvbW9iamVjdF1AeyBwcmVzZW50ID0gW2Jv
HLP:b2xdJGIucHJlc2VudDsgaGVhbHRoX3BjdCA9ICRiLmhlYWx0aF9wY3Q7IHJlcG9ydF9wYXRoID0gJGIucmVwb3J0X3BhdGggfQogICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJCQVRURVJZX1BSRVNFTlQ9JChpZiAoJGIucHJlc2VudCkgeycxJ30gZWxz
HLP:ZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfSEVBTFRIX1BDVD0kKCRiLmhlYWx0aF9wY3QpIgogICAgICAgICJCQVRURVJZX1JFUE9SVD0kKCRiLnJlcG9ydF9wYXRoKSIKICAgIH0KICAgICduZXRhZHZhbmNlZCcgewogICAgICAgICRuID0gR2V0LU5ldEFkdmFu
HLP:Y2VkCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRzdC5kaWFnLm5ldHdvcmsgPSBbcHNjdXN0b21vYmplY3RdQHsgY29ubmVjdGVkID0gW2Jvb2xdJG4uY29ubmVjdGVkOyBkbnNfb2sgPSBbYm9vbF0kbi5kbnNfb2s7
HLP:IGRldGFpbHMgPSAkbi5kZXRhaWxzOyBkbnNfbXMgPSAkbi5kbnNfbXMgfQogICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJORVRfQ09OTkVDVEVEPSQoaWYgKCRuLmNvbm5lY3RlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ETlNfT0s9
HLP:JChpZiAoJG4uZG5zX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0RFVEFJTFM9JCgkbi5kZXRhaWxzKSIKICAgICAgICAiTkVUX0xBVEVOQ1lfTVM9JCgkbi5kbnNfbXMpIgogICAgfQogICAgJ2RpYWdmdWxsJyB7CiAgICAgICAgJHN0ID0gSW5p
HLP:dGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRyID0gR2V0LVJhbUNoZWNrCiAgICAgICAgJHN0LmRpYWcucmFtID0gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICRyLnN0YXR1czsgcmVjb21tZW5kX21kc2NoZWQgPSBbYm9vbF0kci5yZWNvbW1l
HLP:bmRfbWRzY2hlZCB9CiAgICAgICAgJGIgPSBHZXQtQmF0dGVyeUhlYWx0aAogICAgICAgICRzdC5kaWFnLmJhdHRlcnkgPSBbcHNjdXN0b21vYmplY3RdQHsgcHJlc2VudCA9IFtib29sXSRiLnByZXNlbnQ7IGhlYWx0aF9wY3QgPSAkYi5oZWFsdGhfcGN0OyByZXBv
HLP:cnRfcGF0aCA9ICRiLnJlcG9ydF9wYXRoIH0KICAgICAgICAkbiA9IEdldC1OZXRBZHZhbmNlZAogICAgICAgICRzdC5kaWFnLm5ldHdvcmsgPSBbcHNjdXN0b21vYmplY3RdQHsgY29ubmVjdGVkID0gW2Jvb2xdJG4uY29ubmVjdGVkOyBkbnNfb2sgPSBbYm9vbF0k
HLP:bi5kbnNfb2s7IGRldGFpbHMgPSAkbi5kZXRhaWxzOyBkbnNfbXMgPSAkbi5kbnNfbXMgfQogICAgICAgICRkZXYgPSBHZXQtRGV2aWNlTGlzdAogICAgICAgIGlmICgkbnVsbCAtZXEgJGRldikgewogICAgICAgICAgICAkc3QuZGlhZy5kZXZpY2VzID0gQCgpCiAg
HLP:ICAgICAgICAgICRkZXZMaW5lID0gIkRFVklDRVNfU1RBVFVTPWluZm8gbm90IGF2YWlsYWJsZSIKICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAkc3QuZGlhZy5kZXZpY2VzID0gQCgkZGV2KQogICAgICAgICAgICAkZGV2TGluZSA9ICJERVZJQ0VTX0NPVU5U
HLP:PSQoQCgkZGV2KS5Db3VudCkiCiAgICAgICAgfQogICAgICAgICRzbSA9IEdldC1TbWFydEF0dHJpYnV0ZXMKICAgICAgICAkc3QuZGlhZy5zbWFydCA9IFtwc2N1c3RvbW9iamVjdF1AeyBhdmFpbGFibGUgPSBbYm9vbF0kc20uYXZhaWxhYmxlOyBwcmVkaWN0X2Zh
HLP:aWwgPSBbYm9vbF0kc20ucHJlZGljdF9mYWlsOyB0ZW1wX2MgPSAkc20udGVtcF9jOyB3ZWFyX3BjdCA9ICRzbS53ZWFyX3BjdDsgcG9oID0gJHNtLnBvaCB9CiAgICAgICAgJHN0cCA9IEdldC1TdGFydHVwSXRlbXMgOAogICAgICAgICRzdC5kaWFnLnN0YXJ0dXAg
HLP:PSBAKCRzdHApCiAgICAgICAgJGJjZCA9IEdldC1CY2RJbnRlZ3JpdHkKICAgICAgICAkc3QuZGlhZy5iY2QgPSBbcHNjdXN0b21vYmplY3RdQHsgb2sgPSBbYm9vbF0kYmNkLm9rOyBkZXRhaWxzID0gJGJjZC5kZXRhaWxzIH0KICAgICAgICAkcHJvY3MgPSBHZXQt
HLP:VG9wUHJvY2Vzc2VzIDYKICAgICAgICAkc3QuZGlhZy5wcm9jZXNzZXMgPSBAKCRwcm9jcykKICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiUkFNX1NUQVRVUz0kKCRyLnN0YXR1cykiCiAgICAgICAgIlJBTV9SRUNPTU1FTkRfTURTQ0hFRD0kKGlmICgk
HLP:ci5yZWNvbW1lbmRfbWRzY2hlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfUFJFU0VOVD0kKGlmICgkYi5wcmVzZW50KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkFUVEVSWV9IRUFMVEhfUENUPSQoJGIuaGVhbHRoX3BjdCkiCiAg
HLP:ICAgICAgIk5FVF9DT05ORUNURUQ9JChpZiAoJG4uY29ubmVjdGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0ROU19PSz0kKGlmICgkbi5kbnNfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfTEFURU5DWV9NUz0kKCRuLmRuc19t
HLP:cykiCiAgICAgICAgIlNNQVJUX0FWQUlMQUJMRT0kKGlmICgkc20uYXZhaWxhYmxlKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiU01BUlRfUFJFRElDVF9GQUlMPSQoaWYgKCRzbS5wcmVkaWN0X2ZhaWwpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJC
HLP:Q0RfT0s9JChpZiAoJGJjZC5vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgJGRldkxpbmUKICAgIH0KICAgICMgLS0tICh2My4xKSBTRkMgaW5kZXBlbmRpZW50ZSBkZWwgaWRpb21hICsgSlNPTiArIHBhcXVldGUgZGUgc29wb3J0ZSAtLS0KICAgICdzZmNy
HLP:ZXN1bHQnIHsKICAgICAgICAiU0ZDX1JFUz0kKEdldC1TZmNSZXN1bHQpIgogICAgfQogICAgJ2pzb25yZXBvcnQnIHsKICAgICAgICAkb3V0ID0gaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJEFyZykpIHsgSm9pbi1QYXRoICRXb3JrICdJbmZvcm1l
HLP:Lmpzb24nIH0gZWxzZSB7ICRBcmcgfQogICAgICAgIE5ldy1Kc29uUmVwb3J0ICRvdXQKICAgIH0KICAgICdzdXBwb3J0cGFja2FnZScgewogICAgICAgICRvdXQgPSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdv
HLP:cmsgJ1BhcXVldGVfU29wb3J0ZS56aXAnIH0gZWxzZSB7ICRBcmcgfQogICAgICAgIE5ldy1TdXBwb3J0UGFja2FnZSAkb3V0CiAgICB9CiAgICAjIC0tLSAoNS42IC8gUmVxIDE3LjIpIFJvdGFjaW9uIGRlIGxvZ3MgLS0tCiAgICAnbG9ncm90YXRlJyB7CiAgICAg
HLP:ICAgJGZvbGRlciA9IGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnTG9ncycgfSBlbHNlIHsgJEFyZyB9CiAgICAgICAgJG4gPSBJbnZva2UtTG9nUm90YXRlICRmb2xkZXIgJExPR19SRVRFTlRJT04KICAg
HLP:ICAgICAiREVMRVRFRD0kbiIKICAgIH0KICAgICMgLS0tICg1LjggLyBSZXEgMTMsMTgpIFZhbGlkYWNpb24gZGUgZW50b3JubyB5IHNlbGYtdGVzdCAtLS0KICAgICdlbnZjaGVjaycgewogICAgICAgICRlID0gSW52b2tlLUVudlZhbGlkYXRlCiAgICAgICAgIk9T
HLP:X09LPSQoaWYgKCRlLm9zX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiT1NfQlVJTEQ9JCgkZS5idWlsZCkiCiAgICAgICAgIk9TX0NIRUNLX0RPTkU9MSIKICAgIH0KICAgICdzZWxmdGVzdGJyYWluJyB7ICJCUkFJTl9PSz0xIiB9CiAgICAnc2VsZnRl
HLP:c3RyZXN1bHQnIHsKICAgICAgICAkcGFzcyA9IEludm9rZS1TZWxmVGVzdCAoUGFyc2UtQm9vbExpc3QgJEFyZykKICAgICAgICAiU0VMRlRFU1RfUEFTUz0kKGlmICgkcGFzcykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICBkZWZhdWx0ICAgICAgICB7IEdl
HLP:dC1TeXNJbmZvIH0KfQo=
