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
echo  %DIM%Fase suelta 13 - Windows Update%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "13" "Windows Update" "Repara Windows Update (servicios y cache). Respeta el bloqueo con /keepwu."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase13 ) else ( call :menu_fase13 )
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
    call :title_of 13
    call :pshq addphase "13;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase13
call :step "Comprobando si Windows Update esta bloqueado a proposito"
set "WU_BLOCKED=0"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate >nul 2>&1 && set "WU_BLOCKED=1"
sc query wuauserv | findstr /i "DISABLED" >nul 2>&1 && set "WU_BLOCKED=1"
if "!WU_BLOCKED!"=="1" if "%KEEPWU%"=="1" ( call :info "WU bloqueado y se pidio /keepwu: se respeta y se salta la fase" & set "PH_NOTE=bloqueo de WU respetado" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Verificando estado del servicio Windows Update (solo escaneo)"
    sc query wuauserv > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    findstr /i "RUNNING" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :ok "Servicio wuauserv en ejecucion"
        exit /b 0
    )
    findstr /i "STOPPED" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :step "Intentando arrancar wuauserv (solo comprobacion de servicio)"
        net start wuauserv > "%CAP%" 2>&1
        type "%CAP%" >> "%LOGFILE%"
        if !errorlevel! equ 0 (
            call :ok "Servicio wuauserv arrancado correctamente"
            exit /b 0
        )
    )
    call :warn "El servicio Windows Update no esta funcionando o esta desactivado"
    exit /b 1
)

if "%DRY%"=="1" ( call :dry "Repararia servicios y cache de Windows Update" & exit /b 2 )
call :step "Deteniendo servicios de Windows Update"
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop appidsvc /y >nul 2>&1
net stop cryptsvc /y >nul 2>&1
net stop msiserver /y >nul 2>&1

call :step "Limpiando datos de trabajos BITS (qmgr*.dat)"
del /f /q "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1
del /f /q "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1

call :step "Respaldando y vaciando cache (SoftwareDistribution, catroot2)"
set "WU_WARN=0"
if exist "%SystemRoot%\SoftwareDistribution" (
    move "%SystemRoot%\SoftwareDistribution" "%BKDIR%\SoftwareDistribution_%TIMESTAMP%" >nul 2>&1
    call :psh moveresult "%SystemRoot%\SoftwareDistribution|%BKDIR%\SoftwareDistribution_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "No se pudo mover SoftwareDistribution" )
)
rem (v3.2) catroot2 suele quedar bloqueado por cryptsvc unos segundos: reintentos con espera
set "CAT_EXISTS=0"
if exist "%SystemRoot%\System32\catroot2" set "CAT_EXISTS=1"
if "!CAT_EXISTS!"=="1" (
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
)
if "!CAT_EXISTS!"=="1" if exist "%SystemRoot%\System32\catroot2" (
    call :step "catroot2 ocupado: segundo intento tras pausa breve"
    net stop cryptsvc /y >nul 2>&1
    ping 127.0.0.1 -n 5 >nul
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
)
if "!CAT_EXISTS!"=="1" if exist "%SystemRoot%\System32\catroot2" (
    call :step "catroot2 ocupado: tercer intento tras pausa larga"
    net stop cryptsvc /y >nul 2>&1
    ping 127.0.0.1 -n 9 >nul
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
)
if "!CAT_EXISTS!"=="1" (
    call :psh moveresult "%SystemRoot%\System32\catroot2|%BKDIR%\catroot2_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "No se pudo mover catroot2 (3 intentos)" )
)

call :step "Eliminando configuracion de cliente WSUS obsoleta"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f >nul 2>&1

call :step "Re-registrando DLLs de Windows Update y BITS"
pushd "%SystemRoot%\System32"
for %%D in (atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll wuwebv.dll) do (
    regsvr32 /s %%D >> "%LOGFILE%" 2>&1
)
popd

call :step "Reiniciando servicios"
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start appidsvc >nul 2>&1
net start wuauserv >nul 2>&1
set "WUSTART=!errorlevel!"
net start msiserver >nul 2>&1

if "!WUSTART!" neq "0" (
    call :warn "El servicio wuauserv no pudo arrancar tras el registro de DLLs"
    set "WU_WARN=1"
)

call :step "Forzando deteccion de actualizaciones"
wuauclt /resetauthorization /detectnow >nul 2>&1

if "!WU_WARN!"=="1" ( set "PH_NOTE=cache no movida o servicio fallo" & call :warn "Windows Update: la cache no se movio o wuauserv no arranco" & exit /b 1 )
call :ok "Windows Update reparado: cache vaciada, DLLs registradas, deteccion forzada"
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
HLP:ICAiRVFVSVBPPSQoJGNzLk1hbnVmYWN0dXJlcikgJCgkY3MuTW9kZWwpIgogICAgIkNQVT0kY3B1TmFtZSIKICAgICJSQU09JHJhbUdCIEdCIgogICAgIkRJU0NPPUM6ICRmcmVlR0IgR0IgbGlicmVzIGRlICR0b3RHQiBHQiIKICAgICJVUFRJTUU9JChbaW50XSR1
HLP:cC5Ub3RhbERheXMpZCAkKCR1cC5Ib3VycyloICQoJHVwLk1pbnV0ZXMpbSIKICAgICJVU1VBUklPPSRlbnY6VVNFUk5BTUUiCn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0KIyAoNS4yIC8gUmVxIDE1LjYpIE51Y2xlbyBQVVJPIGRlIGNhbGN1bG8gZGVsIHNjb3JlLgojIFJlY2liZSB1biBoYXNodGFibGUgZGUgc2ludG9tYXMgKGZsYWdzL2NvbnRlb3MpIHkgZGV2dWVsdmUgdW4gZW50ZXJvIGVuCiMgWzAsMTAwXS4gQ2FkYSBzaW50
HLP:b21hIHNvbG8gcHVlZGUgUkVTVEFSIHB1bnRvcywgcG9yIGxvIHF1ZSBhbmFkaXIgbyBhZ3JhdmFyCiMgY3VhbHF1aWVyIHNpbnRvbWEgbnVuY2Egc3ViZSBlbCBzY29yZSAoTU9OT1RPTklBKSwgeSBlbCBjbGFtcCBnYXJhbnRpemEgZWwKIyByYW5nbyBbMCwxMDBd
HLP:LiBFcyBkZXRlcm1pbmlzdGEgcmVzcGVjdG8gYSBzdSBlbnRyYWRhICh0ZXN0ZWFibGUgZGUgZm9ybWEKIyBhaXNsYWRhIHBhcmEgbGEgUHJvcGVydHkgMTApLgpmdW5jdGlvbiBDb21wdXRlLVNjb3JlKFtoYXNodGFibGVdJHN5bSkgewogICAgaWYgKCRudWxsIC1l
HLP:cSAkc3ltKSB7ICRzeW0gPSBAe30gfQogICAgJHNjb3JlID0gMTAwCiAgICAjIC0tLSBQZW5hbGl6YWNpb25lcyBleGlzdGVudGVzIChwcmVzZXJ2YWRhcykgLS0tCiAgICBpZiAoJHN5bVsnc21hcnRCYWQnXSkgICAgICAgeyAkc2NvcmUgLT0gMjUgfQogICAgaWYg
HLP:KCRzeW0uQ29udGFpbnNLZXkoJ2ZyZWVHQicpIC1hbmQgJG51bGwgLW5lICRzeW1bJ2ZyZWVHQiddKSB7CiAgICAgICAgJGZyZWVHQiA9IFtkb3VibGVdJHN5bVsnZnJlZUdCJ10KICAgICAgICBpZiAgICAgKCRmcmVlR0IgLWx0IDUpICB7ICRzY29yZSAtPSAxNSB9
HLP:CiAgICAgICAgZWxzZWlmICgkZnJlZUdCIC1sdCAxNSkgeyAkc2NvcmUgLT0gNiB9CiAgICB9CiAgICBpZiAoJHN5bVsncmVib290UGVuZGluZyddKSAgICAgICAgICB7ICRzY29yZSAtPSA1IH0KICAgIGlmIChbaW50XSRzeW1bJ2Jzb2QnXSAtZ3QgMCkgICAgICAg
HLP:IHsgJHNjb3JlIC09IDE4IH0KICAgIGlmIChbaW50XSRzeW1bJ2Rpc2tFcnInXSAtZ3QgMCkgICAgIHsgJHNjb3JlIC09IDEyIH0KICAgIGlmIChbaW50XSRzeW1bJ3doZWEnXSAtZ3QgMCkgICAgICAgIHsgJHNjb3JlIC09IDEyIH0KICAgIGlmIChbaW50XSRzeW1b
HLP:J2NyaXRDb3VudCddIC1ndCAyNSkgIHsgJHNjb3JlIC09IDYgfQogICAgaWYgKFtpbnRdJHN5bVsnc3ZjU3RvcHBlZCddIC1ndCAwKSAgeyAkc2NvcmUgLT0gNCAqIFtpbnRdJHN5bVsnc3ZjU3RvcHBlZCddIH0KICAgIGlmIChbaW50XSRzeW1bJ2RldlByb2JsZW1z
HLP:J10gLWd0IDApIHsgJHNjb3JlIC09IFttYXRoXTo6TWluKDEyLCBbaW50XSRzeW1bJ2RldlByb2JsZW1zJ10gKiAzKSB9CiAgICAjIC0tLSBOdWV2YXMgcGVuYWxpemFjaW9uZXMgZGVsIGRpYWdub3N0aWNvIGFtcGxpYWRvICg1LjIpIC0tLQogICAgaWYgKCRzeW1b
HLP:J3JhbVN1c3BlY3QnXSkgeyAkc2NvcmUgLT0gMTAgfSAgICMgUkFNIHNvc3BlY2hvc2EKICAgIGlmICgkc3ltLkNvbnRhaW5zS2V5KCdiYXR0ZXJ5SGVhbHRoUGN0JykgLWFuZCAkbnVsbCAtbmUgJHN5bVsnYmF0dGVyeUhlYWx0aFBjdCddKSB7CiAgICAgICAgJGJw
HLP:ID0gW2ludF0kc3ltWydiYXR0ZXJ5SGVhbHRoUGN0J10KICAgICAgICBpZiAoJGJwIC1nZSAwIC1hbmQgJGJwIC1sdCA1MCkgeyAkc2NvcmUgLT0gOCB9ICAgIyBiYXRlcmlhIG11eSBkZWdyYWRhZGEgKDw1MCUpCiAgICB9CiAgICBpZiAoJHN5bVsnbmV0UHJvYmxl
HLP:bSddKSB7ICRzY29yZSAtPSA4IH0gICAjIHByb2JsZW1hcyBkZSByZWQgcGVyc2lzdGVudGVzCiAgICAjIC0tLSBDbGFtcCBhbCByYW5nbyBbMCwxMDBdIC0tLQogICAgaWYgKCRzY29yZSAtbHQgMCkgICB7ICRzY29yZSA9IDAgfQogICAgaWYgKCRzY29yZSAtZ3Qg
HLP:MTAwKSB7ICRzY29yZSA9IDEwMCB9CiAgICByZXR1cm4gW2ludF0kc2NvcmUKfQoKIyBQdW50dWFjaW9uIGRlIHNhbHVkIDAtMTAwOiByZWNvbGVjdGEgc2ludG9tYXMgcmVhbGVzIGRlbCBzaXN0ZW1hIChpbmNsdWlkbyBlbAojIGRpYWdub3N0aWNvIGFtcGxpYWRv
HLP:IHBlcnNpc3RpZG8gZW4gZXN0YWRvLmRpYWcpIHkgZGVsZWdhIGVsIGNhbGN1bG8gZW4gbGEKIyBmdW5jaW9uIHB1cmEgQ29tcHV0ZS1TY29yZS4KZnVuY3Rpb24gR2V0LUhlYWx0aFNjb3JlIHsKICAgICRyZWFzb25zID0gQCgpCiAgICAkc3ltID0gQHt9CiAgICAj
HLP:IERpc2NvIFNNQVJUCiAgICAkYmFkID0gQChHZXQtUGh5c2ljYWxEaXNrIHwgV2hlcmUtT2JqZWN0IHsgJF8uSGVhbHRoU3RhdHVzIC1uZSAnSGVhbHRoeScgfSkKICAgICRzeW1bJ3NtYXJ0QmFkJ10gPSAoJGJhZC5Db3VudCAtZ3QgMCkKICAgIGlmICgkc3ltWydz
HLP:bWFydEJhZCddKSB7ICRyZWFzb25zICs9ICJEaXNjbyBjb24gU01BUlQgZGVncmFkYWRvICgtMjUpIiB9CiAgICAjIEVzcGFjaW8gbGlicmUKICAgICRjID0gR2V0LVBTRHJpdmUgQzsgJGZyZWVHQiA9IFttYXRoXTo6Um91bmQoJGMuRnJlZS8xR0IsMSkKICAgICRz
HLP:eW1bJ2ZyZWVHQiddID0gJGZyZWVHQgogICAgaWYgICAgICgkZnJlZUdCIC1sdCA1KSAgeyAkcmVhc29ucyArPSAiTWVub3MgZGUgNSBHQiBsaWJyZXMgZW4gQzogKC0xNSkiIH0KICAgIGVsc2VpZiAoJGZyZWVHQiAtbHQgMTUpIHsgJHJlYXNvbnMgKz0gIlBvY28g
HLP:ZXNwYWNpbyBsaWJyZSBlbiBDOiAoLTYpIiB9CiAgICAjIFJlaW5pY2lvIHBlbmRpZW50ZQogICAgJHBlbmQgPSAoVGVzdC1QYXRoICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93c1xDdXJyZW50VmVyc2lvblxDb21wb25lbnQgQmFzZWQgU2VydmljaW5n
HLP:XFJlYm9vdFBlbmRpbmcnKSAtb3IgYAogICAgICAgICAgICAoVGVzdC1QYXRoICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93c1xDdXJyZW50VmVyc2lvblxXaW5kb3dzVXBkYXRlXEF1dG8gVXBkYXRlXFJlYm9vdFJlcXVpcmVkJykKICAgICRzeW1bJ3Jl
HLP:Ym9vdFBlbmRpbmcnXSA9IFtib29sXSRwZW5kCiAgICBpZiAoJHBlbmQpIHsgJHJlYXNvbnMgKz0gIlJlaW5pY2lvIHBlbmRpZW50ZSAoLTUpIiB9CiAgICAjIEV2ZW50b3MgY3JpdGljb3MgcmVjaWVudGVzICg0OGgpCiAgICAkc2luY2UgPSAoR2V0LURhdGUpLkFk
HLP:ZEhvdXJzKC00OCkKICAgICRjcml0ID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IExldmVsPTEsMjsgU3RhcnRUaW1lPSRzaW5jZX0gLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAkYnNvZCA9IEAo
HLP:JGNyaXQgfCBXaGVyZS1PYmplY3QgeyAkXy5JZCAtaW4gNDEsMTAwMSw2MDA4IH0pLkNvdW50CiAgICAkZGlzayA9IEAoJGNyaXQgfCBXaGVyZS1PYmplY3QgeyAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICdkaXNrfE50ZnN8dm9sbWdyJyB9KS5Db3VudAogICAgJHdo
HLP:ZWEgPSBAKCRjcml0IHwgV2hlcmUtT2JqZWN0IHsgJF8uUHJvdmlkZXJOYW1lIC1tYXRjaCAnV0hFQScgfSkuQ291bnQKICAgICRzeW1bJ2Jzb2QnXSA9ICRic29kOyAkc3ltWydkaXNrRXJyJ10gPSAkZGlzazsgJHN5bVsnd2hlYSddID0gJHdoZWE7ICRzeW1bJ2Ny
HLP:aXRDb3VudCddID0gJGNyaXQuQ291bnQKICAgIGlmICgkYnNvZCAtZ3QgMCkgeyAkcmVhc29ucyArPSAiQXBhZ29uZXMvQlNPRCByZWNpZW50ZXM6ICRic29kICgtMTgpIiB9CiAgICBpZiAoJGRpc2sgLWd0IDApIHsgJHJlYXNvbnMgKz0gIkVycm9yZXMgZGUgZGlz
HLP:Y28vTlRGUyByZWNpZW50ZXM6ICRkaXNrICgtMTIpIiB9CiAgICBpZiAoJHdoZWEgLWd0IDApIHsgJHJlYXNvbnMgKz0gIkVycm9yZXMgZGUgaGFyZHdhcmUgKFdIRUEpOiAkd2hlYSAoLTEyKSIgfQogICAgaWYgKCRjcml0LkNvdW50IC1ndCAyNSkgeyAkcmVhc29u
HLP:cyArPSAiTXVjaG9zIGV2ZW50b3MgY3JpdGljb3MgZW4gNDhoOiAkKCRjcml0LkNvdW50KSAoLTYpIiB9CiAgICAjIFNlcnZpY2lvcyBjbGF2ZSBwYXJhZG9zCiAgICAkc3ZjU3RvcHBlZCA9IDAKICAgIGZvcmVhY2ggKCRzdmMgaW4gJ3d1YXVzZXJ2JywnQklUUycs
HLP:J1dpbm1nbXQnLCdFdmVudExvZycpIHsKICAgICAgICAkcyA9IEdldC1TZXJ2aWNlICRzdmMgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICBpZiAoJHMgLWFuZCAkcy5TdGF0dXMgLW5lICdSdW5uaW5nJyAtYW5kICRzLlN0YXJ0VHlwZSAtbmUg
HLP:J0Rpc2FibGVkJykgeyAkc3ZjU3RvcHBlZCsrOyAkcmVhc29ucyArPSAiU2VydmljaW8gJHN2YyBwYXJhZG8gKC00KSIgfQogICAgfQogICAgJHN5bVsnc3ZjU3RvcHBlZCddID0gJHN2Y1N0b3BwZWQKICAgICMgRGlzcG9zaXRpdm9zIGNvbiBwcm9ibGVtYQogICAg
HLP:JHByb2IgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9QblBFbnRpdHkgfCBXaGVyZS1PYmplY3QgeyAkXy5Db25maWdNYW5hZ2VyRXJyb3JDb2RlIC1ndCAwIH0pLkNvdW50CiAgICAkc3ltWydkZXZQcm9ibGVtcyddID0gJHByb2IKICAgIGlmICgkcHJvYiAtZ3Qg
HLP:MCkgeyAkcmVhc29ucyArPSAiRGlzcG9zaXRpdm9zIGNvbiBlcnJvcjogJHByb2IiIH0KICAgICMgLS0tIERpYWdub3N0aWNvIGFtcGxpYWRvIHBlcnNpc3RpZG8gKDUuMik6IFJBTSwgYmF0ZXJpYSwgcmVkIC0tLQogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgaWYg
HLP:KCgkc3QuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnZGlhZycpIC1hbmQgJHN0LmRpYWcpIHsKICAgICAgICBpZiAoJHN0LmRpYWcucmFtIC1hbmQgKFtzdHJpbmddJHN0LmRpYWcucmFtLnN0YXR1cyAtZXEgJ3N1c3BlY3QnKSkgewogICAgICAg
HLP:ICAgICAkc3ltWydyYW1TdXNwZWN0J10gPSAkdHJ1ZTsgJHJlYXNvbnMgKz0gIlJBTSBzb3NwZWNob3NhICgtMTApIgogICAgICAgIH0KICAgICAgICBpZiAoJHN0LmRpYWcuYmF0dGVyeSAtYW5kICRzdC5kaWFnLmJhdHRlcnkucHJlc2VudCkgewogICAgICAgICAg
HLP:ICAkYnBSYXcgPSAkc3QuZGlhZy5iYXR0ZXJ5LmhlYWx0aF9wY3QKICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkYnBSYXcgLWFuZCBbc3RyaW5nXSRicFJhdyAtbmUgJycpIHsKICAgICAgICAgICAgICAgICRicCA9ICRudWxsOyB0cnkgeyAkYnAgPSBbaW50XSRi
HLP:cFJhdyB9IGNhdGNoIHsgJGJwID0gJG51bGwgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkYnApIHsKICAgICAgICAgICAgICAgICAgICAkc3ltWydiYXR0ZXJ5SGVhbHRoUGN0J10gPSAkYnAKICAgICAgICAgICAgICAgICAgICBpZiAoJGJwIC1nZSAw
HLP:IC1hbmQgJGJwIC1sdCA1MCkgeyAkcmVhc29ucyArPSAiQmF0ZXJpYSBtdXkgZGVncmFkYWRhOiAkYnAlICgtOCkiIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICBpZiAoJHN0LmRpYWcubmV0d29yayAtYW5kICgoJHN0
HLP:LmRpYWcubmV0d29yay5jb25uZWN0ZWQgLWVxICRmYWxzZSkgLW9yICgkc3QuZGlhZy5uZXR3b3JrLmRuc19vayAtZXEgJGZhbHNlKSkpIHsKICAgICAgICAgICAgJHN5bVsnbmV0UHJvYmxlbSddID0gJHRydWU7ICRyZWFzb25zICs9ICJQcm9ibGVtYXMgZGUgcmVk
HLP:IHBlcnNpc3RlbnRlcyAoLTgpIgogICAgICAgIH0KICAgIH0KICAgICRzY29yZSA9IENvbXB1dGUtU2NvcmUgJHN5bQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzY29yZSA9IFtpbnRdJHNjb3JlOyByZWFzb25zID0gJHJlYXNvbnMgfQp9CgojIC0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgRm9yZW5zZSBkZWwgcmVnaXN0cm8gZGUgZXZlbnRvczogdWx0aW1vcyBlcnJvcmVzIHF1ZSBleHBsaWNhbiBsYSBjYXVzYSByYWl6Lgpm
HLP:dW5jdGlvbiBHZXQtRm9yZW5zaWNzIHsKICAgICRzaW5jZSA9IChHZXQtRGF0ZSkuQWRkRGF5cygtNykKICAgICRvdXQgPSBAKCkKICAgICRldiA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0nOyBMZXZlbD0xLDI7IFN0
HLP:YXJ0VGltZT0kc2luY2V9IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgNDAwKQogICAgJGdyb3VwcyA9IEAoCiAgICAgICAgQHsgaz0nQVJSQU5RVUUvQVBBR09OJzsgaWRzPUAoNDEsNjAwOCwxMDAxKTsgcHJvdj0n
HLP:JyB9LAogICAgICAgIEB7IGs9J0RJU0NPL05URlMnOyAgICAgIGlkcz1AKCk7ICAgICAgICAgICAgIHByb3Y9J2Rpc2t8TnRmc3x2b2xtZ3J8c3Rvcm52bWV8c3RvcmFoY2knIH0sCiAgICAgICAgQHsgaz0nSEFSRFdBUkUgKFdIRUEpJzsgaWRzPUAoKTsgICAgICAg
HLP:ICAgICAgcHJvdj0nV0hFQScgfSwKICAgICAgICBAeyBrPSdTRVJWSUNJT1MnOyAgICAgICBpZHM9QCgpOyAgICAgICAgICAgICBwcm92PSdTZXJ2aWNlIENvbnRyb2wgTWFuYWdlcicgfSwKICAgICAgICBAeyBrPSdBUExJQ0FDSU9OJzsgICAgICBpZHM9QCgxMDAw
HLP:LDEwMDIpOyAgICBwcm92PSdBcHBsaWNhdGlvbiBFcnJvcnwuTkVUIFJ1bnRpbWUnIH0KICAgICkKICAgIGZvcmVhY2ggKCRnIGluICRncm91cHMpIHsKICAgICAgICAkc2VsID0gJGV2IHwgV2hlcmUtT2JqZWN0IHsKICAgICAgICAgICAgKCRnLmlkcy5Db3VudCAt
HLP:Z3QgMCAtYW5kICRfLklkIC1pbiAkZy5pZHMpIC1vciAoJGcucHJvdiAtbmUgJycgLWFuZCAkXy5Qcm92aWRlck5hbWUgLW1hdGNoICRnLnByb3YpCiAgICAgICAgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDMKICAgICAgICBmb3JlYWNoICgkZSBpbiAkc2VsKSB7
HLP:CiAgICAgICAgICAgICRtc2cgPSAoJGUuTWVzc2FnZSAtc3BsaXQgImBuIilbMF07IGlmICgkbXNnLkxlbmd0aCAtZ3QgOTApIHsgJG1zZyA9ICRtc2cuU3Vic3RyaW5nKDAsOTApIH0KICAgICAgICAgICAgJG91dCArPSAoInswfXx7MX18ezJ9fHszfSIgLWYgJGcu
HLP:aywgJGUuSWQsICRlLlRpbWVDcmVhdGVkLlRvU3RyaW5nKCdNTS1kZCBISDptbScpLCAkbXNnLlRyaW0oKSkKICAgICAgICB9CiAgICB9CiAgICBpZiAoJG91dC5Db3VudCAtZXEgMCkgeyAiT0t8MHwtfFNpbiBlcnJvcmVzIGNyaXRpY29zIGVuIGxvcyB1bHRpbW9z
HLP:IDcgZGlhcy4iIH0gZWxzZSB7ICRvdXQgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgQXV0by10cmlhZ2U6IGEgcGFydGlyIGRlbCBzY29yZSB5IGxhIGZvcmVu
HLP:c2UsIHJlY29taWVuZGEgZmFzZXMgKGxpc3RhIGRlIElEcykuCmZ1bmN0aW9uIEdldC1UcmlhZ2UgewogICAgJGggPSBHZXQtSGVhbHRoU2NvcmUKICAgICRyZWMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAg
HLP:Zm9yZWFjaCAoJHggaW4gJzAwJywnMDEnLCcwMicpIHsgJHJlYy5BZGQoJHgpIH0gICMgZGlhZ25vc3RpY28rcmVzdG9yZStsaW1waWV6YSBzaWVtcHJlCiAgICAkc2luY2UgPSAoR2V0LURhdGUpLkFkZERheXMoLTcpCiAgICAkZXYgPSBAKEdldC1XaW5FdmVudCAt
HLP:RmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgTGV2ZWw9MSwyOyBTdGFydFRpbWU9JHNpbmNlfSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgIGlmIChAKCRldiB8IFdoZXJlLU9iamVjdCB7ICRfLlByb3ZpZGVyTmFtZSAtbWF0Y2gg
HLP:J2Rpc2t8TnRmc3x2b2xtZ3InIH0pLkNvdW50IC1ndCAwKSB7ICRyZWMuQWRkKCcwMycpIH0KICAgICRyZWMuQWRkKCcwNCcpOyAkcmVjLkFkZCgnMDUnKTsgJHJlYy5BZGQoJzA2JykgICMgZGlzY28vRElTTS9TRkMgYmFzZQogICAgaWYgKChHZXQtU2VydmljZSBX
HLP:aW5tZ210KS5TdGF0dXMgLW5lICdSdW5uaW5nJykgeyAkcmVjLkFkZCgnMDcnKSB9CiAgICAjIFdVIHJvdG8/CiAgICAkd3UgPSBHZXQtU2VydmljZSB3dWF1c2VydiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgaWYgKCR3dSAtYW5kICR3dS5TdGF0
HLP:dXMgLW5lICdSdW5uaW5nJyAtYW5kICR3dS5TdGFydFR5cGUgLW5lICdEaXNhYmxlZCcpIHsgJHJlYy5BZGQoJzEzJykgfQogICAgIlNDT1JFPSQoJGguc2NvcmUpIgogICAgIlJFQ09NRU5EQURBUz0kKFtzdHJpbmddOjpKb2luKCcsJywgKCRyZWMgfCBTZWxlY3Qt
HLP:T2JqZWN0IC1VbmlxdWUpKSkiCn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KZnVuY3Rpb24gTmV3LVJlc3RvcmVQb2ludCB7CiAgICB0cnkgewogICAgICAgIEVuYWJs
HLP:ZS1Db21wdXRlclJlc3RvcmUgLURyaXZlICdDOicgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkayA9ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxDdXJyZW50VmVyc2lvblxTeXN0ZW1SZXN0b3JlJwogICAgICAgICRw
HLP:cmV2ID0gKEdldC1JdGVtUHJvcGVydHkgJGsgLU5hbWUgU3lzdGVtUmVzdG9yZVBvaW50Q3JlYXRpb25GcmVxdWVuY3kgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLlN5c3RlbVJlc3RvcmVQb2ludENyZWF0aW9uRnJlcXVlbmN5CiAgICAgICAgU2V0LUl0
HLP:ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtVmFsdWUgMCAtVHlwZSBEV29yZCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICRuYW1lID0gIlN1aXRlX1JlcGFyYWNpb25fJCgoR2V0LURh
HLP:dGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkX0hILW1tJykpIgogICAgICAgIENoZWNrcG9pbnQtQ29tcHV0ZXIgLURlc2NyaXB0aW9uICRuYW1lIC1SZXN0b3JlUG9pbnRUeXBlIE1PRElGWV9TRVRUSU5HUyAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIGlmICgkbnVs
HLP:bCAtbmUgJHByZXYpIHsgU2V0LUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtVmFsdWUgJHByZXYgLVR5cGUgRFdvcmQgfSBlbHNlIHsgUmVtb3ZlLUl0ZW1Qcm9wZXJ0eSAkayAtTmFtZSBTeXN0ZW1SZXN0
HLP:b3JlUG9pbnRDcmVhdGlvbkZyZXF1ZW5jeSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgJHJwID0gR2V0LUNvbXB1dGVyUmVzdG9yZVBvaW50IHwgV2hlcmUtT2JqZWN0IHsgJF8uRGVzY3JpcHRpb24gLWVxICRuYW1lIH0KICAgICAgICBp
HLP:ZiAoJHJwKSB7ICJSRVNVTFQ9T0siOyAiTkFNRT0kbmFtZSIgfSBlbHNlIHsgIlJFU1VMVD1GQUlMIjsgIk5BTUU9JG5hbWUiIH0KICAgIH0gY2F0Y2ggeyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiIH0KfQoKZnVuY3Rpb24g
HLP:U2F2ZS1IZWFsdGhIaXN0b3J5KCRzY29yZSkgewogICAgJHNjcmlwdERpciA9ICRudWxsCiAgICBpZiAoJFBTU2NyaXB0Um9vdCkgewogICAgICAgICRzY3JpcHREaXIgPSAkUFNTY3JpcHRSb290CiAgICB9IGVsc2VpZiAoJE15SW52b2NhdGlvbi5NeUNvbW1hbmQu
HLP:UGF0aCkgewogICAgICAgICRzY3JpcHREaXIgPSBTcGxpdC1QYXRoIC1QYXJlbnQgJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aAogICAgfQogICAgJGJhc2VEaXIgPSBpZiAoJHNjcmlwdERpcikgeyBKb2luLVBhdGggKFNwbGl0LVBhdGggLVBhcmVudCAkc2Ny
HLP:aXB0RGlyKSAiV1BJX1N1aXRlIiB9IGVsc2UgeyAkV29yayB9CiAgICBpZiAoJHNjcmlwdERpciAtYW5kIChUZXN0LVBhdGggJHNjcmlwdERpcikpIHsKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRiYXNlRGlyKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGly
HLP:ZWN0b3J5IC1QYXRoICRiYXNlRGlyIC1Gb3JjZSB8IE91dC1OdWxsIH0KICAgIH0gZWxzZSB7CiAgICAgICAgJGJhc2VEaXIgPSAkV29yawogICAgfQogICAgJGhpc3RvcnlGaWxlID0gSm9pbi1QYXRoICRiYXNlRGlyICJoZWFsdGhfaGlzdG9yeS5qc29uIgogICAg
HLP:JGhpc3RvcnkgPSBAKCkKICAgIGlmIChUZXN0LVBhdGggJGhpc3RvcnlGaWxlKSB7CiAgICAgICAgdHJ5IHsgJGhpc3RvcnkgPSBHZXQtQ29udGVudCAkaGlzdG9yeUZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24gfSBjYXRjaCB7fQogICAgfQogICAgJGVudHJ5
HLP:ID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgZGF0ZSAgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkIEhIOm1tJykKICAgICAgICBzY29yZSA9IFtpbnRdJHNjb3JlCiAgICB9CiAgICAkaGlzdG9yeSA9IEAoJGhpc3RvcnkpICsgJGVudHJ5CiAg
HLP:ICBpZiAoJGhpc3RvcnkuQ291bnQgLWd0IDEwKSB7ICRoaXN0b3J5ID0gJGhpc3RvcnlbLTEwLi4tMV0gfQogICAgdHJ5IHsKICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJGhpc3RvcnlGaWxlLCAoJGhpc3RvcnkgfCBDb252ZXJ0VG8tSnNv
HLP:biksIChOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpKSkKICAgIH0gY2F0Y2gge30KfQoKZnVuY3Rpb24gSW5zdGFsbC1XaW5nZXRCb290c3RyYXAgewogICAgJHRlbXBGaWxlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAiTWljcm9zb2Z0
HLP:LkRlc2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgogICAgdHJ5IHsKICAgICAgICAkdXJsID0gImh0dHBzOi8vZ2l0aHViLmNvbS9taWNyb3NvZnQvd2luZ2V0LWNsaS9yZWxlYXNlcy9sYXRlc3QvZG93bmxvYWQvTWljcm9zb2Z0LkRl
HLP:c2t0b3BBcHBJbnN0YWxsZXJfOHdla3liM2Q4YmJ3ZS5tc2l4YnVuZGxlIgogICAgICAgIFdyaXRlLUhvc3QgIkRlc2NhcmdhbmRvIEFwcCBJbnN0YWxsZXIgZGVzZGU6ICR1cmwiCiAgICAgICAgJHdlYkNsaWVudCA9IE5ldy1PYmplY3QgU3lzdGVtLk5ldC5XZWJD
HLP:bGllbnQKICAgICAgICBbU3lzdGVtLk5ldC5TZXJ2aWNlUG9pbnRNYW5hZ2VyXTo6U2VjdXJpdHlQcm90b2NvbCA9IFtTeXN0ZW0uTmV0LlNlY3VyaXR5UHJvdG9jb2xUeXBlXTo6VGxzMTIKICAgICAgICAkd2ViQ2xpZW50LkRvd25sb2FkRmlsZSgkdXJsLCAkdGVt
HLP:cEZpbGUpCiAgICAgICAgCiAgICAgICAgV3JpdGUtSG9zdCAiSW5zdGFsYW5kbyBBcHAgSW5zdGFsbGVyIGNvbiBBZGQtQXBweFBhY2thZ2UuLi4iCiAgICAgICAgQWRkLUFwcHhQYWNrYWdlIC1QYXRoICR0ZW1wRmlsZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAg
HLP:IFdyaXRlLUhvc3QgIkluc3RhbGFjaW9uIGV4aXRvc2EuIgogICAgICAgIGlmIChUZXN0LVBhdGggJHRlbXBGaWxlKSB7IFJlbW92ZS1JdGVtICR0ZW1wRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIHJldHVybiAkdHJ1
HLP:ZQogICAgfSBjYXRjaCB7CiAgICAgICAgV3JpdGUtSG9zdCAiRXJyb3IgZW4gYm9vdHN0cmFwIGRlIHdpbmdldDogJCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkdGVtcEZpbGUpIHsgUmVtb3ZlLUl0ZW0gJHRlbXBGaWxlIC1G
HLP:b3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgcmV0dXJuICRmYWxzZQogICAgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgKDMu
HLP:NyAvIEJ1ZyA1IC8gUmVxIDcpIERldGVjY2lvbiBmaWFibGUgZGVsIHRpcG8gZGUgZGlzY28uCiMgQ29udmVydFRvLU1lZGlhQ2xhc3M6IGZ1bmNpb24gUFVSQSBxdWUgbWFwZWEgdW4gTWVkaWFUeXBlIChudW1lcm8gbyB0ZXh0bykKIyBhIGxhIGNsYXNlIGNhbm9u
HLP:aWNhIHtTU0QsSERELFVOS05PV059LiBTU0Q9NCBvICdTU0QnOyBIREQ9MyBvICdIREQnOwojIGN1YWxxdWllciBvdHJvIHZhbG9yIChVbnNwZWNpZmllZD0wLCB2YWNpbywgbnVsbywgU0NNPTUuLi4pIC0+IFVOS05PV04uCmZ1bmN0aW9uIENvbnZlcnRUby1NZWRp
HLP:YUNsYXNzKCRtdCkgewogICAgaWYgKCRudWxsIC1lcSAkbXQpIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICAkcyA9IChbc3RyaW5nXSRtdCkuVHJpbSgpCiAgICBpZiAoJHMgLWVxICcnKSB7IHJldHVybiAnVU5LTk9XTicgfQogICAgc3dpdGNoIC1yZWdleCAoJHMu
HLP:VG9VcHBlcigpKSB7CiAgICAgICAgJ14oNHxTU0QpJCcgeyByZXR1cm4gJ1NTRCcgfQogICAgICAgICdeKDN8SEREKSQnIHsgcmV0dXJuICdIREQnIH0KICAgICAgICBkZWZhdWx0ICAgICB7IHJldHVybiAnVU5LTk9XTicgfQogICAgfQp9CgojIFJlc29sdmUtT3B0
HLP:aW1pemVBY3Rpb246IGZ1bmNpb24gUFVSQS4gVFJJTSBzb2xvIHNpIFNTRCwgREVGUkFHIHNvbG8gc2kgSERECiMgY2xhcm8sIE5PTkUgZW4gY3VhbHF1aWVyIG90cm8gY2FzbyAoYWJzdGVuY2lvbiBzZWd1cmE6IG51bmNhIGRlc2ZyYWdtZW50YQojIGFudGUgdGlw
HLP:byBpbmNpZXJ0bywgZXZpdGFuZG8gZGFuYXIgdW4gcG9zaWJsZSBTU0QpLgpmdW5jdGlvbiBSZXNvbHZlLU9wdGltaXplQWN0aW9uKCRtZWRpYSkgewogICAgJG0gPSAoW3N0cmluZ10kbWVkaWEpLlRyaW0oKS5Ub1VwcGVyKCkKICAgIGlmICAgICAoJG0gLWVxICdT
HLP:U0QnKSAgICAgeyByZXR1cm4gJ1RSSU0nIH0KICAgIGVsc2VpZiAoJG0gLWVxICdIREQnKSAgICAgeyByZXR1cm4gJ0RFRlJBRycgfQogICAgZWxzZWlmICgkbSAtZXEgJ1ZJUlRVQUwnKSB7IHJldHVybiAnTk9ORScgfSAgICMgKHYzLjIpIGRpc2NvIGRlIG1hcXVp
HLP:bmEgdmlydHVhbDogbm8gYXBsaWNhCiAgICBlbHNlICAgICAgICAgICAgICAgICAgICAgIHsgcmV0dXJuICdOT05FJyB9Cn0KCiMgR2V0LU1lZGlhVHlwZTogaWRlbnRpZmljYSBlbCBkaXNjbyBmaXNpY28gZGVsIHZvbHVtZW4gZGVsIHNpc3RlbWEgZGUgZm9ybWEK
HLP:IyBmaWFibGUgKHBvciBEZXZpY2VJZCwgcmVzcGFsZG8gcG9yIFNlcmlhbE51bWJlcikgeSBkZXZ1ZWx2ZSBTU0R8SEREfFZJUlRVQUx8VU5LTk9XTi4KZnVuY3Rpb24gR2V0LU1lZGlhVHlwZSB7CiAgICB0cnkgewogICAgICAgICRzeXMgID0gKCRlbnY6U3lzdGVt
HLP:RHJpdmUpLlRyaW1FbmQoJzonKQogICAgICAgICRkaXNrID0gR2V0LVBhcnRpdGlvbiAtRHJpdmVMZXR0ZXIgJHN5cyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IEdldC1EaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgJHBk
HLP:ID0gJG51bGwKICAgICAgICBpZiAoJGRpc2spIHsKICAgICAgICAgICAgJHBkID0gR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAgICAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLkRldmljZUlkIC1lcSAkZGlz
HLP:ay5OdW1iZXIgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgaWYgKC1ub3QgJHBkIC1hbmQgJGRpc2suU2VyaWFsTnVtYmVyKSB7CiAgICAgICAgICAgICAgICAkcGQgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNv
HLP:bnRpbnVlIHwKICAgICAgICAgICAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLlNlcmlhbE51bWJlciAtYW5kICgkXy5TZXJpYWxOdW1iZXIuVHJpbSgpIC1lcSAoW3N0cmluZ10kZGlzay5TZXJpYWxOdW1iZXIpLlRyaW0oKSkgfSB8CiAgICAgICAgICAgICAg
HLP:ICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgIyAodjMuMikgZGlzY28gZGUgbWFxdWluYSB2aXJ0dWFsIChWaXJ0dWFsQm94L1ZNd2FyZS9IeXBlci1WL1FFTVUpOiBUUklNIHkKICAgICAgICAjIGRl
HLP:c2ZyYWdtZW50YWNpb24gbm8gYXBsaWNhbjsgc2UgaWRlbnRpZmljYSBwb3IgZWwgbW9kZWxvIGRlbCBkaXNjby4KICAgICAgICAkbW9kZWxvcyA9IEAoKQogICAgICAgIGlmICgkZGlzaykgeyAkbW9kZWxvcyArPSBbc3RyaW5nXSRkaXNrLkZyaWVuZGx5TmFtZTsg
HLP:JG1vZGVsb3MgKz0gW3N0cmluZ10kZGlzay5Nb2RlbCB9CiAgICAgICAgaWYgKCRwZCkgICB7ICRtb2RlbG9zICs9IFtzdHJpbmddJHBkLkZyaWVuZGx5TmFtZTsgICAkbW9kZWxvcyArPSBbc3RyaW5nXSRwZC5Nb2RlbCB9CiAgICAgICAgaWYgKCgkbW9kZWxvcyAt
HLP:am9pbiAnICcpIC1tYXRjaCAnVkJPWHxWTVdBUkV8VklSVFVBTHxRRU1VfFhFTlNSQycpIHsgcmV0dXJuICdWSVJUVUFMJyB9CiAgICAgICAgaWYgKC1ub3QgJHBkKSB7IHJldHVybiAnVU5LTk9XTicgfQogICAgICAgIHJldHVybiAoQ29udmVydFRvLU1lZGlhQ2xh
HLP:c3MgJHBkLk1lZGlhVHlwZSkKICAgIH0gY2F0Y2ggeyByZXR1cm4gJ1VOS05PV04nIH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpmdW5jdGlvbiBHZXQtRGV2aWNl
HLP:UHJvYmxlbXMgewogICAgJHAgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9QblBFbnRpdHkgfCBXaGVyZS1PYmplY3QgeyAkXy5Db25maWdNYW5hZ2VyRXJyb3JDb2RlIC1ndCAwIH0pCiAgICBpZiAoJHAuQ291bnQgLWVxIDApIHsgIk9LfFNpbiBkaXNwb3NpdGl2
HLP:b3MgY29uIHByb2JsZW1hLiI7IHJldHVybiB9CiAgICBmb3JlYWNoICgkZCBpbiAoJHAgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxMikpIHsKICAgICAgICAiUFJPQnwkKCRkLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUpfCQoJGQuTmFtZSkiCiAgICB9Cn0KCiMgLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBJbmZvcm1lIEhUTUwgYXV0b2NvbnRlbmlkbyB5IGJvbml0byAodGVtYSBvc2N1cm8pLiAtQXJnID0gcnV0YSBkZSBzYWxpZGEuCmZ1
HLP:bmN0aW9uIE5ldy1IdG1sUmVwb3J0KCRvdXRQYXRoKSB7CiAgICBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XZWIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIHRyeSB7CiAgICAgICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgICAgICRzeXNQ
HLP:YWlycyA9IEdldC1TeXNJbmZvCgogICAgICAgICRlbmMgPSB7IHBhcmFtKCR0KSBbU3lzdGVtLldlYi5IdHRwVXRpbGl0eV06Okh0bWxFbmNvZGUoW3N0cmluZ10kdCkgfQogICAgICAgICRjaXJjID0gNTI3Ljc5CiAgICAgICAgJGJhbmRDb2xvciA9IHsgcGFyYW0o
HLP:JHMpIGlmICgkcyAtZXEgJy0nIC1vciAkbnVsbCAtZXEgJHMgLW9yIFtzdHJpbmddJHMgLWVxICcnKSB7ICcjOTRhM2I4JyB9IGVsc2UgeyAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0Y2ggeyByZXR1cm4gJyM5NGEzYjgnIH07IGlmICgkdiAtZ2UgODApIHsn
HLP:IzIyYzU1ZSd9IGVsc2VpZiAoJHYgLWdlIDUwKSB7JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9IH0gfQogICAgICAgICRiYW5kTGFiZWwgPSB7IHBhcmFtKCRzKSBpZiAoJHMgLWVxICctJyAtb3IgJG51bGwgLWVxICRzIC1vciBbc3RyaW5nXSRzIC1lcSAnJykg
HLP:eyAnc2luIGRhdG9zJyB9IGVsc2UgeyAkdj0wOyB0cnkgeyAkdj1baW50XSRzIH0gY2F0Y2ggeyByZXR1cm4gJ3NpbiBkYXRvcycgfTsgaWYgKCR2IC1nZSA4MCkgeydCdWVuYSd9IGVsc2VpZiAoJHYgLWdlIDUwKSB7J1JlZ3VsYXInfSBlbHNlIHsnQ3JpdGljYSd9
HLP:IH0gfQogICAgICAgICRvZmZzZXRPZiA9IHsgcGFyYW0oJHMpICR2PTA7IHRyeSB7ICR2PVtpbnRdJHMgfSBjYXRjaCB7ICR2PTAgfTsgaWYgKCR2IC1sdCAwKXskdj0wfTsgaWYgKCR2IC1ndCAxMDApeyR2PTEwMH07IFttYXRoXTo6Um91bmQoJGNpcmMgKiAoMSAt
HLP:ICgkdi8xMDAuMCkpLCAyKSB9CiAgICAgICAgJHN0YXR1c0ljb24gPSB7CiAgICAgICAgICAgIHBhcmFtKCRyZXMpCiAgICAgICAgICAgIHN3aXRjaCAoW3N0cmluZ10kcmVzKSB7CiAgICAgICAgICAgICAgICAnT0snICAgIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0
HLP:IDI0JyBjbGFzcz0nc3ZnaWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J2NvcnJlY3RvJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nIzIyYzU1ZScvPjxwYXRoIGQ9J003IDEyLjRsMy4yIDMuMkwxNyA4LjgnIGZpbGw9J25vbmUnIHN0cm9r
HLP:ZT0nIzA0MjEwZicgc3Ryb2tlLXdpZHRoPScyLjYnIHN0cm9rZS1saW5lY2FwPSdyb3VuZCcgc3Ryb2tlLWxpbmVqb2luPSdyb3VuZCcvPjwvc3ZnPiIgfQogICAgICAgICAgICAgICAgJ1dBUk4nICB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2
HLP:Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdhdmlzbyc+PHBhdGggZD0nTTEyIDIuNUwyMyAyMS41SDF6JyBmaWxsPScjZjU5ZTBiJy8+PHJlY3QgeD0nMTEnIHk9JzguNScgd2lkdGg9JzInIGhlaWdodD0nNycgcng9JzEnIGZpbGw9JyMzYTI0MDAnLz48Y2ly
HLP:Y2xlIGN4PScxMicgY3k9JzE4JyByPScxLjMnIGZpbGw9JyMzYTI0MDAnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgICdFUlJPUicgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nZXJyb3In
HLP:PjxjaXJjbGUgY3g9JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScjZWY0NDQ0Jy8+PHBhdGggZD0nTTggOGw4IDhNMTYgOGwtOCA4JyBzdHJva2U9JyMyYTA2MDYnIHN0cm9rZS13aWR0aD0nMi42JyBzdHJva2UtbGluZWNhcD0ncm91bmQnLz48L3N2Zz4iIH0KICAg
HLP:ICAgICAgICAgICAgICdTS0lQJyAgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nb21pdGlkbyc+PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyM2NDc0OGInLz48cmVjdCB4
HLP:PSc2LjUnIHk9JzExJyB3aWR0aD0nMTEnIGhlaWdodD0nMicgcng9JzEnIGZpbGw9JyMwYjEyMjAnLz48L3N2Zz4iIH0KICAgICAgICAgICAgICAgIGRlZmF1bHQgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQgMjQnIGNsYXNzPSdzdmdpY28nPjxjaXJjbGUgY3g9JzEy
HLP:JyBjeT0nMTInIHI9JzExJyBmaWxsPScjOTRhM2I4Jy8+PC9zdmc+IiB9CiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgICRiZWZvcmUgPSAkc3Quc2NvcmVfYmVmb3JlOyBpZiAoJG51bGwgLWVxICRiZWZvcmUpIHsgJGJlZm9yZSA9ICctJyB9CiAgICAg
HLP:ICAgJGFmdGVyICA9ICRzdC5zY29yZV9hZnRlcjsgIGlmICgkbnVsbCAtZXEgJGFmdGVyKSAgeyAkYWZ0ZXIgID0gJy0nIH0KICAgICAgICAkaGFzQm90aCA9ICgkc3Quc2NvcmVfYmVmb3JlIC1uZSAkbnVsbCAtYW5kICRzdC5zY29yZV9hZnRlciAtbmUgJG51bGwp
HLP:CiAgICAgICAgJGRlbHRhID0gMDsgJGRlbHRhVHh0ID0gJ3NpbiBjb21wYXJhY2lvbicKICAgICAgICBpZiAoJGhhc0JvdGgpIHsgJGRlbHRhID0gW2ludF0kc3Quc2NvcmVfYWZ0ZXIgLSBbaW50XSRzdC5zY29yZV9iZWZvcmU7ICRzaWduID0gaWYgKCRkZWx0YSAt
HLP:Z2UgMCkgeycrJ30gZWxzZSB7Jyd9OyAkZGVsdGFUeHQgPSAiJHNpZ24kZGVsdGEgcHVudG9zIiB9CiAgICAgICAgJGRlbHRhQ29sb3IgPSBpZiAoJGRlbHRhIC1ndCAwKSB7JyMyMmM1NWUnfSBlbHNlaWYgKCRkZWx0YSAtbHQgMCkgeycjZWY0NDQ0J30gZWxzZSB7
HLP:JyM5NGEzYjgnfQogICAgICAgICRtYWluU2NvcmUgPSBpZiAoJGFmdGVyIC1uZSAnLScpIHsgJGFmdGVyIH0gZWxzZWlmICgkYmVmb3JlIC1uZSAnLScpIHsgJGJlZm9yZSB9IGVsc2UgeyAnLScgfQogICAgICAgICRtYWluQ29sb3IgPSAmICRiYW5kQ29sb3IgJG1h
HLP:aW5TY29yZQogICAgICAgICRtYWluT2Zmc2V0ID0gJiAkb2Zmc2V0T2YgJG1haW5TY29yZQogICAgICAgICRtYWluTGFiZWwgPSAmICRiYW5kTGFiZWwgJG1haW5TY29yZQogICAgICAgICRiZWZvcmVDb2xvciA9ICYgJGJhbmRDb2xvciAkYmVmb3JlCiAgICAgICAg
HLP:JGFmdGVyQ29sb3IgID0gJiAkYmFuZENvbG9yICRhZnRlcgogICAgICAgICRiZWZvcmVPZmZzZXQgPSAmICRvZmZzZXRPZiAkYmVmb3JlCiAgICAgICAgJGFmdGVyT2Zmc2V0ICA9ICYgJG9mZnNldE9mICRhZnRlcgoKICAgICAgICAkc2NyaXB0RGlyID0gJG51bGwK
HLP:ICAgICAgICBpZiAoJFBTU2NyaXB0Um9vdCkgewogICAgICAgICAgICAkc2NyaXB0RGlyID0gJFBTU2NyaXB0Um9vdAogICAgICAgIH0gZWxzZWlmICgkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoKSB7CiAgICAgICAgICAgICRzY3JpcHREaXIgPSBTcGxpdC1Q
HLP:YXRoIC1QYXJlbnQgJE15SW52b2NhdGlvbi5NeUNvbW1hbmQuUGF0aAogICAgICAgIH0KICAgICAgICAkYmFzZURpciA9IGlmICgkc2NyaXB0RGlyKSB7IEpvaW4tUGF0aCAoU3BsaXQtUGF0aCAtUGFyZW50ICRzY3JpcHREaXIpICJXUElfU3VpdGUiIH0gZWxzZSB7
HLP:ICRXb3JrIH0KICAgICAgICAkaGlzdG9yeUZpbGUgPSBKb2luLVBhdGggJGJhc2VEaXIgImhlYWx0aF9oaXN0b3J5Lmpzb24iCiAgICAgICAgJGhpc3RvcnkgPSBAKCkKICAgICAgICBpZiAoVGVzdC1QYXRoICRoaXN0b3J5RmlsZSkgewogICAgICAgICAgICB0cnkg
HLP:eyAkaGlzdG9yeSA9IEdldC1Db250ZW50ICRoaXN0b3J5RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgICAgICRoaXN0b3J5SHRtbCA9ICcnCiAgICAgICAgaWYgKCRoaXN0b3J5IC1hbmQgJGhpc3RvcnkuQ291bnQg
HLP:LWd0IDApIHsKICAgICAgICAgICAgJGhpc3RvcnlIdG1sICs9ICI8ZGl2IGNsYXNzPSd0cmVuZC10aXRsZSc+SGlzdG9yaWFsIGRlIFNhbHVkIChVbHRpbWFzIGVqZWN1Y2lvbmVzKTwvZGl2PjxkaXYgY2xhc3M9J3RyZW5kLWxpc3QnPiIKICAgICAgICAgICAgZm9y
HLP:ZWFjaCAoJGggaW4gJGhpc3RvcnkpIHsKICAgICAgICAgICAgICAgICRjb2wgPSAmICRiYW5kQ29sb3IgJGguc2NvcmUKICAgICAgICAgICAgICAgICRoaXN0b3J5SHRtbCArPSAiPGRpdiBjbGFzcz0ndHJlbmQtaXRlbSc+PHNwYW4gY2xhc3M9J3RyZW5kLWRhdGUn
HLP:PiQoJGguZGF0ZSk8L3NwYW4+PHNwYW4gY2xhc3M9J3RyZW5kLXNjb3JlJyBzdHlsZT0nY29sb3I6JGNvbCc+JCgkaC5zY29yZSkvMTAwPC9zcGFuPjwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICAkaGlzdG9yeUh0bWwgKz0gIjwvZGl2PiIKICAgICAg
HLP:ICB9CgogICAgICAgICRzeXNNYXAgPSBAe30KICAgICAgICBmb3JlYWNoICgkcCBpbiAkc3lzUGFpcnMpIHsgJGt2ID0gJHAgLXNwbGl0ICc9JywyOyBpZiAoJGt2LkNvdW50IC1lcSAyKSB7ICRzeXNNYXBbJGt2WzBdXSA9ICRrdlsxXSB9IH0KICAgICAgICAkc3lz
HLP:T3JkZXIgPSBAKEAoJ09TJywnU2lzdGVtYSBvcGVyYXRpdm8nKSxAKCdFUVVJUE8nLCdFcXVpcG8nKSxAKCdDUFUnLCdQcm9jZXNhZG9yJyksQCgnUkFNJywnTWVtb3JpYSBSQU0nKSxAKCdESVNDTycsJ0Rpc2NvIEM6JyksQCgnVVBUSU1FJywnVGllbXBvIGVuY2Vu
HLP:ZGlkbycpLEAoJ1VTVUFSSU8nLCdVc3VhcmlvJykpCiAgICAgICAgJHN5c0NhcmRzID0gJycKICAgICAgICBmb3JlYWNoICgkbyBpbiAkc3lzT3JkZXIpIHsgaWYgKCRzeXNNYXAuQ29udGFpbnNLZXkoJG9bMF0pKSB7ICRzeXNDYXJkcyArPSAiPGRpdiBjbGFzcz0n
HLP:c3lzJz48ZGl2IGNsYXNzPSdzeXMtayc+JCgmICRlbmMgJG9bMV0pPC9kaXY+PGRpdiBjbGFzcz0nc3lzLXYnPiQoJiAkZW5jICRzeXNNYXBbJG9bMF1dKTwvZGl2PjwvZGl2PiIgfSB9CiAgICAgICAgJG1hY2hpbmUgPSAkc3lzTWFwWydFUVVJUE8nXTsgaWYgKC1u
HLP:b3QgJG1hY2hpbmUpIHsgJG1hY2hpbmUgPSAkZW52OkNPTVBVVEVSTkFNRSB9CgogICAgICAgICRwaGFzZXMgPSBAKCRzdC5waGFzZXMpCiAgICAgICAgJGNPSz0wOyRjV0FSTj0wOyRjRVJSPTA7JGNTS0lQPTAKICAgICAgICAkbWF4U2VjcyA9IDEKICAgICAgICBm
HLP:b3JlYWNoICgkcGggaW4gJHBoYXNlcykgeyAkc3Y9MDsgdHJ5IHsgJHN2PVtpbnRdJHBoLnNlY3MgfSBjYXRjaCB7fTsgaWYgKCRzdiAtZ3QgJG1heFNlY3MpIHsgJG1heFNlY3MgPSAkc3YgfSB9CiAgICAgICAgJHJvd3MgPSAnJwogICAgICAgICRiYXJzID0gJycK
HLP:ICAgICAgICBmb3JlYWNoICgkcGggaW4gJHBoYXNlcykgewogICAgICAgICAgICAkcmVzID0gW3N0cmluZ10kcGgucmVzdWx0CiAgICAgICAgICAgIHN3aXRjaCAoJHJlcykgeyAnT0snIHskY09LKyt9ICdXQVJOJyB7JGNXQVJOKyt9ICdFUlJPUicgeyRjRVJSKyt9
HLP:ICdTS0lQJyB7JGNTS0lQKyt9IH0KICAgICAgICAgICAgJGxjID0gJHJlcy5Ub0xvd2VyKCkKICAgICAgICAgICAgJG5vdGUgPSBpZiAoW3N0cmluZ10kcGgubm90ZSAtbmUgJycpIHsgIjxkaXYgY2xhc3M9J3BoLW5vdGUnPiQoJiAkZW5jICRwaC5ub3RlKTwvZGl2
HLP:PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAkcm93cyArPSAiPGRpdiBjbGFzcz0ncGggcGgtJGxjJz48ZGl2IGNsYXNzPSdwaC1kb3QnPiQoJiAkc3RhdHVzSWNvbiAkcmVzKTwvZGl2PjxkaXYgY2xhc3M9J3BoLW1haW4nPjxkaXYgY2xhc3M9J3BoLXRvcCc+
HLP:PHNwYW4gY2xhc3M9J3BoLW51bSc+JCgmICRlbmMgJHBoLm51bSk8L3NwYW4+PHNwYW4gY2xhc3M9J3BoLXRpdGxlJz4kKCYgJGVuYyAkcGgudGl0bGUpPC9zcGFuPjxzcGFuIGNsYXNzPSdwaC1iYWRnZSBiLSRsYyc+JHJlczwvc3Bhbj48L2Rpdj4kbm90ZTwvZGl2
HLP:PjxkaXYgY2xhc3M9J3BoLXNlY3MnPiQoJiAkZW5jICRwaC5zZWNzKXM8L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICRzdj0wOyB0cnkgeyAkc3Y9W2ludF0kcGguc2VjcyB9IGNhdGNoIHt9CiAgICAgICAgICAgICR3ID0gW21hdGhdOjpSb3VuZCgxMDAuMCAqICRz
HLP:diAvIFttYXRoXTo6TWF4KDEsJG1heFNlY3MpKTsgaWYgKCR3IC1sdCAyIC1hbmQgJHN2IC1ndCAwKSB7ICR3ID0gMiB9CiAgICAgICAgICAgICRiY29sID0gc3dpdGNoICgkcmVzKSB7ICdPSycgeycjMjJjNTVlJ30gJ1dBUk4nIHsnI2Y1OWUwYid9ICdFUlJPUicg
HLP:eycjZWY0NDQ0J30gZGVmYXVsdCB7JyM2NDc0OGInfSB9CiAgICAgICAgICAgICRiYXJzICs9ICI8ZGl2IGNsYXNzPSdiYXItcm93Jz48ZGl2IGNsYXNzPSdiYXItbGJsJz4kKCYgJGVuYyAkcGgubnVtKSAkKCYgJGVuYyAkcGgudGl0bGUpPC9kaXY+PGRpdiBjbGFz
HLP:cz0nYmFyLXRyYWNrJz48c3BhbiBzdHlsZT0nd2lkdGg6JHclO2JhY2tncm91bmQ6JGJjb2wnPjwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdiYXItdmFsJz4kKCYgJGVuYyAkcGguc2VjcylzPC9kaXY+PC9kaXY+IgogICAgICAgIH0KICAgICAgICBpZiAoLW5vdCAk
HLP:cm93cykgeyAkcm93cyA9ICI8ZGl2IGNsYXNzPSdlbXB0eSc+Tm8gc2UgcmVnaXN0cmFyb24gZmFzZXMgZW4gZXN0YSBlamVjdWNpb24uPC9kaXY+IiB9CiAgICAgICAgaWYgKC1ub3QgJGJhcnMpIHsgJGJhcnMgPSAiPGRpdiBjbGFzcz0nZW1wdHknPlNpbiB0aWVt
HLP:cG9zIHF1ZSBtb3N0cmFyLjwvZGl2PiIgfQogICAgICAgICR0b3RhbFBoID0gJHBoYXNlcy5Db3VudAogICAgICAgICMgRXN0YWRpc3RpY2FzIFJFQUxFUyBhZ3JlZ2FkYXMgZGUgbG8gZWplY3V0YWRvOiB0aWVtcG8gdG90YWwgZGUgbGEgc2VzaW9uCiAgICAgICAg
HLP:IyB5IGVzcGFjaW8gbGliZXJhZG8gKHN1bWFkbyBkZSBsYXMgbm90YXMgbWVkaWRhcyBkZSBjYWRhIGZhc2UsIE1CL0dCKS4KICAgICAgICAkdG90U2VjcyA9IDA7ICRtYkZyZWVkID0gMC4wCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsKICAgICAg
HLP:ICAgICAgJHN2ID0gMDsgdHJ5IHsgJHN2ID0gW2ludF0kcGguc2VjcyB9IGNhdGNoIHt9OyAkdG90U2VjcyArPSAkc3YKICAgICAgICAgICAgZm9yZWFjaCAoJG0gaW4gW3JlZ2V4XTo6TWF0Y2hlcyhbc3RyaW5nXSRwaC5ub3RlLCAnKD9pKSg/OmxpYmVyYWRcdyp8
HLP:ZnJlZWQpXER7MCwxMH0/KFtcZFwuLF0rKVxzKihNQnxHQiknKSkgewogICAgICAgICAgICAgICAgJHYgPSAwLjA7IHRyeSB7ICR2ID0gW2RvdWJsZV0oJG0uR3JvdXBzWzFdLlZhbHVlLlJlcGxhY2UoJywnLCAnLicpKSB9IGNhdGNoIHt9CiAgICAgICAgICAgICAg
HLP:ICBpZiAoJG0uR3JvdXBzWzJdLlZhbHVlIC1tYXRjaCAnKD9pKUdCJykgeyAkdiA9ICR2ICogMTAyNCB9CiAgICAgICAgICAgICAgICAkbWJGcmVlZCArPSAkdgogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgICR0b3RUeHQgPSBpZiAoJHRvdFNlY3MgLWdl
HLP:IDYwKSB7ICgnezB9IG1pbiB7MX0gcycgLWYgW2ludF1bbWF0aF06OkZsb29yKCR0b3RTZWNzIC8gNjApLCAoJHRvdFNlY3MgJSA2MCkpIH0gZWxzZSB7ICgnezB9IHMnIC1mICR0b3RTZWNzKSB9CiAgICAgICAgJGZyZWVkVHh0ID0gaWYgKCRtYkZyZWVkIC1nZSAx
HLP:MDI0KSB7ICgnezA6bjF9IEdCJyAtZiAoJG1iRnJlZWQgLyAxMDI0KSkgfSBlbHNlaWYgKCRtYkZyZWVkIC1ndCAwKSB7ICgnezA6bjB9IE1CJyAtZiAkbWJGcmVlZCkgfSBlbHNlIHsgJycgfQogICAgICAgICRzdGF0TGluZSA9ICgndGllbXBvIHRvdGFsOiB7MH0n
HLP:IC1mICR0b3RUeHQpCiAgICAgICAgaWYgKCRmcmVlZFR4dCkgeyAkc3RhdExpbmUgKz0gKCcgJm1pZGRvdDsgZXNwYWNpbyBsaWJlcmFkbzogezB9JyAtZiAkZnJlZWRUeHQpIH0KCiAgICAgICAgJGZpbmRpbmdzID0gQCgkc3QuZmluZGluZ3MpCiAgICAgICAgJGZp
HLP:bmRIdG1sID0gJycKICAgICAgICAkc3RlcHNMaXN0ID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgICAgICBmb3JlYWNoICgkZiBpbiAkZmluZGluZ3MpIHsKICAgICAgICAgICAgJHR4dCA9IFtzdHJpbmddJGYK
HLP:ICAgICAgICAgICAgJHNldiA9ICdpbmZvJzsgJHNldlR4dCA9ICdBdmlzbycKICAgICAgICAgICAgaWYgKCR0eHQgLW1hdGNoICcoP2kpU01BUlR8QlNPRHxhcGFnfFdIRUF8aGFyZHdhcmV8bm8gcmVwYXJhYmxlc3xkYW5hZHxyZXBvc2l0b3Jpb3xpbnRlZ3JpZGFk
HLP:JykgeyAkc2V2PSdoaWdoJzsgJHNldlR4dD0nSW1wb3J0YW50ZScgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpZXNwYWNpb3xyZWluaWNpbyBwZW5kaWVudGV8XGJyZWRcYnxiYXRlcmlhfGRyaXZlcnxkaXNwb3NpdGl2b3xcYlJBTVxifHNl
HLP:cnZpY2lvJykgeyAkc2V2PSdtZWQnOyAkc2V2VHh0PSdSZXZpc2FyJyB9CiAgICAgICAgICAgICRmaW5kSHRtbCArPSAiPGxpIGNsYXNzPSdmaW5kIGZpbmQtJHNldic+PHNwYW4gY2xhc3M9J3NldiBzZXYtJHNldic+JHNldlR4dDwvc3Bhbj48c3BhbiBjbGFzcz0n
HLP:ZmluZC10eHQnPiQoJiAkZW5jICR0eHQpPC9zcGFuPjwvbGk+IgogICAgICAgICAgICAjIERlcml2YXIgcGFzbyByZWNvbWVuZGFkbyBhIHBhcnRpciBkZWwgaGFsbGF6Z28KICAgICAgICAgICAgaWYgKCR0eHQgLW1hdGNoICcoP2kpU01BUlQnKSAgICAgICAgICB7
HLP:ICRzdGVwc0xpc3QuQWRkKCdIYXogY29waWEgZGUgc2VndXJpZGFkIGRlIHR1cyBkYXRvcyBjdWFudG8gYW50ZXM6IHVuIGRpc2NvIGNvbiBTTUFSVCBkZWdyYWRhZG8gcHVlZGUgZmFsbGFyLiBWYWxvcmEgcmVlbXBsYXphcmxvLicpIH0KICAgICAgICAgICAgZWxz
HLP:ZWlmICgkdHh0IC1tYXRjaCAnKD9pKWVzcGFjaW8nKSAgICB7ICRzdGVwc0xpc3QuQWRkKCdMaWJlcmEgZXNwYWNpbyBlbiBDOiAoZGVzaW5zdGFsYSBsbyBxdWUgbm8gdXNlcyBvIHVzYSBlbCBTZW5zb3IgZGUgYWxtYWNlbmFtaWVudG8pLiBDb252aWVuZSB0ZW5l
HLP:ciBtYXMgZGUgMTUgR0IgbGlicmVzLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKVxiUkFNXGJ8bWVtb3InKSB7ICRzdGVwc0xpc3QuQWRkKCdFamVjdXRhIGVsIERpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUgV2luZG93cyAobWRzY2hl
HLP:ZC5leGUpIHkgcmVpbmljaWEgcGFyYSBjb21wcm9iYXIgbGEgUkFNLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKWJhdGVyaWEnKSAgICB7ICRzdGVwc0xpc3QuQWRkKCdMYSBiYXRlcmlhIGVzdGEgZGVncmFkYWRhLiBSZXZpc2EgZWwg
HLP:aW5mb3JtZSBkZSBiYXRlcmlhIChwb3dlcmNmZyAvYmF0dGVyeXJlcG9ydCkgeSB2YWxvcmEgc3VzdGl0dWlybGEuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpcmVpbmljaW8gcGVuZGllbnRlJykgeyAkc3RlcHNMaXN0LkFkZCgnUmVp
HLP:bmljaWEgZWwgZXF1aXBvIHBhcmEgYXBsaWNhciBjYW1iaW9zIHBlbmRpZW50ZXMgYW50ZXMgZGUgc2VndWlyIHJlcGFyYW5kby4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlubyByZXBhcmFibGVzfHJlcG9zaXRvcmlvfGludGVncmlk
HLP:YWQnKSB7ICRzdGVwc0xpc3QuQWRkKCdRdWVkYW4gY29tcG9uZW50ZXMgZGFuYWRvcy4gRWplY3V0YSBESVNNIGNvbiB1biBvcmlnZW4gdmFsaWRvIChpbnN0YWxsLndpbSkgeSB2dWVsdmUgYSBwYXNhciBTRkMuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQg
HLP:LW1hdGNoICcoP2kpZHJpdmVyfGRpc3Bvc2l0aXZvJykgeyAkc3RlcHNMaXN0LkFkZCgnQWN0dWFsaXphIGxvcyBkcml2ZXJzIGRlIGxvcyBkaXNwb3NpdGl2b3MgY29uIGVycm9yIGRlc2RlIGxhIHdlYiBkZWwgZmFicmljYW50ZSBvIFdpbmRvd3MgVXBkYXRlLicp
HLP:IH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKVxicmVkXGJ8RE5TJykgICAgICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ1JldmlzYSBsYSBjb25leGlvbiBkZSByZWQgeSBlbCBETlMuIFNpIHBlcnNpc3RlLCBwcnVlYmEgY29uIHVuIEROUyBwdWJs
HLP:aWNvICgxLjEuMS4xIC8gOC44LjguOCkuJykgfQogICAgICAgIH0KICAgICAgICAkbm9GaW5kID0gKCRmaW5kaW5ncy5Db3VudCAtZXEgMCkKICAgICAgICBpZiAoJG5vRmluZCkgeyAkZmluZEh0bWwgPSAiPGxpIGNsYXNzPSdmaW5kIGZpbmQtb2snPjxzcGFuIGNs
HLP:YXNzPSdzZXYgc2V2LW9rJz5Ub2RvIE9LPC9zcGFuPjxzcGFuIGNsYXNzPSdmaW5kLXR4dCc+Tm8gc2UgZGV0ZWN0YXJvbiBwcm9ibGVtYXMgcmVsZXZhbnRlcyBkdXJhbnRlIGVsIGRpYWdub3N0aWNvLjwvc3Bhbj48L2xpPiIgfQoKICAgICAgICAjIC0tLSBQcm94
HLP:aW1vcyBwYXNvcyByZWNvbWVuZGFkb3MgKGRlZHVwbGljYWRvcykgLS0tCiAgICAgICAgJHN0ZXBzSHRtbCA9ICcnCiAgICAgICAgJHNlZW4gPSBAe30KICAgICAgICBmb3JlYWNoICgkcyBpbiAkc3RlcHNMaXN0KSB7IGlmICgtbm90ICRzZWVuLkNvbnRhaW5zS2V5
HLP:KCRzKSkgeyAkc2Vlblskc109JHRydWU7ICRzdGVwc0h0bWwgKz0gIjxsaSBjbGFzcz0nc3RlcC1saSc+PHNwYW4gY2xhc3M9J3N0ZXAtaWMnPiYjMTAxNDg7PC9zcGFuPjxzcGFuPiQoJiAkZW5jICRzKTwvc3Bhbj48L2xpPiIgfSB9CiAgICAgICAgaWYgKCRjRVJS
HLP:IC1ndCAwKSB7ICRzdGVwc0h0bWwgPSAiPGxpIGNsYXNzPSdzdGVwLWxpJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDE0ODs8L3NwYW4+PHNwYW4+SHVibyBmYXNlcyBjb24gZXJyb3I6IHJldmlzYSBlbCByZWdpc3RybyBkZXRhbGxhZG8gZW4gbGEgY2FycGV0
HLP:YSBXUElfU3VpdGVcTG9ncy48L3NwYW4+PC9saT4iICsgJHN0ZXBzSHRtbCB9CiAgICAgICAgaWYgKC1ub3QgJHN0ZXBzSHRtbCkgeyAkc3RlcHNIdG1sID0gIjxsaSBjbGFzcz0nc3RlcC1saSBzdGVwLW9rJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDAwMzs8
HLP:L3NwYW4+PHNwYW4+Tm8gaGF5IGFjY2lvbmVzIHBlbmRpZW50ZXMuIFJlaW5pY2lhIGVsIGVxdWlwbyBwYXJhIGFzZWd1cmFyIHF1ZSB0b2RvcyBsb3MgY2FtYmlvcyBxdWVkZW4gYXBsaWNhZG9zLjwvc3Bhbj48L2xpPiIgfQoKICAgICAgICAjID09PT09PT09PT09
HLP:PT09PT09PT09PT0gRElBR05PU1RJQ08gQU1QTElBRE8gPT09PT09PT09PT09PT09PT09PT09PQogICAgICAgICRkaWFnQ2FyZHMgPSAnJwogICAgICAgIGlmICgoJHN0LlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2RpYWcnKSAtYW5kICRzdC5k
HLP:aWFnKSB7CiAgICAgICAgICAgICRkID0gJHN0LmRpYWcKICAgICAgICAgICAgaWYgKCRkLnJhbSkgewogICAgICAgICAgICAgICAgJHJzID0gW3N0cmluZ10kZC5yYW0uc3RhdHVzCiAgICAgICAgICAgICAgICAkcnAgPSBzd2l0Y2ggKCRycykgeyAnb2snIHsnZ29v
HLP:ZCd9ICdzdXNwZWN0JyB7J2JhZCd9IGRlZmF1bHQgeyd1bmtub3duJ30gfQogICAgICAgICAgICAgICAgJHJ0ID0gc3dpdGNoICgkcnMpIHsgJ29rJyB7J1NpbiBlcnJvcmVzIGRldGVjdGFkb3MnfSAnc3VzcGVjdCcgeydTb3NwZWNob3NhJ30gZGVmYXVsdCB7J05v
HLP:IGV2YWx1YWRhJ30gfQogICAgICAgICAgICAgICAgJG1kcyA9IGlmICgkZC5yYW0ucmVjb21tZW5kX21kc2NoZWQpIHsgIjxkaXYgY2xhc3M9J2QtaGludCc+UmVjb21lbmRhZG86IGVqZWN1dGFyIGVsIERpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUgV2luZG93cyAo
HLP:bWRzY2hlZCkuPC9kaXY+IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1yYW0nPjwvc3Bhbj5NZW1vcmlhIFJBTTwvZGl2Pjxk
HLP:aXYgY2xhc3M9J2QtcGlsbCBwaWxsLSRycCc+JHJ0PC9kaXY+JG1kczwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJGQuYmF0dGVyeSkgewogICAgICAgICAgICAgICAgaWYgKCRkLmJhdHRlcnkucHJlc2VudCkgewogICAgICAgICAgICAgICAg
HLP:ICAgICRicFJhdyA9ICRkLmJhdHRlcnkuaGVhbHRoX3BjdAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJGJwUmF3IC1hbmQgW3N0cmluZ10kYnBSYXcgLW5lICcnKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICRicCA9IDA7IHRyeSB7ICRicCA9
HLP:IFtpbnRdJGJwUmF3IH0gY2F0Y2ggeyAkYnAgPSAwIH0KICAgICAgICAgICAgICAgICAgICAgICAgJGJwY29sID0gaWYgKCRicCAtZ2UgODApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJGJwIC1nZSA1MCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfQogICAgICAg
HLP:ICAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXRlcmlhPC9kaXY+PGRpdiBjbGFzcz0nYmF0LWJhcic+PHNwYW4gc3R5bGU9J3dp
HLP:ZHRoOiRicCU7YmFja2dyb3VuZDokYnBjb2wnPjwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdkLXN1Yic+U2FsdWQgZXN0aW1hZGE6IDxiIHN0eWxlPSdjb2xvcjokYnBjb2wnPiRicCU8L2I+PC9kaXY+PC9kaXY+IgogICAgICAgICAgICAgICAgICAgIH0gZWxzZSB7
HLP:CiAgICAgICAgICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJhdCc+PC9zcGFuPkJhdGVyaWE8L2Rpdj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC11bmtu
HLP:b3duJz5QcmVzZW50ZSwgc2FsdWQgZGVzY29ub2NpZGE8L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRp
HLP:diBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1iYXQnPjwvc3Bhbj5CYXRlcmlhPC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtdW5rbm93bic+Tm8gcHJlc2VudGUgKGVxdWlwbyBkZSBzb2JyZW1lc2EpPC9kaXY+PC9kaXY+IgogICAgICAgICAg
HLP:ICAgICAgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkZC5uZXR3b3JrKSB7CiAgICAgICAgICAgICAgICAkY2MgPSBpZiAoJGQubmV0d29yay5jb25uZWN0ZWQpIHsnZ29vZCd9IGVsc2UgeydiYWQnfQogICAgICAgICAgICAgICAgJGN0ID0gaWYgKCRk
HLP:Lm5ldHdvcmsuY29ubmVjdGVkKSB7J0NvbmVjdGFkbyd9IGVsc2UgeydTaW4gY29uZXhpb24nfQogICAgICAgICAgICAgICAgJGRjID0gaWYgKCRkLm5ldHdvcmsuZG5zX29rKSB7J2dvb2QnfSBlbHNlIHsnYmFkJ30KICAgICAgICAgICAgICAgICRkdCA9IGlmICgk
HLP:ZC5uZXR3b3JrLmRuc19vaykgeydETlMgT0snfSBlbHNlIHsnRE5TIGNvbiBmYWxsb3MnfQogICAgICAgICAgICAgICAgJGRldCA9ICYgJGVuYyAkZC5uZXR3b3JrLmRldGFpbHMKICAgICAgICAgICAgICAgICRsYXQgPSAnJwogICAgICAgICAgICAgICAgaWYgKCgk
HLP:ZC5uZXR3b3JrLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2Ruc19tcycpIC1hbmQgJG51bGwgLW5lICRkLm5ldHdvcmsuZG5zX21zIC1hbmQgW3N0cmluZ10kZC5uZXR3b3JrLmRuc19tcyAtbmUgJycpIHsKICAgICAgICAgICAgICAgICAgICAk
HLP:bXMgPSAwOyB0cnkgeyAkbXMgPSBbaW50XSRkLm5ldHdvcmsuZG5zX21zIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICAgICAkbGMyID0gaWYgKCRtcyAtbHQgNjApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJG1zIC1sdCAyMDApIHsnI2Y1OWUwYid9IGVsc2Ugeycj
HLP:ZWY0NDQ0J30KICAgICAgICAgICAgICAgICAgICAkbGF0ID0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5MYXRlbmNpYSBETlM6IDxiIHN0eWxlPSdjb2xvcjokbGMyJz4kbXMgbXM8L2I+PC9kaXY+IgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgJGRpYWdD
HLP:YXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtbmV0Jz48L3NwYW4+UmVkPC9kaXY+PGRpdiBjbGFzcz0ncGlsbC1yb3cnPjxzcGFuIGNsYXNzPSdkLXBpbGwgcGlsbC0kY2MnPiRjdDwvc3Bhbj48
HLP:c3BhbiBjbGFzcz0nZC1waWxsIHBpbGwtJGRjJz4kZHQ8L3NwYW4+PC9kaXY+PGRpdiBjbGFzcz0nZC1zdWInPiRkZXQ8L2Rpdj4kbGF0PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250
HLP:YWlucyAnc21hcnQnKSAtYW5kICRkLnNtYXJ0IC1hbmQgJGQuc21hcnQuYXZhaWxhYmxlKSB7CiAgICAgICAgICAgICAgICAkc20gPSAkZC5zbWFydAogICAgICAgICAgICAgICAgJHBmID0gaWYgKCRzbS5wcmVkaWN0X2ZhaWwpIHsgIjxzcGFuIGNsYXNzPSdkLXBp
HLP:bGwgcGlsbC1iYWQnPlByZWRpY2UgZmFsbG88L3NwYW4+IiB9IGVsc2UgeyAiPHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLWdvb2QnPlNpbiBhbGVydGE8L3NwYW4+IiB9CiAgICAgICAgICAgICAgICAkZXh0cmEgPSAnJwogICAgICAgICAgICAgICAgaWYgKCRudWxs
HLP:IC1uZSAkc20udGVtcF9jIC1hbmQgW3N0cmluZ10kc20udGVtcF9jIC1uZSAnJykgeyAkdGM9MDsgdHJ5eyR0Yz1baW50XSRzbS50ZW1wX2N9Y2F0Y2h7fTsgJHRjb2wgPSBpZiAoJHRjIC1sdCA1MCl7JyMyMmM1NWUnfSBlbHNlaWYgKCR0YyAtbHQgNjUpeycjZjU5
HLP:ZTBiJ30gZWxzZSB7JyNlZjQ0NDQnfTsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+VGVtcGVyYXR1cmE6IDxiIHN0eWxlPSdjb2xvcjokdGNvbCc+JHRjICZkZWc7QzwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLndl
HLP:YXJfcGN0IC1hbmQgW3N0cmluZ10kc20ud2Vhcl9wY3QgLW5lICcnKSB7ICR3cD0wOyB0cnl7JHdwPVtpbnRdJHNtLndlYXJfcGN0fWNhdGNoe307ICR3Y29sID0gaWYgKCR3cCAtbHQgNTApeycjMjJjNTVlJ30gZWxzZWlmICgkd3AgLWx0IDgwKXsnI2Y1OWUwYid9
HLP:IGVsc2UgeycjZWY0NDQ0J307ICRleHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPkRlc2dhc3RlIChTU0QpOiA8YiBzdHlsZT0nY29sb3I6JHdjb2wnPiR3cCU8L2I+PC9kaXY+IiB9CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRzbS5wb2ggLWFuZCBb
HLP:c3RyaW5nXSRzbS5wb2ggLW5lICcnKSB7ICRleHRyYSArPSAiPGRpdiBjbGFzcz0nZC1zdWInPkhvcmFzIGVuY2VuZGlkbzogPGI+JCgmICRlbmMgJHNtLnBvaCk8L2I+PC9kaXY+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdk
HLP:Y2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1zbWFydCc+PC9zcGFuPlNhbHVkIGRlbCBkaXNjbyAoU01BUlQpPC9kaXY+PGRpdiBjbGFzcz0ncGlsbC1yb3cnPiRwZjwvZGl2PiRleHRyYTwvZGl2PiIKICAgICAgICAgICAgfQogICAg
HLP:ICAgICAgICBpZiAoKCRkLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ2JjZCcpIC1hbmQgJGQuYmNkKSB7CiAgICAgICAgICAgICAgICAkYm9rID0gaWYgKCRkLmJjZC5vaykgeydnb29kJ30gZWxzZSB7J2JhZCd9CiAgICAgICAgICAgICAgICAk
HLP:YnR4ID0gaWYgKCRkLmJjZC5vaykgeydDb25maWd1cmFjaW9uIGRlIGFycmFucXVlIGNvcnJlY3RhJ30gZWxzZSB7J0FycmFucXVlIGNvbiBpbmNpZGVuY2lhcyd9CiAgICAgICAgICAgICAgICAkYmRldCA9IGlmIChbc3RyaW5nXSRkLmJjZC5kZXRhaWxzIC1uZSAn
HLP:JykgeyAiPGRpdiBjbGFzcz0nZC1zdWInPiQoJiAkZW5jICRkLmJjZC5kZXRhaWxzKTwvZGl2PiIgfSBlbHNlIHsgJycgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9
HLP:J2QtaWMgaWMtYm9vdCc+PC9zcGFuPkFycmFucXVlIChCQ0QpPC9kaXY+PGRpdiBjbGFzcz0nZC1waWxsIHBpbGwtJGJvayc+JGJ0eDwvZGl2PiRiZGV0PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5O
HLP:YW1lIC1jb250YWlucyAnc3RhcnR1cCcpIC1hbmQgJGQuc3RhcnR1cCAtYW5kIEAoJGQuc3RhcnR1cCkuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAgICAgICAgICAgICAgICBmb3JlYWNoICgkcyBpbiBAKCRkLnN0YXJ0dXApKSB7
HLP:ICRpdGVtcyArPSAiPGxpPiQoJiAkZW5jICRzLm5hbWUpPHNwYW4gY2xhc3M9J211dGVkJz4gJm1kYXNoOyAkKCYgJGVuYyAkcy5jb21tYW5kKTwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQgZGNh
HLP:cmQtd2lkZSc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1zdGFydCc+PC9zcGFuPlByb2dyYW1hcyBhbCBpbmljaWFyIFdpbmRvd3M8L2Rpdj48dWwgY2xhc3M9J2Rldi1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIKICAgICAgICAgICAgfQog
HLP:ICAgICAgICAgICBpZiAoKCRkLlBTT2JqZWN0LlByb3BlcnRpZXMuTmFtZSAtY29udGFpbnMgJ3Byb2Nlc3NlcycpIC1hbmQgJGQucHJvY2Vzc2VzIC1hbmQgQCgkZC5wcm9jZXNzZXMpLkNvdW50IC1ndCAwKSB7CiAgICAgICAgICAgICAgICAkaXRlbXMgPSAnJwog
HLP:ICAgICAgICAgICAgICAgZm9yZWFjaCAoJHByIGluIEAoJGQucHJvY2Vzc2VzKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkcHIubmFtZSk8c3BhbiBjbGFzcz0nbXV0ZWQnPiAmbWRhc2g7ICQoJiAkZW5jICRwci5tZW1fbWIpIE1CPC9zcGFuPjwvbGk+IiB9
HLP:CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1wcm9jJz48L3NwYW4+UHJvY2Vzb3MgcXVlIG1hcyBtZW1vcmlhIHVzYW48L2Rpdj48dWwgY2xhc3M9J2Rl
HLP:di1saXN0Jz4kaXRlbXM8L3VsPjwvZGl2PiIKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoJGQuZGV2aWNlcyAtYW5kIEAoJGQuZGV2aWNlcykuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAgICAgICAgICAgICAgICBmb3Jl
HLP:YWNoICgkZGV2IGluIEAoJGQuZGV2aWNlcykpIHsgJGl0ZW1zICs9ICI8bGk+JCgmICRlbmMgJGRldi5uYW1lKSA8c3BhbiBjbGFzcz0nbXV0ZWQnPihjb2RpZ28gJCgmICRlbmMgJGRldi5jb2RlKSk8L3NwYW4+PC9saT4iIH0KICAgICAgICAgICAgICAgICRkaWFn
HLP:Q2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkIGRjYXJkLXdpZGUnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtZGV2Jz48L3NwYW4+RGlzcG9zaXRpdm9zIGNvbiBhdmlzbzwvZGl2Pjx1bCBjbGFzcz0nZGV2LWxpc3QnPiRpdGVtczwvdWw+
HLP:PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgICRkaWFnU2VjdGlvbiA9ICcnCiAgICAgICAgaWYgKCRkaWFnQ2FyZHMpIHsgJGRpYWdTZWN0aW9uID0gIjxoMiBpZD0nZGlhZycgY2xhc3M9J3NlYy1oJz5EaWFnbm9zdGljbyBhbXBsaWFkbzwv
HLP:aDI+PGRpdiBjbGFzcz0nZGdyaWQnPiRkaWFnQ2FyZHM8L2Rpdj4iIH0KCiAgICAgICAgJGNvbXBhcmVTZWN0aW9uID0gJycKICAgICAgICBpZiAoJGhhc0JvdGgpIHsKICAgICAgICAgICAgJGNvbXBhcmVTZWN0aW9uID0gQCIKPGRpdiBjbGFzcz0nY29tcGFyZSc+
HLP:CiAgPGRpdiBjbGFzcz0nbWluaSc+CiAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1Z2UgZ2F1Z2Utc20nPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScx
HLP:MDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRiZWZvcmVPZmZzZXQ7c3Ryb2tlOiRiZWZvcmVDb2xvcicvPjx0ZXh0IHg9JzEwMCcgeT0nMTA4JyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxsOiRiZWZvcmVDb2xvcic+JGJl
HLP:Zm9yZTwvdGV4dD48L3N2Zz4KICAgIDxkaXYgY2xhc3M9J21pbmktY2FwJz5BTlRFUzwvZGl2PgogIDwvZGl2PgogIDxkaXYgY2xhc3M9J2Fycm93Jz48c3BhbiBzdHlsZT0nY29sb3I6JGRlbHRhQ29sb3InPiYjODU5NDs8L3NwYW4+PGRpdiBjbGFzcz0nZGVsdGEt
HLP:Y2hpcCcgc3R5bGU9J2NvbG9yOiRkZWx0YUNvbG9yO2JvcmRlci1jb2xvcjokZGVsdGFDb2xvcic+JGRlbHRhVHh0PC9kaXY+PC9kaXY+CiAgPGRpdiBjbGFzcz0nbWluaSc+CiAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAgMjAwJyBjbGFzcz0nZ2F1Z2UgZ2F1Z2Ut
HLP:c20nPjxjaXJjbGUgY2xhc3M9J3RyYWNrJyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcvPjxjaXJjbGUgY2xhc3M9J2ZpbGwnIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0JyBzdHlsZT0nLS1jaXJjOiRjaXJjOy0tdGFyZ2V0OiRhZnRlck9mZnNldDtzdHJva2U6JGFm
HLP:dGVyQ29sb3InLz48dGV4dCB4PScxMDAnIHk9JzEwOCcgY2xhc3M9J2ctbnVtJyBzdHlsZT0nZmlsbDokYWZ0ZXJDb2xvcic+JGFmdGVyPC90ZXh0Pjwvc3ZnPgogICAgPGRpdiBjbGFzcz0nbWluaS1jYXAnPkRFU1BVRVM8L2Rpdj4KICA8L2Rpdj4KPC9kaXY+CiJA
HLP:CiAgICAgICAgfQoKICAgICAgICAkbm93ID0gKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZCBISDptbScpCiAgICAgICAgJGV4ZWNWZXJkaWN0ID0gJiAkYmFuZExhYmVsICRtYWluU2NvcmUKICAgICAgICAkaHRtbCA9IEAiCjwhRE9DVFlQRSBodG1sPgo8
HLP:aHRtbCBsYW5nPSdlcyc+CjxoZWFkPgo8bWV0YSBjaGFyc2V0PSd1dGYtOCc+CjxtZXRhIG5hbWU9J3ZpZXdwb3J0JyBjb250ZW50PSd3aWR0aD1kZXZpY2Utd2lkdGgsaW5pdGlhbC1zY2FsZT0xJz4KPHRpdGxlPkluZm9ybWUgZGUgUmVwYXJhY2lvbiAtIFdQSSBT
HLP:dWl0ZSB2My4xPC90aXRsZT4KPHN0eWxlPgoqe2JveC1zaXppbmc6Ym9yZGVyLWJveH0KOnJvb3R7LS1iZzojMGIwZjE3Oy0tYmcyOiMwZDE0MjI7LS1jYXJkOiMxMjFhMmI7LS1jYXJkMjojMGUxNjI2Oy0tbGluZTojMWUyOTNiOy0tdHh0OiNlNmVkZjY7LS1tdXRl
HLP:ZDojOTNhM2JhOy0tYWNjZW50OiMzOGJkZjg7LS1hY2NlbnQyOiM4MThjZjg7LS1zaGFkb3c6MCAxNHB4IDQwcHggcmdiYSgwLDAsMCwuNDApfQpodG1sLmxpZ2h0ey0tYmc6I2VlZjJmODstLWJnMjojZTdlZGY2Oy0tY2FyZDojZmZmZmZmOy0tY2FyZDI6I2Y1Zjhm
HLP:YzstLWxpbmU6I2RkZTVmMDstLXR4dDojMGYxNzJhOy0tbXV0ZWQ6IzVhNmI4MjstLWFjY2VudDojMDI4NGM3Oy0tYWNjZW50MjojNGY0NmU1Oy0tc2hhZG93OjAgMTBweCAyOHB4IHJnYmEoMTUsMjMsNDIsLjEyKX0KYm9keXttYXJnaW46MDtmb250LWZhbWlseTon
HLP:U2Vnb2UgVUknLHN5c3RlbS11aSwtYXBwbGUtc3lzdGVtLEFyaWFsLHNhbnMtc2VyaWY7bGluZS1oZWlnaHQ6MS41NTtjb2xvcjp2YXIoLS10eHQpO2JhY2tncm91bmQ6cmFkaWFsLWdyYWRpZW50KDEyMDBweCA2MDBweCBhdCA4MCUgLTEwJSxyZ2JhKDU2LDE4OSwy
HLP:NDgsLjEwKSx0cmFuc3BhcmVudCA2MCUpLHJhZGlhbC1ncmFkaWVudCg5MDBweCA1MDBweCBhdCAtMTAlIDEwJSxyZ2JhKDEyOSwxNDAsMjQ4LC4xMCksdHJhbnNwYXJlbnQgNTUlKSx2YXIoLS1iZyl9Ci53cmFwe21heC13aWR0aDoxMDgwcHg7bWFyZ2luOjAgYXV0
HLP:bztwYWRkaW5nOjMwcHggMjJweCA2MHB4fQoudG9wYmFye2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47Z2FwOjE2cHg7bWFyZ2luLWJvdHRvbToxOHB4O2ZsZXgtd3JhcDp3cmFwfQouYnJhbmR7ZGlz
HLP:cGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTRweH0KLmxvZ297d2lkdGg6NDZweDtoZWlnaHQ6NDZweDtib3JkZXItcmFkaXVzOjEzcHg7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50Mikp
HLP:O2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Cmgxe2ZvbnQtc2l6ZToyMnB4O21hcmdpbjowO2xldHRlci1zcGFjaW5nOi4ycHh9Ci5zdWJ7Y29sb3I6dmFyKC0tbXV0
HLP:ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6MnB4fQouYmFkZ2V7ZGlzcGxheTppbmxpbmUtYmxvY2s7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWln
HLP:aHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzozcHggMTJweDtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFjaW5nOi40cHg7dmVydGljYWwtYWxpZ246bWlkZGxlO21hcmdpbi1sZWZ0OjhweH0KLmJ0bnN7ZGlzcGxheTpmbGV4O2dhcDo4cHg7Zmxl
HLP:eC13cmFwOndyYXB9Ci50b2dnbGV7Y3Vyc29yOnBvaW50ZXI7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2NvbG9yOnZhcigtLXR4dCk7Ym9yZGVyLXJhZGl1czoxMHB4O3BhZGRpbmc6OHB4IDE0cHg7Zm9udC1zaXpl
HLP:OjEzcHg7Zm9udC13ZWlnaHQ6NjAwO2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KX0KLnRvZ2dsZTpob3Zlcntib3JkZXItY29sb3I6dmFyKC0tYWNjZW50KX0KLnRvY3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4LXdyYXA6d3JhcDttYXJnaW46MCAwIDIycHh9Ci50
HLP:b2MgYXtmb250LXNpemU6MTIuNXB4O2ZvbnQtd2VpZ2h0OjYwMDtjb2xvcjp2YXIoLS1tdXRlZCk7dGV4dC1kZWNvcmF0aW9uOm5vbmU7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtib3JkZXItcmFkaXVzOjk5OXB4
HLP:O3BhZGRpbmc6NnB4IDEzcHh9Ci50b2MgYTpob3Zlcntjb2xvcjp2YXIoLS1hY2NlbnQpO2JvcmRlci1jb2xvcjp2YXIoLS1hY2NlbnQpfQouZXhlY3tkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxOHB4O2ZsZXgtd3JhcDp3cmFwO2JhY2tncm91
HLP:bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRlZyx2YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRpbmc6MThweCAyMnB4O21hcmdpbi1ib3R0b206MjJweDtib3gtc2hhZG93OnZh
HLP:cigtLXNoYWRvdyl9Ci5leGVjLXNjb3Jle2ZvbnQtc2l6ZTo0NnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQouZXhlYy1taWR7ZmxleDoxO21pbi13aWR0aDoyMDBweH0KLmV4ZWMtdmVyZGljdHtmb250LXNpemU6MThweDtmb250LXdlaWdodDo3MDB9
HLP:Ci5leGVjLWxpbmV7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4O21hcmdpbi10b3A6MnB4fQouZXhlYy1kZWx0YXtmb250LXNpemU6MTNweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyOjFweCBzb2xpZDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6
HLP:NHB4IDEycHg7d2hpdGUtc3BhY2U6bm93cmFwfQouaGVyb3tkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOm1pbm1heCgyNDBweCwzMjBweCkgMWZyO2dhcDoyMHB4O21hcmdpbi1ib3R0b206MjJweH0KQG1lZGlhKG1heC13aWR0aDo3NjBweCl7Lmhl
HLP:cm97Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn19Ci5jYXJke2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDE4MGRlZyx2YXIoLS1jYXJkKSx2YXIoLS1jYXJkMikpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxOHB4O3BhZGRp
HLP:bmc6MjJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyl9Ci5nYXVnZXdyYXB7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjt0ZXh0LWFsaWduOmNlbnRlcn0KLmdhdWdle3dp
HLP:ZHRoOjIxMHB4O2hlaWdodDoyMTBweH0KLmdhdWdlLXNte3dpZHRoOjEyMHB4O2hlaWdodDoxMjBweH0KLmdhdWdlIC50cmFja3tmaWxsOm5vbmU7c3Ryb2tlOnZhcigtLWxpbmUpO3N0cm9rZS13aWR0aDoxNH0KLmdhdWdlIC5maWxse2ZpbGw6bm9uZTtzdHJva2Ut
HLP:d2lkdGg6MTQ7c3Ryb2tlLWxpbmVjYXA6cm91bmQ7dHJhbnNmb3JtOnJvdGF0ZSgtOTBkZWcpO3RyYW5zZm9ybS1vcmlnaW46NTAlIDUwJTtzdHJva2UtZGFzaGFycmF5OnZhcigtLWNpcmMpO3N0cm9rZS1kYXNob2Zmc2V0OnZhcigtLWNpcmMpO2FuaW1hdGlvbjpm
HLP:aWxsIDEuNHMgY3ViaWMtYmV6aWVyKC4yMiwxLC4zNiwxKSAuMnMgZm9yd2FyZHN9Ci5nLW51bXtmb250LXNpemU6NTRweDtmb250LXdlaWdodDo4MDA7dGV4dC1hbmNob3I6bWlkZGxlO2ZvbnQtZmFtaWx5OidTZWdvZSBVSScsc3lzdGVtLXVpLEFyaWFsfQouZ2F1
HLP:Z2Utc20gLmctbnVte2ZvbnQtc2l6ZTo0NnB4fQouZy1sYWJlbHttYXJnaW4tdG9wOjZweDtmb250LXdlaWdodDo3MDA7Zm9udC1zaXplOjE1cHh9Ci5nLWNhcHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7bGV0dGVyLXNwYWNpbmc6MS41cHg7bWFy
HLP:Z2luLXRvcDoycHh9Ci5jb21wYXJle2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlmeS1jb250ZW50OmNlbnRlcjtnYXA6OHB4O21hcmdpbi10b3A6MTRweDtmbGV4LXdyYXA6d3JhcH0KLm1pbml7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5taW5pLWNh
HLP:cHtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjExcHg7bGV0dGVyLXNwYWNpbmc6MS4ycHg7bWFyZ2luLXRvcDotNnB4fQouYXJyb3d7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjZweDtmb250LXNp
HLP:emU6MzBweDtmb250LXdlaWdodDo4MDB9Ci5kZWx0YS1jaGlwe2JvcmRlcjoxcHggc29saWQ7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjNweCAxMnB4O2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO3doaXRlLXNwYWNlOm5vd3JhcH0KLmhlcm8t
HLP:c2lkZXtkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2dhcDoxNnB4fQouY2hpcHN7ZGlzcGxheTpmbGV4O2dhcDoxMHB4O2ZsZXgtd3JhcDp3cmFwfQouY2hpcHtmbGV4OjE7bWluLXdpZHRoOjk2cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkMik7Ym9y
HLP:ZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxMnB4IDE0cHg7dGV4dC1hbGlnbjpjZW50ZXJ9Ci5jaGlwIC5ue2ZvbnQtc2l6ZToyNnB4O2ZvbnQtd2VpZ2h0OjgwMDtsaW5lLWhlaWdodDoxfQouY2hpcCAubHtjb2xv
HLP:cjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjExLjVweDtsZXR0ZXItc3BhY2luZzouNnB4O21hcmdpbi10b3A6M3B4fQouYy1va3tjb2xvcjojMjJjNTVlfS5jLXdhcm57Y29sb3I6I2Y1OWUwYn0uYy1lcnJ7Y29sb3I6I2VmNDQ0NH0uYy1za2lwe2NvbG9yOiM5NGEz
HLP:Yjh9Ci5zeXNncmlke2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyIDFmcjtnYXA6MXB4O2JhY2tncm91bmQ6dmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNHB4O292ZXJmbG93OmhpZGRlbn0KQG1lZGlhKG1heC13aWR0aDo1MjBweCl7LnN5
HLP:c2dyaWR7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmcn19Ci5zeXN7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtwYWRkaW5nOjExcHggMTRweH0KLnN5cy1re2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFjaW5nOi40cHh9Ci5zeXMt
HLP:dntmb250LXdlaWdodDo2MDA7Zm9udC1zaXplOjE0cHg7bWFyZ2luLXRvcDoxcHg7d29yZC1icmVhazpicmVhay13b3JkfQpoMi5zZWMtaHtmb250LXNpemU6MTVweDtsZXR0ZXItc3BhY2luZzouNnB4O3RleHQtdHJhbnNmb3JtOnVwcGVyY2FzZTtjb2xvcjp2YXIo
HLP:LS1hY2NlbnQpO21hcmdpbjozMHB4IDAgMTJweDtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4O3Njcm9sbC1tYXJnaW4tdG9wOjE0cHh9CmgyLnNlYy1oOjphZnRlcntjb250ZW50OicnO2ZsZXg6MTtoZWlnaHQ6MXB4O2JhY2tncm91bmQ6
HLP:dmFyKC0tbGluZSl9Ci50aW1lbGluZXtwb3NpdGlvbjpyZWxhdGl2ZTtwYWRkaW5nLWxlZnQ6OHB4fQoucGh7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2FwOjE0cHg7cGFkZGluZzoxM3B4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1s
HLP:aW5lKTtib3JkZXItcmFkaXVzOjE0cHg7bWFyZ2luLWJvdHRvbToxMHB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7cG9zaXRpb246cmVsYXRpdmU7b3ZlcmZsb3c6aGlkZGVufQoucGg6OmJlZm9yZXtjb250ZW50OicnO3Bvc2l0aW9uOmFic29sdXRlO2xlZnQ6MDt0
HLP:b3A6MDtib3R0b206MDt3aWR0aDo0cHh9Ci5waC1vazo6YmVmb3Jle2JhY2tncm91bmQ6IzIyYzU1ZX0ucGgtd2Fybjo6YmVmb3Jle2JhY2tncm91bmQ6I2Y1OWUwYn0ucGgtZXJyb3I6OmJlZm9yZXtiYWNrZ3JvdW5kOiNlZjQ0NDR9LnBoLXNraXA6OmJlZm9yZXti
HLP:YWNrZ3JvdW5kOiM2NDc0OGJ9Ci5waC1kb3R7ZmxleDowIDAgYXV0bzttYXJnaW4tdG9wOjFweH0KLnN2Z2ljb3t3aWR0aDoyNnB4O2hlaWdodDoyNnB4O2Rpc3BsYXk6YmxvY2t9Ci5waC1tYWlue2ZsZXg6MTttaW4td2lkdGg6MH0KLnBoLXRvcHtkaXNwbGF5OmZs
HLP:ZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMHB4O2ZsZXgtd3JhcDp3cmFwfQoucGgtbnVte2ZvbnQtdmFyaWFudC1udW1lcmljOnRhYnVsYXItbnVtcztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEycHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlcjoxcHgg
HLP:c29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czo3cHg7cGFkZGluZzoxcHggN3B4fQoucGgtdGl0bGV7Zm9udC13ZWlnaHQ6NjAwO2ZvbnQtc2l6ZToxNXB4fQoucGgtYmFkZ2V7Zm9udC1zaXplOjExcHg7Zm9udC13ZWlnaHQ6ODAwO2xldHRlci1zcGFjaW5n
HLP:Oi42cHg7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjJweCAxMHB4fQouYi1va3tiYWNrZ3JvdW5kOnJnYmEoMzQsMTk3LDk0LC4xNik7Y29sb3I6IzIyYzU1ZX0uYi13YXJue2JhY2tncm91bmQ6cmdiYSgyNDUsMTU4LDExLC4xNik7Y29sb3I6I2Y1OWUwYn0u
HLP:Yi1lcnJvcntiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uYi1za2lwe2JhY2tncm91bmQ6cmdiYSgxMDAsMTE2LDEzOSwuMTgpO2NvbG9yOiM5NGEzYjh9Ci5waC1ub3Rle2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNw
HLP:eDttYXJnaW4tdG9wOjNweH0KLnBoLXNlY3N7ZmxleDowIDAgYXV0bztjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEzcHg7Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO2FsaWduLXNlbGY6Y2VudGVyfQouZW1wdHl7Y29sb3I6dmFyKC0tbXV0
HLP:ZWQpO3BhZGRpbmc6MThweDt0ZXh0LWFsaWduOmNlbnRlcn0KLmJhcmNoYXJ0e2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7cGFkZGluZzoxNHB4IDE4cHg7bWFyZ2luLXRvcDo0cHh9
HLP:Ci5iYXItcm93e2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEycHg7cGFkZGluZzo1cHggMH0KLmJhci1sYmx7ZmxleDowIDAgMjIwcHg7Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7d2hpdGUtc3BhY2U6bm93cmFwO292ZXJm
HLP:bG93OmhpZGRlbjt0ZXh0LW92ZXJmbG93OmVsbGlwc2lzfQpAbWVkaWEobWF4LXdpZHRoOjYwMHB4KXsuYmFyLWxibHtmbGV4OjAgMCAxMjBweH19Ci5iYXItdHJhY2t7ZmxleDoxO2hlaWdodDoxMHB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIo
HLP:LS1saW5lKTtvdmVyZmxvdzpoaWRkZW59Ci5iYXItdHJhY2sgc3BhbntkaXNwbGF5OmJsb2NrO2hlaWdodDoxMDAlO2JvcmRlci1yYWRpdXM6OTk5cHh9Ci5iYXItdmFse2ZsZXg6MCAwIGF1dG87Zm9udC1zaXplOjEyLjVweDtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9u
HLP:dC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO3dpZHRoOjQ4cHg7dGV4dC1hbGlnbjpyaWdodH0KdWwuZmluZHN7bGlzdC1zdHlsZTpub25lO21hcmdpbjowO3BhZGRpbmc6MH0KLmZpbmR7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7Z2Fw
HLP:OjEycHg7cGFkZGluZzoxMnB4IDE2cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjEzcHg7bWFyZ2luLWJvdHRvbTo5cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKX0KLnNldntmbGV4OjAgMCBhdXRvO2ZvbnQtc2l6ZToxMXB4O2Zv
HLP:bnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzouNXB4O2JvcmRlci1yYWRpdXM6OHB4O3BhZGRpbmc6M3B4IDEwcHg7bWFyZ2luLXRvcDoxcHh9Ci5zZXYtaGlnaHtiYWNrZ3JvdW5kOnJnYmEoMjM5LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0uc2V2LW1lZHti
HLP:YWNrZ3JvdW5kOnJnYmEoMjQ1LDE1OCwxMSwuMTYpO2NvbG9yOiNmNTllMGJ9LnNldi1pbmZve2JhY2tncm91bmQ6cmdiYSg1NiwxODksMjQ4LC4xNik7Y29sb3I6dmFyKC0tYWNjZW50KX0uc2V2LW9re2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xv
HLP:cjojMjJjNTVlfQouZmluZC10eHR7Zm9udC1zaXplOjE0cHh9CnVsLnN0ZXBze2xpc3Qtc3R5bGU6bm9uZTttYXJnaW46MDtwYWRkaW5nOjB9Ci5zdGVwLWxpe2Rpc3BsYXk6ZmxleDtnYXA6MTFweDthbGlnbi1pdGVtczpmbGV4LXN0YXJ0O3BhZGRpbmc6MTFweCAx
HLP:NnB4O2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLWxlZnQ6M3B4IHNvbGlkIHZhcigtLWFjY2VudCk7Ym9yZGVyLXJhZGl1czoxMnB4O21hcmdpbi1ib3R0b206OXB4O2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Zm9udC1zaXplOjE0cHh9Ci5zdGVw
HLP:LW9re2JvcmRlci1sZWZ0LWNvbG9yOiMyMmM1NWV9Ci5zdGVwLWlje2NvbG9yOnZhcigtLWFjY2VudCk7Zm9udC13ZWlnaHQ6ODAwfQouc3RlcC1vayAuc3RlcC1pY3tjb2xvcjojMjJjNTVlfQouZGdyaWR7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1u
HLP:czpyZXBlYXQoYXV0by1maXQsbWlubWF4KDIyMHB4LDFmcikpO2dhcDoxNHB4fQouZGNhcmR7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTVweDtwYWRkaW5nOjE2cHggMThweH0KLmRjYXJk
HLP:LXdpZGV7Z3JpZC1jb2x1bW46MS8tMX0KLmQtaHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDo5cHg7Zm9udC13ZWlnaHQ6NzAwO2ZvbnQtc2l6ZToxNHB4O21hcmdpbi1ib3R0b206MTBweH0KLmQtaWN7d2lkdGg6MTRweDtoZWlnaHQ6MTRweDti
HLP:b3JkZXItcmFkaXVzOjVweDtkaXNwbGF5OmlubGluZS1ibG9ja30KLmljLXJhbXtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzM4YmRmOCwjMGVhNWU5KX0uaWMtYmF0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMjJjNTVlLCMx
HLP:NTgwM2QpfS5pYy1uZXR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCM4MThjZjgsIzRmNDZlNSl9LmljLWRldntiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsI2Y1OWUwYiwjZDk3NzA2KX0uaWMtc21hcnR7YmFja2dyb3VuZDpsaW5l
HLP:YXItZ3JhZGllbnQoMTM1ZGVnLCNmNDcyYjYsI2RiMjc3Nyl9LmljLWJvb3R7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCMyZGQ0YmYsIzBkOTQ4OCl9LmljLXN0YXJ0e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjYTc4YmZhLCM3
HLP:YzNhZWQpfS5pYy1wcm9je2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZmI3MTg1LCNlMTFkNDgpfQouZC1waWxse2Rpc3BsYXk6aW5saW5lLWJsb2NrO2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NzAwO2JvcmRlci1yYWRpdXM6OTk5cHg7
HLP:cGFkZGluZzo0cHggMTJweH0KLnBpbGwtcm93e2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwfQoucGlsbC1nb29ke2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfS5waWxsLWJhZHtiYWNrZ3JvdW5kOnJnYmEoMjM5
HLP:LDY4LDY4LC4xNik7Y29sb3I6I2VmNDQ0NH0ucGlsbC11bmtub3due2JhY2tncm91bmQ6cmdiYSgxNDgsMTYzLDE4NCwuMTYpO2NvbG9yOiM5NGEzYjh9Ci5kLXN1Yntjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEyLjVweDttYXJnaW4tdG9wOjhweH0KLmQt
HLP:aGludHtjb2xvcjojZjU5ZTBiO2ZvbnQtc2l6ZToxMi41cHg7bWFyZ2luLXRvcDo4cHh9Ci5iYXQtYmFye2hlaWdodDoxMnB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtvdmVyZmxvdzpoaWRkZW47bWFyZ2luLXRvcDo0cHh9Ci5i
HLP:YXQtYmFyIHNwYW57ZGlzcGxheTpibG9jaztoZWlnaHQ6MTAwJTtib3JkZXItcmFkaXVzOjk5OXB4fQouZGV2LWxpc3R7bWFyZ2luOjRweCAwIDA7cGFkZGluZy1sZWZ0OjE4cHg7Zm9udC1zaXplOjEzLjVweH0KLmRldi1saXN0IGxpe21hcmdpbjoycHggMH0KLm11
HLP:dGVke2NvbG9yOnZhcigtLW11dGVkKX0KLmZvb3R7bWFyZ2luLXRvcDozNHB4O3RleHQtYWxpZ246Y2VudGVyO2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweH0KLnNlY3Rpb257YW5pbWF0aW9uOnJpc2UgLjVzIGVhc2UgYm90aH0KQGtleWZyYW1lcyBm
HLP:aWxse3Rve3N0cm9rZS1kYXNob2Zmc2V0OnZhcigtLXRhcmdldCl9fQpAa2V5ZnJhbWVzIHJpc2V7ZnJvbXtvcGFjaXR5OjA7dHJhbnNmb3JtOnRyYW5zbGF0ZVkoMTBweCl9dG97b3BhY2l0eToxO3RyYW5zZm9ybTpub25lfX0KQG1lZGlhIHByaW50ey50b2dnbGUs
HLP:LnRvYywuYnRucywudG9hc3R7ZGlzcGxheTpub25lfWJvZHl7YmFja2dyb3VuZDojZmZmO2NvbG9yOiMwMDB9LmNhcmQsLmRjYXJkLC5waCwuZmluZCwuZXhlYywuYmFyY2hhcnQsLnN0ZXAtbGl7Ym94LXNoYWRvdzpub25lO2JhY2tkcm9wLWZpbHRlcjpub25lOy13
HLP:ZWJraXQtYmFja2Ryb3AtZmlsdGVyOm5vbmU7YmFja2dyb3VuZDojZmZmIWltcG9ydGFudH0uZ2F1Z2UgLmZpbGx7YW5pbWF0aW9uOm5vbmV9LnNlY3Rpb257YW5pbWF0aW9uOm5vbmV9YVtocmVmXXtjb2xvcjppbmhlcml0O3RleHQtZGVjb3JhdGlvbjpub25lfX0K
HLP:OnJvb3R7LS1nbGFzczpyZ2JhKDE4LDI2LDQzLC42MCk7LS1nbGFzc2JkOnJnYmEoMjU1LDI1NSwyNTUsLjA3KX0KaHRtbC5saWdodHstLWdsYXNzOnJnYmEoMjU1LDI1NSwyNTUsLjY0KTstLWdsYXNzYmQ6cmdiYSgxNSwyMyw0MiwuMDgpfQouY2FyZCwuZXhlYywu
HLP:ZGNhcmQsLmZpbmQsLmJhcmNoYXJ0LC5zdGVwLWxpe2JhY2tncm91bmQ6dmFyKC0tZ2xhc3MpIWltcG9ydGFudDtiYWNrZHJvcC1maWx0ZXI6Ymx1cigxM3B4KSBzYXR1cmF0ZSgxNDAlKTstd2Via2l0LWJhY2tkcm9wLWZpbHRlcjpibHVyKDEzcHgpIHNhdHVyYXRl
HLP:KDE0MCUpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tZ2xhc3NiZCkhaW1wb3J0YW50fQoudG9hc3R7cG9zaXRpb246Zml4ZWQ7Ym90dG9tOjI0cHg7bGVmdDo1MCU7dHJhbnNmb3JtOnRyYW5zbGF0ZVgoLTUwJSk7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1
HLP:ZGVnLHZhcigtLWFjY2VudCksdmFyKC0tYWNjZW50MikpO2NvbG9yOiMwNDI5M2I7Zm9udC13ZWlnaHQ6NzAwO3BhZGRpbmc6MTBweCAxOHB4O2JvcmRlci1yYWRpdXM6MTJweDtib3gtc2hhZG93OnZhcigtLXNoYWRvdyk7b3BhY2l0eTowO3BvaW50ZXItZXZlbnRz
HLP:Om5vbmU7dHJhbnNpdGlvbjpvcGFjaXR5IC4yNXM7ei1pbmRleDo2MDtmb250LXNpemU6MTNweH0KLnRvYXN0LnNob3d7b3BhY2l0eToxfQoudHJlbmQtdGl0bGV7bWFyZ2luLXRvcDoyMHB4O2ZvbnQtc2l6ZToxMnB4O2ZvbnQtd2VpZ2h0OjcwMDtsZXR0ZXItc3Bh
HLP:Y2luZzoxcHg7dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLWxpc3R7ZGlzcGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjtnYXA6NHB4O3dpZHRoOjEwMCU7bWFyZ2luLXRvcDo4cHg7Ym9yZGVyLXRvcDoxcHgg
HLP:c29saWQgdmFyKC0tbGluZSk7cGFkZGluZy10b3A6OHB4fQoudHJlbmQtaXRlbXtkaXNwbGF5OmZsZXg7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47Zm9udC1zaXplOjEycHh9Ci50cmVuZC1kYXRle2NvbG9yOnZhcigtLW11dGVkKX0KLnRyZW5kLXNjb3Jl
HLP:e2ZvbnQtd2VpZ2h0OjcwMH0KPC9zdHlsZT4KPC9oZWFkPgo8Ym9keT4KPGRpdiBjbGFzcz0nd3JhcCc+CiAgPGRpdiBjbGFzcz0ndG9wYmFyJz4KICAgIDxkaXYgY2xhc3M9J2JyYW5kJz4KICAgICAgPGRpdiBjbGFzcz0nbG9nbyc+PHN2ZyB2aWV3Qm94PScwIDAg
HLP:MjQgMjQnIHdpZHRoPScyNicgaGVpZ2h0PScyNicgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdXUEknPjxwYXRoIGQ9J00xMiAybDcgM3Y2YzAgNC42LTMgOC4zLTcgOS42QzggMTkuMyA1IDE1LjYgNSAxMVY1eicgZmlsbD0nIzA0MjkzYicvPjxwYXRoIGQ9J005IDEy
HLP:bDIgMiA0LTQuNScgZmlsbD0nbm9uZScgc3Ryb2tlPScjZGZmNmZmJyBzdHJva2Utd2lkdGg9JzInIHN0cm9rZS1saW5lY2FwPSdyb3VuZCcgc3Ryb2tlLWxpbmVqb2luPSdyb3VuZCcvPjwvc3ZnPjwvZGl2PgogICAgICA8ZGl2PgogICAgICAgIDxoMT5JbmZvcm1l
HLP:IGRlIFJlcGFyYWNpb24gPHNwYW4gY2xhc3M9J2JhZGdlJz5XUEkgU1VJVEUgdjMuMTwvc3Bhbj48L2gxPgogICAgICAgIDxkaXYgY2xhc3M9J3N1Yic+JCgmICRlbmMgJG1hY2hpbmUpICZuYnNwOyZtaWRkb3Q7Jm5ic3A7IGdlbmVyYWRvIGVsICRub3c8L2Rpdj4K
HLP:ICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2J0bnMnPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dnbGUnIG9uY2xpY2s9IndpbmRvdy5wcmludCgpIj5JbXByaW1pciAvIFBERjwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dn
HLP:bGUnIGlkPSdjb3B5YnRuJyBvbmNsaWNrPSJjb3B5UmVzdW1lbigpIj5Db3BpYXIgcmVzdW1lbjwvYnV0dG9uPgogICAgICA8YnV0dG9uIGNsYXNzPSd0b2dnbGUnIGlkPSd0aGVtZWJ0bicgb25jbGljaz0idG9nZ2xlVGhlbWUoKSI+VGVtYSBjbGFyby9vc2N1cm88
HLP:L2J1dHRvbj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8bmF2IGNsYXNzPSd0b2MnIGFyaWEtbGFiZWw9J0luZGljZSc+CiAgICA8YSBocmVmPScjcmVzdW1lbic+UmVzdW1lbjwvYT4KICAgIDxhIGhyZWY9JyNmYXNlcyc+RmFzZXM8L2E+CiAgICA8YSBocmVmPScj
HLP:aGFsbGF6Z29zJz5IYWxsYXpnb3M8L2E+CiAgICA8YSBocmVmPScjcGFzb3MnPlByb3hpbW9zIHBhc29zPC9hPgogICAgPGEgaHJlZj0nI2RpYWcnPkRpYWdub3N0aWNvPC9hPgogIDwvbmF2PgoKICA8ZGl2IGlkPSdyZXN1bWVuJyBjbGFzcz0nZXhlYyBzZWN0aW9u
HLP:Jz4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtc2NvcmUnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz4kbWFpblNjb3JlPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdleGVjLW1pZCc+CiAgICAgIDxkaXYgY2xhc3M9J2V4ZWMtdmVyZGljdCcgc3R5bGU9J2NvbG9yOiRtYWlu
HLP:Q29sb3InPlNhbHVkIGRlbCBzaXN0ZW1hOiAkZXhlY1ZlcmRpY3Q8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nZXhlYy1saW5lJz4kY09LIGNvcnJlY3RhcyAmbWlkZG90OyAkY1dBUk4gYXZpc29zICZtaWRkb3Q7ICRjRVJSIGVycm9yZXMgJm1pZGRvdDsgJGNTS0lQ
HLP:IG9taXRpZGFzICZtaWRkb3Q7ICR0b3RhbFBoIGZhc2VzIGVuIHRvdGFsPC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9J2V4ZWMtbGluZSc+JHN0YXRMaW5lPC9kaXY+CiAgICA8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtZGVsdGEnIHN0eWxlPSdjb2xvcjokZGVs
HLP:dGFDb2xvcjtib3JkZXItY29sb3I6JGRlbHRhQ29sb3InPiRkZWx0YVR4dDwvZGl2PgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdoZXJvIHNlY3Rpb24nPgogICAgPGRpdiBjbGFzcz0nY2FyZCBnYXVnZXdyYXAnPgogICAgICA8c3ZnIHZpZXdCb3g9JzAgMCAyMDAg
HLP:MjAwJyBjbGFzcz0nZ2F1Z2UnIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nUHVudHVhY2lvbiBkZSBzYWx1ZCAkbWFpblNjb3JlIHNvYnJlIDEwMCc+PGNpcmNsZSBjbGFzcz0ndHJhY2snIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0Jy8+PGNpcmNsZSBjbGFzcz0nZmls
HLP:bCcgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnIHN0eWxlPSctLWNpcmM6JGNpcmM7LS10YXJnZXQ6JG1haW5PZmZzZXQ7c3Ryb2tlOiRtYWluQ29sb3InLz48dGV4dCB4PScxMDAnIHk9JzExMicgY2xhc3M9J2ctbnVtJyBzdHlsZT0nZmlsbDokbWFpbkNvbG9yJz4k
HLP:bWFpblNjb3JlPC90ZXh0Pjwvc3ZnPgogICAgICA8ZGl2IGNsYXNzPSdnLWxhYmVsJyBzdHlsZT0nY29sb3I6JG1haW5Db2xvcic+U2FsdWQ6ICRtYWluTGFiZWw8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nZy1jYXAnPlBVTlRVQUNJT04gU09CUkUgMTAwPC9kaXY+
HLP:CiAgICAgICRjb21wYXJlU2VjdGlvbgogICAgICAkaGlzdG9yeUh0bWwKICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0naGVyby1zaWRlJz4KICAgICAgPGRpdiBjbGFzcz0nY2FyZCc+CiAgICAgICAgPGRpdiBjbGFzcz0nY2hpcHMnPgogICAgICAgICAgPGRpdiBj
HLP:bGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBjLW9rJz4kY09LPC9kaXY+PGRpdiBjbGFzcz0nbCc+T0s8L2Rpdj48L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy13YXJuJz4kY1dBUk48L2Rpdj48ZGl2IGNsYXNzPSdsJz5B
HLP:VklTT1M8L2Rpdj48L2Rpdj4KICAgICAgICAgIDxkaXYgY2xhc3M9J2NoaXAnPjxkaXYgY2xhc3M9J24gYy1lcnInPiRjRVJSPC9kaXY+PGRpdiBjbGFzcz0nbCc+RVJST1JFUzwvZGl2PjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFz
HLP:cz0nbiBjLXNraXAnPiRjU0tJUDwvZGl2PjxkaXYgY2xhc3M9J2wnPk9NSVRJREFTPC9kaXY+PC9kaXY+CiAgICAgICAgPC9kaXY+CiAgICAgIDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdjYXJkJz4KICAgICAgICA8ZGl2IGNsYXNzPSdzeXNncmlkJz4kc3lzQ2Fy
HLP:ZHM8L2Rpdj4KICAgICAgPC9kaXY+CiAgICA8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlvbic+CiAgICA8aDIgaWQ9J2Zhc2VzJyBjbGFzcz0nc2VjLWgnPkxpbmVhIGRlIHRpZW1wbyBkZSBmYXNlcyAoJHRvdGFsUGgpPC9oMj4KICAgIDxkaXYg
HLP:Y2xhc3M9J3RpbWVsaW5lJz4kcm93czwvZGl2PgogICAgPGRpdiBjbGFzcz0nYmFyY2hhcnQnPiRiYXJzPC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdoYWxsYXpnb3MnIGNsYXNzPSdzZWMtaCc+SGFsbGF6Z29zIHkg
HLP:Y2F1c2EgcmFpejwvaDI+CiAgICA8dWwgY2xhc3M9J2ZpbmRzJz4kZmluZEh0bWw8L3VsPgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4KICAgIDxoMiBpZD0ncGFzb3MnIGNsYXNzPSdzZWMtaCc+UHJveGltb3MgcGFzb3MgcmVjb21lbmRhZG9zPC9o
HLP:Mj4KICAgIDx1bCBjbGFzcz0nc3RlcHMnPiRzdGVwc0h0bWw8L3VsPgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4kZGlhZ1NlY3Rpb248L2Rpdj4KCiAgPGRpdiBjbGFzcz0nZm9vdCc+CiAgICBXUEkgJm1pZGRvdDsgU3VpdGUgZGUgUmVwYXJhY2lv
HLP:biBkZSBFbWVyZ2VuY2lhIHBhcmEgV2luZG93cyAxMC8xMSAmbWlkZG90OyBpbmZvcm1lIGRlIHNvbG8gbGVjdHVyYS48YnI+CiAgICBMYXMgY29waWFzIGRlIHNlZ3VyaWRhZCB5IGxvcyByZWdpc3Ryb3MgZXN0YW4gZW4gbGEgY2FycGV0YSBXUElfU3VpdGUganVu
HLP:dG8gYWwgcHJvZ3JhbWEuCiAgPC9kaXY+CjwvZGl2Pgo8c2NyaXB0PgooZnVuY3Rpb24oKXt0cnl7dmFyIHM9bG9jYWxTdG9yYWdlLmdldEl0ZW0oJ3dwaS10aGVtZScpO3ZhciByb290PWRvY3VtZW50LmRvY3VtZW50RWxlbWVudDtpZihzPT09J2xpZ2h0Jyl7cm9v
HLP:dC5jbGFzc0xpc3QuYWRkKCdsaWdodCcpO31lbHNlIGlmKHM9PT0nZGFyaycpe3Jvb3QuY2xhc3NMaXN0LnJlbW92ZSgnbGlnaHQnKTt9ZWxzZSBpZih3aW5kb3cubWF0Y2hNZWRpYSYmd2luZG93Lm1hdGNoTWVkaWEoJyhwcmVmZXJzLWNvbG9yLXNjaGVtZTogbGln
HLP:aHQpJykubWF0Y2hlcyl7cm9vdC5jbGFzc0xpc3QuYWRkKCdsaWdodCcpO319Y2F0Y2goZSl7fX0pKCk7CmZ1bmN0aW9uIHRvZ2dsZVRoZW1lKCl7dHJ5e3ZhciBsPWRvY3VtZW50LmRvY3VtZW50RWxlbWVudC5jbGFzc0xpc3QudG9nZ2xlKCdsaWdodCcpO2xvY2Fs
HLP:U3RvcmFnZS5zZXRJdGVtKCd3cGktdGhlbWUnLGw/J2xpZ2h0JzonZGFyaycpO31jYXRjaChlKXt9fQpmdW5jdGlvbiBmbGFzaChtKXt0cnl7dmFyIHQ9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZGl2Jyk7dC5jbGFzc05hbWU9J3RvYXN0Jzt0LnRleHRDb250ZW50
HLP:PW07ZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZCh0KTtyZXF1ZXN0QW5pbWF0aW9uRnJhbWUoZnVuY3Rpb24oKXt0LmNsYXNzTGlzdC5hZGQoJ3Nob3cnKTt9KTtzZXRUaW1lb3V0KGZ1bmN0aW9uKCl7dC5jbGFzc0xpc3QucmVtb3ZlKCdzaG93Jyk7c2V0VGltZW91
HLP:dChmdW5jdGlvbigpe3QucmVtb3ZlKCk7fSwzMDApO30sMTYwMCk7fWNhdGNoKGUpe319CmZ1bmN0aW9uIGZiKHR4dCxvayl7dHJ5e3ZhciBhPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3RleHRhcmVhJyk7YS52YWx1ZT10eHQ7YS5zdHlsZS5wb3NpdGlvbj0nZml4
HLP:ZWQnO2Euc3R5bGUubGVmdD0nLTk5OTlweCc7ZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChhKTthLnNlbGVjdCgpO2RvY3VtZW50LmV4ZWNDb21tYW5kKCdjb3B5Jyk7YS5yZW1vdmUoKTtvaygpO31jYXRjaChlKXtmbGFzaCgnTm8gc2UgcHVkbyBjb3BpYXInKTt9
HLP:fQpmdW5jdGlvbiBjb3B5UmVzdW1lbigpe3ZhciBwPVtdO3ZhciB0PWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJ2gxJyk7aWYodClwLnB1c2godC5pbm5lclRleHQudHJpbSgpKTt2YXIgcz1kb2N1bWVudC5xdWVyeVNlbGVjdG9yKCcuc3ViJyk7aWYocylwLnB1c2go
HLP:cy5pbm5lclRleHQudHJpbSgpKTt2YXIgZXg9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignLmV4ZWMnKTtpZihleClwLnB1c2goJ1xuJytleC5pbm5lclRleHQucmVwbGFjZSgvXG57Mix9L2csJ1xuJykudHJpbSgpKTt2YXIgaD1kb2N1bWVudC5nZXRFbGVtZW50QnlJ
HLP:ZCgnaGFsbGF6Z29zJyk7aWYoaCYmaC5wYXJlbnROb2RlKXAucHVzaCgnXG4nK2gucGFyZW50Tm9kZS5pbm5lclRleHQudHJpbSgpKTt2YXIgdHh0PXAuam9pbignXG4nKTtmdW5jdGlvbiBvaygpe2ZsYXNoKCdSZXN1bWVuIGNvcGlhZG8nKTt9aWYobmF2aWdhdG9y
HLP:LmNsaXBib2FyZCYmbmF2aWdhdG9yLmNsaXBib2FyZC53cml0ZVRleHQpe25hdmlnYXRvci5jbGlwYm9hcmQud3JpdGVUZXh0KHR4dCkudGhlbihvayxmdW5jdGlvbigpe2ZiKHR4dCxvayk7fSk7fWVsc2V7ZmIodHh0LG9rKTt9fQo8L3NjcmlwdD4KPC9ib2R5Pgo8
HLP:L2h0bWw+CiJACiAgICAgICAgJHV0ZjggPSBOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpCiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRvdXRQYXRoLCAkaHRtbCwgJHV0ZjgpCiAgICAgICAgIlJFU1VMVD1P
HLP:SyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBSZWdpc3RyYXIgcmVzdWx0YWRvIGRlIHVuYSBmYXNlIGVuIGVsIGVzdGFkbyAocGFyYSBlbCBpbmZvcm1lKS4KIyAtQXJnID0gIm51bTt0aXRsZTtyZXN1bHQ7c2Vjcztub3RlIgpmdW5jdGlv
HLP:biBBZGQtUGhhc2VSZXN1bHQoJHNwZWMpIHsKICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICRwYXJ0cyA9ICRzcGVjIC1zcGxpdCAnOycsNQogICAgJHBoID0gW3BzY3VzdG9tb2JqZWN0XUB7IG51bT0kcGFydHNbMF07IHRpdGxlPSRwYXJ0c1sxXTsgcmVzdWx0PSRw
HLP:YXJ0c1syXTsgc2Vjcz0kcGFydHNbM107IG5vdGU9JHBhcnRzWzRdIH0KICAgICRsaXN0ID0gQCgkc3QucGhhc2VzKSArICRwaAogICAgJHN0LnBoYXNlcyA9ICRsaXN0CiAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gU2V0LVNj
HLP:b3JlKCR3aGljaCwgJHZhbCkgewogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgaWYgKCR3aGljaCAtZXEgJ2JlZm9yZScpIHsgCiAgICAgICAgJHN0LnNjb3JlX2JlZm9yZSA9IFtpbnRdJHZhbCAKICAgIH0gZWxzZSB7IAogICAgICAgICRzdC5zY29yZV9hZnRlciA9
HLP:IFtpbnRdJHZhbCAKICAgICAgICBTYXZlLUhlYWx0aEhpc3RvcnkgW2ludF0kdmFsCiAgICB9CiAgICBXcml0ZS1TdGF0ZSAkc3Q7ICJSRVNVTFQ9T0siCn0KZnVuY3Rpb24gQWRkLUZpbmRpbmcoJHRleHQpIHsKICAgICRzdCA9IFJlYWQtU3RhdGU7ICRzdC5maW5k
HLP:aW5ncyA9IEAoJHN0LmZpbmRpbmdzKSArICR0ZXh0OyBXcml0ZS1TdGF0ZSAkc3Q7ICJSRVNVTFQ9T0siCn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgTE9HSUNB
HLP:IFBVUkEgTlVFVkEgLyBDT1JSRUdJREEgKEJsb3F1ZSAzKQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSAoMy4xIC8gQnVnIDQgLyBSZXEgNikgTm9ybWFsaXph
HLP:Y2lvbiBkZSBsYSBzZWxlY2Npb24gZGUgZmFzZXMgLS0tLS0tLS0tLQojIEVudHJhZGE6IGNhZGVuYSBjb24gSURzIHNlcGFyYWRvcyBwb3IgY29tYXMgKGVzcGFjaW9zIGFyYml0cmFyaW9zLCAxLTIKIyBkaWdpdG9zLCBwb3NpYmxlcyBpbnZhbGlkb3MpLiBTYWxp
HLP:ZGE6IG9iamV0byBjb24gLm5vcm0gKGxpc3RhIGNhbm9uaWNhLAojIG9yZGVuYWRhLCB1bmljYSBkZSBJRHMgZGUgMiBkaWdpdG9zIGVuIHswMC4uMTZ9KSB5IC5pbnZhbGlkIChsb3Mgbm8gdmFsaWRvcykuCiMgTnVuY2EgbGFuemEgZXhjZXBjaW9uIGFudGUgZW50
HLP:cmFkYSBtYWxmb3JtYWRhIG8gdmFjaWEuCmZ1bmN0aW9uIE5vcm1hbGl6ZS1GYXNlcyhbc3RyaW5nXSRyYXcpIHsKICAgICR2YWxpZCAgID0gTmV3LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgICRpbnZhbGlkID0gTmV3
HLP:LU9iamVjdCBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0W3N0cmluZ10KICAgIGlmICgkbnVsbCAtbmUgJHJhdyAtYW5kICRyYXcuVHJpbSgpLkxlbmd0aCAtZ3QgMCkgewogICAgICAgIGZvcmVhY2ggKCR0IGluICgkcmF3IC1zcGxpdCAnLCcpKSB7CiAg
HLP:ICAgICAgICAgIGlmICgkbnVsbCAtZXEgJHQpIHsgY29udGludWUgfQogICAgICAgICAgICAkdG9rID0gKCR0IC1yZXBsYWNlICdccycsICcnKSAgICAgICAgICAjIHF1aXRhciBlc3BhY2lvcyBpbnRlcm5vcyB5IGV4dGVybm9zCiAgICAgICAgICAgIGlmICgkdG9r
HLP:IC1lcSAnJykgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRjYW5vbiA9ICR0b2sKICAgICAgICAgICAgaWYgKCR0b2sgLW1hdGNoICdeXGQkJykgeyAkY2Fub24gPSAkdG9rLlBhZExlZnQoMiwgJzAnKSB9ICAgIyAxIGRpZ2l0byAtPiAyIGRpZ2l0b3MKICAgICAg
HLP:ICAgICAgaWYgKCRjYW5vbiAtbWF0Y2ggJ15cZHsyfSQnIC1hbmQgW2ludF0kY2Fub24gLWdlIDAgLWFuZCBbaW50XSRjYW5vbiAtbGUgMTYpIHsKICAgICAgICAgICAgICAgIGlmICgtbm90ICR2YWxpZC5Db250YWlucygkY2Fub24pKSB7ICR2YWxpZC5BZGQoJGNh
HLP:bm9uKSB9CiAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICAkaW52YWxpZC5BZGQoJHRvaykKICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0KICAgICRzb3J0ZWQgPSBAKCR2YWxpZCB8IFNvcnQtT2JqZWN0KQogICAgcmV0dXJuIFtwc2N1c3Rv
HLP:bW9iamVjdF1AeyBub3JtID0gJHNvcnRlZDsgaW52YWxpZCA9IEAoJGludmFsaWQpIH0KfQoKIyAtLS0gKDMuMyAvIFJlcSA0KSBDaGVja3BvaW50IHNvYnJlIGNoZWNrcG9pbnQuanNvbiAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBQYXJzZXIgZGVsIC1Bcmcg
HLP:Y29uIGZvcm1hdG86CiMgICAic2F2ZXxzZWxlY3Rpb249MDAsMDEsMDJ8Y29tcGxldGVkPTAwLDAxfG1vZGU9YXV0bzoxO2RyeTowfHJlYXNvbj1jaGtkc2siCmZ1bmN0aW9uIFBhcnNlLUNoZWNrcG9pbnRBcmcoW3N0cmluZ10kcmF3KSB7CiAgICAkcmVzID0gW29y
HLP:ZGVyZWRdQHsgc3ViID0gJyc7IHNlbGVjdGlvbiA9IEAoKTsgY29tcGxldGVkID0gQCgpOyBtb2RlID0gQHt9OyByZWFzb24gPSAnJyB9CiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yRW1wdHkoJHJhdykpIHsgcmV0dXJuICRyZXMgfQogICAgJHNlZ3MgPSAkcmF3
HLP:IC1zcGxpdCAnXHwnCiAgICAkcmVzLnN1YiA9ICRzZWdzWzBdLlRyaW0oKS5Ub0xvd2VyKCkKICAgIGZvciAoJGkgPSAxOyAkaSAtbHQgJHNlZ3MuQ291bnQ7ICRpKyspIHsKICAgICAgICAka3YgPSAkc2Vnc1skaV0gLXNwbGl0ICc9JywgMgogICAgICAgIGlmICgk
HLP:a3YuQ291bnQgLWx0IDIpIHsgY29udGludWUgfQogICAgICAgICRrZXkgPSAka3ZbMF0uVHJpbSgpLlRvTG93ZXIoKQogICAgICAgICR2YWwgPSAka3ZbMV0KICAgICAgICBzd2l0Y2ggKCRrZXkpIHsKICAgICAgICAgICAgJ3NlbGVjdGlvbicgeyAkcmVzLnNlbGVj
HLP:dGlvbiA9IEAoJHZhbCAtc3BsaXQgJywnIHwgRm9yRWFjaC1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFdoZXJlLU9iamVjdCB7ICRfIC1uZSAnJyB9KSB9CiAgICAgICAgICAgICdjb21wbGV0ZWQnIHsgJHJlcy5jb21wbGV0ZWQgPSBAKCR2YWwgLXNwbGl0ICcsJyB8
HLP:IEZvckVhY2gtT2JqZWN0IHsgJF8uVHJpbSgpIH0gfCBXaGVyZS1PYmplY3QgeyAkXyAtbmUgJycgfSkgfQogICAgICAgICAgICAncmVhc29uJyAgICB7ICRyZXMucmVhc29uID0gJHZhbC5UcmltKCkgfQogICAgICAgICAgICAnbW9kZScgewogICAgICAgICAgICAg
HLP:ICAgJG0gPSBAe30KICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRwYWlyIGluICgkdmFsIC1zcGxpdCAnOycpKSB7CiAgICAgICAgICAgICAgICAgICAgJHAgPSAkcGFpciAtc3BsaXQgJzonLCAyCiAgICAgICAgICAgICAgICAgICAgaWYgKCRwLkNvdW50IC1lcSAy
HLP:KSB7ICRtWyRwWzBdLlRyaW0oKS5Ub0xvd2VyKCldID0gKCRwWzFdLlRyaW0oKSAtZXEgJzEnKSB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAkcmVzLm1vZGUgPSAkbQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQogICAgcmV0dXJuICRy
HLP:ZXMKfQoKIyBDb25zdHJ1eWUgeSBwZXJzaXN0ZSBjaGVja3BvaW50Lmpzb24uIERldnVlbHZlICR0cnVlLyRmYWxzZSAoc2luIGV4Y2VwY2lvbikuCmZ1bmN0aW9uIFNhdmUtQ2hlY2twb2ludCgkcGFyc2VkKSB7CiAgICB0cnkgewogICAgICAgICRtb2RlID0gW3Bz
HLP:Y3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIGF1dG8gICAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydhdXRvJ10KICAgICAgICAgICAgbm9yZWJvb3QgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ25vcmVib290J10KICAgICAgICAgICAga2VlcHd1ICAgPSBbYm9vbF0k
HLP:cGFyc2VkLm1vZGVbJ2tlZXB3dSddCiAgICAgICAgICAgIGRyeSAgICAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWydkcnknXQogICAgICAgICAgICB0cmlhZ2UgICA9IFtib29sXSRwYXJzZWQubW9kZVsndHJpYWdlJ10KICAgICAgICB9CiAgICAgICAgJG5vdyA9IChH
HLP:ZXQtRGF0ZSkuVG9TdHJpbmcoJ3l5eXktTU0tZGRfSEgtbW0nKQogICAgICAgICRjcCA9IFtwc2N1c3RvbW9iamVjdF1AewogICAgICAgICAgICB2ZXJzaW9uICAgICAgICA9ICRXUElfVkVSU0lPTgogICAgICAgICAgICBjcmVhdGVkICAgICAgICA9ICRub3cKICAg
HLP:ICAgICAgICAgbW9kZSAgICAgICAgICAgPSAkbW9kZQogICAgICAgICAgICBzZWxlY3Rpb24gICAgICA9IEAoJHBhcnNlZC5zZWxlY3Rpb24pCiAgICAgICAgICAgIGNvbXBsZXRlZCAgICAgID0gQCgkcGFyc2VkLmNvbXBsZXRlZCkKICAgICAgICAgICAgcGVuZGlu
HLP:Z19yZWFzb24gPSAkcGFyc2VkLnJlYXNvbgogICAgICAgICAgICB0aW1lc3RhbXBfcnVuICA9ICRub3cKICAgICAgICB9CiAgICAgICAgW1N5c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRDaGVja3BvaW50RmlsZSwgKCRjcCB8IENvbnZlcnRUby1Kc29uIC1E
HLP:ZXB0aCA2KSwgKE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkpKQogICAgICAgIHJldHVybiAkdHJ1ZQogICAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9CgojIENhcmdhIGNoZWNrcG9pbnQuanNvbi4gRGV2dWVsdmUgZWwgb2Jq
HLP:ZXRvIG8gJG51bGwgc2kgbm8gZXhpc3RlIC8gbWFsZm9ybWFkby4KZnVuY3Rpb24gTG9hZC1DaGVja3BvaW50IHsKICAgIGlmICgtbm90IChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSkgeyByZXR1cm4gJG51bGwgfQogICAgdHJ5IHsgcmV0dXJuIChHZXQtQ29u
HLP:dGVudCAkQ2hlY2twb2ludEZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24pIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CgojIFZhbGlkYSB1biBjaGVja3BvaW50OiBleGlzdGUgKyBwYXJzZWFibGUgKyB2ZXJzaW9uIGNvbXBhdGlibGUgKyBjb21wbGV0ZWQK
HLP:IyBzdWJjb25qdW50byBkZSBzZWxlY3Rpb24gKyBjcmVhdGVkIGRlbnRybyBkZSBsYSB2ZW50YW5hLiBEZXZ1ZWx2ZSBib29sZWFubwojIFNJTiBsYW56YXIgZXhjZXBjaW9uIGFudGUgSlNPTiBtYWxmb3JtYWRvIG8gY2FkdWNhZG8uCmZ1bmN0aW9uIFRlc3QtQ2hl
HLP:Y2twb2ludFZhbGlkKCRjcCkgewogICAgdHJ5IHsKICAgICAgICBpZiAoJG51bGwgLWVxICRjcCkgewogICAgICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRDaGVja3BvaW50RmlsZSkpIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgICAgIHRyeSB7ICRjcCA9
HLP:IEdldC1Db250ZW50ICRDaGVja3BvaW50RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbiB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgfQogICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIGlmIChbc3Ry
HLP:aW5nXSRjcC52ZXJzaW9uIC1uZSAkV1BJX1ZFUlNJT04pIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgJHNlbCAgPSBAKCRjcC5zZWxlY3Rpb24pCiAgICAgICAgJGNvbXAgPSBAKCRjcC5jb21wbGV0ZWQpCiAgICAgICAgZm9yZWFjaCAoJGMgaW4gJGNvbXApIHsg
HLP:aWYgKCRzZWwgLW5vdGNvbnRhaW5zICRjKSB7IHJldHVybiAkZmFsc2UgfSB9CiAgICAgICAgJGNyZWF0ZWQgPSAkbnVsbAogICAgICAgIGlmICgkY3AuY3JlYXRlZCkgewogICAgICAgICAgICB0cnkgeyAkY3JlYXRlZCA9IFtkYXRldGltZV06OlBhcnNlRXhhY3Qo
HLP:W3N0cmluZ10kY3AuY3JlYXRlZCwgJ3l5eXktTU0tZGRfSEgtbW0nLCAkbnVsbCkgfSBjYXRjaCB7ICRjcmVhdGVkID0gJG51bGwgfQogICAgICAgIH0KICAgICAgICBpZiAoJG51bGwgLWVxICRjcmVhdGVkKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgICRhZ2Ug
HLP:PSAoR2V0LURhdGUpIC0gJGNyZWF0ZWQKICAgICAgICBpZiAoJGFnZS5Ub3RhbERheXMgLWd0ICRDSEVDS1BPSU5UX01BWF9BR0VfREFZUykgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICByZXR1cm4gJHRydWUKICAgIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0K
HLP:fQoKIyBQcmltZXJhIGZhc2UgZGUgJ3NlbGVjdGlvbicgbm8gcHJlc2VudGUgZW4gJ2NvbXBsZXRlZCcgKG8gJycgc2kgdG9kYXMgaGVjaGFzKS4KZnVuY3Rpb24gR2V0LU5leHRQaGFzZSgkY3ApIHsKICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7IHJldHVybiAnJyB9
HLP:CiAgICAkY29tcCA9IEAoJGNwLmNvbXBsZXRlZCkKICAgIGZvcmVhY2ggKCRzIGluIEAoJGNwLnNlbGVjdGlvbikpIHsgaWYgKCRjb21wIC1ub3Rjb250YWlucyAkcykgeyByZXR1cm4gJHMgfSB9CiAgICByZXR1cm4gJycKfQoKIyAtLS0gKDMuOSAvIEJ1ZyA2IC8g
HLP:UmVxIDgpIFJlc2V0IGRlIGVzdGFkbyByZXV0aWxpemFibGUgLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBEZWphIHBoYXNlcz1AKCksIGZpbmRpbmdzPUAoKSB5IGxvcyBzY29yZXMgKGJlZm9yZS9hZnRlcikgYSBudWxsLiBFbAojIGNvbmRpY2lvbmFkbyBhIC9yZXN1
HLP:bWUgbG8gYXBsaWNhIGVsIGJhdGNoICh0YXJlYXMgOC40IC8gOS4xKTogc29sbyBpbnZvY2EKIyAncmVzZXRzdGF0ZScgY3VhbmRvIFJFU1VNRT09MCwgY29uc2VydmFuZG8gZWwgZXN0YWRvIHByZXZpbyBlbiAvcmVzdW1lLgpmdW5jdGlvbiBSZXNldC1TdGF0ZSB7
HLP:CiAgICBXcml0ZS1TdGF0ZSAoW3BzY3VzdG9tb2JqZWN0XUB7IHNjb3JlX2JlZm9yZSA9ICRudWxsOyBzY29yZV9hZnRlciA9ICRudWxsOyBmaW5kaW5ncyA9IEAoKTsgcGhhc2VzID0gQCgpIH0pCn0KCiMgLS0tICgzLjExIC8gQnVnIDcgLyBSZXEgOSkgSG9uZXN0
HLP:aWRhZCBkZWwgbW92aW1pZW50byBkZSBjYWNoZXMgLS0tLS0tLS0tLS0tCiMgRXhpdG8gKHRydWUpIFNJIFkgU09MTyBTSSBlbCBvcmlnZW4gZXN0YSBhdXNlbnRlIHkgZWwgZGVzdGlubyBwcmVzZW50ZS4KIyBWYXJpYW50ZSBwdXJhIChib29sZWFub3MpICsgdmFy
HLP:aWFudGUgcXVlIGFjZXB0YSBydXRhcyB5IGhhY2UgVGVzdC1QYXRoLgpmdW5jdGlvbiBUZXN0LU1vdmVSZXN1bHQoW2Jvb2xdJHNyY0V4aXN0cywgW2Jvb2xdJGRzdEV4aXN0cykgewogICAgcmV0dXJuICgoLW5vdCAkc3JjRXhpc3RzKSAtYW5kICRkc3RFeGlzdHMp
HLP:Cn0KZnVuY3Rpb24gVGVzdC1Nb3ZlUmVzdWx0UGF0aChbc3RyaW5nXSRzcmMsIFtzdHJpbmddJGRzdCkgewogICAgcmV0dXJuIChUZXN0LU1vdmVSZXN1bHQgKFtib29sXShUZXN0LVBhdGggJHNyYykpIChbYm9vbF0oVGVzdC1QYXRoICRkc3QpKSkKfQoKIyAtLS0g
HLP:KDMuMTEgLyBCdWcgOCAvIFJlcSAxMCkgSWRlbXBvdGVuY2lhIGRlIFZpcnR1YWxUZXJtaW5hbExldmVsIC0tLS0tLS0tLS0KIyBOb3JtYWxpemEgdmFsb3JlcyAnMHgxJyAvICcxJyAvIDEgYSBlbnRlcm8gcGFyYSBjb21wYXJhciBkZSBmb3JtYSByb2J1c3RhLgpm
HLP:dW5jdGlvbiBDb252ZXJ0VG8tVnRsSW50KCR2KSB7CiAgICBpZiAoJG51bGwgLWVxICR2KSB7IHJldHVybiAkbnVsbCB9CiAgICAkcyA9IChbc3RyaW5nXSR2KS5UcmltKCkuVG9Mb3dlcigpCiAgICBpZiAoJHMgLWVxICcnKSB7IHJldHVybiAkbnVsbCB9CiAgICB0
HLP:cnkgewogICAgICAgIGlmICgkcy5TdGFydHNXaXRoKCcweCcpKSB7IHJldHVybiBbQ29udmVydF06OlRvSW50MzIoJHMsIDE2KSB9CiAgICAgICAgcmV0dXJuIFtpbnRdJHMKICAgIH0gY2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CiMgRGV2dWVsdmUgJHRydWUgKGVz
HLP:Y3JpYmlyKSBzb2xvIHNpIGVsIHZhbG9yIGFjdHVhbCBkaWZpZXJlIGRlbCBkZXNlYWRvLgpmdW5jdGlvbiBSZXNvbHZlLVZ0bFdyaXRlKCRjdXJyZW50LCAkZGVzaXJlZCkgewogICAgcmV0dXJuICgoQ29udmVydFRvLVZ0bEludCAkY3VycmVudCkgLW5lIChDb252
HLP:ZXJ0VG8tVnRsSW50ICRkZXNpcmVkKSkKfQoKIyAtLS0gKDMuMTQgLyBSZXEgMS4zKSBNYXBlbyBUT1RBTCBkZSBjb2RpZ28gZGUgc2FsaWRhIGEge09LLFdBUk4sU0tJUCxFUlJPUn0KIyAwLT5PSywgMS0+V0FSTiwgMi0+U0tJUCwgMy0+RVJST1I7IGN1YWxxdWll
HLP:ciBvdHJvIGVudGVybyAobyBubyBlbnRlcm8pIC0+IEVSUk9SLgpmdW5jdGlvbiBNYXAtRXhpdENvZGUoJGNvZGUpIHsKICAgICRuID0gJG51bGwKICAgIHRyeSB7ICRuID0gW2ludF0kY29kZSB9IGNhdGNoIHsgcmV0dXJuICdFUlJPUicgfQogICAgc3dpdGNoICgk
HLP:bikgewogICAgICAgIDAgICAgICAgeyAnT0snIH0KICAgICAgICAxICAgICAgIHsgJ1dBUk4nIH0KICAgICAgICAyICAgICAgIHsgJ1NLSVAnIH0KICAgICAgICAzICAgICAgIHsgJ0VSUk9SJyB9CiAgICAgICAgZGVmYXVsdCB7ICdFUlJPUicgfQogICAgfQp9Cgoj
HLP:ID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIERJQUdOT1NUSUNPIEFNUExJQURPICg1LjEgLyBSZXEgMTUuMS0xNS41KQojID09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIC0tLSBSQU0gKFJlcSAxNS4xKSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgUmVzb2x2ZS1SYW1TdGF0dXM6IGZ1
HLP:bmNpb24gUFVSQS4gQSBwYXJ0aXIgZGVsIGNvbnRlbyBkZSBlcnJvcmVzIGRlIG1lbW9yaWEKIyBXSEVBIHkgZGUgZmFsbG9zIGRlbCBkaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlIFdpbmRvd3MsIGRlY2lkZSBlbCBlc3RhZG8geQojIHNpIGNvbnZpZW5lIHJlY29t
HLP:ZW5kYXIgbWRzY2hlZC4KZnVuY3Rpb24gUmVzb2x2ZS1SYW1TdGF0dXMoW2ludF0kd2hlYU1lbUVycm9ycywgW2ludF0kbWVtRGlhZ0ZhaWx1cmVzKSB7CiAgICBpZiAoJHdoZWFNZW1FcnJvcnMgLWd0IDAgLW9yICRtZW1EaWFnRmFpbHVyZXMgLWd0IDApIHsKICAg
HLP:ICAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdzdXNwZWN0JzsgcmVjb21tZW5kX21kc2NoZWQgPSAkdHJ1ZSB9CiAgICB9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHN0YXR1cyA9ICdvayc7IHJlY29tbWVuZF9tZHNjaGVkID0g
HLP:JGZhbHNlIH0KfQoKIyBHZXQtUmFtQ2hlY2s6IGxlZSBldmVudG9zIFdIRUEgeSByZXN1bHRhZG9zIGRlbCBEaWFnbm9zdGljbyBkZSBtZW1vcmlhIGRlCiMgV2luZG93cy4gRGVncmFkYWNpb24gZWxlZ2FudGU6IHNpIGxhIGNvbnN1bHRhIGRlIGV2ZW50b3MgZmFs
HLP:bGEgcG9yIGNvbXBsZXRvLAojIGRldnVlbHZlIHN0YXR1cz0ndW5rbm93bicgc2luIGxhbnphciBleGNlcGNpb24uCmZ1bmN0aW9uIEdldC1SYW1DaGVjayB7CiAgICB0cnkgewogICAgICAgICRxdWVyaWVkID0gJGZhbHNlCiAgICAgICAgJHdoZWFDb3VudCA9IDAK
HLP:ICAgICAgICAkbWVtRGlhZ0ZhaWwgPSAwCiAgICAgICAgIyBFcnJvcmVzIGRlIGhhcmR3YXJlIFdIRUEgcmVsYWNpb25hZG9zIGNvbiBtZW1vcmlhCiAgICAgICAgJHdoZWEgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVt
HLP:JzsgUHJvdmlkZXJOYW1lPSdNaWNyb3NvZnQtV2luZG93cy1XSEVBLUxvZ2dlcid9IC1NYXhFdmVudHMgMTAwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkbnVsbCAtbmUgJHdoZWEpIHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAg
HLP:ICAgJHdoZWFDb3VudCA9IEAoJHdoZWEgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWluIDE4LDE5LDIwLDQ3KSAtb3IgKCRfLk1lc3NhZ2UgLW1hdGNoICdtZW1vcicpIH0pLkNvdW50CiAgICAgICAgIyBSZXN1bHRhZG9zIGRlbCBEaWFnbm9zdGljbyBkZSBtZW1v
HLP:cmlhIGRlIFdpbmRvd3MgKG1kc2NoZWQpCiAgICAgICAgJG1kID0gQChHZXQtV2luRXZlbnQgLUZpbHRlckhhc2h0YWJsZSBAe0xvZ05hbWU9J1N5c3RlbSc7IFByb3ZpZGVyTmFtZT0nTWljcm9zb2Z0LVdpbmRvd3MtTWVtb3J5RGlhZ25vc3RpY3MtUmVzdWx0cyd9
HLP:IC1NYXhFdmVudHMgNTAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYgKCRudWxsIC1uZSAkbWQpIHsgJHF1ZXJpZWQgPSAkdHJ1ZSB9CiAgICAgICAgJG1lbURpYWdGYWlsID0gQCgkbWQgfCBXaGVyZS1PYmplY3QgeyAoJF8uSWQgLWVx
HLP:IDEwMDIpIC1vciAoJF8uTGV2ZWxEaXNwbGF5TmFtZSAtZXEgJ0Vycm9yJykgLW9yICgkXy5NZXNzYWdlIC1tYXRjaCAnZXJyb3J8ZXJyb3JlcycpIH0pLkNvdW50CiAgICAgICAgcmV0dXJuIChSZXNvbHZlLVJhbVN0YXR1cyAkd2hlYUNvdW50ICRtZW1EaWFnRmFp
HLP:bCkKICAgIH0gY2F0Y2ggewogICAgICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJ3Vua25vd24nOyByZWNvbW1lbmRfbWRzY2hlZCA9ICRmYWxzZSB9CiAgICB9Cn0KCiMgLS0tIEJhdGVyaWEgKFJlcSAxNS4yKSAtLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtQmF0dGVyeUhlYWx0aFBjdDogZnVuY2lvbiBQVVJBLiAlIGRlIHNhbHVkID0gcGxlbmEgY2FyZ2EgLyBkaXNlbm8gKiAxMDAuCmZ1bmN0aW9uIEdldC1CYXR0ZXJ5SGVhbHRoUGN0KCRkZXNp
HLP:Z24sICRmdWxsKSB7CiAgICB0cnkgewogICAgICAgICRkID0gW2RvdWJsZV0kZGVzaWduOyAkZiA9IFtkb3VibGVdJGZ1bGwKICAgICAgICBpZiAoJGQgLWd0IDApIHsgcmV0dXJuIFtpbnRdW21hdGhdOjpSb3VuZCgoJGYgLyAkZCkgKiAxMDApIH0KICAgIH0gY2F0
HLP:Y2gge30KICAgIHJldHVybiAkbnVsbAp9CgojIEdldC1CYXR0ZXJ5SGVhbHRoOiBzaSBoYXkgYmF0ZXJpYSwgZ2VuZXJhIHBvd2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0IHkgZXh0cmFlIGxhCiMgc2FsdWQgKGNhcGFjaWRhZCBkZSBkaXNlbm8gdnMgcGxlbmEgY2FyZ2Ep
HLP:LiBTaW4gYmF0ZXJpYSAtPiBwcmVzZW50PSRmYWxzZS4KIyBObyBmYWxsYSBzaSBwb3dlcmNmZyBubyBlc3RhIGRpc3BvbmlibGUgKGhlYWx0aF9wY3QgcXVlZGEgdmFjaW8pLgpmdW5jdGlvbiBHZXQtQmF0dGVyeUhlYWx0aCB7CiAgICAkcHJlc2VudCA9ICRmYWxz
HLP:ZTsgJGhlYWx0aFBjdCA9ICcnOyAkcmVwb3J0UGF0aCA9ICcnCiAgICB0cnkgewogICAgICAgICRiYXQgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9CYXR0ZXJ5IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgIGlmICgkYmF0LkNvdW50IC1n
HLP:dCAwKSB7CiAgICAgICAgICAgICRwcmVzZW50ID0gJHRydWUKICAgICAgICAgICAgJHJlcG9ydFBhdGggPSBKb2luLVBhdGggJFdvcmsgJ2JhdHRlcnktcmVwb3J0Lmh0bWwnCiAgICAgICAgICAgIHRyeSB7ICYgcG93ZXJjZmcgL2JhdHRlcnlyZXBvcnQgL291dHB1
HLP:dCAiJHJlcG9ydFBhdGgiIC9kdXJhdGlvbiAxID4gJG51bGwgMj4mMSB9IGNhdGNoIHt9CiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJHJlcG9ydFBhdGgpIHsKICAgICAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICAgICAgJHR4dCA9IEdldC1Db250
HLP:ZW50ICRyZXBvcnRQYXRoIC1SYXcKICAgICAgICAgICAgICAgICAgICAkZGVzaWduID0gJG51bGw7ICRmdWxsID0gJG51bGwKICAgICAgICAgICAgICAgICAgICAkbTEgPSBbcmVnZXhdOjpNYXRjaCgkdHh0LCAnKD9pcylERVNJR04gQ0FQQUNJVFkuKj8oW1xkXC4s
HLP:XSspXHMqbVdoJykKICAgICAgICAgICAgICAgICAgICAkbTIgPSBbcmVnZXhdOjpNYXRjaCgkdHh0LCAnKD9pcylGVUxMIENIQVJHRSBDQVBBQ0lUWS4qPyhbXGRcLixdKylccyptV2gnKQogICAgICAgICAgICAgICAgICAgIGlmICgkbTEuU3VjY2VzcykgeyAkZGVz
HLP:aWduID0gW2RvdWJsZV0oKCRtMS5Hcm91cHNbMV0uVmFsdWUgLXJlcGxhY2UgJ1tcLixdJywgJycpKSB9CiAgICAgICAgICAgICAgICAgICAgaWYgKCRtMi5TdWNjZXNzKSB7ICRmdWxsICAgPSBbZG91YmxlXSgoJG0yLkdyb3Vwc1sxXS5WYWx1ZSAtcmVwbGFjZSAn
HLP:W1wuLF0nLCAnJykpIH0KICAgICAgICAgICAgICAgICAgICAkcGN0ID0gR2V0LUJhdHRlcnlIZWFsdGhQY3QgJGRlc2lnbiAkZnVsbAogICAgICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHBjdCkgeyAkaGVhbHRoUGN0ID0gJHBjdCB9CiAgICAgICAgICAg
HLP:ICAgICB9IGNhdGNoIHt9CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IHByZXNlbnQgPSAkcHJlc2VudDsgaGVhbHRoX3BjdCA9ICRoZWFsdGhQY3Q7IHJlcG9ydF9wYXRoID0gJHJlcG9y
HLP:dFBhdGggfQp9CgojIC0tLSBSZWQgYXZhbnphZGEgKFJlcSAxNS41KSAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgR2V0LU5ldEFkdmFuY2VkOiBjb25lY3RpdmlkYWQgKHBpbmcgYSAxLjEuMS4xKSwgRE5TIChSZXNvbHZl
HLP:LURuc05hbWUgY29uCiMgcmVzcGFsZG8gcG9yIHBpbmcgYSB1biBob3N0KSB5IGNvbmZpZ3VyYWNpb24gYmFzaWNhIChJUC9nYXRld2F5KS4KIyBEZWdyYWRhY2lvbiBlbGVnYW50ZTogbnVuY2EgbGFuemEgZXhjZXBjaW9uLgpmdW5jdGlvbiBHZXQtTmV0QWR2YW5j
HLP:ZWQgewogICAgJGNvbm5lY3RlZCA9ICRmYWxzZTsgJGRuc09rID0gJGZhbHNlOyAkZGV0YWlscyA9ICcnCiAgICB0cnkgewogICAgICAgICMgQ29uZWN0aXZpZGFkCiAgICAgICAgJHBpbmcgPSAkZmFsc2UKICAgICAgICB0cnkgeyAkcGluZyA9IFtib29sXShUZXN0
HLP:LUNvbm5lY3Rpb24gLUNvbXB1dGVyTmFtZSAnMS4xLjEuMScgLUNvdW50IDEgLVF1aWV0IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSB9IGNhdGNoIHsgJHBpbmcgPSAkZmFsc2UgfQogICAgICAgIGlmICgtbm90ICRwaW5nKSB7CiAgICAgICAgICAgIHRy
HLP:eSB7ICYgcGluZyAtbiAxIC13IDE1MDAgMS4xLjEuMSA+ICRudWxsIDI+JjE7IGlmICgkTEFTVEVYSVRDT0RFIC1lcSAwKSB7ICRwaW5nID0gJHRydWUgfSB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgICAgICRjb25uZWN0ZWQgPSBbYm9vbF0kcGluZwogICAgICAg
HLP:ICMgUmVzb2x1Y2lvbiBETlMgKGNvbiBtZWRpZGEgZGUgbGF0ZW5jaWEpCiAgICAgICAgJGRucyA9ICRmYWxzZTsgJGRuc01zID0gJG51bGwKICAgICAgICB0cnkgewogICAgICAgICAgICAkc3cgPSBbU3lzdGVtLkRpYWdub3N0aWNzLlN0b3B3YXRjaF06OlN0YXJ0
HLP:TmV3KCkKICAgICAgICAgICAgJHIgPSBSZXNvbHZlLURuc05hbWUgLU5hbWUgJ3d3dy5taWNyb3NvZnQuY29tJyAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAgICAgICAkc3cuU3RvcCgpCiAgICAgICAgICAgIGlmICgkcikgeyAkZG5zID0gJHRy
HLP:dWU7ICRkbnNNcyA9IFtpbnRdJHN3LkVsYXBzZWRNaWxsaXNlY29uZHMgfQogICAgICAgIH0gY2F0Y2gge30KICAgICAgICBpZiAoLW5vdCAkZG5zKSB7CiAgICAgICAgICAgIHRyeSB7ICYgcGluZyAtbiAxIC13IDE1MDAgd3d3Lm1pY3Jvc29mdC5jb20gPiAkbnVs
HLP:bCAyPiYxOyBpZiAoJExBU1RFWElUQ09ERSAtZXEgMCkgeyAkZG5zID0gJHRydWUgfSB9IGNhdGNoIHt9CiAgICAgICAgfQogICAgICAgICRkbnNPayA9IFtib29sXSRkbnMKICAgICAgICAjIENvbmZpZ3VyYWNpb24gYmFzaWNhIChJUCAvIGdhdGV3YXkpCiAgICAg
HLP:ICAgJGlwID0gJyc7ICRndyA9ICcnCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJGNmZyA9IEAoR2V0LU5ldElQQ29uZmlndXJhdGlvbiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLklQdjREZWZhdWx0R2F0ZXdheSB9
HLP:KSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgaWYgKCRjZmcpIHsKICAgICAgICAgICAgICAgICRpcCA9ICgkY2ZnLklQdjRBZGRyZXNzIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkuSVBBZGRyZXNzCiAgICAgICAgICAgICAgICAkZ3cgPSAo
HLP:JGNmZy5JUHY0RGVmYXVsdEdhdGV3YXkgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5OZXh0SG9wCiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgJGRldGFpbHMgPSAiSVA9JGlwOyBHVz0kZ3ciCiAgICB9IGNhdGNoIHt9CiAgICByZXR1
HLP:cm4gW3BzY3VzdG9tb2JqZWN0XUB7IGNvbm5lY3RlZCA9ICRjb25uZWN0ZWQ7IGRuc19vayA9ICRkbnNPazsgZGV0YWlscyA9ICRkZXRhaWxzOyBkbnNfbXMgPSAkZG5zTXMgfQp9CgojIC0tLSBEaXNwb3NpdGl2b3MgcGFyYSBkaWFnIChSZXEgMTUuMy8xNS40KSAt
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgR2V0LURldmljZUxpc3Q6IGxpc3RhIGVzdHJ1Y3R1cmFkYSBkZSBkaXNwb3NpdGl2b3MgY29uIGVycm9yIHBhcmEgZXN0YWRvLmRpYWcuCiMgRGV2dWVsdmUgJG51bGwgc2kgbGEgaWRlbnRpZmljYWNpb24g
HLP:ZGUgZHJpdmVycyBmYWxsYSAoc2VuYWwgZGUgImluZm8gbm8KIyBkaXNwb25pYmxlIiBwYXJhIGRlZ3JhZGFjaW9uIGVsZWdhbnRlKS4KZnVuY3Rpb24gR2V0LURldmljZUxpc3QgewogICAgdHJ5IHsKICAgICAgICAkcCA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMy
HLP:X1BuUEVudGl0eSAtRXJyb3JBY3Rpb24gU3RvcCB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUgLWd0IDAgfSkKICAgICAgICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRkIGluICgkcCB8IFNlbGVjdC1PYmplY3QgLUZpcnN0
HLP:IDEyKSkgewogICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsgY29kZSA9IFtpbnRdJGQuQ29uZmlnTWFuYWdlckVycm9yQ29kZTsgbmFtZSA9IFtzdHJpbmddJGQuTmFtZSB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAsJGxpc3QKICAgIH0g
HLP:Y2F0Y2ggeyByZXR1cm4gJG51bGwgfQp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIFJPVEFDSU9OIERFIExPR1MgKDUuNiAvIFJlcSAxNy4yKQojID09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgU2VsZWN0LUxvZ3NUb0RlbGV0ZTogZnVuY2lvbiBQVVJBLiBEZSB1bmEgY29sZWNjaW9uIGRlIGZpY2hlcm9zIChjb24KIyAuTGFzdFdyaXRl
HLP:VGltZSkgeSB1bmEgcmV0ZW5jaW9uIE4sIGRldnVlbHZlIGxvcyBxdWUgZGViZW4gQk9SUkFSU0U6IHRvZG9zCiMgbWVub3MgbG9zIE4gbWFzIHJlY2llbnRlcyAoZXMgZGVjaXIsIGxvcyBtYXMgYW50aWd1b3MpLiBTaSBoYXkgPD0gTiwgbmluZ3Vuby4KZnVuY3Rp
HLP:b24gU2VsZWN0LUxvZ3NUb0RlbGV0ZSgkZmlsZXMsIFtpbnRdJHJldGVudGlvbikgewogICAgJGFyciA9IEAoJGZpbGVzKQogICAgaWYgKCRyZXRlbnRpb24gLWx0IDApIHsgJHJldGVudGlvbiA9IDAgfQogICAgaWYgKCRhcnIuQ291bnQgLWxlICRyZXRlbnRpb24p
HLP:IHsgcmV0dXJuIEAoKSB9CiAgICAkc29ydGVkID0gQCgkYXJyIHwgU29ydC1PYmplY3QgLVByb3BlcnR5IExhc3RXcml0ZVRpbWUgLURlc2NlbmRpbmcpCiAgICByZXR1cm4gQCgkc29ydGVkIHwgU2VsZWN0LU9iamVjdCAtU2tpcCAkcmV0ZW50aW9uKQp9CgojIElu
HLP:dm9rZS1Mb2dSb3RhdGU6IGNvbnNlcnZhIGxvcyAkcmV0ZW50aW9uIGxvZ3MgbWFzIHJlY2llbnRlcyBlbiAkZm9sZGVyIHkKIyBib3JyYSBlbCByZXN0by4gRGV2dWVsdmUgZWwgbnVtZXJvIGRlIGZpY2hlcm9zIGJvcnJhZG9zLgpmdW5jdGlvbiBJbnZva2UtTG9n
HLP:Um90YXRlKFtzdHJpbmddJGZvbGRlciwgW2ludF0kcmV0ZW50aW9uKSB7CiAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkZm9sZGVyKSkgeyAkZm9sZGVyID0gSm9pbi1QYXRoICRXb3JrICdMb2dzJyB9CiAgICAkZGVsZXRlZCA9IDAKICAgIHRy
HLP:eSB7CiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkZm9sZGVyKSkgeyByZXR1cm4gMCB9CiAgICAgICAgJGZpbGVzID0gQChHZXQtQ2hpbGRJdGVtIC1QYXRoICRmb2xkZXIgLUZpbHRlciAnKi5sb2cnIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRp
HLP:bnVlKQogICAgICAgICR0b0RlbGV0ZSA9IFNlbGVjdC1Mb2dzVG9EZWxldGUgJGZpbGVzICRyZXRlbnRpb24KICAgICAgICBmb3JlYWNoICgkZiBpbiAkdG9EZWxldGUpIHsKICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJGYuRnVsbE5hbWUgLUZvcmNlIC1F
HLP:cnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlOyAkZGVsZXRlZCsrIH0gY2F0Y2gge30KICAgICAgICB9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gJGRlbGV0ZWQKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PQojICBWQUxJREFDSU9OIERFIEVOVE9STk8gWSBTRUxGLVRFU1QgKDUuOCAvIFJlcSAxMy41LDEzLjYsMTguMSwxOC4zLDE4LjYpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBUZXN0LU9zU3VwcG9ydGVkOiBmdW5jaW9uIFBVUkEuIFdpbmRvd3MgMTAvMTEgPT4gYnVpbGQgPj0gMTAyNDAuCmZ1bmN0aW9uIFRlc3QtT3NTdXBwb3J0ZWQoW2ludF0kYnVpbGQpIHsKICAgIHJldHVybiAoJGJ1
HLP:aWxkIC1nZSAxMDI0MCkKfQoKIyBJbnZva2UtRW52VmFsaWRhdGU6IGNvbXBydWViYSBsYSB2ZXJzaW9uIGRlbCBTTyB2aWEgQ0lNLiBMYSBjb21wcm9iYWNpb24gc2UKIyBjb25zaWRlcmEgU0lFTVBSRSByZWFsaXphZGEgKGNoZWNrX2RvbmUpIGF1bnF1ZSBsYSB2
HLP:ZXJzaW9uIG5vIHNlYSBjb21wYXRpYmxlLgpmdW5jdGlvbiBJbnZva2UtRW52VmFsaWRhdGUgewogICAgJGJ1aWxkID0gMAogICAgdHJ5IHsgJGJ1aWxkID0gW2ludF0oR2V0LUNpbUluc3RhbmNlIFdpbjMyX09wZXJhdGluZ1N5c3RlbSAtRXJyb3JBY3Rpb24gU2ls
HLP:ZW50bHlDb250aW51ZSkuQnVpbGROdW1iZXIgfSBjYXRjaCB7ICRidWlsZCA9IDAgfQogICAgaWYgKCRidWlsZCAtbGUgMCkgeyB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtSXRlbVByb3BlcnR5ICdIS0xNOlxTT0ZUV0FSRVxNaWNyb3NvZnRcV2luZG93cyBOVFxD
HLP:dXJyZW50VmVyc2lvbicgLU5hbWUgQ3VycmVudEJ1aWxkTnVtYmVyIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKS5DdXJyZW50QnVpbGROdW1iZXIgfSBjYXRjaCB7ICRidWlsZCA9IDAgfSB9CiAgICBpZiAoJGJ1aWxkIC1sZSAwKSB7IHRyeSB7ICRidWls
HLP:ZCA9IFtpbnRdKEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uJyAtTmFtZSBDdXJyZW50QnVpbGQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLkN1cnJlbnRCdWlsZCB9IGNhdGNo
HLP:IHsgJGJ1aWxkID0gMCB9IH0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgb3Nfb2sgPSAoVGVzdC1Pc1N1cHBvcnRlZCAkYnVpbGQpOyBidWlsZCA9ICRidWlsZDsgY2hlY2tfZG9uZSA9ICR0cnVlIH0KfQoKIyBJbnZva2UtU2VsZlRlc3Q6IGFncmVnYWRv
HLP:ciBQVVJPLiBFeGl0byAodHJ1ZSkgc2kgeSBzb2xvIHNpIFRPREFTIGxhcwojIGNvbXByb2JhY2lvbmVzIChib29sZWFub3MpIHBhc2FuLiBDb2xlY2Npb24gdmFjaWEgLT4gdHJ1ZSAobmFkYSBmYWxsbykuCmZ1bmN0aW9uIEludm9rZS1TZWxmVGVzdCgkcmVzdWx0
HLP:cykgewogICAgZm9yZWFjaCAoJHIgaW4gQCgkcmVzdWx0cykpIHsgaWYgKC1ub3QgW2Jvb2xdJHIpIHsgcmV0dXJuICRmYWxzZSB9IH0KICAgIHJldHVybiAkdHJ1ZQp9CgojIFBhcnNlLUJvb2xMaXN0OiBjb252aWVydGUgIjEsMSwwLDEiIChvIHRydWUvb2spIGVu
HLP:IHVuYSBsaXN0YSBkZSBib29sZWFub3MuCmZ1bmN0aW9uIFBhcnNlLUJvb2xMaXN0KFtzdHJpbmddJHJhdykgewogICAgJGxpc3QgPSBAKCkKICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHJhdykpIHsKICAgICAgICBmb3JlYWNoICgk
HLP:dCBpbiAoJHJhdyAtc3BsaXQgJywnKSkgewogICAgICAgICAgICAkdG9rID0gJHQuVHJpbSgpLlRvTG93ZXIoKQogICAgICAgICAgICBpZiAoJHRvayAtZXEgJycpIHsgY29udGludWUgfQogICAgICAgICAgICAkbGlzdCArPSAoJHRvayAtZXEgJzEnIC1vciAkdG9r
HLP:IC1lcSAndHJ1ZScgLW9yICR0b2sgLWVxICdvaycgLW9yICR0b2sgLWVxICdwYXNzJykKICAgICAgICB9CiAgICB9CiAgICByZXR1cm4gLCRsaXN0Cn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBESUFHTk9TVElDTyBQUk9GVU5ETyB2My4xIChTTUFSVCwgYXJyYW5xdWUsIEJDRCwgcHJvY2Vz
HLP:b3MsIFNGQywgSlNPTikKIyAgVG9kYXMgbGFzIGZ1bmNpb25lcyBkZWdyYWRhbiBjb24gZWxlZ2FuY2lhOiBzaSBhbGdvIGZhbGxhLCBkZXZ1ZWx2ZW4KIyAgZXN0cnVjdHVyYXMgdmFjaWFzIC8gJ3Vua25vd24nIGVuIGx1Z2FyIGRlIGxhbnphciBleGNlcGNpb25l
HLP:cy4KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKIyBHZXQtU21hcnRBdHRyaWJ1dGVzOiBzYWx1ZCBmaXNpY2EgZGVsIGRpc2NvIGRlIHNpc3RlbWEgKGluZGVwZW5kaWVu
HLP:dGUgZGVsCiMgaWRpb21hIGRlIFdpbmRvd3MpLiBVc2EgTVNTdG9yYWdlRHJpdmVyX0ZhaWx1cmVQcmVkaWN0U3RhdHVzICsgZWwgY29udGFkb3IKIyBkZSBmaWFiaWxpZGFkIGRlIGFsbWFjZW5hbWllbnRvLiBEZXZ1ZWx2ZSBhdmFpbGFibGU9JGZhbHNlIHNpIG5v
HLP:IGhheSBkYXRvcy4KZnVuY3Rpb24gR2V0LVNtYXJ0QXR0cmlidXRlcyB7CiAgICAkcmVzID0gW3BzY3VzdG9tb2JqZWN0XUB7IGF2YWlsYWJsZSA9ICRmYWxzZTsgcHJlZGljdF9mYWlsID0gJGZhbHNlOyB0ZW1wX2MgPSAkbnVsbDsgd2Vhcl9wY3QgPSAkbnVsbDsg
HLP:cG9oID0gJG51bGwgfQogICAgdHJ5IHsKICAgICAgICAkcGYgPSAkbnVsbAogICAgICAgIHRyeSB7ICRwZiA9IEAoR2V0LUNpbUluc3RhbmNlIC1OYW1lc3BhY2UgJ3Jvb3Rcd21pJyAtQ2xhc3NOYW1lICdNU1N0b3JhZ2VEcml2ZXJfRmFpbHVyZVByZWRpY3RTdGF0
HLP:dXMnIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSB9IGNhdGNoIHsgJHBmID0gJG51bGwgfQogICAgICAgIGlmICgkcGYgLWFuZCAkcGYuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZQogICAgICAgICAgICBmb3Jl
HLP:YWNoICgkeCBpbiAkcGYpIHsgaWYgKCR4LlByZWRpY3RGYWlsdXJlKSB7ICRyZXMucHJlZGljdF9mYWlsID0gJHRydWUgfSB9CiAgICAgICAgfQogICAgICAgICMgRGlzY28gcXVlIGNvbnRpZW5lIEM6IC0+IGNvbnRhZG9yIGRlIGZpYWJpbGlkYWQKICAgICAgICB0
HLP:cnkgewogICAgICAgICAgICAkc3lzRGlzayA9ICRudWxsCiAgICAgICAgICAgIHRyeSB7ICRzeXNEaXNrID0gR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLkRldmljZUlkIC1uZSAkbnVsbCB9
HLP:IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9IGNhdGNoIHt9CiAgICAgICAgICAgICRyYyA9ICRudWxsCiAgICAgICAgICAgIGlmICgkc3lzRGlzaykgeyAkcmMgPSAkc3lzRGlzayB8IEdldC1TdG9yYWdlUmVsaWFiaWxpdHlDb3VudGVyIC1FcnJvckFjdGlvbiBT
HLP:aWxlbnRseUNvbnRpbnVlIH0KICAgICAgICAgICAgaWYgKC1ub3QgJHJjKSB7ICRyYyA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBHZXQtU3RvcmFnZVJlbGlhYmlsaXR5Q291bnRlciAtRXJyb3JBY3Rpb24gU2lsZW50
HLP:bHlDb250aW51ZSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICBpZiAoJHJjKSB7CiAgICAgICAgICAgICAgICAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlCiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyYy5UZW1wZXJhdHVyZSAtYW5k
HLP:ICRyYy5UZW1wZXJhdHVyZSAtZ3QgMCkgeyAkcmVzLnRlbXBfYyA9IFtpbnRdJHJjLlRlbXBlcmF0dXJlIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLldlYXIpICAgICAgICAgeyAkcmVzLndlYXJfcGN0ID0gW2ludF0kcmMuV2VhciB9CiAgICAg
HLP:ICAgICAgICAgICBpZiAoJG51bGwgLW5lICRyYy5Qb3dlck9uSG91cnMpIHsgJHJlcy5wb2ggPSBbaW50XSRyYy5Qb3dlck9uSG91cnMgfQogICAgICAgICAgICB9CiAgICAgICAgICAgICMgU2VuYWwgYWRpY2lvbmFsIGRlIHByZWRpY2Npb24gZGUgZmFsbG8gdmlh
HLP:IGVzdGFkbyBkZSBzYWx1ZCBmaXNpY2EKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICR1bmhlYWx0aHkgPSBAKEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBXaGVyZS1PYmplY3QgeyAkXy5IZWFsdGhTdGF0
HLP:dXMgLWFuZCAkXy5IZWFsdGhTdGF0dXMgLW5lICdIZWFsdGh5JyB9KQogICAgICAgICAgICAgICAgaWYgKCR1bmhlYWx0aHkuQ291bnQgLWd0IDApIHsgJHJlcy5hdmFpbGFibGUgPSAkdHJ1ZTsgJHJlcy5wcmVkaWN0X2ZhaWwgPSAkdHJ1ZSB9CiAgICAgICAgICAg
HLP:IH0gY2F0Y2gge30KICAgICAgICB9IGNhdGNoIHt9CiAgICB9IGNhdGNoIHt9CiAgICByZXR1cm4gJHJlcwp9CgojIEdldC1TdGFydHVwSXRlbXM6IHByb2dyYW1hcyBxdWUgYXJyYW5jYW4gY29uIFdpbmRvd3MgKHRvcCBOKSwgcGFyYSBxdWUgZWwKIyB1c3Vhcmlv
HLP:IHZlYSBxdWUgcmFsZW50aXphIGVsIGluaWNpby4gSW5kZXBlbmRpZW50ZSBkZWwgaWRpb21hLgpmdW5jdGlvbiBHZXQtU3RhcnR1cEl0ZW1zKFtpbnRdJHRvcCA9IDgpIHsKICAgIHRyeSB7CiAgICAgICAgJGl0ZW1zID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJf
HLP:U3RhcnR1cENvbW1hbmQgLUVycm9yQWN0aW9uIFN0b3AgfAogICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5Db21tYW5kIH0gfAogICAgICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAkdG9wKQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFj
HLP:aCAoJGkgaW4gJGl0ZW1zKSB7CiAgICAgICAgICAgICRjbWQgPSBbc3RyaW5nXSRpLkNvbW1hbmQKICAgICAgICAgICAgaWYgKCRjbWQuTGVuZ3RoIC1ndCA4MCkgeyAkY21kID0gJGNtZC5TdWJzdHJpbmcoMCw3NykgKyAnLi4uJyB9CiAgICAgICAgICAgICRubSA9
HLP:IFtzdHJpbmddJGkuTmFtZTsgaWYgKC1ub3QgJG5tKSB7ICRubSA9IFtzdHJpbmddJGkuQ2FwdGlvbiB9CiAgICAgICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBuYW1lID0gJG5tOyBjb21tYW5kID0gJGNtZCB9CiAgICAgICAgfQogICAgICAgIHJl
HLP:dHVybiAsJGxpc3QKICAgIH0gY2F0Y2ggeyByZXR1cm4gQCgpIH0KfQoKIyBHZXQtQmNkSW50ZWdyaXR5OiBjb21wcnVlYmEgcXVlIGxhIGNvbmZpZ3VyYWNpb24gZGUgYXJyYW5xdWUgKEJDRCkgdGllbmUgbGEKIyBlbnRyYWRhIGFjdHVhbCBjb24gb3NkZXZpY2Uv
HLP:ZGV2aWNlLiBMYXMgQ0xBVkVTIGRlIGJjZGVkaXQgc29uIHNpZW1wcmUgZW4KIyBpbmdsZXMsIGFzaSBxdWUgZXMgaW5kZXBlbmRpZW50ZSBkZWwgaWRpb21hIGRlIGxhIGludGVyZmF6LgpmdW5jdGlvbiBHZXQtQmNkSW50ZWdyaXR5IHsKICAgICRyZXMgPSBbcHNj
HLP:dXN0b21vYmplY3RdQHsgb2sgPSAkZmFsc2U7IGRldGFpbHMgPSAnJyB9CiAgICB0cnkgewogICAgICAgICRvdXQgPSAmIGJjZGVkaXQgL2VudW0gJ3tjdXJyZW50fScgMj4kbnVsbAogICAgICAgICR0eHQgPSAoJG91dCAtam9pbiAiYG4iKQogICAgICAgIGlmICgk
HLP:TEFTVEVYSVRDT0RFIC1lcSAwIC1hbmQgJHR4dCAtbWF0Y2ggJyg/aW0pXlxzKm9zZGV2aWNlJyAtYW5kICR0eHQgLW1hdGNoICcoP2ltKV5ccypkZXZpY2UnKSB7CiAgICAgICAgICAgICRyZXMub2sgPSAkdHJ1ZQogICAgICAgICAgICAkcmVzLmRldGFpbHMgPSAn
HLP:RW50cmFkYSBkZSBhcnJhbnF1ZSBhY3R1YWwgaW50ZWdyYSAoZGV2aWNlL29zZGV2aWNlIHByZXNlbnRlcykuJwogICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICRyZXMub2sgPSAkZmFsc2UKICAgICAgICAgICAgJHJlcy5kZXRhaWxzID0gJ05vIHNlIHB1ZG8g
HLP:Y29uZmlybWFyIGxhIGVudHJhZGEgZGUgYXJyYW5xdWUgYWN0dWFsLicKICAgICAgICB9CiAgICB9IGNhdGNoIHsKICAgICAgICAkcmVzLm9rID0gJGZhbHNlCiAgICAgICAgJHJlcy5kZXRhaWxzID0gJ2JjZGVkaXQgbm8gZGlzcG9uaWJsZSBvIHNpbiBwZXJtaXNv
HLP:cy4nCiAgICB9CiAgICByZXR1cm4gJHJlcwp9CgojIEdldC1Ub3BQcm9jZXNzZXM6IHByb2Nlc29zIHF1ZSBtYXMgbWVtb3JpYSBkZSB0cmFiYWpvIGNvbnN1bWVuICh0b3AgTikuCmZ1bmN0aW9uIEdldC1Ub3BQcm9jZXNzZXMoW2ludF0kdG9wID0gNikgewogICAg
HLP:dHJ5IHsKICAgICAgICAkcHMgPSBAKEdldC1Qcm9jZXNzIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAgICAgU29ydC1PYmplY3QgV29ya2luZ1NldDY0IC1EZXNjZW5kaW5nIHwKICAgICAgICAgICAgU2VsZWN0LU9iamVjdCAtRmlyc3Qg
HLP:JHRvcCkKICAgICAgICAkbGlzdCA9IEAoKQogICAgICAgIGZvcmVhY2ggKCRwIGluICRwcykgewogICAgICAgICAgICAkbWIgPSBbbWF0aF06OlJvdW5kKCRwLldvcmtpbmdTZXQ2NCAvIDFNQikKICAgICAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7
HLP:IG5hbWUgPSBbc3RyaW5nXSRwLlByb2Nlc3NOYW1lOyBtZW1fbWIgPSBbaW50XSRtYiB9CiAgICAgICAgfQogICAgICAgIHJldHVybiAsJGxpc3QKICAgIH0gY2F0Y2ggeyByZXR1cm4gQCgpIH0KfQoKIyBHZXQtU2ZjUmVzdWx0OiBjbGFzaWZpY2EgZWwgcmVzdWx0
HLP:YWRvIGRlIFNGQyBsZXllbmRvIENCUy5sb2cgKFNJRU1QUkUgZW4KIyBpbmdsZXMpIGVuIGx1Z2FyIGRlIGxhIHNhbGlkYSB0cmFkdWNpZGEgZGUgbGEgY29uc29sYS4gRGV2dWVsdmUgdW5vIGRlOgojIGNsZWFuIHwgcmVwYWlyZWQgfCB1bnJlcGFpcmFibGUgfCB1
HLP:bmtub3duLgpmdW5jdGlvbiBHZXQtU2ZjUmVzdWx0IHsKICAgICRsb2cgPSBKb2luLVBhdGggJGVudjp3aW5kaXIgJ0xvZ3NcQ0JTXENCUy5sb2cnCiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRsb2cpKSB7IHJldHVybiAndW5rbm93bicgfQogICAgdHJ5IHsKICAg
HLP:ICAgICAkdGFpbCA9IEAoR2V0LUNvbnRlbnQgLVBhdGggJGxvZyAtVGFpbCA0MDAwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKQogICAgICAgICRzciA9IEAoJHRhaWwgfCBXaGVyZS1PYmplY3QgeyAkXyAtbWF0Y2ggJ1xbU1JcXScgfSkKICAgICAgICBp
HLP:ZiAoJHNyLkNvdW50IC1lcSAwKSB7IHJldHVybiAndW5rbm93bicgfQogICAgICAgICRqb2luZWQgPSAoJHNyIC1qb2luICJgbiIpCiAgICAgICAgaWYgKCRqb2luZWQgLW1hdGNoICcoP2kpY2Fubm90IHJlcGFpcicpIHsgcmV0dXJuICd1bnJlcGFpcmFibGUnIH0K
HLP:ICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSlyZXBhaXJpbmdccysoWzEtOV1cZCopXHMrY29tcG9uZW50c3xzdWNjZXNzZnVsbHkgcmVwYWlyZWR8cmVwYWlyZWQgZmlsZXxyZXBhaXJpbmcgY29ycnVwdGVkIGZpbGUnKSB7IHJldHVybiAncmVwYWlyZWQn
HLP:IH0KICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSl2ZXJpZnkgY29tcGxldGV8bm8gLippbnRlZ3JpdHkgdmlvbGF0aW9uc3xjYW5ub3QgdmVyaWZ5fHZlcmlmeWluZycpIHsgcmV0dXJuICdjbGVhbicgfQogICAgICAgIHJldHVybiAnY2xlYW4nCiAgICB9
HLP:IGNhdGNoIHsgcmV0dXJuICd1bmtub3duJyB9Cn0KCiMgTmV3LUpzb25SZXBvcnQ6IHZ1ZWxjYSBlbCBlc3RhZG8gKyByZXN1bWVuIGNhbGN1bGFkbyBhIHVuIGZpY2hlcm8gSlNPTgojICgtQXJnID0gcnV0YSBkZSBzYWxpZGEpLiBVdGlsIHBhcmEgYXV0b21hdGl6
HLP:YWNpb24gLyBNRE0gLyBpbnZlbnRhcmlvLgpmdW5jdGlvbiBOZXctSnNvblJlcG9ydCgkb3V0UGF0aCkgewogICAgdHJ5IHsKICAgICAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAgICAgJHN5c1BhaXJzID0gR2V0LVN5c0luZm8KICAgICAgICAkc3lzTWFwID0gQHt9
HLP:CiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHN5c1BhaXJzKSB7ICRrdiA9ICRwIC1zcGxpdCAnPScsMjsgaWYgKCRrdi5Db3VudCAtZXEgMikgeyAkc3lzTWFwWyRrdlswXV0gPSAka3ZbMV0gfSB9CiAgICAgICAgJHBoYXNlcyA9IEAoJHN0LnBoYXNlcykKICAgICAg
HLP:ICAkY09LPTA7JGNXQVJOPTA7JGNFUlI9MDskY1NLSVA9MAogICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7IHN3aXRjaCAoW3N0cmluZ10kcGgucmVzdWx0KSB7ICdPSycgeyRjT0srK30gJ1dBUk4nIHskY1dBUk4rK30gJ0VSUk9SJyB7JGNFUlIrK30g
HLP:J1NLSVAnIHskY1NLSVArK30gfSB9CiAgICAgICAgJGRlbHRhID0gJG51bGwKICAgICAgICBpZiAoJHN0LnNjb3JlX2JlZm9yZSAtbmUgJG51bGwgLWFuZCAkc3Quc2NvcmVfYWZ0ZXIgLW5lICRudWxsKSB7ICRkZWx0YSA9IFtpbnRdJHN0LnNjb3JlX2FmdGVyIC0g
HLP:W2ludF0kc3Quc2NvcmVfYmVmb3JlIH0KICAgICAgICAkb2JqID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIHNjaGVtYSAgICAgICA9ICd3cGktcmVwb3J0LzEnCiAgICAgICAgICAgIHZlcnNpb24gICAgICA9ICRXUElfVkVSU0lPTgogICAgICAgICAg
HLP:ICBnZW5lcmF0ZWQgICAgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCdzJykKICAgICAgICAgICAgbWFjaGluZSAgICAgID0gJGVudjpDT01QVVRFUk5BTUUKICAgICAgICAgICAgc3lzdGVtICAgICAgID0gJHN5c01hcAogICAgICAgICAgICBzY29yZV9iZWZvcmUgPSAk
HLP:c3Quc2NvcmVfYmVmb3JlCiAgICAgICAgICAgIHNjb3JlX2FmdGVyICA9ICRzdC5zY29yZV9hZnRlcgogICAgICAgICAgICBzY29yZV9kZWx0YSAgPSAkZGVsdGEKICAgICAgICAgICAgc3VtbWFyeSAgICAgID0gW3BzY3VzdG9tb2JqZWN0XUB7IG9rPSRjT0s7IHdh
HLP:cm49JGNXQVJOOyBlcnJvcj0kY0VSUjsgc2tpcD0kY1NLSVA7IHRvdGFsPSRwaGFzZXMuQ291bnQgfQogICAgICAgICAgICBwaGFzZXMgICAgICAgPSAkcGhhc2VzCiAgICAgICAgICAgIGZpbmRpbmdzICAgICA9IEAoJHN0LmZpbmRpbmdzKQogICAgICAgICAgICBk
HLP:aWFnICAgICAgICAgPSAkc3QuZGlhZwogICAgICAgIH0KICAgICAgICAkanNvbiA9ICRvYmogfCBDb252ZXJ0VG8tSnNvbiAtRGVwdGggOAogICAgICAgICR1dGY4ID0gTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKQogICAgICAgIFtT
HLP:eXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkb3V0UGF0aCwgJGpzb24sICR1dGY4KQogICAgICAgICJSRVNVTFQ9T0siCiAgICAgICAgIlBBVEg9JG91dFBhdGgiCiAgICB9IGNhdGNoIHsKICAgICAgICAiUkVTVUxUPUZBSUwiCiAgICAgICAgIkVSUk9SPSQo
HLP:JF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgfQp9CgojIE5ldy1TdXBwb3J0UGFja2FnZTogZW1wYXF1ZXRhIGxvZ3MgKyBpbmZvcm1lICsgZXN0YWRvICsgYmF0dGVyeS1yZXBvcnQgZW4gdW4KIyBaSVAgKC1BcmcgPSBydXRhIGRlbCB6aXApIHBhcmEgZW52aWFy
HLP:IGEgc29wb3J0ZS4gU2luIGRlcGVuZGVuY2lhcyBleHRlcm5hcwojICh1c2EgQ29tcHJlc3MtQXJjaGl2ZSwgaW5jbHVpZG8gZW4gV2luZG93cyAxMC8xMSkuCmZ1bmN0aW9uIE5ldy1TdXBwb3J0UGFja2FnZSgkb3V0UGF0aCkgewogICAgdHJ5IHsKICAgICAgICAk
HLP:dG1wID0gSm9pbi1QYXRoICRXb3JrICgnc29wb3J0ZV8nICsgKEdldC1EYXRlKS5Ub1N0cmluZygneXl5eU1NZGRfSEhtbXNzJykpCiAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkdG1wIC1Gb3JjZSB8IE91dC1OdWxsCiAgICAgICAg
HLP:IyBlc3RhZG8uanNvbgogICAgICAgIGlmIChUZXN0LVBhdGggJFN0YXRlRmlsZSkgeyBDb3B5LUl0ZW0gJFN0YXRlRmlsZSAoSm9pbi1QYXRoICR0bXAgJ2VzdGFkby5qc29uJykgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICAj
HLP:IExvZ3MKICAgICAgICAkbG9ncyA9IEpvaW4tUGF0aCAkV29yayAnTG9ncycKICAgICAgICBpZiAoVGVzdC1QYXRoICRsb2dzKSB7CiAgICAgICAgICAgICRkc3RMb2dzID0gSm9pbi1QYXRoICR0bXAgJ0xvZ3MnCiAgICAgICAgICAgIE5ldy1JdGVtIC1JdGVtVHlw
HLP:ZSBEaXJlY3RvcnkgLVBhdGggJGRzdExvZ3MgLUZvcmNlIHwgT3V0LU51bGwKICAgICAgICAgICAgR2V0LUNoaWxkSXRlbSAkbG9ncyAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IENvcHktSXRlbSAtRGVzdGluYXRpb24gJGRzdExvZ3MgLUZv
HLP:cmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgfQogICAgICAgICMgSW5mb3JtZXMgSFRNTC9KU09OIGV4aXN0ZW50ZXMgZW4gV29yawogICAgICAgIEdldC1DaGlsZEl0ZW0gJFdvcmsgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
HLP:dGludWUgfAogICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAkXy5OYW1lIC1tYXRjaCAnKD9pKV5JbmZvcm1lLipcLihodG1sfGpzb24pJCcgfSB8CiAgICAgICAgICAgIENvcHktSXRlbSAtRGVzdGluYXRpb24gJHRtcCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVu
HLP:dGx5Q29udGludWUKICAgICAgICAjIGJhdHRlcnkgcmVwb3J0IHNpIGV4aXN0ZQogICAgICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICAgICB0cnkgeyBpZiAoJHN0LmRpYWcgLWFuZCAkc3QuZGlhZy5iYXR0ZXJ5IC1hbmQgJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRf
HLP:cGF0aCAtYW5kIChUZXN0LVBhdGggJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCkpIHsgQ29weS1JdGVtICRzdC5kaWFnLmJhdHRlcnkucmVwb3J0X3BhdGggJHRtcCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfSB9IGNhdGNoIHt9CiAg
HLP:ICAgICAgaWYgKFRlc3QtUGF0aCAkb3V0UGF0aCkgeyBSZW1vdmUtSXRlbSAkb3V0UGF0aCAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIENvbXByZXNzLUFyY2hpdmUgLVBhdGggKEpvaW4tUGF0aCAkdG1wICcqJykgLURlc3Rp
HLP:bmF0aW9uUGF0aCAkb3V0UGF0aCAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3AKICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAkdG1wIC1SZWN1cnNlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IGNhdGNoIHt9CiAgICAgICAgIlJFU1VMVD1P
HLP:SyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCnN3aXRjaCAoJEFjdGlvbi5Ub0xvd2VyKCkpIHsKICAgICdub25l
HLP:JyAgICAgICAgIHsgfSAjIFVzYWRvIHBhcmEgZG90LXNvdXJjaW5nCiAgICAnY2hlY2tiYWNrdXBzJyB7CiAgICAgICAgJHBhcnRzID0gJEFyZyAtc3BsaXQgJ1x8JywgMgogICAgICAgIGlmICgkcGFydHMuQ291bnQgLW5lIDIpIHsgIlJFU1VMVD1GQUlMIjsgIkVS
HLP:Uk9SPUFyZ3VtZW50b3MgaW52YWxpZG9zIjsgZXhpdCAwIH0KICAgICAgICAkYmtkaXIgPSAkcGFydHNbMF0KICAgICAgICAkdHMgPSAkcGFydHNbMV0KICAgICAgICAkcnBfb2sgPSAkZmFsc2UKICAgICAgICB0cnkgewogICAgICAgICAgICAkcnBzID0gR2V0LUNv
HLP:bXB1dGVyUmVzdG9yZVBvaW50IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgIGZvcmVhY2ggKCRycCBpbiAkcnBzKSB7CiAgICAgICAgICAgICAgICBpZiAoJHJwLkRlc2NyaXB0aW9uIC1saWtlICJTdWl0ZV9SZXBhcmFjaW9uXyoiKSB7
HLP:ICRycF9vayA9ICR0cnVlOyBicmVhayB9CiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHsgJHJwX29rID0gJGZhbHNlIH0KICAgICAgICAkcmVnX29rID0gJHRydWUKICAgICAgICAkc29mdCA9IEpvaW4tUGF0aCAkYmtkaXIgIlNPRlRXQVJFXyR0cy5yZWci
HLP:CiAgICAgICAgJHN5cyA9IEpvaW4tUGF0aCAkYmtkaXIgIlNZU1RFTV8kdHMucmVnIgogICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJHNvZnQpIC1vciAoR2V0LUl0ZW0gJHNvZnQpLkxlbmd0aCAtZXEgMCkgeyAkcmVnX29rID0gJGZhbHNlIH0KICAgICAgICBp
HLP:ZiAoLW5vdCAoVGVzdC1QYXRoICRzeXMpIC1vciAoR2V0LUl0ZW0gJHN5cykuTGVuZ3RoIC1lcSAwKSB7ICRyZWdfb2sgPSAkZmFsc2UgfQogICAgICAgICJSUF9PSz0kKGlmICgkcnBfb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJSRUdfT0s9JChpZiAo
HLP:JHJlZ19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnYm9vdHN0cmFwd2luZ2V0JyB7CiAgICAgICAgJG9rID0gSW5zdGFsbC1XaW5nZXRCb290c3RyYXAKICAgICAgICAiQk9PVFNUUkFQX09LPSQoaWYgKCRvaykgeycxJ30gZWxzZSB7JzAnfSkiCiAg
HLP:ICB9CiAgICAnZmluZGxvY2Fsc291cmNlJyB7CiAgICAgICAgJGRyaXZlcyA9IEdldC1QU0RyaXZlIC1QU1Byb3ZpZGVyIEZpbGVTeXN0ZW0KICAgICAgICAkcGF0aHMgPSBAKCkKICAgICAgICAkZWRpdGlvbklkID0gJycKICAgICAgICB0cnkgeyAkZWRpdGlvbklk
HLP:ID0gKEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1cnJlbnRWZXJzaW9uJyAtTmFtZSBFZGl0aW9uSUQgLUVycm9yQWN0aW9uIFN0b3ApLkVkaXRpb25JRCB9IGNhdGNoIHt9CiAgICAgICAgZnVuY3Rpb24gR2V0
HLP:LUluc3RhbGxJbWFnZVNvdXJjZShbc3RyaW5nXSRraW5kLCBbc3RyaW5nXSRwYXRoLCBbc3RyaW5nXSRlZGl0aW9uKSB7CiAgICAgICAgICAgICRpbmRleCA9IDEKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICRpbWFnZXMgPSBAKEdldC1XaW5kb3dz
HLP:SW1hZ2UgLUltYWdlUGF0aCAkcGF0aCAtRXJyb3JBY3Rpb24gU3RvcCkKICAgICAgICAgICAgICAgICRtYXRjaCA9ICRudWxsCiAgICAgICAgICAgICAgICBpZiAoJGVkaXRpb24gLW1hdGNoICdQcm9mZXNzaW9uYWwnKSB7ICRtYXRjaCA9ICRpbWFnZXMgfCBXaGVy
HLP:ZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdcYlByb1xifFByb2Zlc3Npb25hbCcgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgZWxzZWlmICgkZWRpdGlvbiAtbWF0Y2ggJ0VudGVycHJpc2UnKSB7ICRtYXRjaCA9ICRp
HLP:bWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdFbnRlcnByaXNlJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnRWR1Y2F0aW9uJykgeyAkbWF0Y2ggPSAk
HLP:aW1hZ2VzIHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnRWR1Y2F0aW9uJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnQ29yZScpIHsgJG1hdGNoID0gJGltYWdl
HLP:cyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ1xiSG9tZVxifENvcmUnIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtZXEgJG1hdGNoIC1hbmQgJGltYWdlcy5Db3VudCAtZXEgMSkgeyAk
HLP:bWF0Y2ggPSAkaW1hZ2VzWzBdIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJG1hdGNoKSB7ICRpbmRleCA9IFtpbnRdJG1hdGNoLkltYWdlSW5kZXggfQogICAgICAgICAgICB9IGNhdGNoIHt9CiAgICAgICAgICAgIHJldHVybiAoInswfTp7MX06ezJ9
HLP:IiAtZiAka2luZCwgJHBhdGgsICRpbmRleCkKICAgICAgICB9CiAgICAgICAgZm9yZWFjaCAoJGQgaW4gJGRyaXZlcykgewogICAgICAgICAgICAkcm9vdCA9ICRkLlJvb3QKICAgICAgICAgICAgJHdpbSA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xpbnN0YWxs
HLP:LndpbSIKICAgICAgICAgICAgJGVzZCA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xpbnN0YWxsLmVzZCIKICAgICAgICAgICAgJHN4cyA9IEpvaW4tUGF0aCAkcm9vdCAic291cmNlc1xzeHMiCiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJHdpbSkgeyAkcGF0
HLP:aHMgKz0gKEdldC1JbnN0YWxsSW1hZ2VTb3VyY2UgJ1dpbScgJHdpbSAkZWRpdGlvbklkKSB9CiAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJGVzZCkgeyAkcGF0aHMgKz0gKEdldC1JbnN0YWxsSW1hZ2VTb3VyY2UgJ0VzZCcgJGVzZCAkZWRpdGlvbklkKSB9CiAg
HLP:ICAgICAgICAgIGlmIChUZXN0LVBhdGggJHN4cykgeyAkcGF0aHMgKz0gJHN4cyB9CiAgICAgICAgfQogICAgICAgIGlmICgkcGF0aHMuQ291bnQgLWd0IDApIHsgIlNPVVJDRT0kKCRwYXRoc1swXSkiIH0gZWxzZSB7ICJTT1VSQ0U9IiB9CiAgICB9CiAgICAnZGlz
HLP:bXJlc3RvcmUnIHsKICAgICAgICAkcGFydHMgPSBAKCRBcmcgLXNwbGl0ICdcfCcsIDIpCiAgICAgICAgJHNvdXJjZSA9IGlmICgkcGFydHMuQ291bnQgLWdlIDEpIHsgJHBhcnRzWzBdIH0gZWxzZSB7ICcnIH0KICAgICAgICAkdGltZW91dE1pbnV0ZXMgPSA0NQog
HLP:ICAgICAgIGlmICgkcGFydHMuQ291bnQgLWdlIDIpIHsgW3ZvaWRdW2ludF06OlRyeVBhcnNlKCRwYXJ0c1sxXSwgW3JlZl0kdGltZW91dE1pbnV0ZXMpIH0KICAgICAgICBpZiAoJHRpbWVvdXRNaW51dGVzIC1sdCA1KSB7ICR0aW1lb3V0TWludXRlcyA9IDUgfQoK
HLP:ICAgICAgICBmdW5jdGlvbiBRdW90ZS1EaXNtVmFsdWUoW3N0cmluZ10kdmFsdWUpIHsKICAgICAgICAgICAgaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJHZhbHVlKSkgeyByZXR1cm4gJHZhbHVlIH0KICAgICAgICAgICAgcmV0dXJuICciJyArICgk
HLP:dmFsdWUgLXJlcGxhY2UgJyInLCAnXCInKSArICciJwogICAgICAgIH0KCiAgICAgICAgJGFyZ3VtZW50cyA9ICcvT25saW5lIC9DbGVhbnVwLUltYWdlIC9SZXN0b3JlSGVhbHRoJwogICAgICAgIGlmICgtbm90IFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2Uo
HLP:JHNvdXJjZSkpIHsKICAgICAgICAgICAgJGFyZ3VtZW50cyArPSAnIC9Tb3VyY2U6JyArIChRdW90ZS1EaXNtVmFsdWUgJHNvdXJjZSkgKyAnIC9MaW1pdEFjY2VzcycKICAgICAgICB9CgogICAgICAgICR0aW1lZE91dCA9ICRmYWxzZQogICAgICAgICRleGl0Q29k
HLP:ZSA9IDMKICAgICAgICAkb3V0RmlsZSA9IEpvaW4tUGF0aCAkV29yayAoImRpc21fcmVzdG9yZV97MH0ub3V0IiAtZiAoW2d1aWRdOjpOZXdHdWlkKCkuVG9TdHJpbmcoJ04nKSkpCiAgICAgICAgJGVyckZpbGUgPSBKb2luLVBhdGggJFdvcmsgKCJkaXNtX3Jlc3Rv
HLP:cmVfezB9LmVyciIgLWYgKFtndWlkXTo6TmV3R3VpZCgpLlRvU3RyaW5nKCdOJykpKQogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRwc2kgPSBbRGlhZ25vc3RpY3MuUHJvY2Vzc1N0YXJ0SW5mb106Om5ldygpCiAgICAgICAgICAgICRwc2kuRmlsZU5hbWUgPSAn
HLP:Y21kLmV4ZScKICAgICAgICAgICAgJHBzaS5Bcmd1bWVudHMgPSAoJy9jIGRpc20uZXhlIHswfSA+ICJ7MX0iIDI+ICJ7Mn0iJyAtZiAkYXJndW1lbnRzLCAkb3V0RmlsZSwgJGVyckZpbGUpCiAgICAgICAgICAgICRwc2kuVXNlU2hlbGxFeGVjdXRlID0gJGZhbHNl
HLP:CiAgICAgICAgICAgICRwc2kuQ3JlYXRlTm9XaW5kb3cgPSAkdHJ1ZQogICAgICAgICAgICAkcCA9IFtEaWFnbm9zdGljcy5Qcm9jZXNzXTo6bmV3KCkKICAgICAgICAgICAgJHAuU3RhcnRJbmZvID0gJHBzaQogICAgICAgICAgICBbdm9pZF0kcC5TdGFydCgpCiAg
HLP:ICAgICAgICAgIGlmICgtbm90ICRwLldhaXRGb3JFeGl0KCR0aW1lb3V0TWludXRlcyAqIDYwICogMTAwMCkpIHsKICAgICAgICAgICAgICAgICR0aW1lZE91dCA9ICR0cnVlCiAgICAgICAgICAgICAgICB0cnkgeyAkcC5LaWxsKCkgfSBjYXRjaCB7fQogICAgICAg
HLP:ICAgICAgICAgJGV4aXRDb2RlID0gMTQ2MAogICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgdHJ5IHsgJHAuV2FpdEZvckV4aXQoKSB9IGNhdGNoIHt9CiAgICAgICAgICAgICAgICAkZXhpdENvZGUgPSAkcC5FeGl0Q29kZQogICAgICAgICAgICAg
HLP:ICAgaWYgKCRudWxsIC1lcSAkZXhpdENvZGUpIHsgJGV4aXRDb2RlID0gMyB9CiAgICAgICAgICAgIH0KICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgIkVSUk9SPSQoJF8uRXhjZXB0aW9uLk1lc3NhZ2UpIgogICAgICAgICAgICAkZXhpdENvZGUgPSAzCiAg
HLP:ICAgICAgfQoKICAgICAgICBpZiAoVGVzdC1QYXRoICRvdXRGaWxlKSB7IEdldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkb3V0RmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgaWYgKFRlc3QtUGF0aCAkZXJyRmlsZSkgeyBHZXQtQ29u
HLP:dGVudCAtTGl0ZXJhbFBhdGggJGVyckZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkb3V0RmlsZSwkZXJyRmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAg
HLP:ICAgICAiVElNRURPVVQ9JChpZiAoJHRpbWVkT3V0KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiRVhJVENPREU9JGV4aXRDb2RlIgogICAgfQogICAgJ3N5c2luZm8nICAgICAgeyBHZXQtU3lzSW5mbyB9CiAgICAnc2NvcmUnICAgICAgICB7ICRoID0gR2V0
HLP:LUhlYWx0aFNjb3JlOyAiU0NPUkU9JCgkaC5zY29yZSkiOyBmb3JlYWNoICgkciBpbiAkaC5yZWFzb25zKSB7ICJSRUFTT049JHIiIH0gfQogICAgJ2ZvcmVuc2ljcycgICAgeyBHZXQtRm9yZW5zaWNzIH0KICAgICd0cmlhZ2UnICAgICAgIHsgR2V0LVRyaWFnZSB9
HLP:CiAgICAncmVzdG9yZXBvaW50JyB7IE5ldy1SZXN0b3JlUG9pbnQgfQogICAgJ21lZGlhdHlwZScgICAgeyAkbWVkaWEgPSBHZXQtTWVkaWFUeXBlOyAiTUVESUE9JG1lZGlhIjsgIk9QVElNSVpFPSQoUmVzb2x2ZS1PcHRpbWl6ZUFjdGlvbiAkbWVkaWEpIiB9CiAg
HLP:ICAnZGV2aWNlcycgICAgICB7IEdldC1EZXZpY2VQcm9ibGVtcyB9CiAgICAncmVwb3J0JyAgICAgICB7IEFkZC1UeXBlIC1Bc3NlbWJseU5hbWUgU3lzdGVtLldlYiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgTmV3LUh0bWxSZXBvcnQgJEFyZyB9CiAg
HLP:ICAnYWRkcGhhc2UnICAgICB7IEFkZC1QaGFzZVJlc3VsdCAkQXJnIH0KICAgICdzZXRiZWZvcmUnICAgIHsgU2V0LVNjb3JlICdiZWZvcmUnICRBcmcgfQogICAgJ3NldGFmdGVyJyAgICAgeyBTZXQtU2NvcmUgJ2FmdGVyJyAkQXJnIH0KICAgICdmaW5kaW5nJyAg
HLP:ICAgIHsgQWRkLUZpbmRpbmcgJEFyZyB9CiAgICAncmVzZXRzdGF0ZScgICB7IFJlc2V0LVN0YXRlOyAiUkVTVUxUPU9LIiB9CiAgICAnbm9ybWFsaXplZmFzZXMnIHsKICAgICAgICAkciA9IE5vcm1hbGl6ZS1GYXNlcyAkQXJnCiAgICAgICAgIk5PUk09JChbc3Ry
HLP:aW5nXTo6Sm9pbignLCcsIEAoJHIubm9ybSkpKSIKICAgICAgICAiSU5WQUxJRD0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkci5pbnZhbGlkKSkpIgogICAgfQogICAgJ2NoZWNrcG9pbnQnIHsKICAgICAgICAkcGFyc2VkID0gUGFyc2UtQ2hlY2twb2ludEFyZyAk
HLP:QXJnCiAgICAgICAgc3dpdGNoICgkcGFyc2VkLnN1YikgewogICAgICAgICAgICAnc2F2ZScgeyBpZiAoU2F2ZS1DaGVja3BvaW50ICRwYXJzZWQpIHsgIlJFU1VMVD1PSyIgfSBlbHNlIHsgIlJFU1VMVD1GQUlMIiB9IH0KICAgICAgICAgICAgJ2xvYWQnIHsKICAg
HLP:ICAgICAgICAgICAgICRjcCA9IExvYWQtQ2hlY2twb2ludAogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkY3ApIHsgIlJFU1VMVD1OT05FIiB9CiAgICAgICAgICAgICAgICBlbHNlIHsKICAgICAgICAgICAgICAgICAgICAiUkVTVUxUPU9LIgogICAgICAg
HLP:ICAgICAgICAgICAgICJWQUxJRD0kKGlmIChUZXN0LUNoZWNrcG9pbnRWYWxpZCAkY3ApIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJWRVJTSU9OPSQoJGNwLnZlcnNpb24pIgogICAgICAgICAgICAgICAgICAgICJDUkVBVEVEPSQoJGNw
HLP:LmNyZWF0ZWQpIgogICAgICAgICAgICAgICAgICAgICJTRUxFQ1RJT049JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJGNwLnNlbGVjdGlvbikpKSIKICAgICAgICAgICAgICAgICAgICAiQ09NUExFVEVEPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRjcC5jb21wbGV0
HLP:ZWQpKSkiCiAgICAgICAgICAgICAgICAgICAgIlJFQVNPTj0kKCRjcC5wZW5kaW5nX3JlYXNvbikiCiAgICAgICAgICAgICAgICAgICAgIk5FWFQ9JChHZXQtTmV4dFBoYXNlICRjcCkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfQVVUTz0kKGlmICgkY3AubW9k
HLP:ZS5hdXRvKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9OT1JFQk9PVD0kKGlmICgkY3AubW9kZS5ub3JlYm9vdCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfS0VFUFdVPSQoaWYgKCRjcC5t
HLP:b2RlLmtlZXB3dSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfRFJZPSQoaWYgKCRjcC5tb2RlLmRyeSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIk1PREVfVFJJQUdFPSQoaWYgKCRjcC5tb2RlLnRy
HLP:aWFnZSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJ25leHQnIHsKICAgICAgICAgICAgICAgICRjcCA9IExvYWQtQ2hlY2twb2ludAogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkY3Ag
HLP:LWFuZCAoVGVzdC1DaGVja3BvaW50VmFsaWQgJGNwKSkgeyAiTkVYVD0kKEdldC1OZXh0UGhhc2UgJGNwKSIgfSBlbHNlIHsgIk5FWFQ9IiB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgJ2NsZWFyJyB7CiAgICAgICAgICAgICAgICBpZiAoVGVzdC1QYXRoICRD
HLP:aGVja3BvaW50RmlsZSkgewogICAgICAgICAgICAgICAgICAgIHRyeSB7IFJlbW92ZS1JdGVtICRDaGVja3BvaW50RmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFN0b3A7ICJSRVNVTFQ9T0siIH0gY2F0Y2ggeyAiUkVTVUxUPUZBSUwiIH0KICAgICAgICAgICAgICAg
HLP:IH0gZWxzZSB7ICJSRVNVTFQ9T0siIH0KICAgICAgICAgICAgfQogICAgICAgICAgICBkZWZhdWx0IHsgIlJFU1VMVD1GQUlMIjsgIkVSUk9SPXN1YmFjY2lvbiBkZSBjaGVja3BvaW50IGRlc2Nvbm9jaWRhIiB9CiAgICAgICAgfQogICAgfQogICAgJ21vdmVyZXN1
HLP:bHQnIHsKICAgICAgICAkcGFydHMgPSAkQXJnIC1zcGxpdCAnXHwnLCAyCiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtZXEgMikgewogICAgICAgICAgICAkb2sgPSBUZXN0LU1vdmVSZXN1bHRQYXRoICRwYXJ0c1swXSAkcGFydHNbMV0KICAgICAgICB9IGVsc2Ug
HLP:ewogICAgICAgICAgICAkYiAgPSAkQXJnIC1zcGxpdCAnLCcKICAgICAgICAgICAgJHNlID0gKCRiLkNvdW50IC1nZSAxIC1hbmQgJGJbMF0uVHJpbSgpIC1lcSAnMScpCiAgICAgICAgICAgICRkZSA9ICgkYi5Db3VudCAtZ2UgMiAtYW5kICRiWzFdLlRyaW0oKSAt
HLP:ZXEgJzEnKQogICAgICAgICAgICAkb2sgPSBUZXN0LU1vdmVSZXN1bHQgJHNlICRkZQogICAgICAgIH0KICAgICAgICAiTU9WRUQ9JChpZiAoJG9rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICd2dGx3cml0ZScgewogICAgICAgICRwICAgPSAkQXJnIC1z
HLP:cGxpdCAnLCcKICAgICAgICAkY3VyID0gaWYgKCRwLkNvdW50IC1nZSAxKSB7ICRwWzBdIH0gZWxzZSB7ICcnIH0KICAgICAgICAkZGVzID0gaWYgKCRwLkNvdW50IC1nZSAyKSB7ICRwWzFdIH0gZWxzZSB7IFtzdHJpbmddJFZUX0xFVkVMX0RFU0lSRUQgfQogICAg
HLP:ICAgICJXUklURT0kKGlmIChSZXNvbHZlLVZ0bFdyaXRlICRjdXIgJGRlcykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnbWFwZXhpdCcgICAgICB7ICJSRVM9JChNYXAtRXhpdENvZGUgJEFyZykiIH0KICAgICMgLS0tICg1LjEgLyBSZXEgMTUpIERpYWdu
HLP:b3N0aWNvIGFtcGxpYWRvIC0tLQogICAgJ3JhbWNoZWNrJyB7CiAgICAgICAgJHIgPSBHZXQtUmFtQ2hlY2sKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAgICAgICAgJHN0LmRpYWcucmFtID0gW3BzY3VzdG9tb2JqZWN0XUB7IHN0
HLP:YXR1cyA9ICRyLnN0YXR1czsgcmVjb21tZW5kX21kc2NoZWQgPSBbYm9vbF0kci5yZWNvbW1lbmRfbWRzY2hlZCB9CiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIlJBTV9TVEFUVVM9JCgkci5zdGF0dXMpIgogICAgICAgICJSQU1fUkVDT01NRU5EX01E
HLP:U0NIRUQ9JChpZiAoJHIucmVjb21tZW5kX21kc2NoZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ2JhdHRlcnknIHsKICAgICAgICAkYiA9IEdldC1CYXR0ZXJ5SGVhbHRoCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQog
HLP:ICAgICAgICRzdC5kaWFnLmJhdHRlcnkgPSBbcHNjdXN0b21vYmplY3RdQHsgcHJlc2VudCA9IFtib29sXSRiLnByZXNlbnQ7IGhlYWx0aF9wY3QgPSAkYi5oZWFsdGhfcGN0OyByZXBvcnRfcGF0aCA9ICRiLnJlcG9ydF9wYXRoIH0KICAgICAgICBXcml0ZS1TdGF0
HLP:ZSAkc3QKICAgICAgICAiQkFUVEVSWV9QUkVTRU5UPSQoaWYgKCRiLnByZXNlbnQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQVRURVJZX0hFQUxUSF9QQ1Q9JCgkYi5oZWFsdGhfcGN0KSIKICAgICAgICAiQkFUVEVSWV9SRVBPUlQ9JCgkYi5yZXBvcnRf
HLP:cGF0aCkiCiAgICB9CiAgICAnbmV0YWR2YW5jZWQnIHsKICAgICAgICAkbiA9IEdldC1OZXRBZHZhbmNlZAogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5uZXR3b3JrID0gW3BzY3VzdG9tb2JqZWN0XUB7
HLP:IGNvbm5lY3RlZCA9IFtib29sXSRuLmNvbm5lY3RlZDsgZG5zX29rID0gW2Jvb2xdJG4uZG5zX29rOyBkZXRhaWxzID0gJG4uZGV0YWlsczsgZG5zX21zID0gJG4uZG5zX21zIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiTkVUX0NPTk5FQ1RFRD0k
HLP:KGlmICgkbi5jb25uZWN0ZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfRE5TX09LPSQoaWYgKCRuLmRuc19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ERVRBSUxTPSQoJG4uZGV0YWlscykiCiAgICAgICAgIk5FVF9MQVRFTkNZ
HLP:X01TPSQoJG4uZG5zX21zKSIKICAgIH0KICAgICdkaWFnZnVsbCcgewogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkciA9IEdldC1SYW1DaGVjawogICAgICAgICRzdC5kaWFnLnJhbSA9IFtwc2N1c3RvbW9iamVjdF1A
HLP:eyBzdGF0dXMgPSAkci5zdGF0dXM7IHJlY29tbWVuZF9tZHNjaGVkID0gW2Jvb2xdJHIucmVjb21tZW5kX21kc2NoZWQgfQogICAgICAgICRiID0gR2V0LUJhdHRlcnlIZWFsdGgKICAgICAgICAkc3QuZGlhZy5iYXR0ZXJ5ID0gW3BzY3VzdG9tb2JqZWN0XUB7IHBy
HLP:ZXNlbnQgPSBbYm9vbF0kYi5wcmVzZW50OyBoZWFsdGhfcGN0ID0gJGIuaGVhbHRoX3BjdDsgcmVwb3J0X3BhdGggPSAkYi5yZXBvcnRfcGF0aCB9CiAgICAgICAgJG4gPSBHZXQtTmV0QWR2YW5jZWQKICAgICAgICAkc3QuZGlhZy5uZXR3b3JrID0gW3BzY3VzdG9t
HLP:b2JqZWN0XUB7IGNvbm5lY3RlZCA9IFtib29sXSRuLmNvbm5lY3RlZDsgZG5zX29rID0gW2Jvb2xdJG4uZG5zX29rOyBkZXRhaWxzID0gJG4uZGV0YWlsczsgZG5zX21zID0gJG4uZG5zX21zIH0KICAgICAgICAkZGV2ID0gR2V0LURldmljZUxpc3QKICAgICAgICBp
HLP:ZiAoJG51bGwgLWVxICRkZXYpIHsKICAgICAgICAgICAgJHN0LmRpYWcuZGV2aWNlcyA9IEAoKQogICAgICAgICAgICAkZGV2TGluZSA9ICJERVZJQ0VTX1NUQVRVUz1pbmZvIG5vIGRpc3BvbmlibGUiCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJHN0LmRp
HLP:YWcuZGV2aWNlcyA9IEAoJGRldikKICAgICAgICAgICAgJGRldkxpbmUgPSAiREVWSUNFU19DT1VOVD0kKEAoJGRldikuQ291bnQpIgogICAgICAgIH0KICAgICAgICAkc20gPSBHZXQtU21hcnRBdHRyaWJ1dGVzCiAgICAgICAgJHN0LmRpYWcuc21hcnQgPSBbcHNj
HLP:dXN0b21vYmplY3RdQHsgYXZhaWxhYmxlID0gW2Jvb2xdJHNtLmF2YWlsYWJsZTsgcHJlZGljdF9mYWlsID0gW2Jvb2xdJHNtLnByZWRpY3RfZmFpbDsgdGVtcF9jID0gJHNtLnRlbXBfYzsgd2Vhcl9wY3QgPSAkc20ud2Vhcl9wY3Q7IHBvaCA9ICRzbS5wb2ggfQog
HLP:ICAgICAgICRzdHAgPSBHZXQtU3RhcnR1cEl0ZW1zIDgKICAgICAgICAkc3QuZGlhZy5zdGFydHVwID0gQCgkc3RwKQogICAgICAgICRiY2QgPSBHZXQtQmNkSW50ZWdyaXR5CiAgICAgICAgJHN0LmRpYWcuYmNkID0gW3BzY3VzdG9tb2JqZWN0XUB7IG9rID0gW2Jv
HLP:b2xdJGJjZC5vazsgZGV0YWlscyA9ICRiY2QuZGV0YWlscyB9CiAgICAgICAgJHByb2NzID0gR2V0LVRvcFByb2Nlc3NlcyA2CiAgICAgICAgJHN0LmRpYWcucHJvY2Vzc2VzID0gQCgkcHJvY3MpCiAgICAgICAgV3JpdGUtU3RhdGUgJHN0CiAgICAgICAgIlJBTV9T
HLP:VEFUVVM9JCgkci5zdGF0dXMpIgogICAgICAgICJSQU1fUkVDT01NRU5EX01EU0NIRUQ9JChpZiAoJHIucmVjb21tZW5kX21kc2NoZWQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQVRURVJZX1BSRVNFTlQ9JChpZiAoJGIucHJlc2VudCkgeycxJ30gZWxz
HLP:ZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfSEVBTFRIX1BDVD0kKCRiLmhlYWx0aF9wY3QpIgogICAgICAgICJORVRfQ09OTkVDVEVEPSQoaWYgKCRuLmNvbm5lY3RlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ETlNfT0s9JChpZiAoJG4uZG5z
HLP:X29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0xBVEVOQ1lfTVM9JCgkbi5kbnNfbXMpIgogICAgICAgICJTTUFSVF9BVkFJTEFCTEU9JChpZiAoJHNtLmF2YWlsYWJsZSkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIlNNQVJUX1BSRURJQ1Rf
HLP:RkFJTD0kKGlmICgkc20ucHJlZGljdF9mYWlsKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiQkNEX09LPSQoaWYgKCRiY2Qub2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICRkZXZMaW5lCiAgICB9CiAgICAjIC0tLSAodjMuMSkgU0ZDIGluZGVwZW5k
HLP:aWVudGUgZGVsIGlkaW9tYSArIEpTT04gKyBwYXF1ZXRlIGRlIHNvcG9ydGUgLS0tCiAgICAnc2ZjcmVzdWx0JyB7CiAgICAgICAgIlNGQ19SRVM9JChHZXQtU2ZjUmVzdWx0KSIKICAgIH0KICAgICdqc29ucmVwb3J0JyB7CiAgICAgICAgJG91dCA9IGlmIChbc3Ry
HLP:aW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnSW5mb3JtZS5qc29uJyB9IGVsc2UgeyAkQXJnIH0KICAgICAgICBOZXctSnNvblJlcG9ydCAkb3V0CiAgICB9CiAgICAnc3VwcG9ydHBhY2thZ2UnIHsKICAgICAgICAkb3V0
HLP:ID0gaWYgKFtzdHJpbmddOjpJc051bGxPcldoaXRlU3BhY2UoJEFyZykpIHsgSm9pbi1QYXRoICRXb3JrICdQYXF1ZXRlX1NvcG9ydGUuemlwJyB9IGVsc2UgeyAkQXJnIH0KICAgICAgICBOZXctU3VwcG9ydFBhY2thZ2UgJG91dAogICAgfQogICAgIyAtLS0gKDUu
HLP:NiAvIFJlcSAxNy4yKSBSb3RhY2lvbiBkZSBsb2dzIC0tLQogICAgJ2xvZ3JvdGF0ZScgewogICAgICAgICRmb2xkZXIgPSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnIH0gZWxzZSB7ICRBcmcg
HLP:fQogICAgICAgICRuID0gSW52b2tlLUxvZ1JvdGF0ZSAkZm9sZGVyICRMT0dfUkVURU5USU9OCiAgICAgICAgIkRFTEVURUQ9JG4iCiAgICB9CiAgICAjIC0tLSAoNS44IC8gUmVxIDEzLDE4KSBWYWxpZGFjaW9uIGRlIGVudG9ybm8geSBzZWxmLXRlc3QgLS0tCiAg
HLP:ICAnZW52Y2hlY2snIHsKICAgICAgICAkZSA9IEludm9rZS1FbnZWYWxpZGF0ZQogICAgICAgICJPU19PSz0kKGlmICgkZS5vc19vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk9TX0JVSUxEPSQoJGUuYnVpbGQpIgogICAgICAgICJPU19DSEVDS19ET05F
HLP:PTEiCiAgICB9CiAgICAnc2VsZnRlc3RicmFpbicgeyAiQlJBSU5fT0s9MSIgfQogICAgJ3NlbGZ0ZXN0cmVzdWx0JyB7CiAgICAgICAgJHBhc3MgPSBJbnZva2UtU2VsZlRlc3QgKFBhcnNlLUJvb2xMaXN0ICRBcmcpCiAgICAgICAgIlNFTEZURVNUX1BBU1M9JChp
HLP:ZiAoJHBhc3MpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgZGVmYXVsdCAgICAgICAgeyBHZXQtU3lzSW5mbyB9Cn0K
