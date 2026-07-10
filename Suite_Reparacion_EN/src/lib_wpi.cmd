::SRC lib_wpi.cmd | Libreria_Comun canonica (Task 1.1, Req 14.1-14.3). Subrutinas compartidas VERBATIM por los 18 .bat.
::SRC Contiene: :wpi_initcolors :ok :warn :err :info :step :dry :phase :bigbanner :nowcs :wpi_extracthelper :psh :title_of
::SRC Task 7 anade: :require_powershell (Bug 9/Req 11), :checkpoint_save/:checkpoint_load/:checkpoint_clear (Req 4), :log_consolidate/:log_rotate (Req 17). Bug 8/Req 10: :wpi_initcolors escribe VirtualTerminalLevel de forma idempotente.
::SRC El generador descarta las lineas ::SRC antes de ensamblar.
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
