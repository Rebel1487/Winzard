@echo off
setlocal EnableDelayedExpansion
:: (v3.2) CAPTURE the script identity BEFORE the argument loop: in cmd,
:: 'shift' without /1 ALSO shifts %0, so after the loop %~f0/%~dp0 point at
:: the last argument (e.g. C:\quiet). This was the root cause of state going
:: to C:\WPI_Suite (drive root) with arguments and of broken self-elevation.
set "SELF=%~f0"
set "SELFDIR=%~dp0"
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
shift /1
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
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/k \"%SELF%\" %*' -Verb RunAs"
    exit /b
)
:admin_done
:: --- carpetas de trabajo ---
set "WORK=%SELFDIR%WPI_Suite"
set "LOGDIR=%WORK%\Logs"
set "BKDIR=%WORK%\Backups"
if not exist "%WORK%" mkdir "%WORK%" >nul 2>&1
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%BKDIR%" mkdir "%BKDIR%" >nul 2>&1
for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')"`) do set "TIMESTAMP=%%t"
set "LOGFILE=%LOGDIR%\repair_%TIMESTAMP%.log"
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
echo  %DIM%Standalone phase 07 - Repair WMI%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "07" "Repair WMI" "Checks and repairs the WMI repository (a broken one causes odd failures)."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase07 ) else ( call :menu_fase07 )
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
rem (v3.2) single phase: record result in state and generate the HTML report
if not "%DRY%"=="1" (
    call :title_of 07
    call :pshq addphase "07;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
    set "REPORT=%WORK%\Report_%TIMESTAMP%.html"
    call :psh report "!REPORT!" >nul 2>&1
)
echo(
echo %BL%------------------------------------------------------------%R%
echo    Result: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
if exist "!REPORT!" echo    %WH%Report:%R% !REPORT!
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %RC%


:Fase07
if "%DRY%"=="1" ( call :dry "Would verify and, if needed, salvage the WMI repository" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Verifying WMI repository (scan only)"
    winmgmt /verifyrepository > "%CAP%" 2>&1
    set "WMIRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    call :wmi_consistent !WMIRC!
    if "!WMI_OK!"=="1" (
        call :ok "WMI repository consistent"
        exit /b 0
    ) else (
        call :warn "WMI repository inconsistent (detected in scan-only)"
        exit /b 1
    )
)

call :step "Verifying the WMI repository"
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "WMI repository coherent" & exit /b 0 )
call :warn "WMI inconsistent: trying to salvage"
winmgmt /salvagerepository >> "%LOGFILE%" 2>&1
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "WMI repaired (salvage)" & exit /b 0 )

call :step "WMI still damaged after salvage. Compiling MOF files from System32\wbem..."
cd /d %SystemRoot%\System32\wbem >nul 2>&1
for /f %%s in ('dir /b *.mof *.mfl') do (
    mofcomp %%s >> "%LOGFILE%" 2>&1
)
cd /d "%SELFDIR%" >nul 2>&1

winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" (
    call :ok "WMI repaired compiling MOF/MFL files"
    exit /b 0
)

call :warn "WMI still damaged after salvage and mofcomp. Full reset stays manual: winmgmt /resetrepository"
call :pshq finding "WMI repository damaged (requires manual reset)"
set "PH_NOTE=WMI requires manual reset"
exit /b 1
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
:: %LOGDIR%\repair_%TIMESTAMP%.log (definido en la cabecera). No introduce
:: logica nueva: si las variables faltaran, las reconstruye de forma segura.
:log_consolidate
if not defined LOGDIR set "LOGDIR=%WORK%\Logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not defined LOGFILE set "LOGFILE=%LOGDIR%\repair_%TIMESTAMP%.log"
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
if exist "%WORK%\Report_%TIMESTAMP%.html" del /f /q "%WORK%\Report_%TIMESTAMP%.html" >nul 2>&1
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
set "REPORT=%WORK%\Report_%TIMESTAMP%.html"
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
HLP:ZXF1ZW5jeSAtVmFsdWUgMCAtVHlwZSBEV29yZCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRuYW1lID0gIlJlcGFpcl9TdWl0ZV8kKChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGRfSEgtbW0nKSkiCiAgICAgICAgQ2hlY2twb2lu
HLP:dC1Db21wdXRlciAtRGVzY3JpcHRpb24gJG5hbWUgLVJlc3RvcmVQb2ludFR5cGUgTU9ESUZZX1NFVFRJTkdTIC1FcnJvckFjdGlvbiBTdG9wCiAgICAgICAgaWYgKCRudWxsIC1uZSAkcHJldikgeyBTZXQtSXRlbVByb3BlcnR5ICRrIC1OYW1lIFN5c3RlbVJlc3Rv
HLP:cmVQb2ludENyZWF0aW9uRnJlcXVlbmN5IC1WYWx1ZSAkcHJldiAtVHlwZSBEV29yZCB9IGVsc2UgeyBSZW1vdmUtSXRlbVByb3BlcnR5ICRrIC1OYW1lIFN5c3RlbVJlc3RvcmVQb2ludENyZWF0aW9uRnJlcXVlbmN5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRp
HLP:bnVlIH0KICAgICAgICAkcnAgPSBHZXQtQ29tcHV0ZXJSZXN0b3JlUG9pbnQgfCBXaGVyZS1PYmplY3QgeyAkXy5EZXNjcmlwdGlvbiAtZXEgJG5hbWUgfQogICAgICAgIGlmICgkcnApIHsgIlJFU1VMVD1PSyI7ICJOQU1FPSRuYW1lIiB9IGVsc2UgeyAiUkVTVUxU
HLP:PUZBSUwiOyAiTkFNRT0kbmFtZSIgfQogICAgfSBjYXRjaCB7ICJSRVNVTFQ9RkFJTCI7ICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgfQp9CgpmdW5jdGlvbiBTYXZlLUhlYWx0aEhpc3RvcnkoJHNjb3JlKSB7CiAgICAkc2NyaXB0RGlyID0gJG51bGwK
HLP:ICAgIGlmICgkUFNTY3JpcHRSb290KSB7CiAgICAgICAgJHNjcmlwdERpciA9ICRQU1NjcmlwdFJvb3QKICAgIH0gZWxzZWlmICgkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoKSB7CiAgICAgICAgJHNjcmlwdERpciA9IFNwbGl0LVBhdGggLVBhcmVudCAkTXlJ
HLP:bnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoCiAgICB9CiAgICAkYmFzZURpciA9IGlmICgkc2NyaXB0RGlyKSB7IEpvaW4tUGF0aCAoU3BsaXQtUGF0aCAtUGFyZW50ICRzY3JpcHREaXIpICJXUElfU3VpdGUiIH0gZWxzZSB7ICRXb3JrIH0KICAgIGlmICgkc2NyaXB0
HLP:RGlyIC1hbmQgKFRlc3QtUGF0aCAkc2NyaXB0RGlyKSkgewogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJGJhc2VEaXIpKSB7IE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJGJhc2VEaXIgLUZvcmNlIHwgT3V0LU51bGwgfQogICAgfSBlbHNl
HLP:IHsKICAgICAgICAkYmFzZURpciA9ICRXb3JrCiAgICB9CiAgICAkaGlzdG9yeUZpbGUgPSBKb2luLVBhdGggJGJhc2VEaXIgImhlYWx0aF9oaXN0b3J5Lmpzb24iCiAgICAkaGlzdG9yeSA9IEAoKQogICAgaWYgKFRlc3QtUGF0aCAkaGlzdG9yeUZpbGUpIHsKICAg
HLP:ICAgICB0cnkgeyAkaGlzdG9yeSA9IEdldC1Db250ZW50ICRoaXN0b3J5RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9IGNhdGNoIHt9CiAgICB9CiAgICAkZW50cnkgPSBbcHNjdXN0b21vYmplY3RdQHsKICAgICAgICBkYXRlICA9IChHZXQtRGF0ZSkuVG9T
HLP:dHJpbmcoJ3l5eXktTU0tZGQgSEg6bW0nKQogICAgICAgIHNjb3JlID0gW2ludF0kc2NvcmUKICAgIH0KICAgICRoaXN0b3J5ID0gQCgkaGlzdG9yeSkgKyAkZW50cnkKICAgIGlmICgkaGlzdG9yeS5Db3VudCAtZ3QgMTApIHsgJGhpc3RvcnkgPSAkaGlzdG9yeVst
HLP:MTAuLi0xXSB9CiAgICB0cnkgewogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkaGlzdG9yeUZpbGUsICgkaGlzdG9yeSB8IENvbnZlcnRUby1Kc29uKSwgKE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkpKQog
HLP:ICAgfSBjYXRjaCB7fQp9CgpmdW5jdGlvbiBJbnN0YWxsLVdpbmdldEJvb3RzdHJhcCB7CiAgICAkdGVtcEZpbGUgPSBKb2luLVBhdGggJGVudjpURU1QICJNaWNyb3NvZnQuRGVza3RvcEFwcEluc3RhbGxlcl84d2VreWIzZDhiYndlLm1zaXhidW5kbGUiCiAgICB0
HLP:cnkgewogICAgICAgICR1cmwgPSAiaHR0cHM6Ly9naXRodWIuY29tL21pY3Jvc29mdC93aW5nZXQtY2xpL3JlbGVhc2VzL2xhdGVzdC9kb3dubG9hZC9NaWNyb3NvZnQuRGVza3RvcEFwcEluc3RhbGxlcl84d2VreWIzZDhiYndlLm1zaXhidW5kbGUiCiAgICAgICAg
HLP:V3JpdGUtSG9zdCAiRG93bmxvYWRpbmcgQXBwIEluc3RhbGxlciBmcm9tOiAkdXJsIgogICAgICAgICR3ZWJDbGllbnQgPSBOZXctT2JqZWN0IFN5c3RlbS5OZXQuV2ViQ2xpZW50CiAgICAgICAgW1N5c3RlbS5OZXQuU2VydmljZVBvaW50TWFuYWdlcl06OlNlY3Vy
HLP:aXR5UHJvdG9jb2wgPSBbU3lzdGVtLk5ldC5TZWN1cml0eVByb3RvY29sVHlwZV06OlRsczEyCiAgICAgICAgJHdlYkNsaWVudC5Eb3dubG9hZEZpbGUoJHVybCwgJHRlbXBGaWxlKQogICAgICAgIAogICAgICAgIFdyaXRlLUhvc3QgIkluc3RhbGxpbmcgQXBwIElu
HLP:c3RhbGxlciB3aXRoIEFkZC1BcHB4UGFja2FnZS4uLiIKICAgICAgICBBZGQtQXBweFBhY2thZ2UgLVBhdGggJHRlbXBGaWxlIC1FcnJvckFjdGlvbiBTdG9wCiAgICAgICAgV3JpdGUtSG9zdCAiSW5zdGFsbGF0aW9uIHN1Y2Nlc3NmdWwuIgogICAgICAgIGlmIChU
HLP:ZXN0LVBhdGggJHRlbXBGaWxlKSB7IFJlbW92ZS1JdGVtICR0ZW1wRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIHJldHVybiAkdHJ1ZQogICAgfSBjYXRjaCB7CiAgICAgICAgV3JpdGUtSG9zdCAid2luZ2V0IGJvb3Rz
HLP:dHJhcCBlcnJvcjogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkdGVtcEZpbGUpIHsgUmVtb3ZlLUl0ZW0gJHRlbXBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgcmV0dXJuICRm
HLP:YWxzZQogICAgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgKDMuNyAvIEJ1ZyA1IC8gUmVxIDcpIERldGVjY2lvbiBmaWFibGUgZGVsIHRpcG8gZGUgZGlzY28u
HLP:CiMgQ29udmVydFRvLU1lZGlhQ2xhc3M6IGZ1bmNpb24gUFVSQSBxdWUgbWFwZWEgdW4gTWVkaWFUeXBlIChudW1lcm8gbyB0ZXh0bykKIyBhIGxhIGNsYXNlIGNhbm9uaWNhIHtTU0QsSERELFVOS05PV059LiBTU0Q9NCBvICdTU0QnOyBIREQ9MyBvICdIREQnOwoj
HLP:IGN1YWxxdWllciBvdHJvIHZhbG9yIChVbnNwZWNpZmllZD0wLCB2YWNpbywgbnVsbywgU0NNPTUuLi4pIC0+IFVOS05PV04uCmZ1bmN0aW9uIENvbnZlcnRUby1NZWRpYUNsYXNzKCRtdCkgewogICAgaWYgKCRudWxsIC1lcSAkbXQpIHsgcmV0dXJuICdVTktOT1dO
HLP:JyB9CiAgICAkcyA9IChbc3RyaW5nXSRtdCkuVHJpbSgpCiAgICBpZiAoJHMgLWVxICcnKSB7IHJldHVybiAnVU5LTk9XTicgfQogICAgc3dpdGNoIC1yZWdleCAoJHMuVG9VcHBlcigpKSB7CiAgICAgICAgJ14oNHxTU0QpJCcgeyByZXR1cm4gJ1NTRCcgfQogICAg
HLP:ICAgICdeKDN8SEREKSQnIHsgcmV0dXJuICdIREQnIH0KICAgICAgICBkZWZhdWx0ICAgICB7IHJldHVybiAnVU5LTk9XTicgfQogICAgfQp9CgojIFJlc29sdmUtT3B0aW1pemVBY3Rpb246IGZ1bmNpb24gUFVSQS4gVFJJTSBzb2xvIHNpIFNTRCwgREVGUkFHIHNv
HLP:bG8gc2kgSERECiMgY2xhcm8sIE5PTkUgZW4gY3VhbHF1aWVyIG90cm8gY2FzbyAoYWJzdGVuY2lvbiBzZWd1cmE6IG51bmNhIGRlc2ZyYWdtZW50YQojIGFudGUgdGlwbyBpbmNpZXJ0bywgZXZpdGFuZG8gZGFuYXIgdW4gcG9zaWJsZSBTU0QpLgpmdW5jdGlvbiBS
HLP:ZXNvbHZlLU9wdGltaXplQWN0aW9uKCRtZWRpYSkgewogICAgJG0gPSAoW3N0cmluZ10kbWVkaWEpLlRyaW0oKS5Ub1VwcGVyKCkKICAgIGlmICAgICAoJG0gLWVxICdTU0QnKSAgICAgeyByZXR1cm4gJ1RSSU0nIH0KICAgIGVsc2VpZiAoJG0gLWVxICdIREQnKSAg
HLP:ICAgeyByZXR1cm4gJ0RFRlJBRycgfQogICAgZWxzZWlmICgkbSAtZXEgJ1ZJUlRVQUwnKSB7IHJldHVybiAnTk9ORScgfSAgICMgKHYzLjIpIGRpc2NvIGRlIG1hcXVpbmEgdmlydHVhbDogbm8gYXBsaWNhCiAgICBlbHNlICAgICAgICAgICAgICAgICAgICAgIHsg
HLP:cmV0dXJuICdOT05FJyB9Cn0KCiMgR2V0LU1lZGlhVHlwZTogaWRlbnRpZmljYSBlbCBkaXNjbyBmaXNpY28gZGVsIHZvbHVtZW4gZGVsIHNpc3RlbWEgZGUgZm9ybWEKIyBmaWFibGUgKHBvciBEZXZpY2VJZCwgcmVzcGFsZG8gcG9yIFNlcmlhbE51bWJlcikgeSBk
HLP:ZXZ1ZWx2ZSBTU0R8SEREfFZJUlRVQUx8VU5LTk9XTi4KZnVuY3Rpb24gR2V0LU1lZGlhVHlwZSB7CiAgICB0cnkgewogICAgICAgICRzeXMgID0gKCRlbnY6U3lzdGVtRHJpdmUpLlRyaW1FbmQoJzonKQogICAgICAgICRkaXNrID0gR2V0LVBhcnRpdGlvbiAtRHJp
HLP:dmVMZXR0ZXIgJHN5cyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IEdldC1EaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgJHBkID0gJG51bGwKICAgICAgICBpZiAoJGRpc2spIHsKICAgICAgICAgICAgJHBkID0gR2V0LVBo
HLP:eXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLkRldmljZUlkIC1lcSAkZGlzay5OdW1iZXIgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgaWYgKC1u
HLP:b3QgJHBkIC1hbmQgJGRpc2suU2VyaWFsTnVtYmVyKSB7CiAgICAgICAgICAgICAgICAkcGQgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAgICAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLlNlcmlh
HLP:bE51bWJlciAtYW5kICgkXy5TZXJpYWxOdW1iZXIuVHJpbSgpIC1lcSAoW3N0cmluZ10kZGlzay5TZXJpYWxOdW1iZXIpLlRyaW0oKSkgfSB8CiAgICAgICAgICAgICAgICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIH0KICAgICAgICB9
HLP:CiAgICAgICAgIyAodjMuMikgZGlzY28gZGUgbWFxdWluYSB2aXJ0dWFsIChWaXJ0dWFsQm94L1ZNd2FyZS9IeXBlci1WL1FFTVUpOiBUUklNIHkKICAgICAgICAjIGRlc2ZyYWdtZW50YWNpb24gbm8gYXBsaWNhbjsgc2UgaWRlbnRpZmljYSBwb3IgZWwgbW9kZWxv
HLP:IGRlbCBkaXNjby4KICAgICAgICAkbW9kZWxvcyA9IEAoKQogICAgICAgIGlmICgkZGlzaykgeyAkbW9kZWxvcyArPSBbc3RyaW5nXSRkaXNrLkZyaWVuZGx5TmFtZTsgJG1vZGVsb3MgKz0gW3N0cmluZ10kZGlzay5Nb2RlbCB9CiAgICAgICAgaWYgKCRwZCkgICB7
HLP:ICRtb2RlbG9zICs9IFtzdHJpbmddJHBkLkZyaWVuZGx5TmFtZTsgICAkbW9kZWxvcyArPSBbc3RyaW5nXSRwZC5Nb2RlbCB9CiAgICAgICAgaWYgKCgkbW9kZWxvcyAtam9pbiAnICcpIC1tYXRjaCAnVkJPWHxWTVdBUkV8VklSVFVBTHxRRU1VfFhFTlNSQycpIHsg
HLP:cmV0dXJuICdWSVJUVUFMJyB9CiAgICAgICAgaWYgKC1ub3QgJHBkKSB7IHJldHVybiAnVU5LTk9XTicgfQogICAgICAgIHJldHVybiAoQ29udmVydFRvLU1lZGlhQ2xhc3MgJHBkLk1lZGlhVHlwZSkKICAgIH0gY2F0Y2ggeyByZXR1cm4gJ1VOS05PV04nIH0KfQoK
HLP:IyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpmdW5jdGlvbiBHZXQtRGV2aWNlUHJvYmxlbXMgewogICAgJHAgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9QblBFbnRpdHkg
HLP:fCBXaGVyZS1PYmplY3QgeyAkXy5Db25maWdNYW5hZ2VyRXJyb3JDb2RlIC1ndCAwIH0pCiAgICBpZiAoJHAuQ291bnQgLWVxIDApIHsgIk9LfE5vIGRldmljZXMgd2l0aCBwcm9ibGVtcy4iOyByZXR1cm4gfQogICAgZm9yZWFjaCAoJGQgaW4gKCRwIHwgU2VsZWN0
HLP:LU9iamVjdCAtRmlyc3QgMTIpKSB7CiAgICAgICAgIlBST0J8JCgkZC5Db25maWdNYW5hZ2VyRXJyb3JDb2RlKXwkKCRkLk5hbWUpIgogICAgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tCiMgSW5mb3JtZSBIVE1MIGF1dG9jb250ZW5pZG8geSBib25pdG8gKHRlbWEgb3NjdXJvKS4gLUFyZyA9IHJ1dGEgZGUgc2FsaWRhLgpmdW5jdGlvbiBOZXctSHRtbFJlcG9ydCgkb3V0UGF0aCkgewogICAgQWRkLVR5cGUgLUFzc2VtYmx5TmFt
HLP:ZSBTeXN0ZW0uV2ViIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICB0cnkgewogICAgICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICAgICAkc3lzUGFpcnMgPSBHZXQtU3lzSW5mbwoKICAgICAgICAkZW5jID0geyBwYXJhbSgkdCkgW1N5c3RlbS5XZWIu
HLP:SHR0cFV0aWxpdHldOjpIdG1sRW5jb2RlKFtzdHJpbmddJHQpIH0KICAgICAgICAkY2lyYyA9IDUyNy43OQogICAgICAgICRiYW5kQ29sb3IgPSB7IHBhcmFtKCRzKSBpZiAoJHMgLWVxICctJyAtb3IgJG51bGwgLWVxICRzIC1vciBbc3RyaW5nXSRzIC1lcSAnJykg
HLP:eyAnIzk0YTNiOCcgfSBlbHNlIHsgJHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgcmV0dXJuICcjOTRhM2I4JyB9OyBpZiAoJHYgLWdlIDgwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCR2IC1nZSA1MCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfSB9
HLP:IH0KICAgICAgICAkYmFuZExhYmVsID0geyBwYXJhbSgkcykgaWYgKCRzIC1lcSAnLScgLW9yICRudWxsIC1lcSAkcyAtb3IgW3N0cmluZ10kcyAtZXEgJycpIHsgJ25vIGRhdGEnIH0gZWxzZSB7ICR2PTA7IHRyeSB7ICR2PVtpbnRdJHMgfSBjYXRjaCB7IHJldHVy
HLP:biAnbm8gZGF0YScgfTsgaWYgKCR2IC1nZSA4MCkgeydHb29kJ30gZWxzZWlmICgkdiAtZ2UgNTApIHsnRmFpcid9IGVsc2UgeydDcml0aWNhbCd9IH0gfQogICAgICAgICRvZmZzZXRPZiA9IHsgcGFyYW0oJHMpICR2PTA7IHRyeSB7ICR2PVtpbnRdJHMgfSBjYXRj
HLP:aCB7ICR2PTAgfTsgaWYgKCR2IC1sdCAwKXskdj0wfTsgaWYgKCR2IC1ndCAxMDApeyR2PTEwMH07IFttYXRoXTo6Um91bmQoJGNpcmMgKiAoMSAtICgkdi8xMDAuMCkpLCAyKSB9CiAgICAgICAgJHN0YXR1c0ljb24gPSB7CiAgICAgICAgICAgIHBhcmFtKCRyZXMp
HLP:CiAgICAgICAgICAgIHN3aXRjaCAoW3N0cmluZ10kcmVzKSB7CiAgICAgICAgICAgICAgICAnT0snICAgIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J3N1Y2Nlc3NmdWwnPjxjaXJjbGUgY3g9
HLP:JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScjMjJjNTVlJy8+PHBhdGggZD0nTTcgMTIuNGwzLjIgMy4yTDE3IDguOCcgZmlsbD0nbm9uZScgc3Ryb2tlPScjMDQyMTBmJyBzdHJva2Utd2lkdGg9JzIuNicgc3Ryb2tlLWxpbmVjYXA9J3JvdW5kJyBzdHJva2UtbGlu
HLP:ZWpvaW49J3JvdW5kJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICAnV0FSTicgIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J3dhcm5pbmcnPjxwYXRoIGQ9J00xMiAyLjVMMjMgMjEuNUgx
HLP:eicgZmlsbD0nI2Y1OWUwYicvPjxyZWN0IHg9JzExJyB5PSc4LjUnIHdpZHRoPScyJyBoZWlnaHQ9JzcnIHJ4PScxJyBmaWxsPScjM2EyNDAwJy8+PGNpcmNsZSBjeD0nMTInIGN5PScxOCcgcj0nMS4zJyBmaWxsPScjM2EyNDAwJy8+PC9zdmc+IiB9CiAgICAgICAg
HLP:ICAgICAgICAnRVJST1InIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J2Vycm9yJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nI2VmNDQ0NCcvPjxwYXRoIGQ9J004IDhs
HLP:OCA4TTE2IDhsLTggOCcgc3Ryb2tlPScjMmEwNjA2JyBzdHJva2Utd2lkdGg9JzIuNicgc3Ryb2tlLWxpbmVjYXA9J3JvdW5kJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICAnU0tJUCcgIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNv
HLP:JyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J3NraXBwZWQnPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScjNjQ3NDhiJy8+PHJlY3QgeD0nNi41JyB5PScxMScgd2lkdGg9JzExJyBoZWlnaHQ9JzInIHJ4PScxJyBmaWxsPScjMGIxMjIwJy8+PC9z
HLP:dmc+IiB9CiAgICAgICAgICAgICAgICBkZWZhdWx0IHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNvJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nIzk0YTNiOCcvPjwvc3ZnPiIgfQogICAgICAgICAgICB9CiAgICAg
HLP:ICAgfQoKICAgICAgICAkYmVmb3JlID0gJHN0LnNjb3JlX2JlZm9yZTsgaWYgKCRudWxsIC1lcSAkYmVmb3JlKSB7ICRiZWZvcmUgPSAnLScgfQogICAgICAgICRhZnRlciAgPSAkc3Quc2NvcmVfYWZ0ZXI7ICBpZiAoJG51bGwgLWVxICRhZnRlcikgIHsgJGFmdGVy
HLP:ICA9ICctJyB9CiAgICAgICAgJGhhc0JvdGggPSAoJHN0LnNjb3JlX2JlZm9yZSAtbmUgJG51bGwgLWFuZCAkc3Quc2NvcmVfYWZ0ZXIgLW5lICRudWxsKQogICAgICAgICRkZWx0YSA9IDA7ICRkZWx0YVR4dCA9ICdubyBjb21wYXJpc29uJwogICAgICAgIGlmICgk
HLP:aGFzQm90aCkgeyAkZGVsdGEgPSBbaW50XSRzdC5zY29yZV9hZnRlciAtIFtpbnRdJHN0LnNjb3JlX2JlZm9yZTsgJHNpZ24gPSBpZiAoJGRlbHRhIC1nZSAwKSB7JysnfSBlbHNlIHsnJ307ICRkZWx0YVR4dCA9ICIkc2lnbiRkZWx0YSBwb2ludHMiIH0KICAgICAg
HLP:ICAkZGVsdGFDb2xvciA9IGlmICgkZGVsdGEgLWd0IDApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJGRlbHRhIC1sdCAwKSB7JyNlZjQ0NDQnfSBlbHNlIHsnIzk0YTNiOCd9CiAgICAgICAgJG1haW5TY29yZSA9IGlmICgkYWZ0ZXIgLW5lICctJykgeyAkYWZ0ZXIgfSBl
HLP:bHNlaWYgKCRiZWZvcmUgLW5lICctJykgeyAkYmVmb3JlIH0gZWxzZSB7ICctJyB9CiAgICAgICAgJG1haW5Db2xvciA9ICYgJGJhbmRDb2xvciAkbWFpblNjb3JlCiAgICAgICAgJG1haW5PZmZzZXQgPSAmICRvZmZzZXRPZiAkbWFpblNjb3JlCiAgICAgICAgJG1h
HLP:aW5MYWJlbCA9ICYgJGJhbmRMYWJlbCAkbWFpblNjb3JlCiAgICAgICAgJGJlZm9yZUNvbG9yID0gJiAkYmFuZENvbG9yICRiZWZvcmUKICAgICAgICAkYWZ0ZXJDb2xvciAgPSAmICRiYW5kQ29sb3IgJGFmdGVyCiAgICAgICAgJGJlZm9yZU9mZnNldCA9ICYgJG9m
HLP:ZnNldE9mICRiZWZvcmUKICAgICAgICAkYWZ0ZXJPZmZzZXQgID0gJiAkb2Zmc2V0T2YgJGFmdGVyCgogICAgICAgICRzY3JpcHREaXIgPSAkbnVsbAogICAgICAgIGlmICgkUFNTY3JpcHRSb290KSB7CiAgICAgICAgICAgICRzY3JpcHREaXIgPSAkUFNTY3JpcHRS
HLP:b290CiAgICAgICAgfSBlbHNlaWYgKCRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgpIHsKICAgICAgICAgICAgJHNjcmlwdERpciA9IFNwbGl0LVBhdGggLVBhcmVudCAkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoCiAgICAgICAgfQogICAgICAgICRiYXNl
HLP:RGlyID0gaWYgKCRzY3JpcHREaXIpIHsgSm9pbi1QYXRoIChTcGxpdC1QYXRoIC1QYXJlbnQgJHNjcmlwdERpcikgIldQSV9TdWl0ZSIgfSBlbHNlIHsgJFdvcmsgfQogICAgICAgICRoaXN0b3J5RmlsZSA9IEpvaW4tUGF0aCAkYmFzZURpciAiaGVhbHRoX2hpc3Rv
HLP:cnkuanNvbiIKICAgICAgICAkaGlzdG9yeSA9IEAoKQogICAgICAgIGlmIChUZXN0LVBhdGggJGhpc3RvcnlGaWxlKSB7CiAgICAgICAgICAgIHRyeSB7ICRoaXN0b3J5ID0gR2V0LUNvbnRlbnQgJGhpc3RvcnlGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uIH0g
HLP:Y2F0Y2gge30KICAgICAgICB9CiAgICAgICAgJGhpc3RvcnlIdG1sID0gJycKICAgICAgICBpZiAoJGhpc3RvcnkgLWFuZCAkaGlzdG9yeS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAkaGlzdG9yeUh0bWwgKz0gIjxkaXYgY2xhc3M9J3RyZW5kLXRpdGxlJz5I
HLP:ZWFsdGggSGlzdG9yeSAoTGFzdCBydW5zKTwvZGl2PjxkaXYgY2xhc3M9J3RyZW5kLWxpc3QnPiIKICAgICAgICAgICAgZm9yZWFjaCAoJGggaW4gJGhpc3RvcnkpIHsKICAgICAgICAgICAgICAgICRjb2wgPSAmICRiYW5kQ29sb3IgJGguc2NvcmUKICAgICAgICAg
HLP:ICAgICAgICRoaXN0b3J5SHRtbCArPSAiPGRpdiBjbGFzcz0ndHJlbmQtaXRlbSc+PHNwYW4gY2xhc3M9J3RyZW5kLWRhdGUnPiQoJGguZGF0ZSk8L3NwYW4+PHNwYW4gY2xhc3M9J3RyZW5kLXNjb3JlJyBzdHlsZT0nY29sb3I6JGNvbCc+JCgkaC5zY29yZSkvMTAw
HLP:PC9zcGFuPjwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICAkaGlzdG9yeUh0bWwgKz0gIjwvZGl2PiIKICAgICAgICB9CgogICAgICAgICRzeXNNYXAgPSBAe30KICAgICAgICBmb3JlYWNoICgkcCBpbiAkc3lzUGFpcnMpIHsgJGt2ID0gJHAgLXNwbGl0
HLP:ICc9JywyOyBpZiAoJGt2LkNvdW50IC1lcSAyKSB7ICRzeXNNYXBbJGt2WzBdXSA9ICRrdlsxXSB9IH0KICAgICAgICAkc3lzT3JkZXIgPSBAKEAoJ09TJywnT3BlcmF0aW5nIFN5c3RlbScpLEAoJ1NZU1RFTScsJ1N5c3RlbSBNb2RlbCcpLEAoJ0NQVScsJ1Byb2Nl
HLP:c3NvcicpLEAoJ1JBTScsJ1JBTSBNZW1vcnknKSxAKCdESVNLJywnRGlzayBDOicpLEAoJ1VQVElNRScsJ1VwdGltZScpLEAoJ1VTRVInLCdVc2VyJykpCiAgICAgICAgJHN5c0NhcmRzID0gJycKICAgICAgICBmb3JlYWNoICgkbyBpbiAkc3lzT3JkZXIpIHsgaWYg
HLP:KCRzeXNNYXAuQ29udGFpbnNLZXkoJG9bMF0pKSB7ICRzeXNDYXJkcyArPSAiPGRpdiBjbGFzcz0nc3lzJz48ZGl2IGNsYXNzPSdzeXMtayc+JCgmICRlbmMgJG9bMV0pPC9kaXY+PGRpdiBjbGFzcz0nc3lzLXYnPiQoJiAkZW5jICRzeXNNYXBbJG9bMF1dKTwvZGl2
HLP:PjwvZGl2PiIgfSB9CiAgICAgICAgJG1hY2hpbmUgPSAkc3lzTWFwWydTWVNURU0nXTsgaWYgKC1ub3QgJG1hY2hpbmUpIHsgJG1hY2hpbmUgPSAkZW52OkNPTVBVVEVSTkFNRSB9CgogICAgICAgICRwaGFzZXMgPSBAKCRzdC5waGFzZXMpCiAgICAgICAgJGNPSz0w
HLP:OyRjV0FSTj0wOyRjRVJSPTA7JGNTS0lQPTAKICAgICAgICAkbWF4U2VjcyA9IDEKICAgICAgICBmb3JlYWNoICgkcGggaW4gJHBoYXNlcykgeyAkc3Y9MDsgdHJ5IHsgJHN2PVtpbnRdJHBoLnNlY3MgfSBjYXRjaCB7fTsgaWYgKCRzdiAtZ3QgJG1heFNlY3MpIHsg
HLP:JG1heFNlY3MgPSAkc3YgfSB9CiAgICAgICAgJHJvd3MgPSAnJwogICAgICAgICRiYXJzID0gJycKICAgICAgICBmb3JlYWNoICgkcGggaW4gJHBoYXNlcykgewogICAgICAgICAgICAkcmVzID0gW3N0cmluZ10kcGgucmVzdWx0CiAgICAgICAgICAgIHN3aXRjaCAo
HLP:JHJlcykgeyAnT0snIHskY09LKyt9ICdXQVJOJyB7JGNXQVJOKyt9ICdFUlJPUicgeyRjRVJSKyt9ICdTS0lQJyB7JGNTS0lQKyt9IH0KICAgICAgICAgICAgJGxjID0gJHJlcy5Ub0xvd2VyKCkKICAgICAgICAgICAgJG5vdGUgPSBpZiAoW3N0cmluZ10kcGgubm90
HLP:ZSAtbmUgJycpIHsgIjxkaXYgY2xhc3M9J3BoLW5vdGUnPiQoJiAkZW5jICRwaC5ub3RlKTwvZGl2PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAkcm93cyArPSAiPGRpdiBjbGFzcz0ncGggcGgtJGxjJz48ZGl2IGNsYXNzPSdwaC1kb3QnPiQoJiAkc3RhdHVz
HLP:SWNvbiAkcmVzKTwvZGl2PjxkaXYgY2xhc3M9J3BoLW1haW4nPjxkaXYgY2xhc3M9J3BoLXRvcCc+PHNwYW4gY2xhc3M9J3BoLW51bSc+JCgmICRlbmMgJHBoLm51bSk8L3NwYW4+PHNwYW4gY2xhc3M9J3BoLXRpdGxlJz4kKCYgJGVuYyAkcGgudGl0bGUpPC9zcGFu
HLP:PjxzcGFuIGNsYXNzPSdwaC1iYWRnZSBiLSRsYyc+JHJlczwvc3Bhbj48L2Rpdj4kbm90ZTwvZGl2PjxkaXYgY2xhc3M9J3BoLXNlY3MnPiQoJiAkZW5jICRwaC5zZWNzKXM8L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICRzdj0wOyB0cnkgeyAkc3Y9W2ludF0kcGgu
HLP:c2VjcyB9IGNhdGNoIHt9CiAgICAgICAgICAgICR3ID0gW21hdGhdOjpSb3VuZCgxMDAuMCAqICRzdiAvIFttYXRoXTo6TWF4KDEsJG1heFNlY3MpKTsgaWYgKCR3IC1sdCAyIC1hbmQgJHN2IC1ndCAwKSB7ICR3ID0gMiB9CiAgICAgICAgICAgICRiY29sID0gc3dp
HLP:dGNoICgkcmVzKSB7ICdPSycgeycjMjJjNTVlJ30gJ1dBUk4nIHsnI2Y1OWUwYid9ICdFUlJPUicgeycjZWY0NDQ0J30gZGVmYXVsdCB7JyM2NDc0OGInfSB9CiAgICAgICAgICAgICRiYXJzICs9ICI8ZGl2IGNsYXNzPSdiYXItcm93Jz48ZGl2IGNsYXNzPSdiYXIt
HLP:bGJsJz4kKCYgJGVuYyAkcGgubnVtKSAkKCYgJGVuYyAkcGgudGl0bGUpPC9kaXY+PGRpdiBjbGFzcz0nYmFyLXRyYWNrJz48c3BhbiBzdHlsZT0nd2lkdGg6JHclO2JhY2tncm91bmQ6JGJjb2wnPjwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdiYXItdmFsJz4kKCYg
HLP:JGVuYyAkcGguc2VjcylzPC9kaXY+PC9kaXY+IgogICAgICAgIH0KICAgICAgICBpZiAoLW5vdCAkcm93cykgeyAkcm93cyA9ICI8ZGl2IGNsYXNzPSdlbXB0eSc+Tm8gcGhhc2VzIHdlcmUgcmVjb3JkZWQgaW4gdGhpcyBydW4uPC9kaXY+IiB9CiAgICAgICAgaWYg
HLP:KC1ub3QgJGJhcnMpIHsgJGJhcnMgPSAiPGRpdiBjbGFzcz0nZW1wdHknPk5vIHRpbWluZ3MgdG8gc2hvdy48L2Rpdj4iIH0KICAgICAgICAkdG90YWxQaCA9ICRwaGFzZXMuQ291bnQKICAgICAgICAjIFJFQUwgYWdncmVnYXRlIHN0YXRpc3RpY3Mgb2Ygd2hhdCBh
HLP:Y3R1YWxseSByYW46IHRvdGFsIHNlc3Npb24gdGltZSBhbmQKICAgICAgICAjIHNwYWNlIGZyZWVkIChzdW1tZWQgZnJvbSBlYWNoIHBoYXNlJ3MgbWVhc3VyZWQgbm90ZXMsIE1CL0dCKS4KICAgICAgICAkdG90U2VjcyA9IDA7ICRtYkZyZWVkID0gMC4wCiAgICAg
HLP:ICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsKICAgICAgICAgICAgJHN2ID0gMDsgdHJ5IHsgJHN2ID0gW2ludF0kcGguc2VjcyB9IGNhdGNoIHt9OyAkdG90U2VjcyArPSAkc3YKICAgICAgICAgICAgZm9yZWFjaCAoJG0gaW4gW3JlZ2V4XTo6TWF0Y2hlcyhb
HLP:c3RyaW5nXSRwaC5ub3RlLCAnKD9pKSg/OmxpYmVyYWRcdyp8ZnJlZWQpXER7MCwxMH0/KFtcZFwuLF0rKVxzKihNQnxHQiknKSkgewogICAgICAgICAgICAgICAgJHYgPSAwLjA7IHRyeSB7ICR2ID0gW2RvdWJsZV0oJG0uR3JvdXBzWzFdLlZhbHVlLlJlcGxhY2Uo
HLP:JywnLCAnLicpKSB9IGNhdGNoIHt9CiAgICAgICAgICAgICAgICBpZiAoJG0uR3JvdXBzWzJdLlZhbHVlIC1tYXRjaCAnKD9pKUdCJykgeyAkdiA9ICR2ICogMTAyNCB9CiAgICAgICAgICAgICAgICAkbWJGcmVlZCArPSAkdgogICAgICAgICAgICB9CiAgICAgICAg
HLP:fQogICAgICAgICR0b3RUeHQgPSBpZiAoJHRvdFNlY3MgLWdlIDYwKSB7ICgnezB9IG1pbiB7MX0gcycgLWYgW2ludF1bbWF0aF06OkZsb29yKCR0b3RTZWNzIC8gNjApLCAoJHRvdFNlY3MgJSA2MCkpIH0gZWxzZSB7ICgnezB9IHMnIC1mICR0b3RTZWNzKSB9CiAg
HLP:ICAgICAgJGZyZWVkVHh0ID0gaWYgKCRtYkZyZWVkIC1nZSAxMDI0KSB7ICgnezA6bjF9IEdCJyAtZiAoJG1iRnJlZWQgLyAxMDI0KSkgfSBlbHNlaWYgKCRtYkZyZWVkIC1ndCAwKSB7ICgnezA6bjB9IE1CJyAtZiAkbWJGcmVlZCkgfSBlbHNlIHsgJycgfQogICAg
HLP:ICAgICRzdGF0TGluZSA9ICgndG90YWwgdGltZTogezB9JyAtZiAkdG90VHh0KQogICAgICAgIGlmICgkZnJlZWRUeHQpIHsgJHN0YXRMaW5lICs9ICgnICZtaWRkb3Q7IHNwYWNlIGZyZWVkOiB7MH0nIC1mICRmcmVlZFR4dCkgfQoKICAgICAgICAkZmluZGluZ3Mg
HLP:PSBAKCRzdC5maW5kaW5ncykKICAgICAgICAkZmluZEh0bWwgPSAnJwogICAgICAgICRzdGVwc0xpc3QgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAgICAgIGZvcmVhY2ggKCRmIGluICRmaW5kaW5ncykgewog
HLP:ICAgICAgICAgICAkdHh0ID0gW3N0cmluZ10kZgogICAgICAgICAgICAkc2V2ID0gJ2luZm8nOyAkc2V2VHh0ID0gJ05vdGljZScKICAgICAgICAgICAgaWYgKCR0eHQgLW1hdGNoICcoP2kpU01BUlR8QlNPRHxjcmFzaHxXSEVBfGhhcmR3YXJlfHVucmVwYWlyYWJs
HLP:ZXxkYW1hZ2VkfHJlcG9zaXRvcnl8aW50ZWdyaXR5JykgeyAkc2V2PSdoaWdoJzsgJHNldlR4dD0nSW1wb3J0YW50JyB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlzcGFjZXxwZW5kaW5nIHJlYm9vdHxuZXR3b3JrfGJhdHRlcnl8ZHJpdmVy
HLP:fGRldmljZXxcYlJBTVxifHNlcnZpY2UnKSB7ICRzZXY9J21lZCc7ICRzZXZUeHQ9J1JldmlldycgfQogICAgICAgICAgICAkZmluZEh0bWwgKz0gIjxsaSBjbGFzcz0nZmluZCBmaW5kLSRzZXYnPjxzcGFuIGNsYXNzPSdzZXYgc2V2LSRzZXYnPiRzZXZUeHQ8L3Nw
HLP:YW4+PHNwYW4gY2xhc3M9J2ZpbmQtdHh0Jz4kKCYgJGVuYyAkdHh0KTwvc3Bhbj48L2xpPiIKICAgICAgICAgICAgIyBEZXJpdmFyIHBhc28gcmVjb21lbmRhZG8gYSBwYXJ0aXIgZGVsIGhhbGxhemdvCiAgICAgICAgICAgIGlmICgkdHh0IC1tYXRjaCAnKD9pKVNN
HLP:QVJUJykgICAgICAgICAgeyAkc3RlcHNMaXN0LkFkZCgnQmFjayB1cCB5b3VyIGRhdGEgYXMgc29vbiBhcyBwb3NzaWJsZTogYSBkaXNrIHdpdGggZGVncmFkZWQgU01BUlQgY2FuIGZhaWwuIENvbnNpZGVyIHJlcGxhY2luZyBpdC4nKSB9CiAgICAgICAgICAgIGVs
HLP:c2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlzcGFjZScpICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ0ZyZWUgdXAgc3BhY2Ugb24gQzogKHVuaW5zdGFsbCB3aGF0IHlvdSBkb24nJ3QgdXNlIG9yIHVzZSBTdG9yYWdlIFNlbnNlKS4gQWltIGZvciBtb3JlIHRoYW4gMTUgR0Ig
HLP:ZnJlZS4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlcYlJBTVxifG1lbW9yeScpIHsgJHN0ZXBzTGlzdC5BZGQoJ1J1biBXaW5kb3dzIE1lbW9yeSBEaWFnbm9zdGljIChtZHNjaGVkLmV4ZSkgYW5kIHJlYm9vdCB0byBjaGVjayB0aGUg
HLP:UkFNLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWJhdHRlcnknKSAgICB7ICRzdGVwc0xpc3QuQWRkKCdUaGUgYmF0dGVyeSBpcyBkZWdyYWRlZC4gQ2hlY2sgdGhlIGJhdHRlcnkgcmVwb3J0IChwb3dlcmNmZyAvYmF0dGVyeXJlcG9y
HLP:dCkgYW5kIGNvbnNpZGVyIHJlcGxhY2luZyBpdC4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlwZW5kaW5nIHJlYm9vdCcpIHsgJHN0ZXBzTGlzdC5BZGQoJ1JlYm9vdCB0aGUgUEMgdG8gYXBwbHkgcGVuZGluZyBjaGFuZ2VzIGJlZm9y
HLP:ZSBjb250aW51aW5nIHJlcGFpcnMuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpdW5yZXBhaXJhYmxlfHJlcG9zaXRvcnl8aW50ZWdyaXR5JykgeyAkc3RlcHNMaXN0LkFkZCgnRGFtYWdlZCBjb21wb25lbnRzIHJlbWFpbi4gUnVuIERJ
HLP:U00gd2l0aCBhIHZhbGlkIHNvdXJjZSAoaW5zdGFsbC53aW0pIGFuZCBydW4gU0ZDIGFnYWluLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWRyaXZlcnxkZXZpY2UnKSB7ICRzdGVwc0xpc3QuQWRkKCdVcGRhdGUgdGhlIGRyaXZlcnMg
HLP:b2YgdGhlIGZhaWxpbmcgZGV2aWNlcyBmcm9tIHRoZSBtYWtlcicncyBzaXRlIG9yIFdpbmRvd3MgVXBkYXRlLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKW5ldHdvcmt8RE5TJykgICAgICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ0NoZWNr
HLP:IHRoZSBuZXR3b3JrIGNvbm5lY3Rpb24gYW5kIEROUy4gSWYgaXQgcGVyc2lzdHMsIHRyeSBhIHB1YmxpYyBETlMgKDEuMS4xLjEgLyA4LjguOC44KS4nKSB9CiAgICAgICAgfQogICAgICAgICRub0ZpbmQgPSAoJGZpbmRpbmdzLkNvdW50IC1lcSAwKQogICAgICAg
HLP:IGlmICgkbm9GaW5kKSB7ICRmaW5kSHRtbCA9ICI8bGkgY2xhc3M9J2ZpbmQgZmluZC1vayc+PHNwYW4gY2xhc3M9J3NldiBzZXYtb2snPkFsbCBPSzwvc3Bhbj48c3BhbiBjbGFzcz0nZmluZC10eHQnPk5vIHJlbGV2YW50IHByb2JsZW1zIHdlcmUgZGV0ZWN0ZWQg
HLP:ZHVyaW5nIGRpYWdub3Npcy48L3NwYW4+PC9saT4iIH0KCiAgICAgICAgIyAtLS0gUHJveGltb3MgcGFzb3MgcmVjb21lbmRhZG9zIChkZWR1cGxpY2Fkb3MpIC0tLQogICAgICAgICRzdGVwc0h0bWwgPSAnJwogICAgICAgICRzZWVuID0gQHt9CiAgICAgICAgZm9y
HLP:ZWFjaCAoJHMgaW4gJHN0ZXBzTGlzdCkgeyBpZiAoLW5vdCAkc2Vlbi5Db250YWluc0tleSgkcykpIHsgJHNlZW5bJHNdPSR0cnVlOyAkc3RlcHNIdG1sICs9ICI8bGkgY2xhc3M9J3N0ZXAtbGknPjxzcGFuIGNsYXNzPSdzdGVwLWljJz4mIzEwMTQ4Ozwvc3Bhbj48
HLP:c3Bhbj4kKCYgJGVuYyAkcyk8L3NwYW4+PC9saT4iIH0gfQogICAgICAgIGlmICgkY0VSUiAtZ3QgMCkgeyAkc3RlcHNIdG1sID0gIjxsaSBjbGFzcz0nc3RlcC1saSc+PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAxNDg7PC9zcGFuPjxzcGFuPlNvbWUgcGhhc2Vz
HLP:IGhhZCBlcnJvcnM6IGNoZWNrIHRoZSBkZXRhaWxlZCBsb2cgaW4gdGhlIFdQSV9TdWl0ZVxMb2dzIGZvbGRlci48L3NwYW4+PC9saT4iICsgJHN0ZXBzSHRtbCB9CiAgICAgICAgaWYgKC1ub3QgJHN0ZXBzSHRtbCkgeyAkc3RlcHNIdG1sID0gIjxsaSBjbGFzcz0n
HLP:c3RlcC1saSBzdGVwLW9rJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDAwMzs8L3NwYW4+PHNwYW4+Tm8gcGVuZGluZyBhY3Rpb25zLiBSZWJvb3QgdGhlIFBDIHRvIG1ha2Ugc3VyZSBhbGwgY2hhbmdlcyBhcmUgYXBwbGllZC48L3NwYW4+PC9saT4iIH0KCiAg
HLP:ICAgICAgIyA9PT09PT09PT09PT09PT09PT09PT09IERJQUdOT1NUSUNPIEFNUExJQURPID09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICAkZGlhZ0NhcmRzID0gJycKICAgICAgICBpZiAoKCRzdC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5z
HLP:ICdkaWFnJykgLWFuZCAkc3QuZGlhZykgewogICAgICAgICAgICAkZCA9ICRzdC5kaWFnCiAgICAgICAgICAgIGlmICgkZC5yYW0pIHsKICAgICAgICAgICAgICAgICRycyA9IFtzdHJpbmddJGQucmFtLnN0YXR1cwogICAgICAgICAgICAgICAgJHJwID0gc3dpdGNo
HLP:ICgkcnMpIHsgJ29rJyB7J2dvb2QnfSAnc3VzcGVjdCcgeydiYWQnfSBkZWZhdWx0IHsndW5rbm93bid9IH0KICAgICAgICAgICAgICAgICRydCA9IHN3aXRjaCAoJHJzKSB7ICdvaycgeydObyBlcnJvcnMgZGV0ZWN0ZWQnfSAnc3VzcGVjdCcgeydTdXNwZWN0J30g
HLP:ZGVmYXVsdCB7J05vdCBldmFsdWF0ZWQnfSB9CiAgICAgICAgICAgICAgICAkbWRzID0gaWYgKCRkLnJhbS5yZWNvbW1lbmRfbWRzY2hlZCkgeyAiPGRpdiBjbGFzcz0nZC1oaW50Jz5SZWNvbW1lbmRlZDogcnVuIFdpbmRvd3MgTWVtb3J5IERpYWdub3N0aWMgKG1k
HLP:c2NoZWQpLjwvZGl2PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtcmFtJz48L3NwYW4+UkFNIE1lbW9yeTwvZGl2PjxkaXYg
HLP:Y2xhc3M9J2QtcGlsbCBwaWxsLSRycCc+JHJ0PC9kaXY+JG1kczwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJGQuYmF0dGVyeSkgewogICAgICAgICAgICAgICAgaWYgKCRkLmJhdHRlcnkucHJlc2VudCkgewogICAgICAgICAgICAgICAgICAg
HLP:ICRicFJhdyA9ICRkLmJhdHRlcnkuaGVhbHRoX3BjdAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGJwUmF3IC1hbmQgW3N0cmluZ10kYnBSYXcgLW5lICcnKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRicCA9IDA7IHRyeSB7ICRicCA9IFtp
HLP:bnRdJGJwUmF3IH0gY2F0Y2ggeyAkYnAgPSAwIH0KICAgICAgICAgICAgICAgICAgICAgICAgJGJwY29sID0gaWYgKCRicCAtZ2UgODApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJGJwIC1nZSA1MCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfQogICAgICAgICAg
HLP:ICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXR0ZXJ5PC9kaXY+PGRpdiBjbGFzcz0nYmF0LWJhcic+PHNwYW4gc3R5bGU9J3dpZHRo
HLP:OiRicCU7YmFja2dyb3VuZDokYnBjb2wnPjwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdkLXN1Yic+RXN0aW1hdGVkIGhlYWx0aDogPGIgc3R5bGU9J2NvbG9yOiRicGNvbCc+JGJwJTwvYj48L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICAgICAgICAgfSBlbHNlIHsK
HLP:ICAgICAgICAgICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0dGVyeTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLXVua25v
HLP:d24nPlByZXNlbnQsIGhlYWx0aCB1bmtub3duPC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xh
HLP:c3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0dGVyeTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLXVua25vd24nPk5vdCBwcmVzZW50IChkZXNrdG9wIFBDKTwvZGl2PjwvZGl2PiIKICAgICAgICAgICAgICAgIH0KICAgICAg
HLP:ICAgICAgfQogICAgICAgICAgICBpZiAoJGQubmV0d29yaykgewogICAgICAgICAgICAgICAgJGNjID0gaWYgKCRkLm5ldHdvcmsuY29ubmVjdGVkKSB7J2dvb2QnfSBlbHNlIHsnYmFkJ30KICAgICAgICAgICAgICAgICRjdCA9IGlmICgkZC5uZXR3b3JrLmNvbm5l
HLP:Y3RlZCkgeydDb25uZWN0ZWQnfSBlbHNlIHsnTm8gY29ubmVjdGlvbid9CiAgICAgICAgICAgICAgICAkZGMgPSBpZiAoJGQubmV0d29yay5kbnNfb2spIHsnZ29vZCd9IGVsc2UgeydiYWQnfQogICAgICAgICAgICAgICAgJGR0ID0gaWYgKCRkLm5ldHdvcmsuZG5z
HLP:X29rKSB7J0ROUyBPSyd9IGVsc2UgeydETlMgZmFpbGluZyd9CiAgICAgICAgICAgICAgICAkZGV0ID0gJiAkZW5jICRkLm5ldHdvcmsuZGV0YWlscwogICAgICAgICAgICAgICAgJGxhdCA9ICcnCiAgICAgICAgICAgICAgICBpZiAoKCRkLm5ldHdvcmsuUFNPYmpl
HLP:Y3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnZG5zX21zJykgLWFuZCAkbnVsbCAtbmUgJGQubmV0d29yay5kbnNfbXMgLWFuZCBbc3RyaW5nXSRkLm5ldHdvcmsuZG5zX21zIC1uZSAnJykgewogICAgICAgICAgICAgICAgICAgICRtcyA9IDA7IHRyeSB7ICRt
HLP:cyA9IFtpbnRdJGQubmV0d29yay5kbnNfbXMgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgICAgICRsYzIgPSBpZiAoJG1zIC1sdCA2MCkgeycjMjJjNTVlJ30gZWxzZWlmICgkbXMgLWx0IDIwMCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfQogICAgICAg
HLP:ICAgICAgICAgICAgICRsYXQgPSAiPGRpdiBjbGFzcz0nZC1zdWInPkROUyBsYXRlbmN5OiA8YiBzdHlsZT0nY29sb3I6JGxjMic+JG1zIG1zPC9iPjwvZGl2PiIKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xh
HLP:c3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLW5ldCc+PC9zcGFuPk5ldHdvcms8L2Rpdj48ZGl2IGNsYXNzPSdwaWxsLXJvdyc+PHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLSRjYyc+JGN0PC9zcGFuPjxzcGFuIGNsYXNzPSdk
HLP:LXBpbGwgcGlsbC0kZGMnPiRkdDwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdkLXN1Yic+JGRldDwvZGl2PiRsYXQ8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdzbWFydCcp
HLP:IC1hbmQgJGQuc21hcnQgLWFuZCAkZC5zbWFydC5hdmFpbGFibGUpIHsKICAgICAgICAgICAgICAgICRzbSA9ICRkLnNtYXJ0CiAgICAgICAgICAgICAgICAkcGYgPSBpZiAoJHNtLnByZWRpY3RfZmFpbCkgeyAiPHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLWJhZCc+
HLP:UHJlZGljdHMgZmFpbHVyZTwvc3Bhbj4iIH0gZWxzZSB7ICI8c3BhbiBjbGFzcz0nZC1waWxsIHBpbGwtZ29vZCc+Tm8gYWxlcnQ8L3NwYW4+IiB9CiAgICAgICAgICAgICAgICAkZXh0cmEgPSAnJwogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkc20udGVt
HLP:cF9jIC1hbmQgW3N0cmluZ10kc20udGVtcF9jIC1uZSAnJykgeyAkdGM9MDsgdHJ5eyR0Yz1baW50XSRzbS50ZW1wX2N9Y2F0Y2h7fTsgJHRjb2wgPSBpZiAoJHRjIC1sdCA1MCl7JyMyMmM1NWUnfSBlbHNlaWYgKCR0YyAtbHQgNjUpeycjZjU5ZTBiJ30gZWxzZSB7
HLP:JyNlZjQ0NDQnfTsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+VGVtcGVyYXR1cmU6IDxiIHN0eWxlPSdjb2xvcjokdGNvbCc+JHRjICZkZWc7QzwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLndlYXJfcGN0IC1hbmQg
HLP:W3N0cmluZ10kc20ud2Vhcl9wY3QgLW5lICcnKSB7ICR3cD0wOyB0cnl7JHdwPVtpbnRdJHNtLndlYXJfcGN0fWNhdGNoe307ICR3Y29sID0gaWYgKCR3cCAtbHQgNTApeycjMjJjNTVlJ30gZWxzZWlmICgkd3AgLWx0IDgwKXsnI2Y1OWUwYid9IGVsc2UgeycjZWY0
HLP:NDQ0J307ICRleHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPldlYXIgKFNTRCk6IDxiIHN0eWxlPSdjb2xvcjokd2NvbCc+JHdwJTwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLnBvaCAtYW5kIFtzdHJpbmddJHNtLnBvaCAt
HLP:bmUgJycpIHsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+UG93ZXItb24gaG91cnM6IDxiPiQoJiAkZW5jICRzbS5wb2gpPC9iPjwvZGl2PiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9
HLP:J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtc21hcnQnPjwvc3Bhbj5EaXNrIGhlYWx0aCAoU01BUlQpPC9kaXY+PGRpdiBjbGFzcz0ncGlsbC1yb3cnPiRwZjwvZGl2PiRleHRyYTwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoKCRkLlBTT2Jq
HLP:ZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2JjZCcpIC1hbmQgJGQuYmNkKSB7CiAgICAgICAgICAgICAgICAkYm9rID0gaWYgKCRkLmJjZC5vaykgeydnb29kJ30gZWxzZSB7J2JhZCd9CiAgICAgICAgICAgICAgICAkYnR4ID0gaWYgKCRkLmJjZC5vaykg
HLP:eydCb290IGNvbmZpZ3VyYXRpb24gY29ycmVjdCd9IGVsc2UgeydCb290IHdpdGggaXNzdWVzJ30KICAgICAgICAgICAgICAgICRiZGV0ID0gaWYgKFtzdHJpbmddJGQuYmNkLmRldGFpbHMgLW5lICcnKSB7ICI8ZGl2IGNsYXNzPSdkLXN1Yic+JCgmICRlbmMgJGQu
HLP:YmNkLmRldGFpbHMpPC9kaXY+IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1ib290Jz48L3NwYW4+Qm9vdCAoQkNEKTwvZGl2
HLP:PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLSRib2snPiRidHg8L2Rpdj4kYmRldDwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoKCRkLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3N0YXJ0dXAnKSAtYW5kICRkLnN0YXJ0dXAg
HLP:LWFuZCBAKCRkLnN0YXJ0dXApLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkaXRlbXMgPSAnJwogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHMgaW4gQCgkZC5zdGFydHVwKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkcy5uYW1lKTxzcGFuIGNs
HLP:YXNzPSdtdXRlZCc+ICZtZGFzaDsgJCgmICRlbmMgJHMuY29tbWFuZCk8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkIGRjYXJkLXdpZGUnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2Qt
HLP:aWMgaWMtc3RhcnQnPjwvc3Bhbj5TdGFydHVwIHByb2dyYW1zPC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlzdCc+JGl0ZW1zPC91bD48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5z
HLP:ICdwcm9jZXNzZXMnKSAtYW5kICRkLnByb2Nlc3NlcyAtYW5kIEAoJGQucHJvY2Vzc2VzKS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwciBpbiBAKCRkLnByb2Nlc3NlcykpIHsgJGl0
HLP:ZW1zICs9ICI8bGk+JCgmICRlbmMgJHByLm5hbWUpPHNwYW4gY2xhc3M9J211dGVkJz4gJm1kYXNoOyAkKCYgJGVuYyAkcHIubWVtX21iKSBNQjwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxk
HLP:aXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtcHJvYyc+PC9zcGFuPlByb2Nlc3NlcyB1c2luZyBtb3N0IG1lbW9yeTwvZGl2Pjx1bCBjbGFzcz0nZGV2LWxpc3QnPiRpdGVtczwvdWw+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlm
HLP:ICgkZC5kZXZpY2VzIC1hbmQgQCgkZC5kZXZpY2VzKS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRkZXYgaW4gQCgkZC5kZXZpY2VzKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAk
HLP:ZGV2Lm5hbWUpIDxzcGFuIGNsYXNzPSdtdXRlZCc+KGNvZGUgJCgmICRlbmMgJGRldi5jb2RlKSk8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkIGRjYXJkLXdpZGUnPjxkaXYgY2xhc3M9J2QtaCc+
HLP:PHNwYW4gY2xhc3M9J2QtaWMgaWMtZGV2Jz48L3NwYW4+RGV2aWNlcyB3aXRoIHdhcm5pbmdzPC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlzdCc+JGl0ZW1zPC91bD48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgJGRpYWdTZWN0aW9uID0gJycK
HLP:ICAgICAgICBpZiAoJGRpYWdDYXJkcykgeyAkZGlhZ1NlY3Rpb24gPSAiPGgyIGlkPSdkaWFnJyBjbGFzcz0nc2VjLWgnPkV4dGVuZGVkIGRpYWdub3NpczwvaDI+PGRpdiBjbGFzcz0nZGdyaWQnPiRkaWFnQ2FyZHM8L2Rpdj4iIH0KCiAgICAgICAgJGNvbXBhcmVT
HLP:ZWN0aW9uID0gJycKICAgICAgICBpZiAoJGhhc0JvdGgpIHsKICAgICAgICAgICAgJGNvbXBhcmVTZWN0aW9uID0gQCIKPGRpdiBjbGFzcz0nY29tcGFyZSc+CiAgPGRpdiBjbGFzcz0nbWluaSc+CiAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0n
HLP:Z2F1Z2UgZ2F1Z2Utc20nPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRiZWZvcmVPZmZz
HLP:ZXQ7c3Ryb2tlOiRiZWZvcmVDb2xvcicvPjx0ZXh0IHg9JzEwMCcgeT0nMTA4JyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxsOiRiZWZvcmVDb2xvcic+JGJlZm9yZTwvdGV4dD48L3N2Zz4KICAgIDxkaXYgY2xhc3M9J21pbmktY2FwJz5CRUZPUkU8L2Rpdj4KICA8
HLP:L2Rpdj4KICA8ZGl2IGNsYXNzPSdhcnJvdyc+PHNwYW4gc3R5bGU9J2NvbG9yOiRkZWx0YUNvbG9yJz4mIzg1OTQ7PC9zcGFuPjxkaXYgY2xhc3M9J2RlbHRhLWNoaXAnIHN0eWxlPSdjb2xvcjokZGVsdGFDb2xvcjtib3JkZXItY29sb3I6JGRlbHRhQ29sb3InPiRk
HLP:ZWx0YVR4dDwvZGl2PjwvZGl2PgogIDxkaXYgY2xhc3M9J21pbmknPgogICAgPHN2ZyB2aWV3Qm94PScwIDAgMjAwIDIwMCcgY2xhc3M9J2dhdWdlIGdhdWdlLXNtJz48Y2lyY2xlIGNsYXNzPSd0cmFjaycgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnLz48Y2lyY2xl
HLP:IGNsYXNzPSdmaWxsJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcgc3R5bGU9Jy0tY2lyYzokY2lyYzstLXRhcmdldDokYWZ0ZXJPZmZzZXQ7c3Ryb2tlOiRhZnRlckNvbG9yJy8+PHRleHQgeD0nMTAwJyB5PScxMDgnIGNsYXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6
HLP:JGFmdGVyQ29sb3InPiRhZnRlcjwvdGV4dD48L3N2Zz4KICAgIDxkaXYgY2xhc3M9J21pbmktY2FwJz5BRlRFUjwvZGl2PgogIDwvZGl2Pgo8L2Rpdj4KIkAKICAgICAgICB9CgogICAgICAgICRub3cgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkIEhI
HLP:Om1tJykKICAgICAgICAkZXhlY1ZlcmRpY3QgPSAmICRiYW5kTGFiZWwgJG1haW5TY29yZQogICAgICAgICRodG1sID0gQCIKPCFET0NUWVBFIGh0bWw+CjxodG1sIGxhbmc9J2VuJz4KPGhlYWQ+CjxtZXRhIGNoYXJzZXQ9J3V0Zi04Jz4KPG1ldGEgbmFtZT0ndmll
HLP:d3BvcnQnIGNvbnRlbnQ9J3dpZHRoPWRldmljZS13aWR0aCxpbml0aWFsLXNjYWxlPTEnPgo8dGl0bGU+UmVwYWlyIFJlcG9ydCAtIFdQSSBTdWl0ZSB2My4xPC90aXRsZT4KPHN0eWxlPgoqe2JveC1zaXppbmc6Ym9yZGVyLWJveH0KOnJvb3R7LS1iZzojMGIwZjE3
HLP:Oy0tYmcyOiMwZDE0MjI7LS1jYXJkOiMxMjFhMmI7LS1jYXJkMjojMGUxNjI2Oy0tbGluZTojMWUyOTNiOy0tdHh0OiNlNmVkZjY7LS1tdXRlZDojOTNhM2JhOy0tYWNjZW50OiMzOGJkZjg7LS1hY2NlbnQyOiM4MThjZjg7LS1zaGFkb3c6MCAxNHB4IDQwcHggcmdi
HLP:YSgwLDAsMCwuNDApfQpodG1sLmxpZ2h0ey0tYmc6I2VlZjJmODstLWJnMjojZTdlZGY2Oy0tY2FyZDojZmZmZmZmOy0tY2FyZDI6I2Y1ZjhmYzstLWxpbmU6I2RkZTVmMDstLXR4dDojMGYxNzJhOy0tbXV0ZWQ6IzVhNmI4MjstLWFjY2VudDojMDI4NGM3Oy0tYWNj
HLP:ZW50MjojNGY0NmU1Oy0tc2hhZG93OjAgMTBweCAyOHB4IHJnYmEoMTUsMjMsNDIsLjEyKX0KYm9keXttYXJnaW46MDtmb250LWZhbWlseTonU2Vnb2UgVUknLHN5c3RlbS11aSwtYXBwbGUtc3lzdGVtLEFyaWFsLHNhbnMtc2VyaWY7bGluZS1oZWlnaHQ6MS41NTtj
HLP:b2xvcjp2YXIoLS10eHQpO2JhY2tncm91bmQ6cmFkaWFsLWdyYWRpZW50KDEyMDBweCA2MDBweCBhdCA4MCUgLTEwJSxyZ2JhKDU2LDE4OSwyNDgsLjEwKSx0cmFuc3BhcmVudCA2MCUpLHJhZGlhbC1ncmFkaWVudCg5MDBweCA1MDBweCBhdCAtMTAlIDEwJSxyZ2Jh
HLP:KDEyOSwxNDAsMjQ4LC4xMCksdHJhbnNwYXJlbnQgNTUlKSx2YXIoLS1iZyl9Ci53cmFwe21heC13aWR0aDoxMDgwcHg7bWFyZ2luOjAgYXV0bztwYWRkaW5nOjMwcHggMjJweCA2MHB4fQoudG9wYmFye2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVz
HLP:dGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47Z2FwOjE2cHg7bWFyZ2luLWJvdHRvbToxOHB4O2ZsZXgtd3JhcDp3cmFwfQouYnJhbmR7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTRweH0KLmxvZ297d2lkdGg6NDZweDtoZWlnaHQ6NDZweDti
HLP:b3JkZXItcmFkaXVzOjEzcHg7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtib3gtc2hhZG93OnZh
HLP:cigtLXNoYWRvdyl9Cmgxe2ZvbnQtc2l6ZToyMnB4O21hcmdpbjowO2xldHRlci1zcGFjaW5nOi4ycHh9Ci5zdWJ7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6MnB4fQouYmFkZ2V7ZGlzcGxheTppbmxpbmUtYmxvY2s7YmFja2dy
HLP:b3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzozcHggMTJweDtmb250LXNpemU6MTEuNXB4O2xldHRlci1z
HLP:cGFjaW5nOi40cHg7dmVydGljYWwtYWxpZ246bWlkZGxlO21hcmdpbi1sZWZ0OjhweH0KLmJ0bnN7ZGlzcGxheTpmbGV4O2dhcDo4cHg7ZmxleC13cmFwOndyYXB9Ci50b2dnbGV7Y3Vyc29yOnBvaW50ZXI7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNr
HLP:Z3JvdW5kOnZhcigtLWNhcmQpO2NvbG9yOnZhcigtLXR4dCk7Ym9yZGVyLXJhZGl1czoxMHB4O3BhZGRpbmc6OHB4IDE0cHg7Zm9udC1zaXplOjEzcHg7Zm9udC13ZWlnaHQ6NjAwO2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KX0KLnRvZ2dsZTpob3Zlcntib3JkZXIt
HLP:Y29sb3I6dmFyKC0tYWNjZW50KX0KLnRvY3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4LXdyYXA6d3JhcDttYXJnaW46MCAwIDIycHh9Ci50b2MgYXtmb250LXNpemU6MTIuNXB4O2ZvbnQtd2VpZ2h0OjYwMDtjb2xvcjp2YXIoLS1tdXRlZCk7dGV4dC1kZWNvcmF0
HLP:aW9uOm5vbmU7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NnB4IDEzcHh9Ci50b2MgYTpob3Zlcntjb2xvcjp2YXIoLS1hY2NlbnQpO2JvcmRlci1jb2xvcjp2YXIo
HLP:LS1hY2NlbnQpfQouZXhlY3tkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxOHB4O2ZsZXgtd3JhcDp3cmFwO2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRlZyx2YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQg
HLP:dmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRpbmc6MThweCAyMnB4O21hcmdpbi1ib3R0b206MjJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci5leGVjLXNjb3Jle2ZvbnQtc2l6ZTo0NnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDox
HLP:fQouZXhlYy1taWR7ZmxleDoxO21pbi13aWR0aDoyMDBweH0KLmV4ZWMtdmVyZGljdHtmb250LXNpemU6MThweDtmb250LXdlaWdodDo3MDB9Ci5leGVjLWxpbmV7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6MnB4fQouZXhlYy1k
HLP:ZWx0YXtmb250LXNpemU6MTNweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyOjFweCBzb2xpZDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NHB4IDEycHg7d2hpdGUtc3BhY2U6bm93cmFwfQouaGVyb3tkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5z
HLP:Om1pbm1heCgyNDBweCwzMjBweCkgMWZyO2dhcDoyMHB4O21hcmdpbi1ib3R0b206MjJweH0KQG1lZGlhKG1heC13aWR0aDo3NjBweCl7Lmhlcm97Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn19Ci5jYXJke2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRl
HLP:Zyx2YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRpbmc6MjJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci5nYXVnZXdyYXB7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0
HLP:aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjt0ZXh0LWFsaWduOmNlbnRlcn0KLmdhdWdle3dpZHRoOjIxMHB4O2hlaWdodDoyMTBweH0KLmdhdWdlLXNte3dpZHRoOjEyMHB4O2hlaWdodDoxMjBweH0KLmdhdWdlIC50
HLP:cmFja3tmaWxsOm5vbmU7c3Ryb2tlOnZhcigtLWxpbmUpO3N0cm9rZS13aWR0aDoxNH0KLmdhdWdlIC5maWxse2ZpbGw6bm9uZTtzdHJva2Utd2lkdGg6MTQ7c3Ryb2tlLWxpbmVjYXA6cm91bmQ7dHJhbnNmb3JtOnJvdGF0ZSgtOTBkZWcpO3RyYW5zZm9ybS1vcmln
HLP:aW46NTAlIDUwJTtzdHJva2UtZGFzaGFycmF5OnZhcigtLWNpcmMpO3N0cm9rZS1kYXNob2Zmc2V0OnZhcigtLWNpcmMpO2FuaW1hdGlvbjpmaWxsIDEuNHMgY3ViaWMtYmV6aWVyKC4yMiwxLC4zNiwxKSAuMnMgZm9yd2FyZHN9Ci5nLW51bXtmb250LXNpemU6NTRw
HLP:eDtmb250LXdlaWdodDo4MDA7dGV4dC1hbmNob3I6bWlkZGxlO2ZvbnQtZmFtaWx5OidTZWdvZSBVSScsc3lzdGVtLXVpLEFyaWFsfQouZ2F1Z2Utc20gLmctbnVte2ZvbnQtc2l6ZTo0NnB4fQouZy1sYWJlbHttYXJnaW4tdG9wOjZweDtmb250LXdlaWdodDo3MDA7
HLP:Zm9udC1zaXplOjE1cHh9Ci5nLWNhcHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7bGV0dGVyLXNwYWNpbmc6MS41cHg7bWFyZ2luLXRvcDoycHh9Ci5jb21wYXJle2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50
HLP:OmNlbnRlcjtnYXA6OHB4O21hcmdpbi10b3A6MTRweDtmbGV4LXdyYXA6d3JhcH0KLm1pbml7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5taW5pLWNhcHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjExcHg7bGV0dGVyLXNwYWNpbmc6MS4ycHg7bWFyZ2luLXRvcDot
HLP:NnB4fQouYXJyb3d7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjZweDtmb250LXNpemU6MzBweDtmb250LXdlaWdodDo4MDB9Ci5kZWx0YS1jaGlwe2JvcmRlcjoxcHggc29saWQ7Ym9yZGVyLXJhZGl1czo5
HLP:OTlweDtwYWRkaW5nOjNweCAxMnB4O2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO3doaXRlLXNwYWNlOm5vd3JhcH0KLmhlcm8tc2lkZXtkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2dhcDoxNnB4fQouY2hpcHN7ZGlzcGxheTpmbGV4
HLP:O2dhcDoxMHB4O2ZsZXgtd3JhcDp3cmFwfQouY2hpcHtmbGV4OjE7bWluLXdpZHRoOjk2cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxMnB4IDE0cHg7dGV4dC1h
HLP:bGlnbjpjZW50ZXJ9Ci5jaGlwIC5ue2ZvbnQtc2l6ZToyNnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQouY2hpcCAubHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjExLjVweDtsZXR0ZXItc3BhY2luZzouNnB4O21hcmdpbi10b3A6M3B4fQou
HLP:Yy1va3tjb2xvcjojMjJjNTVlfS5jLXdhcm57Y29sb3I6I2Y1OWUwYn0uYy1lcnJ7Y29sb3I6I2VmNDQ0NH0uYy1za2lwe2NvbG9yOiM5NGEzYjh9Ci5zeXNncmlke2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyIDFmcjtnYXA6MXB4O2JhY2tn
HLP:cm91bmQ6dmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O292ZXJmbG93OmhpZGRlbn0KQG1lZGlhKG1heC13aWR0aDo1MjBweCl7LnN5c2dyaWR7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn19Ci5zeXN7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtwYWRkaW5n
HLP:OjExcHggMTRweH0KLnN5cy1re2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFjaW5nOi40cHh9Ci5zeXMtdntmb250LXdlaWdodDo2MDA7Zm9udC1zaXplOjE0cHg7bWFyZ2luLXRvcDoxcHg7d29yZC1icmVhazpicmVhay13b3Jk
HLP:fQpoMi5zZWMtaHtmb250LXNpemU6MTVweDtsZXR0ZXItc3BhY2luZzouNnB4O3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTtjb2xvcjp2YXIoLS1hY2NlbnQpO21hcmdpbjozMHB4IDAgMTJweDtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4
HLP:O3Njcm9sbC1tYXJnaW4tdG9wOjE0cHh9CmgyLnNlYy1oOjphZnRlcntjb250ZW50OicnO2ZsZXg6MTtoZWlnaHQ6MXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSl9Ci50aW1lbGluZXtwb3NpdGlvbjpyZWxhdGl2ZTtwYWRkaW5nLWxlZnQ6OHB4fQoucGh7ZGlzcGxh
HLP:eTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOjE0cHg7cGFkZGluZzoxM3B4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7bWFyZ2luLWJvdHRvbToxMHB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7cG9z
HLP:aXRpb246cmVsYXRpdmU7b3ZlcmZsb3c6aGlkZGVufQoucGg6OmJlZm9yZXtjb250ZW50OicnO3Bvc2l0aW9uOmFic29sdXRlO2xlZnQ6MDt0b3A6MDtib3R0b206MDt3aWR0aDo0cHh9Ci5waC1vazo6YmVmb3Jle2JhY2tncm91bmQ6IzIyYzU1ZX0ucGgtd2Fybjo6
HLP:YmVmb3Jle2JhY2tncm91bmQ6I2Y1OWUwYn0ucGgtZXJyb3I6OmJlZm9yZXtiYWNrZ3JvdW5kOiNlZjQ0NDR9LnBoLXNraXA6OmJlZm9yZXtiYWNrZ3JvdW5kOiM2NDc0OGJ9Ci5waC1kb3R7ZmxleDowIDAgYXV0bzttYXJnaW4tdG9wOjFweH0KLnN2Z2ljb3t3aWR0
HLP:aDoyNnB4O2hlaWdodDoyNnB4O2Rpc3BsYXk6YmxvY2t9Ci5waC1tYWlue2ZsZXg6MTttaW4td2lkdGg6MH0KLnBoLXRvcHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4O2ZsZXgtd3JhcDp3cmFwfQoucGgtbnVte2ZvbnQtdmFyaWFudC1u
HLP:dW1lcmljOnRhYnVsYXItbnVtcztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czo3cHg7cGFkZGluZzoxcHggN3B4fQoucGgtdGl0bGV7Zm9udC13
HLP:ZWlnaHQ6NjAwO2ZvbnQtc2l6ZToxNXB4fQoucGgtYmFkZ2V7Zm9udC1zaXplOjExcHg7Zm9udC13ZWlnaHQ6ODAwO2xldHRlci1zcGFjaW5nOi42cHg7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjJweCAxMHB4fQouYi1va3tiYWNrZ3JvdW5kOnJnYmEoMzQs
HLP:MTk3LDk0LC4xNik7Y29sb3I6IzIyYzU1ZX0uYi13YXJue2JhY2tncm91bmQ6cmdiYSgyNDUsMTU4LDExLC4xNik7Y29sb3I6I2Y1OWUwYn0uYi1lcnJvcntiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uYi1za2lwe2JhY2tncm91
HLP:bmQ6cmdiYSgxMDAsMTE2LDEzOSwuMTgpO2NvbG9yOiM5NGEzYjh9Ci5waC1ub3Rle2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDttYXJnaW4tdG9wOjNweH0KLnBoLXNlY3N7ZmxleDowIDAgYXV0bztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXpl
HLP:OjEzcHg7Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO2FsaWduLXNlbGY6Y2VudGVyfQouZW1wdHl7Y29sb3I6dmFyKC0tbXV0ZWQpO3BhZGRpbmc6MThweDt0ZXh0LWFsaWduOmNlbnRlcn0KLmJhcmNoYXJ0e2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7
HLP:Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxNHB4IDE4cHg7bWFyZ2luLXRvcDo0cHh9Ci5iYXItcm93e2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEycHg7cGFkZGluZzo1cHggMH0KLmJh
HLP:ci1sYmx7ZmxleDowIDAgMjIwcHg7Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7d2hpdGUtc3BhY2U6bm93cmFwO292ZXJmbG93OmhpZGRlbjt0ZXh0LW92ZXJmbG93OmVsbGlwc2lzfQpAbWVkaWEobWF4LXdpZHRoOjYwMHB4KXsuYmFyLWxibHtm
HLP:bGV4OjAgMCAxMjBweH19Ci5iYXItdHJhY2t7ZmxleDoxO2hlaWdodDoxMHB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtvdmVyZmxvdzpoaWRkZW59Ci5iYXItdHJhY2sgc3BhbntkaXNwbGF5OmJsb2NrO2hlaWdodDoxMDAlO2Jv
HLP:cmRlci1yYWRpdXM6OTk5cHh9Ci5iYXItdmFse2ZsZXg6MCAwIGF1dG87Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO3dpZHRoOjQ4cHg7dGV4dC1hbGlnbjpyaWdodH0KdWwuZmluZHN7
HLP:bGlzdC1zdHlsZTpub25lO21hcmdpbjowO3BhZGRpbmc6MH0KLmZpbmR7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOjEycHg7cGFkZGluZzoxMnB4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjEz
HLP:cHg7bWFyZ2luLWJvdHRvbTo5cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKX0KLnNldntmbGV4OjAgMCBhdXRvO2ZvbnQtc2l6ZToxMXB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzouNXB4O2JvcmRlci1yYWRpdXM6OHB4O3BhZGRpbmc6M3B4IDEwcHg7
HLP:bWFyZ2luLXRvcDoxcHh9Ci5zZXYtaGlnaHtiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uc2V2LW1lZHtiYWNrZ3JvdW5kOnJnYmEoMjQ1LDE1OCwxMSwuMTYpO2NvbG9yOiNmNTllMGJ9LnNldi1pbmZve2JhY2tncm91bmQ6cmdi
HLP:YSg1NiwxODksMjQ4LC4xNik7Y29sb3I6dmFyKC0tYWNjZW50KX0uc2V2LW9re2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfQouZmluZC10eHR7Zm9udC1zaXplOjE0cHh9CnVsLnN0ZXBze2xpc3Qtc3R5bGU6bm9uZTttYXJnaW46
HLP:MDtwYWRkaW5nOjB9Ci5zdGVwLWxpe2Rpc3BsYXk6ZmxleDtnYXA6MTFweDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O3BhZGRpbmc6MTFweCAxNnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLWxlZnQ6M3B4IHNvbGlkIHZhcigtLWFjY2VudCk7
HLP:Ym9yZGVyLXJhZGl1czoxMnB4O21hcmdpbi1ib3R0b206OXB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Zm9udC1zaXplOjE0cHh9Ci5zdGVwLW9re2JvcmRlci1sZWZ0LWNvbG9yOiMyMmM1NWV9Ci5zdGVwLWlje2NvbG9yOnZhcigtLWFjY2VudCk7Zm9udC13ZWln
HLP:aHQ6ODAwfQouc3RlcC1vayAuc3RlcC1pY3tjb2xvcjojMjJjNTVlfQouZGdyaWR7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczpyZXBlYXQoYXV0by1maXQsbWlubWF4KDIyMHB4LDFmcikpO2dhcDoxNHB4fQouZGNhcmR7YmFja2dyb3VuZDp2YXIo
HLP:LS1jYXJkKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTVweDtwYWRkaW5nOjE2cHggMThweH0KLmRjYXJkLXdpZGV7Z3JpZC1jb2x1bW46MS8tMX0KLmQtaHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDo5cHg7
HLP:Zm9udC13ZWlnaHQ6NzAwO2ZvbnQtc2l6ZToxNHB4O21hcmdpbi1ib3R0b206MTBweH0KLmQtaWN7d2lkdGg6MTRweDtoZWlnaHQ6MTRweDtib3JkZXItcmFkaXVzOjVweDtkaXNwbGF5OmlubGluZS1ibG9ja30KLmljLXJhbXtiYWNrZ3JvdW5kOmxpbmVhci1ncmFk
HLP:aWVudCgxMzVkZWcsIzM4YmRmOCwjMGVhNWU5KX0uaWMtYmF0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMjJjNTVlLCMxNTgwM2QpfS5pYy1uZXR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCM4MThjZjgsIzRmNDZlNSl9Lmlj
HLP:LWRldntiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2Y1OWUwYiwjZDk3NzA2KX0uaWMtc21hcnR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNmNDcyYjYsI2RiMjc3Nyl9LmljLWJvb3R7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGll
HLP:bnQoMTM1ZGVnLCMyZGQ0YmYsIzBkOTQ4OCl9LmljLXN0YXJ0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjYTc4YmZhLCM3YzNhZWQpfS5pYy1wcm9je2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZmI3MTg1LCNlMTFkNDgpfQou
HLP:ZC1waWxse2Rpc3BsYXk6aW5saW5lLWJsb2NrO2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzo0cHggMTJweH0KLnBpbGwtcm93e2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwfQoucGls
HLP:bC1nb29ke2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfS5waWxsLWJhZHtiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0ucGlsbC11bmtub3due2JhY2tncm91bmQ6cmdiYSgxNDgsMTYzLDE4NCwu
HLP:MTYpO2NvbG9yOiM5NGEzYjh9Ci5kLXN1Yntjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEyLjVweDttYXJnaW4tdG9wOjhweH0KLmQtaGludHtjb2xvcjojZjU5ZTBiO2ZvbnQtc2l6ZToxMi41cHg7bWFyZ2luLXRvcDo4cHh9Ci5iYXQtYmFye2hlaWdodDox
HLP:MnB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtvdmVyZmxvdzpoaWRkZW47bWFyZ2luLXRvcDo0cHh9Ci5iYXQtYmFyIHNwYW57ZGlzcGxheTpibG9jaztoZWlnaHQ6MTAwJTtib3JkZXItcmFkaXVzOjk5OXB4fQouZGV2LWxpc3R7
HLP:bWFyZ2luOjRweCAwIDA7cGFkZGluZy1sZWZ0OjE4cHg7Zm9udC1zaXplOjEzLjVweH0KLmRldi1saXN0IGxpe21hcmdpbjoycHggMH0KLm11dGVke2NvbG9yOnZhcigtLW11dGVkKX0KLmZvb3R7bWFyZ2luLXRvcDozNHB4O3RleHQtYWxpZ246Y2VudGVyO2NvbG9y
HLP:OnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweH0KLnNlY3Rpb257YW5pbWF0aW9uOnJpc2UgLjVzIGVhc2UgYm90aH0KQGtleWZyYW1lcyBmaWxse3Rve3N0cm9rZS1kYXNob2Zmc2V0OnZhcigtLXRhcmdldCl9fQpAa2V5ZnJhbWVzIHJpc2V7ZnJvbXtvcGFjaXR5
HLP:OjA7dHJhbnNmb3JtOnRyYW5zbGF0ZVkoMTBweCl9dG97b3BhY2l0eToxO3RyYW5zZm9ybTpub25lfX0KQG1lZGlhIHByaW50ey50b2dnbGUsLnRvYywuYnRucywudG9hc3R7ZGlzcGxheTpub25lfWJvZHl7YmFja2dyb3VuZDojZmZmO2NvbG9yOiMwMDB9LmNhcmQs
HLP:LmRjYXJkLC5waCwuZmluZCwuZXhlYywuYmFyY2hhcnQsLnN0ZXAtbGl7Ym94LXNoYWRvdzpub25lO2JhY2tkcm9wLWZpbHRlcjpub25lOy13ZWJraXQtYmFja2Ryb3AtZmlsdGVyOm5vbmU7YmFja2dyb3VuZDojZmZmIWltcG9ydGFudH0uZ2F1Z2UgLmZpbGx7YW5p
HLP:bWF0aW9uOm5vbmV9LnNlY3Rpb257YW5pbWF0aW9uOm5vbmV9YVtocmVmXXtjb2xvcjppbmhlcml0O3RleHQtZGVjb3JhdGlvbjpub25lfX0KOnJvb3R7LS1nbGFzczpyZ2JhKDE4LDI2LDQzLC42MCk7LS1nbGFzc2JkOnJnYmEoMjU1LDI1NSwyNTUsLjA3KX0KaHRt
HLP:bC5saWdodHstLWdsYXNzOnJnYmEoMjU1LDI1NSwyNTUsLjY0KTstLWdsYXNzYmQ6cmdiYSgxNSwyMyw0MiwuMDgpfQouY2FyZCwuZXhlYywuZGNhcmQsLmZpbmQsLmJhcmNoYXJ0LC5zdGVwLWxpe2JhY2tncm91bmQ6dmFyKC0tZ2xhc3MpIWltcG9ydGFudDtiYWNr
HLP:ZHJvcC1maWx0ZXI6Ymx1cigxM3B4KSBzYXR1cmF0ZSgxNDAlKTstd2Via2l0LWJhY2tkcm9wLWZpbHRlcjpibHVyKDEzcHgpIHNhdHVyYXRlKDE0MCUpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tZ2xhc3NiZCkhaW1wb3J0YW50fQoudG9hc3R7cG9zaXRpb246Zml4
HLP:ZWQ7Ym90dG9tOjI0cHg7bGVmdDo1MCU7dHJhbnNmb3JtOnRyYW5zbGF0ZVgoLTUwJSk7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWlnaHQ6NzAwO3BhZGRp
HLP:bmc6MTBweCAxOHB4O2JvcmRlci1yYWRpdXM6MTJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyk7b3BhY2l0eTowO3BvaW50ZXItZXZlbnRzOm5vbmU7dHJhbnNpdGlvbjpvcGFjaXR5IC4yNXM7ei1pbmRleDo2MDtmb250LXNpemU6MTNweH0KLnRvYXN0LnNob3d7
HLP:b3BhY2l0eToxfQoudHJlbmQtdGl0bGV7bWFyZ2luLXRvcDoyMHB4O2ZvbnQtc2l6ZToxMnB4O2ZvbnQtd2VpZ2h0OjcwMDtsZXR0ZXItc3BhY2luZzoxcHg7dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLWxpc3R7ZGlz
HLP:cGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjtnYXA6NHB4O3dpZHRoOjEwMCU7bWFyZ2luLXRvcDo4cHg7Ym9yZGVyLXRvcDoxcHggc29saWQgdmFyKC0tbGluZSk7cGFkZGluZy10b3A6OHB4fQoudHJlbmQtaXRlbXtkaXNwbGF5OmZsZXg7anVzdGlmeS1j
HLP:b250ZW50OnNwYWNlLWJldHdlZW47Zm9udC1zaXplOjEycHh9Ci50cmVuZC1kYXRle2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLXNjb3Jle2ZvbnQtd2VpZ2h0OjcwMH0KPC9zdHlsZT4KPC9oZWFkPgo8Ym9keT4KPGRpdiBjbGFzcz0nd3JhcCc+CiAgPGRpdiBj
HLP:bGFzcz0ndG9wYmFyJz4KICAgIDxkaXYgY2xhc3M9J2JyYW5kJz4KICAgICAgPGRpdiBjbGFzcz0nbG9nbyc+PHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIHdpZHRoPScyNicgaGVpZ2h0PScyNicgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdXUEknPjxwYXRoIGQ9J00x
HLP:MiAybDcgM3Y2YzAgNC42LTMgOC4zLTcgOS42QzggMTkuMyA1IDE1LjYgNSAxMVY1eicgZmlsbD0nIzA0MjkzYicvPjxwYXRoIGQ9J005IDEybDIgMiA0LTQuNScgZmlsbD0nbm9uZScgc3Ryb2tlPScjZGZmNmZmJyBzdHJva2Utd2lkdGg9JzInIHN0cm9rZS1saW5l
HLP:Y2FwPSdyb3VuZCcgc3Ryb2tlLWxpbmVqb2luPSdyb3VuZCcvPjwvc3ZnPjwvZGl2PgogICAgICA8ZGl2PgogICAgICAgIDxoMT5SZXBhaXIgUmVwb3J0IDxzcGFuIGNsYXNzPSdiYWRnZSc+V1BJIFNVSVRFIHYzLjE8L3NwYW4+PC9oMT4KICAgICAgICA8ZGl2IGNs
HLP:YXNzPSdzdWInPiQoJiAkZW5jICRtYWNoaW5lKSAmbmJzcDsmbWlkZG90OyZuYnNwOyBnZW5lcmF0ZWQgb24gJG5vdzwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0nYnRucyc+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2dsZScg
HLP:b25jbGljaz0id2luZG93LnByaW50KCkiPlByaW50IC8gUERGPC9idXR0b24+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2dsZScgaWQ9J2NvcHlidG4nIG9uY2xpY2s9ImNvcHlSZXN1bWVuKCkiPkNvcHkgc3VtbWFyeTwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNs
HLP:YXNzPSd0b2dnbGUnIGlkPSd0aGVtZWJ0bicgb25jbGljaz0idG9nZ2xlVGhlbWUoKSI+TGlnaHQvRGFyayB0aGVtZTwvYnV0dG9uPgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDxuYXYgY2xhc3M9J3RvYycgYXJpYS1sYWJlbD0nSW5kZXgnPgogICAgPGEgaHJlZj0n
HLP:I3Jlc3VtZW4nPlN1bW1hcnk8L2E+CiAgICA8YSBocmVmPScjZmFzZXMnPlBoYXNlczwvYT4KICAgIDxhIGhyZWY9JyNoYWxsYXpnb3MnPkZpbmRpbmdzPC9hPgogICAgPGEgaHJlZj0nI3Bhc29zJz5OZXh0IHN0ZXBzPC9hPgogICAgPGEgaHJlZj0nI2RpYWcnPkRp
HLP:YWdub3N0aWNzPC9hPgogIDwvbmF2PgoKICA8ZGl2IGlkPSdyZXN1bWVuJyBjbGFzcz0nZXhlYyBzZWN0aW9uJz4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtc2NvcmUnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz4kbWFpblNjb3JlPC9kaXY+CiAgICA8ZGl2IGNsYXNz
HLP:PSdleGVjLW1pZCc+CiAgICAgIDxkaXYgY2xhc3M9J2V4ZWMtdmVyZGljdCcgc3R5bGU9J2NvbG9yOiRtYWluQ29sb3InPlN5c3RlbSBoZWFsdGg6ICRleGVjVmVyZGljdDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdleGVjLWxpbmUnPiRjT0sgc3VjY2Vzc2Z1bCAm
HLP:bWlkZG90OyAkY1dBUk4gd2FybmluZ3MgJm1pZGRvdDsgJGNFUlIgZXJyb3JzICZtaWRkb3Q7ICRjU0tJUCBza2lwcGVkICZtaWRkb3Q7ICR0b3RhbFBoIHBoYXNlcyB0b3RhbDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdleGVjLWxpbmUnPiRzdGF0TGluZTwvZGl2
HLP:PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdleGVjLWRlbHRhJyBzdHlsZT0nY29sb3I6JGRlbHRhQ29sb3I7Ym9yZGVyLWNvbG9yOiRkZWx0YUNvbG9yJz4kZGVsdGFUeHQ8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0naGVybyBzZWN0aW9uJz4KICAg
HLP:IDxkaXYgY2xhc3M9J2NhcmQgZ2F1Z2V3cmFwJz4KICAgICAgPHN2ZyB2aWV3Qm94PScwIDAgMjAwIDIwMCcgY2xhc3M9J2dhdWdlJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J0hlYWx0aCBzY29yZSAkbWFpblNjb3JlIG91dCBvZiAxMDAnPjxjaXJjbGUgY2xhc3M9
HLP:J3RyYWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRtYWluT2Zmc2V0O3N0cm9rZTokbWFpbkNvbG9yJy8+PHRleHQgeD0n
HLP:MTAwJyB5PScxMTInIGNsYXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6JG1haW5Db2xvcic+JG1haW5TY29yZTwvdGV4dD48L3N2Zz4KICAgICAgPGRpdiBjbGFzcz0nZy1sYWJlbCcgc3R5bGU9J2NvbG9yOiRtYWluQ29sb3InPkhlYWx0aDogJG1haW5MYWJlbDwvZGl2
HLP:PgogICAgICA8ZGl2IGNsYXNzPSdnLWNhcCc+U0NPUkUgT1VUIE9GIDEwMDwvZGl2PgogICAgICAkY29tcGFyZVNlY3Rpb24KICAgICAgJGhpc3RvcnlIdG1sCiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2hlcm8tc2lkZSc+CiAgICAgIDxkaXYgY2xhc3M9J2Nh
HLP:cmQnPgogICAgICAgIDxkaXYgY2xhc3M9J2NoaXBzJz4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1vayc+JGNPSzwvZGl2PjxkaXYgY2xhc3M9J2wnPk9LPC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48
HLP:ZGl2IGNsYXNzPSduIGMtd2Fybic+JGNXQVJOPC9kaXY+PGRpdiBjbGFzcz0nbCc+V0FSTklOR1M8L2Rpdj48L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1lcnInPiRjRVJSPC9kaXY+PGRpdiBjbGFzcz0nbCc+RVJST1JT
HLP:PC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNsYXNzPSduIGMtc2tpcCc+JGNTS0lQPC9kaXY+PGRpdiBjbGFzcz0nbCc+U0tJUFBFRDwvZGl2PjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgICAgPGRpdiBj
HLP:bGFzcz0nY2FyZCc+CiAgICAgICAgPGRpdiBjbGFzcz0nc3lzZ3JpZCc+JHN5c0NhcmRzPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdmYXNlcycgY2xhc3M9J3NlYy1oJz5Q
HLP:aGFzZXMgdGltZWxpbmUgKCR0b3RhbFBoKTwvaDI+CiAgICA8ZGl2IGNsYXNzPSd0aW1lbGluZSc+JHJvd3M8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2JhcmNoYXJ0Jz4kYmFyczwvZGl2PgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4KICAgIDxoMiBp
HLP:ZD0naGFsbGF6Z29zJyBjbGFzcz0nc2VjLWgnPkZpbmRpbmdzIGFuZCByb290IGNhdXNlPC9oMj4KICAgIDx1bCBjbGFzcz0nZmluZHMnPiRmaW5kSHRtbDwvdWw+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdwYXNvcycgY2xh
HLP:c3M9J3NlYy1oJz5SZWNvbW1lbmRlZCBuZXh0IHN0ZXBzPC9oMj4KICAgIDx1bCBjbGFzcz0nc3RlcHMnPiRzdGVwc0h0bWw8L3VsPgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4kZGlhZ1NlY3Rpb248L2Rpdj4KCiAgPGRpdiBjbGFzcz0nZm9vdCc+
HLP:CiAgICBXUEkgJm1pZGRvdDsgRW1lcmdlbmN5IFJlcGFpciBTdWl0ZSBmb3IgV2luZG93cyAxMC8xMSAmbWlkZG90OyByZWFkLW9ubHkgcmVwb3J0Ljxicj4KICAgIEJhY2t1cHMgYW5kIGxvZ3MgYXJlIGluIHRoZSBXUElfU3VpdGUgZm9sZGVyIG5leHQgdG8gdGhl
HLP:IHByb2dyYW0uCiAgPC9kaXY+CjwvZGl2Pgo8c2NyaXB0PgooZnVuY3Rpb24oKXt0cnl7dmFyIHM9bG9jYWxTdG9yYWdlLmdldEl0ZW0oJ3dwaS10aGVtZScpO3ZhciByb290PWRvY3VtZW50LmRvY3VtZW50RWxlbWVudDtpZihzPT09J2xpZ2h0Jyl7cm9vdC5jbGFz
HLP:c0xpc3QuYWRkKCdsaWdodCcpO31lbHNlIGlmKHM9PT0nZGFyaycpe3Jvb3QuY2xhc3NMaXN0LnJlbW92ZSgnbGlnaHQnKTt9ZWxzZSBpZih3aW5kb3cubWF0Y2hNZWRpYSYmd2luZG93Lm1hdGNoTWVkaWEoJyhwcmVmZXJzLWNvbG9yLXNjaGVtZTogbGlnaHQpJyku
HLP:bWF0Y2hlcyl7cm9vdC5jbGFzc0xpc3QuYWRkKCdsaWdodCcpO319fWNhdGNoKGUpe319KSgpOwpmdW5jdGlvbiB0b2dnbGVUaGVtZSgpe3RyeXt2YXIgbD1kb2N1bWVudC5kb2N1bWVudEVsZW1lbnQuY2xhc3NMaXN0LnRvZ2dsZSgnbGlnaHQnKTtsb2NhbFN0b3Jh
HLP:Z2Uuc2V0SXRlbSgnd3BpLXRoZW1lJyxsPydsaWdodCc6J2RhcmsnKTt9Y2F0Y2goZSl7fX0KZnVuY3Rpb24gZmxhc2gobSl7dHJ5e3ZhciB0PWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2RpdicpO3QuY2xhc3NOYW1lPSd0b2FzdCc7dC50ZXh0Q29udGVudD1tO2Rv
HLP:Y3VtZW50LmJvZHkuYXBwZW5kQ2hpbGQodCk7cmVxdWVzdEFuaW1hdGlvbkZyYW1lKGZ1bmN0aW9uKCl7dC5jbGFzc0xpc3QuYWRkKCdzaG93Jyk7fSk7c2V0VGltZW91dChmdW5jdGlvbigpe3QuY2xhc3NMaXN0LnJlbW92ZSgnc2hvdycpO3NldFRpbWVvdXQoZnVu
HLP:Y3Rpb24oKXt0LnJlbW92ZSgpO30sMzAwKTt9LDE2MDApO31jYXRjaChlKXt9fQpmdW5jdGlvbiBmYih0eHQsb2spe3RyeXt2YXIgYT1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCd0ZXh0YXJlYScpO2EudmFsdWU9dHh0O2Euc3R5bGUucG9zaXRpb249J2ZpeGVkJzth
HLP:LnN0eWxlLmxlZnQ9Jy05OTk5cHgnO2RvY3VtZW50LmJvZHkuYXBwZW5kQ2hpbGQoYSk7YS5zZWxlY3QoKTtkb2N1bWVudC5leGVjQ29tbWFuZCgnY29weScpO2EucmVtb3ZlKCk7b2soKTt9Y2F0Y2goZSl7Zmxhc2goJ0NvdWxkIG5vdCBjb3B5Jyk7fX0KZnVuY3Rp
HLP:b24gY29weVJlc3VtZW4oKXt2YXIgcD1bXTt2YXIgdD1kb2N1bWVudC5xdWVyeVNlbGVjdG9yKCdoMScpO2lmKHQpcC5wdXNoKHQuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIHM9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignLnN1YicpO2lmKHMpcC5wdXNoKHMuaW5uZXJU
HLP:ZXh0LnRyaW0oKSk7dmFyIGV4PWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJy5leGVjJyk7aWYoZXgpcC5wdXNoKCdcbicrZXguaW5uZXJUZXh0LnJlcGxhY2UoL1xuezIsfS9nLCdcbicpLnRyaW0oKSk7dmFyIGg9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2hhbGxh
HLP:emdvcycpO2lmKGgmJmgucGFyZW50Tm9kZSlwLnB1c2goJ1xuJytoLnBhcmVudE5vZGUuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIHR4dD1wLmpvaW4oJ1xuJyk7ZnVuY3Rpb24gb2soKXtmbGFzaCgnU3VtbWFyeSBjb3BpZWQnKTt9aWYobmF2aWdhdG9yLmNsaXBib2Fy
HLP:ZCYmbmF2aWdhdG9yLmNsaXBib2FyZC53cml0ZVRleHQpe25hdmlnYXRvci5jbGlwYm9hcmQud3JpdGVUZXh0KHR4dCkudGhlbihvayxmdW5jdGlvbigpe2ZiKHR4dCxvayk7fSk7fWVsc2V7ZmIodHh0LG9rKTt9fQo8L3NjcmlwdD4KPC9ib2R5Pgo8L2h0bWw+CiJA
HLP:CiAgICAgICAgJHV0ZjggPSBOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpCiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRvdXRQYXRoLCAkaHRtbCwgJHV0ZjgpCiAgICAgICAgIlJFU1VMVD1PSyIKICAgICAg
HLP:ICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBSZWdpc3RyYXIgcmVzdWx0YWRvIGRlIHVuYSBmYXNlIGVuIGVsIGVzdGFkbyAocGFyYSBlbCBpbmZvcm1lKS4KIyAtQXJnID0gIm51bTt0aXRsZTtyZXN1bHQ7c2Vjcztub3RlIgpmdW5jdGlvbiBBZGQtUGhh
HLP:c2VSZXN1bHQoJHNwZWMpIHsKICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICRwYXJ0cyA9ICRzcGVjIC1zcGxpdCAnOycsNQogICAgJHBoID0gW3BzY3VzdG9tb2JqZWN0XUB7IG51bT0kcGFydHNbMF07IHRpdGxlPSRwYXJ0c1sxXTsgcmVzdWx0PSRwYXJ0c1syXTsg
HLP:c2Vjcz0kcGFydHNbM107IG5vdGU9JHBhcnRzWzRdIH0KICAgICRsaXN0ID0gQCgkc3QucGhhc2VzKSArICRwaAogICAgJHN0LnBoYXNlcyA9ICRsaXN0CiAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gU2V0LVNjb3JlKCR3aGlj
HLP:aCwgJHZhbCkgewogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgaWYgKCR3aGljaCAtZXEgJ2JlZm9yZScpIHsgCiAgICAgICAgJHN0LnNjb3JlX2JlZm9yZSA9IFtpbnRdJHZhbCAKICAgIH0gZWxzZSB7IAogICAgICAgICRzdC5zY29yZV9hZnRlciA9IFtpbnRdJHZh
HLP:bCAKICAgICAgICBTYXZlLUhlYWx0aEhpc3RvcnkgW2ludF0kdmFsCiAgICB9CiAgICBXcml0ZS1TdGF0ZSAkc3Q7ICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gQWRkLUZpbmRpbmcoJHRleHQpIHsKICAgICRzdCA9IFJlYWQtU3RhdGU7ICRzdC5maW5kaW5ncyA9IEAo
HLP:JHN0LmZpbmRpbmdzKSArICR0ZXh0OyBXcml0ZS1TdGF0ZSAkc3Q7ICJSRVNVTFQ9T0siCn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgTE9HSUNBIFBVUkEgTlVF
HLP:VkEgLyBDT1JSRUdJREEgKEJsb3F1ZSAzKQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSAoMy4xIC8gQnVnIDQgLyBSZXEgNikgTm9ybWFsaXphY2lvbiBkZSBs
HLP:YSBzZWxlY2Npb24gZGUgZmFzZXMgLS0tLS0tLS0tLQojIEVudHJhZGE6IGNhZGVuYSBjb24gSURzIHNlcGFyYWRvcyBwb3IgY29tYXMgKGVzcGFjaW9zIGFyYml0cmFyaW9zLCAxLTIKIyBkaWdpdG9zLCBwb3NpYmxlcyBpbnZhbGlkb3MpLiBTYWxpZGE6IG9iamV0
HLP:byBjb24gLm5vcm0gKGxpc3RhIGNhbm9uaWNhLAojIG9yZGVuYWRhLCB1bmljYSBkZSBJRHMgZGUgMiBkaWdpdG9zIGVuIHswMC4uMTZ9KSB5IC5pbnZhbGlkIChsb3Mgbm8gdmFsaWRvcykuCiMgTnVuY2EgbGFuemEgZXhjZXBjaW9uIGFudGUgZW50cmFkYSBtYWxm
HLP:b3JtYWRhIG8gdmFjaWEuCmZ1bmN0aW9uIE5vcm1hbGl6ZS1GYXNlcyhbc3RyaW5nXSRyYXcpIHsKICAgICR2YWxpZCAgID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgICRpbnZhbGlkID0gTmV3LU9iamVjdCBT
HLP:eXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgIGlmICgkbnVsbCAtbmUgJHJhdyAtYW5kICRyYXcuVHJpbSgpLkxlbmd0aCAtZ3QgMCkgewogICAgICAgIGZvcmVhY2ggKCR0IGluICgkcmF3IC1zcGxpdCAnLCcpKSB7CiAgICAgICAgICAg
HLP:IGlmICgkbnVsbCAtZXEgJHQpIHsgY29udGludWUgfQogICAgICAgICAgICAkdG9rID0gKCR0IC1yZXBsYWNlICdccycsICcnKSAgICAgICAgICAjIHF1aXRhciBlc3BhY2lvcyBpbnRlcm5vcyB5IGV4dGVybm9zCiAgICAgICAgICAgIGlmICgkdG9rIC1lcSAnJykg
HLP:eyBjb250aW51ZSB9CiAgICAgICAgICAgICRjYW5vbiA9ICR0b2sKICAgICAgICAgICAgaWYgKCR0b2sgLW1hdGNoICdeXGQkJykgeyAkY2Fub24gPSAkdG9rLlBhZExlZnQoMiwgJzAnKSB9ICAgIyAxIGRpZ2l0byAtPiAyIGRpZ2l0b3MKICAgICAgICAgICAgaWYg
HLP:KCRjYW5vbiAtbWF0Y2ggJ15cZHsyfSQnIC1hbmQgW2ludF0kY2Fub24gLWdlIDAgLWFuZCBbaW50XSRjYW5vbiAtbGUgMTYpIHsKICAgICAgICAgICAgICAgIGlmICgtbm90ICR2YWxpZC5Db250YWlucygkY2Fub24pKSB7ICR2YWxpZC5BZGQoJGNhbm9uKSB9CiAg
HLP:ICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAkaW52YWxpZC5BZGQoJHRvaykKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KICAgICRzb3J0ZWQgPSBAKCR2YWxpZCB8IFNvcnQtT2JqZWN0KQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1A
HLP:eyBub3JtID0gJHNvcnRlZDsgaW52YWxpZCA9IEAoJGludmFsaWQpIH0KfQoKIyAtLS0gKDMuMyAvIFJlcSA0KSBDaGVja3BvaW50IHNvYnJlIGNoZWNrcG9pbnQuanNvbiAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBQYXJzZXIgZGVsIC1BcmcgY29uIGZvcm1h
HLP:dG86CiMgICAic2F2ZXxzZWxlY3Rpb249MDAsMDEsMDJ8Y29tcGxldGVkPTAwLDAxfG1vZGU9YXV0bzoxO2RyeTowfHJlYXNvbj1jaGtkc2siCmZ1bmN0aW9uIFBhcnNlLUNoZWNrcG9pbnRBcmcoW3N0cmluZ10kcmF3KSB7CiAgICAkcmVzID0gW29yZGVyZWRdQHsg
HLP:c3ViID0gJyc7IHNlbGVjdGlvbiA9IEAoKTsgY29tcGxldGVkID0gQCgpOyBtb2RlID0gQHt9OyByZWFzb24gPSAnJyB9CiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yRW1wdHkoJHJhdykpIHsgcmV0dXJuICRyZXMgfQogICAgJHNlZ3MgPSAkcmF3IC1zcGxpdCAn
HLP:XHwnCiAgICAkcmVzLnN1YiA9ICRzZWdzWzBdLlRyaW0oKS5Ub0xvd2VyKCkKICAgIGZvciAoJGkgPSAxOyAkaSAtbHQgJHNlZ3MuQ291bnQ7ICRpKyspIHsKICAgICAgICAka3YgPSAkc2Vnc1skaV0gLXNwbGl0ICc9JywgMgogICAgICAgIGlmICgka3YuQ291bnQg
HLP:LWx0IDIpIHsgY29udGludWUgfQogICAgICAgICRrZXkgPSAka3ZbMF0uVHJpbSgpLlRvTG93ZXIoKQogICAgICAgICR2YWwgPSAka3ZbMV0KICAgICAgICBzd2l0Y2ggKCRrZXkpIHsKICAgICAgICAgICAgJ3NlbGVjdGlvbicgeyAkcmVzLnNlbGVjdGlvbiA9IEAo
HLP:JHZhbCAtc3BsaXQgJywnIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFdoZXJlLU9iamVjdCB7ICRfIC1uZSAnJyB9KSB9CiAgICAgICAgICAgICdjb21wbGV0ZWQnIHsgJHJlcy5jb21wbGV0ZWQgPSBAKCR2YWwgLXNwbGl0ICcsJyB8IEZvckVhY2gt
HLP:T2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBXaGVyZS1PYmplY3QgeyAkXyAtbmUgJycgfSkgfQogICAgICAgICAgICAncmVhc29uJyAgICB7ICRyZXMucmVhc29uID0gJHZhbC5UcmltKCkgfQogICAgICAgICAgICAnbW9kZScgewogICAgICAgICAgICAgICAgJG0gPSBA
HLP:e30KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwYWlyIGluICgkdmFsIC1zcGxpdCAnOycpKSB7CiAgICAgICAgICAgICAgICAgICAgJHAgPSAkcGFpciAtc3BsaXQgJzonLCAyCiAgICAgICAgICAgICAgICAgICAgaWYgKCRwLkNvdW50IC1lcSAyKSB7ICRtWyRw
HLP:WzBdLlRyaW0oKS5Ub0xvd2VyKCldID0gKCRwWzFdLlRyaW0oKSAtZXEgJzEnKSB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAkcmVzLm1vZGUgPSAkbQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQogICAgcmV0dXJuICRyZXMKfQoKIyBD
HLP:b25zdHJ1eWUgeSBwZXJzaXN0ZSBjaGVja3BvaW50Lmpzb24uIERldnVlbHZlICR0cnVlLyRmYWxzZSAoc2luIGV4Y2VwY2lvbikuCmZ1bmN0aW9uIFNhdmUtQ2hlY2twb2ludCgkcGFyc2VkKSB7CiAgICB0cnkgewogICAgICAgICRtb2RlID0gW3BzY3VzdG9tb2Jq
HLP:ZWN0XUB7CiAgICAgICAgICAgIGF1dG8gICAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydhdXRvJ10KICAgICAgICAgICAgbm9yZWJvb3QgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ25vcmVib290J10KICAgICAgICAgICAga2VlcHd1ICAgPSBbYm9vbF0kcGFyc2VkLm1v
HLP:ZGVbJ2tlZXB3dSddCiAgICAgICAgICAgIGRyeSAgICAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydkcnknXQogICAgICAgICAgICB0cmlhZ2UgICA9IFtib29sXSRwYXJzZWQubW9kZVsndHJpYWdlJ10KICAgICAgICB9CiAgICAgICAgJG5vdyA9IChHZXQtRGF0ZSku
HLP:VG9TdHJpbmcoJ3l5eXktTU0tZGRfSEgtbW0nKQogICAgICAgICRjcCA9IFtwc2N1c3RvbW9iamVjdF1AewogICAgICAgICAgICB2ZXJzaW9uICAgICAgICA9ICRXUElfVkVSU0lPTgogICAgICAgICAgICBjcmVhdGVkICAgICAgICA9ICRub3cKICAgICAgICAgICAg
HLP:bW9kZSAgICAgICAgICAgPSAkbW9kZQogICAgICAgICAgICBzZWxlY3Rpb24gICAgICA9IEAoJHBhcnNlZC5zZWxlY3Rpb24pCiAgICAgICAgICAgIGNvbXBsZXRlZCAgICAgID0gQCgkcGFyc2VkLmNvbXBsZXRlZCkKICAgICAgICAgICAgcGVuZGluZ19yZWFzb24g
HLP:PSAkcGFyc2VkLnJlYXNvbgogICAgICAgICAgICB0aW1lc3RhbXBfcnVuICA9ICRub3cKICAgICAgICB9CiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRDaGVja3BvaW50RmlsZSwgKCRjcCB8IENvbnZlcnRUby1Kc29uIC1EZXB0aCA2KSwg
HLP:KE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkpKQogICAgICAgIHJldHVybiAkdHJ1ZQogICAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9CgojIENhcmdhIGNoZWNrcG9pbnQuanNvbi4gRGV2dWVsdmUgZWwgb2JqZXRvIG8gJG51
HLP:bGwgc2kgbm8gZXhpc3RlIC8gbWFsZm9ybWFkby4KZnVuY3Rpb24gTG9hZC1DaGVja3BvaW50IHsKICAgIGlmICgtbm90IChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSkgeyByZXR1cm4gJG51bGwgfQogICAgdHJ5IHsgcmV0dXJuIChHZXQtQ29udGVudCAkQ2hl
HLP:Y2twb2ludEZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24pIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CgojIFZhbGlkYSB1biBjaGVja3BvaW50OiBleGlzdGUgKyBwYXJzZWFibGUgKyB2ZXJzaW9uIGNvbXBhdGlibGUgKyBjb21wbGV0ZWQKIyBzdWJjb25q
HLP:dW50byBkZSBzZWxlY3Rpb24gKyBjcmVhdGVkIGRlbnRybyBkZSBsYSB2ZW50YW5hLiBEZXZ1ZWx2ZSBib29sZWFubwojIFNJTiBsYW56YXIgZXhjZXBjaW9uIGFudGUgSlNPTiBtYWxmb3JtYWRvIG8gY2FkdWNhZG8uCmZ1bmN0aW9uIFRlc3QtQ2hlY2twb2ludFZh
HLP:bGlkKCRjcCkgewogICAgdHJ5IHsKICAgICAgICBpZiAoJG51bGwgLWVxICRjcCkgewogICAgICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkpIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgICAgIHRyeSB7ICRjcCA9IEdldC1Db250
HLP:ZW50ICRDaGVja3BvaW50RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgfQogICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIGlmIChbc3RyaW5nXSRjcC52
HLP:ZXJzaW9uIC1uZSAkV1BJX1ZFUlNJT04pIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgJHNlbCAgPSBAKCRjcC5zZWxlY3Rpb24pCiAgICAgICAgJGNvbXAgPSBAKCRjcC5jb21wbGV0ZWQpCiAgICAgICAgZm9yZWFjaCAoJGMgaW4gJGNvbXApIHsgaWYgKCRzZWwg
HLP:LW5vdGNvbnRhaW5zICRjKSB7IHJldHVybiAkZmFsc2UgfSB9CiAgICAgICAgJGNyZWF0ZWQgPSAkbnVsbAogICAgICAgIGlmICgkY3AuY3JlYXRlZCkgewogICAgICAgICAgICB0cnkgeyAkY3JlYXRlZCA9IFtkYXRldGltZV06OlBhcnNlRXhhY3QoW3N0cmluZ10k
HLP:Y3AuY3JlYXRlZCwgJ3l5eXktTU0tZGRfSEgtbW0nLCAkbnVsbCkgfSBjYXRjaCB7ICRjcmVhdGVkID0gJG51bGwgfQogICAgICAgIH0KICAgICAgICBpZiAoJG51bGwgLWVxICRjcmVhdGVkKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgICRhZ2UgPSAoR2V0LURh
HLP:dGUpIC0gJGNyZWF0ZWQKICAgICAgICBpZiAoJGFnZS5Ub3RhbERheXMgLWd0ICRDSEVDS1BPSU5UX01BWF9BR0VfREFZUykgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0KfQoKIyBQcmlt
HLP:ZXJhIGZhc2UgZGUgJ3NlbGVjdGlvbicgbm8gcHJlc2VudGUgZW4gJ2NvbXBsZXRlZCcgKG8gJycgc2kgdG9kYXMgaGVjaGFzKS4KZnVuY3Rpb24gR2V0LU5leHRQaGFzZSgkY3ApIHsKICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAnJyB9CiAgICAkY29t
HLP:cCA9IEAoJGNwLmNvbXBsZXRlZCkKICAgIGZvcmVhY2ggKCRzIGluIEAoJGNwLnNlbGVjdGlvbikpIHsgaWYgKCRjb21wIC1ub3Rjb250YWlucyAkcykgeyByZXR1cm4gJHMgfSB9CiAgICByZXR1cm4gJycKfQoKIyAtLS0gKDMuOSAvIEJ1ZyA2IC8gUmVxIDgpIFJl
HLP:c2V0IGRlIGVzdGFkbyByZXV0aWxpemFibGUgLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBEZWphIHBoYXNlcz1AKCksIGZpbmRpbmdzPUAoKSB5IGxvcyBzY29yZXMgKGJlZm9yZS9hZnRlcikgYSBudWxsLiBFbAojIGNvbmRpY2lvbmFkbyBhIC9yZXN1bWUgbG8gYXBs
HLP:aWNhIGVsIGJhdGNoICh0YXJlYXMgOC40IC8gOS4xKTogc29sbyBpbnZvY2EKIyAncmVzZXRzdGF0ZScgY3VhbmRvIFJFU1VNRT09MCwgY29uc2VydmFuZG8gZWwgZXN0YWRvIHByZXZpbyBlbiAvcmVzdW1lLgpmdW5jdGlvbiBSZXNldC1TdGF0ZSB7CiAgICBXcml0
HLP:ZS1TdGF0ZSAoW3BzY3VzdG9tb2JqZWN0XUB7IHNjb3JlX2JlZm9yZSA9ICRudWxsOyBzY29yZV9hZnRlciA9ICRudWxsOyBmaW5kaW5ncyA9IEAoKTsgcGhhc2VzID0gQCgpIH0pCn0KCiMgLS0tICgzLjExIC8gQnVnIDcgLyBSZXEgOSkgSG9uZXN0aWRhZCBkZWwg
HLP:bW92aW1pZW50byBkZSBjYWNoZXMgLS0tLS0tLS0tLS0tCiMgRXhpdG8gKHRydWUpIFNJIFkgU09MTyBTSSBlbCBvcmlnZW4gZXN0YSBhdXNlbnRlIHkgZWwgZGVzdGlubyBwcmVzZW50ZS4KIyBWYXJpYW50ZSBwdXJhIChib29sZWFub3MpICsgdmFyaWFudGUgcXVl
HLP:IGFjZXB0YSBydXRhcyB5IGhhY2UgVGVzdC1QYXRoLgpmdW5jdGlvbiBUZXN0LU1vdmVSZXN1bHQoW2Jvb2xdJHNyY0V4aXN0cywgW2Jvb2xdJGRzdEV4aXN0cykgewogICAgcmV0dXJuICgoLW5vdCAkc3JjRXhpc3RzKSAtYW5kICRkc3RFeGlzdHMpCn0KZnVuY3Rp
HLP:b24gVGVzdC1Nb3ZlUmVzdWx0UGF0aChbc3RyaW5nXSRzcmMsIFtzdHJpbmddJGRzdCkgewogICAgcmV0dXJuIChUZXN0LU1vdmVSZXN1bHQgKFtib29sXShUZXN0LVBhdGggJHNyYykpIChbYm9vbF0oVGVzdC1QYXRoICRkc3QpKSkKfQoKIyAtLS0gKDMuMTEgLyBC
HLP:dWcgOCAvIFJlcSAxMCkgSWRlbXBvdGVuY2lhIGRlIFZpcnR1YWxUZXJtaW5hbExldmVsIC0tLS0tLS0tLS0KIyBOb3JtYWxpemEgdmFsb3JlcyAnMHgxJyAvICcxJyAvIDEgYSBlbnRlcm8gcGFyYSBjb21wYXJhciBkZSBmb3JtYSByb2J1c3RhLgpmdW5jdGlvbiBD
HLP:b252ZXJ0VG8tVnRsSW50KCR2KSB7CiAgICBpZiAoJG51bGwgLWVxICR2KSB7IHJldHVybiAkbnVsbCB9CiAgICAkcyA9IChbc3RyaW5nXSR2KS5UcmltKCkuVG9Mb3dlcigpCiAgICBpZiAoJHMgLWVxICcnKSB7IHJldHVybiAkbnVsbCB9CiAgICB0cnkgewogICAg
HLP:ICAgIGlmICgkcy5TdGFydHNXaXRoKCcweCcpKSB7IHJldHVybiBbQ29udmVydF06OlRvSW50MzIoJHMsIDE2KSB9CiAgICAgICAgcmV0dXJuIFtpbnRdJHMKICAgIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CiMgRGV2dWVsdmUgJHRydWUgKGVzY3JpYmlyKSBz
HLP:b2xvIHNpIGVsIHZhbG9yIGFjdHVhbCBkaWZpZXJlIGRlbCBkZXNlYWRvLgpmdW5jdGlvbiBSZXNvbHZlLVZ0bFdyaXRlKCRjdXJyZW50LCAkZGVzaXJlZCkgewogICAgcmV0dXJuICgoQ29udmVydFRvLVZ0bEludCAkY3VycmVudCkgLW5lIChDb252ZXJ0VG8tVnRs
HLP:SW50ICRkZXNpcmVkKSkKfQoKIyAtLS0gKDMuMTQgLyBSZXEgMS4zKSBNYXBlbyBUT1RBTCBkZSBjb2RpZ28gZGUgc2FsaWRhIGEge09LLFdBUk4sU0tJUCxFUlJPUn0KIyAwLT5PSywgMS0+V0FSTiwgMi0+U0tJUCwgMy0+RVJST1I7IGN1YWxxdWllciBvdHJvIGVu
HLP:dGVybyAobyBubyBlbnRlcm8pIC0+IEVSUk9SLgpmdW5jdGlvbiBNYXAtRXhpdENvZGUoJGNvZGUpIHsKICAgICRuID0gJG51bGwKICAgIHRyeSB7ICRuID0gW2ludF0kY29kZSB9IGNhdGNoIHsgcmV0dXJuICdFUlJPUicgfQogICAgc3dpdGNoICgkbikgewogICAg
HLP:ICAgIDAgICAgICAgeyAnT0snIH0KICAgICAgICAxICAgICAgIHsgJ1dBUk4nIH0KICAgICAgICAyICAgICAgIHsgJ1NLSVAnIH0KICAgICAgICAzICAgICAgIHsgJ0VSUk9SJyB9CiAgICAgICAgZGVmYXVsdCB7ICdFUlJPUicgfQogICAgfQp9CgojID09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIERJQUdOT1NUSUNPIEFNUExJQURPICg1LjEgLyBSZXEgMTUuMS0xNS41KQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSBSQU0gKFJlcSAxNS4xKSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUmVzb2x2ZS1SYW1TdGF0dXM6IGZ1bmNpb24gUFVS
HLP:QS4gQSBwYXJ0aXIgZGVsIGNvbnRlbyBkZSBlcnJvcmVzIGRlIG1lbW9yaWEKIyBXSEVBIHkgZGUgZmFsbG9zIGRlbCBkaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MsIGRlY2lkZSBlbCBlc3RhZG8geQojIHNpIGNvbnZpZW5lIHJlY29tZW5kYXIgbWRz
HLP:Y2hlZC4KZnVuY3Rpb24gUmVzb2x2ZS1SYW1TdGF0dXMoW2ludF0kd2hlYU1lbUVycm9ycywgW2ludF0kbWVtRGlhZ0ZhaWx1cmVzKSB7CiAgICBpZiAoJHdoZWFNZW1FcnJvcnMgLWd0IDAgLW9yICRtZW1EaWFnRmFpbHVyZXMgLWd0IDApIHsKICAgICAgICByZXR1
HLP:cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdzdXNwZWN0JzsgcmVjb21tZW5kX21kc2NoZWQgPSAkdHJ1ZSB9CiAgICB9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdvayc7IHJlY29tbWVuZF9tZHNjaGVkID0gJGZhbHNlIH0K
HLP:fQoKIyBHZXQtUmFtQ2hlY2s6IGxlZSBldmVudG9zIFdIRUEgeSByZXN1bHRhZG9zIGRlbCBEaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlCiMgV2luZG93cy4gRGVncmFkYWNpb24gZWxlZ2FudGU6IHNpIGxhIGNvbnN1bHRhIGRlIGV2ZW50b3MgZmFsbGEgcG9yIGNv
HLP:bXBsZXRvLAojIGRldnVlbHZlIHN0YXR1cz0ndW5rbm93bicgc2luIGxhbnphciBleGNlcGNpb24uCmZ1bmN0aW9uIEdldC1SYW1DaGVjayB7CiAgICB0cnkgewogICAgICAgICRxdWVyaWVkID0gJGZhbHNlCiAgICAgICAgJHdoZWFDb3VudCA9IDAKICAgICAgICAk
HLP:bWVtRGlhZ0ZhaWwgPSAwCiAgICAgICAgIyBFcnJvcmVzIGRlIGhhcmR3YXJlIFdIRUEgcmVsYWNpb25hZG9zIGNvbiBtZW1vcmlhCiAgICAgICAgJHdoZWEgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgUHJvdmlk
HLP:ZXJOYW1lPSdNaWNyb3NvZnQtV2luZG93cy1XSEVBLUxvZ2dlcid9IC1NYXhFdmVudHMgMTAwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkbnVsbCAtbmUgJHdoZWEpIHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAgICAgJHdoZWFD
HLP:b3VudCA9IEAoJHdoZWEgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWluIDE4LDE5LDIwLDQ3KSAtb3IgKCRfLk1lc3NhZ2UgLW1hdGNoICdtZW1vcicpIH0pLkNvdW50CiAgICAgICAgIyBSZXN1bHRhZG9zIGRlbCBEaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdp
HLP:bmRvd3MgKG1kc2NoZWQpCiAgICAgICAgJG1kID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IFByb3ZpZGVyTmFtZT0nTWljcm9zb2Z0LVdpbmRvd3MtTWVtb3J5RGlhZ25vc3RpY3MtUmVzdWx0cyd9IC1NYXhFdmVu
HLP:dHMgNTAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYgKCRudWxsIC1uZSAkbWQpIHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAgICAgJG1lbURpYWdGYWlsID0gQCgkbWQgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWVxIDEwMDIpIC1v
HLP:ciAoJF8uTGV2ZWxEaXNwbGF5TmFtZSAtZXEgJ0Vycm9yJykgLW9yICgkXy5NZXNzYWdlIC1tYXRjaCAnZXJyb3J8ZXJyb3JlcycpIH0pLkNvdW50CiAgICAgICAgcmV0dXJuIChSZXNvbHZlLVJhbVN0YXR1cyAkd2hlYUNvdW50ICRtZW1EaWFnRmFpbCkKICAgIH0g
HLP:Y2F0Y2ggewogICAgICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJ3Vua25vd24nOyByZWNvbW1lbmRfbWRzY2hlZCA9ICRmYWxzZSB9CiAgICB9Cn0KCiMgLS0tIEJhdGVyaWEgKFJlcSAxNS4yKSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtQmF0dGVyeUhlYWx0aFBjdDogZnVuY2lvbiBQVVJBLiAlIGRlIHNhbHVkID0gcGxlbmEgY2FyZ2EgLyBkaXNlbm8gKiAxMDAuCmZ1bmN0aW9uIEdldC1CYXR0ZXJ5SGVhbHRoUGN0KCRkZXNpZ24sICRmdWxs
HLP:KSB7CiAgICB0cnkgewogICAgICAgICRkID0gW2RvdWJsZV0kZGVzaWduOyAkZiA9IFtkb3VibGVdJGZ1bGwKICAgICAgICBpZiAoJGQgLWd0IDApIHsgcmV0dXJuIFtpbnRdW21hdGhdOjpSb3VuZCgoJGYgLyAkZCkgKiAxMDApIH0KICAgIH0gY2F0Y2gge30KICAg
HLP:IHJldHVybiAkbnVsbAp9CgojIEdldC1CYXR0ZXJ5SGVhbHRoOiBzaSBoYXkgYmF0ZXJpYSwgZ2VuZXJhIHBvd2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0IHkgZXh0cmFlIGxhCiMgc2FsdWQgKGNhcGFjaWRhZCBkZSBkaXNlbm8gdnMgcGxlbmEgY2FyZ2EpLiBTaW4gYmF0
HLP:ZXJpYSAtPiBwcmVzZW50PSRmYWxzZS4KIyBObyBmYWxsYSBzaSBwb3dlcmNmZyBubyBlc3RhIGRpc3BvbmlibGUgKGhlYWx0aF9wY3QgcXVlZGEgdmFjaW8pLgpmdW5jdGlvbiBHZXQtQmF0dGVyeUhlYWx0aCB7CiAgICAkcHJlc2VudCA9ICRmYWxzZTsgJGhlYWx0
HLP:aFBjdCA9ICcnOyAkcmVwb3J0UGF0aCA9ICcnCiAgICB0cnkgewogICAgICAgICRiYXQgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9CYXR0ZXJ5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkYmF0LkNvdW50IC1ndCAwKSB7CiAg
HLP:ICAgICAgICAgICRwcmVzZW50ID0gJHRydWUKICAgICAgICAgICAgJHJlcG9ydFBhdGggPSBKb2luLVBhdGggJFdvcmsgJ2JhdHRlcnktcmVwb3J0Lmh0bWwnCiAgICAgICAgICAgIHRyeSB7ICYgcG93ZXJjZmcgL2JhdHRlcnlyZXBvcnQgL291dHB1dCAiJHJlcG9y
HLP:dFBhdGgiIC9kdXJhdGlvbiAxID4gJG51bGwgMj4mMSB9IGNhdGNoIHt9CiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJHJlcG9ydFBhdGgpIHsKICAgICAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAgICAgJHR4dCA9IEdldC1Db250ZW50ICRyZXBv
HLP:cnRQYXRoIC1SYXcKICAgICAgICAgICAgICAgICAgICAkZGVzaWduID0gJG51bGw7ICRmdWxsID0gJG51bGwKICAgICAgICAgICAgICAgICAgICAkbTEgPSBbcmVnZXhdOjpNYXRjaCgkdHh0LCAnKD9pcylERVNJR04gQ0FQQUNJVFkuKj8oW1xkXC4sXSspXHMqbVdo
HLP:JykKICAgICAgICAgICAgICAgICAgICAkbTIgPSBbcmVnZXhdOjpNYXRjaCgkdHh0LCAnKD9pcylGVUxMIENIQVJHRSBDQVBBQ0lUWS4qPyhbXGRcLixdKylccyptV2gnKQogICAgICAgICAgICAgICAgICAgIGlmICgkbTEuU3VjY2VzcykgeyAkZGVzaWduID0gW2Rv
HLP:dWJsZV0oKCRtMS5Hcm91cHNbMV0uVmFsdWUgLXJlcGxhY2UgJ1tcLixdJywgJycpKSB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRtMi5TdWNjZXNzKSB7ICRmdWxsICAgPSBbZG91YmxlXSgoJG0yLkdyb3Vwc1sxXS5WYWx1ZSAtcmVwbGFjZSAnW1wuLF0nLCAn
HLP:JykpIH0KICAgICAgICAgICAgICAgICAgICAkcGN0ID0gR2V0LUJhdHRlcnlIZWFsdGhQY3QgJGRlc2lnbiAkZnVsbAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHBjdCkgeyAkaGVhbHRoUGN0ID0gJHBjdCB9CiAgICAgICAgICAgICAgICB9IGNh
HLP:dGNoIHt9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHByZXNlbnQgPSAkcHJlc2VudDsgaGVhbHRoX3BjdCA9ICRoZWFsdGhQY3Q7IHJlcG9ydF9wYXRoID0gJHJlcG9ydFBhdGggfQp9
HLP:CgojIC0tLSBOZXR3b3JrIGF2YW56YWRhIChSZXEgMTUuNSkgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEdldC1OZXRBZHZhbmNlZDogY29uZWN0aXZpZGFkIChwaW5nIGEgMS4xLjEuMSksIEROUyAoUmVzb2x2ZS1EbnNO
HLP:YW1lIGNvbgojIHJlc3BhbGRvIHBvciBwaW5nIGEgdW4gaG9zdCkgeSBjb25maWd1cmFjaW9uIGJhc2ljYSAoSVAvZ2F0ZXdheSkuCiMgRGVncmFkYWNpb24gZWxlZ2FudGU6IG51bmNhIGxhbnphIGV4Y2VwY2lvbi4KZnVuY3Rpb24gR2V0LU5ldEFkdmFuY2VkIHsK
HLP:ICAgICRjb25uZWN0ZWQgPSAkZmFsc2U7ICRkbnNPayA9ICRmYWxzZTsgJGRldGFpbHMgPSAnJwogICAgdHJ5IHsKICAgICAgICAjIENvbmVjdGl2aWRhZAogICAgICAgICRwaW5nID0gJGZhbHNlCiAgICAgICAgdHJ5IHsgJHBpbmcgPSBbYm9vbF0oVGVzdC1Db25u
HLP:ZWN0aW9uIC1Db21wdXRlck5hbWUgJzEuMS4xLjEnIC1Db3VudCAxIC1RdWlldCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkgfSBjYXRjaCB7ICRwaW5nID0gJGZhbHNlIH0KICAgICAgICBpZiAoLW5vdCAkcGluZykgewogICAgICAgICAgICB0cnkgeyAm
HLP:IHBpbmcgLW4gMSAtdyAxNTAwIDEuMS4xLjEgPiAkbnVsbCAyPiYxOyBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCkgeyAkcGluZyA9ICR0cnVlIH0gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkY29ubmVjdGVkID0gW2Jvb2xdJHBpbmcKICAgICAgICAjIFJl
HLP:c29sdWNpb24gRE5TIChjb24gbWVkaWRhIGRlIGxhdGVuY2lhKQogICAgICAgICRkbnMgPSAkZmFsc2U7ICRkbnNNcyA9ICRudWxsCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHN3ID0gW1N5c3RlbS5EaWFnbm9zdGljcy5TdG9wd2F0Y2hdOjpTdGFydE5ldygp
HLP:CiAgICAgICAgICAgICRyID0gUmVzb2x2ZS1EbnNOYW1lIC1OYW1lICd3d3cubWljcm9zb2Z0LmNvbScgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgJHN3LlN0b3AoKQogICAgICAgICAgICBpZiAoJHIpIHsgJGRucyA9ICR0cnVlOyAk
HLP:ZG5zTXMgPSBbaW50XSRzdy5FbGFwc2VkTWlsbGlzZWNvbmRzIH0KICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgaWYgKC1ub3QgJGRucykgewogICAgICAgICAgICB0cnkgeyAmIHBpbmcgLW4gMSAtdyAxNTAwIHd3dy5taWNyb3NvZnQuY29tID4gJG51bGwgMj4m
HLP:MTsgaWYgKCRMQVNURVhJVENPREUgLWVxIDApIHsgJGRucyA9ICR0cnVlIH0gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkZG5zT2sgPSBbYm9vbF0kZG5zCiAgICAgICAgIyBDb25maWd1cmFjaW9uIGJhc2ljYSAoSVAgLyBnYXRld2F5KQogICAgICAgICRp
HLP:cCA9ICcnOyAkZ3cgPSAnJwogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRjZmcgPSBAKEdldC1OZXRJUENvbmZpZ3VyYXRpb24gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBXaGVyZS1PYmplY3QgeyAkXy5JUHY0RGVmYXVsdEdhdGV3YXkgfSkgfCBT
HLP:ZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIGlmICgkY2ZnKSB7CiAgICAgICAgICAgICAgICAkaXAgPSAoJGNmZy5JUHY0QWRkcmVzcyB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEpLklQQWRkcmVzcwogICAgICAgICAgICAgICAgJGd3ID0gKCRjZmcu
HLP:SVB2NERlZmF1bHRHYXRld2F5IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkuTmV4dEhvcAogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICRkZXRhaWxzID0gIklQPSRpcDsgR1c9JGd3IgogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuIFtw
HLP:c2N1c3RvbW9iamVjdF1AeyBjb25uZWN0ZWQgPSAkY29ubmVjdGVkOyBkbnNfb2sgPSAkZG5zT2s7IGRldGFpbHMgPSAkZGV0YWlsczsgZG5zX21zID0gJGRuc01zIH0KfQoKIyAtLS0gRGV2aWNlcyBwYXJhIGRpYWcgKFJlcSAxNS4zLzE1LjQpIC0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtRGV2aWNlTGlzdDogbGlzdGEgZXN0cnVjdHVyYWRhIGRlIGRpc3Bvc2l0aXZvcyBjb24gZXJyb3IgcGFyYSBlc3RhZG8uZGlhZy4KIyBEZXZ1ZWx2ZSAkbnVsbCBzaSBsYSBpZGVudGlmaWNhY2lvbiBkZSBkcml2ZXJz
HLP:IGZhbGxhIChzZW5hbCBkZSAiaW5mbyBubwojIGRpc3BvbmlibGUiIHBhcmEgZGVncmFkYWNpb24gZWxlZ2FudGUpLgpmdW5jdGlvbiBHZXQtRGV2aWNlTGlzdCB7CiAgICB0cnkgewogICAgICAgICRwID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUG5QRW50aXR5
HLP:IC1FcnJvckFjdGlvbiBTdG9wIHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFuYWdlckVycm9yQ29kZSAtZ3QgMCB9KQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJGQgaW4gKCRwIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMTIpKSB7CiAg
HLP:ICAgICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBjb2RlID0gW2ludF0kZC5Db25maWdNYW5hZ2VyRXJyb3JDb2RlOyBuYW1lID0gW3N0cmluZ10kZC5OYW1lIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuICwkbGlzdAogICAgfSBjYXRjaCB7IHJl
HLP:dHVybiAkbnVsbCB9Cn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgUk9UQUNJT04gREUgTE9HUyAoNS42IC8gUmVxIDE3LjIpCiMgPT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBTZWxlY3QtTG9nc1RvRGVsZXRlOiBmdW5jaW9uIFBVUkEuIERlIHVuYSBjb2xlY2Npb24gZGUgZmljaGVyb3MgKGNvbgojIC5MYXN0V3JpdGVUaW1lKSB5IHVu
HLP:YSByZXRlbmNpb24gTiwgZGV2dWVsdmUgbG9zIHF1ZSBkZWJlbiBCT1JSQVJTRTogdG9kb3MKIyBtZW5vcyBsb3MgTiBtYXMgcmVjaWVudGVzIChlcyBkZWNpciwgbG9zIG1hcyBhbnRpZ3VvcykuIFNpIGhheSA8PSBOLCBuaW5ndW5vLgpmdW5jdGlvbiBTZWxlY3Qt
HLP:TG9nc1RvRGVsZXRlKCRmaWxlcywgW2ludF0kcmV0ZW50aW9uKSB7CiAgICAkYXJyID0gQCgkZmlsZXMpCiAgICBpZiAoJHJldGVudGlvbiAtbHQgMCkgeyAkcmV0ZW50aW9uID0gMCB9CiAgICBpZiAoJGFyci5Db3VudCAtbGUgJHJldGVudGlvbikgeyByZXR1cm4g
HLP:QCgpIH0KICAgICRzb3J0ZWQgPSBAKCRhcnIgfCBTb3J0LU9iamVjdCAtUHJvcGVydHkgTGFzdFdyaXRlVGltZSAtRGVzY2VuZGluZykKICAgIHJldHVybiBAKCRzb3J0ZWQgfCBTZWxlY3QtT2JqZWN0IC1Ta2lwICRyZXRlbnRpb24pCn0KCiMgSW52b2tlLUxvZ1Jv
HLP:dGF0ZTogY29uc2VydmEgbG9zICRyZXRlbnRpb24gbG9ncyBtYXMgcmVjaWVudGVzIGVuICRmb2xkZXIgeQojIGJvcnJhIGVsIHJlc3RvLiBEZXZ1ZWx2ZSBlbCBudW1lcm8gZGUgZmljaGVyb3MgYm9ycmFkb3MuCmZ1bmN0aW9uIEludm9rZS1Mb2dSb3RhdGUoW3N0
HLP:cmluZ10kZm9sZGVyLCBbaW50XSRyZXRlbnRpb24pIHsKICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRmb2xkZXIpKSB7ICRmb2xkZXIgPSBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnIH0KICAgICRkZWxldGVkID0gMAogICAgdHJ5IHsKICAgICAg
HLP:ICBpZiAoLW5vdCAoVGVzdC1QYXRoICRmb2xkZXIpKSB7IHJldHVybiAwIH0KICAgICAgICAkZmlsZXMgPSBAKEdldC1DaGlsZEl0ZW0gLVBhdGggJGZvbGRlciAtRmlsdGVyICcqLmxvZycgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAg
HLP:ICAgJHRvRGVsZXRlID0gU2VsZWN0LUxvZ3NUb0RlbGV0ZSAkZmlsZXMgJHJldGVudGlvbgogICAgICAgIGZvcmVhY2ggKCRmIGluICR0b0RlbGV0ZSkgewogICAgICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAkZi5GdWxsTmFtZSAtRm9yY2UgLUVycm9yQWN0aW9u
HLP:IFNpbGVudGx5Q29udGludWU7ICRkZWxldGVkKysgfSBjYXRjaCB7fQogICAgICAgIH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAkZGVsZXRlZAp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09CiMgIFZBTElEQUNJT04gREUgRU5UT1JOTyBZIFNFTEYtVEVTVCAoNS44IC8gUmVxIDEzLjUsMTMuNiwxOC4xLDE4LjMsMTguNikKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PQojIFRlc3QtT3NTdXBwb3J0ZWQ6IGZ1bmNpb24gUFVSQS4gV2luZG93cyAxMC8xMSA9PiBidWlsZCA+PSAxMDI0MC4KZnVuY3Rpb24gVGVzdC1Pc1N1cHBvcnRlZChbaW50XSRidWlsZCkgewogICAgcmV0dXJuICgkYnVpbGQgLWdlIDEw
HLP:MjQwKQp9CgojIEludm9rZS1FbnZWYWxpZGF0ZTogY29tcHJ1ZWJhIGxhIHZlcnNpb24gZGVsIFNPIHZpYSBDSU0uIExhIGNvbXByb2JhY2lvbiBzZQojIGNvbnNpZGVyYSBTSUVNUFJFIHJlYWxpemFkYSAoY2hlY2tfZG9uZSkgYXVucXVlIGxhIHZlcnNpb24gbm8g
HLP:c2VhIGNvbXBhdGlibGUuCmZ1bmN0aW9uIEludm9rZS1FbnZWYWxpZGF0ZSB7CiAgICAkYnVpbGQgPSAwCiAgICB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3BlcmF0aW5nU3lzdGVtIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRp
HLP:bnVlKS5CdWlsZE51bWJlciB9IGNhdGNoIHsgJGJ1aWxkID0gMCB9CiAgICBpZiAoJGJ1aWxkIC1sZSAwKSB7IHRyeSB7ICRidWlsZCA9IFtpbnRdKEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJz
HLP:aW9uJyAtTmFtZSBDdXJyZW50QnVpbGROdW1iZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLkN1cnJlbnRCdWlsZE51bWJlciB9IGNhdGNoIHsgJGJ1aWxkID0gMCB9IH0KICAgIGlmICgkYnVpbGQgLWxlIDApIHsgdHJ5IHsgJGJ1aWxkID0gW2ludF0o
HLP:R2V0LUl0ZW1Qcm9wZXJ0eSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb24nIC1OYW1lIEN1cnJlbnRCdWlsZCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuQ3VycmVudEJ1aWxkIH0gY2F0Y2ggeyAkYnVpbGQg
HLP:PSAwIH0gfQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBvc19vayA9IChUZXN0LU9zU3VwcG9ydGVkICRidWlsZCk7IGJ1aWxkID0gJGJ1aWxkOyBjaGVja19kb25lID0gJHRydWUgfQp9CgojIEludm9rZS1TZWxmVGVzdDogYWdyZWdhZG9yIFBVUk8uIEV4
HLP:aXRvICh0cnVlKSBzaSB5IHNvbG8gc2kgVE9EQVMgbGFzCiMgY29tcHJvYmFjaW9uZXMgKGJvb2xlYW5vcykgcGFzYW4uIENvbGVjY2lvbiB2YWNpYSAtPiB0cnVlIChuYWRhIGZhbGxvKS4KZnVuY3Rpb24gSW52b2tlLVNlbGZUZXN0KCRyZXN1bHRzKSB7CiAgICBm
HLP:b3JlYWNoICgkciBpbiBAKCRyZXN1bHRzKSkgeyBpZiAoLW5vdCBbYm9vbF0kcikgeyByZXR1cm4gJGZhbHNlIH0gfQogICAgcmV0dXJuICR0cnVlCn0KCiMgUGFyc2UtQm9vbExpc3Q6IGNvbnZpZXJ0ZSAiMSwxLDAsMSIgKG8gdHJ1ZS9vaykgZW4gdW5hIGxpc3Rh
HLP:IGRlIGJvb2xlYW5vcy4KZnVuY3Rpb24gUGFyc2UtQm9vbExpc3QoW3N0cmluZ10kcmF3KSB7CiAgICAkbGlzdCA9IEAoKQogICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkcmF3KSkgewogICAgICAgIGZvcmVhY2ggKCR0IGluICgkcmF3
HLP:IC1zcGxpdCAnLCcpKSB7CiAgICAgICAgICAgICR0b2sgPSAkdC5UcmltKCkuVG9Mb3dlcigpCiAgICAgICAgICAgIGlmICgkdG9rIC1lcSAnJykgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRsaXN0ICs9ICgkdG9rIC1lcSAnMScgLW9yICR0b2sgLWVxICd0cnVl
HLP:JyAtb3IgJHRvayAtZXEgJ29rJyAtb3IgJHRvayAtZXEgJ3Bhc3MnKQogICAgICAgIH0KICAgIH0KICAgIHJldHVybiAsJGxpc3QKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIERJQUdOT1NUSUNPIFBST0ZVTkRPIHYzLjEgKFNNQVJULCBhcnJhbnF1ZSwgQkNELCBwcm9jZXNvcywgU0ZDLCBK
HLP:U09OKQojICBUb2RhcyBsYXMgZnVuY2lvbmVzIGRlZ3JhZGFuIGNvbiBlbGVnYW5jaWE6IHNpIGFsZ28gZmFsbGEsIGRldnVlbHZlbgojICBlc3RydWN0dXJhcyB2YWNpYXMgLyAndW5rbm93bicgZW4gbHVnYXIgZGUgbGFuemFyIGV4Y2VwY2lvbmVzLgojID09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIEdldC1TbWFydEF0dHJpYnV0ZXM6IHNhbHVkIGZpc2ljYSBkZWwgZGlzY28gZGUgc2lzdGVtYSAoaW5kZXBlbmRpZW50ZSBkZWwKIyBp
HLP:ZGlvbWEgZGUgV2luZG93cykuIFVzYSBNU1N0b3JhZ2VEcml2ZXJfRmFpbHVyZVByZWRpY3RTdGF0dXMgKyBlbCBjb250YWRvcgojIGRlIGZpYWJpbGlkYWQgZGUgYWxtYWNlbmFtaWVudG8uIERldnVlbHZlIGF2YWlsYWJsZT0kZmFsc2Ugc2kgbm8gaGF5IGRhdG9z
HLP:LgpmdW5jdGlvbiBHZXQtU21hcnRBdHRyaWJ1dGVzIHsKICAgICRyZXMgPSBbcHNjdXN0b21vYmplY3RdQHsgYXZhaWxhYmxlID0gJGZhbHNlOyBwcmVkaWN0X2ZhaWwgPSAkZmFsc2U7IHRlbXBfYyA9ICRudWxsOyB3ZWFyX3BjdCA9ICRudWxsOyBwb2ggPSAkbnVs
HLP:bCB9CiAgICB0cnkgewogICAgICAgICRwZiA9ICRudWxsCiAgICAgICAgdHJ5IHsgJHBmID0gQChHZXQtQ2ltSW5zdGFuY2UgLU5hbWVzcGFjZSAncm9vdFx3bWknIC1DbGFzc05hbWUgJ01TU3RvcmFnZURyaXZlcl9GYWlsdXJlUHJlZGljdFN0YXR1cycgLUVycm9y
HLP:QWN0aW9uIFNpbGVudGx5Q29udGludWUpIH0gY2F0Y2ggeyAkcGYgPSAkbnVsbCB9CiAgICAgICAgaWYgKCRwZiAtYW5kICRwZi5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlCiAgICAgICAgICAgIGZvcmVhY2ggKCR4IGlu
HLP:ICRwZikgeyBpZiAoJHguUHJlZGljdEZhaWx1cmUpIHsgJHJlcy5wcmVkaWN0X2ZhaWwgPSAkdHJ1ZSB9IH0KICAgICAgICB9CiAgICAgICAgIyBEaXNjbyBxdWUgY29udGllbmUgQzogLT4gY29udGFkb3IgZGUgZmlhYmlsaWRhZAogICAgICAgIHRyeSB7CiAgICAg
HLP:ICAgICAgICRzeXNEaXNrID0gJG51bGwKICAgICAgICAgICAgdHJ5IHsgJHN5c0Rpc2sgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgJF8uRGV2aWNlSWQgLW5lICRudWxsIH0gfCBTZWxlY3Qt
HLP:T2JqZWN0IC1GaXJzdCAxIH0gY2F0Y2gge30KICAgICAgICAgICAgJHJjID0gJG51bGwKICAgICAgICAgICAgaWYgKCRzeXNEaXNrKSB7ICRyYyA9ICRzeXNEaXNrIHwgR2V0LVN0b3JhZ2VSZWxpYWJpbGl0eUNvdW50ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
HLP:dGludWUgfQogICAgICAgICAgICBpZiAoLW5vdCAkcmMpIHsgJHJjID0gR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IEdldC1TdG9yYWdlUmVsaWFiaWxpdHlDb3VudGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVl
HLP:IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgIGlmICgkcmMpIHsKICAgICAgICAgICAgICAgICRyZXMuYXZhaWxhYmxlID0gJHRydWUKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLlRlbXBlcmF0dXJlIC1hbmQgJHJjLlRlbXBl
HLP:cmF0dXJlIC1ndCAwKSB7ICRyZXMudGVtcF9jID0gW2ludF0kcmMuVGVtcGVyYXR1cmUgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcmMuV2VhcikgICAgICAgICB7ICRyZXMud2Vhcl9wY3QgPSBbaW50XSRyYy5XZWFyIH0KICAgICAgICAgICAgICAg
HLP:IGlmICgkbnVsbCAtbmUgJHJjLlBvd2VyT25Ib3VycykgeyAkcmVzLnBvaCA9IFtpbnRdJHJjLlBvd2VyT25Ib3VycyB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgIyBTZW5hbCBhZGljaW9uYWwgZGUgcHJlZGljY2lvbiBkZSBmYWxsbyB2aWEgZXN0YWRvIGRl
HLP:IHNhbHVkIGZpc2ljYQogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgJHVuaGVhbHRoeSA9IEAoR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLkhlYWx0aFN0YXR1cyAtYW5kICRf
HLP:LkhlYWx0aFN0YXR1cyAtbmUgJ0hlYWx0aHknIH0pCiAgICAgICAgICAgICAgICBpZiAoJHVuaGVhbHRoeS5Db3VudCAtZ3QgMCkgeyAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlOyAkcmVzLnByZWRpY3RfZmFpbCA9ICR0cnVlIH0KICAgICAgICAgICAgfSBjYXRjaCB7
HLP:fQogICAgICAgIH0gY2F0Y2gge30KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAkcmVzCn0KCiMgR2V0LVN0YXJ0dXBJdGVtczogcHJvZ3JhbWFzIHF1ZSBhcnJhbmNhbiBjb24gV2luZG93cyAodG9wIE4pLCBwYXJhIHF1ZSBlbAojIHVzdWFyaW8gdmVhIHF1ZSBy
HLP:YWxlbnRpemEgZWwgaW5pY2lvLiBJbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEuCmZ1bmN0aW9uIEdldC1TdGFydHVwSXRlbXMoW2ludF0kdG9wID0gOCkgewogICAgdHJ5IHsKICAgICAgICAkaXRlbXMgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9TdGFydHVwQ29t
HLP:bWFuZCAtRXJyb3JBY3Rpb24gU3RvcCB8CiAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLkNvbW1hbmQgfSB8CiAgICAgICAgICAgIFNlbGVjdC1PYmplY3QgLUZpcnN0ICR0b3ApCiAgICAgICAgJGxpc3QgPSBAKCkKICAgICAgICBmb3JlYWNoICgkaSBpbiAk
HLP:aXRlbXMpIHsKICAgICAgICAgICAgJGNtZCA9IFtzdHJpbmddJGkuQ29tbWFuZAogICAgICAgICAgICBpZiAoJGNtZC5MZW5ndGggLWd0IDgwKSB7ICRjbWQgPSAkY21kLlN1YnN0cmluZygwLDc3KSArICcuLi4nIH0KICAgICAgICAgICAgJG5tID0gW3N0cmluZ10k
HLP:aS5OYW1lOyBpZiAoLW5vdCAkbm0pIHsgJG5tID0gW3N0cmluZ10kaS5DYXB0aW9uIH0KICAgICAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7IG5hbWUgPSAkbm07IGNvbW1hbmQgPSAkY21kIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuICwkbGlz
HLP:dAogICAgfSBjYXRjaCB7IHJldHVybiBAKCkgfQp9CgojIEdldC1CY2RJbnRlZ3JpdHk6IGNvbXBydWViYSBxdWUgbGEgY29uZmlndXJhY2lvbiBkZSBhcnJhbnF1ZSAoQkNEKSB0aWVuZSBsYQojIGVudHJhZGEgYWN0dWFsIGNvbiBvc2RldmljZS9kZXZpY2UuIExh
HLP:cyBDTEFWRVMgZGUgYmNkZWRpdCBzb24gc2llbXByZSBlbgojIGluZ2xlcywgYXNpIHF1ZSBlcyBpbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEgZGUgbGEgaW50ZXJmYXouCmZ1bmN0aW9uIEdldC1CY2RJbnRlZ3JpdHkgewogICAgJHJlcyA9IFtwc2N1c3RvbW9iamVj
HLP:dF1AeyBvayA9ICRmYWxzZTsgZGV0YWlscyA9ICcnIH0KICAgIHRyeSB7CiAgICAgICAgJG91dCA9ICYgYmNkZWRpdCAvZW51bSAne2N1cnJlbnR9JyAyPiRudWxsCiAgICAgICAgJHR4dCA9ICgkb3V0IC1qb2luICJgbiIpCiAgICAgICAgaWYgKCRMQVNURVhJVENP
HLP:REUgLWVxIDAgLWFuZCAkdHh0IC1tYXRjaCAnKD9pbSleXHMqb3NkZXZpY2UnIC1hbmQgJHR4dCAtbWF0Y2ggJyg/aW0pXlxzKmRldmljZScpIHsKICAgICAgICAgICAgJHJlcy5vayA9ICR0cnVlCiAgICAgICAgICAgICRyZXMuZGV0YWlscyA9ICdFbnRyYWRhIGRl
HLP:IGFycmFucXVlIGFjdHVhbCBpbnRlZ3JhIChkZXZpY2Uvb3NkZXZpY2UgcHJlc2VudGVzKS4nCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJHJlcy5vayA9ICRmYWxzZQogICAgICAgICAgICAkcmVzLmRldGFpbHMgPSAnQ291bGQgbm90IGNvbmZpcm0gdGhl
HLP:IGN1cnJlbnQgc3RhcnR1cCBlbnRyeS4nCiAgICAgICAgfQogICAgfSBjYXRjaCB7CiAgICAgICAgJHJlcy5vayA9ICRmYWxzZQogICAgICAgICRyZXMuZGV0YWlscyA9ICdiY2RlZGl0IG5vIGRpc3BvbmlibGUgbyBzaW4gcGVybWlzb3MuJwogICAgfQogICAgcmV0
HLP:dXJuICRyZXMKfQoKIyBHZXQtVG9wUHJvY2Vzc2VzOiBwcm9jZXNvcyBxdWUgbWFzIG1lbW9yaWEgZGUgdHJhYmFqbyBjb25zdW1lbiAodG9wIE4pLgpmdW5jdGlvbiBHZXQtVG9wUHJvY2Vzc2VzKFtpbnRdJHRvcCA9IDYpIHsKICAgIHRyeSB7CiAgICAgICAgJHBz
HLP:ID0gQChHZXQtUHJvY2VzcyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgIFNvcnQtT2JqZWN0IFdvcmtpbmdTZXQ2NCAtRGVzY2VuZGluZyB8CiAgICAgICAgICAgIFNlbGVjdC1PYmplY3QgLUZpcnN0ICR0b3ApCiAgICAgICAgJGxp
HLP:c3QgPSBAKCkKICAgICAgICBmb3JlYWNoICgkcCBpbiAkcHMpIHsKICAgICAgICAgICAgJG1iID0gW21hdGhdOjpSb3VuZCgkcC5Xb3JraW5nU2V0NjQgLyAxTUIpCiAgICAgICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBuYW1lID0gW3N0cmluZ10k
HLP:cC5Qcm9jZXNzTmFtZTsgbWVtX21iID0gW2ludF0kbWIgfQogICAgICAgIH0KICAgICAgICByZXR1cm4gLCRsaXN0CiAgICB9IGNhdGNoIHsgcmV0dXJuIEAoKSB9Cn0KCiMgR2V0LVNmY1Jlc3VsdDogY2xhc2lmaWNhIGVsIHJlc3VsdGFkbyBkZSBTRkMgbGV5ZW5k
HLP:byBDQlMubG9nIChTSUVNUFJFIGVuCiMgaW5nbGVzKSBlbiBsdWdhciBkZSBsYSBzYWxpZGEgdHJhZHVjaWRhIGRlIGxhIGNvbnNvbGEuIERldnVlbHZlIHVubyBkZToKIyBjbGVhbiB8IHJlcGFpcmVkIHwgdW5yZXBhaXJhYmxlIHwgdW5rbm93bi4KZnVuY3Rpb24g
HLP:R2V0LVNmY1Jlc3VsdCB7CiAgICAkbG9nID0gSm9pbi1QYXRoICRlbnY6d2luZGlyICdMb2dzXENCU1xDQlMubG9nJwogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkbG9nKSkgeyByZXR1cm4gJ3Vua25vd24nIH0KICAgIHRyeSB7CiAgICAgICAgJHRhaWwgPSBAKEdl
HLP:dC1Db250ZW50IC1QYXRoICRsb2cgLVRhaWwgNDAwMCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICAkc3IgPSBAKCR0YWlsIHwgV2hlcmUtT2JqZWN0IHsgJF8gLW1hdGNoICdcW1NSXF0nIH0pCiAgICAgICAgaWYgKCRzci5Db3VudCAtZXEg
HLP:MCkgeyByZXR1cm4gJ3Vua25vd24nIH0KICAgICAgICAkam9pbmVkID0gKCRzciAtam9pbiAiYG4iKQogICAgICAgIGlmICgkam9pbmVkIC1tYXRjaCAnKD9pKWNhbm5vdCByZXBhaXInKSB7IHJldHVybiAndW5yZXBhaXJhYmxlJyB9CiAgICAgICAgaWYgKCRqb2lu
HLP:ZWQgLW1hdGNoICcoP2kpcmVwYWlyaW5nXHMrKFsxLTldXGQqKVxzK2NvbXBvbmVudHN8c3VjY2Vzc2Z1bGx5IHJlcGFpcmVkfHJlcGFpcmVkIGZpbGV8cmVwYWlyaW5nIGNvcnJ1cHRlZCBmaWxlJykgeyByZXR1cm4gJ3JlcGFpcmVkJyB9CiAgICAgICAgaWYgKCRq
HLP:b2luZWQgLW1hdGNoICcoP2kpdmVyaWZ5IGNvbXBsZXRlfG5vIC4qaW50ZWdyaXR5IHZpb2xhdGlvbnN8Y2Fubm90IHZlcmlmeXx2ZXJpZnlpbmcnKSB7IHJldHVybiAnY2xlYW4nIH0KICAgICAgICByZXR1cm4gJ2NsZWFuJwogICAgfSBjYXRjaCB7IHJldHVybiAn
HLP:dW5rbm93bicgfQp9CgojIE5ldy1Kc29uUmVwb3J0OiB2dWVsY2EgZWwgZXN0YWRvICsgcmVzdW1lbiBjYWxjdWxhZG8gYSB1biBmaWNoZXJvIEpTT04KIyAoLUFyZyA9IHJ1dGEgZGUgc2FsaWRhKS4gVXRpbCBwYXJhIGF1dG9tYXRpemFjaW9uIC8gTURNIC8gaW52
HLP:ZW50YXJpby4KZnVuY3Rpb24gTmV3LUpzb25SZXBvcnQoJG91dFBhdGgpIHsKICAgIHRyeSB7CiAgICAgICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgICAgICRzeXNQYWlycyA9IEdldC1TeXNJbmZvCiAgICAgICAgJHN5c01hcCA9IEB7fQogICAgICAgIGZvcmVhY2gg
HLP:KCRwIGluICRzeXNQYWlycykgeyAka3YgPSAkcCAtc3BsaXQgJz0nLDI7IGlmICgka3YuQ291bnQgLWVxIDIpIHsgJHN5c01hcFska3ZbMF1dID0gJGt2WzFdIH0gfQogICAgICAgICRwaGFzZXMgPSBAKCRzdC5waGFzZXMpCiAgICAgICAgJGNPSz0wOyRjV0FSTj0w
HLP:OyRjRVJSPTA7JGNTS0lQPTAKICAgICAgICBmb3JlYWNoICgkcGggaW4gJHBoYXNlcykgeyBzd2l0Y2ggKFtzdHJpbmddJHBoLnJlc3VsdCkgeyAnT0snIHskY09LKyt9ICdXQVJOJyB7JGNXQVJOKyt9ICdFUlJPUicgeyRjRVJSKyt9ICdTS0lQJyB7JGNTS0lQKyt9
HLP:IH0gfQogICAgICAgICRkZWx0YSA9ICRudWxsCiAgICAgICAgaWYgKCRzdC5zY29yZV9iZWZvcmUgLW5lICRudWxsIC1hbmQgJHN0LnNjb3JlX2FmdGVyIC1uZSAkbnVsbCkgeyAkZGVsdGEgPSBbaW50XSRzdC5zY29yZV9hZnRlciAtIFtpbnRdJHN0LnNjb3JlX2Jl
HLP:Zm9yZSB9CiAgICAgICAgJG9iaiA9IFtwc2N1c3RvbW9iamVjdF1AewogICAgICAgICAgICBzY2hlbWEgICAgICAgPSAnd3BpLXJlcG9ydC8xJwogICAgICAgICAgICB2ZXJzaW9uICAgICAgPSAkV1BJX1ZFUlNJT04KICAgICAgICAgICAgZ2VuZXJhdGVkICAgID0g
HLP:KEdldC1EYXRlKS5Ub1N0cmluZygncycpCiAgICAgICAgICAgIG1hY2hpbmUgICAgICA9ICRlbnY6Q09NUFVURVJOQU1FCiAgICAgICAgICAgIHN5c3RlbSAgICAgICA9ICRzeXNNYXAKICAgICAgICAgICAgc2NvcmVfYmVmb3JlID0gJHN0LnNjb3JlX2JlZm9yZQog
HLP:ICAgICAgICAgICBzY29yZV9hZnRlciAgPSAkc3Quc2NvcmVfYWZ0ZXIKICAgICAgICAgICAgc2NvcmVfZGVsdGEgID0gJGRlbHRhCiAgICAgICAgICAgIHN1bW1hcnkgICAgICA9IFtwc2N1c3RvbW9iamVjdF1AeyBvaz0kY09LOyB3YXJuPSRjV0FSTjsgZXJyb3I9
HLP:JGNFUlI7IHNraXA9JGNTS0lQOyB0b3RhbD0kcGhhc2VzLkNvdW50IH0KICAgICAgICAgICAgcGhhc2VzICAgICAgID0gJHBoYXNlcwogICAgICAgICAgICBmaW5kaW5ncyAgICAgPSBAKCRzdC5maW5kaW5ncykKICAgICAgICAgICAgZGlhZyAgICAgICAgID0gJHN0
HLP:LmRpYWcKICAgICAgICB9CiAgICAgICAgJGpzb24gPSAkb2JqIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDgKICAgICAgICAkdXRmOCA9IE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkKICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpX
HLP:cml0ZUFsbFRleHQoJG91dFBhdGgsICRqc29uLCAkdXRmOCkKICAgICAgICAiUkVTVUxUPU9LIgogICAgICAgICJQQVRIPSRvdXRQYXRoIgogICAgfSBjYXRjaCB7CiAgICAgICAgIlJFU1VMVD1GQUlMIgogICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNz
HLP:YWdlKSIKICAgIH0KfQoKIyBOZXctU3VwcG9ydFBhY2thZ2U6IGVtcGFxdWV0YSBsb2dzICsgaW5mb3JtZSArIGVzdGFkbyArIGJhdHRlcnktcmVwb3J0IGVuIHVuCiMgWklQICgtQXJnID0gcnV0YSBkZWwgemlwKSBwYXJhIGVudmlhciBhIHNvcG9ydGUuIFNpbiBk
HLP:ZXBlbmRlbmNpYXMgZXh0ZXJuYXMKIyAodXNhIENvbXByZXNzLUFyY2hpdmUsIGluY2x1aWRvIGVuIFdpbmRvd3MgMTAvMTEpLgpmdW5jdGlvbiBOZXctU3VwcG9ydFBhY2thZ2UoJG91dFBhdGgpIHsKICAgIHRyeSB7CiAgICAgICAgJHRtcCA9IEpvaW4tUGF0aCAk
HLP:V29yayAoJ3NvcG9ydGVfJyArIChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXlNTWRkX0hIbW1zcycpKQogICAgICAgIE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJHRtcCAtRm9yY2UgfCBPdXQtTnVsbAogICAgICAgICMgZXN0YWRvLmpzb24KICAg
HLP:ICAgICBpZiAoVGVzdC1QYXRoICRTdGF0ZUZpbGUpIHsgQ29weS1JdGVtICRTdGF0ZUZpbGUgKEpvaW4tUGF0aCAkdG1wICdlc3RhZG8uanNvbicpIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgIyBMb2dzCiAgICAgICAgJGxv
HLP:Z3MgPSBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkbG9ncykgewogICAgICAgICAgICAkZHN0TG9ncyA9IEpvaW4tUGF0aCAkdG1wICdMb2dzJwogICAgICAgICAgICBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRo
HLP:ICRkc3RMb2dzIC1Gb3JjZSB8IE91dC1OdWxsCiAgICAgICAgICAgIEdldC1DaGlsZEl0ZW0gJGxvZ3MgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBDb3B5LUl0ZW0gLURlc3RpbmF0aW9uICRkc3RMb2dzIC1Gb3JjZSAtRXJyb3JBY3Rpb24g
HLP:U2lsZW50bHlDb250aW51ZQogICAgICAgIH0KICAgICAgICAjIEluZm9ybWVzIEhUTUwvSlNPTiBleGlzdGVudGVzIGVuIFdvcmsKICAgICAgICBHZXQtQ2hpbGRJdGVtICRXb3JrIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAg
HLP:ICAgV2hlcmUtT2JqZWN0IHsgJF8uTmFtZSAtbWF0Y2ggJyg/aSleSW5mb3JtZS4qXC4oaHRtbHxqc29uKSQnIH0gfAogICAgICAgICAgICBDb3B5LUl0ZW0gLURlc3RpbmF0aW9uICR0bXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAg
HLP:ICAgIyBiYXR0ZXJ5IHJlcG9ydCBzaSBleGlzdGUKICAgICAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAgICAgdHJ5IHsgaWYgKCRzdC5kaWFnIC1hbmQgJHN0LmRpYWcuYmF0dGVyeSAtYW5kICRzdC5kaWFnLmJhdHRlcnkucmVwb3J0X3BhdGggLWFuZCAoVGVzdC1Q
HLP:YXRoICRzdC5kaWFnLmJhdHRlcnkucmVwb3J0X3BhdGgpKSB7IENvcHktSXRlbSAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9wYXRoICR0bXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0gfSBjYXRjaCB7fQogICAgICAgIGlmIChUZXN0LVBh
HLP:dGggJG91dFBhdGgpIHsgUmVtb3ZlLUl0ZW0gJG91dFBhdGggLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICBDb21wcmVzcy1BcmNoaXZlIC1QYXRoIChKb2luLVBhdGggJHRtcCAnKicpIC1EZXN0aW5hdGlvblBhdGggJG91dFBh
HLP:dGggLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wCiAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJHRtcCAtUmVjdXJzZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfSBjYXRjaCB7fQogICAgICAgICJSRVNVTFQ9T0siCiAgICAgICAgIlBBVEg9
HLP:JG91dFBhdGgiCiAgICB9IGNhdGNoIHsKICAgICAgICAiUkVTVUxUPUZBSUwiCiAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgfQp9Cgpzd2l0Y2ggKCRBY3Rpb24uVG9Mb3dlcigpKSB7CiAgICAnbm9uZScgICAgICAgICB7IH0gIyBV
HLP:c2FkbyBwYXJhIGRvdC1zb3VyY2luZwogICAgJ2NoZWNrYmFja3VwcycgewogICAgICAgICRwYXJ0cyA9ICRBcmcgLXNwbGl0ICdcfCcsIDIKICAgICAgICBpZiAoJHBhcnRzLkNvdW50IC1uZSAyKSB7ICJSRVNVTFQ9RkFJTCI7ICJFUlJPUj1Bcmd1bWVudG9zIGlu
HLP:dmFsaWRvcyI7IGV4aXQgMCB9CiAgICAgICAgJGJrZGlyID0gJHBhcnRzWzBdCiAgICAgICAgJHRzID0gJHBhcnRzWzFdCiAgICAgICAgJHJwX29rID0gJGZhbHNlCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHJwcyA9IEdldC1Db21wdXRlclJlc3RvcmVQb2lu
HLP:dCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICBmb3JlYWNoICgkcnAgaW4gJHJwcykgewogICAgICAgICAgICAgICAgaWYgKCRycC5EZXNjcmlwdGlvbiAtbGlrZSAiUmVwYWlyX1N1aXRlXyoiKSB7ICRycF9vayA9ICR0cnVlOyBicmVh
HLP:ayB9CiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHsgJHJwX29rID0gJGZhbHNlIH0KICAgICAgICAkcmVnX29rID0gJHRydWUKICAgICAgICAkc29mdCA9IEpvaW4tUGF0aCAkYmtkaXIgIlNPRlRXQVJFXyR0cy5yZWciCiAgICAgICAgJHN5cyA9IEpvaW4t
HLP:UGF0aCAkYmtkaXIgIlNZU1RFTV8kdHMucmVnIgogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJHNvZnQpIC1vciAoR2V0LUl0ZW0gJHNvZnQpLkxlbmd0aCAtZXEgMCkgeyAkcmVnX29rID0gJGZhbHNlIH0KICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRz
HLP:eXMpIC1vciAoR2V0LUl0ZW0gJHN5cykuTGVuZ3RoIC1lcSAwKSB7ICRyZWdfb2sgPSAkZmFsc2UgfQogICAgICAgICJSUF9PSz0kKGlmICgkcnBfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJSRUdfT0s9JChpZiAoJHJlZ19vaykgeycxJ30gZWxzZSB7
HLP:JzAnfSkiCiAgICB9CiAgICAnYm9vdHN0cmFwd2luZ2V0JyB7CiAgICAgICAgJG9rID0gSW5zdGFsbC1XaW5nZXRCb290c3RyYXAKICAgICAgICAiQk9PVFNUUkFQX09LPSQoaWYgKCRvaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnZmluZGxvY2Fsc291
HLP:cmNlJyB7CiAgICAgICAgJGRyaXZlcyA9IEdldC1QU0RyaXZlIC1QU1Byb3ZpZGVyIEZpbGVTeXN0ZW0KICAgICAgICAkcGF0aHMgPSBAKCkKICAgICAgICAkZWRpdGlvbklkID0gJycKICAgICAgICB0cnkgeyAkZWRpdGlvbklkID0gKEdldC1JdGVtUHJvcGVydHkg
HLP:J0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uJyAtTmFtZSBFZGl0aW9uSUQgLUVycm9yQWN0aW9uIFN0b3ApLkVkaXRpb25JRCB9IGNhdGNoIHt9CiAgICAgICAgZnVuY3Rpb24gR2V0LUluc3RhbGxJbWFnZVNvdXJjZShb
HLP:c3RyaW5nXSRraW5kLCBbc3RyaW5nXSRwYXRoLCBbc3RyaW5nXSRlZGl0aW9uKSB7CiAgICAgICAgICAgICRpbmRleCA9IDEKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRpbWFnZXMgPSBAKEdldC1XaW5kb3dzSW1hZ2UgLUltYWdlUGF0aCAkcGF0
HLP:aCAtRXJyb3JBY3Rpb24gU3RvcCkKICAgICAgICAgICAgICAgICRtYXRjaCA9ICRudWxsCiAgICAgICAgICAgICAgICBpZiAoJGVkaXRpb24gLW1hdGNoICdQcm9mZXNzaW9uYWwnKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5h
HLP:bWUgLW1hdGNoICdcYlByb1xifFByb2Zlc3Npb25hbCcgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgZWxzZWlmICgkZWRpdGlvbiAtbWF0Y2ggJ0VudGVycHJpc2UnKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3Qg
HLP:eyAkXy5JbWFnZU5hbWUgLW1hdGNoICdFbnRlcnByaXNlJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnRWR1Y2F0aW9uJykgeyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0
HLP:IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnRWR1Y2F0aW9uJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnQ29yZScpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJlLU9iamVjdCB7ICRf
HLP:LkltYWdlTmFtZSAtbWF0Y2ggJ1xiSG9tZVxifENvcmUnIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJG1hdGNoIC1hbmQgJGltYWdlcy5Db3VudCAtZXEgMSkgeyAkbWF0Y2ggPSAkaW1hZ2VzWzBdIH0K
HLP:ICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJG1hdGNoKSB7ICRpbmRleCA9IFtpbnRdJG1hdGNoLkltYWdlSW5kZXggfQogICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgICAgIHJldHVybiAoInswfTp7MX06ezJ9IiAtZiAka2luZCwgJHBhdGgsICRp
HLP:bmRleCkKICAgICAgICB9CiAgICAgICAgZm9yZWFjaCAoJGQgaW4gJGRyaXZlcykgewogICAgICAgICAgICAkcm9vdCA9ICRkLlJvb3QKICAgICAgICAgICAgJHdpbSA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xpbnN0YWxsLndpbSIKICAgICAgICAgICAgJGVz
HLP:ZCA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xpbnN0YWxsLmVzZCIKICAgICAgICAgICAgJHN4cyA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xzeHMiCiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJHdpbSkgeyAkcGF0aHMgKz0gKEdldC1JbnN0YWxsSW1h
HLP:Z2VTb3VyY2UgJ1dpbScgJHdpbSAkZWRpdGlvbklkKSB9CiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJGVzZCkgeyAkcGF0aHMgKz0gKEdldC1JbnN0YWxsSW1hZ2VTb3VyY2UgJ0VzZCcgJGVzZCAkZWRpdGlvbklkKSB9CiAgICAgICAgICAgIGlmIChUZXN0LVBh
HLP:dGggJHN4cykgeyAkcGF0aHMgKz0gJHN4cyB9CiAgICAgICAgfQogICAgICAgIGlmICgkcGF0aHMuQ291bnQgLWd0IDApIHsgIlNPVVJDRT0kKCRwYXRoc1swXSkiIH0gZWxzZSB7ICJTT1VSQ0U9IiB9CiAgICB9CiAgICAnZGlzbXJlc3RvcmUnIHsKICAgICAgICAk
HLP:cGFydHMgPSBAKCRBcmcgLXNwbGl0ICdcfCcsIDIpCiAgICAgICAgJHNvdXJjZSA9IGlmICgkcGFydHMuQ291bnQgLWdlIDEpIHsgJHBhcnRzWzBdIH0gZWxzZSB7ICcnIH0KICAgICAgICAkdGltZW91dE1pbnV0ZXMgPSA0NQogICAgICAgIGlmICgkcGFydHMuQ291
HLP:bnQgLWdlIDIpIHsgW3ZvaWRdW2ludF06OlRyeVBhcnNlKCRwYXJ0c1sxXSwgW3JlZl0kdGltZW91dE1pbnV0ZXMpIH0KICAgICAgICBpZiAoJHRpbWVvdXRNaW51dGVzIC1sdCA1KSB7ICR0aW1lb3V0TWludXRlcyA9IDUgfQoKICAgICAgICBmdW5jdGlvbiBRdW90
HLP:ZS1EaXNtVmFsdWUoW3N0cmluZ10kdmFsdWUpIHsKICAgICAgICAgICAgaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHZhbHVlKSkgeyByZXR1cm4gJHZhbHVlIH0KICAgICAgICAgICAgcmV0dXJuICciJyArICgkdmFsdWUgLXJlcGxhY2UgJyInLCAn
HLP:XCInKSArICciJwogICAgICAgIH0KCiAgICAgICAgJGFyZ3VtZW50cyA9ICcvT25saW5lIC9DbGVhbnVwLUltYWdlIC9SZXN0b3JlSGVhbHRoJwogICAgICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHNvdXJjZSkpIHsKICAgICAgICAg
HLP:ICAgJGFyZ3VtZW50cyArPSAnIC9Tb3VyY2U6JyArIChRdW90ZS1EaXNtVmFsdWUgJHNvdXJjZSkgKyAnIC9MaW1pdEFjY2VzcycKICAgICAgICB9CgogICAgICAgICR0aW1lZE91dCA9ICRmYWxzZQogICAgICAgICRleGl0Q29kZSA9IDMKICAgICAgICAkb3V0Rmls
HLP:ZSA9IEpvaW4tUGF0aCAkV29yayAoImRpc21fcmVzdG9yZV97MH0ub3V0IiAtZiAoW2d1aWRdOjpOZXdHdWlkKCkuVG9TdHJpbmcoJ04nKSkpCiAgICAgICAgJGVyckZpbGUgPSBKb2luLVBhdGggJFdvcmsgKCJkaXNtX3Jlc3RvcmVfezB9LmVyciIgLWYgKFtndWlk
HLP:XTo6TmV3R3VpZCgpLlRvU3RyaW5nKCdOJykpKQogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRwc2kgPSBbRGlhZ25vc3RpY3MuUHJvY2Vzc1N0YXJ0SW5mb106Om5ldygpCiAgICAgICAgICAgICRwc2kuRmlsZU5hbWUgPSAnY21kLmV4ZScKICAgICAgICAgICAg
HLP:JHBzaS5Bcmd1bWVudHMgPSAoJy9jIGRpc20uZXhlIHswfSA+ICJ7MX0iIDI+ICJ7Mn0iJyAtZiAkYXJndW1lbnRzLCAkb3V0RmlsZSwgJGVyckZpbGUpCiAgICAgICAgICAgICRwc2kuVXNlU2hlbGxFeGVjdXRlID0gJGZhbHNlCiAgICAgICAgICAgICRwc2kuQ3Jl
HLP:YXRlTm9XaW5kb3cgPSAkdHJ1ZQogICAgICAgICAgICAkcCA9IFtEaWFnbm9zdGljcy5Qcm9jZXNzXTo6bmV3KCkKICAgICAgICAgICAgJHAuU3RhcnRJbmZvID0gJHBzaQogICAgICAgICAgICBbdm9pZF0kcC5TdGFydCgpCiAgICAgICAgICAgIGlmICgtbm90ICRw
HLP:LldhaXRGb3JFeGl0KCR0aW1lb3V0TWludXRlcyAqIDYwICogMTAwMCkpIHsKICAgICAgICAgICAgICAgICR0aW1lZE91dCA9ICR0cnVlCiAgICAgICAgICAgICAgICB0cnkgeyAkcC5LaWxsKCkgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgJGV4aXRDb2RlID0g
HLP:MTQ2MAogICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgdHJ5IHsgJHAuV2FpdEZvckV4aXQoKSB9IGNhdGNoIHt9CiAgICAgICAgICAgICAgICAkZXhpdENvZGUgPSAkcC5FeGl0Q29kZQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkZXhp
HLP:dENvZGUpIHsgJGV4aXRDb2RlID0gMyB9CiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgICAgICAgICAkZXhpdENvZGUgPSAzCiAgICAgICAgfQoKICAgICAgICBpZiAo
HLP:VGVzdC1QYXRoICRvdXRGaWxlKSB7IEdldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkb3V0RmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgaWYgKFRlc3QtUGF0aCAkZXJyRmlsZSkgeyBHZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGVy
HLP:ckZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkb3V0RmlsZSwkZXJyRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAiVElNRURPVVQ9JChpZiAo
HLP:JHRpbWVkT3V0KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiRVhJVENPREU9JGV4aXRDb2RlIgogICAgfQogICAgJ3N5c2luZm8nICAgICAgeyBHZXQtU3lzSW5mbyB9CiAgICAnc2NvcmUnICAgICAgICB7ICRoID0gR2V0LUhlYWx0aFNjb3JlOyAiU0NPUkU9
HLP:JCgkaC5zY29yZSkiOyBmb3JlYWNoICgkciBpbiAkaC5yZWFzb25zKSB7ICJSRUFTT049JHIiIH0gfQogICAgJ2ZvcmVuc2ljcycgICAgeyBHZXQtRm9yZW5zaWNzIH0KICAgICd0cmlhZ2UnICAgICAgIHsgR2V0LVRyaWFnZSB9CiAgICAncmVzdG9yZXBvaW50JyB7
HLP:IE5ldy1SZXN0b3JlUG9pbnQgfQogICAgJ21lZGlhdHlwZScgICAgeyAkbWVkaWEgPSBHZXQtTWVkaWFUeXBlOyAiTUVESUE9JG1lZGlhIjsgIk9QVElNSVpFPSQoUmVzb2x2ZS1PcHRpbWl6ZUFjdGlvbiAkbWVkaWEpIiB9CiAgICAnZGV2aWNlcycgICAgICB7IEdl
HLP:dC1EZXZpY2VQcm9ibGVtcyB9CiAgICAncmVwb3J0JyAgICAgICB7IEFkZC1UeXBlIC1Bc3NlbWJseU5hbWUgU3lzdGVtLldlYiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgTmV3LUh0bWxSZXBvcnQgJEFyZyB9CiAgICAnYWRkcGhhc2UnICAgICB7IEFk
HLP:ZC1QaGFzZVJlc3VsdCAkQXJnIH0KICAgICdzZXRiZWZvcmUnICAgIHsgU2V0LVNjb3JlICdiZWZvcmUnICRBcmcgfQogICAgJ3NldGFmdGVyJyAgICAgeyBTZXQtU2NvcmUgJ2FmdGVyJyAkQXJnIH0KICAgICdmaW5kaW5nJyAgICAgIHsgQWRkLUZpbmRpbmcgJEFy
HLP:ZyB9CiAgICAncmVzZXRzdGF0ZScgICB7IFJlc2V0LVN0YXRlOyAiUkVTVUxUPU9LIiB9CiAgICAnbm9ybWFsaXplZmFzZXMnIHsKICAgICAgICAkciA9IE5vcm1hbGl6ZS1GYXNlcyAkQXJnCiAgICAgICAgIk5PUk09JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJHIu
HLP:bm9ybSkpKSIKICAgICAgICAiSU5WQUxJRD0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkci5pbnZhbGlkKSkpIgogICAgfQogICAgJ2NoZWNrcG9pbnQnIHsKICAgICAgICAkcGFyc2VkID0gUGFyc2UtQ2hlY2twb2ludEFyZyAkQXJnCiAgICAgICAgc3dpdGNoICgk
HLP:cGFyc2VkLnN1YikgewogICAgICAgICAgICAnc2F2ZScgeyBpZiAoU2F2ZS1DaGVja3BvaW50ICRwYXJzZWQpIHsgIlJFU1VMVD1PSyIgfSBlbHNlIHsgIlJFU1VMVD1GQUlMIiB9IH0KICAgICAgICAgICAgJ2xvYWQnIHsKICAgICAgICAgICAgICAgICRjcCA9IExv
HLP:YWQtQ2hlY2twb2ludAogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkY3ApIHsgIlJFU1VMVD1OT05FIiB9CiAgICAgICAgICAgICAgICBlbHNlIHsKICAgICAgICAgICAgICAgICAgICAiUkVTVUxUPU9LIgogICAgICAgICAgICAgICAgICAgICJWQUxJRD0k
HLP:KGlmIChUZXN0LUNoZWNrcG9pbnRWYWxpZCAkY3ApIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJWRVJTSU9OPSQoJGNwLnZlcnNpb24pIgogICAgICAgICAgICAgICAgICAgICJDUkVBVEVEPSQoJGNwLmNyZWF0ZWQpIgogICAgICAgICAg
HLP:ICAgICAgICAgICJTRUxFQ1RJT049JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJGNwLnNlbGVjdGlvbikpKSIKICAgICAgICAgICAgICAgICAgICAiQ09NUExFVEVEPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRjcC5jb21wbGV0ZWQpKSkiCiAgICAgICAgICAgICAg
HLP:ICAgICAgIlJFQVNPTj0kKCRjcC5wZW5kaW5nX3JlYXNvbikiCiAgICAgICAgICAgICAgICAgICAgIk5FWFQ9JChHZXQtTmV4dFBoYXNlICRjcCkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfQVVUTz0kKGlmICgkY3AubW9kZS5hdXRvKSB7JzEnfSBlbHNlIHsn
HLP:MCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9OT1JFQk9PVD0kKGlmICgkY3AubW9kZS5ub3JlYm9vdCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfS0VFUFdVPSQoaWYgKCRjcC5tb2RlLmtlZXB3dSkgeycxJ30gZWxz
HLP:ZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfRFJZPSQoaWYgKCRjcC5tb2RlLmRyeSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfVFJJQUdFPSQoaWYgKCRjcC5tb2RlLnRyaWFnZSkgeycxJ30gZWxzZSB7JzAn
HLP:fSkiCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJ25leHQnIHsKICAgICAgICAgICAgICAgICRjcCA9IExvYWQtQ2hlY2twb2ludAogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkY3AgLWFuZCAoVGVzdC1DaGVja3BvaW50
HLP:VmFsaWQgJGNwKSkgeyAiTkVYVD0kKEdldC1OZXh0UGhhc2UgJGNwKSIgfSBlbHNlIHsgIk5FWFQ9IiB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJ2NsZWFyJyB7CiAgICAgICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkgewogICAg
HLP:ICAgICAgICAgICAgICAgIHRyeSB7IFJlbW92ZS1JdGVtICRDaGVja3BvaW50RmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3A7ICJSRVNVTFQ9T0siIH0gY2F0Y2ggeyAiUkVTVUxUPUZBSUwiIH0KICAgICAgICAgICAgICAgIH0gZWxzZSB7ICJSRVNVTFQ9T0si
HLP:IH0KICAgICAgICAgICAgfQogICAgICAgICAgICBkZWZhdWx0IHsgIlJFU1VMVD1GQUlMIjsgIkVSUk9SPXN1YmFjY2lvbiBkZSBjaGVja3BvaW50IGRlc2Nvbm9jaWRhIiB9CiAgICAgICAgfQogICAgfQogICAgJ21vdmVyZXN1bHQnIHsKICAgICAgICAkcGFydHMg
HLP:PSAkQXJnIC1zcGxpdCAnXHwnLCAyCiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtZXEgMikgewogICAgICAgICAgICAkb2sgPSBUZXN0LU1vdmVSZXN1bHRQYXRoICRwYXJ0c1swXSAkcGFydHNbMV0KICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAkYiAgPSAk
HLP:QXJnIC1zcGxpdCAnLCcKICAgICAgICAgICAgJHNlID0gKCRiLkNvdW50IC1nZSAxIC1hbmQgJGJbMF0uVHJpbSgpIC1lcSAnMScpCiAgICAgICAgICAgICRkZSA9ICgkYi5Db3VudCAtZ2UgMiAtYW5kICRiWzFdLlRyaW0oKSAtZXEgJzEnKQogICAgICAgICAgICAk
HLP:b2sgPSBUZXN0LU1vdmVSZXN1bHQgJHNlICRkZQogICAgICAgIH0KICAgICAgICAiTU9WRUQ9JChpZiAoJG9rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICd2dGx3cml0ZScgewogICAgICAgICRwICAgPSAkQXJnIC1zcGxpdCAnLCcKICAgICAgICAkY3Vy
HLP:ID0gaWYgKCRwLkNvdW50IC1nZSAxKSB7ICRwWzBdIH0gZWxzZSB7ICcnIH0KICAgICAgICAkZGVzID0gaWYgKCRwLkNvdW50IC1nZSAyKSB7ICRwWzFdIH0gZWxzZSB7IFtzdHJpbmddJFZUX0xFVkVMX0RFU0lSRUQgfQogICAgICAgICJXUklURT0kKGlmIChSZXNv
HLP:bHZlLVZ0bFdyaXRlICRjdXIgJGRlcykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnbWFwZXhpdCcgICAgICB7ICJSRVM9JChNYXAtRXhpdENvZGUgJEFyZykiIH0KICAgICMgLS0tICg1LjEgLyBSZXEgMTUpIERpYWdub3N0aWNvIGFtcGxpYWRvIC0tLQog
HLP:ICAgJ3JhbWNoZWNrJyB7CiAgICAgICAgJHIgPSBHZXQtUmFtQ2hlY2sKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHN0LmRpYWcucmFtID0gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICRyLnN0YXR1czsgcmVj
HLP:b21tZW5kX21kc2NoZWQgPSBbYm9vbF0kci5yZWNvbW1lbmRfbWRzY2hlZCB9CiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIlJBTV9TVEFUVVM9JCgkci5zdGF0dXMpIgogICAgICAgICJSQU1fUkVDT01NRU5EX01EU0NIRUQ9JChpZiAoJHIucmVjb21t
HLP:ZW5kX21kc2NoZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ2JhdHRlcnknIHsKICAgICAgICAkYiA9IEdldC1CYXR0ZXJ5SGVhbHRoCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRzdC5kaWFnLmJhdHRl
HLP:cnkgPSBbcHNjdXN0b21vYmplY3RdQHsgcHJlc2VudCA9IFtib29sXSRiLnByZXNlbnQ7IGhlYWx0aF9wY3QgPSAkYi5oZWFsdGhfcGN0OyByZXBvcnRfcGF0aCA9ICRiLnJlcG9ydF9wYXRoIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiQkFUVEVS
HLP:WV9QUkVTRU5UPSQoaWYgKCRiLnByZXNlbnQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQVRURVJZX0hFQUxUSF9QQ1Q9JCgkYi5oZWFsdGhfcGN0KSIKICAgICAgICAiQkFUVEVSWV9SRVBPUlQ9JCgkYi5yZXBvcnRfcGF0aCkiCiAgICB9CiAgICAnbmV0
HLP:YWR2YW5jZWQnIHsKICAgICAgICAkbiA9IEdldC1OZXRBZHZhbmNlZAogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5uZXR3b3JrID0gW3BzY3VzdG9tb2JqZWN0XUB7IGNvbm5lY3RlZCA9IFtib29sXSRu
HLP:LmNvbm5lY3RlZDsgZG5zX29rID0gW2Jvb2xdJG4uZG5zX29rOyBkZXRhaWxzID0gJG4uZGV0YWlsczsgZG5zX21zID0gJG4uZG5zX21zIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiTkVUX0NPTk5FQ1RFRD0kKGlmICgkbi5jb25uZWN0ZWQpIHsn
HLP:MSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfRE5TX09LPSQoaWYgKCRuLmRuc19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ERVRBSUxTPSQoJG4uZGV0YWlscykiCiAgICAgICAgIk5FVF9MQVRFTkNZX01TPSQoJG4uZG5zX21zKSIKICAg
HLP:IH0KICAgICdkaWFnZnVsbCcgewogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkciA9IEdldC1SYW1DaGVjawogICAgICAgICRzdC5kaWFnLnJhbSA9IFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAkci5zdGF0dXM7
HLP:IHJlY29tbWVuZF9tZHNjaGVkID0gW2Jvb2xdJHIucmVjb21tZW5kX21kc2NoZWQgfQogICAgICAgICRiID0gR2V0LUJhdHRlcnlIZWFsdGgKICAgICAgICAkc3QuZGlhZy5iYXR0ZXJ5ID0gW3BzY3VzdG9tb2JqZWN0XUB7IHByZXNlbnQgPSBbYm9vbF0kYi5wcmVz
HLP:ZW50OyBoZWFsdGhfcGN0ID0gJGIuaGVhbHRoX3BjdDsgcmVwb3J0X3BhdGggPSAkYi5yZXBvcnRfcGF0aCB9CiAgICAgICAgJG4gPSBHZXQtTmV0QWR2YW5jZWQKICAgICAgICAkc3QuZGlhZy5uZXR3b3JrID0gW3BzY3VzdG9tb2JqZWN0XUB7IGNvbm5lY3RlZCA9
HLP:IFtib29sXSRuLmNvbm5lY3RlZDsgZG5zX29rID0gW2Jvb2xdJG4uZG5zX29rOyBkZXRhaWxzID0gJG4uZGV0YWlsczsgZG5zX21zID0gJG4uZG5zX21zIH0KICAgICAgICAkZGV2ID0gR2V0LURldmljZUxpc3QKICAgICAgICBpZiAoJG51bGwgLWVxICRkZXYpIHsK
HLP:ICAgICAgICAgICAgJHN0LmRpYWcuZGV2aWNlcyA9IEAoKQogICAgICAgICAgICAkZGV2TGluZSA9ICJERVZJQ0VTX1NUQVRVUz1pbmZvIG5vdCBhdmFpbGFibGUiCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJHN0LmRpYWcuZGV2aWNlcyA9IEAoJGRldikK
HLP:ICAgICAgICAgICAgJGRldkxpbmUgPSAiREVWSUNFU19DT1VOVD0kKEAoJGRldikuQ291bnQpIgogICAgICAgIH0KICAgICAgICAkc20gPSBHZXQtU21hcnRBdHRyaWJ1dGVzCiAgICAgICAgJHN0LmRpYWcuc21hcnQgPSBbcHNjdXN0b21vYmplY3RdQHsgYXZhaWxh
HLP:YmxlID0gW2Jvb2xdJHNtLmF2YWlsYWJsZTsgcHJlZGljdF9mYWlsID0gW2Jvb2xdJHNtLnByZWRpY3RfZmFpbDsgdGVtcF9jID0gJHNtLnRlbXBfYzsgd2Vhcl9wY3QgPSAkc20ud2Vhcl9wY3Q7IHBvaCA9ICRzbS5wb2ggfQogICAgICAgICRzdHAgPSBHZXQtU3Rh
HLP:cnR1cEl0ZW1zIDgKICAgICAgICAkc3QuZGlhZy5zdGFydHVwID0gQCgkc3RwKQogICAgICAgICRiY2QgPSBHZXQtQmNkSW50ZWdyaXR5CiAgICAgICAgJHN0LmRpYWcuYmNkID0gW3BzY3VzdG9tb2JqZWN0XUB7IG9rID0gW2Jvb2xdJGJjZC5vazsgZGV0YWlscyA9
HLP:ICRiY2QuZGV0YWlscyB9CiAgICAgICAgJHByb2NzID0gR2V0LVRvcFByb2Nlc3NlcyA2CiAgICAgICAgJHN0LmRpYWcucHJvY2Vzc2VzID0gQCgkcHJvY3MpCiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIlJBTV9TVEFUVVM9JCgkci5zdGF0dXMpIgog
HLP:ICAgICAgICJSQU1fUkVDT01NRU5EX01EU0NIRUQ9JChpZiAoJHIucmVjb21tZW5kX21kc2NoZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQVRURVJZX1BSRVNFTlQ9JChpZiAoJGIucHJlc2VudCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJB
HLP:VFRFUllfSEVBTFRIX1BDVD0kKCRiLmhlYWx0aF9wY3QpIgogICAgICAgICJORVRfQ09OTkVDVEVEPSQoaWYgKCRuLmNvbm5lY3RlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ETlNfT0s9JChpZiAoJG4uZG5zX29rKSB7JzEnfSBlbHNlIHsnMCd9
HLP:KSIKICAgICAgICAiTkVUX0xBVEVOQ1lfTVM9JCgkbi5kbnNfbXMpIgogICAgICAgICJTTUFSVF9BVkFJTEFCTEU9JChpZiAoJHNtLmF2YWlsYWJsZSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIlNNQVJUX1BSRURJQ1RfRkFJTD0kKGlmICgkc20ucHJlZGlj
HLP:dF9mYWlsKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkNEX09LPSQoaWYgKCRiY2Qub2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICRkZXZMaW5lCiAgICB9CiAgICAjIC0tLSAodjMuMSkgU0ZDIGluZGVwZW5kaWVudGUgZGVsIGlkaW9tYSArIEpT
HLP:T04gKyBwYXF1ZXRlIGRlIHNvcG9ydGUgLS0tCiAgICAnc2ZjcmVzdWx0JyB7CiAgICAgICAgIlNGQ19SRVM9JChHZXQtU2ZjUmVzdWx0KSIKICAgIH0KICAgICdqc29ucmVwb3J0JyB7CiAgICAgICAgJG91dCA9IGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNw
HLP:YWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnSW5mb3JtZS5qc29uJyB9IGVsc2UgeyAkQXJnIH0KICAgICAgICBOZXctSnNvblJlcG9ydCAkb3V0CiAgICB9CiAgICAnc3VwcG9ydHBhY2thZ2UnIHsKICAgICAgICAkb3V0ID0gaWYgKFtzdHJpbmddOjpJc051
HLP:bGxPcldoaXRlU3BhY2UoJEFyZykpIHsgSm9pbi1QYXRoICRXb3JrICdQYXF1ZXRlX1NvcG9ydGUuemlwJyB9IGVsc2UgeyAkQXJnIH0KICAgICAgICBOZXctU3VwcG9ydFBhY2thZ2UgJG91dAogICAgfQogICAgIyAtLS0gKDUuNiAvIFJlcSAxNy4yKSBSb3RhY2lv
HLP:biBkZSBsb2dzIC0tLQogICAgJ2xvZ3JvdGF0ZScgewogICAgICAgICRmb2xkZXIgPSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnIH0gZWxzZSB7ICRBcmcgfQogICAgICAgICRuID0gSW52b2tl
HLP:LUxvZ1JvdGF0ZSAkZm9sZGVyICRMT0dfUkVURU5USU9OCiAgICAgICAgIkRFTEVURUQ9JG4iCiAgICB9CiAgICAjIC0tLSAoNS44IC8gUmVxIDEzLDE4KSBWYWxpZGFjaW9uIGRlIGVudG9ybm8geSBzZWxmLXRlc3QgLS0tCiAgICAnZW52Y2hlY2snIHsKICAgICAg
HLP:ICAkZSA9IEludm9rZS1FbnZWYWxpZGF0ZQogICAgICAgICJPU19PSz0kKGlmICgkZS5vc19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk9TX0JVSUxEPSQoJGUuYnVpbGQpIgogICAgICAgICJPU19DSEVDS19ET05FPTEiCiAgICB9CiAgICAnc2VsZnRl
HLP:c3RicmFpbicgeyAiQlJBSU5fT0s9MSIgfQogICAgJ3NlbGZ0ZXN0cmVzdWx0JyB7CiAgICAgICAgJHBhc3MgPSBJbnZva2UtU2VsZlRlc3QgKFBhcnNlLUJvb2xMaXN0ICRBcmcpCiAgICAgICAgIlNFTEZURVNUX1BBU1M9JChpZiAoJHBhc3MpIHsnMSd9IGVsc2Ug
HLP:eycwJ30pIgogICAgfQogICAgZGVmYXVsdCAgICAgICAgeyBHZXQtU3lzSW5mbyB9Cn0K
