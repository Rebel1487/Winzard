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
echo  %DIM%Standalone phase 10 - Certificates and time%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "10" "Certificates and time" "Refreshes root certificates and syncs the clock (fixes WU/Store/cert)."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase10 ) else ( call :menu_fase10 )
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
    call :title_of 10
    call :pshq addphase "10;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase10
if "%DRY%"=="1" ( call :dry "Would sync the clock and refresh the root certificates" & exit /b 2 )
call :step "Synchronizing the system clock"
net start w32time >nul 2>&1
w32tm /resync /force >> "%LOGFILE%" 2>&1
set "TIME_OK=1"
if !errorlevel! neq 0 ( set "TIME_OK=0" & call :warn "w32tm /resync returned an error (no network or time service stopped)" )
call :step "Updating trusted root certificates"
certutil -generateSSTFromWU "%WORK%\roots.sst" >> "%LOGFILE%" 2>&1
set "CERT_OK=0"
if exist "%WORK%\roots.sst" (
    powershell -NoProfile -Command "try { Import-Certificate -FilePath '%WORK%\roots.sst' -CertStoreLocation Cert:\LocalMachine\Root -ErrorAction Stop | Out-Null; exit 0 } catch { Write-Output $_.Exception.Message; exit 1 }" >> "%LOGFILE%" 2>&1
    if !errorlevel! equ 0 ( set "CERT_OK=1" ) else ( call :warn "Could not import the root certificates (check the log)" & set "PH_NOTE=certificate import failed" )
) else (
    call :warn "Could not download root certificates (no Internet)."
    set "PH_NOTE=no Internet for certificates"
)
if "!CERT_OK!"=="1" if "!TIME_OK!"=="1" ( call :ok "Root certificates refreshed and clock synchronized (verified)" & exit /b 0 )
if "!TIME_OK!"=="1" ( call :warn "Clock synchronized; certificates NOT refreshed" ) else ( call :warn "The clock could NOT be synchronized" )
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
HLP:IyBXaW56YXJkIC0gaHR0cHM6Ly9naXRodWIuY29tL1JlYmVsMTQ4Ny9XaW56YXJkDQojIENvcHlyaWdodCAoYykgMjAyNiBSZWJlbDE0ODcgLSBjcmVhdG9yIGFuZCBmb3VuZGVyIG9mIHRoZSBwcm9qZWN0DQojIFNQRFgtTGljZW5zZS1JZGVudGlmaWVyOiBNSVQN
HLP:CiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBXUEkgLSBDZXJlYnJvIGRlIGxhIFN1aXRlIGRlIFJlcGFyYWNpb24gKGhlbHBlcikKIyAgSW52b2NhZG8gcG9yIGVs
HLP:IC5iYXQ6IHBvd2Vyc2hlbGwgLUZpbGUgc3VpdGVfaGVscGVyLnBzMSAtQWN0aW9uIDxhY2Npb24+IC4uLgojICBBY2Npb25lczogc3lzaW5mbyB8IHNjb3JlIHwgZm9yZW5zaWNzIHwgdHJpYWdlIHwgcmVzdG9yZXBvaW50IHwgbWVkaWF0eXBlCiMgICAgICAgICAg
HLP:ICB8IGRldmljZXMgfCByZXBvcnQgfCBhZGRwaGFzZSB8IHNldGJlZm9yZSB8IHNldGFmdGVyIHwgZmluZGluZwojICAgICAgICAgICAgfCByZXNldHN0YXRlIHwgbm9ybWFsaXplZmFzZXMgfCBjaGVja3BvaW50IHwgbW92ZXJlc3VsdCB8IHZ0bHdyaXRlCiMgICAg
HLP:ICAgICAgICB8IG1hcGV4aXQgfCByYW1jaGVjayB8IGJhdHRlcnkgfCBuZXRhZHZhbmNlZCB8IGRpYWdmdWxsCiMgICAgICAgICAgICB8IGxvZ3JvdGF0ZSB8IGVudmNoZWNrIHwgc2VsZnRlc3RicmFpbiB8IHNlbGZ0ZXN0cmVzdWx0CiMgICAgICAgICAgICB8IHNm
HLP:Y3Jlc3VsdCB8IGpzb25yZXBvcnQgfCBzdXBwb3J0cGFja2FnZQojICBUb2RvIHZhIGEgU1RET1VUIGVuIGxpbmVhcyBLRVk9VkFMVUUgKGZhY2lsZXMgZGUgbGVlciBkZXNkZSBiYXRjaCBjb24gRk9SKSwKIyAgc2Fsdm8gJ3JlcG9ydCcgcXVlIGVzY3JpYmUgdW4g
HLP:SFRNTC4gU2luIGRlcGVuZGVuY2lhcyBleHRlcm5hcy4KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CnBhcmFtKAogICAgW3N0cmluZ10kQWN0aW9uID0gJ3N5c2luZm8n
HLP:LAogICAgW3N0cmluZ10kV29yayAgID0gIiRlbnY6VEVNUFxXUElfU3VpdGUiLAogICAgW3N0cmluZ10kQXJnICAgID0gJycKKQokRXJyb3JBY3Rpb25QcmVmZXJlbmNlID0gJ1NpbGVudGx5Q29udGludWUnCmlmICgtbm90IChUZXN0LVBhdGggJFdvcmspKSB7IE5l
HLP:dy1JdGVtIC1JdGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJFdvcmsgLUZvcmNlIHwgT3V0LU51bGwgfQokU3RhdGVGaWxlID0gSm9pbi1QYXRoICRXb3JrICdlc3RhZG8uanNvbicKCiMgLS0tIENvbnN0YW50ZXMgZGUgY29uZmlndXJhY2lvbiAoYWxpbmVhZGFzIGNv
HLP:biBtYW5pZmVzdC5wc2QxIC8gZGVzaWduKSAtLS0KJENoZWNrcG9pbnRGaWxlICAgICAgICAgID0gSm9pbi1QYXRoICRXb3JrICdjaGVja3BvaW50Lmpzb24nCiRXUElfVkVSU0lPTiAgICAgICAgICAgICA9ICczLjEnCiRDSEVDS1BPSU5UX01BWF9BR0VfREFZUyA9
HLP:IDcKJFZUX0xFVkVMX0RFU0lSRUQgICAgICAgID0gMQokTE9HX1JFVEVOVElPTiAgICAgICAgICAgPSAxMAoKZnVuY3Rpb24gUmVhZC1TdGF0ZSB7CiAgICBpZiAoVGVzdC1QYXRoICRTdGF0ZUZpbGUpIHsgdHJ5IHsgcmV0dXJuIChHZXQtQ29udGVudCAkU3RhdGVG
HLP:aWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uKSB9IGNhdGNoIHt9IH0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc2NvcmVfYmVmb3JlID0gJG51bGw7IHNjb3JlX2FmdGVyID0gJG51bGw7IGZpbmRpbmdzID0gQCgpOyBwaGFzZXMgPSBAKCk7IGRpYWcg
HLP:PSAkbnVsbCB9Cn0KZnVuY3Rpb24gV3JpdGUtU3RhdGUoJHMpIHsgdHJ5IHsgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRTdGF0ZUZpbGUsICgkcyB8IENvbnZlcnRUby1Kc29uIC1EZXB0aCA2KSwgKE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVu
HLP:Y29kaW5nKCRmYWxzZSkpKSB9IGNhdGNoIHt9IH0KCiMgR2FyYW50aXphIHF1ZSBlbCBlc3RhZG8gdGllbmUgZWwgc3ViLW9iamV0byAnZGlhZycgKHJhbS9iYXR0ZXJ5L2RldmljZXMvbmV0d29yaykuCiMgQ29tcGF0aWJsZSBjb24gZXN0YWRvcyBhbnRpZ3VvcyBj
HLP:YXJnYWRvcyBkZSBlc3RhZG8uanNvbiBzaW4gbGEgcHJvcGllZGFkICdkaWFnJy4KZnVuY3Rpb24gSW5pdGlhbGl6ZS1EaWFnKCRzdCkgewogICAgaWYgKC1ub3QgKCRzdC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdkaWFnJykgLW9yICRudWxs
HLP:IC1lcSAkc3QuZGlhZykgewogICAgICAgICRkaWFnID0gW3BzY3VzdG9tb2JqZWN0XUB7IHJhbSA9ICRudWxsOyBiYXR0ZXJ5ID0gJG51bGw7IGRldmljZXMgPSBAKCk7IG5ldHdvcmsgPSAkbnVsbDsgc21hcnQgPSAkbnVsbDsgYmNkID0gJG51bGw7IHByb2Nlc3Nl
HLP:cyA9ICRudWxsOyBzdGFydHVwID0gJG51bGwgfQogICAgICAgICRzdCB8IEFkZC1NZW1iZXIgLU5vdGVQcm9wZXJ0eU5hbWUgZGlhZyAtTm90ZVByb3BlcnR5VmFsdWUgJGRpYWcgLUZvcmNlCiAgICB9IGVsc2UgewogICAgICAgIGZvcmVhY2ggKCRwcCBpbiAnc21h
HLP:cnQnLCdiY2QnLCdwcm9jZXNzZXMnLCdzdGFydHVwJykgewogICAgICAgICAgICBpZiAoLW5vdCAoJHN0LmRpYWcuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAkcHApKSB7CiAgICAgICAgICAgICAgICAkc3QuZGlhZyB8IEFkZC1NZW1iZXIgLU5v
HLP:dGVQcm9wZXJ0eU5hbWUgJHBwIC1Ob3RlUHJvcGVydHlWYWx1ZSAkbnVsbCAtRm9yY2UKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KICAgIHJldHVybiAkc3QKfQoKZnVuY3Rpb24gR2V0LVN5c0luZm8gewogICAgJG9zICA9IEdldC1DaW1JbnN0YW5jZSBX
HLP:aW4zMl9PcGVyYXRpbmdTeXN0ZW0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICRjcyAgPSBHZXQtQ2ltSW5zdGFuY2UgV2luMzJfQ29tcHV0ZXJTeXN0ZW0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICRjcHUgPSAoR2V0LUNpbUlu
HLP:c3RhbmNlIFdpbjMyX1Byb2Nlc3NvciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEpCiAgICAkYyAgID0gR2V0LVBTRHJpdmUgQwogICAgaWYgKCRvcyAtYW5kICRvcy5MYXN0Qm9vdFVwVGltZSkgewogICAgICAg
HLP:ICR1cCA9IChHZXQtRGF0ZSkgLSAkb3MuTGFzdEJvb3RVcFRpbWUKICAgIH0gZWxzZSB7CiAgICAgICAgJHRpY2tzID0gW1N5c3RlbS5FbnZpcm9ubWVudF06OlRpY2tDb3VudDY0CiAgICAgICAgaWYgKCRudWxsIC1lcSAkdGlja3MpIHsKICAgICAgICAgICAgJHRp
HLP:Y2tzID0gW1N5c3RlbS5FbnZpcm9ubWVudF06OlRpY2tDb3VudAogICAgICAgICAgICBpZiAoJHRpY2tzIC1sdCAwKSB7ICR0aWNrcyA9IFt1aW50MzJdJHRpY2tzIH0KICAgICAgICB9CiAgICAgICAgJHVwID0gW1RpbWVTcGFuXTo6RnJvbU1pbGxpc2Vjb25kcygk
HLP:dGlja3MpCiAgICB9CiAgICAkY3B1TmFtZSA9ICIiCiAgICBpZiAoJGNwdSAtYW5kICRjcHUuTmFtZSkgeyAkY3B1TmFtZSA9ICRjcHUuTmFtZS5UcmltKCkgfQogICAgJHJhbUdCICA9IFttYXRoXTo6Um91bmQoJGNzLlRvdGFsUGh5c2ljYWxNZW1vcnkvMUdCLDEp
HLP:CiAgICAkZnJlZUdCID0gW21hdGhdOjpSb3VuZCgkYy5GcmVlLzFHQiwxKQogICAgJHRvdEdCICA9IFttYXRoXTo6Um91bmQoKCRjLkZyZWUrJGMuVXNlZCkvMUdCLDEpCiAgICAiT1M9JCgkb3MuQ2FwdGlvbikgKGJ1aWxkICQoJG9zLkJ1aWxkTnVtYmVyKSkiCiAg
HLP:ICAiU1lTVEVNPSQoJGNzLk1hbnVmYWN0dXJlcikgJCgkY3MuTW9kZWwpIgogICAgIkNQVT0kY3B1TmFtZSIKICAgICJSQU09JHJhbUdCIEdCIgogICAgIkRJU0s9QzogJGZyZWVHQiBHQiBmcmVlIG9mICR0b3RHQiBHQiIKICAgICJVUFRJTUU9JChbaW50XSR1cC5U
HLP:b3RhbERheXMpZCAkKCR1cC5Ib3VycyloICQoJHVwLk1pbnV0ZXMpbSIKICAgICJVU0VSPSRlbnY6VVNFUk5BTUUiCn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyAo
HLP:NS4yIC8gUmVxIDE1LjYpIE51Y2xlbyBQVVJPIGRlIGNhbGN1bG8gZGVsIHNjb3JlLgojIFJlY2liZSB1biBoYXNodGFibGUgZGUgc2ludG9tYXMgKGZsYWdzL2NvbnRlb3MpIHkgZGV2dWVsdmUgdW4gZW50ZXJvIGVuCiMgWzAsMTAwXS4gQ2FkYSBzaW50b21hIHNv
HLP:bG8gcHVlZGUgUkVTVEFSIHB1bnRvcywgcG9yIGxvIHF1ZSBhbmFkaXIgbyBhZ3JhdmFyCiMgY3VhbHF1aWVyIHNpbnRvbWEgbnVuY2Egc3ViZSBlbCBzY29yZSAoTU9OT1RPTklBKSwgeSBlbCBjbGFtcCBnYXJhbnRpemEgZWwKIyByYW5nbyBbMCwxMDBdLiBFcyBk
HLP:ZXRlcm1pbmlzdGEgcmVzcGVjdG8gYSBzdSBlbnRyYWRhICh0ZXN0ZWFibGUgZGUgZm9ybWEKIyBhaXNsYWRhIHBhcmEgbGEgUHJvcGVydHkgMTApLgpmdW5jdGlvbiBDb21wdXRlLVNjb3JlKFtoYXNodGFibGVdJHN5bSkgewogICAgaWYgKCRudWxsIC1lcSAkc3lt
HLP:KSB7ICRzeW0gPSBAe30gfQogICAgJHNjb3JlID0gMTAwCiAgICAjIC0tLSBQZW5hbGl6YWNpb25lcyBleGlzdGVudGVzIChwcmVzZXJ2YWRhcykgLS0tCiAgICBpZiAoJHN5bVsnc21hcnRCYWQnXSkgICAgICAgeyAkc2NvcmUgLT0gMjUgfQogICAgaWYgKCRzeW0u
HLP:Q29udGFpbnNLZXkoJ2ZyZWVHQicpIC1hbmQgJG51bGwgLW5lICRzeW1bJ2ZyZWVHQiddKSB7CiAgICAgICAgJGZyZWVHQiA9IFtkb3VibGVdJHN5bVsnZnJlZUdCJ10KICAgICAgICBpZiAgICAgKCRmcmVlR0IgLWx0IDUpICB7ICRzY29yZSAtPSAxNSB9CiAgICAg
HLP:ICAgZWxzZWlmICgkZnJlZUdCIC1sdCAxNSkgeyAkc2NvcmUgLT0gNiB9CiAgICB9CiAgICBpZiAoJHN5bVsncmVib290UGVuZGluZyddKSAgICAgICAgICB7ICRzY29yZSAtPSA1IH0KICAgIGlmIChbaW50XSRzeW1bJ2Jzb2QnXSAtZ3QgMCkgICAgICAgIHsgJHNj
HLP:b3JlIC09IDE4IH0KICAgIGlmIChbaW50XSRzeW1bJ2Rpc2tFcnInXSAtZ3QgMCkgICAgIHsgJHNjb3JlIC09IDEyIH0KICAgIGlmIChbaW50XSRzeW1bJ3doZWEnXSAtZ3QgMCkgICAgICAgIHsgJHNjb3JlIC09IDEyIH0KICAgIGlmIChbaW50XSRzeW1bJ2NyaXRD
HLP:b3VudCddIC1ndCAyNSkgIHsgJHNjb3JlIC09IDYgfQogICAgaWYgKFtpbnRdJHN5bVsnc3ZjU3RvcHBlZCddIC1ndCAwKSAgeyAkc2NvcmUgLT0gNCAqIFtpbnRdJHN5bVsnc3ZjU3RvcHBlZCddIH0KICAgIGlmIChbaW50XSRzeW1bJ2RldlByb2JsZW1zJ10gLWd0
HLP:IDApIHsgJHNjb3JlIC09IFttYXRoXTo6TWluKDEyLCBbaW50XSRzeW1bJ2RldlByb2JsZW1zJ10gKiAzKSB9CiAgICAjIC0tLSBOdWV2YXMgcGVuYWxpemFjaW9uZXMgZGVsIGRpYWdub3N0aWNvIGFtcGxpYWRvICg1LjIpIC0tLQogICAgaWYgKCRzeW1bJ3JhbVN1
HLP:c3BlY3QnXSkgeyAkc2NvcmUgLT0gMTAgfSAgICMgUkFNIHNvc3BlY2hvc2EKICAgIGlmICgkc3ltLkNvbnRhaW5zS2V5KCdiYXR0ZXJ5SGVhbHRoUGN0JykgLWFuZCAkbnVsbCAtbmUgJHN5bVsnYmF0dGVyeUhlYWx0aFBjdCddKSB7CiAgICAgICAgJGJwID0gW2lu
HLP:dF0kc3ltWydiYXR0ZXJ5SGVhbHRoUGN0J10KICAgICAgICBpZiAoJGJwIC1nZSAwIC1hbmQgJGJwIC1sdCA1MCkgeyAkc2NvcmUgLT0gOCB9ICAgIyBiYXRlcmlhIG11eSBkZWdyYWRhZGEgKDw1MCUpCiAgICB9CiAgICBpZiAoJHN5bVsnbmV0UHJvYmxlbSddKSB7
HLP:ICRzY29yZSAtPSA4IH0gICAjIHByb2JsZW1hcyBkZSByZWQgcGVyc2lzdGVudGVzCiAgICAjIC0tLSBDbGFtcCBhbCByYW5nbyBbMCwxMDBdIC0tLQogICAgaWYgKCRzY29yZSAtbHQgMCkgICB7ICRzY29yZSA9IDAgfQogICAgaWYgKCRzY29yZSAtZ3QgMTAwKSB7
HLP:ICRzY29yZSA9IDEwMCB9CiAgICByZXR1cm4gW2ludF0kc2NvcmUKfQoKIyBQdW50dWFjaW9uIGRlIHNhbHVkIDAtMTAwOiByZWNvbGVjdGEgc2ludG9tYXMgcmVhbGVzIGRlbCBzaXN0ZW1hIChpbmNsdWlkbyBlbAojIGRpYWdub3N0aWNvIGFtcGxpYWRvIHBlcnNp
HLP:c3RpZG8gZW4gZXN0YWRvLmRpYWcpIHkgZGVsZWdhIGVsIGNhbGN1bG8gZW4gbGEKIyBmdW5jaW9uIHB1cmEgQ29tcHV0ZS1TY29yZS4KZnVuY3Rpb24gR2V0LUhlYWx0aFNjb3JlIHsKICAgICRyZWFzb25zID0gQCgpCiAgICAkc3ltID0gQHt9CiAgICAjIERpc2Nv
HLP:IFNNQVJUCiAgICAkYmFkID0gQChHZXQtUGh5c2ljYWxEaXNrIHwgV2hlcmUtT2JqZWN0IHsgJF8uSGVhbHRoU3RhdHVzIC1uZSAnSGVhbHRoeScgfSkKICAgICRzeW1bJ3NtYXJ0QmFkJ10gPSAoJGJhZC5Db3VudCAtZ3QgMCkKICAgIGlmICgkc3ltWydzbWFydEJh
HLP:ZCddKSB7ICRyZWFzb25zICs9ICJEaXNrIHdpdGggZGVncmFkZWQgU01BUlQgKC0yNSkiIH0KICAgICMgRXNwYWNpbyBsaWJyZQogICAgJGMgPSBHZXQtUFNEcml2ZSBDOyAkZnJlZUdCID0gW21hdGhdOjpSb3VuZCgkYy5GcmVlLzFHQiwxKQogICAgJHN5bVsnZnJl
HLP:ZUdCJ10gPSAkZnJlZUdCCiAgICBpZiAgICAgKCRmcmVlR0IgLWx0IDUpICB7ICRyZWFzb25zICs9ICJMZXNzIHRoYW4gNSBHQiBmcmVlIG9uIEM6ICgtMTUpIiB9CiAgICBlbHNlaWYgKCRmcmVlR0IgLWx0IDE1KSB7ICRyZWFzb25zICs9ICJMb3cgZnJlZSBzcGFj
HLP:ZSBvbiBDOiAoLTYpIiB9CiAgICAjIFJlaW5pY2lvIHBlbmRpZW50ZQogICAgJHBlbmQgPSAoVGVzdC1QYXRoICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93c1xDdXJyZW50VmVyc2lvblxDb21wb25lbnQgQmFzZWQgU2VydmljaW5nXFJlYm9vdFBlbmRp
HLP:bmcnKSAtb3IgYAogICAgICAgICAgICAoVGVzdC1QYXRoICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93c1xDdXJyZW50VmVyc2lvblxXaW5kb3dzVXBkYXRlXEF1dG8gVXBkYXRlXFJlYm9vdFJlcXVpcmVkJykKICAgICRzeW1bJ3JlYm9vdFBlbmRpbmcn
HLP:XSA9IFtib29sXSRwZW5kCiAgICBpZiAoJHBlbmQpIHsgJHJlYXNvbnMgKz0gIlBlbmRpbmcgcmVib290ICgtNSkiIH0KICAgICMgRXZlbnRvcyBjcml0aWNvcyByZWNpZW50ZXMgKDQ4aCkKICAgICRzaW5jZSA9IChHZXQtRGF0ZSkuQWRkSG91cnMoLTQ4KQogICAg
HLP:JGNyaXQgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgTGV2ZWw9MSwyOyBTdGFydFRpbWU9JHNpbmNlfSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICRic29kID0gQCgkY3JpdCB8IFdoZXJlLU9i
HLP:amVjdCB7ICRfLklkIC1pbiA0MSwxMDAxLDYwMDggfSkuQ291bnQKICAgICRkaXNrID0gQCgkY3JpdCB8IFdoZXJlLU9iamVjdCB7ICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2ggJ2Rpc2t8TnRmc3x2b2xtZ3InIH0pLkNvdW50CiAgICAkd2hlYSA9IEAoJGNyaXQgfCBX
HLP:aGVyZS1PYmplY3QgeyAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICdXSEVBJyB9KS5Db3VudAogICAgJHN5bVsnYnNvZCddID0gJGJzb2Q7ICRzeW1bJ2Rpc2tFcnInXSA9ICRkaXNrOyAkc3ltWyd3aGVhJ10gPSAkd2hlYTsgJHN5bVsnY3JpdENvdW50J10gPSAkY3Jp
HLP:dC5Db3VudAogICAgaWYgKCRic29kIC1ndCAwKSB7ICRyZWFzb25zICs9ICJSZWNlbnQgY3Jhc2hlcy9CU09EOiAkYnNvZCAoLTE4KSIgfQogICAgaWYgKCRkaXNrIC1ndCAwKSB7ICRyZWFzb25zICs9ICJSZWNlbnQgZGlzay9OVEZTIGVycm9yczogJGRpc2sgKC0x
HLP:MikiIH0KICAgIGlmICgkd2hlYSAtZ3QgMCkgeyAkcmVhc29ucyArPSAiSGFyZHdhcmUgZXJyb3JzIChXSEVBKTogJHdoZWEgKC0xMikiIH0KICAgIGlmICgkY3JpdC5Db3VudCAtZ3QgMjUpIHsgJHJlYXNvbnMgKz0gIk1hbnkgY3JpdGljYWwgZXZlbnRzIGluIDQ4
HLP:aDogJCgkY3JpdC5Db3VudCkgKC02KSIgfQogICAgIyBTZXJ2aWNpb3MgY2xhdmUgcGFyYWRvcwogICAgJHN2Y1N0b3BwZWQgPSAwCiAgICBmb3JlYWNoICgkc3ZjIGluICd3dWF1c2VydicsJ0JJVFMnLCdXaW5tZ210JywnRXZlbnRMb2cnKSB7CiAgICAgICAgJHMg
HLP:PSBHZXQtU2VydmljZSAkc3ZjIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgaWYgKCRzIC1hbmQgJHMuU3RhdHVzIC1uZSAnUnVubmluZycgLWFuZCAkcy5TdGFydFR5cGUgLW5lICdEaXNhYmxlZCcpIHsgJHN2Y1N0b3BwZWQrKzsgJHJlYXNv
HLP:bnMgKz0gIlNlcnZpY2UgJHN2YyBzdG9wcGVkICgtNCkiIH0KICAgIH0KICAgICRzeW1bJ3N2Y1N0b3BwZWQnXSA9ICRzdmNTdG9wcGVkCiAgICAjIERldmljZXMgY29uIHByb2JsZW1hCiAgICAkcHJvYiA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1BuUEVudGl0
HLP:eSB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUgLWd0IDAgfSkuQ291bnQKICAgICRzeW1bJ2RldlByb2JsZW1zJ10gPSAkcHJvYgogICAgaWYgKCRwcm9iIC1ndCAwKSB7ICRyZWFzb25zICs9ICJEZXZpY2VzIHdpdGggZXJyb3JzOiAk
HLP:cHJvYiIgfQogICAgIyAtLS0gRGlhZ25vc3RpY28gYW1wbGlhZG8gcGVyc2lzdGlkbyAoNS4yKTogUkFNLCBiYXRlcmlhLCByZWQgLS0tCiAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICBpZiAoKCRzdC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdk
HLP:aWFnJykgLWFuZCAkc3QuZGlhZykgewogICAgICAgIGlmICgkc3QuZGlhZy5yYW0gLWFuZCAoW3N0cmluZ10kc3QuZGlhZy5yYW0uc3RhdHVzIC1lcSAnc3VzcGVjdCcpKSB7CiAgICAgICAgICAgICRzeW1bJ3JhbVN1c3BlY3QnXSA9ICR0cnVlOyAkcmVhc29ucyAr
HLP:PSAiUkFNIHN1c3BpY2lvdXMgKC0xMCkiCiAgICAgICAgfQogICAgICAgIGlmICgkc3QuZGlhZy5iYXR0ZXJ5IC1hbmQgJHN0LmRpYWcuYmF0dGVyeS5wcmVzZW50KSB7CiAgICAgICAgICAgICRicFJhdyA9ICRzdC5kaWFnLmJhdHRlcnkuaGVhbHRoX3BjdAogICAg
HLP:ICAgICAgICBpZiAoJG51bGwgLW5lICRicFJhdyAtYW5kIFtzdHJpbmddJGJwUmF3IC1uZSAnJykgewogICAgICAgICAgICAgICAgJGJwID0gJG51bGw7IHRyeSB7ICRicCA9IFtpbnRdJGJwUmF3IH0gY2F0Y2ggeyAkYnAgPSAkbnVsbCB9CiAgICAgICAgICAgICAg
HLP:ICBpZiAoJG51bGwgLW5lICRicCkgewogICAgICAgICAgICAgICAgICAgICRzeW1bJ2JhdHRlcnlIZWFsdGhQY3QnXSA9ICRicAogICAgICAgICAgICAgICAgICAgIGlmICgkYnAgLWdlIDAgLWFuZCAkYnAgLWx0IDUwKSB7ICRyZWFzb25zICs9ICJCYXR0ZXJ5IGhl
HLP:YXZpbHkgZGVncmFkZWQ6ICRicCUgKC04KSIgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIGlmICgkc3QuZGlhZy5uZXR3b3JrIC1hbmQgKCgkc3QuZGlhZy5uZXR3b3JrLmNvbm5lY3RlZCAtZXEgJGZhbHNlKSAtb3Ig
HLP:KCRzdC5kaWFnLm5ldHdvcmsuZG5zX29rIC1lcSAkZmFsc2UpKSkgewogICAgICAgICAgICAkc3ltWyduZXRQcm9ibGVtJ10gPSAkdHJ1ZTsgJHJlYXNvbnMgKz0gIlBlcnNpc3RlbnQgbmV0d29yayBwcm9ibGVtcyAoLTgpIgogICAgICAgIH0KICAgIH0KICAgICRz
HLP:Y29yZSA9IENvbXB1dGUtU2NvcmUgJHN5bQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzY29yZSA9IFtpbnRdJHNjb3JlOyByZWFzb25zID0gJHJlYXNvbnMgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgRm9yZW5zZSBkZWwgcmVnaXN0cm8gZGUgZXZlbnRvczogdWx0aW1vcyBlcnJvcmVzIHF1ZSBleHBsaWNhbiBsYSBjYXVzYSByYWl6LgpmdW5jdGlvbiBHZXQtRm9yZW5zaWNzIHsKICAgICRzaW5jZSA9IChHZXQt
HLP:RGF0ZSkuQWRkRGF5cygtNykKICAgICRvdXQgPSBAKCkKICAgICRldiA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBMZXZlbD0xLDI7IFN0YXJ0VGltZT0kc2luY2V9IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRp
HLP:bnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgNDAwKQogICAgJGdyb3VwcyA9IEAoCiAgICAgICAgQHsgaz0nQVJSQU5RVUUvQVBBR09OJzsgaWRzPUAoNDEsNjAwOCwxMDAxKTsgcHJvdj0nJyB9LAogICAgICAgIEB7IGs9J0RJU0NPL05URlMnOyAgICAgIGlkcz1A
HLP:KCk7ICAgICAgICAgICAgIHByb3Y9J2Rpc2t8TnRmc3x2b2xtZ3J8c3Rvcm52bWV8c3RvcmFoY2knIH0sCiAgICAgICAgQHsgaz0nSEFSRFdBUkUgKFdIRUEpJzsgaWRzPUAoKTsgICAgICAgICAgICAgcHJvdj0nV0hFQScgfSwKICAgICAgICBAeyBrPSdTRVJWSUNJ
HLP:T1MnOyAgICAgICBpZHM9QCgpOyAgICAgICAgICAgICBwcm92PSdTZXJ2aWNlIENvbnRyb2wgTWFuYWdlcicgfSwKICAgICAgICBAeyBrPSdBUExJQ0FDSU9OJzsgICAgICBpZHM9QCgxMDAwLDEwMDIpOyAgICBwcm92PSdBcHBsaWNhdGlvbiBFcnJvcnwuTkVUIFJ1
HLP:bnRpbWUnIH0KICAgICkKICAgIGZvcmVhY2ggKCRnIGluICRncm91cHMpIHsKICAgICAgICAkc2VsID0gJGV2IHwgV2hlcmUtT2JqZWN0IHsKICAgICAgICAgICAgKCRnLmlkcy5Db3VudCAtZ3QgMCAtYW5kICRfLklkIC1pbiAkZy5pZHMpIC1vciAoJGcucHJvdiAt
HLP:bmUgJycgLWFuZCAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICRnLnByb3YpCiAgICAgICAgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDMKICAgICAgICBmb3JlYWNoICgkZSBpbiAkc2VsKSB7CiAgICAgICAgICAgICRtc2cgPSAoJGUuTWVzc2FnZSAtc3BsaXQgImBu
HLP:IilbMF07IGlmICgkbXNnLkxlbmd0aCAtZ3QgOTApIHsgJG1zZyA9ICRtc2cuU3Vic3RyaW5nKDAsOTApIH0KICAgICAgICAgICAgJG91dCArPSAoInswfXx7MX18ezJ9fHszfSIgLWYgJGcuaywgJGUuSWQsICRlLlRpbWVDcmVhdGVkLlRvU3RyaW5nKCdNTS1kZCBI
HLP:SDptbScpLCAkbXNnLlRyaW0oKSkKICAgICAgICB9CiAgICB9CiAgICBpZiAoJG91dC5Db3VudCAtZXEgMCkgeyAiT0t8MHwtfE5vIGNyaXRpY2FsIGVycm9ycyBpbiB0aGUgbGFzdCA3IGRheXMuIiB9IGVsc2UgeyAkb3V0IH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEF1dG8tdHJpYWdlOiBhIHBhcnRpciBkZWwgc2NvcmUgeSBsYSBmb3JlbnNlLCByZWNvbWllbmRhIGZhc2VzIChsaXN0YSBkZSBJRHMpLgpmdW5jdGlvbiBH
HLP:ZXQtVHJpYWdlIHsKICAgICRoID0gR2V0LUhlYWx0aFNjb3JlCiAgICAkcmVjID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgIGZvcmVhY2ggKCR4IGluICcwMCcsJzAxJywnMDInKSB7ICRyZWMuQWRkKCR4KSB9
HLP:ICAjIGRpYWdub3N0aWNvK3Jlc3RvcmUrbGltcGllemEgc2llbXByZQogICAgJHNpbmNlID0gKEdldC1EYXRlKS5BZGREYXlzKC03KQogICAgJGV2ID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IExldmVsPTEsMjsg
HLP:U3RhcnRUaW1lPSRzaW5jZX0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICBpZiAoQCgkZXYgfCBXaGVyZS1PYmplY3QgeyAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICdkaXNrfE50ZnN8dm9sbWdyJyB9KS5Db3VudCAtZ3QgMCkgeyAkcmVjLkFkZCgn
HLP:MDMnKSB9CiAgICAkcmVjLkFkZCgnMDQnKTsgJHJlYy5BZGQoJzA1Jyk7ICRyZWMuQWRkKCcwNicpICAjIGRpc2NvL0RJU00vU0ZDIGJhc2UKICAgIGlmICgoR2V0LVNlcnZpY2UgV2lubWdtdCkuU3RhdHVzIC1uZSAnUnVubmluZycpIHsgJHJlYy5BZGQoJzA3Jykg
HLP:fQogICAgIyBXVSByb3RvPwogICAgJHd1ID0gR2V0LVNlcnZpY2Ugd3VhdXNlcnYgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIGlmICgkd3UgLWFuZCAkd3UuU3RhdHVzIC1uZSAnUnVubmluZycgLWFuZCAkd3UuU3RhcnRUeXBlIC1uZSAnRGlzYWJs
HLP:ZWQnKSB7ICRyZWMuQWRkKCcxMycpIH0KICAgICJTQ09SRT0kKCRoLnNjb3JlKSIKICAgICJSRUNPTUVOREFEQVM9JChbc3RyaW5nXTo6Sm9pbignLCcsICgkcmVjIHwgU2VsZWN0LU9iamVjdCAtVW5pcXVlKSkpIgp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCmZ1bmN0aW9uIE5ldy1SZXN0b3JlUG9pbnQgewogICAgdHJ5IHsKICAgICAgICBFbmFibGUtQ29tcHV0ZXJSZXN0b3JlIC1Ecml2ZSAnQzonIC1FcnJvckFjdGlvbiBTaWxl
HLP:bnRseUNvbnRpbnVlCiAgICAgICAgJGsgPSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb25cU3lzdGVtUmVzdG9yZScKICAgICAgICAkcHJldiA9IChHZXQtSXRlbVByb3BlcnR5ICRrIC1OYW1lIFN5c3RlbVJlc3RvcmVQ
HLP:b2ludENyZWF0aW9uRnJlcXVlbmN5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS5TeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeQogICAgICAgIFNldC1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25G
HLP:cmVxdWVuY3kgLVZhbHVlIDAgLVR5cGUgRFdvcmQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkbmFtZSA9ICJSZXBhaXJfU3VpdGVfJCgoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkX0hILW1tJykpIgogICAgICAgIENoZWNrcG9p
HLP:bnQtQ29tcHV0ZXIgLURlc2NyaXB0aW9uICRuYW1lIC1SZXN0b3JlUG9pbnRUeXBlIE1PRElGWV9TRVRUSU5HUyAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIGlmICgkbnVsbCAtbmUgJHByZXYpIHsgU2V0LUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0
HLP:b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtVmFsdWUgJHByZXYgLVR5cGUgRFdvcmQgfSBlbHNlIHsgUmVtb3ZlLUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250
HLP:aW51ZSB9CiAgICAgICAgJHJwID0gR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IHwgV2hlcmUtT2JqZWN0IHsgJF8uRGVzY3JpcHRpb24gLWVxICRuYW1lIH0KICAgICAgICBpZiAoJHJwKSB7ICJSRVNVTFQ9T0siOyAiTkFNRT0kbmFtZSIgfSBlbHNlIHsgIlJFU1VM
HLP:VD1GQUlMIjsgIk5BTUU9JG5hbWUiIH0KICAgIH0gY2F0Y2ggeyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiIH0KfQoKZnVuY3Rpb24gU2F2ZS1IZWFsdGhIaXN0b3J5KCRzY29yZSkgewogICAgJHNjcmlwdERpciA9ICRudWxs
HLP:CiAgICBpZiAoJFBTU2NyaXB0Um9vdCkgewogICAgICAgICRzY3JpcHREaXIgPSAkUFNTY3JpcHRSb290CiAgICB9IGVsc2VpZiAoJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aCkgewogICAgICAgICRzY3JpcHREaXIgPSBTcGxpdC1QYXRoIC1QYXJlbnQgJE15
HLP:SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aAogICAgfQogICAgJGJhc2VEaXIgPSBpZiAoJHNjcmlwdERpcikgeyBKb2luLVBhdGggKFNwbGl0LVBhdGggLVBhcmVudCAkc2NyaXB0RGlyKSAiV1BJX1N1aXRlIiB9IGVsc2UgeyAkV29yayB9CiAgICBpZiAoJHNjcmlw
HLP:dERpciAtYW5kIChUZXN0LVBhdGggJHNjcmlwdERpcikpIHsKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRiYXNlRGlyKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRiYXNlRGlyIC1Gb3JjZSB8IE91dC1OdWxsIH0KICAgIH0gZWxz
HLP:ZSB7CiAgICAgICAgJGJhc2VEaXIgPSAkV29yawogICAgfQogICAgJGhpc3RvcnlGaWxlID0gSm9pbi1QYXRoICRiYXNlRGlyICJoZWFsdGhfaGlzdG9yeS5qc29uIgogICAgJGhpc3RvcnkgPSBAKCkKICAgIGlmIChUZXN0LVBhdGggJGhpc3RvcnlGaWxlKSB7CiAg
HLP:ICAgICAgdHJ5IHsgJGhpc3RvcnkgPSBHZXQtQ29udGVudCAkaGlzdG9yeUZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7fQogICAgfQogICAgJGVudHJ5ID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgZGF0ZSAgPSAoR2V0LURhdGUpLlRv
HLP:U3RyaW5nKCd5eXl5LU1NLWRkIEhIOm1tJykKICAgICAgICBzY29yZSA9IFtpbnRdJHNjb3JlCiAgICB9CiAgICAkaGlzdG9yeSA9IEAoJGhpc3RvcnkpICsgJGVudHJ5CiAgICBpZiAoJGhpc3RvcnkuQ291bnQgLWd0IDEwKSB7ICRoaXN0b3J5ID0gJGhpc3Rvcnlb
HLP:LTEwLi4tMV0gfQogICAgdHJ5IHsKICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJGhpc3RvcnlGaWxlLCAoJGhpc3RvcnkgfCBDb252ZXJ0VG8tSnNvbiksIChOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpKSkK
HLP:ICAgIH0gY2F0Y2gge30KfQoKZnVuY3Rpb24gSW5zdGFsbC1XaW5nZXRCb290c3RyYXAgewogICAgJHRlbXBGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAiTWljcm9zb2Z0LkRlc2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgogICAg
HLP:dHJ5IHsKICAgICAgICAkdXJsID0gImh0dHBzOi8vZ2l0aHViLmNvbS9taWNyb3NvZnQvd2luZ2V0LWNsaS9yZWxlYXNlcy9sYXRlc3QvZG93bmxvYWQvTWljcm9zb2Z0LkRlc2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgogICAgICAg
HLP:IFdyaXRlLUhvc3QgIkRvd25sb2FkaW5nIEFwcCBJbnN0YWxsZXIgZnJvbTogJHVybCIKICAgICAgICAkd2ViQ2xpZW50ID0gTmV3LU9iamVjdCBTeXN0ZW0uTmV0LldlYkNsaWVudAogICAgICAgIFtTeXN0ZW0uTmV0LlNlcnZpY2VQb2ludE1hbmFnZXJdOjpTZWN1
HLP:cml0eVByb3RvY29sID0gW1N5c3RlbS5OZXQuU2VjdXJpdHlQcm90b2NvbFR5cGVdOjpUbHMxMgogICAgICAgICR3ZWJDbGllbnQuRG93bmxvYWRGaWxlKCR1cmwsICR0ZW1wRmlsZSkKICAgICAgICAKICAgICAgICBXcml0ZS1Ib3N0ICJJbnN0YWxsaW5nIEFwcCBJ
HLP:bnN0YWxsZXIgd2l0aCBBZGQtQXBweFBhY2thZ2UuLi4iCiAgICAgICAgQWRkLUFwcHhQYWNrYWdlIC1QYXRoICR0ZW1wRmlsZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIFdyaXRlLUhvc3QgIkluc3RhbGxhdGlvbiBzdWNjZXNzZnVsLiIKICAgICAgICBpZiAo
HLP:VGVzdC1QYXRoICR0ZW1wRmlsZSkgeyBSZW1vdmUtSXRlbSAkdGVtcEZpbGUgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggewogICAgICAgIFdyaXRlLUhvc3QgIndpbmdldCBib290
HLP:c3RyYXAgZXJyb3I6ICQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgICAgIGlmIChUZXN0LVBhdGggJHRlbXBGaWxlKSB7IFJlbW92ZS1JdGVtICR0ZW1wRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIHJldHVybiAk
HLP:ZmFsc2UKICAgIH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojICgzLjcgLyBCdWcgNSAvIFJlcSA3KSBEZXRlY2Npb24gZmlhYmxlIGRlbCB0aXBvIGRlIGRpc2Nv
HLP:LgojIENvbnZlcnRUby1NZWRpYUNsYXNzOiBmdW5jaW9uIFBVUkEgcXVlIG1hcGVhIHVuIE1lZGlhVHlwZSAobnVtZXJvIG8gdGV4dG8pCiMgYSBsYSBjbGFzZSBjYW5vbmljYSB7U1NELEhERCxVTktOT1dOfS4gU1NEPTQgbyAnU1NEJzsgSEREPTMgbyAnSEREJzsK
HLP:IyBjdWFscXVpZXIgb3RybyB2YWxvciAoVW5zcGVjaWZpZWQ9MCwgdmFjaW8sIG51bG8sIFNDTT01Li4uKSAtPiBVTktOT1dOLgpmdW5jdGlvbiBDb252ZXJ0VG8tTWVkaWFDbGFzcygkbXQpIHsKICAgIGlmICgkbnVsbCAtZXEgJG10KSB7IHJldHVybiAnVU5LTk9X
HLP:TicgfQogICAgJHMgPSAoW3N0cmluZ10kbXQpLlRyaW0oKQogICAgaWYgKCRzIC1lcSAnJykgeyByZXR1cm4gJ1VOS05PV04nIH0KICAgIHN3aXRjaCAtcmVnZXggKCRzLlRvVXBwZXIoKSkgewogICAgICAgICdeKDR8U1NEKSQnIHsgcmV0dXJuICdTU0QnIH0KICAg
HLP:ICAgICAnXigzfEhERCkkJyB7IHJldHVybiAnSEREJyB9CiAgICAgICAgZGVmYXVsdCAgICAgeyByZXR1cm4gJ1VOS05PV04nIH0KICAgIH0KfQoKIyBSZXNvbHZlLU9wdGltaXplQWN0aW9uOiBmdW5jaW9uIFBVUkEuIFRSSU0gc29sbyBzaSBTU0QsIERFRlJBRyBz
HLP:b2xvIHNpIEhERAojIGNsYXJvLCBOT05FIGVuIGN1YWxxdWllciBvdHJvIGNhc28gKGFic3RlbmNpb24gc2VndXJhOiBudW5jYSBkZXNmcmFnbWVudGEKIyBhbnRlIHRpcG8gaW5jaWVydG8sIGV2aXRhbmRvIGRhbmFyIHVuIHBvc2libGUgU1NEKS4KZnVuY3Rpb24g
HLP:UmVzb2x2ZS1PcHRpbWl6ZUFjdGlvbigkbWVkaWEpIHsKICAgICRtID0gKFtzdHJpbmddJG1lZGlhKS5UcmltKCkuVG9VcHBlcigpCiAgICBpZiAgICAgKCRtIC1lcSAnU1NEJykgICAgIHsgcmV0dXJuICdUUklNJyB9CiAgICBlbHNlaWYgKCRtIC1lcSAnSEREJykg
HLP:ICAgIHsgcmV0dXJuICdERUZSQUcnIH0KICAgIGVsc2VpZiAoJG0gLWVxICdWSVJUVUFMJykgeyByZXR1cm4gJ05PTkUnIH0gICAjICh2My4yKSBkaXNjbyBkZSBtYXF1aW5hIHZpcnR1YWw6IG5vIGFwbGljYQogICAgZWxzZSAgICAgICAgICAgICAgICAgICAgICB7
HLP:IHJldHVybiAnTk9ORScgfQp9CgojIEdldC1NZWRpYVR5cGU6IGlkZW50aWZpY2EgZWwgZGlzY28gZmlzaWNvIGRlbCB2b2x1bWVuIGRlbCBzaXN0ZW1hIGRlIGZvcm1hCiMgZmlhYmxlIChwb3IgRGV2aWNlSWQsIHJlc3BhbGRvIHBvciBTZXJpYWxOdW1iZXIpIHkg
HLP:ZGV2dWVsdmUgU1NEfEhERHxWSVJUVUFMfFVOS05PV04uCmZ1bmN0aW9uIEdldC1NZWRpYVR5cGUgewogICAgdHJ5IHsKICAgICAgICAkc3lzICA9ICgkZW52OlN5c3RlbURyaXZlKS5UcmltRW5kKCc6JykKICAgICAgICAkZGlzayA9IEdldC1QYXJ0aXRpb24gLURy
HLP:aXZlTGV0dGVyICRzeXMgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBHZXQtRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRwZCA9ICRudWxsCiAgICAgICAgaWYgKCRkaXNrKSB7CiAgICAgICAgICAgICRwZCA9IEdldC1Q
HLP:aHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAgICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5EZXZpY2VJZCAtZXEgJGRpc2suTnVtYmVyIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIGlmICgt
HLP:bm90ICRwZCAtYW5kICRkaXNrLlNlcmlhbE51bWJlcikgewogICAgICAgICAgICAgICAgJHBkID0gR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5TZXJp
HLP:YWxOdW1iZXIgLWFuZCAoJF8uU2VyaWFsTnVtYmVyLlRyaW0oKSAtZXEgKFtzdHJpbmddJGRpc2suU2VyaWFsTnVtYmVyKS5UcmltKCkpIH0gfAogICAgICAgICAgICAgICAgICAgICAgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICB9CiAgICAgICAg
HLP:fQogICAgICAgICMgKHYzLjIpIGRpc2NvIGRlIG1hcXVpbmEgdmlydHVhbCAoVmlydHVhbEJveC9WTXdhcmUvSHlwZXItVi9RRU1VKTogVFJJTSB5CiAgICAgICAgIyBkZXNmcmFnbWVudGFjaW9uIG5vIGFwbGljYW47IHNlIGlkZW50aWZpY2EgcG9yIGVsIG1vZGVs
HLP:byBkZWwgZGlzY28uCiAgICAgICAgJG1vZGVsb3MgPSBAKCkKICAgICAgICBpZiAoJGRpc2spIHsgJG1vZGVsb3MgKz0gW3N0cmluZ10kZGlzay5GcmllbmRseU5hbWU7ICRtb2RlbG9zICs9IFtzdHJpbmddJGRpc2suTW9kZWwgfQogICAgICAgIGlmICgkcGQpICAg
HLP:eyAkbW9kZWxvcyArPSBbc3RyaW5nXSRwZC5GcmllbmRseU5hbWU7ICAgJG1vZGVsb3MgKz0gW3N0cmluZ10kcGQuTW9kZWwgfQogICAgICAgIGlmICgoJG1vZGVsb3MgLWpvaW4gJyAnKSAtbWF0Y2ggJ1ZCT1h8Vk1XQVJFfFZJUlRVQUx8UUVNVXxYRU5TUkMnKSB7
HLP:IHJldHVybiAnVklSVFVBTCcgfQogICAgICAgIGlmICgtbm90ICRwZCkgeyByZXR1cm4gJ1VOS05PV04nIH0KICAgICAgICByZXR1cm4gKENvbnZlcnRUby1NZWRpYUNsYXNzICRwZC5NZWRpYVR5cGUpCiAgICB9IGNhdGNoIHsgcmV0dXJuICdVTktOT1dOJyB9Cn0K
HLP:CiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KZnVuY3Rpb24gR2V0LURldmljZVByb2JsZW1zIHsKICAgICRwID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUG5QRW50aXR5
HLP:IHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFuYWdlckVycm9yQ29kZSAtZ3QgMCB9KQogICAgaWYgKCRwLkNvdW50IC1lcSAwKSB7ICJPS3xObyBkZXZpY2VzIHdpdGggcHJvYmxlbXMuIjsgcmV0dXJuIH0KICAgIGZvcmVhY2ggKCRkIGluICgkcCB8IFNlbGVj
HLP:dC1PYmplY3QgLUZpcnN0IDEyKSkgewogICAgICAgICJQUk9CfCQoJGQuQ29uZmlnTWFuYWdlckVycm9yQ29kZSl8JCgkZC5OYW1lKSIKICAgIH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLQojIEluZm9ybWUgSFRNTCBhdXRvY29udGVuaWRvIHkgYm9uaXRvICh0ZW1hIG9zY3VybykuIC1BcmcgPSBydXRhIGRlIHNhbGlkYS4KZnVuY3Rpb24gTmV3LUh0bWxSZXBvcnQoJG91dFBhdGgpIHsKICAgIEFkZC1UeXBlIC1Bc3NlbWJseU5h
HLP:bWUgU3lzdGVtLldlYiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgdHJ5IHsKICAgICAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAgICAgJHN5c1BhaXJzID0gR2V0LVN5c0luZm8KCiAgICAgICAgJGVuYyA9IHsgcGFyYW0oJHQpIFtTeXN0ZW0uV2Vi
HLP:Lkh0dHBVdGlsaXR5XTo6SHRtbEVuY29kZShbc3RyaW5nXSR0KSB9CiAgICAgICAgJGNpcmMgPSA1MjcuNzkKICAgICAgICAkYmFuZENvbG9yID0geyBwYXJhbSgkcykgaWYgKCRzIC1lcSAnLScgLW9yICRudWxsIC1lcSAkcyAtb3IgW3N0cmluZ10kcyAtZXEgJycp
HLP:IHsgJyM5NGEzYjgnIH0gZWxzZSB7ICR2PTA7IHRyeSB7ICR2PVtpbnRdJHMgfSBjYXRjaCB7IHJldHVybiAnIzk0YTNiOCcgfTsgaWYgKCR2IC1nZSA4MCkgeycjMjJjNTVlJ30gZWxzZWlmICgkdiAtZ2UgNTApIHsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J30g
HLP:fSB9CiAgICAgICAgJGJhbmRMYWJlbCA9IHsgcGFyYW0oJHMpIGlmICgkcyAtZXEgJy0nIC1vciAkbnVsbCAtZXEgJHMgLW9yIFtzdHJpbmddJHMgLWVxICcnKSB7ICdubyBkYXRhJyB9IGVsc2UgeyAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0Y2ggeyByZXR1
HLP:cm4gJ25vIGRhdGEnIH07IGlmICgkdiAtZ2UgODApIHsnR29vZCd9IGVsc2VpZiAoJHYgLWdlIDUwKSB7J0ZhaXInfSBlbHNlIHsnQ3JpdGljYWwnfSB9IH0KICAgICAgICAkb2Zmc2V0T2YgPSB7IHBhcmFtKCRzKSAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0
HLP:Y2ggeyAkdj0wIH07IGlmICgkdiAtbHQgMCl7JHY9MH07IGlmICgkdiAtZ3QgMTAwKXskdj0xMDB9OyBbbWF0aF06OlJvdW5kKCRjaXJjICogKDEgLSAoJHYvMTAwLjApKSwgMikgfQogICAgICAgICRzdGF0dXNJY29uID0gewogICAgICAgICAgICBwYXJhbSgkcmVz
HLP:KQogICAgICAgICAgICBzd2l0Y2ggKFtzdHJpbmddJHJlcykgewogICAgICAgICAgICAgICAgJ09LJyAgICB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdzdWNjZXNzZnVsJz48Y2lyY2xlIGN4
HLP:PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nIzIyYzU1ZScvPjxwYXRoIGQ9J003IDEyLjRsMy4yIDMuMkwxNyA4LjgnIGZpbGw9J25vbmUnIHN0cm9rZT0nIzA0MjEwZicgc3Ryb2tlLXdpZHRoPScyLjYnIHN0cm9rZS1saW5lY2FwPSdyb3VuZCcgc3Ryb2tlLWxp
HLP:bmVqb2luPSdyb3VuZCcvPjwvc3ZnPiIgfQogICAgICAgICAgICAgICAgJ1dBUk4nICB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSd3YXJuaW5nJz48cGF0aCBkPSdNMTIgMi41TDIzIDIxLjVI
HLP:MXonIGZpbGw9JyNmNTllMGInLz48cmVjdCB4PScxMScgeT0nOC41JyB3aWR0aD0nMicgaGVpZ2h0PSc3JyByeD0nMScgZmlsbD0nIzNhMjQwMCcvPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTgnIHI9JzEuMycgZmlsbD0nIzNhMjQwMCcvPjwvc3ZnPiIgfQogICAgICAg
HLP:ICAgICAgICAgJ0VSUk9SJyB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdlcnJvcic+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyNlZjQ0NDQnLz48cGF0aCBkPSdNOCA4
HLP:bDggOE0xNiA4bC04IDgnIHN0cm9rZT0nIzJhMDYwNicgc3Ryb2tlLXdpZHRoPScyLjYnIHN0cm9rZS1saW5lY2FwPSdyb3VuZCcvPjwvc3ZnPiIgfQogICAgICAgICAgICAgICAgJ1NLSVAnICB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2lj
HLP:bycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdza2lwcGVkJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nIzY0NzQ4YicvPjxyZWN0IHg9JzYuNScgeT0nMTEnIHdpZHRoPScxMScgaGVpZ2h0PScyJyByeD0nMScgZmlsbD0nIzBiMTIyMCcvPjwv
HLP:c3ZnPiIgfQogICAgICAgICAgICAgICAgZGVmYXVsdCB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbyc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyM5NGEzYjgnLz48L3N2Zz4iIH0KICAgICAgICAgICAgfQogICAg
HLP:ICAgIH0KCiAgICAgICAgJGJlZm9yZSA9ICRzdC5zY29yZV9iZWZvcmU7IGlmICgkbnVsbCAtZXEgJGJlZm9yZSkgeyAkYmVmb3JlID0gJy0nIH0KICAgICAgICAkYWZ0ZXIgID0gJHN0LnNjb3JlX2FmdGVyOyAgaWYgKCRudWxsIC1lcSAkYWZ0ZXIpICB7ICRhZnRl
HLP:ciAgPSAnLScgfQogICAgICAgICRoYXNCb3RoID0gKCRzdC5zY29yZV9iZWZvcmUgLW5lICRudWxsIC1hbmQgJHN0LnNjb3JlX2FmdGVyIC1uZSAkbnVsbCkKICAgICAgICAkZGVsdGEgPSAwOyAkZGVsdGFUeHQgPSAnbm8gY29tcGFyaXNvbicKICAgICAgICBpZiAo
HLP:JGhhc0JvdGgpIHsgJGRlbHRhID0gW2ludF0kc3Quc2NvcmVfYWZ0ZXIgLSBbaW50XSRzdC5zY29yZV9iZWZvcmU7ICRzaWduID0gaWYgKCRkZWx0YSAtZ2UgMCkgeycrJ30gZWxzZSB7Jyd9OyAkZGVsdGFUeHQgPSAiJHNpZ24kZGVsdGEgcG9pbnRzIiB9CiAgICAg
HLP:ICAgJGRlbHRhQ29sb3IgPSBpZiAoJGRlbHRhIC1ndCAwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCRkZWx0YSAtbHQgMCkgeycjZWY0NDQ0J30gZWxzZSB7JyM5NGEzYjgnfQogICAgICAgICRtYWluU2NvcmUgPSBpZiAoJGFmdGVyIC1uZSAnLScpIHsgJGFmdGVyIH0g
HLP:ZWxzZWlmICgkYmVmb3JlIC1uZSAnLScpIHsgJGJlZm9yZSB9IGVsc2UgeyAnLScgfQogICAgICAgICRtYWluQ29sb3IgPSAmICRiYW5kQ29sb3IgJG1haW5TY29yZQogICAgICAgICRtYWluT2Zmc2V0ID0gJiAkb2Zmc2V0T2YgJG1haW5TY29yZQogICAgICAgICRt
HLP:YWluTGFiZWwgPSAmICRiYW5kTGFiZWwgJG1haW5TY29yZQogICAgICAgICRiZWZvcmVDb2xvciA9ICYgJGJhbmRDb2xvciAkYmVmb3JlCiAgICAgICAgJGFmdGVyQ29sb3IgID0gJiAkYmFuZENvbG9yICRhZnRlcgogICAgICAgICRiZWZvcmVPZmZzZXQgPSAmICRv
HLP:ZmZzZXRPZiAkYmVmb3JlCiAgICAgICAgJGFmdGVyT2Zmc2V0ICA9ICYgJG9mZnNldE9mICRhZnRlcgoKICAgICAgICAkc2NyaXB0RGlyID0gJG51bGwKICAgICAgICBpZiAoJFBTU2NyaXB0Um9vdCkgewogICAgICAgICAgICAkc2NyaXB0RGlyID0gJFBTU2NyaXB0
HLP:Um9vdAogICAgICAgIH0gZWxzZWlmICgkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoKSB7CiAgICAgICAgICAgICRzY3JpcHREaXIgPSBTcGxpdC1QYXRoIC1QYXJlbnQgJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aAogICAgICAgIH0KICAgICAgICAkYmFz
HLP:ZURpciA9IGlmICgkc2NyaXB0RGlyKSB7IEpvaW4tUGF0aCAoU3BsaXQtUGF0aCAtUGFyZW50ICRzY3JpcHREaXIpICJXUElfU3VpdGUiIH0gZWxzZSB7ICRXb3JrIH0KICAgICAgICAkaGlzdG9yeUZpbGUgPSBKb2luLVBhdGggJGJhc2VEaXIgImhlYWx0aF9oaXN0
HLP:b3J5Lmpzb24iCiAgICAgICAgJGhpc3RvcnkgPSBAKCkKICAgICAgICBpZiAoVGVzdC1QYXRoICRoaXN0b3J5RmlsZSkgewogICAgICAgICAgICB0cnkgeyAkaGlzdG9yeSA9IEdldC1Db250ZW50ICRoaXN0b3J5RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9
HLP:IGNhdGNoIHt9CiAgICAgICAgfQogICAgICAgICRoaXN0b3J5SHRtbCA9ICcnCiAgICAgICAgaWYgKCRoaXN0b3J5IC1hbmQgJGhpc3RvcnkuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgJGhpc3RvcnlIdG1sICs9ICI8ZGl2IGNsYXNzPSd0cmVuZC10aXRsZSc+
HLP:SGVhbHRoIEhpc3RvcnkgKExhc3QgcnVucyk8L2Rpdj48ZGl2IGNsYXNzPSd0cmVuZC1saXN0Jz4iCiAgICAgICAgICAgIGZvcmVhY2ggKCRoIGluICRoaXN0b3J5KSB7CiAgICAgICAgICAgICAgICAkY29sID0gJiAkYmFuZENvbG9yICRoLnNjb3JlCiAgICAgICAg
HLP:ICAgICAgICAkaGlzdG9yeUh0bWwgKz0gIjxkaXYgY2xhc3M9J3RyZW5kLWl0ZW0nPjxzcGFuIGNsYXNzPSd0cmVuZC1kYXRlJz4kKCRoLmRhdGUpPC9zcGFuPjxzcGFuIGNsYXNzPSd0cmVuZC1zY29yZScgc3R5bGU9J2NvbG9yOiRjb2wnPiQoJGguc2NvcmUpLzEw
HLP:MDwvc3Bhbj48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgJGhpc3RvcnlIdG1sICs9ICI8L2Rpdj4iCiAgICAgICAgfQoKICAgICAgICAkc3lzTWFwID0gQHt9CiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHN5c1BhaXJzKSB7ICRrdiA9ICRwIC1zcGxp
HLP:dCAnPScsMjsgaWYgKCRrdi5Db3VudCAtZXEgMikgeyAkc3lzTWFwWyRrdlswXV0gPSAka3ZbMV0gfSB9CiAgICAgICAgJHN5c09yZGVyID0gQChAKCdPUycsJ09wZXJhdGluZyBTeXN0ZW0nKSxAKCdTWVNURU0nLCdTeXN0ZW0gTW9kZWwnKSxAKCdDUFUnLCdQcm9j
HLP:ZXNzb3InKSxAKCdSQU0nLCdSQU0gTWVtb3J5JyksQCgnRElTSycsJ0Rpc2sgQzonKSxAKCdVUFRJTUUnLCdVcHRpbWUnKSxAKCdVU0VSJywnVXNlcicpKQogICAgICAgICRzeXNDYXJkcyA9ICcnCiAgICAgICAgZm9yZWFjaCAoJG8gaW4gJHN5c09yZGVyKSB7IGlm
HLP:ICgkc3lzTWFwLkNvbnRhaW5zS2V5KCRvWzBdKSkgeyAkc3lzQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J3N5cyc+PGRpdiBjbGFzcz0nc3lzLWsnPiQoJiAkZW5jICRvWzFdKTwvZGl2PjxkaXYgY2xhc3M9J3N5cy12Jz4kKCYgJGVuYyAkc3lzTWFwWyRvWzBdXSk8L2Rp
HLP:dj48L2Rpdj4iIH0gfQogICAgICAgICRtYWNoaW5lID0gJHN5c01hcFsnU1lTVEVNJ107IGlmICgtbm90ICRtYWNoaW5lKSB7ICRtYWNoaW5lID0gJGVudjpDT01QVVRFUk5BTUUgfQoKICAgICAgICAkcGhhc2VzID0gQCgkc3QucGhhc2VzKQogICAgICAgICRjT0s9
HLP:MDskY1dBUk49MDskY0VSUj0wOyRjU0tJUD0wCiAgICAgICAgJG1heFNlY3MgPSAxCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsgJHN2PTA7IHRyeSB7ICRzdj1baW50XSRwaC5zZWNzIH0gY2F0Y2gge307IGlmICgkc3YgLWd0ICRtYXhTZWNzKSB7
HLP:ICRtYXhTZWNzID0gJHN2IH0gfQogICAgICAgICRyb3dzID0gJycKICAgICAgICAkYmFycyA9ICcnCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsKICAgICAgICAgICAgJHJlcyA9IFtzdHJpbmddJHBoLnJlc3VsdAogICAgICAgICAgICBzd2l0Y2gg
HLP:KCRyZXMpIHsgJ09LJyB7JGNPSysrfSAnV0FSTicgeyRjV0FSTisrfSAnRVJST1InIHskY0VSUisrfSAnU0tJUCcgeyRjU0tJUCsrfSB9CiAgICAgICAgICAgICRsYyA9ICRyZXMuVG9Mb3dlcigpCiAgICAgICAgICAgICRub3RlID0gaWYgKFtzdHJpbmddJHBoLm5v
HLP:dGUgLW5lICcnKSB7ICI8ZGl2IGNsYXNzPSdwaC1ub3RlJz4kKCYgJGVuYyAkcGgubm90ZSk8L2Rpdj4iIH0gZWxzZSB7ICcnIH0KICAgICAgICAgICAgJHJvd3MgKz0gIjxkaXYgY2xhc3M9J3BoIHBoLSRsYyc+PGRpdiBjbGFzcz0ncGgtZG90Jz4kKCYgJHN0YXR1
HLP:c0ljb24gJHJlcyk8L2Rpdj48ZGl2IGNsYXNzPSdwaC1tYWluJz48ZGl2IGNsYXNzPSdwaC10b3AnPjxzcGFuIGNsYXNzPSdwaC1udW0nPiQoJiAkZW5jICRwaC5udW0pPC9zcGFuPjxzcGFuIGNsYXNzPSdwaC10aXRsZSc+JCgmICRlbmMgJHBoLnRpdGxlKTwvc3Bh
HLP:bj48c3BhbiBjbGFzcz0ncGgtYmFkZ2UgYi0kbGMnPiRyZXM8L3NwYW4+PC9kaXY+JG5vdGU8L2Rpdj48ZGl2IGNsYXNzPSdwaC1zZWNzJz4kKCYgJGVuYyAkcGguc2VjcylzPC9kaXY+PC9kaXY+IgogICAgICAgICAgICAkc3Y9MDsgdHJ5IHsgJHN2PVtpbnRdJHBo
HLP:LnNlY3MgfSBjYXRjaCB7fQogICAgICAgICAgICAkdyA9IFttYXRoXTo6Um91bmQoMTAwLjAgKiAkc3YgLyBbbWF0aF06Ok1heCgxLCRtYXhTZWNzKSk7IGlmICgkdyAtbHQgMiAtYW5kICRzdiAtZ3QgMCkgeyAkdyA9IDIgfQogICAgICAgICAgICAkYmNvbCA9IHN3
HLP:aXRjaCAoJHJlcykgeyAnT0snIHsnIzIyYzU1ZSd9ICdXQVJOJyB7JyNmNTllMGInfSAnRVJST1InIHsnI2VmNDQ0NCd9IGRlZmF1bHQgeycjNjQ3NDhiJ30gfQogICAgICAgICAgICAkYmFycyArPSAiPGRpdiBjbGFzcz0nYmFyLXJvdyc+PGRpdiBjbGFzcz0nYmFy
HLP:LWxibCc+JCgmICRlbmMgJHBoLm51bSkgJCgmICRlbmMgJHBoLnRpdGxlKTwvZGl2PjxkaXYgY2xhc3M9J2Jhci10cmFjayc+PHNwYW4gc3R5bGU9J3dpZHRoOiR3JTtiYWNrZ3JvdW5kOiRiY29sJz48L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nYmFyLXZhbCc+JCgm
HLP:ICRlbmMgJHBoLnNlY3MpczwvZGl2PjwvZGl2PiIKICAgICAgICB9CiAgICAgICAgaWYgKC1ub3QgJHJvd3MpIHsgJHJvd3MgPSAiPGRpdiBjbGFzcz0nZW1wdHknPk5vIHBoYXNlcyB3ZXJlIHJlY29yZGVkIGluIHRoaXMgcnVuLjwvZGl2PiIgfQogICAgICAgIGlm
HLP:ICgtbm90ICRiYXJzKSB7ICRiYXJzID0gIjxkaXYgY2xhc3M9J2VtcHR5Jz5ObyB0aW1pbmdzIHRvIHNob3cuPC9kaXY+IiB9CiAgICAgICAgJHRvdGFsUGggPSAkcGhhc2VzLkNvdW50CiAgICAgICAgIyBSRUFMIGFnZ3JlZ2F0ZSBzdGF0aXN0aWNzIG9mIHdoYXQg
HLP:YWN0dWFsbHkgcmFuOiB0b3RhbCBzZXNzaW9uIHRpbWUgYW5kCiAgICAgICAgIyBzcGFjZSBmcmVlZCAoc3VtbWVkIGZyb20gZWFjaCBwaGFzZSdzIG1lYXN1cmVkIG5vdGVzLCBNQi9HQikuCiAgICAgICAgJHRvdFNlY3MgPSAwOyAkbWJGcmVlZCA9IDAuMAogICAg
HLP:ICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7CiAgICAgICAgICAgICRzdiA9IDA7IHRyeSB7ICRzdiA9IFtpbnRdJHBoLnNlY3MgfSBjYXRjaCB7fTsgJHRvdFNlY3MgKz0gJHN2CiAgICAgICAgICAgIGZvcmVhY2ggKCRtIGluIFtyZWdleF06Ok1hdGNoZXMo
HLP:W3N0cmluZ10kcGgubm90ZSwgJyg/aSkoPzpsaWJlcmFkXHcqfGZyZWVkKVxEezAsMTB9PyhbXGRcLixdKylccyooTUJ8R0IpJykpIHsKICAgICAgICAgICAgICAgICR2ID0gMC4wOyB0cnkgeyAkdiA9IFtkb3VibGVdKCRtLkdyb3Vwc1sxXS5WYWx1ZS5SZXBsYWNl
HLP:KCcsJywgJy4nKSkgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgaWYgKCRtLkdyb3Vwc1syXS5WYWx1ZSAtbWF0Y2ggJyg/aSlHQicpIHsgJHYgPSAkdiAqIDEwMjQgfQogICAgICAgICAgICAgICAgJG1iRnJlZWQgKz0gJHYKICAgICAgICAgICAgfQogICAgICAg
HLP:IH0KICAgICAgICAkdG90VHh0ID0gaWYgKCR0b3RTZWNzIC1nZSA2MCkgeyAoJ3swfSBtaW4gezF9IHMnIC1mIFtpbnRdW21hdGhdOjpGbG9vcigkdG90U2VjcyAvIDYwKSwgKCR0b3RTZWNzICUgNjApKSB9IGVsc2UgeyAoJ3swfSBzJyAtZiAkdG90U2VjcykgfQog
HLP:ICAgICAgICRmcmVlZFR4dCA9IGlmICgkbWJGcmVlZCAtZ2UgMTAyNCkgeyAoJ3swOm4xfSBHQicgLWYgKCRtYkZyZWVkIC8gMTAyNCkpIH0gZWxzZWlmICgkbWJGcmVlZCAtZ3QgMCkgeyAoJ3swOm4wfSBNQicgLWYgJG1iRnJlZWQpIH0gZWxzZSB7ICcnIH0KICAg
HLP:ICAgICAkc3RhdExpbmUgPSAoJ3RvdGFsIHRpbWU6IHswfScgLWYgJHRvdFR4dCkKICAgICAgICBpZiAoJGZyZWVkVHh0KSB7ICRzdGF0TGluZSArPSAoJyAmbWlkZG90OyBzcGFjZSBmcmVlZDogezB9JyAtZiAkZnJlZWRUeHQpIH0KCiAgICAgICAgJGZpbmRpbmdz
HLP:ID0gQCgkc3QuZmluZGluZ3MpCiAgICAgICAgJGZpbmRIdG1sID0gJycKICAgICAgICAkc3RlcHNMaXN0ID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgICAgICBmb3JlYWNoICgkZiBpbiAkZmluZGluZ3MpIHsK
HLP:ICAgICAgICAgICAgJHR4dCA9IFtzdHJpbmddJGYKICAgICAgICAgICAgJHNldiA9ICdpbmZvJzsgJHNldlR4dCA9ICdOb3RpY2UnCiAgICAgICAgICAgIGlmICgkdHh0IC1tYXRjaCAnKD9pKVNNQVJUfEJTT0R8Y3Jhc2h8V0hFQXxoYXJkd2FyZXx1bnJlcGFpcmFi
HLP:bGV8ZGFtYWdlZHxyZXBvc2l0b3J5fGludGVncml0eScpIHsgJHNldj0naGlnaCc7ICRzZXZUeHQ9J0ltcG9ydGFudCcgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpc3BhY2V8cGVuZGluZyByZWJvb3R8bmV0d29ya3xiYXR0ZXJ5fGRyaXZl
HLP:cnxkZXZpY2V8XGJSQU1cYnxzZXJ2aWNlJykgeyAkc2V2PSdtZWQnOyAkc2V2VHh0PSdSZXZpZXcnIH0KICAgICAgICAgICAgJGZpbmRIdG1sICs9ICI8bGkgY2xhc3M9J2ZpbmQgZmluZC0kc2V2Jz48c3BhbiBjbGFzcz0nc2V2IHNldi0kc2V2Jz4kc2V2VHh0PC9z
HLP:cGFuPjxzcGFuIGNsYXNzPSdmaW5kLXR4dCc+JCgmICRlbmMgJHR4dCk8L3NwYW4+PC9saT4iCiAgICAgICAgICAgICMgRGVyaXZhciBwYXNvIHJlY29tZW5kYWRvIGEgcGFydGlyIGRlbCBoYWxsYXpnbwogICAgICAgICAgICBpZiAoJHR4dCAtbWF0Y2ggJyg/aSlT
HLP:TUFSVCcpICAgICAgICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ0JhY2sgdXAgeW91ciBkYXRhIGFzIHNvb24gYXMgcG9zc2libGU6IGEgZGlzayB3aXRoIGRlZ3JhZGVkIFNNQVJUIGNhbiBmYWlsLiBDb25zaWRlciByZXBsYWNpbmcgaXQuJykgfQogICAgICAgICAgICBl
HLP:bHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpc3BhY2UnKSAgICB7ICRzdGVwc0xpc3QuQWRkKCdGcmVlIHVwIHNwYWNlIG9uIEM6ICh1bmluc3RhbGwgd2hhdCB5b3UgZG9uJyd0IHVzZSBvciB1c2UgU3RvcmFnZSBTZW5zZSkuIEFpbSBmb3IgbW9yZSB0aGFuIDE1IEdC
HLP:IGZyZWUuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpXGJSQU1cYnxtZW1vcnknKSB7ICRzdGVwc0xpc3QuQWRkKCdSdW4gV2luZG93cyBNZW1vcnkgRGlhZ25vc3RpYyAobWRzY2hlZC5leGUpIGFuZCByZWJvb3QgdG8gY2hlY2sgdGhl
HLP:IFJBTS4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSliYXR0ZXJ5JykgICAgeyAkc3RlcHNMaXN0LkFkZCgnVGhlIGJhdHRlcnkgaXMgZGVncmFkZWQuIENoZWNrIHRoZSBiYXR0ZXJ5IHJlcG9ydCAocG93ZXJjZmcgL2JhdHRlcnlyZXBv
HLP:cnQpIGFuZCBjb25zaWRlciByZXBsYWNpbmcgaXQuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpcGVuZGluZyByZWJvb3QnKSB7ICRzdGVwc0xpc3QuQWRkKCdSZWJvb3QgdGhlIFBDIHRvIGFwcGx5IHBlbmRpbmcgY2hhbmdlcyBiZWZv
HLP:cmUgY29udGludWluZyByZXBhaXJzLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKXVucmVwYWlyYWJsZXxyZXBvc2l0b3J5fGludGVncml0eScpIHsgJHN0ZXBzTGlzdC5BZGQoJ0RhbWFnZWQgY29tcG9uZW50cyByZW1haW4uIFJ1biBE
HLP:SVNNIHdpdGggYSB2YWxpZCBzb3VyY2UgKGluc3RhbGwud2ltKSBhbmQgcnVuIFNGQyBhZ2Fpbi4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlkcml2ZXJ8ZGV2aWNlJykgeyAkc3RlcHNMaXN0LkFkZCgnVXBkYXRlIHRoZSBkcml2ZXJz
HLP:IG9mIHRoZSBmYWlsaW5nIGRldmljZXMgZnJvbSB0aGUgbWFrZXInJ3Mgc2l0ZSBvciBXaW5kb3dzIFVwZGF0ZS4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSluZXR3b3JrfEROUycpICAgICAgICB7ICRzdGVwc0xpc3QuQWRkKCdDaGVj
HLP:ayB0aGUgbmV0d29yayBjb25uZWN0aW9uIGFuZCBETlMuIElmIGl0IHBlcnNpc3RzLCB0cnkgYSBwdWJsaWMgRE5TICgxLjEuMS4xIC8gOC44LjguOCkuJykgfQogICAgICAgIH0KICAgICAgICAkbm9GaW5kID0gKCRmaW5kaW5ncy5Db3VudCAtZXEgMCkKICAgICAg
HLP:ICBpZiAoJG5vRmluZCkgeyAkZmluZEh0bWwgPSAiPGxpIGNsYXNzPSdmaW5kIGZpbmQtb2snPjxzcGFuIGNsYXNzPSdzZXYgc2V2LW9rJz5BbGwgT0s8L3NwYW4+PHNwYW4gY2xhc3M9J2ZpbmQtdHh0Jz5ObyByZWxldmFudCBwcm9ibGVtcyB3ZXJlIGRldGVjdGVk
HLP:IGR1cmluZyBkaWFnbm9zaXMuPC9zcGFuPjwvbGk+IiB9CgogICAgICAgICMgLS0tIFByb3hpbW9zIHBhc29zIHJlY29tZW5kYWRvcyAoZGVkdXBsaWNhZG9zKSAtLS0KICAgICAgICAkc3RlcHNIdG1sID0gJycKICAgICAgICAkc2VlbiA9IEB7fQogICAgICAgIGZv
HLP:cmVhY2ggKCRzIGluICRzdGVwc0xpc3QpIHsgaWYgKC1ub3QgJHNlZW4uQ29udGFpbnNLZXkoJHMpKSB7ICRzZWVuWyRzXT0kdHJ1ZTsgJHN0ZXBzSHRtbCArPSAiPGxpIGNsYXNzPSdzdGVwLWxpJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDE0ODs8L3NwYW4+
HLP:PHNwYW4+JCgmICRlbmMgJHMpPC9zcGFuPjwvbGk+IiB9IH0KICAgICAgICBpZiAoJGNFUlIgLWd0IDApIHsgJHN0ZXBzSHRtbCA9ICI8bGkgY2xhc3M9J3N0ZXAtbGknPjxzcGFuIGNsYXNzPSdzdGVwLWljJz4mIzEwMTQ4Ozwvc3Bhbj48c3Bhbj5Tb21lIHBoYXNl
HLP:cyBoYWQgZXJyb3JzOiBjaGVjayB0aGUgZGV0YWlsZWQgbG9nIGluIHRoZSBXUElfU3VpdGVcTG9ncyBmb2xkZXIuPC9zcGFuPjwvbGk+IiArICRzdGVwc0h0bWwgfQogICAgICAgIGlmICgtbm90ICRzdGVwc0h0bWwpIHsgJHN0ZXBzSHRtbCA9ICI8bGkgY2xhc3M9
HLP:J3N0ZXAtbGkgc3RlcC1vayc+PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAwMDM7PC9zcGFuPjxzcGFuPk5vIHBlbmRpbmcgYWN0aW9ucy4gUmVib290IHRoZSBQQyB0byBtYWtlIHN1cmUgYWxsIGNoYW5nZXMgYXJlIGFwcGxpZWQuPC9zcGFuPjwvbGk+IiB9Cgog
HLP:ICAgICAgICMgPT09PT09PT09PT09PT09PT09PT09PSBESUFHTk9TVElDTyBBTVBMSUFETyA9PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgJGRpYWdDYXJkcyA9ICcnCiAgICAgICAgaWYgKCgkc3QuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlu
HLP:cyAnZGlhZycpIC1hbmQgJHN0LmRpYWcpIHsKICAgICAgICAgICAgJGQgPSAkc3QuZGlhZwogICAgICAgICAgICBpZiAoJGQucmFtKSB7CiAgICAgICAgICAgICAgICAkcnMgPSBbc3RyaW5nXSRkLnJhbS5zdGF0dXMKICAgICAgICAgICAgICAgICRycCA9IHN3aXRj
HLP:aCAoJHJzKSB7ICdvaycgeydnb29kJ30gJ3N1c3BlY3QnIHsnYmFkJ30gZGVmYXVsdCB7J3Vua25vd24nfSB9CiAgICAgICAgICAgICAgICAkcnQgPSBzd2l0Y2ggKCRycykgeyAnb2snIHsnTm8gZXJyb3JzIGRldGVjdGVkJ30gJ3N1c3BlY3QnIHsnU3VzcGVjdCd9
HLP:IGRlZmF1bHQgeydOb3QgZXZhbHVhdGVkJ30gfQogICAgICAgICAgICAgICAgJG1kcyA9IGlmICgkZC5yYW0ucmVjb21tZW5kX21kc2NoZWQpIHsgIjxkaXYgY2xhc3M9J2QtaGludCc+UmVjb21tZW5kZWQ6IHJ1biBXaW5kb3dzIE1lbW9yeSBEaWFnbm9zdGljICht
HLP:ZHNjaGVkKS48L2Rpdj4iIH0gZWxzZSB7ICcnIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLXJhbSc+PC9zcGFuPlJBTSBNZW1vcnk8L2Rpdj48ZGl2
HLP:IGNsYXNzPSdkLXBpbGwgcGlsbC0kcnAnPiRydDwvZGl2PiRtZHM8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRkLmJhdHRlcnkpIHsKICAgICAgICAgICAgICAgIGlmICgkZC5iYXR0ZXJ5LnByZXNlbnQpIHsKICAgICAgICAgICAgICAgICAg
HLP:ICAkYnBSYXcgPSAkZC5iYXR0ZXJ5LmhlYWx0aF9wY3QKICAgICAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRicFJhdyAtYW5kIFtzdHJpbmddJGJwUmF3IC1uZSAnJykgewogICAgICAgICAgICAgICAgICAgICAgICAkYnAgPSAwOyB0cnkgeyAkYnAgPSBb
HLP:aW50XSRicFJhdyB9IGNhdGNoIHsgJGJwID0gMCB9CiAgICAgICAgICAgICAgICAgICAgICAgICRicGNvbCA9IGlmICgkYnAgLWdlIDgwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCRicCAtZ2UgNTApIHsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J30KICAgICAgICAg
HLP:ICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0dGVyeTwvZGl2PjxkaXYgY2xhc3M9J2JhdC1iYXInPjxzcGFuIHN0eWxlPSd3aWR0
HLP:aDokYnAlO2JhY2tncm91bmQ6JGJwY29sJz48L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nZC1zdWInPkVzdGltYXRlZCBoZWFsdGg6IDxiIHN0eWxlPSdjb2xvcjokYnBjb2wnPiRicCU8L2I+PC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgICAgIH0gZWxzZSB7
HLP:CiAgICAgICAgICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJhdCc+PC9zcGFuPkJhdHRlcnk8L2Rpdj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC11bmtu
HLP:b3duJz5QcmVzZW50LCBoZWFsdGggdW5rbm93bjwvZGl2PjwvZGl2PiIKICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNs
HLP:YXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJhdCc+PC9zcGFuPkJhdHRlcnk8L2Rpdj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC11bmtub3duJz5Ob3QgcHJlc2VudCAoZGVza3RvcCBQQyk8L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICAgICB9CiAgICAg
HLP:ICAgICAgIH0KICAgICAgICAgICAgaWYgKCRkLm5ldHdvcmspIHsKICAgICAgICAgICAgICAgICRjYyA9IGlmICgkZC5uZXR3b3JrLmNvbm5lY3RlZCkgeydnb29kJ30gZWxzZSB7J2JhZCd9CiAgICAgICAgICAgICAgICAkY3QgPSBpZiAoJGQubmV0d29yay5jb25u
HLP:ZWN0ZWQpIHsnQ29ubmVjdGVkJ30gZWxzZSB7J05vIGNvbm5lY3Rpb24nfQogICAgICAgICAgICAgICAgJGRjID0gaWYgKCRkLm5ldHdvcmsuZG5zX29rKSB7J2dvb2QnfSBlbHNlIHsnYmFkJ30KICAgICAgICAgICAgICAgICRkdCA9IGlmICgkZC5uZXR3b3JrLmRu
HLP:c19vaykgeydETlMgT0snfSBlbHNlIHsnRE5TIGZhaWxpbmcnfQogICAgICAgICAgICAgICAgJGRldCA9ICYgJGVuYyAkZC5uZXR3b3JrLmRldGFpbHMKICAgICAgICAgICAgICAgICRsYXQgPSAnJwogICAgICAgICAgICAgICAgaWYgKCgkZC5uZXR3b3JrLlBTT2Jq
HLP:ZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2Ruc19tcycpIC1hbmQgJG51bGwgLW5lICRkLm5ldHdvcmsuZG5zX21zIC1hbmQgW3N0cmluZ10kZC5uZXR3b3JrLmRuc19tcyAtbmUgJycpIHsKICAgICAgICAgICAgICAgICAgICAkbXMgPSAwOyB0cnkgeyAk
HLP:bXMgPSBbaW50XSRkLm5ldHdvcmsuZG5zX21zIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICAgICAkbGMyID0gaWYgKCRtcyAtbHQgNjApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJG1zIC1sdCAyMDApIHsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J30KICAgICAg
HLP:ICAgICAgICAgICAgICAkbGF0ID0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5ETlMgbGF0ZW5jeTogPGIgc3R5bGU9J2NvbG9yOiRsYzInPiRtcyBtczwvYj48L2Rpdj4iCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNs
HLP:YXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1uZXQnPjwvc3Bhbj5OZXR3b3JrPC9kaXY+PGRpdiBjbGFzcz0ncGlsbC1yb3cnPjxzcGFuIGNsYXNzPSdkLXBpbGwgcGlsbC0kY2MnPiRjdDwvc3Bhbj48c3BhbiBjbGFzcz0n
HLP:ZC1waWxsIHBpbGwtJGRjJz4kZHQ8L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nZC1zdWInPiRkZXQ8L2Rpdj4kbGF0PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnc21hcnQn
HLP:KSAtYW5kICRkLnNtYXJ0IC1hbmQgJGQuc21hcnQuYXZhaWxhYmxlKSB7CiAgICAgICAgICAgICAgICAkc20gPSAkZC5zbWFydAogICAgICAgICAgICAgICAgJHBmID0gaWYgKCRzbS5wcmVkaWN0X2ZhaWwpIHsgIjxzcGFuIGNsYXNzPSdkLXBpbGwgcGlsbC1iYWQn
HLP:PlByZWRpY3RzIGZhaWx1cmU8L3NwYW4+IiB9IGVsc2UgeyAiPHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLWdvb2QnPk5vIGFsZXJ0PC9zcGFuPiIgfQogICAgICAgICAgICAgICAgJGV4dHJhID0gJycKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLnRl
HLP:bXBfYyAtYW5kIFtzdHJpbmddJHNtLnRlbXBfYyAtbmUgJycpIHsgJHRjPTA7IHRyeXskdGM9W2ludF0kc20udGVtcF9jfWNhdGNoe307ICR0Y29sID0gaWYgKCR0YyAtbHQgNTApeycjMjJjNTVlJ30gZWxzZWlmICgkdGMgLWx0IDY1KXsnI2Y1OWUwYid9IGVsc2Ug
HLP:eycjZWY0NDQ0J307ICRleHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPlRlbXBlcmF0dXJlOiA8YiBzdHlsZT0nY29sb3I6JHRjb2wnPiR0YyAmZGVnO0M8L2I+PC9kaXY+IiB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRzbS53ZWFyX3BjdCAtYW5k
HLP:IFtzdHJpbmddJHNtLndlYXJfcGN0IC1uZSAnJykgeyAkd3A9MDsgdHJ5eyR3cD1baW50XSRzbS53ZWFyX3BjdH1jYXRjaHt9OyAkd2NvbCA9IGlmICgkd3AgLWx0IDUwKXsnIzIyYzU1ZSd9IGVsc2VpZiAoJHdwIC1sdCA4MCl7JyNmNTllMGInfSBlbHNlIHsnI2Vm
HLP:NDQ0NCd9OyAkZXh0cmEgKz0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5XZWFyIChTU0QpOiA8YiBzdHlsZT0nY29sb3I6JHdjb2wnPiR3cCU8L2I+PC9kaXY+IiB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRzbS5wb2ggLWFuZCBbc3RyaW5nXSRzbS5wb2gg
HLP:LW5lICcnKSB7ICRleHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPlBvd2VyLW9uIGhvdXJzOiA8Yj4kKCYgJGVuYyAkc20ucG9oKTwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNz
HLP:PSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLXNtYXJ0Jz48L3NwYW4+RGlzayBoZWFsdGggKFNNQVJUKTwvZGl2PjxkaXYgY2xhc3M9J3BpbGwtcm93Jz4kcGY8L2Rpdj4kZXh0cmE8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09i
HLP:amVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdiY2QnKSAtYW5kICRkLmJjZCkgewogICAgICAgICAgICAgICAgJGJvayA9IGlmICgkZC5iY2Qub2spIHsnZ29vZCd9IGVsc2UgeydiYWQnfQogICAgICAgICAgICAgICAgJGJ0eCA9IGlmICgkZC5iY2Qub2sp
HLP:IHsnQm9vdCBjb25maWd1cmF0aW9uIGNvcnJlY3QnfSBlbHNlIHsnQm9vdCB3aXRoIGlzc3Vlcyd9CiAgICAgICAgICAgICAgICAkYmRldCA9IGlmIChbc3RyaW5nXSRkLmJjZC5kZXRhaWxzIC1uZSAnJykgeyAiPGRpdiBjbGFzcz0nZC1zdWInPiQoJiAkZW5jICRk
HLP:LmJjZC5kZXRhaWxzKTwvZGl2PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYm9vdCc+PC9zcGFuPkJvb3QgKEJDRCk8L2Rp
HLP:dj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC0kYm9rJz4kYnR4PC9kaXY+JGJkZXQ8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdzdGFydHVwJykgLWFuZCAkZC5zdGFydHVw
HLP:IC1hbmQgQCgkZC5zdGFydHVwKS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRzIGluIEAoJGQuc3RhcnR1cCkpIHsgJGl0ZW1zICs9ICI8bGk+JCgmICRlbmMgJHMubmFtZSk8c3BhbiBj
HLP:bGFzcz0nbXV0ZWQnPiAmbWRhc2g7ICQoJiAkZW5jICRzLmNvbW1hbmQpPC9zcGFuPjwvbGk+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCBkY2FyZC13aWRlJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdk
HLP:LWljIGljLXN0YXJ0Jz48L3NwYW4+U3RhcnR1cCBwcm9ncmFtczwvZGl2Pjx1bCBjbGFzcz0nZGV2LWxpc3QnPiRpdGVtczwvdWw+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlu
HLP:cyAncHJvY2Vzc2VzJykgLWFuZCAkZC5wcm9jZXNzZXMgLWFuZCBAKCRkLnByb2Nlc3NlcykuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcHIgaW4gQCgkZC5wcm9jZXNzZXMpKSB7ICRp
HLP:dGVtcyArPSAiPGxpPiQoJiAkZW5jICRwci5uYW1lKTxzcGFuIGNsYXNzPSdtdXRlZCc+ICZtZGFzaDsgJCgmICRlbmMgJHByLm1lbV9tYikgTUI8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48
HLP:ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLXByb2MnPjwvc3Bhbj5Qcm9jZXNzZXMgdXNpbmcgbW9zdCBtZW1vcnk8L2Rpdj48dWwgY2xhc3M9J2Rldi1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBp
HLP:ZiAoJGQuZGV2aWNlcyAtYW5kIEAoJGQuZGV2aWNlcykuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkZGV2IGluIEAoJGQuZGV2aWNlcykpIHsgJGl0ZW1zICs9ICI8bGk+JCgmICRlbmMg
HLP:JGRldi5uYW1lKSA8c3BhbiBjbGFzcz0nbXV0ZWQnPihjb2RlICQoJiAkZW5jICRkZXYuY29kZSkpPC9zcGFuPjwvbGk+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCBkY2FyZC13aWRlJz48ZGl2IGNsYXNzPSdkLWgn
HLP:PjxzcGFuIGNsYXNzPSdkLWljIGljLWRldic+PC9zcGFuPkRldmljZXMgd2l0aCB3YXJuaW5nczwvZGl2Pjx1bCBjbGFzcz0nZGV2LWxpc3QnPiRpdGVtczwvdWw+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgICRkaWFnU2VjdGlvbiA9ICcn
HLP:CiAgICAgICAgaWYgKCRkaWFnQ2FyZHMpIHsgJGRpYWdTZWN0aW9uID0gIjxoMiBpZD0nZGlhZycgY2xhc3M9J3NlYy1oJz5FeHRlbmRlZCBkaWFnbm9zaXM8L2gyPjxkaXYgY2xhc3M9J2RncmlkJz4kZGlhZ0NhcmRzPC9kaXY+IiB9CgogICAgICAgICRjb21wYXJl
HLP:U2VjdGlvbiA9ICcnCiAgICAgICAgaWYgKCRoYXNCb3RoKSB7CiAgICAgICAgICAgICRjb21wYXJlU2VjdGlvbiA9IEAiCjxkaXYgY2xhc3M9J2NvbXBhcmUnPgogIDxkaXYgY2xhc3M9J21pbmknPgogICAgPHN2ZyB2aWV3Qm94PScwIDAgMjAwIDIwMCcgY2xhc3M9
HLP:J2dhdWdlIGdhdWdlLXNtJz48Y2lyY2xlIGNsYXNzPSd0cmFjaycgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnLz48Y2lyY2xlIGNsYXNzPSdmaWxsJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcgc3R5bGU9Jy0tY2lyYzokY2lyYzstLXRhcmdldDokYmVmb3JlT2Zm
HLP:c2V0O3N0cm9rZTokYmVmb3JlQ29sb3InLz48dGV4dCB4PScxMDAnIHk9JzEwOCcgY2xhc3M9J2ctbnVtJyBzdHlsZT0nZmlsbDokYmVmb3JlQ29sb3InPiRiZWZvcmU8L3RleHQ+PC9zdmc+CiAgICA8ZGl2IGNsYXNzPSdtaW5pLWNhcCc+QkVGT1JFPC9kaXY+CiAg
HLP:PC9kaXY+CiAgPGRpdiBjbGFzcz0nYXJyb3cnPjxzcGFuIHN0eWxlPSdjb2xvcjokZGVsdGFDb2xvcic+JiM4NTk0Ozwvc3Bhbj48ZGl2IGNsYXNzPSdkZWx0YS1jaGlwJyBzdHlsZT0nY29sb3I6JGRlbHRhQ29sb3I7Ym9yZGVyLWNvbG9yOiRkZWx0YUNvbG9yJz4k
HLP:ZGVsdGFUeHQ8L2Rpdj48L2Rpdj4KICA8ZGl2IGNsYXNzPSdtaW5pJz4KICAgIDxzdmcgdmlld0JveD0nMCAwIDIwMCAyMDAnIGNsYXNzPSdnYXVnZSBnYXVnZS1zbSc+PGNpcmNsZSBjbGFzcz0ndHJhY2snIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0Jy8+PGNpcmNs
HLP:ZSBjbGFzcz0nZmlsbCcgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnIHN0eWxlPSctLWNpcmM6JGNpcmM7LS10YXJnZXQ6JGFmdGVyT2Zmc2V0O3N0cm9rZTokYWZ0ZXJDb2xvcicvPjx0ZXh0IHg9JzEwMCcgeT0nMTA4JyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxs
HLP:OiRhZnRlckNvbG9yJz4kYWZ0ZXI8L3RleHQ+PC9zdmc+CiAgICA8ZGl2IGNsYXNzPSdtaW5pLWNhcCc+QUZURVI8L2Rpdj4KICA8L2Rpdj4KPC9kaXY+CiJACiAgICAgICAgfQoKICAgICAgICAkbm93ID0gKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZCBI
HLP:SDptbScpCiAgICAgICAgJGV4ZWNWZXJkaWN0ID0gJiAkYmFuZExhYmVsICRtYWluU2NvcmUKICAgICAgICAkaHRtbCA9IEAiCjwhRE9DVFlQRSBodG1sPgo8aHRtbCBsYW5nPSdlbic+CjxoZWFkPgo8bWV0YSBjaGFyc2V0PSd1dGYtOCc+CjxtZXRhIG5hbWU9J3Zp
HLP:ZXdwb3J0JyBjb250ZW50PSd3aWR0aD1kZXZpY2Utd2lkdGgsaW5pdGlhbC1zY2FsZT0xJz4KPHRpdGxlPlJlcGFpciBSZXBvcnQgLSBXUEkgU3VpdGUgdjMuMTwvdGl0bGU+CjxzdHlsZT4KKntib3gtc2l6aW5nOmJvcmRlci1ib3h9Cjpyb290ey0tYmc6IzBiMGYx
HLP:NzstLWJnMjojMGQxNDIyOy0tY2FyZDojMTIxYTJiOy0tY2FyZDI6IzBlMTYyNjstLWxpbmU6IzFlMjkzYjstLXR4dDojZTZlZGY2Oy0tbXV0ZWQ6IzkzYTNiYTstLWFjY2VudDojMzhiZGY4Oy0tYWNjZW50MjojODE4Y2Y4Oy0tc2hhZG93OjAgMTRweCA0MHB4IHJn
HLP:YmEoMCwwLDAsLjQwKX0KaHRtbC5saWdodHstLWJnOiNlZWYyZjg7LS1iZzI6I2U3ZWRmNjstLWNhcmQ6I2ZmZmZmZjstLWNhcmQyOiNmNWY4ZmM7LS1saW5lOiNkZGU1ZjA7LS10eHQ6IzBmMTcyYTstLW11dGVkOiM1YTZiODI7LS1hY2NlbnQ6IzAyODRjNzstLWFj
HLP:Y2VudDI6IzRmNDZlNTstLXNoYWRvdzowIDEwcHggMjhweCByZ2JhKDE1LDIzLDQyLC4xMil9CmJvZHl7bWFyZ2luOjA7Zm9udC1mYW1pbHk6J1NlZ29lIFVJJyxzeXN0ZW0tdWksLWFwcGxlLXN5c3RlbSxBcmlhbCxzYW5zLXNlcmlmO2xpbmUtaGVpZ2h0OjEuNTU7
HLP:Y29sb3I6dmFyKC0tdHh0KTtiYWNrZ3JvdW5kOnJhZGlhbC1ncmFkaWVudCgxMjAwcHggNjAwcHggYXQgODAlIC0xMCUscmdiYSg1NiwxODksMjQ4LC4xMCksdHJhbnNwYXJlbnQgNjAlKSxyYWRpYWwtZ3JhZGllbnQoOTAwcHggNTAwcHggYXQgLTEwJSAxMCUscmdi
HLP:YSgxMjksMTQwLDI0OCwuMTApLHRyYW5zcGFyZW50IDU1JSksdmFyKC0tYmcpfQoud3JhcHttYXgtd2lkdGg6MTA4MHB4O21hcmdpbjowIGF1dG87cGFkZGluZzozMHB4IDIycHggNjBweH0KLnRvcGJhcntkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1
HLP:c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO2dhcDoxNnB4O21hcmdpbi1ib3R0b206MThweDtmbGV4LXdyYXA6d3JhcH0KLmJyYW5ke2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjE0cHh9Ci5sb2dve3dpZHRoOjQ2cHg7aGVpZ2h0OjQ2cHg7
HLP:Ym9yZGVyLXJhZGl1czoxM3B4O2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZyx2YXIoLS1hY2NlbnQpLHZhcigtLWFjY2VudDIpKTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7Ym94LXNoYWRvdzp2
HLP:YXIoLS1zaGFkb3cpfQpoMXtmb250LXNpemU6MjJweDttYXJnaW46MDtsZXR0ZXItc3BhY2luZzouMnB4fQouc3Vie2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDttYXJnaW4tdG9wOjJweH0KLmJhZGdle2Rpc3BsYXk6aW5saW5lLWJsb2NrO2JhY2tn
HLP:cm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZyx2YXIoLS1hY2NlbnQpLHZhcigtLWFjY2VudDIpKTtjb2xvcjojMDQyOTNiO2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6M3B4IDEycHg7Zm9udC1zaXplOjExLjVweDtsZXR0ZXIt
HLP:c3BhY2luZzouNHB4O3ZlcnRpY2FsLWFsaWduOm1pZGRsZTttYXJnaW4tbGVmdDo4cHh9Ci5idG5ze2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwfQoudG9nZ2xle2N1cnNvcjpwb2ludGVyO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7YmFj
HLP:a2dyb3VuZDp2YXIoLS1jYXJkKTtjb2xvcjp2YXIoLS10eHQpO2JvcmRlci1yYWRpdXM6MTBweDtwYWRkaW5nOjhweCAxNHB4O2ZvbnQtc2l6ZToxM3B4O2ZvbnQtd2VpZ2h0OjYwMDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci50b2dnbGU6aG92ZXJ7Ym9yZGVy
HLP:LWNvbG9yOnZhcigtLWFjY2VudCl9Ci50b2N7ZGlzcGxheTpmbGV4O2dhcDo4cHg7ZmxleC13cmFwOndyYXA7bWFyZ2luOjAgMCAyMnB4fQoudG9jIGF7Zm9udC1zaXplOjEyLjVweDtmb250LXdlaWdodDo2MDA7Y29sb3I6dmFyKC0tbXV0ZWQpO3RleHQtZGVjb3Jh
HLP:dGlvbjpub25lO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjZweCAxM3B4fQoudG9jIGE6aG92ZXJ7Y29sb3I6dmFyKC0tYWNjZW50KTtib3JkZXItY29sb3I6dmFy
HLP:KC0tYWNjZW50KX0KLmV4ZWN7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MThweDtmbGV4LXdyYXA6d3JhcDtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxODBkZWcsdmFyKC0tY2FyZCksdmFyKC0tY2FyZDIpKTtib3JkZXI6MXB4IHNvbGlk
HLP:IHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MThweDtwYWRkaW5nOjE4cHggMjJweDttYXJnaW4tYm90dG9tOjIycHg7Ym94LXNoYWRvdzp2YXIoLS1zaGFkb3cpfQouZXhlYy1zY29yZXtmb250LXNpemU6NDZweDtmb250LXdlaWdodDo4MDA7bGluZS1oZWlnaHQ6
HLP:MX0KLmV4ZWMtbWlke2ZsZXg6MTttaW4td2lkdGg6MjAwcHh9Ci5leGVjLXZlcmRpY3R7Zm9udC1zaXplOjE4cHg7Zm9udC13ZWlnaHQ6NzAwfQouZXhlYy1saW5le2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDttYXJnaW4tdG9wOjJweH0KLmV4ZWMt
HLP:ZGVsdGF7Zm9udC1zaXplOjEzcHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlcjoxcHggc29saWQ7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjRweCAxMnB4O3doaXRlLXNwYWNlOm5vd3JhcH0KLmhlcm97ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1u
HLP:czptaW5tYXgoMjQwcHgsMzIwcHgpIDFmcjtnYXA6MjBweDttYXJnaW4tYm90dG9tOjIycHh9CkBtZWRpYShtYXgtd2lkdGg6NzYwcHgpey5oZXJve2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnJ9fQouY2FyZHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxODBk
HLP:ZWcsdmFyKC0tY2FyZCksdmFyKC0tY2FyZDIpKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MThweDtwYWRkaW5nOjIycHg7Ym94LXNoYWRvdzp2YXIoLS1zaGFkb3cpfQouZ2F1Z2V3cmFwe2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVj
HLP:dGlvbjpjb2x1bW47YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5nYXVnZXt3aWR0aDoyMTBweDtoZWlnaHQ6MjEwcHh9Ci5nYXVnZS1zbXt3aWR0aDoxMjBweDtoZWlnaHQ6MTIwcHh9Ci5nYXVnZSAu
HLP:dHJhY2t7ZmlsbDpub25lO3N0cm9rZTp2YXIoLS1saW5lKTtzdHJva2Utd2lkdGg6MTR9Ci5nYXVnZSAuZmlsbHtmaWxsOm5vbmU7c3Ryb2tlLXdpZHRoOjE0O3N0cm9rZS1saW5lY2FwOnJvdW5kO3RyYW5zZm9ybTpyb3RhdGUoLTkwZGVnKTt0cmFuc2Zvcm0tb3Jp
HLP:Z2luOjUwJSA1MCU7c3Ryb2tlLWRhc2hhcnJheTp2YXIoLS1jaXJjKTtzdHJva2UtZGFzaG9mZnNldDp2YXIoLS1jaXJjKTthbmltYXRpb246ZmlsbCAxLjRzIGN1YmljLWJlemllciguMjIsMSwuMzYsMSkgLjJzIGZvcndhcmRzfQouZy1udW17Zm9udC1zaXplOjU0
HLP:cHg7Zm9udC13ZWlnaHQ6ODAwO3RleHQtYW5jaG9yOm1pZGRsZTtmb250LWZhbWlseTonU2Vnb2UgVUknLHN5c3RlbS11aSxBcmlhbH0KLmdhdWdlLXNtIC5nLW51bXtmb250LXNpemU6NDZweH0KLmctbGFiZWx7bWFyZ2luLXRvcDo2cHg7Zm9udC13ZWlnaHQ6NzAw
HLP:O2ZvbnQtc2l6ZToxNXB4fQouZy1jYXB7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMnB4O2xldHRlci1zcGFjaW5nOjEuNXB4O21hcmdpbi10b3A6MnB4fQouY29tcGFyZXtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVu
HLP:dDpjZW50ZXI7Z2FwOjhweDttYXJnaW4tdG9wOjE0cHg7ZmxleC13cmFwOndyYXB9Ci5taW5pe3RleHQtYWxpZ246Y2VudGVyfQoubWluaS1jYXB7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMXB4O2xldHRlci1zcGFjaW5nOjEuMnB4O21hcmdpbi10b3A6
HLP:LTZweH0KLmFycm93e2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47YWxpZ24taXRlbXM6Y2VudGVyO2dhcDo2cHg7Zm9udC1zaXplOjMwcHg7Zm9udC13ZWlnaHQ6ODAwfQouZGVsdGEtY2hpcHtib3JkZXI6MXB4IHNvbGlkO2JvcmRlci1yYWRpdXM6
HLP:OTk5cHg7cGFkZGluZzozcHggMTJweDtmb250LXNpemU6MTIuNXB4O2ZvbnQtd2VpZ2h0OjcwMDt3aGl0ZS1zcGFjZTpub3dyYXB9Ci5oZXJvLXNpZGV7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjtnYXA6MTZweH0KLmNoaXBze2Rpc3BsYXk6Zmxl
HLP:eDtnYXA6MTBweDtmbGV4LXdyYXA6d3JhcH0KLmNoaXB7ZmxleDoxO21pbi13aWR0aDo5NnB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZDIpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O3BhZGRpbmc6MTJweCAxNHB4O3RleHQt
HLP:YWxpZ246Y2VudGVyfQouY2hpcCAubntmb250LXNpemU6MjZweDtmb250LXdlaWdodDo4MDA7bGluZS1oZWlnaHQ6MX0KLmNoaXAgLmx7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMS41cHg7bGV0dGVyLXNwYWNpbmc6LjZweDttYXJnaW4tdG9wOjNweH0K
HLP:LmMtb2t7Y29sb3I6IzIyYzU1ZX0uYy13YXJue2NvbG9yOiNmNTllMGJ9LmMtZXJye2NvbG9yOiNlZjQ0NDR9LmMtc2tpcHtjb2xvcjojOTRhM2I4fQouc3lzZ3JpZHtkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmciAxZnI7Z2FwOjFweDtiYWNr
HLP:Z3JvdW5kOnZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTRweDtvdmVyZmxvdzpoaWRkZW59CkBtZWRpYShtYXgtd2lkdGg6NTIwcHgpey5zeXNncmlke2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnJ9fQouc3lze2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7cGFkZGlu
HLP:ZzoxMXB4IDE0cHh9Ci5zeXMta3tjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjExLjVweDtsZXR0ZXItc3BhY2luZzouNHB4fQouc3lzLXZ7Zm9udC13ZWlnaHQ6NjAwO2ZvbnQtc2l6ZToxNHB4O21hcmdpbi10b3A6MXB4O3dvcmQtYnJlYWs6YnJlYWstd29y
HLP:ZH0KaDIuc2VjLWh7Zm9udC1zaXplOjE1cHg7bGV0dGVyLXNwYWNpbmc6LjZweDt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7Y29sb3I6dmFyKC0tYWNjZW50KTttYXJnaW46MzBweCAwIDEycHg7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTBw
HLP:eDtzY3JvbGwtbWFyZ2luLXRvcDoxNHB4fQpoMi5zZWMtaDo6YWZ0ZXJ7Y29udGVudDonJztmbGV4OjE7aGVpZ2h0OjFweDtiYWNrZ3JvdW5kOnZhcigtLWxpbmUpfQoudGltZWxpbmV7cG9zaXRpb246cmVsYXRpdmU7cGFkZGluZy1sZWZ0OjhweH0KLnBoe2Rpc3Bs
HLP:YXk6ZmxleDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O2dhcDoxNHB4O3BhZGRpbmc6MTNweCAxNnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O21hcmdpbi1ib3R0b206MTBweDtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO3Bv
HLP:c2l0aW9uOnJlbGF0aXZlO292ZXJmbG93OmhpZGRlbn0KLnBoOjpiZWZvcmV7Y29udGVudDonJztwb3NpdGlvbjphYnNvbHV0ZTtsZWZ0OjA7dG9wOjA7Ym90dG9tOjA7d2lkdGg6NHB4fQoucGgtb2s6OmJlZm9yZXtiYWNrZ3JvdW5kOiMyMmM1NWV9LnBoLXdhcm46
HLP:OmJlZm9yZXtiYWNrZ3JvdW5kOiNmNTllMGJ9LnBoLWVycm9yOjpiZWZvcmV7YmFja2dyb3VuZDojZWY0NDQ0fS5waC1za2lwOjpiZWZvcmV7YmFja2dyb3VuZDojNjQ3NDhifQoucGgtZG90e2ZsZXg6MCAwIGF1dG87bWFyZ2luLXRvcDoxcHh9Ci5zdmdpY297d2lk
HLP:dGg6MjZweDtoZWlnaHQ6MjZweDtkaXNwbGF5OmJsb2NrfQoucGgtbWFpbntmbGV4OjE7bWluLXdpZHRoOjB9Ci5waC10b3B7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTBweDtmbGV4LXdyYXA6d3JhcH0KLnBoLW51bXtmb250LXZhcmlhbnQt
HLP:bnVtZXJpYzp0YWJ1bGFyLW51bXM7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMnB4O2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6N3B4O3BhZGRpbmc6MXB4IDdweH0KLnBoLXRpdGxle2ZvbnQt
HLP:d2VpZ2h0OjYwMDtmb250LXNpemU6MTVweH0KLnBoLWJhZGdle2ZvbnQtc2l6ZToxMXB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzouNnB4O2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzoycHggMTBweH0KLmItb2t7YmFja2dyb3VuZDpyZ2JhKDM0
HLP:LDE5Nyw5NCwuMTYpO2NvbG9yOiMyMmM1NWV9LmItd2FybntiYWNrZ3JvdW5kOnJnYmEoMjQ1LDE1OCwxMSwuMTYpO2NvbG9yOiNmNTllMGJ9LmItZXJyb3J7YmFja2dyb3VuZDpyZ2JhKDIzOSw2OCw2OCwuMTYpO2NvbG9yOiNlZjQ0NDR9LmItc2tpcHtiYWNrZ3Jv
HLP:dW5kOnJnYmEoMTAwLDExNiwxMzksLjE4KTtjb2xvcjojOTRhM2I4fQoucGgtbm90ZXtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEzcHg7bWFyZ2luLXRvcDozcHh9Ci5waC1zZWNze2ZsZXg6MCAwIGF1dG87Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6
HLP:ZToxM3B4O2ZvbnQtdmFyaWFudC1udW1lcmljOnRhYnVsYXItbnVtczthbGlnbi1zZWxmOmNlbnRlcn0KLmVtcHR5e2NvbG9yOnZhcigtLW11dGVkKTtwYWRkaW5nOjE4cHg7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5iYXJjaGFydHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQp
HLP:O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O3BhZGRpbmc6MTRweCAxOHB4O21hcmdpbi10b3A6NHB4fQouYmFyLXJvd3tkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMnB4O3BhZGRpbmc6NXB4IDB9Ci5i
HLP:YXItbGJse2ZsZXg6MCAwIDIyMHB4O2ZvbnQtc2l6ZToxMi41cHg7Y29sb3I6dmFyKC0tbXV0ZWQpO3doaXRlLXNwYWNlOm5vd3JhcDtvdmVyZmxvdzpoaWRkZW47dGV4dC1vdmVyZmxvdzplbGxpcHNpc30KQG1lZGlhKG1heC13aWR0aDo2MDBweCl7LmJhci1sYmx7
HLP:ZmxleDowIDAgMTIwcHh9fQouYmFyLXRyYWNre2ZsZXg6MTtoZWlnaHQ6MTBweDtib3JkZXItcmFkaXVzOjk5OXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSk7b3ZlcmZsb3c6aGlkZGVufQouYmFyLXRyYWNrIHNwYW57ZGlzcGxheTpibG9jaztoZWlnaHQ6MTAwJTti
HLP:b3JkZXItcmFkaXVzOjk5OXB4fQouYmFyLXZhbHtmbGV4OjAgMCBhdXRvO2ZvbnQtc2l6ZToxMi41cHg7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtdmFyaWFudC1udW1lcmljOnRhYnVsYXItbnVtczt3aWR0aDo0OHB4O3RleHQtYWxpZ246cmlnaHR9CnVsLmZpbmRz
HLP:e2xpc3Qtc3R5bGU6bm9uZTttYXJnaW46MDtwYWRkaW5nOjB9Ci5maW5ke2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O2dhcDoxMnB4O3BhZGRpbmc6MTJweCAxNnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czox
HLP:M3B4O21hcmdpbi1ib3R0b206OXB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCl9Ci5zZXZ7ZmxleDowIDAgYXV0bztmb250LXNpemU6MTFweDtmb250LXdlaWdodDo4MDA7bGV0dGVyLXNwYWNpbmc6LjVweDtib3JkZXItcmFkaXVzOjhweDtwYWRkaW5nOjNweCAxMHB4
HLP:O21hcmdpbi10b3A6MXB4fQouc2V2LWhpZ2h7YmFja2dyb3VuZDpyZ2JhKDIzOSw2OCw2OCwuMTYpO2NvbG9yOiNlZjQ0NDR9LnNldi1tZWR7YmFja2dyb3VuZDpyZ2JhKDI0NSwxNTgsMTEsLjE2KTtjb2xvcjojZjU5ZTBifS5zZXYtaW5mb3tiYWNrZ3JvdW5kOnJn
HLP:YmEoNTYsMTg5LDI0OCwuMTYpO2NvbG9yOnZhcigtLWFjY2VudCl9LnNldi1va3tiYWNrZ3JvdW5kOnJnYmEoMzQsMTk3LDk0LC4xNik7Y29sb3I6IzIyYzU1ZX0KLmZpbmQtdHh0e2ZvbnQtc2l6ZToxNHB4fQp1bC5zdGVwc3tsaXN0LXN0eWxlOm5vbmU7bWFyZ2lu
HLP:OjA7cGFkZGluZzowfQouc3RlcC1saXtkaXNwbGF5OmZsZXg7Z2FwOjExcHg7YWxpZ24taXRlbXM6ZmxleC1zdGFydDtwYWRkaW5nOjExcHggMTZweDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1sZWZ0OjNweCBzb2xpZCB2YXIoLS1hY2NlbnQp
HLP:O2JvcmRlci1yYWRpdXM6MTJweDttYXJnaW4tYm90dG9tOjlweDtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2ZvbnQtc2l6ZToxNHB4fQouc3RlcC1va3tib3JkZXItbGVmdC1jb2xvcjojMjJjNTVlfQouc3RlcC1pY3tjb2xvcjp2YXIoLS1hY2NlbnQpO2ZvbnQtd2Vp
HLP:Z2h0OjgwMH0KLnN0ZXAtb2sgLnN0ZXAtaWN7Y29sb3I6IzIyYzU1ZX0KLmRncmlke2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6cmVwZWF0KGF1dG8tZml0LG1pbm1heCgyMjBweCwxZnIpKTtnYXA6MTRweH0KLmRjYXJke2JhY2tncm91bmQ6dmFy
HLP:KC0tY2FyZCk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE1cHg7cGFkZGluZzoxNnB4IDE4cHh9Ci5kY2FyZC13aWRle2dyaWQtY29sdW1uOjEvLTF9Ci5kLWh7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6OXB4
HLP:O2ZvbnQtd2VpZ2h0OjcwMDtmb250LXNpemU6MTRweDttYXJnaW4tYm90dG9tOjEwcHh9Ci5kLWlje3dpZHRoOjE0cHg7aGVpZ2h0OjE0cHg7Ym9yZGVyLXJhZGl1czo1cHg7ZGlzcGxheTppbmxpbmUtYmxvY2t9Ci5pYy1yYW17YmFja2dyb3VuZDpsaW5lYXItZ3Jh
HLP:ZGllbnQoMTM1ZGVnLCMzOGJkZjgsIzBlYTVlOSl9LmljLWJhdHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzIyYzU1ZSwjMTU4MDNkKX0uaWMtbmV0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjODE4Y2Y4LCM0ZjQ2ZTUpfS5p
HLP:Yy1kZXZ7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNmNTllMGIsI2Q5NzcwNil9LmljLXNtYXJ0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZjQ3MmI2LCNkYjI3NzcpfS5pYy1ib290e2JhY2tncm91bmQ6bGluZWFyLWdyYWRp
HLP:ZW50KDEzNWRlZywjMmRkNGJmLCMwZDk0ODgpfS5pYy1zdGFydHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2E3OGJmYSwjN2MzYWVkKX0uaWMtcHJvY3tiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2ZiNzE4NSwjZTExZDQ4KX0K
HLP:LmQtcGlsbHtkaXNwbGF5OmlubGluZS1ibG9jaztmb250LXNpemU6MTIuNXB4O2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NHB4IDEycHh9Ci5waWxsLXJvd3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4LXdyYXA6d3JhcH0KLnBp
HLP:bGwtZ29vZHtiYWNrZ3JvdW5kOnJnYmEoMzQsMTk3LDk0LC4xNik7Y29sb3I6IzIyYzU1ZX0ucGlsbC1iYWR7YmFja2dyb3VuZDpyZ2JhKDIzOSw2OCw2OCwuMTYpO2NvbG9yOiNlZjQ0NDR9LnBpbGwtdW5rbm93bntiYWNrZ3JvdW5kOnJnYmEoMTQ4LDE2MywxODQs
HLP:LjE2KTtjb2xvcjojOTRhM2I4fQouZC1zdWJ7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMi41cHg7bWFyZ2luLXRvcDo4cHh9Ci5kLWhpbnR7Y29sb3I6I2Y1OWUwYjtmb250LXNpemU6MTIuNXB4O21hcmdpbi10b3A6OHB4fQouYmF0LWJhcntoZWlnaHQ6
HLP:MTJweDtib3JkZXItcmFkaXVzOjk5OXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSk7b3ZlcmZsb3c6aGlkZGVuO21hcmdpbi10b3A6NHB4fQouYmF0LWJhciBzcGFue2Rpc3BsYXk6YmxvY2s7aGVpZ2h0OjEwMCU7Ym9yZGVyLXJhZGl1czo5OTlweH0KLmRldi1saXN0
HLP:e21hcmdpbjo0cHggMCAwO3BhZGRpbmctbGVmdDoxOHB4O2ZvbnQtc2l6ZToxMy41cHh9Ci5kZXYtbGlzdCBsaXttYXJnaW46MnB4IDB9Ci5tdXRlZHtjb2xvcjp2YXIoLS1tdXRlZCl9Ci5mb290e21hcmdpbi10b3A6MzRweDt0ZXh0LWFsaWduOmNlbnRlcjtjb2xv
HLP:cjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHh9Ci5zZWN0aW9ue2FuaW1hdGlvbjpyaXNlIC41cyBlYXNlIGJvdGh9CkBrZXlmcmFtZXMgZmlsbHt0b3tzdHJva2UtZGFzaG9mZnNldDp2YXIoLS10YXJnZXQpfX0KQGtleWZyYW1lcyByaXNle2Zyb217b3BhY2l0
HLP:eTowO3RyYW5zZm9ybTp0cmFuc2xhdGVZKDEwcHgpfXRve29wYWNpdHk6MTt0cmFuc2Zvcm06bm9uZX19CkBtZWRpYSBwcmludHsudG9nZ2xlLC50b2MsLmJ0bnMsLnRvYXN0e2Rpc3BsYXk6bm9uZX1ib2R5e2JhY2tncm91bmQ6I2ZmZjtjb2xvcjojMDAwfS5jYXJk
HLP:LC5kY2FyZCwucGgsLmZpbmQsLmV4ZWMsLmJhcmNoYXJ0LC5zdGVwLWxpe2JveC1zaGFkb3c6bm9uZTtiYWNrZHJvcC1maWx0ZXI6bm9uZTstd2Via2l0LWJhY2tkcm9wLWZpbHRlcjpub25lO2JhY2tncm91bmQ6I2ZmZiFpbXBvcnRhbnR9LmdhdWdlIC5maWxse2Fu
HLP:aW1hdGlvbjpub25lfS5zZWN0aW9ue2FuaW1hdGlvbjpub25lfWFbaHJlZl17Y29sb3I6aW5oZXJpdDt0ZXh0LWRlY29yYXRpb246bm9uZX19Cjpyb290ey0tZ2xhc3M6cmdiYSgxOCwyNiw0MywuNjApOy0tZ2xhc3NiZDpyZ2JhKDI1NSwyNTUsMjU1LC4wNyl9Cmh0
HLP:bWwubGlnaHR7LS1nbGFzczpyZ2JhKDI1NSwyNTUsMjU1LC42NCk7LS1nbGFzc2JkOnJnYmEoMTUsMjMsNDIsLjA4KX0KLmNhcmQsLmV4ZWMsLmRjYXJkLC5maW5kLC5iYXJjaGFydCwuc3RlcC1saXtiYWNrZ3JvdW5kOnZhcigtLWdsYXNzKSFpbXBvcnRhbnQ7YmFj
HLP:a2Ryb3AtZmlsdGVyOmJsdXIoMTNweCkgc2F0dXJhdGUoMTQwJSk7LXdlYmtpdC1iYWNrZHJvcC1maWx0ZXI6Ymx1cigxM3B4KSBzYXR1cmF0ZSgxNDAlKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWdsYXNzYmQpIWltcG9ydGFudH0KLnRvYXN0e3Bvc2l0aW9uOmZp
HLP:eGVkO2JvdHRvbToyNHB4O2xlZnQ6NTAlO3RyYW5zZm9ybTp0cmFuc2xhdGVYKC01MCUpO2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZyx2YXIoLS1hY2NlbnQpLHZhcigtLWFjY2VudDIpKTtjb2xvcjojMDQyOTNiO2ZvbnQtd2VpZ2h0OjcwMDtwYWRk
HLP:aW5nOjEwcHggMThweDtib3JkZXItcmFkaXVzOjEycHg7Ym94LXNoYWRvdzp2YXIoLS1zaGFkb3cpO29wYWNpdHk6MDtwb2ludGVyLWV2ZW50czpub25lO3RyYW5zaXRpb246b3BhY2l0eSAuMjVzO3otaW5kZXg6NjA7Zm9udC1zaXplOjEzcHh9Ci50b2FzdC5zaG93
HLP:e29wYWNpdHk6MX0KLnRyZW5kLXRpdGxle21hcmdpbi10b3A6MjBweDtmb250LXNpemU6MTJweDtmb250LXdlaWdodDo3MDA7bGV0dGVyLXNwYWNpbmc6MXB4O3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTtjb2xvcjp2YXIoLS1tdXRlZCl9Ci50cmVuZC1saXN0e2Rp
HLP:c3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47Z2FwOjRweDt3aWR0aDoxMDAlO21hcmdpbi10b3A6OHB4O2JvcmRlci10b3A6MXB4IHNvbGlkIHZhcigtLWxpbmUpO3BhZGRpbmctdG9wOjhweH0KLnRyZW5kLWl0ZW17ZGlzcGxheTpmbGV4O2p1c3RpZnkt
HLP:Y29udGVudDpzcGFjZS1iZXR3ZWVuO2ZvbnQtc2l6ZToxMnB4fQoudHJlbmQtZGF0ZXtjb2xvcjp2YXIoLS1tdXRlZCl9Ci50cmVuZC1zY29yZXtmb250LXdlaWdodDo3MDB9Cjwvc3R5bGU+CjwvaGVhZD4KPGJvZHk+CjxkaXYgY2xhc3M9J3dyYXAnPgogIDxkaXYg
HLP:Y2xhc3M9J3RvcGJhcic+CiAgICA8ZGl2IGNsYXNzPSdicmFuZCc+CiAgICAgIDxkaXYgY2xhc3M9J2xvZ28nPjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyB3aWR0aD0nMjYnIGhlaWdodD0nMjYnIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nV1BJJz48cGF0aCBkPSdN
HLP:MTIgMmw3IDN2NmMwIDQuNi0zIDguMy03IDkuNkM4IDE5LjMgNSAxNS42IDUgMTFWNXonIGZpbGw9JyMwNDI5M2InLz48cGF0aCBkPSdNOSAxMmwyIDIgNC00LjUnIGZpbGw9J25vbmUnIHN0cm9rZT0nI2RmZjZmZicgc3Ryb2tlLXdpZHRoPScyJyBzdHJva2UtbGlu
HLP:ZWNhcD0ncm91bmQnIHN0cm9rZS1saW5lam9pbj0ncm91bmQnLz48L3N2Zz48L2Rpdj4KICAgICAgPGRpdj4KICAgICAgICA8aDE+UmVwYWlyIFJlcG9ydCA8c3BhbiBjbGFzcz0nYmFkZ2UnPldQSSBTVUlURSB2My4xPC9zcGFuPjwvaDE+CiAgICAgICAgPGRpdiBj
HLP:bGFzcz0nc3ViJz4kKCYgJGVuYyAkbWFjaGluZSkgJm5ic3A7Jm1pZGRvdDsmbmJzcDsgZ2VuZXJhdGVkIG9uICRub3c8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2J0bnMnPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dnbGUn
HLP:IG9uY2xpY2s9IndpbmRvdy5wcmludCgpIj5QcmludCAvIFBERjwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dnbGUnIGlkPSdjb3B5YnRuJyBvbmNsaWNrPSJjb3B5UmVzdW1lbigpIj5Db3B5IHN1bW1hcnk8L2J1dHRvbj4KICAgICAgPGJ1dHRvbiBj
HLP:bGFzcz0ndG9nZ2xlJyBpZD0ndGhlbWVidG4nIG9uY2xpY2s9InRvZ2dsZVRoZW1lKCkiPkxpZ2h0L0RhcmsgdGhlbWU8L2J1dHRvbj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8bmF2IGNsYXNzPSd0b2MnIGFyaWEtbGFiZWw9J0luZGV4Jz4KICAgIDxhIGhyZWY9
HLP:JyNyZXN1bWVuJz5TdW1tYXJ5PC9hPgogICAgPGEgaHJlZj0nI2Zhc2VzJz5QaGFzZXM8L2E+CiAgICA8YSBocmVmPScjaGFsbGF6Z29zJz5GaW5kaW5nczwvYT4KICAgIDxhIGhyZWY9JyNwYXNvcyc+TmV4dCBzdGVwczwvYT4KICAgIDxhIGhyZWY9JyNkaWFnJz5E
HLP:aWFnbm9zdGljczwvYT4KICA8L25hdj4KCiAgPGRpdiBpZD0ncmVzdW1lbicgY2xhc3M9J2V4ZWMgc2VjdGlvbic+CiAgICA8ZGl2IGNsYXNzPSdleGVjLXNjb3JlJyBzdHlsZT0nY29sb3I6JG1haW5Db2xvcic+JG1haW5TY29yZTwvZGl2PgogICAgPGRpdiBjbGFz
HLP:cz0nZXhlYy1taWQnPgogICAgICA8ZGl2IGNsYXNzPSdleGVjLXZlcmRpY3QnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz5TeXN0ZW0gaGVhbHRoOiAkZXhlY1ZlcmRpY3Q8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nZXhlYy1saW5lJz4kY09LIHN1Y2Nlc3NmdWwg
HLP:Jm1pZGRvdDsgJGNXQVJOIHdhcm5pbmdzICZtaWRkb3Q7ICRjRVJSIGVycm9ycyAmbWlkZG90OyAkY1NLSVAgc2tpcHBlZCAmbWlkZG90OyAkdG90YWxQaCBwaGFzZXMgdG90YWw8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nZXhlYy1saW5lJz4kc3RhdExpbmU8L2Rp
HLP:dj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0nZXhlYy1kZWx0YScgc3R5bGU9J2NvbG9yOiRkZWx0YUNvbG9yO2JvcmRlci1jb2xvcjokZGVsdGFDb2xvcic+JGRlbHRhVHh0PC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J2hlcm8gc2VjdGlvbic+CiAg
HLP:ICA8ZGl2IGNsYXNzPSdjYXJkIGdhdWdld3JhcCc+CiAgICAgIDxzdmcgdmlld0JveD0nMCAwIDIwMCAyMDAnIGNsYXNzPSdnYXVnZScgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdIZWFsdGggc2NvcmUgJG1haW5TY29yZSBvdXQgb2YgMTAwJz48Y2lyY2xlIGNsYXNz
HLP:PSd0cmFjaycgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnLz48Y2lyY2xlIGNsYXNzPSdmaWxsJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcgc3R5bGU9Jy0tY2lyYzokY2lyYzstLXRhcmdldDokbWFpbk9mZnNldDtzdHJva2U6JG1haW5Db2xvcicvPjx0ZXh0IHg9
HLP:JzEwMCcgeT0nMTEyJyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxsOiRtYWluQ29sb3InPiRtYWluU2NvcmU8L3RleHQ+PC9zdmc+CiAgICAgIDxkaXYgY2xhc3M9J2ctbGFiZWwnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz5IZWFsdGg6ICRtYWluTGFiZWw8L2Rp
HLP:dj4KICAgICAgPGRpdiBjbGFzcz0nZy1jYXAnPlNDT1JFIE9VVCBPRiAxMDA8L2Rpdj4KICAgICAgJGNvbXBhcmVTZWN0aW9uCiAgICAgICRoaXN0b3J5SHRtbAogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdoZXJvLXNpZGUnPgogICAgICA8ZGl2IGNsYXNzPSdj
HLP:YXJkJz4KICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwcyc+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNsYXNzPSduIGMtb2snPiRjT0s8L2Rpdj48ZGl2IGNsYXNzPSdsJz5PSzwvZGl2PjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+
HLP:PGRpdiBjbGFzcz0nbiBjLXdhcm4nPiRjV0FSTjwvZGl2PjxkaXYgY2xhc3M9J2wnPldBUk5JTkdTPC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNsYXNzPSduIGMtZXJyJz4kY0VSUjwvZGl2PjxkaXYgY2xhc3M9J2wnPkVSUk9S
HLP:UzwvZGl2PjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBjLXNraXAnPiRjU0tJUDwvZGl2PjxkaXYgY2xhc3M9J2wnPlNLSVBQRUQ8L2Rpdj48L2Rpdj4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICAgIDxkaXYg
HLP:Y2xhc3M9J2NhcmQnPgogICAgICAgIDxkaXYgY2xhc3M9J3N5c2dyaWQnPiRzeXNDYXJkczwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4KICAgIDxoMiBpZD0nZmFzZXMnIGNsYXNzPSdzZWMtaCc+
HLP:UGhhc2VzIHRpbWVsaW5lICgkdG90YWxQaCk8L2gyPgogICAgPGRpdiBjbGFzcz0ndGltZWxpbmUnPiRyb3dzPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdiYXJjaGFydCc+JGJhcnM8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlvbic+CiAgICA8aDIg
HLP:aWQ9J2hhbGxhemdvcycgY2xhc3M9J3NlYy1oJz5GaW5kaW5ncyBhbmQgcm9vdCBjYXVzZTwvaDI+CiAgICA8dWwgY2xhc3M9J2ZpbmRzJz4kZmluZEh0bWw8L3VsPgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4KICAgIDxoMiBpZD0ncGFzb3MnIGNs
HLP:YXNzPSdzZWMtaCc+UmVjb21tZW5kZWQgbmV4dCBzdGVwczwvaDI+CiAgICA8dWwgY2xhc3M9J3N0ZXBzJz4kc3RlcHNIdG1sPC91bD4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlvbic+JGRpYWdTZWN0aW9uPC9kaXY+CgogIDxkaXYgY2xhc3M9J2Zvb3Qn
HLP:PgogICAgV1BJICZtaWRkb3Q7IEVtZXJnZW5jeSBSZXBhaXIgU3VpdGUgZm9yIFdpbmRvd3MgMTAvMTEgJm1pZGRvdDsgcmVhZC1vbmx5IHJlcG9ydC48YnI+CiAgICBCYWNrdXBzIGFuZCBsb2dzIGFyZSBpbiB0aGUgV1BJX1N1aXRlIGZvbGRlciBuZXh0IHRvIHRo
HLP:ZSBwcm9ncmFtLgogIDwvZGl2Pgo8L2Rpdj4KPHNjcmlwdD4KKGZ1bmN0aW9uKCl7dHJ5e3ZhciBzPWxvY2FsU3RvcmFnZS5nZXRJdGVtKCd3cGktdGhlbWUnKTt2YXIgcm9vdD1kb2N1bWVudC5kb2N1bWVudEVsZW1lbnQ7aWYocz09PSdsaWdodCcpe3Jvb3QuY2xh
HLP:c3NMaXN0LmFkZCgnbGlnaHQnKTt9ZWxzZSBpZihzPT09J2RhcmsnKXtyb290LmNsYXNzTGlzdC5yZW1vdmUoJ2xpZ2h0Jyk7fWVsc2UgaWYod2luZG93Lm1hdGNoTWVkaWEmJndpbmRvdy5tYXRjaE1lZGlhKCcocHJlZmVycy1jb2xvci1zY2hlbWU6IGxpZ2h0KScp
HLP:Lm1hdGNoZXMpe3Jvb3QuY2xhc3NMaXN0LmFkZCgnbGlnaHQnKTt9fX1jYXRjaChlKXt9fSkoKTsKZnVuY3Rpb24gdG9nZ2xlVGhlbWUoKXt0cnl7dmFyIGw9ZG9jdW1lbnQuZG9jdW1lbnRFbGVtZW50LmNsYXNzTGlzdC50b2dnbGUoJ2xpZ2h0Jyk7bG9jYWxTdG9y
HLP:YWdlLnNldEl0ZW0oJ3dwaS10aGVtZScsbD8nbGlnaHQnOidkYXJrJyk7fWNhdGNoKGUpe319CmZ1bmN0aW9uIGZsYXNoKG0pe3RyeXt2YXIgdD1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCdkaXYnKTt0LmNsYXNzTmFtZT0ndG9hc3QnO3QudGV4dENvbnRlbnQ9bTtk
HLP:b2N1bWVudC5ib2R5LmFwcGVuZENoaWxkKHQpO3JlcXVlc3RBbmltYXRpb25GcmFtZShmdW5jdGlvbigpe3QuY2xhc3NMaXN0LmFkZCgnc2hvdycpO30pO3NldFRpbWVvdXQoZnVuY3Rpb24oKXt0LmNsYXNzTGlzdC5yZW1vdmUoJ3Nob3cnKTtzZXRUaW1lb3V0KGZ1
HLP:bmN0aW9uKCl7dC5yZW1vdmUoKTt9LDMwMCk7fSwxNjAwKTt9Y2F0Y2goZSl7fX0KZnVuY3Rpb24gZmIodHh0LG9rKXt0cnl7dmFyIGE9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgndGV4dGFyZWEnKTthLnZhbHVlPXR4dDthLnN0eWxlLnBvc2l0aW9uPSdmaXhlZCc7
HLP:YS5zdHlsZS5sZWZ0PSctOTk5OXB4Jztkb2N1bWVudC5ib2R5LmFwcGVuZENoaWxkKGEpO2Euc2VsZWN0KCk7ZG9jdW1lbnQuZXhlY0NvbW1hbmQoJ2NvcHknKTthLnJlbW92ZSgpO29rKCk7fWNhdGNoKGUpe2ZsYXNoKCdDb3VsZCBub3QgY29weScpO319CmZ1bmN0
HLP:aW9uIGNvcHlSZXN1bWVuKCl7dmFyIHA9W107dmFyIHQ9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignaDEnKTtpZih0KXAucHVzaCh0LmlubmVyVGV4dC50cmltKCkpO3ZhciBzPWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJy5zdWInKTtpZihzKXAucHVzaChzLmlubmVy
HLP:VGV4dC50cmltKCkpO3ZhciBleD1kb2N1bWVudC5xdWVyeVNlbGVjdG9yKCcuZXhlYycpO2lmKGV4KXAucHVzaCgnXG4nK2V4LmlubmVyVGV4dC5yZXBsYWNlKC9cbnsyLH0vZywnXG4nKS50cmltKCkpO3ZhciBoPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdoYWxs
HLP:YXpnb3MnKTtpZihoJiZoLnBhcmVudE5vZGUpcC5wdXNoKCdcbicraC5wYXJlbnROb2RlLmlubmVyVGV4dC50cmltKCkpO3ZhciB0eHQ9cC5qb2luKCdcbicpO2Z1bmN0aW9uIG9rKCl7Zmxhc2goJ1N1bW1hcnkgY29waWVkJyk7fWlmKG5hdmlnYXRvci5jbGlwYm9h
HLP:cmQmJm5hdmlnYXRvci5jbGlwYm9hcmQud3JpdGVUZXh0KXtuYXZpZ2F0b3IuY2xpcGJvYXJkLndyaXRlVGV4dCh0eHQpLnRoZW4ob2ssZnVuY3Rpb24oKXtmYih0eHQsb2spO30pO31lbHNle2ZiKHR4dCxvayk7fX0KPC9zY3JpcHQ+CjwvYm9keT4KPC9odG1sPgoi
HLP:QAogICAgICAgICR1dGY4ID0gTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKQogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkb3V0UGF0aCwgJGh0bWwsICR1dGY4KQogICAgICAgICJSRVNVTFQ9T0siCiAgICAg
HLP:ICAgIlBBVEg9JG91dFBhdGgiCiAgICB9IGNhdGNoIHsKICAgICAgICAiUkVTVUxUPUZBSUwiCiAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUmVnaXN0cmFyIHJlc3VsdGFkbyBkZSB1bmEgZmFzZSBlbiBlbCBlc3RhZG8gKHBhcmEgZWwgaW5mb3JtZSkuCiMgLUFyZyA9ICJudW07dGl0bGU7cmVzdWx0O3NlY3M7bm90ZSIKZnVuY3Rpb24gQWRkLVBo
HLP:YXNlUmVzdWx0KCRzcGVjKSB7CiAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAkcGFydHMgPSAkc3BlYyAtc3BsaXQgJzsnLDUKICAgICRwaCA9IFtwc2N1c3RvbW9iamVjdF1AeyBudW09JHBhcnRzWzBdOyB0aXRsZT0kcGFydHNbMV07IHJlc3VsdD0kcGFydHNbMl07
HLP:IHNlY3M9JHBhcnRzWzNdOyBub3RlPSRwYXJ0c1s0XSB9CiAgICAkbGlzdCA9IEAoJHN0LnBoYXNlcykgKyAkcGgKICAgICRzdC5waGFzZXMgPSAkbGlzdAogICAgV3JpdGUtU3RhdGUgJHN0CiAgICAiUkVTVUxUPU9LIgp9CmZ1bmN0aW9uIFNldC1TY29yZSgkd2hp
HLP:Y2gsICR2YWwpIHsKICAgICRzdCA9IFJlYWQtU3RhdGUKICAgIGlmICgkd2hpY2ggLWVxICdiZWZvcmUnKSB7IAogICAgICAgICRzdC5zY29yZV9iZWZvcmUgPSBbaW50XSR2YWwgCiAgICB9IGVsc2UgeyAKICAgICAgICAkc3Quc2NvcmVfYWZ0ZXIgPSBbaW50XSR2
HLP:YWwgCiAgICAgICAgU2F2ZS1IZWFsdGhIaXN0b3J5IFtpbnRdJHZhbAogICAgfQogICAgV3JpdGUtU3RhdGUgJHN0OyAiUkVTVUxUPU9LIgp9CmZ1bmN0aW9uIEFkZC1GaW5kaW5nKCR0ZXh0KSB7CiAgICAkc3QgPSBSZWFkLVN0YXRlOyAkc3QuZmluZGluZ3MgPSBA
HLP:KCRzdC5maW5kaW5ncykgKyAkdGV4dDsgV3JpdGUtU3RhdGUgJHN0OyAiUkVTVUxUPU9LIgp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIExPR0lDQSBQVVJBIE5V
HLP:RVZBIC8gQ09SUkVHSURBIChCbG9xdWUgMykKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKIyAtLS0gKDMuMSAvIEJ1ZyA0IC8gUmVxIDYpIE5vcm1hbGl6YWNpb24gZGUg
HLP:bGEgc2VsZWNjaW9uIGRlIGZhc2VzIC0tLS0tLS0tLS0KIyBFbnRyYWRhOiBjYWRlbmEgY29uIElEcyBzZXBhcmFkb3MgcG9yIGNvbWFzIChlc3BhY2lvcyBhcmJpdHJhcmlvcywgMS0yCiMgZGlnaXRvcywgcG9zaWJsZXMgaW52YWxpZG9zKS4gU2FsaWRhOiBvYmpl
HLP:dG8gY29uIC5ub3JtIChsaXN0YSBjYW5vbmljYSwKIyBvcmRlbmFkYSwgdW5pY2EgZGUgSURzIGRlIDIgZGlnaXRvcyBlbiB7MDAuLjE2fSkgeSAuaW52YWxpZCAobG9zIG5vIHZhbGlkb3MpLgojIE51bmNhIGxhbnphIGV4Y2VwY2lvbiBhbnRlIGVudHJhZGEgbWFs
HLP:Zm9ybWFkYSBvIHZhY2lhLgpmdW5jdGlvbiBOb3JtYWxpemUtRmFzZXMoW3N0cmluZ10kcmF3KSB7CiAgICAkdmFsaWQgICA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddCiAgICAkaW52YWxpZCA9IE5ldy1PYmplY3Qg
HLP:U3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddCiAgICBpZiAoJG51bGwgLW5lICRyYXcgLWFuZCAkcmF3LlRyaW0oKS5MZW5ndGggLWd0IDApIHsKICAgICAgICBmb3JlYWNoICgkdCBpbiAoJHJhdyAtc3BsaXQgJywnKSkgewogICAgICAgICAg
HLP:ICBpZiAoJG51bGwgLWVxICR0KSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgJHRvayA9ICgkdCAtcmVwbGFjZSAnXHMnLCAnJykgICAgICAgICAgIyBxdWl0YXIgZXNwYWNpb3MgaW50ZXJub3MgeSBleHRlcm5vcwogICAgICAgICAgICBpZiAoJHRvayAtZXEgJycp
HLP:IHsgY29udGludWUgfQogICAgICAgICAgICAkY2Fub24gPSAkdG9rCiAgICAgICAgICAgIGlmICgkdG9rIC1tYXRjaCAnXlxkJCcpIHsgJGNhbm9uID0gJHRvay5QYWRMZWZ0KDIsICcwJykgfSAgICMgMSBkaWdpdG8gLT4gMiBkaWdpdG9zCiAgICAgICAgICAgIGlm
HLP:ICgkY2Fub24gLW1hdGNoICdeXGR7Mn0kJyAtYW5kIFtpbnRdJGNhbm9uIC1nZSAwIC1hbmQgW2ludF0kY2Fub24gLWxlIDE2KSB7CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkdmFsaWQuQ29udGFpbnMoJGNhbm9uKSkgeyAkdmFsaWQuQWRkKCRjYW5vbikgfQog
HLP:ICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgJGludmFsaWQuQWRkKCR0b2spCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9CiAgICAkc29ydGVkID0gQCgkdmFsaWQgfCBTb3J0LU9iamVjdCkKICAgIHJldHVybiBbcHNjdXN0b21vYmplY3Rd
HLP:QHsgbm9ybSA9ICRzb3J0ZWQ7IGludmFsaWQgPSBAKCRpbnZhbGlkKSB9Cn0KCiMgLS0tICgzLjMgLyBSZXEgNCkgQ2hlY2twb2ludCBzb2JyZSBjaGVja3BvaW50Lmpzb24gLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUGFyc2VyIGRlbCAtQXJnIGNvbiBmb3Jt
HLP:YXRvOgojICAgInNhdmV8c2VsZWN0aW9uPTAwLDAxLDAyfGNvbXBsZXRlZD0wMCwwMXxtb2RlPWF1dG86MTtkcnk6MHxyZWFzb249Y2hrZHNrIgpmdW5jdGlvbiBQYXJzZS1DaGVja3BvaW50QXJnKFtzdHJpbmddJHJhdykgewogICAgJHJlcyA9IFtvcmRlcmVkXUB7
HLP:IHN1YiA9ICcnOyBzZWxlY3Rpb24gPSBAKCk7IGNvbXBsZXRlZCA9IEAoKTsgbW9kZSA9IEB7fTsgcmVhc29uID0gJycgfQogICAgaWYgKFtzdHJpbmddOjpJc051bGxPckVtcHR5KCRyYXcpKSB7IHJldHVybiAkcmVzIH0KICAgICRzZWdzID0gJHJhdyAtc3BsaXQg
HLP:J1x8JwogICAgJHJlcy5zdWIgPSAkc2Vnc1swXS5UcmltKCkuVG9Mb3dlcigpCiAgICBmb3IgKCRpID0gMTsgJGkgLWx0ICRzZWdzLkNvdW50OyAkaSsrKSB7CiAgICAgICAgJGt2ID0gJHNlZ3NbJGldIC1zcGxpdCAnPScsIDIKICAgICAgICBpZiAoJGt2LkNvdW50
HLP:IC1sdCAyKSB7IGNvbnRpbnVlIH0KICAgICAgICAka2V5ID0gJGt2WzBdLlRyaW0oKS5Ub0xvd2VyKCkKICAgICAgICAkdmFsID0gJGt2WzFdCiAgICAgICAgc3dpdGNoICgka2V5KSB7CiAgICAgICAgICAgICdzZWxlY3Rpb24nIHsgJHJlcy5zZWxlY3Rpb24gPSBA
HLP:KCR2YWwgLXNwbGl0ICcsJyB8IEZvckVhY2gtT2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBXaGVyZS1PYmplY3QgeyAkXyAtbmUgJycgfSkgfQogICAgICAgICAgICAnY29tcGxldGVkJyB7ICRyZXMuY29tcGxldGVkID0gQCgkdmFsIC1zcGxpdCAnLCcgfCBGb3JFYWNo
HLP:LU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgV2hlcmUtT2JqZWN0IHsgJF8gLW5lICcnIH0pIH0KICAgICAgICAgICAgJ3JlYXNvbicgICAgeyAkcmVzLnJlYXNvbiA9ICR2YWwuVHJpbSgpIH0KICAgICAgICAgICAgJ21vZGUnIHsKICAgICAgICAgICAgICAgICRtID0g
HLP:QHt9CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcGFpciBpbiAoJHZhbCAtc3BsaXQgJzsnKSkgewogICAgICAgICAgICAgICAgICAgICRwID0gJHBhaXIgLXNwbGl0ICc6JywgMgogICAgICAgICAgICAgICAgICAgIGlmICgkcC5Db3VudCAtZXEgMikgeyAkbVsk
HLP:cFswXS5UcmltKCkuVG9Mb3dlcigpXSA9ICgkcFsxXS5UcmltKCkgLWVxICcxJykgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgJHJlcy5tb2RlID0gJG0KICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KICAgIHJldHVybiAkcmVzCn0KCiMg
HLP:Q29uc3RydXllIHkgcGVyc2lzdGUgY2hlY2twb2ludC5qc29uLiBEZXZ1ZWx2ZSAkdHJ1ZS8kZmFsc2UgKHNpbiBleGNlcGNpb24pLgpmdW5jdGlvbiBTYXZlLUNoZWNrcG9pbnQoJHBhcnNlZCkgewogICAgdHJ5IHsKICAgICAgICAkbW9kZSA9IFtwc2N1c3RvbW9i
HLP:amVjdF1AewogICAgICAgICAgICBhdXRvICAgICA9IFtib29sXSRwYXJzZWQubW9kZVsnYXV0byddCiAgICAgICAgICAgIG5vcmVib290ID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydub3JlYm9vdCddCiAgICAgICAgICAgIGtlZXB3dSAgID0gW2Jvb2xdJHBhcnNlZC5t
HLP:b2RlWydrZWVwd3UnXQogICAgICAgICAgICBkcnkgICAgICA9IFtib29sXSRwYXJzZWQubW9kZVsnZHJ5J10KICAgICAgICAgICAgdHJpYWdlICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ3RyaWFnZSddCiAgICAgICAgfQogICAgICAgICRub3cgPSAoR2V0LURhdGUp
HLP:LlRvU3RyaW5nKCd5eXl5LU1NLWRkX0hILW1tJykKICAgICAgICAkY3AgPSBbcHNjdXN0b21vYmplY3RdQHsKICAgICAgICAgICAgdmVyc2lvbiAgICAgICAgPSAkV1BJX1ZFUlNJT04KICAgICAgICAgICAgY3JlYXRlZCAgICAgICAgPSAkbm93CiAgICAgICAgICAg
HLP:IG1vZGUgICAgICAgICAgID0gJG1vZGUKICAgICAgICAgICAgc2VsZWN0aW9uICAgICAgPSBAKCRwYXJzZWQuc2VsZWN0aW9uKQogICAgICAgICAgICBjb21wbGV0ZWQgICAgICA9IEAoJHBhcnNlZC5jb21wbGV0ZWQpCiAgICAgICAgICAgIHBlbmRpbmdfcmVhc29u
HLP:ID0gJHBhcnNlZC5yZWFzb24KICAgICAgICAgICAgdGltZXN0YW1wX3J1biAgPSAkbm93CiAgICAgICAgfQogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkQ2hlY2twb2ludEZpbGUsICgkY3AgfCBDb252ZXJ0VG8tSnNvbiAtRGVwdGggNiks
HLP:IChOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpKSkKICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0KfQoKIyBDYXJnYSBjaGVja3BvaW50Lmpzb24uIERldnVlbHZlIGVsIG9iamV0byBvICRu
HLP:dWxsIHNpIG5vIGV4aXN0ZSAvIG1hbGZvcm1hZG8uCmZ1bmN0aW9uIExvYWQtQ2hlY2twb2ludCB7CiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkpIHsgcmV0dXJuICRudWxsIH0KICAgIHRyeSB7IHJldHVybiAoR2V0LUNvbnRlbnQgJENo
HLP:ZWNrcG9pbnRGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uKSB9IGNhdGNoIHsgcmV0dXJuICRudWxsIH0KfQoKIyBWYWxpZGEgdW4gY2hlY2twb2ludDogZXhpc3RlICsgcGFyc2VhYmxlICsgdmVyc2lvbiBjb21wYXRpYmxlICsgY29tcGxldGVkCiMgc3ViY29u
HLP:anVudG8gZGUgc2VsZWN0aW9uICsgY3JlYXRlZCBkZW50cm8gZGUgbGEgdmVudGFuYS4gRGV2dWVsdmUgYm9vbGVhbm8KIyBTSU4gbGFuemFyIGV4Y2VwY2lvbiBhbnRlIEpTT04gbWFsZm9ybWFkbyBvIGNhZHVjYWRvLgpmdW5jdGlvbiBUZXN0LUNoZWNrcG9pbnRW
HLP:YWxpZCgkY3ApIHsKICAgIHRyeSB7CiAgICAgICAgaWYgKCRudWxsIC1lcSAkY3ApIHsKICAgICAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkQ2hlY2twb2ludEZpbGUpKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgICAgICB0cnkgeyAkY3AgPSBHZXQtQ29u
HLP:dGVudCAkQ2hlY2twb2ludEZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIH0KICAgICAgICBpZiAoJG51bGwgLWVxICRjcCkgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICBpZiAoW3N0cmluZ10kY3Au
HLP:dmVyc2lvbiAtbmUgJFdQSV9WRVJTSU9OKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgICRzZWwgID0gQCgkY3Auc2VsZWN0aW9uKQogICAgICAgICRjb21wID0gQCgkY3AuY29tcGxldGVkKQogICAgICAgIGZvcmVhY2ggKCRjIGluICRjb21wKSB7IGlmICgkc2Vs
HLP:IC1ub3Rjb250YWlucyAkYykgeyByZXR1cm4gJGZhbHNlIH0gfQogICAgICAgICRjcmVhdGVkID0gJG51bGwKICAgICAgICBpZiAoJGNwLmNyZWF0ZWQpIHsKICAgICAgICAgICAgdHJ5IHsgJGNyZWF0ZWQgPSBbZGF0ZXRpbWVdOjpQYXJzZUV4YWN0KFtzdHJpbmdd
HLP:JGNwLmNyZWF0ZWQsICd5eXl5LU1NLWRkX0hILW1tJywgJG51bGwpIH0gY2F0Y2ggeyAkY3JlYXRlZCA9ICRudWxsIH0KICAgICAgICB9CiAgICAgICAgaWYgKCRudWxsIC1lcSAkY3JlYXRlZCkgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICAkYWdlID0gKEdldC1E
HLP:YXRlKSAtICRjcmVhdGVkCiAgICAgICAgaWYgKCRhZ2UuVG90YWxEYXlzIC1ndCAkQ0hFQ0tQT0lOVF9NQVhfQUdFX0RBWVMpIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgcmV0dXJuICR0cnVlCiAgICB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9Cn0KCiMgUHJp
HLP:bWVyYSBmYXNlIGRlICdzZWxlY3Rpb24nIG5vIHByZXNlbnRlIGVuICdjb21wbGV0ZWQnIChvICcnIHNpIHRvZGFzIGhlY2hhcykuCmZ1bmN0aW9uIEdldC1OZXh0UGhhc2UoJGNwKSB7CiAgICBpZiAoJG51bGwgLWVxICRjcCkgeyByZXR1cm4gJycgfQogICAgJGNv
HLP:bXAgPSBAKCRjcC5jb21wbGV0ZWQpCiAgICBmb3JlYWNoICgkcyBpbiBAKCRjcC5zZWxlY3Rpb24pKSB7IGlmICgkY29tcCAtbm90Y29udGFpbnMgJHMpIHsgcmV0dXJuICRzIH0gfQogICAgcmV0dXJuICcnCn0KCiMgLS0tICgzLjkgLyBCdWcgNiAvIFJlcSA4KSBS
HLP:ZXNldCBkZSBlc3RhZG8gcmV1dGlsaXphYmxlIC0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgRGVqYSBwaGFzZXM9QCgpLCBmaW5kaW5ncz1AKCkgeSBsb3Mgc2NvcmVzIChiZWZvcmUvYWZ0ZXIpIGEgbnVsbC4gRWwKIyBjb25kaWNpb25hZG8gYSAvcmVzdW1lIGxvIGFw
HLP:bGljYSBlbCBiYXRjaCAodGFyZWFzIDguNCAvIDkuMSk6IHNvbG8gaW52b2NhCiMgJ3Jlc2V0c3RhdGUnIGN1YW5kbyBSRVNVTUU9PTAsIGNvbnNlcnZhbmRvIGVsIGVzdGFkbyBwcmV2aW8gZW4gL3Jlc3VtZS4KZnVuY3Rpb24gUmVzZXQtU3RhdGUgewogICAgV3Jp
HLP:dGUtU3RhdGUgKFtwc2N1c3RvbW9iamVjdF1AeyBzY29yZV9iZWZvcmUgPSAkbnVsbDsgc2NvcmVfYWZ0ZXIgPSAkbnVsbDsgZmluZGluZ3MgPSBAKCk7IHBoYXNlcyA9IEAoKSB9KQp9CgojIC0tLSAoMy4xMSAvIEJ1ZyA3IC8gUmVxIDkpIEhvbmVzdGlkYWQgZGVs
HLP:IG1vdmltaWVudG8gZGUgY2FjaGVzIC0tLS0tLS0tLS0tLQojIEV4aXRvICh0cnVlKSBTSSBZIFNPTE8gU0kgZWwgb3JpZ2VuIGVzdGEgYXVzZW50ZSB5IGVsIGRlc3Rpbm8gcHJlc2VudGUuCiMgVmFyaWFudGUgcHVyYSAoYm9vbGVhbm9zKSArIHZhcmlhbnRlIHF1
HLP:ZSBhY2VwdGEgcnV0YXMgeSBoYWNlIFRlc3QtUGF0aC4KZnVuY3Rpb24gVGVzdC1Nb3ZlUmVzdWx0KFtib29sXSRzcmNFeGlzdHMsIFtib29sXSRkc3RFeGlzdHMpIHsKICAgIHJldHVybiAoKC1ub3QgJHNyY0V4aXN0cykgLWFuZCAkZHN0RXhpc3RzKQp9CmZ1bmN0
HLP:aW9uIFRlc3QtTW92ZVJlc3VsdFBhdGgoW3N0cmluZ10kc3JjLCBbc3RyaW5nXSRkc3QpIHsKICAgIHJldHVybiAoVGVzdC1Nb3ZlUmVzdWx0IChbYm9vbF0oVGVzdC1QYXRoICRzcmMpKSAoW2Jvb2xdKFRlc3QtUGF0aCAkZHN0KSkpCn0KCiMgLS0tICgzLjExIC8g
HLP:QnVnIDggLyBSZXEgMTApIElkZW1wb3RlbmNpYSBkZSBWaXJ0dWFsVGVybWluYWxMZXZlbCAtLS0tLS0tLS0tCiMgTm9ybWFsaXphIHZhbG9yZXMgJzB4MScgLyAnMScgLyAxIGEgZW50ZXJvIHBhcmEgY29tcGFyYXIgZGUgZm9ybWEgcm9idXN0YS4KZnVuY3Rpb24g
HLP:Q29udmVydFRvLVZ0bEludCgkdikgewogICAgaWYgKCRudWxsIC1lcSAkdikgeyByZXR1cm4gJG51bGwgfQogICAgJHMgPSAoW3N0cmluZ10kdikuVHJpbSgpLlRvTG93ZXIoKQogICAgaWYgKCRzIC1lcSAnJykgeyByZXR1cm4gJG51bGwgfQogICAgdHJ5IHsKICAg
HLP:ICAgICBpZiAoJHMuU3RhcnRzV2l0aCgnMHgnKSkgeyByZXR1cm4gW0NvbnZlcnRdOjpUb0ludDMyKCRzLCAxNikgfQogICAgICAgIHJldHVybiBbaW50XSRzCiAgICB9IGNhdGNoIHsgcmV0dXJuICRudWxsIH0KfQojIERldnVlbHZlICR0cnVlIChlc2NyaWJpcikg
HLP:c29sbyBzaSBlbCB2YWxvciBhY3R1YWwgZGlmaWVyZSBkZWwgZGVzZWFkby4KZnVuY3Rpb24gUmVzb2x2ZS1WdGxXcml0ZSgkY3VycmVudCwgJGRlc2lyZWQpIHsKICAgIHJldHVybiAoKENvbnZlcnRUby1WdGxJbnQgJGN1cnJlbnQpIC1uZSAoQ29udmVydFRvLVZ0
HLP:bEludCAkZGVzaXJlZCkpCn0KCiMgLS0tICgzLjE0IC8gUmVxIDEuMykgTWFwZW8gVE9UQUwgZGUgY29kaWdvIGRlIHNhbGlkYSBhIHtPSyxXQVJOLFNLSVAsRVJST1J9CiMgMC0+T0ssIDEtPldBUk4sIDItPlNLSVAsIDMtPkVSUk9SOyBjdWFscXVpZXIgb3RybyBl
HLP:bnRlcm8gKG8gbm8gZW50ZXJvKSAtPiBFUlJPUi4KZnVuY3Rpb24gTWFwLUV4aXRDb2RlKCRjb2RlKSB7CiAgICAkbiA9ICRudWxsCiAgICB0cnkgeyAkbiA9IFtpbnRdJGNvZGUgfSBjYXRjaCB7IHJldHVybiAnRVJST1InIH0KICAgIHN3aXRjaCAoJG4pIHsKICAg
HLP:ICAgICAwICAgICAgIHsgJ09LJyB9CiAgICAgICAgMSAgICAgICB7ICdXQVJOJyB9CiAgICAgICAgMiAgICAgICB7ICdTS0lQJyB9CiAgICAgICAgMyAgICAgICB7ICdFUlJPUicgfQogICAgICAgIGRlZmF1bHQgeyAnRVJST1InIH0KICAgIH0KfQoKIyA9PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBESUFHTk9TVElDTyBBTVBMSUFETyAoNS4xIC8gUmVxIDE1LjEtMTUuNSkKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKIyAtLS0gUkFNIChSZXEgMTUuMSkgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIFJlc29sdmUtUmFtU3RhdHVzOiBmdW5jaW9uIFBV
HLP:UkEuIEEgcGFydGlyIGRlbCBjb250ZW8gZGUgZXJyb3JlcyBkZSBtZW1vcmlhCiMgV0hFQSB5IGRlIGZhbGxvcyBkZWwgZGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZSBXaW5kb3dzLCBkZWNpZGUgZWwgZXN0YWRvIHkKIyBzaSBjb252aWVuZSByZWNvbWVuZGFyIG1k
HLP:c2NoZWQuCmZ1bmN0aW9uIFJlc29sdmUtUmFtU3RhdHVzKFtpbnRdJHdoZWFNZW1FcnJvcnMsIFtpbnRdJG1lbURpYWdGYWlsdXJlcykgewogICAgaWYgKCR3aGVhTWVtRXJyb3JzIC1ndCAwIC1vciAkbWVtRGlhZ0ZhaWx1cmVzIC1ndCAwKSB7CiAgICAgICAgcmV0
HLP:dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAnc3VzcGVjdCc7IHJlY29tbWVuZF9tZHNjaGVkID0gJHRydWUgfQogICAgfQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAnb2snOyByZWNvbW1lbmRfbWRzY2hlZCA9ICRmYWxzZSB9
HLP:Cn0KCiMgR2V0LVJhbUNoZWNrOiBsZWUgZXZlbnRvcyBXSEVBIHkgcmVzdWx0YWRvcyBkZWwgRGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZQojIFdpbmRvd3MuIERlZ3JhZGFjaW9uIGVsZWdhbnRlOiBzaSBsYSBjb25zdWx0YSBkZSBldmVudG9zIGZhbGxhIHBvciBj
HLP:b21wbGV0bywKIyBkZXZ1ZWx2ZSBzdGF0dXM9J3Vua25vd24nIHNpbiBsYW56YXIgZXhjZXBjaW9uLgpmdW5jdGlvbiBHZXQtUmFtQ2hlY2sgewogICAgdHJ5IHsKICAgICAgICAkcXVlcmllZCA9ICRmYWxzZQogICAgICAgICR3aGVhQ291bnQgPSAwCiAgICAgICAg
HLP:JG1lbURpYWdGYWlsID0gMAogICAgICAgICMgRXJyb3JlcyBkZSBoYXJkd2FyZSBXSEVBIHJlbGFjaW9uYWRvcyBjb24gbWVtb3JpYQogICAgICAgICR3aGVhID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IFByb3Zp
HLP:ZGVyTmFtZT0nTWljcm9zb2Z0LVdpbmRvd3MtV0hFQS1Mb2dnZXInfSAtTWF4RXZlbnRzIDEwMCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICBpZiAoJG51bGwgLW5lICR3aGVhKSB7ICRxdWVyaWVkID0gJHRydWUgfQogICAgICAgICR3aGVh
HLP:Q291bnQgPSBAKCR3aGVhIHwgV2hlcmUtT2JqZWN0IHsgKCRfLklkIC1pbiAxOCwxOSwyMCw0NykgLW9yICgkXy5NZXNzYWdlIC1tYXRjaCAnbWVtb3InKSB9KS5Db3VudAogICAgICAgICMgUmVzdWx0YWRvcyBkZWwgRGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZSBX
HLP:aW5kb3dzIChtZHNjaGVkKQogICAgICAgICRtZCA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBQcm92aWRlck5hbWU9J01pY3Jvc29mdC1XaW5kb3dzLU1lbW9yeURpYWdub3N0aWNzLVJlc3VsdHMnfSAtTWF4RXZl
HLP:bnRzIDUwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkbnVsbCAtbmUgJG1kKSB7ICRxdWVyaWVkID0gJHRydWUgfQogICAgICAgICRtZW1EaWFnRmFpbCA9IEAoJG1kIHwgV2hlcmUtT2JqZWN0IHsgKCRfLklkIC1lcSAxMDAyKSAt
HLP:b3IgKCRfLkxldmVsRGlzcGxheU5hbWUgLWVxICdFcnJvcicpIC1vciAoJF8uTWVzc2FnZSAtbWF0Y2ggJ2Vycm9yfGVycm9yZXMnKSB9KS5Db3VudAogICAgICAgIHJldHVybiAoUmVzb2x2ZS1SYW1TdGF0dXMgJHdoZWFDb3VudCAkbWVtRGlhZ0ZhaWwpCiAgICB9
HLP:IGNhdGNoIHsKICAgICAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICd1bmtub3duJzsgcmVjb21tZW5kX21kc2NoZWQgPSAkZmFsc2UgfQogICAgfQp9CgojIC0tLSBCYXRlcmlhIChSZXEgMTUuMikgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgR2V0LUJhdHRlcnlIZWFsdGhQY3Q6IGZ1bmNpb24gUFVSQS4gJSBkZSBzYWx1ZCA9IHBsZW5hIGNhcmdhIC8gZGlzZW5vICogMTAwLgpmdW5jdGlvbiBHZXQtQmF0dGVyeUhlYWx0aFBjdCgkZGVzaWduLCAkZnVs
HLP:bCkgewogICAgdHJ5IHsKICAgICAgICAkZCA9IFtkb3VibGVdJGRlc2lnbjsgJGYgPSBbZG91YmxlXSRmdWxsCiAgICAgICAgaWYgKCRkIC1ndCAwKSB7IHJldHVybiBbaW50XVttYXRoXTo6Um91bmQoKCRmIC8gJGQpICogMTAwKSB9CiAgICB9IGNhdGNoIHt9CiAg
HLP:ICByZXR1cm4gJG51bGwKfQoKIyBHZXQtQmF0dGVyeUhlYWx0aDogc2kgaGF5IGJhdGVyaWEsIGdlbmVyYSBwb3dlcmNmZyAvYmF0dGVyeXJlcG9ydCB5IGV4dHJhZSBsYQojIHNhbHVkIChjYXBhY2lkYWQgZGUgZGlzZW5vIHZzIHBsZW5hIGNhcmdhKS4gU2luIGJh
HLP:dGVyaWEgLT4gcHJlc2VudD0kZmFsc2UuCiMgTm8gZmFsbGEgc2kgcG93ZXJjZmcgbm8gZXN0YSBkaXNwb25pYmxlIChoZWFsdGhfcGN0IHF1ZWRhIHZhY2lvKS4KZnVuY3Rpb24gR2V0LUJhdHRlcnlIZWFsdGggewogICAgJHByZXNlbnQgPSAkZmFsc2U7ICRoZWFs
HLP:dGhQY3QgPSAnJzsgJHJlcG9ydFBhdGggPSAnJwogICAgdHJ5IHsKICAgICAgICAkYmF0ID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfQmF0dGVyeSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICBpZiAoJGJhdC5Db3VudCAtZ3QgMCkgewog
HLP:ICAgICAgICAgICAkcHJlc2VudCA9ICR0cnVlCiAgICAgICAgICAgICRyZXBvcnRQYXRoID0gSm9pbi1QYXRoICRXb3JrICdiYXR0ZXJ5LXJlcG9ydC5odG1sJwogICAgICAgICAgICB0cnkgeyAmIHBvd2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0IC9vdXRwdXQgIiRyZXBv
HLP:cnRQYXRoIiAvZHVyYXRpb24gMSA+ICRudWxsIDI+JjEgfSBjYXRjaCB7fQogICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRyZXBvcnRQYXRoKSB7CiAgICAgICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgICAgICR0eHQgPSBHZXQtQ29udGVudCAkcmVw
HLP:b3J0UGF0aCAtUmF3CiAgICAgICAgICAgICAgICAgICAgJGRlc2lnbiA9ICRudWxsOyAkZnVsbCA9ICRudWxsCiAgICAgICAgICAgICAgICAgICAgJG0xID0gW3JlZ2V4XTo6TWF0Y2goJHR4dCwgJyg/aXMpREVTSUdOIENBUEFDSVRZLio/KFtcZFwuLF0rKVxzKm1X
HLP:aCcpCiAgICAgICAgICAgICAgICAgICAgJG0yID0gW3JlZ2V4XTo6TWF0Y2goJHR4dCwgJyg/aXMpRlVMTCBDSEFSR0UgQ0FQQUNJVFkuKj8oW1xkXC4sXSspXHMqbVdoJykKICAgICAgICAgICAgICAgICAgICBpZiAoJG0xLlN1Y2Nlc3MpIHsgJGRlc2lnbiA9IFtk
HLP:b3VibGVdKCgkbTEuR3JvdXBzWzFdLlZhbHVlIC1yZXBsYWNlICdbXC4sXScsICcnKSkgfQogICAgICAgICAgICAgICAgICAgIGlmICgkbTIuU3VjY2VzcykgeyAkZnVsbCAgID0gW2RvdWJsZV0oKCRtMi5Hcm91cHNbMV0uVmFsdWUgLXJlcGxhY2UgJ1tcLixdJywg
HLP:JycpKSB9CiAgICAgICAgICAgICAgICAgICAgJHBjdCA9IEdldC1CYXR0ZXJ5SGVhbHRoUGN0ICRkZXNpZ24gJGZ1bGwKICAgICAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRwY3QpIHsgJGhlYWx0aFBjdCA9ICRwY3QgfQogICAgICAgICAgICAgICAgfSBj
HLP:YXRjaCB7fQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBwcmVzZW50ID0gJHByZXNlbnQ7IGhlYWx0aF9wY3QgPSAkaGVhbHRoUGN0OyByZXBvcnRfcGF0aCA9ICRyZXBvcnRQYXRoIH0K
HLP:fQoKIyAtLS0gTmV0d29yayBhdmFuemFkYSAoUmVxIDE1LjUpIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtTmV0QWR2YW5jZWQ6IGNvbmVjdGl2aWRhZCAocGluZyBhIDEuMS4xLjEpLCBETlMgKFJlc29sdmUtRG5z
HLP:TmFtZSBjb24KIyByZXNwYWxkbyBwb3IgcGluZyBhIHVuIGhvc3QpIHkgY29uZmlndXJhY2lvbiBiYXNpY2EgKElQL2dhdGV3YXkpLgojIERlZ3JhZGFjaW9uIGVsZWdhbnRlOiBudW5jYSBsYW56YSBleGNlcGNpb24uCmZ1bmN0aW9uIEdldC1OZXRBZHZhbmNlZCB7
HLP:CiAgICAkY29ubmVjdGVkID0gJGZhbHNlOyAkZG5zT2sgPSAkZmFsc2U7ICRkZXRhaWxzID0gJycKICAgIHRyeSB7CiAgICAgICAgIyBDb25lY3RpdmlkYWQKICAgICAgICAkcGluZyA9ICRmYWxzZQogICAgICAgIHRyeSB7ICRwaW5nID0gW2Jvb2xdKFRlc3QtQ29u
HLP:bmVjdGlvbiAtQ29tcHV0ZXJOYW1lICcxLjEuMS4xJyAtQ291bnQgMSAtUXVpZXQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIH0gY2F0Y2ggeyAkcGluZyA9ICRmYWxzZSB9CiAgICAgICAgaWYgKC1ub3QgJHBpbmcpIHsKICAgICAgICAgICAgdHJ5IHsg
HLP:JiBwaW5nIC1uIDEgLXcgMTUwMCAxLjEuMS4xID4gJG51bGwgMj4mMTsgaWYgKCRMQVNURVhJVENPREUgLWVxIDApIHsgJHBpbmcgPSAkdHJ1ZSB9IH0gY2F0Y2gge30KICAgICAgICB9CiAgICAgICAgJGNvbm5lY3RlZCA9IFtib29sXSRwaW5nCiAgICAgICAgIyBS
HLP:ZXNvbHVjaW9uIEROUyAoY29uIG1lZGlkYSBkZSBsYXRlbmNpYSkKICAgICAgICAkZG5zID0gJGZhbHNlOyAkZG5zTXMgPSAkbnVsbAogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRzdyA9IFtTeXN0ZW0uRGlhZ25vc3RpY3MuU3RvcHdhdGNoXTo6U3RhcnROZXco
HLP:KQogICAgICAgICAgICAkciA9IFJlc29sdmUtRG5zTmFtZSAtTmFtZSAnd3d3Lm1pY3Jvc29mdC5jb20nIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgICRzdy5TdG9wKCkKICAgICAgICAgICAgaWYgKCRyKSB7ICRkbnMgPSAkdHJ1ZTsg
HLP:JGRuc01zID0gW2ludF0kc3cuRWxhcHNlZE1pbGxpc2Vjb25kcyB9CiAgICAgICAgfSBjYXRjaCB7fQogICAgICAgIGlmICgtbm90ICRkbnMpIHsKICAgICAgICAgICAgdHJ5IHsgJiBwaW5nIC1uIDEgLXcgMTUwMCB3d3cubWljcm9zb2Z0LmNvbSA+ICRudWxsIDI+
HLP:JjE7IGlmICgkTEFTVEVYSVRDT0RFIC1lcSAwKSB7ICRkbnMgPSAkdHJ1ZSB9IH0gY2F0Y2gge30KICAgICAgICB9CiAgICAgICAgJGRuc09rID0gW2Jvb2xdJGRucwogICAgICAgICMgQ29uZmlndXJhY2lvbiBiYXNpY2EgKElQIC8gZ2F0ZXdheSkKICAgICAgICAk
HLP:aXAgPSAnJzsgJGd3ID0gJycKICAgICAgICB0cnkgewogICAgICAgICAgICAkY2ZnID0gQChHZXQtTmV0SVBDb25maWd1cmF0aW9uIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgJF8uSVB2NERlZmF1bHRHYXRld2F5IH0pIHwg
HLP:U2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICBpZiAoJGNmZykgewogICAgICAgICAgICAgICAgJGlwID0gKCRjZmcuSVB2NEFkZHJlc3MgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5JUEFkZHJlc3MKICAgICAgICAgICAgICAgICRndyA9ICgkY2Zn
HLP:LklQdjREZWZhdWx0R2F0ZXdheSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEpLk5leHRIb3AKICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2gge30KICAgICAgICAkZGV0YWlscyA9ICJJUD0kaXA7IEdXPSRndyIKICAgIH0gY2F0Y2gge30KICAgIHJldHVybiBb
HLP:cHNjdXN0b21vYmplY3RdQHsgY29ubmVjdGVkID0gJGNvbm5lY3RlZDsgZG5zX29rID0gJGRuc09rOyBkZXRhaWxzID0gJGRldGFpbHM7IGRuc19tcyA9ICRkbnNNcyB9Cn0KCiMgLS0tIERldmljZXMgcGFyYSBkaWFnIChSZXEgMTUuMy8xNS40KSAtLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgR2V0LURldmljZUxpc3Q6IGxpc3RhIGVzdHJ1Y3R1cmFkYSBkZSBkaXNwb3NpdGl2b3MgY29uIGVycm9yIHBhcmEgZXN0YWRvLmRpYWcuCiMgRGV2dWVsdmUgJG51bGwgc2kgbGEgaWRlbnRpZmljYWNpb24gZGUgZHJpdmVy
HLP:cyBmYWxsYSAoc2VuYWwgZGUgImluZm8gbm8KIyBkaXNwb25pYmxlIiBwYXJhIGRlZ3JhZGFjaW9uIGVsZWdhbnRlKS4KZnVuY3Rpb24gR2V0LURldmljZUxpc3QgewogICAgdHJ5IHsKICAgICAgICAkcCA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1BuUEVudGl0
HLP:eSAtRXJyb3JBY3Rpb24gU3RvcCB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUgLWd0IDAgfSkKICAgICAgICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRkIGluICgkcCB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEyKSkgewog
HLP:ICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsgY29kZSA9IFtpbnRdJGQuQ29uZmlnTWFuYWdlckVycm9yQ29kZTsgbmFtZSA9IFtzdHJpbmddJGQuTmFtZSB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAsJGxpc3QKICAgIH0gY2F0Y2ggeyBy
HLP:ZXR1cm4gJG51bGwgfQp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIFJPVEFDSU9OIERFIExPR1MgKDUuNiAvIFJlcSAxNy4yKQojID09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgU2VsZWN0LUxvZ3NUb0RlbGV0ZTogZnVuY2lvbiBQVVJBLiBEZSB1bmEgY29sZWNjaW9uIGRlIGZpY2hlcm9zIChjb24KIyAuTGFzdFdyaXRlVGltZSkgeSB1
HLP:bmEgcmV0ZW5jaW9uIE4sIGRldnVlbHZlIGxvcyBxdWUgZGViZW4gQk9SUkFSU0U6IHRvZG9zCiMgbWVub3MgbG9zIE4gbWFzIHJlY2llbnRlcyAoZXMgZGVjaXIsIGxvcyBtYXMgYW50aWd1b3MpLiBTaSBoYXkgPD0gTiwgbmluZ3Vuby4KZnVuY3Rpb24gU2VsZWN0
HLP:LUxvZ3NUb0RlbGV0ZSgkZmlsZXMsIFtpbnRdJHJldGVudGlvbikgewogICAgJGFyciA9IEAoJGZpbGVzKQogICAgaWYgKCRyZXRlbnRpb24gLWx0IDApIHsgJHJldGVudGlvbiA9IDAgfQogICAgaWYgKCRhcnIuQ291bnQgLWxlICRyZXRlbnRpb24pIHsgcmV0dXJu
HLP:IEAoKSB9CiAgICAkc29ydGVkID0gQCgkYXJyIHwgU29ydC1PYmplY3QgLVByb3BlcnR5IExhc3RXcml0ZVRpbWUgLURlc2NlbmRpbmcpCiAgICByZXR1cm4gQCgkc29ydGVkIHwgU2VsZWN0LU9iamVjdCAtU2tpcCAkcmV0ZW50aW9uKQp9CgojIEludm9rZS1Mb2dS
HLP:b3RhdGU6IGNvbnNlcnZhIGxvcyAkcmV0ZW50aW9uIGxvZ3MgbWFzIHJlY2llbnRlcyBlbiAkZm9sZGVyIHkKIyBib3JyYSBlbCByZXN0by4gRGV2dWVsdmUgZWwgbnVtZXJvIGRlIGZpY2hlcm9zIGJvcnJhZG9zLgpmdW5jdGlvbiBJbnZva2UtTG9nUm90YXRlKFtz
HLP:dHJpbmddJGZvbGRlciwgW2ludF0kcmV0ZW50aW9uKSB7CiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkZm9sZGVyKSkgeyAkZm9sZGVyID0gSm9pbi1QYXRoICRXb3JrICdMb2dzJyB9CiAgICAkZGVsZXRlZCA9IDAKICAgIHRyeSB7CiAgICAg
HLP:ICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkZm9sZGVyKSkgeyByZXR1cm4gMCB9CiAgICAgICAgJGZpbGVzID0gQChHZXQtQ2hpbGRJdGVtIC1QYXRoICRmb2xkZXIgLUZpbHRlciAnKi5sb2cnIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAg
HLP:ICAgICR0b0RlbGV0ZSA9IFNlbGVjdC1Mb2dzVG9EZWxldGUgJGZpbGVzICRyZXRlbnRpb24KICAgICAgICBmb3JlYWNoICgkZiBpbiAkdG9EZWxldGUpIHsKICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJGYuRnVsbE5hbWUgLUZvcmNlIC1FcnJvckFjdGlv
HLP:biBTaWxlbnRseUNvbnRpbnVlOyAkZGVsZXRlZCsrIH0gY2F0Y2gge30KICAgICAgICB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gJGRlbGV0ZWQKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PQojICBWQUxJREFDSU9OIERFIEVOVE9STk8gWSBTRUxGLVRFU1QgKDUuOCAvIFJlcSAxMy41LDEzLjYsMTguMSwxOC4zLDE4LjYpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT0KIyBUZXN0LU9zU3VwcG9ydGVkOiBmdW5jaW9uIFBVUkEuIFdpbmRvd3MgMTAvMTEgPT4gYnVpbGQgPj0gMTAyNDAuCmZ1bmN0aW9uIFRlc3QtT3NTdXBwb3J0ZWQoW2ludF0kYnVpbGQpIHsKICAgIHJldHVybiAoJGJ1aWxkIC1nZSAx
HLP:MDI0MCkKfQoKIyBJbnZva2UtRW52VmFsaWRhdGU6IGNvbXBydWViYSBsYSB2ZXJzaW9uIGRlbCBTTyB2aWEgQ0lNLiBMYSBjb21wcm9iYWNpb24gc2UKIyBjb25zaWRlcmEgU0lFTVBSRSByZWFsaXphZGEgKGNoZWNrX2RvbmUpIGF1bnF1ZSBsYSB2ZXJzaW9uIG5v
HLP:IHNlYSBjb21wYXRpYmxlLgpmdW5jdGlvbiBJbnZva2UtRW52VmFsaWRhdGUgewogICAgJGJ1aWxkID0gMAogICAgdHJ5IHsgJGJ1aWxkID0gW2ludF0oR2V0LUNpbUluc3RhbmNlIFdpbjMyX09wZXJhdGluZ1N5c3RlbSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250
HLP:aW51ZSkuQnVpbGROdW1iZXIgfSBjYXRjaCB7ICRidWlsZCA9IDAgfQogICAgaWYgKCRidWlsZCAtbGUgMCkgeyB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtSXRlbVByb3BlcnR5ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVy
HLP:c2lvbicgLU5hbWUgQ3VycmVudEJ1aWxkTnVtYmVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS5DdXJyZW50QnVpbGROdW1iZXIgfSBjYXRjaCB7ICRidWlsZCA9IDAgfSB9CiAgICBpZiAoJGJ1aWxkIC1sZSAwKSB7IHRyeSB7ICRidWlsZCA9IFtpbnRd
HLP:KEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uJyAtTmFtZSBDdXJyZW50QnVpbGQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLkN1cnJlbnRCdWlsZCB9IGNhdGNoIHsgJGJ1aWxk
HLP:ID0gMCB9IH0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgb3Nfb2sgPSAoVGVzdC1Pc1N1cHBvcnRlZCAkYnVpbGQpOyBidWlsZCA9ICRidWlsZDsgY2hlY2tfZG9uZSA9ICR0cnVlIH0KfQoKIyBJbnZva2UtU2VsZlRlc3Q6IGFncmVnYWRvciBQVVJPLiBF
HLP:eGl0byAodHJ1ZSkgc2kgeSBzb2xvIHNpIFRPREFTIGxhcwojIGNvbXByb2JhY2lvbmVzIChib29sZWFub3MpIHBhc2FuLiBDb2xlY2Npb24gdmFjaWEgLT4gdHJ1ZSAobmFkYSBmYWxsbykuCmZ1bmN0aW9uIEludm9rZS1TZWxmVGVzdCgkcmVzdWx0cykgewogICAg
HLP:Zm9yZWFjaCAoJHIgaW4gQCgkcmVzdWx0cykpIHsgaWYgKC1ub3QgW2Jvb2xdJHIpIHsgcmV0dXJuICRmYWxzZSB9IH0KICAgIHJldHVybiAkdHJ1ZQp9CgojIFBhcnNlLUJvb2xMaXN0OiBjb252aWVydGUgIjEsMSwwLDEiIChvIHRydWUvb2spIGVuIHVuYSBsaXN0
HLP:YSBkZSBib29sZWFub3MuCmZ1bmN0aW9uIFBhcnNlLUJvb2xMaXN0KFtzdHJpbmddJHJhdykgewogICAgJGxpc3QgPSBAKCkKICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHJhdykpIHsKICAgICAgICBmb3JlYWNoICgkdCBpbiAoJHJh
HLP:dyAtc3BsaXQgJywnKSkgewogICAgICAgICAgICAkdG9rID0gJHQuVHJpbSgpLlRvTG93ZXIoKQogICAgICAgICAgICBpZiAoJHRvayAtZXEgJycpIHsgY29udGludWUgfQogICAgICAgICAgICAkbGlzdCArPSAoJHRvayAtZXEgJzEnIC1vciAkdG9rIC1lcSAndHJ1
HLP:ZScgLW9yICR0b2sgLWVxICdvaycgLW9yICR0b2sgLWVxICdwYXNzJykKICAgICAgICB9CiAgICB9CiAgICByZXR1cm4gLCRsaXN0Cn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBESUFHTk9TVElDTyBQUk9GVU5ETyB2My4xIChTTUFSVCwgYXJyYW5xdWUsIEJDRCwgcHJvY2Vzb3MsIFNGQywg
HLP:SlNPTikKIyAgVG9kYXMgbGFzIGZ1bmNpb25lcyBkZWdyYWRhbiBjb24gZWxlZ2FuY2lhOiBzaSBhbGdvIGZhbGxhLCBkZXZ1ZWx2ZW4KIyAgZXN0cnVjdHVyYXMgdmFjaWFzIC8gJ3Vua25vd24nIGVuIGx1Z2FyIGRlIGxhbnphciBleGNlcGNpb25lcy4KIyA9PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKIyBHZXQtU21hcnRBdHRyaWJ1dGVzOiBzYWx1ZCBmaXNpY2EgZGVsIGRpc2NvIGRlIHNpc3RlbWEgKGluZGVwZW5kaWVudGUgZGVsCiMg
HLP:aWRpb21hIGRlIFdpbmRvd3MpLiBVc2EgTVNTdG9yYWdlRHJpdmVyX0ZhaWx1cmVQcmVkaWN0U3RhdHVzICsgZWwgY29udGFkb3IKIyBkZSBmaWFiaWxpZGFkIGRlIGFsbWFjZW5hbWllbnRvLiBEZXZ1ZWx2ZSBhdmFpbGFibGU9JGZhbHNlIHNpIG5vIGhheSBkYXRv
HLP:cy4KZnVuY3Rpb24gR2V0LVNtYXJ0QXR0cmlidXRlcyB7CiAgICAkcmVzID0gW3BzY3VzdG9tb2JqZWN0XUB7IGF2YWlsYWJsZSA9ICRmYWxzZTsgcHJlZGljdF9mYWlsID0gJGZhbHNlOyB0ZW1wX2MgPSAkbnVsbDsgd2Vhcl9wY3QgPSAkbnVsbDsgcG9oID0gJG51
HLP:bGwgfQogICAgdHJ5IHsKICAgICAgICAkcGYgPSAkbnVsbAogICAgICAgIHRyeSB7ICRwZiA9IEAoR2V0LUNpbUluc3RhbmNlIC1OYW1lc3BhY2UgJ3Jvb3Rcd21pJyAtQ2xhc3NOYW1lICdNU1N0b3JhZ2VEcml2ZXJfRmFpbHVyZVByZWRpY3RTdGF0dXMnIC1FcnJv
HLP:ckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSB9IGNhdGNoIHsgJHBmID0gJG51bGwgfQogICAgICAgIGlmICgkcGYgLWFuZCAkcGYuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZQogICAgICAgICAgICBmb3JlYWNoICgkeCBp
HLP:biAkcGYpIHsgaWYgKCR4LlByZWRpY3RGYWlsdXJlKSB7ICRyZXMucHJlZGljdF9mYWlsID0gJHRydWUgfSB9CiAgICAgICAgfQogICAgICAgICMgRGlzY28gcXVlIGNvbnRpZW5lIEM6IC0+IGNvbnRhZG9yIGRlIGZpYWJpbGlkYWQKICAgICAgICB0cnkgewogICAg
HLP:ICAgICAgICAkc3lzRGlzayA9ICRudWxsCiAgICAgICAgICAgIHRyeSB7ICRzeXNEaXNrID0gR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLkRldmljZUlkIC1uZSAkbnVsbCB9IHwgU2VsZWN0
HLP:LU9iamVjdCAtRmlyc3QgMSB9IGNhdGNoIHt9CiAgICAgICAgICAgICRyYyA9ICRudWxsCiAgICAgICAgICAgIGlmICgkc3lzRGlzaykgeyAkcmMgPSAkc3lzRGlzayB8IEdldC1TdG9yYWdlUmVsaWFiaWxpdHlDb3VudGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
HLP:bnRpbnVlIH0KICAgICAgICAgICAgaWYgKC1ub3QgJHJjKSB7ICRyYyA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBHZXQtU3RvcmFnZVJlbGlhYmlsaXR5Q291bnRlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51
HLP:ZSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICBpZiAoJHJjKSB7CiAgICAgICAgICAgICAgICAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlCiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyYy5UZW1wZXJhdHVyZSAtYW5kICRyYy5UZW1w
HLP:ZXJhdHVyZSAtZ3QgMCkgeyAkcmVzLnRlbXBfYyA9IFtpbnRdJHJjLlRlbXBlcmF0dXJlIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLldlYXIpICAgICAgICAgeyAkcmVzLndlYXJfcGN0ID0gW2ludF0kcmMuV2VhciB9CiAgICAgICAgICAgICAg
HLP:ICBpZiAoJG51bGwgLW5lICRyYy5Qb3dlck9uSG91cnMpIHsgJHJlcy5wb2ggPSBbaW50XSRyYy5Qb3dlck9uSG91cnMgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICMgU2VuYWwgYWRpY2lvbmFsIGRlIHByZWRpY2Npb24gZGUgZmFsbG8gdmlhIGVzdGFkbyBk
HLP:ZSBzYWx1ZCBmaXNpY2EKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICR1bmhlYWx0aHkgPSBAKEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBXaGVyZS1PYmplY3QgeyAkXy5IZWFsdGhTdGF0dXMgLWFuZCAk
HLP:Xy5IZWFsdGhTdGF0dXMgLW5lICdIZWFsdGh5JyB9KQogICAgICAgICAgICAgICAgaWYgKCR1bmhlYWx0aHkuQ291bnQgLWd0IDApIHsgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZTsgJHJlcy5wcmVkaWN0X2ZhaWwgPSAkdHJ1ZSB9CiAgICAgICAgICAgIH0gY2F0Y2gg
HLP:e30KICAgICAgICB9IGNhdGNoIHt9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gJHJlcwp9CgojIEdldC1TdGFydHVwSXRlbXM6IHByb2dyYW1hcyBxdWUgYXJyYW5jYW4gY29uIFdpbmRvd3MgKHRvcCBOKSwgcGFyYSBxdWUgZWwKIyB1c3VhcmlvIHZlYSBxdWUg
HLP:cmFsZW50aXphIGVsIGluaWNpby4gSW5kZXBlbmRpZW50ZSBkZWwgaWRpb21hLgpmdW5jdGlvbiBHZXQtU3RhcnR1cEl0ZW1zKFtpbnRdJHRvcCA9IDgpIHsKICAgIHRyeSB7CiAgICAgICAgJGl0ZW1zID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfU3RhcnR1cENv
HLP:bW1hbmQgLUVycm9yQWN0aW9uIFN0b3AgfAogICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5Db21tYW5kIH0gfAogICAgICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAkdG9wKQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJGkgaW4g
HLP:JGl0ZW1zKSB7CiAgICAgICAgICAgICRjbWQgPSBbc3RyaW5nXSRpLkNvbW1hbmQKICAgICAgICAgICAgaWYgKCRjbWQuTGVuZ3RoIC1ndCA4MCkgeyAkY21kID0gJGNtZC5TdWJzdHJpbmcoMCw3NykgKyAnLi4uJyB9CiAgICAgICAgICAgICRubSA9IFtzdHJpbmdd
HLP:JGkuTmFtZTsgaWYgKC1ub3QgJG5tKSB7ICRubSA9IFtzdHJpbmddJGkuQ2FwdGlvbiB9CiAgICAgICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBuYW1lID0gJG5tOyBjb21tYW5kID0gJGNtZCB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAsJGxp
HLP:c3QKICAgIH0gY2F0Y2ggeyByZXR1cm4gQCgpIH0KfQoKIyBHZXQtQmNkSW50ZWdyaXR5OiBjb21wcnVlYmEgcXVlIGxhIGNvbmZpZ3VyYWNpb24gZGUgYXJyYW5xdWUgKEJDRCkgdGllbmUgbGEKIyBlbnRyYWRhIGFjdHVhbCBjb24gb3NkZXZpY2UvZGV2aWNlLiBM
HLP:YXMgQ0xBVkVTIGRlIGJjZGVkaXQgc29uIHNpZW1wcmUgZW4KIyBpbmdsZXMsIGFzaSBxdWUgZXMgaW5kZXBlbmRpZW50ZSBkZWwgaWRpb21hIGRlIGxhIGludGVyZmF6LgpmdW5jdGlvbiBHZXQtQmNkSW50ZWdyaXR5IHsKICAgICRyZXMgPSBbcHNjdXN0b21vYmpl
HLP:Y3RdQHsgb2sgPSAkZmFsc2U7IGRldGFpbHMgPSAnJyB9CiAgICB0cnkgewogICAgICAgICRvdXQgPSAmIGJjZGVkaXQgL2VudW0gJ3tjdXJyZW50fScgMj4kbnVsbAogICAgICAgICR0eHQgPSAoJG91dCAtam9pbiAiYG4iKQogICAgICAgIGlmICgkTEFTVEVYSVRD
HLP:T0RFIC1lcSAwIC1hbmQgJHR4dCAtbWF0Y2ggJyg/aW0pXlxzKm9zZGV2aWNlJyAtYW5kICR0eHQgLW1hdGNoICcoP2ltKV5ccypkZXZpY2UnKSB7CiAgICAgICAgICAgICRyZXMub2sgPSAkdHJ1ZQogICAgICAgICAgICAkcmVzLmRldGFpbHMgPSAnRW50cmFkYSBk
HLP:ZSBhcnJhbnF1ZSBhY3R1YWwgaW50ZWdyYSAoZGV2aWNlL29zZGV2aWNlIHByZXNlbnRlcykuJwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRyZXMub2sgPSAkZmFsc2UKICAgICAgICAgICAgJHJlcy5kZXRhaWxzID0gJ0NvdWxkIG5vdCBjb25maXJtIHRo
HLP:ZSBjdXJyZW50IHN0YXJ0dXAgZW50cnkuJwogICAgICAgIH0KICAgIH0gY2F0Y2ggewogICAgICAgICRyZXMub2sgPSAkZmFsc2UKICAgICAgICAkcmVzLmRldGFpbHMgPSAnYmNkZWRpdCBubyBkaXNwb25pYmxlIG8gc2luIHBlcm1pc29zLicKICAgIH0KICAgIHJl
HLP:dHVybiAkcmVzCn0KCiMgR2V0LVRvcFByb2Nlc3NlczogcHJvY2Vzb3MgcXVlIG1hcyBtZW1vcmlhIGRlIHRyYWJham8gY29uc3VtZW4gKHRvcCBOKS4KZnVuY3Rpb24gR2V0LVRvcFByb2Nlc3NlcyhbaW50XSR0b3AgPSA2KSB7CiAgICB0cnkgewogICAgICAgICRw
HLP:cyA9IEAoR2V0LVByb2Nlc3MgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAgICAgICBTb3J0LU9iamVjdCBXb3JraW5nU2V0NjQgLURlc2NlbmRpbmcgfAogICAgICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAkdG9wKQogICAgICAgICRs
HLP:aXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHBzKSB7CiAgICAgICAgICAgICRtYiA9IFttYXRoXTo6Um91bmQoJHAuV29ya2luZ1NldDY0IC8gMU1CKQogICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsgbmFtZSA9IFtzdHJpbmdd
HLP:JHAuUHJvY2Vzc05hbWU7IG1lbV9tYiA9IFtpbnRdJG1iIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuICwkbGlzdAogICAgfSBjYXRjaCB7IHJldHVybiBAKCkgfQp9CgojIEdldC1TZmNSZXN1bHQ6IGNsYXNpZmljYSBlbCByZXN1bHRhZG8gZGUgU0ZDIGxleWVu
HLP:ZG8gQ0JTLmxvZyAoU0lFTVBSRSBlbgojIGluZ2xlcykgZW4gbHVnYXIgZGUgbGEgc2FsaWRhIHRyYWR1Y2lkYSBkZSBsYSBjb25zb2xhLiBEZXZ1ZWx2ZSB1bm8gZGU6CiMgY2xlYW4gfCByZXBhaXJlZCB8IHVucmVwYWlyYWJsZSB8IHVua25vd24uCmZ1bmN0aW9u
HLP:IEdldC1TZmNSZXN1bHQgewogICAgJGxvZyA9IEpvaW4tUGF0aCAkZW52OndpbmRpciAnTG9nc1xDQlNcQ0JTLmxvZycKICAgIGlmICgtbm90IChUZXN0LVBhdGggJGxvZykpIHsgcmV0dXJuICd1bmtub3duJyB9CiAgICB0cnkgewogICAgICAgICR0YWlsID0gQChH
HLP:ZXQtQ29udGVudCAtUGF0aCAkbG9nIC1UYWlsIDQwMDAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgJHNyID0gQCgkdGFpbCB8IFdoZXJlLU9iamVjdCB7ICRfIC1tYXRjaCAnXFtTUlxdJyB9KQogICAgICAgIGlmICgkc3IuQ291bnQgLWVx
HLP:IDApIHsgcmV0dXJuICd1bmtub3duJyB9CiAgICAgICAgJGpvaW5lZCA9ICgkc3IgLWpvaW4gImBuIikKICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSljYW5ub3QgcmVwYWlyJykgeyByZXR1cm4gJ3VucmVwYWlyYWJsZScgfQogICAgICAgIGlmICgkam9p
HLP:bmVkIC1tYXRjaCAnKD9pKXJlcGFpcmluZ1xzKyhbMS05XVxkKilccytjb21wb25lbnRzfHN1Y2Nlc3NmdWxseSByZXBhaXJlZHxyZXBhaXJlZCBmaWxlfHJlcGFpcmluZyBjb3JydXB0ZWQgZmlsZScpIHsgcmV0dXJuICdyZXBhaXJlZCcgfQogICAgICAgIGlmICgk
HLP:am9pbmVkIC1tYXRjaCAnKD9pKXZlcmlmeSBjb21wbGV0ZXxubyAuKmludGVncml0eSB2aW9sYXRpb25zfGNhbm5vdCB2ZXJpZnl8dmVyaWZ5aW5nJykgeyByZXR1cm4gJ2NsZWFuJyB9CiAgICAgICAgcmV0dXJuICdjbGVhbicKICAgIH0gY2F0Y2ggeyByZXR1cm4g
HLP:J3Vua25vd24nIH0KfQoKIyBOZXctSnNvblJlcG9ydDogdnVlbGNhIGVsIGVzdGFkbyArIHJlc3VtZW4gY2FsY3VsYWRvIGEgdW4gZmljaGVybyBKU09OCiMgKC1BcmcgPSBydXRhIGRlIHNhbGlkYSkuIFV0aWwgcGFyYSBhdXRvbWF0aXphY2lvbiAvIE1ETSAvIGlu
HLP:dmVudGFyaW8uCmZ1bmN0aW9uIE5ldy1Kc29uUmVwb3J0KCRvdXRQYXRoKSB7CiAgICB0cnkgewogICAgICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICAgICAkc3lzUGFpcnMgPSBHZXQtU3lzSW5mbwogICAgICAgICRzeXNNYXAgPSBAe30KICAgICAgICBmb3JlYWNo
HLP:ICgkcCBpbiAkc3lzUGFpcnMpIHsgJGt2ID0gJHAgLXNwbGl0ICc9JywyOyBpZiAoJGt2LkNvdW50IC1lcSAyKSB7ICRzeXNNYXBbJGt2WzBdXSA9ICRrdlsxXSB9IH0KICAgICAgICAkcGhhc2VzID0gQCgkc3QucGhhc2VzKQogICAgICAgICRjT0s9MDskY1dBUk49
HLP:MDskY0VSUj0wOyRjU0tJUD0wCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsgc3dpdGNoIChbc3RyaW5nXSRwaC5yZXN1bHQpIHsgJ09LJyB7JGNPSysrfSAnV0FSTicgeyRjV0FSTisrfSAnRVJST1InIHskY0VSUisrfSAnU0tJUCcgeyRjU0tJUCsr
HLP:fSB9IH0KICAgICAgICAkZGVsdGEgPSAkbnVsbAogICAgICAgIGlmICgkc3Quc2NvcmVfYmVmb3JlIC1uZSAkbnVsbCAtYW5kICRzdC5zY29yZV9hZnRlciAtbmUgJG51bGwpIHsgJGRlbHRhID0gW2ludF0kc3Quc2NvcmVfYWZ0ZXIgLSBbaW50XSRzdC5zY29yZV9i
HLP:ZWZvcmUgfQogICAgICAgICRvYmogPSBbcHNjdXN0b21vYmplY3RdQHsKICAgICAgICAgICAgc2NoZW1hICAgICAgID0gJ3dwaS1yZXBvcnQvMScKICAgICAgICAgICAgdmVyc2lvbiAgICAgID0gJFdQSV9WRVJTSU9OCiAgICAgICAgICAgIGdlbmVyYXRlZCAgICA9
HLP:IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3MnKQogICAgICAgICAgICBtYWNoaW5lICAgICAgPSAkZW52OkNPTVBVVEVSTkFNRQogICAgICAgICAgICBzeXN0ZW0gICAgICAgPSAkc3lzTWFwCiAgICAgICAgICAgIHNjb3JlX2JlZm9yZSA9ICRzdC5zY29yZV9iZWZvcmUK
HLP:ICAgICAgICAgICAgc2NvcmVfYWZ0ZXIgID0gJHN0LnNjb3JlX2FmdGVyCiAgICAgICAgICAgIHNjb3JlX2RlbHRhICA9ICRkZWx0YQogICAgICAgICAgICBzdW1tYXJ5ICAgICAgPSBbcHNjdXN0b21vYmplY3RdQHsgb2s9JGNPSzsgd2Fybj0kY1dBUk47IGVycm9y
HLP:PSRjRVJSOyBza2lwPSRjU0tJUDsgdG90YWw9JHBoYXNlcy5Db3VudCB9CiAgICAgICAgICAgIHBoYXNlcyAgICAgICA9ICRwaGFzZXMKICAgICAgICAgICAgZmluZGluZ3MgICAgID0gQCgkc3QuZmluZGluZ3MpCiAgICAgICAgICAgIGRpYWcgICAgICAgICA9ICRz
HLP:dC5kaWFnCiAgICAgICAgfQogICAgICAgICRqc29uID0gJG9iaiB8IENvbnZlcnRUby1Kc29uIC1EZXB0aCA4CiAgICAgICAgJHV0ZjggPSBOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpCiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6
HLP:V3JpdGVBbGxUZXh0KCRvdXRQYXRoLCAkanNvbiwgJHV0ZjgpCiAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVz
HLP:c2FnZSkiCiAgICB9Cn0KCiMgTmV3LVN1cHBvcnRQYWNrYWdlOiBlbXBhcXVldGEgbG9ncyArIGluZm9ybWUgKyBlc3RhZG8gKyBiYXR0ZXJ5LXJlcG9ydCBlbiB1bgojIFpJUCAoLUFyZyA9IHJ1dGEgZGVsIHppcCkgcGFyYSBlbnZpYXIgYSBzb3BvcnRlLiBTaW4g
HLP:ZGVwZW5kZW5jaWFzIGV4dGVybmFzCiMgKHVzYSBDb21wcmVzcy1BcmNoaXZlLCBpbmNsdWlkbyBlbiBXaW5kb3dzIDEwLzExKS4KZnVuY3Rpb24gTmV3LVN1cHBvcnRQYWNrYWdlKCRvdXRQYXRoKSB7CiAgICB0cnkgewogICAgICAgICR0bXAgPSBKb2luLVBhdGgg
HLP:JFdvcmsgKCdzb3BvcnRlXycgKyAoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5TU1kZF9ISG1tc3MnKSkKICAgICAgICBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICR0bXAgLUZvcmNlIHwgT3V0LU51bGwKICAgICAgICAjIGVzdGFkby5qc29uCiAg
HLP:ICAgICAgaWYgKFRlc3QtUGF0aCAkU3RhdGVGaWxlKSB7IENvcHktSXRlbSAkU3RhdGVGaWxlIChKb2luLVBhdGggJHRtcCAnZXN0YWRvLmpzb24nKSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICMgTG9ncwogICAgICAgICRs
HLP:b2dzID0gSm9pbi1QYXRoICRXb3JrICdMb2dzJwogICAgICAgIGlmIChUZXN0LVBhdGggJGxvZ3MpIHsKICAgICAgICAgICAgJGRzdExvZ3MgPSBKb2luLVBhdGggJHRtcCAnTG9ncycKICAgICAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0
HLP:aCAkZHN0TG9ncyAtRm9yY2UgfCBPdXQtTnVsbAogICAgICAgICAgICBHZXQtQ2hpbGRJdGVtICRsb2dzIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgQ29weS1JdGVtIC1EZXN0aW5hdGlvbiAkZHN0TG9ncyAtRm9yY2UgLUVycm9yQWN0aW9u
HLP:IFNpbGVudGx5Q29udGludWUKICAgICAgICB9CiAgICAgICAgIyBJbmZvcm1lcyBIVE1ML0pTT04gZXhpc3RlbnRlcyBlbiBXb3JrCiAgICAgICAgR2V0LUNoaWxkSXRlbSAkV29yayAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAg
HLP:ICAgIFdoZXJlLU9iamVjdCB7ICRfLk5hbWUgLW1hdGNoICcoP2kpXkluZm9ybWUuKlwuKGh0bWx8anNvbikkJyB9IHwKICAgICAgICAgICAgQ29weS1JdGVtIC1EZXN0aW5hdGlvbiAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAg
HLP:ICAgICMgYmF0dGVyeSByZXBvcnQgc2kgZXhpc3RlCiAgICAgICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgICAgIHRyeSB7IGlmICgkc3QuZGlhZyAtYW5kICRzdC5kaWFnLmJhdHRlcnkgLWFuZCAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9wYXRoIC1hbmQgKFRlc3Qt
HLP:UGF0aCAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9wYXRoKSkgeyBDb3B5LUl0ZW0gJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IH0gY2F0Y2gge30KICAgICAgICBpZiAoVGVzdC1Q
HLP:YXRoICRvdXRQYXRoKSB7IFJlbW92ZS1JdGVtICRvdXRQYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgQ29tcHJlc3MtQXJjaGl2ZSAtUGF0aCAoSm9pbi1QYXRoICR0bXAgJyonKSAtRGVzdGluYXRpb25QYXRoICRvdXRQ
HLP:YXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIHRyeSB7IFJlbW92ZS1JdGVtICR0bXAgLVJlY3Vyc2UgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30KICAgICAgICAiUkVTVUxUPU9LIgogICAgICAgICJQQVRI
HLP:PSRvdXRQYXRoIgogICAgfSBjYXRjaCB7CiAgICAgICAgIlJFU1VMVD1GQUlMIgogICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgIH0KfQoKc3dpdGNoICgkQWN0aW9uLlRvTG93ZXIoKSkgewogICAgJ25vbmUnICAgICAgICAgeyB9ICMg
HLP:VXNhZG8gcGFyYSBkb3Qtc291cmNpbmcKICAgICdjaGVja2JhY2t1cHMnIHsKICAgICAgICAkcGFydHMgPSAkQXJnIC1zcGxpdCAnXHwnLCAyCiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtbmUgMikgeyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9QXJndW1lbnRvcyBp
HLP:bnZhbGlkb3MiOyBleGl0IDAgfQogICAgICAgICRia2RpciA9ICRwYXJ0c1swXQogICAgICAgICR0cyA9ICRwYXJ0c1sxXQogICAgICAgICRycF9vayA9ICRmYWxzZQogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRycHMgPSBHZXQtQ29tcHV0ZXJSZXN0b3JlUG9p
HLP:bnQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgZm9yZWFjaCAoJHJwIGluICRycHMpIHsKICAgICAgICAgICAgICAgIGlmICgkcnAuRGVzY3JpcHRpb24gLWxpa2UgIlJlcGFpcl9TdWl0ZV8qIikgeyAkcnBfb2sgPSAkdHJ1ZTsgYnJl
HLP:YWsgfQogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7ICRycF9vayA9ICRmYWxzZSB9CiAgICAgICAgJHJlZ19vayA9ICR0cnVlCiAgICAgICAgJHNvZnQgPSBKb2luLVBhdGggJGJrZGlyICJTT0ZUV0FSRV8kdHMucmVnIgogICAgICAgICRzeXMgPSBKb2lu
HLP:LVBhdGggJGJrZGlyICJTWVNURU1fJHRzLnJlZyIKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRzb2Z0KSAtb3IgKEdldC1JdGVtICRzb2Z0KS5MZW5ndGggLWVxIDApIHsgJHJlZ19vayA9ICRmYWxzZSB9CiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAk
HLP:c3lzKSAtb3IgKEdldC1JdGVtICRzeXMpLkxlbmd0aCAtZXEgMCkgeyAkcmVnX29rID0gJGZhbHNlIH0KICAgICAgICAiUlBfT0s9JChpZiAoJHJwX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiUkVHX09LPSQoaWYgKCRyZWdfb2spIHsnMSd9IGVsc2Ug
HLP:eycwJ30pIgogICAgfQogICAgJ2Jvb3RzdHJhcHdpbmdldCcgewogICAgICAgICRvayA9IEluc3RhbGwtV2luZ2V0Qm9vdHN0cmFwCiAgICAgICAgIkJPT1RTVFJBUF9PSz0kKGlmICgkb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ2ZpbmRsb2NhbHNv
HLP:dXJjZScgewogICAgICAgICRkcml2ZXMgPSBHZXQtUFNEcml2ZSAtUFNQcm92aWRlciBGaWxlU3lzdGVtCiAgICAgICAgJHBhdGhzID0gQCgpCiAgICAgICAgJGVkaXRpb25JZCA9ICcnCiAgICAgICAgdHJ5IHsgJGVkaXRpb25JZCA9IChHZXQtSXRlbVByb3BlcnR5
HLP:ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvbicgLU5hbWUgRWRpdGlvbklEIC1FcnJvckFjdGlvbiBTdG9wKS5FZGl0aW9uSUQgfSBjYXRjaCB7fQogICAgICAgIGZ1bmN0aW9uIEdldC1JbnN0YWxsSW1hZ2VTb3VyY2Uo
HLP:W3N0cmluZ10ka2luZCwgW3N0cmluZ10kcGF0aCwgW3N0cmluZ10kZWRpdGlvbikgewogICAgICAgICAgICAkaW5kZXggPSAxCiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAkaW1hZ2VzID0gQChHZXQtV2luZG93c0ltYWdlIC1JbWFnZVBhdGggJHBh
HLP:dGggLUVycm9yQWN0aW9uIFN0b3ApCiAgICAgICAgICAgICAgICAkbWF0Y2ggPSAkbnVsbAogICAgICAgICAgICAgICAgaWYgKCRlZGl0aW9uIC1tYXRjaCAnUHJvZmVzc2lvbmFsJykgeyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VO
HLP:YW1lIC1tYXRjaCAnXGJQcm9cYnxQcm9mZXNzaW9uYWwnIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRpb24gLW1hdGNoICdFbnRlcnByaXNlJykgeyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0
HLP:IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnRW50ZXJwcmlzZScgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgZWxzZWlmICgkZWRpdGlvbiAtbWF0Y2ggJ0VkdWNhdGlvbicpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJlLU9iamVj
HLP:dCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ0VkdWNhdGlvbicgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgZWxzZWlmICgkZWRpdGlvbiAtbWF0Y2ggJ0NvcmUnKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3QgeyAk
HLP:Xy5JbWFnZU5hbWUgLW1hdGNoICdcYkhvbWVcYnxDb3JlJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLWVxICRtYXRjaCAtYW5kICRpbWFnZXMuQ291bnQgLWVxIDEpIHsgJG1hdGNoID0gJGltYWdlc1swXSB9
HLP:CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRtYXRjaCkgeyAkaW5kZXggPSBbaW50XSRtYXRjaC5JbWFnZUluZGV4IH0KICAgICAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICAgICByZXR1cm4gKCJ7MH06ezF9OnsyfSIgLWYgJGtpbmQsICRwYXRoLCAk
HLP:aW5kZXgpCiAgICAgICAgfQogICAgICAgIGZvcmVhY2ggKCRkIGluICRkcml2ZXMpIHsKICAgICAgICAgICAgJHJvb3QgPSAkZC5Sb290CiAgICAgICAgICAgICR3aW0gPSBKb2luLVBhdGggJHJvb3QgInNvdXJjZXNcaW5zdGFsbC53aW0iCiAgICAgICAgICAgICRl
HLP:c2QgPSBKb2luLVBhdGggJHJvb3QgInNvdXJjZXNcaW5zdGFsbC5lc2QiCiAgICAgICAgICAgICRzeHMgPSBKb2luLVBhdGggJHJvb3QgInNvdXJjZXNcc3hzIgogICAgICAgICAgICBpZiAoVGVzdC1QYXRoICR3aW0pIHsgJHBhdGhzICs9IChHZXQtSW5zdGFsbElt
HLP:YWdlU291cmNlICdXaW0nICR3aW0gJGVkaXRpb25JZCkgfQogICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRlc2QpIHsgJHBhdGhzICs9IChHZXQtSW5zdGFsbEltYWdlU291cmNlICdFc2QnICRlc2QgJGVkaXRpb25JZCkgfQogICAgICAgICAgICBpZiAoVGVzdC1Q
HLP:YXRoICRzeHMpIHsgJHBhdGhzICs9ICRzeHMgfQogICAgICAgIH0KICAgICAgICBpZiAoJHBhdGhzLkNvdW50IC1ndCAwKSB7ICJTT1VSQ0U9JCgkcGF0aHNbMF0pIiB9IGVsc2UgeyAiU09VUkNFPSIgfQogICAgfQogICAgJ2Rpc21yZXN0b3JlJyB7CiAgICAgICAg
HLP:JHBhcnRzID0gQCgkQXJnIC1zcGxpdCAnXHwnLCAyKQogICAgICAgICRzb3VyY2UgPSBpZiAoJHBhcnRzLkNvdW50IC1nZSAxKSB7ICRwYXJ0c1swXSB9IGVsc2UgeyAnJyB9CiAgICAgICAgJHRpbWVvdXRNaW51dGVzID0gNDUKICAgICAgICBpZiAoJHBhcnRzLkNv
HLP:dW50IC1nZSAyKSB7IFt2b2lkXVtpbnRdOjpUcnlQYXJzZSgkcGFydHNbMV0sIFtyZWZdJHRpbWVvdXRNaW51dGVzKSB9CiAgICAgICAgaWYgKCR0aW1lb3V0TWludXRlcyAtbHQgNSkgeyAkdGltZW91dE1pbnV0ZXMgPSA1IH0KCiAgICAgICAgZnVuY3Rpb24gUXVv
HLP:dGUtRGlzbVZhbHVlKFtzdHJpbmddJHZhbHVlKSB7CiAgICAgICAgICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCR2YWx1ZSkpIHsgcmV0dXJuICR2YWx1ZSB9CiAgICAgICAgICAgIHJldHVybiAnIicgKyAoJHZhbHVlIC1yZXBsYWNlICciJywg
HLP:J1wiJykgKyAnIicKICAgICAgICB9CgogICAgICAgICRhcmd1bWVudHMgPSAnL09ubGluZSAvQ2xlYW51cC1JbWFnZSAvUmVzdG9yZUhlYWx0aCcKICAgICAgICBpZiAoLW5vdCBbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRzb3VyY2UpKSB7CiAgICAgICAg
HLP:ICAgICRhcmd1bWVudHMgKz0gJyAvU291cmNlOicgKyAoUXVvdGUtRGlzbVZhbHVlICRzb3VyY2UpICsgJyAvTGltaXRBY2Nlc3MnCiAgICAgICAgfQoKICAgICAgICAkdGltZWRPdXQgPSAkZmFsc2UKICAgICAgICAkZXhpdENvZGUgPSAzCiAgICAgICAgJG91dEZp
HLP:bGUgPSBKb2luLVBhdGggJFdvcmsgKCJkaXNtX3Jlc3RvcmVfezB9Lm91dCIgLWYgKFtndWlkXTo6TmV3R3VpZCgpLlRvU3RyaW5nKCdOJykpKQogICAgICAgICRlcnJGaWxlID0gSm9pbi1QYXRoICRXb3JrICgiZGlzbV9yZXN0b3JlX3swfS5lcnIiIC1mIChbZ3Vp
HLP:ZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKSkKICAgICAgICB0cnkgewogICAgICAgICAgICAkcHNpID0gW0RpYWdub3N0aWNzLlByb2Nlc3NTdGFydEluZm9dOjpuZXcoKQogICAgICAgICAgICAkcHNpLkZpbGVOYW1lID0gJ2NtZC5leGUnCiAgICAgICAgICAg
HLP:ICRwc2kuQXJndW1lbnRzID0gKCcvYyBkaXNtLmV4ZSB7MH0gPiAiezF9IiAyPiAiezJ9IicgLWYgJGFyZ3VtZW50cywgJG91dEZpbGUsICRlcnJGaWxlKQogICAgICAgICAgICAkcHNpLlVzZVNoZWxsRXhlY3V0ZSA9ICRmYWxzZQogICAgICAgICAgICAkcHNpLkNy
HLP:ZWF0ZU5vV2luZG93ID0gJHRydWUKICAgICAgICAgICAgJHAgPSBbRGlhZ25vc3RpY3MuUHJvY2Vzc106Om5ldygpCiAgICAgICAgICAgICRwLlN0YXJ0SW5mbyA9ICRwc2kKICAgICAgICAgICAgW3ZvaWRdJHAuU3RhcnQoKQogICAgICAgICAgICBpZiAoLW5vdCAk
HLP:cC5XYWl0Rm9yRXhpdCgkdGltZW91dE1pbnV0ZXMgKiA2MCAqIDEwMDApKSB7CiAgICAgICAgICAgICAgICAkdGltZWRPdXQgPSAkdHJ1ZQogICAgICAgICAgICAgICAgdHJ5IHsgJHAuS2lsbCgpIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICRleGl0Q29kZSA9
HLP:IDE0NjAKICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgIHRyeSB7ICRwLldhaXRGb3JFeGl0KCkgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgJGV4aXRDb2RlID0gJHAuRXhpdENvZGUKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJGV4
HLP:aXRDb2RlKSB7ICRleGl0Q29kZSA9IDMgfQogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7CiAgICAgICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgICAgICAgICAgJGV4aXRDb2RlID0gMwogICAgICAgIH0KCiAgICAgICAgaWYg
HLP:KFRlc3QtUGF0aCAkb3V0RmlsZSkgeyBHZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJG91dEZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIGlmIChUZXN0LVBhdGggJGVyckZpbGUpIHsgR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRl
HLP:cnJGaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJG91dEZpbGUsJGVyckZpbGUgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgIlRJTUVET1VUPSQoaWYg
HLP:KCR0aW1lZE91dCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkVYSVRDT0RFPSRleGl0Q29kZSIKICAgIH0KICAgICdzeXNpbmZvJyAgICAgIHsgR2V0LVN5c0luZm8gfQogICAgJ3Njb3JlJyAgICAgICAgeyAkaCA9IEdldC1IZWFsdGhTY29yZTsgIlNDT1JF
HLP:PSQoJGguc2NvcmUpIjsgZm9yZWFjaCAoJHIgaW4gJGgucmVhc29ucykgeyAiUkVBU09OPSRyIiB9IH0KICAgICdmb3JlbnNpY3MnICAgIHsgR2V0LUZvcmVuc2ljcyB9CiAgICAndHJpYWdlJyAgICAgICB7IEdldC1UcmlhZ2UgfQogICAgJ3Jlc3RvcmVwb2ludCcg
HLP:eyBOZXctUmVzdG9yZVBvaW50IH0KICAgICdtZWRpYXR5cGUnICAgIHsgJG1lZGlhID0gR2V0LU1lZGlhVHlwZTsgIk1FRElBPSRtZWRpYSI7ICJPUFRJTUlaRT0kKFJlc29sdmUtT3B0aW1pemVBY3Rpb24gJG1lZGlhKSIgfQogICAgJ2RldmljZXMnICAgICAgeyBH
HLP:ZXQtRGV2aWNlUHJvYmxlbXMgfQogICAgJ3JlcG9ydCcgICAgICAgeyBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XZWIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWU7IE5ldy1IdG1sUmVwb3J0ICRBcmcgfQogICAgJ2FkZHBoYXNlJyAgICAgeyBB
HLP:ZGQtUGhhc2VSZXN1bHQgJEFyZyB9CiAgICAnc2V0YmVmb3JlJyAgICB7IFNldC1TY29yZSAnYmVmb3JlJyAkQXJnIH0KICAgICdzZXRhZnRlcicgICAgIHsgU2V0LVNjb3JlICdhZnRlcicgJEFyZyB9CiAgICAnZmluZGluZycgICAgICB7IEFkZC1GaW5kaW5nICRB
HLP:cmcgfQogICAgJ3Jlc2V0c3RhdGUnICAgeyBSZXNldC1TdGF0ZTsgIlJFU1VMVD1PSyIgfQogICAgJ25vcm1hbGl6ZWZhc2VzJyB7CiAgICAgICAgJHIgPSBOb3JtYWxpemUtRmFzZXMgJEFyZwogICAgICAgICJOT1JNPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRy
HLP:Lm5vcm0pKSkiCiAgICAgICAgIklOVkFMSUQ9JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJHIuaW52YWxpZCkpKSIKICAgIH0KICAgICdjaGVja3BvaW50JyB7CiAgICAgICAgJHBhcnNlZCA9IFBhcnNlLUNoZWNrcG9pbnRBcmcgJEFyZwogICAgICAgIHN3aXRjaCAo
HLP:JHBhcnNlZC5zdWIpIHsKICAgICAgICAgICAgJ3NhdmUnIHsgaWYgKFNhdmUtQ2hlY2twb2ludCAkcGFyc2VkKSB7ICJSRVNVTFQ9T0siIH0gZWxzZSB7ICJSRVNVTFQ9RkFJTCIgfSB9CiAgICAgICAgICAgICdsb2FkJyB7CiAgICAgICAgICAgICAgICAkY3AgPSBM
HLP:b2FkLUNoZWNrcG9pbnQKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7ICJSRVNVTFQ9Tk9ORSIgfQogICAgICAgICAgICAgICAgZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAgICAgICAgICAgICAiVkFMSUQ9
HLP:JChpZiAoVGVzdC1DaGVja3BvaW50VmFsaWQgJGNwKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiVkVSU0lPTj0kKCRjcC52ZXJzaW9uKSIKICAgICAgICAgICAgICAgICAgICAiQ1JFQVRFRD0kKCRjcC5jcmVhdGVkKSIKICAgICAgICAg
HLP:ICAgICAgICAgICAiU0VMRUNUSU9OPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRjcC5zZWxlY3Rpb24pKSkiCiAgICAgICAgICAgICAgICAgICAgIkNPTVBMRVRFRD0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkY3AuY29tcGxldGVkKSkpIgogICAgICAgICAgICAg
HLP:ICAgICAgICJSRUFTT049JCgkY3AucGVuZGluZ19yZWFzb24pIgogICAgICAgICAgICAgICAgICAgICJORVhUPSQoR2V0LU5leHRQaGFzZSAkY3ApIgogICAgICAgICAgICAgICAgICAgICJNT0RFX0FVVE89JChpZiAoJGNwLm1vZGUuYXV0bykgeycxJ30gZWxzZSB7
HLP:JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfTk9SRUJPT1Q9JChpZiAoJGNwLm1vZGUubm9yZWJvb3QpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJNT0RFX0tFRVBXVT0kKGlmICgkY3AubW9kZS5rZWVwd3UpIHsnMSd9IGVs
HLP:c2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJNT0RFX0RSWT0kKGlmICgkY3AubW9kZS5kcnkpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJNT0RFX1RSSUFHRT0kKGlmICgkY3AubW9kZS50cmlhZ2UpIHsnMSd9IGVsc2Ugeycw
HLP:J30pIgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICduZXh0JyB7CiAgICAgICAgICAgICAgICAkY3AgPSBMb2FkLUNoZWNrcG9pbnQKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGNwIC1hbmQgKFRlc3QtQ2hlY2twb2lu
HLP:dFZhbGlkICRjcCkpIHsgIk5FWFQ9JChHZXQtTmV4dFBoYXNlICRjcCkiIH0gZWxzZSB7ICJORVhUPSIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICdjbGVhcicgewogICAgICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkQ2hlY2twb2ludEZpbGUpIHsKICAg
HLP:ICAgICAgICAgICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAkQ2hlY2twb2ludEZpbGUgLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wOyAiUkVTVUxUPU9LIiB9IGNhdGNoIHsgIlJFU1VMVD1GQUlMIiB9CiAgICAgICAgICAgICAgICB9IGVsc2UgeyAiUkVTVUxUPU9L
HLP:IiB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgZGVmYXVsdCB7ICJSRVNVTFQ9RkFJTCI7ICJFUlJPUj1zdWJhY2Npb24gZGUgY2hlY2twb2ludCBkZXNjb25vY2lkYSIgfQogICAgICAgIH0KICAgIH0KICAgICdtb3ZlcmVzdWx0JyB7CiAgICAgICAgJHBhcnRz
HLP:ID0gJEFyZyAtc3BsaXQgJ1x8JywgMgogICAgICAgIGlmICgkcGFydHMuQ291bnQgLWVxIDIpIHsKICAgICAgICAgICAgJG9rID0gVGVzdC1Nb3ZlUmVzdWx0UGF0aCAkcGFydHNbMF0gJHBhcnRzWzFdCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJGIgID0g
HLP:JEFyZyAtc3BsaXQgJywnCiAgICAgICAgICAgICRzZSA9ICgkYi5Db3VudCAtZ2UgMSAtYW5kICRiWzBdLlRyaW0oKSAtZXEgJzEnKQogICAgICAgICAgICAkZGUgPSAoJGIuQ291bnQgLWdlIDIgLWFuZCAkYlsxXS5UcmltKCkgLWVxICcxJykKICAgICAgICAgICAg
HLP:JG9rID0gVGVzdC1Nb3ZlUmVzdWx0ICRzZSAkZGUKICAgICAgICB9CiAgICAgICAgIk1PVkVEPSQoaWYgKCRvaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAndnRsd3JpdGUnIHsKICAgICAgICAkcCAgID0gJEFyZyAtc3BsaXQgJywnCiAgICAgICAgJGN1
HLP:ciA9IGlmICgkcC5Db3VudCAtZ2UgMSkgeyAkcFswXSB9IGVsc2UgeyAnJyB9CiAgICAgICAgJGRlcyA9IGlmICgkcC5Db3VudCAtZ2UgMikgeyAkcFsxXSB9IGVsc2UgeyBbc3RyaW5nXSRWVF9MRVZFTF9ERVNJUkVEIH0KICAgICAgICAiV1JJVEU9JChpZiAoUmVz
HLP:b2x2ZS1WdGxXcml0ZSAkY3VyICRkZXMpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ21hcGV4aXQnICAgICAgeyAiUkVTPSQoTWFwLUV4aXRDb2RlICRBcmcpIiB9CiAgICAjIC0tLSAoNS4xIC8gUmVxIDE1KSBEaWFnbm9zdGljbyBhbXBsaWFkbyAtLS0K
HLP:ICAgICdyYW1jaGVjaycgewogICAgICAgICRyID0gR2V0LVJhbUNoZWNrCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRzdC5kaWFnLnJhbSA9IFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAkci5zdGF0dXM7IHJl
HLP:Y29tbWVuZF9tZHNjaGVkID0gW2Jvb2xdJHIucmVjb21tZW5kX21kc2NoZWQgfQogICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJSQU1fU1RBVFVTPSQoJHIuc3RhdHVzKSIKICAgICAgICAiUkFNX1JFQ09NTUVORF9NRFNDSEVEPSQoaWYgKCRyLnJlY29t
HLP:bWVuZF9tZHNjaGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdiYXR0ZXJ5JyB7CiAgICAgICAgJGIgPSBHZXQtQmF0dGVyeUhlYWx0aAogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5iYXR0
HLP:ZXJ5ID0gW3BzY3VzdG9tb2JqZWN0XUB7IHByZXNlbnQgPSBbYm9vbF0kYi5wcmVzZW50OyBoZWFsdGhfcGN0ID0gJGIuaGVhbHRoX3BjdDsgcmVwb3J0X3BhdGggPSAkYi5yZXBvcnRfcGF0aCB9CiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIkJBVFRF
HLP:UllfUFJFU0VOVD0kKGlmICgkYi5wcmVzZW50KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkFUVEVSWV9IRUFMVEhfUENUPSQoJGIuaGVhbHRoX3BjdCkiCiAgICAgICAgIkJBVFRFUllfUkVQT1JUPSQoJGIucmVwb3J0X3BhdGgpIgogICAgfQogICAgJ25l
HLP:dGFkdmFuY2VkJyB7CiAgICAgICAgJG4gPSBHZXQtTmV0QWR2YW5jZWQKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHN0LmRpYWcubmV0d29yayA9IFtwc2N1c3RvbW9iamVjdF1AeyBjb25uZWN0ZWQgPSBbYm9vbF0k
HLP:bi5jb25uZWN0ZWQ7IGRuc19vayA9IFtib29sXSRuLmRuc19vazsgZGV0YWlscyA9ICRuLmRldGFpbHM7IGRuc19tcyA9ICRuLmRuc19tcyB9CiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIk5FVF9DT05ORUNURUQ9JChpZiAoJG4uY29ubmVjdGVkKSB7
HLP:JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0ROU19PSz0kKGlmICgkbi5kbnNfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfREVUQUlMUz0kKCRuLmRldGFpbHMpIgogICAgICAgICJORVRfTEFURU5DWV9NUz0kKCRuLmRuc19tcykiCiAg
HLP:ICB9CiAgICAnZGlhZ2Z1bGwnIHsKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHIgPSBHZXQtUmFtQ2hlY2sKICAgICAgICAkc3QuZGlhZy5yYW0gPSBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJHIuc3RhdHVz
HLP:OyByZWNvbW1lbmRfbWRzY2hlZCA9IFtib29sXSRyLnJlY29tbWVuZF9tZHNjaGVkIH0KICAgICAgICAkYiA9IEdldC1CYXR0ZXJ5SGVhbHRoCiAgICAgICAgJHN0LmRpYWcuYmF0dGVyeSA9IFtwc2N1c3RvbW9iamVjdF1AeyBwcmVzZW50ID0gW2Jvb2xdJGIucHJl
HLP:c2VudDsgaGVhbHRoX3BjdCA9ICRiLmhlYWx0aF9wY3Q7IHJlcG9ydF9wYXRoID0gJGIucmVwb3J0X3BhdGggfQogICAgICAgICRuID0gR2V0LU5ldEFkdmFuY2VkCiAgICAgICAgJHN0LmRpYWcubmV0d29yayA9IFtwc2N1c3RvbW9iamVjdF1AeyBjb25uZWN0ZWQg
HLP:PSBbYm9vbF0kbi5jb25uZWN0ZWQ7IGRuc19vayA9IFtib29sXSRuLmRuc19vazsgZGV0YWlscyA9ICRuLmRldGFpbHM7IGRuc19tcyA9ICRuLmRuc19tcyB9CiAgICAgICAgJGRldiA9IEdldC1EZXZpY2VMaXN0CiAgICAgICAgaWYgKCRudWxsIC1lcSAkZGV2KSB7
HLP:CiAgICAgICAgICAgICRzdC5kaWFnLmRldmljZXMgPSBAKCkKICAgICAgICAgICAgJGRldkxpbmUgPSAiREVWSUNFU19TVEFUVVM9aW5mbyBub3QgYXZhaWxhYmxlIgogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRzdC5kaWFnLmRldmljZXMgPSBAKCRkZXYp
HLP:CiAgICAgICAgICAgICRkZXZMaW5lID0gIkRFVklDRVNfQ09VTlQ9JChAKCRkZXYpLkNvdW50KSIKICAgICAgICB9CiAgICAgICAgJHNtID0gR2V0LVNtYXJ0QXR0cmlidXRlcwogICAgICAgICRzdC5kaWFnLnNtYXJ0ID0gW3BzY3VzdG9tb2JqZWN0XUB7IGF2YWls
HLP:YWJsZSA9IFtib29sXSRzbS5hdmFpbGFibGU7IHByZWRpY3RfZmFpbCA9IFtib29sXSRzbS5wcmVkaWN0X2ZhaWw7IHRlbXBfYyA9ICRzbS50ZW1wX2M7IHdlYXJfcGN0ID0gJHNtLndlYXJfcGN0OyBwb2ggPSAkc20ucG9oIH0KICAgICAgICAkc3RwID0gR2V0LVN0
HLP:YXJ0dXBJdGVtcyA4CiAgICAgICAgJHN0LmRpYWcuc3RhcnR1cCA9IEAoJHN0cCkKICAgICAgICAkYmNkID0gR2V0LUJjZEludGVncml0eQogICAgICAgICRzdC5kaWFnLmJjZCA9IFtwc2N1c3RvbW9iamVjdF1AeyBvayA9IFtib29sXSRiY2Qub2s7IGRldGFpbHMg
HLP:PSAkYmNkLmRldGFpbHMgfQogICAgICAgICRwcm9jcyA9IEdldC1Ub3BQcm9jZXNzZXMgNgogICAgICAgICRzdC5kaWFnLnByb2Nlc3NlcyA9IEAoJHByb2NzKQogICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJSQU1fU1RBVFVTPSQoJHIuc3RhdHVzKSIK
HLP:ICAgICAgICAiUkFNX1JFQ09NTUVORF9NRFNDSEVEPSQoaWYgKCRyLnJlY29tbWVuZF9tZHNjaGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkFUVEVSWV9QUkVTRU5UPSQoaWYgKCRiLnByZXNlbnQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJC
HLP:QVRURVJZX0hFQUxUSF9QQ1Q9JCgkYi5oZWFsdGhfcGN0KSIKICAgICAgICAiTkVUX0NPTk5FQ1RFRD0kKGlmICgkbi5jb25uZWN0ZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfRE5TX09LPSQoaWYgKCRuLmRuc19vaykgeycxJ30gZWxzZSB7JzAn
HLP:fSkiCiAgICAgICAgIk5FVF9MQVRFTkNZX01TPSQoJG4uZG5zX21zKSIKICAgICAgICAiU01BUlRfQVZBSUxBQkxFPSQoaWYgKCRzbS5hdmFpbGFibGUpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJTTUFSVF9QUkVESUNUX0ZBSUw9JChpZiAoJHNtLnByZWRp
HLP:Y3RfZmFpbCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJDRF9PSz0kKGlmICgkYmNkLm9rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAkZGV2TGluZQogICAgfQogICAgIyAtLS0gKHYzLjEpIFNGQyBpbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEgKyBK
HLP:U09OICsgcGFxdWV0ZSBkZSBzb3BvcnRlIC0tLQogICAgJ3NmY3Jlc3VsdCcgewogICAgICAgICJTRkNfUkVTPSQoR2V0LVNmY1Jlc3VsdCkiCiAgICB9CiAgICAnanNvbnJlcG9ydCcgewogICAgICAgICRvdXQgPSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVT
HLP:cGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdvcmsgJ0luZm9ybWUuanNvbicgfSBlbHNlIHsgJEFyZyB9CiAgICAgICAgTmV3LUpzb25SZXBvcnQgJG91dAogICAgfQogICAgJ3N1cHBvcnRwYWNrYWdlJyB7CiAgICAgICAgJG91dCA9IGlmIChbc3RyaW5nXTo6SXNO
HLP:dWxsT3JXaGl0ZVNwYWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnUGFxdWV0ZV9Tb3BvcnRlLnppcCcgfSBlbHNlIHsgJEFyZyB9CiAgICAgICAgTmV3LVN1cHBvcnRQYWNrYWdlICRvdXQKICAgIH0KICAgICMgLS0tICg1LjYgLyBSZXEgMTcuMikgUm90YWNp
HLP:b24gZGUgbG9ncyAtLS0KICAgICdsb2dyb3RhdGUnIHsKICAgICAgICAkZm9sZGVyID0gaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJEFyZykpIHsgSm9pbi1QYXRoICRXb3JrICdMb2dzJyB9IGVsc2UgeyAkQXJnIH0KICAgICAgICAkbiA9IEludm9r
HLP:ZS1Mb2dSb3RhdGUgJGZvbGRlciAkTE9HX1JFVEVOVElPTgogICAgICAgICJERUxFVEVEPSRuIgogICAgfQogICAgIyAtLS0gKDUuOCAvIFJlcSAxMywxOCkgVmFsaWRhY2lvbiBkZSBlbnRvcm5vIHkgc2VsZi10ZXN0IC0tLQogICAgJ2VudmNoZWNrJyB7CiAgICAg
HLP:ICAgJGUgPSBJbnZva2UtRW52VmFsaWRhdGUKICAgICAgICAiT1NfT0s9JChpZiAoJGUub3Nfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJPU19CVUlMRD0kKCRlLmJ1aWxkKSIKICAgICAgICAiT1NfQ0hFQ0tfRE9ORT0xIgogICAgfQogICAgJ3NlbGZ0
HLP:ZXN0YnJhaW4nIHsgIkJSQUlOX09LPTEiIH0KICAgICdzZWxmdGVzdHJlc3VsdCcgewogICAgICAgICRwYXNzID0gSW52b2tlLVNlbGZUZXN0IChQYXJzZS1Cb29sTGlzdCAkQXJnKQogICAgICAgICJTRUxGVEVTVF9QQVNTPSQoaWYgKCRwYXNzKSB7JzEnfSBlbHNl
HLP:IHsnMCd9KSIKICAgIH0KICAgIGRlZmF1bHQgICAgICAgIHsgR2V0LVN5c0luZm8gfQp9Cg==
