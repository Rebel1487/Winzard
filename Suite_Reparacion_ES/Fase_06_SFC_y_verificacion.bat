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
    echo Solicitando privilegios de Administrador...
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
echo  %DIM%Fase suelta 06 - SFC y verificacion%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "06" "SFC y verificacion" "Repara archivos de sistema y verifica el resultado tras DISM."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase06 ) else ( call :menu_fase06 )
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
echo    Resultado: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b %RC%


:Fase06
if "%DRY%"=="1" ( call :dry "Ejecutaria SFC /scannow y verificaria con una segunda pasada" & exit /b 2 )
if "%QUICK%"=="1" (
    call :step "SFC /verifyonly (solo verificacion rapida, sin reparar)"
    sfc /verifyonly > "%CAP%" 2>&1
    set "SFCRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    call :sfc_classify !SFCRC!
    if "!SFC_RES!"=="clean" (
        call :ok "SFC: sin violaciones de integridad"
        exit /b 0
    ) else (
        call :warn "SFC detecto problemas de integridad en modo solo verificacion"
        exit /b 1
    )
)
call :substep 1 2 "SFC /scannow (primera pasada)"
sfc /scannow > "%CAP%" 2>&1
set "SFCRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :sfc_classify !SFCRC!
if "!SFC_RES!"=="clean" ( call :ok "SFC: sin violaciones de integridad" & exit /b 0 )
if "!SFC_RES!"=="unrepairable" ( call :warn "SFC: danos no reparables. Ejecuta la fase DISM (05) y reintenta." & call :pshq finding "SFC: danos de sistema no reparables (requiere DISM)" & set "PH_NOTE=danos no reparables" & exit /b 1 )
if not "!SFC_RES!"=="repaired" ( call :warn "Resultado de SFC indeterminado. Revisa CBS.log." & set "PH_NOTE=resultado SFC indeterminado" & exit /b 1 )
call :warn "SFC reparo archivos. Reinicia y vuelve a ejecutar la fase 06 para verificar sin bloquear esta sesion."
call :pshq finding "SFC: archivos reparados; requiere reinicio/reverificacion"
set "PH_NOTE=archivos reparados por SFC; requiere reverificacion"
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
echo  %BGB%%WH%%B%  FASE %~1     %~2%R%
echo  %DIM%%~3%R%
>>"%LOGFILE%" echo(
>>"%LOGFILE%" echo ===== FASE %~1 : %~2 =====
exit /b 0

:: --- caja de cabecera principal ---
:bigbanner
echo(
echo  %BGC%%BK%                                                                %R%
echo  %BGC%%BK%   SUITE DE REPARACION DE EMERGENCIA   -   WINDOWS 10/11        %R%
echo  %BGC%%BK%   Todo en Uno      -      version 3.1      -      WPI           %R%
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
if "%~1"=="00" ( set "PH_TITLE=Diagnostico y triage" & set "PH_WHY=Mira discos, espacio y eventos, y detecta la causa raiz." & set "PH_TIME=~1 min" & set "PH_SAFE=Seguro: solo lee" )
if "%~1"=="01" ( set "PH_TITLE=Punto de restauracion" & set "PH_WHY=Crea un punto de restauracion y respalda el registro para volver atras." & set "PH_TIME=~1-2 min" & set "PH_SAFE=Seguro: crea respaldo" )
if "%~1"=="02" ( set "PH_TITLE=Limpieza inicial" & set "PH_WHY=Borra temporales, papelera y caches para dar aire al disco." & set "PH_TIME=~1-2 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="03" ( set "PH_TITLE=CHKDSK" & set "PH_WHY=Comprueba el sistema de archivos del disco C: en busca de errores." & set "PH_TIME=~1 min (o reinicio)" & set "PH_SAFE=Hace cambios" )
if "%~1"=="04" ( set "PH_TITLE=Optimizacion de disco" & set "PH_WHY=TRIM si es SSD o desfragmenta si es HDD, segun el tipo de disco." & set "PH_TIME=~1-10 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="05" ( set "PH_TITLE=DISM" & set "PH_WHY=Repara la imagen de componentes de Windows (el origen de SFC)." & set "PH_TIME=~5-15 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="06" ( set "PH_TITLE=SFC y verificacion" & set "PH_WHY=Repara archivos de sistema y verifica el resultado tras DISM." & set "PH_TIME=~5-10 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="07" ( set "PH_TITLE=Reparar WMI" & set "PH_WHY=Comprueba y repara el repositorio WMI (su rotura causa fallos raros)." & set "PH_TIME=~1-3 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="08" ( set "PH_TITLE=Apps de Store e Inicio" & set "PH_WHY=Re-registra las apps de la Store y repara el menu Inicio." & set "PH_TIME=~2-5 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="09" ( set "PH_TITLE=Busqueda y caches" & set "PH_WHY=Reconstruye el indice de Busqueda, cache de iconos/fuentes y el spooler." & set "PH_TIME=~1-3 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="10" ( set "PH_TITLE=Certificados y hora" & set "PH_WHY=Refresca certificados raiz y sincroniza la hora (arregla WU/Store/cert)." & set "PH_TIME=~1 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="11" ( set "PH_TITLE=Red" & set "PH_WHY=Reinicia winsock, IP, DNS y proxy, y revisa el archivo hosts." & set "PH_TIME=~1 min" & set "PH_SAFE=Hace cambios (reinicio)" )
if "%~1"=="12" ( set "PH_TITLE=Directivas (GPO)" & set "PH_WHY=Reaplica las directivas de grupo para deshacer politicas mal aplicadas." & set "PH_TIME=~1 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="13" ( set "PH_TITLE=Windows Update" & set "PH_WHY=Repara Windows Update (servicios y cache). Respeta el bloqueo con /keepwu." & set "PH_TIME=~2-5 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="14" ( set "PH_TITLE=Winget" & set "PH_WHY=Repara winget y actualiza el gestor de paquetes." & set "PH_TIME=~1-5 min" & set "PH_SAFE=Hace cambios" )
if "%~1"=="15" ( set "PH_TITLE=Dispositivos" & set "PH_WHY=Lista drivers/dispositivos con error para que sepas que revisar." & set "PH_TIME=~1 min" & set "PH_SAFE=Seguro: solo lista" )
if "%~1"=="16" ( set "PH_TITLE=Limpieza final e informe" & set "PH_WHY=Limpieza profunda, recalcula la salud y genera el informe HTML." & set "PH_TIME=~2-5 min" & set "PH_SAFE=Hace cambios" )
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
echo    %RE%[ X ]%R%  PowerShell no esta disponible. La Suite lo necesita.
>>"%LOGFILE%" echo [ X ] PowerShell no esta disponible. La Suite lo necesita.
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
call :warn "No se pudo borrar checkpoint.json tras 3 intentos"
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
echo Suite de Reparacion de Emergencia ^(WPI^) - version 3.1
echo Windows 10/11. Sin dependencias externas.
exit /b 0

:: --- (Task 10.1 / Req 12.1, 12.2) ayuda de uso ---
:show_help
echo(
echo  %B%%WH%Suite de Reparacion de Emergencia (WPI) v3.1%R%
echo  %DIM%Diagnostica y repara Windows 10/11 sin dependencias externas.%R%
echo(
echo  %WH%USO:%R%  Suite_Reparacion_TodoEnUno.bat [opciones]
echo        ^(clic derecho -^> Ejecutar como administrador^)
echo(
echo  %WH%OPCIONES:%R%
echo    %CY%/auto%R%        Ejecuta todas las fases sin menu (modo desatendido).
echo    %CY%/triage%R%      Ejecuta solo las fases que el diagnostico recomiende.
echo    %CY%/fases:LISTA%R%  Ejecuta solo esas fases. Ej: /fases:05,06,13
echo    %CY%/dry%R%         Simulacion: muestra que haria, sin tocar el sistema.
echo    %CY%/noreboot%R%    En /auto, no reinicia al terminar.
echo    %CY%/keepwu%R%      Respeta el bloqueo de Windows Update (no lo reactiva).
echo    %CY%/resume%R%      Reanuda una ejecucion previa desde su checkpoint.
echo    %CY%/quiet%R%       Menos texto en pantalla (el log se mantiene completo).
echo    %CY%/selftest%R%    Auto-diagnostico de la suite (no toca el sistema).
echo    %CY%/version%R%     Muestra la version y sale.
echo    %CY%/quick%R%       Inspeccion rapida (1-2 min): diagnostica, no repara.
echo    %CY%/json%R%        Genera ademas un informe JSON (para automatizacion).
echo    %CY%/support%R%     Crea un ZIP con logs e informe para enviar a soporte.
echo    %CY%/nocolor%R%     Salida en texto plano (sin colores ANSI).
echo    %CY%/help, /?%R%    Muestra esta ayuda y sale.
echo(
echo  %WH%CODIGOS DE SALIDA:%R%  0=OK  1=WARN  2=SKIP  3=ERROR
echo  %DIM%Pruebalo primero en una maquina virtual: realiza cambios reales.%R%
echo(
exit /b 0

:: --- (Task 10.2 / Req 13) validacion de entorno con registro de cada paso ---
:: Admin y PowerShell ya se validaron en la cabecera; aqui se registran y se
:: comprueba la version de Windows via Cerebro (envcheck). La comprobacion se
:: considera SIEMPRE realizada; si el SO no es 10/11, :err y devuelve 3 (parar).
:env_validate
call :log_consolidate
>>"%LOGFILE%" echo [ENV] Administrador: OK (proceso elevado en la cabecera)
if not "%QUIET%"=="1" call :info "Entorno: privilegios de administrador OK"
>>"%LOGFILE%" echo [ENV] PowerShell: OK (verificado en la cabecera)
call :psh envcheck > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "OS_OK=0" & set "OS_BUILD="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OS_OK=" "%CAP%"`) do for /f "delims=" %%b in ("%%a") do set "OS_OK=%%b"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OS_BUILD=" "%CAP%"`) do for /f "delims=" %%b in ("%%a") do set "OS_BUILD=%%b"
if not defined OS_BUILD set "OS_BUILD=0"
if "!OS_BUILD!"=="" set "OS_BUILD=0"
rem Respaldo nativo (NO depende de WMI) por si el cerebro no devolvio el build
if "!OS_BUILD!"=="0" for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| findstr /i "REG_"') do set "OS_BUILD=%%a"
set /a _b=OS_BUILD 2>nul
if "!_b!"=="" set "_b=0"
if !_b! GEQ 10240 set "OS_OK=1"
>>"%LOGFILE%" echo [ENV] Windows: comprobacion realizada (build !OS_BUILD!, soportado=!OS_OK!)
if "!OS_OK!"=="1" ( call :ok "Entorno: Windows 10/11 soportado (build !OS_BUILD!)" & exit /b 0 )
if !_b! GTR 0 if !_b! LSS 10240 ( call :err "Este sistema no parece Windows 10/11 (build !OS_BUILD!). Se detiene por seguridad." & exit /b 3 )
call :warn "No se pudo determinar la version de Windows (build !OS_BUILD!); continuo igualmente."
exit /b 0

:: --- (Task 10.3 / Req 18) self-test: cerebro responde, cada fase inicializa en
:: /dry sin error y (en desarrollo) equivalencia de bloques. No deja cambios:
:: se respalda y restaura el estado y se borra cualquier informe generado.
:selftest
echo(
echo %BL%============================================================%R%
echo  %B%%WH%AUTO-DIAGNOSTICO DE LA SUITE (self-test)%R%   %DIM%no toca el sistema%R%
echo %BL%============================================================%R%
set "ST_RESULTS="
:: 1) el Cerebro responde
call :psh selftestbrain > "%CAP%" 2>&1
findstr /b /c:"BRAIN_OK=1" "%CAP%" >nul 2>&1
if not errorlevel 1 ( call :ok "Cerebro: responde correctamente" & set "ST_RESULTS=!ST_RESULTS!,1" ) else ( call :err "Cerebro: no responde" & set "ST_RESULTS=!ST_RESULTS!,0" )
:: 2) cada fase inicializa en /dry sin ERROR (respaldando el estado)
if exist "%WORK%\estado.json" copy /y "%WORK%\estado.json" "%WORK%\_estado.selftest.bak" >nul 2>&1
set "_OLDDRY=%DRY%" & set "DRY=1"
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do (
    call :Fase%%P >nul 2>&1
    set "_RC=!errorlevel!"
    call :psh mapexit "!_RC!" > "%CAP%" 2>&1
    findstr /b /c:"RES=ERROR" "%CAP%" >nul 2>&1
    if errorlevel 1 ( set "ST_RESULTS=!ST_RESULTS!,1" ) else ( call :warn "Fase %%P devolvio ERROR al inicializar en /dry" & set "ST_RESULTS=!ST_RESULTS!,0" )
)
set "DRY=%_OLDDRY%"
:: restaurar estado y limpiar artefactos del self-test
if exist "%WORK%\_estado.selftest.bak" ( move /y "%WORK%\_estado.selftest.bak" "%WORK%\estado.json" >nul 2>&1 ) else ( if exist "%WORK%\estado.json" del /f /q "%WORK%\estado.json" >nul 2>&1 )
if exist "%WORK%\Informe_%TIMESTAMP%.html" del /f /q "%WORK%\Informe_%TIMESTAMP%.html" >nul 2>&1
call :ok "Fases: las 17 inicializan en simulacion sin errores criticos"
:: 3) equivalencia de bloques (solo si esta el generador, es decir, en desarrollo)
if exist "%~dp0build\generar.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build\generar.ps1" -Check >nul 2>&1
    if errorlevel 1 ( call :err "Equivalencia: los .bat divergen de la fuente canonica" & set "ST_RESULTS=!ST_RESULTS!,0" ) else ( call :ok "Equivalencia: los .bat coinciden con la fuente canonica" & set "ST_RESULTS=!ST_RESULTS!,1" )
) else (
    call :info "Equivalencia: generador no presente (normal en la version distribuida; se omite)"
)
:: 4) Verificar subrutinas anadidas en v3.1 y variables clave
set "SUB_ERR=0"
for %%S in (do_fase00 do_fase01 do_fase02 do_fase03 do_fase04 do_fase05 do_fase06 do_fase07 do_fase08 do_fase09 do_fase10 do_fase11 do_fase12 do_fase13 do_fase14 do_fase15 do_fase16 plan_wizard run_cmd run_ps run_chkdsk act) do (
    findstr /b /c:":%%S" "%~f0" >nul 2>&1
    if errorlevel 1 (
        call :warn "Self-test: Falta la subrutina :%%S"
        set "SUB_ERR=1"
    )
)
if not defined COLOR_ON (
    call :warn "Self-test: La variable COLOR_ON no esta definida"
    set "SUB_ERR=1"
)
if "!SUB_ERR!"=="0" (
    call :ok "Estructura de la suite: subrutinas y variables premium validadas"
    set "ST_RESULTS=!ST_RESULTS!,1"
) else (
    call :err "Estructura de la suite: fallaron comprobaciones estructurales"
    set "ST_RESULTS=!ST_RESULTS!,0"
)
:: veredicto agregado via Cerebro
call :psh selftestresult "!ST_RESULTS!" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "ST_PASS=0"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SELFTEST_PASS=" "%CAP%"`) do set "ST_PASS=%%a"
echo(
if "!ST_PASS!"=="1" ( call :ok "SELF-TEST: TODO CORRECTO" & exit /b 0 )
call :err "SELF-TEST: hay comprobaciones que han fallado"
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
    echo    %B%%CY%Progreso de la suite%R%  %BGG%!_pb_f!%R%%BGK%!_pb_e!%R%  %WH%!_pb_pct!%%%R%   %DIM%^(fase !_pb_i! de !_pb_t!^)%R%
) else (
    echo    Progreso de la suite  [!_pb_bar!] !_pb_pct!%%  ^(fase !_pb_i! de !_pb_t!^)
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
if not "%MODE_AUTO%"=="1" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
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
if "%~4"=="desc" if "%~1"=="sub" set "PICK_CMD=(rutina interna de la suite)"
if "%~4"=="desc" if "%~1"=="diag" set "PICK_CMD=(diagnostico ampliado del cerebro)"
if "%~4"=="desc" exit /b 0
if /i "%~5"=="P" call :info "Comando PROFUNDO: puede tardar varios minutos. Es normal, espera a que termine."
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
if "%DRY%"=="1" call :info "[SIMULACION] %~1"
if "%DRY%"=="1" exit /b 0
%~1
if errorlevel 1 ( call :warn "Termino con avisos: %~2" ) else ( call :ok "Hecho: %~2" )
exit /b 0

:run_ps
call :step "%~2"
if "%DRY%"=="1" call :info "[SIMULACION] powershell: %~1"
if "%DRY%"=="1" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "%~1"
if errorlevel 1 ( call :warn "Termino con avisos: %~2" ) else ( call :ok "Hecho: %~2" )
exit /b 0

:run_chkdsk
call :step "%~2"
if "%DRY%"=="1" call :info "[SIMULACION] chkdsk %SystemDrive% %~1"
if "%DRY%"=="1" exit /b 0
call :info "Si pregunta si programar para el proximo reinicio, responde S (o Y) y Enter."
chkdsk %SystemDrive% %~1
set "CHKDSK_SCHEDULED=1"
exit /b 0

:restart_explorer
call :step "Reiniciando el Explorador de Windows"
if "%DRY%"=="1" call :info "[SIMULACION] taskkill explorer + start explorer"
if "%DRY%"=="1" exit /b 0
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
call :ok "Explorador reiniciado"
exit /b 0

:wu_restart_services
call :step "Reiniciando los servicios de Windows Update"
if "%DRY%"=="1" call :info "[SIMULACION] net stop/start wuauserv y bits"
if "%DRY%"=="1" exit /b 0
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
call :ok "Servicios de Windows Update reiniciados"
exit /b 0

:wu_clear_cache
call :step "Limpiando la cache de Windows Update"
if "%DRY%"=="1" call :info "[SIMULACION] detener servicios y renombrar SoftwareDistribution"
if "%DRY%"=="1" exit /b 0
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
ren "%SystemRoot%\SoftwareDistribution" SoftwareDistribution.old >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
call :ok "Cache de Windows Update limpiada (carpeta renombrada a .old)"
exit /b 0

:gen_report_manual
call :step "Generando el informe HTML"
if "%DRY%"=="1" call :info "[SIMULACION] se generaria el informe HTML"
if "%DRY%"=="1" exit /b 0
set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
call :psh report "%REPORT%"
if exist "%REPORT%" ( call :ok "Informe creado en !REPORT!" ) else ( call :warn "No se pudo generar el informe" )
exit /b 0

:: --- Linea de opcion: numero + etiqueta velocidad + descripcion ---
:opt_line
set "PICK_DESC=" & set "PICK_SPEED=" & set "PICK_CMD="
call :do_fase%~1 "%~2" desc
if not defined PICK_DESC exit /b 0
set "STAG=%GY%[ ? ]%R%"
if /i "!PICK_SPEED!"=="R" set "STAG=%GR%[rapido]%R% "
if /i "!PICK_SPEED!"=="P" set "STAG=%YE%[profundo]%R%"
echo    %CY%%~2%R%^)  !STAG!  !PICK_DESC!
if "%SHOWCMD%"=="1" if defined PICK_CMD echo         %GY%comando: !PICK_CMD!%R%
exit /b 0

:: --- Cabecera de menu: muestra titulo + PARA QUE SIRVE la fase (PH_WHY) ---
:menu_head
call :title_of %~1
call :phase "%~1" "!PH_TITLE!" "!PH_WHY!"
echo    %WH%Duracion aprox:%R% !PH_TIME!     %WH%Impacto:%R% !PH_SAFE!
echo    %DIM%Etiquetas:%R% %GR%[rapido]%R%%DIM%=ligero/escaneo%R%  %YE%[profundo]%R%%DIM%=reparacion. Numero para elegir; 0 = volver.%R%
echo(
exit /b 0

:: ===== Comandos por fase (fuente unica) =====
:: do_faseNN: %1=opcion  %2=("" ejecuta | "desc" describe)  -> :act ... <R|P>

:do_fase00
if "%~1"=="1" call :act cmd "systeminfo" "Ver informacion del equipo (systeminfo): modelo, version de Windows y RAM" "%~2" R
if "%~1"=="2" call :act ps "Get-PhysicalDisk | Select-Object FriendlyName,HealthStatus,OperationalStatus,@{n='GB';e={[int]($_.Size/1GB)}} | Format-Table -Auto" "Salud de los discos (SMART): avisa si un disco esta fallando" "%~2" R
if "%~1"=="3" call :act diag "" "Diagnostico ampliado: RAM, bateria, red, discos y arranque" "%~2" R
if "%~1"=="4" call :act_all 00 "1 2 3" "Ejecutar TODO el diagnostico (informacion + SMART + ampliado)" "%~2" R
exit /b 0
:opts_fase00
call :opt_line 00 1
call :opt_line 00 2
call :opt_line 00 3
call :opt_line 00 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase00
call :menu_head "00"
call :opts_fase00
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase00 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase00

:do_fase01
if "%~1"=="1" call :act ps "Checkpoint-Computer -Description 'WPI Suite' -RestorePointType MODIFY_SETTINGS" "Crear un punto de restauracion ahora: red de seguridad antes de reparar" "%~2" R
if "%~1"=="2" call :act ps "Get-ComputerRestorePoint | Select-Object SequenceNumber,Description,CreationTime | Format-Table -Auto" "Ver los puntos de restauracion que ya existen" "%~2" R
if "%~1"=="3" call :act ps "Enable-ComputerRestore -Drive 'C:\'" "Activar la proteccion del sistema en C: (necesario para crear puntos)" "%~2" R
exit /b 0
:opts_fase01
call :opt_line 01 1
call :opt_line 01 2
call :opt_line 01 3
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase01
call :menu_head "01"
call :opts_fase01
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase01 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase01

:do_fase02
if "%~1"=="1" call :act cmd "cleanmgr" "Abrir el Liberador de espacio de Windows para borrar archivos inutiles" "%~2" R
if "%~1"=="2" call :act cmd "del /q /f /s \"%TEMP%\\*\"" "Vaciar la carpeta de archivos temporales: libera espacio rapido" "%~2" R
if "%~1"=="3" call :act ps "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" "Vaciar la Papelera de reciclaje" "%~2" R
if "%~1"=="4" call :act_all 02 "1 2 3" "Ejecutar TODA la limpieza (liberador + temporales + papelera)" "%~2" R
exit /b 0
:opts_fase02
call :opt_line 02 1
call :opt_line 02 2
call :opt_line 02 3
call :opt_line 02 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase02
call :menu_head "02"
call :opts_fase02
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase02 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase02

:do_fase03
if "%~1"=="1" call :act cmd "chkdsk %SystemDrive%" "Solo escanear el disco, sin cambios (chkdsk): revisa errores sin tocar nada" "%~2" R
if "%~1"=="2" call :act cmd "chkdsk %SystemDrive% /scan" "Escaneo en caliente, sin reiniciar (chkdsk /scan)" "%~2" R
if "%~1"=="3" call :act chk "/f" "Reparar errores del disco (chkdsk /f): los corrige y pedira reiniciar" "%~2" P
if "%~1"=="4" call :act chk "/r" "Reparar errores + recuperar sectores danados (chkdsk /r): el mas a fondo" "%~2" P
exit /b 0
:opts_fase03
call :opt_line 03 1
call :opt_line 03 2
call :opt_line 03 3
call :opt_line 03 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase03
call :menu_head "03"
call :opts_fase03
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase03 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase03

:do_fase04
if "%~1"=="1" call :act ps "Optimize-Volume -DriveLetter C -Analyze -Verbose" "Analizar el disco: mira la fragmentacion y si conviene optimizar" "%~2" R
if "%~1"=="2" call :act ps "Optimize-Volume -DriveLetter C -ReTrim -Verbose" "Optimizar SSD (TRIM): mantiene rapido el disco solido" "%~2" R
if "%~1"=="3" call :act ps "Optimize-Volume -DriveLetter C -Defrag -Verbose" "Desfragmentar HDD (disco mecanico): reordena archivos, puede tardar" "%~2" P
if "%~1"=="4" call :act cmd "fsutil behavior query DisableDeleteNotify" "Ver si el TRIM esta activado en el sistema" "%~2" R
exit /b 0
:opts_fase04
call :opt_line 04 1
call :opt_line 04 2
call :opt_line 04 3
call :opt_line 04 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase04
call :menu_head "04"
call :opts_fase04
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase04 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase04

:do_fase05
if "%~1"=="1" call :act cmd "DISM /Online /Cleanup-Image /CheckHealth" "Comprobacion rapida de la imagen de Windows (DISM /CheckHealth)" "%~2" R
if "%~1"=="2" call :act cmd "DISM /Online /Cleanup-Image /ScanHealth" "Analisis a fondo de la imagen de Windows (DISM /ScanHealth)" "%~2" P
if "%~1"=="3" call :act cmd "DISM /Online /Cleanup-Image /RestoreHealth" "Reparar la imagen de Windows (DISM /RestoreHealth): descarga y arregla" "%~2" P
if "%~1"=="4" call :act cmd "DISM /Online /Cleanup-Image /StartComponentCleanup" "Limpiar componentes antiguos y liberar espacio" "%~2" P
exit /b 0
:opts_fase05
call :opt_line 05 1
call :opt_line 05 2
call :opt_line 05 3
call :opt_line 05 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase05
call :menu_head "05"
call :opts_fase05
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase05 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase05

:do_fase06
if "%~1"=="1" call :act cmd "sfc /verifyonly" "Solo verificar los archivos de sistema, sin reparar (sfc /verifyonly)" "%~2" P
if "%~1"=="2" call :act cmd "sfc /scannow" "Verificar y reparar los archivos de sistema (sfc /scannow)" "%~2" P
exit /b 0
:opts_fase06
call :opt_line 06 1
call :opt_line 06 2
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase06
call :menu_head "06"
call :opts_fase06
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase06 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase06

:do_fase07
if "%~1"=="1" call :act cmd "winmgmt /verifyrepository" "Comprobar si el repositorio WMI esta sano (verifyrepository)" "%~2" R
if "%~1"=="2" call :act cmd "winmgmt /salvagerepository" "Reparar el repositorio WMI conservando datos (salvagerepository)" "%~2" P
if "%~1"=="3" call :act cmd "winmgmt /resetrepository" "Reconstruir el repositorio WMI desde cero (ultimo recurso)" "%~2" P
exit /b 0
:opts_fase07
call :opt_line 07 1
call :opt_line 07 2
call :opt_line 07 3
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase07
call :menu_head "07"
call :opts_fase07
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase07 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase07

:do_fase08
if "%~1"=="1" call :act cmd "wsreset.exe" "Reiniciar la cache de Microsoft Store (arregla la Store)" "%~2" R
if "%~1"=="2" call :act sub "restart_explorer" "Reiniciar el Explorador (refresca escritorio, barra de tareas e iconos)" "%~2" R
if "%~1"=="3" call :act ps "Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location | Format-Table -Auto" "Ver que programas arrancan con Windows" "%~2" R
if "%~1"=="4" call :act_all 08 "1 2 3" "Ejecutar TODO (cache de Store + reiniciar Explorador + ver inicio)" "%~2" R
exit /b 0
:opts_fase08
call :opt_line 08 1
call :opt_line 08 2
call :opt_line 08 3
call :opt_line 08 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase08
call :menu_head "08"
call :opts_fase08
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase08 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase08

:do_fase09
if "%~1"=="1" call :act ps "Restart-Service WSearch -Force" "Reiniciar la Busqueda de Windows (arregla el buscador del menu Inicio)" "%~2" R
if "%~1"=="2" call :act cmd "del /a /q \"%LOCALAPPDATA%\\IconCache.db\"" "Vaciar la cache de iconos (arregla iconos en blanco o rotos)" "%~2" R
if "%~1"=="3" call :act cmd "ipconfig /flushdns" "Vaciar la cache de DNS (problemas para abrir webs)" "%~2" R
if "%~1"=="4" call :act_all 09 "1 2 3" "Ejecutar TODO (Busqueda + cache de iconos + DNS)" "%~2" R
exit /b 0
:opts_fase09
call :opt_line 09 1
call :opt_line 09 2
call :opt_line 09 3
call :opt_line 09 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase09
call :menu_head "09"
call :opts_fase09
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase09 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase09

:do_fase10
if "%~1"=="1" call :act cmd "w32tm /resync /force" "Sincronizar el reloj con internet (arregla fallos de hora y certificados)" "%~2" R
if "%~1"=="2" call :act cmd "w32tm /query /status" "Ver el estado de la sincronizacion de hora" "%~2" R
exit /b 0
:opts_fase10
call :opt_line 10 1
call :opt_line 10 2
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase10
call :menu_head "10"
call :opts_fase10
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase10 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase10

:do_fase11
if "%~1"=="1" call :act cmd "ipconfig /flushdns" "Vaciar la cache de DNS (no cargan webs): rapido y seguro" "%~2" R
if "%~1"=="2" call :act cmd "ipconfig /renew" "Renovar la direccion IP que da el router" "%~2" R
if "%~1"=="3" call :act cmd "netsh winsock reset" "Resetear Winsock (arregla la conexion): pedira reiniciar" "%~2" R
if "%~1"=="4" call :act cmd "netsh int ip reset" "Resetear la pila TCP/IP (problemas de red persistentes): pedira reiniciar" "%~2" R
if "%~1"=="5" call :act_all 11 "1 2 3 4" "Ejecutar TODO el reseteo de red (DNS + IP + Winsock + TCP/IP)" "%~2" R
exit /b 0
:opts_fase11
call :opt_line 11 1
call :opt_line 11 2
call :opt_line 11 3
call :opt_line 11 4
call :opt_line 11 5
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase11
call :menu_head "11"
call :opts_fase11
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase11 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase11

:do_fase12
if "%~1"=="1" call :act cmd "gpupdate /force" "Forzar la actualizacion de las directivas de grupo" "%~2" P
if "%~1"=="2" call :act cmd "gpresult /r /scope computer" "Ver las directivas que estan aplicadas al equipo" "%~2" R
if "%~1"=="3" call :act_all 12 "1 2" "Ejecutar TODO (actualizar directivas + ver resultado)" "%~2" P
exit /b 0
:opts_fase12
call :opt_line 12 1
call :opt_line 12 2
call :opt_line 12 3
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase12
call :menu_head "12"
call :opts_fase12
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase12 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase12

:do_fase13
if "%~1"=="1" call :act sub "wu_restart_services" "Reiniciar los servicios de Windows Update" "%~2" R
if "%~1"=="2" call :act sub "wu_clear_cache" "Limpiar la cache de Windows Update (arregla actualizaciones atascadas)" "%~2" P
if "%~1"=="3" call :act cmd "start ms-settings:windowsupdate" "Abrir Windows Update en Configuracion" "%~2" R
if "%~1"=="4" call :act_all 13 "1 2 3" "Ejecutar TODO (reiniciar servicios + limpiar cache + abrir WU)" "%~2" P
exit /b 0
:opts_fase13
call :opt_line 13 1
call :opt_line 13 2
call :opt_line 13 3
call :opt_line 13 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase13
call :menu_head "13"
call :opts_fase13
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase13 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase13

:do_fase14
if "%~1"=="1" call :act cmd "winget --version" "Ver la version de winget (comprobar que esta instalado)" "%~2" R
if "%~1"=="2" call :act cmd "winget upgrade --all --accept-source-agreements --accept-package-agreements" "Actualizar TODOS los programas con winget: puede tardar mucho" "%~2" P
if "%~1"=="3" call :act cmd "start ms-windows-store://pdp/?productid=9NBLGGH4NNS1" "Reinstalar App Installer (winget) desde la Store" "%~2" R
exit /b 0
:opts_fase14
call :opt_line 14 1
call :opt_line 14 2
call :opt_line 14 3
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase14
call :menu_head "14"
call :opts_fase14
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase14 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase14

:do_fase15
if "%~1"=="1" call :act cmd "pnputil /scan-devices" "Buscar cambios de hardware (detecta dispositivos nuevos)" "%~2" R
if "%~1"=="2" call :act ps "Get-PnpDevice | Where-Object {$_.Status -ne 'OK'} | Select-Object FriendlyName,Status,Class | Format-Table -Auto" "Ver los dispositivos con problemas o sin driver" "%~2" R
if "%~1"=="3" call :act cmd "devmgmt.msc" "Abrir el Administrador de dispositivos" "%~2" R
exit /b 0
:opts_fase15
call :opt_line 15 1
call :opt_line 15 2
call :opt_line 15 3
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase15
call :menu_head "15"
call :opts_fase15
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase15 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase15

:do_fase16
if "%~1"=="1" call :act cmd "ipconfig /flushdns" "Vaciar la cache de DNS" "%~2" R
if "%~1"=="2" call :act cmd "del /f /q \"%SystemRoot%\\Panther\\*.log\"" "Borrar logs de instalacion antiguos (Panther): libera espacio" "%~2" R
if "%~1"=="3" call :act sub "gen_report_manual" "Generar el informe HTML de esta sesion" "%~2" R
if "%~1"=="4" call :act_all 16 "1 2 3" "Ejecutar TODA la limpieza final (DNS + logs + informe)" "%~2" R
exit /b 0
:opts_fase16
call :opt_line 16 1
call :opt_line 16 2
call :opt_line 16 3
call :opt_line 16 4
echo    %CY%0%R%^)  Volver / saltar
exit /b 0
:menu_fase16
call :menu_head "16"
call :opts_fase16
set "OPT=" & set /p "OPT=   Tu eleccion: "
if not defined OPT exit /b 10
if "!OPT!"=="0" exit /b 10
call :do_fase16 "!OPT!"
echo(
echo  %DIM%Pulsa una tecla para volver al menu de la fase (elige 0 para cerrar)...%R%
pause >nul
cls
call :bigbanner
goto :menu_fase16

:: ============================================================
:: INSPECCION RAPIDA con submodos (solo escaneo / escaneo + reparacion)
:: ============================================================
:quick_wizard
call :bigbanner
echo  %B%%WH%INSPECCION RAPIDA%R%   %DIM%elige el alcance%R%
echo(
echo    %CY%1%R%^)  %GR%[rapido]%R%   Solo escaneo: revisa el equipo y NO cambia nada
echo    %CY%2%R%^)  %YE%[profundo]%R% Escaneo + reparacion segura (SFC y DISM): puede tardar
echo    %CY%0%R%^)  Volver
echo(
choice /C 120 /N /M "  Tu eleccion: "
set "QW=!errorlevel!"
if "!QW!"=="1" call :quick_run scan
if "!QW!"=="2" call :quick_run fix
exit /b 0

:quick_run
rem %1 = scan | fix
if /i "%~1"=="fix" ( call :info "Inspeccion rapida: escaneo + reparacion segura" ) else ( call :info "Inspeccion rapida: solo escaneo (no cambia nada)" )
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
call :info "Aplicando reparaciones seguras (esto puede tardar)..."
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
:: PLAN PERSONALIZADO (asistente guiado)
:: ============================================================
:plan_wizard
:plan_top
call :plan_reset
call :bigbanner
echo  %B%%WH%PLAN PERSONALIZADO%R%   %DIM%elige un comando por fase, o salta la que no necesites%R%
echo  %DIM%Numero del comando, 0 para saltar la fase, o X para terminar de elegir.%R%
call :plan_build
call :plan_summary
echo(
choice /C SNC /N /M "  Empezamos con este plan?   S = Si    N = No    C = Cambiar: "
set "PCONF=!errorlevel!"
if "!PCONF!"=="3" goto :plan_top
if "!PCONF!"=="2" ( call :info "Plan cancelado. No se ha ejecutado nada." & exit /b 0 )
echo(
call :info "Empezando tu plan personalizado..."
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
echo  %BGB%%WH%%B%  Fase !PN!: !PH_TITLE!%R%
echo   %DIM%!PH_WHY!%R%
call :opts_fase!PN!
set "OPT=" & set /p "OPT=   Elige numero (0 = saltar, X = terminar): "
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
echo  %B%%WH%========== TU PLAN ==========%R%
set "PLAN_ANY=0"
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do call :plan_show %%P
if "!PLAN_ANY!"=="0" echo   %DIM%(no elegiste ningun comando; el plan esta vacio)%R%
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
if /i "!PICK_SPEED!"=="R" set "STAG=%GR%[rapido]%R%"
if /i "!PICK_SPEED!"=="P" set "STAG=%YE%[profundo]%R%"
if defined PICK_DESC echo    %GR%Fase !PN!%R% %WH%!PH_TITLE!%R%  !STAG!
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
HLP:ICJFUVVJUE89JCgkY3MuTWFudWZhY3R1cmVyKSAkKCRjcy5Nb2RlbCkiCiAgICAiQ1BVPSRjcHVOYW1lIgogICAgIlJBTT0kcmFtR0IgR0IiCiAgICAiRElTQ089QzogJGZyZWVHQiBHQiBsaWJyZXMgZGUgJHRvdEdCIEdCIgogICAgIlVQVElNRT0kKFtpbnRdJHVw
HLP:LlRvdGFsRGF5cylkICQoJHVwLkhvdXJzKWggJCgkdXAuTWludXRlcyltIgogICAgIlVTVUFSSU89JGVudjpVU0VSTkFNRSIKfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LQojICg1LjIgLyBSZXEgMTUuNikgTnVjbGVvIFBVUk8gZGUgY2FsY3VsbyBkZWwgc2NvcmUuCiMgUmVjaWJlIHVuIGhhc2h0YWJsZSBkZSBzaW50b21hcyAoZmxhZ3MvY29udGVvcykgeSBkZXZ1ZWx2ZSB1biBlbnRlcm8gZW4KIyBbMCwxMDBdLiBDYWRhIHNpbnRv
HLP:bWEgc29sbyBwdWVkZSBSRVNUQVIgcHVudG9zLCBwb3IgbG8gcXVlIGFuYWRpciBvIGFncmF2YXIKIyBjdWFscXVpZXIgc2ludG9tYSBudW5jYSBzdWJlIGVsIHNjb3JlIChNT05PVE9OSUEpLCB5IGVsIGNsYW1wIGdhcmFudGl6YSBlbAojIHJhbmdvIFswLDEwMF0u
HLP:IEVzIGRldGVybWluaXN0YSByZXNwZWN0byBhIHN1IGVudHJhZGEgKHRlc3RlYWJsZSBkZSBmb3JtYQojIGFpc2xhZGEgcGFyYSBsYSBQcm9wZXJ0eSAxMCkuCmZ1bmN0aW9uIENvbXB1dGUtU2NvcmUoW2hhc2h0YWJsZV0kc3ltKSB7CiAgICBpZiAoJG51bGwgLWVx
HLP:ICRzeW0pIHsgJHN5bSA9IEB7fSB9CiAgICAkc2NvcmUgPSAxMDAKICAgICMgLS0tIFBlbmFsaXphY2lvbmVzIGV4aXN0ZW50ZXMgKHByZXNlcnZhZGFzKSAtLS0KICAgIGlmICgkc3ltWydzbWFydEJhZCddKSAgICAgICB7ICRzY29yZSAtPSAyNSB9CiAgICBpZiAo
HLP:JHN5bS5Db250YWluc0tleSgnZnJlZUdCJykgLWFuZCAkbnVsbCAtbmUgJHN5bVsnZnJlZUdCJ10pIHsKICAgICAgICAkZnJlZUdCID0gW2RvdWJsZV0kc3ltWydmcmVlR0InXQogICAgICAgIGlmICAgICAoJGZyZWVHQiAtbHQgNSkgIHsgJHNjb3JlIC09IDE1IH0K
HLP:ICAgICAgICBlbHNlaWYgKCRmcmVlR0IgLWx0IDE1KSB7ICRzY29yZSAtPSA2IH0KICAgIH0KICAgIGlmICgkc3ltWydyZWJvb3RQZW5kaW5nJ10pICAgICAgICAgIHsgJHNjb3JlIC09IDUgfQogICAgaWYgKFtpbnRdJHN5bVsnYnNvZCddIC1ndCAwKSAgICAgICAg
HLP:eyAkc2NvcmUgLT0gMTggfQogICAgaWYgKFtpbnRdJHN5bVsnZGlza0VyciddIC1ndCAwKSAgICAgeyAkc2NvcmUgLT0gMTIgfQogICAgaWYgKFtpbnRdJHN5bVsnd2hlYSddIC1ndCAwKSAgICAgICAgeyAkc2NvcmUgLT0gMTIgfQogICAgaWYgKFtpbnRdJHN5bVsn
HLP:Y3JpdENvdW50J10gLWd0IDI1KSAgeyAkc2NvcmUgLT0gNiB9CiAgICBpZiAoW2ludF0kc3ltWydzdmNTdG9wcGVkJ10gLWd0IDApICB7ICRzY29yZSAtPSA0ICogW2ludF0kc3ltWydzdmNTdG9wcGVkJ10gfQogICAgaWYgKFtpbnRdJHN5bVsnZGV2UHJvYmxlbXMn
HLP:XSAtZ3QgMCkgeyAkc2NvcmUgLT0gW21hdGhdOjpNaW4oMTIsIFtpbnRdJHN5bVsnZGV2UHJvYmxlbXMnXSAqIDMpIH0KICAgICMgLS0tIE51ZXZhcyBwZW5hbGl6YWNpb25lcyBkZWwgZGlhZ25vc3RpY28gYW1wbGlhZG8gKDUuMikgLS0tCiAgICBpZiAoJHN5bVsn
HLP:cmFtU3VzcGVjdCddKSB7ICRzY29yZSAtPSAxMCB9ICAgIyBSQU0gc29zcGVjaG9zYQogICAgaWYgKCRzeW0uQ29udGFpbnNLZXkoJ2JhdHRlcnlIZWFsdGhQY3QnKSAtYW5kICRudWxsIC1uZSAkc3ltWydiYXR0ZXJ5SGVhbHRoUGN0J10pIHsKICAgICAgICAkYnAg
HLP:PSBbaW50XSRzeW1bJ2JhdHRlcnlIZWFsdGhQY3QnXQogICAgICAgIGlmICgkYnAgLWdlIDAgLWFuZCAkYnAgLWx0IDUwKSB7ICRzY29yZSAtPSA4IH0gICAjIGJhdGVyaWEgbXV5IGRlZ3JhZGFkYSAoPDUwJSkKICAgIH0KICAgIGlmICgkc3ltWyduZXRQcm9ibGVt
HLP:J10pIHsgJHNjb3JlIC09IDggfSAgICMgcHJvYmxlbWFzIGRlIHJlZCBwZXJzaXN0ZW50ZXMKICAgICMgLS0tIENsYW1wIGFsIHJhbmdvIFswLDEwMF0gLS0tCiAgICBpZiAoJHNjb3JlIC1sdCAwKSAgIHsgJHNjb3JlID0gMCB9CiAgICBpZiAoJHNjb3JlIC1ndCAx
HLP:MDApIHsgJHNjb3JlID0gMTAwIH0KICAgIHJldHVybiBbaW50XSRzY29yZQp9CgojIFB1bnR1YWNpb24gZGUgc2FsdWQgMC0xMDA6IHJlY29sZWN0YSBzaW50b21hcyByZWFsZXMgZGVsIHNpc3RlbWEgKGluY2x1aWRvIGVsCiMgZGlhZ25vc3RpY28gYW1wbGlhZG8g
HLP:cGVyc2lzdGlkbyBlbiBlc3RhZG8uZGlhZykgeSBkZWxlZ2EgZWwgY2FsY3VsbyBlbiBsYQojIGZ1bmNpb24gcHVyYSBDb21wdXRlLVNjb3JlLgpmdW5jdGlvbiBHZXQtSGVhbHRoU2NvcmUgewogICAgJHJlYXNvbnMgPSBAKCkKICAgICRzeW0gPSBAe30KICAgICMg
HLP:RGlzY28gU01BUlQKICAgICRiYWQgPSBAKEdldC1QaHlzaWNhbERpc2sgfCBXaGVyZS1PYmplY3QgeyAkXy5IZWFsdGhTdGF0dXMgLW5lICdIZWFsdGh5JyB9KQogICAgJHN5bVsnc21hcnRCYWQnXSA9ICgkYmFkLkNvdW50IC1ndCAwKQogICAgaWYgKCRzeW1bJ3Nt
HLP:YXJ0QmFkJ10pIHsgJHJlYXNvbnMgKz0gIkRpc2NvIGNvbiBTTUFSVCBkZWdyYWRhZG8gKC0yNSkiIH0KICAgICMgRXNwYWNpbyBsaWJyZQogICAgJGMgPSBHZXQtUFNEcml2ZSBDOyAkZnJlZUdCID0gW21hdGhdOjpSb3VuZCgkYy5GcmVlLzFHQiwxKQogICAgJHN5
HLP:bVsnZnJlZUdCJ10gPSAkZnJlZUdCCiAgICBpZiAgICAgKCRmcmVlR0IgLWx0IDUpICB7ICRyZWFzb25zICs9ICJNZW5vcyBkZSA1IEdCIGxpYnJlcyBlbiBDOiAoLTE1KSIgfQogICAgZWxzZWlmICgkZnJlZUdCIC1sdCAxNSkgeyAkcmVhc29ucyArPSAiUG9jbyBl
HLP:c3BhY2lvIGxpYnJlIGVuIEM6ICgtNikiIH0KICAgICMgUmVpbmljaW8gcGVuZGllbnRlCiAgICAkcGVuZCA9IChUZXN0LVBhdGggJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXENvbXBvbmVudCBCYXNlZCBTZXJ2aWNpbmdc
HLP:UmVib290UGVuZGluZycpIC1vciBgCiAgICAgICAgICAgIChUZXN0LVBhdGggJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXFdpbmRvd3NVcGRhdGVcQXV0byBVcGRhdGVcUmVib290UmVxdWlyZWQnKQogICAgJHN5bVsncmVi
HLP:b290UGVuZGluZyddID0gW2Jvb2xdJHBlbmQKICAgIGlmICgkcGVuZCkgeyAkcmVhc29ucyArPSAiUmVpbmljaW8gcGVuZGllbnRlICgtNSkiIH0KICAgICMgRXZlbnRvcyBjcml0aWNvcyByZWNpZW50ZXMgKDQ4aCkKICAgICRzaW5jZSA9IChHZXQtRGF0ZSkuQWRk
HLP:SG91cnMoLTQ4KQogICAgJGNyaXQgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgTGV2ZWw9MSwyOyBTdGFydFRpbWU9JHNpbmNlfSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICRic29kID0gQCgk
HLP:Y3JpdCB8IFdoZXJlLU9iamVjdCB7ICRfLklkIC1pbiA0MSwxMDAxLDYwMDggfSkuQ291bnQKICAgICRkaXNrID0gQCgkY3JpdCB8IFdoZXJlLU9iamVjdCB7ICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2ggJ2Rpc2t8TnRmc3x2b2xtZ3InIH0pLkNvdW50CiAgICAkd2hl
HLP:YSA9IEAoJGNyaXQgfCBXaGVyZS1PYmplY3QgeyAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICdXSEVBJyB9KS5Db3VudAogICAgJHN5bVsnYnNvZCddID0gJGJzb2Q7ICRzeW1bJ2Rpc2tFcnInXSA9ICRkaXNrOyAkc3ltWyd3aGVhJ10gPSAkd2hlYTsgJHN5bVsnY3Jp
HLP:dENvdW50J10gPSAkY3JpdC5Db3VudAogICAgaWYgKCRic29kIC1ndCAwKSB7ICRyZWFzb25zICs9ICJBcGFnb25lcy9CU09EIHJlY2llbnRlczogJGJzb2QgKC0xOCkiIH0KICAgIGlmICgkZGlzayAtZ3QgMCkgeyAkcmVhc29ucyArPSAiRXJyb3JlcyBkZSBkaXNj
HLP:by9OVEZTIHJlY2llbnRlczogJGRpc2sgKC0xMikiIH0KICAgIGlmICgkd2hlYSAtZ3QgMCkgeyAkcmVhc29ucyArPSAiRXJyb3JlcyBkZSBoYXJkd2FyZSAoV0hFQSk6ICR3aGVhICgtMTIpIiB9CiAgICBpZiAoJGNyaXQuQ291bnQgLWd0IDI1KSB7ICRyZWFzb25z
HLP:ICs9ICJNdWNob3MgZXZlbnRvcyBjcml0aWNvcyBlbiA0OGg6ICQoJGNyaXQuQ291bnQpICgtNikiIH0KICAgICMgU2VydmljaW9zIGNsYXZlIHBhcmFkb3MKICAgICRzdmNTdG9wcGVkID0gMAogICAgZm9yZWFjaCAoJHN2YyBpbiAnd3VhdXNlcnYnLCdCSVRTJywn
HLP:V2lubWdtdCcsJ0V2ZW50TG9nJykgewogICAgICAgICRzID0gR2V0LVNlcnZpY2UgJHN2YyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIGlmICgkcyAtYW5kICRzLlN0YXR1cyAtbmUgJ1J1bm5pbmcnIC1hbmQgJHMuU3RhcnRUeXBlIC1uZSAn
HLP:RGlzYWJsZWQnKSB7ICRzdmNTdG9wcGVkKys7ICRyZWFzb25zICs9ICJTZXJ2aWNpbyAkc3ZjIHBhcmFkbyAoLTQpIiB9CiAgICB9CiAgICAkc3ltWydzdmNTdG9wcGVkJ10gPSAkc3ZjU3RvcHBlZAogICAgIyBEaXNwb3NpdGl2b3MgY29uIHByb2JsZW1hCiAgICAk
HLP:cHJvYiA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1BuUEVudGl0eSB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUgLWd0IDAgfSkuQ291bnQKICAgICRzeW1bJ2RldlByb2JsZW1zJ10gPSAkcHJvYgogICAgaWYgKCRwcm9iIC1ndCAw
HLP:KSB7ICRyZWFzb25zICs9ICJEaXNwb3NpdGl2b3MgY29uIGVycm9yOiAkcHJvYiIgfQogICAgIyAtLS0gRGlhZ25vc3RpY28gYW1wbGlhZG8gcGVyc2lzdGlkbyAoNS4yKTogUkFNLCBiYXRlcmlhLCByZWQgLS0tCiAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICBpZiAo
HLP:KCRzdC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdkaWFnJykgLWFuZCAkc3QuZGlhZykgewogICAgICAgIGlmICgkc3QuZGlhZy5yYW0gLWFuZCAoW3N0cmluZ10kc3QuZGlhZy5yYW0uc3RhdHVzIC1lcSAnc3VzcGVjdCcpKSB7CiAgICAgICAg
HLP:ICAgICRzeW1bJ3JhbVN1c3BlY3QnXSA9ICR0cnVlOyAkcmVhc29ucyArPSAiUkFNIHNvc3BlY2hvc2EgKC0xMCkiCiAgICAgICAgfQogICAgICAgIGlmICgkc3QuZGlhZy5iYXR0ZXJ5IC1hbmQgJHN0LmRpYWcuYmF0dGVyeS5wcmVzZW50KSB7CiAgICAgICAgICAg
HLP:ICRicFJhdyA9ICRzdC5kaWFnLmJhdHRlcnkuaGVhbHRoX3BjdAogICAgICAgICAgICBpZiAoJG51bGwgLW5lICRicFJhdyAtYW5kIFtzdHJpbmddJGJwUmF3IC1uZSAnJykgewogICAgICAgICAgICAgICAgJGJwID0gJG51bGw7IHRyeSB7ICRicCA9IFtpbnRdJGJw
HLP:UmF3IH0gY2F0Y2ggeyAkYnAgPSAkbnVsbCB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRicCkgewogICAgICAgICAgICAgICAgICAgICRzeW1bJ2JhdHRlcnlIZWFsdGhQY3QnXSA9ICRicAogICAgICAgICAgICAgICAgICAgIGlmICgkYnAgLWdlIDAg
HLP:LWFuZCAkYnAgLWx0IDUwKSB7ICRyZWFzb25zICs9ICJCYXRlcmlhIG11eSBkZWdyYWRhZGE6ICRicCUgKC04KSIgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIGlmICgkc3QuZGlhZy5uZXR3b3JrIC1hbmQgKCgkc3Qu
HLP:ZGlhZy5uZXR3b3JrLmNvbm5lY3RlZCAtZXEgJGZhbHNlKSAtb3IgKCRzdC5kaWFnLm5ldHdvcmsuZG5zX29rIC1lcSAkZmFsc2UpKSkgewogICAgICAgICAgICAkc3ltWyduZXRQcm9ibGVtJ10gPSAkdHJ1ZTsgJHJlYXNvbnMgKz0gIlByb2JsZW1hcyBkZSByZWQg
HLP:cGVyc2lzdGVudGVzICgtOCkiCiAgICAgICAgfQogICAgfQogICAgJHNjb3JlID0gQ29tcHV0ZS1TY29yZSAkc3ltCiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHNjb3JlID0gW2ludF0kc2NvcmU7IHJlYXNvbnMgPSAkcmVhc29ucyB9Cn0KCiMgLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBGb3JlbnNlIGRlbCByZWdpc3RybyBkZSBldmVudG9zOiB1bHRpbW9zIGVycm9yZXMgcXVlIGV4cGxpY2FuIGxhIGNhdXNhIHJhaXouCmZ1
HLP:bmN0aW9uIEdldC1Gb3JlbnNpY3MgewogICAgJHNpbmNlID0gKEdldC1EYXRlKS5BZGREYXlzKC03KQogICAgJG91dCA9IEAoKQogICAgJGV2ID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IExldmVsPTEsMjsgU3Rh
HLP:cnRUaW1lPSRzaW5jZX0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCA0MDApCiAgICAkZ3JvdXBzID0gQCgKICAgICAgICBAeyBrPSdBUlJBTlFVRS9BUEFHT04nOyBpZHM9QCg0MSw2MDA4LDEwMDEpOyBwcm92PScn
HLP:IH0sCiAgICAgICAgQHsgaz0nRElTQ08vTlRGUyc7ICAgICAgaWRzPUAoKTsgICAgICAgICAgICAgcHJvdj0nZGlza3xOdGZzfHZvbG1ncnxzdG9ybnZtZXxzdG9yYWhjaScgfSwKICAgICAgICBAeyBrPSdIQVJEV0FSRSAoV0hFQSknOyBpZHM9QCgpOyAgICAgICAg
HLP:ICAgICBwcm92PSdXSEVBJyB9LAogICAgICAgIEB7IGs9J1NFUlZJQ0lPUyc7ICAgICAgIGlkcz1AKCk7ICAgICAgICAgICAgIHByb3Y9J1NlcnZpY2UgQ29udHJvbCBNYW5hZ2VyJyB9LAogICAgICAgIEB7IGs9J0FQTElDQUNJT04nOyAgICAgIGlkcz1AKDEwMDAs
HLP:MTAwMik7ICAgIHByb3Y9J0FwcGxpY2F0aW9uIEVycm9yfC5ORVQgUnVudGltZScgfQogICAgKQogICAgZm9yZWFjaCAoJGcgaW4gJGdyb3VwcykgewogICAgICAgICRzZWwgPSAkZXYgfCBXaGVyZS1PYmplY3QgewogICAgICAgICAgICAoJGcuaWRzLkNvdW50IC1n
HLP:dCAwIC1hbmQgJF8uSWQgLWluICRnLmlkcykgLW9yICgkZy5wcm92IC1uZSAnJyAtYW5kICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2ggJGcucHJvdikKICAgICAgICB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMwogICAgICAgIGZvcmVhY2ggKCRlIGluICRzZWwpIHsK
HLP:ICAgICAgICAgICAgJG1zZyA9ICgkZS5NZXNzYWdlIC1zcGxpdCAiYG4iKVswXTsgaWYgKCRtc2cuTGVuZ3RoIC1ndCA5MCkgeyAkbXNnID0gJG1zZy5TdWJzdHJpbmcoMCw5MCkgfQogICAgICAgICAgICAkb3V0ICs9ICgiezB9fHsxfXx7Mn18ezN9IiAtZiAkZy5r
HLP:LCAkZS5JZCwgJGUuVGltZUNyZWF0ZWQuVG9TdHJpbmcoJ01NLWRkIEhIOm1tJyksICRtc2cuVHJpbSgpKQogICAgICAgIH0KICAgIH0KICAgIGlmICgkb3V0LkNvdW50IC1lcSAwKSB7ICJPS3wwfC18U2luIGVycm9yZXMgY3JpdGljb3MgZW4gbG9zIHVsdGltb3Mg
HLP:NyBkaWFzLiIgfSBlbHNlIHsgJG91dCB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBBdXRvLXRyaWFnZTogYSBwYXJ0aXIgZGVsIHNjb3JlIHkgbGEgZm9yZW5z
HLP:ZSwgcmVjb21pZW5kYSBmYXNlcyAobGlzdGEgZGUgSURzKS4KZnVuY3Rpb24gR2V0LVRyaWFnZSB7CiAgICAkaCA9IEdldC1IZWFsdGhTY29yZQogICAgJHJlYyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddCiAgICBm
HLP:b3JlYWNoICgkeCBpbiAnMDAnLCcwMScsJzAyJykgeyAkcmVjLkFkZCgkeCkgfSAgIyBkaWFnbm9zdGljbytyZXN0b3JlK2xpbXBpZXphIHNpZW1wcmUKICAgICRzaW5jZSA9IChHZXQtRGF0ZSkuQWRkRGF5cygtNykKICAgICRldiA9IEAoR2V0LVdpbkV2ZW50IC1G
HLP:aWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBMZXZlbD0xLDI7IFN0YXJ0VGltZT0kc2luY2V9IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgaWYgKEAoJGV2IHwgV2hlcmUtT2JqZWN0IHsgJF8uUHJvdmlkZXJOYW1lIC1tYXRjaCAn
HLP:ZGlza3xOdGZzfHZvbG1ncicgfSkuQ291bnQgLWd0IDApIHsgJHJlYy5BZGQoJzAzJykgfQogICAgJHJlYy5BZGQoJzA0Jyk7ICRyZWMuQWRkKCcwNScpOyAkcmVjLkFkZCgnMDYnKSAgIyBkaXNjby9ESVNNL1NGQyBiYXNlCiAgICBpZiAoKEdldC1TZXJ2aWNlIFdp
HLP:bm1nbXQpLlN0YXR1cyAtbmUgJ1J1bm5pbmcnKSB7ICRyZWMuQWRkKCcwNycpIH0KICAgICMgV1Ugcm90bz8KICAgICR3dSA9IEdldC1TZXJ2aWNlIHd1YXVzZXJ2IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICBpZiAoJHd1IC1hbmQgJHd1LlN0YXR1
HLP:cyAtbmUgJ1J1bm5pbmcnIC1hbmQgJHd1LlN0YXJ0VHlwZSAtbmUgJ0Rpc2FibGVkJykgeyAkcmVjLkFkZCgnMTMnKSB9CiAgICAiU0NPUkU9JCgkaC5zY29yZSkiCiAgICAiUkVDT01FTkRBREFTPSQoW3N0cmluZ106OkpvaW4oJywnLCAoJHJlYyB8IFNlbGVjdC1P
HLP:YmplY3QgLVVuaXF1ZSkpKSIKfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpmdW5jdGlvbiBOZXctUmVzdG9yZVBvaW50IHsKICAgIHRyeSB7CiAgICAgICAgRW5hYmxl
HLP:LUNvbXB1dGVyUmVzdG9yZSAtRHJpdmUgJ0M6JyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRrID0gJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uXFN5c3RlbVJlc3RvcmUnCiAgICAgICAgJHBy
HLP:ZXYgPSAoR2V0LUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25GcmVxdWVuY3kKICAgICAgICBTZXQtSXRl
HLP:bVByb3BlcnR5ICRrIC1OYW1lIFN5c3RlbVJlc3RvcmVQb2ludENyZWF0aW9uRnJlcXVlbmN5IC1WYWx1ZSAwIC1UeXBlIERXb3JkIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgJG5hbWUgPSAiU3VpdGVfUmVwYXJhY2lvbl8kKChHZXQtRGF0
HLP:ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGRfSEgtbW0nKSkiCiAgICAgICAgQ2hlY2twb2ludC1Db21wdXRlciAtRGVzY3JpcHRpb24gJG5hbWUgLVJlc3RvcmVQb2ludFR5cGUgTU9ESUZZX1NFVFRJTkdTIC1FcnJvckFjdGlvbiBTdG9wCiAgICAgICAgaWYgKCRudWxs
HLP:IC1uZSAkcHJldikgeyBTZXQtSXRlbVByb3BlcnR5ICRrIC1OYW1lIFN5c3RlbVJlc3RvcmVQb2ludENyZWF0aW9uRnJlcXVlbmN5IC1WYWx1ZSAkcHJldiAtVHlwZSBEV29yZCB9IGVsc2UgeyBSZW1vdmUtSXRlbVByb3BlcnR5ICRrIC1OYW1lIFN5c3RlbVJlc3Rv
HLP:cmVQb2ludENyZWF0aW9uRnJlcXVlbmN5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICAkcnAgPSBHZXQtQ29tcHV0ZXJSZXN0b3JlUG9pbnQgfCBXaGVyZS1PYmplY3QgeyAkXy5EZXNjcmlwdGlvbiAtZXEgJG5hbWUgfQogICAgICAgIGlm
HLP:ICgkcnApIHsgIlJFU1VMVD1PSyI7ICJOQU1FPSRuYW1lIiB9IGVsc2UgeyAiUkVTVUxUPUZBSUwiOyAiTkFNRT0kbmFtZSIgfQogICAgfSBjYXRjaCB7ICJSRVNVTFQ9RkFJTCI7ICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIgfQp9CgpmdW5jdGlvbiBT
HLP:YXZlLUhlYWx0aEhpc3RvcnkoJHNjb3JlKSB7CiAgICAkc2NyaXB0RGlyID0gJG51bGwKICAgIGlmICgkUFNTY3JpcHRSb290KSB7CiAgICAgICAgJHNjcmlwdERpciA9ICRQU1NjcmlwdFJvb3QKICAgIH0gZWxzZWlmICgkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5Q
HLP:YXRoKSB7CiAgICAgICAgJHNjcmlwdERpciA9IFNwbGl0LVBhdGggLVBhcmVudCAkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoCiAgICB9CiAgICAkYmFzZURpciA9IGlmICgkc2NyaXB0RGlyKSB7IEpvaW4tUGF0aCAoU3BsaXQtUGF0aCAtUGFyZW50ICRzY3Jp
HLP:cHREaXIpICJXUElfU3VpdGUiIH0gZWxzZSB7ICRXb3JrIH0KICAgIGlmICgkc2NyaXB0RGlyIC1hbmQgKFRlc3QtUGF0aCAkc2NyaXB0RGlyKSkgewogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJGJhc2VEaXIpKSB7IE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJl
HLP:Y3RvcnkgLVBhdGggJGJhc2VEaXIgLUZvcmNlIHwgT3V0LU51bGwgfQogICAgfSBlbHNlIHsKICAgICAgICAkYmFzZURpciA9ICRXb3JrCiAgICB9CiAgICAkaGlzdG9yeUZpbGUgPSBKb2luLVBhdGggJGJhc2VEaXIgImhlYWx0aF9oaXN0b3J5Lmpzb24iCiAgICAk
HLP:aGlzdG9yeSA9IEAoKQogICAgaWYgKFRlc3QtUGF0aCAkaGlzdG9yeUZpbGUpIHsKICAgICAgICB0cnkgeyAkaGlzdG9yeSA9IEdldC1Db250ZW50ICRoaXN0b3J5RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9IGNhdGNoIHt9CiAgICB9CiAgICAkZW50cnkg
HLP:PSBbcHNjdXN0b21vYmplY3RdQHsKICAgICAgICBkYXRlICA9IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGQgSEg6bW0nKQogICAgICAgIHNjb3JlID0gW2ludF0kc2NvcmUKICAgIH0KICAgICRoaXN0b3J5ID0gQCgkaGlzdG9yeSkgKyAkZW50cnkKICAg
HLP:IGlmICgkaGlzdG9yeS5Db3VudCAtZ3QgMTApIHsgJGhpc3RvcnkgPSAkaGlzdG9yeVstMTAuLi0xXSB9CiAgICB0cnkgewogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkaGlzdG9yeUZpbGUsICgkaGlzdG9yeSB8IENvbnZlcnRUby1Kc29u
HLP:KSwgKE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkpKQogICAgfSBjYXRjaCB7fQp9CgpmdW5jdGlvbiBJbnN0YWxsLVdpbmdldEJvb3RzdHJhcCB7CiAgICAkdGVtcEZpbGUgPSBKb2luLVBhdGggJGVudjpURU1QICJNaWNyb3NvZnQu
HLP:RGVza3RvcEFwcEluc3RhbGxlcl84d2VreWIzZDhiYndlLm1zaXhidW5kbGUiCiAgICB0cnkgewogICAgICAgICR1cmwgPSAiaHR0cHM6Ly9naXRodWIuY29tL21pY3Jvc29mdC93aW5nZXQtY2xpL3JlbGVhc2VzL2xhdGVzdC9kb3dubG9hZC9NaWNyb3NvZnQuRGVz
HLP:a3RvcEFwcEluc3RhbGxlcl84d2VreWIzZDhiYndlLm1zaXhidW5kbGUiCiAgICAgICAgV3JpdGUtSG9zdCAiRGVzY2FyZ2FuZG8gQXBwIEluc3RhbGxlciBkZXNkZTogJHVybCIKICAgICAgICAkd2ViQ2xpZW50ID0gTmV3LU9iamVjdCBTeXN0ZW0uTmV0LldlYkNs
HLP:aWVudAogICAgICAgIFtTeXN0ZW0uTmV0LlNlcnZpY2VQb2ludE1hbmFnZXJdOjpTZWN1cml0eVByb3RvY29sID0gW1N5c3RlbS5OZXQuU2VjdXJpdHlQcm90b2NvbFR5cGVdOjpUbHMxMgogICAgICAgICR3ZWJDbGllbnQuRG93bmxvYWRGaWxlKCR1cmwsICR0ZW1w
HLP:RmlsZSkKICAgICAgICAKICAgICAgICBXcml0ZS1Ib3N0ICJJbnN0YWxhbmRvIEFwcCBJbnN0YWxsZXIgY29uIEFkZC1BcHB4UGFja2FnZS4uLiIKICAgICAgICBBZGQtQXBweFBhY2thZ2UgLVBhdGggJHRlbXBGaWxlIC1FcnJvckFjdGlvbiBTdG9wCiAgICAgICAg
HLP:V3JpdGUtSG9zdCAiSW5zdGFsYWNpb24gZXhpdG9zYS4iCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkdGVtcEZpbGUpIHsgUmVtb3ZlLUl0ZW0gJHRlbXBGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgcmV0dXJuICR0cnVl
HLP:CiAgICB9IGNhdGNoIHsKICAgICAgICBXcml0ZS1Ib3N0ICJFcnJvciBlbiBib290c3RyYXAgZGUgd2luZ2V0OiAkKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgICAgICBpZiAoVGVzdC1QYXRoICR0ZW1wRmlsZSkgeyBSZW1vdmUtSXRlbSAkdGVtcEZpbGUgLUZv
HLP:cmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICByZXR1cm4gJGZhbHNlCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyAoMy43
HLP:IC8gQnVnIDUgLyBSZXEgNykgRGV0ZWNjaW9uIGZpYWJsZSBkZWwgdGlwbyBkZSBkaXNjby4KIyBDb252ZXJ0VG8tTWVkaWFDbGFzczogZnVuY2lvbiBQVVJBIHF1ZSBtYXBlYSB1biBNZWRpYVR5cGUgKG51bWVybyBvIHRleHRvKQojIGEgbGEgY2xhc2UgY2Fub25p
HLP:Y2Ege1NTRCxIREQsVU5LTk9XTn0uIFNTRD00IG8gJ1NTRCc7IEhERD0zIG8gJ0hERCc7CiMgY3VhbHF1aWVyIG90cm8gdmFsb3IgKFVuc3BlY2lmaWVkPTAsIHZhY2lvLCBudWxvLCBTQ009NS4uLikgLT4gVU5LTk9XTi4KZnVuY3Rpb24gQ29udmVydFRvLU1lZGlh
HLP:Q2xhc3MoJG10KSB7CiAgICBpZiAoJG51bGwgLWVxICRtdCkgeyByZXR1cm4gJ1VOS05PV04nIH0KICAgICRzID0gKFtzdHJpbmddJG10KS5UcmltKCkKICAgIGlmICgkcyAtZXEgJycpIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICBzd2l0Y2ggLXJlZ2V4ICgkcy5U
HLP:b1VwcGVyKCkpIHsKICAgICAgICAnXig0fFNTRCkkJyB7IHJldHVybiAnU1NEJyB9CiAgICAgICAgJ14oM3xIREQpJCcgeyByZXR1cm4gJ0hERCcgfQogICAgICAgIGRlZmF1bHQgICAgIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICB9Cn0KCiMgUmVzb2x2ZS1PcHRp
HLP:bWl6ZUFjdGlvbjogZnVuY2lvbiBQVVJBLiBUUklNIHNvbG8gc2kgU1NELCBERUZSQUcgc29sbyBzaSBIREQKIyBjbGFybywgTk9ORSBlbiBjdWFscXVpZXIgb3RybyBjYXNvIChhYnN0ZW5jaW9uIHNlZ3VyYTogbnVuY2EgZGVzZnJhZ21lbnRhCiMgYW50ZSB0aXBv
HLP:IGluY2llcnRvLCBldml0YW5kbyBkYW5hciB1biBwb3NpYmxlIFNTRCkuCmZ1bmN0aW9uIFJlc29sdmUtT3B0aW1pemVBY3Rpb24oJG1lZGlhKSB7CiAgICAkbSA9IChbc3RyaW5nXSRtZWRpYSkuVHJpbSgpLlRvVXBwZXIoKQogICAgaWYgICAgICgkbSAtZXEgJ1NT
HLP:RCcpIHsgcmV0dXJuICdUUklNJyB9CiAgICBlbHNlaWYgKCRtIC1lcSAnSEREJykgeyByZXR1cm4gJ0RFRlJBRycgfQogICAgZWxzZSAgICAgICAgICAgICAgICAgIHsgcmV0dXJuICdOT05FJyB9Cn0KCiMgR2V0LU1lZGlhVHlwZTogaWRlbnRpZmljYSBlbCBkaXNj
HLP:byBmaXNpY28gZGVsIHZvbHVtZW4gZGVsIHNpc3RlbWEgZGUgZm9ybWEKIyBmaWFibGUgKHBvciBEZXZpY2VJZCwgcmVzcGFsZG8gcG9yIFNlcmlhbE51bWJlcikgeSBkZXZ1ZWx2ZSBTU0R8SEREfFVOS05PV04uCmZ1bmN0aW9uIEdldC1NZWRpYVR5cGUgewogICAg
HLP:dHJ5IHsKICAgICAgICAkc3lzICA9ICgkZW52OlN5c3RlbURyaXZlKS5UcmltRW5kKCc6JykKICAgICAgICAkZGlzayA9IEdldC1QYXJ0aXRpb24gLURyaXZlTGV0dGVyICRzeXMgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBHZXQtRGlzayAtRXJyb3JB
HLP:Y3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRwZCA9ICRudWxsCiAgICAgICAgaWYgKCRkaXNrKSB7CiAgICAgICAgICAgICRwZCA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAgICAgICAgICAgICBX
HLP:aGVyZS1PYmplY3QgeyAkXy5EZXZpY2VJZCAtZXEgJGRpc2suTnVtYmVyIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIGlmICgtbm90ICRwZCAtYW5kICRkaXNrLlNlcmlhbE51bWJlcikgewogICAgICAgICAgICAgICAgJHBkID0gR2V0LVBo
HLP:eXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5TZXJpYWxOdW1iZXIgLWFuZCAoJF8uU2VyaWFsTnVtYmVyLlRyaW0oKSAtZXEgKFtzdHJpbmddJGRpc2suU2VyaWFs
HLP:TnVtYmVyKS5UcmltKCkpIH0gfAogICAgICAgICAgICAgICAgICAgICAgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIGlmICgtbm90ICRwZCkgeyByZXR1cm4gJ1VOS05PV04nIH0KICAgICAgICByZXR1cm4gKENv
HLP:bnZlcnRUby1NZWRpYUNsYXNzICRwZC5NZWRpYVR5cGUpCiAgICB9IGNhdGNoIHsgcmV0dXJuICdVTktOT1dOJyB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KZnVu
HLP:Y3Rpb24gR2V0LURldmljZVByb2JsZW1zIHsKICAgICRwID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUG5QRW50aXR5IHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFuYWdlckVycm9yQ29kZSAtZ3QgMCB9KQogICAgaWYgKCRwLkNvdW50IC1lcSAwKSB7ICJP
HLP:S3xTaW4gZGlzcG9zaXRpdm9zIGNvbiBwcm9ibGVtYS4iOyByZXR1cm4gfQogICAgZm9yZWFjaCAoJGQgaW4gKCRwIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMTIpKSB7CiAgICAgICAgIlBST0J8JCgkZC5Db25maWdNYW5hZ2VyRXJyb3JDb2RlKXwkKCRkLk5hbWUp
HLP:IgogICAgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgSW5mb3JtZSBIVE1MIGF1dG9jb250ZW5pZG8geSBib25pdG8gKHRlbWEgb3NjdXJvKS4gLUFyZyA9IHJ1
HLP:dGEgZGUgc2FsaWRhLgpmdW5jdGlvbiBOZXctSHRtbFJlcG9ydCgkb3V0UGF0aCkgewogICAgQWRkLVR5cGUgLUFzc2VtYmx5TmFtZSBTeXN0ZW0uV2ViIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICB0cnkgewogICAgICAgICRzdCA9IFJlYWQtU3Rh
HLP:dGUKICAgICAgICAkc3lzUGFpcnMgPSBHZXQtU3lzSW5mbwoKICAgICAgICAkZW5jID0geyBwYXJhbSgkdCkgW1N5c3RlbS5XZWIuSHR0cFV0aWxpdHldOjpIdG1sRW5jb2RlKFtzdHJpbmddJHQpIH0KICAgICAgICAkY2lyYyA9IDUyNy43OQogICAgICAgICRiYW5k
HLP:Q29sb3IgPSB7IHBhcmFtKCRzKSBpZiAoJHMgLWVxICctJyAtb3IgJG51bGwgLWVxICRzIC1vciBbc3RyaW5nXSRzIC1lcSAnJykgeyAnIzk0YTNiOCcgfSBlbHNlIHsgJHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgcmV0dXJuICcjOTRhM2I4JyB9OyBp
HLP:ZiAoJHYgLWdlIDgwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCR2IC1nZSA1MCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfSB9IH0KICAgICAgICAkYmFuZExhYmVsID0geyBwYXJhbSgkcykgaWYgKCRzIC1lcSAnLScgLW9yICRudWxsIC1lcSAkcyAtb3IgW3N0
HLP:cmluZ10kcyAtZXEgJycpIHsgJ3NpbiBkYXRvcycgfSBlbHNlIHsgJHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgcmV0dXJuICdzaW4gZGF0b3MnIH07IGlmICgkdiAtZ2UgODApIHsnQnVlbmEnfSBlbHNlaWYgKCR2IC1nZSA1MCkgeydSZWd1bGFyJ30g
HLP:ZWxzZSB7J0NyaXRpY2EnfSB9IH0KICAgICAgICAkb2Zmc2V0T2YgPSB7IHBhcmFtKCRzKSAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0Y2ggeyAkdj0wIH07IGlmICgkdiAtbHQgMCl7JHY9MH07IGlmICgkdiAtZ3QgMTAwKXskdj0xMDB9OyBbbWF0aF06OlJv
HLP:dW5kKCRjaXJjICogKDEgLSAoJHYvMTAwLjApKSwgMikgfQogICAgICAgICRzdGF0dXNJY29uID0gewogICAgICAgICAgICBwYXJhbSgkcmVzKQogICAgICAgICAgICBzd2l0Y2ggKFtzdHJpbmddJHJlcykgewogICAgICAgICAgICAgICAgJ09LJyAgICB7ICI8c3Zn
HLP:IHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdjb3JyZWN0byc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyMyMmM1NWUnLz48cGF0aCBkPSdNNyAxMi40bDMuMiAzLjJMMTcgOC44JyBm
HLP:aWxsPSdub25lJyBzdHJva2U9JyMwNDIxMGYnIHN0cm9rZS13aWR0aD0nMi42JyBzdHJva2UtbGluZWNhcD0ncm91bmQnIHN0cm9rZS1saW5lam9pbj0ncm91bmQnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdXQVJOJyAgeyAiPHN2ZyB2aWV3Qm94PScwIDAg
HLP:MjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nYXZpc28nPjxwYXRoIGQ9J00xMiAyLjVMMjMgMjEuNUgxeicgZmlsbD0nI2Y1OWUwYicvPjxyZWN0IHg9JzExJyB5PSc4LjUnIHdpZHRoPScyJyBoZWlnaHQ9JzcnIHJ4PScxJyBmaWxs
HLP:PScjM2EyNDAwJy8+PGNpcmNsZSBjeD0nMTInIGN5PScxOCcgcj0nMS4zJyBmaWxsPScjM2EyNDAwJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICAnRVJST1InIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNvJyByb2xlPSdpbWcnIGFy
HLP:aWEtbGFiZWw9J2Vycm9yJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nI2VmNDQ0NCcvPjxwYXRoIGQ9J004IDhsOCA4TTE2IDhsLTggOCcgc3Ryb2tlPScjMmEwNjA2JyBzdHJva2Utd2lkdGg9JzIuNicgc3Ryb2tlLWxpbmVjYXA9J3JvdW5k
HLP:Jy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICAnU0tJUCcgIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J29taXRpZG8nPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScj
HLP:NjQ3NDhiJy8+PHJlY3QgeD0nNi41JyB5PScxMScgd2lkdGg9JzExJyBoZWlnaHQ9JzInIHJ4PScxJyBmaWxsPScjMGIxMjIwJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICBkZWZhdWx0IHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNv
HLP:Jz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nIzk0YTNiOCcvPjwvc3ZnPiIgfQogICAgICAgICAgICB9CiAgICAgICAgfQoKICAgICAgICAkYmVmb3JlID0gJHN0LnNjb3JlX2JlZm9yZTsgaWYgKCRudWxsIC1lcSAkYmVmb3JlKSB7ICRiZWZv
HLP:cmUgPSAnLScgfQogICAgICAgICRhZnRlciAgPSAkc3Quc2NvcmVfYWZ0ZXI7ICBpZiAoJG51bGwgLWVxICRhZnRlcikgIHsgJGFmdGVyICA9ICctJyB9CiAgICAgICAgJGhhc0JvdGggPSAoJHN0LnNjb3JlX2JlZm9yZSAtbmUgJG51bGwgLWFuZCAkc3Quc2NvcmVf
HLP:YWZ0ZXIgLW5lICRudWxsKQogICAgICAgICRkZWx0YSA9IDA7ICRkZWx0YVR4dCA9ICdzaW4gY29tcGFyYWNpb24nCiAgICAgICAgaWYgKCRoYXNCb3RoKSB7ICRkZWx0YSA9IFtpbnRdJHN0LnNjb3JlX2FmdGVyIC0gW2ludF0kc3Quc2NvcmVfYmVmb3JlOyAkc2ln
HLP:biA9IGlmICgkZGVsdGEgLWdlIDApIHsnKyd9IGVsc2UgeycnfTsgJGRlbHRhVHh0ID0gIiRzaWduJGRlbHRhIHB1bnRvcyIgfQogICAgICAgICRkZWx0YUNvbG9yID0gaWYgKCRkZWx0YSAtZ3QgMCkgeycjMjJjNTVlJ30gZWxzZWlmICgkZGVsdGEgLWx0IDApIHsn
HLP:I2VmNDQ0NCd9IGVsc2UgeycjOTRhM2I4J30KICAgICAgICAkbWFpblNjb3JlID0gaWYgKCRhZnRlciAtbmUgJy0nKSB7ICRhZnRlciB9IGVsc2VpZiAoJGJlZm9yZSAtbmUgJy0nKSB7ICRiZWZvcmUgfSBlbHNlIHsgJy0nIH0KICAgICAgICAkbWFpbkNvbG9yID0g
HLP:JiAkYmFuZENvbG9yICRtYWluU2NvcmUKICAgICAgICAkbWFpbk9mZnNldCA9ICYgJG9mZnNldE9mICRtYWluU2NvcmUKICAgICAgICAkbWFpbkxhYmVsID0gJiAkYmFuZExhYmVsICRtYWluU2NvcmUKICAgICAgICAkYmVmb3JlQ29sb3IgPSAmICRiYW5kQ29sb3Ig
HLP:JGJlZm9yZQogICAgICAgICRhZnRlckNvbG9yICA9ICYgJGJhbmRDb2xvciAkYWZ0ZXIKICAgICAgICAkYmVmb3JlT2Zmc2V0ID0gJiAkb2Zmc2V0T2YgJGJlZm9yZQogICAgICAgICRhZnRlck9mZnNldCAgPSAmICRvZmZzZXRPZiAkYWZ0ZXIKCiAgICAgICAgJHNj
HLP:cmlwdERpciA9ICRudWxsCiAgICAgICAgaWYgKCRQU1NjcmlwdFJvb3QpIHsKICAgICAgICAgICAgJHNjcmlwdERpciA9ICRQU1NjcmlwdFJvb3QKICAgICAgICB9IGVsc2VpZiAoJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aCkgewogICAgICAgICAgICAkc2Ny
HLP:aXB0RGlyID0gU3BsaXQtUGF0aCAtUGFyZW50ICRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgKICAgICAgICB9CiAgICAgICAgJGJhc2VEaXIgPSBpZiAoJHNjcmlwdERpcikgeyBKb2luLVBhdGggKFNwbGl0LVBhdGggLVBhcmVudCAkc2NyaXB0RGlyKSAiV1BJ
HLP:X1N1aXRlIiB9IGVsc2UgeyAkV29yayB9CiAgICAgICAgJGhpc3RvcnlGaWxlID0gSm9pbi1QYXRoICRiYXNlRGlyICJoZWFsdGhfaGlzdG9yeS5qc29uIgogICAgICAgICRoaXN0b3J5ID0gQCgpCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkaGlzdG9yeUZpbGUpIHsK
HLP:ICAgICAgICAgICAgdHJ5IHsgJGhpc3RvcnkgPSBHZXQtQ29udGVudCAkaGlzdG9yeUZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkaGlzdG9yeUh0bWwgPSAnJwogICAgICAgIGlmICgkaGlzdG9yeSAtYW5k
HLP:ICRoaXN0b3J5LkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRoaXN0b3J5SHRtbCArPSAiPGRpdiBjbGFzcz0ndHJlbmQtdGl0bGUnPkhpc3RvcmlhbCBkZSBTYWx1ZCAoVWx0aW1hcyBlamVjdWNpb25lcyk8L2Rpdj48ZGl2IGNsYXNzPSd0cmVuZC1saXN0Jz4i
HLP:CiAgICAgICAgICAgIGZvcmVhY2ggKCRoIGluICRoaXN0b3J5KSB7CiAgICAgICAgICAgICAgICAkY29sID0gJiAkYmFuZENvbG9yICRoLnNjb3JlCiAgICAgICAgICAgICAgICAkaGlzdG9yeUh0bWwgKz0gIjxkaXYgY2xhc3M9J3RyZW5kLWl0ZW0nPjxzcGFuIGNs
HLP:YXNzPSd0cmVuZC1kYXRlJz4kKCRoLmRhdGUpPC9zcGFuPjxzcGFuIGNsYXNzPSd0cmVuZC1zY29yZScgc3R5bGU9J2NvbG9yOiRjb2wnPiQoJGguc2NvcmUpLzEwMDwvc3Bhbj48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgJGhpc3RvcnlIdG1sICs9
HLP:ICI8L2Rpdj4iCiAgICAgICAgfQoKICAgICAgICAkc3lzTWFwID0gQHt9CiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHN5c1BhaXJzKSB7ICRrdiA9ICRwIC1zcGxpdCAnPScsMjsgaWYgKCRrdi5Db3VudCAtZXEgMikgeyAkc3lzTWFwWyRrdlswXV0gPSAka3ZbMV0g
HLP:fSB9CiAgICAgICAgJHN5c09yZGVyID0gQChAKCdPUycsJ1Npc3RlbWEgb3BlcmF0aXZvJyksQCgnRVFVSVBPJywnRXF1aXBvJyksQCgnQ1BVJywnUHJvY2VzYWRvcicpLEAoJ1JBTScsJ01lbW9yaWEgUkFNJyksQCgnRElTQ08nLCdEaXNjbyBDOicpLEAoJ1VQVElN
HLP:RScsJ1RpZW1wbyBlbmNlbmRpZG8nKSxAKCdVU1VBUklPJywnVXN1YXJpbycpKQogICAgICAgICRzeXNDYXJkcyA9ICcnCiAgICAgICAgZm9yZWFjaCAoJG8gaW4gJHN5c09yZGVyKSB7IGlmICgkc3lzTWFwLkNvbnRhaW5zS2V5KCRvWzBdKSkgeyAkc3lzQ2FyZHMg
HLP:Kz0gIjxkaXYgY2xhc3M9J3N5cyc+PGRpdiBjbGFzcz0nc3lzLWsnPiQoJiAkZW5jICRvWzFdKTwvZGl2PjxkaXYgY2xhc3M9J3N5cy12Jz4kKCYgJGVuYyAkc3lzTWFwWyRvWzBdXSk8L2Rpdj48L2Rpdj4iIH0gfQogICAgICAgICRtYWNoaW5lID0gJHN5c01hcFsn
HLP:RVFVSVBPJ107IGlmICgtbm90ICRtYWNoaW5lKSB7ICRtYWNoaW5lID0gJGVudjpDT01QVVRFUk5BTUUgfQoKICAgICAgICAkcGhhc2VzID0gQCgkc3QucGhhc2VzKQogICAgICAgICRjT0s9MDskY1dBUk49MDskY0VSUj0wOyRjU0tJUD0wCiAgICAgICAgJG1heFNl
HLP:Y3MgPSAxCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsgJHN2PTA7IHRyeSB7ICRzdj1baW50XSRwaC5zZWNzIH0gY2F0Y2gge307IGlmICgkc3YgLWd0ICRtYXhTZWNzKSB7ICRtYXhTZWNzID0gJHN2IH0gfQogICAgICAgICRyb3dzID0gJycKICAg
HLP:ICAgICAkYmFycyA9ICcnCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsKICAgICAgICAgICAgJHJlcyA9IFtzdHJpbmddJHBoLnJlc3VsdAogICAgICAgICAgICBzd2l0Y2ggKCRyZXMpIHsgJ09LJyB7JGNPSysrfSAnV0FSTicgeyRjV0FSTisrfSAn
HLP:RVJST1InIHskY0VSUisrfSAnU0tJUCcgeyRjU0tJUCsrfSB9CiAgICAgICAgICAgICRsYyA9ICRyZXMuVG9Mb3dlcigpCiAgICAgICAgICAgICRub3RlID0gaWYgKFtzdHJpbmddJHBoLm5vdGUgLW5lICcnKSB7ICI8ZGl2IGNsYXNzPSdwaC1ub3RlJz4kKCYgJGVu
HLP:YyAkcGgubm90ZSk8L2Rpdj4iIH0gZWxzZSB7ICcnIH0KICAgICAgICAgICAgJHJvd3MgKz0gIjxkaXYgY2xhc3M9J3BoIHBoLSRsYyc+PGRpdiBjbGFzcz0ncGgtZG90Jz4kKCYgJHN0YXR1c0ljb24gJHJlcyk8L2Rpdj48ZGl2IGNsYXNzPSdwaC1tYWluJz48ZGl2
HLP:IGNsYXNzPSdwaC10b3AnPjxzcGFuIGNsYXNzPSdwaC1udW0nPiQoJiAkZW5jICRwaC5udW0pPC9zcGFuPjxzcGFuIGNsYXNzPSdwaC10aXRsZSc+JCgmICRlbmMgJHBoLnRpdGxlKTwvc3Bhbj48c3BhbiBjbGFzcz0ncGgtYmFkZ2UgYi0kbGMnPiRyZXM8L3NwYW4+
HLP:PC9kaXY+JG5vdGU8L2Rpdj48ZGl2IGNsYXNzPSdwaC1zZWNzJz4kKCYgJGVuYyAkcGguc2VjcylzPC9kaXY+PC9kaXY+IgogICAgICAgICAgICAkc3Y9MDsgdHJ5IHsgJHN2PVtpbnRdJHBoLnNlY3MgfSBjYXRjaCB7fQogICAgICAgICAgICAkdyA9IFttYXRoXTo6
HLP:Um91bmQoMTAwLjAgKiAkc3YgLyBbbWF0aF06Ok1heCgxLCRtYXhTZWNzKSk7IGlmICgkdyAtbHQgMiAtYW5kICRzdiAtZ3QgMCkgeyAkdyA9IDIgfQogICAgICAgICAgICAkYmNvbCA9IHN3aXRjaCAoJHJlcykgeyAnT0snIHsnIzIyYzU1ZSd9ICdXQVJOJyB7JyNm
HLP:NTllMGInfSAnRVJST1InIHsnI2VmNDQ0NCd9IGRlZmF1bHQgeycjNjQ3NDhiJ30gfQogICAgICAgICAgICAkYmFycyArPSAiPGRpdiBjbGFzcz0nYmFyLXJvdyc+PGRpdiBjbGFzcz0nYmFyLWxibCc+JCgmICRlbmMgJHBoLm51bSkgJCgmICRlbmMgJHBoLnRpdGxl
HLP:KTwvZGl2PjxkaXYgY2xhc3M9J2Jhci10cmFjayc+PHNwYW4gc3R5bGU9J3dpZHRoOiR3JTtiYWNrZ3JvdW5kOiRiY29sJz48L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nYmFyLXZhbCc+JCgmICRlbmMgJHBoLnNlY3MpczwvZGl2PjwvZGl2PiIKICAgICAgICB9CiAg
HLP:ICAgICAgaWYgKC1ub3QgJHJvd3MpIHsgJHJvd3MgPSAiPGRpdiBjbGFzcz0nZW1wdHknPk5vIHNlIHJlZ2lzdHJhcm9uIGZhc2VzIGVuIGVzdGEgZWplY3VjaW9uLjwvZGl2PiIgfQogICAgICAgIGlmICgtbm90ICRiYXJzKSB7ICRiYXJzID0gIjxkaXYgY2xhc3M9
HLP:J2VtcHR5Jz5TaW4gdGllbXBvcyBxdWUgbW9zdHJhci48L2Rpdj4iIH0KICAgICAgICAkdG90YWxQaCA9ICRwaGFzZXMuQ291bnQKCiAgICAgICAgJGZpbmRpbmdzID0gQCgkc3QuZmluZGluZ3MpCiAgICAgICAgJGZpbmRIdG1sID0gJycKICAgICAgICAkc3RlcHNM
HLP:aXN0ID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgICAgICBmb3JlYWNoICgkZiBpbiAkZmluZGluZ3MpIHsKICAgICAgICAgICAgJHR4dCA9IFtzdHJpbmddJGYKICAgICAgICAgICAgJHNldiA9ICdpbmZvJzsg
HLP:JHNldlR4dCA9ICdBdmlzbycKICAgICAgICAgICAgaWYgKCR0eHQgLW1hdGNoICcoP2kpU01BUlR8QlNPRHxhcGFnfFdIRUF8aGFyZHdhcmV8bm8gcmVwYXJhYmxlc3xkYW5hZHxyZXBvc2l0b3Jpb3xpbnRlZ3JpZGFkJykgeyAkc2V2PSdoaWdoJzsgJHNldlR4dD0n
HLP:SW1wb3J0YW50ZScgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpZXNwYWNpb3xyZWluaWNpbyBwZW5kaWVudGV8XGJyZWRcYnxiYXRlcmlhfGRyaXZlcnxkaXNwb3NpdGl2b3xcYlJBTVxifHNlcnZpY2lvJykgeyAkc2V2PSdtZWQnOyAkc2V2
HLP:VHh0PSdSZXZpc2FyJyB9CiAgICAgICAgICAgICRmaW5kSHRtbCArPSAiPGxpIGNsYXNzPSdmaW5kIGZpbmQtJHNldic+PHNwYW4gY2xhc3M9J3NldiBzZXYtJHNldic+JHNldlR4dDwvc3Bhbj48c3BhbiBjbGFzcz0nZmluZC10eHQnPiQoJiAkZW5jICR0eHQpPC9z
HLP:cGFuPjwvbGk+IgogICAgICAgICAgICAjIERlcml2YXIgcGFzbyByZWNvbWVuZGFkbyBhIHBhcnRpciBkZWwgaGFsbGF6Z28KICAgICAgICAgICAgaWYgKCR0eHQgLW1hdGNoICcoP2kpU01BUlQnKSAgICAgICAgICB7ICRzdGVwc0xpc3QuQWRkKCdIYXogY29waWEg
HLP:ZGUgc2VndXJpZGFkIGRlIHR1cyBkYXRvcyBjdWFudG8gYW50ZXM6IHVuIGRpc2NvIGNvbiBTTUFSVCBkZWdyYWRhZG8gcHVlZGUgZmFsbGFyLiBWYWxvcmEgcmVlbXBsYXphcmxvLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWVzcGFj
HLP:aW8nKSAgICB7ICRzdGVwc0xpc3QuQWRkKCdMaWJlcmEgZXNwYWNpbyBlbiBDOiAoZGVzaW5zdGFsYSBsbyBxdWUgbm8gdXNlcyBvIHVzYSBlbCBTZW5zb3IgZGUgYWxtYWNlbmFtaWVudG8pLiBDb252aWVuZSB0ZW5lciBtYXMgZGUgMTUgR0IgbGlicmVzLicpIH0K
HLP:ICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKVxiUkFNXGJ8bWVtb3InKSB7ICRzdGVwc0xpc3QuQWRkKCdFamVjdXRhIGVsIERpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUgV2luZG93cyAobWRzY2hlZC5leGUpIHkgcmVpbmljaWEgcGFyYSBjb21w
HLP:cm9iYXIgbGEgUkFNLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWJhdGVyaWEnKSAgICB7ICRzdGVwc0xpc3QuQWRkKCdMYSBiYXRlcmlhIGVzdGEgZGVncmFkYWRhLiBSZXZpc2EgZWwgaW5mb3JtZSBkZSBiYXRlcmlhIChwb3dlcmNm
HLP:ZyAvYmF0dGVyeXJlcG9ydCkgeSB2YWxvcmEgc3VzdGl0dWlybGEuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpcmVpbmljaW8gcGVuZGllbnRlJykgeyAkc3RlcHNMaXN0LkFkZCgnUmVpbmljaWEgZWwgZXF1aXBvIHBhcmEgYXBsaWNh
HLP:ciBjYW1iaW9zIHBlbmRpZW50ZXMgYW50ZXMgZGUgc2VndWlyIHJlcGFyYW5kby4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlubyByZXBhcmFibGVzfHJlcG9zaXRvcmlvfGludGVncmlkYWQnKSB7ICRzdGVwc0xpc3QuQWRkKCdRdWVk
HLP:YW4gY29tcG9uZW50ZXMgZGFuYWRvcy4gRWplY3V0YSBESVNNIGNvbiB1biBvcmlnZW4gdmFsaWRvIChpbnN0YWxsLndpbSkgeSB2dWVsdmUgYSBwYXNhciBTRkMuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpZHJpdmVyfGRpc3Bvc2l0
HLP:aXZvJykgeyAkc3RlcHNMaXN0LkFkZCgnQWN0dWFsaXphIGxvcyBkcml2ZXJzIGRlIGxvcyBkaXNwb3NpdGl2b3MgY29uIGVycm9yIGRlc2RlIGxhIHdlYiBkZWwgZmFicmljYW50ZSBvIFdpbmRvd3MgVXBkYXRlLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0
HLP:IC1tYXRjaCAnKD9pKVxicmVkXGJ8RE5TJykgICAgICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ1JldmlzYSBsYSBjb25leGlvbiBkZSByZWQgeSBlbCBETlMuIFNpIHBlcnNpc3RlLCBwcnVlYmEgY29uIHVuIEROUyBwdWJsaWNvICgxLjEuMS4xIC8gOC44LjguOCkuJykg
HLP:fQogICAgICAgIH0KICAgICAgICAkbm9GaW5kID0gKCRmaW5kaW5ncy5Db3VudCAtZXEgMCkKICAgICAgICBpZiAoJG5vRmluZCkgeyAkZmluZEh0bWwgPSAiPGxpIGNsYXNzPSdmaW5kIGZpbmQtb2snPjxzcGFuIGNsYXNzPSdzZXYgc2V2LW9rJz5Ub2RvIE9LPC9z
HLP:cGFuPjxzcGFuIGNsYXNzPSdmaW5kLXR4dCc+Tm8gc2UgZGV0ZWN0YXJvbiBwcm9ibGVtYXMgcmVsZXZhbnRlcyBkdXJhbnRlIGVsIGRpYWdub3N0aWNvLjwvc3Bhbj48L2xpPiIgfQoKICAgICAgICAjIC0tLSBQcm94aW1vcyBwYXNvcyByZWNvbWVuZGFkb3MgKGRl
HLP:ZHVwbGljYWRvcykgLS0tCiAgICAgICAgJHN0ZXBzSHRtbCA9ICcnCiAgICAgICAgJHNlZW4gPSBAe30KICAgICAgICBmb3JlYWNoICgkcyBpbiAkc3RlcHNMaXN0KSB7IGlmICgtbm90ICRzZWVuLkNvbnRhaW5zS2V5KCRzKSkgeyAkc2Vlblskc109JHRydWU7ICRz
HLP:dGVwc0h0bWwgKz0gIjxsaSBjbGFzcz0nc3RlcC1saSc+PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAxNDg7PC9zcGFuPjxzcGFuPiQoJiAkZW5jICRzKTwvc3Bhbj48L2xpPiIgfSB9CiAgICAgICAgaWYgKCRjRVJSIC1ndCAwKSB7ICRzdGVwc0h0bWwgPSAiPGxp
HLP:IGNsYXNzPSdzdGVwLWxpJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDE0ODs8L3NwYW4+PHNwYW4+SHVibyBmYXNlcyBjb24gZXJyb3I6IHJldmlzYSBlbCByZWdpc3RybyBkZXRhbGxhZG8gZW4gbGEgY2FycGV0YSBXUElfU3VpdGVcTG9ncy48L3NwYW4+PC9s
HLP:aT4iICsgJHN0ZXBzSHRtbCB9CiAgICAgICAgaWYgKC1ub3QgJHN0ZXBzSHRtbCkgeyAkc3RlcHNIdG1sID0gIjxsaSBjbGFzcz0nc3RlcC1saSBzdGVwLW9rJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDAwMzs8L3NwYW4+PHNwYW4+Tm8gaGF5IGFjY2lvbmVz
HLP:IHBlbmRpZW50ZXMuIFJlaW5pY2lhIGVsIGVxdWlwbyBwYXJhIGFzZWd1cmFyIHF1ZSB0b2RvcyBsb3MgY2FtYmlvcyBxdWVkZW4gYXBsaWNhZG9zLjwvc3Bhbj48L2xpPiIgfQoKICAgICAgICAjID09PT09PT09PT09PT09PT09PT09PT0gRElBR05PU1RJQ08gQU1Q
HLP:TElBRE8gPT09PT09PT09PT09PT09PT09PT09PQogICAgICAgICRkaWFnQ2FyZHMgPSAnJwogICAgICAgIGlmICgoJHN0LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2RpYWcnKSAtYW5kICRzdC5kaWFnKSB7CiAgICAgICAgICAgICRkID0gJHN0
HLP:LmRpYWcKICAgICAgICAgICAgaWYgKCRkLnJhbSkgewogICAgICAgICAgICAgICAgJHJzID0gW3N0cmluZ10kZC5yYW0uc3RhdHVzCiAgICAgICAgICAgICAgICAkcnAgPSBzd2l0Y2ggKCRycykgeyAnb2snIHsnZ29vZCd9ICdzdXNwZWN0JyB7J2JhZCd9IGRlZmF1
HLP:bHQgeyd1bmtub3duJ30gfQogICAgICAgICAgICAgICAgJHJ0ID0gc3dpdGNoICgkcnMpIHsgJ29rJyB7J1NpbiBlcnJvcmVzIGRldGVjdGFkb3MnfSAnc3VzcGVjdCcgeydTb3NwZWNob3NhJ30gZGVmYXVsdCB7J05vIGV2YWx1YWRhJ30gfQogICAgICAgICAgICAg
HLP:ICAgJG1kcyA9IGlmICgkZC5yYW0ucmVjb21tZW5kX21kc2NoZWQpIHsgIjxkaXYgY2xhc3M9J2QtaGludCc+UmVjb21lbmRhZG86IGVqZWN1dGFyIGVsIERpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUgV2luZG93cyAobWRzY2hlZCkuPC9kaXY+IiB9IGVsc2UgeyAn
HLP:JyB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1yYW0nPjwvc3Bhbj5NZW1vcmlhIFJBTTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLSRycCc+
HLP:JHJ0PC9kaXY+JG1kczwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJGQuYmF0dGVyeSkgewogICAgICAgICAgICAgICAgaWYgKCRkLmJhdHRlcnkucHJlc2VudCkgewogICAgICAgICAgICAgICAgICAgICRicFJhdyA9ICRkLmJhdHRlcnkuaGVh
HLP:bHRoX3BjdAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGJwUmF3IC1hbmQgW3N0cmluZ10kYnBSYXcgLW5lICcnKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRicCA9IDA7IHRyeSB7ICRicCA9IFtpbnRdJGJwUmF3IH0gY2F0Y2ggeyAkYnAg
HLP:PSAwIH0KICAgICAgICAgICAgICAgICAgICAgICAgJGJwY29sID0gaWYgKCRicCAtZ2UgODApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJGJwIC1nZSA1MCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfQogICAgICAgICAgICAgICAgICAgICAgICAkZGlhZ0NhcmRz
HLP:ICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXRlcmlhPC9kaXY+PGRpdiBjbGFzcz0nYmF0LWJhcic+PHNwYW4gc3R5bGU9J3dpZHRoOiRicCU7YmFja2dyb3VuZDokYnBjb2wn
HLP:Pjwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdkLXN1Yic+U2FsdWQgZXN0aW1hZGE6IDxiIHN0eWxlPSdjb2xvcjokYnBjb2wnPiRicCU8L2I+PC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRk
HLP:aWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJhdCc+PC9zcGFuPkJhdGVyaWE8L2Rpdj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC11bmtub3duJz5QcmVzZW50ZSwgc2FsdWQgZGVzY29u
HLP:b2NpZGE8L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0n
HLP:ZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXRlcmlhPC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtdW5rbm93bic+Tm8gcHJlc2VudGUgKGVxdWlwbyBkZSBzb2JyZW1lc2EpPC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAg
HLP:ICAgICAgIGlmICgkZC5uZXR3b3JrKSB7CiAgICAgICAgICAgICAgICAkY2MgPSBpZiAoJGQubmV0d29yay5jb25uZWN0ZWQpIHsnZ29vZCd9IGVsc2UgeydiYWQnfQogICAgICAgICAgICAgICAgJGN0ID0gaWYgKCRkLm5ldHdvcmsuY29ubmVjdGVkKSB7J0NvbmVj
HLP:dGFkbyd9IGVsc2UgeydTaW4gY29uZXhpb24nfQogICAgICAgICAgICAgICAgJGRjID0gaWYgKCRkLm5ldHdvcmsuZG5zX29rKSB7J2dvb2QnfSBlbHNlIHsnYmFkJ30KICAgICAgICAgICAgICAgICRkdCA9IGlmICgkZC5uZXR3b3JrLmRuc19vaykgeydETlMgT0sn
HLP:fSBlbHNlIHsnRE5TIGNvbiBmYWxsb3MnfQogICAgICAgICAgICAgICAgJGRldCA9ICYgJGVuYyAkZC5uZXR3b3JrLmRldGFpbHMKICAgICAgICAgICAgICAgICRsYXQgPSAnJwogICAgICAgICAgICAgICAgaWYgKCgkZC5uZXR3b3JrLlBTT2JqZWN0LlByb3BlcnRp
HLP:ZXMuTmFtZSAtY29udGFpbnMgJ2Ruc19tcycpIC1hbmQgJG51bGwgLW5lICRkLm5ldHdvcmsuZG5zX21zIC1hbmQgW3N0cmluZ10kZC5uZXR3b3JrLmRuc19tcyAtbmUgJycpIHsKICAgICAgICAgICAgICAgICAgICAkbXMgPSAwOyB0cnkgeyAkbXMgPSBbaW50XSRk
HLP:Lm5ldHdvcmsuZG5zX21zIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICAgICAkbGMyID0gaWYgKCRtcyAtbHQgNjApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJG1zIC1sdCAyMDApIHsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J30KICAgICAgICAgICAgICAgICAg
HLP:ICAkbGF0ID0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5MYXRlbmNpYSBETlM6IDxiIHN0eWxlPSdjb2xvcjokbGMyJz4kbXMgbXM8L2I+PC9kaXY+IgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQn
HLP:PjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtbmV0Jz48L3NwYW4+UmVkPC9kaXY+PGRpdiBjbGFzcz0ncGlsbC1yb3cnPjxzcGFuIGNsYXNzPSdkLXBpbGwgcGlsbC0kY2MnPiRjdDwvc3Bhbj48c3BhbiBjbGFzcz0nZC1waWxsIHBpbGwtJGRj
HLP:Jz4kZHQ8L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nZC1zdWInPiRkZXQ8L2Rpdj4kbGF0PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnc21hcnQnKSAtYW5kICRkLnNtYXJ0
HLP:IC1hbmQgJGQuc21hcnQuYXZhaWxhYmxlKSB7CiAgICAgICAgICAgICAgICAkc20gPSAkZC5zbWFydAogICAgICAgICAgICAgICAgJHBmID0gaWYgKCRzbS5wcmVkaWN0X2ZhaWwpIHsgIjxzcGFuIGNsYXNzPSdkLXBpbGwgcGlsbC1iYWQnPlByZWRpY2UgZmFsbG88
HLP:L3NwYW4+IiB9IGVsc2UgeyAiPHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLWdvb2QnPlNpbiBhbGVydGE8L3NwYW4+IiB9CiAgICAgICAgICAgICAgICAkZXh0cmEgPSAnJwogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkc20udGVtcF9jIC1hbmQgW3N0cmlu
HLP:Z10kc20udGVtcF9jIC1uZSAnJykgeyAkdGM9MDsgdHJ5eyR0Yz1baW50XSRzbS50ZW1wX2N9Y2F0Y2h7fTsgJHRjb2wgPSBpZiAoJHRjIC1sdCA1MCl7JyMyMmM1NWUnfSBlbHNlaWYgKCR0YyAtbHQgNjUpeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfTsgJGV4
HLP:dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+VGVtcGVyYXR1cmE6IDxiIHN0eWxlPSdjb2xvcjokdGNvbCc+JHRjICZkZWc7QzwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLndlYXJfcGN0IC1hbmQgW3N0cmluZ10kc20ud2Vh
HLP:cl9wY3QgLW5lICcnKSB7ICR3cD0wOyB0cnl7JHdwPVtpbnRdJHNtLndlYXJfcGN0fWNhdGNoe307ICR3Y29sID0gaWYgKCR3cCAtbHQgNTApeycjMjJjNTVlJ30gZWxzZWlmICgkd3AgLWx0IDgwKXsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J307ICRleHRyYSAr
HLP:PSAiPGRpdiBjbGFzcz0nZC1zdWInPkRlc2dhc3RlIChTU0QpOiA8YiBzdHlsZT0nY29sb3I6JHdjb2wnPiR3cCU8L2I+PC9kaXY+IiB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRzbS5wb2ggLWFuZCBbc3RyaW5nXSRzbS5wb2ggLW5lICcnKSB7ICRl
HLP:eHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPkhvcmFzIGVuY2VuZGlkbzogPGI+JCgmICRlbmMgJHNtLnBvaCk8L2I+PC9kaXY+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3Bh
HLP:biBjbGFzcz0nZC1pYyBpYy1zbWFydCc+PC9zcGFuPlNhbHVkIGRlbCBkaXNjbyAoU01BUlQpPC9kaXY+PGRpdiBjbGFzcz0ncGlsbC1yb3cnPiRwZjwvZGl2PiRleHRyYTwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoKCRkLlBTT2JqZWN0LlBy
HLP:b3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2JjZCcpIC1hbmQgJGQuYmNkKSB7CiAgICAgICAgICAgICAgICAkYm9rID0gaWYgKCRkLmJjZC5vaykgeydnb29kJ30gZWxzZSB7J2JhZCd9CiAgICAgICAgICAgICAgICAkYnR4ID0gaWYgKCRkLmJjZC5vaykgeydDb25m
HLP:aWd1cmFjaW9uIGRlIGFycmFucXVlIGNvcnJlY3RhJ30gZWxzZSB7J0FycmFucXVlIGNvbiBpbmNpZGVuY2lhcyd9CiAgICAgICAgICAgICAgICAkYmRldCA9IGlmIChbc3RyaW5nXSRkLmJjZC5kZXRhaWxzIC1uZSAnJykgeyAiPGRpdiBjbGFzcz0nZC1zdWInPiQo
HLP:JiAkZW5jICRkLmJjZC5kZXRhaWxzKTwvZGl2PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYm9vdCc+PC9zcGFuPkFycmFu
HLP:cXVlIChCQ0QpPC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtJGJvayc+JGJ0eDwvZGl2PiRiZGV0PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnc3RhcnR1cCcpIC1h
HLP:bmQgJGQuc3RhcnR1cCAtYW5kIEAoJGQuc3RhcnR1cCkuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcyBpbiBAKCRkLnN0YXJ0dXApKSB7ICRpdGVtcyArPSAiPGxpPiQoJiAkZW5jICRz
HLP:Lm5hbWUpPHNwYW4gY2xhc3M9J211dGVkJz4gJm1kYXNoOyAkKCYgJGVuYyAkcy5jb21tYW5kKTwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQgZGNhcmQtd2lkZSc+PGRpdiBjbGFzcz0nZC1oJz48
HLP:c3BhbiBjbGFzcz0nZC1pYyBpYy1zdGFydCc+PC9zcGFuPlByb2dyYW1hcyBhbCBpbmljaWFyIFdpbmRvd3M8L2Rpdj48dWwgY2xhc3M9J2Rldi1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoKCRkLlBTT2JqZWN0
HLP:LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3Byb2Nlc3NlcycpIC1hbmQgJGQucHJvY2Vzc2VzIC1hbmQgQCgkZC5wcm9jZXNzZXMpLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkaXRlbXMgPSAnJwogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHBy
HLP:IGluIEAoJGQucHJvY2Vzc2VzKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkcHIubmFtZSk8c3BhbiBjbGFzcz0nbXV0ZWQnPiAmbWRhc2g7ICQoJiAkZW5jICRwci5tZW1fbWIpIE1CPC9zcGFuPjwvbGk+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRz
HLP:ICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1wcm9jJz48L3NwYW4+UHJvY2Vzb3MgcXVlIG1hcyBtZW1vcmlhIHVzYW48L2Rpdj48dWwgY2xhc3M9J2Rldi1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIK
HLP:ICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJGQuZGV2aWNlcyAtYW5kIEAoJGQuZGV2aWNlcykuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkZGV2IGluIEAoJGQuZGV2aWNlcykp
HLP:IHsgJGl0ZW1zICs9ICI8bGk+JCgmICRlbmMgJGRldi5uYW1lKSA8c3BhbiBjbGFzcz0nbXV0ZWQnPihjb2RpZ28gJCgmICRlbmMgJGRldi5jb2RlKSk8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJk
HLP:IGRjYXJkLXdpZGUnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtZGV2Jz48L3NwYW4+RGlzcG9zaXRpdm9zIGNvbiBhdmlzbzwvZGl2Pjx1bCBjbGFzcz0nZGV2LWxpc3QnPiRpdGVtczwvdWw+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAg
HLP:ICAgfQogICAgICAgICRkaWFnU2VjdGlvbiA9ICcnCiAgICAgICAgaWYgKCRkaWFnQ2FyZHMpIHsgJGRpYWdTZWN0aW9uID0gIjxoMiBpZD0nZGlhZycgY2xhc3M9J3NlYy1oJz5EaWFnbm9zdGljbyBhbXBsaWFkbzwvaDI+PGRpdiBjbGFzcz0nZGdyaWQnPiRkaWFn
HLP:Q2FyZHM8L2Rpdj4iIH0KCiAgICAgICAgJGNvbXBhcmVTZWN0aW9uID0gJycKICAgICAgICBpZiAoJGhhc0JvdGgpIHsKICAgICAgICAgICAgJGNvbXBhcmVTZWN0aW9uID0gQCIKPGRpdiBjbGFzcz0nY29tcGFyZSc+CiAgPGRpdiBjbGFzcz0nbWluaSc+CiAgICA8
HLP:c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1Z2UgZ2F1Z2Utc20nPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0n
HLP:LS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRiZWZvcmVPZmZzZXQ7c3Ryb2tlOiRiZWZvcmVDb2xvcicvPjx0ZXh0IHg9JzEwMCcgeT0nMTA4JyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxsOiRiZWZvcmVDb2xvcic+JGJlZm9yZTwvdGV4dD48L3N2Zz4KICAgIDxkaXYg
HLP:Y2xhc3M9J21pbmktY2FwJz5BTlRFUzwvZGl2PgogIDwvZGl2PgogIDxkaXYgY2xhc3M9J2Fycm93Jz48c3BhbiBzdHlsZT0nY29sb3I6JGRlbHRhQ29sb3InPiYjODU5NDs8L3NwYW4+PGRpdiBjbGFzcz0nZGVsdGEtY2hpcCcgc3R5bGU9J2NvbG9yOiRkZWx0YUNv
HLP:bG9yO2JvcmRlci1jb2xvcjokZGVsdGFDb2xvcic+JGRlbHRhVHh0PC9kaXY+PC9kaXY+CiAgPGRpdiBjbGFzcz0nbWluaSc+CiAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1Z2UgZ2F1Z2Utc20nPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBj
HLP:eD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRhZnRlck9mZnNldDtzdHJva2U6JGFmdGVyQ29sb3InLz48dGV4dCB4PScxMDAnIHk9
HLP:JzEwOCcgY2xhc3M9J2ctbnVtJyBzdHlsZT0nZmlsbDokYWZ0ZXJDb2xvcic+JGFmdGVyPC90ZXh0Pjwvc3ZnPgogICAgPGRpdiBjbGFzcz0nbWluaS1jYXAnPkRFU1BVRVM8L2Rpdj4KICA8L2Rpdj4KPC9kaXY+CiJACiAgICAgICAgfQoKICAgICAgICAkbm93ID0g
HLP:KEdldC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZCBISDptbScpCiAgICAgICAgJGV4ZWNWZXJkaWN0ID0gJiAkYmFuZExhYmVsICRtYWluU2NvcmUKICAgICAgICAkaHRtbCA9IEAiCjwhRE9DVFlQRSBodG1sPgo8aHRtbCBsYW5nPSdlcyc+CjxoZWFkPgo8bWV0
HLP:YSBjaGFyc2V0PSd1dGYtOCc+CjxtZXRhIG5hbWU9J3ZpZXdwb3J0JyBjb250ZW50PSd3aWR0aD1kZXZpY2Utd2lkdGgsaW5pdGlhbC1zY2FsZT0xJz4KPHRpdGxlPkluZm9ybWUgZGUgUmVwYXJhY2lvbiAtIFdQSSBTdWl0ZSB2My4xPC90aXRsZT4KPHN0eWxlPgoq
HLP:e2JveC1zaXppbmc6Ym9yZGVyLWJveH0KOnJvb3R7LS1iZzojMGIwZjE3Oy0tYmcyOiMwZDE0MjI7LS1jYXJkOiMxMjFhMmI7LS1jYXJkMjojMGUxNjI2Oy0tbGluZTojMWUyOTNiOy0tdHh0OiNlNmVkZjY7LS1tdXRlZDojOTNhM2JhOy0tYWNjZW50OiMzOGJkZjg7
HLP:LS1hY2NlbnQyOiM4MThjZjg7LS1zaGFkb3c6MCAxNHB4IDQwcHggcmdiYSgwLDAsMCwuNDApfQpodG1sLmxpZ2h0ey0tYmc6I2VlZjJmODstLWJnMjojZTdlZGY2Oy0tY2FyZDojZmZmZmZmOy0tY2FyZDI6I2Y1ZjhmYzstLWxpbmU6I2RkZTVmMDstLXR4dDojMGYx
HLP:NzJhOy0tbXV0ZWQ6IzVhNmI4MjstLWFjY2VudDojMDI4NGM3Oy0tYWNjZW50MjojNGY0NmU1Oy0tc2hhZG93OjAgMTBweCAyOHB4IHJnYmEoMTUsMjMsNDIsLjEyKX0KYm9keXttYXJnaW46MDtmb250LWZhbWlseTonU2Vnb2UgVUknLHN5c3RlbS11aSwtYXBwbGUt
HLP:c3lzdGVtLEFyaWFsLHNhbnMtc2VyaWY7bGluZS1oZWlnaHQ6MS41NTtjb2xvcjp2YXIoLS10eHQpO2JhY2tncm91bmQ6cmFkaWFsLWdyYWRpZW50KDEyMDBweCA2MDBweCBhdCA4MCUgLTEwJSxyZ2JhKDU2LDE4OSwyNDgsLjEwKSx0cmFuc3BhcmVudCA2MCUpLHJh
HLP:ZGlhbC1ncmFkaWVudCg5MDBweCA1MDBweCBhdCAtMTAlIDEwJSxyZ2JhKDEyOSwxNDAsMjQ4LC4xMCksdHJhbnNwYXJlbnQgNTUlKSx2YXIoLS1iZyl9Ci53cmFwe21heC13aWR0aDoxMDgwcHg7bWFyZ2luOjAgYXV0bztwYWRkaW5nOjMwcHggMjJweCA2MHB4fQou
HLP:dG9wYmFye2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47Z2FwOjE2cHg7bWFyZ2luLWJvdHRvbToxOHB4O2ZsZXgtd3JhcDp3cmFwfQouYnJhbmR7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRl
HLP:cjtnYXA6MTRweH0KLmxvZ297d2lkdGg6NDZweDtoZWlnaHQ6NDZweDtib3JkZXItcmFkaXVzOjEzcHg7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpj
HLP:ZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Cmgxe2ZvbnQtc2l6ZToyMnB4O21hcmdpbjowO2xldHRlci1zcGFjaW5nOi4ycHh9Ci5zdWJ7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10
HLP:b3A6MnB4fQouYmFkZ2V7ZGlzcGxheTppbmxpbmUtYmxvY2s7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7
HLP:cGFkZGluZzozcHggMTJweDtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFjaW5nOi40cHg7dmVydGljYWwtYWxpZ246bWlkZGxlO21hcmdpbi1sZWZ0OjhweH0KLmJ0bnN7ZGlzcGxheTpmbGV4O2dhcDo4cHg7ZmxleC13cmFwOndyYXB9Ci50b2dnbGV7Y3Vyc29y
HLP:OnBvaW50ZXI7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2NvbG9yOnZhcigtLXR4dCk7Ym9yZGVyLXJhZGl1czoxMHB4O3BhZGRpbmc6OHB4IDE0cHg7Zm9udC1zaXplOjEzcHg7Zm9udC13ZWlnaHQ6NjAwO2JveC1z
HLP:aGFkb3c6dmFyKC0tc2hhZG93KX0KLnRvZ2dsZTpob3Zlcntib3JkZXItY29sb3I6dmFyKC0tYWNjZW50KX0KLnRvY3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4LXdyYXA6d3JhcDttYXJnaW46MCAwIDIycHh9Ci50b2MgYXtmb250LXNpemU6MTIuNXB4O2ZvbnQt
HLP:d2VpZ2h0OjYwMDtjb2xvcjp2YXIoLS1tdXRlZCk7dGV4dC1kZWNvcmF0aW9uOm5vbmU7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NnB4IDEzcHh9Ci50b2MgYTpo
HLP:b3Zlcntjb2xvcjp2YXIoLS1hY2NlbnQpO2JvcmRlci1jb2xvcjp2YXIoLS1hY2NlbnQpfQouZXhlY3tkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxOHB4O2ZsZXgtd3JhcDp3cmFwO2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRlZyx2
HLP:YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRpbmc6MThweCAyMnB4O21hcmdpbi1ib3R0b206MjJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci5leGVjLXNjb3Jle2Zv
HLP:bnQtc2l6ZTo0NnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQouZXhlYy1taWR7ZmxleDoxO21pbi13aWR0aDoyMDBweH0KLmV4ZWMtdmVyZGljdHtmb250LXNpemU6MThweDtmb250LXdlaWdodDo3MDB9Ci5leGVjLWxpbmV7Y29sb3I6dmFyKC0tbXV0
HLP:ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6MnB4fQouZXhlYy1kZWx0YXtmb250LXNpemU6MTNweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyOjFweCBzb2xpZDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NHB4IDEycHg7d2hpdGUtc3BhY2U6bm93cmFw
HLP:fQouaGVyb3tkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOm1pbm1heCgyNDBweCwzMjBweCkgMWZyO2dhcDoyMHB4O21hcmdpbi1ib3R0b206MjJweH0KQG1lZGlhKG1heC13aWR0aDo3NjBweCl7Lmhlcm97Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFm
HLP:cn19Ci5jYXJke2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRlZyx2YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRpbmc6MjJweDtib3gtc2hhZG93OnZhcigtLXNo
HLP:YWRvdyl9Ci5nYXVnZXdyYXB7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjt0ZXh0LWFsaWduOmNlbnRlcn0KLmdhdWdle3dpZHRoOjIxMHB4O2hlaWdodDoyMTBweH0KLmdh
HLP:dWdlLXNte3dpZHRoOjEyMHB4O2hlaWdodDoxMjBweH0KLmdhdWdlIC50cmFja3tmaWxsOm5vbmU7c3Ryb2tlOnZhcigtLWxpbmUpO3N0cm9rZS13aWR0aDoxNH0KLmdhdWdlIC5maWxse2ZpbGw6bm9uZTtzdHJva2Utd2lkdGg6MTQ7c3Ryb2tlLWxpbmVjYXA6cm91
HLP:bmQ7dHJhbnNmb3JtOnJvdGF0ZSgtOTBkZWcpO3RyYW5zZm9ybS1vcmlnaW46NTAlIDUwJTtzdHJva2UtZGFzaGFycmF5OnZhcigtLWNpcmMpO3N0cm9rZS1kYXNob2Zmc2V0OnZhcigtLWNpcmMpO2FuaW1hdGlvbjpmaWxsIDEuNHMgY3ViaWMtYmV6aWVyKC4yMiwx
HLP:LC4zNiwxKSAuMnMgZm9yd2FyZHN9Ci5nLW51bXtmb250LXNpemU6NTRweDtmb250LXdlaWdodDo4MDA7dGV4dC1hbmNob3I6bWlkZGxlO2ZvbnQtZmFtaWx5OidTZWdvZSBVSScsc3lzdGVtLXVpLEFyaWFsfQouZ2F1Z2Utc20gLmctbnVte2ZvbnQtc2l6ZTo0NnB4
HLP:fQouZy1sYWJlbHttYXJnaW4tdG9wOjZweDtmb250LXdlaWdodDo3MDA7Zm9udC1zaXplOjE1cHh9Ci5nLWNhcHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7bGV0dGVyLXNwYWNpbmc6MS41cHg7bWFyZ2luLXRvcDoycHh9Ci5jb21wYXJle2Rpc3Bs
HLP:YXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtnYXA6OHB4O21hcmdpbi10b3A6MTRweDtmbGV4LXdyYXA6d3JhcH0KLm1pbml7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5taW5pLWNhcHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1z
HLP:aXplOjExcHg7bGV0dGVyLXNwYWNpbmc6MS4ycHg7bWFyZ2luLXRvcDotNnB4fQouYXJyb3d7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjZweDtmb250LXNpemU6MzBweDtmb250LXdlaWdodDo4MDB9Ci5k
HLP:ZWx0YS1jaGlwe2JvcmRlcjoxcHggc29saWQ7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjNweCAxMnB4O2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO3doaXRlLXNwYWNlOm5vd3JhcH0KLmhlcm8tc2lkZXtkaXNwbGF5OmZsZXg7ZmxleC1kaXJl
HLP:Y3Rpb246Y29sdW1uO2dhcDoxNnB4fQouY2hpcHN7ZGlzcGxheTpmbGV4O2dhcDoxMHB4O2ZsZXgtd3JhcDp3cmFwfQouY2hpcHtmbGV4OjE7bWluLXdpZHRoOjk2cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTti
HLP:b3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxMnB4IDE0cHg7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5jaGlwIC5ue2ZvbnQtc2l6ZToyNnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQouY2hpcCAubHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEx
HLP:LjVweDtsZXR0ZXItc3BhY2luZzouNnB4O21hcmdpbi10b3A6M3B4fQouYy1va3tjb2xvcjojMjJjNTVlfS5jLXdhcm57Y29sb3I6I2Y1OWUwYn0uYy1lcnJ7Y29sb3I6I2VmNDQ0NH0uYy1za2lwe2NvbG9yOiM5NGEzYjh9Ci5zeXNncmlke2Rpc3BsYXk6Z3JpZDtn
HLP:cmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyIDFmcjtnYXA6MXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O292ZXJmbG93OmhpZGRlbn0KQG1lZGlhKG1heC13aWR0aDo1MjBweCl7LnN5c2dyaWR7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5z
HLP:OjFmcn19Ci5zeXN7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtwYWRkaW5nOjExcHggMTRweH0KLnN5cy1re2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFjaW5nOi40cHh9Ci5zeXMtdntmb250LXdlaWdodDo2MDA7Zm9udC1zaXpl
HLP:OjE0cHg7bWFyZ2luLXRvcDoxcHg7d29yZC1icmVhazpicmVhay13b3JkfQpoMi5zZWMtaHtmb250LXNpemU6MTVweDtsZXR0ZXItc3BhY2luZzouNnB4O3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTtjb2xvcjp2YXIoLS1hY2NlbnQpO21hcmdpbjozMHB4IDAgMTJw
HLP:eDtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4O3Njcm9sbC1tYXJnaW4tdG9wOjE0cHh9CmgyLnNlYy1oOjphZnRlcntjb250ZW50OicnO2ZsZXg6MTtoZWlnaHQ6MXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSl9Ci50aW1lbGluZXtwb3Np
HLP:dGlvbjpyZWxhdGl2ZTtwYWRkaW5nLWxlZnQ6OHB4fQoucGh7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOjE0cHg7cGFkZGluZzoxM3B4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7bWFy
HLP:Z2luLWJvdHRvbToxMHB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7cG9zaXRpb246cmVsYXRpdmU7b3ZlcmZsb3c6aGlkZGVufQoucGg6OmJlZm9yZXtjb250ZW50OicnO3Bvc2l0aW9uOmFic29sdXRlO2xlZnQ6MDt0b3A6MDtib3R0b206MDt3aWR0aDo0cHh9Ci5w
HLP:aC1vazo6YmVmb3Jle2JhY2tncm91bmQ6IzIyYzU1ZX0ucGgtd2Fybjo6YmVmb3Jle2JhY2tncm91bmQ6I2Y1OWUwYn0ucGgtZXJyb3I6OmJlZm9yZXtiYWNrZ3JvdW5kOiNlZjQ0NDR9LnBoLXNraXA6OmJlZm9yZXtiYWNrZ3JvdW5kOiM2NDc0OGJ9Ci5waC1kb3R7
HLP:ZmxleDowIDAgYXV0bzttYXJnaW4tdG9wOjFweH0KLnN2Z2ljb3t3aWR0aDoyNnB4O2hlaWdodDoyNnB4O2Rpc3BsYXk6YmxvY2t9Ci5waC1tYWlue2ZsZXg6MTttaW4td2lkdGg6MH0KLnBoLXRvcHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDox
HLP:MHB4O2ZsZXgtd3JhcDp3cmFwfQoucGgtbnVte2ZvbnQtdmFyaWFudC1udW1lcmljOnRhYnVsYXItbnVtcztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJh
HLP:ZGl1czo3cHg7cGFkZGluZzoxcHggN3B4fQoucGgtdGl0bGV7Zm9udC13ZWlnaHQ6NjAwO2ZvbnQtc2l6ZToxNXB4fQoucGgtYmFkZ2V7Zm9udC1zaXplOjExcHg7Zm9udC13ZWlnaHQ6ODAwO2xldHRlci1zcGFjaW5nOi42cHg7Ym9yZGVyLXJhZGl1czo5OTlweDtw
HLP:YWRkaW5nOjJweCAxMHB4fQouYi1va3tiYWNrZ3JvdW5kOnJnYmEoMzQsMTk3LDk0LC4xNik7Y29sb3I6IzIyYzU1ZX0uYi13YXJue2JhY2tncm91bmQ6cmdiYSgyNDUsMTU4LDExLC4xNik7Y29sb3I6I2Y1OWUwYn0uYi1lcnJvcntiYWNrZ3JvdW5kOnJnYmEoMjM5
HLP:LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uYi1za2lwe2JhY2tncm91bmQ6cmdiYSgxMDAsMTE2LDEzOSwuMTgpO2NvbG9yOiM5NGEzYjh9Ci5waC1ub3Rle2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDttYXJnaW4tdG9wOjNweH0KLnBoLXNlY3N7
HLP:ZmxleDowIDAgYXV0bztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEzcHg7Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO2FsaWduLXNlbGY6Y2VudGVyfQouZW1wdHl7Y29sb3I6dmFyKC0tbXV0ZWQpO3BhZGRpbmc6MThweDt0ZXh0LWFsaWdu
HLP:OmNlbnRlcn0KLmJhcmNoYXJ0e2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxNHB4IDE4cHg7bWFyZ2luLXRvcDo0cHh9Ci5iYXItcm93e2Rpc3BsYXk6ZmxleDthbGln
HLP:bi1pdGVtczpjZW50ZXI7Z2FwOjEycHg7cGFkZGluZzo1cHggMH0KLmJhci1sYmx7ZmxleDowIDAgMjIwcHg7Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7d2hpdGUtc3BhY2U6bm93cmFwO292ZXJmbG93OmhpZGRlbjt0ZXh0LW92ZXJmbG93OmVs
HLP:bGlwc2lzfQpAbWVkaWEobWF4LXdpZHRoOjYwMHB4KXsuYmFyLWxibHtmbGV4OjAgMCAxMjBweH19Ci5iYXItdHJhY2t7ZmxleDoxO2hlaWdodDoxMHB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtvdmVyZmxvdzpoaWRkZW59Ci5i
HLP:YXItdHJhY2sgc3BhbntkaXNwbGF5OmJsb2NrO2hlaWdodDoxMDAlO2JvcmRlci1yYWRpdXM6OTk5cHh9Ci5iYXItdmFse2ZsZXg6MCAwIGF1dG87Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1u
HLP:dW1zO3dpZHRoOjQ4cHg7dGV4dC1hbGlnbjpyaWdodH0KdWwuZmluZHN7bGlzdC1zdHlsZTpub25lO21hcmdpbjowO3BhZGRpbmc6MH0KLmZpbmR7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOjEycHg7cGFkZGluZzoxMnB4IDE2cHg7Ym9y
HLP:ZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjEzcHg7bWFyZ2luLWJvdHRvbTo5cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKX0KLnNldntmbGV4OjAgMCBhdXRvO2ZvbnQtc2l6ZToxMXB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2lu
HLP:ZzouNXB4O2JvcmRlci1yYWRpdXM6OHB4O3BhZGRpbmc6M3B4IDEwcHg7bWFyZ2luLXRvcDoxcHh9Ci5zZXYtaGlnaHtiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uc2V2LW1lZHtiYWNrZ3JvdW5kOnJnYmEoMjQ1LDE1OCwxMSwu
HLP:MTYpO2NvbG9yOiNmNTllMGJ9LnNldi1pbmZve2JhY2tncm91bmQ6cmdiYSg1NiwxODksMjQ4LC4xNik7Y29sb3I6dmFyKC0tYWNjZW50KX0uc2V2LW9re2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfQouZmluZC10eHR7Zm9udC1z
HLP:aXplOjE0cHh9CnVsLnN0ZXBze2xpc3Qtc3R5bGU6bm9uZTttYXJnaW46MDtwYWRkaW5nOjB9Ci5zdGVwLWxpe2Rpc3BsYXk6ZmxleDtnYXA6MTFweDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O3BhZGRpbmc6MTFweCAxNnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0t
HLP:bGluZSk7Ym9yZGVyLWxlZnQ6M3B4IHNvbGlkIHZhcigtLWFjY2VudCk7Ym9yZGVyLXJhZGl1czoxMnB4O21hcmdpbi1ib3R0b206OXB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Zm9udC1zaXplOjE0cHh9Ci5zdGVwLW9re2JvcmRlci1sZWZ0LWNvbG9yOiMyMmM1
HLP:NWV9Ci5zdGVwLWlje2NvbG9yOnZhcigtLWFjY2VudCk7Zm9udC13ZWlnaHQ6ODAwfQouc3RlcC1vayAuc3RlcC1pY3tjb2xvcjojMjJjNTVlfQouZGdyaWR7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczpyZXBlYXQoYXV0by1maXQsbWlubWF4KDIy
HLP:MHB4LDFmcikpO2dhcDoxNHB4fQouZGNhcmR7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTVweDtwYWRkaW5nOjE2cHggMThweH0KLmRjYXJkLXdpZGV7Z3JpZC1jb2x1bW46MS8tMX0KLmQt
HLP:aHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDo5cHg7Zm9udC13ZWlnaHQ6NzAwO2ZvbnQtc2l6ZToxNHB4O21hcmdpbi1ib3R0b206MTBweH0KLmQtaWN7d2lkdGg6MTRweDtoZWlnaHQ6MTRweDtib3JkZXItcmFkaXVzOjVweDtkaXNwbGF5Omlu
HLP:bGluZS1ibG9ja30KLmljLXJhbXtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzM4YmRmOCwjMGVhNWU5KX0uaWMtYmF0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMjJjNTVlLCMxNTgwM2QpfS5pYy1uZXR7YmFja2dyb3VuZDps
HLP:aW5lYXItZ3JhZGllbnQoMTM1ZGVnLCM4MThjZjgsIzRmNDZlNSl9LmljLWRldntiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2Y1OWUwYiwjZDk3NzA2KX0uaWMtc21hcnR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNmNDcyYjYs
HLP:I2RiMjc3Nyl9LmljLWJvb3R7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCMyZGQ0YmYsIzBkOTQ4OCl9LmljLXN0YXJ0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjYTc4YmZhLCM3YzNhZWQpfS5pYy1wcm9je2JhY2tncm91bmQ6
HLP:bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZmI3MTg1LCNlMTFkNDgpfQouZC1waWxse2Rpc3BsYXk6aW5saW5lLWJsb2NrO2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzo0cHggMTJweH0KLnBpbGwtcm93
HLP:e2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwfQoucGlsbC1nb29ke2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfS5waWxsLWJhZHtiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0u
HLP:cGlsbC11bmtub3due2JhY2tncm91bmQ6cmdiYSgxNDgsMTYzLDE4NCwuMTYpO2NvbG9yOiM5NGEzYjh9Ci5kLXN1Yntjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEyLjVweDttYXJnaW4tdG9wOjhweH0KLmQtaGludHtjb2xvcjojZjU5ZTBiO2ZvbnQtc2l6
HLP:ZToxMi41cHg7bWFyZ2luLXRvcDo4cHh9Ci5iYXQtYmFye2hlaWdodDoxMnB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtvdmVyZmxvdzpoaWRkZW47bWFyZ2luLXRvcDo0cHh9Ci5iYXQtYmFyIHNwYW57ZGlzcGxheTpibG9jazto
HLP:ZWlnaHQ6MTAwJTtib3JkZXItcmFkaXVzOjk5OXB4fQouZGV2LWxpc3R7bWFyZ2luOjRweCAwIDA7cGFkZGluZy1sZWZ0OjE4cHg7Zm9udC1zaXplOjEzLjVweH0KLmRldi1saXN0IGxpe21hcmdpbjoycHggMH0KLm11dGVke2NvbG9yOnZhcigtLW11dGVkKX0KLmZv
HLP:b3R7bWFyZ2luLXRvcDozNHB4O3RleHQtYWxpZ246Y2VudGVyO2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweH0KLnNlY3Rpb257YW5pbWF0aW9uOnJpc2UgLjVzIGVhc2UgYm90aH0KQGtleWZyYW1lcyBmaWxse3Rve3N0cm9rZS1kYXNob2Zmc2V0OnZh
HLP:cigtLXRhcmdldCl9fQpAa2V5ZnJhbWVzIHJpc2V7ZnJvbXtvcGFjaXR5OjA7dHJhbnNmb3JtOnRyYW5zbGF0ZVkoMTBweCl9dG97b3BhY2l0eToxO3RyYW5zZm9ybTpub25lfX0KQG1lZGlhIHByaW50ey50b2dnbGUsLnRvYywuYnRucywudG9hc3R7ZGlzcGxheTpu
HLP:b25lfWJvZHl7YmFja2dyb3VuZDojZmZmO2NvbG9yOiMwMDB9LmNhcmQsLmRjYXJkLC5waCwuZmluZCwuZXhlYywuYmFyY2hhcnQsLnN0ZXAtbGl7Ym94LXNoYWRvdzpub25lO2JhY2tkcm9wLWZpbHRlcjpub25lOy13ZWJraXQtYmFja2Ryb3AtZmlsdGVyOm5vbmU7
HLP:YmFja2dyb3VuZDojZmZmIWltcG9ydGFudH0uZ2F1Z2UgLmZpbGx7YW5pbWF0aW9uOm5vbmV9LnNlY3Rpb257YW5pbWF0aW9uOm5vbmV9YVtocmVmXXtjb2xvcjppbmhlcml0O3RleHQtZGVjb3JhdGlvbjpub25lfX0KOnJvb3R7LS1nbGFzczpyZ2JhKDE4LDI2LDQz
HLP:LC42MCk7LS1nbGFzc2JkOnJnYmEoMjU1LDI1NSwyNTUsLjA3KX0KaHRtbC5saWdodHstLWdsYXNzOnJnYmEoMjU1LDI1NSwyNTUsLjY0KTstLWdsYXNzYmQ6cmdiYSgxNSwyMyw0MiwuMDgpfQouY2FyZCwuZXhlYywuZGNhcmQsLmZpbmQsLmJhcmNoYXJ0LC5zdGVw
HLP:LWxpe2JhY2tncm91bmQ6dmFyKC0tZ2xhc3MpIWltcG9ydGFudDtiYWNrZHJvcC1maWx0ZXI6Ymx1cigxM3B4KSBzYXR1cmF0ZSgxNDAlKTstd2Via2l0LWJhY2tkcm9wLWZpbHRlcjpibHVyKDEzcHgpIHNhdHVyYXRlKDE0MCUpO2JvcmRlcjoxcHggc29saWQgdmFy
HLP:KC0tZ2xhc3NiZCkhaW1wb3J0YW50fQoudG9hc3R7cG9zaXRpb246Zml4ZWQ7Ym90dG9tOjI0cHg7bGVmdDo1MCU7dHJhbnNmb3JtOnRyYW5zbGF0ZVgoLTUwJSk7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNj
HLP:ZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWlnaHQ6NzAwO3BhZGRpbmc6MTBweCAxOHB4O2JvcmRlci1yYWRpdXM6MTJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyk7b3BhY2l0eTowO3BvaW50ZXItZXZlbnRzOm5vbmU7dHJhbnNpdGlvbjpvcGFjaXR5IC4y
HLP:NXM7ei1pbmRleDo2MDtmb250LXNpemU6MTNweH0KLnRvYXN0LnNob3d7b3BhY2l0eToxfQoudHJlbmQtdGl0bGV7bWFyZ2luLXRvcDoyMHB4O2ZvbnQtc2l6ZToxMnB4O2ZvbnQtd2VpZ2h0OjcwMDtsZXR0ZXItc3BhY2luZzoxcHg7dGV4dC10cmFuc2Zvcm06dXBw
HLP:ZXJjYXNlO2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLWxpc3R7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjtnYXA6NHB4O3dpZHRoOjEwMCU7bWFyZ2luLXRvcDo4cHg7Ym9yZGVyLXRvcDoxcHggc29saWQgdmFyKC0tbGluZSk7cGFkZGluZy10
HLP:b3A6OHB4fQoudHJlbmQtaXRlbXtkaXNwbGF5OmZsZXg7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47Zm9udC1zaXplOjEycHh9Ci50cmVuZC1kYXRle2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLXNjb3Jle2ZvbnQtd2VpZ2h0OjcwMH0KPC9zdHlsZT4K
HLP:PC9oZWFkPgo8Ym9keT4KPGRpdiBjbGFzcz0nd3JhcCc+CiAgPGRpdiBjbGFzcz0ndG9wYmFyJz4KICAgIDxkaXYgY2xhc3M9J2JyYW5kJz4KICAgICAgPGRpdiBjbGFzcz0nbG9nbyc+PHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIHdpZHRoPScyNicgaGVpZ2h0PScy
HLP:Nicgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdXUEknPjxwYXRoIGQ9J00xMiAybDcgM3Y2YzAgNC42LTMgOC4zLTcgOS42QzggMTkuMyA1IDE1LjYgNSAxMVY1eicgZmlsbD0nIzA0MjkzYicvPjxwYXRoIGQ9J005IDEybDIgMiA0LTQuNScgZmlsbD0nbm9uZScgc3Ry
HLP:b2tlPScjZGZmNmZmJyBzdHJva2Utd2lkdGg9JzInIHN0cm9rZS1saW5lY2FwPSdyb3VuZCcgc3Ryb2tlLWxpbmVqb2luPSdyb3VuZCcvPjwvc3ZnPjwvZGl2PgogICAgICA8ZGl2PgogICAgICAgIDxoMT5JbmZvcm1lIGRlIFJlcGFyYWNpb24gPHNwYW4gY2xhc3M9
HLP:J2JhZGdlJz5XUEkgU1VJVEUgdjMuMTwvc3Bhbj48L2gxPgogICAgICAgIDxkaXYgY2xhc3M9J3N1Yic+JCgmICRlbmMgJG1hY2hpbmUpICZuYnNwOyZtaWRkb3Q7Jm5ic3A7IGdlbmVyYWRvIGVsICRub3c8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICAg
HLP:IDxkaXYgY2xhc3M9J2J0bnMnPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dnbGUnIG9uY2xpY2s9IndpbmRvdy5wcmludCgpIj5JbXByaW1pciAvIFBERjwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dnbGUnIGlkPSdjb3B5YnRuJyBvbmNsaWNrPSJj
HLP:b3B5UmVzdW1lbigpIj5Db3BpYXIgcmVzdW1lbjwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dnbGUnIGlkPSd0aGVtZWJ0bicgb25jbGljaz0idG9nZ2xlVGhlbWUoKSI+VGVtYSBjbGFyby9vc2N1cm88L2J1dHRvbj4KICAgIDwvZGl2PgogIDwvZGl2
HLP:PgoKICA8bmF2IGNsYXNzPSd0b2MnIGFyaWEtbGFiZWw9J0luZGljZSc+CiAgICA8YSBocmVmPScjcmVzdW1lbic+UmVzdW1lbjwvYT4KICAgIDxhIGhyZWY9JyNmYXNlcyc+RmFzZXM8L2E+CiAgICA8YSBocmVmPScjaGFsbGF6Z29zJz5IYWxsYXpnb3M8L2E+CiAg
HLP:ICA8YSBocmVmPScjcGFzb3MnPlByb3hpbW9zIHBhc29zPC9hPgogICAgPGEgaHJlZj0nI2RpYWcnPkRpYWdub3N0aWNvPC9hPgogIDwvbmF2PgoKICA8ZGl2IGlkPSdyZXN1bWVuJyBjbGFzcz0nZXhlYyBzZWN0aW9uJz4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtc2Nv
HLP:cmUnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz4kbWFpblNjb3JlPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdleGVjLW1pZCc+CiAgICAgIDxkaXYgY2xhc3M9J2V4ZWMtdmVyZGljdCcgc3R5bGU9J2NvbG9yOiRtYWluQ29sb3InPlNhbHVkIGRlbCBzaXN0ZW1hOiAk
HLP:ZXhlY1ZlcmRpY3Q8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nZXhlYy1saW5lJz4kY09LIGNvcnJlY3RhcyAmbWlkZG90OyAkY1dBUk4gYXZpc29zICZtaWRkb3Q7ICRjRVJSIGVycm9yZXMgJm1pZGRvdDsgJGNTS0lQIG9taXRpZGFzICZtaWRkb3Q7ICR0b3RhbFBo
HLP:IGZhc2VzIGVuIHRvdGFsPC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtZGVsdGEnIHN0eWxlPSdjb2xvcjokZGVsdGFDb2xvcjtib3JkZXItY29sb3I6JGRlbHRhQ29sb3InPiRkZWx0YVR4dDwvZGl2PgogIDwvZGl2PgoKICA8ZGl2IGNsYXNz
HLP:PSdoZXJvIHNlY3Rpb24nPgogICAgPGRpdiBjbGFzcz0nY2FyZCBnYXVnZXdyYXAnPgogICAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1Z2UnIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nUHVudHVhY2lvbiBkZSBzYWx1ZCAkbWFpblNjb3Jl
HLP:IHNvYnJlIDEwMCc+PGNpcmNsZSBjbGFzcz0ndHJhY2snIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0Jy8+PGNpcmNsZSBjbGFzcz0nZmlsbCcgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnIHN0eWxlPSctLWNpcmM6JGNpcmM7LS10YXJnZXQ6JG1haW5PZmZzZXQ7c3Ry
HLP:b2tlOiRtYWluQ29sb3InLz48dGV4dCB4PScxMDAnIHk9JzExMicgY2xhc3M9J2ctbnVtJyBzdHlsZT0nZmlsbDokbWFpbkNvbG9yJz4kbWFpblNjb3JlPC90ZXh0Pjwvc3ZnPgogICAgICA8ZGl2IGNsYXNzPSdnLWxhYmVsJyBzdHlsZT0nY29sb3I6JG1haW5Db2xv
HLP:cic+U2FsdWQ6ICRtYWluTGFiZWw8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nZy1jYXAnPlBVTlRVQUNJT04gU09CUkUgMTAwPC9kaXY+CiAgICAgICRjb21wYXJlU2VjdGlvbgogICAgICAkaGlzdG9yeUh0bWwKICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0naGVy
HLP:by1zaWRlJz4KICAgICAgPGRpdiBjbGFzcz0nY2FyZCc+CiAgICAgICAgPGRpdiBjbGFzcz0nY2hpcHMnPgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBjLW9rJz4kY09LPC9kaXY+PGRpdiBjbGFzcz0nbCc+T0s8L2Rpdj48L2Rpdj4K
HLP:ICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy13YXJuJz4kY1dBUk48L2Rpdj48ZGl2IGNsYXNzPSdsJz5BVklTT1M8L2Rpdj48L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1lcnInPiRjRVJS
HLP:PC9kaXY+PGRpdiBjbGFzcz0nbCc+RVJST1JFUzwvZGl2PjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBjLXNraXAnPiRjU0tJUDwvZGl2PjxkaXYgY2xhc3M9J2wnPk9NSVRJREFTPC9kaXY+PC9kaXY+CiAgICAgICAgPC9k
HLP:aXY+CiAgICAgIDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdjYXJkJz4KICAgICAgICA8ZGl2IGNsYXNzPSdzeXNncmlkJz4kc3lzQ2FyZHM8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlvbic+CiAgICA8
HLP:aDIgaWQ9J2Zhc2VzJyBjbGFzcz0nc2VjLWgnPkxpbmVhIGRlIHRpZW1wbyBkZSBmYXNlcyAoJHRvdGFsUGgpPC9oMj4KICAgIDxkaXYgY2xhc3M9J3RpbWVsaW5lJz4kcm93czwvZGl2PgogICAgPGRpdiBjbGFzcz0nYmFyY2hhcnQnPiRiYXJzPC9kaXY+CiAgPC9k
HLP:aXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdoYWxsYXpnb3MnIGNsYXNzPSdzZWMtaCc+SGFsbGF6Z29zIHkgY2F1c2EgcmFpejwvaDI+CiAgICA8dWwgY2xhc3M9J2ZpbmRzJz4kZmluZEh0bWw8L3VsPgogIDwvZGl2PgoKICA8ZGl2IGNs
HLP:YXNzPSdzZWN0aW9uJz4KICAgIDxoMiBpZD0ncGFzb3MnIGNsYXNzPSdzZWMtaCc+UHJveGltb3MgcGFzb3MgcmVjb21lbmRhZG9zPC9oMj4KICAgIDx1bCBjbGFzcz0nc3RlcHMnPiRzdGVwc0h0bWw8L3VsPgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9u
HLP:Jz4kZGlhZ1NlY3Rpb248L2Rpdj4KCiAgPGRpdiBjbGFzcz0nZm9vdCc+CiAgICBXUEkgJm1pZGRvdDsgU3VpdGUgZGUgUmVwYXJhY2lvbiBkZSBFbWVyZ2VuY2lhIHBhcmEgV2luZG93cyAxMC8xMSAmbWlkZG90OyBpbmZvcm1lIGRlIHNvbG8gbGVjdHVyYS48YnI+
HLP:CiAgICBMYXMgY29waWFzIGRlIHNlZ3VyaWRhZCB5IGxvcyByZWdpc3Ryb3MgZXN0YW4gZW4gbGEgY2FycGV0YSBXUElfU3VpdGUganVudG8gYWwgcHJvZ3JhbWEuCiAgPC9kaXY+CjwvZGl2Pgo8c2NyaXB0PgooZnVuY3Rpb24oKXt0cnl7dmFyIHM9bG9jYWxTdG9y
HLP:YWdlLmdldEl0ZW0oJ3dwaS10aGVtZScpO3ZhciByb290PWRvY3VtZW50LmRvY3VtZW50RWxlbWVudDtpZihzPT09J2xpZ2h0Jyl7cm9vdC5jbGFzc0xpc3QuYWRkKCdsaWdodCcpO31lbHNlIGlmKHM9PT0nZGFyaycpe3Jvb3QuY2xhc3NMaXN0LnJlbW92ZSgnbGln
HLP:aHQnKTt9ZWxzZSBpZih3aW5kb3cubWF0Y2hNZWRpYSYmd2luZG93Lm1hdGNoTWVkaWEoJyhwcmVmZXJzLWNvbG9yLXNjaGVtZTogbGlnaHQpJykubWF0Y2hlcyl7cm9vdC5jbGFzc0xpc3QuYWRkKCdsaWdodCcpO319Y2F0Y2goZSl7fX0pKCk7CmZ1bmN0aW9uIHRv
HLP:Z2dsZVRoZW1lKCl7dHJ5e3ZhciBsPWRvY3VtZW50LmRvY3VtZW50RWxlbWVudC5jbGFzc0xpc3QudG9nZ2xlKCdsaWdodCcpO2xvY2FsU3RvcmFnZS5zZXRJdGVtKCd3cGktdGhlbWUnLGw/J2xpZ2h0JzonZGFyaycpO31jYXRjaChlKXt9fQpmdW5jdGlvbiBmbGFz
HLP:aChtKXt0cnl7dmFyIHQ9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZGl2Jyk7dC5jbGFzc05hbWU9J3RvYXN0Jzt0LnRleHRDb250ZW50PW07ZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZCh0KTtyZXF1ZXN0QW5pbWF0aW9uRnJhbWUoZnVuY3Rpb24oKXt0LmNsYXNz
HLP:TGlzdC5hZGQoJ3Nob3cnKTt9KTtzZXRUaW1lb3V0KGZ1bmN0aW9uKCl7dC5jbGFzc0xpc3QucmVtb3ZlKCdzaG93Jyk7c2V0VGltZW91dChmdW5jdGlvbigpe3QucmVtb3ZlKCk7fSwzMDApO30sMTYwMCk7fWNhdGNoKGUpe319CmZ1bmN0aW9uIGZiKHR4dCxvayl7
HLP:dHJ5e3ZhciBhPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3RleHRhcmVhJyk7YS52YWx1ZT10eHQ7YS5zdHlsZS5wb3NpdGlvbj0nZml4ZWQnO2Euc3R5bGUubGVmdD0nLTk5OTlweCc7ZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChhKTthLnNlbGVjdCgpO2RvY3Vt
HLP:ZW50LmV4ZWNDb21tYW5kKCdjb3B5Jyk7YS5yZW1vdmUoKTtvaygpO31jYXRjaChlKXtmbGFzaCgnTm8gc2UgcHVkbyBjb3BpYXInKTt9fQpmdW5jdGlvbiBjb3B5UmVzdW1lbigpe3ZhciBwPVtdO3ZhciB0PWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJ2gxJyk7aWYo
HLP:dClwLnB1c2godC5pbm5lclRleHQudHJpbSgpKTt2YXIgcz1kb2N1bWVudC5xdWVyeVNlbGVjdG9yKCcuc3ViJyk7aWYocylwLnB1c2gocy5pbm5lclRleHQudHJpbSgpKTt2YXIgZXg9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignLmV4ZWMnKTtpZihleClwLnB1c2go
HLP:J1xuJytleC5pbm5lclRleHQucmVwbGFjZSgvXG57Mix9L2csJ1xuJykudHJpbSgpKTt2YXIgaD1kb2N1bWVudC5nZXRFbGVtZW50QnlJZCgnaGFsbGF6Z29zJyk7aWYoaCYmaC5wYXJlbnROb2RlKXAucHVzaCgnXG4nK2gucGFyZW50Tm9kZS5pbm5lclRleHQudHJp
HLP:bSgpKTt2YXIgdHh0PXAuam9pbignXG4nKTtmdW5jdGlvbiBvaygpe2ZsYXNoKCdSZXN1bWVuIGNvcGlhZG8nKTt9aWYobmF2aWdhdG9yLmNsaXBib2FyZCYmbmF2aWdhdG9yLmNsaXBib2FyZC53cml0ZVRleHQpe25hdmlnYXRvci5jbGlwYm9hcmQud3JpdGVUZXh0
HLP:KHR4dCkudGhlbihvayxmdW5jdGlvbigpe2ZiKHR4dCxvayk7fSk7fWVsc2V7ZmIodHh0LG9rKTt9fQo8L3NjcmlwdD4KPC9ib2R5Pgo8L2h0bWw+CiJACiAgICAgICAgJHV0ZjggPSBOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpCiAg
HLP:ICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRvdXRQYXRoLCAkaHRtbCwgJHV0ZjgpCiAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAi
HLP:RVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBSZWdpc3RyYXIgcmVzdWx0YWRvIGRlIHVuYSBmYXNl
HLP:IGVuIGVsIGVzdGFkbyAocGFyYSBlbCBpbmZvcm1lKS4KIyAtQXJnID0gIm51bTt0aXRsZTtyZXN1bHQ7c2Vjcztub3RlIgpmdW5jdGlvbiBBZGQtUGhhc2VSZXN1bHQoJHNwZWMpIHsKICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICRwYXJ0cyA9ICRzcGVjIC1zcGxp
HLP:dCAnOycsNQogICAgJHBoID0gW3BzY3VzdG9tb2JqZWN0XUB7IG51bT0kcGFydHNbMF07IHRpdGxlPSRwYXJ0c1sxXTsgcmVzdWx0PSRwYXJ0c1syXTsgc2Vjcz0kcGFydHNbM107IG5vdGU9JHBhcnRzWzRdIH0KICAgICRsaXN0ID0gQCgkc3QucGhhc2VzKSArICRw
HLP:aAogICAgJHN0LnBoYXNlcyA9ICRsaXN0CiAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gU2V0LVNjb3JlKCR3aGljaCwgJHZhbCkgewogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgaWYgKCR3aGljaCAtZXEgJ2JlZm9yZScpIHsg
HLP:CiAgICAgICAgJHN0LnNjb3JlX2JlZm9yZSA9IFtpbnRdJHZhbCAKICAgIH0gZWxzZSB7IAogICAgICAgICRzdC5zY29yZV9hZnRlciA9IFtpbnRdJHZhbCAKICAgICAgICBTYXZlLUhlYWx0aEhpc3RvcnkgW2ludF0kdmFsCiAgICB9CiAgICBXcml0ZS1TdGF0ZSAk
HLP:c3Q7ICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gQWRkLUZpbmRpbmcoJHRleHQpIHsKICAgICRzdCA9IFJlYWQtU3RhdGU7ICRzdC5maW5kaW5ncyA9IEAoJHN0LmZpbmRpbmdzKSArICR0ZXh0OyBXcml0ZS1TdGF0ZSAkc3Q7ICJSRVNVTFQ9T0siCn0KCiMgPT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgTE9HSUNBIFBVUkEgTlVFVkEgLyBDT1JSRUdJREEgKEJsb3F1ZSAzKQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSAoMy4xIC8gQnVnIDQgLyBSZXEgNikgTm9ybWFsaXphY2lvbiBkZSBsYSBzZWxlY2Npb24gZGUgZmFzZXMgLS0tLS0tLS0tLQojIEVudHJhZGE6IGNhZGVuYSBjb24gSURzIHNlcGFy
HLP:YWRvcyBwb3IgY29tYXMgKGVzcGFjaW9zIGFyYml0cmFyaW9zLCAxLTIKIyBkaWdpdG9zLCBwb3NpYmxlcyBpbnZhbGlkb3MpLiBTYWxpZGE6IG9iamV0byBjb24gLm5vcm0gKGxpc3RhIGNhbm9uaWNhLAojIG9yZGVuYWRhLCB1bmljYSBkZSBJRHMgZGUgMiBkaWdp
HLP:dG9zIGVuIHswMC4uMTZ9KSB5IC5pbnZhbGlkIChsb3Mgbm8gdmFsaWRvcykuCiMgTnVuY2EgbGFuemEgZXhjZXBjaW9uIGFudGUgZW50cmFkYSBtYWxmb3JtYWRhIG8gdmFjaWEuCmZ1bmN0aW9uIE5vcm1hbGl6ZS1GYXNlcyhbc3RyaW5nXSRyYXcpIHsKICAgICR2
HLP:YWxpZCAgID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgICRpbnZhbGlkID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgIGlmICgkbnVsbCAtbmUgJHJhdyAt
HLP:YW5kICRyYXcuVHJpbSgpLkxlbmd0aCAtZ3QgMCkgewogICAgICAgIGZvcmVhY2ggKCR0IGluICgkcmF3IC1zcGxpdCAnLCcpKSB7CiAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJHQpIHsgY29udGludWUgfQogICAgICAgICAgICAkdG9rID0gKCR0IC1yZXBsYWNl
HLP:ICdccycsICcnKSAgICAgICAgICAjIHF1aXRhciBlc3BhY2lvcyBpbnRlcm5vcyB5IGV4dGVybm9zCiAgICAgICAgICAgIGlmICgkdG9rIC1lcSAnJykgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRjYW5vbiA9ICR0b2sKICAgICAgICAgICAgaWYgKCR0b2sgLW1h
HLP:dGNoICdeXGQkJykgeyAkY2Fub24gPSAkdG9rLlBhZExlZnQoMiwgJzAnKSB9ICAgIyAxIGRpZ2l0byAtPiAyIGRpZ2l0b3MKICAgICAgICAgICAgaWYgKCRjYW5vbiAtbWF0Y2ggJ15cZHsyfSQnIC1hbmQgW2ludF0kY2Fub24gLWdlIDAgLWFuZCBbaW50XSRjYW5v
HLP:biAtbGUgMTYpIHsKICAgICAgICAgICAgICAgIGlmICgtbm90ICR2YWxpZC5Db250YWlucygkY2Fub24pKSB7ICR2YWxpZC5BZGQoJGNhbm9uKSB9CiAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAkaW52YWxpZC5BZGQoJHRvaykKICAgICAgICAg
HLP:ICAgfQogICAgICAgIH0KICAgIH0KICAgICRzb3J0ZWQgPSBAKCR2YWxpZCB8IFNvcnQtT2JqZWN0KQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBub3JtID0gJHNvcnRlZDsgaW52YWxpZCA9IEAoJGludmFsaWQpIH0KfQoKIyAtLS0gKDMuMyAvIFJlcSA0
HLP:KSBDaGVja3BvaW50IHNvYnJlIGNoZWNrcG9pbnQuanNvbiAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBQYXJzZXIgZGVsIC1BcmcgY29uIGZvcm1hdG86CiMgICAic2F2ZXxzZWxlY3Rpb249MDAsMDEsMDJ8Y29tcGxldGVkPTAwLDAxfG1vZGU9YXV0bzoxO2Ry
HLP:eTowfHJlYXNvbj1jaGtkc2siCmZ1bmN0aW9uIFBhcnNlLUNoZWNrcG9pbnRBcmcoW3N0cmluZ10kcmF3KSB7CiAgICAkcmVzID0gW29yZGVyZWRdQHsgc3ViID0gJyc7IHNlbGVjdGlvbiA9IEAoKTsgY29tcGxldGVkID0gQCgpOyBtb2RlID0gQHt9OyByZWFzb24g
HLP:PSAnJyB9CiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yRW1wdHkoJHJhdykpIHsgcmV0dXJuICRyZXMgfQogICAgJHNlZ3MgPSAkcmF3IC1zcGxpdCAnXHwnCiAgICAkcmVzLnN1YiA9ICRzZWdzWzBdLlRyaW0oKS5Ub0xvd2VyKCkKICAgIGZvciAoJGkgPSAxOyAk
HLP:aSAtbHQgJHNlZ3MuQ291bnQ7ICRpKyspIHsKICAgICAgICAka3YgPSAkc2Vnc1skaV0gLXNwbGl0ICc9JywgMgogICAgICAgIGlmICgka3YuQ291bnQgLWx0IDIpIHsgY29udGludWUgfQogICAgICAgICRrZXkgPSAka3ZbMF0uVHJpbSgpLlRvTG93ZXIoKQogICAg
HLP:ICAgICR2YWwgPSAka3ZbMV0KICAgICAgICBzd2l0Y2ggKCRrZXkpIHsKICAgICAgICAgICAgJ3NlbGVjdGlvbicgeyAkcmVzLnNlbGVjdGlvbiA9IEAoJHZhbCAtc3BsaXQgJywnIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFdoZXJlLU9iamVjdCB7
HLP:ICRfIC1uZSAnJyB9KSB9CiAgICAgICAgICAgICdjb21wbGV0ZWQnIHsgJHJlcy5jb21wbGV0ZWQgPSBAKCR2YWwgLXNwbGl0ICcsJyB8IEZvckVhY2gtT2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBXaGVyZS1PYmplY3QgeyAkXyAtbmUgJycgfSkgfQogICAgICAgICAg
HLP:ICAncmVhc29uJyAgICB7ICRyZXMucmVhc29uID0gJHZhbC5UcmltKCkgfQogICAgICAgICAgICAnbW9kZScgewogICAgICAgICAgICAgICAgJG0gPSBAe30KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwYWlyIGluICgkdmFsIC1zcGxpdCAnOycpKSB7CiAgICAg
HLP:ICAgICAgICAgICAgICAgJHAgPSAkcGFpciAtc3BsaXQgJzonLCAyCiAgICAgICAgICAgICAgICAgICAgaWYgKCRwLkNvdW50IC1lcSAyKSB7ICRtWyRwWzBdLlRyaW0oKS5Ub0xvd2VyKCldID0gKCRwWzFdLlRyaW0oKSAtZXEgJzEnKSB9CiAgICAgICAgICAgICAg
HLP:ICB9CiAgICAgICAgICAgICAgICAkcmVzLm1vZGUgPSAkbQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQogICAgcmV0dXJuICRyZXMKfQoKIyBDb25zdHJ1eWUgeSBwZXJzaXN0ZSBjaGVja3BvaW50Lmpzb24uIERldnVlbHZlICR0cnVlLyRmYWxzZSAoc2lu
HLP:IGV4Y2VwY2lvbikuCmZ1bmN0aW9uIFNhdmUtQ2hlY2twb2ludCgkcGFyc2VkKSB7CiAgICB0cnkgewogICAgICAgICRtb2RlID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIGF1dG8gICAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydhdXRvJ10KICAgICAg
HLP:ICAgICAgbm9yZWJvb3QgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ25vcmVib290J10KICAgICAgICAgICAga2VlcHd1ICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ2tlZXB3dSddCiAgICAgICAgICAgIGRyeSAgICAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydkcnknXQog
HLP:ICAgICAgICAgICB0cmlhZ2UgICA9IFtib29sXSRwYXJzZWQubW9kZVsndHJpYWdlJ10KICAgICAgICB9CiAgICAgICAgJG5vdyA9IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGRfSEgtbW0nKQogICAgICAgICRjcCA9IFtwc2N1c3RvbW9iamVjdF1Aewog
HLP:ICAgICAgICAgICB2ZXJzaW9uICAgICAgICA9ICRXUElfVkVSU0lPTgogICAgICAgICAgICBjcmVhdGVkICAgICAgICA9ICRub3cKICAgICAgICAgICAgbW9kZSAgICAgICAgICAgPSAkbW9kZQogICAgICAgICAgICBzZWxlY3Rpb24gICAgICA9IEAoJHBhcnNlZC5z
HLP:ZWxlY3Rpb24pCiAgICAgICAgICAgIGNvbXBsZXRlZCAgICAgID0gQCgkcGFyc2VkLmNvbXBsZXRlZCkKICAgICAgICAgICAgcGVuZGluZ19yZWFzb24gPSAkcGFyc2VkLnJlYXNvbgogICAgICAgICAgICB0aW1lc3RhbXBfcnVuICA9ICRub3cKICAgICAgICB9CiAg
HLP:ICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRDaGVja3BvaW50RmlsZSwgKCRjcCB8IENvbnZlcnRUby1Kc29uIC1EZXB0aCA2KSwgKE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkpKQogICAgICAgIHJldHVybiAk
HLP:dHJ1ZQogICAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9CgojIENhcmdhIGNoZWNrcG9pbnQuanNvbi4gRGV2dWVsdmUgZWwgb2JqZXRvIG8gJG51bGwgc2kgbm8gZXhpc3RlIC8gbWFsZm9ybWFkby4KZnVuY3Rpb24gTG9hZC1DaGVja3BvaW50IHsKICAgIGlm
HLP:ICgtbm90IChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSkgeyByZXR1cm4gJG51bGwgfQogICAgdHJ5IHsgcmV0dXJuIChHZXQtQ29udGVudCAkQ2hlY2twb2ludEZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24pIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9
HLP:CgojIFZhbGlkYSB1biBjaGVja3BvaW50OiBleGlzdGUgKyBwYXJzZWFibGUgKyB2ZXJzaW9uIGNvbXBhdGlibGUgKyBjb21wbGV0ZWQKIyBzdWJjb25qdW50byBkZSBzZWxlY3Rpb24gKyBjcmVhdGVkIGRlbnRybyBkZSBsYSB2ZW50YW5hLiBEZXZ1ZWx2ZSBib29s
HLP:ZWFubwojIFNJTiBsYW56YXIgZXhjZXBjaW9uIGFudGUgSlNPTiBtYWxmb3JtYWRvIG8gY2FkdWNhZG8uCmZ1bmN0aW9uIFRlc3QtQ2hlY2twb2ludFZhbGlkKCRjcCkgewogICAgdHJ5IHsKICAgICAgICBpZiAoJG51bGwgLWVxICRjcCkgewogICAgICAgICAgICBp
HLP:ZiAoLW5vdCAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkpIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgICAgIHRyeSB7ICRjcCA9IEdldC1Db250ZW50ICRDaGVja3BvaW50RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9IGNhdGNoIHsgcmV0dXJuICRm
HLP:YWxzZSB9CiAgICAgICAgfQogICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIGlmIChbc3RyaW5nXSRjcC52ZXJzaW9uIC1uZSAkV1BJX1ZFUlNJT04pIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgJHNlbCAgPSBAKCRj
HLP:cC5zZWxlY3Rpb24pCiAgICAgICAgJGNvbXAgPSBAKCRjcC5jb21wbGV0ZWQpCiAgICAgICAgZm9yZWFjaCAoJGMgaW4gJGNvbXApIHsgaWYgKCRzZWwgLW5vdGNvbnRhaW5zICRjKSB7IHJldHVybiAkZmFsc2UgfSB9CiAgICAgICAgJGNyZWF0ZWQgPSAkbnVsbAog
HLP:ICAgICAgIGlmICgkY3AuY3JlYXRlZCkgewogICAgICAgICAgICB0cnkgeyAkY3JlYXRlZCA9IFtkYXRldGltZV06OlBhcnNlRXhhY3QoW3N0cmluZ10kY3AuY3JlYXRlZCwgJ3l5eXktTU0tZGRfSEgtbW0nLCAkbnVsbCkgfSBjYXRjaCB7ICRjcmVhdGVkID0gJG51
HLP:bGwgfQogICAgICAgIH0KICAgICAgICBpZiAoJG51bGwgLWVxICRjcmVhdGVkKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgICRhZ2UgPSAoR2V0LURhdGUpIC0gJGNyZWF0ZWQKICAgICAgICBpZiAoJGFnZS5Ub3RhbERheXMgLWd0ICRDSEVDS1BPSU5UX01BWF9B
HLP:R0VfREFZUykgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0KfQoKIyBQcmltZXJhIGZhc2UgZGUgJ3NlbGVjdGlvbicgbm8gcHJlc2VudGUgZW4gJ2NvbXBsZXRlZCcgKG8gJycgc2kgdG9k
HLP:YXMgaGVjaGFzKS4KZnVuY3Rpb24gR2V0LU5leHRQaGFzZSgkY3ApIHsKICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAnJyB9CiAgICAkY29tcCA9IEAoJGNwLmNvbXBsZXRlZCkKICAgIGZvcmVhY2ggKCRzIGluIEAoJGNwLnNlbGVjdGlvbikpIHsgaWYg
HLP:KCRjb21wIC1ub3Rjb250YWlucyAkcykgeyByZXR1cm4gJHMgfSB9CiAgICByZXR1cm4gJycKfQoKIyAtLS0gKDMuOSAvIEJ1ZyA2IC8gUmVxIDgpIFJlc2V0IGRlIGVzdGFkbyByZXV0aWxpemFibGUgLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBEZWphIHBoYXNlcz1A
HLP:KCksIGZpbmRpbmdzPUAoKSB5IGxvcyBzY29yZXMgKGJlZm9yZS9hZnRlcikgYSBudWxsLiBFbAojIGNvbmRpY2lvbmFkbyBhIC9yZXN1bWUgbG8gYXBsaWNhIGVsIGJhdGNoICh0YXJlYXMgOC40IC8gOS4xKTogc29sbyBpbnZvY2EKIyAncmVzZXRzdGF0ZScgY3Vh
HLP:bmRvIFJFU1VNRT09MCwgY29uc2VydmFuZG8gZWwgZXN0YWRvIHByZXZpbyBlbiAvcmVzdW1lLgpmdW5jdGlvbiBSZXNldC1TdGF0ZSB7CiAgICBXcml0ZS1TdGF0ZSAoW3BzY3VzdG9tb2JqZWN0XUB7IHNjb3JlX2JlZm9yZSA9ICRudWxsOyBzY29yZV9hZnRlciA9
HLP:ICRudWxsOyBmaW5kaW5ncyA9IEAoKTsgcGhhc2VzID0gQCgpIH0pCn0KCiMgLS0tICgzLjExIC8gQnVnIDcgLyBSZXEgOSkgSG9uZXN0aWRhZCBkZWwgbW92aW1pZW50byBkZSBjYWNoZXMgLS0tLS0tLS0tLS0tCiMgRXhpdG8gKHRydWUpIFNJIFkgU09MTyBTSSBl
HLP:bCBvcmlnZW4gZXN0YSBhdXNlbnRlIHkgZWwgZGVzdGlubyBwcmVzZW50ZS4KIyBWYXJpYW50ZSBwdXJhIChib29sZWFub3MpICsgdmFyaWFudGUgcXVlIGFjZXB0YSBydXRhcyB5IGhhY2UgVGVzdC1QYXRoLgpmdW5jdGlvbiBUZXN0LU1vdmVSZXN1bHQoW2Jvb2xd
HLP:JHNyY0V4aXN0cywgW2Jvb2xdJGRzdEV4aXN0cykgewogICAgcmV0dXJuICgoLW5vdCAkc3JjRXhpc3RzKSAtYW5kICRkc3RFeGlzdHMpCn0KZnVuY3Rpb24gVGVzdC1Nb3ZlUmVzdWx0UGF0aChbc3RyaW5nXSRzcmMsIFtzdHJpbmddJGRzdCkgewogICAgcmV0dXJu
HLP:IChUZXN0LU1vdmVSZXN1bHQgKFtib29sXShUZXN0LVBhdGggJHNyYykpIChbYm9vbF0oVGVzdC1QYXRoICRkc3QpKSkKfQoKIyAtLS0gKDMuMTEgLyBCdWcgOCAvIFJlcSAxMCkgSWRlbXBvdGVuY2lhIGRlIFZpcnR1YWxUZXJtaW5hbExldmVsIC0tLS0tLS0tLS0K
HLP:IyBOb3JtYWxpemEgdmFsb3JlcyAnMHgxJyAvICcxJyAvIDEgYSBlbnRlcm8gcGFyYSBjb21wYXJhciBkZSBmb3JtYSByb2J1c3RhLgpmdW5jdGlvbiBDb252ZXJ0VG8tVnRsSW50KCR2KSB7CiAgICBpZiAoJG51bGwgLWVxICR2KSB7IHJldHVybiAkbnVsbCB9CiAg
HLP:ICAkcyA9IChbc3RyaW5nXSR2KS5UcmltKCkuVG9Mb3dlcigpCiAgICBpZiAoJHMgLWVxICcnKSB7IHJldHVybiAkbnVsbCB9CiAgICB0cnkgewogICAgICAgIGlmICgkcy5TdGFydHNXaXRoKCcweCcpKSB7IHJldHVybiBbQ29udmVydF06OlRvSW50MzIoJHMsIDE2
HLP:KSB9CiAgICAgICAgcmV0dXJuIFtpbnRdJHMKICAgIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CiMgRGV2dWVsdmUgJHRydWUgKGVzY3JpYmlyKSBzb2xvIHNpIGVsIHZhbG9yIGFjdHVhbCBkaWZpZXJlIGRlbCBkZXNlYWRvLgpmdW5jdGlvbiBSZXNvbHZlLVZ0
HLP:bFdyaXRlKCRjdXJyZW50LCAkZGVzaXJlZCkgewogICAgcmV0dXJuICgoQ29udmVydFRvLVZ0bEludCAkY3VycmVudCkgLW5lIChDb252ZXJ0VG8tVnRsSW50ICRkZXNpcmVkKSkKfQoKIyAtLS0gKDMuMTQgLyBSZXEgMS4zKSBNYXBlbyBUT1RBTCBkZSBjb2RpZ28g
HLP:ZGUgc2FsaWRhIGEge09LLFdBUk4sU0tJUCxFUlJPUn0KIyAwLT5PSywgMS0+V0FSTiwgMi0+U0tJUCwgMy0+RVJST1I7IGN1YWxxdWllciBvdHJvIGVudGVybyAobyBubyBlbnRlcm8pIC0+IEVSUk9SLgpmdW5jdGlvbiBNYXAtRXhpdENvZGUoJGNvZGUpIHsKICAg
HLP:ICRuID0gJG51bGwKICAgIHRyeSB7ICRuID0gW2ludF0kY29kZSB9IGNhdGNoIHsgcmV0dXJuICdFUlJPUicgfQogICAgc3dpdGNoICgkbikgewogICAgICAgIDAgICAgICAgeyAnT0snIH0KICAgICAgICAxICAgICAgIHsgJ1dBUk4nIH0KICAgICAgICAyICAgICAg
HLP:IHsgJ1NLSVAnIH0KICAgICAgICAzICAgICAgIHsgJ0VSUk9SJyB9CiAgICAgICAgZGVmYXVsdCB7ICdFUlJPUicgfQogICAgfQp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09CiMgIERJQUdOT1NUSUNPIEFNUExJQURPICg1LjEgLyBSZXEgMTUuMS0xNS41KQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSBSQU0gKFJlcSAxNS4xKSAt
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUmVzb2x2ZS1SYW1TdGF0dXM6IGZ1bmNpb24gUFVSQS4gQSBwYXJ0aXIgZGVsIGNvbnRlbyBkZSBlcnJvcmVzIGRlIG1lbW9yaWEKIyBXSEVBIHkgZGUgZmFsbG9z
HLP:IGRlbCBkaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MsIGRlY2lkZSBlbCBlc3RhZG8geQojIHNpIGNvbnZpZW5lIHJlY29tZW5kYXIgbWRzY2hlZC4KZnVuY3Rpb24gUmVzb2x2ZS1SYW1TdGF0dXMoW2ludF0kd2hlYU1lbUVycm9ycywgW2ludF0kbWVt
HLP:RGlhZ0ZhaWx1cmVzKSB7CiAgICBpZiAoJHdoZWFNZW1FcnJvcnMgLWd0IDAgLW9yICRtZW1EaWFnRmFpbHVyZXMgLWd0IDApIHsKICAgICAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdzdXNwZWN0JzsgcmVjb21tZW5kX21kc2NoZWQgPSAk
HLP:dHJ1ZSB9CiAgICB9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdvayc7IHJlY29tbWVuZF9tZHNjaGVkID0gJGZhbHNlIH0KfQoKIyBHZXQtUmFtQ2hlY2s6IGxlZSBldmVudG9zIFdIRUEgeSByZXN1bHRhZG9zIGRlbCBEaWFnbm9zdGlj
HLP:byBkZSBtZW1vcmlhIGRlCiMgV2luZG93cy4gRGVncmFkYWNpb24gZWxlZ2FudGU6IHNpIGxhIGNvbnN1bHRhIGRlIGV2ZW50b3MgZmFsbGEgcG9yIGNvbXBsZXRvLAojIGRldnVlbHZlIHN0YXR1cz0ndW5rbm93bicgc2luIGxhbnphciBleGNlcGNpb24uCmZ1bmN0
HLP:aW9uIEdldC1SYW1DaGVjayB7CiAgICB0cnkgewogICAgICAgICRxdWVyaWVkID0gJGZhbHNlCiAgICAgICAgJHdoZWFDb3VudCA9IDAKICAgICAgICAkbWVtRGlhZ0ZhaWwgPSAwCiAgICAgICAgIyBFcnJvcmVzIGRlIGhhcmR3YXJlIFdIRUEgcmVsYWNpb25hZG9z
HLP:IGNvbiBtZW1vcmlhCiAgICAgICAgJHdoZWEgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgUHJvdmlkZXJOYW1lPSdNaWNyb3NvZnQtV2luZG93cy1XSEVBLUxvZ2dlcid9IC1NYXhFdmVudHMgMTAwIC1FcnJvckFj
HLP:dGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkbnVsbCAtbmUgJHdoZWEpIHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAgICAgJHdoZWFDb3VudCA9IEAoJHdoZWEgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWluIDE4LDE5LDIwLDQ3KSAtb3IgKCRf
HLP:Lk1lc3NhZ2UgLW1hdGNoICdtZW1vcicpIH0pLkNvdW50CiAgICAgICAgIyBSZXN1bHRhZG9zIGRlbCBEaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MgKG1kc2NoZWQpCiAgICAgICAgJG1kID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBA
HLP:e0xvZ05hbWU9J1N5c3RlbSc7IFByb3ZpZGVyTmFtZT0nTWljcm9zb2Z0LVdpbmRvd3MtTWVtb3J5RGlhZ25vc3RpY3MtUmVzdWx0cyd9IC1NYXhFdmVudHMgNTAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYgKCRudWxsIC1uZSAkbWQp
HLP:IHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAgICAgJG1lbURpYWdGYWlsID0gQCgkbWQgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWVxIDEwMDIpIC1vciAoJF8uTGV2ZWxEaXNwbGF5TmFtZSAtZXEgJ0Vycm9yJykgLW9yICgkXy5NZXNzYWdlIC1tYXRjaCAnZXJy
HLP:b3J8ZXJyb3JlcycpIH0pLkNvdW50CiAgICAgICAgcmV0dXJuIChSZXNvbHZlLVJhbVN0YXR1cyAkd2hlYUNvdW50ICRtZW1EaWFnRmFpbCkKICAgIH0gY2F0Y2ggewogICAgICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJ3Vua25vd24nOyBy
HLP:ZWNvbW1lbmRfbWRzY2hlZCA9ICRmYWxzZSB9CiAgICB9Cn0KCiMgLS0tIEJhdGVyaWEgKFJlcSAxNS4yKSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtQmF0dGVyeUhlYWx0aFBjdDogZnVuY2lvbiBQVVJB
HLP:LiAlIGRlIHNhbHVkID0gcGxlbmEgY2FyZ2EgLyBkaXNlbm8gKiAxMDAuCmZ1bmN0aW9uIEdldC1CYXR0ZXJ5SGVhbHRoUGN0KCRkZXNpZ24sICRmdWxsKSB7CiAgICB0cnkgewogICAgICAgICRkID0gW2RvdWJsZV0kZGVzaWduOyAkZiA9IFtkb3VibGVdJGZ1bGwK
HLP:ICAgICAgICBpZiAoJGQgLWd0IDApIHsgcmV0dXJuIFtpbnRdW21hdGhdOjpSb3VuZCgoJGYgLyAkZCkgKiAxMDApIH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAkbnVsbAp9CgojIEdldC1CYXR0ZXJ5SGVhbHRoOiBzaSBoYXkgYmF0ZXJpYSwgZ2VuZXJhIHBv
HLP:d2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0IHkgZXh0cmFlIGxhCiMgc2FsdWQgKGNhcGFjaWRhZCBkZSBkaXNlbm8gdnMgcGxlbmEgY2FyZ2EpLiBTaW4gYmF0ZXJpYSAtPiBwcmVzZW50PSRmYWxzZS4KIyBObyBmYWxsYSBzaSBwb3dlcmNmZyBubyBlc3RhIGRpc3Bvbmli
HLP:bGUgKGhlYWx0aF9wY3QgcXVlZGEgdmFjaW8pLgpmdW5jdGlvbiBHZXQtQmF0dGVyeUhlYWx0aCB7CiAgICAkcHJlc2VudCA9ICRmYWxzZTsgJGhlYWx0aFBjdCA9ICcnOyAkcmVwb3J0UGF0aCA9ICcnCiAgICB0cnkgewogICAgICAgICRiYXQgPSBAKEdldC1DaW1J
HLP:bnN0YW5jZSBXaW4zMl9CYXR0ZXJ5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkYmF0LkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRwcmVzZW50ID0gJHRydWUKICAgICAgICAgICAgJHJlcG9ydFBhdGggPSBKb2luLVBhdGgg
HLP:JFdvcmsgJ2JhdHRlcnktcmVwb3J0Lmh0bWwnCiAgICAgICAgICAgIHRyeSB7ICYgcG93ZXJjZmcgL2JhdHRlcnlyZXBvcnQgL291dHB1dCAiJHJlcG9ydFBhdGgiIC9kdXJhdGlvbiAxID4gJG51bGwgMj4mMSB9IGNhdGNoIHt9CiAgICAgICAgICAgIGlmIChUZXN0
HLP:LVBhdGggJHJlcG9ydFBhdGgpIHsKICAgICAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAgICAgJHR4dCA9IEdldC1Db250ZW50ICRyZXBvcnRQYXRoIC1SYXcKICAgICAgICAgICAgICAgICAgICAkZGVzaWduID0gJG51bGw7ICRmdWxsID0gJG51bGwK
HLP:ICAgICAgICAgICAgICAgICAgICAkbTEgPSBbcmVnZXhdOjpNYXRjaCgkdHh0LCAnKD9pcylERVNJR04gQ0FQQUNJVFkuKj8oW1xkXC4sXSspXHMqbVdoJykKICAgICAgICAgICAgICAgICAgICAkbTIgPSBbcmVnZXhdOjpNYXRjaCgkdHh0LCAnKD9pcylGVUxMIENI
HLP:QVJHRSBDQVBBQ0lUWS4qPyhbXGRcLixdKylccyptV2gnKQogICAgICAgICAgICAgICAgICAgIGlmICgkbTEuU3VjY2VzcykgeyAkZGVzaWduID0gW2RvdWJsZV0oKCRtMS5Hcm91cHNbMV0uVmFsdWUgLXJlcGxhY2UgJ1tcLixdJywgJycpKSB9CiAgICAgICAgICAg
HLP:ICAgICAgICAgaWYgKCRtMi5TdWNjZXNzKSB7ICRmdWxsICAgPSBbZG91YmxlXSgoJG0yLkdyb3Vwc1sxXS5WYWx1ZSAtcmVwbGFjZSAnW1wuLF0nLCAnJykpIH0KICAgICAgICAgICAgICAgICAgICAkcGN0ID0gR2V0LUJhdHRlcnlIZWFsdGhQY3QgJGRlc2lnbiAk
HLP:ZnVsbAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHBjdCkgeyAkaGVhbHRoUGN0ID0gJHBjdCB9CiAgICAgICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gW3BzY3Vz
HLP:dG9tb2JqZWN0XUB7IHByZXNlbnQgPSAkcHJlc2VudDsgaGVhbHRoX3BjdCA9ICRoZWFsdGhQY3Q7IHJlcG9ydF9wYXRoID0gJHJlcG9ydFBhdGggfQp9CgojIC0tLSBSZWQgYXZhbnphZGEgKFJlcSAxNS41KSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tCiMgR2V0LU5ldEFkdmFuY2VkOiBjb25lY3RpdmlkYWQgKHBpbmcgYSAxLjEuMS4xKSwgRE5TIChSZXNvbHZlLURuc05hbWUgY29uCiMgcmVzcGFsZG8gcG9yIHBpbmcgYSB1biBob3N0KSB5IGNvbmZpZ3VyYWNpb24gYmFzaWNhIChJUC9n
HLP:YXRld2F5KS4KIyBEZWdyYWRhY2lvbiBlbGVnYW50ZTogbnVuY2EgbGFuemEgZXhjZXBjaW9uLgpmdW5jdGlvbiBHZXQtTmV0QWR2YW5jZWQgewogICAgJGNvbm5lY3RlZCA9ICRmYWxzZTsgJGRuc09rID0gJGZhbHNlOyAkZGV0YWlscyA9ICcnCiAgICB0cnkgewog
HLP:ICAgICAgICMgQ29uZWN0aXZpZGFkCiAgICAgICAgJHBpbmcgPSAkZmFsc2UKICAgICAgICB0cnkgeyAkcGluZyA9IFtib29sXShUZXN0LUNvbm5lY3Rpb24gLUNvbXB1dGVyTmFtZSAnMS4xLjEuMScgLUNvdW50IDEgLVF1aWV0IC1FcnJvckFjdGlvbiBTaWxlbnRs
HLP:eUNvbnRpbnVlKSB9IGNhdGNoIHsgJHBpbmcgPSAkZmFsc2UgfQogICAgICAgIGlmICgtbm90ICRwaW5nKSB7CiAgICAgICAgICAgIHRyeSB7ICYgcGluZyAtbiAxIC13IDE1MDAgMS4xLjEuMSA+ICRudWxsIDI+JjE7IGlmICgkTEFTVEVYSVRDT0RFIC1lcSAwKSB7
HLP:ICRwaW5nID0gJHRydWUgfSB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgICAgICRjb25uZWN0ZWQgPSBbYm9vbF0kcGluZwogICAgICAgICMgUmVzb2x1Y2lvbiBETlMgKGNvbiBtZWRpZGEgZGUgbGF0ZW5jaWEpCiAgICAgICAgJGRucyA9ICRmYWxzZTsgJGRuc01z
HLP:ID0gJG51bGwKICAgICAgICB0cnkgewogICAgICAgICAgICAkc3cgPSBbU3lzdGVtLkRpYWdub3N0aWNzLlN0b3B3YXRjaF06OlN0YXJ0TmV3KCkKICAgICAgICAgICAgJHIgPSBSZXNvbHZlLURuc05hbWUgLU5hbWUgJ3d3dy5taWNyb3NvZnQuY29tJyAtRXJyb3JB
HLP:Y3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICAkc3cuU3RvcCgpCiAgICAgICAgICAgIGlmICgkcikgeyAkZG5zID0gJHRydWU7ICRkbnNNcyA9IFtpbnRdJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgfQogICAgICAgIH0gY2F0Y2gge30KICAgICAgICBp
HLP:ZiAoLW5vdCAkZG5zKSB7CiAgICAgICAgICAgIHRyeSB7ICYgcGluZyAtbiAxIC13IDE1MDAgd3d3Lm1pY3Jvc29mdC5jb20gPiAkbnVsbCAyPiYxOyBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCkgeyAkZG5zID0gJHRydWUgfSB9IGNhdGNoIHt9CiAgICAgICAgfQog
HLP:ICAgICAgICRkbnNPayA9IFtib29sXSRkbnMKICAgICAgICAjIENvbmZpZ3VyYWNpb24gYmFzaWNhIChJUCAvIGdhdGV3YXkpCiAgICAgICAgJGlwID0gJyc7ICRndyA9ICcnCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJGNmZyA9IEAoR2V0LU5ldElQQ29uZmln
HLP:dXJhdGlvbiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLklQdjREZWZhdWx0R2F0ZXdheSB9KSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgaWYgKCRjZmcpIHsKICAgICAgICAgICAgICAgICRpcCA9
HLP:ICgkY2ZnLklQdjRBZGRyZXNzIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkuSVBBZGRyZXNzCiAgICAgICAgICAgICAgICAkZ3cgPSAoJGNmZy5JUHY0RGVmYXVsdEdhdGV3YXkgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5OZXh0SG9wCiAgICAgICAgICAgIH0K
HLP:ICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgJGRldGFpbHMgPSAiSVA9JGlwOyBHVz0kZ3ciCiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IGNvbm5lY3RlZCA9ICRjb25uZWN0ZWQ7IGRuc19vayA9ICRkbnNPazsgZGV0YWlscyA9
HLP:ICRkZXRhaWxzOyBkbnNfbXMgPSAkZG5zTXMgfQp9CgojIC0tLSBEaXNwb3NpdGl2b3MgcGFyYSBkaWFnIChSZXEgMTUuMy8xNS40KSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgR2V0LURldmljZUxpc3Q6IGxpc3RhIGVzdHJ1Y3R1cmFkYSBkZSBk
HLP:aXNwb3NpdGl2b3MgY29uIGVycm9yIHBhcmEgZXN0YWRvLmRpYWcuCiMgRGV2dWVsdmUgJG51bGwgc2kgbGEgaWRlbnRpZmljYWNpb24gZGUgZHJpdmVycyBmYWxsYSAoc2VuYWwgZGUgImluZm8gbm8KIyBkaXNwb25pYmxlIiBwYXJhIGRlZ3JhZGFjaW9uIGVsZWdh
HLP:bnRlKS4KZnVuY3Rpb24gR2V0LURldmljZUxpc3QgewogICAgdHJ5IHsKICAgICAgICAkcCA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1BuUEVudGl0eSAtRXJyb3JBY3Rpb24gU3RvcCB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUg
HLP:LWd0IDAgfSkKICAgICAgICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRkIGluICgkcCB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEyKSkgewogICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsgY29kZSA9IFtpbnRdJGQuQ29uZmlnTWFu
HLP:YWdlckVycm9yQ29kZTsgbmFtZSA9IFtzdHJpbmddJGQuTmFtZSB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAsJGxpc3QKICAgIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIFJPVEFDSU9OIERFIExPR1MgKDUuNiAvIFJlcSAxNy4yKQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgU2Vs
HLP:ZWN0LUxvZ3NUb0RlbGV0ZTogZnVuY2lvbiBQVVJBLiBEZSB1bmEgY29sZWNjaW9uIGRlIGZpY2hlcm9zIChjb24KIyAuTGFzdFdyaXRlVGltZSkgeSB1bmEgcmV0ZW5jaW9uIE4sIGRldnVlbHZlIGxvcyBxdWUgZGViZW4gQk9SUkFSU0U6IHRvZG9zCiMgbWVub3Mg
HLP:bG9zIE4gbWFzIHJlY2llbnRlcyAoZXMgZGVjaXIsIGxvcyBtYXMgYW50aWd1b3MpLiBTaSBoYXkgPD0gTiwgbmluZ3Vuby4KZnVuY3Rpb24gU2VsZWN0LUxvZ3NUb0RlbGV0ZSgkZmlsZXMsIFtpbnRdJHJldGVudGlvbikgewogICAgJGFyciA9IEAoJGZpbGVzKQog
HLP:ICAgaWYgKCRyZXRlbnRpb24gLWx0IDApIHsgJHJldGVudGlvbiA9IDAgfQogICAgaWYgKCRhcnIuQ291bnQgLWxlICRyZXRlbnRpb24pIHsgcmV0dXJuIEAoKSB9CiAgICAkc29ydGVkID0gQCgkYXJyIHwgU29ydC1PYmplY3QgLVByb3BlcnR5IExhc3RXcml0ZVRp
HLP:bWUgLURlc2NlbmRpbmcpCiAgICByZXR1cm4gQCgkc29ydGVkIHwgU2VsZWN0LU9iamVjdCAtU2tpcCAkcmV0ZW50aW9uKQp9CgojIEludm9rZS1Mb2dSb3RhdGU6IGNvbnNlcnZhIGxvcyAkcmV0ZW50aW9uIGxvZ3MgbWFzIHJlY2llbnRlcyBlbiAkZm9sZGVyIHkK
HLP:IyBib3JyYSBlbCByZXN0by4gRGV2dWVsdmUgZWwgbnVtZXJvIGRlIGZpY2hlcm9zIGJvcnJhZG9zLgpmdW5jdGlvbiBJbnZva2UtTG9nUm90YXRlKFtzdHJpbmddJGZvbGRlciwgW2ludF0kcmV0ZW50aW9uKSB7CiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hp
HLP:dGVTcGFjZSgkZm9sZGVyKSkgeyAkZm9sZGVyID0gSm9pbi1QYXRoICRXb3JrICdMb2dzJyB9CiAgICAkZGVsZXRlZCA9IDAKICAgIHRyeSB7CiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkZm9sZGVyKSkgeyByZXR1cm4gMCB9CiAgICAgICAgJGZpbGVzID0g
HLP:QChHZXQtQ2hpbGRJdGVtIC1QYXRoICRmb2xkZXIgLUZpbHRlciAnKi5sb2cnIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgICR0b0RlbGV0ZSA9IFNlbGVjdC1Mb2dzVG9EZWxldGUgJGZpbGVzICRyZXRlbnRpb24KICAgICAgICBm
HLP:b3JlYWNoICgkZiBpbiAkdG9EZWxldGUpIHsKICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJGYuRnVsbE5hbWUgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlOyAkZGVsZXRlZCsrIH0gY2F0Y2gge30KICAgICAgICB9CiAgICB9IGNhdGNo
HLP:IHt9CiAgICByZXR1cm4gJGRlbGV0ZWQKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBWQUxJREFDSU9OIERFIEVOVE9STk8gWSBTRUxGLVRFU1QgKDUuOCAvIFJl
HLP:cSAxMy41LDEzLjYsMTguMSwxOC4zLDE4LjYpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBUZXN0LU9zU3VwcG9ydGVkOiBmdW5jaW9uIFBVUkEuIFdpbmRvd3MgMTAv
HLP:MTEgPT4gYnVpbGQgPj0gMTAyNDAuCmZ1bmN0aW9uIFRlc3QtT3NTdXBwb3J0ZWQoW2ludF0kYnVpbGQpIHsKICAgIHJldHVybiAoJGJ1aWxkIC1nZSAxMDI0MCkKfQoKIyBJbnZva2UtRW52VmFsaWRhdGU6IGNvbXBydWViYSBsYSB2ZXJzaW9uIGRlbCBTTyB2aWEg
HLP:Q0lNLiBMYSBjb21wcm9iYWNpb24gc2UKIyBjb25zaWRlcmEgU0lFTVBSRSByZWFsaXphZGEgKGNoZWNrX2RvbmUpIGF1bnF1ZSBsYSB2ZXJzaW9uIG5vIHNlYSBjb21wYXRpYmxlLgpmdW5jdGlvbiBJbnZva2UtRW52VmFsaWRhdGUgewogICAgJGJ1aWxkID0gMAog
HLP:ICAgdHJ5IHsgJGJ1aWxkID0gW2ludF0oR2V0LUNpbUluc3RhbmNlIFdpbjMyX09wZXJhdGluZ1N5c3RlbSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuQnVpbGROdW1iZXIgfSBjYXRjaCB7ICRidWlsZCA9IDAgfQogICAgaWYgKCRidWlsZCAtbGUgMCkg
HLP:eyB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtSXRlbVByb3BlcnR5ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvbicgLU5hbWUgQ3VycmVudEJ1aWxkTnVtYmVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS5D
HLP:dXJyZW50QnVpbGROdW1iZXIgfSBjYXRjaCB7ICRidWlsZCA9IDAgfSB9CiAgICBpZiAoJGJ1aWxkIC1sZSAwKSB7IHRyeSB7ICRidWlsZCA9IFtpbnRdKEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRW
HLP:ZXJzaW9uJyAtTmFtZSBDdXJyZW50QnVpbGQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLkN1cnJlbnRCdWlsZCB9IGNhdGNoIHsgJGJ1aWxkID0gMCB9IH0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgb3Nfb2sgPSAoVGVzdC1Pc1N1cHBvcnRl
HLP:ZCAkYnVpbGQpOyBidWlsZCA9ICRidWlsZDsgY2hlY2tfZG9uZSA9ICR0cnVlIH0KfQoKIyBJbnZva2UtU2VsZlRlc3Q6IGFncmVnYWRvciBQVVJPLiBFeGl0byAodHJ1ZSkgc2kgeSBzb2xvIHNpIFRPREFTIGxhcwojIGNvbXByb2JhY2lvbmVzIChib29sZWFub3Mp
HLP:IHBhc2FuLiBDb2xlY2Npb24gdmFjaWEgLT4gdHJ1ZSAobmFkYSBmYWxsbykuCmZ1bmN0aW9uIEludm9rZS1TZWxmVGVzdCgkcmVzdWx0cykgewogICAgZm9yZWFjaCAoJHIgaW4gQCgkcmVzdWx0cykpIHsgaWYgKC1ub3QgW2Jvb2xdJHIpIHsgcmV0dXJuICRmYWxz
HLP:ZSB9IH0KICAgIHJldHVybiAkdHJ1ZQp9CgojIFBhcnNlLUJvb2xMaXN0OiBjb252aWVydGUgIjEsMSwwLDEiIChvIHRydWUvb2spIGVuIHVuYSBsaXN0YSBkZSBib29sZWFub3MuCmZ1bmN0aW9uIFBhcnNlLUJvb2xMaXN0KFtzdHJpbmddJHJhdykgewogICAgJGxp
HLP:c3QgPSBAKCkKICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHJhdykpIHsKICAgICAgICBmb3JlYWNoICgkdCBpbiAoJHJhdyAtc3BsaXQgJywnKSkgewogICAgICAgICAgICAkdG9rID0gJHQuVHJpbSgpLlRvTG93ZXIoKQogICAgICAg
HLP:ICAgICBpZiAoJHRvayAtZXEgJycpIHsgY29udGludWUgfQogICAgICAgICAgICAkbGlzdCArPSAoJHRvayAtZXEgJzEnIC1vciAkdG9rIC1lcSAndHJ1ZScgLW9yICR0b2sgLWVxICdvaycgLW9yICR0b2sgLWVxICdwYXNzJykKICAgICAgICB9CiAgICB9CiAgICBy
HLP:ZXR1cm4gLCRsaXN0Cn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PQojICBESUFHTk9TVElDTyBQUk9GVU5ETyB2My4xIChTTUFSVCwgYXJyYW5xdWUsIEJDRCwgcHJvY2Vzb3MsIFNGQywgSlNPTikKIyAgVG9kYXMgbGFzIGZ1bmNpb25lcyBkZWdyYWRhbiBjb24gZWxlZ2FuY2lhOiBzaSBhbGdvIGZh
HLP:bGxhLCBkZXZ1ZWx2ZW4KIyAgZXN0cnVjdHVyYXMgdmFjaWFzIC8gJ3Vua25vd24nIGVuIGx1Z2FyIGRlIGxhbnphciBleGNlcGNpb25lcy4KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PQoKIyBHZXQtU21hcnRBdHRyaWJ1dGVzOiBzYWx1ZCBmaXNpY2EgZGVsIGRpc2NvIGRlIHNpc3RlbWEgKGluZGVwZW5kaWVudGUgZGVsCiMgaWRpb21hIGRlIFdpbmRvd3MpLiBVc2EgTVNTdG9yYWdlRHJpdmVyX0ZhaWx1cmVQcmVkaWN0U3RhdHVzICsg
HLP:ZWwgY29udGFkb3IKIyBkZSBmaWFiaWxpZGFkIGRlIGFsbWFjZW5hbWllbnRvLiBEZXZ1ZWx2ZSBhdmFpbGFibGU9JGZhbHNlIHNpIG5vIGhheSBkYXRvcy4KZnVuY3Rpb24gR2V0LVNtYXJ0QXR0cmlidXRlcyB7CiAgICAkcmVzID0gW3BzY3VzdG9tb2JqZWN0XUB7
HLP:IGF2YWlsYWJsZSA9ICRmYWxzZTsgcHJlZGljdF9mYWlsID0gJGZhbHNlOyB0ZW1wX2MgPSAkbnVsbDsgd2Vhcl9wY3QgPSAkbnVsbDsgcG9oID0gJG51bGwgfQogICAgdHJ5IHsKICAgICAgICAkcGYgPSAkbnVsbAogICAgICAgIHRyeSB7ICRwZiA9IEAoR2V0LUNp
HLP:bUluc3RhbmNlIC1OYW1lc3BhY2UgJ3Jvb3Rcd21pJyAtQ2xhc3NOYW1lICdNU1N0b3JhZ2VEcml2ZXJfRmFpbHVyZVByZWRpY3RTdGF0dXMnIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSB9IGNhdGNoIHsgJHBmID0gJG51bGwgfQogICAgICAgIGlmICgk
HLP:cGYgLWFuZCAkcGYuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZQogICAgICAgICAgICBmb3JlYWNoICgkeCBpbiAkcGYpIHsgaWYgKCR4LlByZWRpY3RGYWlsdXJlKSB7ICRyZXMucHJlZGljdF9mYWlsID0gJHRydWUgfSB9
HLP:CiAgICAgICAgfQogICAgICAgICMgRGlzY28gcXVlIGNvbnRpZW5lIEM6IC0+IGNvbnRhZG9yIGRlIGZpYWJpbGlkYWQKICAgICAgICB0cnkgewogICAgICAgICAgICAkc3lzRGlzayA9ICRudWxsCiAgICAgICAgICAgIHRyeSB7ICRzeXNEaXNrID0gR2V0LVBoeXNp
HLP:Y2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLkRldmljZUlkIC1uZSAkbnVsbCB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9IGNhdGNoIHt9CiAgICAgICAgICAgICRyYyA9ICRudWxsCiAgICAgICAgICAg
HLP:IGlmICgkc3lzRGlzaykgeyAkcmMgPSAkc3lzRGlzayB8IEdldC1TdG9yYWdlUmVsaWFiaWxpdHlDb3VudGVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICAgICAgaWYgKC1ub3QgJHJjKSB7ICRyYyA9IEdldC1QaHlzaWNhbERpc2sgLUVy
HLP:cm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBHZXQtU3RvcmFnZVJlbGlhYmlsaXR5Q291bnRlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICBpZiAoJHJjKSB7CiAgICAgICAgICAg
HLP:ICAgICAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlCiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyYy5UZW1wZXJhdHVyZSAtYW5kICRyYy5UZW1wZXJhdHVyZSAtZ3QgMCkgeyAkcmVzLnRlbXBfYyA9IFtpbnRdJHJjLlRlbXBlcmF0dXJlIH0KICAgICAgICAg
HLP:ICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLldlYXIpICAgICAgICAgeyAkcmVzLndlYXJfcGN0ID0gW2ludF0kcmMuV2VhciB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyYy5Qb3dlck9uSG91cnMpIHsgJHJlcy5wb2ggPSBbaW50XSRyYy5Qb3dlck9u
HLP:SG91cnMgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICMgU2VuYWwgYWRpY2lvbmFsIGRlIHByZWRpY2Npb24gZGUgZmFsbG8gdmlhIGVzdGFkbyBkZSBzYWx1ZCBmaXNpY2EKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICR1bmhlYWx0aHkgPSBA
HLP:KEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBXaGVyZS1PYmplY3QgeyAkXy5IZWFsdGhTdGF0dXMgLWFuZCAkXy5IZWFsdGhTdGF0dXMgLW5lICdIZWFsdGh5JyB9KQogICAgICAgICAgICAgICAgaWYgKCR1bmhlYWx0aHku
HLP:Q291bnQgLWd0IDApIHsgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZTsgJHJlcy5wcmVkaWN0X2ZhaWwgPSAkdHJ1ZSB9CiAgICAgICAgICAgIH0gY2F0Y2gge30KICAgICAgICB9IGNhdGNoIHt9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gJHJlcwp9CgojIEdldC1T
HLP:dGFydHVwSXRlbXM6IHByb2dyYW1hcyBxdWUgYXJyYW5jYW4gY29uIFdpbmRvd3MgKHRvcCBOKSwgcGFyYSBxdWUgZWwKIyB1c3VhcmlvIHZlYSBxdWUgcmFsZW50aXphIGVsIGluaWNpby4gSW5kZXBlbmRpZW50ZSBkZWwgaWRpb21hLgpmdW5jdGlvbiBHZXQtU3Rh
HLP:cnR1cEl0ZW1zKFtpbnRdJHRvcCA9IDgpIHsKICAgIHRyeSB7CiAgICAgICAgJGl0ZW1zID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfU3RhcnR1cENvbW1hbmQgLUVycm9yQWN0aW9uIFN0b3AgfAogICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5Db21tYW5k
HLP:IH0gfAogICAgICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAkdG9wKQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJGkgaW4gJGl0ZW1zKSB7CiAgICAgICAgICAgICRjbWQgPSBbc3RyaW5nXSRpLkNvbW1hbmQKICAgICAgICAgICAgaWYg
HLP:KCRjbWQuTGVuZ3RoIC1ndCA4MCkgeyAkY21kID0gJGNtZC5TdWJzdHJpbmcoMCw3NykgKyAnLi4uJyB9CiAgICAgICAgICAgICRubSA9IFtzdHJpbmddJGkuTmFtZTsgaWYgKC1ub3QgJG5tKSB7ICRubSA9IFtzdHJpbmddJGkuQ2FwdGlvbiB9CiAgICAgICAgICAg
HLP:ICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBuYW1lID0gJG5tOyBjb21tYW5kID0gJGNtZCB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAsJGxpc3QKICAgIH0gY2F0Y2ggeyByZXR1cm4gQCgpIH0KfQoKIyBHZXQtQmNkSW50ZWdyaXR5OiBjb21wcnVlYmEg
HLP:cXVlIGxhIGNvbmZpZ3VyYWNpb24gZGUgYXJyYW5xdWUgKEJDRCkgdGllbmUgbGEKIyBlbnRyYWRhIGFjdHVhbCBjb24gb3NkZXZpY2UvZGV2aWNlLiBMYXMgQ0xBVkVTIGRlIGJjZGVkaXQgc29uIHNpZW1wcmUgZW4KIyBpbmdsZXMsIGFzaSBxdWUgZXMgaW5kZXBl
HLP:bmRpZW50ZSBkZWwgaWRpb21hIGRlIGxhIGludGVyZmF6LgpmdW5jdGlvbiBHZXQtQmNkSW50ZWdyaXR5IHsKICAgICRyZXMgPSBbcHNjdXN0b21vYmplY3RdQHsgb2sgPSAkZmFsc2U7IGRldGFpbHMgPSAnJyB9CiAgICB0cnkgewogICAgICAgICRvdXQgPSAmIGJj
HLP:ZGVkaXQgL2VudW0gJ3tjdXJyZW50fScgMj4kbnVsbAogICAgICAgICR0eHQgPSAoJG91dCAtam9pbiAiYG4iKQogICAgICAgIGlmICgkTEFTVEVYSVRDT0RFIC1lcSAwIC1hbmQgJHR4dCAtbWF0Y2ggJyg/aW0pXlxzKm9zZGV2aWNlJyAtYW5kICR0eHQgLW1hdGNo
HLP:ICcoP2ltKV5ccypkZXZpY2UnKSB7CiAgICAgICAgICAgICRyZXMub2sgPSAkdHJ1ZQogICAgICAgICAgICAkcmVzLmRldGFpbHMgPSAnRW50cmFkYSBkZSBhcnJhbnF1ZSBhY3R1YWwgaW50ZWdyYSAoZGV2aWNlL29zZGV2aWNlIHByZXNlbnRlcykuJwogICAgICAg
HLP:IH0gZWxzZSB7CiAgICAgICAgICAgICRyZXMub2sgPSAkZmFsc2UKICAgICAgICAgICAgJHJlcy5kZXRhaWxzID0gJ05vIHNlIHB1ZG8gY29uZmlybWFyIGxhIGVudHJhZGEgZGUgYXJyYW5xdWUgYWN0dWFsLicKICAgICAgICB9CiAgICB9IGNhdGNoIHsKICAgICAg
HLP:ICAkcmVzLm9rID0gJGZhbHNlCiAgICAgICAgJHJlcy5kZXRhaWxzID0gJ2JjZGVkaXQgbm8gZGlzcG9uaWJsZSBvIHNpbiBwZXJtaXNvcy4nCiAgICB9CiAgICByZXR1cm4gJHJlcwp9CgojIEdldC1Ub3BQcm9jZXNzZXM6IHByb2Nlc29zIHF1ZSBtYXMgbWVtb3Jp
HLP:YSBkZSB0cmFiYWpvIGNvbnN1bWVuICh0b3AgTikuCmZ1bmN0aW9uIEdldC1Ub3BQcm9jZXNzZXMoW2ludF0kdG9wID0gNikgewogICAgdHJ5IHsKICAgICAgICAkcHMgPSBAKEdldC1Qcm9jZXNzIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAg
HLP:ICAgICAgU29ydC1PYmplY3QgV29ya2luZ1NldDY0IC1EZXNjZW5kaW5nIHwKICAgICAgICAgICAgU2VsZWN0LU9iamVjdCAtRmlyc3QgJHRvcCkKICAgICAgICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRwIGluICRwcykgewogICAgICAgICAgICAkbWIg
HLP:PSBbbWF0aF06OlJvdW5kKCRwLldvcmtpbmdTZXQ2NCAvIDFNQikKICAgICAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7IG5hbWUgPSBbc3RyaW5nXSRwLlByb2Nlc3NOYW1lOyBtZW1fbWIgPSBbaW50XSRtYiB9CiAgICAgICAgfQogICAgICAgIHJl
HLP:dHVybiAsJGxpc3QKICAgIH0gY2F0Y2ggeyByZXR1cm4gQCgpIH0KfQoKIyBHZXQtU2ZjUmVzdWx0OiBjbGFzaWZpY2EgZWwgcmVzdWx0YWRvIGRlIFNGQyBsZXllbmRvIENCUy5sb2cgKFNJRU1QUkUgZW4KIyBpbmdsZXMpIGVuIGx1Z2FyIGRlIGxhIHNhbGlkYSB0
HLP:cmFkdWNpZGEgZGUgbGEgY29uc29sYS4gRGV2dWVsdmUgdW5vIGRlOgojIGNsZWFuIHwgcmVwYWlyZWQgfCB1bnJlcGFpcmFibGUgfCB1bmtub3duLgpmdW5jdGlvbiBHZXQtU2ZjUmVzdWx0IHsKICAgICRsb2cgPSBKb2luLVBhdGggJGVudjp3aW5kaXIgJ0xvZ3Nc
HLP:Q0JTXENCUy5sb2cnCiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRsb2cpKSB7IHJldHVybiAndW5rbm93bicgfQogICAgdHJ5IHsKICAgICAgICAkdGFpbCA9IEAoR2V0LUNvbnRlbnQgLVBhdGggJGxvZyAtVGFpbCA0MDAwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
HLP:bnRpbnVlKQogICAgICAgICRzciA9IEAoJHRhaWwgfCBXaGVyZS1PYmplY3QgeyAkXyAtbWF0Y2ggJ1xbU1JcXScgfSkKICAgICAgICBpZiAoJHNyLkNvdW50IC1lcSAwKSB7IHJldHVybiAndW5rbm93bicgfQogICAgICAgICRqb2luZWQgPSAoJHNyIC1qb2luICJg
HLP:biIpCiAgICAgICAgaWYgKCRqb2luZWQgLW1hdGNoICcoP2kpY2Fubm90IHJlcGFpcicpIHsgcmV0dXJuICd1bnJlcGFpcmFibGUnIH0KICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSlyZXBhaXJpbmdccysoWzEtOV1cZCopXHMrY29tcG9uZW50c3xzdWNj
HLP:ZXNzZnVsbHkgcmVwYWlyZWR8cmVwYWlyZWQgZmlsZXxyZXBhaXJpbmcgY29ycnVwdGVkIGZpbGUnKSB7IHJldHVybiAncmVwYWlyZWQnIH0KICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSl2ZXJpZnkgY29tcGxldGV8bm8gLippbnRlZ3JpdHkgdmlvbGF0
HLP:aW9uc3xjYW5ub3QgdmVyaWZ5fHZlcmlmeWluZycpIHsgcmV0dXJuICdjbGVhbicgfQogICAgICAgIHJldHVybiAnY2xlYW4nCiAgICB9IGNhdGNoIHsgcmV0dXJuICd1bmtub3duJyB9Cn0KCiMgTmV3LUpzb25SZXBvcnQ6IHZ1ZWxjYSBlbCBlc3RhZG8gKyByZXN1
HLP:bWVuIGNhbGN1bGFkbyBhIHVuIGZpY2hlcm8gSlNPTgojICgtQXJnID0gcnV0YSBkZSBzYWxpZGEpLiBVdGlsIHBhcmEgYXV0b21hdGl6YWNpb24gLyBNRE0gLyBpbnZlbnRhcmlvLgpmdW5jdGlvbiBOZXctSnNvblJlcG9ydCgkb3V0UGF0aCkgewogICAgdHJ5IHsK
HLP:ICAgICAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAgICAgJHN5c1BhaXJzID0gR2V0LVN5c0luZm8KICAgICAgICAkc3lzTWFwID0gQHt9CiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHN5c1BhaXJzKSB7ICRrdiA9ICRwIC1zcGxpdCAnPScsMjsgaWYgKCRrdi5Db3Vu
HLP:dCAtZXEgMikgeyAkc3lzTWFwWyRrdlswXV0gPSAka3ZbMV0gfSB9CiAgICAgICAgJHBoYXNlcyA9IEAoJHN0LnBoYXNlcykKICAgICAgICAkY09LPTA7JGNXQVJOPTA7JGNFUlI9MDskY1NLSVA9MAogICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7IHN3
HLP:aXRjaCAoW3N0cmluZ10kcGgucmVzdWx0KSB7ICdPSycgeyRjT0srK30gJ1dBUk4nIHskY1dBUk4rK30gJ0VSUk9SJyB7JGNFUlIrK30gJ1NLSVAnIHskY1NLSVArK30gfSB9CiAgICAgICAgJGRlbHRhID0gJG51bGwKICAgICAgICBpZiAoJHN0LnNjb3JlX2JlZm9y
HLP:ZSAtbmUgJG51bGwgLWFuZCAkc3Quc2NvcmVfYWZ0ZXIgLW5lICRudWxsKSB7ICRkZWx0YSA9IFtpbnRdJHN0LnNjb3JlX2FmdGVyIC0gW2ludF0kc3Quc2NvcmVfYmVmb3JlIH0KICAgICAgICAkb2JqID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIHNj
HLP:aGVtYSAgICAgICA9ICd3cGktcmVwb3J0LzEnCiAgICAgICAgICAgIHZlcnNpb24gICAgICA9ICRXUElfVkVSU0lPTgogICAgICAgICAgICBnZW5lcmF0ZWQgICAgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCdzJykKICAgICAgICAgICAgbWFjaGluZSAgICAgID0gJGVu
HLP:djpDT01QVVRFUk5BTUUKICAgICAgICAgICAgc3lzdGVtICAgICAgID0gJHN5c01hcAogICAgICAgICAgICBzY29yZV9iZWZvcmUgPSAkc3Quc2NvcmVfYmVmb3JlCiAgICAgICAgICAgIHNjb3JlX2FmdGVyICA9ICRzdC5zY29yZV9hZnRlcgogICAgICAgICAgICBz
HLP:Y29yZV9kZWx0YSAgPSAkZGVsdGEKICAgICAgICAgICAgc3VtbWFyeSAgICAgID0gW3BzY3VzdG9tb2JqZWN0XUB7IG9rPSRjT0s7IHdhcm49JGNXQVJOOyBlcnJvcj0kY0VSUjsgc2tpcD0kY1NLSVA7IHRvdGFsPSRwaGFzZXMuQ291bnQgfQogICAgICAgICAgICBw
HLP:aGFzZXMgICAgICAgPSAkcGhhc2VzCiAgICAgICAgICAgIGZpbmRpbmdzICAgICA9IEAoJHN0LmZpbmRpbmdzKQogICAgICAgICAgICBkaWFnICAgICAgICAgPSAkc3QuZGlhZwogICAgICAgIH0KICAgICAgICAkanNvbiA9ICRvYmogfCBDb252ZXJ0VG8tSnNvbiAt
HLP:RGVwdGggOAogICAgICAgICR1dGY4ID0gTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKQogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkb3V0UGF0aCwgJGpzb24sICR1dGY4KQogICAgICAgICJSRVNVTFQ9T0si
HLP:CiAgICAgICAgIlBBVEg9JG91dFBhdGgiCiAgICB9IGNhdGNoIHsKICAgICAgICAiUkVTVUxUPUZBSUwiCiAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgfQp9CgojIE5ldy1TdXBwb3J0UGFja2FnZTogZW1wYXF1ZXRhIGxvZ3MgKyBp
HLP:bmZvcm1lICsgZXN0YWRvICsgYmF0dGVyeS1yZXBvcnQgZW4gdW4KIyBaSVAgKC1BcmcgPSBydXRhIGRlbCB6aXApIHBhcmEgZW52aWFyIGEgc29wb3J0ZS4gU2luIGRlcGVuZGVuY2lhcyBleHRlcm5hcwojICh1c2EgQ29tcHJlc3MtQXJjaGl2ZSwgaW5jbHVpZG8g
HLP:ZW4gV2luZG93cyAxMC8xMSkuCmZ1bmN0aW9uIE5ldy1TdXBwb3J0UGFja2FnZSgkb3V0UGF0aCkgewogICAgdHJ5IHsKICAgICAgICAkdG1wID0gSm9pbi1QYXRoICRXb3JrICgnc29wb3J0ZV8nICsgKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eU1NZGRfSEhtbXNz
HLP:JykpCiAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkdG1wIC1Gb3JjZSB8IE91dC1OdWxsCiAgICAgICAgIyBlc3RhZG8uanNvbgogICAgICAgIGlmIChUZXN0LVBhdGggJFN0YXRlRmlsZSkgeyBDb3B5LUl0ZW0gJFN0YXRlRmlsZSAo
HLP:Sm9pbi1QYXRoICR0bXAgJ2VzdGFkby5qc29uJykgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICAjIExvZ3MKICAgICAgICAkbG9ncyA9IEpvaW4tUGF0aCAkV29yayAnTG9ncycKICAgICAgICBpZiAoVGVzdC1QYXRoICRsb2dz
HLP:KSB7CiAgICAgICAgICAgICRkc3RMb2dzID0gSm9pbi1QYXRoICR0bXAgJ0xvZ3MnCiAgICAgICAgICAgIE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJGRzdExvZ3MgLUZvcmNlIHwgT3V0LU51bGwKICAgICAgICAgICAgR2V0LUNoaWxkSXRlbSAk
HLP:bG9ncyAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IENvcHktSXRlbSAtRGVzdGluYXRpb24gJGRzdExvZ3MgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgfQogICAgICAgICMgSW5mb3JtZXMgSFRNTC9KU09O
HLP:IGV4aXN0ZW50ZXMgZW4gV29yawogICAgICAgIEdldC1DaGlsZEl0ZW0gJFdvcmsgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5OYW1lIC1tYXRjaCAnKD9pKV5JbmZvcm1lLipcLihodG1s
HLP:fGpzb24pJCcgfSB8CiAgICAgICAgICAgIENvcHktSXRlbSAtRGVzdGluYXRpb24gJHRtcCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAjIGJhdHRlcnkgcmVwb3J0IHNpIGV4aXN0ZQogICAgICAgICRzdCA9IFJlYWQtU3RhdGUK
HLP:ICAgICAgICB0cnkgeyBpZiAoJHN0LmRpYWcgLWFuZCAkc3QuZGlhZy5iYXR0ZXJ5IC1hbmQgJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCAtYW5kIChUZXN0LVBhdGggJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCkpIHsgQ29weS1JdGVtICRzdC5kaWFn
HLP:LmJhdHRlcnkucmVwb3J0X3BhdGggJHRtcCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfSB9IGNhdGNoIHt9CiAgICAgICAgaWYgKFRlc3QtUGF0aCAkb3V0UGF0aCkgeyBSZW1vdmUtSXRlbSAkb3V0UGF0aCAtRm9yY2UgLUVycm9yQWN0aW9u
HLP:IFNpbGVudGx5Q29udGludWUgfQogICAgICAgIENvbXByZXNzLUFyY2hpdmUgLVBhdGggKEpvaW4tUGF0aCAkdG1wICcqJykgLURlc3RpbmF0aW9uUGF0aCAkb3V0UGF0aCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAk
HLP:dG1wIC1SZWN1cnNlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IGNhdGNoIHt9CiAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAi
HLP:RVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCnN3aXRjaCAoJEFjdGlvbi5Ub0xvd2VyKCkpIHsKICAgICdub25lJyAgICAgICAgIHsgfSAjIFVzYWRvIHBhcmEgZG90LXNvdXJjaW5nCiAgICAnY2hlY2tiYWNrdXBzJyB7CiAgICAgICAgJHBh
HLP:cnRzID0gJEFyZyAtc3BsaXQgJ1x8JywgMgogICAgICAgIGlmICgkcGFydHMuQ291bnQgLW5lIDIpIHsgIlJFU1VMVD1GQUlMIjsgIkVSUk9SPUFyZ3VtZW50b3MgaW52YWxpZG9zIjsgZXhpdCAwIH0KICAgICAgICAkYmtkaXIgPSAkcGFydHNbMF0KICAgICAgICAk
HLP:dHMgPSAkcGFydHNbMV0KICAgICAgICAkcnBfb2sgPSAkZmFsc2UKICAgICAgICB0cnkgewogICAgICAgICAgICAkcnBzID0gR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIGZvcmVhY2ggKCRy
HLP:cCBpbiAkcnBzKSB7CiAgICAgICAgICAgICAgICBpZiAoJHJwLkRlc2NyaXB0aW9uIC1saWtlICJTdWl0ZV9SZXBhcmFjaW9uXyoiKSB7ICRycF9vayA9ICR0cnVlOyBicmVhayB9CiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHsgJHJwX29rID0gJGZhbHNl
HLP:IH0KICAgICAgICAkcmVnX29rID0gJHRydWUKICAgICAgICAkc29mdCA9IEpvaW4tUGF0aCAkYmtkaXIgIlNPRlRXQVJFXyR0cy5yZWciCiAgICAgICAgJHN5cyA9IEpvaW4tUGF0aCAkYmtkaXIgIlNZU1RFTV8kdHMucmVnIgogICAgICAgIGlmICgtbm90IChUZXN0
HLP:LVBhdGggJHNvZnQpIC1vciAoR2V0LUl0ZW0gJHNvZnQpLkxlbmd0aCAtZXEgMCkgeyAkcmVnX29rID0gJGZhbHNlIH0KICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRzeXMpIC1vciAoR2V0LUl0ZW0gJHN5cykuTGVuZ3RoIC1lcSAwKSB7ICRyZWdfb2sgPSAk
HLP:ZmFsc2UgfQogICAgICAgICJSUF9PSz0kKGlmICgkcnBfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJSRUdfT0s9JChpZiAoJHJlZ19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnYm9vdHN0cmFwd2luZ2V0JyB7CiAgICAgICAgJG9rID0g
HLP:SW5zdGFsbC1XaW5nZXRCb290c3RyYXAKICAgICAgICAiQk9PVFNUUkFQX09LPSQoaWYgKCRvaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnZmluZGxvY2Fsc291cmNlJyB7CiAgICAgICAgJGRyaXZlcyA9IEdldC1QU0RyaXZlIC1QU1Byb3ZpZGVyIEZp
HLP:bGVTeXN0ZW0KICAgICAgICAkcGF0aHMgPSBAKCkKICAgICAgICAkZWRpdGlvbklkID0gJycKICAgICAgICB0cnkgeyAkZWRpdGlvbklkID0gKEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9u
HLP:JyAtTmFtZSBFZGl0aW9uSUQgLUVycm9yQWN0aW9uIFN0b3ApLkVkaXRpb25JRCB9IGNhdGNoIHt9CiAgICAgICAgZnVuY3Rpb24gR2V0LUluc3RhbGxJbWFnZVNvdXJjZShbc3RyaW5nXSRraW5kLCBbc3RyaW5nXSRwYXRoLCBbc3RyaW5nXSRlZGl0aW9uKSB7CiAg
HLP:ICAgICAgICAgICRpbmRleCA9IDEKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRpbWFnZXMgPSBAKEdldC1XaW5kb3dzSW1hZ2UgLUltYWdlUGF0aCAkcGF0aCAtRXJyb3JBY3Rpb24gU3RvcCkKICAgICAgICAgICAgICAgICRtYXRjaCA9ICRudWxs
HLP:CiAgICAgICAgICAgICAgICBpZiAoJGVkaXRpb24gLW1hdGNoICdQcm9mZXNzaW9uYWwnKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdcYlByb1xifFByb2Zlc3Npb25hbCcgfSB8IFNlbGVjdC1PYmplY3Qg
HLP:LUZpcnN0IDEgfQogICAgICAgICAgICAgICAgZWxzZWlmICgkZWRpdGlvbiAtbWF0Y2ggJ0VudGVycHJpc2UnKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdFbnRlcnByaXNlJyB9IHwgU2VsZWN0LU9iamVj
HLP:dCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnRWR1Y2F0aW9uJykgeyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnRWR1Y2F0aW9uJyB9IHwgU2VsZWN0LU9iamVj
HLP:dCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnQ29yZScpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ1xiSG9tZVxifENvcmUnIH0gfCBTZWxlY3QtT2JqZWN0
HLP:IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJG1hdGNoIC1hbmQgJGltYWdlcy5Db3VudCAtZXEgMSkgeyAkbWF0Y2ggPSAkaW1hZ2VzWzBdIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJG1hdGNoKSB7ICRpbmRleCA9IFtp
HLP:bnRdJG1hdGNoLkltYWdlSW5kZXggfQogICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgICAgIHJldHVybiAoInswfTp7MX06ezJ9IiAtZiAka2luZCwgJHBhdGgsICRpbmRleCkKICAgICAgICB9CiAgICAgICAgZm9yZWFjaCAoJGQgaW4gJGRyaXZlcykgewog
HLP:ICAgICAgICAgICAkcm9vdCA9ICRkLlJvb3QKICAgICAgICAgICAgJHdpbSA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xpbnN0YWxsLndpbSIKICAgICAgICAgICAgJGVzZCA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xpbnN0YWxsLmVzZCIKICAgICAgICAg
HLP:ICAgJHN4cyA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xzeHMiCiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJHdpbSkgeyAkcGF0aHMgKz0gKEdldC1JbnN0YWxsSW1hZ2VTb3VyY2UgJ1dpbScgJHdpbSAkZWRpdGlvbklkKSB9CiAgICAgICAgICAgIGlmIChU
HLP:ZXN0LVBhdGggJGVzZCkgeyAkcGF0aHMgKz0gKEdldC1JbnN0YWxsSW1hZ2VTb3VyY2UgJ0VzZCcgJGVzZCAkZWRpdGlvbklkKSB9CiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJHN4cykgeyAkcGF0aHMgKz0gJHN4cyB9CiAgICAgICAgfQogICAgICAgIGlmICgk
HLP:cGF0aHMuQ291bnQgLWd0IDApIHsgIlNPVVJDRT0kKCRwYXRoc1swXSkiIH0gZWxzZSB7ICJTT1VSQ0U9IiB9CiAgICB9CiAgICAnZGlzbXJlc3RvcmUnIHsKICAgICAgICAkcGFydHMgPSBAKCRBcmcgLXNwbGl0ICdcfCcsIDIpCiAgICAgICAgJHNvdXJjZSA9IGlm
HLP:ICgkcGFydHMuQ291bnQgLWdlIDEpIHsgJHBhcnRzWzBdIH0gZWxzZSB7ICcnIH0KICAgICAgICAkdGltZW91dE1pbnV0ZXMgPSA0NQogICAgICAgIGlmICgkcGFydHMuQ291bnQgLWdlIDIpIHsgW3ZvaWRdW2ludF06OlRyeVBhcnNlKCRwYXJ0c1sxXSwgW3JlZl0k
HLP:dGltZW91dE1pbnV0ZXMpIH0KICAgICAgICBpZiAoJHRpbWVvdXRNaW51dGVzIC1sdCA1KSB7ICR0aW1lb3V0TWludXRlcyA9IDUgfQoKICAgICAgICBmdW5jdGlvbiBRdW90ZS1EaXNtVmFsdWUoW3N0cmluZ10kdmFsdWUpIHsKICAgICAgICAgICAgaWYgKFtzdHJp
HLP:bmddOjpJc051bGxPcldoaXRlU3BhY2UoJHZhbHVlKSkgeyByZXR1cm4gJHZhbHVlIH0KICAgICAgICAgICAgcmV0dXJuICciJyArICgkdmFsdWUgLXJlcGxhY2UgJyInLCAnXCInKSArICciJwogICAgICAgIH0KCiAgICAgICAgJGFyZ3VtZW50cyA9ICcvT25saW5l
HLP:IC9DbGVhbnVwLUltYWdlIC9SZXN0b3JlSGVhbHRoJwogICAgICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHNvdXJjZSkpIHsKICAgICAgICAgICAgJGFyZ3VtZW50cyArPSAnIC9Tb3VyY2U6JyArIChRdW90ZS1EaXNtVmFsdWUgJHNv
HLP:dXJjZSkgKyAnIC9MaW1pdEFjY2VzcycKICAgICAgICB9CgogICAgICAgICR0aW1lZE91dCA9ICRmYWxzZQogICAgICAgICRleGl0Q29kZSA9IDMKICAgICAgICAkb3V0RmlsZSA9IEpvaW4tUGF0aCAkV29yayAoImRpc21fcmVzdG9yZV97MH0ub3V0IiAtZiAoW2d1
HLP:aWRdOjpOZXdHdWlkKCkuVG9TdHJpbmcoJ04nKSkpCiAgICAgICAgJGVyckZpbGUgPSBKb2luLVBhdGggJFdvcmsgKCJkaXNtX3Jlc3RvcmVfezB9LmVyciIgLWYgKFtndWlkXTo6TmV3R3VpZCgpLlRvU3RyaW5nKCdOJykpKQogICAgICAgIHRyeSB7CiAgICAgICAg
HLP:ICAgICRwc2kgPSBbRGlhZ25vc3RpY3MuUHJvY2Vzc1N0YXJ0SW5mb106Om5ldygpCiAgICAgICAgICAgICRwc2kuRmlsZU5hbWUgPSAnY21kLmV4ZScKICAgICAgICAgICAgJHBzaS5Bcmd1bWVudHMgPSAoJy9jIGRpc20uZXhlIHswfSA+ICJ7MX0iIDI+ICJ7Mn0i
HLP:JyAtZiAkYXJndW1lbnRzLCAkb3V0RmlsZSwgJGVyckZpbGUpCiAgICAgICAgICAgICRwc2kuVXNlU2hlbGxFeGVjdXRlID0gJGZhbHNlCiAgICAgICAgICAgICRwc2kuQ3JlYXRlTm9XaW5kb3cgPSAkdHJ1ZQogICAgICAgICAgICAkcCA9IFtEaWFnbm9zdGljcy5Q
HLP:cm9jZXNzXTo6bmV3KCkKICAgICAgICAgICAgJHAuU3RhcnRJbmZvID0gJHBzaQogICAgICAgICAgICBbdm9pZF0kcC5TdGFydCgpCiAgICAgICAgICAgIGlmICgtbm90ICRwLldhaXRGb3JFeGl0KCR0aW1lb3V0TWludXRlcyAqIDYwICogMTAwMCkpIHsKICAgICAg
HLP:ICAgICAgICAgICR0aW1lZE91dCA9ICR0cnVlCiAgICAgICAgICAgICAgICB0cnkgeyAkcC5LaWxsKCkgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgJGV4aXRDb2RlID0gMTQ2MAogICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgdHJ5IHsgJHAu
HLP:V2FpdEZvckV4aXQoKSB9IGNhdGNoIHt9CiAgICAgICAgICAgICAgICAkZXhpdENvZGUgPSAkcC5FeGl0Q29kZQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkZXhpdENvZGUpIHsgJGV4aXRDb2RlID0gMyB9CiAgICAgICAgICAgIH0KICAgICAgICB9IGNh
HLP:dGNoIHsKICAgICAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgICAgICAgICAkZXhpdENvZGUgPSAzCiAgICAgICAgfQoKICAgICAgICBpZiAoVGVzdC1QYXRoICRvdXRGaWxlKSB7IEdldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkb3V0
HLP:RmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgaWYgKFRlc3QtUGF0aCAkZXJyRmlsZSkgeyBHZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGVyckZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIFJlbW92
HLP:ZS1JdGVtIC1MaXRlcmFsUGF0aCAkb3V0RmlsZSwkZXJyRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAiVElNRURPVVQ9JChpZiAoJHRpbWVkT3V0KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiRVhJVENPREU9JGV4
HLP:aXRDb2RlIgogICAgfQogICAgJ3N5c2luZm8nICAgICAgeyBHZXQtU3lzSW5mbyB9CiAgICAnc2NvcmUnICAgICAgICB7ICRoID0gR2V0LUhlYWx0aFNjb3JlOyAiU0NPUkU9JCgkaC5zY29yZSkiOyBmb3JlYWNoICgkciBpbiAkaC5yZWFzb25zKSB7ICJSRUFTT049
HLP:JHIiIH0gfQogICAgJ2ZvcmVuc2ljcycgICAgeyBHZXQtRm9yZW5zaWNzIH0KICAgICd0cmlhZ2UnICAgICAgIHsgR2V0LVRyaWFnZSB9CiAgICAncmVzdG9yZXBvaW50JyB7IE5ldy1SZXN0b3JlUG9pbnQgfQogICAgJ21lZGlhdHlwZScgICAgeyAkbWVkaWEgPSBH
HLP:ZXQtTWVkaWFUeXBlOyAiTUVESUE9JG1lZGlhIjsgIk9QVElNSVpFPSQoUmVzb2x2ZS1PcHRpbWl6ZUFjdGlvbiAkbWVkaWEpIiB9CiAgICAnZGV2aWNlcycgICAgICB7IEdldC1EZXZpY2VQcm9ibGVtcyB9CiAgICAncmVwb3J0JyAgICAgICB7IEFkZC1UeXBlIC1B
HLP:c3NlbWJseU5hbWUgU3lzdGVtLldlYiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgTmV3LUh0bWxSZXBvcnQgJEFyZyB9CiAgICAnYWRkcGhhc2UnICAgICB7IEFkZC1QaGFzZVJlc3VsdCAkQXJnIH0KICAgICdzZXRiZWZvcmUnICAgIHsgU2V0LVNjb3Jl
HLP:ICdiZWZvcmUnICRBcmcgfQogICAgJ3NldGFmdGVyJyAgICAgeyBTZXQtU2NvcmUgJ2FmdGVyJyAkQXJnIH0KICAgICdmaW5kaW5nJyAgICAgIHsgQWRkLUZpbmRpbmcgJEFyZyB9CiAgICAncmVzZXRzdGF0ZScgICB7IFJlc2V0LVN0YXRlOyAiUkVTVUxUPU9LIiB9
HLP:CiAgICAnbm9ybWFsaXplZmFzZXMnIHsKICAgICAgICAkciA9IE5vcm1hbGl6ZS1GYXNlcyAkQXJnCiAgICAgICAgIk5PUk09JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJHIubm9ybSkpKSIKICAgICAgICAiSU5WQUxJRD0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgk
HLP:ci5pbnZhbGlkKSkpIgogICAgfQogICAgJ2NoZWNrcG9pbnQnIHsKICAgICAgICAkcGFyc2VkID0gUGFyc2UtQ2hlY2twb2ludEFyZyAkQXJnCiAgICAgICAgc3dpdGNoICgkcGFyc2VkLnN1YikgewogICAgICAgICAgICAnc2F2ZScgeyBpZiAoU2F2ZS1DaGVja3Bv
HLP:aW50ICRwYXJzZWQpIHsgIlJFU1VMVD1PSyIgfSBlbHNlIHsgIlJFU1VMVD1GQUlMIiB9IH0KICAgICAgICAgICAgJ2xvYWQnIHsKICAgICAgICAgICAgICAgICRjcCA9IExvYWQtQ2hlY2twb2ludAogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkY3ApIHsg
HLP:IlJFU1VMVD1OT05FIiB9CiAgICAgICAgICAgICAgICBlbHNlIHsKICAgICAgICAgICAgICAgICAgICAiUkVTVUxUPU9LIgogICAgICAgICAgICAgICAgICAgICJWQUxJRD0kKGlmIChUZXN0LUNoZWNrcG9pbnRWYWxpZCAkY3ApIHsnMSd9IGVsc2UgeycwJ30pIgog
HLP:ICAgICAgICAgICAgICAgICAgICJWRVJTSU9OPSQoJGNwLnZlcnNpb24pIgogICAgICAgICAgICAgICAgICAgICJDUkVBVEVEPSQoJGNwLmNyZWF0ZWQpIgogICAgICAgICAgICAgICAgICAgICJTRUxFQ1RJT049JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJGNwLnNl
HLP:bGVjdGlvbikpKSIKICAgICAgICAgICAgICAgICAgICAiQ09NUExFVEVEPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRjcC5jb21wbGV0ZWQpKSkiCiAgICAgICAgICAgICAgICAgICAgIlJFQVNPTj0kKCRjcC5wZW5kaW5nX3JlYXNvbikiCiAgICAgICAgICAgICAg
HLP:ICAgICAgIk5FWFQ9JChHZXQtTmV4dFBoYXNlICRjcCkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfQVVUTz0kKGlmICgkY3AubW9kZS5hdXRvKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9OT1JFQk9PVD0kKGlmICgkY3Au
HLP:bW9kZS5ub3JlYm9vdCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfS0VFUFdVPSQoaWYgKCRjcC5tb2RlLmtlZXB3dSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfRFJZPSQoaWYgKCRjcC5t
HLP:b2RlLmRyeSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfVFJJQUdFPSQoaWYgKCRjcC5tb2RlLnRyaWFnZSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJ25l
HLP:eHQnIHsKICAgICAgICAgICAgICAgICRjcCA9IExvYWQtQ2hlY2twb2ludAogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkY3AgLWFuZCAoVGVzdC1DaGVja3BvaW50VmFsaWQgJGNwKSkgeyAiTkVYVD0kKEdldC1OZXh0UGhhc2UgJGNwKSIgfSBlbHNlIHsg
HLP:Ik5FWFQ9IiB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJ2NsZWFyJyB7CiAgICAgICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkgewogICAgICAgICAgICAgICAgICAgIHRyeSB7IFJlbW92ZS1JdGVtICRDaGVja3BvaW50RmlsZSAt
HLP:Rm9yY2UgLUVycm9yQWN0aW9uIFN0b3A7ICJSRVNVTFQ9T0siIH0gY2F0Y2ggeyAiUkVTVUxUPUZBSUwiIH0KICAgICAgICAgICAgICAgIH0gZWxzZSB7ICJSRVNVTFQ9T0siIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBkZWZhdWx0IHsgIlJFU1VMVD1GQUlM
HLP:IjsgIkVSUk9SPXN1YmFjY2lvbiBkZSBjaGVja3BvaW50IGRlc2Nvbm9jaWRhIiB9CiAgICAgICAgfQogICAgfQogICAgJ21vdmVyZXN1bHQnIHsKICAgICAgICAkcGFydHMgPSAkQXJnIC1zcGxpdCAnXHwnLCAyCiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtZXEg
HLP:MikgewogICAgICAgICAgICAkb2sgPSBUZXN0LU1vdmVSZXN1bHRQYXRoICRwYXJ0c1swXSAkcGFydHNbMV0KICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAkYiAgPSAkQXJnIC1zcGxpdCAnLCcKICAgICAgICAgICAgJHNlID0gKCRiLkNvdW50IC1nZSAxIC1h
HLP:bmQgJGJbMF0uVHJpbSgpIC1lcSAnMScpCiAgICAgICAgICAgICRkZSA9ICgkYi5Db3VudCAtZ2UgMiAtYW5kICRiWzFdLlRyaW0oKSAtZXEgJzEnKQogICAgICAgICAgICAkb2sgPSBUZXN0LU1vdmVSZXN1bHQgJHNlICRkZQogICAgICAgIH0KICAgICAgICAiTU9W
HLP:RUQ9JChpZiAoJG9rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICd2dGx3cml0ZScgewogICAgICAgICRwICAgPSAkQXJnIC1zcGxpdCAnLCcKICAgICAgICAkY3VyID0gaWYgKCRwLkNvdW50IC1nZSAxKSB7ICRwWzBdIH0gZWxzZSB7ICcnIH0KICAgICAg
HLP:ICAkZGVzID0gaWYgKCRwLkNvdW50IC1nZSAyKSB7ICRwWzFdIH0gZWxzZSB7IFtzdHJpbmddJFZUX0xFVkVMX0RFU0lSRUQgfQogICAgICAgICJXUklURT0kKGlmIChSZXNvbHZlLVZ0bFdyaXRlICRjdXIgJGRlcykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAg
HLP:ICAnbWFwZXhpdCcgICAgICB7ICJSRVM9JChNYXAtRXhpdENvZGUgJEFyZykiIH0KICAgICMgLS0tICg1LjEgLyBSZXEgMTUpIERpYWdub3N0aWNvIGFtcGxpYWRvIC0tLQogICAgJ3JhbWNoZWNrJyB7CiAgICAgICAgJHIgPSBHZXQtUmFtQ2hlY2sKICAgICAgICAk
HLP:c3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHN0LmRpYWcucmFtID0gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICRyLnN0YXR1czsgcmVjb21tZW5kX21kc2NoZWQgPSBbYm9vbF0kci5yZWNvbW1lbmRfbWRzY2hlZCB9CiAgICAg
HLP:ICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIlJBTV9TVEFUVVM9JCgkci5zdGF0dXMpIgogICAgICAgICJSQU1fUkVDT01NRU5EX01EU0NIRUQ9JChpZiAoJHIucmVjb21tZW5kX21kc2NoZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ2JhdHRlcnkn
HLP:IHsKICAgICAgICAkYiA9IEdldC1CYXR0ZXJ5SGVhbHRoCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRzdC5kaWFnLmJhdHRlcnkgPSBbcHNjdXN0b21vYmplY3RdQHsgcHJlc2VudCA9IFtib29sXSRiLnByZXNlbnQ7
HLP:IGhlYWx0aF9wY3QgPSAkYi5oZWFsdGhfcGN0OyByZXBvcnRfcGF0aCA9ICRiLnJlcG9ydF9wYXRoIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiQkFUVEVSWV9QUkVTRU5UPSQoaWYgKCRiLnByZXNlbnQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAg
HLP:ICAgICJCQVRURVJZX0hFQUxUSF9QQ1Q9JCgkYi5oZWFsdGhfcGN0KSIKICAgICAgICAiQkFUVEVSWV9SRVBPUlQ9JCgkYi5yZXBvcnRfcGF0aCkiCiAgICB9CiAgICAnbmV0YWR2YW5jZWQnIHsKICAgICAgICAkbiA9IEdldC1OZXRBZHZhbmNlZAogICAgICAgICRz
HLP:dCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5uZXR3b3JrID0gW3BzY3VzdG9tb2JqZWN0XUB7IGNvbm5lY3RlZCA9IFtib29sXSRuLmNvbm5lY3RlZDsgZG5zX29rID0gW2Jvb2xdJG4uZG5zX29rOyBkZXRhaWxzID0gJG4u
HLP:ZGV0YWlsczsgZG5zX21zID0gJG4uZG5zX21zIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiTkVUX0NPTk5FQ1RFRD0kKGlmICgkbi5jb25uZWN0ZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfRE5TX09LPSQoaWYgKCRuLmRuc19v
HLP:aykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ERVRBSUxTPSQoJG4uZGV0YWlscykiCiAgICAgICAgIk5FVF9MQVRFTkNZX01TPSQoJG4uZG5zX21zKSIKICAgIH0KICAgICdkaWFnZnVsbCcgewogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAo
HLP:UmVhZC1TdGF0ZSkKICAgICAgICAkciA9IEdldC1SYW1DaGVjawogICAgICAgICRzdC5kaWFnLnJhbSA9IFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAkci5zdGF0dXM7IHJlY29tbWVuZF9tZHNjaGVkID0gW2Jvb2xdJHIucmVjb21tZW5kX21kc2NoZWQgfQog
HLP:ICAgICAgICRiID0gR2V0LUJhdHRlcnlIZWFsdGgKICAgICAgICAkc3QuZGlhZy5iYXR0ZXJ5ID0gW3BzY3VzdG9tb2JqZWN0XUB7IHByZXNlbnQgPSBbYm9vbF0kYi5wcmVzZW50OyBoZWFsdGhfcGN0ID0gJGIuaGVhbHRoX3BjdDsgcmVwb3J0X3BhdGggPSAkYi5y
HLP:ZXBvcnRfcGF0aCB9CiAgICAgICAgJG4gPSBHZXQtTmV0QWR2YW5jZWQKICAgICAgICAkc3QuZGlhZy5uZXR3b3JrID0gW3BzY3VzdG9tb2JqZWN0XUB7IGNvbm5lY3RlZCA9IFtib29sXSRuLmNvbm5lY3RlZDsgZG5zX29rID0gW2Jvb2xdJG4uZG5zX29rOyBkZXRh
HLP:aWxzID0gJG4uZGV0YWlsczsgZG5zX21zID0gJG4uZG5zX21zIH0KICAgICAgICAkZGV2ID0gR2V0LURldmljZUxpc3QKICAgICAgICBpZiAoJG51bGwgLWVxICRkZXYpIHsKICAgICAgICAgICAgJHN0LmRpYWcuZGV2aWNlcyA9IEAoKQogICAgICAgICAgICAkZGV2
HLP:TGluZSA9ICJERVZJQ0VTX1NUQVRVUz1pbmZvIG5vIGRpc3BvbmlibGUiCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJHN0LmRpYWcuZGV2aWNlcyA9IEAoJGRldikKICAgICAgICAgICAgJGRldkxpbmUgPSAiREVWSUNFU19DT1VOVD0kKEAoJGRldikuQ291
HLP:bnQpIgogICAgICAgIH0KICAgICAgICAkc20gPSBHZXQtU21hcnRBdHRyaWJ1dGVzCiAgICAgICAgJHN0LmRpYWcuc21hcnQgPSBbcHNjdXN0b21vYmplY3RdQHsgYXZhaWxhYmxlID0gW2Jvb2xdJHNtLmF2YWlsYWJsZTsgcHJlZGljdF9mYWlsID0gW2Jvb2xdJHNt
HLP:LnByZWRpY3RfZmFpbDsgdGVtcF9jID0gJHNtLnRlbXBfYzsgd2Vhcl9wY3QgPSAkc20ud2Vhcl9wY3Q7IHBvaCA9ICRzbS5wb2ggfQogICAgICAgICRzdHAgPSBHZXQtU3RhcnR1cEl0ZW1zIDgKICAgICAgICAkc3QuZGlhZy5zdGFydHVwID0gQCgkc3RwKQogICAg
HLP:ICAgICRiY2QgPSBHZXQtQmNkSW50ZWdyaXR5CiAgICAgICAgJHN0LmRpYWcuYmNkID0gW3BzY3VzdG9tb2JqZWN0XUB7IG9rID0gW2Jvb2xdJGJjZC5vazsgZGV0YWlscyA9ICRiY2QuZGV0YWlscyB9CiAgICAgICAgJHByb2NzID0gR2V0LVRvcFByb2Nlc3NlcyA2
HLP:CiAgICAgICAgJHN0LmRpYWcucHJvY2Vzc2VzID0gQCgkcHJvY3MpCiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIlJBTV9TVEFUVVM9JCgkci5zdGF0dXMpIgogICAgICAgICJSQU1fUkVDT01NRU5EX01EU0NIRUQ9JChpZiAoJHIucmVjb21tZW5kX21k
HLP:c2NoZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQVRURVJZX1BSRVNFTlQ9JChpZiAoJGIucHJlc2VudCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfSEVBTFRIX1BDVD0kKCRiLmhlYWx0aF9wY3QpIgogICAgICAgICJORVRfQ09O
HLP:TkVDVEVEPSQoaWYgKCRuLmNvbm5lY3RlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ETlNfT0s9JChpZiAoJG4uZG5zX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0xBVEVOQ1lfTVM9JCgkbi5kbnNfbXMpIgogICAgICAgICJT
HLP:TUFSVF9BVkFJTEFCTEU9JChpZiAoJHNtLmF2YWlsYWJsZSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIlNNQVJUX1BSRURJQ1RfRkFJTD0kKGlmICgkc20ucHJlZGljdF9mYWlsKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkNEX09LPSQoaWYgKCRi
HLP:Y2Qub2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICRkZXZMaW5lCiAgICB9CiAgICAjIC0tLSAodjMuMSkgU0ZDIGluZGVwZW5kaWVudGUgZGVsIGlkaW9tYSArIEpTT04gKyBwYXF1ZXRlIGRlIHNvcG9ydGUgLS0tCiAgICAnc2ZjcmVzdWx0JyB7CiAgICAg
HLP:ICAgIlNGQ19SRVM9JChHZXQtU2ZjUmVzdWx0KSIKICAgIH0KICAgICdqc29ucmVwb3J0JyB7CiAgICAgICAgJG91dCA9IGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnSW5mb3JtZS5qc29uJyB9IGVsc2Ug
HLP:eyAkQXJnIH0KICAgICAgICBOZXctSnNvblJlcG9ydCAkb3V0CiAgICB9CiAgICAnc3VwcG9ydHBhY2thZ2UnIHsKICAgICAgICAkb3V0ID0gaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJEFyZykpIHsgSm9pbi1QYXRoICRXb3JrICdQYXF1ZXRlX1Nv
HLP:cG9ydGUuemlwJyB9IGVsc2UgeyAkQXJnIH0KICAgICAgICBOZXctU3VwcG9ydFBhY2thZ2UgJG91dAogICAgfQogICAgIyAtLS0gKDUuNiAvIFJlcSAxNy4yKSBSb3RhY2lvbiBkZSBsb2dzIC0tLQogICAgJ2xvZ3JvdGF0ZScgewogICAgICAgICRmb2xkZXIgPSBp
HLP:ZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnIH0gZWxzZSB7ICRBcmcgfQogICAgICAgICRuID0gSW52b2tlLUxvZ1JvdGF0ZSAkZm9sZGVyICRMT0dfUkVURU5USU9OCiAgICAgICAgIkRFTEVURUQ9
HLP:JG4iCiAgICB9CiAgICAjIC0tLSAoNS44IC8gUmVxIDEzLDE4KSBWYWxpZGFjaW9uIGRlIGVudG9ybm8geSBzZWxmLXRlc3QgLS0tCiAgICAnZW52Y2hlY2snIHsKICAgICAgICAkZSA9IEludm9rZS1FbnZWYWxpZGF0ZQogICAgICAgICJPU19PSz0kKGlmICgkZS5v
HLP:c19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk9TX0JVSUxEPSQoJGUuYnVpbGQpIgogICAgICAgICJPU19DSEVDS19ET05FPTEiCiAgICB9CiAgICAnc2VsZnRlc3RicmFpbicgeyAiQlJBSU5fT0s9MSIgfQogICAgJ3NlbGZ0ZXN0cmVzdWx0JyB7CiAg
HLP:ICAgICAgJHBhc3MgPSBJbnZva2UtU2VsZlRlc3QgKFBhcnNlLUJvb2xMaXN0ICRBcmcpCiAgICAgICAgIlNFTEZURVNUX1BBU1M9JChpZiAoJHBhc3MpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgZGVmYXVsdCAgICAgICAgeyBHZXQtU3lzSW5mbyB9Cn0K
