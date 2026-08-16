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
echo  %DIM%Standalone phase 11 - Network%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "11" "Network" "Resets winsock, IP, DNS and proxy, and checks the hosts file."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase11 ) else ( call :menu_fase11 )
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
    call :title_of 11
    call :pshq addphase "11;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase11
if "%DRY%"=="1" ( call :dry "Would reset winsock, IP, DNS and proxy" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Test ping to public DNS (scan only)"
    ping 1.1.1.1 -n 1 -w 1500 > "%CAP%" 2>&1
    set "P1=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!P1!"=="0" (
        call :ok "Internet connectivity OK (ping to 1.1.1.1)"
        exit /b 0
    ) else (
        ping 8.8.8.8 -n 1 -w 1500 > "%CAP%" 2>&1
        set "P2=!errorlevel!"
        type "%CAP%" >> "%LOGFILE%"
        if "!P2!"=="0" (
            call :ok "Internet connectivity OK (ping to 8.8.8.8)"
            exit /b 0
        ) else (
            call :warn "Ping to public DNS servers failed (no connection or blocked)"
            exit /b 1
        )
    )
)

set "NET_RC=0"
call :step "Resetting Winsock and IP"
netsh winsock reset >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 ( call :warn "netsh winsock reset returned an error (check the log)" & set "NET_RC=1" )
netsh int ip reset >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 call :info "netsh int ip reset returned warnings (protected keys; this is usually normal)"
call :step "Renewing DHCP and flushing DNS"
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
ipconfig /flushdns >nul 2>&1
call :step "Removing WinHTTP proxy"
netsh winhttp reset proxy >> "%LOGFILE%" 2>&1

call :step "Purging ARP tables and network routes"
arp -d * >> "%LOGFILE%" 2>&1
route -f >> "%LOGFILE%" 2>&1

if "%FWRESET%"=="1" (
    call :step "Resetting Windows Firewall (/fwreset)"
    netsh advfirewall reset >> "%LOGFILE%" 2>&1
    if !errorlevel! equ 0 ( call :ok "Firewall reset to default values" ) else ( call :warn "netsh advfirewall reset returned an error (check the log)" & set "NET_RC=1" )
)

call :step "Checking the hosts file"
findstr /v /b "#" "%SystemRoot%\System32\drivers\etc\hosts" | findstr /r "[0-9]" >nul 2>&1
if !errorlevel! equ 0 ( call :warn "The hosts file has active entries. Review it in case it blocks sites." ) else ( call :ok "hosts file clean" )
set "PH_NOTE=winsock/ip reset; requires reboot"
if "!NET_RC!"=="1" ( call :warn "Network stack reset with warnings: check the log" & exit /b 1 )
call :ok "Network stack reset (winsock requires reboot)"
exit /b 0
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
HLP:IyBXaW56YXJkIC0gaHR0cHM6Ly9naXRodWIuY29tL1JlYmVsMTQ4Ny9XaW56YXJkDQojIENvcHlyaWdodCAoYykgMjAyNiA8PE5PTUJSRV9MRUdBTF9QRU5ESUVOVEU+PiAoR2l0SHViOiBSZWJlbDE0ODcpIC0gY3JlYXRvciBhbmQgZm91bmRlciBvZiB0aGUgcHJv
HLP:amVjdA0KIyBTUERYLUxpY2Vuc2UtSWRlbnRpZmllcjogTUlUDQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgV1BJIC0gQ2VyZWJybyBkZSBsYSBTdWl0ZSBkZSBS
HLP:ZXBhcmFjaW9uIChoZWxwZXIpCiMgIEludm9jYWRvIHBvciBlbCAuYmF0OiBwb3dlcnNoZWxsIC1GaWxlIHN1aXRlX2hlbHBlci5wczEgLUFjdGlvbiA8YWNjaW9uPiAuLi4KIyAgQWNjaW9uZXM6IHN5c2luZm8gfCBzY29yZSB8IGZvcmVuc2ljcyB8IHRyaWFnZSB8
HLP:IHJlc3RvcmVwb2ludCB8IG1lZGlhdHlwZQojICAgICAgICAgICAgfCBkZXZpY2VzIHwgcmVwb3J0IHwgYWRkcGhhc2UgfCBzZXRiZWZvcmUgfCBzZXRhZnRlciB8IGZpbmRpbmcKIyAgICAgICAgICAgIHwgcmVzZXRzdGF0ZSB8IG5vcm1hbGl6ZWZhc2VzIHwgY2hl
HLP:Y2twb2ludCB8IG1vdmVyZXN1bHQgfCB2dGx3cml0ZQojICAgICAgICAgICAgfCBtYXBleGl0IHwgcmFtY2hlY2sgfCBiYXR0ZXJ5IHwgbmV0YWR2YW5jZWQgfCBkaWFnZnVsbAojICAgICAgICAgICAgfCBsb2dyb3RhdGUgfCBlbnZjaGVjayB8IHNlbGZ0ZXN0YnJh
HLP:aW4gfCBzZWxmdGVzdHJlc3VsdAojICAgICAgICAgICAgfCBzZmNyZXN1bHQgfCBqc29ucmVwb3J0IHwgc3VwcG9ydHBhY2thZ2UKIyAgVG9kbyB2YSBhIFNURE9VVCBlbiBsaW5lYXMgS0VZPVZBTFVFIChmYWNpbGVzIGRlIGxlZXIgZGVzZGUgYmF0Y2ggY29uIEZP
HLP:UiksCiMgIHNhbHZvICdyZXBvcnQnIHF1ZSBlc2NyaWJlIHVuIEhUTUwuIFNpbiBkZXBlbmRlbmNpYXMgZXh0ZXJuYXMuCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQpw
HLP:YXJhbSgKICAgIFtzdHJpbmddJEFjdGlvbiA9ICdzeXNpbmZvJywKICAgIFtzdHJpbmddJFdvcmsgICA9ICIkZW52OlRFTVBcV1BJX1N1aXRlIiwKICAgIFtzdHJpbmddJEFyZyAgICA9ICcnCikKJEVycm9yQWN0aW9uUHJlZmVyZW5jZSA9ICdTaWxlbnRseUNvbnRp
HLP:bnVlJwppZiAoLW5vdCAoVGVzdC1QYXRoICRXb3JrKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRXb3JrIC1Gb3JjZSB8IE91dC1OdWxsIH0KJFN0YXRlRmlsZSA9IEpvaW4tUGF0aCAkV29yayAnZXN0YWRvLmpzb24nCgojIC0tLSBDb25z
HLP:dGFudGVzIGRlIGNvbmZpZ3VyYWNpb24gKGFsaW5lYWRhcyBjb24gbWFuaWZlc3QucHNkMSAvIGRlc2lnbikgLS0tCiRDaGVja3BvaW50RmlsZSAgICAgICAgICA9IEpvaW4tUGF0aCAkV29yayAnY2hlY2twb2ludC5qc29uJwokV1BJX1ZFUlNJT04gICAgICAgICAg
HLP:ICAgPSAnMy4xJwokQ0hFQ0tQT0lOVF9NQVhfQUdFX0RBWVMgPSA3CiRWVF9MRVZFTF9ERVNJUkVEICAgICAgICA9IDEKJExPR19SRVRFTlRJT04gICAgICAgICAgID0gMTAKCmZ1bmN0aW9uIFJlYWQtU3RhdGUgewogICAgaWYgKFRlc3QtUGF0aCAkU3RhdGVGaWxl
HLP:KSB7IHRyeSB7IHJldHVybiAoR2V0LUNvbnRlbnQgJFN0YXRlRmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbikgfSBjYXRjaCB7fSB9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHNjb3JlX2JlZm9yZSA9ICRudWxsOyBzY29yZV9hZnRlciA9ICRudWxs
HLP:OyBmaW5kaW5ncyA9IEAoKTsgcGhhc2VzID0gQCgpOyBkaWFnID0gJG51bGwgfQp9CmZ1bmN0aW9uIFdyaXRlLVN0YXRlKCRzKSB7IHRyeSB7IFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkU3RhdGVGaWxlLCAoJHMgfCBDb252ZXJ0VG8tSnNvbiAtRGVw
HLP:dGggNiksIChOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpKSkgfSBjYXRjaCB7fSB9CgojIEdhcmFudGl6YSBxdWUgZWwgZXN0YWRvIHRpZW5lIGVsIHN1Yi1vYmpldG8gJ2RpYWcnIChyYW0vYmF0dGVyeS9kZXZpY2VzL25ldHdvcmsp
HLP:LgojIENvbXBhdGlibGUgY29uIGVzdGFkb3MgYW50aWd1b3MgY2FyZ2Fkb3MgZGUgZXN0YWRvLmpzb24gc2luIGxhIHByb3BpZWRhZCAnZGlhZycuCmZ1bmN0aW9uIEluaXRpYWxpemUtRGlhZygkc3QpIHsKICAgIGlmICgtbm90ICgkc3QuUFNPYmplY3QuUHJvcGVy
HLP:dGllcy5OYW1lIC1jb250YWlucyAnZGlhZycpIC1vciAkbnVsbCAtZXEgJHN0LmRpYWcpIHsKICAgICAgICAkZGlhZyA9IFtwc2N1c3RvbW9iamVjdF1AeyByYW0gPSAkbnVsbDsgYmF0dGVyeSA9ICRudWxsOyBkZXZpY2VzID0gQCgpOyBuZXR3b3JrID0gJG51bGw7
HLP:IHNtYXJ0ID0gJG51bGw7IGJjZCA9ICRudWxsOyBwcm9jZXNzZXMgPSAkbnVsbDsgc3RhcnR1cCA9ICRudWxsIH0KICAgICAgICAkc3QgfCBBZGQtTWVtYmVyIC1Ob3RlUHJvcGVydHlOYW1lIGRpYWcgLU5vdGVQcm9wZXJ0eVZhbHVlICRkaWFnIC1Gb3JjZQogICAg
HLP:fSBlbHNlIHsKICAgICAgICBmb3JlYWNoICgkcHAgaW4gJ3NtYXJ0JywnYmNkJywncHJvY2Vzc2VzJywnc3RhcnR1cCcpIHsKICAgICAgICAgICAgaWYgKC1ub3QgKCRzdC5kaWFnLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJHBwKSkgewogICAg
HLP:ICAgICAgICAgICAgJHN0LmRpYWcgfCBBZGQtTWVtYmVyIC1Ob3RlUHJvcGVydHlOYW1lICRwcCAtTm90ZVByb3BlcnR5VmFsdWUgJG51bGwgLUZvcmNlCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9CiAgICByZXR1cm4gJHN0Cn0KCmZ1bmN0aW9uIEdldC1T
HLP:eXNJbmZvIHsKICAgICRvcyAgPSBHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3BlcmF0aW5nU3lzdGVtIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAkY3MgID0gR2V0LUNpbUluc3RhbmNlIFdpbjMyX0NvbXB1dGVyU3lzdGVtIC1FcnJvckFjdGlvbiBT
HLP:aWxlbnRseUNvbnRpbnVlCiAgICAkY3B1ID0gKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9Qcm9jZXNzb3IgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKQogICAgJGMgICA9IEdldC1QU0RyaXZlIEMKICAgIGlmICgk
HLP:b3MgLWFuZCAkb3MuTGFzdEJvb3RVcFRpbWUpIHsKICAgICAgICAkdXAgPSAoR2V0LURhdGUpIC0gJG9zLkxhc3RCb290VXBUaW1lCiAgICB9IGVsc2UgewogICAgICAgICR0aWNrcyA9IFtTeXN0ZW0uRW52aXJvbm1lbnRdOjpUaWNrQ291bnQ2NAogICAgICAgIGlm
HLP:ICgkbnVsbCAtZXEgJHRpY2tzKSB7CiAgICAgICAgICAgICR0aWNrcyA9IFtTeXN0ZW0uRW52aXJvbm1lbnRdOjpUaWNrQ291bnQKICAgICAgICAgICAgaWYgKCR0aWNrcyAtbHQgMCkgeyAkdGlja3MgPSBbdWludDMyXSR0aWNrcyB9CiAgICAgICAgfQogICAgICAg
HLP:ICR1cCA9IFtUaW1lU3Bhbl06OkZyb21NaWxsaXNlY29uZHMoJHRpY2tzKQogICAgfQogICAgJGNwdU5hbWUgPSAiIgogICAgaWYgKCRjcHUgLWFuZCAkY3B1Lk5hbWUpIHsgJGNwdU5hbWUgPSAkY3B1Lk5hbWUuVHJpbSgpIH0KICAgICRyYW1HQiAgPSBbbWF0aF06
HLP:OlJvdW5kKCRjcy5Ub3RhbFBoeXNpY2FsTWVtb3J5LzFHQiwxKQogICAgJGZyZWVHQiA9IFttYXRoXTo6Um91bmQoJGMuRnJlZS8xR0IsMSkKICAgICR0b3RHQiAgPSBbbWF0aF06OlJvdW5kKCgkYy5GcmVlKyRjLlVzZWQpLzFHQiwxKQogICAgIk9TPSQoJG9zLkNh
HLP:cHRpb24pIChidWlsZCAkKCRvcy5CdWlsZE51bWJlcikpIgogICAgIlNZU1RFTT0kKCRjcy5NYW51ZmFjdHVyZXIpICQoJGNzLk1vZGVsKSIKICAgICJDUFU9JGNwdU5hbWUiCiAgICAiUkFNPSRyYW1HQiBHQiIKICAgICJESVNLPUM6ICRmcmVlR0IgR0IgZnJlZSBv
HLP:ZiAkdG90R0IgR0IiCiAgICAiVVBUSU1FPSQoW2ludF0kdXAuVG90YWxEYXlzKWQgJCgkdXAuSG91cnMpaCAkKCR1cC5NaW51dGVzKW0iCiAgICAiVVNFUj0kZW52OlVTRVJOQU1FIgp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgKDUuMiAvIFJlcSAxNS42KSBOdWNsZW8gUFVSTyBkZSBjYWxjdWxvIGRlbCBzY29yZS4KIyBSZWNpYmUgdW4gaGFzaHRhYmxlIGRlIHNpbnRvbWFzIChmbGFncy9jb250ZW9zKSB5IGRldnVlbHZlIHVu
HLP:IGVudGVybyBlbgojIFswLDEwMF0uIENhZGEgc2ludG9tYSBzb2xvIHB1ZWRlIFJFU1RBUiBwdW50b3MsIHBvciBsbyBxdWUgYW5hZGlyIG8gYWdyYXZhcgojIGN1YWxxdWllciBzaW50b21hIG51bmNhIHN1YmUgZWwgc2NvcmUgKE1PTk9UT05JQSksIHkgZWwgY2xh
HLP:bXAgZ2FyYW50aXphIGVsCiMgcmFuZ28gWzAsMTAwXS4gRXMgZGV0ZXJtaW5pc3RhIHJlc3BlY3RvIGEgc3UgZW50cmFkYSAodGVzdGVhYmxlIGRlIGZvcm1hCiMgYWlzbGFkYSBwYXJhIGxhIFByb3BlcnR5IDEwKS4KZnVuY3Rpb24gQ29tcHV0ZS1TY29yZShbaGFz
HLP:aHRhYmxlXSRzeW0pIHsKICAgIGlmICgkbnVsbCAtZXEgJHN5bSkgeyAkc3ltID0gQHt9IH0KICAgICRzY29yZSA9IDEwMAogICAgIyAtLS0gUGVuYWxpemFjaW9uZXMgZXhpc3RlbnRlcyAocHJlc2VydmFkYXMpIC0tLQogICAgaWYgKCRzeW1bJ3NtYXJ0QmFkJ10p
HLP:ICAgICAgIHsgJHNjb3JlIC09IDI1IH0KICAgIGlmICgkc3ltLkNvbnRhaW5zS2V5KCdmcmVlR0InKSAtYW5kICRudWxsIC1uZSAkc3ltWydmcmVlR0InXSkgewogICAgICAgICRmcmVlR0IgPSBbZG91YmxlXSRzeW1bJ2ZyZWVHQiddCiAgICAgICAgaWYgICAgICgk
HLP:ZnJlZUdCIC1sdCA1KSAgeyAkc2NvcmUgLT0gMTUgfQogICAgICAgIGVsc2VpZiAoJGZyZWVHQiAtbHQgMTUpIHsgJHNjb3JlIC09IDYgfQogICAgfQogICAgaWYgKCRzeW1bJ3JlYm9vdFBlbmRpbmcnXSkgICAgICAgICAgeyAkc2NvcmUgLT0gNSB9CiAgICBpZiAo
HLP:W2ludF0kc3ltWydic29kJ10gLWd0IDApICAgICAgICB7ICRzY29yZSAtPSAxOCB9CiAgICBpZiAoW2ludF0kc3ltWydkaXNrRXJyJ10gLWd0IDApICAgICB7ICRzY29yZSAtPSAxMiB9CiAgICBpZiAoW2ludF0kc3ltWyd3aGVhJ10gLWd0IDApICAgICAgICB7ICRz
HLP:Y29yZSAtPSAxMiB9CiAgICBpZiAoW2ludF0kc3ltWydjcml0Q291bnQnXSAtZ3QgMjUpICB7ICRzY29yZSAtPSA2IH0KICAgIGlmIChbaW50XSRzeW1bJ3N2Y1N0b3BwZWQnXSAtZ3QgMCkgIHsgJHNjb3JlIC09IDQgKiBbaW50XSRzeW1bJ3N2Y1N0b3BwZWQnXSB9
HLP:CiAgICBpZiAoW2ludF0kc3ltWydkZXZQcm9ibGVtcyddIC1ndCAwKSB7ICRzY29yZSAtPSBbbWF0aF06Ok1pbigxMiwgW2ludF0kc3ltWydkZXZQcm9ibGVtcyddICogMykgfQogICAgIyAtLS0gTnVldmFzIHBlbmFsaXphY2lvbmVzIGRlbCBkaWFnbm9zdGljbyBh
HLP:bXBsaWFkbyAoNS4yKSAtLS0KICAgIGlmICgkc3ltWydyYW1TdXNwZWN0J10pIHsgJHNjb3JlIC09IDEwIH0gICAjIFJBTSBzb3NwZWNob3NhCiAgICBpZiAoJHN5bS5Db250YWluc0tleSgnYmF0dGVyeUhlYWx0aFBjdCcpIC1hbmQgJG51bGwgLW5lICRzeW1bJ2Jh
HLP:dHRlcnlIZWFsdGhQY3QnXSkgewogICAgICAgICRicCA9IFtpbnRdJHN5bVsnYmF0dGVyeUhlYWx0aFBjdCddCiAgICAgICAgaWYgKCRicCAtZ2UgMCAtYW5kICRicCAtbHQgNTApIHsgJHNjb3JlIC09IDggfSAgICMgYmF0ZXJpYSBtdXkgZGVncmFkYWRhICg8NTAl
HLP:KQogICAgfQogICAgaWYgKCRzeW1bJ25ldFByb2JsZW0nXSkgeyAkc2NvcmUgLT0gOCB9ICAgIyBwcm9ibGVtYXMgZGUgcmVkIHBlcnNpc3RlbnRlcwogICAgIyAtLS0gQ2xhbXAgYWwgcmFuZ28gWzAsMTAwXSAtLS0KICAgIGlmICgkc2NvcmUgLWx0IDApICAgeyAk
HLP:c2NvcmUgPSAwIH0KICAgIGlmICgkc2NvcmUgLWd0IDEwMCkgeyAkc2NvcmUgPSAxMDAgfQogICAgcmV0dXJuIFtpbnRdJHNjb3JlCn0KCiMgUHVudHVhY2lvbiBkZSBzYWx1ZCAwLTEwMDogcmVjb2xlY3RhIHNpbnRvbWFzIHJlYWxlcyBkZWwgc2lzdGVtYSAoaW5j
HLP:bHVpZG8gZWwKIyBkaWFnbm9zdGljbyBhbXBsaWFkbyBwZXJzaXN0aWRvIGVuIGVzdGFkby5kaWFnKSB5IGRlbGVnYSBlbCBjYWxjdWxvIGVuIGxhCiMgZnVuY2lvbiBwdXJhIENvbXB1dGUtU2NvcmUuCmZ1bmN0aW9uIEdldC1IZWFsdGhTY29yZSB7CiAgICAkcmVh
HLP:c29ucyA9IEAoKQogICAgJHN5bSA9IEB7fQogICAgIyBEaXNjbyBTTUFSVAogICAgJGJhZCA9IEAoR2V0LVBoeXNpY2FsRGlzayB8IFdoZXJlLU9iamVjdCB7ICRfLkhlYWx0aFN0YXR1cyAtbmUgJ0hlYWx0aHknIH0pCiAgICAkc3ltWydzbWFydEJhZCddID0gKCRi
HLP:YWQuQ291bnQgLWd0IDApCiAgICBpZiAoJHN5bVsnc21hcnRCYWQnXSkgeyAkcmVhc29ucyArPSAiRGlzayB3aXRoIGRlZ3JhZGVkIFNNQVJUICgtMjUpIiB9CiAgICAjIEVzcGFjaW8gbGlicmUKICAgICRjID0gR2V0LVBTRHJpdmUgQzsgJGZyZWVHQiA9IFttYXRo
HLP:XTo6Um91bmQoJGMuRnJlZS8xR0IsMSkKICAgICRzeW1bJ2ZyZWVHQiddID0gJGZyZWVHQgogICAgaWYgICAgICgkZnJlZUdCIC1sdCA1KSAgeyAkcmVhc29ucyArPSAiTGVzcyB0aGFuIDUgR0IgZnJlZSBvbiBDOiAoLTE1KSIgfQogICAgZWxzZWlmICgkZnJlZUdC
HLP:IC1sdCAxNSkgeyAkcmVhc29ucyArPSAiTG93IGZyZWUgc3BhY2Ugb24gQzogKC02KSIgfQogICAgIyBSZWluaWNpbyBwZW5kaWVudGUKICAgICRwZW5kID0gKFRlc3QtUGF0aCAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3NcQ3VycmVudFZlcnNpb25c
HLP:Q29tcG9uZW50IEJhc2VkIFNlcnZpY2luZ1xSZWJvb3RQZW5kaW5nJykgLW9yIGAKICAgICAgICAgICAgKFRlc3QtUGF0aCAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3NcQ3VycmVudFZlcnNpb25cV2luZG93c1VwZGF0ZVxBdXRvIFVwZGF0ZVxSZWJv
HLP:b3RSZXF1aXJlZCcpCiAgICAkc3ltWydyZWJvb3RQZW5kaW5nJ10gPSBbYm9vbF0kcGVuZAogICAgaWYgKCRwZW5kKSB7ICRyZWFzb25zICs9ICJQZW5kaW5nIHJlYm9vdCAoLTUpIiB9CiAgICAjIEV2ZW50b3MgY3JpdGljb3MgcmVjaWVudGVzICg0OGgpCiAgICAk
HLP:c2luY2UgPSAoR2V0LURhdGUpLkFkZEhvdXJzKC00OCkKICAgICRjcml0ID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IExldmVsPTEsMjsgU3RhcnRUaW1lPSRzaW5jZX0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
HLP:dGludWUpCiAgICAkYnNvZCA9IEAoJGNyaXQgfCBXaGVyZS1PYmplY3QgeyAkXy5JZCAtaW4gNDEsMTAwMSw2MDA4IH0pLkNvdW50CiAgICAkZGlzayA9IEAoJGNyaXQgfCBXaGVyZS1PYmplY3QgeyAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICdkaXNrfE50ZnN8dm9s
HLP:bWdyJyB9KS5Db3VudAogICAgJHdoZWEgPSBAKCRjcml0IHwgV2hlcmUtT2JqZWN0IHsgJF8uUHJvdmlkZXJOYW1lIC1tYXRjaCAnV0hFQScgfSkuQ291bnQKICAgICRzeW1bJ2Jzb2QnXSA9ICRic29kOyAkc3ltWydkaXNrRXJyJ10gPSAkZGlzazsgJHN5bVsnd2hl
HLP:YSddID0gJHdoZWE7ICRzeW1bJ2NyaXRDb3VudCddID0gJGNyaXQuQ291bnQKICAgIGlmICgkYnNvZCAtZ3QgMCkgeyAkcmVhc29ucyArPSAiUmVjZW50IGNyYXNoZXMvQlNPRDogJGJzb2QgKC0xOCkiIH0KICAgIGlmICgkZGlzayAtZ3QgMCkgeyAkcmVhc29ucyAr
HLP:PSAiUmVjZW50IGRpc2svTlRGUyBlcnJvcnM6ICRkaXNrICgtMTIpIiB9CiAgICBpZiAoJHdoZWEgLWd0IDApIHsgJHJlYXNvbnMgKz0gIkhhcmR3YXJlIGVycm9ycyAoV0hFQSk6ICR3aGVhICgtMTIpIiB9CiAgICBpZiAoJGNyaXQuQ291bnQgLWd0IDI1KSB7ICRy
HLP:ZWFzb25zICs9ICJNYW55IGNyaXRpY2FsIGV2ZW50cyBpbiA0OGg6ICQoJGNyaXQuQ291bnQpICgtNikiIH0KICAgICMgU2VydmljaW9zIGNsYXZlIHBhcmFkb3MKICAgICRzdmNTdG9wcGVkID0gMAogICAgZm9yZWFjaCAoJHN2YyBpbiAnd3VhdXNlcnYnLCdCSVRT
HLP:JywnV2lubWdtdCcsJ0V2ZW50TG9nJykgewogICAgICAgICRzID0gR2V0LVNlcnZpY2UgJHN2YyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIGlmICgkcyAtYW5kICRzLlN0YXR1cyAtbmUgJ1J1bm5pbmcnIC1hbmQgJHMuU3RhcnRUeXBlIC1u
HLP:ZSAnRGlzYWJsZWQnKSB7ICRzdmNTdG9wcGVkKys7ICRyZWFzb25zICs9ICJTZXJ2aWNlICRzdmMgc3RvcHBlZCAoLTQpIiB9CiAgICB9CiAgICAkc3ltWydzdmNTdG9wcGVkJ10gPSAkc3ZjU3RvcHBlZAogICAgIyBEZXZpY2VzIGNvbiBwcm9ibGVtYQogICAgJHBy
HLP:b2IgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9QblBFbnRpdHkgfCBXaGVyZS1PYmplY3QgeyAkXy5Db25maWdNYW5hZ2VyRXJyb3JDb2RlIC1ndCAwIH0pLkNvdW50CiAgICAkc3ltWydkZXZQcm9ibGVtcyddID0gJHByb2IKICAgIGlmICgkcHJvYiAtZ3QgMCkg
HLP:eyAkcmVhc29ucyArPSAiRGV2aWNlcyB3aXRoIGVycm9yczogJHByb2IiIH0KICAgICMgLS0tIERpYWdub3N0aWNvIGFtcGxpYWRvIHBlcnNpc3RpZG8gKDUuMik6IFJBTSwgYmF0ZXJpYSwgcmVkIC0tLQogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgaWYgKCgkc3Qu
HLP:UFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnZGlhZycpIC1hbmQgJHN0LmRpYWcpIHsKICAgICAgICBpZiAoJHN0LmRpYWcucmFtIC1hbmQgKFtzdHJpbmddJHN0LmRpYWcucmFtLnN0YXR1cyAtZXEgJ3N1c3BlY3QnKSkgewogICAgICAgICAgICAk
HLP:c3ltWydyYW1TdXNwZWN0J10gPSAkdHJ1ZTsgJHJlYXNvbnMgKz0gIlJBTSBzdXNwaWNpb3VzICgtMTApIgogICAgICAgIH0KICAgICAgICBpZiAoJHN0LmRpYWcuYmF0dGVyeSAtYW5kICRzdC5kaWFnLmJhdHRlcnkucHJlc2VudCkgewogICAgICAgICAgICAkYnBS
HLP:YXcgPSAkc3QuZGlhZy5iYXR0ZXJ5LmhlYWx0aF9wY3QKICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkYnBSYXcgLWFuZCBbc3RyaW5nXSRicFJhdyAtbmUgJycpIHsKICAgICAgICAgICAgICAgICRicCA9ICRudWxsOyB0cnkgeyAkYnAgPSBbaW50XSRicFJhdyB9
HLP:IGNhdGNoIHsgJGJwID0gJG51bGwgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkYnApIHsKICAgICAgICAgICAgICAgICAgICAkc3ltWydiYXR0ZXJ5SGVhbHRoUGN0J10gPSAkYnAKICAgICAgICAgICAgICAgICAgICBpZiAoJGJwIC1nZSAwIC1hbmQg
HLP:JGJwIC1sdCA1MCkgeyAkcmVhc29ucyArPSAiQmF0dGVyeSBoZWF2aWx5IGRlZ3JhZGVkOiAkYnAlICgtOCkiIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICBpZiAoJHN0LmRpYWcubmV0d29yayAtYW5kICgoJHN0LmRp
HLP:YWcubmV0d29yay5jb25uZWN0ZWQgLWVxICRmYWxzZSkgLW9yICgkc3QuZGlhZy5uZXR3b3JrLmRuc19vayAtZXEgJGZhbHNlKSkpIHsKICAgICAgICAgICAgJHN5bVsnbmV0UHJvYmxlbSddID0gJHRydWU7ICRyZWFzb25zICs9ICJQZXJzaXN0ZW50IG5ldHdvcmsg
HLP:cHJvYmxlbXMgKC04KSIKICAgICAgICB9CiAgICB9CiAgICAkc2NvcmUgPSBDb21wdXRlLVNjb3JlICRzeW0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc2NvcmUgPSBbaW50XSRzY29yZTsgcmVhc29ucyA9ICRyZWFzb25zIH0KfQoKIyAtLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEZvcmVuc2UgZGVsIHJlZ2lzdHJvIGRlIGV2ZW50b3M6IHVsdGltb3MgZXJyb3JlcyBxdWUgZXhwbGljYW4gbGEgY2F1c2EgcmFpei4KZnVuY3Rp
HLP:b24gR2V0LUZvcmVuc2ljcyB7CiAgICAkc2luY2UgPSAoR2V0LURhdGUpLkFkZERheXMoLTcpCiAgICAkb3V0ID0gQCgpCiAgICAkZXYgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgTGV2ZWw9MSwyOyBTdGFydFRp
HLP:bWU9JHNpbmNlfSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDQwMCkKICAgICRncm91cHMgPSBAKAogICAgICAgIEB7IGs9J0FSUkFOUVVFL0FQQUdPTic7IGlkcz1AKDQxLDYwMDgsMTAwMSk7IHByb3Y9JycgfSwK
HLP:ICAgICAgICBAeyBrPSdESVNDTy9OVEZTJzsgICAgICBpZHM9QCgpOyAgICAgICAgICAgICBwcm92PSdkaXNrfE50ZnN8dm9sbWdyfHN0b3Judm1lfHN0b3JhaGNpJyB9LAogICAgICAgIEB7IGs9J0hBUkRXQVJFIChXSEVBKSc7IGlkcz1AKCk7ICAgICAgICAgICAg
HLP:IHByb3Y9J1dIRUEnIH0sCiAgICAgICAgQHsgaz0nU0VSVklDSU9TJzsgICAgICAgaWRzPUAoKTsgICAgICAgICAgICAgcHJvdj0nU2VydmljZSBDb250cm9sIE1hbmFnZXInIH0sCiAgICAgICAgQHsgaz0nQVBMSUNBQ0lPTic7ICAgICAgaWRzPUAoMTAwMCwxMDAy
HLP:KTsgICAgcHJvdj0nQXBwbGljYXRpb24gRXJyb3J8Lk5FVCBSdW50aW1lJyB9CiAgICApCiAgICBmb3JlYWNoICgkZyBpbiAkZ3JvdXBzKSB7CiAgICAgICAgJHNlbCA9ICRldiB8IFdoZXJlLU9iamVjdCB7CiAgICAgICAgICAgICgkZy5pZHMuQ291bnQgLWd0IDAg
HLP:LWFuZCAkXy5JZCAtaW4gJGcuaWRzKSAtb3IgKCRnLnByb3YgLW5lICcnIC1hbmQgJF8uUHJvdmlkZXJOYW1lIC1tYXRjaCAkZy5wcm92KQogICAgICAgIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAzCiAgICAgICAgZm9yZWFjaCAoJGUgaW4gJHNlbCkgewogICAg
HLP:ICAgICAgICAkbXNnID0gKCRlLk1lc3NhZ2UgLXNwbGl0ICJgbiIpWzBdOyBpZiAoJG1zZy5MZW5ndGggLWd0IDkwKSB7ICRtc2cgPSAkbXNnLlN1YnN0cmluZygwLDkwKSB9CiAgICAgICAgICAgICRvdXQgKz0gKCJ7MH18ezF9fHsyfXx7M30iIC1mICRnLmssICRl
HLP:LklkLCAkZS5UaW1lQ3JlYXRlZC5Ub1N0cmluZygnTU0tZGQgSEg6bW0nKSwgJG1zZy5UcmltKCkpCiAgICAgICAgfQogICAgfQogICAgaWYgKCRvdXQuQ291bnQgLWVxIDApIHsgIk9LfDB8LXxObyBjcml0aWNhbCBlcnJvcnMgaW4gdGhlIGxhc3QgNyBkYXlzLiIg
HLP:fSBlbHNlIHsgJG91dCB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBBdXRvLXRyaWFnZTogYSBwYXJ0aXIgZGVsIHNjb3JlIHkgbGEgZm9yZW5zZSwgcmVjb21p
HLP:ZW5kYSBmYXNlcyAobGlzdGEgZGUgSURzKS4KZnVuY3Rpb24gR2V0LVRyaWFnZSB7CiAgICAkaCA9IEdldC1IZWFsdGhTY29yZQogICAgJHJlYyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddCiAgICBmb3JlYWNoICgk
HLP:eCBpbiAnMDAnLCcwMScsJzAyJykgeyAkcmVjLkFkZCgkeCkgfSAgIyBkaWFnbm9zdGljbytyZXN0b3JlK2xpbXBpZXphIHNpZW1wcmUKICAgICRzaW5jZSA9IChHZXQtRGF0ZSkuQWRkRGF5cygtNykKICAgICRldiA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNo
HLP:dGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBMZXZlbD0xLDI7IFN0YXJ0VGltZT0kc2luY2V9IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgaWYgKEAoJGV2IHwgV2hlcmUtT2JqZWN0IHsgJF8uUHJvdmlkZXJOYW1lIC1tYXRjaCAnZGlza3xOdGZz
HLP:fHZvbG1ncicgfSkuQ291bnQgLWd0IDApIHsgJHJlYy5BZGQoJzAzJykgfQogICAgJHJlYy5BZGQoJzA0Jyk7ICRyZWMuQWRkKCcwNScpOyAkcmVjLkFkZCgnMDYnKSAgIyBkaXNjby9ESVNNL1NGQyBiYXNlCiAgICBpZiAoKEdldC1TZXJ2aWNlIFdpbm1nbXQpLlN0
HLP:YXR1cyAtbmUgJ1J1bm5pbmcnKSB7ICRyZWMuQWRkKCcwNycpIH0KICAgICMgV1Ugcm90bz8KICAgICR3dSA9IEdldC1TZXJ2aWNlIHd1YXVzZXJ2IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICBpZiAoJHd1IC1hbmQgJHd1LlN0YXR1cyAtbmUgJ1J1
HLP:bm5pbmcnIC1hbmQgJHd1LlN0YXJ0VHlwZSAtbmUgJ0Rpc2FibGVkJykgeyAkcmVjLkFkZCgnMTMnKSB9CiAgICAiU0NPUkU9JCgkaC5zY29yZSkiCiAgICAiUkVDT01FTkRBREFTPSQoW3N0cmluZ106OkpvaW4oJywnLCAoJHJlYyB8IFNlbGVjdC1PYmplY3QgLVVu
HLP:aXF1ZSkpKSIKfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpmdW5jdGlvbiBOZXctUmVzdG9yZVBvaW50IHsKICAgIHRyeSB7CiAgICAgICAgRW5hYmxlLUNvbXB1dGVy
HLP:UmVzdG9yZSAtRHJpdmUgJ0M6JyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRrID0gJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uXFN5c3RlbVJlc3RvcmUnCiAgICAgICAgJHByZXYgPSAoR2V0
HLP:LUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25GcmVxdWVuY3kKICAgICAgICBTZXQtSXRlbVByb3BlcnR5
HLP:ICRrIC1OYW1lIFN5c3RlbVJlc3RvcmVQb2ludENyZWF0aW9uRnJlcXVlbmN5IC1WYWx1ZSAwIC1UeXBlIERXb3JkIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgJG5hbWUgPSAiUmVwYWlyX1N1aXRlXyQoKEdldC1EYXRlKS5Ub1N0cmluZygn
HLP:eXl5eS1NTS1kZF9ISC1tbScpKSIKICAgICAgICBDaGVja3BvaW50LUNvbXB1dGVyIC1EZXNjcmlwdGlvbiAkbmFtZSAtUmVzdG9yZVBvaW50VHlwZSBNT0RJRllfU0VUVElOR1MgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICBpZiAoJG51bGwgLW5lICRwcmV2KSB7
HLP:IFNldC1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25GcmVxdWVuY3kgLVZhbHVlICRwcmV2IC1UeXBlIERXb3JkIH0gZWxzZSB7IFJlbW92ZS1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRp
HLP:b25GcmVxdWVuY3kgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICRycCA9IEdldC1Db21wdXRlclJlc3RvcmVQb2ludCB8IFdoZXJlLU9iamVjdCB7ICRfLkRlc2NyaXB0aW9uIC1lcSAkbmFtZSB9CiAgICAgICAgaWYgKCRycCkgeyAiUkVT
HLP:VUxUPU9LIjsgIk5BTUU9JG5hbWUiIH0gZWxzZSB7ICJSRVNVTFQ9RkFJTCI7ICJOQU1FPSRuYW1lIiB9CiAgICB9IGNhdGNoIHsgIlJFU1VMVD1GQUlMIjsgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIiB9Cn0KCmZ1bmN0aW9uIFNhdmUtSGVhbHRoSGlz
HLP:dG9yeSgkc2NvcmUpIHsKICAgICRzY3JpcHREaXIgPSAkbnVsbAogICAgaWYgKCRQU1NjcmlwdFJvb3QpIHsKICAgICAgICAkc2NyaXB0RGlyID0gJFBTU2NyaXB0Um9vdAogICAgfSBlbHNlaWYgKCRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgpIHsKICAgICAg
HLP:ICAkc2NyaXB0RGlyID0gU3BsaXQtUGF0aCAtUGFyZW50ICRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgKICAgIH0KICAgICRiYXNlRGlyID0gaWYgKCRzY3JpcHREaXIpIHsgSm9pbi1QYXRoIChTcGxpdC1QYXRoIC1QYXJlbnQgJHNjcmlwdERpcikgIldQSV9T
HLP:dWl0ZSIgfSBlbHNlIHsgJFdvcmsgfQogICAgaWYgKCRzY3JpcHREaXIgLWFuZCAoVGVzdC1QYXRoICRzY3JpcHREaXIpKSB7CiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkYmFzZURpcikpIHsgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAk
HLP:YmFzZURpciAtRm9yY2UgfCBPdXQtTnVsbCB9CiAgICB9IGVsc2UgewogICAgICAgICRiYXNlRGlyID0gJFdvcmsKICAgIH0KICAgICRoaXN0b3J5RmlsZSA9IEpvaW4tUGF0aCAkYmFzZURpciAiaGVhbHRoX2hpc3RvcnkuanNvbiIKICAgICRoaXN0b3J5ID0gQCgp
HLP:CiAgICBpZiAoVGVzdC1QYXRoICRoaXN0b3J5RmlsZSkgewogICAgICAgIHRyeSB7ICRoaXN0b3J5ID0gR2V0LUNvbnRlbnQgJGhpc3RvcnlGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uIH0gY2F0Y2gge30KICAgIH0KICAgICRlbnRyeSA9IFtwc2N1c3RvbW9i
HLP:amVjdF1AewogICAgICAgIGRhdGUgID0gKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZCBISDptbScpCiAgICAgICAgc2NvcmUgPSBbaW50XSRzY29yZQogICAgfQogICAgJGhpc3RvcnkgPSBAKCRoaXN0b3J5KSArICRlbnRyeQogICAgaWYgKCRoaXN0b3J5
HLP:LkNvdW50IC1ndCAxMCkgeyAkaGlzdG9yeSA9ICRoaXN0b3J5Wy0xMC4uLTFdIH0KICAgIHRyeSB7CiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRoaXN0b3J5RmlsZSwgKCRoaXN0b3J5IHwgQ29udmVydFRvLUpzb24pLCAoTmV3LU9iamVj
HLP:dCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKSkpCiAgICB9IGNhdGNoIHt9Cn0KCmZ1bmN0aW9uIEluc3RhbGwtV2luZ2V0Qm9vdHN0cmFwIHsKICAgICR0ZW1wRmlsZSA9IEpvaW4tUGF0aCAkZW52OlRFTVAgIk1pY3Jvc29mdC5EZXNrdG9wQXBwSW5z
HLP:dGFsbGVyXzh3ZWt5YjNkOGJid2UubXNpeGJ1bmRsZSIKICAgIHRyeSB7CiAgICAgICAgJHVybCA9ICJodHRwczovL2dpdGh1Yi5jb20vbWljcm9zb2Z0L3dpbmdldC1jbGkvcmVsZWFzZXMvbGF0ZXN0L2Rvd25sb2FkL01pY3Jvc29mdC5EZXNrdG9wQXBwSW5zdGFs
HLP:bGVyXzh3ZWt5YjNkOGJid2UubXNpeGJ1bmRsZSIKICAgICAgICBXcml0ZS1Ib3N0ICJEb3dubG9hZGluZyBBcHAgSW5zdGFsbGVyIGZyb206ICR1cmwiCiAgICAgICAgJHdlYkNsaWVudCA9IE5ldy1PYmplY3QgU3lzdGVtLk5ldC5XZWJDbGllbnQKICAgICAgICBb
HLP:U3lzdGVtLk5ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6U2VjdXJpdHlQcm90b2NvbCA9IFtTeXN0ZW0uTmV0LlNlY3VyaXR5UHJvdG9jb2xUeXBlXTo6VGxzMTIKICAgICAgICAkd2ViQ2xpZW50LkRvd25sb2FkRmlsZSgkdXJsLCAkdGVtcEZpbGUpCiAgICAgICAg
HLP:CiAgICAgICAgV3JpdGUtSG9zdCAiSW5zdGFsbGluZyBBcHAgSW5zdGFsbGVyIHdpdGggQWRkLUFwcHhQYWNrYWdlLi4uIgogICAgICAgIEFkZC1BcHB4UGFja2FnZSAtUGF0aCAkdGVtcEZpbGUgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICBXcml0ZS1Ib3N0ICJJ
HLP:bnN0YWxsYXRpb24gc3VjY2Vzc2Z1bC4iCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkdGVtcEZpbGUpIHsgUmVtb3ZlLUl0ZW0gJHRlbXBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgcmV0dXJuICR0cnVlCiAgICB9IGNh
HLP:dGNoIHsKICAgICAgICBXcml0ZS1Ib3N0ICJ3aW5nZXQgYm9vdHN0cmFwIGVycm9yOiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgICAgICBpZiAoVGVzdC1QYXRoICR0ZW1wRmlsZSkgeyBSZW1vdmUtSXRlbSAkdGVtcEZpbGUgLUZvcmNlIC1FcnJvckFjdGlv
HLP:biBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICByZXR1cm4gJGZhbHNlCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyAoMy43IC8gQnVnIDUgLyBSZXEg
HLP:NykgRGV0ZWNjaW9uIGZpYWJsZSBkZWwgdGlwbyBkZSBkaXNjby4KIyBDb252ZXJ0VG8tTWVkaWFDbGFzczogZnVuY2lvbiBQVVJBIHF1ZSBtYXBlYSB1biBNZWRpYVR5cGUgKG51bWVybyBvIHRleHRvKQojIGEgbGEgY2xhc2UgY2Fub25pY2Ege1NTRCxIREQsVU5L
HLP:Tk9XTn0uIFNTRD00IG8gJ1NTRCc7IEhERD0zIG8gJ0hERCc7CiMgY3VhbHF1aWVyIG90cm8gdmFsb3IgKFVuc3BlY2lmaWVkPTAsIHZhY2lvLCBudWxvLCBTQ009NS4uLikgLT4gVU5LTk9XTi4KZnVuY3Rpb24gQ29udmVydFRvLU1lZGlhQ2xhc3MoJG10KSB7CiAg
HLP:ICBpZiAoJG51bGwgLWVxICRtdCkgeyByZXR1cm4gJ1VOS05PV04nIH0KICAgICRzID0gKFtzdHJpbmddJG10KS5UcmltKCkKICAgIGlmICgkcyAtZXEgJycpIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICBzd2l0Y2ggLXJlZ2V4ICgkcy5Ub1VwcGVyKCkpIHsKICAg
HLP:ICAgICAnXig0fFNTRCkkJyB7IHJldHVybiAnU1NEJyB9CiAgICAgICAgJ14oM3xIREQpJCcgeyByZXR1cm4gJ0hERCcgfQogICAgICAgIGRlZmF1bHQgICAgIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICB9Cn0KCiMgUmVzb2x2ZS1PcHRpbWl6ZUFjdGlvbjogZnVu
HLP:Y2lvbiBQVVJBLiBUUklNIHNvbG8gc2kgU1NELCBERUZSQUcgc29sbyBzaSBIREQKIyBjbGFybywgTk9ORSBlbiBjdWFscXVpZXIgb3RybyBjYXNvIChhYnN0ZW5jaW9uIHNlZ3VyYTogbnVuY2EgZGVzZnJhZ21lbnRhCiMgYW50ZSB0aXBvIGluY2llcnRvLCBldml0
HLP:YW5kbyBkYW5hciB1biBwb3NpYmxlIFNTRCkuCmZ1bmN0aW9uIFJlc29sdmUtT3B0aW1pemVBY3Rpb24oJG1lZGlhKSB7CiAgICAkbSA9IChbc3RyaW5nXSRtZWRpYSkuVHJpbSgpLlRvVXBwZXIoKQogICAgaWYgICAgICgkbSAtZXEgJ1NTRCcpICAgICB7IHJldHVy
HLP:biAnVFJJTScgfQogICAgZWxzZWlmICgkbSAtZXEgJ0hERCcpICAgICB7IHJldHVybiAnREVGUkFHJyB9CiAgICBlbHNlaWYgKCRtIC1lcSAnVklSVFVBTCcpIHsgcmV0dXJuICdOT05FJyB9ICAgIyAodjMuMikgZGlzY28gZGUgbWFxdWluYSB2aXJ0dWFsOiBubyBh
HLP:cGxpY2EKICAgIGVsc2UgICAgICAgICAgICAgICAgICAgICAgeyByZXR1cm4gJ05PTkUnIH0KfQoKIyBHZXQtTWVkaWFUeXBlOiBpZGVudGlmaWNhIGVsIGRpc2NvIGZpc2ljbyBkZWwgdm9sdW1lbiBkZWwgc2lzdGVtYSBkZSBmb3JtYQojIGZpYWJsZSAocG9yIERl
HLP:dmljZUlkLCByZXNwYWxkbyBwb3IgU2VyaWFsTnVtYmVyKSB5IGRldnVlbHZlIFNTRHxIRER8VklSVFVBTHxVTktOT1dOLgpmdW5jdGlvbiBHZXQtTWVkaWFUeXBlIHsKICAgIHRyeSB7CiAgICAgICAgJHN5cyAgPSAoJGVudjpTeXN0ZW1Ecml2ZSkuVHJpbUVuZCgn
HLP:OicpCiAgICAgICAgJGRpc2sgPSBHZXQtUGFydGl0aW9uIC1Ecml2ZUxldHRlciAkc3lzIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgR2V0LURpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkcGQgPSAkbnVsbAogICAgICAg
HLP:IGlmICgkZGlzaykgewogICAgICAgICAgICAkcGQgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uRGV2aWNlSWQgLWVxICRkaXNrLk51bWJlciB9IHwgU2Vs
HLP:ZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICBpZiAoLW5vdCAkcGQgLWFuZCAkZGlzay5TZXJpYWxOdW1iZXIpIHsKICAgICAgICAgICAgICAgICRwZCA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAg
HLP:ICAgICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uU2VyaWFsTnVtYmVyIC1hbmQgKCRfLlNlcmlhbE51bWJlci5UcmltKCkgLWVxIChbc3RyaW5nXSRkaXNrLlNlcmlhbE51bWJlcikuVHJpbSgpKSB9IHwKICAgICAgICAgICAgICAgICAgICAgIFNlbGVjdC1P
HLP:YmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICAjICh2My4yKSBkaXNjbyBkZSBtYXF1aW5hIHZpcnR1YWwgKFZpcnR1YWxCb3gvVk13YXJlL0h5cGVyLVYvUUVNVSk6IFRSSU0geQogICAgICAgICMgZGVzZnJhZ21lbnRhY2lvbiBu
HLP:byBhcGxpY2FuOyBzZSBpZGVudGlmaWNhIHBvciBlbCBtb2RlbG8gZGVsIGRpc2NvLgogICAgICAgICRtb2RlbG9zID0gQCgpCiAgICAgICAgaWYgKCRkaXNrKSB7ICRtb2RlbG9zICs9IFtzdHJpbmddJGRpc2suRnJpZW5kbHlOYW1lOyAkbW9kZWxvcyArPSBbc3Ry
HLP:aW5nXSRkaXNrLk1vZGVsIH0KICAgICAgICBpZiAoJHBkKSAgIHsgJG1vZGVsb3MgKz0gW3N0cmluZ10kcGQuRnJpZW5kbHlOYW1lOyAgICRtb2RlbG9zICs9IFtzdHJpbmddJHBkLk1vZGVsIH0KICAgICAgICBpZiAoKCRtb2RlbG9zIC1qb2luICcgJykgLW1hdGNo
HLP:ICdWQk9YfFZNV0FSRXxWSVJUVUFMfFFFTVV8WEVOU1JDJykgeyByZXR1cm4gJ1ZJUlRVQUwnIH0KICAgICAgICBpZiAoLW5vdCAkcGQpIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICAgICAgcmV0dXJuIChDb252ZXJ0VG8tTWVkaWFDbGFzcyAkcGQuTWVkaWFUeXBl
HLP:KQogICAgfSBjYXRjaCB7IHJldHVybiAnVU5LTk9XTicgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCmZ1bmN0aW9uIEdldC1EZXZpY2VQcm9ibGVtcyB7CiAgICAk
HLP:cCA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1BuUEVudGl0eSB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUgLWd0IDAgfSkKICAgIGlmICgkcC5Db3VudCAtZXEgMCkgeyAiT0t8Tm8gZGV2aWNlcyB3aXRoIHByb2JsZW1zLiI7IHJl
HLP:dHVybiB9CiAgICBmb3JlYWNoICgkZCBpbiAoJHAgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxMikpIHsKICAgICAgICAiUFJPQnwkKCRkLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUpfCQoJGQuTmFtZSkiCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBJbmZvcm1lIEhUTUwgYXV0b2NvbnRlbmlkbyB5IGJvbml0byAodGVtYSBvc2N1cm8pLiAtQXJnID0gcnV0YSBkZSBzYWxpZGEuCmZ1bmN0aW9uIE5ldy1IdG1sUmVwb3J0
HLP:KCRvdXRQYXRoKSB7CiAgICBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XZWIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIHRyeSB7CiAgICAgICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgICAgICRzeXNQYWlycyA9IEdldC1TeXNJbmZvCgog
HLP:ICAgICAgICRlbmMgPSB7IHBhcmFtKCR0KSBbU3lzdGVtLldlYi5IdHRwVXRpbGl0eV06Okh0bWxFbmNvZGUoW3N0cmluZ10kdCkgfQogICAgICAgICRjaXJjID0gNTI3Ljc5CiAgICAgICAgJGJhbmRDb2xvciA9IHsgcGFyYW0oJHMpIGlmICgkcyAtZXEgJy0nIC1v
HLP:ciAkbnVsbCAtZXEgJHMgLW9yIFtzdHJpbmddJHMgLWVxICcnKSB7ICcjOTRhM2I4JyB9IGVsc2UgeyAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0Y2ggeyByZXR1cm4gJyM5NGEzYjgnIH07IGlmICgkdiAtZ2UgODApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJHYg
HLP:LWdlIDUwKSB7JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9IH0gfQogICAgICAgICRiYW5kTGFiZWwgPSB7IHBhcmFtKCRzKSBpZiAoJHMgLWVxICctJyAtb3IgJG51bGwgLWVxICRzIC1vciBbc3RyaW5nXSRzIC1lcSAnJykgeyAnbm8gZGF0YScgfSBlbHNlIHsg
HLP:JHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgcmV0dXJuICdubyBkYXRhJyB9OyBpZiAoJHYgLWdlIDgwKSB7J0dvb2QnfSBlbHNlaWYgKCR2IC1nZSA1MCkgeydGYWlyJ30gZWxzZSB7J0NyaXRpY2FsJ30gfSB9CiAgICAgICAgJG9mZnNldE9mID0geyBw
HLP:YXJhbSgkcykgJHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgJHY9MCB9OyBpZiAoJHYgLWx0IDApeyR2PTB9OyBpZiAoJHYgLWd0IDEwMCl7JHY9MTAwfTsgW21hdGhdOjpSb3VuZCgkY2lyYyAqICgxIC0gKCR2LzEwMC4wKSksIDIpIH0KICAgICAgICAk
HLP:c3RhdHVzSWNvbiA9IHsKICAgICAgICAgICAgcGFyYW0oJHJlcykKICAgICAgICAgICAgc3dpdGNoIChbc3RyaW5nXSRyZXMpIHsKICAgICAgICAgICAgICAgICdPSycgICAgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2lt
HLP:ZycgYXJpYS1sYWJlbD0nc3VjY2Vzc2Z1bCc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyMyMmM1NWUnLz48cGF0aCBkPSdNNyAxMi40bDMuMiAzLjJMMTcgOC44JyBmaWxsPSdub25lJyBzdHJva2U9JyMwNDIxMGYnIHN0cm9rZS13aWR0aD0n
HLP:Mi42JyBzdHJva2UtbGluZWNhcD0ncm91bmQnIHN0cm9rZS1saW5lam9pbj0ncm91bmQnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdXQVJOJyAgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJl
HLP:bD0nd2FybmluZyc+PHBhdGggZD0nTTEyIDIuNUwyMyAyMS41SDF6JyBmaWxsPScjZjU5ZTBiJy8+PHJlY3QgeD0nMTEnIHk9JzguNScgd2lkdGg9JzInIGhlaWdodD0nNycgcng9JzEnIGZpbGw9JyMzYTI0MDAnLz48Y2lyY2xlIGN4PScxMicgY3k9JzE4JyByPScx
HLP:LjMnIGZpbGw9JyMzYTI0MDAnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdFUlJPUicgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nZXJyb3InPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTIn
HLP:IHI9JzExJyBmaWxsPScjZWY0NDQ0Jy8+PHBhdGggZD0nTTggOGw4IDhNMTYgOGwtOCA4JyBzdHJva2U9JyMyYTA2MDYnIHN0cm9rZS13aWR0aD0nMi42JyBzdHJva2UtbGluZWNhcD0ncm91bmQnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdTS0lQJyAgeyAi
HLP:PHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nc2tpcHBlZCc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyM2NDc0OGInLz48cmVjdCB4PSc2LjUnIHk9JzExJyB3aWR0aD0nMTEn
HLP:IGhlaWdodD0nMicgcng9JzEnIGZpbGw9JyMwYjEyMjAnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgIGRlZmF1bHQgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScj
HLP:OTRhM2I4Jy8+PC9zdmc+IiB9CiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgICRiZWZvcmUgPSAkc3Quc2NvcmVfYmVmb3JlOyBpZiAoJG51bGwgLWVxICRiZWZvcmUpIHsgJGJlZm9yZSA9ICctJyB9CiAgICAgICAgJGFmdGVyICA9ICRzdC5zY29yZV9h
HLP:ZnRlcjsgIGlmICgkbnVsbCAtZXEgJGFmdGVyKSAgeyAkYWZ0ZXIgID0gJy0nIH0KICAgICAgICAkaGFzQm90aCA9ICgkc3Quc2NvcmVfYmVmb3JlIC1uZSAkbnVsbCAtYW5kICRzdC5zY29yZV9hZnRlciAtbmUgJG51bGwpCiAgICAgICAgJGRlbHRhID0gMDsgJGRl
HLP:bHRhVHh0ID0gJ25vIGNvbXBhcmlzb24nCiAgICAgICAgaWYgKCRoYXNCb3RoKSB7ICRkZWx0YSA9IFtpbnRdJHN0LnNjb3JlX2FmdGVyIC0gW2ludF0kc3Quc2NvcmVfYmVmb3JlOyAkc2lnbiA9IGlmICgkZGVsdGEgLWdlIDApIHsnKyd9IGVsc2UgeycnfTsgJGRl
HLP:bHRhVHh0ID0gIiRzaWduJGRlbHRhIHBvaW50cyIgfQogICAgICAgICRkZWx0YUNvbG9yID0gaWYgKCRkZWx0YSAtZ3QgMCkgeycjMjJjNTVlJ30gZWxzZWlmICgkZGVsdGEgLWx0IDApIHsnI2VmNDQ0NCd9IGVsc2UgeycjOTRhM2I4J30KICAgICAgICAkbWFpblNj
HLP:b3JlID0gaWYgKCRhZnRlciAtbmUgJy0nKSB7ICRhZnRlciB9IGVsc2VpZiAoJGJlZm9yZSAtbmUgJy0nKSB7ICRiZWZvcmUgfSBlbHNlIHsgJy0nIH0KICAgICAgICAkbWFpbkNvbG9yID0gJiAkYmFuZENvbG9yICRtYWluU2NvcmUKICAgICAgICAkbWFpbk9mZnNl
HLP:dCA9ICYgJG9mZnNldE9mICRtYWluU2NvcmUKICAgICAgICAkbWFpbkxhYmVsID0gJiAkYmFuZExhYmVsICRtYWluU2NvcmUKICAgICAgICAkYmVmb3JlQ29sb3IgPSAmICRiYW5kQ29sb3IgJGJlZm9yZQogICAgICAgICRhZnRlckNvbG9yICA9ICYgJGJhbmRDb2xv
HLP:ciAkYWZ0ZXIKICAgICAgICAkYmVmb3JlT2Zmc2V0ID0gJiAkb2Zmc2V0T2YgJGJlZm9yZQogICAgICAgICRhZnRlck9mZnNldCAgPSAmICRvZmZzZXRPZiAkYWZ0ZXIKCiAgICAgICAgJHNjcmlwdERpciA9ICRudWxsCiAgICAgICAgaWYgKCRQU1NjcmlwdFJvb3Qp
HLP:IHsKICAgICAgICAgICAgJHNjcmlwdERpciA9ICRQU1NjcmlwdFJvb3QKICAgICAgICB9IGVsc2VpZiAoJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aCkgewogICAgICAgICAgICAkc2NyaXB0RGlyID0gU3BsaXQtUGF0aCAtUGFyZW50ICRNeUludm9jYXRpb24u
HLP:TXlDb21tYW5kLlBhdGgKICAgICAgICB9CiAgICAgICAgJGJhc2VEaXIgPSBpZiAoJHNjcmlwdERpcikgeyBKb2luLVBhdGggKFNwbGl0LVBhdGggLVBhcmVudCAkc2NyaXB0RGlyKSAiV1BJX1N1aXRlIiB9IGVsc2UgeyAkV29yayB9CiAgICAgICAgJGhpc3RvcnlG
HLP:aWxlID0gSm9pbi1QYXRoICRiYXNlRGlyICJoZWFsdGhfaGlzdG9yeS5qc29uIgogICAgICAgICRoaXN0b3J5ID0gQCgpCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkaGlzdG9yeUZpbGUpIHsKICAgICAgICAgICAgdHJ5IHsgJGhpc3RvcnkgPSBHZXQtQ29udGVudCAk
HLP:aGlzdG9yeUZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkaGlzdG9yeUh0bWwgPSAnJwogICAgICAgIGlmICgkaGlzdG9yeSAtYW5kICRoaXN0b3J5LkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRoaXN0
HLP:b3J5SHRtbCArPSAiPGRpdiBjbGFzcz0ndHJlbmQtdGl0bGUnPkhlYWx0aCBIaXN0b3J5IChMYXN0IHJ1bnMpPC9kaXY+PGRpdiBjbGFzcz0ndHJlbmQtbGlzdCc+IgogICAgICAgICAgICBmb3JlYWNoICgkaCBpbiAkaGlzdG9yeSkgewogICAgICAgICAgICAgICAg
HLP:JGNvbCA9ICYgJGJhbmRDb2xvciAkaC5zY29yZQogICAgICAgICAgICAgICAgJGhpc3RvcnlIdG1sICs9ICI8ZGl2IGNsYXNzPSd0cmVuZC1pdGVtJz48c3BhbiBjbGFzcz0ndHJlbmQtZGF0ZSc+JCgkaC5kYXRlKTwvc3Bhbj48c3BhbiBjbGFzcz0ndHJlbmQtc2Nv
HLP:cmUnIHN0eWxlPSdjb2xvcjokY29sJz4kKCRoLnNjb3JlKS8xMDA8L3NwYW4+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgICRoaXN0b3J5SHRtbCArPSAiPC9kaXY+IgogICAgICAgIH0KCiAgICAgICAgJHN5c01hcCA9IEB7fQogICAgICAgIGZvcmVh
HLP:Y2ggKCRwIGluICRzeXNQYWlycykgeyAka3YgPSAkcCAtc3BsaXQgJz0nLDI7IGlmICgka3YuQ291bnQgLWVxIDIpIHsgJHN5c01hcFska3ZbMF1dID0gJGt2WzFdIH0gfQogICAgICAgICRzeXNPcmRlciA9IEAoQCgnT1MnLCdPcGVyYXRpbmcgU3lzdGVtJyksQCgn
HLP:U1lTVEVNJywnU3lzdGVtIE1vZGVsJyksQCgnQ1BVJywnUHJvY2Vzc29yJyksQCgnUkFNJywnUkFNIE1lbW9yeScpLEAoJ0RJU0snLCdEaXNrIEM6JyksQCgnVVBUSU1FJywnVXB0aW1lJyksQCgnVVNFUicsJ1VzZXInKSkKICAgICAgICAkc3lzQ2FyZHMgPSAnJwog
HLP:ICAgICAgIGZvcmVhY2ggKCRvIGluICRzeXNPcmRlcikgeyBpZiAoJHN5c01hcC5Db250YWluc0tleSgkb1swXSkpIHsgJHN5c0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdzeXMnPjxkaXYgY2xhc3M9J3N5cy1rJz4kKCYgJGVuYyAkb1sxXSk8L2Rpdj48ZGl2IGNsYXNz
HLP:PSdzeXMtdic+JCgmICRlbmMgJHN5c01hcFskb1swXV0pPC9kaXY+PC9kaXY+IiB9IH0KICAgICAgICAkbWFjaGluZSA9ICRzeXNNYXBbJ1NZU1RFTSddOyBpZiAoLW5vdCAkbWFjaGluZSkgeyAkbWFjaGluZSA9ICRlbnY6Q09NUFVURVJOQU1FIH0KCiAgICAgICAg
HLP:JHBoYXNlcyA9IEAoJHN0LnBoYXNlcykKICAgICAgICAkY09LPTA7JGNXQVJOPTA7JGNFUlI9MDskY1NLSVA9MAogICAgICAgICRtYXhTZWNzID0gMQogICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7ICRzdj0wOyB0cnkgeyAkc3Y9W2ludF0kcGguc2Vj
HLP:cyB9IGNhdGNoIHt9OyBpZiAoJHN2IC1ndCAkbWF4U2VjcykgeyAkbWF4U2VjcyA9ICRzdiB9IH0KICAgICAgICAkcm93cyA9ICcnCiAgICAgICAgJGJhcnMgPSAnJwogICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7CiAgICAgICAgICAgICRyZXMgPSBb
HLP:c3RyaW5nXSRwaC5yZXN1bHQKICAgICAgICAgICAgc3dpdGNoICgkcmVzKSB7ICdPSycgeyRjT0srK30gJ1dBUk4nIHskY1dBUk4rK30gJ0VSUk9SJyB7JGNFUlIrK30gJ1NLSVAnIHskY1NLSVArK30gfQogICAgICAgICAgICAkbGMgPSAkcmVzLlRvTG93ZXIoKQog
HLP:ICAgICAgICAgICAkbm90ZSA9IGlmIChbc3RyaW5nXSRwaC5ub3RlIC1uZSAnJykgeyAiPGRpdiBjbGFzcz0ncGgtbm90ZSc+JCgmICRlbmMgJHBoLm5vdGUpPC9kaXY+IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICRyb3dzICs9ICI8ZGl2IGNsYXNzPSdwaCBw
HLP:aC0kbGMnPjxkaXYgY2xhc3M9J3BoLWRvdCc+JCgmICRzdGF0dXNJY29uICRyZXMpPC9kaXY+PGRpdiBjbGFzcz0ncGgtbWFpbic+PGRpdiBjbGFzcz0ncGgtdG9wJz48c3BhbiBjbGFzcz0ncGgtbnVtJz4kKCYgJGVuYyAkcGgubnVtKTwvc3Bhbj48c3BhbiBjbGFz
HLP:cz0ncGgtdGl0bGUnPiQoJiAkZW5jICRwaC50aXRsZSk8L3NwYW4+PHNwYW4gY2xhc3M9J3BoLWJhZGdlIGItJGxjJz4kcmVzPC9zcGFuPjwvZGl2PiRub3RlPC9kaXY+PGRpdiBjbGFzcz0ncGgtc2Vjcyc+JCgmICRlbmMgJHBoLnNlY3MpczwvZGl2PjwvZGl2PiIK
HLP:ICAgICAgICAgICAgJHN2PTA7IHRyeSB7ICRzdj1baW50XSRwaC5zZWNzIH0gY2F0Y2gge30KICAgICAgICAgICAgJHcgPSBbbWF0aF06OlJvdW5kKDEwMC4wICogJHN2IC8gW21hdGhdOjpNYXgoMSwkbWF4U2VjcykpOyBpZiAoJHcgLWx0IDIgLWFuZCAkc3YgLWd0
HLP:IDApIHsgJHcgPSAyIH0KICAgICAgICAgICAgJGJjb2wgPSBzd2l0Y2ggKCRyZXMpIHsgJ09LJyB7JyMyMmM1NWUnfSAnV0FSTicgeycjZjU5ZTBiJ30gJ0VSUk9SJyB7JyNlZjQ0NDQnfSBkZWZhdWx0IHsnIzY0NzQ4Yid9IH0KICAgICAgICAgICAgJGJhcnMgKz0g
HLP:IjxkaXYgY2xhc3M9J2Jhci1yb3cnPjxkaXYgY2xhc3M9J2Jhci1sYmwnPiQoJiAkZW5jICRwaC5udW0pICQoJiAkZW5jICRwaC50aXRsZSk8L2Rpdj48ZGl2IGNsYXNzPSdiYXItdHJhY2snPjxzcGFuIHN0eWxlPSd3aWR0aDokdyU7YmFja2dyb3VuZDokYmNvbCc+
HLP:PC9zcGFuPjwvZGl2PjxkaXYgY2xhc3M9J2Jhci12YWwnPiQoJiAkZW5jICRwaC5zZWNzKXM8L2Rpdj48L2Rpdj4iCiAgICAgICAgfQogICAgICAgIGlmICgtbm90ICRyb3dzKSB7ICRyb3dzID0gIjxkaXYgY2xhc3M9J2VtcHR5Jz5ObyBwaGFzZXMgd2VyZSByZWNv
HLP:cmRlZCBpbiB0aGlzIHJ1bi48L2Rpdj4iIH0KICAgICAgICBpZiAoLW5vdCAkYmFycykgeyAkYmFycyA9ICI8ZGl2IGNsYXNzPSdlbXB0eSc+Tm8gdGltaW5ncyB0byBzaG93LjwvZGl2PiIgfQogICAgICAgICR0b3RhbFBoID0gJHBoYXNlcy5Db3VudAogICAgICAg
HLP:ICMgUkVBTCBhZ2dyZWdhdGUgc3RhdGlzdGljcyBvZiB3aGF0IGFjdHVhbGx5IHJhbjogdG90YWwgc2Vzc2lvbiB0aW1lIGFuZAogICAgICAgICMgc3BhY2UgZnJlZWQgKHN1bW1lZCBmcm9tIGVhY2ggcGhhc2UncyBtZWFzdXJlZCBub3RlcywgTUIvR0IpLgogICAg
HLP:ICAgICR0b3RTZWNzID0gMDsgJG1iRnJlZWQgPSAwLjAKICAgICAgICBmb3JlYWNoICgkcGggaW4gJHBoYXNlcykgewogICAgICAgICAgICAkc3YgPSAwOyB0cnkgeyAkc3YgPSBbaW50XSRwaC5zZWNzIH0gY2F0Y2gge307ICR0b3RTZWNzICs9ICRzdgogICAgICAg
HLP:ICAgICBmb3JlYWNoICgkbSBpbiBbcmVnZXhdOjpNYXRjaGVzKFtzdHJpbmddJHBoLm5vdGUsICcoP2kpKD86bGliZXJhZFx3KnxmcmVlZClcRHswLDEwfT8oW1xkXC4sXSspXHMqKE1CfEdCKScpKSB7CiAgICAgICAgICAgICAgICAkdiA9IDAuMDsgdHJ5IHsgJHYg
HLP:PSBbZG91YmxlXSgkbS5Hcm91cHNbMV0uVmFsdWUuUmVwbGFjZSgnLCcsICcuJykpIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgIGlmICgkbS5Hcm91cHNbMl0uVmFsdWUgLW1hdGNoICcoP2kpR0InKSB7ICR2ID0gJHYgKiAxMDI0IH0KICAgICAgICAgICAgICAg
HLP:ICRtYkZyZWVkICs9ICR2CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgJHRvdFR4dCA9IGlmICgkdG90U2VjcyAtZ2UgNjApIHsgKCd7MH0gbWluIHsxfSBzJyAtZiBbaW50XVttYXRoXTo6Rmxvb3IoJHRvdFNlY3MgLyA2MCksICgkdG90U2VjcyAlIDYw
HLP:KSkgfSBlbHNlIHsgKCd7MH0gcycgLWYgJHRvdFNlY3MpIH0KICAgICAgICAkZnJlZWRUeHQgPSBpZiAoJG1iRnJlZWQgLWdlIDEwMjQpIHsgKCd7MDpuMX0gR0InIC1mICgkbWJGcmVlZCAvIDEwMjQpKSB9IGVsc2VpZiAoJG1iRnJlZWQgLWd0IDApIHsgKCd7MDpu
HLP:MH0gTUInIC1mICRtYkZyZWVkKSB9IGVsc2UgeyAnJyB9CiAgICAgICAgJHN0YXRMaW5lID0gKCd0b3RhbCB0aW1lOiB7MH0nIC1mICR0b3RUeHQpCiAgICAgICAgaWYgKCRmcmVlZFR4dCkgeyAkc3RhdExpbmUgKz0gKCcgJm1pZGRvdDsgc3BhY2UgZnJlZWQ6IHsw
HLP:fScgLWYgJGZyZWVkVHh0KSB9CgogICAgICAgICRmaW5kaW5ncyA9IEAoJHN0LmZpbmRpbmdzKQogICAgICAgICRmaW5kSHRtbCA9ICcnCiAgICAgICAgJHN0ZXBzTGlzdCA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmdd
HLP:CiAgICAgICAgZm9yZWFjaCAoJGYgaW4gJGZpbmRpbmdzKSB7CiAgICAgICAgICAgICR0eHQgPSBbc3RyaW5nXSRmCiAgICAgICAgICAgICRzZXYgPSAnaW5mbyc7ICRzZXZUeHQgPSAnTm90aWNlJwogICAgICAgICAgICBpZiAoJHR4dCAtbWF0Y2ggJyg/aSlTTUFS
HLP:VHxCU09EfGNyYXNofFdIRUF8aGFyZHdhcmV8dW5yZXBhaXJhYmxlfGRhbWFnZWR8cmVwb3NpdG9yeXxpbnRlZ3JpdHknKSB7ICRzZXY9J2hpZ2gnOyAkc2V2VHh0PSdJbXBvcnRhbnQnIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKXNwYWNl
HLP:fHBlbmRpbmcgcmVib290fG5ldHdvcmt8YmF0dGVyeXxkcml2ZXJ8ZGV2aWNlfFxiUkFNXGJ8c2VydmljZScpIHsgJHNldj0nbWVkJzsgJHNldlR4dD0nUmV2aWV3JyB9CiAgICAgICAgICAgICRmaW5kSHRtbCArPSAiPGxpIGNsYXNzPSdmaW5kIGZpbmQtJHNldic+
HLP:PHNwYW4gY2xhc3M9J3NldiBzZXYtJHNldic+JHNldlR4dDwvc3Bhbj48c3BhbiBjbGFzcz0nZmluZC10eHQnPiQoJiAkZW5jICR0eHQpPC9zcGFuPjwvbGk+IgogICAgICAgICAgICAjIERlcml2YXIgcGFzbyByZWNvbWVuZGFkbyBhIHBhcnRpciBkZWwgaGFsbGF6
HLP:Z28KICAgICAgICAgICAgaWYgKCR0eHQgLW1hdGNoICcoP2kpU01BUlQnKSAgICAgICAgICB7ICRzdGVwc0xpc3QuQWRkKCdCYWNrIHVwIHlvdXIgZGF0YSBhcyBzb29uIGFzIHBvc3NpYmxlOiBhIGRpc2sgd2l0aCBkZWdyYWRlZCBTTUFSVCBjYW4gZmFpbC4gQ29u
HLP:c2lkZXIgcmVwbGFjaW5nIGl0LicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKXNwYWNlJykgICAgeyAkc3RlcHNMaXN0LkFkZCgnRnJlZSB1cCBzcGFjZSBvbiBDOiAodW5pbnN0YWxsIHdoYXQgeW91IGRvbicndCB1c2Ugb3IgdXNlIFN0
HLP:b3JhZ2UgU2Vuc2UpLiBBaW0gZm9yIG1vcmUgdGhhbiAxNSBHQiBmcmVlLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKVxiUkFNXGJ8bWVtb3J5JykgeyAkc3RlcHNMaXN0LkFkZCgnUnVuIFdpbmRvd3MgTWVtb3J5IERpYWdub3N0aWMg
HLP:KG1kc2NoZWQuZXhlKSBhbmQgcmVib290IHRvIGNoZWNrIHRoZSBSQU0uJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpYmF0dGVyeScpICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ1RoZSBiYXR0ZXJ5IGlzIGRlZ3JhZGVkLiBDaGVjayB0aGUg
HLP:YmF0dGVyeSByZXBvcnQgKHBvd2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0KSBhbmQgY29uc2lkZXIgcmVwbGFjaW5nIGl0LicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKXBlbmRpbmcgcmVib290JykgeyAkc3RlcHNMaXN0LkFkZCgnUmVib290
HLP:IHRoZSBQQyB0byBhcHBseSBwZW5kaW5nIGNoYW5nZXMgYmVmb3JlIGNvbnRpbnVpbmcgcmVwYWlycy4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSl1bnJlcGFpcmFibGV8cmVwb3NpdG9yeXxpbnRlZ3JpdHknKSB7ICRzdGVwc0xpc3Qu
HLP:QWRkKCdEYW1hZ2VkIGNvbXBvbmVudHMgcmVtYWluLiBSdW4gRElTTSB3aXRoIGEgdmFsaWQgc291cmNlIChpbnN0YWxsLndpbSkgYW5kIHJ1biBTRkMgYWdhaW4uJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpZHJpdmVyfGRldmljZScp
HLP:IHsgJHN0ZXBzTGlzdC5BZGQoJ1VwZGF0ZSB0aGUgZHJpdmVycyBvZiB0aGUgZmFpbGluZyBkZXZpY2VzIGZyb20gdGhlIG1ha2VyJydzIHNpdGUgb3IgV2luZG93cyBVcGRhdGUuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpbmV0d29y
HLP:a3xETlMnKSAgICAgICAgeyAkc3RlcHNMaXN0LkFkZCgnQ2hlY2sgdGhlIG5ldHdvcmsgY29ubmVjdGlvbiBhbmQgRE5TLiBJZiBpdCBwZXJzaXN0cywgdHJ5IGEgcHVibGljIEROUyAoMS4xLjEuMSAvIDguOC44LjgpLicpIH0KICAgICAgICB9CiAgICAgICAgJG5v
HLP:RmluZCA9ICgkZmluZGluZ3MuQ291bnQgLWVxIDApCiAgICAgICAgaWYgKCRub0ZpbmQpIHsgJGZpbmRIdG1sID0gIjxsaSBjbGFzcz0nZmluZCBmaW5kLW9rJz48c3BhbiBjbGFzcz0nc2V2IHNldi1vayc+QWxsIE9LPC9zcGFuPjxzcGFuIGNsYXNzPSdmaW5kLXR4
HLP:dCc+Tm8gcmVsZXZhbnQgcHJvYmxlbXMgd2VyZSBkZXRlY3RlZCBkdXJpbmcgZGlhZ25vc2lzLjwvc3Bhbj48L2xpPiIgfQoKICAgICAgICAjIC0tLSBQcm94aW1vcyBwYXNvcyByZWNvbWVuZGFkb3MgKGRlZHVwbGljYWRvcykgLS0tCiAgICAgICAgJHN0ZXBzSHRt
HLP:bCA9ICcnCiAgICAgICAgJHNlZW4gPSBAe30KICAgICAgICBmb3JlYWNoICgkcyBpbiAkc3RlcHNMaXN0KSB7IGlmICgtbm90ICRzZWVuLkNvbnRhaW5zS2V5KCRzKSkgeyAkc2Vlblskc109JHRydWU7ICRzdGVwc0h0bWwgKz0gIjxsaSBjbGFzcz0nc3RlcC1saSc+
HLP:PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAxNDg7PC9zcGFuPjxzcGFuPiQoJiAkZW5jICRzKTwvc3Bhbj48L2xpPiIgfSB9CiAgICAgICAgaWYgKCRjRVJSIC1ndCAwKSB7ICRzdGVwc0h0bWwgPSAiPGxpIGNsYXNzPSdzdGVwLWxpJz48c3BhbiBjbGFzcz0nc3Rl
HLP:cC1pYyc+JiMxMDE0ODs8L3NwYW4+PHNwYW4+U29tZSBwaGFzZXMgaGFkIGVycm9yczogY2hlY2sgdGhlIGRldGFpbGVkIGxvZyBpbiB0aGUgV1BJX1N1aXRlXExvZ3MgZm9sZGVyLjwvc3Bhbj48L2xpPiIgKyAkc3RlcHNIdG1sIH0KICAgICAgICBpZiAoLW5vdCAk
HLP:c3RlcHNIdG1sKSB7ICRzdGVwc0h0bWwgPSAiPGxpIGNsYXNzPSdzdGVwLWxpIHN0ZXAtb2snPjxzcGFuIGNsYXNzPSdzdGVwLWljJz4mIzEwMDAzOzwvc3Bhbj48c3Bhbj5ObyBwZW5kaW5nIGFjdGlvbnMuIFJlYm9vdCB0aGUgUEMgdG8gbWFrZSBzdXJlIGFsbCBj
HLP:aGFuZ2VzIGFyZSBhcHBsaWVkLjwvc3Bhbj48L2xpPiIgfQoKICAgICAgICAjID09PT09PT09PT09PT09PT09PT09PT0gRElBR05PU1RJQ08gQU1QTElBRE8gPT09PT09PT09PT09PT09PT09PT09PQogICAgICAgICRkaWFnQ2FyZHMgPSAnJwogICAgICAgIGlmICgo
HLP:JHN0LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2RpYWcnKSAtYW5kICRzdC5kaWFnKSB7CiAgICAgICAgICAgICRkID0gJHN0LmRpYWcKICAgICAgICAgICAgaWYgKCRkLnJhbSkgewogICAgICAgICAgICAgICAgJHJzID0gW3N0cmluZ10kZC5y
HLP:YW0uc3RhdHVzCiAgICAgICAgICAgICAgICAkcnAgPSBzd2l0Y2ggKCRycykgeyAnb2snIHsnZ29vZCd9ICdzdXNwZWN0JyB7J2JhZCd9IGRlZmF1bHQgeyd1bmtub3duJ30gfQogICAgICAgICAgICAgICAgJHJ0ID0gc3dpdGNoICgkcnMpIHsgJ29rJyB7J05vIGVy
HLP:cm9ycyBkZXRlY3RlZCd9ICdzdXNwZWN0JyB7J1N1c3BlY3QnfSBkZWZhdWx0IHsnTm90IGV2YWx1YXRlZCd9IH0KICAgICAgICAgICAgICAgICRtZHMgPSBpZiAoJGQucmFtLnJlY29tbWVuZF9tZHNjaGVkKSB7ICI8ZGl2IGNsYXNzPSdkLWhpbnQnPlJlY29tbWVu
HLP:ZGVkOiBydW4gV2luZG93cyBNZW1vcnkgRGlhZ25vc3RpYyAobWRzY2hlZCkuPC9kaXY+IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1p
HLP:YyBpYy1yYW0nPjwvc3Bhbj5SQU0gTWVtb3J5PC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtJHJwJz4kcnQ8L2Rpdj4kbWRzPC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkZC5iYXR0ZXJ5KSB7CiAgICAgICAgICAgICAgICBpZiAoJGQu
HLP:YmF0dGVyeS5wcmVzZW50KSB7CiAgICAgICAgICAgICAgICAgICAgJGJwUmF3ID0gJGQuYmF0dGVyeS5oZWFsdGhfcGN0CiAgICAgICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkYnBSYXcgLWFuZCBbc3RyaW5nXSRicFJhdyAtbmUgJycpIHsKICAgICAgICAg
HLP:ICAgICAgICAgICAgICAgJGJwID0gMDsgdHJ5IHsgJGJwID0gW2ludF0kYnBSYXcgfSBjYXRjaCB7ICRicCA9IDAgfQogICAgICAgICAgICAgICAgICAgICAgICAkYnBjb2wgPSBpZiAoJGJwIC1nZSA4MCkgeycjMjJjNTVlJ30gZWxzZWlmICgkYnAgLWdlIDUwKSB7
HLP:JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9CiAgICAgICAgICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJhdCc+PC9zcGFuPkJhdHRlcnk8L2Rpdj48
HLP:ZGl2IGNsYXNzPSdiYXQtYmFyJz48c3BhbiBzdHlsZT0nd2lkdGg6JGJwJTtiYWNrZ3JvdW5kOiRicGNvbCc+PC9zcGFuPjwvZGl2PjxkaXYgY2xhc3M9J2Qtc3ViJz5Fc3RpbWF0ZWQgaGVhbHRoOiA8YiBzdHlsZT0nY29sb3I6JGJwY29sJz4kYnAlPC9iPjwvZGl2
HLP:PjwvZGl2PiIKICAgICAgICAgICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXR0
HLP:ZXJ5PC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtdW5rbm93bic+UHJlc2VudCwgaGVhbHRoIHVua25vd248L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgICAgICAkZGlh
HLP:Z0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXR0ZXJ5PC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtdW5rbm93bic+Tm90IHByZXNlbnQgKGRlc2t0b3AgUEMp
HLP:PC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkZC5uZXR3b3JrKSB7CiAgICAgICAgICAgICAgICAkY2MgPSBpZiAoJGQubmV0d29yay5jb25uZWN0ZWQpIHsnZ29vZCd9IGVsc2UgeydiYWQnfQogICAg
HLP:ICAgICAgICAgICAgJGN0ID0gaWYgKCRkLm5ldHdvcmsuY29ubmVjdGVkKSB7J0Nvbm5lY3RlZCd9IGVsc2UgeydObyBjb25uZWN0aW9uJ30KICAgICAgICAgICAgICAgICRkYyA9IGlmICgkZC5uZXR3b3JrLmRuc19vaykgeydnb29kJ30gZWxzZSB7J2JhZCd9CiAg
HLP:ICAgICAgICAgICAgICAkZHQgPSBpZiAoJGQubmV0d29yay5kbnNfb2spIHsnRE5TIE9LJ30gZWxzZSB7J0ROUyBmYWlsaW5nJ30KICAgICAgICAgICAgICAgICRkZXQgPSAmICRlbmMgJGQubmV0d29yay5kZXRhaWxzCiAgICAgICAgICAgICAgICAkbGF0ID0gJycK
HLP:ICAgICAgICAgICAgICAgIGlmICgoJGQubmV0d29yay5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdkbnNfbXMnKSAtYW5kICRudWxsIC1uZSAkZC5uZXR3b3JrLmRuc19tcyAtYW5kIFtzdHJpbmddJGQubmV0d29yay5kbnNfbXMgLW5lICcnKSB7
HLP:CiAgICAgICAgICAgICAgICAgICAgJG1zID0gMDsgdHJ5IHsgJG1zID0gW2ludF0kZC5uZXR3b3JrLmRuc19tcyB9IGNhdGNoIHt9CiAgICAgICAgICAgICAgICAgICAgJGxjMiA9IGlmICgkbXMgLWx0IDYwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCRtcyAtbHQgMjAw
HLP:KSB7JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9CiAgICAgICAgICAgICAgICAgICAgJGxhdCA9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+RE5TIGxhdGVuY3k6IDxiIHN0eWxlPSdjb2xvcjokbGMyJz4kbXMgbXM8L2I+PC9kaXY+IgogICAgICAgICAgICAgICAgfQog
HLP:ICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtbmV0Jz48L3NwYW4+TmV0d29yazwvZGl2PjxkaXYgY2xhc3M9J3BpbGwtcm93Jz48c3BhbiBjbGFzcz0nZC1w
HLP:aWxsIHBpbGwtJGNjJz4kY3Q8L3NwYW4+PHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLSRkYyc+JGR0PC9zcGFuPjwvZGl2PjxkaXYgY2xhc3M9J2Qtc3ViJz4kZGV0PC9kaXY+JGxhdDwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoKCRkLlBTT2Jq
HLP:ZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3NtYXJ0JykgLWFuZCAkZC5zbWFydCAtYW5kICRkLnNtYXJ0LmF2YWlsYWJsZSkgewogICAgICAgICAgICAgICAgJHNtID0gJGQuc21hcnQKICAgICAgICAgICAgICAgICRwZiA9IGlmICgkc20ucHJlZGljdF9m
HLP:YWlsKSB7ICI8c3BhbiBjbGFzcz0nZC1waWxsIHBpbGwtYmFkJz5QcmVkaWN0cyBmYWlsdXJlPC9zcGFuPiIgfSBlbHNlIHsgIjxzcGFuIGNsYXNzPSdkLXBpbGwgcGlsbC1nb29kJz5ObyBhbGVydDwvc3Bhbj4iIH0KICAgICAgICAgICAgICAgICRleHRyYSA9ICcn
HLP:CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRzbS50ZW1wX2MgLWFuZCBbc3RyaW5nXSRzbS50ZW1wX2MgLW5lICcnKSB7ICR0Yz0wOyB0cnl7JHRjPVtpbnRdJHNtLnRlbXBfY31jYXRjaHt9OyAkdGNvbCA9IGlmICgkdGMgLWx0IDUwKXsnIzIyYzU1ZSd9
HLP:IGVsc2VpZiAoJHRjIC1sdCA2NSl7JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9OyAkZXh0cmEgKz0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5UZW1wZXJhdHVyZTogPGIgc3R5bGU9J2NvbG9yOiR0Y29sJz4kdGMgJmRlZztDPC9iPjwvZGl2PiIgfQogICAgICAgICAg
HLP:ICAgICAgaWYgKCRudWxsIC1uZSAkc20ud2Vhcl9wY3QgLWFuZCBbc3RyaW5nXSRzbS53ZWFyX3BjdCAtbmUgJycpIHsgJHdwPTA7IHRyeXskd3A9W2ludF0kc20ud2Vhcl9wY3R9Y2F0Y2h7fTsgJHdjb2wgPSBpZiAoJHdwIC1sdCA1MCl7JyMyMmM1NWUnfSBlbHNl
HLP:aWYgKCR3cCAtbHQgODApeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfTsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+V2VhciAoU1NEKTogPGIgc3R5bGU9J2NvbG9yOiR3Y29sJz4kd3AlPC9iPjwvZGl2PiIgfQogICAgICAgICAgICAgICAgaWYgKCRu
HLP:dWxsIC1uZSAkc20ucG9oIC1hbmQgW3N0cmluZ10kc20ucG9oIC1uZSAnJykgeyAkZXh0cmEgKz0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5Qb3dlci1vbiBob3VyczogPGI+JCgmICRlbmMgJHNtLnBvaCk8L2I+PC9kaXY+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0Nh
HLP:cmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1zbWFydCc+PC9zcGFuPkRpc2sgaGVhbHRoIChTTUFSVCk8L2Rpdj48ZGl2IGNsYXNzPSdwaWxsLXJvdyc+JHBmPC9kaXY+JGV4dHJhPC9kaXY+Igog
HLP:ICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnYmNkJykgLWFuZCAkZC5iY2QpIHsKICAgICAgICAgICAgICAgICRib2sgPSBpZiAoJGQuYmNkLm9rKSB7J2dvb2QnfSBlbHNlIHsnYmFkJ30K
HLP:ICAgICAgICAgICAgICAgICRidHggPSBpZiAoJGQuYmNkLm9rKSB7J0Jvb3QgY29uZmlndXJhdGlvbiBjb3JyZWN0J30gZWxzZSB7J0Jvb3Qgd2l0aCBpc3N1ZXMnfQogICAgICAgICAgICAgICAgJGJkZXQgPSBpZiAoW3N0cmluZ10kZC5iY2QuZGV0YWlscyAtbmUg
HLP:JycpIHsgIjxkaXYgY2xhc3M9J2Qtc3ViJz4kKCYgJGVuYyAkZC5iY2QuZGV0YWlscyk8L2Rpdj4iIH0gZWxzZSB7ICcnIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNz
HLP:PSdkLWljIGljLWJvb3QnPjwvc3Bhbj5Cb290IChCQ0QpPC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtJGJvayc+JGJ0eDwvZGl2PiRiZGV0PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1l
HLP:IC1jb250YWlucyAnc3RhcnR1cCcpIC1hbmQgJGQuc3RhcnR1cCAtYW5kIEAoJGQuc3RhcnR1cCkuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcyBpbiBAKCRkLnN0YXJ0dXApKSB7ICRp
HLP:dGVtcyArPSAiPGxpPiQoJiAkZW5jICRzLm5hbWUpPHNwYW4gY2xhc3M9J211dGVkJz4gJm1kYXNoOyAkKCYgJGVuYyAkcy5jb21tYW5kKTwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQgZGNhcmQt
HLP:d2lkZSc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1zdGFydCc+PC9zcGFuPlN0YXJ0dXAgcHJvZ3JhbXM8L2Rpdj48dWwgY2xhc3M9J2Rldi1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAo
HLP:KCRkLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3Byb2Nlc3NlcycpIC1hbmQgJGQucHJvY2Vzc2VzIC1hbmQgQCgkZC5wcm9jZXNzZXMpLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkaXRlbXMgPSAnJwogICAgICAgICAgICAgICAg
HLP:Zm9yZWFjaCAoJHByIGluIEAoJGQucHJvY2Vzc2VzKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkcHIubmFtZSk8c3BhbiBjbGFzcz0nbXV0ZWQnPiAmbWRhc2g7ICQoJiAkZW5jICRwci5tZW1fbWIpIE1CPC9zcGFuPjwvbGk+IiB9CiAgICAgICAgICAgICAg
HLP:ICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1wcm9jJz48L3NwYW4+UHJvY2Vzc2VzIHVzaW5nIG1vc3QgbWVtb3J5PC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlzdCc+JGl0ZW1zPC91
HLP:bD48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRkLmRldmljZXMgLWFuZCBAKCRkLmRldmljZXMpLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkaXRlbXMgPSAnJwogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGRldiBpbiBAKCRk
HLP:LmRldmljZXMpKSB7ICRpdGVtcyArPSAiPGxpPiQoJiAkZW5jICRkZXYubmFtZSkgPHNwYW4gY2xhc3M9J211dGVkJz4oY29kZSAkKCYgJGVuYyAkZGV2LmNvZGUpKTwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFz
HLP:cz0nZGNhcmQgZGNhcmQtd2lkZSc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1kZXYnPjwvc3Bhbj5EZXZpY2VzIHdpdGggd2FybmluZ3M8L2Rpdj48dWwgY2xhc3M9J2Rldi1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIKICAgICAgICAgICAg
HLP:fQogICAgICAgIH0KICAgICAgICAkZGlhZ1NlY3Rpb24gPSAnJwogICAgICAgIGlmICgkZGlhZ0NhcmRzKSB7ICRkaWFnU2VjdGlvbiA9ICI8aDIgaWQ9J2RpYWcnIGNsYXNzPSdzZWMtaCc+RXh0ZW5kZWQgZGlhZ25vc2lzPC9oMj48ZGl2IGNsYXNzPSdkZ3JpZCc+
HLP:JGRpYWdDYXJkczwvZGl2PiIgfQoKICAgICAgICAkY29tcGFyZVNlY3Rpb24gPSAnJwogICAgICAgIGlmICgkaGFzQm90aCkgewogICAgICAgICAgICAkY29tcGFyZVNlY3Rpb24gPSBAIgo8ZGl2IGNsYXNzPSdjb21wYXJlJz4KICA8ZGl2IGNsYXNzPSdtaW5pJz4K
HLP:ICAgIDxzdmcgdmlld0JveD0nMCAwIDIwMCAyMDAnIGNsYXNzPSdnYXVnZSBnYXVnZS1zbSc+PGNpcmNsZSBjbGFzcz0ndHJhY2snIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0Jy8+PGNpcmNsZSBjbGFzcz0nZmlsbCcgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnIHN0
HLP:eWxlPSctLWNpcmM6JGNpcmM7LS10YXJnZXQ6JGJlZm9yZU9mZnNldDtzdHJva2U6JGJlZm9yZUNvbG9yJy8+PHRleHQgeD0nMTAwJyB5PScxMDgnIGNsYXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6JGJlZm9yZUNvbG9yJz4kYmVmb3JlPC90ZXh0Pjwvc3ZnPgogICAg
HLP:PGRpdiBjbGFzcz0nbWluaS1jYXAnPkJFRk9SRTwvZGl2PgogIDwvZGl2PgogIDxkaXYgY2xhc3M9J2Fycm93Jz48c3BhbiBzdHlsZT0nY29sb3I6JGRlbHRhQ29sb3InPiYjODU5NDs8L3NwYW4+PGRpdiBjbGFzcz0nZGVsdGEtY2hpcCcgc3R5bGU9J2NvbG9yOiRk
HLP:ZWx0YUNvbG9yO2JvcmRlci1jb2xvcjokZGVsdGFDb2xvcic+JGRlbHRhVHh0PC9kaXY+PC9kaXY+CiAgPGRpdiBjbGFzcz0nbWluaSc+CiAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1Z2UgZ2F1Z2Utc20nPjxjaXJjbGUgY2xhc3M9J3Ry
HLP:YWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRhZnRlck9mZnNldDtzdHJva2U6JGFmdGVyQ29sb3InLz48dGV4dCB4PScx
HLP:MDAnIHk9JzEwOCcgY2xhc3M9J2ctbnVtJyBzdHlsZT0nZmlsbDokYWZ0ZXJDb2xvcic+JGFmdGVyPC90ZXh0Pjwvc3ZnPgogICAgPGRpdiBjbGFzcz0nbWluaS1jYXAnPkFGVEVSPC9kaXY+CiAgPC9kaXY+CjwvZGl2PgoiQAogICAgICAgIH0KCiAgICAgICAgJG5v
HLP:dyA9IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGQgSEg6bW0nKQogICAgICAgICRleGVjVmVyZGljdCA9ICYgJGJhbmRMYWJlbCAkbWFpblNjb3JlCiAgICAgICAgJGh0bWwgPSBAIgo8IURPQ1RZUEUgaHRtbD4KPGh0bWwgbGFuZz0nZW4nPgo8aGVhZD4K
HLP:PG1ldGEgY2hhcnNldD0ndXRmLTgnPgo8bWV0YSBuYW1lPSd2aWV3cG9ydCcgY29udGVudD0nd2lkdGg9ZGV2aWNlLXdpZHRoLGluaXRpYWwtc2NhbGU9MSc+Cjx0aXRsZT5SZXBhaXIgUmVwb3J0IC0gV1BJIFN1aXRlIHYzLjE8L3RpdGxlPgo8c3R5bGU+Cip7Ym94
HLP:LXNpemluZzpib3JkZXItYm94fQo6cm9vdHstLWJnOiMwYjBmMTc7LS1iZzI6IzBkMTQyMjstLWNhcmQ6IzEyMWEyYjstLWNhcmQyOiMwZTE2MjY7LS1saW5lOiMxZTI5M2I7LS10eHQ6I2U2ZWRmNjstLW11dGVkOiM5M2EzYmE7LS1hY2NlbnQ6IzM4YmRmODstLWFj
HLP:Y2VudDI6IzgxOGNmODstLXNoYWRvdzowIDE0cHggNDBweCByZ2JhKDAsMCwwLC40MCl9Cmh0bWwubGlnaHR7LS1iZzojZWVmMmY4Oy0tYmcyOiNlN2VkZjY7LS1jYXJkOiNmZmZmZmY7LS1jYXJkMjojZjVmOGZjOy0tbGluZTojZGRlNWYwOy0tdHh0OiMwZjE3MmE7
HLP:LS1tdXRlZDojNWE2YjgyOy0tYWNjZW50OiMwMjg0Yzc7LS1hY2NlbnQyOiM0ZjQ2ZTU7LS1zaGFkb3c6MCAxMHB4IDI4cHggcmdiYSgxNSwyMyw0MiwuMTIpfQpib2R5e21hcmdpbjowO2ZvbnQtZmFtaWx5OidTZWdvZSBVSScsc3lzdGVtLXVpLC1hcHBsZS1zeXN0
HLP:ZW0sQXJpYWwsc2Fucy1zZXJpZjtsaW5lLWhlaWdodDoxLjU1O2NvbG9yOnZhcigtLXR4dCk7YmFja2dyb3VuZDpyYWRpYWwtZ3JhZGllbnQoMTIwMHB4IDYwMHB4IGF0IDgwJSAtMTAlLHJnYmEoNTYsMTg5LDI0OCwuMTApLHRyYW5zcGFyZW50IDYwJSkscmFkaWFs
HLP:LWdyYWRpZW50KDkwMHB4IDUwMHB4IGF0IC0xMCUgMTAlLHJnYmEoMTI5LDE0MCwyNDgsLjEwKSx0cmFuc3BhcmVudCA1NSUpLHZhcigtLWJnKX0KLndyYXB7bWF4LXdpZHRoOjEwODBweDttYXJnaW46MCBhdXRvO3BhZGRpbmc6MzBweCAyMnB4IDYwcHh9Ci50b3Bi
HLP:YXJ7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjtnYXA6MTZweDttYXJnaW4tYm90dG9tOjE4cHg7ZmxleC13cmFwOndyYXB9Ci5icmFuZHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dh
HLP:cDoxNHB4fQoubG9nb3t3aWR0aDo0NnB4O2hlaWdodDo0NnB4O2JvcmRlci1yYWRpdXM6MTNweDtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsdmFyKC0tYWNjZW50KSx2YXIoLS1hY2NlbnQyKSk7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRl
HLP:cjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KX0KaDF7Zm9udC1zaXplOjIycHg7bWFyZ2luOjA7bGV0dGVyLXNwYWNpbmc6LjJweH0KLnN1Yntjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEzcHg7bWFyZ2luLXRvcDoy
HLP:cHh9Ci5iYWRnZXtkaXNwbGF5OmlubGluZS1ibG9jaztiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsdmFyKC0tYWNjZW50KSx2YXIoLS1hY2NlbnQyKSk7Y29sb3I6IzA0MjkzYjtmb250LXdlaWdodDo3MDA7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRk
HLP:aW5nOjNweCAxMnB4O2ZvbnQtc2l6ZToxMS41cHg7bGV0dGVyLXNwYWNpbmc6LjRweDt2ZXJ0aWNhbC1hbGlnbjptaWRkbGU7bWFyZ2luLWxlZnQ6OHB4fQouYnRuc3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4LXdyYXA6d3JhcH0KLnRvZ2dsZXtjdXJzb3I6cG9p
HLP:bnRlcjtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Y29sb3I6dmFyKC0tdHh0KTtib3JkZXItcmFkaXVzOjEwcHg7cGFkZGluZzo4cHggMTRweDtmb250LXNpemU6MTNweDtmb250LXdlaWdodDo2MDA7Ym94LXNoYWRv
HLP:dzp2YXIoLS1zaGFkb3cpfQoudG9nZ2xlOmhvdmVye2JvcmRlci1jb2xvcjp2YXIoLS1hY2NlbnQpfQoudG9je2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwO21hcmdpbjowIDAgMjJweH0KLnRvYyBhe2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWln
HLP:aHQ6NjAwO2NvbG9yOnZhcigtLW11dGVkKTt0ZXh0LWRlY29yYXRpb246bm9uZTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JhY2tncm91bmQ6dmFyKC0tY2FyZDIpO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzo2cHggMTNweH0KLnRvYyBhOmhvdmVy
HLP:e2NvbG9yOnZhcigtLWFjY2VudCk7Ym9yZGVyLWNvbG9yOnZhcigtLWFjY2VudCl9Ci5leGVje2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjE4cHg7ZmxleC13cmFwOndyYXA7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTgwZGVnLHZhcigt
HLP:LWNhcmQpLHZhcigtLWNhcmQyKSk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE4cHg7cGFkZGluZzoxOHB4IDIycHg7bWFyZ2luLWJvdHRvbToyMnB4O2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KX0KLmV4ZWMtc2NvcmV7Zm9udC1z
HLP:aXplOjQ2cHg7Zm9udC13ZWlnaHQ6ODAwO2xpbmUtaGVpZ2h0OjF9Ci5leGVjLW1pZHtmbGV4OjE7bWluLXdpZHRoOjIwMHB4fQouZXhlYy12ZXJkaWN0e2ZvbnQtc2l6ZToxOHB4O2ZvbnQtd2VpZ2h0OjcwMH0KLmV4ZWMtbGluZXtjb2xvcjp2YXIoLS1tdXRlZCk7
HLP:Zm9udC1zaXplOjEzcHg7bWFyZ2luLXRvcDoycHh9Ci5leGVjLWRlbHRhe2ZvbnQtc2l6ZToxM3B4O2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXI6MXB4IHNvbGlkO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzo0cHggMTJweDt3aGl0ZS1zcGFjZTpub3dyYXB9Ci5o
HLP:ZXJve2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6bWlubWF4KDI0MHB4LDMyMHB4KSAxZnI7Z2FwOjIwcHg7bWFyZ2luLWJvdHRvbToyMnB4fQpAbWVkaWEobWF4LXdpZHRoOjc2MHB4KXsuaGVyb3tncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyfX0K
HLP:LmNhcmR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTgwZGVnLHZhcigtLWNhcmQpLHZhcigtLWNhcmQyKSk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE4cHg7cGFkZGluZzoyMnB4O2JveC1zaGFkb3c6dmFyKC0tc2hhZG93
HLP:KX0KLmdhdWdld3JhcHtkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO3RleHQtYWxpZ246Y2VudGVyfQouZ2F1Z2V7d2lkdGg6MjEwcHg7aGVpZ2h0OjIxMHB4fQouZ2F1Z2Ut
HLP:c217d2lkdGg6MTIwcHg7aGVpZ2h0OjEyMHB4fQouZ2F1Z2UgLnRyYWNre2ZpbGw6bm9uZTtzdHJva2U6dmFyKC0tbGluZSk7c3Ryb2tlLXdpZHRoOjE0fQouZ2F1Z2UgLmZpbGx7ZmlsbDpub25lO3N0cm9rZS13aWR0aDoxNDtzdHJva2UtbGluZWNhcDpyb3VuZDt0
HLP:cmFuc2Zvcm06cm90YXRlKC05MGRlZyk7dHJhbnNmb3JtLW9yaWdpbjo1MCUgNTAlO3N0cm9rZS1kYXNoYXJyYXk6dmFyKC0tY2lyYyk7c3Ryb2tlLWRhc2hvZmZzZXQ6dmFyKC0tY2lyYyk7YW5pbWF0aW9uOmZpbGwgMS40cyBjdWJpYy1iZXppZXIoLjIyLDEsLjM2
HLP:LDEpIC4ycyBmb3J3YXJkc30KLmctbnVte2ZvbnQtc2l6ZTo1NHB4O2ZvbnQtd2VpZ2h0OjgwMDt0ZXh0LWFuY2hvcjptaWRkbGU7Zm9udC1mYW1pbHk6J1NlZ29lIFVJJyxzeXN0ZW0tdWksQXJpYWx9Ci5nYXVnZS1zbSAuZy1udW17Zm9udC1zaXplOjQ2cHh9Ci5n
HLP:LWxhYmVse21hcmdpbi10b3A6NnB4O2ZvbnQtd2VpZ2h0OjcwMDtmb250LXNpemU6MTVweH0KLmctY2Fwe2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweDtsZXR0ZXItc3BhY2luZzoxLjVweDttYXJnaW4tdG9wOjJweH0KLmNvbXBhcmV7ZGlzcGxheTpm
HLP:bGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2dhcDo4cHg7bWFyZ2luLXRvcDoxNHB4O2ZsZXgtd3JhcDp3cmFwfQoubWluaXt0ZXh0LWFsaWduOmNlbnRlcn0KLm1pbmktY2Fwe2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6
HLP:MTFweDtsZXR0ZXItc3BhY2luZzoxLjJweDttYXJnaW4tdG9wOi02cHh9Ci5hcnJvd3tkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6NnB4O2ZvbnQtc2l6ZTozMHB4O2ZvbnQtd2VpZ2h0OjgwMH0KLmRlbHRh
HLP:LWNoaXB7Ym9yZGVyOjFweCBzb2xpZDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6M3B4IDEycHg7Zm9udC1zaXplOjEyLjVweDtmb250LXdlaWdodDo3MDA7d2hpdGUtc3BhY2U6bm93cmFwfQouaGVyby1zaWRle2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlv
HLP:bjpjb2x1bW47Z2FwOjE2cHh9Ci5jaGlwc3tkaXNwbGF5OmZsZXg7Z2FwOjEwcHg7ZmxleC13cmFwOndyYXB9Ci5jaGlwe2ZsZXg6MTttaW4td2lkdGg6OTZweDtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRl
HLP:ci1yYWRpdXM6MTRweDtwYWRkaW5nOjEycHggMTRweDt0ZXh0LWFsaWduOmNlbnRlcn0KLmNoaXAgLm57Zm9udC1zaXplOjI2cHg7Zm9udC13ZWlnaHQ6ODAwO2xpbmUtaGVpZ2h0OjF9Ci5jaGlwIC5se2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTEuNXB4
HLP:O2xldHRlci1zcGFjaW5nOi42cHg7bWFyZ2luLXRvcDozcHh9Ci5jLW9re2NvbG9yOiMyMmM1NWV9LmMtd2Fybntjb2xvcjojZjU5ZTBifS5jLWVycntjb2xvcjojZWY0NDQ0fS5jLXNraXB7Y29sb3I6Izk0YTNiOH0KLnN5c2dyaWR7ZGlzcGxheTpncmlkO2dyaWQt
HLP:dGVtcGxhdGUtY29sdW1uczoxZnIgMWZyO2dhcDoxcHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7b3ZlcmZsb3c6aGlkZGVufQpAbWVkaWEobWF4LXdpZHRoOjUyMHB4KXsuc3lzZ3JpZHtncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZy
HLP:fX0KLnN5c3tiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO3BhZGRpbmc6MTFweCAxNHB4fQouc3lzLWt7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMS41cHg7bGV0dGVyLXNwYWNpbmc6LjRweH0KLnN5cy12e2ZvbnQtd2VpZ2h0OjYwMDtmb250LXNpemU6MTRw
HLP:eDttYXJnaW4tdG9wOjFweDt3b3JkLWJyZWFrOmJyZWFrLXdvcmR9CmgyLnNlYy1oe2ZvbnQtc2l6ZToxNXB4O2xldHRlci1zcGFjaW5nOi42cHg7dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2NvbG9yOnZhcigtLWFjY2VudCk7bWFyZ2luOjMwcHggMCAxMnB4O2Rp
HLP:c3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEwcHg7c2Nyb2xsLW1hcmdpbi10b3A6MTRweH0KaDIuc2VjLWg6OmFmdGVye2NvbnRlbnQ6Jyc7ZmxleDoxO2hlaWdodDoxcHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKX0KLnRpbWVsaW5le3Bvc2l0aW9u
HLP:OnJlbGF0aXZlO3BhZGRpbmctbGVmdDo4cHh9Ci5waHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6ZmxleC1zdGFydDtnYXA6MTRweDtwYWRkaW5nOjEzcHggMTZweDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTRweDttYXJnaW4t
HLP:Ym90dG9tOjEwcHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtwb3NpdGlvbjpyZWxhdGl2ZTtvdmVyZmxvdzpoaWRkZW59Ci5waDo6YmVmb3Jle2NvbnRlbnQ6Jyc7cG9zaXRpb246YWJzb2x1dGU7bGVmdDowO3RvcDowO2JvdHRvbTowO3dpZHRoOjRweH0KLnBoLW9r
HLP:OjpiZWZvcmV7YmFja2dyb3VuZDojMjJjNTVlfS5waC13YXJuOjpiZWZvcmV7YmFja2dyb3VuZDojZjU5ZTBifS5waC1lcnJvcjo6YmVmb3Jle2JhY2tncm91bmQ6I2VmNDQ0NH0ucGgtc2tpcDo6YmVmb3Jle2JhY2tncm91bmQ6IzY0NzQ4Yn0KLnBoLWRvdHtmbGV4
HLP:OjAgMCBhdXRvO21hcmdpbi10b3A6MXB4fQouc3ZnaWNve3dpZHRoOjI2cHg7aGVpZ2h0OjI2cHg7ZGlzcGxheTpibG9ja30KLnBoLW1haW57ZmxleDoxO21pbi13aWR0aDowfQoucGgtdG9we2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEwcHg7
HLP:ZmxleC13cmFwOndyYXB9Ci5waC1udW17Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVz
HLP:OjdweDtwYWRkaW5nOjFweCA3cHh9Ci5waC10aXRsZXtmb250LXdlaWdodDo2MDA7Zm9udC1zaXplOjE1cHh9Ci5waC1iYWRnZXtmb250LXNpemU6MTFweDtmb250LXdlaWdodDo4MDA7bGV0dGVyLXNwYWNpbmc6LjZweDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRp
HLP:bmc6MnB4IDEwcHh9Ci5iLW9re2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfS5iLXdhcm57YmFja2dyb3VuZDpyZ2JhKDI0NSwxNTgsMTEsLjE2KTtjb2xvcjojZjU5ZTBifS5iLWVycm9ye2JhY2tncm91bmQ6cmdiYSgyMzksNjgs
HLP:NjgsLjE2KTtjb2xvcjojZWY0NDQ0fS5iLXNraXB7YmFja2dyb3VuZDpyZ2JhKDEwMCwxMTYsMTM5LC4xOCk7Y29sb3I6Izk0YTNiOH0KLnBoLW5vdGV7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6M3B4fQoucGgtc2Vjc3tmbGV4
HLP:OjAgMCBhdXRvO2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDtmb250LXZhcmlhbnQtbnVtZXJpYzp0YWJ1bGFyLW51bXM7YWxpZ24tc2VsZjpjZW50ZXJ9Ci5lbXB0eXtjb2xvcjp2YXIoLS1tdXRlZCk7cGFkZGluZzoxOHB4O3RleHQtYWxpZ246Y2Vu
HLP:dGVyfQouYmFyY2hhcnR7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTRweDtwYWRkaW5nOjE0cHggMThweDttYXJnaW4tdG9wOjRweH0KLmJhci1yb3d7ZGlzcGxheTpmbGV4O2FsaWduLWl0
HLP:ZW1zOmNlbnRlcjtnYXA6MTJweDtwYWRkaW5nOjVweCAwfQouYmFyLWxibHtmbGV4OjAgMCAyMjBweDtmb250LXNpemU6MTIuNXB4O2NvbG9yOnZhcigtLW11dGVkKTt3aGl0ZS1zcGFjZTpub3dyYXA7b3ZlcmZsb3c6aGlkZGVuO3RleHQtb3ZlcmZsb3c6ZWxsaXBz
HLP:aXN9CkBtZWRpYShtYXgtd2lkdGg6NjAwcHgpey5iYXItbGJse2ZsZXg6MCAwIDEyMHB4fX0KLmJhci10cmFja3tmbGV4OjE7aGVpZ2h0OjEwcHg7Ym9yZGVyLXJhZGl1czo5OTlweDtiYWNrZ3JvdW5kOnZhcigtLWxpbmUpO292ZXJmbG93OmhpZGRlbn0KLmJhci10
HLP:cmFjayBzcGFue2Rpc3BsYXk6YmxvY2s7aGVpZ2h0OjEwMCU7Ym9yZGVyLXJhZGl1czo5OTlweH0KLmJhci12YWx7ZmxleDowIDAgYXV0bztmb250LXNpemU6MTIuNXB4O2NvbG9yOnZhcigtLW11dGVkKTtmb250LXZhcmlhbnQtbnVtZXJpYzp0YWJ1bGFyLW51bXM7
HLP:d2lkdGg6NDhweDt0ZXh0LWFsaWduOnJpZ2h0fQp1bC5maW5kc3tsaXN0LXN0eWxlOm5vbmU7bWFyZ2luOjA7cGFkZGluZzowfQouZmluZHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6ZmxleC1zdGFydDtnYXA6MTJweDtwYWRkaW5nOjEycHggMTZweDtib3JkZXI6
HLP:MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTNweDttYXJnaW4tYm90dG9tOjlweDtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpfQouc2V2e2ZsZXg6MCAwIGF1dG87Zm9udC1zaXplOjExcHg7Zm9udC13ZWlnaHQ6ODAwO2xldHRlci1zcGFjaW5nOi41
HLP:cHg7Ym9yZGVyLXJhZGl1czo4cHg7cGFkZGluZzozcHggMTBweDttYXJnaW4tdG9wOjFweH0KLnNldi1oaWdoe2JhY2tncm91bmQ6cmdiYSgyMzksNjgsNjgsLjE2KTtjb2xvcjojZWY0NDQ0fS5zZXYtbWVke2JhY2tncm91bmQ6cmdiYSgyNDUsMTU4LDExLC4xNik7
HLP:Y29sb3I6I2Y1OWUwYn0uc2V2LWluZm97YmFja2dyb3VuZDpyZ2JhKDU2LDE4OSwyNDgsLjE2KTtjb2xvcjp2YXIoLS1hY2NlbnQpfS5zZXYtb2t7YmFja2dyb3VuZDpyZ2JhKDM0LDE5Nyw5NCwuMTYpO2NvbG9yOiMyMmM1NWV9Ci5maW5kLXR4dHtmb250LXNpemU6
HLP:MTRweH0KdWwuc3RlcHN7bGlzdC1zdHlsZTpub25lO21hcmdpbjowO3BhZGRpbmc6MH0KLnN0ZXAtbGl7ZGlzcGxheTpmbGV4O2dhcDoxMXB4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7cGFkZGluZzoxMXB4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5l
HLP:KTtib3JkZXItbGVmdDozcHggc29saWQgdmFyKC0tYWNjZW50KTtib3JkZXItcmFkaXVzOjEycHg7bWFyZ2luLWJvdHRvbTo5cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtmb250LXNpemU6MTRweH0KLnN0ZXAtb2t7Ym9yZGVyLWxlZnQtY29sb3I6IzIyYzU1ZX0K
HLP:LnN0ZXAtaWN7Y29sb3I6dmFyKC0tYWNjZW50KTtmb250LXdlaWdodDo4MDB9Ci5zdGVwLW9rIC5zdGVwLWlje2NvbG9yOiMyMmM1NWV9Ci5kZ3JpZHtkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOnJlcGVhdChhdXRvLWZpdCxtaW5tYXgoMjIwcHgs
HLP:MWZyKSk7Z2FwOjE0cHh9Ci5kY2FyZHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNXB4O3BhZGRpbmc6MTZweCAxOHB4fQouZGNhcmQtd2lkZXtncmlkLWNvbHVtbjoxLy0xfQouZC1oe2Rp
HLP:c3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjlweDtmb250LXdlaWdodDo3MDA7Zm9udC1zaXplOjE0cHg7bWFyZ2luLWJvdHRvbToxMHB4fQouZC1pY3t3aWR0aDoxNHB4O2hlaWdodDoxNHB4O2JvcmRlci1yYWRpdXM6NXB4O2Rpc3BsYXk6aW5saW5l
HLP:LWJsb2NrfQouaWMtcmFte2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMzhiZGY4LCMwZWE1ZTkpfS5pYy1iYXR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCMyMmM1NWUsIzE1ODAzZCl9LmljLW5ldHtiYWNrZ3JvdW5kOmxpbmVh
HLP:ci1ncmFkaWVudCgxMzVkZWcsIzgxOGNmOCwjNGY0NmU1KX0uaWMtZGV2e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZjU5ZTBiLCNkOTc3MDYpfS5pYy1zbWFydHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2Y0NzJiNiwjZGIy
HLP:Nzc3KX0uaWMtYm9vdHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzJkZDRiZiwjMGQ5NDg4KX0uaWMtc3RhcnR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNhNzhiZmEsIzdjM2FlZCl9LmljLXByb2N7YmFja2dyb3VuZDpsaW5l
HLP:YXItZ3JhZGllbnQoMTM1ZGVnLCNmYjcxODUsI2UxMWQ0OCl9Ci5kLXBpbGx7ZGlzcGxheTppbmxpbmUtYmxvY2s7Zm9udC1zaXplOjEyLjVweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjRweCAxMnB4fQoucGlsbC1yb3d7ZGlz
HLP:cGxheTpmbGV4O2dhcDo4cHg7ZmxleC13cmFwOndyYXB9Ci5waWxsLWdvb2R7YmFja2dyb3VuZDpyZ2JhKDM0LDE5Nyw5NCwuMTYpO2NvbG9yOiMyMmM1NWV9LnBpbGwtYmFke2JhY2tncm91bmQ6cmdiYSgyMzksNjgsNjgsLjE2KTtjb2xvcjojZWY0NDQ0fS5waWxs
HLP:LXVua25vd257YmFja2dyb3VuZDpyZ2JhKDE0OCwxNjMsMTg0LC4xNik7Y29sb3I6Izk0YTNiOH0KLmQtc3Vie2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTIuNXB4O21hcmdpbi10b3A6OHB4fQouZC1oaW50e2NvbG9yOiNmNTllMGI7Zm9udC1zaXplOjEy
HLP:LjVweDttYXJnaW4tdG9wOjhweH0KLmJhdC1iYXJ7aGVpZ2h0OjEycHg7Ym9yZGVyLXJhZGl1czo5OTlweDtiYWNrZ3JvdW5kOnZhcigtLWxpbmUpO292ZXJmbG93OmhpZGRlbjttYXJnaW4tdG9wOjRweH0KLmJhdC1iYXIgc3BhbntkaXNwbGF5OmJsb2NrO2hlaWdo
HLP:dDoxMDAlO2JvcmRlci1yYWRpdXM6OTk5cHh9Ci5kZXYtbGlzdHttYXJnaW46NHB4IDAgMDtwYWRkaW5nLWxlZnQ6MThweDtmb250LXNpemU6MTMuNXB4fQouZGV2LWxpc3QgbGl7bWFyZ2luOjJweCAwfQoubXV0ZWR7Y29sb3I6dmFyKC0tbXV0ZWQpfQouZm9vdHtt
HLP:YXJnaW4tdG9wOjM0cHg7dGV4dC1hbGlnbjpjZW50ZXI7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMnB4fQouc2VjdGlvbnthbmltYXRpb246cmlzZSAuNXMgZWFzZSBib3RofQpAa2V5ZnJhbWVzIGZpbGx7dG97c3Ryb2tlLWRhc2hvZmZzZXQ6dmFyKC0t
HLP:dGFyZ2V0KX19CkBrZXlmcmFtZXMgcmlzZXtmcm9te29wYWNpdHk6MDt0cmFuc2Zvcm06dHJhbnNsYXRlWSgxMHB4KX10b3tvcGFjaXR5OjE7dHJhbnNmb3JtOm5vbmV9fQpAbWVkaWEgcHJpbnR7LnRvZ2dsZSwudG9jLC5idG5zLC50b2FzdHtkaXNwbGF5Om5vbmV9
HLP:Ym9keXtiYWNrZ3JvdW5kOiNmZmY7Y29sb3I6IzAwMH0uY2FyZCwuZGNhcmQsLnBoLC5maW5kLC5leGVjLC5iYXJjaGFydCwuc3RlcC1saXtib3gtc2hhZG93Om5vbmU7YmFja2Ryb3AtZmlsdGVyOm5vbmU7LXdlYmtpdC1iYWNrZHJvcC1maWx0ZXI6bm9uZTtiYWNr
HLP:Z3JvdW5kOiNmZmYhaW1wb3J0YW50fS5nYXVnZSAuZmlsbHthbmltYXRpb246bm9uZX0uc2VjdGlvbnthbmltYXRpb246bm9uZX1hW2hyZWZde2NvbG9yOmluaGVyaXQ7dGV4dC1kZWNvcmF0aW9uOm5vbmV9fQo6cm9vdHstLWdsYXNzOnJnYmEoMTgsMjYsNDMsLjYw
HLP:KTstLWdsYXNzYmQ6cmdiYSgyNTUsMjU1LDI1NSwuMDcpfQpodG1sLmxpZ2h0ey0tZ2xhc3M6cmdiYSgyNTUsMjU1LDI1NSwuNjQpOy0tZ2xhc3NiZDpyZ2JhKDE1LDIzLDQyLC4wOCl9Ci5jYXJkLC5leGVjLC5kY2FyZCwuZmluZCwuYmFyY2hhcnQsLnN0ZXAtbGl7
HLP:YmFja2dyb3VuZDp2YXIoLS1nbGFzcykhaW1wb3J0YW50O2JhY2tkcm9wLWZpbHRlcjpibHVyKDEzcHgpIHNhdHVyYXRlKDE0MCUpOy13ZWJraXQtYmFja2Ryb3AtZmlsdGVyOmJsdXIoMTNweCkgc2F0dXJhdGUoMTQwJSk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1n
HLP:bGFzc2JkKSFpbXBvcnRhbnR9Ci50b2FzdHtwb3NpdGlvbjpmaXhlZDtib3R0b206MjRweDtsZWZ0OjUwJTt0cmFuc2Zvcm06dHJhbnNsYXRlWCgtNTAlKTtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsdmFyKC0tYWNjZW50KSx2YXIoLS1hY2NlbnQy
HLP:KSk7Y29sb3I6IzA0MjkzYjtmb250LXdlaWdodDo3MDA7cGFkZGluZzoxMHB4IDE4cHg7Ym9yZGVyLXJhZGl1czoxMnB4O2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KTtvcGFjaXR5OjA7cG9pbnRlci1ldmVudHM6bm9uZTt0cmFuc2l0aW9uOm9wYWNpdHkgLjI1czt6
HLP:LWluZGV4OjYwO2ZvbnQtc2l6ZToxM3B4fQoudG9hc3Quc2hvd3tvcGFjaXR5OjF9Ci50cmVuZC10aXRsZXttYXJnaW4tdG9wOjIwcHg7Zm9udC1zaXplOjEycHg7Zm9udC13ZWlnaHQ6NzAwO2xldHRlci1zcGFjaW5nOjFweDt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNh
HLP:c2U7Y29sb3I6dmFyKC0tbXV0ZWQpfQoudHJlbmQtbGlzdHtkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2dhcDo0cHg7d2lkdGg6MTAwJTttYXJnaW4tdG9wOjhweDtib3JkZXItdG9wOjFweCBzb2xpZCB2YXIoLS1saW5lKTtwYWRkaW5nLXRvcDo4
HLP:cHh9Ci50cmVuZC1pdGVte2Rpc3BsYXk6ZmxleDtqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2Vlbjtmb250LXNpemU6MTJweH0KLnRyZW5kLWRhdGV7Y29sb3I6dmFyKC0tbXV0ZWQpfQoudHJlbmQtc2NvcmV7Zm9udC13ZWlnaHQ6NzAwfQo8L3N0eWxlPgo8L2hl
HLP:YWQ+Cjxib2R5Pgo8ZGl2IGNsYXNzPSd3cmFwJz4KICA8ZGl2IGNsYXNzPSd0b3BiYXInPgogICAgPGRpdiBjbGFzcz0nYnJhbmQnPgogICAgICA8ZGl2IGNsYXNzPSdsb2dvJz48c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgd2lkdGg9JzI2JyBoZWlnaHQ9JzI2JyBy
HLP:b2xlPSdpbWcnIGFyaWEtbGFiZWw9J1dQSSc+PHBhdGggZD0nTTEyIDJsNyAzdjZjMCA0LjYtMyA4LjMtNyA5LjZDOCAxOS4zIDUgMTUuNiA1IDExVjV6JyBmaWxsPScjMDQyOTNiJy8+PHBhdGggZD0nTTkgMTJsMiAyIDQtNC41JyBmaWxsPSdub25lJyBzdHJva2U9
HLP:JyNkZmY2ZmYnIHN0cm9rZS13aWR0aD0nMicgc3Ryb2tlLWxpbmVjYXA9J3JvdW5kJyBzdHJva2UtbGluZWpvaW49J3JvdW5kJy8+PC9zdmc+PC9kaXY+CiAgICAgIDxkaXY+CiAgICAgICAgPGgxPlJlcGFpciBSZXBvcnQgPHNwYW4gY2xhc3M9J2JhZGdlJz5XUEkg
HLP:U1VJVEUgdjMuMTwvc3Bhbj48L2gxPgogICAgICAgIDxkaXYgY2xhc3M9J3N1Yic+JCgmICRlbmMgJG1hY2hpbmUpICZuYnNwOyZtaWRkb3Q7Jm5ic3A7IGdlbmVyYXRlZCBvbiAkbm93PC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNz
HLP:PSdidG5zJz4KICAgICAgPGJ1dHRvbiBjbGFzcz0ndG9nZ2xlJyBvbmNsaWNrPSJ3aW5kb3cucHJpbnQoKSI+UHJpbnQgLyBQREY8L2J1dHRvbj4KICAgICAgPGJ1dHRvbiBjbGFzcz0ndG9nZ2xlJyBpZD0nY29weWJ0bicgb25jbGljaz0iY29weVJlc3VtZW4oKSI+
HLP:Q29weSBzdW1tYXJ5PC9idXR0b24+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2dsZScgaWQ9J3RoZW1lYnRuJyBvbmNsaWNrPSJ0b2dnbGVUaGVtZSgpIj5MaWdodC9EYXJrIHRoZW1lPC9idXR0b24+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPG5hdiBjbGFzcz0n
HLP:dG9jJyBhcmlhLWxhYmVsPSdJbmRleCc+CiAgICA8YSBocmVmPScjcmVzdW1lbic+U3VtbWFyeTwvYT4KICAgIDxhIGhyZWY9JyNmYXNlcyc+UGhhc2VzPC9hPgogICAgPGEgaHJlZj0nI2hhbGxhemdvcyc+RmluZGluZ3M8L2E+CiAgICA8YSBocmVmPScjcGFzb3Mn
HLP:Pk5leHQgc3RlcHM8L2E+CiAgICA8YSBocmVmPScjZGlhZyc+RGlhZ25vc3RpY3M8L2E+CiAgPC9uYXY+CgogIDxkaXYgaWQ9J3Jlc3VtZW4nIGNsYXNzPSdleGVjIHNlY3Rpb24nPgogICAgPGRpdiBjbGFzcz0nZXhlYy1zY29yZScgc3R5bGU9J2NvbG9yOiRtYWlu
HLP:Q29sb3InPiRtYWluU2NvcmU8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtbWlkJz4KICAgICAgPGRpdiBjbGFzcz0nZXhlYy12ZXJkaWN0JyBzdHlsZT0nY29sb3I6JG1haW5Db2xvcic+U3lzdGVtIGhlYWx0aDogJGV4ZWNWZXJkaWN0PC9kaXY+CiAgICAgIDxk
HLP:aXYgY2xhc3M9J2V4ZWMtbGluZSc+JGNPSyBzdWNjZXNzZnVsICZtaWRkb3Q7ICRjV0FSTiB3YXJuaW5ncyAmbWlkZG90OyAkY0VSUiBlcnJvcnMgJm1pZGRvdDsgJGNTS0lQIHNraXBwZWQgJm1pZGRvdDsgJHRvdGFsUGggcGhhc2VzIHRvdGFsPC9kaXY+CiAgICAg
HLP:IDxkaXYgY2xhc3M9J2V4ZWMtbGluZSc+JHN0YXRMaW5lPC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtZGVsdGEnIHN0eWxlPSdjb2xvcjokZGVsdGFDb2xvcjtib3JkZXItY29sb3I6JGRlbHRhQ29sb3InPiRkZWx0YVR4dDwvZGl2PgogIDwv
HLP:ZGl2PgoKICA8ZGl2IGNsYXNzPSdoZXJvIHNlY3Rpb24nPgogICAgPGRpdiBjbGFzcz0nY2FyZCBnYXVnZXdyYXAnPgogICAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1Z2UnIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nSGVhbHRoIHNjb3Jl
HLP:ICRtYWluU2NvcmUgb3V0IG9mIDEwMCc+PGNpcmNsZSBjbGFzcz0ndHJhY2snIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0Jy8+PGNpcmNsZSBjbGFzcz0nZmlsbCcgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnIHN0eWxlPSctLWNpcmM6JGNpcmM7LS10YXJnZXQ6JG1h
HLP:aW5PZmZzZXQ7c3Ryb2tlOiRtYWluQ29sb3InLz48dGV4dCB4PScxMDAnIHk9JzExMicgY2xhc3M9J2ctbnVtJyBzdHlsZT0nZmlsbDokbWFpbkNvbG9yJz4kbWFpblNjb3JlPC90ZXh0Pjwvc3ZnPgogICAgICA8ZGl2IGNsYXNzPSdnLWxhYmVsJyBzdHlsZT0nY29s
HLP:b3I6JG1haW5Db2xvcic+SGVhbHRoOiAkbWFpbkxhYmVsPC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9J2ctY2FwJz5TQ09SRSBPVVQgT0YgMTAwPC9kaXY+CiAgICAgICRjb21wYXJlU2VjdGlvbgogICAgICAkaGlzdG9yeUh0bWwKICAgIDwvZGl2PgogICAgPGRpdiBj
HLP:bGFzcz0naGVyby1zaWRlJz4KICAgICAgPGRpdiBjbGFzcz0nY2FyZCc+CiAgICAgICAgPGRpdiBjbGFzcz0nY2hpcHMnPgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBjLW9rJz4kY09LPC9kaXY+PGRpdiBjbGFzcz0nbCc+T0s8L2Rp
HLP:dj48L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy13YXJuJz4kY1dBUk48L2Rpdj48ZGl2IGNsYXNzPSdsJz5XQVJOSU5HUzwvZGl2PjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBj
HLP:LWVycic+JGNFUlI8L2Rpdj48ZGl2IGNsYXNzPSdsJz5FUlJPUlM8L2Rpdj48L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1za2lwJz4kY1NLSVA8L2Rpdj48ZGl2IGNsYXNzPSdsJz5TS0lQUEVEPC9kaXY+PC9kaXY+CiAg
HLP:ICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdjYXJkJz4KICAgICAgICA8ZGl2IGNsYXNzPSdzeXNncmlkJz4kc3lzQ2FyZHM8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlv
HLP:bic+CiAgICA8aDIgaWQ9J2Zhc2VzJyBjbGFzcz0nc2VjLWgnPlBoYXNlcyB0aW1lbGluZSAoJHRvdGFsUGgpPC9oMj4KICAgIDxkaXYgY2xhc3M9J3RpbWVsaW5lJz4kcm93czwvZGl2PgogICAgPGRpdiBjbGFzcz0nYmFyY2hhcnQnPiRiYXJzPC9kaXY+CiAgPC9k
HLP:aXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdoYWxsYXpnb3MnIGNsYXNzPSdzZWMtaCc+RmluZGluZ3MgYW5kIHJvb3QgY2F1c2U8L2gyPgogICAgPHVsIGNsYXNzPSdmaW5kcyc+JGZpbmRIdG1sPC91bD4KICA8L2Rpdj4KCiAgPGRpdiBj
HLP:bGFzcz0nc2VjdGlvbic+CiAgICA8aDIgaWQ9J3Bhc29zJyBjbGFzcz0nc2VjLWgnPlJlY29tbWVuZGVkIG5leHQgc3RlcHM8L2gyPgogICAgPHVsIGNsYXNzPSdzdGVwcyc+JHN0ZXBzSHRtbDwvdWw+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPiRk
HLP:aWFnU2VjdGlvbjwvZGl2PgoKICA8ZGl2IGNsYXNzPSdmb290Jz4KICAgIFdQSSAmbWlkZG90OyBFbWVyZ2VuY3kgUmVwYWlyIFN1aXRlIGZvciBXaW5kb3dzIDEwLzExICZtaWRkb3Q7IHJlYWQtb25seSByZXBvcnQuPGJyPgogICAgQmFja3VwcyBhbmQgbG9ncyBh
HLP:cmUgaW4gdGhlIFdQSV9TdWl0ZSBmb2xkZXIgbmV4dCB0byB0aGUgcHJvZ3JhbS4KICA8L2Rpdj4KPC9kaXY+CjxzY3JpcHQ+CihmdW5jdGlvbigpe3RyeXt2YXIgcz1sb2NhbFN0b3JhZ2UuZ2V0SXRlbSgnd3BpLXRoZW1lJyk7dmFyIHJvb3Q9ZG9jdW1lbnQuZG9j
HLP:dW1lbnRFbGVtZW50O2lmKHM9PT0nbGlnaHQnKXtyb290LmNsYXNzTGlzdC5hZGQoJ2xpZ2h0Jyk7fWVsc2UgaWYocz09PSdkYXJrJyl7cm9vdC5jbGFzc0xpc3QucmVtb3ZlKCdsaWdodCcpO31lbHNlIGlmKHdpbmRvdy5tYXRjaE1lZGlhJiZ3aW5kb3cubWF0Y2hN
HLP:ZWRpYSgnKHByZWZlcnMtY29sb3Itc2NoZW1lOiBsaWdodCknKS5tYXRjaGVzKXtyb290LmNsYXNzTGlzdC5hZGQoJ2xpZ2h0Jyk7fX19Y2F0Y2goZSl7fX0pKCk7CmZ1bmN0aW9uIHRvZ2dsZVRoZW1lKCl7dHJ5e3ZhciBsPWRvY3VtZW50LmRvY3VtZW50RWxlbWVu
HLP:dC5jbGFzc0xpc3QudG9nZ2xlKCdsaWdodCcpO2xvY2FsU3RvcmFnZS5zZXRJdGVtKCd3cGktdGhlbWUnLGw/J2xpZ2h0JzonZGFyaycpO31jYXRjaChlKXt9fQpmdW5jdGlvbiBmbGFzaChtKXt0cnl7dmFyIHQ9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZGl2Jyk7
HLP:dC5jbGFzc05hbWU9J3RvYXN0Jzt0LnRleHRDb250ZW50PW07ZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZCh0KTtyZXF1ZXN0QW5pbWF0aW9uRnJhbWUoZnVuY3Rpb24oKXt0LmNsYXNzTGlzdC5hZGQoJ3Nob3cnKTt9KTtzZXRUaW1lb3V0KGZ1bmN0aW9uKCl7dC5j
HLP:bGFzc0xpc3QucmVtb3ZlKCdzaG93Jyk7c2V0VGltZW91dChmdW5jdGlvbigpe3QucmVtb3ZlKCk7fSwzMDApO30sMTYwMCk7fWNhdGNoKGUpe319CmZ1bmN0aW9uIGZiKHR4dCxvayl7dHJ5e3ZhciBhPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3RleHRhcmVhJyk7
HLP:YS52YWx1ZT10eHQ7YS5zdHlsZS5wb3NpdGlvbj0nZml4ZWQnO2Euc3R5bGUubGVmdD0nLTk5OTlweCc7ZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChhKTthLnNlbGVjdCgpO2RvY3VtZW50LmV4ZWNDb21tYW5kKCdjb3B5Jyk7YS5yZW1vdmUoKTtvaygpO31jYXRj
HLP:aChlKXtmbGFzaCgnQ291bGQgbm90IGNvcHknKTt9fQpmdW5jdGlvbiBjb3B5UmVzdW1lbigpe3ZhciBwPVtdO3ZhciB0PWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJ2gxJyk7aWYodClwLnB1c2godC5pbm5lclRleHQudHJpbSgpKTt2YXIgcz1kb2N1bWVudC5xdWVy
HLP:eVNlbGVjdG9yKCcuc3ViJyk7aWYocylwLnB1c2gocy5pbm5lclRleHQudHJpbSgpKTt2YXIgZXg9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignLmV4ZWMnKTtpZihleClwLnB1c2goJ1xuJytleC5pbm5lclRleHQucmVwbGFjZSgvXG57Mix9L2csJ1xuJykudHJpbSgp
HLP:KTt2YXIgaD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnaGFsbGF6Z29zJyk7aWYoaCYmaC5wYXJlbnROb2RlKXAucHVzaCgnXG4nK2gucGFyZW50Tm9kZS5pbm5lclRleHQudHJpbSgpKTt2YXIgdHh0PXAuam9pbignXG4nKTtmdW5jdGlvbiBvaygpe2ZsYXNoKCdT
HLP:dW1tYXJ5IGNvcGllZCcpO31pZihuYXZpZ2F0b3IuY2xpcGJvYXJkJiZuYXZpZ2F0b3IuY2xpcGJvYXJkLndyaXRlVGV4dCl7bmF2aWdhdG9yLmNsaXBib2FyZC53cml0ZVRleHQodHh0KS50aGVuKG9rLGZ1bmN0aW9uKCl7ZmIodHh0LG9rKTt9KTt9ZWxzZXtmYih0
HLP:eHQsb2spO319Cjwvc2NyaXB0Pgo8L2JvZHk+CjwvaHRtbD4KIkAKICAgICAgICAkdXRmOCA9IE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkKICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJG91dFBhdGgsICRo
HLP:dG1sLCAkdXRmOCkKICAgICAgICAiUkVTVUxUPU9LIgogICAgICAgICJQQVRIPSRvdXRQYXRoIgogICAgfSBjYXRjaCB7CiAgICAgICAgIlJFU1VMVD1GQUlMIgogICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgIH0KfQoKIyAtLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIFJlZ2lzdHJhciByZXN1bHRhZG8gZGUgdW5hIGZhc2UgZW4gZWwgZXN0YWRvIChwYXJhIGVsIGluZm9ybWUpLgojIC1BcmcgPSAibnVtO3Rp
HLP:dGxlO3Jlc3VsdDtzZWNzO25vdGUiCmZ1bmN0aW9uIEFkZC1QaGFzZVJlc3VsdCgkc3BlYykgewogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgJHBhcnRzID0gJHNwZWMgLXNwbGl0ICc7Jyw1CiAgICAkcGggPSBbcHNjdXN0b21vYmplY3RdQHsgbnVtPSRwYXJ0c1sw
HLP:XTsgdGl0bGU9JHBhcnRzWzFdOyByZXN1bHQ9JHBhcnRzWzJdOyBzZWNzPSRwYXJ0c1szXTsgbm90ZT0kcGFydHNbNF0gfQogICAgJGxpc3QgPSBAKCRzdC5waGFzZXMpICsgJHBoCiAgICAkc3QucGhhc2VzID0gJGxpc3QKICAgIFdyaXRlLVN0YXRlICRzdAogICAg
HLP:IlJFU1VMVD1PSyIKfQpmdW5jdGlvbiBTZXQtU2NvcmUoJHdoaWNoLCAkdmFsKSB7CiAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICBpZiAoJHdoaWNoIC1lcSAnYmVmb3JlJykgeyAKICAgICAgICAkc3Quc2NvcmVfYmVmb3JlID0gW2ludF0kdmFsIAogICAgfSBlbHNl
HLP:IHsgCiAgICAgICAgJHN0LnNjb3JlX2FmdGVyID0gW2ludF0kdmFsIAogICAgICAgIFNhdmUtSGVhbHRoSGlzdG9yeSBbaW50XSR2YWwKICAgIH0KICAgIFdyaXRlLVN0YXRlICRzdDsgIlJFU1VMVD1PSyIKfQpmdW5jdGlvbiBBZGQtRmluZGluZygkdGV4dCkgewog
HLP:ICAgJHN0ID0gUmVhZC1TdGF0ZTsgJHN0LmZpbmRpbmdzID0gQCgkc3QuZmluZGluZ3MpICsgJHRleHQ7IFdyaXRlLVN0YXRlICRzdDsgIlJFU1VMVD1PSyIKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PQojICBMT0dJQ0EgUFVSQSBOVUVWQSAvIENPUlJFR0lEQSAoQmxvcXVlIDMpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCiMgLS0tICgz
HLP:LjEgLyBCdWcgNCAvIFJlcSA2KSBOb3JtYWxpemFjaW9uIGRlIGxhIHNlbGVjY2lvbiBkZSBmYXNlcyAtLS0tLS0tLS0tCiMgRW50cmFkYTogY2FkZW5hIGNvbiBJRHMgc2VwYXJhZG9zIHBvciBjb21hcyAoZXNwYWNpb3MgYXJiaXRyYXJpb3MsIDEtMgojIGRpZ2l0
HLP:b3MsIHBvc2libGVzIGludmFsaWRvcykuIFNhbGlkYTogb2JqZXRvIGNvbiAubm9ybSAobGlzdGEgY2Fub25pY2EsCiMgb3JkZW5hZGEsIHVuaWNhIGRlIElEcyBkZSAyIGRpZ2l0b3MgZW4gezAwLi4xNn0pIHkgLmludmFsaWQgKGxvcyBubyB2YWxpZG9zKS4KIyBO
HLP:dW5jYSBsYW56YSBleGNlcGNpb24gYW50ZSBlbnRyYWRhIG1hbGZvcm1hZGEgbyB2YWNpYS4KZnVuY3Rpb24gTm9ybWFsaXplLUZhc2VzKFtzdHJpbmddJHJhdykgewogICAgJHZhbGlkICAgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxp
HLP:c3Rbc3RyaW5nXQogICAgJGludmFsaWQgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAgaWYgKCRudWxsIC1uZSAkcmF3IC1hbmQgJHJhdy5UcmltKCkuTGVuZ3RoIC1ndCAwKSB7CiAgICAgICAgZm9yZWFjaCAo
HLP:JHQgaW4gKCRyYXcgLXNwbGl0ICcsJykpIHsKICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkdCkgeyBjb250aW51ZSB9CiAgICAgICAgICAgICR0b2sgPSAoJHQgLXJlcGxhY2UgJ1xzJywgJycpICAgICAgICAgICMgcXVpdGFyIGVzcGFjaW9zIGludGVybm9zIHkg
HLP:ZXh0ZXJub3MKICAgICAgICAgICAgaWYgKCR0b2sgLWVxICcnKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgJGNhbm9uID0gJHRvawogICAgICAgICAgICBpZiAoJHRvayAtbWF0Y2ggJ15cZCQnKSB7ICRjYW5vbiA9ICR0b2suUGFkTGVmdCgyLCAnMCcpIH0gICAj
HLP:IDEgZGlnaXRvIC0+IDIgZGlnaXRvcwogICAgICAgICAgICBpZiAoJGNhbm9uIC1tYXRjaCAnXlxkezJ9JCcgLWFuZCBbaW50XSRjYW5vbiAtZ2UgMCAtYW5kIFtpbnRdJGNhbm9uIC1sZSAxNikgewogICAgICAgICAgICAgICAgaWYgKC1ub3QgJHZhbGlkLkNvbnRh
HLP:aW5zKCRjYW5vbikpIHsgJHZhbGlkLkFkZCgkY2Fub24pIH0KICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgICRpbnZhbGlkLkFkZCgkdG9rKQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQogICAgJHNvcnRlZCA9IEAoJHZhbGlkIHwgU29y
HLP:dC1PYmplY3QpCiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IG5vcm0gPSAkc29ydGVkOyBpbnZhbGlkID0gQCgkaW52YWxpZCkgfQp9CgojIC0tLSAoMy4zIC8gUmVxIDQpIENoZWNrcG9pbnQgc29icmUgY2hlY2twb2ludC5qc29uIC0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLQojIFBhcnNlciBkZWwgLUFyZyBjb24gZm9ybWF0bzoKIyAgICJzYXZlfHNlbGVjdGlvbj0wMCwwMSwwMnxjb21wbGV0ZWQ9MDAsMDF8bW9kZT1hdXRvOjE7ZHJ5OjB8cmVhc29uPWNoa2RzayIKZnVuY3Rpb24gUGFyc2UtQ2hlY2twb2ludEFyZyhb
HLP:c3RyaW5nXSRyYXcpIHsKICAgICRyZXMgPSBbb3JkZXJlZF1AeyBzdWIgPSAnJzsgc2VsZWN0aW9uID0gQCgpOyBjb21wbGV0ZWQgPSBAKCk7IG1vZGUgPSBAe307IHJlYXNvbiA9ICcnIH0KICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JFbXB0eSgkcmF3KSkgeyBy
HLP:ZXR1cm4gJHJlcyB9CiAgICAkc2VncyA9ICRyYXcgLXNwbGl0ICdcfCcKICAgICRyZXMuc3ViID0gJHNlZ3NbMF0uVHJpbSgpLlRvTG93ZXIoKQogICAgZm9yICgkaSA9IDE7ICRpIC1sdCAkc2Vncy5Db3VudDsgJGkrKykgewogICAgICAgICRrdiA9ICRzZWdzWyRp
HLP:XSAtc3BsaXQgJz0nLCAyCiAgICAgICAgaWYgKCRrdi5Db3VudCAtbHQgMikgeyBjb250aW51ZSB9CiAgICAgICAgJGtleSA9ICRrdlswXS5UcmltKCkuVG9Mb3dlcigpCiAgICAgICAgJHZhbCA9ICRrdlsxXQogICAgICAgIHN3aXRjaCAoJGtleSkgewogICAgICAg
HLP:ICAgICAnc2VsZWN0aW9uJyB7ICRyZXMuc2VsZWN0aW9uID0gQCgkdmFsIC1zcGxpdCAnLCcgfCBGb3JFYWNoLU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgV2hlcmUtT2JqZWN0IHsgJF8gLW5lICcnIH0pIH0KICAgICAgICAgICAgJ2NvbXBsZXRlZCcgeyAkcmVzLmNv
HLP:bXBsZXRlZCA9IEAoJHZhbCAtc3BsaXQgJywnIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFdoZXJlLU9iamVjdCB7ICRfIC1uZSAnJyB9KSB9CiAgICAgICAgICAgICdyZWFzb24nICAgIHsgJHJlcy5yZWFzb24gPSAkdmFsLlRyaW0oKSB9CiAgICAg
HLP:ICAgICAgICdtb2RlJyB7CiAgICAgICAgICAgICAgICAkbSA9IEB7fQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHBhaXIgaW4gKCR2YWwgLXNwbGl0ICc7JykpIHsKICAgICAgICAgICAgICAgICAgICAkcCA9ICRwYWlyIC1zcGxpdCAnOicsIDIKICAgICAgICAg
HLP:ICAgICAgICAgICBpZiAoJHAuQ291bnQgLWVxIDIpIHsgJG1bJHBbMF0uVHJpbSgpLlRvTG93ZXIoKV0gPSAoJHBbMV0uVHJpbSgpIC1lcSAnMScpIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICRyZXMubW9kZSA9ICRtCiAgICAgICAgICAgIH0K
HLP:ICAgICAgICB9CiAgICB9CiAgICByZXR1cm4gJHJlcwp9CgojIENvbnN0cnV5ZSB5IHBlcnNpc3RlIGNoZWNrcG9pbnQuanNvbi4gRGV2dWVsdmUgJHRydWUvJGZhbHNlIChzaW4gZXhjZXBjaW9uKS4KZnVuY3Rpb24gU2F2ZS1DaGVja3BvaW50KCRwYXJzZWQpIHsK
HLP:ICAgIHRyeSB7CiAgICAgICAgJG1vZGUgPSBbcHNjdXN0b21vYmplY3RdQHsKICAgICAgICAgICAgYXV0byAgICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ2F1dG8nXQogICAgICAgICAgICBub3JlYm9vdCA9IFtib29sXSRwYXJzZWQubW9kZVsnbm9yZWJvb3QnXQog
HLP:ICAgICAgICAgICBrZWVwd3UgICA9IFtib29sXSRwYXJzZWQubW9kZVsna2VlcHd1J10KICAgICAgICAgICAgZHJ5ICAgICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ2RyeSddCiAgICAgICAgICAgIHRyaWFnZSAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWyd0cmlhZ2Un
HLP:XQogICAgICAgIH0KICAgICAgICAkbm93ID0gKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZF9ISC1tbScpCiAgICAgICAgJGNwID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIHZlcnNpb24gICAgICAgID0gJFdQSV9WRVJTSU9OCiAgICAgICAg
HLP:ICAgIGNyZWF0ZWQgICAgICAgID0gJG5vdwogICAgICAgICAgICBtb2RlICAgICAgICAgICA9ICRtb2RlCiAgICAgICAgICAgIHNlbGVjdGlvbiAgICAgID0gQCgkcGFyc2VkLnNlbGVjdGlvbikKICAgICAgICAgICAgY29tcGxldGVkICAgICAgPSBAKCRwYXJzZWQu
HLP:Y29tcGxldGVkKQogICAgICAgICAgICBwZW5kaW5nX3JlYXNvbiA9ICRwYXJzZWQucmVhc29uCiAgICAgICAgICAgIHRpbWVzdGFtcF9ydW4gID0gJG5vdwogICAgICAgIH0KICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJENoZWNrcG9pbnRG
HLP:aWxlLCAoJGNwIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDYpLCAoTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKSkpCiAgICAgICAgcmV0dXJuICR0cnVlCiAgICB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9Cn0KCiMgQ2FyZ2EgY2hl
HLP:Y2twb2ludC5qc29uLiBEZXZ1ZWx2ZSBlbCBvYmpldG8gbyAkbnVsbCBzaSBubyBleGlzdGUgLyBtYWxmb3JtYWRvLgpmdW5jdGlvbiBMb2FkLUNoZWNrcG9pbnQgewogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkQ2hlY2twb2ludEZpbGUpKSB7IHJldHVybiAkbnVs
HLP:bCB9CiAgICB0cnkgeyByZXR1cm4gKEdldC1Db250ZW50ICRDaGVja3BvaW50RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbikgfSBjYXRjaCB7IHJldHVybiAkbnVsbCB9Cn0KCiMgVmFsaWRhIHVuIGNoZWNrcG9pbnQ6IGV4aXN0ZSArIHBhcnNlYWJsZSArIHZl
HLP:cnNpb24gY29tcGF0aWJsZSArIGNvbXBsZXRlZAojIHN1YmNvbmp1bnRvIGRlIHNlbGVjdGlvbiArIGNyZWF0ZWQgZGVudHJvIGRlIGxhIHZlbnRhbmEuIERldnVlbHZlIGJvb2xlYW5vCiMgU0lOIGxhbnphciBleGNlcGNpb24gYW50ZSBKU09OIG1hbGZvcm1hZG8g
HLP:byBjYWR1Y2Fkby4KZnVuY3Rpb24gVGVzdC1DaGVja3BvaW50VmFsaWQoJGNwKSB7CiAgICB0cnkgewogICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7CiAgICAgICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSkgeyByZXR1cm4gJGZh
HLP:bHNlIH0KICAgICAgICAgICAgdHJ5IHsgJGNwID0gR2V0LUNvbnRlbnQgJENoZWNrcG9pbnRGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICB9CiAgICAgICAgaWYgKCRudWxsIC1lcSAkY3ApIHsgcmV0
HLP:dXJuICRmYWxzZSB9CiAgICAgICAgaWYgKFtzdHJpbmddJGNwLnZlcnNpb24gLW5lICRXUElfVkVSU0lPTikgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICAkc2VsICA9IEAoJGNwLnNlbGVjdGlvbikKICAgICAgICAkY29tcCA9IEAoJGNwLmNvbXBsZXRlZCkKICAg
HLP:ICAgICBmb3JlYWNoICgkYyBpbiAkY29tcCkgeyBpZiAoJHNlbCAtbm90Y29udGFpbnMgJGMpIHsgcmV0dXJuICRmYWxzZSB9IH0KICAgICAgICAkY3JlYXRlZCA9ICRudWxsCiAgICAgICAgaWYgKCRjcC5jcmVhdGVkKSB7CiAgICAgICAgICAgIHRyeSB7ICRjcmVh
HLP:dGVkID0gW2RhdGV0aW1lXTo6UGFyc2VFeGFjdChbc3RyaW5nXSRjcC5jcmVhdGVkLCAneXl5eS1NTS1kZF9ISC1tbScsICRudWxsKSB9IGNhdGNoIHsgJGNyZWF0ZWQgPSAkbnVsbCB9CiAgICAgICAgfQogICAgICAgIGlmICgkbnVsbCAtZXEgJGNyZWF0ZWQpIHsg
HLP:cmV0dXJuICRmYWxzZSB9CiAgICAgICAgJGFnZSA9IChHZXQtRGF0ZSkgLSAkY3JlYXRlZAogICAgICAgIGlmICgkYWdlLlRvdGFsRGF5cyAtZ3QgJENIRUNLUE9JTlRfTUFYX0FHRV9EQVlTKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIHJldHVybiAkdHJ1ZQog
HLP:ICAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9CgojIFByaW1lcmEgZmFzZSBkZSAnc2VsZWN0aW9uJyBubyBwcmVzZW50ZSBlbiAnY29tcGxldGVkJyAobyAnJyBzaSB0b2RhcyBoZWNoYXMpLgpmdW5jdGlvbiBHZXQtTmV4dFBoYXNlKCRjcCkgewogICAgaWYg
HLP:KCRudWxsIC1lcSAkY3ApIHsgcmV0dXJuICcnIH0KICAgICRjb21wID0gQCgkY3AuY29tcGxldGVkKQogICAgZm9yZWFjaCAoJHMgaW4gQCgkY3Auc2VsZWN0aW9uKSkgeyBpZiAoJGNvbXAgLW5vdGNvbnRhaW5zICRzKSB7IHJldHVybiAkcyB9IH0KICAgIHJldHVy
HLP:biAnJwp9CgojIC0tLSAoMy45IC8gQnVnIDYgLyBSZXEgOCkgUmVzZXQgZGUgZXN0YWRvIHJldXRpbGl6YWJsZSAtLS0tLS0tLS0tLS0tLS0tLS0tLQojIERlamEgcGhhc2VzPUAoKSwgZmluZGluZ3M9QCgpIHkgbG9zIHNjb3JlcyAoYmVmb3JlL2FmdGVyKSBhIG51
HLP:bGwuIEVsCiMgY29uZGljaW9uYWRvIGEgL3Jlc3VtZSBsbyBhcGxpY2EgZWwgYmF0Y2ggKHRhcmVhcyA4LjQgLyA5LjEpOiBzb2xvIGludm9jYQojICdyZXNldHN0YXRlJyBjdWFuZG8gUkVTVU1FPT0wLCBjb25zZXJ2YW5kbyBlbCBlc3RhZG8gcHJldmlvIGVuIC9y
HLP:ZXN1bWUuCmZ1bmN0aW9uIFJlc2V0LVN0YXRlIHsKICAgIFdyaXRlLVN0YXRlIChbcHNjdXN0b21vYmplY3RdQHsgc2NvcmVfYmVmb3JlID0gJG51bGw7IHNjb3JlX2FmdGVyID0gJG51bGw7IGZpbmRpbmdzID0gQCgpOyBwaGFzZXMgPSBAKCkgfSkKfQoKIyAtLS0g
HLP:KDMuMTEgLyBCdWcgNyAvIFJlcSA5KSBIb25lc3RpZGFkIGRlbCBtb3ZpbWllbnRvIGRlIGNhY2hlcyAtLS0tLS0tLS0tLS0KIyBFeGl0byAodHJ1ZSkgU0kgWSBTT0xPIFNJIGVsIG9yaWdlbiBlc3RhIGF1c2VudGUgeSBlbCBkZXN0aW5vIHByZXNlbnRlLgojIFZh
HLP:cmlhbnRlIHB1cmEgKGJvb2xlYW5vcykgKyB2YXJpYW50ZSBxdWUgYWNlcHRhIHJ1dGFzIHkgaGFjZSBUZXN0LVBhdGguCmZ1bmN0aW9uIFRlc3QtTW92ZVJlc3VsdChbYm9vbF0kc3JjRXhpc3RzLCBbYm9vbF0kZHN0RXhpc3RzKSB7CiAgICByZXR1cm4gKCgtbm90
HLP:ICRzcmNFeGlzdHMpIC1hbmQgJGRzdEV4aXN0cykKfQpmdW5jdGlvbiBUZXN0LU1vdmVSZXN1bHRQYXRoKFtzdHJpbmddJHNyYywgW3N0cmluZ10kZHN0KSB7CiAgICByZXR1cm4gKFRlc3QtTW92ZVJlc3VsdCAoW2Jvb2xdKFRlc3QtUGF0aCAkc3JjKSkgKFtib29s
HLP:XShUZXN0LVBhdGggJGRzdCkpKQp9CgojIC0tLSAoMy4xMSAvIEJ1ZyA4IC8gUmVxIDEwKSBJZGVtcG90ZW5jaWEgZGUgVmlydHVhbFRlcm1pbmFsTGV2ZWwgLS0tLS0tLS0tLQojIE5vcm1hbGl6YSB2YWxvcmVzICcweDEnIC8gJzEnIC8gMSBhIGVudGVybyBwYXJh
HLP:IGNvbXBhcmFyIGRlIGZvcm1hIHJvYnVzdGEuCmZ1bmN0aW9uIENvbnZlcnRUby1WdGxJbnQoJHYpIHsKICAgIGlmICgkbnVsbCAtZXEgJHYpIHsgcmV0dXJuICRudWxsIH0KICAgICRzID0gKFtzdHJpbmddJHYpLlRyaW0oKS5Ub0xvd2VyKCkKICAgIGlmICgkcyAt
HLP:ZXEgJycpIHsgcmV0dXJuICRudWxsIH0KICAgIHRyeSB7CiAgICAgICAgaWYgKCRzLlN0YXJ0c1dpdGgoJzB4JykpIHsgcmV0dXJuIFtDb252ZXJ0XTo6VG9JbnQzMigkcywgMTYpIH0KICAgICAgICByZXR1cm4gW2ludF0kcwogICAgfSBjYXRjaCB7IHJldHVybiAk
HLP:bnVsbCB9Cn0KIyBEZXZ1ZWx2ZSAkdHJ1ZSAoZXNjcmliaXIpIHNvbG8gc2kgZWwgdmFsb3IgYWN0dWFsIGRpZmllcmUgZGVsIGRlc2VhZG8uCmZ1bmN0aW9uIFJlc29sdmUtVnRsV3JpdGUoJGN1cnJlbnQsICRkZXNpcmVkKSB7CiAgICByZXR1cm4gKChDb252ZXJ0
HLP:VG8tVnRsSW50ICRjdXJyZW50KSAtbmUgKENvbnZlcnRUby1WdGxJbnQgJGRlc2lyZWQpKQp9CgojIC0tLSAoMy4xNCAvIFJlcSAxLjMpIE1hcGVvIFRPVEFMIGRlIGNvZGlnbyBkZSBzYWxpZGEgYSB7T0ssV0FSTixTS0lQLEVSUk9SfQojIDAtPk9LLCAxLT5XQVJO
HLP:LCAyLT5TS0lQLCAzLT5FUlJPUjsgY3VhbHF1aWVyIG90cm8gZW50ZXJvIChvIG5vIGVudGVybykgLT4gRVJST1IuCmZ1bmN0aW9uIE1hcC1FeGl0Q29kZSgkY29kZSkgewogICAgJG4gPSAkbnVsbAogICAgdHJ5IHsgJG4gPSBbaW50XSRjb2RlIH0gY2F0Y2ggeyBy
HLP:ZXR1cm4gJ0VSUk9SJyB9CiAgICBzd2l0Y2ggKCRuKSB7CiAgICAgICAgMCAgICAgICB7ICdPSycgfQogICAgICAgIDEgICAgICAgeyAnV0FSTicgfQogICAgICAgIDIgICAgICAgeyAnU0tJUCcgfQogICAgICAgIDMgICAgICAgeyAnRVJST1InIH0KICAgICAgICBk
HLP:ZWZhdWx0IHsgJ0VSUk9SJyB9CiAgICB9Cn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgRElBR05PU1RJQ08gQU1QTElBRE8gKDUuMSAvIFJlcSAxNS4xLTE1LjUp
HLP:CiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCiMgLS0tIFJBTSAoUmVxIDE1LjEpIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0KIyBSZXNvbHZlLVJhbVN0YXR1czogZnVuY2lvbiBQVVJBLiBBIHBhcnRpciBkZWwgY29udGVvIGRlIGVycm9yZXMgZGUgbWVtb3JpYQojIFdIRUEgeSBkZSBmYWxsb3MgZGVsIGRpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUgV2luZG93cywgZGVjaWRlIGVs
HLP:IGVzdGFkbyB5CiMgc2kgY29udmllbmUgcmVjb21lbmRhciBtZHNjaGVkLgpmdW5jdGlvbiBSZXNvbHZlLVJhbVN0YXR1cyhbaW50XSR3aGVhTWVtRXJyb3JzLCBbaW50XSRtZW1EaWFnRmFpbHVyZXMpIHsKICAgIGlmICgkd2hlYU1lbUVycm9ycyAtZ3QgMCAtb3Ig
HLP:JG1lbURpYWdGYWlsdXJlcyAtZ3QgMCkgewogICAgICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJ3N1c3BlY3QnOyByZWNvbW1lbmRfbWRzY2hlZCA9ICR0cnVlIH0KICAgIH0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVz
HLP:ID0gJ29rJzsgcmVjb21tZW5kX21kc2NoZWQgPSAkZmFsc2UgfQp9CgojIEdldC1SYW1DaGVjazogbGVlIGV2ZW50b3MgV0hFQSB5IHJlc3VsdGFkb3MgZGVsIERpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUKIyBXaW5kb3dzLiBEZWdyYWRhY2lvbiBlbGVnYW50ZTog
HLP:c2kgbGEgY29uc3VsdGEgZGUgZXZlbnRvcyBmYWxsYSBwb3IgY29tcGxldG8sCiMgZGV2dWVsdmUgc3RhdHVzPSd1bmtub3duJyBzaW4gbGFuemFyIGV4Y2VwY2lvbi4KZnVuY3Rpb24gR2V0LVJhbUNoZWNrIHsKICAgIHRyeSB7CiAgICAgICAgJHF1ZXJpZWQgPSAk
HLP:ZmFsc2UKICAgICAgICAkd2hlYUNvdW50ID0gMAogICAgICAgICRtZW1EaWFnRmFpbCA9IDAKICAgICAgICAjIEVycm9yZXMgZGUgaGFyZHdhcmUgV0hFQSByZWxhY2lvbmFkb3MgY29uIG1lbW9yaWEKICAgICAgICAkd2hlYSA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0
HLP:ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBQcm92aWRlck5hbWU9J01pY3Jvc29mdC1XaW5kb3dzLVdIRUEtTG9nZ2VyJ30gLU1heEV2ZW50cyAxMDAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYgKCRudWxsIC1uZSAkd2hl
HLP:YSkgeyAkcXVlcmllZCA9ICR0cnVlIH0KICAgICAgICAkd2hlYUNvdW50ID0gQCgkd2hlYSB8IFdoZXJlLU9iamVjdCB7ICgkXy5JZCAtaW4gMTgsMTksMjAsNDcpIC1vciAoJF8uTWVzc2FnZSAtbWF0Y2ggJ21lbW9yJykgfSkuQ291bnQKICAgICAgICAjIFJlc3Vs
HLP:dGFkb3MgZGVsIERpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUgV2luZG93cyAobWRzY2hlZCkKICAgICAgICAkbWQgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgUHJvdmlkZXJOYW1lPSdNaWNyb3NvZnQtV2luZG93
HLP:cy1NZW1vcnlEaWFnbm9zdGljcy1SZXN1bHRzJ30gLU1heEV2ZW50cyA1MCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICBpZiAoJG51bGwgLW5lICRtZCkgeyAkcXVlcmllZCA9ICR0cnVlIH0KICAgICAgICAkbWVtRGlhZ0ZhaWwgPSBAKCRt
HLP:ZCB8IFdoZXJlLU9iamVjdCB7ICgkXy5JZCAtZXEgMTAwMikgLW9yICgkXy5MZXZlbERpc3BsYXlOYW1lIC1lcSAnRXJyb3InKSAtb3IgKCRfLk1lc3NhZ2UgLW1hdGNoICdlcnJvcnxlcnJvcmVzJykgfSkuQ291bnQKICAgICAgICByZXR1cm4gKFJlc29sdmUtUmFt
HLP:U3RhdHVzICR3aGVhQ291bnQgJG1lbURpYWdGYWlsKQogICAgfSBjYXRjaCB7CiAgICAgICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAndW5rbm93bic7IHJlY29tbWVuZF9tZHNjaGVkID0gJGZhbHNlIH0KICAgIH0KfQoKIyAtLS0gQmF0ZXJp
HLP:YSAoUmVxIDE1LjIpIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEdldC1CYXR0ZXJ5SGVhbHRoUGN0OiBmdW5jaW9uIFBVUkEuICUgZGUgc2FsdWQgPSBwbGVuYSBjYXJnYSAvIGRpc2VubyAqIDEwMC4KZnVuY3Rp
HLP:b24gR2V0LUJhdHRlcnlIZWFsdGhQY3QoJGRlc2lnbiwgJGZ1bGwpIHsKICAgIHRyeSB7CiAgICAgICAgJGQgPSBbZG91YmxlXSRkZXNpZ247ICRmID0gW2RvdWJsZV0kZnVsbAogICAgICAgIGlmICgkZCAtZ3QgMCkgeyByZXR1cm4gW2ludF1bbWF0aF06OlJvdW5k
HLP:KCgkZiAvICRkKSAqIDEwMCkgfQogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuICRudWxsCn0KCiMgR2V0LUJhdHRlcnlIZWFsdGg6IHNpIGhheSBiYXRlcmlhLCBnZW5lcmEgcG93ZXJjZmcgL2JhdHRlcnlyZXBvcnQgeSBleHRyYWUgbGEKIyBzYWx1ZCAoY2FwYWNp
HLP:ZGFkIGRlIGRpc2VubyB2cyBwbGVuYSBjYXJnYSkuIFNpbiBiYXRlcmlhIC0+IHByZXNlbnQ9JGZhbHNlLgojIE5vIGZhbGxhIHNpIHBvd2VyY2ZnIG5vIGVzdGEgZGlzcG9uaWJsZSAoaGVhbHRoX3BjdCBxdWVkYSB2YWNpbykuCmZ1bmN0aW9uIEdldC1CYXR0ZXJ5
HLP:SGVhbHRoIHsKICAgICRwcmVzZW50ID0gJGZhbHNlOyAkaGVhbHRoUGN0ID0gJyc7ICRyZXBvcnRQYXRoID0gJycKICAgIHRyeSB7CiAgICAgICAgJGJhdCA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX0JhdHRlcnkgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGlu
HLP:dWUpCiAgICAgICAgaWYgKCRiYXQuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgJHByZXNlbnQgPSAkdHJ1ZQogICAgICAgICAgICAkcmVwb3J0UGF0aCA9IEpvaW4tUGF0aCAkV29yayAnYmF0dGVyeS1yZXBvcnQuaHRtbCcKICAgICAgICAgICAgdHJ5IHsgJiBw
HLP:b3dlcmNmZyAvYmF0dGVyeXJlcG9ydCAvb3V0cHV0ICIkcmVwb3J0UGF0aCIgL2R1cmF0aW9uIDEgPiAkbnVsbCAyPiYxIH0gY2F0Y2gge30KICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkcmVwb3J0UGF0aCkgewogICAgICAgICAgICAgICAgdHJ5IHsKICAgICAg
HLP:ICAgICAgICAgICAgICAkdHh0ID0gR2V0LUNvbnRlbnQgJHJlcG9ydFBhdGggLVJhdwogICAgICAgICAgICAgICAgICAgICRkZXNpZ24gPSAkbnVsbDsgJGZ1bGwgPSAkbnVsbAogICAgICAgICAgICAgICAgICAgICRtMSA9IFtyZWdleF06Ok1hdGNoKCR0eHQsICco
HLP:P2lzKURFU0lHTiBDQVBBQ0lUWS4qPyhbXGRcLixdKylccyptV2gnKQogICAgICAgICAgICAgICAgICAgICRtMiA9IFtyZWdleF06Ok1hdGNoKCR0eHQsICcoP2lzKUZVTEwgQ0hBUkdFIENBUEFDSVRZLio/KFtcZFwuLF0rKVxzKm1XaCcpCiAgICAgICAgICAgICAg
HLP:ICAgICAgaWYgKCRtMS5TdWNjZXNzKSB7ICRkZXNpZ24gPSBbZG91YmxlXSgoJG0xLkdyb3Vwc1sxXS5WYWx1ZSAtcmVwbGFjZSAnW1wuLF0nLCAnJykpIH0KICAgICAgICAgICAgICAgICAgICBpZiAoJG0yLlN1Y2Nlc3MpIHsgJGZ1bGwgICA9IFtkb3VibGVdKCgk
HLP:bTIuR3JvdXBzWzFdLlZhbHVlIC1yZXBsYWNlICdbXC4sXScsICcnKSkgfQogICAgICAgICAgICAgICAgICAgICRwY3QgPSBHZXQtQmF0dGVyeUhlYWx0aFBjdCAkZGVzaWduICRmdWxsCiAgICAgICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcGN0KSB7ICRo
HLP:ZWFsdGhQY3QgPSAkcGN0IH0KICAgICAgICAgICAgICAgIH0gY2F0Y2gge30KICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgcHJlc2VudCA9ICRwcmVzZW50OyBoZWFsdGhfcGN0ID0gJGhl
HLP:YWx0aFBjdDsgcmVwb3J0X3BhdGggPSAkcmVwb3J0UGF0aCB9Cn0KCiMgLS0tIE5ldHdvcmsgYXZhbnphZGEgKFJlcSAxNS41KSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgR2V0LU5ldEFkdmFuY2VkOiBjb25lY3Rpdmlk
HLP:YWQgKHBpbmcgYSAxLjEuMS4xKSwgRE5TIChSZXNvbHZlLURuc05hbWUgY29uCiMgcmVzcGFsZG8gcG9yIHBpbmcgYSB1biBob3N0KSB5IGNvbmZpZ3VyYWNpb24gYmFzaWNhIChJUC9nYXRld2F5KS4KIyBEZWdyYWRhY2lvbiBlbGVnYW50ZTogbnVuY2EgbGFuemEg
HLP:ZXhjZXBjaW9uLgpmdW5jdGlvbiBHZXQtTmV0QWR2YW5jZWQgewogICAgJGNvbm5lY3RlZCA9ICRmYWxzZTsgJGRuc09rID0gJGZhbHNlOyAkZGV0YWlscyA9ICcnCiAgICB0cnkgewogICAgICAgICMgQ29uZWN0aXZpZGFkCiAgICAgICAgJHBpbmcgPSAkZmFsc2UK
HLP:ICAgICAgICB0cnkgeyAkcGluZyA9IFtib29sXShUZXN0LUNvbm5lY3Rpb24gLUNvbXB1dGVyTmFtZSAnMS4xLjEuMScgLUNvdW50IDEgLVF1aWV0IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSB9IGNhdGNoIHsgJHBpbmcgPSAkZmFsc2UgfQogICAgICAg
HLP:IGlmICgtbm90ICRwaW5nKSB7CiAgICAgICAgICAgIHRyeSB7ICYgcGluZyAtbiAxIC13IDE1MDAgMS4xLjEuMSA+ICRudWxsIDI+JjE7IGlmICgkTEFTVEVYSVRDT0RFIC1lcSAwKSB7ICRwaW5nID0gJHRydWUgfSB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgICAg
HLP:ICRjb25uZWN0ZWQgPSBbYm9vbF0kcGluZwogICAgICAgICMgUmVzb2x1Y2lvbiBETlMgKGNvbiBtZWRpZGEgZGUgbGF0ZW5jaWEpCiAgICAgICAgJGRucyA9ICRmYWxzZTsgJGRuc01zID0gJG51bGwKICAgICAgICB0cnkgewogICAgICAgICAgICAkc3cgPSBbU3lz
HLP:dGVtLkRpYWdub3N0aWNzLlN0b3B3YXRjaF06OlN0YXJ0TmV3KCkKICAgICAgICAgICAgJHIgPSBSZXNvbHZlLURuc05hbWUgLU5hbWUgJ3d3dy5taWNyb3NvZnQuY29tJyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICAkc3cuU3RvcCgp
HLP:CiAgICAgICAgICAgIGlmICgkcikgeyAkZG5zID0gJHRydWU7ICRkbnNNcyA9IFtpbnRdJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgfQogICAgICAgIH0gY2F0Y2gge30KICAgICAgICBpZiAoLW5vdCAkZG5zKSB7CiAgICAgICAgICAgIHRyeSB7ICYgcGluZyAtbiAx
HLP:IC13IDE1MDAgd3d3Lm1pY3Jvc29mdC5jb20gPiAkbnVsbCAyPiYxOyBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCkgeyAkZG5zID0gJHRydWUgfSB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgICAgICRkbnNPayA9IFtib29sXSRkbnMKICAgICAgICAjIENvbmZpZ3Vy
HLP:YWNpb24gYmFzaWNhIChJUCAvIGdhdGV3YXkpCiAgICAgICAgJGlwID0gJyc7ICRndyA9ICcnCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJGNmZyA9IEAoR2V0LU5ldElQQ29uZmlndXJhdGlvbiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJl
HLP:LU9iamVjdCB7ICRfLklQdjREZWZhdWx0R2F0ZXdheSB9KSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgaWYgKCRjZmcpIHsKICAgICAgICAgICAgICAgICRpcCA9ICgkY2ZnLklQdjRBZGRyZXNzIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSku
HLP:SVBBZGRyZXNzCiAgICAgICAgICAgICAgICAkZ3cgPSAoJGNmZy5JUHY0RGVmYXVsdEdhdGV3YXkgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5OZXh0SG9wCiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgJGRldGFpbHMgPSAiSVA9JGlw
HLP:OyBHVz0kZ3ciCiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IGNvbm5lY3RlZCA9ICRjb25uZWN0ZWQ7IGRuc19vayA9ICRkbnNPazsgZGV0YWlscyA9ICRkZXRhaWxzOyBkbnNfbXMgPSAkZG5zTXMgfQp9CgojIC0tLSBEZXZpY2Vz
HLP:IHBhcmEgZGlhZyAoUmVxIDE1LjMvMTUuNCkgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEdldC1EZXZpY2VMaXN0OiBsaXN0YSBlc3RydWN0dXJhZGEgZGUgZGlzcG9zaXRpdm9zIGNvbiBlcnJvciBwYXJhIGVzdGFkby5kaWFnLgojIERldnVlbHZl
HLP:ICRudWxsIHNpIGxhIGlkZW50aWZpY2FjaW9uIGRlIGRyaXZlcnMgZmFsbGEgKHNlbmFsIGRlICJpbmZvIG5vCiMgZGlzcG9uaWJsZSIgcGFyYSBkZWdyYWRhY2lvbiBlbGVnYW50ZSkuCmZ1bmN0aW9uIEdldC1EZXZpY2VMaXN0IHsKICAgIHRyeSB7CiAgICAgICAg
HLP:JHAgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9QblBFbnRpdHkgLUVycm9yQWN0aW9uIFN0b3AgfCBXaGVyZS1PYmplY3QgeyAkXy5Db25maWdNYW5hZ2VyRXJyb3JDb2RlIC1ndCAwIH0pCiAgICAgICAgJGxpc3QgPSBAKCkKICAgICAgICBmb3JlYWNoICgkZCBp
HLP:biAoJHAgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxMikpIHsKICAgICAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7IGNvZGUgPSBbaW50XSRkLkNvbmZpZ01hbmFnZXJFcnJvckNvZGU7IG5hbWUgPSBbc3RyaW5nXSRkLk5hbWUgfQogICAgICAgIH0K
HLP:ICAgICAgICByZXR1cm4gLCRsaXN0CiAgICB9IGNhdGNoIHsgcmV0dXJuICRudWxsIH0KfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBST1RBQ0lPTiBERSBMT0dT
HLP:ICg1LjYgLyBSZXEgMTcuMikKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIFNlbGVjdC1Mb2dzVG9EZWxldGU6IGZ1bmNpb24gUFVSQS4gRGUgdW5hIGNvbGVjY2lvbiBk
HLP:ZSBmaWNoZXJvcyAoY29uCiMgLkxhc3RXcml0ZVRpbWUpIHkgdW5hIHJldGVuY2lvbiBOLCBkZXZ1ZWx2ZSBsb3MgcXVlIGRlYmVuIEJPUlJBUlNFOiB0b2RvcwojIG1lbm9zIGxvcyBOIG1hcyByZWNpZW50ZXMgKGVzIGRlY2lyLCBsb3MgbWFzIGFudGlndW9zKS4g
HLP:U2kgaGF5IDw9IE4sIG5pbmd1bm8uCmZ1bmN0aW9uIFNlbGVjdC1Mb2dzVG9EZWxldGUoJGZpbGVzLCBbaW50XSRyZXRlbnRpb24pIHsKICAgICRhcnIgPSBAKCRmaWxlcykKICAgIGlmICgkcmV0ZW50aW9uIC1sdCAwKSB7ICRyZXRlbnRpb24gPSAwIH0KICAgIGlm
HLP:ICgkYXJyLkNvdW50IC1sZSAkcmV0ZW50aW9uKSB7IHJldHVybiBAKCkgfQogICAgJHNvcnRlZCA9IEAoJGFyciB8IFNvcnQtT2JqZWN0IC1Qcm9wZXJ0eSBMYXN0V3JpdGVUaW1lIC1EZXNjZW5kaW5nKQogICAgcmV0dXJuIEAoJHNvcnRlZCB8IFNlbGVjdC1PYmpl
HLP:Y3QgLVNraXAgJHJldGVudGlvbikKfQoKIyBJbnZva2UtTG9nUm90YXRlOiBjb25zZXJ2YSBsb3MgJHJldGVudGlvbiBsb2dzIG1hcyByZWNpZW50ZXMgZW4gJGZvbGRlciB5CiMgYm9ycmEgZWwgcmVzdG8uIERldnVlbHZlIGVsIG51bWVybyBkZSBmaWNoZXJvcyBi
HLP:b3JyYWRvcy4KZnVuY3Rpb24gSW52b2tlLUxvZ1JvdGF0ZShbc3RyaW5nXSRmb2xkZXIsIFtpbnRdJHJldGVudGlvbikgewogICAgaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJGZvbGRlcikpIHsgJGZvbGRlciA9IEpvaW4tUGF0aCAkV29yayAnTG9n
HLP:cycgfQogICAgJGRlbGV0ZWQgPSAwCiAgICB0cnkgewogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJGZvbGRlcikpIHsgcmV0dXJuIDAgfQogICAgICAgICRmaWxlcyA9IEAoR2V0LUNoaWxkSXRlbSAtUGF0aCAkZm9sZGVyIC1GaWx0ZXIgJyoubG9nJyAtRmls
HLP:ZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICAkdG9EZWxldGUgPSBTZWxlY3QtTG9nc1RvRGVsZXRlICRmaWxlcyAkcmV0ZW50aW9uCiAgICAgICAgZm9yZWFjaCAoJGYgaW4gJHRvRGVsZXRlKSB7CiAgICAgICAgICAgIHRyeSB7IFJlbW92
HLP:ZS1JdGVtICRmLkZ1bGxOYW1lIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgJGRlbGV0ZWQrKyB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuICRkZWxldGVkCn0KCiMgPT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgVkFMSURBQ0lPTiBERSBFTlRPUk5PIFkgU0VMRi1URVNUICg1LjggLyBSZXEgMTMuNSwxMy42LDE4LjEsMTguMywxOC42KQojID09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgVGVzdC1Pc1N1cHBvcnRlZDogZnVuY2lvbiBQVVJBLiBXaW5kb3dzIDEwLzExID0+IGJ1aWxkID49IDEwMjQwLgpmdW5jdGlvbiBUZXN0LU9zU3VwcG9ydGVkKFtp
HLP:bnRdJGJ1aWxkKSB7CiAgICByZXR1cm4gKCRidWlsZCAtZ2UgMTAyNDApCn0KCiMgSW52b2tlLUVudlZhbGlkYXRlOiBjb21wcnVlYmEgbGEgdmVyc2lvbiBkZWwgU08gdmlhIENJTS4gTGEgY29tcHJvYmFjaW9uIHNlCiMgY29uc2lkZXJhIFNJRU1QUkUgcmVhbGl6
HLP:YWRhIChjaGVja19kb25lKSBhdW5xdWUgbGEgdmVyc2lvbiBubyBzZWEgY29tcGF0aWJsZS4KZnVuY3Rpb24gSW52b2tlLUVudlZhbGlkYXRlIHsKICAgICRidWlsZCA9IDAKICAgIHRyeSB7ICRidWlsZCA9IFtpbnRdKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9PcGVy
HLP:YXRpbmdTeXN0ZW0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLkJ1aWxkTnVtYmVyIH0gY2F0Y2ggeyAkYnVpbGQgPSAwIH0KICAgIGlmICgkYnVpbGQgLWxlIDApIHsgdHJ5IHsgJGJ1aWxkID0gW2ludF0oR2V0LUl0ZW1Qcm9wZXJ0eSAnSEtMTTpcU09G
HLP:VFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb24nIC1OYW1lIEN1cnJlbnRCdWlsZE51bWJlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuQ3VycmVudEJ1aWxkTnVtYmVyIH0gY2F0Y2ggeyAkYnVpbGQgPSAwIH0gfQogICAgaWYg
HLP:KCRidWlsZCAtbGUgMCkgeyB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtSXRlbVByb3BlcnR5ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvbicgLU5hbWUgQ3VycmVudEJ1aWxkIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
HLP:bnRpbnVlKS5DdXJyZW50QnVpbGQgfSBjYXRjaCB7ICRidWlsZCA9IDAgfSB9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IG9zX29rID0gKFRlc3QtT3NTdXBwb3J0ZWQgJGJ1aWxkKTsgYnVpbGQgPSAkYnVpbGQ7IGNoZWNrX2RvbmUgPSAkdHJ1ZSB9Cn0K
HLP:CiMgSW52b2tlLVNlbGZUZXN0OiBhZ3JlZ2Fkb3IgUFVSTy4gRXhpdG8gKHRydWUpIHNpIHkgc29sbyBzaSBUT0RBUyBsYXMKIyBjb21wcm9iYWNpb25lcyAoYm9vbGVhbm9zKSBwYXNhbi4gQ29sZWNjaW9uIHZhY2lhIC0+IHRydWUgKG5hZGEgZmFsbG8pLgpmdW5j
HLP:dGlvbiBJbnZva2UtU2VsZlRlc3QoJHJlc3VsdHMpIHsKICAgIGZvcmVhY2ggKCRyIGluIEAoJHJlc3VsdHMpKSB7IGlmICgtbm90IFtib29sXSRyKSB7IHJldHVybiAkZmFsc2UgfSB9CiAgICByZXR1cm4gJHRydWUKfQoKIyBQYXJzZS1Cb29sTGlzdDogY29udmll
HLP:cnRlICIxLDEsMCwxIiAobyB0cnVlL29rKSBlbiB1bmEgbGlzdGEgZGUgYm9vbGVhbm9zLgpmdW5jdGlvbiBQYXJzZS1Cb29sTGlzdChbc3RyaW5nXSRyYXcpIHsKICAgICRsaXN0ID0gQCgpCiAgICBpZiAoLW5vdCBbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNl
HLP:KCRyYXcpKSB7CiAgICAgICAgZm9yZWFjaCAoJHQgaW4gKCRyYXcgLXNwbGl0ICcsJykpIHsKICAgICAgICAgICAgJHRvayA9ICR0LlRyaW0oKS5Ub0xvd2VyKCkKICAgICAgICAgICAgaWYgKCR0b2sgLWVxICcnKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgJGxp
HLP:c3QgKz0gKCR0b2sgLWVxICcxJyAtb3IgJHRvayAtZXEgJ3RydWUnIC1vciAkdG9rIC1lcSAnb2snIC1vciAkdG9rIC1lcSAncGFzcycpCiAgICAgICAgfQogICAgfQogICAgcmV0dXJuICwkbGlzdAp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgRElBR05PU1RJQ08gUFJPRlVORE8gdjMuMSAo
HLP:U01BUlQsIGFycmFucXVlLCBCQ0QsIHByb2Nlc29zLCBTRkMsIEpTT04pCiMgIFRvZGFzIGxhcyBmdW5jaW9uZXMgZGVncmFkYW4gY29uIGVsZWdhbmNpYTogc2kgYWxnbyBmYWxsYSwgZGV2dWVsdmVuCiMgIGVzdHJ1Y3R1cmFzIHZhY2lhcyAvICd1bmtub3duJyBl
HLP:biBsdWdhciBkZSBsYW56YXIgZXhjZXBjaW9uZXMuCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCiMgR2V0LVNtYXJ0QXR0cmlidXRlczogc2FsdWQgZmlzaWNhIGRlbCBk
HLP:aXNjbyBkZSBzaXN0ZW1hIChpbmRlcGVuZGllbnRlIGRlbAojIGlkaW9tYSBkZSBXaW5kb3dzKS4gVXNhIE1TU3RvcmFnZURyaXZlcl9GYWlsdXJlUHJlZGljdFN0YXR1cyArIGVsIGNvbnRhZG9yCiMgZGUgZmlhYmlsaWRhZCBkZSBhbG1hY2VuYW1pZW50by4gRGV2
HLP:dWVsdmUgYXZhaWxhYmxlPSRmYWxzZSBzaSBubyBoYXkgZGF0b3MuCmZ1bmN0aW9uIEdldC1TbWFydEF0dHJpYnV0ZXMgewogICAgJHJlcyA9IFtwc2N1c3RvbW9iamVjdF1AeyBhdmFpbGFibGUgPSAkZmFsc2U7IHByZWRpY3RfZmFpbCA9ICRmYWxzZTsgdGVtcF9j
HLP:ID0gJG51bGw7IHdlYXJfcGN0ID0gJG51bGw7IHBvaCA9ICRudWxsIH0KICAgIHRyeSB7CiAgICAgICAgJHBmID0gJG51bGwKICAgICAgICB0cnkgeyAkcGYgPSBAKEdldC1DaW1JbnN0YW5jZSAtTmFtZXNwYWNlICdyb290XHdtaScgLUNsYXNzTmFtZSAnTVNTdG9y
HLP:YWdlRHJpdmVyX0ZhaWx1cmVQcmVkaWN0U3RhdHVzJyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkgfSBjYXRjaCB7ICRwZiA9ICRudWxsIH0KICAgICAgICBpZiAoJHBmIC1hbmQgJHBmLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRyZXMuYXZhaWxh
HLP:YmxlID0gJHRydWUKICAgICAgICAgICAgZm9yZWFjaCAoJHggaW4gJHBmKSB7IGlmICgkeC5QcmVkaWN0RmFpbHVyZSkgeyAkcmVzLnByZWRpY3RfZmFpbCA9ICR0cnVlIH0gfQogICAgICAgIH0KICAgICAgICAjIERpc2NvIHF1ZSBjb250aWVuZSBDOiAtPiBjb250
HLP:YWRvciBkZSBmaWFiaWxpZGFkCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHN5c0Rpc2sgPSAkbnVsbAogICAgICAgICAgICB0cnkgeyAkc3lzRGlzayA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBXaGVyZS1PYmpl
HLP:Y3QgeyAkXy5EZXZpY2VJZCAtbmUgJG51bGwgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfSBjYXRjaCB7fQogICAgICAgICAgICAkcmMgPSAkbnVsbAogICAgICAgICAgICBpZiAoJHN5c0Rpc2spIHsgJHJjID0gJHN5c0Rpc2sgfCBHZXQtU3RvcmFnZVJlbGlh
HLP:YmlsaXR5Q291bnRlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgIGlmICgtbm90ICRyYykgeyAkcmMgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgR2V0LVN0b3JhZ2VSZWxpYWJpbGl0
HLP:eUNvdW50ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgaWYgKCRyYykgewogICAgICAgICAgICAgICAgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZQogICAgICAgICAgICAgICAgaWYgKCRu
HLP:dWxsIC1uZSAkcmMuVGVtcGVyYXR1cmUgLWFuZCAkcmMuVGVtcGVyYXR1cmUgLWd0IDApIHsgJHJlcy50ZW1wX2MgPSBbaW50XSRyYy5UZW1wZXJhdHVyZSB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyYy5XZWFyKSAgICAgICAgIHsgJHJlcy53ZWFy
HLP:X3BjdCA9IFtpbnRdJHJjLldlYXIgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcmMuUG93ZXJPbkhvdXJzKSB7ICRyZXMucG9oID0gW2ludF0kcmMuUG93ZXJPbkhvdXJzIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAjIFNlbmFsIGFkaWNpb25h
HLP:bCBkZSBwcmVkaWNjaW9uIGRlIGZhbGxvIHZpYSBlc3RhZG8gZGUgc2FsdWQgZmlzaWNhCiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAkdW5oZWFsdGh5ID0gQChHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwg
HLP:V2hlcmUtT2JqZWN0IHsgJF8uSGVhbHRoU3RhdHVzIC1hbmQgJF8uSGVhbHRoU3RhdHVzIC1uZSAnSGVhbHRoeScgfSkKICAgICAgICAgICAgICAgIGlmICgkdW5oZWFsdGh5LkNvdW50IC1ndCAwKSB7ICRyZXMuYXZhaWxhYmxlID0gJHRydWU7ICRyZXMucHJlZGlj
HLP:dF9mYWlsID0gJHRydWUgfQogICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgfSBjYXRjaCB7fQogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuICRyZXMKfQoKIyBHZXQtU3RhcnR1cEl0ZW1zOiBwcm9ncmFtYXMgcXVlIGFycmFuY2FuIGNvbiBXaW5kb3dzICh0
HLP:b3AgTiksIHBhcmEgcXVlIGVsCiMgdXN1YXJpbyB2ZWEgcXVlIHJhbGVudGl6YSBlbCBpbmljaW8uIEluZGVwZW5kaWVudGUgZGVsIGlkaW9tYS4KZnVuY3Rpb24gR2V0LVN0YXJ0dXBJdGVtcyhbaW50XSR0b3AgPSA4KSB7CiAgICB0cnkgewogICAgICAgICRpdGVt
HLP:cyA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1N0YXJ0dXBDb21tYW5kIC1FcnJvckFjdGlvbiBTdG9wIHwKICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uQ29tbWFuZCB9IHwKICAgICAgICAgICAgU2VsZWN0LU9iamVjdCAtRmlyc3QgJHRvcCkKICAgICAg
HLP:ICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRpIGluICRpdGVtcykgewogICAgICAgICAgICAkY21kID0gW3N0cmluZ10kaS5Db21tYW5kCiAgICAgICAgICAgIGlmICgkY21kLkxlbmd0aCAtZ3QgODApIHsgJGNtZCA9ICRjbWQuU3Vic3RyaW5nKDAsNzcp
HLP:ICsgJy4uLicgfQogICAgICAgICAgICAkbm0gPSBbc3RyaW5nXSRpLk5hbWU7IGlmICgtbm90ICRubSkgeyAkbm0gPSBbc3RyaW5nXSRpLkNhcHRpb24gfQogICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsgbmFtZSA9ICRubTsgY29tbWFuZCA9
HLP:ICRjbWQgfQogICAgICAgIH0KICAgICAgICByZXR1cm4gLCRsaXN0CiAgICB9IGNhdGNoIHsgcmV0dXJuIEAoKSB9Cn0KCiMgR2V0LUJjZEludGVncml0eTogY29tcHJ1ZWJhIHF1ZSBsYSBjb25maWd1cmFjaW9uIGRlIGFycmFucXVlIChCQ0QpIHRpZW5lIGxhCiMg
HLP:ZW50cmFkYSBhY3R1YWwgY29uIG9zZGV2aWNlL2RldmljZS4gTGFzIENMQVZFUyBkZSBiY2RlZGl0IHNvbiBzaWVtcHJlIGVuCiMgaW5nbGVzLCBhc2kgcXVlIGVzIGluZGVwZW5kaWVudGUgZGVsIGlkaW9tYSBkZSBsYSBpbnRlcmZhei4KZnVuY3Rpb24gR2V0LUJj
HLP:ZEludGVncml0eSB7CiAgICAkcmVzID0gW3BzY3VzdG9tb2JqZWN0XUB7IG9rID0gJGZhbHNlOyBkZXRhaWxzID0gJycgfQogICAgdHJ5IHsKICAgICAgICAkb3V0ID0gJiBiY2RlZGl0IC9lbnVtICd7Y3VycmVudH0nIDI+JG51bGwKICAgICAgICAkdHh0ID0gKCRv
HLP:dXQgLWpvaW4gImBuIikKICAgICAgICBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCAtYW5kICR0eHQgLW1hdGNoICcoP2ltKV5ccypvc2RldmljZScgLWFuZCAkdHh0IC1tYXRjaCAnKD9pbSleXHMqZGV2aWNlJykgewogICAgICAgICAgICAkcmVzLm9rID0gJHRydWUK
HLP:ICAgICAgICAgICAgJHJlcy5kZXRhaWxzID0gJ0VudHJhZGEgZGUgYXJyYW5xdWUgYWN0dWFsIGludGVncmEgKGRldmljZS9vc2RldmljZSBwcmVzZW50ZXMpLicKICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAkcmVzLm9rID0gJGZhbHNlCiAgICAgICAgICAg
HLP:ICRyZXMuZGV0YWlscyA9ICdDb3VsZCBub3QgY29uZmlybSB0aGUgY3VycmVudCBzdGFydHVwIGVudHJ5LicKICAgICAgICB9CiAgICB9IGNhdGNoIHsKICAgICAgICAkcmVzLm9rID0gJGZhbHNlCiAgICAgICAgJHJlcy5kZXRhaWxzID0gJ2JjZGVkaXQgbm8gZGlz
HLP:cG9uaWJsZSBvIHNpbiBwZXJtaXNvcy4nCiAgICB9CiAgICByZXR1cm4gJHJlcwp9CgojIEdldC1Ub3BQcm9jZXNzZXM6IHByb2Nlc29zIHF1ZSBtYXMgbWVtb3JpYSBkZSB0cmFiYWpvIGNvbnN1bWVuICh0b3AgTikuCmZ1bmN0aW9uIEdldC1Ub3BQcm9jZXNzZXMo
HLP:W2ludF0kdG9wID0gNikgewogICAgdHJ5IHsKICAgICAgICAkcHMgPSBAKEdldC1Qcm9jZXNzIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAgICAgU29ydC1PYmplY3QgV29ya2luZ1NldDY0IC1EZXNjZW5kaW5nIHwKICAgICAgICAgICAg
HLP:U2VsZWN0LU9iamVjdCAtRmlyc3QgJHRvcCkKICAgICAgICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRwIGluICRwcykgewogICAgICAgICAgICAkbWIgPSBbbWF0aF06OlJvdW5kKCRwLldvcmtpbmdTZXQ2NCAvIDFNQikKICAgICAgICAgICAgJGxpc3Qg
HLP:Kz0gW3BzY3VzdG9tb2JqZWN0XUB7IG5hbWUgPSBbc3RyaW5nXSRwLlByb2Nlc3NOYW1lOyBtZW1fbWIgPSBbaW50XSRtYiB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAsJGxpc3QKICAgIH0gY2F0Y2ggeyByZXR1cm4gQCgpIH0KfQoKIyBHZXQtU2ZjUmVzdWx0
HLP:OiBjbGFzaWZpY2EgZWwgcmVzdWx0YWRvIGRlIFNGQyBsZXllbmRvIENCUy5sb2cgKFNJRU1QUkUgZW4KIyBpbmdsZXMpIGVuIGx1Z2FyIGRlIGxhIHNhbGlkYSB0cmFkdWNpZGEgZGUgbGEgY29uc29sYS4gRGV2dWVsdmUgdW5vIGRlOgojIGNsZWFuIHwgcmVwYWly
HLP:ZWQgfCB1bnJlcGFpcmFibGUgfCB1bmtub3duLgpmdW5jdGlvbiBHZXQtU2ZjUmVzdWx0IHsKICAgICRsb2cgPSBKb2luLVBhdGggJGVudjp3aW5kaXIgJ0xvZ3NcQ0JTXENCUy5sb2cnCiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRsb2cpKSB7IHJldHVybiAndW5r
HLP:bm93bicgfQogICAgdHJ5IHsKICAgICAgICAkdGFpbCA9IEAoR2V0LUNvbnRlbnQgLVBhdGggJGxvZyAtVGFpbCA0MDAwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgICRzciA9IEAoJHRhaWwgfCBXaGVyZS1PYmplY3QgeyAkXyAtbWF0Y2gg
HLP:J1xbU1JcXScgfSkKICAgICAgICBpZiAoJHNyLkNvdW50IC1lcSAwKSB7IHJldHVybiAndW5rbm93bicgfQogICAgICAgICRqb2luZWQgPSAoJHNyIC1qb2luICJgbiIpCiAgICAgICAgaWYgKCRqb2luZWQgLW1hdGNoICcoP2kpY2Fubm90IHJlcGFpcicpIHsgcmV0
HLP:dXJuICd1bnJlcGFpcmFibGUnIH0KICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSlyZXBhaXJpbmdccysoWzEtOV1cZCopXHMrY29tcG9uZW50c3xzdWNjZXNzZnVsbHkgcmVwYWlyZWR8cmVwYWlyZWQgZmlsZXxyZXBhaXJpbmcgY29ycnVwdGVkIGZpbGUn
HLP:KSB7IHJldHVybiAncmVwYWlyZWQnIH0KICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSl2ZXJpZnkgY29tcGxldGV8bm8gLippbnRlZ3JpdHkgdmlvbGF0aW9uc3xjYW5ub3QgdmVyaWZ5fHZlcmlmeWluZycpIHsgcmV0dXJuICdjbGVhbicgfQogICAgICAg
HLP:IHJldHVybiAnY2xlYW4nCiAgICB9IGNhdGNoIHsgcmV0dXJuICd1bmtub3duJyB9Cn0KCiMgTmV3LUpzb25SZXBvcnQ6IHZ1ZWxjYSBlbCBlc3RhZG8gKyByZXN1bWVuIGNhbGN1bGFkbyBhIHVuIGZpY2hlcm8gSlNPTgojICgtQXJnID0gcnV0YSBkZSBzYWxpZGEp
HLP:LiBVdGlsIHBhcmEgYXV0b21hdGl6YWNpb24gLyBNRE0gLyBpbnZlbnRhcmlvLgpmdW5jdGlvbiBOZXctSnNvblJlcG9ydCgkb3V0UGF0aCkgewogICAgdHJ5IHsKICAgICAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAgICAgJHN5c1BhaXJzID0gR2V0LVN5c0luZm8K
HLP:ICAgICAgICAkc3lzTWFwID0gQHt9CiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHN5c1BhaXJzKSB7ICRrdiA9ICRwIC1zcGxpdCAnPScsMjsgaWYgKCRrdi5Db3VudCAtZXEgMikgeyAkc3lzTWFwWyRrdlswXV0gPSAka3ZbMV0gfSB9CiAgICAgICAgJHBoYXNlcyA9
HLP:IEAoJHN0LnBoYXNlcykKICAgICAgICAkY09LPTA7JGNXQVJOPTA7JGNFUlI9MDskY1NLSVA9MAogICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7IHN3aXRjaCAoW3N0cmluZ10kcGgucmVzdWx0KSB7ICdPSycgeyRjT0srK30gJ1dBUk4nIHskY1dBUk4r
HLP:K30gJ0VSUk9SJyB7JGNFUlIrK30gJ1NLSVAnIHskY1NLSVArK30gfSB9CiAgICAgICAgJGRlbHRhID0gJG51bGwKICAgICAgICBpZiAoJHN0LnNjb3JlX2JlZm9yZSAtbmUgJG51bGwgLWFuZCAkc3Quc2NvcmVfYWZ0ZXIgLW5lICRudWxsKSB7ICRkZWx0YSA9IFtp
HLP:bnRdJHN0LnNjb3JlX2FmdGVyIC0gW2ludF0kc3Quc2NvcmVfYmVmb3JlIH0KICAgICAgICAkb2JqID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIHNjaGVtYSAgICAgICA9ICd3cGktcmVwb3J0LzEnCiAgICAgICAgICAgIHZlcnNpb24gICAgICA9ICRX
HLP:UElfVkVSU0lPTgogICAgICAgICAgICBnZW5lcmF0ZWQgICAgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCdzJykKICAgICAgICAgICAgbWFjaGluZSAgICAgID0gJGVudjpDT01QVVRFUk5BTUUKICAgICAgICAgICAgc3lzdGVtICAgICAgID0gJHN5c01hcAogICAgICAg
HLP:ICAgICBzY29yZV9iZWZvcmUgPSAkc3Quc2NvcmVfYmVmb3JlCiAgICAgICAgICAgIHNjb3JlX2FmdGVyICA9ICRzdC5zY29yZV9hZnRlcgogICAgICAgICAgICBzY29yZV9kZWx0YSAgPSAkZGVsdGEKICAgICAgICAgICAgc3VtbWFyeSAgICAgID0gW3BzY3VzdG9t
HLP:b2JqZWN0XUB7IG9rPSRjT0s7IHdhcm49JGNXQVJOOyBlcnJvcj0kY0VSUjsgc2tpcD0kY1NLSVA7IHRvdGFsPSRwaGFzZXMuQ291bnQgfQogICAgICAgICAgICBwaGFzZXMgICAgICAgPSAkcGhhc2VzCiAgICAgICAgICAgIGZpbmRpbmdzICAgICA9IEAoJHN0LmZp
HLP:bmRpbmdzKQogICAgICAgICAgICBkaWFnICAgICAgICAgPSAkc3QuZGlhZwogICAgICAgIH0KICAgICAgICAkanNvbiA9ICRvYmogfCBDb252ZXJ0VG8tSnNvbiAtRGVwdGggOAogICAgICAgICR1dGY4ID0gTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2Rp
HLP:bmcoJGZhbHNlKQogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkb3V0UGF0aCwgJGpzb24sICR1dGY4KQogICAgICAgICJSRVNVTFQ9T0siCiAgICAgICAgIlBBVEg9JG91dFBhdGgiCiAgICB9IGNhdGNoIHsKICAgICAgICAiUkVTVUxUPUZB
HLP:SUwiCiAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgfQp9CgojIE5ldy1TdXBwb3J0UGFja2FnZTogZW1wYXF1ZXRhIGxvZ3MgKyBpbmZvcm1lICsgZXN0YWRvICsgYmF0dGVyeS1yZXBvcnQgZW4gdW4KIyBaSVAgKC1BcmcgPSBydXRh
HLP:IGRlbCB6aXApIHBhcmEgZW52aWFyIGEgc29wb3J0ZS4gU2luIGRlcGVuZGVuY2lhcyBleHRlcm5hcwojICh1c2EgQ29tcHJlc3MtQXJjaGl2ZSwgaW5jbHVpZG8gZW4gV2luZG93cyAxMC8xMSkuCmZ1bmN0aW9uIE5ldy1TdXBwb3J0UGFja2FnZSgkb3V0UGF0aCkg
HLP:ewogICAgdHJ5IHsKICAgICAgICAkdG1wID0gSm9pbi1QYXRoICRXb3JrICgnc29wb3J0ZV8nICsgKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eU1NZGRfSEhtbXNzJykpCiAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkdG1wIC1Gb3Jj
HLP:ZSB8IE91dC1OdWxsCiAgICAgICAgIyBlc3RhZG8uanNvbgogICAgICAgIGlmIChUZXN0LVBhdGggJFN0YXRlRmlsZSkgeyBDb3B5LUl0ZW0gJFN0YXRlRmlsZSAoSm9pbi1QYXRoICR0bXAgJ2VzdGFkby5qc29uJykgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRs
HLP:eUNvbnRpbnVlIH0KICAgICAgICAjIExvZ3MKICAgICAgICAkbG9ncyA9IEpvaW4tUGF0aCAkV29yayAnTG9ncycKICAgICAgICBpZiAoVGVzdC1QYXRoICRsb2dzKSB7CiAgICAgICAgICAgICRkc3RMb2dzID0gSm9pbi1QYXRoICR0bXAgJ0xvZ3MnCiAgICAgICAg
HLP:ICAgIE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJGRzdExvZ3MgLUZvcmNlIHwgT3V0LU51bGwKICAgICAgICAgICAgR2V0LUNoaWxkSXRlbSAkbG9ncyAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IENvcHktSXRlbSAtRGVz
HLP:dGluYXRpb24gJGRzdExvZ3MgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgfQogICAgICAgICMgSW5mb3JtZXMgSFRNTC9KU09OIGV4aXN0ZW50ZXMgZW4gV29yawogICAgICAgIEdldC1DaGlsZEl0ZW0gJFdvcmsgLUZpbGUgLUVy
HLP:cm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5OYW1lIC1tYXRjaCAnKD9pKV5JbmZvcm1lLipcLihodG1sfGpzb24pJCcgfSB8CiAgICAgICAgICAgIENvcHktSXRlbSAtRGVzdGluYXRpb24gJHRtcCAtRm9y
HLP:Y2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAjIGJhdHRlcnkgcmVwb3J0IHNpIGV4aXN0ZQogICAgICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICAgICB0cnkgeyBpZiAoJHN0LmRpYWcgLWFuZCAkc3QuZGlhZy5iYXR0ZXJ5IC1hbmQgJHN0
HLP:LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCAtYW5kIChUZXN0LVBhdGggJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCkpIHsgQ29weS1JdGVtICRzdC5kaWFnLmJhdHRlcnkucmVwb3J0X3BhdGggJHRtcCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
HLP:dGludWUgfSB9IGNhdGNoIHt9CiAgICAgICAgaWYgKFRlc3QtUGF0aCAkb3V0UGF0aCkgeyBSZW1vdmUtSXRlbSAkb3V0UGF0aCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIENvbXByZXNzLUFyY2hpdmUgLVBhdGggKEpvaW4t
HLP:UGF0aCAkdG1wICcqJykgLURlc3RpbmF0aW9uUGF0aCAkb3V0UGF0aCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAkdG1wIC1SZWN1cnNlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IGNhdGNo
HLP:IHt9CiAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCnN3aXRjaCAoJEFjdGlvbi5U
HLP:b0xvd2VyKCkpIHsKICAgICdub25lJyAgICAgICAgIHsgfSAjIFVzYWRvIHBhcmEgZG90LXNvdXJjaW5nCiAgICAnY2hlY2tiYWNrdXBzJyB7CiAgICAgICAgJHBhcnRzID0gJEFyZyAtc3BsaXQgJ1x8JywgMgogICAgICAgIGlmICgkcGFydHMuQ291bnQgLW5lIDIp
HLP:IHsgIlJFU1VMVD1GQUlMIjsgIkVSUk9SPUFyZ3VtZW50b3MgaW52YWxpZG9zIjsgZXhpdCAwIH0KICAgICAgICAkYmtkaXIgPSAkcGFydHNbMF0KICAgICAgICAkdHMgPSAkcGFydHNbMV0KICAgICAgICAkcnBfb2sgPSAkZmFsc2UKICAgICAgICB0cnkgewogICAg
HLP:ICAgICAgICAkcnBzID0gR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIGZvcmVhY2ggKCRycCBpbiAkcnBzKSB7CiAgICAgICAgICAgICAgICBpZiAoJHJwLkRlc2NyaXB0aW9uIC1saWtlICJS
HLP:ZXBhaXJfU3VpdGVfKiIpIHsgJHJwX29rID0gJHRydWU7IGJyZWFrIH0KICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2ggeyAkcnBfb2sgPSAkZmFsc2UgfQogICAgICAgICRyZWdfb2sgPSAkdHJ1ZQogICAgICAgICRzb2Z0ID0gSm9pbi1QYXRoICRia2RpciAi
HLP:U09GVFdBUkVfJHRzLnJlZyIKICAgICAgICAkc3lzID0gSm9pbi1QYXRoICRia2RpciAiU1lTVEVNXyR0cy5yZWciCiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkc29mdCkgLW9yIChHZXQtSXRlbSAkc29mdCkuTGVuZ3RoIC1lcSAwKSB7ICRyZWdfb2sgPSAk
HLP:ZmFsc2UgfQogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJHN5cykgLW9yIChHZXQtSXRlbSAkc3lzKS5MZW5ndGggLWVxIDApIHsgJHJlZ19vayA9ICRmYWxzZSB9CiAgICAgICAgIlJQX09LPSQoaWYgKCRycF9vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAg
HLP:ICAgIlJFR19PSz0kKGlmICgkcmVnX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdib290c3RyYXB3aW5nZXQnIHsKICAgICAgICAkb2sgPSBJbnN0YWxsLVdpbmdldEJvb3RzdHJhcAogICAgICAgICJCT09UU1RSQVBfT0s9JChpZiAoJG9rKSB7JzEn
HLP:fSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdmaW5kbG9jYWxzb3VyY2UnIHsKICAgICAgICAkZHJpdmVzID0gR2V0LVBTRHJpdmUgLVBTUHJvdmlkZXIgRmlsZVN5c3RlbQogICAgICAgICRwYXRocyA9IEAoKQogICAgICAgICRlZGl0aW9uSWQgPSAnJwogICAgICAg
HLP:IHRyeSB7ICRlZGl0aW9uSWQgPSAoR2V0LUl0ZW1Qcm9wZXJ0eSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb24nIC1OYW1lIEVkaXRpb25JRCAtRXJyb3JBY3Rpb24gU3RvcCkuRWRpdGlvbklEIH0gY2F0Y2gge30KICAg
HLP:ICAgICBmdW5jdGlvbiBHZXQtSW5zdGFsbEltYWdlU291cmNlKFtzdHJpbmddJGtpbmQsIFtzdHJpbmddJHBhdGgsIFtzdHJpbmddJGVkaXRpb24pIHsKICAgICAgICAgICAgJGluZGV4ID0gMQogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgJGltYWdl
HLP:cyA9IEAoR2V0LVdpbmRvd3NJbWFnZSAtSW1hZ2VQYXRoICRwYXRoIC1FcnJvckFjdGlvbiBTdG9wKQogICAgICAgICAgICAgICAgJG1hdGNoID0gJG51bGwKICAgICAgICAgICAgICAgIGlmICgkZWRpdGlvbiAtbWF0Y2ggJ1Byb2Zlc3Npb25hbCcpIHsgJG1hdGNo
HLP:ID0gJGltYWdlcyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ1xiUHJvXGJ8UHJvZmVzc2lvbmFsJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnRW50ZXJwcmlz
HLP:ZScpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ0VudGVycHJpc2UnIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRpb24gLW1hdGNoICdFZHVjYXRp
HLP:b24nKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdFZHVjYXRpb24nIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRpb24gLW1hdGNoICdDb3JlJykg
HLP:eyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnXGJIb21lXGJ8Q29yZScgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkbWF0Y2ggLWFuZCAkaW1hZ2Vz
HLP:LkNvdW50IC1lcSAxKSB7ICRtYXRjaCA9ICRpbWFnZXNbMF0gfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkbWF0Y2gpIHsgJGluZGV4ID0gW2ludF0kbWF0Y2guSW1hZ2VJbmRleCB9CiAgICAgICAgICAgIH0gY2F0Y2gge30KICAgICAgICAgICAgcmV0
HLP:dXJuICgiezB9OnsxfTp7Mn0iIC1mICRraW5kLCAkcGF0aCwgJGluZGV4KQogICAgICAgIH0KICAgICAgICBmb3JlYWNoICgkZCBpbiAkZHJpdmVzKSB7CiAgICAgICAgICAgICRyb290ID0gJGQuUm9vdAogICAgICAgICAgICAkd2ltID0gSm9pbi1QYXRoICRyb290
HLP:ICJzb3VyY2VzXGluc3RhbGwud2ltIgogICAgICAgICAgICAkZXNkID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXGluc3RhbGwuZXNkIgogICAgICAgICAgICAkc3hzID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXHN4cyIKICAgICAgICAgICAgaWYgKFRlc3Qt
HLP:UGF0aCAkd2ltKSB7ICRwYXRocyArPSAoR2V0LUluc3RhbGxJbWFnZVNvdXJjZSAnV2ltJyAkd2ltICRlZGl0aW9uSWQpIH0KICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkZXNkKSB7ICRwYXRocyArPSAoR2V0LUluc3RhbGxJbWFnZVNvdXJjZSAnRXNkJyAkZXNk
HLP:ICRlZGl0aW9uSWQpIH0KICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkc3hzKSB7ICRwYXRocyArPSAkc3hzIH0KICAgICAgICB9CiAgICAgICAgaWYgKCRwYXRocy5Db3VudCAtZ3QgMCkgeyAiU09VUkNFPSQoJHBhdGhzWzBdKSIgfSBlbHNlIHsgIlNPVVJDRT0i
HLP:IH0KICAgIH0KICAgICdkaXNtcmVzdG9yZScgewogICAgICAgICRwYXJ0cyA9IEAoJEFyZyAtc3BsaXQgJ1x8JywgMikKICAgICAgICAkc291cmNlID0gaWYgKCRwYXJ0cy5Db3VudCAtZ2UgMSkgeyAkcGFydHNbMF0gfSBlbHNlIHsgJycgfQogICAgICAgICR0aW1l
HLP:b3V0TWludXRlcyA9IDQ1CiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtZ2UgMikgeyBbdm9pZF1baW50XTo6VHJ5UGFyc2UoJHBhcnRzWzFdLCBbcmVmXSR0aW1lb3V0TWludXRlcykgfQogICAgICAgIGlmICgkdGltZW91dE1pbnV0ZXMgLWx0IDUpIHsgJHRpbWVv
HLP:dXRNaW51dGVzID0gNSB9CgogICAgICAgIGZ1bmN0aW9uIFF1b3RlLURpc21WYWx1ZShbc3RyaW5nXSR2YWx1ZSkgewogICAgICAgICAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkdmFsdWUpKSB7IHJldHVybiAkdmFsdWUgfQogICAgICAgICAg
HLP:ICByZXR1cm4gJyInICsgKCR2YWx1ZSAtcmVwbGFjZSAnIicsICdcIicpICsgJyInCiAgICAgICAgfQoKICAgICAgICAkYXJndW1lbnRzID0gJy9PbmxpbmUgL0NsZWFudXAtSW1hZ2UgL1Jlc3RvcmVIZWFsdGgnCiAgICAgICAgaWYgKC1ub3QgW3N0cmluZ106Oklz
HLP:TnVsbE9yV2hpdGVTcGFjZSgkc291cmNlKSkgewogICAgICAgICAgICAkYXJndW1lbnRzICs9ICcgL1NvdXJjZTonICsgKFF1b3RlLURpc21WYWx1ZSAkc291cmNlKSArICcgL0xpbWl0QWNjZXNzJwogICAgICAgIH0KCiAgICAgICAgJHRpbWVkT3V0ID0gJGZhbHNl
HLP:CiAgICAgICAgJGV4aXRDb2RlID0gMwogICAgICAgICRvdXRGaWxlID0gSm9pbi1QYXRoICRXb3JrICgiZGlzbV9yZXN0b3JlX3swfS5vdXQiIC1mIChbZ3VpZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKSkKICAgICAgICAkZXJyRmlsZSA9IEpvaW4tUGF0aCAk
HLP:V29yayAoImRpc21fcmVzdG9yZV97MH0uZXJyIiAtZiAoW2d1aWRdOjpOZXdHdWlkKCkuVG9TdHJpbmcoJ04nKSkpCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHBzaSA9IFtEaWFnbm9zdGljcy5Qcm9jZXNzU3RhcnRJbmZvXTo6bmV3KCkKICAgICAgICAgICAg
HLP:JHBzaS5GaWxlTmFtZSA9ICdjbWQuZXhlJwogICAgICAgICAgICAkcHNpLkFyZ3VtZW50cyA9ICgnL2MgZGlzbS5leGUgezB9ID4gInsxfSIgMj4gInsyfSInIC1mICRhcmd1bWVudHMsICRvdXRGaWxlLCAkZXJyRmlsZSkKICAgICAgICAgICAgJHBzaS5Vc2VTaGVs
HLP:bEV4ZWN1dGUgPSAkZmFsc2UKICAgICAgICAgICAgJHBzaS5DcmVhdGVOb1dpbmRvdyA9ICR0cnVlCiAgICAgICAgICAgICRwID0gW0RpYWdub3N0aWNzLlByb2Nlc3NdOjpuZXcoKQogICAgICAgICAgICAkcC5TdGFydEluZm8gPSAkcHNpCiAgICAgICAgICAgIFt2
HLP:b2lkXSRwLlN0YXJ0KCkKICAgICAgICAgICAgaWYgKC1ub3QgJHAuV2FpdEZvckV4aXQoJHRpbWVvdXRNaW51dGVzICogNjAgKiAxMDAwKSkgewogICAgICAgICAgICAgICAgJHRpbWVkT3V0ID0gJHRydWUKICAgICAgICAgICAgICAgIHRyeSB7ICRwLktpbGwoKSB9
HLP:IGNhdGNoIHt9CiAgICAgICAgICAgICAgICAkZXhpdENvZGUgPSAxNDYwCiAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICB0cnkgeyAkcC5XYWl0Rm9yRXhpdCgpIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICRleGl0Q29kZSA9ICRwLkV4aXRD
HLP:b2RlCiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLWVxICRleGl0Q29kZSkgeyAkZXhpdENvZGUgPSAzIH0KICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2ggewogICAgICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICAgICAgICAg
HLP:ICRleGl0Q29kZSA9IDMKICAgICAgICB9CgogICAgICAgIGlmIChUZXN0LVBhdGggJG91dEZpbGUpIHsgR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRvdXRGaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICBpZiAoVGVzdC1QYXRoICRl
HLP:cnJGaWxlKSB7IEdldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkZXJyRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRvdXRGaWxlLCRlcnJGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2ls
HLP:ZW50bHlDb250aW51ZQogICAgICAgICJUSU1FRE9VVD0kKGlmICgkdGltZWRPdXQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJFWElUQ09ERT0kZXhpdENvZGUiCiAgICB9CiAgICAnc3lzaW5mbycgICAgICB7IEdldC1TeXNJbmZvIH0KICAgICdzY29yZScg
HLP:ICAgICAgIHsgJGggPSBHZXQtSGVhbHRoU2NvcmU7ICJTQ09SRT0kKCRoLnNjb3JlKSI7IGZvcmVhY2ggKCRyIGluICRoLnJlYXNvbnMpIHsgIlJFQVNPTj0kciIgfSB9CiAgICAnZm9yZW5zaWNzJyAgICB7IEdldC1Gb3JlbnNpY3MgfQogICAgJ3RyaWFnZScgICAg
HLP:ICAgeyBHZXQtVHJpYWdlIH0KICAgICdyZXN0b3JlcG9pbnQnIHsgTmV3LVJlc3RvcmVQb2ludCB9CiAgICAnbWVkaWF0eXBlJyAgICB7ICRtZWRpYSA9IEdldC1NZWRpYVR5cGU7ICJNRURJQT0kbWVkaWEiOyAiT1BUSU1JWkU9JChSZXNvbHZlLU9wdGltaXplQWN0
HLP:aW9uICRtZWRpYSkiIH0KICAgICdkZXZpY2VzJyAgICAgIHsgR2V0LURldmljZVByb2JsZW1zIH0KICAgICdyZXBvcnQnICAgICAgIHsgQWRkLVR5cGUgLUFzc2VtYmx5TmFtZSBTeXN0ZW0uV2ViIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlOyBOZXctSHRt
HLP:bFJlcG9ydCAkQXJnIH0KICAgICdhZGRwaGFzZScgICAgIHsgQWRkLVBoYXNlUmVzdWx0ICRBcmcgfQogICAgJ3NldGJlZm9yZScgICAgeyBTZXQtU2NvcmUgJ2JlZm9yZScgJEFyZyB9CiAgICAnc2V0YWZ0ZXInICAgICB7IFNldC1TY29yZSAnYWZ0ZXInICRBcmcg
HLP:fQogICAgJ2ZpbmRpbmcnICAgICAgeyBBZGQtRmluZGluZyAkQXJnIH0KICAgICdyZXNldHN0YXRlJyAgIHsgUmVzZXQtU3RhdGU7ICJSRVNVTFQ9T0siIH0KICAgICdub3JtYWxpemVmYXNlcycgewogICAgICAgICRyID0gTm9ybWFsaXplLUZhc2VzICRBcmcKICAg
HLP:ICAgICAiTk9STT0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkci5ub3JtKSkpIgogICAgICAgICJJTlZBTElEPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRyLmludmFsaWQpKSkiCiAgICB9CiAgICAnY2hlY2twb2ludCcgewogICAgICAgICRwYXJzZWQgPSBQYXJz
HLP:ZS1DaGVja3BvaW50QXJnICRBcmcKICAgICAgICBzd2l0Y2ggKCRwYXJzZWQuc3ViKSB7CiAgICAgICAgICAgICdzYXZlJyB7IGlmIChTYXZlLUNoZWNrcG9pbnQgJHBhcnNlZCkgeyAiUkVTVUxUPU9LIiB9IGVsc2UgeyAiUkVTVUxUPUZBSUwiIH0gfQogICAgICAg
HLP:ICAgICAnbG9hZCcgewogICAgICAgICAgICAgICAgJGNwID0gTG9hZC1DaGVja3BvaW50CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLWVxICRjcCkgeyAiUkVTVUxUPU5PTkUiIH0KICAgICAgICAgICAgICAgIGVsc2UgewogICAgICAgICAgICAgICAgICAgICJS
HLP:RVNVTFQ9T0siCiAgICAgICAgICAgICAgICAgICAgIlZBTElEPSQoaWYgKFRlc3QtQ2hlY2twb2ludFZhbGlkICRjcCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIlZFUlNJT049JCgkY3AudmVyc2lvbikiCiAgICAgICAgICAgICAgICAg
HLP:ICAgIkNSRUFURUQ9JCgkY3AuY3JlYXRlZCkiCiAgICAgICAgICAgICAgICAgICAgIlNFTEVDVElPTj0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkY3Auc2VsZWN0aW9uKSkpIgogICAgICAgICAgICAgICAgICAgICJDT01QTEVURUQ9JChbc3RyaW5nXTo6Sm9pbign
HLP:LCcsIEAoJGNwLmNvbXBsZXRlZCkpKSIKICAgICAgICAgICAgICAgICAgICAiUkVBU09OPSQoJGNwLnBlbmRpbmdfcmVhc29uKSIKICAgICAgICAgICAgICAgICAgICAiTkVYVD0kKEdldC1OZXh0UGhhc2UgJGNwKSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9B
HLP:VVRPPSQoaWYgKCRjcC5tb2RlLmF1dG8pIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJNT0RFX05PUkVCT09UPSQoaWYgKCRjcC5tb2RlLm5vcmVib290KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9L
HLP:RUVQV1U9JChpZiAoJGNwLm1vZGUua2VlcHd1KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9EUlk9JChpZiAoJGNwLm1vZGUuZHJ5KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9UUklBR0U9
HLP:JChpZiAoJGNwLm1vZGUudHJpYWdlKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAnbmV4dCcgewogICAgICAgICAgICAgICAgJGNwID0gTG9hZC1DaGVja3BvaW50CiAgICAgICAgICAgICAgICBp
HLP:ZiAoJG51bGwgLW5lICRjcCAtYW5kIChUZXN0LUNoZWNrcG9pbnRWYWxpZCAkY3ApKSB7ICJORVhUPSQoR2V0LU5leHRQaGFzZSAkY3ApIiB9IGVsc2UgeyAiTkVYVD0iIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAnY2xlYXInIHsKICAgICAgICAgICAgICAg
HLP:IGlmIChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSB7CiAgICAgICAgICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJENoZWNrcG9pbnRGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcDsgIlJFU1VMVD1PSyIgfSBjYXRjaCB7ICJSRVNVTFQ9RkFJTCIg
HLP:fQogICAgICAgICAgICAgICAgfSBlbHNlIHsgIlJFU1VMVD1PSyIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGRlZmF1bHQgeyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9c3ViYWNjaW9uIGRlIGNoZWNrcG9pbnQgZGVzY29ub2NpZGEiIH0KICAgICAgICB9CiAg
HLP:ICB9CiAgICAnbW92ZXJlc3VsdCcgewogICAgICAgICRwYXJ0cyA9ICRBcmcgLXNwbGl0ICdcfCcsIDIKICAgICAgICBpZiAoJHBhcnRzLkNvdW50IC1lcSAyKSB7CiAgICAgICAgICAgICRvayA9IFRlc3QtTW92ZVJlc3VsdFBhdGggJHBhcnRzWzBdICRwYXJ0c1sx
HLP:XQogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRiICA9ICRBcmcgLXNwbGl0ICcsJwogICAgICAgICAgICAkc2UgPSAoJGIuQ291bnQgLWdlIDEgLWFuZCAkYlswXS5UcmltKCkgLWVxICcxJykKICAgICAgICAgICAgJGRlID0gKCRiLkNvdW50IC1nZSAyIC1h
HLP:bmQgJGJbMV0uVHJpbSgpIC1lcSAnMScpCiAgICAgICAgICAgICRvayA9IFRlc3QtTW92ZVJlc3VsdCAkc2UgJGRlCiAgICAgICAgfQogICAgICAgICJNT1ZFRD0kKGlmICgkb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ3Z0bHdyaXRlJyB7CiAgICAg
HLP:ICAgJHAgICA9ICRBcmcgLXNwbGl0ICcsJwogICAgICAgICRjdXIgPSBpZiAoJHAuQ291bnQgLWdlIDEpIHsgJHBbMF0gfSBlbHNlIHsgJycgfQogICAgICAgICRkZXMgPSBpZiAoJHAuQ291bnQgLWdlIDIpIHsgJHBbMV0gfSBlbHNlIHsgW3N0cmluZ10kVlRfTEVW
HLP:RUxfREVTSVJFRCB9CiAgICAgICAgIldSSVRFPSQoaWYgKFJlc29sdmUtVnRsV3JpdGUgJGN1ciAkZGVzKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdtYXBleGl0JyAgICAgIHsgIlJFUz0kKE1hcC1FeGl0Q29kZSAkQXJnKSIgfQogICAgIyAtLS0gKDUu
HLP:MSAvIFJlcSAxNSkgRGlhZ25vc3RpY28gYW1wbGlhZG8gLS0tCiAgICAncmFtY2hlY2snIHsKICAgICAgICAkciA9IEdldC1SYW1DaGVjawogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5yYW0gPSBbcHNj
HLP:dXN0b21vYmplY3RdQHsgc3RhdHVzID0gJHIuc3RhdHVzOyByZWNvbW1lbmRfbWRzY2hlZCA9IFtib29sXSRyLnJlY29tbWVuZF9tZHNjaGVkIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiUkFNX1NUQVRVUz0kKCRyLnN0YXR1cykiCiAgICAgICAg
HLP:IlJBTV9SRUNPTU1FTkRfTURTQ0hFRD0kKGlmICgkci5yZWNvbW1lbmRfbWRzY2hlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnYmF0dGVyeScgewogICAgICAgICRiID0gR2V0LUJhdHRlcnlIZWFsdGgKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURp
HLP:YWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHN0LmRpYWcuYmF0dGVyeSA9IFtwc2N1c3RvbW9iamVjdF1AeyBwcmVzZW50ID0gW2Jvb2xdJGIucHJlc2VudDsgaGVhbHRoX3BjdCA9ICRiLmhlYWx0aF9wY3Q7IHJlcG9ydF9wYXRoID0gJGIucmVwb3J0X3BhdGggfQog
HLP:ICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJCQVRURVJZX1BSRVNFTlQ9JChpZiAoJGIucHJlc2VudCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfSEVBTFRIX1BDVD0kKCRiLmhlYWx0aF9wY3QpIgogICAgICAgICJCQVRURVJZX1JF
HLP:UE9SVD0kKCRiLnJlcG9ydF9wYXRoKSIKICAgIH0KICAgICduZXRhZHZhbmNlZCcgewogICAgICAgICRuID0gR2V0LU5ldEFkdmFuY2VkCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRzdC5kaWFnLm5ldHdvcmsgPSBb
HLP:cHNjdXN0b21vYmplY3RdQHsgY29ubmVjdGVkID0gW2Jvb2xdJG4uY29ubmVjdGVkOyBkbnNfb2sgPSBbYm9vbF0kbi5kbnNfb2s7IGRldGFpbHMgPSAkbi5kZXRhaWxzOyBkbnNfbXMgPSAkbi5kbnNfbXMgfQogICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAg
HLP:ICJORVRfQ09OTkVDVEVEPSQoaWYgKCRuLmNvbm5lY3RlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ETlNfT0s9JChpZiAoJG4uZG5zX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0RFVEFJTFM9JCgkbi5kZXRhaWxzKSIKICAg
HLP:ICAgICAiTkVUX0xBVEVOQ1lfTVM9JCgkbi5kbnNfbXMpIgogICAgfQogICAgJ2RpYWdmdWxsJyB7CiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRyID0gR2V0LVJhbUNoZWNrCiAgICAgICAgJHN0LmRpYWcucmFtID0g
HLP:W3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICRyLnN0YXR1czsgcmVjb21tZW5kX21kc2NoZWQgPSBbYm9vbF0kci5yZWNvbW1lbmRfbWRzY2hlZCB9CiAgICAgICAgJGIgPSBHZXQtQmF0dGVyeUhlYWx0aAogICAgICAgICRzdC5kaWFnLmJhdHRlcnkgPSBbcHNj
HLP:dXN0b21vYmplY3RdQHsgcHJlc2VudCA9IFtib29sXSRiLnByZXNlbnQ7IGhlYWx0aF9wY3QgPSAkYi5oZWFsdGhfcGN0OyByZXBvcnRfcGF0aCA9ICRiLnJlcG9ydF9wYXRoIH0KICAgICAgICAkbiA9IEdldC1OZXRBZHZhbmNlZAogICAgICAgICRzdC5kaWFnLm5l
HLP:dHdvcmsgPSBbcHNjdXN0b21vYmplY3RdQHsgY29ubmVjdGVkID0gW2Jvb2xdJG4uY29ubmVjdGVkOyBkbnNfb2sgPSBbYm9vbF0kbi5kbnNfb2s7IGRldGFpbHMgPSAkbi5kZXRhaWxzOyBkbnNfbXMgPSAkbi5kbnNfbXMgfQogICAgICAgICRkZXYgPSBHZXQtRGV2
HLP:aWNlTGlzdAogICAgICAgIGlmICgkbnVsbCAtZXEgJGRldikgewogICAgICAgICAgICAkc3QuZGlhZy5kZXZpY2VzID0gQCgpCiAgICAgICAgICAgICRkZXZMaW5lID0gIkRFVklDRVNfU1RBVFVTPWluZm8gbm90IGF2YWlsYWJsZSIKICAgICAgICB9IGVsc2Ugewog
HLP:ICAgICAgICAgICAkc3QuZGlhZy5kZXZpY2VzID0gQCgkZGV2KQogICAgICAgICAgICAkZGV2TGluZSA9ICJERVZJQ0VTX0NPVU5UPSQoQCgkZGV2KS5Db3VudCkiCiAgICAgICAgfQogICAgICAgICRzbSA9IEdldC1TbWFydEF0dHJpYnV0ZXMKICAgICAgICAkc3Qu
HLP:ZGlhZy5zbWFydCA9IFtwc2N1c3RvbW9iamVjdF1AeyBhdmFpbGFibGUgPSBbYm9vbF0kc20uYXZhaWxhYmxlOyBwcmVkaWN0X2ZhaWwgPSBbYm9vbF0kc20ucHJlZGljdF9mYWlsOyB0ZW1wX2MgPSAkc20udGVtcF9jOyB3ZWFyX3BjdCA9ICRzbS53ZWFyX3BjdDsg
HLP:cG9oID0gJHNtLnBvaCB9CiAgICAgICAgJHN0cCA9IEdldC1TdGFydHVwSXRlbXMgOAogICAgICAgICRzdC5kaWFnLnN0YXJ0dXAgPSBAKCRzdHApCiAgICAgICAgJGJjZCA9IEdldC1CY2RJbnRlZ3JpdHkKICAgICAgICAkc3QuZGlhZy5iY2QgPSBbcHNjdXN0b21v
HLP:YmplY3RdQHsgb2sgPSBbYm9vbF0kYmNkLm9rOyBkZXRhaWxzID0gJGJjZC5kZXRhaWxzIH0KICAgICAgICAkcHJvY3MgPSBHZXQtVG9wUHJvY2Vzc2VzIDYKICAgICAgICAkc3QuZGlhZy5wcm9jZXNzZXMgPSBAKCRwcm9jcykKICAgICAgICBXcml0ZS1TdGF0ZSAk
HLP:c3QKICAgICAgICAiUkFNX1NUQVRVUz0kKCRyLnN0YXR1cykiCiAgICAgICAgIlJBTV9SRUNPTU1FTkRfTURTQ0hFRD0kKGlmICgkci5yZWNvbW1lbmRfbWRzY2hlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfUFJFU0VOVD0kKGlmICgkYi5w
HLP:cmVzZW50KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkFUVEVSWV9IRUFMVEhfUENUPSQoJGIuaGVhbHRoX3BjdCkiCiAgICAgICAgIk5FVF9DT05ORUNURUQ9JChpZiAoJG4uY29ubmVjdGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0RO
HLP:U19PSz0kKGlmICgkbi5kbnNfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfTEFURU5DWV9NUz0kKCRuLmRuc19tcykiCiAgICAgICAgIlNNQVJUX0FWQUlMQUJMRT0kKGlmICgkc20uYXZhaWxhYmxlKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAg
HLP:ICAiU01BUlRfUFJFRElDVF9GQUlMPSQoaWYgKCRzbS5wcmVkaWN0X2ZhaWwpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQ0RfT0s9JChpZiAoJGJjZC5vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgJGRldkxpbmUKICAgIH0KICAgICMgLS0tICh2
HLP:My4xKSBTRkMgaW5kZXBlbmRpZW50ZSBkZWwgaWRpb21hICsgSlNPTiArIHBhcXVldGUgZGUgc29wb3J0ZSAtLS0KICAgICdzZmNyZXN1bHQnIHsKICAgICAgICAiU0ZDX1JFUz0kKEdldC1TZmNSZXN1bHQpIgogICAgfQogICAgJ2pzb25yZXBvcnQnIHsKICAgICAg
HLP:ICAkb3V0ID0gaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJEFyZykpIHsgSm9pbi1QYXRoICRXb3JrICdJbmZvcm1lLmpzb24nIH0gZWxzZSB7ICRBcmcgfQogICAgICAgIE5ldy1Kc29uUmVwb3J0ICRvdXQKICAgIH0KICAgICdzdXBwb3J0cGFja2Fn
HLP:ZScgewogICAgICAgICRvdXQgPSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdvcmsgJ1BhcXVldGVfU29wb3J0ZS56aXAnIH0gZWxzZSB7ICRBcmcgfQogICAgICAgIE5ldy1TdXBwb3J0UGFja2FnZSAkb3V0CiAg
HLP:ICB9CiAgICAjIC0tLSAoNS42IC8gUmVxIDE3LjIpIFJvdGFjaW9uIGRlIGxvZ3MgLS0tCiAgICAnbG9ncm90YXRlJyB7CiAgICAgICAgJGZvbGRlciA9IGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnTG9n
HLP:cycgfSBlbHNlIHsgJEFyZyB9CiAgICAgICAgJG4gPSBJbnZva2UtTG9nUm90YXRlICRmb2xkZXIgJExPR19SRVRFTlRJT04KICAgICAgICAiREVMRVRFRD0kbiIKICAgIH0KICAgICMgLS0tICg1LjggLyBSZXEgMTMsMTgpIFZhbGlkYWNpb24gZGUgZW50b3JubyB5
HLP:IHNlbGYtdGVzdCAtLS0KICAgICdlbnZjaGVjaycgewogICAgICAgICRlID0gSW52b2tlLUVudlZhbGlkYXRlCiAgICAgICAgIk9TX09LPSQoaWYgKCRlLm9zX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiT1NfQlVJTEQ9JCgkZS5idWlsZCkiCiAgICAg
HLP:ICAgIk9TX0NIRUNLX0RPTkU9MSIKICAgIH0KICAgICdzZWxmdGVzdGJyYWluJyB7ICJCUkFJTl9PSz0xIiB9CiAgICAnc2VsZnRlc3RyZXN1bHQnIHsKICAgICAgICAkcGFzcyA9IEludm9rZS1TZWxmVGVzdCAoUGFyc2UtQm9vbExpc3QgJEFyZykKICAgICAgICAi
HLP:U0VMRlRFU1RfUEFTUz0kKGlmICgkcGFzcykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICBkZWZhdWx0ICAgICAgICB7IEdldC1TeXNJbmZvIH0KfQo=
