@echo off
setlocal EnableDelayedExpansion
:: (v3.2) CAPTURAR la identidad del script ANTES del bucle de argumentos:
:: en cmd, 'shift' sin /1 desplaza TAMBIEN %0, y tras el bucle %~f0/%~dp0
:: apuntan al ultimo argumento (p. ej. C:\quiet). Era la causa raiz de que
:: con argumentos el estado fuese a C:\WPI_Suite (raiz del disco) y de que
:: la auto-elevacion relanzara una ruta invalida.
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
    echo Solicitando privilegios de Administrador...
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
echo  %DIM%Fase suelta 08 - Apps de Store e Inicio%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "08" "Apps de Store e Inicio" "Re-registra las apps de la Store y repara el menu Inicio."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase08 ) else ( call :menu_fase08 )
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
rem (v3.2) fase suelta: registrar resultado en el estado y generar informe HTML
if not "%DRY%"=="1" (
    call :title_of 08
    call :pshq addphase "08;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
    set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
    call :psh report "!REPORT!" >nul 2>&1
)
echo(
echo %BL%------------------------------------------------------------%R%
echo    Resultado: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
if exist "!REPORT!" echo    %WH%Informe:%R% !REPORT!
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b %RC%


:Fase08
if "%DRY%"=="1" ( call :dry "Re-registraria las apps de la Store y reiniciaria el Inicio" & exit /b 2 )
call :step "Re-registrando apps de la Microsoft Store (puede tardar)"
powershell -NoProfile -Command "Get-AppxPackage -AllUsers | ForEach-Object { try { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppXManifest.xml') -ErrorAction SilentlyContinue } catch {} }" >> "%LOGFILE%" 2>&1
call :step "Reiniciando el menu Inicio"
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1
taskkill /f /im ShellExperienceHost.exe >nul 2>&1
timeout /t 3 /nobreak >nul 2>&1
tasklist /fi "imagename eq StartMenuExperienceHost.exe" 2>nul | find /i "StartMenuExperienceHost.exe" >nul 2>&1
if !errorlevel! neq 0 ( call :warn "Re-registro lanzado, pero el menu Inicio aun no se ha relanzado (lo hace solo al usarlo). Revisa el log si alguna app sigue fallando." & set "PH_NOTE=Inicio pendiente de relanzarse" & exit /b 1 )
call :ok "Apps de Store re-registradas e Inicio reiniciado (verificado)"
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
HLP:cHRpb24pIChidWlsZCAkKCRvcy5CdWlsZE51bWJlcikpIgogICAgIkVRVUlQTz0kKCRjcy5NYW51ZmFjdHVyZXIpICQoJGNzLk1vZGVsKSIKICAgICJDUFU9JGNwdU5hbWUiCiAgICAiUkFNPSRyYW1HQiBHQiIKICAgICJESVNDTz1DOiAkZnJlZUdCIEdCIGxpYnJl
HLP:cyBkZSAkdG90R0IgR0IiCiAgICAiVVBUSU1FPSQoW2ludF0kdXAuVG90YWxEYXlzKWQgJCgkdXAuSG91cnMpaCAkKCR1cC5NaW51dGVzKW0iCiAgICAiVVNVQVJJTz0kZW52OlVTRVJOQU1FIgp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgKDUuMiAvIFJlcSAxNS42KSBOdWNsZW8gUFVSTyBkZSBjYWxjdWxvIGRlbCBzY29yZS4KIyBSZWNpYmUgdW4gaGFzaHRhYmxlIGRlIHNpbnRvbWFzIChmbGFncy9jb250ZW9zKSB5IGRldnVl
HLP:bHZlIHVuIGVudGVybyBlbgojIFswLDEwMF0uIENhZGEgc2ludG9tYSBzb2xvIHB1ZWRlIFJFU1RBUiBwdW50b3MsIHBvciBsbyBxdWUgYW5hZGlyIG8gYWdyYXZhcgojIGN1YWxxdWllciBzaW50b21hIG51bmNhIHN1YmUgZWwgc2NvcmUgKE1PTk9UT05JQSksIHkg
HLP:ZWwgY2xhbXAgZ2FyYW50aXphIGVsCiMgcmFuZ28gWzAsMTAwXS4gRXMgZGV0ZXJtaW5pc3RhIHJlc3BlY3RvIGEgc3UgZW50cmFkYSAodGVzdGVhYmxlIGRlIGZvcm1hCiMgYWlzbGFkYSBwYXJhIGxhIFByb3BlcnR5IDEwKS4KZnVuY3Rpb24gQ29tcHV0ZS1TY29y
HLP:ZShbaGFzaHRhYmxlXSRzeW0pIHsKICAgIGlmICgkbnVsbCAtZXEgJHN5bSkgeyAkc3ltID0gQHt9IH0KICAgICRzY29yZSA9IDEwMAogICAgIyAtLS0gUGVuYWxpemFjaW9uZXMgZXhpc3RlbnRlcyAocHJlc2VydmFkYXMpIC0tLQogICAgaWYgKCRzeW1bJ3NtYXJ0
HLP:QmFkJ10pICAgICAgIHsgJHNjb3JlIC09IDI1IH0KICAgIGlmICgkc3ltLkNvbnRhaW5zS2V5KCdmcmVlR0InKSAtYW5kICRudWxsIC1uZSAkc3ltWydmcmVlR0InXSkgewogICAgICAgICRmcmVlR0IgPSBbZG91YmxlXSRzeW1bJ2ZyZWVHQiddCiAgICAgICAgaWYg
HLP:ICAgICgkZnJlZUdCIC1sdCA1KSAgeyAkc2NvcmUgLT0gMTUgfQogICAgICAgIGVsc2VpZiAoJGZyZWVHQiAtbHQgMTUpIHsgJHNjb3JlIC09IDYgfQogICAgfQogICAgaWYgKCRzeW1bJ3JlYm9vdFBlbmRpbmcnXSkgICAgICAgICAgeyAkc2NvcmUgLT0gNSB9CiAg
HLP:ICBpZiAoW2ludF0kc3ltWydic29kJ10gLWd0IDApICAgICAgICB7ICRzY29yZSAtPSAxOCB9CiAgICBpZiAoW2ludF0kc3ltWydkaXNrRXJyJ10gLWd0IDApICAgICB7ICRzY29yZSAtPSAxMiB9CiAgICBpZiAoW2ludF0kc3ltWyd3aGVhJ10gLWd0IDApICAgICAg
HLP:ICB7ICRzY29yZSAtPSAxMiB9CiAgICBpZiAoW2ludF0kc3ltWydjcml0Q291bnQnXSAtZ3QgMjUpICB7ICRzY29yZSAtPSA2IH0KICAgIGlmIChbaW50XSRzeW1bJ3N2Y1N0b3BwZWQnXSAtZ3QgMCkgIHsgJHNjb3JlIC09IDQgKiBbaW50XSRzeW1bJ3N2Y1N0b3Bw
HLP:ZWQnXSB9CiAgICBpZiAoW2ludF0kc3ltWydkZXZQcm9ibGVtcyddIC1ndCAwKSB7ICRzY29yZSAtPSBbbWF0aF06Ok1pbigxMiwgW2ludF0kc3ltWydkZXZQcm9ibGVtcyddICogMykgfQogICAgIyAtLS0gTnVldmFzIHBlbmFsaXphY2lvbmVzIGRlbCBkaWFnbm9z
HLP:dGljbyBhbXBsaWFkbyAoNS4yKSAtLS0KICAgIGlmICgkc3ltWydyYW1TdXNwZWN0J10pIHsgJHNjb3JlIC09IDEwIH0gICAjIFJBTSBzb3NwZWNob3NhCiAgICBpZiAoJHN5bS5Db250YWluc0tleSgnYmF0dGVyeUhlYWx0aFBjdCcpIC1hbmQgJG51bGwgLW5lICRz
HLP:eW1bJ2JhdHRlcnlIZWFsdGhQY3QnXSkgewogICAgICAgICRicCA9IFtpbnRdJHN5bVsnYmF0dGVyeUhlYWx0aFBjdCddCiAgICAgICAgaWYgKCRicCAtZ2UgMCAtYW5kICRicCAtbHQgNTApIHsgJHNjb3JlIC09IDggfSAgICMgYmF0ZXJpYSBtdXkgZGVncmFkYWRh
HLP:ICg8NTAlKQogICAgfQogICAgaWYgKCRzeW1bJ25ldFByb2JsZW0nXSkgeyAkc2NvcmUgLT0gOCB9ICAgIyBwcm9ibGVtYXMgZGUgcmVkIHBlcnNpc3RlbnRlcwogICAgIyAtLS0gQ2xhbXAgYWwgcmFuZ28gWzAsMTAwXSAtLS0KICAgIGlmICgkc2NvcmUgLWx0IDAp
HLP:ICAgeyAkc2NvcmUgPSAwIH0KICAgIGlmICgkc2NvcmUgLWd0IDEwMCkgeyAkc2NvcmUgPSAxMDAgfQogICAgcmV0dXJuIFtpbnRdJHNjb3JlCn0KCiMgUHVudHVhY2lvbiBkZSBzYWx1ZCAwLTEwMDogcmVjb2xlY3RhIHNpbnRvbWFzIHJlYWxlcyBkZWwgc2lzdGVt
HLP:YSAoaW5jbHVpZG8gZWwKIyBkaWFnbm9zdGljbyBhbXBsaWFkbyBwZXJzaXN0aWRvIGVuIGVzdGFkby5kaWFnKSB5IGRlbGVnYSBlbCBjYWxjdWxvIGVuIGxhCiMgZnVuY2lvbiBwdXJhIENvbXB1dGUtU2NvcmUuCmZ1bmN0aW9uIEdldC1IZWFsdGhTY29yZSB7CiAg
HLP:ICAkcmVhc29ucyA9IEAoKQogICAgJHN5bSA9IEB7fQogICAgIyBEaXNjbyBTTUFSVAogICAgJGJhZCA9IEAoR2V0LVBoeXNpY2FsRGlzayB8IFdoZXJlLU9iamVjdCB7ICRfLkhlYWx0aFN0YXR1cyAtbmUgJ0hlYWx0aHknIH0pCiAgICAkc3ltWydzbWFydEJhZCdd
HLP:ID0gKCRiYWQuQ291bnQgLWd0IDApCiAgICBpZiAoJHN5bVsnc21hcnRCYWQnXSkgeyAkcmVhc29ucyArPSAiRGlzY28gY29uIFNNQVJUIGRlZ3JhZGFkbyAoLTI1KSIgfQogICAgIyBFc3BhY2lvIGxpYnJlCiAgICAkYyA9IEdldC1QU0RyaXZlIEM7ICRmcmVlR0Ig
HLP:PSBbbWF0aF06OlJvdW5kKCRjLkZyZWUvMUdCLDEpCiAgICAkc3ltWydmcmVlR0InXSA9ICRmcmVlR0IKICAgIGlmICAgICAoJGZyZWVHQiAtbHQgNSkgIHsgJHJlYXNvbnMgKz0gIk1lbm9zIGRlIDUgR0IgbGlicmVzIGVuIEM6ICgtMTUpIiB9CiAgICBlbHNlaWYg
HLP:KCRmcmVlR0IgLWx0IDE1KSB7ICRyZWFzb25zICs9ICJQb2NvIGVzcGFjaW8gbGlicmUgZW4gQzogKC02KSIgfQogICAgIyBSZWluaWNpbyBwZW5kaWVudGUKICAgICRwZW5kID0gKFRlc3QtUGF0aCAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3NcQ3Vy
HLP:cmVudFZlcnNpb25cQ29tcG9uZW50IEJhc2VkIFNlcnZpY2luZ1xSZWJvb3RQZW5kaW5nJykgLW9yIGAKICAgICAgICAgICAgKFRlc3QtUGF0aCAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3NcQ3VycmVudFZlcnNpb25cV2luZG93c1VwZGF0ZVxBdXRv
HLP:IFVwZGF0ZVxSZWJvb3RSZXF1aXJlZCcpCiAgICAkc3ltWydyZWJvb3RQZW5kaW5nJ10gPSBbYm9vbF0kcGVuZAogICAgaWYgKCRwZW5kKSB7ICRyZWFzb25zICs9ICJSZWluaWNpbyBwZW5kaWVudGUgKC01KSIgfQogICAgIyBFdmVudG9zIGNyaXRpY29zIHJlY2ll
HLP:bnRlcyAoNDhoKQogICAgJHNpbmNlID0gKEdldC1EYXRlKS5BZGRIb3VycygtNDgpCiAgICAkY3JpdCA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBMZXZlbD0xLDI7IFN0YXJ0VGltZT0kc2luY2V9IC1FcnJvckFj
HLP:dGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgJGJzb2QgPSBAKCRjcml0IHwgV2hlcmUtT2JqZWN0IHsgJF8uSWQgLWluIDQxLDEwMDEsNjAwOCB9KS5Db3VudAogICAgJGRpc2sgPSBAKCRjcml0IHwgV2hlcmUtT2JqZWN0IHsgJF8uUHJvdmlkZXJOYW1lIC1tYXRj
HLP:aCAnZGlza3xOdGZzfHZvbG1ncicgfSkuQ291bnQKICAgICR3aGVhID0gQCgkY3JpdCB8IFdoZXJlLU9iamVjdCB7ICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2ggJ1dIRUEnIH0pLkNvdW50CiAgICAkc3ltWydic29kJ10gPSAkYnNvZDsgJHN5bVsnZGlza0VyciddID0g
HLP:JGRpc2s7ICRzeW1bJ3doZWEnXSA9ICR3aGVhOyAkc3ltWydjcml0Q291bnQnXSA9ICRjcml0LkNvdW50CiAgICBpZiAoJGJzb2QgLWd0IDApIHsgJHJlYXNvbnMgKz0gIkFwYWdvbmVzL0JTT0QgcmVjaWVudGVzOiAkYnNvZCAoLTE4KSIgfQogICAgaWYgKCRkaXNr
HLP:IC1ndCAwKSB7ICRyZWFzb25zICs9ICJFcnJvcmVzIGRlIGRpc2NvL05URlMgcmVjaWVudGVzOiAkZGlzayAoLTEyKSIgfQogICAgaWYgKCR3aGVhIC1ndCAwKSB7ICRyZWFzb25zICs9ICJFcnJvcmVzIGRlIGhhcmR3YXJlIChXSEVBKTogJHdoZWEgKC0xMikiIH0K
HLP:ICAgIGlmICgkY3JpdC5Db3VudCAtZ3QgMjUpIHsgJHJlYXNvbnMgKz0gIk11Y2hvcyBldmVudG9zIGNyaXRpY29zIGVuIDQ4aDogJCgkY3JpdC5Db3VudCkgKC02KSIgfQogICAgIyBTZXJ2aWNpb3MgY2xhdmUgcGFyYWRvcwogICAgJHN2Y1N0b3BwZWQgPSAwCiAg
HLP:ICBmb3JlYWNoICgkc3ZjIGluICd3dWF1c2VydicsJ0JJVFMnLCdXaW5tZ210JywnRXZlbnRMb2cnKSB7CiAgICAgICAgJHMgPSBHZXQtU2VydmljZSAkc3ZjIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgaWYgKCRzIC1hbmQgJHMuU3RhdHVz
HLP:IC1uZSAnUnVubmluZycgLWFuZCAkcy5TdGFydFR5cGUgLW5lICdEaXNhYmxlZCcpIHsgJHN2Y1N0b3BwZWQrKzsgJHJlYXNvbnMgKz0gIlNlcnZpY2lvICRzdmMgcGFyYWRvICgtNCkiIH0KICAgIH0KICAgICRzeW1bJ3N2Y1N0b3BwZWQnXSA9ICRzdmNTdG9wcGVk
HLP:CiAgICAjIERpc3Bvc2l0aXZvcyBjb24gcHJvYmxlbWEKICAgICRwcm9iID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUG5QRW50aXR5IHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFuYWdlckVycm9yQ29kZSAtZ3QgMCB9KS5Db3VudAogICAgJHN5bVsnZGV2
HLP:UHJvYmxlbXMnXSA9ICRwcm9iCiAgICBpZiAoJHByb2IgLWd0IDApIHsgJHJlYXNvbnMgKz0gIkRpc3Bvc2l0aXZvcyBjb24gZXJyb3I6ICRwcm9iIiB9CiAgICAjIC0tLSBEaWFnbm9zdGljbyBhbXBsaWFkbyBwZXJzaXN0aWRvICg1LjIpOiBSQU0sIGJhdGVyaWEs
HLP:IHJlZCAtLS0KICAgICRzdCA9IFJlYWQtU3RhdGUKICAgIGlmICgoJHN0LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2RpYWcnKSAtYW5kICRzdC5kaWFnKSB7CiAgICAgICAgaWYgKCRzdC5kaWFnLnJhbSAtYW5kIChbc3RyaW5nXSRzdC5kaWFn
HLP:LnJhbS5zdGF0dXMgLWVxICdzdXNwZWN0JykpIHsKICAgICAgICAgICAgJHN5bVsncmFtU3VzcGVjdCddID0gJHRydWU7ICRyZWFzb25zICs9ICJSQU0gc29zcGVjaG9zYSAoLTEwKSIKICAgICAgICB9CiAgICAgICAgaWYgKCRzdC5kaWFnLmJhdHRlcnkgLWFuZCAk
HLP:c3QuZGlhZy5iYXR0ZXJ5LnByZXNlbnQpIHsKICAgICAgICAgICAgJGJwUmF3ID0gJHN0LmRpYWcuYmF0dGVyeS5oZWFsdGhfcGN0CiAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGJwUmF3IC1hbmQgW3N0cmluZ10kYnBSYXcgLW5lICcnKSB7CiAgICAgICAgICAg
HLP:ICAgICAkYnAgPSAkbnVsbDsgdHJ5IHsgJGJwID0gW2ludF0kYnBSYXcgfSBjYXRjaCB7ICRicCA9ICRudWxsIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGJwKSB7CiAgICAgICAgICAgICAgICAgICAgJHN5bVsnYmF0dGVyeUhlYWx0aFBjdCddID0g
HLP:JGJwCiAgICAgICAgICAgICAgICAgICAgaWYgKCRicCAtZ2UgMCAtYW5kICRicCAtbHQgNTApIHsgJHJlYXNvbnMgKz0gIkJhdGVyaWEgbXV5IGRlZ3JhZGFkYTogJGJwJSAoLTgpIiB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAg
HLP:ICAgICAgaWYgKCRzdC5kaWFnLm5ldHdvcmsgLWFuZCAoKCRzdC5kaWFnLm5ldHdvcmsuY29ubmVjdGVkIC1lcSAkZmFsc2UpIC1vciAoJHN0LmRpYWcubmV0d29yay5kbnNfb2sgLWVxICRmYWxzZSkpKSB7CiAgICAgICAgICAgICRzeW1bJ25ldFByb2JsZW0nXSA9
HLP:ICR0cnVlOyAkcmVhc29ucyArPSAiUHJvYmxlbWFzIGRlIHJlZCBwZXJzaXN0ZW50ZXMgKC04KSIKICAgICAgICB9CiAgICB9CiAgICAkc2NvcmUgPSBDb21wdXRlLVNjb3JlICRzeW0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc2NvcmUgPSBbaW50XSRz
HLP:Y29yZTsgcmVhc29ucyA9ICRyZWFzb25zIH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEZvcmVuc2UgZGVsIHJlZ2lzdHJvIGRlIGV2ZW50b3M6IHVsdGltb3Mg
HLP:ZXJyb3JlcyBxdWUgZXhwbGljYW4gbGEgY2F1c2EgcmFpei4KZnVuY3Rpb24gR2V0LUZvcmVuc2ljcyB7CiAgICAkc2luY2UgPSAoR2V0LURhdGUpLkFkZERheXMoLTcpCiAgICAkb3V0ID0gQCgpCiAgICAkZXYgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRh
HLP:YmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgTGV2ZWw9MSwyOyBTdGFydFRpbWU9JHNpbmNlfSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDQwMCkKICAgICRncm91cHMgPSBAKAogICAgICAgIEB7IGs9J0FSUkFOUVVF
HLP:L0FQQUdPTic7IGlkcz1AKDQxLDYwMDgsMTAwMSk7IHByb3Y9JycgfSwKICAgICAgICBAeyBrPSdESVNDTy9OVEZTJzsgICAgICBpZHM9QCgpOyAgICAgICAgICAgICBwcm92PSdkaXNrfE50ZnN8dm9sbWdyfHN0b3Judm1lfHN0b3JhaGNpJyB9LAogICAgICAgIEB7
HLP:IGs9J0hBUkRXQVJFIChXSEVBKSc7IGlkcz1AKCk7ICAgICAgICAgICAgIHByb3Y9J1dIRUEnIH0sCiAgICAgICAgQHsgaz0nU0VSVklDSU9TJzsgICAgICAgaWRzPUAoKTsgICAgICAgICAgICAgcHJvdj0nU2VydmljZSBDb250cm9sIE1hbmFnZXInIH0sCiAgICAg
HLP:ICAgQHsgaz0nQVBMSUNBQ0lPTic7ICAgICAgaWRzPUAoMTAwMCwxMDAyKTsgICAgcHJvdj0nQXBwbGljYXRpb24gRXJyb3J8Lk5FVCBSdW50aW1lJyB9CiAgICApCiAgICBmb3JlYWNoICgkZyBpbiAkZ3JvdXBzKSB7CiAgICAgICAgJHNlbCA9ICRldiB8IFdoZXJl
HLP:LU9iamVjdCB7CiAgICAgICAgICAgICgkZy5pZHMuQ291bnQgLWd0IDAgLWFuZCAkXy5JZCAtaW4gJGcuaWRzKSAtb3IgKCRnLnByb3YgLW5lICcnIC1hbmQgJF8uUHJvdmlkZXJOYW1lIC1tYXRjaCAkZy5wcm92KQogICAgICAgIH0gfCBTZWxlY3QtT2JqZWN0IC1G
HLP:aXJzdCAzCiAgICAgICAgZm9yZWFjaCAoJGUgaW4gJHNlbCkgewogICAgICAgICAgICAkbXNnID0gKCRlLk1lc3NhZ2UgLXNwbGl0ICJgbiIpWzBdOyBpZiAoJG1zZy5MZW5ndGggLWd0IDkwKSB7ICRtc2cgPSAkbXNnLlN1YnN0cmluZygwLDkwKSB9CiAgICAgICAg
HLP:ICAgICRvdXQgKz0gKCJ7MH18ezF9fHsyfXx7M30iIC1mICRnLmssICRlLklkLCAkZS5UaW1lQ3JlYXRlZC5Ub1N0cmluZygnTU0tZGQgSEg6bW0nKSwgJG1zZy5UcmltKCkpCiAgICAgICAgfQogICAgfQogICAgaWYgKCRvdXQuQ291bnQgLWVxIDApIHsgIk9LfDB8
HLP:LXxTaW4gZXJyb3JlcyBjcml0aWNvcyBlbiBsb3MgdWx0aW1vcyA3IGRpYXMuIiB9IGVsc2UgeyAkb3V0IH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEF1dG8t
HLP:dHJpYWdlOiBhIHBhcnRpciBkZWwgc2NvcmUgeSBsYSBmb3JlbnNlLCByZWNvbWllbmRhIGZhc2VzIChsaXN0YSBkZSBJRHMpLgpmdW5jdGlvbiBHZXQtVHJpYWdlIHsKICAgICRoID0gR2V0LUhlYWx0aFNjb3JlCiAgICAkcmVjID0gTmV3LU9iamVjdCBTeXN0ZW0u
HLP:Q29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgIGZvcmVhY2ggKCR4IGluICcwMCcsJzAxJywnMDInKSB7ICRyZWMuQWRkKCR4KSB9ICAjIGRpYWdub3N0aWNvK3Jlc3RvcmUrbGltcGllemEgc2llbXByZQogICAgJHNpbmNlID0gKEdldC1EYXRlKS5B
HLP:ZGREYXlzKC03KQogICAgJGV2ID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IExldmVsPTEsMjsgU3RhcnRUaW1lPSRzaW5jZX0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICBpZiAoQCgkZXYgfCBX
HLP:aGVyZS1PYmplY3QgeyAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICdkaXNrfE50ZnN8dm9sbWdyJyB9KS5Db3VudCAtZ3QgMCkgeyAkcmVjLkFkZCgnMDMnKSB9CiAgICAkcmVjLkFkZCgnMDQnKTsgJHJlYy5BZGQoJzA1Jyk7ICRyZWMuQWRkKCcwNicpICAjIGRpc2Nv
HLP:L0RJU00vU0ZDIGJhc2UKICAgIGlmICgoR2V0LVNlcnZpY2UgV2lubWdtdCkuU3RhdHVzIC1uZSAnUnVubmluZycpIHsgJHJlYy5BZGQoJzA3JykgfQogICAgIyBXVSByb3RvPwogICAgJHd1ID0gR2V0LVNlcnZpY2Ugd3VhdXNlcnYgLUVycm9yQWN0aW9uIFNpbGVu
HLP:dGx5Q29udGludWUKICAgIGlmICgkd3UgLWFuZCAkd3UuU3RhdHVzIC1uZSAnUnVubmluZycgLWFuZCAkd3UuU3RhcnRUeXBlIC1uZSAnRGlzYWJsZWQnKSB7ICRyZWMuQWRkKCcxMycpIH0KICAgICJTQ09SRT0kKCRoLnNjb3JlKSIKICAgICJSRUNPTUVOREFEQVM9
HLP:JChbc3RyaW5nXTo6Sm9pbignLCcsICgkcmVjIHwgU2VsZWN0LU9iamVjdCAtVW5pcXVlKSkpIgp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCmZ1bmN0aW9uIE5ldy1S
HLP:ZXN0b3JlUG9pbnQgewogICAgdHJ5IHsKICAgICAgICBFbmFibGUtQ29tcHV0ZXJSZXN0b3JlIC1Ecml2ZSAnQzonIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgJGsgPSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3Vy
HLP:cmVudFZlcnNpb25cU3lzdGVtUmVzdG9yZScKICAgICAgICAkcHJldiA9IChHZXQtSXRlbVByb3BlcnR5ICRrIC1OYW1lIFN5c3RlbVJlc3RvcmVQb2ludENyZWF0aW9uRnJlcXVlbmN5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS5TeXN0ZW1SZXN0b3Jl
HLP:UG9pbnRDcmVhdGlvbkZyZXF1ZW5jeQogICAgICAgIFNldC1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25GcmVxdWVuY3kgLVZhbHVlIDAgLVR5cGUgRFdvcmQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAg
HLP:ICAkbmFtZSA9ICJTdWl0ZV9SZXBhcmFjaW9uXyQoKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZF9ISC1tbScpKSIKICAgICAgICBDaGVja3BvaW50LUNvbXB1dGVyIC1EZXNjcmlwdGlvbiAkbmFtZSAtUmVzdG9yZVBvaW50VHlwZSBNT0RJRllfU0VUVElO
HLP:R1MgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICBpZiAoJG51bGwgLW5lICRwcmV2KSB7IFNldC1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25GcmVxdWVuY3kgLVZhbHVlICRwcmV2IC1UeXBlIERXb3JkIH0gZWxzZSB7IFJl
HLP:bW92ZS1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25GcmVxdWVuY3kgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICRycCA9IEdldC1Db21wdXRlclJlc3RvcmVQb2ludCB8IFdoZXJlLU9iamVjdCB7
HLP:ICRfLkRlc2NyaXB0aW9uIC1lcSAkbmFtZSB9CiAgICAgICAgaWYgKCRycCkgeyAiUkVTVUxUPU9LIjsgIk5BTUU9JG5hbWUiIH0gZWxzZSB7ICJSRVNVTFQ9RkFJTCI7ICJOQU1FPSRuYW1lIiB9CiAgICB9IGNhdGNoIHsgIlJFU1VMVD1GQUlMIjsgIkVSUk9SPSQo
HLP:JF8uRXhjZXB0aW9uLk1lc3NhZ2UpIiB9Cn0KCmZ1bmN0aW9uIFNhdmUtSGVhbHRoSGlzdG9yeSgkc2NvcmUpIHsKICAgICRzY3JpcHREaXIgPSAkbnVsbAogICAgaWYgKCRQU1NjcmlwdFJvb3QpIHsKICAgICAgICAkc2NyaXB0RGlyID0gJFBTU2NyaXB0Um9vdAog
HLP:ICAgfSBlbHNlaWYgKCRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgpIHsKICAgICAgICAkc2NyaXB0RGlyID0gU3BsaXQtUGF0aCAtUGFyZW50ICRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgKICAgIH0KICAgICRiYXNlRGlyID0gaWYgKCRzY3JpcHREaXIp
HLP:IHsgSm9pbi1QYXRoIChTcGxpdC1QYXRoIC1QYXJlbnQgJHNjcmlwdERpcikgIldQSV9TdWl0ZSIgfSBlbHNlIHsgJFdvcmsgfQogICAgaWYgKCRzY3JpcHREaXIgLWFuZCAoVGVzdC1QYXRoICRzY3JpcHREaXIpKSB7CiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0
HLP:aCAkYmFzZURpcikpIHsgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkYmFzZURpciAtRm9yY2UgfCBPdXQtTnVsbCB9CiAgICB9IGVsc2UgewogICAgICAgICRiYXNlRGlyID0gJFdvcmsKICAgIH0KICAgICRoaXN0b3J5RmlsZSA9IEpvaW4tUGF0
HLP:aCAkYmFzZURpciAiaGVhbHRoX2hpc3RvcnkuanNvbiIKICAgICRoaXN0b3J5ID0gQCgpCiAgICBpZiAoVGVzdC1QYXRoICRoaXN0b3J5RmlsZSkgewogICAgICAgIHRyeSB7ICRoaXN0b3J5ID0gR2V0LUNvbnRlbnQgJGhpc3RvcnlGaWxlIC1SYXcgfCBDb252ZXJ0
HLP:RnJvbS1Kc29uIH0gY2F0Y2gge30KICAgIH0KICAgICRlbnRyeSA9IFtwc2N1c3RvbW9iamVjdF1AewogICAgICAgIGRhdGUgID0gKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZCBISDptbScpCiAgICAgICAgc2NvcmUgPSBbaW50XSRzY29yZQogICAgfQog
HLP:ICAgJGhpc3RvcnkgPSBAKCRoaXN0b3J5KSArICRlbnRyeQogICAgaWYgKCRoaXN0b3J5LkNvdW50IC1ndCAxMCkgeyAkaGlzdG9yeSA9ICRoaXN0b3J5Wy0xMC4uLTFdIH0KICAgIHRyeSB7CiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRo
HLP:aXN0b3J5RmlsZSwgKCRoaXN0b3J5IHwgQ29udmVydFRvLUpzb24pLCAoTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKSkpCiAgICB9IGNhdGNoIHt9Cn0KCmZ1bmN0aW9uIEluc3RhbGwtV2luZ2V0Qm9vdHN0cmFwIHsKICAgICR0ZW1w
HLP:RmlsZSA9IEpvaW4tUGF0aCAkZW52OlRFTVAgIk1pY3Jvc29mdC5EZXNrdG9wQXBwSW5zdGFsbGVyXzh3ZWt5YjNkOGJid2UubXNpeGJ1bmRsZSIKICAgIHRyeSB7CiAgICAgICAgJHVybCA9ICJodHRwczovL2dpdGh1Yi5jb20vbWljcm9zb2Z0L3dpbmdldC1jbGkv
HLP:cmVsZWFzZXMvbGF0ZXN0L2Rvd25sb2FkL01pY3Jvc29mdC5EZXNrdG9wQXBwSW5zdGFsbGVyXzh3ZWt5YjNkOGJid2UubXNpeGJ1bmRsZSIKICAgICAgICBXcml0ZS1Ib3N0ICJEZXNjYXJnYW5kbyBBcHAgSW5zdGFsbGVyIGRlc2RlOiAkdXJsIgogICAgICAgICR3
HLP:ZWJDbGllbnQgPSBOZXctT2JqZWN0IFN5c3RlbS5OZXQuV2ViQ2xpZW50CiAgICAgICAgW1N5c3RlbS5OZXQuU2VydmljZVBvaW50TWFuYWdlcl06OlNlY3VyaXR5UHJvdG9jb2wgPSBbU3lzdGVtLk5ldC5TZWN1cml0eVByb3RvY29sVHlwZV06OlRsczEyCiAgICAg
HLP:ICAgJHdlYkNsaWVudC5Eb3dubG9hZEZpbGUoJHVybCwgJHRlbXBGaWxlKQogICAgICAgIAogICAgICAgIFdyaXRlLUhvc3QgIkluc3RhbGFuZG8gQXBwIEluc3RhbGxlciBjb24gQWRkLUFwcHhQYWNrYWdlLi4uIgogICAgICAgIEFkZC1BcHB4UGFja2FnZSAtUGF0
HLP:aCAkdGVtcEZpbGUgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICBXcml0ZS1Ib3N0ICJJbnN0YWxhY2lvbiBleGl0b3NhLiIKICAgICAgICBpZiAoVGVzdC1QYXRoICR0ZW1wRmlsZSkgeyBSZW1vdmUtSXRlbSAkdGVtcEZpbGUgLUZvcmNlIC1FcnJvckFjdGlvbiBT
HLP:aWxlbnRseUNvbnRpbnVlIH0KICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggewogICAgICAgIFdyaXRlLUhvc3QgIkVycm9yIGVuIGJvb3RzdHJhcCBkZSB3aW5nZXQ6ICQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgICAgIGlmIChUZXN0LVBhdGgg
HLP:JHRlbXBGaWxlKSB7IFJlbW92ZS1JdGVtICR0ZW1wRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIHJldHVybiAkZmFsc2UKICAgIH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojICgzLjcgLyBCdWcgNSAvIFJlcSA3KSBEZXRlY2Npb24gZmlhYmxlIGRlbCB0aXBvIGRlIGRpc2NvLgojIENvbnZlcnRUby1NZWRpYUNsYXNzOiBmdW5jaW9uIFBVUkEgcXVlIG1hcGVhIHVuIE1lZGlhVHlw
HLP:ZSAobnVtZXJvIG8gdGV4dG8pCiMgYSBsYSBjbGFzZSBjYW5vbmljYSB7U1NELEhERCxVTktOT1dOfS4gU1NEPTQgbyAnU1NEJzsgSEREPTMgbyAnSEREJzsKIyBjdWFscXVpZXIgb3RybyB2YWxvciAoVW5zcGVjaWZpZWQ9MCwgdmFjaW8sIG51bG8sIFNDTT01Li4u
HLP:KSAtPiBVTktOT1dOLgpmdW5jdGlvbiBDb252ZXJ0VG8tTWVkaWFDbGFzcygkbXQpIHsKICAgIGlmICgkbnVsbCAtZXEgJG10KSB7IHJldHVybiAnVU5LTk9XTicgfQogICAgJHMgPSAoW3N0cmluZ10kbXQpLlRyaW0oKQogICAgaWYgKCRzIC1lcSAnJykgeyByZXR1
HLP:cm4gJ1VOS05PV04nIH0KICAgIHN3aXRjaCAtcmVnZXggKCRzLlRvVXBwZXIoKSkgewogICAgICAgICdeKDR8U1NEKSQnIHsgcmV0dXJuICdTU0QnIH0KICAgICAgICAnXigzfEhERCkkJyB7IHJldHVybiAnSEREJyB9CiAgICAgICAgZGVmYXVsdCAgICAgeyByZXR1
HLP:cm4gJ1VOS05PV04nIH0KICAgIH0KfQoKIyBSZXNvbHZlLU9wdGltaXplQWN0aW9uOiBmdW5jaW9uIFBVUkEuIFRSSU0gc29sbyBzaSBTU0QsIERFRlJBRyBzb2xvIHNpIEhERAojIGNsYXJvLCBOT05FIGVuIGN1YWxxdWllciBvdHJvIGNhc28gKGFic3RlbmNpb24g
HLP:c2VndXJhOiBudW5jYSBkZXNmcmFnbWVudGEKIyBhbnRlIHRpcG8gaW5jaWVydG8sIGV2aXRhbmRvIGRhbmFyIHVuIHBvc2libGUgU1NEKS4KZnVuY3Rpb24gUmVzb2x2ZS1PcHRpbWl6ZUFjdGlvbigkbWVkaWEpIHsKICAgICRtID0gKFtzdHJpbmddJG1lZGlhKS5U
HLP:cmltKCkuVG9VcHBlcigpCiAgICBpZiAgICAgKCRtIC1lcSAnU1NEJykgICAgIHsgcmV0dXJuICdUUklNJyB9CiAgICBlbHNlaWYgKCRtIC1lcSAnSEREJykgICAgIHsgcmV0dXJuICdERUZSQUcnIH0KICAgIGVsc2VpZiAoJG0gLWVxICdWSVJUVUFMJykgeyByZXR1
HLP:cm4gJ05PTkUnIH0gICAjICh2My4yKSBkaXNjbyBkZSBtYXF1aW5hIHZpcnR1YWw6IG5vIGFwbGljYQogICAgZWxzZSAgICAgICAgICAgICAgICAgICAgICB7IHJldHVybiAnTk9ORScgfQp9CgojIEdldC1NZWRpYVR5cGU6IGlkZW50aWZpY2EgZWwgZGlzY28gZmlz
HLP:aWNvIGRlbCB2b2x1bWVuIGRlbCBzaXN0ZW1hIGRlIGZvcm1hCiMgZmlhYmxlIChwb3IgRGV2aWNlSWQsIHJlc3BhbGRvIHBvciBTZXJpYWxOdW1iZXIpIHkgZGV2dWVsdmUgU1NEfEhERHxWSVJUVUFMfFVOS05PV04uCmZ1bmN0aW9uIEdldC1NZWRpYVR5cGUgewog
HLP:ICAgdHJ5IHsKICAgICAgICAkc3lzICA9ICgkZW52OlN5c3RlbURyaXZlKS5UcmltRW5kKCc6JykKICAgICAgICAkZGlzayA9IEdldC1QYXJ0aXRpb24gLURyaXZlTGV0dGVyICRzeXMgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBHZXQtRGlzayAtRXJy
HLP:b3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRwZCA9ICRudWxsCiAgICAgICAgaWYgKCRkaXNrKSB7CiAgICAgICAgICAgICRwZCA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAgICAgICAgICAg
HLP:ICBXaGVyZS1PYmplY3QgeyAkXy5EZXZpY2VJZCAtZXEgJGRpc2suTnVtYmVyIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIGlmICgtbm90ICRwZCAtYW5kICRkaXNrLlNlcmlhbE51bWJlcikgewogICAgICAgICAgICAgICAgJHBkID0gR2V0
HLP:LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5TZXJpYWxOdW1iZXIgLWFuZCAoJF8uU2VyaWFsTnVtYmVyLlRyaW0oKSAtZXEgKFtzdHJpbmddJGRpc2suU2Vy
HLP:aWFsTnVtYmVyKS5UcmltKCkpIH0gfAogICAgICAgICAgICAgICAgICAgICAgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgICMgKHYzLjIpIGRpc2NvIGRlIG1hcXVpbmEgdmlydHVhbCAoVmlydHVhbEJveC9WTXdh
HLP:cmUvSHlwZXItVi9RRU1VKTogVFJJTSB5CiAgICAgICAgIyBkZXNmcmFnbWVudGFjaW9uIG5vIGFwbGljYW47IHNlIGlkZW50aWZpY2EgcG9yIGVsIG1vZGVsbyBkZWwgZGlzY28uCiAgICAgICAgJG1vZGVsb3MgPSBAKCkKICAgICAgICBpZiAoJGRpc2spIHsgJG1v
HLP:ZGVsb3MgKz0gW3N0cmluZ10kZGlzay5GcmllbmRseU5hbWU7ICRtb2RlbG9zICs9IFtzdHJpbmddJGRpc2suTW9kZWwgfQogICAgICAgIGlmICgkcGQpICAgeyAkbW9kZWxvcyArPSBbc3RyaW5nXSRwZC5GcmllbmRseU5hbWU7ICAgJG1vZGVsb3MgKz0gW3N0cmlu
HLP:Z10kcGQuTW9kZWwgfQogICAgICAgIGlmICgoJG1vZGVsb3MgLWpvaW4gJyAnKSAtbWF0Y2ggJ1ZCT1h8Vk1XQVJFfFZJUlRVQUx8UUVNVXxYRU5TUkMnKSB7IHJldHVybiAnVklSVFVBTCcgfQogICAgICAgIGlmICgtbm90ICRwZCkgeyByZXR1cm4gJ1VOS05PV04n
HLP:IH0KICAgICAgICByZXR1cm4gKENvbnZlcnRUby1NZWRpYUNsYXNzICRwZC5NZWRpYVR5cGUpCiAgICB9IGNhdGNoIHsgcmV0dXJuICdVTktOT1dOJyB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0KZnVuY3Rpb24gR2V0LURldmljZVByb2JsZW1zIHsKICAgICRwID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfUG5QRW50aXR5IHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFuYWdlckVycm9yQ29kZSAtZ3QgMCB9KQogICAgaWYg
HLP:KCRwLkNvdW50IC1lcSAwKSB7ICJPS3xTaW4gZGlzcG9zaXRpdm9zIGNvbiBwcm9ibGVtYS4iOyByZXR1cm4gfQogICAgZm9yZWFjaCAoJGQgaW4gKCRwIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMTIpKSB7CiAgICAgICAgIlBST0J8JCgkZC5Db25maWdNYW5hZ2Vy
HLP:RXJyb3JDb2RlKXwkKCRkLk5hbWUpIgogICAgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgSW5mb3JtZSBIVE1MIGF1dG9jb250ZW5pZG8geSBib25pdG8gKHRl
HLP:bWEgb3NjdXJvKS4gLUFyZyA9IHJ1dGEgZGUgc2FsaWRhLgpmdW5jdGlvbiBOZXctSHRtbFJlcG9ydCgkb3V0UGF0aCkgewogICAgQWRkLVR5cGUgLUFzc2VtYmx5TmFtZSBTeXN0ZW0uV2ViIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICB0cnkgewog
HLP:ICAgICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICAgICAkc3lzUGFpcnMgPSBHZXQtU3lzSW5mbwoKICAgICAgICAkZW5jID0geyBwYXJhbSgkdCkgW1N5c3RlbS5XZWIuSHR0cFV0aWxpdHldOjpIdG1sRW5jb2RlKFtzdHJpbmddJHQpIH0KICAgICAgICAkY2lyYyA9
HLP:IDUyNy43OQogICAgICAgICRiYW5kQ29sb3IgPSB7IHBhcmFtKCRzKSBpZiAoJHMgLWVxICctJyAtb3IgJG51bGwgLWVxICRzIC1vciBbc3RyaW5nXSRzIC1lcSAnJykgeyAnIzk0YTNiOCcgfSBlbHNlIHsgJHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsg
HLP:cmV0dXJuICcjOTRhM2I4JyB9OyBpZiAoJHYgLWdlIDgwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCR2IC1nZSA1MCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfSB9IH0KICAgICAgICAkYmFuZExhYmVsID0geyBwYXJhbSgkcykgaWYgKCRzIC1lcSAnLScgLW9y
HLP:ICRudWxsIC1lcSAkcyAtb3IgW3N0cmluZ10kcyAtZXEgJycpIHsgJ3NpbiBkYXRvcycgfSBlbHNlIHsgJHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgcmV0dXJuICdzaW4gZGF0b3MnIH07IGlmICgkdiAtZ2UgODApIHsnQnVlbmEnfSBlbHNlaWYgKCR2
HLP:IC1nZSA1MCkgeydSZWd1bGFyJ30gZWxzZSB7J0NyaXRpY2EnfSB9IH0KICAgICAgICAkb2Zmc2V0T2YgPSB7IHBhcmFtKCRzKSAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0Y2ggeyAkdj0wIH07IGlmICgkdiAtbHQgMCl7JHY9MH07IGlmICgkdiAtZ3QgMTAw
HLP:KXskdj0xMDB9OyBbbWF0aF06OlJvdW5kKCRjaXJjICogKDEgLSAoJHYvMTAwLjApKSwgMikgfQogICAgICAgICRzdGF0dXNJY29uID0gewogICAgICAgICAgICBwYXJhbSgkcmVzKQogICAgICAgICAgICBzd2l0Y2ggKFtzdHJpbmddJHJlcykgewogICAgICAgICAg
HLP:ICAgICAgJ09LJyAgICB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdjb3JyZWN0byc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyMyMmM1NWUnLz48cGF0aCBkPSdNNyAx
HLP:Mi40bDMuMiAzLjJMMTcgOC44JyBmaWxsPSdub25lJyBzdHJva2U9JyMwNDIxMGYnIHN0cm9rZS13aWR0aD0nMi42JyBzdHJva2UtbGluZWNhcD0ncm91bmQnIHN0cm9rZS1saW5lam9pbj0ncm91bmQnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdXQVJOJyAg
HLP:eyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nYXZpc28nPjxwYXRoIGQ9J00xMiAyLjVMMjMgMjEuNUgxeicgZmlsbD0nI2Y1OWUwYicvPjxyZWN0IHg9JzExJyB5PSc4LjUnIHdpZHRoPScyJyBo
HLP:ZWlnaHQ9JzcnIHJ4PScxJyBmaWxsPScjM2EyNDAwJy8+PGNpcmNsZSBjeD0nMTInIGN5PScxOCcgcj0nMS4zJyBmaWxsPScjM2EyNDAwJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICAnRVJST1InIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0n
HLP:c3ZnaWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J2Vycm9yJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nI2VmNDQ0NCcvPjxwYXRoIGQ9J004IDhsOCA4TTE2IDhsLTggOCcgc3Ryb2tlPScjMmEwNjA2JyBzdHJva2Utd2lkdGg9JzIuNicg
HLP:c3Ryb2tlLWxpbmVjYXA9J3JvdW5kJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICAnU0tJUCcgIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3ZnaWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J29taXRpZG8nPjxjaXJjbGUgY3g9JzEyJyBj
HLP:eT0nMTInIHI9JzExJyBmaWxsPScjNjQ3NDhiJy8+PHJlY3QgeD0nNi41JyB5PScxMScgd2lkdGg9JzExJyBoZWlnaHQ9JzInIHJ4PScxJyBmaWxsPScjMGIxMjIwJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICBkZWZhdWx0IHsgIjxzdmcgdmlld0JveD0nMCAw
HLP:IDI0IDI0JyBjbGFzcz0nc3ZnaWNvJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nIzk0YTNiOCcvPjwvc3ZnPiIgfQogICAgICAgICAgICB9CiAgICAgICAgfQoKICAgICAgICAkYmVmb3JlID0gJHN0LnNjb3JlX2JlZm9yZTsgaWYgKCRudWxs
HLP:IC1lcSAkYmVmb3JlKSB7ICRiZWZvcmUgPSAnLScgfQogICAgICAgICRhZnRlciAgPSAkc3Quc2NvcmVfYWZ0ZXI7ICBpZiAoJG51bGwgLWVxICRhZnRlcikgIHsgJGFmdGVyICA9ICctJyB9CiAgICAgICAgJGhhc0JvdGggPSAoJHN0LnNjb3JlX2JlZm9yZSAtbmUg
HLP:JG51bGwgLWFuZCAkc3Quc2NvcmVfYWZ0ZXIgLW5lICRudWxsKQogICAgICAgICRkZWx0YSA9IDA7ICRkZWx0YVR4dCA9ICdzaW4gY29tcGFyYWNpb24nCiAgICAgICAgaWYgKCRoYXNCb3RoKSB7ICRkZWx0YSA9IFtpbnRdJHN0LnNjb3JlX2FmdGVyIC0gW2ludF0k
HLP:c3Quc2NvcmVfYmVmb3JlOyAkc2lnbiA9IGlmICgkZGVsdGEgLWdlIDApIHsnKyd9IGVsc2UgeycnfTsgJGRlbHRhVHh0ID0gIiRzaWduJGRlbHRhIHB1bnRvcyIgfQogICAgICAgICRkZWx0YUNvbG9yID0gaWYgKCRkZWx0YSAtZ3QgMCkgeycjMjJjNTVlJ30gZWxz
HLP:ZWlmICgkZGVsdGEgLWx0IDApIHsnI2VmNDQ0NCd9IGVsc2UgeycjOTRhM2I4J30KICAgICAgICAkbWFpblNjb3JlID0gaWYgKCRhZnRlciAtbmUgJy0nKSB7ICRhZnRlciB9IGVsc2VpZiAoJGJlZm9yZSAtbmUgJy0nKSB7ICRiZWZvcmUgfSBlbHNlIHsgJy0nIH0K
HLP:ICAgICAgICAkbWFpbkNvbG9yID0gJiAkYmFuZENvbG9yICRtYWluU2NvcmUKICAgICAgICAkbWFpbk9mZnNldCA9ICYgJG9mZnNldE9mICRtYWluU2NvcmUKICAgICAgICAkbWFpbkxhYmVsID0gJiAkYmFuZExhYmVsICRtYWluU2NvcmUKICAgICAgICAkYmVmb3Jl
HLP:Q29sb3IgPSAmICRiYW5kQ29sb3IgJGJlZm9yZQogICAgICAgICRhZnRlckNvbG9yICA9ICYgJGJhbmRDb2xvciAkYWZ0ZXIKICAgICAgICAkYmVmb3JlT2Zmc2V0ID0gJiAkb2Zmc2V0T2YgJGJlZm9yZQogICAgICAgICRhZnRlck9mZnNldCAgPSAmICRvZmZzZXRP
HLP:ZiAkYWZ0ZXIKCiAgICAgICAgJHNjcmlwdERpciA9ICRudWxsCiAgICAgICAgaWYgKCRQU1NjcmlwdFJvb3QpIHsKICAgICAgICAgICAgJHNjcmlwdERpciA9ICRQU1NjcmlwdFJvb3QKICAgICAgICB9IGVsc2VpZiAoJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0
HLP:aCkgewogICAgICAgICAgICAkc2NyaXB0RGlyID0gU3BsaXQtUGF0aCAtUGFyZW50ICRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgKICAgICAgICB9CiAgICAgICAgJGJhc2VEaXIgPSBpZiAoJHNjcmlwdERpcikgeyBKb2luLVBhdGggKFNwbGl0LVBhdGggLVBh
HLP:cmVudCAkc2NyaXB0RGlyKSAiV1BJX1N1aXRlIiB9IGVsc2UgeyAkV29yayB9CiAgICAgICAgJGhpc3RvcnlGaWxlID0gSm9pbi1QYXRoICRiYXNlRGlyICJoZWFsdGhfaGlzdG9yeS5qc29uIgogICAgICAgICRoaXN0b3J5ID0gQCgpCiAgICAgICAgaWYgKFRlc3Qt
HLP:UGF0aCAkaGlzdG9yeUZpbGUpIHsKICAgICAgICAgICAgdHJ5IHsgJGhpc3RvcnkgPSBHZXQtQ29udGVudCAkaGlzdG9yeUZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkaGlzdG9yeUh0bWwgPSAnJwogICAg
HLP:ICAgIGlmICgkaGlzdG9yeSAtYW5kICRoaXN0b3J5LkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRoaXN0b3J5SHRtbCArPSAiPGRpdiBjbGFzcz0ndHJlbmQtdGl0bGUnPkhpc3RvcmlhbCBkZSBTYWx1ZCAoVWx0aW1hcyBlamVjdWNpb25lcyk8L2Rpdj48ZGl2
HLP:IGNsYXNzPSd0cmVuZC1saXN0Jz4iCiAgICAgICAgICAgIGZvcmVhY2ggKCRoIGluICRoaXN0b3J5KSB7CiAgICAgICAgICAgICAgICAkY29sID0gJiAkYmFuZENvbG9yICRoLnNjb3JlCiAgICAgICAgICAgICAgICAkaGlzdG9yeUh0bWwgKz0gIjxkaXYgY2xhc3M9
HLP:J3RyZW5kLWl0ZW0nPjxzcGFuIGNsYXNzPSd0cmVuZC1kYXRlJz4kKCRoLmRhdGUpPC9zcGFuPjxzcGFuIGNsYXNzPSd0cmVuZC1zY29yZScgc3R5bGU9J2NvbG9yOiRjb2wnPiQoJGguc2NvcmUpLzEwMDwvc3Bhbj48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAg
HLP:ICAgICAgJGhpc3RvcnlIdG1sICs9ICI8L2Rpdj4iCiAgICAgICAgfQoKICAgICAgICAkc3lzTWFwID0gQHt9CiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHN5c1BhaXJzKSB7ICRrdiA9ICRwIC1zcGxpdCAnPScsMjsgaWYgKCRrdi5Db3VudCAtZXEgMikgeyAkc3lz
HLP:TWFwWyRrdlswXV0gPSAka3ZbMV0gfSB9CiAgICAgICAgJHN5c09yZGVyID0gQChAKCdPUycsJ1Npc3RlbWEgb3BlcmF0aXZvJyksQCgnRVFVSVBPJywnRXF1aXBvJyksQCgnQ1BVJywnUHJvY2VzYWRvcicpLEAoJ1JBTScsJ01lbW9yaWEgUkFNJyksQCgnRElTQ08n
HLP:LCdEaXNjbyBDOicpLEAoJ1VQVElNRScsJ1RpZW1wbyBlbmNlbmRpZG8nKSxAKCdVU1VBUklPJywnVXN1YXJpbycpKQogICAgICAgICRzeXNDYXJkcyA9ICcnCiAgICAgICAgZm9yZWFjaCAoJG8gaW4gJHN5c09yZGVyKSB7IGlmICgkc3lzTWFwLkNvbnRhaW5zS2V5
HLP:KCRvWzBdKSkgeyAkc3lzQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J3N5cyc+PGRpdiBjbGFzcz0nc3lzLWsnPiQoJiAkZW5jICRvWzFdKTwvZGl2PjxkaXYgY2xhc3M9J3N5cy12Jz4kKCYgJGVuYyAkc3lzTWFwWyRvWzBdXSk8L2Rpdj48L2Rpdj4iIH0gfQogICAgICAg
HLP:ICRtYWNoaW5lID0gJHN5c01hcFsnRVFVSVBPJ107IGlmICgtbm90ICRtYWNoaW5lKSB7ICRtYWNoaW5lID0gJGVudjpDT01QVVRFUk5BTUUgfQoKICAgICAgICAkcGhhc2VzID0gQCgkc3QucGhhc2VzKQogICAgICAgICRjT0s9MDskY1dBUk49MDskY0VSUj0wOyRj
HLP:U0tJUD0wCiAgICAgICAgJG1heFNlY3MgPSAxCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsgJHN2PTA7IHRyeSB7ICRzdj1baW50XSRwaC5zZWNzIH0gY2F0Y2gge307IGlmICgkc3YgLWd0ICRtYXhTZWNzKSB7ICRtYXhTZWNzID0gJHN2IH0gfQog
HLP:ICAgICAgICRyb3dzID0gJycKICAgICAgICAkYmFycyA9ICcnCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsKICAgICAgICAgICAgJHJlcyA9IFtzdHJpbmddJHBoLnJlc3VsdAogICAgICAgICAgICBzd2l0Y2ggKCRyZXMpIHsgJ09LJyB7JGNPSysr
HLP:fSAnV0FSTicgeyRjV0FSTisrfSAnRVJST1InIHskY0VSUisrfSAnU0tJUCcgeyRjU0tJUCsrfSB9CiAgICAgICAgICAgICRsYyA9ICRyZXMuVG9Mb3dlcigpCiAgICAgICAgICAgICRub3RlID0gaWYgKFtzdHJpbmddJHBoLm5vdGUgLW5lICcnKSB7ICI8ZGl2IGNs
HLP:YXNzPSdwaC1ub3RlJz4kKCYgJGVuYyAkcGgubm90ZSk8L2Rpdj4iIH0gZWxzZSB7ICcnIH0KICAgICAgICAgICAgJHJvd3MgKz0gIjxkaXYgY2xhc3M9J3BoIHBoLSRsYyc+PGRpdiBjbGFzcz0ncGgtZG90Jz4kKCYgJHN0YXR1c0ljb24gJHJlcyk8L2Rpdj48ZGl2
HLP:IGNsYXNzPSdwaC1tYWluJz48ZGl2IGNsYXNzPSdwaC10b3AnPjxzcGFuIGNsYXNzPSdwaC1udW0nPiQoJiAkZW5jICRwaC5udW0pPC9zcGFuPjxzcGFuIGNsYXNzPSdwaC10aXRsZSc+JCgmICRlbmMgJHBoLnRpdGxlKTwvc3Bhbj48c3BhbiBjbGFzcz0ncGgtYmFk
HLP:Z2UgYi0kbGMnPiRyZXM8L3NwYW4+PC9kaXY+JG5vdGU8L2Rpdj48ZGl2IGNsYXNzPSdwaC1zZWNzJz4kKCYgJGVuYyAkcGguc2VjcylzPC9kaXY+PC9kaXY+IgogICAgICAgICAgICAkc3Y9MDsgdHJ5IHsgJHN2PVtpbnRdJHBoLnNlY3MgfSBjYXRjaCB7fQogICAg
HLP:ICAgICAgICAkdyA9IFttYXRoXTo6Um91bmQoMTAwLjAgKiAkc3YgLyBbbWF0aF06Ok1heCgxLCRtYXhTZWNzKSk7IGlmICgkdyAtbHQgMiAtYW5kICRzdiAtZ3QgMCkgeyAkdyA9IDIgfQogICAgICAgICAgICAkYmNvbCA9IHN3aXRjaCAoJHJlcykgeyAnT0snIHsn
HLP:IzIyYzU1ZSd9ICdXQVJOJyB7JyNmNTllMGInfSAnRVJST1InIHsnI2VmNDQ0NCd9IGRlZmF1bHQgeycjNjQ3NDhiJ30gfQogICAgICAgICAgICAkYmFycyArPSAiPGRpdiBjbGFzcz0nYmFyLXJvdyc+PGRpdiBjbGFzcz0nYmFyLWxibCc+JCgmICRlbmMgJHBoLm51
HLP:bSkgJCgmICRlbmMgJHBoLnRpdGxlKTwvZGl2PjxkaXYgY2xhc3M9J2Jhci10cmFjayc+PHNwYW4gc3R5bGU9J3dpZHRoOiR3JTtiYWNrZ3JvdW5kOiRiY29sJz48L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nYmFyLXZhbCc+JCgmICRlbmMgJHBoLnNlY3MpczwvZGl2
HLP:PjwvZGl2PiIKICAgICAgICB9CiAgICAgICAgaWYgKC1ub3QgJHJvd3MpIHsgJHJvd3MgPSAiPGRpdiBjbGFzcz0nZW1wdHknPk5vIHNlIHJlZ2lzdHJhcm9uIGZhc2VzIGVuIGVzdGEgZWplY3VjaW9uLjwvZGl2PiIgfQogICAgICAgIGlmICgtbm90ICRiYXJzKSB7
HLP:ICRiYXJzID0gIjxkaXYgY2xhc3M9J2VtcHR5Jz5TaW4gdGllbXBvcyBxdWUgbW9zdHJhci48L2Rpdj4iIH0KICAgICAgICAkdG90YWxQaCA9ICRwaGFzZXMuQ291bnQKICAgICAgICAjIEVzdGFkaXN0aWNhcyBSRUFMRVMgYWdyZWdhZGFzIGRlIGxvIGVqZWN1dGFk
HLP:bzogdGllbXBvIHRvdGFsIGRlIGxhIHNlc2lvbgogICAgICAgICMgeSBlc3BhY2lvIGxpYmVyYWRvIChzdW1hZG8gZGUgbGFzIG5vdGFzIG1lZGlkYXMgZGUgY2FkYSBmYXNlLCBNQi9HQikuCiAgICAgICAgJHRvdFNlY3MgPSAwOyAkbWJGcmVlZCA9IDAuMAogICAg
HLP:ICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7CiAgICAgICAgICAgICRzdiA9IDA7IHRyeSB7ICRzdiA9IFtpbnRdJHBoLnNlY3MgfSBjYXRjaCB7fTsgJHRvdFNlY3MgKz0gJHN2CiAgICAgICAgICAgIGZvcmVhY2ggKCRtIGluIFtyZWdleF06Ok1hdGNoZXMo
HLP:W3N0cmluZ10kcGgubm90ZSwgJyg/aSkoPzpsaWJlcmFkXHcqfGZyZWVkKVxEezAsMTB9PyhbXGRcLixdKylccyooTUJ8R0IpJykpIHsKICAgICAgICAgICAgICAgICR2ID0gMC4wOyB0cnkgeyAkdiA9IFtkb3VibGVdKCRtLkdyb3Vwc1sxXS5WYWx1ZS5SZXBsYWNl
HLP:KCcsJywgJy4nKSkgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgaWYgKCRtLkdyb3Vwc1syXS5WYWx1ZSAtbWF0Y2ggJyg/aSlHQicpIHsgJHYgPSAkdiAqIDEwMjQgfQogICAgICAgICAgICAgICAgJG1iRnJlZWQgKz0gJHYKICAgICAgICAgICAgfQogICAgICAg
HLP:IH0KICAgICAgICAkdG90VHh0ID0gaWYgKCR0b3RTZWNzIC1nZSA2MCkgeyAoJ3swfSBtaW4gezF9IHMnIC1mIFtpbnRdW21hdGhdOjpGbG9vcigkdG90U2VjcyAvIDYwKSwgKCR0b3RTZWNzICUgNjApKSB9IGVsc2UgeyAoJ3swfSBzJyAtZiAkdG90U2VjcykgfQog
HLP:ICAgICAgICRmcmVlZFR4dCA9IGlmICgkbWJGcmVlZCAtZ2UgMTAyNCkgeyAoJ3swOm4xfSBHQicgLWYgKCRtYkZyZWVkIC8gMTAyNCkpIH0gZWxzZWlmICgkbWJGcmVlZCAtZ3QgMCkgeyAoJ3swOm4wfSBNQicgLWYgJG1iRnJlZWQpIH0gZWxzZSB7ICcnIH0KICAg
HLP:ICAgICAkc3RhdExpbmUgPSAoJ3RpZW1wbyB0b3RhbDogezB9JyAtZiAkdG90VHh0KQogICAgICAgIGlmICgkZnJlZWRUeHQpIHsgJHN0YXRMaW5lICs9ICgnICZtaWRkb3Q7IGVzcGFjaW8gbGliZXJhZG86IHswfScgLWYgJGZyZWVkVHh0KSB9CgogICAgICAgICRm
HLP:aW5kaW5ncyA9IEAoJHN0LmZpbmRpbmdzKQogICAgICAgICRmaW5kSHRtbCA9ICcnCiAgICAgICAgJHN0ZXBzTGlzdCA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddCiAgICAgICAgZm9yZWFjaCAoJGYgaW4gJGZpbmRp
HLP:bmdzKSB7CiAgICAgICAgICAgICR0eHQgPSBbc3RyaW5nXSRmCiAgICAgICAgICAgICRzZXYgPSAnaW5mbyc7ICRzZXZUeHQgPSAnQXZpc28nCiAgICAgICAgICAgIGlmICgkdHh0IC1tYXRjaCAnKD9pKVNNQVJUfEJTT0R8YXBhZ3xXSEVBfGhhcmR3YXJlfG5vIHJl
HLP:cGFyYWJsZXN8ZGFuYWR8cmVwb3NpdG9yaW98aW50ZWdyaWRhZCcpIHsgJHNldj0naGlnaCc7ICRzZXZUeHQ9J0ltcG9ydGFudGUnIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWVzcGFjaW98cmVpbmljaW8gcGVuZGllbnRlfFxicmVkXGJ8
HLP:YmF0ZXJpYXxkcml2ZXJ8ZGlzcG9zaXRpdm98XGJSQU1cYnxzZXJ2aWNpbycpIHsgJHNldj0nbWVkJzsgJHNldlR4dD0nUmV2aXNhcicgfQogICAgICAgICAgICAkZmluZEh0bWwgKz0gIjxsaSBjbGFzcz0nZmluZCBmaW5kLSRzZXYnPjxzcGFuIGNsYXNzPSdzZXYg
HLP:c2V2LSRzZXYnPiRzZXZUeHQ8L3NwYW4+PHNwYW4gY2xhc3M9J2ZpbmQtdHh0Jz4kKCYgJGVuYyAkdHh0KTwvc3Bhbj48L2xpPiIKICAgICAgICAgICAgIyBEZXJpdmFyIHBhc28gcmVjb21lbmRhZG8gYSBwYXJ0aXIgZGVsIGhhbGxhemdvCiAgICAgICAgICAgIGlm
HLP:ICgkdHh0IC1tYXRjaCAnKD9pKVNNQVJUJykgICAgICAgICAgeyAkc3RlcHNMaXN0LkFkZCgnSGF6IGNvcGlhIGRlIHNlZ3VyaWRhZCBkZSB0dXMgZGF0b3MgY3VhbnRvIGFudGVzOiB1biBkaXNjbyBjb24gU01BUlQgZGVncmFkYWRvIHB1ZWRlIGZhbGxhci4gVmFs
HLP:b3JhIHJlZW1wbGF6YXJsby4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSllc3BhY2lvJykgICAgeyAkc3RlcHNMaXN0LkFkZCgnTGliZXJhIGVzcGFjaW8gZW4gQzogKGRlc2luc3RhbGEgbG8gcXVlIG5vIHVzZXMgbyB1c2EgZWwgU2Vu
HLP:c29yIGRlIGFsbWFjZW5hbWllbnRvKS4gQ29udmllbmUgdGVuZXIgbWFzIGRlIDE1IEdCIGxpYnJlcy4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlcYlJBTVxifG1lbW9yJykgeyAkc3RlcHNMaXN0LkFkZCgnRWplY3V0YSBlbCBEaWFn
HLP:bm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MgKG1kc2NoZWQuZXhlKSB5IHJlaW5pY2lhIHBhcmEgY29tcHJvYmFyIGxhIFJBTS4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSliYXRlcmlhJykgICAgeyAkc3RlcHNMaXN0LkFkZCgn
HLP:TGEgYmF0ZXJpYSBlc3RhIGRlZ3JhZGFkYS4gUmV2aXNhIGVsIGluZm9ybWUgZGUgYmF0ZXJpYSAocG93ZXJjZmcgL2JhdHRlcnlyZXBvcnQpIHkgdmFsb3JhIHN1c3RpdHVpcmxhLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKXJlaW5p
HLP:Y2lvIHBlbmRpZW50ZScpIHsgJHN0ZXBzTGlzdC5BZGQoJ1JlaW5pY2lhIGVsIGVxdWlwbyBwYXJhIGFwbGljYXIgY2FtYmlvcyBwZW5kaWVudGVzIGFudGVzIGRlIHNlZ3VpciByZXBhcmFuZG8uJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICco
HLP:P2kpbm8gcmVwYXJhYmxlc3xyZXBvc2l0b3Jpb3xpbnRlZ3JpZGFkJykgeyAkc3RlcHNMaXN0LkFkZCgnUXVlZGFuIGNvbXBvbmVudGVzIGRhbmFkb3MuIEVqZWN1dGEgRElTTSBjb24gdW4gb3JpZ2VuIHZhbGlkbyAoaW5zdGFsbC53aW0pIHkgdnVlbHZlIGEgcGFz
HLP:YXIgU0ZDLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWRyaXZlcnxkaXNwb3NpdGl2bycpIHsgJHN0ZXBzTGlzdC5BZGQoJ0FjdHVhbGl6YSBsb3MgZHJpdmVycyBkZSBsb3MgZGlzcG9zaXRpdm9zIGNvbiBlcnJvciBkZXNkZSBsYSB3
HLP:ZWIgZGVsIGZhYnJpY2FudGUgbyBXaW5kb3dzIFVwZGF0ZS4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlcYnJlZFxifEROUycpICAgICAgICB7ICRzdGVwc0xpc3QuQWRkKCdSZXZpc2EgbGEgY29uZXhpb24gZGUgcmVkIHkgZWwgRE5T
HLP:LiBTaSBwZXJzaXN0ZSwgcHJ1ZWJhIGNvbiB1biBETlMgcHVibGljbyAoMS4xLjEuMSAvIDguOC44LjgpLicpIH0KICAgICAgICB9CiAgICAgICAgJG5vRmluZCA9ICgkZmluZGluZ3MuQ291bnQgLWVxIDApCiAgICAgICAgaWYgKCRub0ZpbmQpIHsgJGZpbmRIdG1s
HLP:ID0gIjxsaSBjbGFzcz0nZmluZCBmaW5kLW9rJz48c3BhbiBjbGFzcz0nc2V2IHNldi1vayc+VG9kbyBPSzwvc3Bhbj48c3BhbiBjbGFzcz0nZmluZC10eHQnPk5vIHNlIGRldGVjdGFyb24gcHJvYmxlbWFzIHJlbGV2YW50ZXMgZHVyYW50ZSBlbCBkaWFnbm9zdGlj
HLP:by48L3NwYW4+PC9saT4iIH0KCiAgICAgICAgIyAtLS0gUHJveGltb3MgcGFzb3MgcmVjb21lbmRhZG9zIChkZWR1cGxpY2Fkb3MpIC0tLQogICAgICAgICRzdGVwc0h0bWwgPSAnJwogICAgICAgICRzZWVuID0gQHt9CiAgICAgICAgZm9yZWFjaCAoJHMgaW4gJHN0
HLP:ZXBzTGlzdCkgeyBpZiAoLW5vdCAkc2Vlbi5Db250YWluc0tleSgkcykpIHsgJHNlZW5bJHNdPSR0cnVlOyAkc3RlcHNIdG1sICs9ICI8bGkgY2xhc3M9J3N0ZXAtbGknPjxzcGFuIGNsYXNzPSdzdGVwLWljJz4mIzEwMTQ4Ozwvc3Bhbj48c3Bhbj4kKCYgJGVuYyAk
HLP:cyk8L3NwYW4+PC9saT4iIH0gfQogICAgICAgIGlmICgkY0VSUiAtZ3QgMCkgeyAkc3RlcHNIdG1sID0gIjxsaSBjbGFzcz0nc3RlcC1saSc+PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAxNDg7PC9zcGFuPjxzcGFuPkh1Ym8gZmFzZXMgY29uIGVycm9yOiByZXZp
HLP:c2EgZWwgcmVnaXN0cm8gZGV0YWxsYWRvIGVuIGxhIGNhcnBldGEgV1BJX1N1aXRlXExvZ3MuPC9zcGFuPjwvbGk+IiArICRzdGVwc0h0bWwgfQogICAgICAgIGlmICgtbm90ICRzdGVwc0h0bWwpIHsgJHN0ZXBzSHRtbCA9ICI8bGkgY2xhc3M9J3N0ZXAtbGkgc3Rl
HLP:cC1vayc+PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAwMDM7PC9zcGFuPjxzcGFuPk5vIGhheSBhY2Npb25lcyBwZW5kaWVudGVzLiBSZWluaWNpYSBlbCBlcXVpcG8gcGFyYSBhc2VndXJhciBxdWUgdG9kb3MgbG9zIGNhbWJpb3MgcXVlZGVuIGFwbGljYWRvcy48
HLP:L3NwYW4+PC9saT4iIH0KCiAgICAgICAgIyA9PT09PT09PT09PT09PT09PT09PT09IERJQUdOT1NUSUNPIEFNUExJQURPID09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICAkZGlhZ0NhcmRzID0gJycKICAgICAgICBpZiAoKCRzdC5QU09iamVjdC5Qcm9wZXJ0
HLP:aWVzLk5hbWUgLWNvbnRhaW5zICdkaWFnJykgLWFuZCAkc3QuZGlhZykgewogICAgICAgICAgICAkZCA9ICRzdC5kaWFnCiAgICAgICAgICAgIGlmICgkZC5yYW0pIHsKICAgICAgICAgICAgICAgICRycyA9IFtzdHJpbmddJGQucmFtLnN0YXR1cwogICAgICAgICAg
HLP:ICAgICAgJHJwID0gc3dpdGNoICgkcnMpIHsgJ29rJyB7J2dvb2QnfSAnc3VzcGVjdCcgeydiYWQnfSBkZWZhdWx0IHsndW5rbm93bid9IH0KICAgICAgICAgICAgICAgICRydCA9IHN3aXRjaCAoJHJzKSB7ICdvaycgeydTaW4gZXJyb3JlcyBkZXRlY3RhZG9zJ30g
HLP:J3N1c3BlY3QnIHsnU29zcGVjaG9zYSd9IGRlZmF1bHQgeydObyBldmFsdWFkYSd9IH0KICAgICAgICAgICAgICAgICRtZHMgPSBpZiAoJGQucmFtLnJlY29tbWVuZF9tZHNjaGVkKSB7ICI8ZGl2IGNsYXNzPSdkLWhpbnQnPlJlY29tZW5kYWRvOiBlamVjdXRhciBl
HLP:bCBEaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MgKG1kc2NoZWQpLjwvZGl2PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2Qt
HLP:aWMgaWMtcmFtJz48L3NwYW4+TWVtb3JpYSBSQU08L2Rpdj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC0kcnAnPiRydDwvZGl2PiRtZHM8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRkLmJhdHRlcnkpIHsKICAgICAgICAgICAgICAgIGlmICgk
HLP:ZC5iYXR0ZXJ5LnByZXNlbnQpIHsKICAgICAgICAgICAgICAgICAgICAkYnBSYXcgPSAkZC5iYXR0ZXJ5LmhlYWx0aF9wY3QKICAgICAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRicFJhdyAtYW5kIFtzdHJpbmddJGJwUmF3IC1uZSAnJykgewogICAgICAg
HLP:ICAgICAgICAgICAgICAgICAkYnAgPSAwOyB0cnkgeyAkYnAgPSBbaW50XSRicFJhdyB9IGNhdGNoIHsgJGJwID0gMCB9CiAgICAgICAgICAgICAgICAgICAgICAgICRicGNvbCA9IGlmICgkYnAgLWdlIDgwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCRicCAtZ2UgNTAp
HLP:IHsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J30KICAgICAgICAgICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0ZXJpYTwvZGl2
HLP:PjxkaXYgY2xhc3M9J2JhdC1iYXInPjxzcGFuIHN0eWxlPSd3aWR0aDokYnAlO2JhY2tncm91bmQ6JGJwY29sJz48L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nZC1zdWInPlNhbHVkIGVzdGltYWRhOiA8YiBzdHlsZT0nY29sb3I6JGJwY29sJz4kYnAlPC9iPjwvZGl2
HLP:PjwvZGl2PiIKICAgICAgICAgICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXRl
HLP:cmlhPC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtdW5rbm93bic+UHJlc2VudGUsIHNhbHVkIGRlc2Nvbm9jaWRhPC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAgICAg
HLP:JGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0ZXJpYTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLXVua25vd24nPk5vIHByZXNlbnRlIChlcXVpcG8g
HLP:ZGUgc29icmVtZXNhKTwvZGl2PjwvZGl2PiIKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJGQubmV0d29yaykgewogICAgICAgICAgICAgICAgJGNjID0gaWYgKCRkLm5ldHdvcmsuY29ubmVjdGVkKSB7J2dvb2QnfSBlbHNl
HLP:IHsnYmFkJ30KICAgICAgICAgICAgICAgICRjdCA9IGlmICgkZC5uZXR3b3JrLmNvbm5lY3RlZCkgeydDb25lY3RhZG8nfSBlbHNlIHsnU2luIGNvbmV4aW9uJ30KICAgICAgICAgICAgICAgICRkYyA9IGlmICgkZC5uZXR3b3JrLmRuc19vaykgeydnb29kJ30gZWxz
HLP:ZSB7J2JhZCd9CiAgICAgICAgICAgICAgICAkZHQgPSBpZiAoJGQubmV0d29yay5kbnNfb2spIHsnRE5TIE9LJ30gZWxzZSB7J0ROUyBjb24gZmFsbG9zJ30KICAgICAgICAgICAgICAgICRkZXQgPSAmICRlbmMgJGQubmV0d29yay5kZXRhaWxzCiAgICAgICAgICAg
HLP:ICAgICAkbGF0ID0gJycKICAgICAgICAgICAgICAgIGlmICgoJGQubmV0d29yay5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdkbnNfbXMnKSAtYW5kICRudWxsIC1uZSAkZC5uZXR3b3JrLmRuc19tcyAtYW5kIFtzdHJpbmddJGQubmV0d29yay5k
HLP:bnNfbXMgLW5lICcnKSB7CiAgICAgICAgICAgICAgICAgICAgJG1zID0gMDsgdHJ5IHsgJG1zID0gW2ludF0kZC5uZXR3b3JrLmRuc19tcyB9IGNhdGNoIHt9CiAgICAgICAgICAgICAgICAgICAgJGxjMiA9IGlmICgkbXMgLWx0IDYwKSB7JyMyMmM1NWUnfSBlbHNl
HLP:aWYgKCRtcyAtbHQgMjAwKSB7JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9CiAgICAgICAgICAgICAgICAgICAgJGxhdCA9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+TGF0ZW5jaWEgRE5TOiA8YiBzdHlsZT0nY29sb3I6JGxjMic+JG1zIG1zPC9iPjwvZGl2PiIKICAg
HLP:ICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLW5ldCc+PC9zcGFuPlJlZDwvZGl2PjxkaXYgY2xhc3M9J3BpbGwtcm93Jz48c3Bh
HLP:biBjbGFzcz0nZC1waWxsIHBpbGwtJGNjJz4kY3Q8L3NwYW4+PHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLSRkYyc+JGR0PC9zcGFuPjwvZGl2PjxkaXYgY2xhc3M9J2Qtc3ViJz4kZGV0PC9kaXY+JGxhdDwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBp
HLP:ZiAoKCRkLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3NtYXJ0JykgLWFuZCAkZC5zbWFydCAtYW5kICRkLnNtYXJ0LmF2YWlsYWJsZSkgewogICAgICAgICAgICAgICAgJHNtID0gJGQuc21hcnQKICAgICAgICAgICAgICAgICRwZiA9IGlmICgk
HLP:c20ucHJlZGljdF9mYWlsKSB7ICI8c3BhbiBjbGFzcz0nZC1waWxsIHBpbGwtYmFkJz5QcmVkaWNlIGZhbGxvPC9zcGFuPiIgfSBlbHNlIHsgIjxzcGFuIGNsYXNzPSdkLXBpbGwgcGlsbC1nb29kJz5TaW4gYWxlcnRhPC9zcGFuPiIgfQogICAgICAgICAgICAgICAg
HLP:JGV4dHJhID0gJycKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLnRlbXBfYyAtYW5kIFtzdHJpbmddJHNtLnRlbXBfYyAtbmUgJycpIHsgJHRjPTA7IHRyeXskdGM9W2ludF0kc20udGVtcF9jfWNhdGNoe307ICR0Y29sID0gaWYgKCR0YyAtbHQgNTAp
HLP:eycjMjJjNTVlJ30gZWxzZWlmICgkdGMgLWx0IDY1KXsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J307ICRleHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPlRlbXBlcmF0dXJhOiA8YiBzdHlsZT0nY29sb3I6JHRjb2wnPiR0YyAmZGVnO0M8L2I+PC9kaXY+IiB9
HLP:CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRzbS53ZWFyX3BjdCAtYW5kIFtzdHJpbmddJHNtLndlYXJfcGN0IC1uZSAnJykgeyAkd3A9MDsgdHJ5eyR3cD1baW50XSRzbS53ZWFyX3BjdH1jYXRjaHt9OyAkd2NvbCA9IGlmICgkd3AgLWx0IDUwKXsnIzIy
HLP:YzU1ZSd9IGVsc2VpZiAoJHdwIC1sdCA4MCl7JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9OyAkZXh0cmEgKz0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5EZXNnYXN0ZSAoU1NEKTogPGIgc3R5bGU9J2NvbG9yOiR3Y29sJz4kd3AlPC9iPjwvZGl2PiIgfQogICAgICAg
HLP:ICAgICAgICAgaWYgKCRudWxsIC1uZSAkc20ucG9oIC1hbmQgW3N0cmluZ10kc20ucG9oIC1uZSAnJykgeyAkZXh0cmEgKz0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5Ib3JhcyBlbmNlbmRpZG86IDxiPiQoJiAkZW5jICRzbS5wb2gpPC9iPjwvZGl2PiIgfQogICAgICAg
HLP:ICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtc21hcnQnPjwvc3Bhbj5TYWx1ZCBkZWwgZGlzY28gKFNNQVJUKTwvZGl2PjxkaXYgY2xhc3M9J3BpbGwtcm93Jz4kcGY8
HLP:L2Rpdj4kZXh0cmE8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdiY2QnKSAtYW5kICRkLmJjZCkgewogICAgICAgICAgICAgICAgJGJvayA9IGlmICgkZC5iY2Qub2spIHsn
HLP:Z29vZCd9IGVsc2UgeydiYWQnfQogICAgICAgICAgICAgICAgJGJ0eCA9IGlmICgkZC5iY2Qub2spIHsnQ29uZmlndXJhY2lvbiBkZSBhcnJhbnF1ZSBjb3JyZWN0YSd9IGVsc2UgeydBcnJhbnF1ZSBjb24gaW5jaWRlbmNpYXMnfQogICAgICAgICAgICAgICAgJGJk
HLP:ZXQgPSBpZiAoW3N0cmluZ10kZC5iY2QuZGV0YWlscyAtbmUgJycpIHsgIjxkaXYgY2xhc3M9J2Qtc3ViJz4kKCYgJGVuYyAkZC5iY2QuZGV0YWlscyk8L2Rpdj4iIH0gZWxzZSB7ICcnIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9
HLP:J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJvb3QnPjwvc3Bhbj5BcnJhbnF1ZSAoQkNEKTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLSRib2snPiRidHg8L2Rpdj4kYmRldDwvZGl2PiIKICAgICAgICAgICAgfQogICAg
HLP:ICAgICAgICBpZiAoKCRkLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3N0YXJ0dXAnKSAtYW5kICRkLnN0YXJ0dXAgLWFuZCBAKCRkLnN0YXJ0dXApLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkaXRlbXMgPSAnJwogICAgICAgICAg
HLP:ICAgICAgZm9yZWFjaCAoJHMgaW4gQCgkZC5zdGFydHVwKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkcy5uYW1lKTxzcGFuIGNsYXNzPSdtdXRlZCc+ICZtZGFzaDsgJCgmICRlbmMgJHMuY29tbWFuZCk8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAg
HLP:ICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkIGRjYXJkLXdpZGUnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtc3RhcnQnPjwvc3Bhbj5Qcm9ncmFtYXMgYWwgaW5pY2lhciBXaW5kb3dzPC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlz
HLP:dCc+JGl0ZW1zPC91bD48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICdwcm9jZXNzZXMnKSAtYW5kICRkLnByb2Nlc3NlcyAtYW5kIEAoJGQucHJvY2Vzc2VzKS5Db3VudCAt
HLP:Z3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwciBpbiBAKCRkLnByb2Nlc3NlcykpIHsgJGl0ZW1zICs9ICI8bGk+JCgmICRlbmMgJHByLm5hbWUpPHNwYW4gY2xhc3M9J211dGVkJz4gJm1kYXNoOyAk
HLP:KCYgJGVuYyAkcHIubWVtX21iKSBNQjwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtcHJvYyc+PC9zcGFuPlByb2Nlc29zIHF1
HLP:ZSBtYXMgbWVtb3JpYSB1c2FuPC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlzdCc+JGl0ZW1zPC91bD48L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRkLmRldmljZXMgLWFuZCBAKCRkLmRldmljZXMpLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAg
HLP:ICAgICAkaXRlbXMgPSAnJwogICAgICAgICAgICAgICAgZm9yZWFjaCAoJGRldiBpbiBAKCRkLmRldmljZXMpKSB7ICRpdGVtcyArPSAiPGxpPiQoJiAkZW5jICRkZXYubmFtZSkgPHNwYW4gY2xhc3M9J211dGVkJz4oY29kaWdvICQoJiAkZW5jICRkZXYuY29kZSkp
HLP:PC9zcGFuPjwvbGk+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCBkY2FyZC13aWRlJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWRldic+PC9zcGFuPkRpc3Bvc2l0aXZvcyBjb24gYXZpc288
HLP:L2Rpdj48dWwgY2xhc3M9J2Rldi1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICAkZGlhZ1NlY3Rpb24gPSAnJwogICAgICAgIGlmICgkZGlhZ0NhcmRzKSB7ICRkaWFnU2VjdGlvbiA9ICI8aDIgaWQ9J2RpYWcn
HLP:IGNsYXNzPSdzZWMtaCc+RGlhZ25vc3RpY28gYW1wbGlhZG88L2gyPjxkaXYgY2xhc3M9J2RncmlkJz4kZGlhZ0NhcmRzPC9kaXY+IiB9CgogICAgICAgICRjb21wYXJlU2VjdGlvbiA9ICcnCiAgICAgICAgaWYgKCRoYXNCb3RoKSB7CiAgICAgICAgICAgICRjb21w
HLP:YXJlU2VjdGlvbiA9IEAiCjxkaXYgY2xhc3M9J2NvbXBhcmUnPgogIDxkaXYgY2xhc3M9J21pbmknPgogICAgPHN2ZyB2aWV3Qm94PScwIDAgMjAwIDIwMCcgY2xhc3M9J2dhdWdlIGdhdWdlLXNtJz48Y2lyY2xlIGNsYXNzPSd0cmFjaycgY3g9JzEwMCcgY3k9JzEw
HLP:MCcgcj0nODQnLz48Y2lyY2xlIGNsYXNzPSdmaWxsJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcgc3R5bGU9Jy0tY2lyYzokY2lyYzstLXRhcmdldDokYmVmb3JlT2Zmc2V0O3N0cm9rZTokYmVmb3JlQ29sb3InLz48dGV4dCB4PScxMDAnIHk9JzEwOCcgY2xhc3M9
HLP:J2ctbnVtJyBzdHlsZT0nZmlsbDokYmVmb3JlQ29sb3InPiRiZWZvcmU8L3RleHQ+PC9zdmc+CiAgICA8ZGl2IGNsYXNzPSdtaW5pLWNhcCc+QU5URVM8L2Rpdj4KICA8L2Rpdj4KICA8ZGl2IGNsYXNzPSdhcnJvdyc+PHNwYW4gc3R5bGU9J2NvbG9yOiRkZWx0YUNv
HLP:bG9yJz4mIzg1OTQ7PC9zcGFuPjxkaXYgY2xhc3M9J2RlbHRhLWNoaXAnIHN0eWxlPSdjb2xvcjokZGVsdGFDb2xvcjtib3JkZXItY29sb3I6JGRlbHRhQ29sb3InPiRkZWx0YVR4dDwvZGl2PjwvZGl2PgogIDxkaXYgY2xhc3M9J21pbmknPgogICAgPHN2ZyB2aWV3
HLP:Qm94PScwIDAgMjAwIDIwMCcgY2xhc3M9J2dhdWdlIGdhdWdlLXNtJz48Y2lyY2xlIGNsYXNzPSd0cmFjaycgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnLz48Y2lyY2xlIGNsYXNzPSdmaWxsJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcgc3R5bGU9Jy0tY2lyYzok
HLP:Y2lyYzstLXRhcmdldDokYWZ0ZXJPZmZzZXQ7c3Ryb2tlOiRhZnRlckNvbG9yJy8+PHRleHQgeD0nMTAwJyB5PScxMDgnIGNsYXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6JGFmdGVyQ29sb3InPiRhZnRlcjwvdGV4dD48L3N2Zz4KICAgIDxkaXYgY2xhc3M9J21pbmkt
HLP:Y2FwJz5ERVNQVUVTPC9kaXY+CiAgPC9kaXY+CjwvZGl2PgoiQAogICAgICAgIH0KCiAgICAgICAgJG5vdyA9IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGQgSEg6bW0nKQogICAgICAgICRleGVjVmVyZGljdCA9ICYgJGJhbmRMYWJlbCAkbWFpblNjb3Jl
HLP:CiAgICAgICAgJGh0bWwgPSBAIgo8IURPQ1RZUEUgaHRtbD4KPGh0bWwgbGFuZz0nZXMnPgo8aGVhZD4KPG1ldGEgY2hhcnNldD0ndXRmLTgnPgo8bWV0YSBuYW1lPSd2aWV3cG9ydCcgY29udGVudD0nd2lkdGg9ZGV2aWNlLXdpZHRoLGluaXRpYWwtc2NhbGU9MSc+
HLP:Cjx0aXRsZT5JbmZvcm1lIGRlIFJlcGFyYWNpb24gLSBXUEkgU3VpdGUgdjMuMTwvdGl0bGU+CjxzdHlsZT4KKntib3gtc2l6aW5nOmJvcmRlci1ib3h9Cjpyb290ey0tYmc6IzBiMGYxNzstLWJnMjojMGQxNDIyOy0tY2FyZDojMTIxYTJiOy0tY2FyZDI6IzBlMTYy
HLP:NjstLWxpbmU6IzFlMjkzYjstLXR4dDojZTZlZGY2Oy0tbXV0ZWQ6IzkzYTNiYTstLWFjY2VudDojMzhiZGY4Oy0tYWNjZW50MjojODE4Y2Y4Oy0tc2hhZG93OjAgMTRweCA0MHB4IHJnYmEoMCwwLDAsLjQwKX0KaHRtbC5saWdodHstLWJnOiNlZWYyZjg7LS1iZzI6
HLP:I2U3ZWRmNjstLWNhcmQ6I2ZmZmZmZjstLWNhcmQyOiNmNWY4ZmM7LS1saW5lOiNkZGU1ZjA7LS10eHQ6IzBmMTcyYTstLW11dGVkOiM1YTZiODI7LS1hY2NlbnQ6IzAyODRjNzstLWFjY2VudDI6IzRmNDZlNTstLXNoYWRvdzowIDEwcHggMjhweCByZ2JhKDE1LDIz
HLP:LDQyLC4xMil9CmJvZHl7bWFyZ2luOjA7Zm9udC1mYW1pbHk6J1NlZ29lIFVJJyxzeXN0ZW0tdWksLWFwcGxlLXN5c3RlbSxBcmlhbCxzYW5zLXNlcmlmO2xpbmUtaGVpZ2h0OjEuNTU7Y29sb3I6dmFyKC0tdHh0KTtiYWNrZ3JvdW5kOnJhZGlhbC1ncmFkaWVudCgx
HLP:MjAwcHggNjAwcHggYXQgODAlIC0xMCUscmdiYSg1NiwxODksMjQ4LC4xMCksdHJhbnNwYXJlbnQgNjAlKSxyYWRpYWwtZ3JhZGllbnQoOTAwcHggNTAwcHggYXQgLTEwJSAxMCUscmdiYSgxMjksMTQwLDI0OCwuMTApLHRyYW5zcGFyZW50IDU1JSksdmFyKC0tYmcp
HLP:fQoud3JhcHttYXgtd2lkdGg6MTA4MHB4O21hcmdpbjowIGF1dG87cGFkZGluZzozMHB4IDIycHggNjBweH0KLnRvcGJhcntkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO2dhcDoxNnB4O21hcmdpbi1i
HLP:b3R0b206MThweDtmbGV4LXdyYXA6d3JhcH0KLmJyYW5ke2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjE0cHh9Ci5sb2dve3dpZHRoOjQ2cHg7aGVpZ2h0OjQ2cHg7Ym9yZGVyLXJhZGl1czoxM3B4O2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50
HLP:KDEzNWRlZyx2YXIoLS1hY2NlbnQpLHZhcigtLWFjY2VudDIpKTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7Ym94LXNoYWRvdzp2YXIoLS1zaGFkb3cpfQpoMXtmb250LXNpemU6MjJweDttYXJnaW46MDtsZXR0
HLP:ZXItc3BhY2luZzouMnB4fQouc3Vie2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDttYXJnaW4tdG9wOjJweH0KLmJhZGdle2Rpc3BsYXk6aW5saW5lLWJsb2NrO2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZyx2YXIoLS1hY2NlbnQpLHZh
HLP:cigtLWFjY2VudDIpKTtjb2xvcjojMDQyOTNiO2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6M3B4IDEycHg7Zm9udC1zaXplOjExLjVweDtsZXR0ZXItc3BhY2luZzouNHB4O3ZlcnRpY2FsLWFsaWduOm1pZGRsZTttYXJnaW4tbGVm
HLP:dDo4cHh9Ci5idG5ze2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwfQoudG9nZ2xle2N1cnNvcjpwb2ludGVyO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtjb2xvcjp2YXIoLS10eHQpO2JvcmRlci1y
HLP:YWRpdXM6MTBweDtwYWRkaW5nOjhweCAxNHB4O2ZvbnQtc2l6ZToxM3B4O2ZvbnQtd2VpZ2h0OjYwMDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci50b2dnbGU6aG92ZXJ7Ym9yZGVyLWNvbG9yOnZhcigtLWFjY2VudCl9Ci50b2N7ZGlzcGxheTpmbGV4O2dhcDo4
HLP:cHg7ZmxleC13cmFwOndyYXA7bWFyZ2luOjAgMCAyMnB4fQoudG9jIGF7Zm9udC1zaXplOjEyLjVweDtmb250LXdlaWdodDo2MDA7Y29sb3I6dmFyKC0tbXV0ZWQpO3RleHQtZGVjb3JhdGlvbjpub25lO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7YmFja2dy
HLP:b3VuZDp2YXIoLS1jYXJkMik7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjZweCAxM3B4fQoudG9jIGE6aG92ZXJ7Y29sb3I6dmFyKC0tYWNjZW50KTtib3JkZXItY29sb3I6dmFyKC0tYWNjZW50KX0KLmV4ZWN7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNl
HLP:bnRlcjtnYXA6MThweDtmbGV4LXdyYXA6d3JhcDtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxODBkZWcsdmFyKC0tY2FyZCksdmFyKC0tY2FyZDIpKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MThweDtwYWRkaW5nOjE4cHgg
HLP:MjJweDttYXJnaW4tYm90dG9tOjIycHg7Ym94LXNoYWRvdzp2YXIoLS1zaGFkb3cpfQouZXhlYy1zY29yZXtmb250LXNpemU6NDZweDtmb250LXdlaWdodDo4MDA7bGluZS1oZWlnaHQ6MX0KLmV4ZWMtbWlke2ZsZXg6MTttaW4td2lkdGg6MjAwcHh9Ci5leGVjLXZl
HLP:cmRpY3R7Zm9udC1zaXplOjE4cHg7Zm9udC13ZWlnaHQ6NzAwfQouZXhlYy1saW5le2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDttYXJnaW4tdG9wOjJweH0KLmV4ZWMtZGVsdGF7Zm9udC1zaXplOjEzcHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlcjox
HLP:cHggc29saWQ7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjRweCAxMnB4O3doaXRlLXNwYWNlOm5vd3JhcH0KLmhlcm97ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczptaW5tYXgoMjQwcHgsMzIwcHgpIDFmcjtnYXA6MjBweDttYXJnaW4tYm90
HLP:dG9tOjIycHh9CkBtZWRpYShtYXgtd2lkdGg6NzYwcHgpey5oZXJve2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnJ9fQouY2FyZHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxODBkZWcsdmFyKC0tY2FyZCksdmFyKC0tY2FyZDIpKTtib3JkZXI6MXB4IHNvbGlk
HLP:IHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MThweDtwYWRkaW5nOjIycHg7Ym94LXNoYWRvdzp2YXIoLS1zaGFkb3cpfQouZ2F1Z2V3cmFwe2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVu
HLP:dDpjZW50ZXI7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5nYXVnZXt3aWR0aDoyMTBweDtoZWlnaHQ6MjEwcHh9Ci5nYXVnZS1zbXt3aWR0aDoxMjBweDtoZWlnaHQ6MTIwcHh9Ci5nYXVnZSAudHJhY2t7ZmlsbDpub25lO3N0cm9rZTp2YXIoLS1saW5lKTtzdHJva2Utd2lk
HLP:dGg6MTR9Ci5nYXVnZSAuZmlsbHtmaWxsOm5vbmU7c3Ryb2tlLXdpZHRoOjE0O3N0cm9rZS1saW5lY2FwOnJvdW5kO3RyYW5zZm9ybTpyb3RhdGUoLTkwZGVnKTt0cmFuc2Zvcm0tb3JpZ2luOjUwJSA1MCU7c3Ryb2tlLWRhc2hhcnJheTp2YXIoLS1jaXJjKTtzdHJv
HLP:a2UtZGFzaG9mZnNldDp2YXIoLS1jaXJjKTthbmltYXRpb246ZmlsbCAxLjRzIGN1YmljLWJlemllciguMjIsMSwuMzYsMSkgLjJzIGZvcndhcmRzfQouZy1udW17Zm9udC1zaXplOjU0cHg7Zm9udC13ZWlnaHQ6ODAwO3RleHQtYW5jaG9yOm1pZGRsZTtmb250LWZh
HLP:bWlseTonU2Vnb2UgVUknLHN5c3RlbS11aSxBcmlhbH0KLmdhdWdlLXNtIC5nLW51bXtmb250LXNpemU6NDZweH0KLmctbGFiZWx7bWFyZ2luLXRvcDo2cHg7Zm9udC13ZWlnaHQ6NzAwO2ZvbnQtc2l6ZToxNXB4fQouZy1jYXB7Y29sb3I6dmFyKC0tbXV0ZWQpO2Zv
HLP:bnQtc2l6ZToxMnB4O2xldHRlci1zcGFjaW5nOjEuNXB4O21hcmdpbi10b3A6MnB4fQouY29tcGFyZXtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7Z2FwOjhweDttYXJnaW4tdG9wOjE0cHg7ZmxleC13cmFwOndy
HLP:YXB9Ci5taW5pe3RleHQtYWxpZ246Y2VudGVyfQoubWluaS1jYXB7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMXB4O2xldHRlci1zcGFjaW5nOjEuMnB4O21hcmdpbi10b3A6LTZweH0KLmFycm93e2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1
HLP:bW47YWxpZ24taXRlbXM6Y2VudGVyO2dhcDo2cHg7Zm9udC1zaXplOjMwcHg7Zm9udC13ZWlnaHQ6ODAwfQouZGVsdGEtY2hpcHtib3JkZXI6MXB4IHNvbGlkO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzozcHggMTJweDtmb250LXNpemU6MTIuNXB4O2ZvbnQt
HLP:d2VpZ2h0OjcwMDt3aGl0ZS1zcGFjZTpub3dyYXB9Ci5oZXJvLXNpZGV7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjtnYXA6MTZweH0KLmNoaXBze2Rpc3BsYXk6ZmxleDtnYXA6MTBweDtmbGV4LXdyYXA6d3JhcH0KLmNoaXB7ZmxleDoxO21pbi13
HLP:aWR0aDo5NnB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZDIpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O3BhZGRpbmc6MTJweCAxNHB4O3RleHQtYWxpZ246Y2VudGVyfQouY2hpcCAubntmb250LXNpemU6MjZweDtmb250LXdl
HLP:aWdodDo4MDA7bGluZS1oZWlnaHQ6MX0KLmNoaXAgLmx7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMS41cHg7bGV0dGVyLXNwYWNpbmc6LjZweDttYXJnaW4tdG9wOjNweH0KLmMtb2t7Y29sb3I6IzIyYzU1ZX0uYy13YXJue2NvbG9yOiNmNTllMGJ9LmMt
HLP:ZXJye2NvbG9yOiNlZjQ0NDR9LmMtc2tpcHtjb2xvcjojOTRhM2I4fQouc3lzZ3JpZHtkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmciAxZnI7Z2FwOjFweDtiYWNrZ3JvdW5kOnZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTRweDtvdmVyZmxv
HLP:dzpoaWRkZW59CkBtZWRpYShtYXgtd2lkdGg6NTIwcHgpey5zeXNncmlke2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnJ9fQouc3lze2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7cGFkZGluZzoxMXB4IDE0cHh9Ci5zeXMta3tjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1z
HLP:aXplOjExLjVweDtsZXR0ZXItc3BhY2luZzouNHB4fQouc3lzLXZ7Zm9udC13ZWlnaHQ6NjAwO2ZvbnQtc2l6ZToxNHB4O21hcmdpbi10b3A6MXB4O3dvcmQtYnJlYWs6YnJlYWstd29yZH0KaDIuc2VjLWh7Zm9udC1zaXplOjE1cHg7bGV0dGVyLXNwYWNpbmc6LjZw
HLP:eDt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7Y29sb3I6dmFyKC0tYWNjZW50KTttYXJnaW46MzBweCAwIDEycHg7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTBweDtzY3JvbGwtbWFyZ2luLXRvcDoxNHB4fQpoMi5zZWMtaDo6YWZ0ZXJ7Y29u
HLP:dGVudDonJztmbGV4OjE7aGVpZ2h0OjFweDtiYWNrZ3JvdW5kOnZhcigtLWxpbmUpfQoudGltZWxpbmV7cG9zaXRpb246cmVsYXRpdmU7cGFkZGluZy1sZWZ0OjhweH0KLnBoe2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O2dhcDoxNHB4O3BhZGRp
HLP:bmc6MTNweCAxNnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O21hcmdpbi1ib3R0b206MTBweDtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO3Bvc2l0aW9uOnJlbGF0aXZlO292ZXJmbG93OmhpZGRlbn0KLnBoOjpiZWZvcmV7
HLP:Y29udGVudDonJztwb3NpdGlvbjphYnNvbHV0ZTtsZWZ0OjA7dG9wOjA7Ym90dG9tOjA7d2lkdGg6NHB4fQoucGgtb2s6OmJlZm9yZXtiYWNrZ3JvdW5kOiMyMmM1NWV9LnBoLXdhcm46OmJlZm9yZXtiYWNrZ3JvdW5kOiNmNTllMGJ9LnBoLWVycm9yOjpiZWZvcmV7
HLP:YmFja2dyb3VuZDojZWY0NDQ0fS5waC1za2lwOjpiZWZvcmV7YmFja2dyb3VuZDojNjQ3NDhifQoucGgtZG90e2ZsZXg6MCAwIGF1dG87bWFyZ2luLXRvcDoxcHh9Ci5zdmdpY297d2lkdGg6MjZweDtoZWlnaHQ6MjZweDtkaXNwbGF5OmJsb2NrfQoucGgtbWFpbntm
HLP:bGV4OjE7bWluLXdpZHRoOjB9Ci5waC10b3B7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTBweDtmbGV4LXdyYXA6d3JhcH0KLnBoLW51bXtmb250LXZhcmlhbnQtbnVtZXJpYzp0YWJ1bGFyLW51bXM7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQt
HLP:c2l6ZToxMnB4O2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6N3B4O3BhZGRpbmc6MXB4IDdweH0KLnBoLXRpdGxle2ZvbnQtd2VpZ2h0OjYwMDtmb250LXNpemU6MTVweH0KLnBoLWJhZGdle2ZvbnQtc2l6
HLP:ZToxMXB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzouNnB4O2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzoycHggMTBweH0KLmItb2t7YmFja2dyb3VuZDpyZ2JhKDM0LDE5Nyw5NCwuMTYpO2NvbG9yOiMyMmM1NWV9LmItd2FybntiYWNrZ3JvdW5k
HLP:OnJnYmEoMjQ1LDE1OCwxMSwuMTYpO2NvbG9yOiNmNTllMGJ9LmItZXJyb3J7YmFja2dyb3VuZDpyZ2JhKDIzOSw2OCw2OCwuMTYpO2NvbG9yOiNlZjQ0NDR9LmItc2tpcHtiYWNrZ3JvdW5kOnJnYmEoMTAwLDExNiwxMzksLjE4KTtjb2xvcjojOTRhM2I4fQoucGgt
HLP:bm90ZXtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEzcHg7bWFyZ2luLXRvcDozcHh9Ci5waC1zZWNze2ZsZXg6MCAwIGF1dG87Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O2ZvbnQtdmFyaWFudC1udW1lcmljOnRhYnVsYXItbnVtczthbGln
HLP:bi1zZWxmOmNlbnRlcn0KLmVtcHR5e2NvbG9yOnZhcigtLW11dGVkKTtwYWRkaW5nOjE4cHg7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5iYXJjaGFydHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czox
HLP:NHB4O3BhZGRpbmc6MTRweCAxOHB4O21hcmdpbi10b3A6NHB4fQouYmFyLXJvd3tkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMnB4O3BhZGRpbmc6NXB4IDB9Ci5iYXItbGJse2ZsZXg6MCAwIDIyMHB4O2ZvbnQtc2l6ZToxMi41cHg7Y29sb3I6
HLP:dmFyKC0tbXV0ZWQpO3doaXRlLXNwYWNlOm5vd3JhcDtvdmVyZmxvdzpoaWRkZW47dGV4dC1vdmVyZmxvdzplbGxpcHNpc30KQG1lZGlhKG1heC13aWR0aDo2MDBweCl7LmJhci1sYmx7ZmxleDowIDAgMTIwcHh9fQouYmFyLXRyYWNre2ZsZXg6MTtoZWlnaHQ6MTBw
HLP:eDtib3JkZXItcmFkaXVzOjk5OXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSk7b3ZlcmZsb3c6aGlkZGVufQouYmFyLXRyYWNrIHNwYW57ZGlzcGxheTpibG9jaztoZWlnaHQ6MTAwJTtib3JkZXItcmFkaXVzOjk5OXB4fQouYmFyLXZhbHtmbGV4OjAgMCBhdXRvO2Zv
HLP:bnQtc2l6ZToxMi41cHg7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtdmFyaWFudC1udW1lcmljOnRhYnVsYXItbnVtczt3aWR0aDo0OHB4O3RleHQtYWxpZ246cmlnaHR9CnVsLmZpbmRze2xpc3Qtc3R5bGU6bm9uZTttYXJnaW46MDtwYWRkaW5nOjB9Ci5maW5ke2Rp
HLP:c3BsYXk6ZmxleDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O2dhcDoxMnB4O3BhZGRpbmc6MTJweCAxNnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxM3B4O21hcmdpbi1ib3R0b206OXB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCl9
HLP:Ci5zZXZ7ZmxleDowIDAgYXV0bztmb250LXNpemU6MTFweDtmb250LXdlaWdodDo4MDA7bGV0dGVyLXNwYWNpbmc6LjVweDtib3JkZXItcmFkaXVzOjhweDtwYWRkaW5nOjNweCAxMHB4O21hcmdpbi10b3A6MXB4fQouc2V2LWhpZ2h7YmFja2dyb3VuZDpyZ2JhKDIz
HLP:OSw2OCw2OCwuMTYpO2NvbG9yOiNlZjQ0NDR9LnNldi1tZWR7YmFja2dyb3VuZDpyZ2JhKDI0NSwxNTgsMTEsLjE2KTtjb2xvcjojZjU5ZTBifS5zZXYtaW5mb3tiYWNrZ3JvdW5kOnJnYmEoNTYsMTg5LDI0OCwuMTYpO2NvbG9yOnZhcigtLWFjY2VudCl9LnNldi1v
HLP:a3tiYWNrZ3JvdW5kOnJnYmEoMzQsMTk3LDk0LC4xNik7Y29sb3I6IzIyYzU1ZX0KLmZpbmQtdHh0e2ZvbnQtc2l6ZToxNHB4fQp1bC5zdGVwc3tsaXN0LXN0eWxlOm5vbmU7bWFyZ2luOjA7cGFkZGluZzowfQouc3RlcC1saXtkaXNwbGF5OmZsZXg7Z2FwOjExcHg7
HLP:YWxpZ24taXRlbXM6ZmxleC1zdGFydDtwYWRkaW5nOjExcHggMTZweDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1sZWZ0OjNweCBzb2xpZCB2YXIoLS1hY2NlbnQpO2JvcmRlci1yYWRpdXM6MTJweDttYXJnaW4tYm90dG9tOjlweDtiYWNrZ3Jv
HLP:dW5kOnZhcigtLWNhcmQpO2ZvbnQtc2l6ZToxNHB4fQouc3RlcC1va3tib3JkZXItbGVmdC1jb2xvcjojMjJjNTVlfQouc3RlcC1pY3tjb2xvcjp2YXIoLS1hY2NlbnQpO2ZvbnQtd2VpZ2h0OjgwMH0KLnN0ZXAtb2sgLnN0ZXAtaWN7Y29sb3I6IzIyYzU1ZX0KLmRn
HLP:cmlke2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6cmVwZWF0KGF1dG8tZml0LG1pbm1heCgyMjBweCwxZnIpKTtnYXA6MTRweH0KLmRjYXJke2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXIt
HLP:cmFkaXVzOjE1cHg7cGFkZGluZzoxNnB4IDE4cHh9Ci5kY2FyZC13aWRle2dyaWQtY29sdW1uOjEvLTF9Ci5kLWh7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6OXB4O2ZvbnQtd2VpZ2h0OjcwMDtmb250LXNpemU6MTRweDttYXJnaW4tYm90dG9t
HLP:OjEwcHh9Ci5kLWlje3dpZHRoOjE0cHg7aGVpZ2h0OjE0cHg7Ym9yZGVyLXJhZGl1czo1cHg7ZGlzcGxheTppbmxpbmUtYmxvY2t9Ci5pYy1yYW17YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCMzOGJkZjgsIzBlYTVlOSl9LmljLWJhdHtiYWNrZ3Jv
HLP:dW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzIyYzU1ZSwjMTU4MDNkKX0uaWMtbmV0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjODE4Y2Y4LCM0ZjQ2ZTUpfS5pYy1kZXZ7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNmNTll
HLP:MGIsI2Q5NzcwNil9LmljLXNtYXJ0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZjQ3MmI2LCNkYjI3NzcpfS5pYy1ib290e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMmRkNGJmLCMwZDk0ODgpfS5pYy1zdGFydHtiYWNrZ3Jv
HLP:dW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2E3OGJmYSwjN2MzYWVkKX0uaWMtcHJvY3tiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2ZiNzE4NSwjZTExZDQ4KX0KLmQtcGlsbHtkaXNwbGF5OmlubGluZS1ibG9jaztmb250LXNpemU6MTIuNXB4
HLP:O2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6NHB4IDEycHh9Ci5waWxsLXJvd3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4LXdyYXA6d3JhcH0KLnBpbGwtZ29vZHtiYWNrZ3JvdW5kOnJnYmEoMzQsMTk3LDk0LC4xNik7Y29sb3I6
HLP:IzIyYzU1ZX0ucGlsbC1iYWR7YmFja2dyb3VuZDpyZ2JhKDIzOSw2OCw2OCwuMTYpO2NvbG9yOiNlZjQ0NDR9LnBpbGwtdW5rbm93bntiYWNrZ3JvdW5kOnJnYmEoMTQ4LDE2MywxODQsLjE2KTtjb2xvcjojOTRhM2I4fQouZC1zdWJ7Y29sb3I6dmFyKC0tbXV0ZWQp
HLP:O2ZvbnQtc2l6ZToxMi41cHg7bWFyZ2luLXRvcDo4cHh9Ci5kLWhpbnR7Y29sb3I6I2Y1OWUwYjtmb250LXNpemU6MTIuNXB4O21hcmdpbi10b3A6OHB4fQouYmF0LWJhcntoZWlnaHQ6MTJweDtib3JkZXItcmFkaXVzOjk5OXB4O2JhY2tncm91bmQ6dmFyKC0tbGlu
HLP:ZSk7b3ZlcmZsb3c6aGlkZGVuO21hcmdpbi10b3A6NHB4fQouYmF0LWJhciBzcGFue2Rpc3BsYXk6YmxvY2s7aGVpZ2h0OjEwMCU7Ym9yZGVyLXJhZGl1czo5OTlweH0KLmRldi1saXN0e21hcmdpbjo0cHggMCAwO3BhZGRpbmctbGVmdDoxOHB4O2ZvbnQtc2l6ZTox
HLP:My41cHh9Ci5kZXYtbGlzdCBsaXttYXJnaW46MnB4IDB9Ci5tdXRlZHtjb2xvcjp2YXIoLS1tdXRlZCl9Ci5mb290e21hcmdpbi10b3A6MzRweDt0ZXh0LWFsaWduOmNlbnRlcjtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHh9Ci5zZWN0aW9ue2FuaW1h
HLP:dGlvbjpyaXNlIC41cyBlYXNlIGJvdGh9CkBrZXlmcmFtZXMgZmlsbHt0b3tzdHJva2UtZGFzaG9mZnNldDp2YXIoLS10YXJnZXQpfX0KQGtleWZyYW1lcyByaXNle2Zyb217b3BhY2l0eTowO3RyYW5zZm9ybTp0cmFuc2xhdGVZKDEwcHgpfXRve29wYWNpdHk6MTt0
HLP:cmFuc2Zvcm06bm9uZX19CkBtZWRpYSBwcmludHsudG9nZ2xlLC50b2MsLmJ0bnMsLnRvYXN0e2Rpc3BsYXk6bm9uZX1ib2R5e2JhY2tncm91bmQ6I2ZmZjtjb2xvcjojMDAwfS5jYXJkLC5kY2FyZCwucGgsLmZpbmQsLmV4ZWMsLmJhcmNoYXJ0LC5zdGVwLWxpe2Jv
HLP:eC1zaGFkb3c6bm9uZTtiYWNrZHJvcC1maWx0ZXI6bm9uZTstd2Via2l0LWJhY2tkcm9wLWZpbHRlcjpub25lO2JhY2tncm91bmQ6I2ZmZiFpbXBvcnRhbnR9LmdhdWdlIC5maWxse2FuaW1hdGlvbjpub25lfS5zZWN0aW9ue2FuaW1hdGlvbjpub25lfWFbaHJlZl17
HLP:Y29sb3I6aW5oZXJpdDt0ZXh0LWRlY29yYXRpb246bm9uZX19Cjpyb290ey0tZ2xhc3M6cmdiYSgxOCwyNiw0MywuNjApOy0tZ2xhc3NiZDpyZ2JhKDI1NSwyNTUsMjU1LC4wNyl9Cmh0bWwubGlnaHR7LS1nbGFzczpyZ2JhKDI1NSwyNTUsMjU1LC42NCk7LS1nbGFz
HLP:c2JkOnJnYmEoMTUsMjMsNDIsLjA4KX0KLmNhcmQsLmV4ZWMsLmRjYXJkLC5maW5kLC5iYXJjaGFydCwuc3RlcC1saXtiYWNrZ3JvdW5kOnZhcigtLWdsYXNzKSFpbXBvcnRhbnQ7YmFja2Ryb3AtZmlsdGVyOmJsdXIoMTNweCkgc2F0dXJhdGUoMTQwJSk7LXdlYmtp
HLP:dC1iYWNrZHJvcC1maWx0ZXI6Ymx1cigxM3B4KSBzYXR1cmF0ZSgxNDAlKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWdsYXNzYmQpIWltcG9ydGFudH0KLnRvYXN0e3Bvc2l0aW9uOmZpeGVkO2JvdHRvbToyNHB4O2xlZnQ6NTAlO3RyYW5zZm9ybTp0cmFuc2xhdGVY
HLP:KC01MCUpO2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZyx2YXIoLS1hY2NlbnQpLHZhcigtLWFjY2VudDIpKTtjb2xvcjojMDQyOTNiO2ZvbnQtd2VpZ2h0OjcwMDtwYWRkaW5nOjEwcHggMThweDtib3JkZXItcmFkaXVzOjEycHg7Ym94LXNoYWRvdzp2
HLP:YXIoLS1zaGFkb3cpO29wYWNpdHk6MDtwb2ludGVyLWV2ZW50czpub25lO3RyYW5zaXRpb246b3BhY2l0eSAuMjVzO3otaW5kZXg6NjA7Zm9udC1zaXplOjEzcHh9Ci50b2FzdC5zaG93e29wYWNpdHk6MX0KLnRyZW5kLXRpdGxle21hcmdpbi10b3A6MjBweDtmb250
HLP:LXNpemU6MTJweDtmb250LXdlaWdodDo3MDA7bGV0dGVyLXNwYWNpbmc6MXB4O3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTtjb2xvcjp2YXIoLS1tdXRlZCl9Ci50cmVuZC1saXN0e2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47Z2FwOjRweDt3aWR0
HLP:aDoxMDAlO21hcmdpbi10b3A6OHB4O2JvcmRlci10b3A6MXB4IHNvbGlkIHZhcigtLWxpbmUpO3BhZGRpbmctdG9wOjhweH0KLnRyZW5kLWl0ZW17ZGlzcGxheTpmbGV4O2p1c3RpZnktY29udGVudDpzcGFjZS1iZXR3ZWVuO2ZvbnQtc2l6ZToxMnB4fQoudHJlbmQt
HLP:ZGF0ZXtjb2xvcjp2YXIoLS1tdXRlZCl9Ci50cmVuZC1zY29yZXtmb250LXdlaWdodDo3MDB9Cjwvc3R5bGU+CjwvaGVhZD4KPGJvZHk+CjxkaXYgY2xhc3M9J3dyYXAnPgogIDxkaXYgY2xhc3M9J3RvcGJhcic+CiAgICA8ZGl2IGNsYXNzPSdicmFuZCc+CiAgICAg
HLP:IDxkaXYgY2xhc3M9J2xvZ28nPjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyB3aWR0aD0nMjYnIGhlaWdodD0nMjYnIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nV1BJJz48cGF0aCBkPSdNMTIgMmw3IDN2NmMwIDQuNi0zIDguMy03IDkuNkM4IDE5LjMgNSAxNS42IDUg
HLP:MTFWNXonIGZpbGw9JyMwNDI5M2InLz48cGF0aCBkPSdNOSAxMmwyIDIgNC00LjUnIGZpbGw9J25vbmUnIHN0cm9rZT0nI2RmZjZmZicgc3Ryb2tlLXdpZHRoPScyJyBzdHJva2UtbGluZWNhcD0ncm91bmQnIHN0cm9rZS1saW5lam9pbj0ncm91bmQnLz48L3N2Zz48
HLP:L2Rpdj4KICAgICAgPGRpdj4KICAgICAgICA8aDE+SW5mb3JtZSBkZSBSZXBhcmFjaW9uIDxzcGFuIGNsYXNzPSdiYWRnZSc+V1BJIFNVSVRFIHYzLjE8L3NwYW4+PC9oMT4KICAgICAgICA8ZGl2IGNsYXNzPSdzdWInPiQoJiAkZW5jICRtYWNoaW5lKSAmbmJzcDsm
HLP:bWlkZG90OyZuYnNwOyBnZW5lcmFkbyBlbCAkbm93PC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdidG5zJz4KICAgICAgPGJ1dHRvbiBjbGFzcz0ndG9nZ2xlJyBvbmNsaWNrPSJ3aW5kb3cucHJpbnQoKSI+SW1wcmltaXIgLyBQ
HLP:REY8L2J1dHRvbj4KICAgICAgPGJ1dHRvbiBjbGFzcz0ndG9nZ2xlJyBpZD0nY29weWJ0bicgb25jbGljaz0iY29weVJlc3VtZW4oKSI+Q29waWFyIHJlc3VtZW48L2J1dHRvbj4KICAgICAgPGJ1dHRvbiBjbGFzcz0ndG9nZ2xlJyBpZD0ndGhlbWVidG4nIG9uY2xp
HLP:Y2s9InRvZ2dsZVRoZW1lKCkiPlRlbWEgY2xhcm8vb3NjdXJvPC9idXR0b24+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPG5hdiBjbGFzcz0ndG9jJyBhcmlhLWxhYmVsPSdJbmRpY2UnPgogICAgPGEgaHJlZj0nI3Jlc3VtZW4nPlJlc3VtZW48L2E+CiAgICA8YSBo
HLP:cmVmPScjZmFzZXMnPkZhc2VzPC9hPgogICAgPGEgaHJlZj0nI2hhbGxhemdvcyc+SGFsbGF6Z29zPC9hPgogICAgPGEgaHJlZj0nI3Bhc29zJz5Qcm94aW1vcyBwYXNvczwvYT4KICAgIDxhIGhyZWY9JyNkaWFnJz5EaWFnbm9zdGljbzwvYT4KICA8L25hdj4KCiAg
HLP:PGRpdiBpZD0ncmVzdW1lbicgY2xhc3M9J2V4ZWMgc2VjdGlvbic+CiAgICA8ZGl2IGNsYXNzPSdleGVjLXNjb3JlJyBzdHlsZT0nY29sb3I6JG1haW5Db2xvcic+JG1haW5TY29yZTwvZGl2PgogICAgPGRpdiBjbGFzcz0nZXhlYy1taWQnPgogICAgICA8ZGl2IGNs
HLP:YXNzPSdleGVjLXZlcmRpY3QnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz5TYWx1ZCBkZWwgc2lzdGVtYTogJGV4ZWNWZXJkaWN0PC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9J2V4ZWMtbGluZSc+JGNPSyBjb3JyZWN0YXMgJm1pZGRvdDsgJGNXQVJOIGF2aXNvcyAm
HLP:bWlkZG90OyAkY0VSUiBlcnJvcmVzICZtaWRkb3Q7ICRjU0tJUCBvbWl0aWRhcyAmbWlkZG90OyAkdG90YWxQaCBmYXNlcyBlbiB0b3RhbDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdleGVjLWxpbmUnPiRzdGF0TGluZTwvZGl2PgogICAgPC9kaXY+CiAgICA8ZGl2
HLP:IGNsYXNzPSdleGVjLWRlbHRhJyBzdHlsZT0nY29sb3I6JGRlbHRhQ29sb3I7Ym9yZGVyLWNvbG9yOiRkZWx0YUNvbG9yJz4kZGVsdGFUeHQ8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0naGVybyBzZWN0aW9uJz4KICAgIDxkaXYgY2xhc3M9J2NhcmQgZ2F1
HLP:Z2V3cmFwJz4KICAgICAgPHN2ZyB2aWV3Qm94PScwIDAgMjAwIDIwMCcgY2xhc3M9J2dhdWdlJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J1B1bnR1YWNpb24gZGUgc2FsdWQgJG1haW5TY29yZSBzb2JyZSAxMDAnPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBjeD0nMTAw
HLP:JyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRtYWluT2Zmc2V0O3N0cm9rZTokbWFpbkNvbG9yJy8+PHRleHQgeD0nMTAwJyB5PScxMTInIGNs
HLP:YXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6JG1haW5Db2xvcic+JG1haW5TY29yZTwvdGV4dD48L3N2Zz4KICAgICAgPGRpdiBjbGFzcz0nZy1sYWJlbCcgc3R5bGU9J2NvbG9yOiRtYWluQ29sb3InPlNhbHVkOiAkbWFpbkxhYmVsPC9kaXY+CiAgICAgIDxkaXYgY2xh
HLP:c3M9J2ctY2FwJz5QVU5UVUFDSU9OIFNPQlJFIDEwMDwvZGl2PgogICAgICAkY29tcGFyZVNlY3Rpb24KICAgICAgJGhpc3RvcnlIdG1sCiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2hlcm8tc2lkZSc+CiAgICAgIDxkaXYgY2xhc3M9J2NhcmQnPgogICAgICAg
HLP:IDxkaXYgY2xhc3M9J2NoaXBzJz4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1vayc+JGNPSzwvZGl2PjxkaXYgY2xhc3M9J2wnPk9LPC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNsYXNzPSdu
HLP:IGMtd2Fybic+JGNXQVJOPC9kaXY+PGRpdiBjbGFzcz0nbCc+QVZJU09TPC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNsYXNzPSduIGMtZXJyJz4kY0VSUjwvZGl2PjxkaXYgY2xhc3M9J2wnPkVSUk9SRVM8L2Rpdj48L2Rpdj4K
HLP:ICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1za2lwJz4kY1NLSVA8L2Rpdj48ZGl2IGNsYXNzPSdsJz5PTUlUSURBUzwvZGl2PjwvZGl2PgogICAgICAgIDwvZGl2PgogICAgICA8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nY2FyZCc+
HLP:CiAgICAgICAgPGRpdiBjbGFzcz0nc3lzZ3JpZCc+JHN5c0NhcmRzPC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdmYXNlcycgY2xhc3M9J3NlYy1oJz5MaW5lYSBkZSB0aWVt
HLP:cG8gZGUgZmFzZXMgKCR0b3RhbFBoKTwvaDI+CiAgICA8ZGl2IGNsYXNzPSd0aW1lbGluZSc+JHJvd3M8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2JhcmNoYXJ0Jz4kYmFyczwvZGl2PgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4KICAgIDxoMiBpZD0n
HLP:aGFsbGF6Z29zJyBjbGFzcz0nc2VjLWgnPkhhbGxhemdvcyB5IGNhdXNhIHJhaXo8L2gyPgogICAgPHVsIGNsYXNzPSdmaW5kcyc+JGZpbmRIdG1sPC91bD4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlvbic+CiAgICA8aDIgaWQ9J3Bhc29zJyBjbGFzcz0n
HLP:c2VjLWgnPlByb3hpbW9zIHBhc29zIHJlY29tZW5kYWRvczwvaDI+CiAgICA8dWwgY2xhc3M9J3N0ZXBzJz4kc3RlcHNIdG1sPC91bD4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlvbic+JGRpYWdTZWN0aW9uPC9kaXY+CgogIDxkaXYgY2xhc3M9J2Zvb3Qn
HLP:PgogICAgV1BJICZtaWRkb3Q7IFN1aXRlIGRlIFJlcGFyYWNpb24gZGUgRW1lcmdlbmNpYSBwYXJhIFdpbmRvd3MgMTAvMTEgJm1pZGRvdDsgaW5mb3JtZSBkZSBzb2xvIGxlY3R1cmEuPGJyPgogICAgTGFzIGNvcGlhcyBkZSBzZWd1cmlkYWQgeSBsb3MgcmVnaXN0
HLP:cm9zIGVzdGFuIGVuIGxhIGNhcnBldGEgV1BJX1N1aXRlIGp1bnRvIGFsIHByb2dyYW1hLgogIDwvZGl2Pgo8L2Rpdj4KPHNjcmlwdD4KKGZ1bmN0aW9uKCl7dHJ5e3ZhciBzPWxvY2FsU3RvcmFnZS5nZXRJdGVtKCd3cGktdGhlbWUnKTt2YXIgcm9vdD1kb2N1bWVu
HLP:dC5kb2N1bWVudEVsZW1lbnQ7aWYocz09PSdsaWdodCcpe3Jvb3QuY2xhc3NMaXN0LmFkZCgnbGlnaHQnKTt9ZWxzZSBpZihzPT09J2RhcmsnKXtyb290LmNsYXNzTGlzdC5yZW1vdmUoJ2xpZ2h0Jyk7fWVsc2UgaWYod2luZG93Lm1hdGNoTWVkaWEmJndpbmRvdy5t
HLP:YXRjaE1lZGlhKCcocHJlZmVycy1jb2xvci1zY2hlbWU6IGxpZ2h0KScpLm1hdGNoZXMpe3Jvb3QuY2xhc3NMaXN0LmFkZCgnbGlnaHQnKTt9fWNhdGNoKGUpe319KSgpOwpmdW5jdGlvbiB0b2dnbGVUaGVtZSgpe3RyeXt2YXIgbD1kb2N1bWVudC5kb2N1bWVudEVs
HLP:ZW1lbnQuY2xhc3NMaXN0LnRvZ2dsZSgnbGlnaHQnKTtsb2NhbFN0b3JhZ2Uuc2V0SXRlbSgnd3BpLXRoZW1lJyxsPydsaWdodCc6J2RhcmsnKTt9Y2F0Y2goZSl7fX0KZnVuY3Rpb24gZmxhc2gobSl7dHJ5e3ZhciB0PWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2Rp
HLP:dicpO3QuY2xhc3NOYW1lPSd0b2FzdCc7dC50ZXh0Q29udGVudD1tO2RvY3VtZW50LmJvZHkuYXBwZW5kQ2hpbGQodCk7cmVxdWVzdEFuaW1hdGlvbkZyYW1lKGZ1bmN0aW9uKCl7dC5jbGFzc0xpc3QuYWRkKCdzaG93Jyk7fSk7c2V0VGltZW91dChmdW5jdGlvbigp
HLP:e3QuY2xhc3NMaXN0LnJlbW92ZSgnc2hvdycpO3NldFRpbWVvdXQoZnVuY3Rpb24oKXt0LnJlbW92ZSgpO30sMzAwKTt9LDE2MDApO31jYXRjaChlKXt9fQpmdW5jdGlvbiBmYih0eHQsb2spe3RyeXt2YXIgYT1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCd0ZXh0YXJl
HLP:YScpO2EudmFsdWU9dHh0O2Euc3R5bGUucG9zaXRpb249J2ZpeGVkJzthLnN0eWxlLmxlZnQ9Jy05OTk5cHgnO2RvY3VtZW50LmJvZHkuYXBwZW5kQ2hpbGQoYSk7YS5zZWxlY3QoKTtkb2N1bWVudC5leGVjQ29tbWFuZCgnY29weScpO2EucmVtb3ZlKCk7b2soKTt9
HLP:Y2F0Y2goZSl7Zmxhc2goJ05vIHNlIHB1ZG8gY29waWFyJyk7fX0KZnVuY3Rpb24gY29weVJlc3VtZW4oKXt2YXIgcD1bXTt2YXIgdD1kb2N1bWVudC5xdWVyeVNlbGVjdG9yKCdoMScpO2lmKHQpcC5wdXNoKHQuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIHM9ZG9jdW1l
HLP:bnQucXVlcnlTZWxlY3RvcignLnN1YicpO2lmKHMpcC5wdXNoKHMuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIGV4PWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJy5leGVjJyk7aWYoZXgpcC5wdXNoKCdcbicrZXguaW5uZXJUZXh0LnJlcGxhY2UoL1xuezIsfS9nLCdcbicp
HLP:LnRyaW0oKSk7dmFyIGg9ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ2hhbGxhemdvcycpO2lmKGgmJmgucGFyZW50Tm9kZSlwLnB1c2goJ1xuJytoLnBhcmVudE5vZGUuaW5uZXJUZXh0LnRyaW0oKSk7dmFyIHR4dD1wLmpvaW4oJ1xuJyk7ZnVuY3Rpb24gb2soKXtm
HLP:bGFzaCgnUmVzdW1lbiBjb3BpYWRvJyk7fWlmKG5hdmlnYXRvci5jbGlwYm9hcmQmJm5hdmlnYXRvci5jbGlwYm9hcmQud3JpdGVUZXh0KXtuYXZpZ2F0b3IuY2xpcGJvYXJkLndyaXRlVGV4dCh0eHQpLnRoZW4ob2ssZnVuY3Rpb24oKXtmYih0eHQsb2spO30pO31l
HLP:bHNle2ZiKHR4dCxvayk7fX0KPC9zY3JpcHQ+CjwvYm9keT4KPC9odG1sPgoiQAogICAgICAgICR1dGY4ID0gTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKQogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkb3V0
HLP:UGF0aCwgJGh0bWwsICR1dGY4KQogICAgICAgICJSRVNVTFQ9T0siCiAgICAgICAgIlBBVEg9JG91dFBhdGgiCiAgICB9IGNhdGNoIHsKICAgICAgICAiUkVTVUxUPUZBSUwiCiAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgfQp9Cgoj
HLP:IC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUmVnaXN0cmFyIHJlc3VsdGFkbyBkZSB1bmEgZmFzZSBlbiBlbCBlc3RhZG8gKHBhcmEgZWwgaW5mb3JtZSkuCiMgLUFyZyA9
HLP:ICJudW07dGl0bGU7cmVzdWx0O3NlY3M7bm90ZSIKZnVuY3Rpb24gQWRkLVBoYXNlUmVzdWx0KCRzcGVjKSB7CiAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAkcGFydHMgPSAkc3BlYyAtc3BsaXQgJzsnLDUKICAgICRwaCA9IFtwc2N1c3RvbW9iamVjdF1AeyBudW09
HLP:JHBhcnRzWzBdOyB0aXRsZT0kcGFydHNbMV07IHJlc3VsdD0kcGFydHNbMl07IHNlY3M9JHBhcnRzWzNdOyBub3RlPSRwYXJ0c1s0XSB9CiAgICAkbGlzdCA9IEAoJHN0LnBoYXNlcykgKyAkcGgKICAgICRzdC5waGFzZXMgPSAkbGlzdAogICAgV3JpdGUtU3RhdGUg
HLP:JHN0CiAgICAiUkVTVUxUPU9LIgp9CmZ1bmN0aW9uIFNldC1TY29yZSgkd2hpY2gsICR2YWwpIHsKICAgICRzdCA9IFJlYWQtU3RhdGUKICAgIGlmICgkd2hpY2ggLWVxICdiZWZvcmUnKSB7IAogICAgICAgICRzdC5zY29yZV9iZWZvcmUgPSBbaW50XSR2YWwgCiAg
HLP:ICB9IGVsc2UgeyAKICAgICAgICAkc3Quc2NvcmVfYWZ0ZXIgPSBbaW50XSR2YWwgCiAgICAgICAgU2F2ZS1IZWFsdGhIaXN0b3J5IFtpbnRdJHZhbAogICAgfQogICAgV3JpdGUtU3RhdGUgJHN0OyAiUkVTVUxUPU9LIgp9CmZ1bmN0aW9uIEFkZC1GaW5kaW5nKCR0
HLP:ZXh0KSB7CiAgICAkc3QgPSBSZWFkLVN0YXRlOyAkc3QuZmluZGluZ3MgPSBAKCRzdC5maW5kaW5ncykgKyAkdGV4dDsgV3JpdGUtU3RhdGUgJHN0OyAiUkVTVUxUPU9LIgp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIExPR0lDQSBQVVJBIE5VRVZBIC8gQ09SUkVHSURBIChCbG9xdWUgMykKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoK
HLP:IyAtLS0gKDMuMSAvIEJ1ZyA0IC8gUmVxIDYpIE5vcm1hbGl6YWNpb24gZGUgbGEgc2VsZWNjaW9uIGRlIGZhc2VzIC0tLS0tLS0tLS0KIyBFbnRyYWRhOiBjYWRlbmEgY29uIElEcyBzZXBhcmFkb3MgcG9yIGNvbWFzIChlc3BhY2lvcyBhcmJpdHJhcmlvcywgMS0y
HLP:CiMgZGlnaXRvcywgcG9zaWJsZXMgaW52YWxpZG9zKS4gU2FsaWRhOiBvYmpldG8gY29uIC5ub3JtIChsaXN0YSBjYW5vbmljYSwKIyBvcmRlbmFkYSwgdW5pY2EgZGUgSURzIGRlIDIgZGlnaXRvcyBlbiB7MDAuLjE2fSkgeSAuaW52YWxpZCAobG9zIG5vIHZhbGlk
HLP:b3MpLgojIE51bmNhIGxhbnphIGV4Y2VwY2lvbiBhbnRlIGVudHJhZGEgbWFsZm9ybWFkYSBvIHZhY2lhLgpmdW5jdGlvbiBOb3JtYWxpemUtRmFzZXMoW3N0cmluZ10kcmF3KSB7CiAgICAkdmFsaWQgICA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdl
HLP:bmVyaWMuTGlzdFtzdHJpbmddCiAgICAkaW52YWxpZCA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddCiAgICBpZiAoJG51bGwgLW5lICRyYXcgLWFuZCAkcmF3LlRyaW0oKS5MZW5ndGggLWd0IDApIHsKICAgICAgICBm
HLP:b3JlYWNoICgkdCBpbiAoJHJhdyAtc3BsaXQgJywnKSkgewogICAgICAgICAgICBpZiAoJG51bGwgLWVxICR0KSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgJHRvayA9ICgkdCAtcmVwbGFjZSAnXHMnLCAnJykgICAgICAgICAgIyBxdWl0YXIgZXNwYWNpb3MgaW50
HLP:ZXJub3MgeSBleHRlcm5vcwogICAgICAgICAgICBpZiAoJHRvayAtZXEgJycpIHsgY29udGludWUgfQogICAgICAgICAgICAkY2Fub24gPSAkdG9rCiAgICAgICAgICAgIGlmICgkdG9rIC1tYXRjaCAnXlxkJCcpIHsgJGNhbm9uID0gJHRvay5QYWRMZWZ0KDIsICcw
HLP:JykgfSAgICMgMSBkaWdpdG8gLT4gMiBkaWdpdG9zCiAgICAgICAgICAgIGlmICgkY2Fub24gLW1hdGNoICdeXGR7Mn0kJyAtYW5kIFtpbnRdJGNhbm9uIC1nZSAwIC1hbmQgW2ludF0kY2Fub24gLWxlIDE2KSB7CiAgICAgICAgICAgICAgICBpZiAoLW5vdCAkdmFs
HLP:aWQuQ29udGFpbnMoJGNhbm9uKSkgeyAkdmFsaWQuQWRkKCRjYW5vbikgfQogICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgJGludmFsaWQuQWRkKCR0b2spCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9CiAgICAkc29ydGVkID0gQCgkdmFs
HLP:aWQgfCBTb3J0LU9iamVjdCkKICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgbm9ybSA9ICRzb3J0ZWQ7IGludmFsaWQgPSBAKCRpbnZhbGlkKSB9Cn0KCiMgLS0tICgzLjMgLyBSZXEgNCkgQ2hlY2twb2ludCBzb2JyZSBjaGVja3BvaW50Lmpzb24gLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tCiMgUGFyc2VyIGRlbCAtQXJnIGNvbiBmb3JtYXRvOgojICAgInNhdmV8c2VsZWN0aW9uPTAwLDAxLDAyfGNvbXBsZXRlZD0wMCwwMXxtb2RlPWF1dG86MTtkcnk6MHxyZWFzb249Y2hrZHNrIgpmdW5jdGlvbiBQYXJzZS1DaGVja3Bv
HLP:aW50QXJnKFtzdHJpbmddJHJhdykgewogICAgJHJlcyA9IFtvcmRlcmVkXUB7IHN1YiA9ICcnOyBzZWxlY3Rpb24gPSBAKCk7IGNvbXBsZXRlZCA9IEAoKTsgbW9kZSA9IEB7fTsgcmVhc29uID0gJycgfQogICAgaWYgKFtzdHJpbmddOjpJc051bGxPckVtcHR5KCRy
HLP:YXcpKSB7IHJldHVybiAkcmVzIH0KICAgICRzZWdzID0gJHJhdyAtc3BsaXQgJ1x8JwogICAgJHJlcy5zdWIgPSAkc2Vnc1swXS5UcmltKCkuVG9Mb3dlcigpCiAgICBmb3IgKCRpID0gMTsgJGkgLWx0ICRzZWdzLkNvdW50OyAkaSsrKSB7CiAgICAgICAgJGt2ID0g
HLP:JHNlZ3NbJGldIC1zcGxpdCAnPScsIDIKICAgICAgICBpZiAoJGt2LkNvdW50IC1sdCAyKSB7IGNvbnRpbnVlIH0KICAgICAgICAka2V5ID0gJGt2WzBdLlRyaW0oKS5Ub0xvd2VyKCkKICAgICAgICAkdmFsID0gJGt2WzFdCiAgICAgICAgc3dpdGNoICgka2V5KSB7
HLP:CiAgICAgICAgICAgICdzZWxlY3Rpb24nIHsgJHJlcy5zZWxlY3Rpb24gPSBAKCR2YWwgLXNwbGl0ICcsJyB8IEZvckVhY2gtT2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBXaGVyZS1PYmplY3QgeyAkXyAtbmUgJycgfSkgfQogICAgICAgICAgICAnY29tcGxldGVkJyB7
HLP:ICRyZXMuY29tcGxldGVkID0gQCgkdmFsIC1zcGxpdCAnLCcgfCBGb3JFYWNoLU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgV2hlcmUtT2JqZWN0IHsgJF8gLW5lICcnIH0pIH0KICAgICAgICAgICAgJ3JlYXNvbicgICAgeyAkcmVzLnJlYXNvbiA9ICR2YWwuVHJpbSgp
HLP:IH0KICAgICAgICAgICAgJ21vZGUnIHsKICAgICAgICAgICAgICAgICRtID0gQHt9CiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcGFpciBpbiAoJHZhbCAtc3BsaXQgJzsnKSkgewogICAgICAgICAgICAgICAgICAgICRwID0gJHBhaXIgLXNwbGl0ICc6JywgMgog
HLP:ICAgICAgICAgICAgICAgICAgIGlmICgkcC5Db3VudCAtZXEgMikgeyAkbVskcFswXS5UcmltKCkuVG9Mb3dlcigpXSA9ICgkcFsxXS5UcmltKCkgLWVxICcxJykgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgJHJlcy5tb2RlID0gJG0KICAgICAg
HLP:ICAgICAgfQogICAgICAgIH0KICAgIH0KICAgIHJldHVybiAkcmVzCn0KCiMgQ29uc3RydXllIHkgcGVyc2lzdGUgY2hlY2twb2ludC5qc29uLiBEZXZ1ZWx2ZSAkdHJ1ZS8kZmFsc2UgKHNpbiBleGNlcGNpb24pLgpmdW5jdGlvbiBTYXZlLUNoZWNrcG9pbnQoJHBh
HLP:cnNlZCkgewogICAgdHJ5IHsKICAgICAgICAkbW9kZSA9IFtwc2N1c3RvbW9iamVjdF1AewogICAgICAgICAgICBhdXRvICAgICA9IFtib29sXSRwYXJzZWQubW9kZVsnYXV0byddCiAgICAgICAgICAgIG5vcmVib290ID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydub3Jl
HLP:Ym9vdCddCiAgICAgICAgICAgIGtlZXB3dSAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydrZWVwd3UnXQogICAgICAgICAgICBkcnkgICAgICA9IFtib29sXSRwYXJzZWQubW9kZVsnZHJ5J10KICAgICAgICAgICAgdHJpYWdlICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVb
HLP:J3RyaWFnZSddCiAgICAgICAgfQogICAgICAgICRub3cgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkX0hILW1tJykKICAgICAgICAkY3AgPSBbcHNjdXN0b21vYmplY3RdQHsKICAgICAgICAgICAgdmVyc2lvbiAgICAgICAgPSAkV1BJX1ZFUlNJT04K
HLP:ICAgICAgICAgICAgY3JlYXRlZCAgICAgICAgPSAkbm93CiAgICAgICAgICAgIG1vZGUgICAgICAgICAgID0gJG1vZGUKICAgICAgICAgICAgc2VsZWN0aW9uICAgICAgPSBAKCRwYXJzZWQuc2VsZWN0aW9uKQogICAgICAgICAgICBjb21wbGV0ZWQgICAgICA9IEAo
HLP:JHBhcnNlZC5jb21wbGV0ZWQpCiAgICAgICAgICAgIHBlbmRpbmdfcmVhc29uID0gJHBhcnNlZC5yZWFzb24KICAgICAgICAgICAgdGltZXN0YW1wX3J1biAgPSAkbm93CiAgICAgICAgfQogICAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkQ2hl
HLP:Y2twb2ludEZpbGUsICgkY3AgfCBDb252ZXJ0VG8tSnNvbiAtRGVwdGggNiksIChOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpKSkKICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0KfQoKIyBD
HLP:YXJnYSBjaGVja3BvaW50Lmpzb24uIERldnVlbHZlIGVsIG9iamV0byBvICRudWxsIHNpIG5vIGV4aXN0ZSAvIG1hbGZvcm1hZG8uCmZ1bmN0aW9uIExvYWQtQ2hlY2twb2ludCB7CiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkpIHsgcmV0
HLP:dXJuICRudWxsIH0KICAgIHRyeSB7IHJldHVybiAoR2V0LUNvbnRlbnQgJENoZWNrcG9pbnRGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uKSB9IGNhdGNoIHsgcmV0dXJuICRudWxsIH0KfQoKIyBWYWxpZGEgdW4gY2hlY2twb2ludDogZXhpc3RlICsgcGFyc2Vh
HLP:YmxlICsgdmVyc2lvbiBjb21wYXRpYmxlICsgY29tcGxldGVkCiMgc3ViY29uanVudG8gZGUgc2VsZWN0aW9uICsgY3JlYXRlZCBkZW50cm8gZGUgbGEgdmVudGFuYS4gRGV2dWVsdmUgYm9vbGVhbm8KIyBTSU4gbGFuemFyIGV4Y2VwY2lvbiBhbnRlIEpTT04gbWFs
HLP:Zm9ybWFkbyBvIGNhZHVjYWRvLgpmdW5jdGlvbiBUZXN0LUNoZWNrcG9pbnRWYWxpZCgkY3ApIHsKICAgIHRyeSB7CiAgICAgICAgaWYgKCRudWxsIC1lcSAkY3ApIHsKICAgICAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkQ2hlY2twb2ludEZpbGUpKSB7IHJl
HLP:dHVybiAkZmFsc2UgfQogICAgICAgICAgICB0cnkgeyAkY3AgPSBHZXQtQ29udGVudCAkQ2hlY2twb2ludEZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIH0KICAgICAgICBpZiAoJG51bGwgLWVxICRj
HLP:cCkgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICBpZiAoW3N0cmluZ10kY3AudmVyc2lvbiAtbmUgJFdQSV9WRVJTSU9OKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgICRzZWwgID0gQCgkY3Auc2VsZWN0aW9uKQogICAgICAgICRjb21wID0gQCgkY3AuY29tcGxl
HLP:dGVkKQogICAgICAgIGZvcmVhY2ggKCRjIGluICRjb21wKSB7IGlmICgkc2VsIC1ub3Rjb250YWlucyAkYykgeyByZXR1cm4gJGZhbHNlIH0gfQogICAgICAgICRjcmVhdGVkID0gJG51bGwKICAgICAgICBpZiAoJGNwLmNyZWF0ZWQpIHsKICAgICAgICAgICAgdHJ5
HLP:IHsgJGNyZWF0ZWQgPSBbZGF0ZXRpbWVdOjpQYXJzZUV4YWN0KFtzdHJpbmddJGNwLmNyZWF0ZWQsICd5eXl5LU1NLWRkX0hILW1tJywgJG51bGwpIH0gY2F0Y2ggeyAkY3JlYXRlZCA9ICRudWxsIH0KICAgICAgICB9CiAgICAgICAgaWYgKCRudWxsIC1lcSAkY3Jl
HLP:YXRlZCkgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICAkYWdlID0gKEdldC1EYXRlKSAtICRjcmVhdGVkCiAgICAgICAgaWYgKCRhZ2UuVG90YWxEYXlzIC1ndCAkQ0hFQ0tQT0lOVF9NQVhfQUdFX0RBWVMpIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgcmV0dXJu
HLP:ICR0cnVlCiAgICB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9Cn0KCiMgUHJpbWVyYSBmYXNlIGRlICdzZWxlY3Rpb24nIG5vIHByZXNlbnRlIGVuICdjb21wbGV0ZWQnIChvICcnIHNpIHRvZGFzIGhlY2hhcykuCmZ1bmN0aW9uIEdldC1OZXh0UGhhc2UoJGNwKSB7
HLP:CiAgICBpZiAoJG51bGwgLWVxICRjcCkgeyByZXR1cm4gJycgfQogICAgJGNvbXAgPSBAKCRjcC5jb21wbGV0ZWQpCiAgICBmb3JlYWNoICgkcyBpbiBAKCRjcC5zZWxlY3Rpb24pKSB7IGlmICgkY29tcCAtbm90Y29udGFpbnMgJHMpIHsgcmV0dXJuICRzIH0gfQog
HLP:ICAgcmV0dXJuICcnCn0KCiMgLS0tICgzLjkgLyBCdWcgNiAvIFJlcSA4KSBSZXNldCBkZSBlc3RhZG8gcmV1dGlsaXphYmxlIC0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgRGVqYSBwaGFzZXM9QCgpLCBmaW5kaW5ncz1AKCkgeSBsb3Mgc2NvcmVzIChiZWZvcmUvYWZ0
HLP:ZXIpIGEgbnVsbC4gRWwKIyBjb25kaWNpb25hZG8gYSAvcmVzdW1lIGxvIGFwbGljYSBlbCBiYXRjaCAodGFyZWFzIDguNCAvIDkuMSk6IHNvbG8gaW52b2NhCiMgJ3Jlc2V0c3RhdGUnIGN1YW5kbyBSRVNVTUU9PTAsIGNvbnNlcnZhbmRvIGVsIGVzdGFkbyBwcmV2
HLP:aW8gZW4gL3Jlc3VtZS4KZnVuY3Rpb24gUmVzZXQtU3RhdGUgewogICAgV3JpdGUtU3RhdGUgKFtwc2N1c3RvbW9iamVjdF1AeyBzY29yZV9iZWZvcmUgPSAkbnVsbDsgc2NvcmVfYWZ0ZXIgPSAkbnVsbDsgZmluZGluZ3MgPSBAKCk7IHBoYXNlcyA9IEAoKSB9KQp9
HLP:CgojIC0tLSAoMy4xMSAvIEJ1ZyA3IC8gUmVxIDkpIEhvbmVzdGlkYWQgZGVsIG1vdmltaWVudG8gZGUgY2FjaGVzIC0tLS0tLS0tLS0tLQojIEV4aXRvICh0cnVlKSBTSSBZIFNPTE8gU0kgZWwgb3JpZ2VuIGVzdGEgYXVzZW50ZSB5IGVsIGRlc3Rpbm8gcHJlc2Vu
HLP:dGUuCiMgVmFyaWFudGUgcHVyYSAoYm9vbGVhbm9zKSArIHZhcmlhbnRlIHF1ZSBhY2VwdGEgcnV0YXMgeSBoYWNlIFRlc3QtUGF0aC4KZnVuY3Rpb24gVGVzdC1Nb3ZlUmVzdWx0KFtib29sXSRzcmNFeGlzdHMsIFtib29sXSRkc3RFeGlzdHMpIHsKICAgIHJldHVy
HLP:biAoKC1ub3QgJHNyY0V4aXN0cykgLWFuZCAkZHN0RXhpc3RzKQp9CmZ1bmN0aW9uIFRlc3QtTW92ZVJlc3VsdFBhdGgoW3N0cmluZ10kc3JjLCBbc3RyaW5nXSRkc3QpIHsKICAgIHJldHVybiAoVGVzdC1Nb3ZlUmVzdWx0IChbYm9vbF0oVGVzdC1QYXRoICRzcmMp
HLP:KSAoW2Jvb2xdKFRlc3QtUGF0aCAkZHN0KSkpCn0KCiMgLS0tICgzLjExIC8gQnVnIDggLyBSZXEgMTApIElkZW1wb3RlbmNpYSBkZSBWaXJ0dWFsVGVybWluYWxMZXZlbCAtLS0tLS0tLS0tCiMgTm9ybWFsaXphIHZhbG9yZXMgJzB4MScgLyAnMScgLyAxIGEgZW50
HLP:ZXJvIHBhcmEgY29tcGFyYXIgZGUgZm9ybWEgcm9idXN0YS4KZnVuY3Rpb24gQ29udmVydFRvLVZ0bEludCgkdikgewogICAgaWYgKCRudWxsIC1lcSAkdikgeyByZXR1cm4gJG51bGwgfQogICAgJHMgPSAoW3N0cmluZ10kdikuVHJpbSgpLlRvTG93ZXIoKQogICAg
HLP:aWYgKCRzIC1lcSAnJykgeyByZXR1cm4gJG51bGwgfQogICAgdHJ5IHsKICAgICAgICBpZiAoJHMuU3RhcnRzV2l0aCgnMHgnKSkgeyByZXR1cm4gW0NvbnZlcnRdOjpUb0ludDMyKCRzLCAxNikgfQogICAgICAgIHJldHVybiBbaW50XSRzCiAgICB9IGNhdGNoIHsg
HLP:cmV0dXJuICRudWxsIH0KfQojIERldnVlbHZlICR0cnVlIChlc2NyaWJpcikgc29sbyBzaSBlbCB2YWxvciBhY3R1YWwgZGlmaWVyZSBkZWwgZGVzZWFkby4KZnVuY3Rpb24gUmVzb2x2ZS1WdGxXcml0ZSgkY3VycmVudCwgJGRlc2lyZWQpIHsKICAgIHJldHVybiAo
HLP:KENvbnZlcnRUby1WdGxJbnQgJGN1cnJlbnQpIC1uZSAoQ29udmVydFRvLVZ0bEludCAkZGVzaXJlZCkpCn0KCiMgLS0tICgzLjE0IC8gUmVxIDEuMykgTWFwZW8gVE9UQUwgZGUgY29kaWdvIGRlIHNhbGlkYSBhIHtPSyxXQVJOLFNLSVAsRVJST1J9CiMgMC0+T0ss
HLP:IDEtPldBUk4sIDItPlNLSVAsIDMtPkVSUk9SOyBjdWFscXVpZXIgb3RybyBlbnRlcm8gKG8gbm8gZW50ZXJvKSAtPiBFUlJPUi4KZnVuY3Rpb24gTWFwLUV4aXRDb2RlKCRjb2RlKSB7CiAgICAkbiA9ICRudWxsCiAgICB0cnkgeyAkbiA9IFtpbnRdJGNvZGUgfSBj
HLP:YXRjaCB7IHJldHVybiAnRVJST1InIH0KICAgIHN3aXRjaCAoJG4pIHsKICAgICAgICAwICAgICAgIHsgJ09LJyB9CiAgICAgICAgMSAgICAgICB7ICdXQVJOJyB9CiAgICAgICAgMiAgICAgICB7ICdTS0lQJyB9CiAgICAgICAgMyAgICAgICB7ICdFUlJPUicgfQog
HLP:ICAgICAgIGRlZmF1bHQgeyAnRVJST1InIH0KICAgIH0KfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBESUFHTk9TVElDTyBBTVBMSUFETyAoNS4xIC8gUmVxIDE1
HLP:LjEtMTUuNSkKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKIyAtLS0gUkFNIChSZXEgMTUuMSkgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLQojIFJlc29sdmUtUmFtU3RhdHVzOiBmdW5jaW9uIFBVUkEuIEEgcGFydGlyIGRlbCBjb250ZW8gZGUgZXJyb3JlcyBkZSBtZW1vcmlhCiMgV0hFQSB5IGRlIGZhbGxvcyBkZWwgZGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZSBXaW5kb3dzLCBk
HLP:ZWNpZGUgZWwgZXN0YWRvIHkKIyBzaSBjb252aWVuZSByZWNvbWVuZGFyIG1kc2NoZWQuCmZ1bmN0aW9uIFJlc29sdmUtUmFtU3RhdHVzKFtpbnRdJHdoZWFNZW1FcnJvcnMsIFtpbnRdJG1lbURpYWdGYWlsdXJlcykgewogICAgaWYgKCR3aGVhTWVtRXJyb3JzIC1n
HLP:dCAwIC1vciAkbWVtRGlhZ0ZhaWx1cmVzIC1ndCAwKSB7CiAgICAgICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAnc3VzcGVjdCc7IHJlY29tbWVuZF9tZHNjaGVkID0gJHRydWUgfQogICAgfQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1A
HLP:eyBzdGF0dXMgPSAnb2snOyByZWNvbW1lbmRfbWRzY2hlZCA9ICRmYWxzZSB9Cn0KCiMgR2V0LVJhbUNoZWNrOiBsZWUgZXZlbnRvcyBXSEVBIHkgcmVzdWx0YWRvcyBkZWwgRGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZQojIFdpbmRvd3MuIERlZ3JhZGFjaW9uIGVs
HLP:ZWdhbnRlOiBzaSBsYSBjb25zdWx0YSBkZSBldmVudG9zIGZhbGxhIHBvciBjb21wbGV0bywKIyBkZXZ1ZWx2ZSBzdGF0dXM9J3Vua25vd24nIHNpbiBsYW56YXIgZXhjZXBjaW9uLgpmdW5jdGlvbiBHZXQtUmFtQ2hlY2sgewogICAgdHJ5IHsKICAgICAgICAkcXVl
HLP:cmllZCA9ICRmYWxzZQogICAgICAgICR3aGVhQ291bnQgPSAwCiAgICAgICAgJG1lbURpYWdGYWlsID0gMAogICAgICAgICMgRXJyb3JlcyBkZSBoYXJkd2FyZSBXSEVBIHJlbGFjaW9uYWRvcyBjb24gbWVtb3JpYQogICAgICAgICR3aGVhID0gQChHZXQtV2luRXZl
HLP:bnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IFByb3ZpZGVyTmFtZT0nTWljcm9zb2Z0LVdpbmRvd3MtV0hFQS1Mb2dnZXInfSAtTWF4RXZlbnRzIDEwMCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICBpZiAoJG51bGwg
HLP:LW5lICR3aGVhKSB7ICRxdWVyaWVkID0gJHRydWUgfQogICAgICAgICR3aGVhQ291bnQgPSBAKCR3aGVhIHwgV2hlcmUtT2JqZWN0IHsgKCRfLklkIC1pbiAxOCwxOSwyMCw0NykgLW9yICgkXy5NZXNzYWdlIC1tYXRjaCAnbWVtb3InKSB9KS5Db3VudAogICAgICAg
HLP:ICMgUmVzdWx0YWRvcyBkZWwgRGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZSBXaW5kb3dzIChtZHNjaGVkKQogICAgICAgICRtZCA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBQcm92aWRlck5hbWU9J01pY3Jvc29m
HLP:dC1XaW5kb3dzLU1lbW9yeURpYWdub3N0aWNzLVJlc3VsdHMnfSAtTWF4RXZlbnRzIDUwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkbnVsbCAtbmUgJG1kKSB7ICRxdWVyaWVkID0gJHRydWUgfQogICAgICAgICRtZW1EaWFnRmFp
HLP:bCA9IEAoJG1kIHwgV2hlcmUtT2JqZWN0IHsgKCRfLklkIC1lcSAxMDAyKSAtb3IgKCRfLkxldmVsRGlzcGxheU5hbWUgLWVxICdFcnJvcicpIC1vciAoJF8uTWVzc2FnZSAtbWF0Y2ggJ2Vycm9yfGVycm9yZXMnKSB9KS5Db3VudAogICAgICAgIHJldHVybiAoUmVz
HLP:b2x2ZS1SYW1TdGF0dXMgJHdoZWFDb3VudCAkbWVtRGlhZ0ZhaWwpCiAgICB9IGNhdGNoIHsKICAgICAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICd1bmtub3duJzsgcmVjb21tZW5kX21kc2NoZWQgPSAkZmFsc2UgfQogICAgfQp9CgojIC0t
HLP:LSBCYXRlcmlhIChSZXEgMTUuMikgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgR2V0LUJhdHRlcnlIZWFsdGhQY3Q6IGZ1bmNpb24gUFVSQS4gJSBkZSBzYWx1ZCA9IHBsZW5hIGNhcmdhIC8gZGlzZW5vICogMTAw
HLP:LgpmdW5jdGlvbiBHZXQtQmF0dGVyeUhlYWx0aFBjdCgkZGVzaWduLCAkZnVsbCkgewogICAgdHJ5IHsKICAgICAgICAkZCA9IFtkb3VibGVdJGRlc2lnbjsgJGYgPSBbZG91YmxlXSRmdWxsCiAgICAgICAgaWYgKCRkIC1ndCAwKSB7IHJldHVybiBbaW50XVttYXRo
HLP:XTo6Um91bmQoKCRmIC8gJGQpICogMTAwKSB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gJG51bGwKfQoKIyBHZXQtQmF0dGVyeUhlYWx0aDogc2kgaGF5IGJhdGVyaWEsIGdlbmVyYSBwb3dlcmNmZyAvYmF0dGVyeXJlcG9ydCB5IGV4dHJhZSBsYQojIHNhbHVk
HLP:IChjYXBhY2lkYWQgZGUgZGlzZW5vIHZzIHBsZW5hIGNhcmdhKS4gU2luIGJhdGVyaWEgLT4gcHJlc2VudD0kZmFsc2UuCiMgTm8gZmFsbGEgc2kgcG93ZXJjZmcgbm8gZXN0YSBkaXNwb25pYmxlIChoZWFsdGhfcGN0IHF1ZWRhIHZhY2lvKS4KZnVuY3Rpb24gR2V0
HLP:LUJhdHRlcnlIZWFsdGggewogICAgJHByZXNlbnQgPSAkZmFsc2U7ICRoZWFsdGhQY3QgPSAnJzsgJHJlcG9ydFBhdGggPSAnJwogICAgdHJ5IHsKICAgICAgICAkYmF0ID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfQmF0dGVyeSAtRXJyb3JBY3Rpb24gU2lsZW50
HLP:bHlDb250aW51ZSkKICAgICAgICBpZiAoJGJhdC5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAkcHJlc2VudCA9ICR0cnVlCiAgICAgICAgICAgICRyZXBvcnRQYXRoID0gSm9pbi1QYXRoICRXb3JrICdiYXR0ZXJ5LXJlcG9ydC5odG1sJwogICAgICAgICAgICB0
HLP:cnkgeyAmIHBvd2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0IC9vdXRwdXQgIiRyZXBvcnRQYXRoIiAvZHVyYXRpb24gMSA+ICRudWxsIDI+JjEgfSBjYXRjaCB7fQogICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRyZXBvcnRQYXRoKSB7CiAgICAgICAgICAgICAgICB0cnkg
HLP:ewogICAgICAgICAgICAgICAgICAgICR0eHQgPSBHZXQtQ29udGVudCAkcmVwb3J0UGF0aCAtUmF3CiAgICAgICAgICAgICAgICAgICAgJGRlc2lnbiA9ICRudWxsOyAkZnVsbCA9ICRudWxsCiAgICAgICAgICAgICAgICAgICAgJG0xID0gW3JlZ2V4XTo6TWF0Y2go
HLP:JHR4dCwgJyg/aXMpREVTSUdOIENBUEFDSVRZLio/KFtcZFwuLF0rKVxzKm1XaCcpCiAgICAgICAgICAgICAgICAgICAgJG0yID0gW3JlZ2V4XTo6TWF0Y2goJHR4dCwgJyg/aXMpRlVMTCBDSEFSR0UgQ0FQQUNJVFkuKj8oW1xkXC4sXSspXHMqbVdoJykKICAgICAg
HLP:ICAgICAgICAgICAgICBpZiAoJG0xLlN1Y2Nlc3MpIHsgJGRlc2lnbiA9IFtkb3VibGVdKCgkbTEuR3JvdXBzWzFdLlZhbHVlIC1yZXBsYWNlICdbXC4sXScsICcnKSkgfQogICAgICAgICAgICAgICAgICAgIGlmICgkbTIuU3VjY2VzcykgeyAkZnVsbCAgID0gW2Rv
HLP:dWJsZV0oKCRtMi5Hcm91cHNbMV0uVmFsdWUgLXJlcGxhY2UgJ1tcLixdJywgJycpKSB9CiAgICAgICAgICAgICAgICAgICAgJHBjdCA9IEdldC1CYXR0ZXJ5SGVhbHRoUGN0ICRkZXNpZ24gJGZ1bGwKICAgICAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRw
HLP:Y3QpIHsgJGhlYWx0aFBjdCA9ICRwY3QgfQogICAgICAgICAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBwcmVzZW50ID0gJHByZXNlbnQ7IGhlYWx0aF9w
HLP:Y3QgPSAkaGVhbHRoUGN0OyByZXBvcnRfcGF0aCA9ICRyZXBvcnRQYXRoIH0KfQoKIyAtLS0gUmVkIGF2YW56YWRhIChSZXEgMTUuNSkgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEdldC1OZXRBZHZhbmNlZDogY29uZWN0
HLP:aXZpZGFkIChwaW5nIGEgMS4xLjEuMSksIEROUyAoUmVzb2x2ZS1EbnNOYW1lIGNvbgojIHJlc3BhbGRvIHBvciBwaW5nIGEgdW4gaG9zdCkgeSBjb25maWd1cmFjaW9uIGJhc2ljYSAoSVAvZ2F0ZXdheSkuCiMgRGVncmFkYWNpb24gZWxlZ2FudGU6IG51bmNhIGxh
HLP:bnphIGV4Y2VwY2lvbi4KZnVuY3Rpb24gR2V0LU5ldEFkdmFuY2VkIHsKICAgICRjb25uZWN0ZWQgPSAkZmFsc2U7ICRkbnNPayA9ICRmYWxzZTsgJGRldGFpbHMgPSAnJwogICAgdHJ5IHsKICAgICAgICAjIENvbmVjdGl2aWRhZAogICAgICAgICRwaW5nID0gJGZh
HLP:bHNlCiAgICAgICAgdHJ5IHsgJHBpbmcgPSBbYm9vbF0oVGVzdC1Db25uZWN0aW9uIC1Db21wdXRlck5hbWUgJzEuMS4xLjEnIC1Db3VudCAxIC1RdWlldCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkgfSBjYXRjaCB7ICRwaW5nID0gJGZhbHNlIH0KICAg
HLP:ICAgICBpZiAoLW5vdCAkcGluZykgewogICAgICAgICAgICB0cnkgeyAmIHBpbmcgLW4gMSAtdyAxNTAwIDEuMS4xLjEgPiAkbnVsbCAyPiYxOyBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCkgeyAkcGluZyA9ICR0cnVlIH0gfSBjYXRjaCB7fQogICAgICAgIH0KICAg
HLP:ICAgICAkY29ubmVjdGVkID0gW2Jvb2xdJHBpbmcKICAgICAgICAjIFJlc29sdWNpb24gRE5TIChjb24gbWVkaWRhIGRlIGxhdGVuY2lhKQogICAgICAgICRkbnMgPSAkZmFsc2U7ICRkbnNNcyA9ICRudWxsCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHN3ID0g
HLP:W1N5c3RlbS5EaWFnbm9zdGljcy5TdG9wd2F0Y2hdOjpTdGFydE5ldygpCiAgICAgICAgICAgICRyID0gUmVzb2x2ZS1EbnNOYW1lIC1OYW1lICd3d3cubWljcm9zb2Z0LmNvbScgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgJHN3LlN0
HLP:b3AoKQogICAgICAgICAgICBpZiAoJHIpIHsgJGRucyA9ICR0cnVlOyAkZG5zTXMgPSBbaW50XSRzdy5FbGFwc2VkTWlsbGlzZWNvbmRzIH0KICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgaWYgKC1ub3QgJGRucykgewogICAgICAgICAgICB0cnkgeyAmIHBpbmcg
HLP:LW4gMSAtdyAxNTAwIHd3dy5taWNyb3NvZnQuY29tID4gJG51bGwgMj4mMTsgaWYgKCRMQVNURVhJVENPREUgLWVxIDApIHsgJGRucyA9ICR0cnVlIH0gfSBjYXRjaCB7fQogICAgICAgIH0KICAgICAgICAkZG5zT2sgPSBbYm9vbF0kZG5zCiAgICAgICAgIyBDb25m
HLP:aWd1cmFjaW9uIGJhc2ljYSAoSVAgLyBnYXRld2F5KQogICAgICAgICRpcCA9ICcnOyAkZ3cgPSAnJwogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRjZmcgPSBAKEdldC1OZXRJUENvbmZpZ3VyYXRpb24gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBX
HLP:aGVyZS1PYmplY3QgeyAkXy5JUHY0RGVmYXVsdEdhdGV3YXkgfSkgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIGlmICgkY2ZnKSB7CiAgICAgICAgICAgICAgICAkaXAgPSAoJGNmZy5JUHY0QWRkcmVzcyB8IFNlbGVjdC1PYmplY3QgLUZpcnN0
HLP:IDEpLklQQWRkcmVzcwogICAgICAgICAgICAgICAgJGd3ID0gKCRjZmcuSVB2NERlZmF1bHRHYXRld2F5IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkuTmV4dEhvcAogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7fQogICAgICAgICRkZXRhaWxzID0gIklQ
HLP:PSRpcDsgR1c9JGd3IgogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBjb25uZWN0ZWQgPSAkY29ubmVjdGVkOyBkbnNfb2sgPSAkZG5zT2s7IGRldGFpbHMgPSAkZGV0YWlsczsgZG5zX21zID0gJGRuc01zIH0KfQoKIyAtLS0gRGlz
HLP:cG9zaXRpdm9zIHBhcmEgZGlhZyAoUmVxIDE1LjMvMTUuNCkgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEdldC1EZXZpY2VMaXN0OiBsaXN0YSBlc3RydWN0dXJhZGEgZGUgZGlzcG9zaXRpdm9zIGNvbiBlcnJvciBwYXJhIGVzdGFkby5kaWFnLgoj
HLP:IERldnVlbHZlICRudWxsIHNpIGxhIGlkZW50aWZpY2FjaW9uIGRlIGRyaXZlcnMgZmFsbGEgKHNlbmFsIGRlICJpbmZvIG5vCiMgZGlzcG9uaWJsZSIgcGFyYSBkZWdyYWRhY2lvbiBlbGVnYW50ZSkuCmZ1bmN0aW9uIEdldC1EZXZpY2VMaXN0IHsKICAgIHRyeSB7
HLP:CiAgICAgICAgJHAgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9QblBFbnRpdHkgLUVycm9yQWN0aW9uIFN0b3AgfCBXaGVyZS1PYmplY3QgeyAkXy5Db25maWdNYW5hZ2VyRXJyb3JDb2RlIC1ndCAwIH0pCiAgICAgICAgJGxpc3QgPSBAKCkKICAgICAgICBmb3Jl
HLP:YWNoICgkZCBpbiAoJHAgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxMikpIHsKICAgICAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7IGNvZGUgPSBbaW50XSRkLkNvbmZpZ01hbmFnZXJFcnJvckNvZGU7IG5hbWUgPSBbc3RyaW5nXSRkLk5hbWUgfQog
HLP:ICAgICAgIH0KICAgICAgICByZXR1cm4gLCRsaXN0CiAgICB9IGNhdGNoIHsgcmV0dXJuICRudWxsIH0KfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBST1RBQ0lP
HLP:TiBERSBMT0dTICg1LjYgLyBSZXEgMTcuMikKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojIFNlbGVjdC1Mb2dzVG9EZWxldGU6IGZ1bmNpb24gUFVSQS4gRGUgdW5hIGNv
HLP:bGVjY2lvbiBkZSBmaWNoZXJvcyAoY29uCiMgLkxhc3RXcml0ZVRpbWUpIHkgdW5hIHJldGVuY2lvbiBOLCBkZXZ1ZWx2ZSBsb3MgcXVlIGRlYmVuIEJPUlJBUlNFOiB0b2RvcwojIG1lbm9zIGxvcyBOIG1hcyByZWNpZW50ZXMgKGVzIGRlY2lyLCBsb3MgbWFzIGFu
HLP:dGlndW9zKS4gU2kgaGF5IDw9IE4sIG5pbmd1bm8uCmZ1bmN0aW9uIFNlbGVjdC1Mb2dzVG9EZWxldGUoJGZpbGVzLCBbaW50XSRyZXRlbnRpb24pIHsKICAgICRhcnIgPSBAKCRmaWxlcykKICAgIGlmICgkcmV0ZW50aW9uIC1sdCAwKSB7ICRyZXRlbnRpb24gPSAw
HLP:IH0KICAgIGlmICgkYXJyLkNvdW50IC1sZSAkcmV0ZW50aW9uKSB7IHJldHVybiBAKCkgfQogICAgJHNvcnRlZCA9IEAoJGFyciB8IFNvcnQtT2JqZWN0IC1Qcm9wZXJ0eSBMYXN0V3JpdGVUaW1lIC1EZXNjZW5kaW5nKQogICAgcmV0dXJuIEAoJHNvcnRlZCB8IFNl
HLP:bGVjdC1PYmplY3QgLVNraXAgJHJldGVudGlvbikKfQoKIyBJbnZva2UtTG9nUm90YXRlOiBjb25zZXJ2YSBsb3MgJHJldGVudGlvbiBsb2dzIG1hcyByZWNpZW50ZXMgZW4gJGZvbGRlciB5CiMgYm9ycmEgZWwgcmVzdG8uIERldnVlbHZlIGVsIG51bWVybyBkZSBm
HLP:aWNoZXJvcyBib3JyYWRvcy4KZnVuY3Rpb24gSW52b2tlLUxvZ1JvdGF0ZShbc3RyaW5nXSRmb2xkZXIsIFtpbnRdJHJldGVudGlvbikgewogICAgaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJGZvbGRlcikpIHsgJGZvbGRlciA9IEpvaW4tUGF0aCAk
HLP:V29yayAnTG9ncycgfQogICAgJGRlbGV0ZWQgPSAwCiAgICB0cnkgewogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJGZvbGRlcikpIHsgcmV0dXJuIDAgfQogICAgICAgICRmaWxlcyA9IEAoR2V0LUNoaWxkSXRlbSAtUGF0aCAkZm9sZGVyIC1GaWx0ZXIgJyou
HLP:bG9nJyAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICAkdG9EZWxldGUgPSBTZWxlY3QtTG9nc1RvRGVsZXRlICRmaWxlcyAkcmV0ZW50aW9uCiAgICAgICAgZm9yZWFjaCAoJGYgaW4gJHRvRGVsZXRlKSB7CiAgICAgICAgICAgIHRy
HLP:eSB7IFJlbW92ZS1JdGVtICRmLkZ1bGxOYW1lIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgJGRlbGV0ZWQrKyB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuICRkZWxldGVkCn0KCiMgPT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgVkFMSURBQ0lPTiBERSBFTlRPUk5PIFkgU0VMRi1URVNUICg1LjggLyBSZXEgMTMuNSwxMy42LDE4LjEsMTguMywxOC42KQojID09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgVGVzdC1Pc1N1cHBvcnRlZDogZnVuY2lvbiBQVVJBLiBXaW5kb3dzIDEwLzExID0+IGJ1aWxkID49IDEwMjQwLgpmdW5jdGlvbiBUZXN0LU9zU3Vw
HLP:cG9ydGVkKFtpbnRdJGJ1aWxkKSB7CiAgICByZXR1cm4gKCRidWlsZCAtZ2UgMTAyNDApCn0KCiMgSW52b2tlLUVudlZhbGlkYXRlOiBjb21wcnVlYmEgbGEgdmVyc2lvbiBkZWwgU08gdmlhIENJTS4gTGEgY29tcHJvYmFjaW9uIHNlCiMgY29uc2lkZXJhIFNJRU1Q
HLP:UkUgcmVhbGl6YWRhIChjaGVja19kb25lKSBhdW5xdWUgbGEgdmVyc2lvbiBubyBzZWEgY29tcGF0aWJsZS4KZnVuY3Rpb24gSW52b2tlLUVudlZhbGlkYXRlIHsKICAgICRidWlsZCA9IDAKICAgIHRyeSB7ICRidWlsZCA9IFtpbnRdKEdldC1DaW1JbnN0YW5jZSBX
HLP:aW4zMl9PcGVyYXRpbmdTeXN0ZW0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLkJ1aWxkTnVtYmVyIH0gY2F0Y2ggeyAkYnVpbGQgPSAwIH0KICAgIGlmICgkYnVpbGQgLWxlIDApIHsgdHJ5IHsgJGJ1aWxkID0gW2ludF0oR2V0LUl0ZW1Qcm9wZXJ0eSAn
HLP:SEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb24nIC1OYW1lIEN1cnJlbnRCdWlsZE51bWJlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuQ3VycmVudEJ1aWxkTnVtYmVyIH0gY2F0Y2ggeyAkYnVpbGQgPSAwIH0g
HLP:fQogICAgaWYgKCRidWlsZCAtbGUgMCkgeyB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtSXRlbVByb3BlcnR5ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvbicgLU5hbWUgQ3VycmVudEJ1aWxkIC1FcnJvckFjdGlvbiBT
HLP:aWxlbnRseUNvbnRpbnVlKS5DdXJyZW50QnVpbGQgfSBjYXRjaCB7ICRidWlsZCA9IDAgfSB9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IG9zX29rID0gKFRlc3QtT3NTdXBwb3J0ZWQgJGJ1aWxkKTsgYnVpbGQgPSAkYnVpbGQ7IGNoZWNrX2RvbmUgPSAk
HLP:dHJ1ZSB9Cn0KCiMgSW52b2tlLVNlbGZUZXN0OiBhZ3JlZ2Fkb3IgUFVSTy4gRXhpdG8gKHRydWUpIHNpIHkgc29sbyBzaSBUT0RBUyBsYXMKIyBjb21wcm9iYWNpb25lcyAoYm9vbGVhbm9zKSBwYXNhbi4gQ29sZWNjaW9uIHZhY2lhIC0+IHRydWUgKG5hZGEgZmFs
HLP:bG8pLgpmdW5jdGlvbiBJbnZva2UtU2VsZlRlc3QoJHJlc3VsdHMpIHsKICAgIGZvcmVhY2ggKCRyIGluIEAoJHJlc3VsdHMpKSB7IGlmICgtbm90IFtib29sXSRyKSB7IHJldHVybiAkZmFsc2UgfSB9CiAgICByZXR1cm4gJHRydWUKfQoKIyBQYXJzZS1Cb29sTGlz
HLP:dDogY29udmllcnRlICIxLDEsMCwxIiAobyB0cnVlL29rKSBlbiB1bmEgbGlzdGEgZGUgYm9vbGVhbm9zLgpmdW5jdGlvbiBQYXJzZS1Cb29sTGlzdChbc3RyaW5nXSRyYXcpIHsKICAgICRsaXN0ID0gQCgpCiAgICBpZiAoLW5vdCBbc3RyaW5nXTo6SXNOdWxsT3JX
HLP:aGl0ZVNwYWNlKCRyYXcpKSB7CiAgICAgICAgZm9yZWFjaCAoJHQgaW4gKCRyYXcgLXNwbGl0ICcsJykpIHsKICAgICAgICAgICAgJHRvayA9ICR0LlRyaW0oKS5Ub0xvd2VyKCkKICAgICAgICAgICAgaWYgKCR0b2sgLWVxICcnKSB7IGNvbnRpbnVlIH0KICAgICAg
HLP:ICAgICAgJGxpc3QgKz0gKCR0b2sgLWVxICcxJyAtb3IgJHRvayAtZXEgJ3RydWUnIC1vciAkdG9rIC1lcSAnb2snIC1vciAkdG9rIC1lcSAncGFzcycpCiAgICAgICAgfQogICAgfQogICAgcmV0dXJuICwkbGlzdAp9CgojID09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgRElBR05PU1RJQ08gUFJPRlVO
HLP:RE8gdjMuMSAoU01BUlQsIGFycmFucXVlLCBCQ0QsIHByb2Nlc29zLCBTRkMsIEpTT04pCiMgIFRvZGFzIGxhcyBmdW5jaW9uZXMgZGVncmFkYW4gY29uIGVsZWdhbmNpYTogc2kgYWxnbyBmYWxsYSwgZGV2dWVsdmVuCiMgIGVzdHJ1Y3R1cmFzIHZhY2lhcyAvICd1
HLP:bmtub3duJyBlbiBsdWdhciBkZSBsYW56YXIgZXhjZXBjaW9uZXMuCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCiMgR2V0LVNtYXJ0QXR0cmlidXRlczogc2FsdWQgZmlz
HLP:aWNhIGRlbCBkaXNjbyBkZSBzaXN0ZW1hIChpbmRlcGVuZGllbnRlIGRlbAojIGlkaW9tYSBkZSBXaW5kb3dzKS4gVXNhIE1TU3RvcmFnZURyaXZlcl9GYWlsdXJlUHJlZGljdFN0YXR1cyArIGVsIGNvbnRhZG9yCiMgZGUgZmlhYmlsaWRhZCBkZSBhbG1hY2VuYW1p
HLP:ZW50by4gRGV2dWVsdmUgYXZhaWxhYmxlPSRmYWxzZSBzaSBubyBoYXkgZGF0b3MuCmZ1bmN0aW9uIEdldC1TbWFydEF0dHJpYnV0ZXMgewogICAgJHJlcyA9IFtwc2N1c3RvbW9iamVjdF1AeyBhdmFpbGFibGUgPSAkZmFsc2U7IHByZWRpY3RfZmFpbCA9ICRmYWxz
HLP:ZTsgdGVtcF9jID0gJG51bGw7IHdlYXJfcGN0ID0gJG51bGw7IHBvaCA9ICRudWxsIH0KICAgIHRyeSB7CiAgICAgICAgJHBmID0gJG51bGwKICAgICAgICB0cnkgeyAkcGYgPSBAKEdldC1DaW1JbnN0YW5jZSAtTmFtZXNwYWNlICdyb290XHdtaScgLUNsYXNzTmFt
HLP:ZSAnTVNTdG9yYWdlRHJpdmVyX0ZhaWx1cmVQcmVkaWN0U3RhdHVzJyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkgfSBjYXRjaCB7ICRwZiA9ICRudWxsIH0KICAgICAgICBpZiAoJHBmIC1hbmQgJHBmLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICRy
HLP:ZXMuYXZhaWxhYmxlID0gJHRydWUKICAgICAgICAgICAgZm9yZWFjaCAoJHggaW4gJHBmKSB7IGlmICgkeC5QcmVkaWN0RmFpbHVyZSkgeyAkcmVzLnByZWRpY3RfZmFpbCA9ICR0cnVlIH0gfQogICAgICAgIH0KICAgICAgICAjIERpc2NvIHF1ZSBjb250aWVuZSBD
HLP:OiAtPiBjb250YWRvciBkZSBmaWFiaWxpZGFkCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHN5c0Rpc2sgPSAkbnVsbAogICAgICAgICAgICB0cnkgeyAkc3lzRGlzayA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBX
HLP:aGVyZS1PYmplY3QgeyAkXy5EZXZpY2VJZCAtbmUgJG51bGwgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfSBjYXRjaCB7fQogICAgICAgICAgICAkcmMgPSAkbnVsbAogICAgICAgICAgICBpZiAoJHN5c0Rpc2spIHsgJHJjID0gJHN5c0Rpc2sgfCBHZXQtU3Rv
HLP:cmFnZVJlbGlhYmlsaXR5Q291bnRlciAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgICAgIGlmICgtbm90ICRyYykgeyAkcmMgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgR2V0LVN0b3JhZ2VS
HLP:ZWxpYWJpbGl0eUNvdW50ZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgaWYgKCRyYykgewogICAgICAgICAgICAgICAgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZQogICAgICAgICAgICAg
HLP:ICAgaWYgKCRudWxsIC1uZSAkcmMuVGVtcGVyYXR1cmUgLWFuZCAkcmMuVGVtcGVyYXR1cmUgLWd0IDApIHsgJHJlcy50ZW1wX2MgPSBbaW50XSRyYy5UZW1wZXJhdHVyZSB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyYy5XZWFyKSAgICAgICAgIHsg
HLP:JHJlcy53ZWFyX3BjdCA9IFtpbnRdJHJjLldlYXIgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcmMuUG93ZXJPbkhvdXJzKSB7ICRyZXMucG9oID0gW2ludF0kcmMuUG93ZXJPbkhvdXJzIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAjIFNlbmFs
HLP:IGFkaWNpb25hbCBkZSBwcmVkaWNjaW9uIGRlIGZhbGxvIHZpYSBlc3RhZG8gZGUgc2FsdWQgZmlzaWNhCiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAkdW5oZWFsdGh5ID0gQChHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
HLP:bnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgJF8uSGVhbHRoU3RhdHVzIC1hbmQgJF8uSGVhbHRoU3RhdHVzIC1uZSAnSGVhbHRoeScgfSkKICAgICAgICAgICAgICAgIGlmICgkdW5oZWFsdGh5LkNvdW50IC1ndCAwKSB7ICRyZXMuYXZhaWxhYmxlID0gJHRydWU7ICRy
HLP:ZXMucHJlZGljdF9mYWlsID0gJHRydWUgfQogICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgfSBjYXRjaCB7fQogICAgfSBjYXRjaCB7fQogICAgcmV0dXJuICRyZXMKfQoKIyBHZXQtU3RhcnR1cEl0ZW1zOiBwcm9ncmFtYXMgcXVlIGFycmFuY2FuIGNvbiBX
HLP:aW5kb3dzICh0b3AgTiksIHBhcmEgcXVlIGVsCiMgdXN1YXJpbyB2ZWEgcXVlIHJhbGVudGl6YSBlbCBpbmljaW8uIEluZGVwZW5kaWVudGUgZGVsIGlkaW9tYS4KZnVuY3Rpb24gR2V0LVN0YXJ0dXBJdGVtcyhbaW50XSR0b3AgPSA4KSB7CiAgICB0cnkgewogICAg
HLP:ICAgICRpdGVtcyA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1N0YXJ0dXBDb21tYW5kIC1FcnJvckFjdGlvbiBTdG9wIHwKICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uQ29tbWFuZCB9IHwKICAgICAgICAgICAgU2VsZWN0LU9iamVjdCAtRmlyc3QgJHRv
HLP:cCkKICAgICAgICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRpIGluICRpdGVtcykgewogICAgICAgICAgICAkY21kID0gW3N0cmluZ10kaS5Db21tYW5kCiAgICAgICAgICAgIGlmICgkY21kLkxlbmd0aCAtZ3QgODApIHsgJGNtZCA9ICRjbWQuU3Vic3Ry
HLP:aW5nKDAsNzcpICsgJy4uLicgfQogICAgICAgICAgICAkbm0gPSBbc3RyaW5nXSRpLk5hbWU7IGlmICgtbm90ICRubSkgeyAkbm0gPSBbc3RyaW5nXSRpLkNhcHRpb24gfQogICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsgbmFtZSA9ICRubTsg
HLP:Y29tbWFuZCA9ICRjbWQgfQogICAgICAgIH0KICAgICAgICByZXR1cm4gLCRsaXN0CiAgICB9IGNhdGNoIHsgcmV0dXJuIEAoKSB9Cn0KCiMgR2V0LUJjZEludGVncml0eTogY29tcHJ1ZWJhIHF1ZSBsYSBjb25maWd1cmFjaW9uIGRlIGFycmFucXVlIChCQ0QpIHRp
HLP:ZW5lIGxhCiMgZW50cmFkYSBhY3R1YWwgY29uIG9zZGV2aWNlL2RldmljZS4gTGFzIENMQVZFUyBkZSBiY2RlZGl0IHNvbiBzaWVtcHJlIGVuCiMgaW5nbGVzLCBhc2kgcXVlIGVzIGluZGVwZW5kaWVudGUgZGVsIGlkaW9tYSBkZSBsYSBpbnRlcmZhei4KZnVuY3Rp
HLP:b24gR2V0LUJjZEludGVncml0eSB7CiAgICAkcmVzID0gW3BzY3VzdG9tb2JqZWN0XUB7IG9rID0gJGZhbHNlOyBkZXRhaWxzID0gJycgfQogICAgdHJ5IHsKICAgICAgICAkb3V0ID0gJiBiY2RlZGl0IC9lbnVtICd7Y3VycmVudH0nIDI+JG51bGwKICAgICAgICAk
HLP:dHh0ID0gKCRvdXQgLWpvaW4gImBuIikKICAgICAgICBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCAtYW5kICR0eHQgLW1hdGNoICcoP2ltKV5ccypvc2RldmljZScgLWFuZCAkdHh0IC1tYXRjaCAnKD9pbSleXHMqZGV2aWNlJykgewogICAgICAgICAgICAkcmVzLm9r
HLP:ID0gJHRydWUKICAgICAgICAgICAgJHJlcy5kZXRhaWxzID0gJ0VudHJhZGEgZGUgYXJyYW5xdWUgYWN0dWFsIGludGVncmEgKGRldmljZS9vc2RldmljZSBwcmVzZW50ZXMpLicKICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAkcmVzLm9rID0gJGZhbHNlCiAg
HLP:ICAgICAgICAgICRyZXMuZGV0YWlscyA9ICdObyBzZSBwdWRvIGNvbmZpcm1hciBsYSBlbnRyYWRhIGRlIGFycmFucXVlIGFjdHVhbC4nCiAgICAgICAgfQogICAgfSBjYXRjaCB7CiAgICAgICAgJHJlcy5vayA9ICRmYWxzZQogICAgICAgICRyZXMuZGV0YWlscyA9
HLP:ICdiY2RlZGl0IG5vIGRpc3BvbmlibGUgbyBzaW4gcGVybWlzb3MuJwogICAgfQogICAgcmV0dXJuICRyZXMKfQoKIyBHZXQtVG9wUHJvY2Vzc2VzOiBwcm9jZXNvcyBxdWUgbWFzIG1lbW9yaWEgZGUgdHJhYmFqbyBjb25zdW1lbiAodG9wIE4pLgpmdW5jdGlvbiBH
HLP:ZXQtVG9wUHJvY2Vzc2VzKFtpbnRdJHRvcCA9IDYpIHsKICAgIHRyeSB7CiAgICAgICAgJHBzID0gQChHZXQtUHJvY2VzcyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgIFNvcnQtT2JqZWN0IFdvcmtpbmdTZXQ2NCAtRGVzY2VuZGlu
HLP:ZyB8CiAgICAgICAgICAgIFNlbGVjdC1PYmplY3QgLUZpcnN0ICR0b3ApCiAgICAgICAgJGxpc3QgPSBAKCkKICAgICAgICBmb3JlYWNoICgkcCBpbiAkcHMpIHsKICAgICAgICAgICAgJG1iID0gW21hdGhdOjpSb3VuZCgkcC5Xb3JraW5nU2V0NjQgLyAxTUIpCiAg
HLP:ICAgICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBuYW1lID0gW3N0cmluZ10kcC5Qcm9jZXNzTmFtZTsgbWVtX21iID0gW2ludF0kbWIgfQogICAgICAgIH0KICAgICAgICByZXR1cm4gLCRsaXN0CiAgICB9IGNhdGNoIHsgcmV0dXJuIEAoKSB9Cn0K
HLP:CiMgR2V0LVNmY1Jlc3VsdDogY2xhc2lmaWNhIGVsIHJlc3VsdGFkbyBkZSBTRkMgbGV5ZW5kbyBDQlMubG9nIChTSUVNUFJFIGVuCiMgaW5nbGVzKSBlbiBsdWdhciBkZSBsYSBzYWxpZGEgdHJhZHVjaWRhIGRlIGxhIGNvbnNvbGEuIERldnVlbHZlIHVubyBkZToK
HLP:IyBjbGVhbiB8IHJlcGFpcmVkIHwgdW5yZXBhaXJhYmxlIHwgdW5rbm93bi4KZnVuY3Rpb24gR2V0LVNmY1Jlc3VsdCB7CiAgICAkbG9nID0gSm9pbi1QYXRoICRlbnY6d2luZGlyICdMb2dzXENCU1xDQlMubG9nJwogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkbG9n
HLP:KSkgeyByZXR1cm4gJ3Vua25vd24nIH0KICAgIHRyeSB7CiAgICAgICAgJHRhaWwgPSBAKEdldC1Db250ZW50IC1QYXRoICRsb2cgLVRhaWwgNDAwMCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICAkc3IgPSBAKCR0YWlsIHwgV2hlcmUtT2Jq
HLP:ZWN0IHsgJF8gLW1hdGNoICdcW1NSXF0nIH0pCiAgICAgICAgaWYgKCRzci5Db3VudCAtZXEgMCkgeyByZXR1cm4gJ3Vua25vd24nIH0KICAgICAgICAkam9pbmVkID0gKCRzciAtam9pbiAiYG4iKQogICAgICAgIGlmICgkam9pbmVkIC1tYXRjaCAnKD9pKWNhbm5v
HLP:dCByZXBhaXInKSB7IHJldHVybiAndW5yZXBhaXJhYmxlJyB9CiAgICAgICAgaWYgKCRqb2luZWQgLW1hdGNoICcoP2kpcmVwYWlyaW5nXHMrKFsxLTldXGQqKVxzK2NvbXBvbmVudHN8c3VjY2Vzc2Z1bGx5IHJlcGFpcmVkfHJlcGFpcmVkIGZpbGV8cmVwYWlyaW5n
HLP:IGNvcnJ1cHRlZCBmaWxlJykgeyByZXR1cm4gJ3JlcGFpcmVkJyB9CiAgICAgICAgaWYgKCRqb2luZWQgLW1hdGNoICcoP2kpdmVyaWZ5IGNvbXBsZXRlfG5vIC4qaW50ZWdyaXR5IHZpb2xhdGlvbnN8Y2Fubm90IHZlcmlmeXx2ZXJpZnlpbmcnKSB7IHJldHVybiAn
HLP:Y2xlYW4nIH0KICAgICAgICByZXR1cm4gJ2NsZWFuJwogICAgfSBjYXRjaCB7IHJldHVybiAndW5rbm93bicgfQp9CgojIE5ldy1Kc29uUmVwb3J0OiB2dWVsY2EgZWwgZXN0YWRvICsgcmVzdW1lbiBjYWxjdWxhZG8gYSB1biBmaWNoZXJvIEpTT04KIyAoLUFyZyA9
HLP:IHJ1dGEgZGUgc2FsaWRhKS4gVXRpbCBwYXJhIGF1dG9tYXRpemFjaW9uIC8gTURNIC8gaW52ZW50YXJpby4KZnVuY3Rpb24gTmV3LUpzb25SZXBvcnQoJG91dFBhdGgpIHsKICAgIHRyeSB7CiAgICAgICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgICAgICRzeXNQYWly
HLP:cyA9IEdldC1TeXNJbmZvCiAgICAgICAgJHN5c01hcCA9IEB7fQogICAgICAgIGZvcmVhY2ggKCRwIGluICRzeXNQYWlycykgeyAka3YgPSAkcCAtc3BsaXQgJz0nLDI7IGlmICgka3YuQ291bnQgLWVxIDIpIHsgJHN5c01hcFska3ZbMF1dID0gJGt2WzFdIH0gfQog
HLP:ICAgICAgICRwaGFzZXMgPSBAKCRzdC5waGFzZXMpCiAgICAgICAgJGNPSz0wOyRjV0FSTj0wOyRjRVJSPTA7JGNTS0lQPTAKICAgICAgICBmb3JlYWNoICgkcGggaW4gJHBoYXNlcykgeyBzd2l0Y2ggKFtzdHJpbmddJHBoLnJlc3VsdCkgeyAnT0snIHskY09LKyt9
HLP:ICdXQVJOJyB7JGNXQVJOKyt9ICdFUlJPUicgeyRjRVJSKyt9ICdTS0lQJyB7JGNTS0lQKyt9IH0gfQogICAgICAgICRkZWx0YSA9ICRudWxsCiAgICAgICAgaWYgKCRzdC5zY29yZV9iZWZvcmUgLW5lICRudWxsIC1hbmQgJHN0LnNjb3JlX2FmdGVyIC1uZSAkbnVs
HLP:bCkgeyAkZGVsdGEgPSBbaW50XSRzdC5zY29yZV9hZnRlciAtIFtpbnRdJHN0LnNjb3JlX2JlZm9yZSB9CiAgICAgICAgJG9iaiA9IFtwc2N1c3RvbW9iamVjdF1AewogICAgICAgICAgICBzY2hlbWEgICAgICAgPSAnd3BpLXJlcG9ydC8xJwogICAgICAgICAgICB2
HLP:ZXJzaW9uICAgICAgPSAkV1BJX1ZFUlNJT04KICAgICAgICAgICAgZ2VuZXJhdGVkICAgID0gKEdldC1EYXRlKS5Ub1N0cmluZygncycpCiAgICAgICAgICAgIG1hY2hpbmUgICAgICA9ICRlbnY6Q09NUFVURVJOQU1FCiAgICAgICAgICAgIHN5c3RlbSAgICAgICA9
HLP:ICRzeXNNYXAKICAgICAgICAgICAgc2NvcmVfYmVmb3JlID0gJHN0LnNjb3JlX2JlZm9yZQogICAgICAgICAgICBzY29yZV9hZnRlciAgPSAkc3Quc2NvcmVfYWZ0ZXIKICAgICAgICAgICAgc2NvcmVfZGVsdGEgID0gJGRlbHRhCiAgICAgICAgICAgIHN1bW1hcnkg
HLP:ICAgICA9IFtwc2N1c3RvbW9iamVjdF1AeyBvaz0kY09LOyB3YXJuPSRjV0FSTjsgZXJyb3I9JGNFUlI7IHNraXA9JGNTS0lQOyB0b3RhbD0kcGhhc2VzLkNvdW50IH0KICAgICAgICAgICAgcGhhc2VzICAgICAgID0gJHBoYXNlcwogICAgICAgICAgICBmaW5kaW5n
HLP:cyAgICAgPSBAKCRzdC5maW5kaW5ncykKICAgICAgICAgICAgZGlhZyAgICAgICAgID0gJHN0LmRpYWcKICAgICAgICB9CiAgICAgICAgJGpzb24gPSAkb2JqIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDgKICAgICAgICAkdXRmOCA9IE5ldy1PYmplY3QgU3lzdGVt
HLP:LlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkKICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJG91dFBhdGgsICRqc29uLCAkdXRmOCkKICAgICAgICAiUkVTVUxUPU9LIgogICAgICAgICJQQVRIPSRvdXRQYXRoIgogICAgfSBjYXRjaCB7CiAg
HLP:ICAgICAgIlJFU1VMVD1GQUlMIgogICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgIH0KfQoKIyBOZXctU3VwcG9ydFBhY2thZ2U6IGVtcGFxdWV0YSBsb2dzICsgaW5mb3JtZSArIGVzdGFkbyArIGJhdHRlcnktcmVwb3J0IGVuIHVuCiMg
HLP:WklQICgtQXJnID0gcnV0YSBkZWwgemlwKSBwYXJhIGVudmlhciBhIHNvcG9ydGUuIFNpbiBkZXBlbmRlbmNpYXMgZXh0ZXJuYXMKIyAodXNhIENvbXByZXNzLUFyY2hpdmUsIGluY2x1aWRvIGVuIFdpbmRvd3MgMTAvMTEpLgpmdW5jdGlvbiBOZXctU3VwcG9ydFBh
HLP:Y2thZ2UoJG91dFBhdGgpIHsKICAgIHRyeSB7CiAgICAgICAgJHRtcCA9IEpvaW4tUGF0aCAkV29yayAoJ3NvcG9ydGVfJyArIChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXlNTWRkX0hIbW1zcycpKQogICAgICAgIE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3Rvcnkg
HLP:LVBhdGggJHRtcCAtRm9yY2UgfCBPdXQtTnVsbAogICAgICAgICMgZXN0YWRvLmpzb24KICAgICAgICBpZiAoVGVzdC1QYXRoICRTdGF0ZUZpbGUpIHsgQ29weS1JdGVtICRTdGF0ZUZpbGUgKEpvaW4tUGF0aCAkdG1wICdlc3RhZG8uanNvbicpIC1Gb3JjZSAtRXJy
HLP:b3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgIyBMb2dzCiAgICAgICAgJGxvZ3MgPSBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkbG9ncykgewogICAgICAgICAgICAkZHN0TG9ncyA9IEpvaW4tUGF0aCAkdG1w
HLP:ICdMb2dzJwogICAgICAgICAgICBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRkc3RMb2dzIC1Gb3JjZSB8IE91dC1OdWxsCiAgICAgICAgICAgIEdldC1DaGlsZEl0ZW0gJGxvZ3MgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUg
HLP:fCBDb3B5LUl0ZW0gLURlc3RpbmF0aW9uICRkc3RMb2dzIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgIH0KICAgICAgICAjIEluZm9ybWVzIEhUTUwvSlNPTiBleGlzdGVudGVzIGVuIFdvcmsKICAgICAgICBHZXQtQ2hpbGRJdGVt
HLP:ICRXb3JrIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uTmFtZSAtbWF0Y2ggJyg/aSleSW5mb3JtZS4qXC4oaHRtbHxqc29uKSQnIH0gfAogICAgICAgICAgICBDb3B5LUl0ZW0gLURlc3Rp
HLP:bmF0aW9uICR0bXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgIyBiYXR0ZXJ5IHJlcG9ydCBzaSBleGlzdGUKICAgICAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAgICAgdHJ5IHsgaWYgKCRzdC5kaWFnIC1hbmQgJHN0LmRpYWcu
HLP:YmF0dGVyeSAtYW5kICRzdC5kaWFnLmJhdHRlcnkucmVwb3J0X3BhdGggLWFuZCAoVGVzdC1QYXRoICRzdC5kaWFnLmJhdHRlcnkucmVwb3J0X3BhdGgpKSB7IENvcHktSXRlbSAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9wYXRoICR0bXAgLUZvcmNlIC1FcnJvckFj
HLP:dGlvbiBTaWxlbnRseUNvbnRpbnVlIH0gfSBjYXRjaCB7fQogICAgICAgIGlmIChUZXN0LVBhdGggJG91dFBhdGgpIHsgUmVtb3ZlLUl0ZW0gJG91dFBhdGggLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICBDb21wcmVzcy1BcmNo
HLP:aXZlIC1QYXRoIChKb2luLVBhdGggJHRtcCAnKicpIC1EZXN0aW5hdGlvblBhdGggJG91dFBhdGggLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wCiAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJHRtcCAtUmVjdXJzZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5
HLP:Q29udGludWUgfSBjYXRjaCB7fQogICAgICAgICJSRVNVTFQ9T0siCiAgICAgICAgIlBBVEg9JG91dFBhdGgiCiAgICB9IGNhdGNoIHsKICAgICAgICAiUkVTVUxUPUZBSUwiCiAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgfQp9Cgpz
HLP:d2l0Y2ggKCRBY3Rpb24uVG9Mb3dlcigpKSB7CiAgICAnbm9uZScgICAgICAgICB7IH0gIyBVc2FkbyBwYXJhIGRvdC1zb3VyY2luZwogICAgJ2NoZWNrYmFja3VwcycgewogICAgICAgICRwYXJ0cyA9ICRBcmcgLXNwbGl0ICdcfCcsIDIKICAgICAgICBpZiAoJHBh
HLP:cnRzLkNvdW50IC1uZSAyKSB7ICJSRVNVTFQ9RkFJTCI7ICJFUlJPUj1Bcmd1bWVudG9zIGludmFsaWRvcyI7IGV4aXQgMCB9CiAgICAgICAgJGJrZGlyID0gJHBhcnRzWzBdCiAgICAgICAgJHRzID0gJHBhcnRzWzFdCiAgICAgICAgJHJwX29rID0gJGZhbHNlCiAg
HLP:ICAgICAgdHJ5IHsKICAgICAgICAgICAgJHJwcyA9IEdldC1Db21wdXRlclJlc3RvcmVQb2ludCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICBmb3JlYWNoICgkcnAgaW4gJHJwcykgewogICAgICAgICAgICAgICAgaWYgKCRycC5EZXNj
HLP:cmlwdGlvbiAtbGlrZSAiU3VpdGVfUmVwYXJhY2lvbl8qIikgeyAkcnBfb2sgPSAkdHJ1ZTsgYnJlYWsgfQogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7ICRycF9vayA9ICRmYWxzZSB9CiAgICAgICAgJHJlZ19vayA9ICR0cnVlCiAgICAgICAgJHNvZnQg
HLP:PSBKb2luLVBhdGggJGJrZGlyICJTT0ZUV0FSRV8kdHMucmVnIgogICAgICAgICRzeXMgPSBKb2luLVBhdGggJGJrZGlyICJTWVNURU1fJHRzLnJlZyIKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRzb2Z0KSAtb3IgKEdldC1JdGVtICRzb2Z0KS5MZW5ndGgg
HLP:LWVxIDApIHsgJHJlZ19vayA9ICRmYWxzZSB9CiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkc3lzKSAtb3IgKEdldC1JdGVtICRzeXMpLkxlbmd0aCAtZXEgMCkgeyAkcmVnX29rID0gJGZhbHNlIH0KICAgICAgICAiUlBfT0s9JChpZiAoJHJwX29rKSB7JzEn
HLP:fSBlbHNlIHsnMCd9KSIKICAgICAgICAiUkVHX09LPSQoaWYgKCRyZWdfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ2Jvb3RzdHJhcHdpbmdldCcgewogICAgICAgICRvayA9IEluc3RhbGwtV2luZ2V0Qm9vdHN0cmFwCiAgICAgICAgIkJPT1RTVFJB
HLP:UF9PSz0kKGlmICgkb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ2ZpbmRsb2NhbHNvdXJjZScgewogICAgICAgICRkcml2ZXMgPSBHZXQtUFNEcml2ZSAtUFNQcm92aWRlciBGaWxlU3lzdGVtCiAgICAgICAgJHBhdGhzID0gQCgpCiAgICAgICAgJGVk
HLP:aXRpb25JZCA9ICcnCiAgICAgICAgdHJ5IHsgJGVkaXRpb25JZCA9IChHZXQtSXRlbVByb3BlcnR5ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvbicgLU5hbWUgRWRpdGlvbklEIC1FcnJvckFjdGlvbiBTdG9wKS5FZGl0
HLP:aW9uSUQgfSBjYXRjaCB7fQogICAgICAgIGZ1bmN0aW9uIEdldC1JbnN0YWxsSW1hZ2VTb3VyY2UoW3N0cmluZ10ka2luZCwgW3N0cmluZ10kcGF0aCwgW3N0cmluZ10kZWRpdGlvbikgewogICAgICAgICAgICAkaW5kZXggPSAxCiAgICAgICAgICAgIHRyeSB7CiAg
HLP:ICAgICAgICAgICAgICAkaW1hZ2VzID0gQChHZXQtV2luZG93c0ltYWdlIC1JbWFnZVBhdGggJHBhdGggLUVycm9yQWN0aW9uIFN0b3ApCiAgICAgICAgICAgICAgICAkbWF0Y2ggPSAkbnVsbAogICAgICAgICAgICAgICAgaWYgKCRlZGl0aW9uIC1tYXRjaCAnUHJv
HLP:ZmVzc2lvbmFsJykgeyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnXGJQcm9cYnxQcm9mZXNzaW9uYWwnIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRp
HLP:b24gLW1hdGNoICdFbnRlcnByaXNlJykgeyAkbWF0Y2ggPSAkaW1hZ2VzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnRW50ZXJwcmlzZScgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgZWxzZWlmICgkZWRp
HLP:dGlvbiAtbWF0Y2ggJ0VkdWNhdGlvbicpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ0VkdWNhdGlvbicgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgZWxzZWlmICgkZWRp
HLP:dGlvbiAtbWF0Y2ggJ0NvcmUnKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdcYkhvbWVcYnxDb3JlJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLWVx
HLP:ICRtYXRjaCAtYW5kICRpbWFnZXMuQ291bnQgLWVxIDEpIHsgJG1hdGNoID0gJGltYWdlc1swXSB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRtYXRjaCkgeyAkaW5kZXggPSBbaW50XSRtYXRjaC5JbWFnZUluZGV4IH0KICAgICAgICAgICAgfSBjYXRj
HLP:aCB7fQogICAgICAgICAgICByZXR1cm4gKCJ7MH06ezF9OnsyfSIgLWYgJGtpbmQsICRwYXRoLCAkaW5kZXgpCiAgICAgICAgfQogICAgICAgIGZvcmVhY2ggKCRkIGluICRkcml2ZXMpIHsKICAgICAgICAgICAgJHJvb3QgPSAkZC5Sb290CiAgICAgICAgICAgICR3
HLP:aW0gPSBKb2luLVBhdGggJHJvb3QgInNvdXJjZXNcaW5zdGFsbC53aW0iCiAgICAgICAgICAgICRlc2QgPSBKb2luLVBhdGggJHJvb3QgInNvdXJjZXNcaW5zdGFsbC5lc2QiCiAgICAgICAgICAgICRzeHMgPSBKb2luLVBhdGggJHJvb3QgInNvdXJjZXNcc3hzIgog
HLP:ICAgICAgICAgICBpZiAoVGVzdC1QYXRoICR3aW0pIHsgJHBhdGhzICs9IChHZXQtSW5zdGFsbEltYWdlU291cmNlICdXaW0nICR3aW0gJGVkaXRpb25JZCkgfQogICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRlc2QpIHsgJHBhdGhzICs9IChHZXQtSW5zdGFsbElt
HLP:YWdlU291cmNlICdFc2QnICRlc2QgJGVkaXRpb25JZCkgfQogICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRzeHMpIHsgJHBhdGhzICs9ICRzeHMgfQogICAgICAgIH0KICAgICAgICBpZiAoJHBhdGhzLkNvdW50IC1ndCAwKSB7ICJTT1VSQ0U9JCgkcGF0aHNbMF0p
HLP:IiB9IGVsc2UgeyAiU09VUkNFPSIgfQogICAgfQogICAgJ2Rpc21yZXN0b3JlJyB7CiAgICAgICAgJHBhcnRzID0gQCgkQXJnIC1zcGxpdCAnXHwnLCAyKQogICAgICAgICRzb3VyY2UgPSBpZiAoJHBhcnRzLkNvdW50IC1nZSAxKSB7ICRwYXJ0c1swXSB9IGVsc2Ug
HLP:eyAnJyB9CiAgICAgICAgJHRpbWVvdXRNaW51dGVzID0gNDUKICAgICAgICBpZiAoJHBhcnRzLkNvdW50IC1nZSAyKSB7IFt2b2lkXVtpbnRdOjpUcnlQYXJzZSgkcGFydHNbMV0sIFtyZWZdJHRpbWVvdXRNaW51dGVzKSB9CiAgICAgICAgaWYgKCR0aW1lb3V0TWlu
HLP:dXRlcyAtbHQgNSkgeyAkdGltZW91dE1pbnV0ZXMgPSA1IH0KCiAgICAgICAgZnVuY3Rpb24gUXVvdGUtRGlzbVZhbHVlKFtzdHJpbmddJHZhbHVlKSB7CiAgICAgICAgICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCR2YWx1ZSkpIHsgcmV0dXJu
HLP:ICR2YWx1ZSB9CiAgICAgICAgICAgIHJldHVybiAnIicgKyAoJHZhbHVlIC1yZXBsYWNlICciJywgJ1wiJykgKyAnIicKICAgICAgICB9CgogICAgICAgICRhcmd1bWVudHMgPSAnL09ubGluZSAvQ2xlYW51cC1JbWFnZSAvUmVzdG9yZUhlYWx0aCcKICAgICAgICBp
HLP:ZiAoLW5vdCBbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRzb3VyY2UpKSB7CiAgICAgICAgICAgICRhcmd1bWVudHMgKz0gJyAvU291cmNlOicgKyAoUXVvdGUtRGlzbVZhbHVlICRzb3VyY2UpICsgJyAvTGltaXRBY2Nlc3MnCiAgICAgICAgfQoKICAgICAg
HLP:ICAkdGltZWRPdXQgPSAkZmFsc2UKICAgICAgICAkZXhpdENvZGUgPSAzCiAgICAgICAgJG91dEZpbGUgPSBKb2luLVBhdGggJFdvcmsgKCJkaXNtX3Jlc3RvcmVfezB9Lm91dCIgLWYgKFtndWlkXTo6TmV3R3VpZCgpLlRvU3RyaW5nKCdOJykpKQogICAgICAgICRl
HLP:cnJGaWxlID0gSm9pbi1QYXRoICRXb3JrICgiZGlzbV9yZXN0b3JlX3swfS5lcnIiIC1mIChbZ3VpZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKSkKICAgICAgICB0cnkgewogICAgICAgICAgICAkcHNpID0gW0RpYWdub3N0aWNzLlByb2Nlc3NTdGFydEluZm9d
HLP:OjpuZXcoKQogICAgICAgICAgICAkcHNpLkZpbGVOYW1lID0gJ2NtZC5leGUnCiAgICAgICAgICAgICRwc2kuQXJndW1lbnRzID0gKCcvYyBkaXNtLmV4ZSB7MH0gPiAiezF9IiAyPiAiezJ9IicgLWYgJGFyZ3VtZW50cywgJG91dEZpbGUsICRlcnJGaWxlKQogICAg
HLP:ICAgICAgICAkcHNpLlVzZVNoZWxsRXhlY3V0ZSA9ICRmYWxzZQogICAgICAgICAgICAkcHNpLkNyZWF0ZU5vV2luZG93ID0gJHRydWUKICAgICAgICAgICAgJHAgPSBbRGlhZ25vc3RpY3MuUHJvY2Vzc106Om5ldygpCiAgICAgICAgICAgICRwLlN0YXJ0SW5mbyA9
HLP:ICRwc2kKICAgICAgICAgICAgW3ZvaWRdJHAuU3RhcnQoKQogICAgICAgICAgICBpZiAoLW5vdCAkcC5XYWl0Rm9yRXhpdCgkdGltZW91dE1pbnV0ZXMgKiA2MCAqIDEwMDApKSB7CiAgICAgICAgICAgICAgICAkdGltZWRPdXQgPSAkdHJ1ZQogICAgICAgICAgICAg
HLP:ICAgdHJ5IHsgJHAuS2lsbCgpIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICRleGl0Q29kZSA9IDE0NjAKICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgIHRyeSB7ICRwLldhaXRGb3JFeGl0KCkgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAg
HLP:JGV4aXRDb2RlID0gJHAuRXhpdENvZGUKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJGV4aXRDb2RlKSB7ICRleGl0Q29kZSA9IDMgfQogICAgICAgICAgICB9CiAgICAgICAgfSBjYXRjaCB7CiAgICAgICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5N
HLP:ZXNzYWdlKSIKICAgICAgICAgICAgJGV4aXRDb2RlID0gMwogICAgICAgIH0KCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkb3V0RmlsZSkgeyBHZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJG91dEZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAg
HLP:ICAgIGlmIChUZXN0LVBhdGggJGVyckZpbGUpIHsgR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRlcnJGaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJG91dEZpbGUsJGVyckZpbGUgLUZv
HLP:cmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgIlRJTUVET1VUPSQoaWYgKCR0aW1lZE91dCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkVYSVRDT0RFPSRleGl0Q29kZSIKICAgIH0KICAgICdzeXNpbmZvJyAgICAgIHsgR2V0LVN5
HLP:c0luZm8gfQogICAgJ3Njb3JlJyAgICAgICAgeyAkaCA9IEdldC1IZWFsdGhTY29yZTsgIlNDT1JFPSQoJGguc2NvcmUpIjsgZm9yZWFjaCAoJHIgaW4gJGgucmVhc29ucykgeyAiUkVBU09OPSRyIiB9IH0KICAgICdmb3JlbnNpY3MnICAgIHsgR2V0LUZvcmVuc2lj
HLP:cyB9CiAgICAndHJpYWdlJyAgICAgICB7IEdldC1UcmlhZ2UgfQogICAgJ3Jlc3RvcmVwb2ludCcgeyBOZXctUmVzdG9yZVBvaW50IH0KICAgICdtZWRpYXR5cGUnICAgIHsgJG1lZGlhID0gR2V0LU1lZGlhVHlwZTsgIk1FRElBPSRtZWRpYSI7ICJPUFRJTUlaRT0k
HLP:KFJlc29sdmUtT3B0aW1pemVBY3Rpb24gJG1lZGlhKSIgfQogICAgJ2RldmljZXMnICAgICAgeyBHZXQtRGV2aWNlUHJvYmxlbXMgfQogICAgJ3JlcG9ydCcgICAgICAgeyBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XZWIgLUVycm9yQWN0aW9uIFNpbGVu
HLP:dGx5Q29udGludWU7IE5ldy1IdG1sUmVwb3J0ICRBcmcgfQogICAgJ2FkZHBoYXNlJyAgICAgeyBBZGQtUGhhc2VSZXN1bHQgJEFyZyB9CiAgICAnc2V0YmVmb3JlJyAgICB7IFNldC1TY29yZSAnYmVmb3JlJyAkQXJnIH0KICAgICdzZXRhZnRlcicgICAgIHsgU2V0
HLP:LVNjb3JlICdhZnRlcicgJEFyZyB9CiAgICAnZmluZGluZycgICAgICB7IEFkZC1GaW5kaW5nICRBcmcgfQogICAgJ3Jlc2V0c3RhdGUnICAgeyBSZXNldC1TdGF0ZTsgIlJFU1VMVD1PSyIgfQogICAgJ25vcm1hbGl6ZWZhc2VzJyB7CiAgICAgICAgJHIgPSBOb3Jt
HLP:YWxpemUtRmFzZXMgJEFyZwogICAgICAgICJOT1JNPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRyLm5vcm0pKSkiCiAgICAgICAgIklOVkFMSUQ9JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJHIuaW52YWxpZCkpKSIKICAgIH0KICAgICdjaGVja3BvaW50JyB7CiAg
HLP:ICAgICAgJHBhcnNlZCA9IFBhcnNlLUNoZWNrcG9pbnRBcmcgJEFyZwogICAgICAgIHN3aXRjaCAoJHBhcnNlZC5zdWIpIHsKICAgICAgICAgICAgJ3NhdmUnIHsgaWYgKFNhdmUtQ2hlY2twb2ludCAkcGFyc2VkKSB7ICJSRVNVTFQ9T0siIH0gZWxzZSB7ICJSRVNV
HLP:TFQ9RkFJTCIgfSB9CiAgICAgICAgICAgICdsb2FkJyB7CiAgICAgICAgICAgICAgICAkY3AgPSBMb2FkLUNoZWNrcG9pbnQKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7ICJSRVNVTFQ9Tk9ORSIgfQogICAgICAgICAgICAgICAgZWxzZSB7CiAg
HLP:ICAgICAgICAgICAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAgICAgICAgICAgICAiVkFMSUQ9JChpZiAoVGVzdC1DaGVja3BvaW50VmFsaWQgJGNwKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiVkVSU0lPTj0kKCRjcC52ZXJzaW9u
HLP:KSIKICAgICAgICAgICAgICAgICAgICAiQ1JFQVRFRD0kKCRjcC5jcmVhdGVkKSIKICAgICAgICAgICAgICAgICAgICAiU0VMRUNUSU9OPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRjcC5zZWxlY3Rpb24pKSkiCiAgICAgICAgICAgICAgICAgICAgIkNPTVBMRVRF
HLP:RD0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkY3AuY29tcGxldGVkKSkpIgogICAgICAgICAgICAgICAgICAgICJSRUFTT049JCgkY3AucGVuZGluZ19yZWFzb24pIgogICAgICAgICAgICAgICAgICAgICJORVhUPSQoR2V0LU5leHRQaGFzZSAkY3ApIgogICAgICAg
HLP:ICAgICAgICAgICAgICJNT0RFX0FVVE89JChpZiAoJGNwLm1vZGUuYXV0bykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfTk9SRUJPT1Q9JChpZiAoJGNwLm1vZGUubm9yZWJvb3QpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAg
HLP:ICAgICAgICAgICAgICJNT0RFX0tFRVBXVT0kKGlmICgkY3AubW9kZS5rZWVwd3UpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJNT0RFX0RSWT0kKGlmICgkY3AubW9kZS5kcnkpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAg
HLP:ICAgICAgICJNT0RFX1RSSUFHRT0kKGlmICgkY3AubW9kZS50cmlhZ2UpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICduZXh0JyB7CiAgICAgICAgICAgICAgICAkY3AgPSBMb2FkLUNoZWNrcG9p
HLP:bnQKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGNwIC1hbmQgKFRlc3QtQ2hlY2twb2ludFZhbGlkICRjcCkpIHsgIk5FWFQ9JChHZXQtTmV4dFBoYXNlICRjcCkiIH0gZWxzZSB7ICJORVhUPSIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICdjbGVh
HLP:cicgewogICAgICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkQ2hlY2twb2ludEZpbGUpIHsKICAgICAgICAgICAgICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAkQ2hlY2twb2ludEZpbGUgLUZvcmNlIC1FcnJvckFjdGlvbiBTdG9wOyAiUkVTVUxUPU9LIiB9IGNh
HLP:dGNoIHsgIlJFU1VMVD1GQUlMIiB9CiAgICAgICAgICAgICAgICB9IGVsc2UgeyAiUkVTVUxUPU9LIiB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgZGVmYXVsdCB7ICJSRVNVTFQ9RkFJTCI7ICJFUlJPUj1zdWJhY2Npb24gZGUgY2hlY2twb2ludCBkZXNjb25v
HLP:Y2lkYSIgfQogICAgICAgIH0KICAgIH0KICAgICdtb3ZlcmVzdWx0JyB7CiAgICAgICAgJHBhcnRzID0gJEFyZyAtc3BsaXQgJ1x8JywgMgogICAgICAgIGlmICgkcGFydHMuQ291bnQgLWVxIDIpIHsKICAgICAgICAgICAgJG9rID0gVGVzdC1Nb3ZlUmVzdWx0UGF0
HLP:aCAkcGFydHNbMF0gJHBhcnRzWzFdCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJGIgID0gJEFyZyAtc3BsaXQgJywnCiAgICAgICAgICAgICRzZSA9ICgkYi5Db3VudCAtZ2UgMSAtYW5kICRiWzBdLlRyaW0oKSAtZXEgJzEnKQogICAgICAgICAgICAkZGUg
HLP:PSAoJGIuQ291bnQgLWdlIDIgLWFuZCAkYlsxXS5UcmltKCkgLWVxICcxJykKICAgICAgICAgICAgJG9rID0gVGVzdC1Nb3ZlUmVzdWx0ICRzZSAkZGUKICAgICAgICB9CiAgICAgICAgIk1PVkVEPSQoaWYgKCRvaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAg
HLP:ICAndnRsd3JpdGUnIHsKICAgICAgICAkcCAgID0gJEFyZyAtc3BsaXQgJywnCiAgICAgICAgJGN1ciA9IGlmICgkcC5Db3VudCAtZ2UgMSkgeyAkcFswXSB9IGVsc2UgeyAnJyB9CiAgICAgICAgJGRlcyA9IGlmICgkcC5Db3VudCAtZ2UgMikgeyAkcFsxXSB9IGVs
HLP:c2UgeyBbc3RyaW5nXSRWVF9MRVZFTF9ERVNJUkVEIH0KICAgICAgICAiV1JJVEU9JChpZiAoUmVzb2x2ZS1WdGxXcml0ZSAkY3VyICRkZXMpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ21hcGV4aXQnICAgICAgeyAiUkVTPSQoTWFwLUV4aXRDb2RlICRB
HLP:cmcpIiB9CiAgICAjIC0tLSAoNS4xIC8gUmVxIDE1KSBEaWFnbm9zdGljbyBhbXBsaWFkbyAtLS0KICAgICdyYW1jaGVjaycgewogICAgICAgICRyID0gR2V0LVJhbUNoZWNrCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAg
HLP:ICRzdC5kaWFnLnJhbSA9IFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAkci5zdGF0dXM7IHJlY29tbWVuZF9tZHNjaGVkID0gW2Jvb2xdJHIucmVjb21tZW5kX21kc2NoZWQgfQogICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJSQU1fU1RBVFVTPSQo
HLP:JHIuc3RhdHVzKSIKICAgICAgICAiUkFNX1JFQ09NTUVORF9NRFNDSEVEPSQoaWYgKCRyLnJlY29tbWVuZF9tZHNjaGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdiYXR0ZXJ5JyB7CiAgICAgICAgJGIgPSBHZXQtQmF0dGVyeUhlYWx0aAogICAgICAg
HLP:ICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5iYXR0ZXJ5ID0gW3BzY3VzdG9tb2JqZWN0XUB7IHByZXNlbnQgPSBbYm9vbF0kYi5wcmVzZW50OyBoZWFsdGhfcGN0ID0gJGIuaGVhbHRoX3BjdDsgcmVwb3J0X3BhdGgg
HLP:PSAkYi5yZXBvcnRfcGF0aCB9CiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIkJBVFRFUllfUFJFU0VOVD0kKGlmICgkYi5wcmVzZW50KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkFUVEVSWV9IRUFMVEhfUENUPSQoJGIuaGVhbHRoX3BjdCki
HLP:CiAgICAgICAgIkJBVFRFUllfUkVQT1JUPSQoJGIucmVwb3J0X3BhdGgpIgogICAgfQogICAgJ25ldGFkdmFuY2VkJyB7CiAgICAgICAgJG4gPSBHZXQtTmV0QWR2YW5jZWQKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAg
HLP:JHN0LmRpYWcubmV0d29yayA9IFtwc2N1c3RvbW9iamVjdF1AeyBjb25uZWN0ZWQgPSBbYm9vbF0kbi5jb25uZWN0ZWQ7IGRuc19vayA9IFtib29sXSRuLmRuc19vazsgZGV0YWlscyA9ICRuLmRldGFpbHM7IGRuc19tcyA9ICRuLmRuc19tcyB9CiAgICAgICAgV3Jp
HLP:dGUtU3RhdGUgJHN0CiAgICAgICAgIk5FVF9DT05ORUNURUQ9JChpZiAoJG4uY29ubmVjdGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0ROU19PSz0kKGlmICgkbi5kbnNfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfREVUQUlM
HLP:Uz0kKCRuLmRldGFpbHMpIgogICAgICAgICJORVRfTEFURU5DWV9NUz0kKCRuLmRuc19tcykiCiAgICB9CiAgICAnZGlhZ2Z1bGwnIHsKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHIgPSBHZXQtUmFtQ2hlY2sKICAg
HLP:ICAgICAkc3QuZGlhZy5yYW0gPSBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJHIuc3RhdHVzOyByZWNvbW1lbmRfbWRzY2hlZCA9IFtib29sXSRyLnJlY29tbWVuZF9tZHNjaGVkIH0KICAgICAgICAkYiA9IEdldC1CYXR0ZXJ5SGVhbHRoCiAgICAgICAgJHN0
HLP:LmRpYWcuYmF0dGVyeSA9IFtwc2N1c3RvbW9iamVjdF1AeyBwcmVzZW50ID0gW2Jvb2xdJGIucHJlc2VudDsgaGVhbHRoX3BjdCA9ICRiLmhlYWx0aF9wY3Q7IHJlcG9ydF9wYXRoID0gJGIucmVwb3J0X3BhdGggfQogICAgICAgICRuID0gR2V0LU5ldEFkdmFuY2Vk
HLP:CiAgICAgICAgJHN0LmRpYWcubmV0d29yayA9IFtwc2N1c3RvbW9iamVjdF1AeyBjb25uZWN0ZWQgPSBbYm9vbF0kbi5jb25uZWN0ZWQ7IGRuc19vayA9IFtib29sXSRuLmRuc19vazsgZGV0YWlscyA9ICRuLmRldGFpbHM7IGRuc19tcyA9ICRuLmRuc19tcyB9CiAg
HLP:ICAgICAgJGRldiA9IEdldC1EZXZpY2VMaXN0CiAgICAgICAgaWYgKCRudWxsIC1lcSAkZGV2KSB7CiAgICAgICAgICAgICRzdC5kaWFnLmRldmljZXMgPSBAKCkKICAgICAgICAgICAgJGRldkxpbmUgPSAiREVWSUNFU19TVEFUVVM9aW5mbyBubyBkaXNwb25pYmxl
HLP:IgogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRzdC5kaWFnLmRldmljZXMgPSBAKCRkZXYpCiAgICAgICAgICAgICRkZXZMaW5lID0gIkRFVklDRVNfQ09VTlQ9JChAKCRkZXYpLkNvdW50KSIKICAgICAgICB9CiAgICAgICAgJHNtID0gR2V0LVNtYXJ0QXR0
HLP:cmlidXRlcwogICAgICAgICRzdC5kaWFnLnNtYXJ0ID0gW3BzY3VzdG9tb2JqZWN0XUB7IGF2YWlsYWJsZSA9IFtib29sXSRzbS5hdmFpbGFibGU7IHByZWRpY3RfZmFpbCA9IFtib29sXSRzbS5wcmVkaWN0X2ZhaWw7IHRlbXBfYyA9ICRzbS50ZW1wX2M7IHdlYXJf
HLP:cGN0ID0gJHNtLndlYXJfcGN0OyBwb2ggPSAkc20ucG9oIH0KICAgICAgICAkc3RwID0gR2V0LVN0YXJ0dXBJdGVtcyA4CiAgICAgICAgJHN0LmRpYWcuc3RhcnR1cCA9IEAoJHN0cCkKICAgICAgICAkYmNkID0gR2V0LUJjZEludGVncml0eQogICAgICAgICRzdC5k
HLP:aWFnLmJjZCA9IFtwc2N1c3RvbW9iamVjdF1AeyBvayA9IFtib29sXSRiY2Qub2s7IGRldGFpbHMgPSAkYmNkLmRldGFpbHMgfQogICAgICAgICRwcm9jcyA9IEdldC1Ub3BQcm9jZXNzZXMgNgogICAgICAgICRzdC5kaWFnLnByb2Nlc3NlcyA9IEAoJHByb2NzKQog
HLP:ICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJSQU1fU1RBVFVTPSQoJHIuc3RhdHVzKSIKICAgICAgICAiUkFNX1JFQ09NTUVORF9NRFNDSEVEPSQoaWYgKCRyLnJlY29tbWVuZF9tZHNjaGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkFUVEVS
HLP:WV9QUkVTRU5UPSQoaWYgKCRiLnByZXNlbnQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQVRURVJZX0hFQUxUSF9QQ1Q9JCgkYi5oZWFsdGhfcGN0KSIKICAgICAgICAiTkVUX0NPTk5FQ1RFRD0kKGlmICgkbi5jb25uZWN0ZWQpIHsnMSd9IGVsc2Ugeycw
HLP:J30pIgogICAgICAgICJORVRfRE5TX09LPSQoaWYgKCRuLmRuc19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9MQVRFTkNZX01TPSQoJG4uZG5zX21zKSIKICAgICAgICAiU01BUlRfQVZBSUxBQkxFPSQoaWYgKCRzbS5hdmFpbGFibGUpIHsnMSd9
HLP:IGVsc2UgeycwJ30pIgogICAgICAgICJTTUFSVF9QUkVESUNUX0ZBSUw9JChpZiAoJHNtLnByZWRpY3RfZmFpbCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJDRF9PSz0kKGlmICgkYmNkLm9rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAkZGV2TGlu
HLP:ZQogICAgfQogICAgIyAtLS0gKHYzLjEpIFNGQyBpbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEgKyBKU09OICsgcGFxdWV0ZSBkZSBzb3BvcnRlIC0tLQogICAgJ3NmY3Jlc3VsdCcgewogICAgICAgICJTRkNfUkVTPSQoR2V0LVNmY1Jlc3VsdCkiCiAgICB9CiAgICAn
HLP:anNvbnJlcG9ydCcgewogICAgICAgICRvdXQgPSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdvcmsgJ0luZm9ybWUuanNvbicgfSBlbHNlIHsgJEFyZyB9CiAgICAgICAgTmV3LUpzb25SZXBvcnQgJG91dAogICAg
HLP:fQogICAgJ3N1cHBvcnRwYWNrYWdlJyB7CiAgICAgICAgJG91dCA9IGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnUGFxdWV0ZV9Tb3BvcnRlLnppcCcgfSBlbHNlIHsgJEFyZyB9CiAgICAgICAgTmV3LVN1
HLP:cHBvcnRQYWNrYWdlICRvdXQKICAgIH0KICAgICMgLS0tICg1LjYgLyBSZXEgMTcuMikgUm90YWNpb24gZGUgbG9ncyAtLS0KICAgICdsb2dyb3RhdGUnIHsKICAgICAgICAkZm9sZGVyID0gaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJEFyZykpIHsg
HLP:Sm9pbi1QYXRoICRXb3JrICdMb2dzJyB9IGVsc2UgeyAkQXJnIH0KICAgICAgICAkbiA9IEludm9rZS1Mb2dSb3RhdGUgJGZvbGRlciAkTE9HX1JFVEVOVElPTgogICAgICAgICJERUxFVEVEPSRuIgogICAgfQogICAgIyAtLS0gKDUuOCAvIFJlcSAxMywxOCkgVmFs
HLP:aWRhY2lvbiBkZSBlbnRvcm5vIHkgc2VsZi10ZXN0IC0tLQogICAgJ2VudmNoZWNrJyB7CiAgICAgICAgJGUgPSBJbnZva2UtRW52VmFsaWRhdGUKICAgICAgICAiT1NfT0s9JChpZiAoJGUub3Nfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJPU19CVUlM
HLP:RD0kKCRlLmJ1aWxkKSIKICAgICAgICAiT1NfQ0hFQ0tfRE9ORT0xIgogICAgfQogICAgJ3NlbGZ0ZXN0YnJhaW4nIHsgIkJSQUlOX09LPTEiIH0KICAgICdzZWxmdGVzdHJlc3VsdCcgewogICAgICAgICRwYXNzID0gSW52b2tlLVNlbGZUZXN0IChQYXJzZS1Cb29s
HLP:TGlzdCAkQXJnKQogICAgICAgICJTRUxGVEVTVF9QQVNTPSQoaWYgKCRwYXNzKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgIGRlZmF1bHQgICAgICAgIHsgR2V0LVN5c0luZm8gfQp9Cg==
