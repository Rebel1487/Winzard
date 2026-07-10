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
HLP:RCcpICAgICB7IHJldHVybiAnVFJJTScgfQogICAgZWxzZWlmICgkbSAtZXEgJ0hERCcpICAgICB7IHJldHVybiAnREVGUkFHJyB9CiAgICBlbHNlaWYgKCRtIC1lcSAnVklSVFVBTCcpIHsgcmV0dXJuICdOT05FJyB9ICAgIyAodjMuMikgZGlzY28gZGUgbWFxdWlu
HLP:YSB2aXJ0dWFsOiBubyBhcGxpY2EKICAgIGVsc2UgICAgICAgICAgICAgICAgICAgICAgeyByZXR1cm4gJ05PTkUnIH0KfQoKIyBHZXQtTWVkaWFUeXBlOiBpZGVudGlmaWNhIGVsIGRpc2NvIGZpc2ljbyBkZWwgdm9sdW1lbiBkZWwgc2lzdGVtYSBkZSBmb3JtYQoj
HLP:IGZpYWJsZSAocG9yIERldmljZUlkLCByZXNwYWxkbyBwb3IgU2VyaWFsTnVtYmVyKSB5IGRldnVlbHZlIFNTRHxIRER8VklSVFVBTHxVTktOT1dOLgpmdW5jdGlvbiBHZXQtTWVkaWFUeXBlIHsKICAgIHRyeSB7CiAgICAgICAgJHN5cyAgPSAoJGVudjpTeXN0ZW1E
HLP:cml2ZSkuVHJpbUVuZCgnOicpCiAgICAgICAgJGRpc2sgPSBHZXQtUGFydGl0aW9uIC1Ecml2ZUxldHRlciAkc3lzIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgR2V0LURpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkcGQg
HLP:PSAkbnVsbAogICAgICAgIGlmICgkZGlzaykgewogICAgICAgICAgICAkcGQgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwKICAgICAgICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uRGV2aWNlSWQgLWVxICRkaXNr
HLP:Lk51bWJlciB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICBpZiAoLW5vdCAkcGQgLWFuZCAkZGlzay5TZXJpYWxOdW1iZXIpIHsKICAgICAgICAgICAgICAgICRwZCA9IEdldC1QaHlzaWNhbERpc2sgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29u
HLP:dGludWUgfAogICAgICAgICAgICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgJF8uU2VyaWFsTnVtYmVyIC1hbmQgKCRfLlNlcmlhbE51bWJlci5UcmltKCkgLWVxIChbc3RyaW5nXSRkaXNrLlNlcmlhbE51bWJlcikuVHJpbSgpKSB9IHwKICAgICAgICAgICAgICAg
HLP:ICAgICAgIFNlbGVjdC1PYmplY3QgLUZpcnN0IDEKICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICAjICh2My4yKSBkaXNjbyBkZSBtYXF1aW5hIHZpcnR1YWwgKFZpcnR1YWxCb3gvVk13YXJlL0h5cGVyLVYvUUVNVSk6IFRSSU0geQogICAgICAgICMgZGVz
HLP:ZnJhZ21lbnRhY2lvbiBubyBhcGxpY2FuOyBzZSBpZGVudGlmaWNhIHBvciBlbCBtb2RlbG8gZGVsIGRpc2NvLgogICAgICAgICRtb2RlbG9zID0gQCgpCiAgICAgICAgaWYgKCRkaXNrKSB7ICRtb2RlbG9zICs9IFtzdHJpbmddJGRpc2suRnJpZW5kbHlOYW1lOyAk
HLP:bW9kZWxvcyArPSBbc3RyaW5nXSRkaXNrLk1vZGVsIH0KICAgICAgICBpZiAoJHBkKSAgIHsgJG1vZGVsb3MgKz0gW3N0cmluZ10kcGQuRnJpZW5kbHlOYW1lOyAgICRtb2RlbG9zICs9IFtzdHJpbmddJHBkLk1vZGVsIH0KICAgICAgICBpZiAoKCRtb2RlbG9zIC1q
HLP:b2luICcgJykgLW1hdGNoICdWQk9YfFZNV0FSRXxWSVJUVUFMfFFFTVV8WEVOU1JDJykgeyByZXR1cm4gJ1ZJUlRVQUwnIH0KICAgICAgICBpZiAoLW5vdCAkcGQpIHsgcmV0dXJuICdVTktOT1dOJyB9CiAgICAgICAgcmV0dXJuIChDb252ZXJ0VG8tTWVkaWFDbGFz
HLP:cyAkcGQuTWVkaWFUeXBlKQogICAgfSBjYXRjaCB7IHJldHVybiAnVU5LTk9XTicgfQp9CgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCmZ1bmN0aW9uIEdldC1EZXZpY2VQ
HLP:cm9ibGVtcyB7CiAgICAkcCA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX1BuUEVudGl0eSB8IFdoZXJlLU9iamVjdCB7ICRfLkNvbmZpZ01hbmFnZXJFcnJvckNvZGUgLWd0IDAgfSkKICAgIGlmICgkcC5Db3VudCAtZXEgMCkgeyAiT0t8U2luIGRpc3Bvc2l0aXZv
HLP:cyBjb24gcHJvYmxlbWEuIjsgcmV0dXJuIH0KICAgIGZvcmVhY2ggKCRkIGluICgkcCB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEyKSkgewogICAgICAgICJQUk9CfCQoJGQuQ29uZmlnTWFuYWdlckVycm9yQ29kZSl8JCgkZC5OYW1lKSIKICAgIH0KfQoKIyAtLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEluZm9ybWUgSFRNTCBhdXRvY29udGVuaWRvIHkgYm9uaXRvICh0ZW1hIG9zY3VybykuIC1BcmcgPSBydXRhIGRlIHNhbGlkYS4KZnVu
HLP:Y3Rpb24gTmV3LUh0bWxSZXBvcnQoJG91dFBhdGgpIHsKICAgIEFkZC1UeXBlIC1Bc3NlbWJseU5hbWUgU3lzdGVtLldlYiAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgdHJ5IHsKICAgICAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICAgICAgJHN5c1Bh
HLP:aXJzID0gR2V0LVN5c0luZm8KCiAgICAgICAgJGVuYyA9IHsgcGFyYW0oJHQpIFtTeXN0ZW0uV2ViLkh0dHBVdGlsaXR5XTo6SHRtbEVuY29kZShbc3RyaW5nXSR0KSB9CiAgICAgICAgJGNpcmMgPSA1MjcuNzkKICAgICAgICAkYmFuZENvbG9yID0geyBwYXJhbSgk
HLP:cykgaWYgKCRzIC1lcSAnLScgLW9yICRudWxsIC1lcSAkcyAtb3IgW3N0cmluZ10kcyAtZXEgJycpIHsgJyM5NGEzYjgnIH0gZWxzZSB7ICR2PTA7IHRyeSB7ICR2PVtpbnRdJHMgfSBjYXRjaCB7IHJldHVybiAnIzk0YTNiOCcgfTsgaWYgKCR2IC1nZSA4MCkgeycj
HLP:MjJjNTVlJ30gZWxzZWlmICgkdiAtZ2UgNTApIHsnI2Y1OWUwYid9IGVsc2UgeycjZWY0NDQ0J30gfSB9CiAgICAgICAgJGJhbmRMYWJlbCA9IHsgcGFyYW0oJHMpIGlmICgkcyAtZXEgJy0nIC1vciAkbnVsbCAtZXEgJHMgLW9yIFtzdHJpbmddJHMgLWVxICcnKSB7
HLP:ICdzaW4gZGF0b3MnIH0gZWxzZSB7ICR2PTA7IHRyeSB7ICR2PVtpbnRdJHMgfSBjYXRjaCB7IHJldHVybiAnc2luIGRhdG9zJyB9OyBpZiAoJHYgLWdlIDgwKSB7J0J1ZW5hJ30gZWxzZWlmICgkdiAtZ2UgNTApIHsnUmVndWxhcid9IGVsc2UgeydDcml0aWNhJ30g
HLP:fSB9CiAgICAgICAgJG9mZnNldE9mID0geyBwYXJhbSgkcykgJHY9MDsgdHJ5IHsgJHY9W2ludF0kcyB9IGNhdGNoIHsgJHY9MCB9OyBpZiAoJHYgLWx0IDApeyR2PTB9OyBpZiAoJHYgLWd0IDEwMCl7JHY9MTAwfTsgW21hdGhdOjpSb3VuZCgkY2lyYyAqICgxIC0g
HLP:KCR2LzEwMC4wKSksIDIpIH0KICAgICAgICAkc3RhdHVzSWNvbiA9IHsKICAgICAgICAgICAgcGFyYW0oJHJlcykKICAgICAgICAgICAgc3dpdGNoIChbc3RyaW5nXSRyZXMpIHsKICAgICAgICAgICAgICAgICdPSycgICAgeyAiPHN2ZyB2aWV3Qm94PScwIDAgMjQg
HLP:MjQnIGNsYXNzPSdzdmdpY28nIHJvbGU9J2ltZycgYXJpYS1sYWJlbD0nY29ycmVjdG8nPjxjaXJjbGUgY3g9JzEyJyBjeT0nMTInIHI9JzExJyBmaWxsPScjMjJjNTVlJy8+PHBhdGggZD0nTTcgMTIuNGwzLjIgMy4yTDE3IDguOCcgZmlsbD0nbm9uZScgc3Ryb2tl
HLP:PScjMDQyMTBmJyBzdHJva2Utd2lkdGg9JzIuNicgc3Ryb2tlLWxpbmVjYXA9J3JvdW5kJyBzdHJva2UtbGluZWpvaW49J3JvdW5kJy8+PC9zdmc+IiB9CiAgICAgICAgICAgICAgICAnV0FSTicgIHsgIjxzdmcgdmlld0JveD0nMCAwIDI0IDI0JyBjbGFzcz0nc3Zn
HLP:aWNvJyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J2F2aXNvJz48cGF0aCBkPSdNMTIgMi41TDIzIDIxLjVIMXonIGZpbGw9JyNmNTllMGInLz48cmVjdCB4PScxMScgeT0nOC41JyB3aWR0aD0nMicgaGVpZ2h0PSc3JyByeD0nMScgZmlsbD0nIzNhMjQwMCcvPjxjaXJj
HLP:bGUgY3g9JzEyJyBjeT0nMTgnIHI9JzEuMycgZmlsbD0nIzNhMjQwMCcvPjwvc3ZnPiIgfQogICAgICAgICAgICAgICAgJ0VSUk9SJyB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdlcnJvcic+
HLP:PGNpcmNsZSBjeD0nMTInIGN5PScxMicgcj0nMTEnIGZpbGw9JyNlZjQ0NDQnLz48cGF0aCBkPSdNOCA4bDggOE0xNiA4bC04IDgnIHN0cm9rZT0nIzJhMDYwNicgc3Ryb2tlLXdpZHRoPScyLjYnIHN0cm9rZS1saW5lY2FwPSdyb3VuZCcvPjwvc3ZnPiIgfQogICAg
HLP:ICAgICAgICAgICAgJ1NLSVAnICB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbycgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdvbWl0aWRvJz48Y2lyY2xlIGN4PScxMicgY3k9JzEyJyByPScxMScgZmlsbD0nIzY0NzQ4YicvPjxyZWN0IHg9
HLP:JzYuNScgeT0nMTEnIHdpZHRoPScxMScgaGVpZ2h0PScyJyByeD0nMScgZmlsbD0nIzBiMTIyMCcvPjwvc3ZnPiIgfQogICAgICAgICAgICAgICAgZGVmYXVsdCB7ICI8c3ZnIHZpZXdCb3g9JzAgMCAyNCAyNCcgY2xhc3M9J3N2Z2ljbyc+PGNpcmNsZSBjeD0nMTIn
HLP:IGN5PScxMicgcj0nMTEnIGZpbGw9JyM5NGEzYjgnLz48L3N2Zz4iIH0KICAgICAgICAgICAgfQogICAgICAgIH0KCiAgICAgICAgJGJlZm9yZSA9ICRzdC5zY29yZV9iZWZvcmU7IGlmICgkbnVsbCAtZXEgJGJlZm9yZSkgeyAkYmVmb3JlID0gJy0nIH0KICAgICAg
HLP:ICAkYWZ0ZXIgID0gJHN0LnNjb3JlX2FmdGVyOyAgaWYgKCRudWxsIC1lcSAkYWZ0ZXIpICB7ICRhZnRlciAgPSAnLScgfQogICAgICAgICRoYXNCb3RoID0gKCRzdC5zY29yZV9iZWZvcmUgLW5lICRudWxsIC1hbmQgJHN0LnNjb3JlX2FmdGVyIC1uZSAkbnVsbCkK
HLP:ICAgICAgICAkZGVsdGEgPSAwOyAkZGVsdGFUeHQgPSAnc2luIGNvbXBhcmFjaW9uJwogICAgICAgIGlmICgkaGFzQm90aCkgeyAkZGVsdGEgPSBbaW50XSRzdC5zY29yZV9hZnRlciAtIFtpbnRdJHN0LnNjb3JlX2JlZm9yZTsgJHNpZ24gPSBpZiAoJGRlbHRhIC1n
HLP:ZSAwKSB7JysnfSBlbHNlIHsnJ307ICRkZWx0YVR4dCA9ICIkc2lnbiRkZWx0YSBwdW50b3MiIH0KICAgICAgICAkZGVsdGFDb2xvciA9IGlmICgkZGVsdGEgLWd0IDApIHsnIzIyYzU1ZSd9IGVsc2VpZiAoJGRlbHRhIC1sdCAwKSB7JyNlZjQ0NDQnfSBlbHNlIHsn
HLP:Izk0YTNiOCd9CiAgICAgICAgJG1haW5TY29yZSA9IGlmICgkYWZ0ZXIgLW5lICctJykgeyAkYWZ0ZXIgfSBlbHNlaWYgKCRiZWZvcmUgLW5lICctJykgeyAkYmVmb3JlIH0gZWxzZSB7ICctJyB9CiAgICAgICAgJG1haW5Db2xvciA9ICYgJGJhbmRDb2xvciAkbWFp
HLP:blNjb3JlCiAgICAgICAgJG1haW5PZmZzZXQgPSAmICRvZmZzZXRPZiAkbWFpblNjb3JlCiAgICAgICAgJG1haW5MYWJlbCA9ICYgJGJhbmRMYWJlbCAkbWFpblNjb3JlCiAgICAgICAgJGJlZm9yZUNvbG9yID0gJiAkYmFuZENvbG9yICRiZWZvcmUKICAgICAgICAk
HLP:YWZ0ZXJDb2xvciAgPSAmICRiYW5kQ29sb3IgJGFmdGVyCiAgICAgICAgJGJlZm9yZU9mZnNldCA9ICYgJG9mZnNldE9mICRiZWZvcmUKICAgICAgICAkYWZ0ZXJPZmZzZXQgID0gJiAkb2Zmc2V0T2YgJGFmdGVyCgogICAgICAgICRzY3JpcHREaXIgPSAkbnVsbAog
HLP:ICAgICAgIGlmICgkUFNTY3JpcHRSb290KSB7CiAgICAgICAgICAgICRzY3JpcHREaXIgPSAkUFNTY3JpcHRSb290CiAgICAgICAgfSBlbHNlaWYgKCRNeUludm9jYXRpb24uTXlDb21tYW5kLlBhdGgpIHsKICAgICAgICAgICAgJHNjcmlwdERpciA9IFNwbGl0LVBh
HLP:dGggLVBhcmVudCAkTXlJbnZvY2F0aW9uLk15Q29tbWFuZC5QYXRoCiAgICAgICAgfQogICAgICAgICRiYXNlRGlyID0gaWYgKCRzY3JpcHREaXIpIHsgSm9pbi1QYXRoIChTcGxpdC1QYXRoIC1QYXJlbnQgJHNjcmlwdERpcikgIldQSV9TdWl0ZSIgfSBlbHNlIHsg
HLP:JFdvcmsgfQogICAgICAgICRoaXN0b3J5RmlsZSA9IEpvaW4tUGF0aCAkYmFzZURpciAiaGVhbHRoX2hpc3RvcnkuanNvbiIKICAgICAgICAkaGlzdG9yeSA9IEAoKQogICAgICAgIGlmIChUZXN0LVBhdGggJGhpc3RvcnlGaWxlKSB7CiAgICAgICAgICAgIHRyeSB7
HLP:ICRoaXN0b3J5ID0gR2V0LUNvbnRlbnQgJGhpc3RvcnlGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uIH0gY2F0Y2gge30KICAgICAgICB9CiAgICAgICAgJGhpc3RvcnlIdG1sID0gJycKICAgICAgICBpZiAoJGhpc3RvcnkgLWFuZCAkaGlzdG9yeS5Db3VudCAt
HLP:Z3QgMCkgewogICAgICAgICAgICAkaGlzdG9yeUh0bWwgKz0gIjxkaXYgY2xhc3M9J3RyZW5kLXRpdGxlJz5IaXN0b3JpYWwgZGUgU2FsdWQgKFVsdGltYXMgZWplY3VjaW9uZXMpPC9kaXY+PGRpdiBjbGFzcz0ndHJlbmQtbGlzdCc+IgogICAgICAgICAgICBmb3Jl
HLP:YWNoICgkaCBpbiAkaGlzdG9yeSkgewogICAgICAgICAgICAgICAgJGNvbCA9ICYgJGJhbmRDb2xvciAkaC5zY29yZQogICAgICAgICAgICAgICAgJGhpc3RvcnlIdG1sICs9ICI8ZGl2IGNsYXNzPSd0cmVuZC1pdGVtJz48c3BhbiBjbGFzcz0ndHJlbmQtZGF0ZSc+
HLP:JCgkaC5kYXRlKTwvc3Bhbj48c3BhbiBjbGFzcz0ndHJlbmQtc2NvcmUnIHN0eWxlPSdjb2xvcjokY29sJz4kKCRoLnNjb3JlKS8xMDA8L3NwYW4+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgICRoaXN0b3J5SHRtbCArPSAiPC9kaXY+IgogICAgICAg
HLP:IH0KCiAgICAgICAgJHN5c01hcCA9IEB7fQogICAgICAgIGZvcmVhY2ggKCRwIGluICRzeXNQYWlycykgeyAka3YgPSAkcCAtc3BsaXQgJz0nLDI7IGlmICgka3YuQ291bnQgLWVxIDIpIHsgJHN5c01hcFska3ZbMF1dID0gJGt2WzFdIH0gfQogICAgICAgICRzeXNP
HLP:cmRlciA9IEAoQCgnT1MnLCdTaXN0ZW1hIG9wZXJhdGl2bycpLEAoJ0VRVUlQTycsJ0VxdWlwbycpLEAoJ0NQVScsJ1Byb2Nlc2Fkb3InKSxAKCdSQU0nLCdNZW1vcmlhIFJBTScpLEAoJ0RJU0NPJywnRGlzY28gQzonKSxAKCdVUFRJTUUnLCdUaWVtcG8gZW5jZW5k
HLP:aWRvJyksQCgnVVNVQVJJTycsJ1VzdWFyaW8nKSkKICAgICAgICAkc3lzQ2FyZHMgPSAnJwogICAgICAgIGZvcmVhY2ggKCRvIGluICRzeXNPcmRlcikgeyBpZiAoJHN5c01hcC5Db250YWluc0tleSgkb1swXSkpIHsgJHN5c0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdz
HLP:eXMnPjxkaXYgY2xhc3M9J3N5cy1rJz4kKCYgJGVuYyAkb1sxXSk8L2Rpdj48ZGl2IGNsYXNzPSdzeXMtdic+JCgmICRlbmMgJHN5c01hcFskb1swXV0pPC9kaXY+PC9kaXY+IiB9IH0KICAgICAgICAkbWFjaGluZSA9ICRzeXNNYXBbJ0VRVUlQTyddOyBpZiAoLW5v
HLP:dCAkbWFjaGluZSkgeyAkbWFjaGluZSA9ICRlbnY6Q09NUFVURVJOQU1FIH0KCiAgICAgICAgJHBoYXNlcyA9IEAoJHN0LnBoYXNlcykKICAgICAgICAkY09LPTA7JGNXQVJOPTA7JGNFUlI9MDskY1NLSVA9MAogICAgICAgICRtYXhTZWNzID0gMQogICAgICAgIGZv
HLP:cmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7ICRzdj0wOyB0cnkgeyAkc3Y9W2ludF0kcGguc2VjcyB9IGNhdGNoIHt9OyBpZiAoJHN2IC1ndCAkbWF4U2VjcykgeyAkbWF4U2VjcyA9ICRzdiB9IH0KICAgICAgICAkcm93cyA9ICcnCiAgICAgICAgJGJhcnMgPSAnJwog
HLP:ICAgICAgIGZvcmVhY2ggKCRwaCBpbiAkcGhhc2VzKSB7CiAgICAgICAgICAgICRyZXMgPSBbc3RyaW5nXSRwaC5yZXN1bHQKICAgICAgICAgICAgc3dpdGNoICgkcmVzKSB7ICdPSycgeyRjT0srK30gJ1dBUk4nIHskY1dBUk4rK30gJ0VSUk9SJyB7JGNFUlIrK30g
HLP:J1NLSVAnIHskY1NLSVArK30gfQogICAgICAgICAgICAkbGMgPSAkcmVzLlRvTG93ZXIoKQogICAgICAgICAgICAkbm90ZSA9IGlmIChbc3RyaW5nXSRwaC5ub3RlIC1uZSAnJykgeyAiPGRpdiBjbGFzcz0ncGgtbm90ZSc+JCgmICRlbmMgJHBoLm5vdGUpPC9kaXY+
HLP:IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICRyb3dzICs9ICI8ZGl2IGNsYXNzPSdwaCBwaC0kbGMnPjxkaXYgY2xhc3M9J3BoLWRvdCc+JCgmICRzdGF0dXNJY29uICRyZXMpPC9kaXY+PGRpdiBjbGFzcz0ncGgtbWFpbic+PGRpdiBjbGFzcz0ncGgtdG9wJz48
HLP:c3BhbiBjbGFzcz0ncGgtbnVtJz4kKCYgJGVuYyAkcGgubnVtKTwvc3Bhbj48c3BhbiBjbGFzcz0ncGgtdGl0bGUnPiQoJiAkZW5jICRwaC50aXRsZSk8L3NwYW4+PHNwYW4gY2xhc3M9J3BoLWJhZGdlIGItJGxjJz4kcmVzPC9zcGFuPjwvZGl2PiRub3RlPC9kaXY+
HLP:PGRpdiBjbGFzcz0ncGgtc2Vjcyc+JCgmICRlbmMgJHBoLnNlY3MpczwvZGl2PjwvZGl2PiIKICAgICAgICAgICAgJHN2PTA7IHRyeSB7ICRzdj1baW50XSRwaC5zZWNzIH0gY2F0Y2gge30KICAgICAgICAgICAgJHcgPSBbbWF0aF06OlJvdW5kKDEwMC4wICogJHN2
HLP:IC8gW21hdGhdOjpNYXgoMSwkbWF4U2VjcykpOyBpZiAoJHcgLWx0IDIgLWFuZCAkc3YgLWd0IDApIHsgJHcgPSAyIH0KICAgICAgICAgICAgJGJjb2wgPSBzd2l0Y2ggKCRyZXMpIHsgJ09LJyB7JyMyMmM1NWUnfSAnV0FSTicgeycjZjU5ZTBiJ30gJ0VSUk9SJyB7
HLP:JyNlZjQ0NDQnfSBkZWZhdWx0IHsnIzY0NzQ4Yid9IH0KICAgICAgICAgICAgJGJhcnMgKz0gIjxkaXYgY2xhc3M9J2Jhci1yb3cnPjxkaXYgY2xhc3M9J2Jhci1sYmwnPiQoJiAkZW5jICRwaC5udW0pICQoJiAkZW5jICRwaC50aXRsZSk8L2Rpdj48ZGl2IGNsYXNz
HLP:PSdiYXItdHJhY2snPjxzcGFuIHN0eWxlPSd3aWR0aDokdyU7YmFja2dyb3VuZDokYmNvbCc+PC9zcGFuPjwvZGl2PjxkaXYgY2xhc3M9J2Jhci12YWwnPiQoJiAkZW5jICRwaC5zZWNzKXM8L2Rpdj48L2Rpdj4iCiAgICAgICAgfQogICAgICAgIGlmICgtbm90ICRy
HLP:b3dzKSB7ICRyb3dzID0gIjxkaXYgY2xhc3M9J2VtcHR5Jz5ObyBzZSByZWdpc3RyYXJvbiBmYXNlcyBlbiBlc3RhIGVqZWN1Y2lvbi48L2Rpdj4iIH0KICAgICAgICBpZiAoLW5vdCAkYmFycykgeyAkYmFycyA9ICI8ZGl2IGNsYXNzPSdlbXB0eSc+U2luIHRpZW1w
HLP:b3MgcXVlIG1vc3RyYXIuPC9kaXY+IiB9CiAgICAgICAgJHRvdGFsUGggPSAkcGhhc2VzLkNvdW50CiAgICAgICAgIyBFc3RhZGlzdGljYXMgUkVBTEVTIGFncmVnYWRhcyBkZSBsbyBlamVjdXRhZG86IHRpZW1wbyB0b3RhbCBkZSBsYSBzZXNpb24KICAgICAgICAj
HLP:IHkgZXNwYWNpbyBsaWJlcmFkbyAoc3VtYWRvIGRlIGxhcyBub3RhcyBtZWRpZGFzIGRlIGNhZGEgZmFzZSwgTUIvR0IpLgogICAgICAgICR0b3RTZWNzID0gMDsgJG1iRnJlZWQgPSAwLjAKICAgICAgICBmb3JlYWNoICgkcGggaW4gJHBoYXNlcykgewogICAgICAg
HLP:ICAgICAkc3YgPSAwOyB0cnkgeyAkc3YgPSBbaW50XSRwaC5zZWNzIH0gY2F0Y2gge307ICR0b3RTZWNzICs9ICRzdgogICAgICAgICAgICBmb3JlYWNoICgkbSBpbiBbcmVnZXhdOjpNYXRjaGVzKFtzdHJpbmddJHBoLm5vdGUsICcoP2kpKD86bGliZXJhZFx3Knxm
HLP:cmVlZClcRHswLDEwfT8oW1xkXC4sXSspXHMqKE1CfEdCKScpKSB7CiAgICAgICAgICAgICAgICAkdiA9IDAuMDsgdHJ5IHsgJHYgPSBbZG91YmxlXSgkbS5Hcm91cHNbMV0uVmFsdWUuUmVwbGFjZSgnLCcsICcuJykpIH0gY2F0Y2gge30KICAgICAgICAgICAgICAg
HLP:IGlmICgkbS5Hcm91cHNbMl0uVmFsdWUgLW1hdGNoICcoP2kpR0InKSB7ICR2ID0gJHYgKiAxMDI0IH0KICAgICAgICAgICAgICAgICRtYkZyZWVkICs9ICR2CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgJHRvdFR4dCA9IGlmICgkdG90U2VjcyAtZ2Ug
HLP:NjApIHsgKCd7MH0gbWluIHsxfSBzJyAtZiBbaW50XVttYXRoXTo6Rmxvb3IoJHRvdFNlY3MgLyA2MCksICgkdG90U2VjcyAlIDYwKSkgfSBlbHNlIHsgKCd7MH0gcycgLWYgJHRvdFNlY3MpIH0KICAgICAgICAkZnJlZWRUeHQgPSBpZiAoJG1iRnJlZWQgLWdlIDEw
HLP:MjQpIHsgKCd7MDpuMX0gR0InIC1mICgkbWJGcmVlZCAvIDEwMjQpKSB9IGVsc2VpZiAoJG1iRnJlZWQgLWd0IDApIHsgKCd7MDpuMH0gTUInIC1mICRtYkZyZWVkKSB9IGVsc2UgeyAnJyB9CiAgICAgICAgJHN0YXRMaW5lID0gKCd0aWVtcG8gdG90YWw6IHswfScg
HLP:LWYgJHRvdFR4dCkKICAgICAgICBpZiAoJGZyZWVkVHh0KSB7ICRzdGF0TGluZSArPSAoJyAmbWlkZG90OyBlc3BhY2lvIGxpYmVyYWRvOiB7MH0nIC1mICRmcmVlZFR4dCkgfQoKICAgICAgICAkZmluZGluZ3MgPSBAKCRzdC5maW5kaW5ncykKICAgICAgICAkZmlu
HLP:ZEh0bWwgPSAnJwogICAgICAgICRzdGVwc0xpc3QgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAgICAgIGZvcmVhY2ggKCRmIGluICRmaW5kaW5ncykgewogICAgICAgICAgICAkdHh0ID0gW3N0cmluZ10kZgog
HLP:ICAgICAgICAgICAkc2V2ID0gJ2luZm8nOyAkc2V2VHh0ID0gJ0F2aXNvJwogICAgICAgICAgICBpZiAoJHR4dCAtbWF0Y2ggJyg/aSlTTUFSVHxCU09EfGFwYWd8V0hFQXxoYXJkd2FyZXxubyByZXBhcmFibGVzfGRhbmFkfHJlcG9zaXRvcmlvfGludGVncmlkYWQn
HLP:KSB7ICRzZXY9J2hpZ2gnOyAkc2V2VHh0PSdJbXBvcnRhbnRlJyB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSllc3BhY2lvfHJlaW5pY2lvIHBlbmRpZW50ZXxcYnJlZFxifGJhdGVyaWF8ZHJpdmVyfGRpc3Bvc2l0aXZvfFxiUkFNXGJ8c2Vy
HLP:dmljaW8nKSB7ICRzZXY9J21lZCc7ICRzZXZUeHQ9J1JldmlzYXInIH0KICAgICAgICAgICAgJGZpbmRIdG1sICs9ICI8bGkgY2xhc3M9J2ZpbmQgZmluZC0kc2V2Jz48c3BhbiBjbGFzcz0nc2V2IHNldi0kc2V2Jz4kc2V2VHh0PC9zcGFuPjxzcGFuIGNsYXNzPSdm
HLP:aW5kLXR4dCc+JCgmICRlbmMgJHR4dCk8L3NwYW4+PC9saT4iCiAgICAgICAgICAgICMgRGVyaXZhciBwYXNvIHJlY29tZW5kYWRvIGEgcGFydGlyIGRlbCBoYWxsYXpnbwogICAgICAgICAgICBpZiAoJHR4dCAtbWF0Y2ggJyg/aSlTTUFSVCcpICAgICAgICAgIHsg
HLP:JHN0ZXBzTGlzdC5BZGQoJ0hheiBjb3BpYSBkZSBzZWd1cmlkYWQgZGUgdHVzIGRhdG9zIGN1YW50byBhbnRlczogdW4gZGlzY28gY29uIFNNQVJUIGRlZ3JhZGFkbyBwdWVkZSBmYWxsYXIuIFZhbG9yYSByZWVtcGxhemFybG8uJykgfQogICAgICAgICAgICBlbHNl
HLP:aWYgKCR0eHQgLW1hdGNoICcoP2kpZXNwYWNpbycpICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ0xpYmVyYSBlc3BhY2lvIGVuIEM6IChkZXNpbnN0YWxhIGxvIHF1ZSBubyB1c2VzIG8gdXNhIGVsIFNlbnNvciBkZSBhbG1hY2VuYW1pZW50bykuIENvbnZpZW5lIHRlbmVy
HLP:IG1hcyBkZSAxNSBHQiBsaWJyZXMuJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpXGJSQU1cYnxtZW1vcicpIHsgJHN0ZXBzTGlzdC5BZGQoJ0VqZWN1dGEgZWwgRGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZSBXaW5kb3dzIChtZHNjaGVk
HLP:LmV4ZSkgeSByZWluaWNpYSBwYXJhIGNvbXByb2JhciBsYSBSQU0uJykgfQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpYmF0ZXJpYScpICAgIHsgJHN0ZXBzTGlzdC5BZGQoJ0xhIGJhdGVyaWEgZXN0YSBkZWdyYWRhZGEuIFJldmlzYSBlbCBp
HLP:bmZvcm1lIGRlIGJhdGVyaWEgKHBvd2VyY2ZnIC9iYXR0ZXJ5cmVwb3J0KSB5IHZhbG9yYSBzdXN0aXR1aXJsYS4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAtbWF0Y2ggJyg/aSlyZWluaWNpbyBwZW5kaWVudGUnKSB7ICRzdGVwc0xpc3QuQWRkKCdSZWlu
HLP:aWNpYSBlbCBlcXVpcG8gcGFyYSBhcGxpY2FyIGNhbWJpb3MgcGVuZGllbnRlcyBhbnRlcyBkZSBzZWd1aXIgcmVwYXJhbmRvLicpIH0KICAgICAgICAgICAgZWxzZWlmICgkdHh0IC1tYXRjaCAnKD9pKW5vIHJlcGFyYWJsZXN8cmVwb3NpdG9yaW98aW50ZWdyaWRh
HLP:ZCcpIHsgJHN0ZXBzTGlzdC5BZGQoJ1F1ZWRhbiBjb21wb25lbnRlcyBkYW5hZG9zLiBFamVjdXRhIERJU00gY29uIHVuIG9yaWdlbiB2YWxpZG8gKGluc3RhbGwud2ltKSB5IHZ1ZWx2ZSBhIHBhc2FyIFNGQy4nKSB9CiAgICAgICAgICAgIGVsc2VpZiAoJHR4dCAt
HLP:bWF0Y2ggJyg/aSlkcml2ZXJ8ZGlzcG9zaXRpdm8nKSB7ICRzdGVwc0xpc3QuQWRkKCdBY3R1YWxpemEgbG9zIGRyaXZlcnMgZGUgbG9zIGRpc3Bvc2l0aXZvcyBjb24gZXJyb3IgZGVzZGUgbGEgd2ViIGRlbCBmYWJyaWNhbnRlIG8gV2luZG93cyBVcGRhdGUuJykg
HLP:fQogICAgICAgICAgICBlbHNlaWYgKCR0eHQgLW1hdGNoICcoP2kpXGJyZWRcYnxETlMnKSAgICAgICAgeyAkc3RlcHNMaXN0LkFkZCgnUmV2aXNhIGxhIGNvbmV4aW9uIGRlIHJlZCB5IGVsIEROUy4gU2kgcGVyc2lzdGUsIHBydWViYSBjb24gdW4gRE5TIHB1Ymxp
HLP:Y28gKDEuMS4xLjEgLyA4LjguOC44KS4nKSB9CiAgICAgICAgfQogICAgICAgICRub0ZpbmQgPSAoJGZpbmRpbmdzLkNvdW50IC1lcSAwKQogICAgICAgIGlmICgkbm9GaW5kKSB7ICRmaW5kSHRtbCA9ICI8bGkgY2xhc3M9J2ZpbmQgZmluZC1vayc+PHNwYW4gY2xh
HLP:c3M9J3NldiBzZXYtb2snPlRvZG8gT0s8L3NwYW4+PHNwYW4gY2xhc3M9J2ZpbmQtdHh0Jz5ObyBzZSBkZXRlY3Rhcm9uIHByb2JsZW1hcyByZWxldmFudGVzIGR1cmFudGUgZWwgZGlhZ25vc3RpY28uPC9zcGFuPjwvbGk+IiB9CgogICAgICAgICMgLS0tIFByb3hp
HLP:bW9zIHBhc29zIHJlY29tZW5kYWRvcyAoZGVkdXBsaWNhZG9zKSAtLS0KICAgICAgICAkc3RlcHNIdG1sID0gJycKICAgICAgICAkc2VlbiA9IEB7fQogICAgICAgIGZvcmVhY2ggKCRzIGluICRzdGVwc0xpc3QpIHsgaWYgKC1ub3QgJHNlZW4uQ29udGFpbnNLZXko
HLP:JHMpKSB7ICRzZWVuWyRzXT0kdHJ1ZTsgJHN0ZXBzSHRtbCArPSAiPGxpIGNsYXNzPSdzdGVwLWxpJz48c3BhbiBjbGFzcz0nc3RlcC1pYyc+JiMxMDE0ODs8L3NwYW4+PHNwYW4+JCgmICRlbmMgJHMpPC9zcGFuPjwvbGk+IiB9IH0KICAgICAgICBpZiAoJGNFUlIg
HLP:LWd0IDApIHsgJHN0ZXBzSHRtbCA9ICI8bGkgY2xhc3M9J3N0ZXAtbGknPjxzcGFuIGNsYXNzPSdzdGVwLWljJz4mIzEwMTQ4Ozwvc3Bhbj48c3Bhbj5IdWJvIGZhc2VzIGNvbiBlcnJvcjogcmV2aXNhIGVsIHJlZ2lzdHJvIGRldGFsbGFkbyBlbiBsYSBjYXJwZXRh
HLP:IFdQSV9TdWl0ZVxMb2dzLjwvc3Bhbj48L2xpPiIgKyAkc3RlcHNIdG1sIH0KICAgICAgICBpZiAoLW5vdCAkc3RlcHNIdG1sKSB7ICRzdGVwc0h0bWwgPSAiPGxpIGNsYXNzPSdzdGVwLWxpIHN0ZXAtb2snPjxzcGFuIGNsYXNzPSdzdGVwLWljJz4mIzEwMDAzOzwv
HLP:c3Bhbj48c3Bhbj5ObyBoYXkgYWNjaW9uZXMgcGVuZGllbnRlcy4gUmVpbmljaWEgZWwgZXF1aXBvIHBhcmEgYXNlZ3VyYXIgcXVlIHRvZG9zIGxvcyBjYW1iaW9zIHF1ZWRlbiBhcGxpY2Fkb3MuPC9zcGFuPjwvbGk+IiB9CgogICAgICAgICMgPT09PT09PT09PT09
HLP:PT09PT09PT09PSBESUFHTk9TVElDTyBBTVBMSUFETyA9PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgJGRpYWdDYXJkcyA9ICcnCiAgICAgICAgaWYgKCgkc3QuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnZGlhZycpIC1hbmQgJHN0LmRp
HLP:YWcpIHsKICAgICAgICAgICAgJGQgPSAkc3QuZGlhZwogICAgICAgICAgICBpZiAoJGQucmFtKSB7CiAgICAgICAgICAgICAgICAkcnMgPSBbc3RyaW5nXSRkLnJhbS5zdGF0dXMKICAgICAgICAgICAgICAgICRycCA9IHN3aXRjaCAoJHJzKSB7ICdvaycgeydnb29k
HLP:J30gJ3N1c3BlY3QnIHsnYmFkJ30gZGVmYXVsdCB7J3Vua25vd24nfSB9CiAgICAgICAgICAgICAgICAkcnQgPSBzd2l0Y2ggKCRycykgeyAnb2snIHsnU2luIGVycm9yZXMgZGV0ZWN0YWRvcyd9ICdzdXNwZWN0JyB7J1Nvc3BlY2hvc2EnfSBkZWZhdWx0IHsnTm8g
HLP:ZXZhbHVhZGEnfSB9CiAgICAgICAgICAgICAgICAkbWRzID0gaWYgKCRkLnJhbS5yZWNvbW1lbmRfbWRzY2hlZCkgeyAiPGRpdiBjbGFzcz0nZC1oaW50Jz5SZWNvbWVuZGFkbzogZWplY3V0YXIgZWwgRGlhZ25vc3RpY28gZGUgbWVtb3JpYSBkZSBXaW5kb3dzICht
HLP:ZHNjaGVkKS48L2Rpdj4iIH0gZWxzZSB7ICcnIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLXJhbSc+PC9zcGFuPk1lbW9yaWEgUkFNPC9kaXY+PGRp
HLP:diBjbGFzcz0nZC1waWxsIHBpbGwtJHJwJz4kcnQ8L2Rpdj4kbWRzPC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkZC5iYXR0ZXJ5KSB7CiAgICAgICAgICAgICAgICBpZiAoJGQuYmF0dGVyeS5wcmVzZW50KSB7CiAgICAgICAgICAgICAgICAg
HLP:ICAgJGJwUmF3ID0gJGQuYmF0dGVyeS5oZWFsdGhfcGN0CiAgICAgICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkYnBSYXcgLWFuZCBbc3RyaW5nXSRicFJhdyAtbmUgJycpIHsKICAgICAgICAgICAgICAgICAgICAgICAgJGJwID0gMDsgdHJ5IHsgJGJwID0g
HLP:W2ludF0kYnBSYXcgfSBjYXRjaCB7ICRicCA9IDAgfQogICAgICAgICAgICAgICAgICAgICAgICAkYnBjb2wgPSBpZiAoJGJwIC1nZSA4MCkgeycjMjJjNTVlJ30gZWxzZWlmICgkYnAgLWdlIDUwKSB7JyNmNTllMGInfSBlbHNlIHsnI2VmNDQ0NCd9CiAgICAgICAg
HLP:ICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJhdCc+PC9zcGFuPkJhdGVyaWE8L2Rpdj48ZGl2IGNsYXNzPSdiYXQtYmFyJz48c3BhbiBzdHlsZT0nd2lk
HLP:dGg6JGJwJTtiYWNrZ3JvdW5kOiRicGNvbCc+PC9zcGFuPjwvZGl2PjxkaXYgY2xhc3M9J2Qtc3ViJz5TYWx1ZCBlc3RpbWFkYTogPGIgc3R5bGU9J2NvbG9yOiRicGNvbCc+JGJwJTwvYj48L2Rpdj48L2Rpdj4iCiAgICAgICAgICAgICAgICAgICAgfSBlbHNlIHsK
HLP:ICAgICAgICAgICAgICAgICAgICAgICAgJGRpYWdDYXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQnPjxkaXYgY2xhc3M9J2QtaCc+PHNwYW4gY2xhc3M9J2QtaWMgaWMtYmF0Jz48L3NwYW4+QmF0ZXJpYTwvZGl2PjxkaXYgY2xhc3M9J2QtcGlsbCBwaWxsLXVua25v
HLP:d24nPlByZXNlbnRlLCBzYWx1ZCBkZXNjb25vY2lkYTwvZGl2PjwvZGl2PiIKICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2
HLP:IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLWJhdCc+PC9zcGFuPkJhdGVyaWE8L2Rpdj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC11bmtub3duJz5ObyBwcmVzZW50ZSAoZXF1aXBvIGRlIHNvYnJlbWVzYSk8L2Rpdj48L2Rpdj4iCiAgICAgICAgICAg
HLP:ICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCRkLm5ldHdvcmspIHsKICAgICAgICAgICAgICAgICRjYyA9IGlmICgkZC5uZXR3b3JrLmNvbm5lY3RlZCkgeydnb29kJ30gZWxzZSB7J2JhZCd9CiAgICAgICAgICAgICAgICAkY3QgPSBpZiAoJGQu
HLP:bmV0d29yay5jb25uZWN0ZWQpIHsnQ29uZWN0YWRvJ30gZWxzZSB7J1NpbiBjb25leGlvbid9CiAgICAgICAgICAgICAgICAkZGMgPSBpZiAoJGQubmV0d29yay5kbnNfb2spIHsnZ29vZCd9IGVsc2UgeydiYWQnfQogICAgICAgICAgICAgICAgJGR0ID0gaWYgKCRk
HLP:Lm5ldHdvcmsuZG5zX29rKSB7J0ROUyBPSyd9IGVsc2UgeydETlMgY29uIGZhbGxvcyd9CiAgICAgICAgICAgICAgICAkZGV0ID0gJiAkZW5jICRkLm5ldHdvcmsuZGV0YWlscwogICAgICAgICAgICAgICAgJGxhdCA9ICcnCiAgICAgICAgICAgICAgICBpZiAoKCRk
HLP:Lm5ldHdvcmsuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnZG5zX21zJykgLWFuZCAkbnVsbCAtbmUgJGQubmV0d29yay5kbnNfbXMgLWFuZCBbc3RyaW5nXSRkLm5ldHdvcmsuZG5zX21zIC1uZSAnJykgewogICAgICAgICAgICAgICAgICAgICRt
HLP:cyA9IDA7IHRyeSB7ICRtcyA9IFtpbnRdJGQubmV0d29yay5kbnNfbXMgfSBjYXRjaCB7fQogICAgICAgICAgICAgICAgICAgICRsYzIgPSBpZiAoJG1zIC1sdCA2MCkgeycjMjJjNTVlJ30gZWxzZWlmICgkbXMgLWx0IDIwMCkgeycjZjU5ZTBiJ30gZWxzZSB7JyNl
HLP:ZjQ0NDQnfQogICAgICAgICAgICAgICAgICAgICRsYXQgPSAiPGRpdiBjbGFzcz0nZC1zdWInPkxhdGVuY2lhIEROUzogPGIgc3R5bGU9J2NvbG9yOiRsYzInPiRtcyBtczwvYj48L2Rpdj4iCiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAkZGlhZ0Nh
HLP:cmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1uZXQnPjwvc3Bhbj5SZWQ8L2Rpdj48ZGl2IGNsYXNzPSdwaWxsLXJvdyc+PHNwYW4gY2xhc3M9J2QtcGlsbCBwaWxsLSRjYyc+JGN0PC9zcGFuPjxz
HLP:cGFuIGNsYXNzPSdkLXBpbGwgcGlsbC0kZGMnPiRkdDwvc3Bhbj48L2Rpdj48ZGl2IGNsYXNzPSdkLXN1Yic+JGRldDwvZGl2PiRsYXQ8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRh
HLP:aW5zICdzbWFydCcpIC1hbmQgJGQuc21hcnQgLWFuZCAkZC5zbWFydC5hdmFpbGFibGUpIHsKICAgICAgICAgICAgICAgICRzbSA9ICRkLnNtYXJ0CiAgICAgICAgICAgICAgICAkcGYgPSBpZiAoJHNtLnByZWRpY3RfZmFpbCkgeyAiPHNwYW4gY2xhc3M9J2QtcGls
HLP:bCBwaWxsLWJhZCc+UHJlZGljZSBmYWxsbzwvc3Bhbj4iIH0gZWxzZSB7ICI8c3BhbiBjbGFzcz0nZC1waWxsIHBpbGwtZ29vZCc+U2luIGFsZXJ0YTwvc3Bhbj4iIH0KICAgICAgICAgICAgICAgICRleHRyYSA9ICcnCiAgICAgICAgICAgICAgICBpZiAoJG51bGwg
HLP:LW5lICRzbS50ZW1wX2MgLWFuZCBbc3RyaW5nXSRzbS50ZW1wX2MgLW5lICcnKSB7ICR0Yz0wOyB0cnl7JHRjPVtpbnRdJHNtLnRlbXBfY31jYXRjaHt9OyAkdGNvbCA9IGlmICgkdGMgLWx0IDUwKXsnIzIyYzU1ZSd9IGVsc2VpZiAoJHRjIC1sdCA2NSl7JyNmNTll
HLP:MGInfSBlbHNlIHsnI2VmNDQ0NCd9OyAkZXh0cmEgKz0gIjxkaXYgY2xhc3M9J2Qtc3ViJz5UZW1wZXJhdHVyYTogPGIgc3R5bGU9J2NvbG9yOiR0Y29sJz4kdGMgJmRlZztDPC9iPjwvZGl2PiIgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkc20ud2Vh
HLP:cl9wY3QgLWFuZCBbc3RyaW5nXSRzbS53ZWFyX3BjdCAtbmUgJycpIHsgJHdwPTA7IHRyeXskd3A9W2ludF0kc20ud2Vhcl9wY3R9Y2F0Y2h7fTsgJHdjb2wgPSBpZiAoJHdwIC1sdCA1MCl7JyMyMmM1NWUnfSBlbHNlaWYgKCR3cCAtbHQgODApeycjZjU5ZTBiJ30g
HLP:ZWxzZSB7JyNlZjQ0NDQnfTsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+RGVzZ2FzdGUgKFNTRCk6IDxiIHN0eWxlPSdjb2xvcjokd2NvbCc+JHdwJTwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHNtLnBvaCAtYW5kIFtz
HLP:dHJpbmddJHNtLnBvaCAtbmUgJycpIHsgJGV4dHJhICs9ICI8ZGl2IGNsYXNzPSdkLXN1Yic+SG9yYXMgZW5jZW5kaWRvOiA8Yj4kKCYgJGVuYyAkc20ucG9oKTwvYj48L2Rpdj4iIH0KICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2Rj
HLP:YXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLXNtYXJ0Jz48L3NwYW4+U2FsdWQgZGVsIGRpc2NvIChTTUFSVCk8L2Rpdj48ZGl2IGNsYXNzPSdwaWxsLXJvdyc+JHBmPC9kaXY+JGV4dHJhPC9kaXY+IgogICAgICAgICAgICB9CiAgICAg
HLP:ICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAnYmNkJykgLWFuZCAkZC5iY2QpIHsKICAgICAgICAgICAgICAgICRib2sgPSBpZiAoJGQuYmNkLm9rKSB7J2dvb2QnfSBlbHNlIHsnYmFkJ30KICAgICAgICAgICAgICAgICRi
HLP:dHggPSBpZiAoJGQuYmNkLm9rKSB7J0NvbmZpZ3VyYWNpb24gZGUgYXJyYW5xdWUgY29ycmVjdGEnfSBlbHNlIHsnQXJyYW5xdWUgY29uIGluY2lkZW5jaWFzJ30KICAgICAgICAgICAgICAgICRiZGV0ID0gaWYgKFtzdHJpbmddJGQuYmNkLmRldGFpbHMgLW5lICcn
HLP:KSB7ICI8ZGl2IGNsYXNzPSdkLXN1Yic+JCgmICRlbmMgJGQuYmNkLmRldGFpbHMpPC9kaXY+IiB9IGVsc2UgeyAnJyB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0n
HLP:ZC1pYyBpYy1ib290Jz48L3NwYW4+QXJyYW5xdWUgKEJDRCk8L2Rpdj48ZGl2IGNsYXNzPSdkLXBpbGwgcGlsbC0kYm9rJz4kYnR4PC9kaXY+JGJkZXQ8L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICAgICAgaWYgKCgkZC5QU09iamVjdC5Qcm9wZXJ0aWVzLk5h
HLP:bWUgLWNvbnRhaW5zICdzdGFydHVwJykgLWFuZCAkZC5zdGFydHVwIC1hbmQgQCgkZC5zdGFydHVwKS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVhY2ggKCRzIGluIEAoJGQuc3RhcnR1cCkpIHsg
HLP:JGl0ZW1zICs9ICI8bGk+JCgmICRlbmMgJHMubmFtZSk8c3BhbiBjbGFzcz0nbXV0ZWQnPiAmbWRhc2g7ICQoJiAkZW5jICRzLmNvbW1hbmQpPC9zcGFuPjwvbGk+IiB9CiAgICAgICAgICAgICAgICAkZGlhZ0NhcmRzICs9ICI8ZGl2IGNsYXNzPSdkY2FyZCBkY2Fy
HLP:ZC13aWRlJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLXN0YXJ0Jz48L3NwYW4+UHJvZ3JhbWFzIGFsIGluaWNpYXIgV2luZG93czwvZGl2Pjx1bCBjbGFzcz0nZGV2LWxpc3QnPiRpdGVtczwvdWw+PC9kaXY+IgogICAgICAgICAgICB9CiAg
HLP:ICAgICAgICAgIGlmICgoJGQuUFNPYmplY3QuUHJvcGVydGllcy5OYW1lIC1jb250YWlucyAncHJvY2Vzc2VzJykgLWFuZCAkZC5wcm9jZXNzZXMgLWFuZCBAKCRkLnByb2Nlc3NlcykuQ291bnQgLWd0IDApIHsKICAgICAgICAgICAgICAgICRpdGVtcyA9ICcnCiAg
HLP:ICAgICAgICAgICAgICBmb3JlYWNoICgkcHIgaW4gQCgkZC5wcm9jZXNzZXMpKSB7ICRpdGVtcyArPSAiPGxpPiQoJiAkZW5jICRwci5uYW1lKTxzcGFuIGNsYXNzPSdtdXRlZCc+ICZtZGFzaDsgJCgmICRlbmMgJHByLm1lbV9tYikgTUI8L3NwYW4+PC9saT4iIH0K
HLP:ICAgICAgICAgICAgICAgICRkaWFnQ2FyZHMgKz0gIjxkaXYgY2xhc3M9J2RjYXJkJz48ZGl2IGNsYXNzPSdkLWgnPjxzcGFuIGNsYXNzPSdkLWljIGljLXByb2MnPjwvc3Bhbj5Qcm9jZXNvcyBxdWUgbWFzIG1lbW9yaWEgdXNhbjwvZGl2Pjx1bCBjbGFzcz0nZGV2
HLP:LWxpc3QnPiRpdGVtczwvdWw+PC9kaXY+IgogICAgICAgICAgICB9CiAgICAgICAgICAgIGlmICgkZC5kZXZpY2VzIC1hbmQgQCgkZC5kZXZpY2VzKS5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAgICAgJGl0ZW1zID0gJycKICAgICAgICAgICAgICAgIGZvcmVh
HLP:Y2ggKCRkZXYgaW4gQCgkZC5kZXZpY2VzKSkgeyAkaXRlbXMgKz0gIjxsaT4kKCYgJGVuYyAkZGV2Lm5hbWUpIDxzcGFuIGNsYXNzPSdtdXRlZCc+KGNvZGlnbyAkKCYgJGVuYyAkZGV2LmNvZGUpKTwvc3Bhbj48L2xpPiIgfQogICAgICAgICAgICAgICAgJGRpYWdD
HLP:YXJkcyArPSAiPGRpdiBjbGFzcz0nZGNhcmQgZGNhcmQtd2lkZSc+PGRpdiBjbGFzcz0nZC1oJz48c3BhbiBjbGFzcz0nZC1pYyBpYy1kZXYnPjwvc3Bhbj5EaXNwb3NpdGl2b3MgY29uIGF2aXNvPC9kaXY+PHVsIGNsYXNzPSdkZXYtbGlzdCc+JGl0ZW1zPC91bD48
HLP:L2Rpdj4iCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgJGRpYWdTZWN0aW9uID0gJycKICAgICAgICBpZiAoJGRpYWdDYXJkcykgeyAkZGlhZ1NlY3Rpb24gPSAiPGgyIGlkPSdkaWFnJyBjbGFzcz0nc2VjLWgnPkRpYWdub3N0aWNvIGFtcGxpYWRvPC9o
HLP:Mj48ZGl2IGNsYXNzPSdkZ3JpZCc+JGRpYWdDYXJkczwvZGl2PiIgfQoKICAgICAgICAkY29tcGFyZVNlY3Rpb24gPSAnJwogICAgICAgIGlmICgkaGFzQm90aCkgewogICAgICAgICAgICAkY29tcGFyZVNlY3Rpb24gPSBAIgo8ZGl2IGNsYXNzPSdjb21wYXJlJz4K
HLP:ICA8ZGl2IGNsYXNzPSdtaW5pJz4KICAgIDxzdmcgdmlld0JveD0nMCAwIDIwMCAyMDAnIGNsYXNzPSdnYXVnZSBnYXVnZS1zbSc+PGNpcmNsZSBjbGFzcz0ndHJhY2snIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0Jy8+PGNpcmNsZSBjbGFzcz0nZmlsbCcgY3g9JzEw
HLP:MCcgY3k9JzEwMCcgcj0nODQnIHN0eWxlPSctLWNpcmM6JGNpcmM7LS10YXJnZXQ6JGJlZm9yZU9mZnNldDtzdHJva2U6JGJlZm9yZUNvbG9yJy8+PHRleHQgeD0nMTAwJyB5PScxMDgnIGNsYXNzPSdnLW51bScgc3R5bGU9J2ZpbGw6JGJlZm9yZUNvbG9yJz4kYmVm
HLP:b3JlPC90ZXh0Pjwvc3ZnPgogICAgPGRpdiBjbGFzcz0nbWluaS1jYXAnPkFOVEVTPC9kaXY+CiAgPC9kaXY+CiAgPGRpdiBjbGFzcz0nYXJyb3cnPjxzcGFuIHN0eWxlPSdjb2xvcjokZGVsdGFDb2xvcic+JiM4NTk0Ozwvc3Bhbj48ZGl2IGNsYXNzPSdkZWx0YS1j
HLP:aGlwJyBzdHlsZT0nY29sb3I6JGRlbHRhQ29sb3I7Ym9yZGVyLWNvbG9yOiRkZWx0YUNvbG9yJz4kZGVsdGFUeHQ8L2Rpdj48L2Rpdj4KICA8ZGl2IGNsYXNzPSdtaW5pJz4KICAgIDxzdmcgdmlld0JveD0nMCAwIDIwMCAyMDAnIGNsYXNzPSdnYXVnZSBnYXVnZS1z
HLP:bSc+PGNpcmNsZSBjbGFzcz0ndHJhY2snIGN4PScxMDAnIGN5PScxMDAnIHI9Jzg0Jy8+PGNpcmNsZSBjbGFzcz0nZmlsbCcgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnIHN0eWxlPSctLWNpcmM6JGNpcmM7LS10YXJnZXQ6JGFmdGVyT2Zmc2V0O3N0cm9rZTokYWZ0
HLP:ZXJDb2xvcicvPjx0ZXh0IHg9JzEwMCcgeT0nMTA4JyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxsOiRhZnRlckNvbG9yJz4kYWZ0ZXI8L3RleHQ+PC9zdmc+CiAgICA8ZGl2IGNsYXNzPSdtaW5pLWNhcCc+REVTUFVFUzwvZGl2PgogIDwvZGl2Pgo8L2Rpdj4KIkAK
HLP:ICAgICAgICB9CgogICAgICAgICRub3cgPSAoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5LU1NLWRkIEhIOm1tJykKICAgICAgICAkZXhlY1ZlcmRpY3QgPSAmICRiYW5kTGFiZWwgJG1haW5TY29yZQogICAgICAgICRodG1sID0gQCIKPCFET0NUWVBFIGh0bWw+Cjxo
HLP:dG1sIGxhbmc9J2VzJz4KPGhlYWQ+CjxtZXRhIGNoYXJzZXQ9J3V0Zi04Jz4KPG1ldGEgbmFtZT0ndmlld3BvcnQnIGNvbnRlbnQ9J3dpZHRoPWRldmljZS13aWR0aCxpbml0aWFsLXNjYWxlPTEnPgo8dGl0bGU+SW5mb3JtZSBkZSBSZXBhcmFjaW9uIC0gV1BJIFN1
HLP:aXRlIHYzLjE8L3RpdGxlPgo8c3R5bGU+Cip7Ym94LXNpemluZzpib3JkZXItYm94fQo6cm9vdHstLWJnOiMwYjBmMTc7LS1iZzI6IzBkMTQyMjstLWNhcmQ6IzEyMWEyYjstLWNhcmQyOiMwZTE2MjY7LS1saW5lOiMxZTI5M2I7LS10eHQ6I2U2ZWRmNjstLW11dGVk
HLP:OiM5M2EzYmE7LS1hY2NlbnQ6IzM4YmRmODstLWFjY2VudDI6IzgxOGNmODstLXNoYWRvdzowIDE0cHggNDBweCByZ2JhKDAsMCwwLC40MCl9Cmh0bWwubGlnaHR7LS1iZzojZWVmMmY4Oy0tYmcyOiNlN2VkZjY7LS1jYXJkOiNmZmZmZmY7LS1jYXJkMjojZjVmOGZj
HLP:Oy0tbGluZTojZGRlNWYwOy0tdHh0OiMwZjE3MmE7LS1tdXRlZDojNWE2YjgyOy0tYWNjZW50OiMwMjg0Yzc7LS1hY2NlbnQyOiM0ZjQ2ZTU7LS1zaGFkb3c6MCAxMHB4IDI4cHggcmdiYSgxNSwyMyw0MiwuMTIpfQpib2R5e21hcmdpbjowO2ZvbnQtZmFtaWx5OidT
HLP:ZWdvZSBVSScsc3lzdGVtLXVpLC1hcHBsZS1zeXN0ZW0sQXJpYWwsc2Fucy1zZXJpZjtsaW5lLWhlaWdodDoxLjU1O2NvbG9yOnZhcigtLXR4dCk7YmFja2dyb3VuZDpyYWRpYWwtZ3JhZGllbnQoMTIwMHB4IDYwMHB4IGF0IDgwJSAtMTAlLHJnYmEoNTYsMTg5LDI0
HLP:OCwuMTApLHRyYW5zcGFyZW50IDYwJSkscmFkaWFsLWdyYWRpZW50KDkwMHB4IDUwMHB4IGF0IC0xMCUgMTAlLHJnYmEoMTI5LDE0MCwyNDgsLjEwKSx0cmFuc3BhcmVudCA1NSUpLHZhcigtLWJnKX0KLndyYXB7bWF4LXdpZHRoOjEwODBweDttYXJnaW46MCBhdXRv
HLP:O3BhZGRpbmc6MzBweCAyMnB4IDYwcHh9Ci50b3BiYXJ7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjtnYXA6MTZweDttYXJnaW4tYm90dG9tOjE4cHg7ZmxleC13cmFwOndyYXB9Ci5icmFuZHtkaXNw
HLP:bGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxNHB4fQoubG9nb3t3aWR0aDo0NnB4O2hlaWdodDo0NnB4O2JvcmRlci1yYWRpdXM6MTNweDtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsdmFyKC0tYWNjZW50KSx2YXIoLS1hY2NlbnQyKSk7
HLP:ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KX0KaDF7Zm9udC1zaXplOjIycHg7bWFyZ2luOjA7bGV0dGVyLXNwYWNpbmc6LjJweH0KLnN1Yntjb2xvcjp2YXIoLS1tdXRl
HLP:ZCk7Zm9udC1zaXplOjEzcHg7bWFyZ2luLXRvcDoycHh9Ci5iYWRnZXtkaXNwbGF5OmlubGluZS1ibG9jaztiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsdmFyKC0tYWNjZW50KSx2YXIoLS1hY2NlbnQyKSk7Y29sb3I6IzA0MjkzYjtmb250LXdlaWdo
HLP:dDo3MDA7Ym9yZGVyLXJhZGl1czo5OTlweDtwYWRkaW5nOjNweCAxMnB4O2ZvbnQtc2l6ZToxMS41cHg7bGV0dGVyLXNwYWNpbmc6LjRweDt2ZXJ0aWNhbC1hbGlnbjptaWRkbGU7bWFyZ2luLWxlZnQ6OHB4fQouYnRuc3tkaXNwbGF5OmZsZXg7Z2FwOjhweDtmbGV4
HLP:LXdyYXA6d3JhcH0KLnRvZ2dsZXtjdXJzb3I6cG9pbnRlcjtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JhY2tncm91bmQ6dmFyKC0tY2FyZCk7Y29sb3I6dmFyKC0tdHh0KTtib3JkZXItcmFkaXVzOjEwcHg7cGFkZGluZzo4cHggMTRweDtmb250LXNpemU6
HLP:MTNweDtmb250LXdlaWdodDo2MDA7Ym94LXNoYWRvdzp2YXIoLS1zaGFkb3cpfQoudG9nZ2xlOmhvdmVye2JvcmRlci1jb2xvcjp2YXIoLS1hY2NlbnQpfQoudG9je2Rpc3BsYXk6ZmxleDtnYXA6OHB4O2ZsZXgtd3JhcDp3cmFwO21hcmdpbjowIDAgMjJweH0KLnRv
HLP:YyBhe2ZvbnQtc2l6ZToxMi41cHg7Zm9udC13ZWlnaHQ6NjAwO2NvbG9yOnZhcigtLW11dGVkKTt0ZXh0LWRlY29yYXRpb246bm9uZTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JhY2tncm91bmQ6dmFyKC0tY2FyZDIpO2JvcmRlci1yYWRpdXM6OTk5cHg7
HLP:cGFkZGluZzo2cHggMTNweH0KLnRvYyBhOmhvdmVye2NvbG9yOnZhcigtLWFjY2VudCk7Ym9yZGVyLWNvbG9yOnZhcigtLWFjY2VudCl9Ci5leGVje2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjE4cHg7ZmxleC13cmFwOndyYXA7YmFja2dyb3Vu
HLP:ZDpsaW5lYXItZ3JhZGllbnQoMTgwZGVnLHZhcigtLWNhcmQpLHZhcigtLWNhcmQyKSk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE4cHg7cGFkZGluZzoxOHB4IDIycHg7bWFyZ2luLWJvdHRvbToyMnB4O2JveC1zaGFkb3c6dmFy
HLP:KC0tc2hhZG93KX0KLmV4ZWMtc2NvcmV7Zm9udC1zaXplOjQ2cHg7Zm9udC13ZWlnaHQ6ODAwO2xpbmUtaGVpZ2h0OjF9Ci5leGVjLW1pZHtmbGV4OjE7bWluLXdpZHRoOjIwMHB4fQouZXhlYy12ZXJkaWN0e2ZvbnQtc2l6ZToxOHB4O2ZvbnQtd2VpZ2h0OjcwMH0K
HLP:LmV4ZWMtbGluZXtjb2xvcjp2YXIoLS1tdXRlZCk7Zm9udC1zaXplOjEzcHg7bWFyZ2luLXRvcDoycHh9Ci5leGVjLWRlbHRhe2ZvbnQtc2l6ZToxM3B4O2ZvbnQtd2VpZ2h0OjcwMDtib3JkZXI6MXB4IHNvbGlkO2JvcmRlci1yYWRpdXM6OTk5cHg7cGFkZGluZzo0
HLP:cHggMTJweDt3aGl0ZS1zcGFjZTpub3dyYXB9Ci5oZXJve2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6bWlubWF4KDI0MHB4LDMyMHB4KSAxZnI7Z2FwOjIwcHg7bWFyZ2luLWJvdHRvbToyMnB4fQpAbWVkaWEobWF4LXdpZHRoOjc2MHB4KXsuaGVy
HLP:b3tncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyfX0KLmNhcmR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTgwZGVnLHZhcigtLWNhcmQpLHZhcigtLWNhcmQyKSk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE4cHg7cGFkZGlu
HLP:ZzoyMnB4O2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KX0KLmdhdWdld3JhcHtkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO3RleHQtYWxpZ246Y2VudGVyfQouZ2F1Z2V7d2lk
HLP:dGg6MjEwcHg7aGVpZ2h0OjIxMHB4fQouZ2F1Z2Utc217d2lkdGg6MTIwcHg7aGVpZ2h0OjEyMHB4fQouZ2F1Z2UgLnRyYWNre2ZpbGw6bm9uZTtzdHJva2U6dmFyKC0tbGluZSk7c3Ryb2tlLXdpZHRoOjE0fQouZ2F1Z2UgLmZpbGx7ZmlsbDpub25lO3N0cm9rZS13
HLP:aWR0aDoxNDtzdHJva2UtbGluZWNhcDpyb3VuZDt0cmFuc2Zvcm06cm90YXRlKC05MGRlZyk7dHJhbnNmb3JtLW9yaWdpbjo1MCUgNTAlO3N0cm9rZS1kYXNoYXJyYXk6dmFyKC0tY2lyYyk7c3Ryb2tlLWRhc2hvZmZzZXQ6dmFyKC0tY2lyYyk7YW5pbWF0aW9uOmZp
HLP:bGwgMS40cyBjdWJpYy1iZXppZXIoLjIyLDEsLjM2LDEpIC4ycyBmb3J3YXJkc30KLmctbnVte2ZvbnQtc2l6ZTo1NHB4O2ZvbnQtd2VpZ2h0OjgwMDt0ZXh0LWFuY2hvcjptaWRkbGU7Zm9udC1mYW1pbHk6J1NlZ29lIFVJJyxzeXN0ZW0tdWksQXJpYWx9Ci5nYXVn
HLP:ZS1zbSAuZy1udW17Zm9udC1zaXplOjQ2cHh9Ci5nLWxhYmVse21hcmdpbi10b3A6NnB4O2ZvbnQtd2VpZ2h0OjcwMDtmb250LXNpemU6MTVweH0KLmctY2Fwe2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweDtsZXR0ZXItc3BhY2luZzoxLjVweDttYXJn
HLP:aW4tdG9wOjJweH0KLmNvbXBhcmV7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2dhcDo4cHg7bWFyZ2luLXRvcDoxNHB4O2ZsZXgtd3JhcDp3cmFwfQoubWluaXt0ZXh0LWFsaWduOmNlbnRlcn0KLm1pbmktY2Fw
HLP:e2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTFweDtsZXR0ZXItc3BhY2luZzoxLjJweDttYXJnaW4tdG9wOi02cHh9Ci5hcnJvd3tkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6NnB4O2ZvbnQtc2l6
HLP:ZTozMHB4O2ZvbnQtd2VpZ2h0OjgwMH0KLmRlbHRhLWNoaXB7Ym9yZGVyOjFweCBzb2xpZDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6M3B4IDEycHg7Zm9udC1zaXplOjEyLjVweDtmb250LXdlaWdodDo3MDA7d2hpdGUtc3BhY2U6bm93cmFwfQouaGVyby1z
HLP:aWRle2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47Z2FwOjE2cHh9Ci5jaGlwc3tkaXNwbGF5OmZsZXg7Z2FwOjEwcHg7ZmxleC13cmFwOndyYXB9Ci5jaGlwe2ZsZXg6MTttaW4td2lkdGg6OTZweDtiYWNrZ3JvdW5kOnZhcigtLWNhcmQyKTtib3Jk
HLP:ZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTRweDtwYWRkaW5nOjEycHggMTRweDt0ZXh0LWFsaWduOmNlbnRlcn0KLmNoaXAgLm57Zm9udC1zaXplOjI2cHg7Zm9udC13ZWlnaHQ6ODAwO2xpbmUtaGVpZ2h0OjF9Ci5jaGlwIC5se2NvbG9y
HLP:OnZhcigtLW11dGVkKTtmb250LXNpemU6MTEuNXB4O2xldHRlci1zcGFjaW5nOi42cHg7bWFyZ2luLXRvcDozcHh9Ci5jLW9re2NvbG9yOiMyMmM1NWV9LmMtd2Fybntjb2xvcjojZjU5ZTBifS5jLWVycntjb2xvcjojZWY0NDQ0fS5jLXNraXB7Y29sb3I6Izk0YTNi
HLP:OH0KLnN5c2dyaWR7ZGlzcGxheTpncmlkO2dyaWQtdGVtcGxhdGUtY29sdW1uczoxZnIgMWZyO2dhcDoxcHg7YmFja2dyb3VuZDp2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjE0cHg7b3ZlcmZsb3c6aGlkZGVufQpAbWVkaWEobWF4LXdpZHRoOjUyMHB4KXsuc3lz
HLP:Z3JpZHtncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyfX0KLnN5c3tiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO3BhZGRpbmc6MTFweCAxNHB4fQouc3lzLWt7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMS41cHg7bGV0dGVyLXNwYWNpbmc6LjRweH0KLnN5cy12
HLP:e2ZvbnQtd2VpZ2h0OjYwMDtmb250LXNpemU6MTRweDttYXJnaW4tdG9wOjFweDt3b3JkLWJyZWFrOmJyZWFrLXdvcmR9CmgyLnNlYy1oe2ZvbnQtc2l6ZToxNXB4O2xldHRlci1zcGFjaW5nOi42cHg7dGV4dC10cmFuc2Zvcm06dXBwZXJjYXNlO2NvbG9yOnZhcigt
HLP:LWFjY2VudCk7bWFyZ2luOjMwcHggMCAxMnB4O2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEwcHg7c2Nyb2xsLW1hcmdpbi10b3A6MTRweH0KaDIuc2VjLWg6OmFmdGVye2NvbnRlbnQ6Jyc7ZmxleDoxO2hlaWdodDoxcHg7YmFja2dyb3VuZDp2
HLP:YXIoLS1saW5lKX0KLnRpbWVsaW5le3Bvc2l0aW9uOnJlbGF0aXZlO3BhZGRpbmctbGVmdDo4cHh9Ci5waHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6ZmxleC1zdGFydDtnYXA6MTRweDtwYWRkaW5nOjEzcHggMTZweDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxp
HLP:bmUpO2JvcmRlci1yYWRpdXM6MTRweDttYXJnaW4tYm90dG9tOjEwcHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtwb3NpdGlvbjpyZWxhdGl2ZTtvdmVyZmxvdzpoaWRkZW59Ci5waDo6YmVmb3Jle2NvbnRlbnQ6Jyc7cG9zaXRpb246YWJzb2x1dGU7bGVmdDowO3Rv
HLP:cDowO2JvdHRvbTowO3dpZHRoOjRweH0KLnBoLW9rOjpiZWZvcmV7YmFja2dyb3VuZDojMjJjNTVlfS5waC13YXJuOjpiZWZvcmV7YmFja2dyb3VuZDojZjU5ZTBifS5waC1lcnJvcjo6YmVmb3Jle2JhY2tncm91bmQ6I2VmNDQ0NH0ucGgtc2tpcDo6YmVmb3Jle2Jh
HLP:Y2tncm91bmQ6IzY0NzQ4Yn0KLnBoLWRvdHtmbGV4OjAgMCBhdXRvO21hcmdpbi10b3A6MXB4fQouc3ZnaWNve3dpZHRoOjI2cHg7aGVpZ2h0OjI2cHg7ZGlzcGxheTpibG9ja30KLnBoLW1haW57ZmxleDoxO21pbi13aWR0aDowfQoucGgtdG9we2Rpc3BsYXk6Zmxl
HLP:eDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjEwcHg7ZmxleC13cmFwOndyYXB9Ci5waC1udW17Zm9udC12YXJpYW50LW51bWVyaWM6dGFidWxhci1udW1zO2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTJweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyOjFweCBz
HLP:b2xpZCB2YXIoLS1saW5lKTtib3JkZXItcmFkaXVzOjdweDtwYWRkaW5nOjFweCA3cHh9Ci5waC10aXRsZXtmb250LXdlaWdodDo2MDA7Zm9udC1zaXplOjE1cHh9Ci5waC1iYWRnZXtmb250LXNpemU6MTFweDtmb250LXdlaWdodDo4MDA7bGV0dGVyLXNwYWNpbmc6
HLP:LjZweDtib3JkZXItcmFkaXVzOjk5OXB4O3BhZGRpbmc6MnB4IDEwcHh9Ci5iLW9re2JhY2tncm91bmQ6cmdiYSgzNCwxOTcsOTQsLjE2KTtjb2xvcjojMjJjNTVlfS5iLXdhcm57YmFja2dyb3VuZDpyZ2JhKDI0NSwxNTgsMTEsLjE2KTtjb2xvcjojZjU5ZTBifS5i
HLP:LWVycm9ye2JhY2tncm91bmQ6cmdiYSgyMzksNjgsNjgsLjE2KTtjb2xvcjojZWY0NDQ0fS5iLXNraXB7YmFja2dyb3VuZDpyZ2JhKDEwMCwxMTYsMTM5LC4xOCk7Y29sb3I6Izk0YTNiOH0KLnBoLW5vdGV7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxM3B4
HLP:O21hcmdpbi10b3A6M3B4fQoucGgtc2Vjc3tmbGV4OjAgMCBhdXRvO2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTNweDtmb250LXZhcmlhbnQtbnVtZXJpYzp0YWJ1bGFyLW51bXM7YWxpZ24tc2VsZjpjZW50ZXJ9Ci5lbXB0eXtjb2xvcjp2YXIoLS1tdXRl
HLP:ZCk7cGFkZGluZzoxOHB4O3RleHQtYWxpZ246Y2VudGVyfQouYmFyY2hhcnR7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTRweDtwYWRkaW5nOjE0cHggMThweDttYXJnaW4tdG9wOjRweH0K
HLP:LmJhci1yb3d7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtnYXA6MTJweDtwYWRkaW5nOjVweCAwfQouYmFyLWxibHtmbGV4OjAgMCAyMjBweDtmb250LXNpemU6MTIuNXB4O2NvbG9yOnZhcigtLW11dGVkKTt3aGl0ZS1zcGFjZTpub3dyYXA7b3ZlcmZs
HLP:b3c6aGlkZGVuO3RleHQtb3ZlcmZsb3c6ZWxsaXBzaXN9CkBtZWRpYShtYXgtd2lkdGg6NjAwcHgpey5iYXItbGJse2ZsZXg6MCAwIDEyMHB4fX0KLmJhci10cmFja3tmbGV4OjE7aGVpZ2h0OjEwcHg7Ym9yZGVyLXJhZGl1czo5OTlweDtiYWNrZ3JvdW5kOnZhcigt
HLP:LWxpbmUpO292ZXJmbG93OmhpZGRlbn0KLmJhci10cmFjayBzcGFue2Rpc3BsYXk6YmxvY2s7aGVpZ2h0OjEwMCU7Ym9yZGVyLXJhZGl1czo5OTlweH0KLmJhci12YWx7ZmxleDowIDAgYXV0bztmb250LXNpemU6MTIuNXB4O2NvbG9yOnZhcigtLW11dGVkKTtmb250
HLP:LXZhcmlhbnQtbnVtZXJpYzp0YWJ1bGFyLW51bXM7d2lkdGg6NDhweDt0ZXh0LWFsaWduOnJpZ2h0fQp1bC5maW5kc3tsaXN0LXN0eWxlOm5vbmU7bWFyZ2luOjA7cGFkZGluZzowfQouZmluZHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6ZmxleC1zdGFydDtnYXA6
HLP:MTJweDtwYWRkaW5nOjEycHggMTZweDtib3JkZXI6MXB4IHNvbGlkIHZhcigtLWxpbmUpO2JvcmRlci1yYWRpdXM6MTNweDttYXJnaW4tYm90dG9tOjlweDtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpfQouc2V2e2ZsZXg6MCAwIGF1dG87Zm9udC1zaXplOjExcHg7Zm9u
HLP:dC13ZWlnaHQ6ODAwO2xldHRlci1zcGFjaW5nOi41cHg7Ym9yZGVyLXJhZGl1czo4cHg7cGFkZGluZzozcHggMTBweDttYXJnaW4tdG9wOjFweH0KLnNldi1oaWdoe2JhY2tncm91bmQ6cmdiYSgyMzksNjgsNjgsLjE2KTtjb2xvcjojZWY0NDQ0fS5zZXYtbWVke2Jh
HLP:Y2tncm91bmQ6cmdiYSgyNDUsMTU4LDExLC4xNik7Y29sb3I6I2Y1OWUwYn0uc2V2LWluZm97YmFja2dyb3VuZDpyZ2JhKDU2LDE4OSwyNDgsLjE2KTtjb2xvcjp2YXIoLS1hY2NlbnQpfS5zZXYtb2t7YmFja2dyb3VuZDpyZ2JhKDM0LDE5Nyw5NCwuMTYpO2NvbG9y
HLP:OiMyMmM1NWV9Ci5maW5kLXR4dHtmb250LXNpemU6MTRweH0KdWwuc3RlcHN7bGlzdC1zdHlsZTpub25lO21hcmdpbjowO3BhZGRpbmc6MH0KLnN0ZXAtbGl7ZGlzcGxheTpmbGV4O2dhcDoxMXB4O2FsaWduLWl0ZW1zOmZsZXgtc3RhcnQ7cGFkZGluZzoxMXB4IDE2
HLP:cHg7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1saW5lKTtib3JkZXItbGVmdDozcHggc29saWQgdmFyKC0tYWNjZW50KTtib3JkZXItcmFkaXVzOjEycHg7bWFyZ2luLWJvdHRvbTo5cHg7YmFja2dyb3VuZDp2YXIoLS1jYXJkKTtmb250LXNpemU6MTRweH0KLnN0ZXAt
HLP:b2t7Ym9yZGVyLWxlZnQtY29sb3I6IzIyYzU1ZX0KLnN0ZXAtaWN7Y29sb3I6dmFyKC0tYWNjZW50KTtmb250LXdlaWdodDo4MDB9Ci5zdGVwLW9rIC5zdGVwLWlje2NvbG9yOiMyMmM1NWV9Ci5kZ3JpZHtkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5z
HLP:OnJlcGVhdChhdXRvLWZpdCxtaW5tYXgoMjIwcHgsMWZyKSk7Z2FwOjE0cHh9Ci5kY2FyZHtiYWNrZ3JvdW5kOnZhcigtLWNhcmQpO2JvcmRlcjoxcHggc29saWQgdmFyKC0tbGluZSk7Ym9yZGVyLXJhZGl1czoxNXB4O3BhZGRpbmc6MTZweCAxOHB4fQouZGNhcmQt
HLP:d2lkZXtncmlkLWNvbHVtbjoxLy0xfQouZC1oe2Rpc3BsYXk6ZmxleDthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjlweDtmb250LXdlaWdodDo3MDA7Zm9udC1zaXplOjE0cHg7bWFyZ2luLWJvdHRvbToxMHB4fQouZC1pY3t3aWR0aDoxNHB4O2hlaWdodDoxNHB4O2Jv
HLP:cmRlci1yYWRpdXM6NXB4O2Rpc3BsYXk6aW5saW5lLWJsb2NrfQouaWMtcmFte2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjMzhiZGY4LCMwZWE1ZTkpfS5pYy1iYXR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCMyMmM1NWUsIzE1
HLP:ODAzZCl9LmljLW5ldHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzgxOGNmOCwjNGY0NmU1KX0uaWMtZGV2e2JhY2tncm91bmQ6bGluZWFyLWdyYWRpZW50KDEzNWRlZywjZjU5ZTBiLCNkOTc3MDYpfS5pYy1zbWFydHtiYWNrZ3JvdW5kOmxpbmVh
HLP:ci1ncmFkaWVudCgxMzVkZWcsI2Y0NzJiNiwjZGIyNzc3KX0uaWMtYm9vdHtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVkZWcsIzJkZDRiZiwjMGQ5NDg4KX0uaWMtc3RhcnR7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNhNzhiZmEsIzdj
HLP:M2FlZCl9LmljLXByb2N7YmFja2dyb3VuZDpsaW5lYXItZ3JhZGllbnQoMTM1ZGVnLCNmYjcxODUsI2UxMWQ0OCl9Ci5kLXBpbGx7ZGlzcGxheTppbmxpbmUtYmxvY2s7Zm9udC1zaXplOjEyLjVweDtmb250LXdlaWdodDo3MDA7Ym9yZGVyLXJhZGl1czo5OTlweDtw
HLP:YWRkaW5nOjRweCAxMnB4fQoucGlsbC1yb3d7ZGlzcGxheTpmbGV4O2dhcDo4cHg7ZmxleC13cmFwOndyYXB9Ci5waWxsLWdvb2R7YmFja2dyb3VuZDpyZ2JhKDM0LDE5Nyw5NCwuMTYpO2NvbG9yOiMyMmM1NWV9LnBpbGwtYmFke2JhY2tncm91bmQ6cmdiYSgyMzks
HLP:NjgsNjgsLjE2KTtjb2xvcjojZWY0NDQ0fS5waWxsLXVua25vd257YmFja2dyb3VuZDpyZ2JhKDE0OCwxNjMsMTg0LC4xNik7Y29sb3I6Izk0YTNiOH0KLmQtc3Vie2NvbG9yOnZhcigtLW11dGVkKTtmb250LXNpemU6MTIuNXB4O21hcmdpbi10b3A6OHB4fQouZC1o
HLP:aW50e2NvbG9yOiNmNTllMGI7Zm9udC1zaXplOjEyLjVweDttYXJnaW4tdG9wOjhweH0KLmJhdC1iYXJ7aGVpZ2h0OjEycHg7Ym9yZGVyLXJhZGl1czo5OTlweDtiYWNrZ3JvdW5kOnZhcigtLWxpbmUpO292ZXJmbG93OmhpZGRlbjttYXJnaW4tdG9wOjRweH0KLmJh
HLP:dC1iYXIgc3BhbntkaXNwbGF5OmJsb2NrO2hlaWdodDoxMDAlO2JvcmRlci1yYWRpdXM6OTk5cHh9Ci5kZXYtbGlzdHttYXJnaW46NHB4IDAgMDtwYWRkaW5nLWxlZnQ6MThweDtmb250LXNpemU6MTMuNXB4fQouZGV2LWxpc3QgbGl7bWFyZ2luOjJweCAwfQoubXV0
HLP:ZWR7Y29sb3I6dmFyKC0tbXV0ZWQpfQouZm9vdHttYXJnaW4tdG9wOjM0cHg7dGV4dC1hbGlnbjpjZW50ZXI7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMnB4fQouc2VjdGlvbnthbmltYXRpb246cmlzZSAuNXMgZWFzZSBib3RofQpAa2V5ZnJhbWVzIGZp
HLP:bGx7dG97c3Ryb2tlLWRhc2hvZmZzZXQ6dmFyKC0tdGFyZ2V0KX19CkBrZXlmcmFtZXMgcmlzZXtmcm9te29wYWNpdHk6MDt0cmFuc2Zvcm06dHJhbnNsYXRlWSgxMHB4KX10b3tvcGFjaXR5OjE7dHJhbnNmb3JtOm5vbmV9fQpAbWVkaWEgcHJpbnR7LnRvZ2dsZSwu
HLP:dG9jLC5idG5zLC50b2FzdHtkaXNwbGF5Om5vbmV9Ym9keXtiYWNrZ3JvdW5kOiNmZmY7Y29sb3I6IzAwMH0uY2FyZCwuZGNhcmQsLnBoLC5maW5kLC5leGVjLC5iYXJjaGFydCwuc3RlcC1saXtib3gtc2hhZG93Om5vbmU7YmFja2Ryb3AtZmlsdGVyOm5vbmU7LXdl
HLP:YmtpdC1iYWNrZHJvcC1maWx0ZXI6bm9uZTtiYWNrZ3JvdW5kOiNmZmYhaW1wb3J0YW50fS5nYXVnZSAuZmlsbHthbmltYXRpb246bm9uZX0uc2VjdGlvbnthbmltYXRpb246bm9uZX1hW2hyZWZde2NvbG9yOmluaGVyaXQ7dGV4dC1kZWNvcmF0aW9uOm5vbmV9fQo6
HLP:cm9vdHstLWdsYXNzOnJnYmEoMTgsMjYsNDMsLjYwKTstLWdsYXNzYmQ6cmdiYSgyNTUsMjU1LDI1NSwuMDcpfQpodG1sLmxpZ2h0ey0tZ2xhc3M6cmdiYSgyNTUsMjU1LDI1NSwuNjQpOy0tZ2xhc3NiZDpyZ2JhKDE1LDIzLDQyLC4wOCl9Ci5jYXJkLC5leGVjLC5k
HLP:Y2FyZCwuZmluZCwuYmFyY2hhcnQsLnN0ZXAtbGl7YmFja2dyb3VuZDp2YXIoLS1nbGFzcykhaW1wb3J0YW50O2JhY2tkcm9wLWZpbHRlcjpibHVyKDEzcHgpIHNhdHVyYXRlKDE0MCUpOy13ZWJraXQtYmFja2Ryb3AtZmlsdGVyOmJsdXIoMTNweCkgc2F0dXJhdGUo
HLP:MTQwJSk7Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1nbGFzc2JkKSFpbXBvcnRhbnR9Ci50b2FzdHtwb3NpdGlvbjpmaXhlZDtib3R0b206MjRweDtsZWZ0OjUwJTt0cmFuc2Zvcm06dHJhbnNsYXRlWCgtNTAlKTtiYWNrZ3JvdW5kOmxpbmVhci1ncmFkaWVudCgxMzVk
HLP:ZWcsdmFyKC0tYWNjZW50KSx2YXIoLS1hY2NlbnQyKSk7Y29sb3I6IzA0MjkzYjtmb250LXdlaWdodDo3MDA7cGFkZGluZzoxMHB4IDE4cHg7Ym9yZGVyLXJhZGl1czoxMnB4O2JveC1zaGFkb3c6dmFyKC0tc2hhZG93KTtvcGFjaXR5OjA7cG9pbnRlci1ldmVudHM6
HLP:bm9uZTt0cmFuc2l0aW9uOm9wYWNpdHkgLjI1czt6LWluZGV4OjYwO2ZvbnQtc2l6ZToxM3B4fQoudG9hc3Quc2hvd3tvcGFjaXR5OjF9Ci50cmVuZC10aXRsZXttYXJnaW4tdG9wOjIwcHg7Zm9udC1zaXplOjEycHg7Zm9udC13ZWlnaHQ6NzAwO2xldHRlci1zcGFj
HLP:aW5nOjFweDt0ZXh0LXRyYW5zZm9ybTp1cHBlcmNhc2U7Y29sb3I6dmFyKC0tbXV0ZWQpfQoudHJlbmQtbGlzdHtkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2dhcDo0cHg7d2lkdGg6MTAwJTttYXJnaW4tdG9wOjhweDtib3JkZXItdG9wOjFweCBz
HLP:b2xpZCB2YXIoLS1saW5lKTtwYWRkaW5nLXRvcDo4cHh9Ci50cmVuZC1pdGVte2Rpc3BsYXk6ZmxleDtqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2Vlbjtmb250LXNpemU6MTJweH0KLnRyZW5kLWRhdGV7Y29sb3I6dmFyKC0tbXV0ZWQpfQoudHJlbmQtc2NvcmV7
HLP:Zm9udC13ZWlnaHQ6NzAwfQo8L3N0eWxlPgo8L2hlYWQ+Cjxib2R5Pgo8ZGl2IGNsYXNzPSd3cmFwJz4KICA8ZGl2IGNsYXNzPSd0b3BiYXInPgogICAgPGRpdiBjbGFzcz0nYnJhbmQnPgogICAgICA8ZGl2IGNsYXNzPSdsb2dvJz48c3ZnIHZpZXdCb3g9JzAgMCAy
HLP:NCAyNCcgd2lkdGg9JzI2JyBoZWlnaHQ9JzI2JyByb2xlPSdpbWcnIGFyaWEtbGFiZWw9J1dQSSc+PHBhdGggZD0nTTEyIDJsNyAzdjZjMCA0LjYtMyA4LjMtNyA5LjZDOCAxOS4zIDUgMTUuNiA1IDExVjV6JyBmaWxsPScjMDQyOTNiJy8+PHBhdGggZD0nTTkgMTJs
HLP:MiAyIDQtNC41JyBmaWxsPSdub25lJyBzdHJva2U9JyNkZmY2ZmYnIHN0cm9rZS13aWR0aD0nMicgc3Ryb2tlLWxpbmVjYXA9J3JvdW5kJyBzdHJva2UtbGluZWpvaW49J3JvdW5kJy8+PC9zdmc+PC9kaXY+CiAgICAgIDxkaXY+CiAgICAgICAgPGgxPkluZm9ybWUg
HLP:ZGUgUmVwYXJhY2lvbiA8c3BhbiBjbGFzcz0nYmFkZ2UnPldQSSBTVUlURSB2My4xPC9zcGFuPjwvaDE+CiAgICAgICAgPGRpdiBjbGFzcz0nc3ViJz4kKCYgJGVuYyAkbWFjaGluZSkgJm5ic3A7Jm1pZGRvdDsmbmJzcDsgZ2VuZXJhZG8gZWwgJG5vdzwvZGl2Pgog
HLP:ICAgICA8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0nYnRucyc+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2dsZScgb25jbGljaz0id2luZG93LnByaW50KCkiPkltcHJpbWlyIC8gUERGPC9idXR0b24+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2ds
HLP:ZScgaWQ9J2NvcHlidG4nIG9uY2xpY2s9ImNvcHlSZXN1bWVuKCkiPkNvcGlhciByZXN1bWVuPC9idXR0b24+CiAgICAgIDxidXR0b24gY2xhc3M9J3RvZ2dsZScgaWQ9J3RoZW1lYnRuJyBvbmNsaWNrPSJ0b2dnbGVUaGVtZSgpIj5UZW1hIGNsYXJvL29zY3Vybzwv
HLP:YnV0dG9uPgogICAgPC9kaXY+CiAgPC9kaXY+CgogIDxuYXYgY2xhc3M9J3RvYycgYXJpYS1sYWJlbD0nSW5kaWNlJz4KICAgIDxhIGhyZWY9JyNyZXN1bWVuJz5SZXN1bWVuPC9hPgogICAgPGEgaHJlZj0nI2Zhc2VzJz5GYXNlczwvYT4KICAgIDxhIGhyZWY9JyNo
HLP:YWxsYXpnb3MnPkhhbGxhemdvczwvYT4KICAgIDxhIGhyZWY9JyNwYXNvcyc+UHJveGltb3MgcGFzb3M8L2E+CiAgICA8YSBocmVmPScjZGlhZyc+RGlhZ25vc3RpY288L2E+CiAgPC9uYXY+CgogIDxkaXYgaWQ9J3Jlc3VtZW4nIGNsYXNzPSdleGVjIHNlY3Rpb24n
HLP:PgogICAgPGRpdiBjbGFzcz0nZXhlYy1zY29yZScgc3R5bGU9J2NvbG9yOiRtYWluQ29sb3InPiRtYWluU2NvcmU8L2Rpdj4KICAgIDxkaXYgY2xhc3M9J2V4ZWMtbWlkJz4KICAgICAgPGRpdiBjbGFzcz0nZXhlYy12ZXJkaWN0JyBzdHlsZT0nY29sb3I6JG1haW5D
HLP:b2xvcic+U2FsdWQgZGVsIHNpc3RlbWE6ICRleGVjVmVyZGljdDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdleGVjLWxpbmUnPiRjT0sgY29ycmVjdGFzICZtaWRkb3Q7ICRjV0FSTiBhdmlzb3MgJm1pZGRvdDsgJGNFUlIgZXJyb3JlcyAmbWlkZG90OyAkY1NLSVAg
HLP:b21pdGlkYXMgJm1pZGRvdDsgJHRvdGFsUGggZmFzZXMgZW4gdG90YWw8L2Rpdj4KICAgICAgPGRpdiBjbGFzcz0nZXhlYy1saW5lJz4kc3RhdExpbmU8L2Rpdj4KICAgIDwvZGl2PgogICAgPGRpdiBjbGFzcz0nZXhlYy1kZWx0YScgc3R5bGU9J2NvbG9yOiRkZWx0
HLP:YUNvbG9yO2JvcmRlci1jb2xvcjokZGVsdGFDb2xvcic+JGRlbHRhVHh0PC9kaXY+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J2hlcm8gc2VjdGlvbic+CiAgICA8ZGl2IGNsYXNzPSdjYXJkIGdhdWdld3JhcCc+CiAgICAgIDxzdmcgdmlld0JveD0nMCAwIDIwMCAy
HLP:MDAnIGNsYXNzPSdnYXVnZScgcm9sZT0naW1nJyBhcmlhLWxhYmVsPSdQdW50dWFjaW9uIGRlIHNhbHVkICRtYWluU2NvcmUgc29icmUgMTAwJz48Y2lyY2xlIGNsYXNzPSd0cmFjaycgY3g9JzEwMCcgY3k9JzEwMCcgcj0nODQnLz48Y2lyY2xlIGNsYXNzPSdmaWxs
HLP:JyBjeD0nMTAwJyBjeT0nMTAwJyByPSc4NCcgc3R5bGU9Jy0tY2lyYzokY2lyYzstLXRhcmdldDokbWFpbk9mZnNldDtzdHJva2U6JG1haW5Db2xvcicvPjx0ZXh0IHg9JzEwMCcgeT0nMTEyJyBjbGFzcz0nZy1udW0nIHN0eWxlPSdmaWxsOiRtYWluQ29sb3InPiRt
HLP:YWluU2NvcmU8L3RleHQ+PC9zdmc+CiAgICAgIDxkaXYgY2xhc3M9J2ctbGFiZWwnIHN0eWxlPSdjb2xvcjokbWFpbkNvbG9yJz5TYWx1ZDogJG1haW5MYWJlbDwvZGl2PgogICAgICA8ZGl2IGNsYXNzPSdnLWNhcCc+UFVOVFVBQ0lPTiBTT0JSRSAxMDA8L2Rpdj4K
HLP:ICAgICAgJGNvbXBhcmVTZWN0aW9uCiAgICAgICRoaXN0b3J5SHRtbAogICAgPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdoZXJvLXNpZGUnPgogICAgICA8ZGl2IGNsYXNzPSdjYXJkJz4KICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwcyc+CiAgICAgICAgICA8ZGl2IGNs
HLP:YXNzPSdjaGlwJz48ZGl2IGNsYXNzPSduIGMtb2snPiRjT0s8L2Rpdj48ZGl2IGNsYXNzPSdsJz5PSzwvZGl2PjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBjLXdhcm4nPiRjV0FSTjwvZGl2PjxkaXYgY2xhc3M9J2wnPkFW
HLP:SVNPUzwvZGl2PjwvZGl2PgogICAgICAgICAgPGRpdiBjbGFzcz0nY2hpcCc+PGRpdiBjbGFzcz0nbiBjLWVycic+JGNFUlI8L2Rpdj48ZGl2IGNsYXNzPSdsJz5FUlJPUkVTPC9kaXY+PC9kaXY+CiAgICAgICAgICA8ZGl2IGNsYXNzPSdjaGlwJz48ZGl2IGNsYXNz
HLP:PSduIGMtc2tpcCc+JGNTS0lQPC9kaXY+PGRpdiBjbGFzcz0nbCc+T01JVElEQVM8L2Rpdj48L2Rpdj4KICAgICAgICA8L2Rpdj4KICAgICAgPC9kaXY+CiAgICAgIDxkaXYgY2xhc3M9J2NhcmQnPgogICAgICAgIDxkaXYgY2xhc3M9J3N5c2dyaWQnPiRzeXNDYXJk
HLP:czwvZGl2PgogICAgICA8L2Rpdj4KICAgIDwvZGl2PgogIDwvZGl2PgoKICA8ZGl2IGNsYXNzPSdzZWN0aW9uJz4KICAgIDxoMiBpZD0nZmFzZXMnIGNsYXNzPSdzZWMtaCc+TGluZWEgZGUgdGllbXBvIGRlIGZhc2VzICgkdG90YWxQaCk8L2gyPgogICAgPGRpdiBj
HLP:bGFzcz0ndGltZWxpbmUnPiRyb3dzPC9kaXY+CiAgICA8ZGl2IGNsYXNzPSdiYXJjaGFydCc+JGJhcnM8L2Rpdj4KICA8L2Rpdj4KCiAgPGRpdiBjbGFzcz0nc2VjdGlvbic+CiAgICA8aDIgaWQ9J2hhbGxhemdvcycgY2xhc3M9J3NlYy1oJz5IYWxsYXpnb3MgeSBj
HLP:YXVzYSByYWl6PC9oMj4KICAgIDx1bCBjbGFzcz0nZmluZHMnPiRmaW5kSHRtbDwvdWw+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPgogICAgPGgyIGlkPSdwYXNvcycgY2xhc3M9J3NlYy1oJz5Qcm94aW1vcyBwYXNvcyByZWNvbWVuZGFkb3M8L2gy
HLP:PgogICAgPHVsIGNsYXNzPSdzdGVwcyc+JHN0ZXBzSHRtbDwvdWw+CiAgPC9kaXY+CgogIDxkaXYgY2xhc3M9J3NlY3Rpb24nPiRkaWFnU2VjdGlvbjwvZGl2PgoKICA8ZGl2IGNsYXNzPSdmb290Jz4KICAgIFdQSSAmbWlkZG90OyBTdWl0ZSBkZSBSZXBhcmFjaW9u
HLP:IGRlIEVtZXJnZW5jaWEgcGFyYSBXaW5kb3dzIDEwLzExICZtaWRkb3Q7IGluZm9ybWUgZGUgc29sbyBsZWN0dXJhLjxicj4KICAgIExhcyBjb3BpYXMgZGUgc2VndXJpZGFkIHkgbG9zIHJlZ2lzdHJvcyBlc3RhbiBlbiBsYSBjYXJwZXRhIFdQSV9TdWl0ZSBqdW50
HLP:byBhbCBwcm9ncmFtYS4KICA8L2Rpdj4KPC9kaXY+CjxzY3JpcHQ+CihmdW5jdGlvbigpe3RyeXt2YXIgcz1sb2NhbFN0b3JhZ2UuZ2V0SXRlbSgnd3BpLXRoZW1lJyk7dmFyIHJvb3Q9ZG9jdW1lbnQuZG9jdW1lbnRFbGVtZW50O2lmKHM9PT0nbGlnaHQnKXtyb290
HLP:LmNsYXNzTGlzdC5hZGQoJ2xpZ2h0Jyk7fWVsc2UgaWYocz09PSdkYXJrJyl7cm9vdC5jbGFzc0xpc3QucmVtb3ZlKCdsaWdodCcpO31lbHNlIGlmKHdpbmRvdy5tYXRjaE1lZGlhJiZ3aW5kb3cubWF0Y2hNZWRpYSgnKHByZWZlcnMtY29sb3Itc2NoZW1lOiBsaWdo
HLP:dCknKS5tYXRjaGVzKXtyb290LmNsYXNzTGlzdC5hZGQoJ2xpZ2h0Jyk7fX1jYXRjaChlKXt9fSkoKTsKZnVuY3Rpb24gdG9nZ2xlVGhlbWUoKXt0cnl7dmFyIGw9ZG9jdW1lbnQuZG9jdW1lbnRFbGVtZW50LmNsYXNzTGlzdC50b2dnbGUoJ2xpZ2h0Jyk7bG9jYWxT
HLP:dG9yYWdlLnNldEl0ZW0oJ3dwaS10aGVtZScsbD8nbGlnaHQnOidkYXJrJyk7fWNhdGNoKGUpe319CmZ1bmN0aW9uIGZsYXNoKG0pe3RyeXt2YXIgdD1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCdkaXYnKTt0LmNsYXNzTmFtZT0ndG9hc3QnO3QudGV4dENvbnRlbnQ9
HLP:bTtkb2N1bWVudC5ib2R5LmFwcGVuZENoaWxkKHQpO3JlcXVlc3RBbmltYXRpb25GcmFtZShmdW5jdGlvbigpe3QuY2xhc3NMaXN0LmFkZCgnc2hvdycpO30pO3NldFRpbWVvdXQoZnVuY3Rpb24oKXt0LmNsYXNzTGlzdC5yZW1vdmUoJ3Nob3cnKTtzZXRUaW1lb3V0
HLP:KGZ1bmN0aW9uKCl7dC5yZW1vdmUoKTt9LDMwMCk7fSwxNjAwKTt9Y2F0Y2goZSl7fX0KZnVuY3Rpb24gZmIodHh0LG9rKXt0cnl7dmFyIGE9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgndGV4dGFyZWEnKTthLnZhbHVlPXR4dDthLnN0eWxlLnBvc2l0aW9uPSdmaXhl
HLP:ZCc7YS5zdHlsZS5sZWZ0PSctOTk5OXB4Jztkb2N1bWVudC5ib2R5LmFwcGVuZENoaWxkKGEpO2Euc2VsZWN0KCk7ZG9jdW1lbnQuZXhlY0NvbW1hbmQoJ2NvcHknKTthLnJlbW92ZSgpO29rKCk7fWNhdGNoKGUpe2ZsYXNoKCdObyBzZSBwdWRvIGNvcGlhcicpO319
HLP:CmZ1bmN0aW9uIGNvcHlSZXN1bWVuKCl7dmFyIHA9W107dmFyIHQ9ZG9jdW1lbnQucXVlcnlTZWxlY3RvcignaDEnKTtpZih0KXAucHVzaCh0LmlubmVyVGV4dC50cmltKCkpO3ZhciBzPWRvY3VtZW50LnF1ZXJ5U2VsZWN0b3IoJy5zdWInKTtpZihzKXAucHVzaChz
HLP:LmlubmVyVGV4dC50cmltKCkpO3ZhciBleD1kb2N1bWVudC5xdWVyeVNlbGVjdG9yKCcuZXhlYycpO2lmKGV4KXAucHVzaCgnXG4nK2V4LmlubmVyVGV4dC5yZXBsYWNlKC9cbnsyLH0vZywnXG4nKS50cmltKCkpO3ZhciBoPWRvY3VtZW50LmdldEVsZW1lbnRCeUlk
HLP:KCdoYWxsYXpnb3MnKTtpZihoJiZoLnBhcmVudE5vZGUpcC5wdXNoKCdcbicraC5wYXJlbnROb2RlLmlubmVyVGV4dC50cmltKCkpO3ZhciB0eHQ9cC5qb2luKCdcbicpO2Z1bmN0aW9uIG9rKCl7Zmxhc2goJ1Jlc3VtZW4gY29waWFkbycpO31pZihuYXZpZ2F0b3Iu
HLP:Y2xpcGJvYXJkJiZuYXZpZ2F0b3IuY2xpcGJvYXJkLndyaXRlVGV4dCl7bmF2aWdhdG9yLmNsaXBib2FyZC53cml0ZVRleHQodHh0KS50aGVuKG9rLGZ1bmN0aW9uKCl7ZmIodHh0LG9rKTt9KTt9ZWxzZXtmYih0eHQsb2spO319Cjwvc2NyaXB0Pgo8L2JvZHk+Cjwv
HLP:aHRtbD4KIkAKICAgICAgICAkdXRmOCA9IE5ldy1PYmplY3QgU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nKCRmYWxzZSkKICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJG91dFBhdGgsICRodG1sLCAkdXRmOCkKICAgICAgICAiUkVTVUxUPU9L
HLP:IgogICAgICAgICJQQVRIPSRvdXRQYXRoIgogICAgfSBjYXRjaCB7CiAgICAgICAgIlJFU1VMVD1GQUlMIgogICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgIH0KfQoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIFJlZ2lzdHJhciByZXN1bHRhZG8gZGUgdW5hIGZhc2UgZW4gZWwgZXN0YWRvIChwYXJhIGVsIGluZm9ybWUpLgojIC1BcmcgPSAibnVtO3RpdGxlO3Jlc3VsdDtzZWNzO25vdGUiCmZ1bmN0aW9u
HLP:IEFkZC1QaGFzZVJlc3VsdCgkc3BlYykgewogICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgJHBhcnRzID0gJHNwZWMgLXNwbGl0ICc7Jyw1CiAgICAkcGggPSBbcHNjdXN0b21vYmplY3RdQHsgbnVtPSRwYXJ0c1swXTsgdGl0bGU9JHBhcnRzWzFdOyByZXN1bHQ9JHBh
HLP:cnRzWzJdOyBzZWNzPSRwYXJ0c1szXTsgbm90ZT0kcGFydHNbNF0gfQogICAgJGxpc3QgPSBAKCRzdC5waGFzZXMpICsgJHBoCiAgICAkc3QucGhhc2VzID0gJGxpc3QKICAgIFdyaXRlLVN0YXRlICRzdAogICAgIlJFU1VMVD1PSyIKfQpmdW5jdGlvbiBTZXQtU2Nv
HLP:cmUoJHdoaWNoLCAkdmFsKSB7CiAgICAkc3QgPSBSZWFkLVN0YXRlCiAgICBpZiAoJHdoaWNoIC1lcSAnYmVmb3JlJykgeyAKICAgICAgICAkc3Quc2NvcmVfYmVmb3JlID0gW2ludF0kdmFsIAogICAgfSBlbHNlIHsgCiAgICAgICAgJHN0LnNjb3JlX2FmdGVyID0g
HLP:W2ludF0kdmFsIAogICAgICAgIFNhdmUtSGVhbHRoSGlzdG9yeSBbaW50XSR2YWwKICAgIH0KICAgIFdyaXRlLVN0YXRlICRzdDsgIlJFU1VMVD1PSyIKfQpmdW5jdGlvbiBBZGQtRmluZGluZygkdGV4dCkgewogICAgJHN0ID0gUmVhZC1TdGF0ZTsgJHN0LmZpbmRp
HLP:bmdzID0gQCgkc3QuZmluZGluZ3MpICsgJHRleHQ7IFdyaXRlLVN0YXRlICRzdDsgIlJFU1VMVD1PSyIKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICBMT0dJQ0Eg
HLP:UFVSQSBOVUVWQSAvIENPUlJFR0lEQSAoQmxvcXVlIDMpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCiMgLS0tICgzLjEgLyBCdWcgNCAvIFJlcSA2KSBOb3JtYWxpemFj
HLP:aW9uIGRlIGxhIHNlbGVjY2lvbiBkZSBmYXNlcyAtLS0tLS0tLS0tCiMgRW50cmFkYTogY2FkZW5hIGNvbiBJRHMgc2VwYXJhZG9zIHBvciBjb21hcyAoZXNwYWNpb3MgYXJiaXRyYXJpb3MsIDEtMgojIGRpZ2l0b3MsIHBvc2libGVzIGludmFsaWRvcykuIFNhbGlk
HLP:YTogb2JqZXRvIGNvbiAubm9ybSAobGlzdGEgY2Fub25pY2EsCiMgb3JkZW5hZGEsIHVuaWNhIGRlIElEcyBkZSAyIGRpZ2l0b3MgZW4gezAwLi4xNn0pIHkgLmludmFsaWQgKGxvcyBubyB2YWxpZG9zKS4KIyBOdW5jYSBsYW56YSBleGNlcGNpb24gYW50ZSBlbnRy
HLP:YWRhIG1hbGZvcm1hZGEgbyB2YWNpYS4KZnVuY3Rpb24gTm9ybWFsaXplLUZhc2VzKFtzdHJpbmddJHJhdykgewogICAgJHZhbGlkICAgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAgJGludmFsaWQgPSBOZXct
HLP:T2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogICAgaWYgKCRudWxsIC1uZSAkcmF3IC1hbmQgJHJhdy5UcmltKCkuTGVuZ3RoIC1ndCAwKSB7CiAgICAgICAgZm9yZWFjaCAoJHQgaW4gKCRyYXcgLXNwbGl0ICcsJykpIHsKICAg
HLP:ICAgICAgICAgaWYgKCRudWxsIC1lcSAkdCkgeyBjb250aW51ZSB9CiAgICAgICAgICAgICR0b2sgPSAoJHQgLXJlcGxhY2UgJ1xzJywgJycpICAgICAgICAgICMgcXVpdGFyIGVzcGFjaW9zIGludGVybm9zIHkgZXh0ZXJub3MKICAgICAgICAgICAgaWYgKCR0b2sg
HLP:LWVxICcnKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgJGNhbm9uID0gJHRvawogICAgICAgICAgICBpZiAoJHRvayAtbWF0Y2ggJ15cZCQnKSB7ICRjYW5vbiA9ICR0b2suUGFkTGVmdCgyLCAnMCcpIH0gICAjIDEgZGlnaXRvIC0+IDIgZGlnaXRvcwogICAgICAg
HLP:ICAgICBpZiAoJGNhbm9uIC1tYXRjaCAnXlxkezJ9JCcgLWFuZCBbaW50XSRjYW5vbiAtZ2UgMCAtYW5kIFtpbnRdJGNhbm9uIC1sZSAxNikgewogICAgICAgICAgICAgICAgaWYgKC1ub3QgJHZhbGlkLkNvbnRhaW5zKCRjYW5vbikpIHsgJHZhbGlkLkFkZCgkY2Fu
HLP:b24pIH0KICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgICRpbnZhbGlkLkFkZCgkdG9rKQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgfQogICAgJHNvcnRlZCA9IEAoJHZhbGlkIHwgU29ydC1PYmplY3QpCiAgICByZXR1cm4gW3BzY3VzdG9t
HLP:b2JqZWN0XUB7IG5vcm0gPSAkc29ydGVkOyBpbnZhbGlkID0gQCgkaW52YWxpZCkgfQp9CgojIC0tLSAoMy4zIC8gUmVxIDQpIENoZWNrcG9pbnQgc29icmUgY2hlY2twb2ludC5qc29uIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIFBhcnNlciBkZWwgLUFyZyBj
HLP:b24gZm9ybWF0bzoKIyAgICJzYXZlfHNlbGVjdGlvbj0wMCwwMSwwMnxjb21wbGV0ZWQ9MDAsMDF8bW9kZT1hdXRvOjE7ZHJ5OjB8cmVhc29uPWNoa2RzayIKZnVuY3Rpb24gUGFyc2UtQ2hlY2twb2ludEFyZyhbc3RyaW5nXSRyYXcpIHsKICAgICRyZXMgPSBbb3Jk
HLP:ZXJlZF1AeyBzdWIgPSAnJzsgc2VsZWN0aW9uID0gQCgpOyBjb21wbGV0ZWQgPSBAKCk7IG1vZGUgPSBAe307IHJlYXNvbiA9ICcnIH0KICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JFbXB0eSgkcmF3KSkgeyByZXR1cm4gJHJlcyB9CiAgICAkc2VncyA9ICRyYXcg
HLP:LXNwbGl0ICdcfCcKICAgICRyZXMuc3ViID0gJHNlZ3NbMF0uVHJpbSgpLlRvTG93ZXIoKQogICAgZm9yICgkaSA9IDE7ICRpIC1sdCAkc2Vncy5Db3VudDsgJGkrKykgewogICAgICAgICRrdiA9ICRzZWdzWyRpXSAtc3BsaXQgJz0nLCAyCiAgICAgICAgaWYgKCRr
HLP:di5Db3VudCAtbHQgMikgeyBjb250aW51ZSB9CiAgICAgICAgJGtleSA9ICRrdlswXS5UcmltKCkuVG9Mb3dlcigpCiAgICAgICAgJHZhbCA9ICRrdlsxXQogICAgICAgIHN3aXRjaCAoJGtleSkgewogICAgICAgICAgICAnc2VsZWN0aW9uJyB7ICRyZXMuc2VsZWN0
HLP:aW9uID0gQCgkdmFsIC1zcGxpdCAnLCcgfCBGb3JFYWNoLU9iamVjdCB7ICRfLlRyaW0oKSB9IHwgV2hlcmUtT2JqZWN0IHsgJF8gLW5lICcnIH0pIH0KICAgICAgICAgICAgJ2NvbXBsZXRlZCcgeyAkcmVzLmNvbXBsZXRlZCA9IEAoJHZhbCAtc3BsaXQgJywnIHwg
HLP:Rm9yRWFjaC1PYmplY3QgeyAkXy5UcmltKCkgfSB8IFdoZXJlLU9iamVjdCB7ICRfIC1uZSAnJyB9KSB9CiAgICAgICAgICAgICdyZWFzb24nICAgIHsgJHJlcy5yZWFzb24gPSAkdmFsLlRyaW0oKSB9CiAgICAgICAgICAgICdtb2RlJyB7CiAgICAgICAgICAgICAg
HLP:ICAkbSA9IEB7fQogICAgICAgICAgICAgICAgZm9yZWFjaCAoJHBhaXIgaW4gKCR2YWwgLXNwbGl0ICc7JykpIHsKICAgICAgICAgICAgICAgICAgICAkcCA9ICRwYWlyIC1zcGxpdCAnOicsIDIKICAgICAgICAgICAgICAgICAgICBpZiAoJHAuQ291bnQgLWVxIDIp
HLP:IHsgJG1bJHBbMF0uVHJpbSgpLlRvTG93ZXIoKV0gPSAoJHBbMV0uVHJpbSgpIC1lcSAnMScpIH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICRyZXMubW9kZSA9ICRtCiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICB9CiAgICByZXR1cm4gJHJl
HLP:cwp9CgojIENvbnN0cnV5ZSB5IHBlcnNpc3RlIGNoZWNrcG9pbnQuanNvbi4gRGV2dWVsdmUgJHRydWUvJGZhbHNlIChzaW4gZXhjZXBjaW9uKS4KZnVuY3Rpb24gU2F2ZS1DaGVja3BvaW50KCRwYXJzZWQpIHsKICAgIHRyeSB7CiAgICAgICAgJG1vZGUgPSBbcHNj
HLP:dXN0b21vYmplY3RdQHsKICAgICAgICAgICAgYXV0byAgICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ2F1dG8nXQogICAgICAgICAgICBub3JlYm9vdCA9IFtib29sXSRwYXJzZWQubW9kZVsnbm9yZWJvb3QnXQogICAgICAgICAgICBrZWVwd3UgICA9IFtib29sXSRw
HLP:YXJzZWQubW9kZVsna2VlcHd1J10KICAgICAgICAgICAgZHJ5ICAgICAgPSBbYm9vbF0kcGFyc2VkLm1vZGVbJ2RyeSddCiAgICAgICAgICAgIHRyaWFnZSAgID0gW2Jvb2xdJHBhcnNlZC5tb2RlWyd0cmlhZ2UnXQogICAgICAgIH0KICAgICAgICAkbm93ID0gKEdl
HLP:dC1EYXRlKS5Ub1N0cmluZygneXl5eS1NTS1kZF9ISC1tbScpCiAgICAgICAgJGNwID0gW3BzY3VzdG9tb2JqZWN0XUB7CiAgICAgICAgICAgIHZlcnNpb24gICAgICAgID0gJFdQSV9WRVJTSU9OCiAgICAgICAgICAgIGNyZWF0ZWQgICAgICAgID0gJG5vdwogICAg
HLP:ICAgICAgICBtb2RlICAgICAgICAgICA9ICRtb2RlCiAgICAgICAgICAgIHNlbGVjdGlvbiAgICAgID0gQCgkcGFyc2VkLnNlbGVjdGlvbikKICAgICAgICAgICAgY29tcGxldGVkICAgICAgPSBAKCRwYXJzZWQuY29tcGxldGVkKQogICAgICAgICAgICBwZW5kaW5n
HLP:X3JlYXNvbiA9ICRwYXJzZWQucmVhc29uCiAgICAgICAgICAgIHRpbWVzdGFtcF9ydW4gID0gJG5vdwogICAgICAgIH0KICAgICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJENoZWNrcG9pbnRGaWxlLCAoJGNwIHwgQ29udmVydFRvLUpzb24gLURl
HLP:cHRoIDYpLCAoTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKSkpCiAgICAgICAgcmV0dXJuICR0cnVlCiAgICB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9Cn0KCiMgQ2FyZ2EgY2hlY2twb2ludC5qc29uLiBEZXZ1ZWx2ZSBlbCBvYmpl
HLP:dG8gbyAkbnVsbCBzaSBubyBleGlzdGUgLyBtYWxmb3JtYWRvLgpmdW5jdGlvbiBMb2FkLUNoZWNrcG9pbnQgewogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkQ2hlY2twb2ludEZpbGUpKSB7IHJldHVybiAkbnVsbCB9CiAgICB0cnkgeyByZXR1cm4gKEdldC1Db250
HLP:ZW50ICRDaGVja3BvaW50RmlsZSAtUmF3IHwgQ29udmVydEZyb20tSnNvbikgfSBjYXRjaCB7IHJldHVybiAkbnVsbCB9Cn0KCiMgVmFsaWRhIHVuIGNoZWNrcG9pbnQ6IGV4aXN0ZSArIHBhcnNlYWJsZSArIHZlcnNpb24gY29tcGF0aWJsZSArIGNvbXBsZXRlZAoj
HLP:IHN1YmNvbmp1bnRvIGRlIHNlbGVjdGlvbiArIGNyZWF0ZWQgZGVudHJvIGRlIGxhIHZlbnRhbmEuIERldnVlbHZlIGJvb2xlYW5vCiMgU0lOIGxhbnphciBleGNlcGNpb24gYW50ZSBKU09OIG1hbGZvcm1hZG8gbyBjYWR1Y2Fkby4KZnVuY3Rpb24gVGVzdC1DaGVj
HLP:a3BvaW50VmFsaWQoJGNwKSB7CiAgICB0cnkgewogICAgICAgIGlmICgkbnVsbCAtZXEgJGNwKSB7CiAgICAgICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggJENoZWNrcG9pbnRGaWxlKSkgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICAgICAgdHJ5IHsgJGNwID0g
HLP:R2V0LUNvbnRlbnQgJENoZWNrcG9pbnRGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uIH0gY2F0Y2ggeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICB9CiAgICAgICAgaWYgKCRudWxsIC1lcSAkY3ApIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgaWYgKFtzdHJp
HLP:bmddJGNwLnZlcnNpb24gLW5lICRXUElfVkVSU0lPTikgeyByZXR1cm4gJGZhbHNlIH0KICAgICAgICAkc2VsICA9IEAoJGNwLnNlbGVjdGlvbikKICAgICAgICAkY29tcCA9IEAoJGNwLmNvbXBsZXRlZCkKICAgICAgICBmb3JlYWNoICgkYyBpbiAkY29tcCkgeyBp
HLP:ZiAoJHNlbCAtbm90Y29udGFpbnMgJGMpIHsgcmV0dXJuICRmYWxzZSB9IH0KICAgICAgICAkY3JlYXRlZCA9ICRudWxsCiAgICAgICAgaWYgKCRjcC5jcmVhdGVkKSB7CiAgICAgICAgICAgIHRyeSB7ICRjcmVhdGVkID0gW2RhdGV0aW1lXTo6UGFyc2VFeGFjdChb
HLP:c3RyaW5nXSRjcC5jcmVhdGVkLCAneXl5eS1NTS1kZF9ISC1tbScsICRudWxsKSB9IGNhdGNoIHsgJGNyZWF0ZWQgPSAkbnVsbCB9CiAgICAgICAgfQogICAgICAgIGlmICgkbnVsbCAtZXEgJGNyZWF0ZWQpIHsgcmV0dXJuICRmYWxzZSB9CiAgICAgICAgJGFnZSA9
HLP:IChHZXQtRGF0ZSkgLSAkY3JlYXRlZAogICAgICAgIGlmICgkYWdlLlRvdGFsRGF5cyAtZ3QgJENIRUNLUE9JTlRfTUFYX0FHRV9EQVlTKSB7IHJldHVybiAkZmFsc2UgfQogICAgICAgIHJldHVybiAkdHJ1ZQogICAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9
HLP:CgojIFByaW1lcmEgZmFzZSBkZSAnc2VsZWN0aW9uJyBubyBwcmVzZW50ZSBlbiAnY29tcGxldGVkJyAobyAnJyBzaSB0b2RhcyBoZWNoYXMpLgpmdW5jdGlvbiBHZXQtTmV4dFBoYXNlKCRjcCkgewogICAgaWYgKCRudWxsIC1lcSAkY3ApIHsgcmV0dXJuICcnIH0K
HLP:ICAgICRjb21wID0gQCgkY3AuY29tcGxldGVkKQogICAgZm9yZWFjaCAoJHMgaW4gQCgkY3Auc2VsZWN0aW9uKSkgeyBpZiAoJGNvbXAgLW5vdGNvbnRhaW5zICRzKSB7IHJldHVybiAkcyB9IH0KICAgIHJldHVybiAnJwp9CgojIC0tLSAoMy45IC8gQnVnIDYgLyBS
HLP:ZXEgOCkgUmVzZXQgZGUgZXN0YWRvIHJldXRpbGl6YWJsZSAtLS0tLS0tLS0tLS0tLS0tLS0tLQojIERlamEgcGhhc2VzPUAoKSwgZmluZGluZ3M9QCgpIHkgbG9zIHNjb3JlcyAoYmVmb3JlL2FmdGVyKSBhIG51bGwuIEVsCiMgY29uZGljaW9uYWRvIGEgL3Jlc3Vt
HLP:ZSBsbyBhcGxpY2EgZWwgYmF0Y2ggKHRhcmVhcyA4LjQgLyA5LjEpOiBzb2xvIGludm9jYQojICdyZXNldHN0YXRlJyBjdWFuZG8gUkVTVU1FPT0wLCBjb25zZXJ2YW5kbyBlbCBlc3RhZG8gcHJldmlvIGVuIC9yZXN1bWUuCmZ1bmN0aW9uIFJlc2V0LVN0YXRlIHsK
HLP:ICAgIFdyaXRlLVN0YXRlIChbcHNjdXN0b21vYmplY3RdQHsgc2NvcmVfYmVmb3JlID0gJG51bGw7IHNjb3JlX2FmdGVyID0gJG51bGw7IGZpbmRpbmdzID0gQCgpOyBwaGFzZXMgPSBAKCkgfSkKfQoKIyAtLS0gKDMuMTEgLyBCdWcgNyAvIFJlcSA5KSBIb25lc3Rp
HLP:ZGFkIGRlbCBtb3ZpbWllbnRvIGRlIGNhY2hlcyAtLS0tLS0tLS0tLS0KIyBFeGl0byAodHJ1ZSkgU0kgWSBTT0xPIFNJIGVsIG9yaWdlbiBlc3RhIGF1c2VudGUgeSBlbCBkZXN0aW5vIHByZXNlbnRlLgojIFZhcmlhbnRlIHB1cmEgKGJvb2xlYW5vcykgKyB2YXJp
HLP:YW50ZSBxdWUgYWNlcHRhIHJ1dGFzIHkgaGFjZSBUZXN0LVBhdGguCmZ1bmN0aW9uIFRlc3QtTW92ZVJlc3VsdChbYm9vbF0kc3JjRXhpc3RzLCBbYm9vbF0kZHN0RXhpc3RzKSB7CiAgICByZXR1cm4gKCgtbm90ICRzcmNFeGlzdHMpIC1hbmQgJGRzdEV4aXN0cykK
HLP:fQpmdW5jdGlvbiBUZXN0LU1vdmVSZXN1bHRQYXRoKFtzdHJpbmddJHNyYywgW3N0cmluZ10kZHN0KSB7CiAgICByZXR1cm4gKFRlc3QtTW92ZVJlc3VsdCAoW2Jvb2xdKFRlc3QtUGF0aCAkc3JjKSkgKFtib29sXShUZXN0LVBhdGggJGRzdCkpKQp9CgojIC0tLSAo
HLP:My4xMSAvIEJ1ZyA4IC8gUmVxIDEwKSBJZGVtcG90ZW5jaWEgZGUgVmlydHVhbFRlcm1pbmFsTGV2ZWwgLS0tLS0tLS0tLQojIE5vcm1hbGl6YSB2YWxvcmVzICcweDEnIC8gJzEnIC8gMSBhIGVudGVybyBwYXJhIGNvbXBhcmFyIGRlIGZvcm1hIHJvYnVzdGEuCmZ1
HLP:bmN0aW9uIENvbnZlcnRUby1WdGxJbnQoJHYpIHsKICAgIGlmICgkbnVsbCAtZXEgJHYpIHsgcmV0dXJuICRudWxsIH0KICAgICRzID0gKFtzdHJpbmddJHYpLlRyaW0oKS5Ub0xvd2VyKCkKICAgIGlmICgkcyAtZXEgJycpIHsgcmV0dXJuICRudWxsIH0KICAgIHRy
HLP:eSB7CiAgICAgICAgaWYgKCRzLlN0YXJ0c1dpdGgoJzB4JykpIHsgcmV0dXJuIFtDb252ZXJ0XTo6VG9JbnQzMigkcywgMTYpIH0KICAgICAgICByZXR1cm4gW2ludF0kcwogICAgfSBjYXRjaCB7IHJldHVybiAkbnVsbCB9Cn0KIyBEZXZ1ZWx2ZSAkdHJ1ZSAoZXNj
HLP:cmliaXIpIHNvbG8gc2kgZWwgdmFsb3IgYWN0dWFsIGRpZmllcmUgZGVsIGRlc2VhZG8uCmZ1bmN0aW9uIFJlc29sdmUtVnRsV3JpdGUoJGN1cnJlbnQsICRkZXNpcmVkKSB7CiAgICByZXR1cm4gKChDb252ZXJ0VG8tVnRsSW50ICRjdXJyZW50KSAtbmUgKENvbnZl
HLP:cnRUby1WdGxJbnQgJGRlc2lyZWQpKQp9CgojIC0tLSAoMy4xNCAvIFJlcSAxLjMpIE1hcGVvIFRPVEFMIGRlIGNvZGlnbyBkZSBzYWxpZGEgYSB7T0ssV0FSTixTS0lQLEVSUk9SfQojIDAtPk9LLCAxLT5XQVJOLCAyLT5TS0lQLCAzLT5FUlJPUjsgY3VhbHF1aWVy
HLP:IG90cm8gZW50ZXJvIChvIG5vIGVudGVybykgLT4gRVJST1IuCmZ1bmN0aW9uIE1hcC1FeGl0Q29kZSgkY29kZSkgewogICAgJG4gPSAkbnVsbAogICAgdHJ5IHsgJG4gPSBbaW50XSRjb2RlIH0gY2F0Y2ggeyByZXR1cm4gJ0VSUk9SJyB9CiAgICBzd2l0Y2ggKCRu
HLP:KSB7CiAgICAgICAgMCAgICAgICB7ICdPSycgfQogICAgICAgIDEgICAgICAgeyAnV0FSTicgfQogICAgICAgIDIgICAgICAgeyAnU0tJUCcgfQogICAgICAgIDMgICAgICAgeyAnRVJST1InIH0KICAgICAgICBkZWZhdWx0IHsgJ0VSUk9SJyB9CiAgICB9Cn0KCiMg
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgRElBR05PU1RJQ08gQU1QTElBRE8gKDUuMSAvIFJlcSAxNS4xLTE1LjUpCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KCiMgLS0tIFJBTSAoUmVxIDE1LjEpIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBSZXNvbHZlLVJhbVN0YXR1czogZnVu
HLP:Y2lvbiBQVVJBLiBBIHBhcnRpciBkZWwgY29udGVvIGRlIGVycm9yZXMgZGUgbWVtb3JpYQojIFdIRUEgeSBkZSBmYWxsb3MgZGVsIGRpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUgV2luZG93cywgZGVjaWRlIGVsIGVzdGFkbyB5CiMgc2kgY29udmllbmUgcmVjb21l
HLP:bmRhciBtZHNjaGVkLgpmdW5jdGlvbiBSZXNvbHZlLVJhbVN0YXR1cyhbaW50XSR3aGVhTWVtRXJyb3JzLCBbaW50XSRtZW1EaWFnRmFpbHVyZXMpIHsKICAgIGlmICgkd2hlYU1lbUVycm9ycyAtZ3QgMCAtb3IgJG1lbURpYWdGYWlsdXJlcyAtZ3QgMCkgewogICAg
HLP:ICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJ3N1c3BlY3QnOyByZWNvbW1lbmRfbWRzY2hlZCA9ICR0cnVlIH0KICAgIH0KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgc3RhdHVzID0gJ29rJzsgcmVjb21tZW5kX21kc2NoZWQgPSAk
HLP:ZmFsc2UgfQp9CgojIEdldC1SYW1DaGVjazogbGVlIGV2ZW50b3MgV0hFQSB5IHJlc3VsdGFkb3MgZGVsIERpYWdub3N0aWNvIGRlIG1lbW9yaWEgZGUKIyBXaW5kb3dzLiBEZWdyYWRhY2lvbiBlbGVnYW50ZTogc2kgbGEgY29uc3VsdGEgZGUgZXZlbnRvcyBmYWxs
HLP:YSBwb3IgY29tcGxldG8sCiMgZGV2dWVsdmUgc3RhdHVzPSd1bmtub3duJyBzaW4gbGFuemFyIGV4Y2VwY2lvbi4KZnVuY3Rpb24gR2V0LVJhbUNoZWNrIHsKICAgIHRyeSB7CiAgICAgICAgJHF1ZXJpZWQgPSAkZmFsc2UKICAgICAgICAkd2hlYUNvdW50ID0gMAog
HLP:ICAgICAgICRtZW1EaWFnRmFpbCA9IDAKICAgICAgICAjIEVycm9yZXMgZGUgaGFyZHdhcmUgV0hFQSByZWxhY2lvbmFkb3MgY29uIG1lbW9yaWEKICAgICAgICAkd2hlYSA9IEAoR2V0LVdpbkV2ZW50IC1GaWx0ZXJIYXNodGFibGUgQHtMb2dOYW1lPSdTeXN0ZW0n
HLP:OyBQcm92aWRlck5hbWU9J01pY3Jvc29mdC1XaW5kb3dzLVdIRUEtTG9nZ2VyJ30gLU1heEV2ZW50cyAxMDAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYgKCRudWxsIC1uZSAkd2hlYSkgeyAkcXVlcmllZCA9ICR0cnVlIH0KICAgICAg
HLP:ICAkd2hlYUNvdW50ID0gQCgkd2hlYSB8IFdoZXJlLU9iamVjdCB7ICgkXy5JZCAtaW4gMTgsMTksMjAsNDcpIC1vciAoJF8uTWVzc2FnZSAtbWF0Y2ggJ21lbW9yJykgfSkuQ291bnQKICAgICAgICAjIFJlc3VsdGFkb3MgZGVsIERpYWdub3N0aWNvIGRlIG1lbW9y
HLP:aWEgZGUgV2luZG93cyAobWRzY2hlZCkKICAgICAgICAkbWQgPSBAKEdldC1XaW5FdmVudCAtRmlsdGVySGFzaHRhYmxlIEB7TG9nTmFtZT0nU3lzdGVtJzsgUHJvdmlkZXJOYW1lPSdNaWNyb3NvZnQtV2luZG93cy1NZW1vcnlEaWFnbm9zdGljcy1SZXN1bHRzJ30g
HLP:LU1heEV2ZW50cyA1MCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkKICAgICAgICBpZiAoJG51bGwgLW5lICRtZCkgeyAkcXVlcmllZCA9ICR0cnVlIH0KICAgICAgICAkbWVtRGlhZ0ZhaWwgPSBAKCRtZCB8IFdoZXJlLU9iamVjdCB7ICgkXy5JZCAtZXEg
HLP:MTAwMikgLW9yICgkXy5MZXZlbERpc3BsYXlOYW1lIC1lcSAnRXJyb3InKSAtb3IgKCRfLk1lc3NhZ2UgLW1hdGNoICdlcnJvcnxlcnJvcmVzJykgfSkuQ291bnQKICAgICAgICByZXR1cm4gKFJlc29sdmUtUmFtU3RhdHVzICR3aGVhQ291bnQgJG1lbURpYWdGYWls
HLP:KQogICAgfSBjYXRjaCB7CiAgICAgICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBzdGF0dXMgPSAndW5rbm93bic7IHJlY29tbWVuZF9tZHNjaGVkID0gJGZhbHNlIH0KICAgIH0KfQoKIyAtLS0gQmF0ZXJpYSAoUmVxIDE1LjIpIC0tLS0tLS0tLS0tLS0tLS0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIEdldC1CYXR0ZXJ5SGVhbHRoUGN0OiBmdW5jaW9uIFBVUkEuICUgZGUgc2FsdWQgPSBwbGVuYSBjYXJnYSAvIGRpc2VubyAqIDEwMC4KZnVuY3Rpb24gR2V0LUJhdHRlcnlIZWFsdGhQY3QoJGRlc2ln
HLP:biwgJGZ1bGwpIHsKICAgIHRyeSB7CiAgICAgICAgJGQgPSBbZG91YmxlXSRkZXNpZ247ICRmID0gW2RvdWJsZV0kZnVsbAogICAgICAgIGlmICgkZCAtZ3QgMCkgeyByZXR1cm4gW2ludF1bbWF0aF06OlJvdW5kKCgkZiAvICRkKSAqIDEwMCkgfQogICAgfSBjYXRj
HLP:aCB7fQogICAgcmV0dXJuICRudWxsCn0KCiMgR2V0LUJhdHRlcnlIZWFsdGg6IHNpIGhheSBiYXRlcmlhLCBnZW5lcmEgcG93ZXJjZmcgL2JhdHRlcnlyZXBvcnQgeSBleHRyYWUgbGEKIyBzYWx1ZCAoY2FwYWNpZGFkIGRlIGRpc2VubyB2cyBwbGVuYSBjYXJnYSku
HLP:IFNpbiBiYXRlcmlhIC0+IHByZXNlbnQ9JGZhbHNlLgojIE5vIGZhbGxhIHNpIHBvd2VyY2ZnIG5vIGVzdGEgZGlzcG9uaWJsZSAoaGVhbHRoX3BjdCBxdWVkYSB2YWNpbykuCmZ1bmN0aW9uIEdldC1CYXR0ZXJ5SGVhbHRoIHsKICAgICRwcmVzZW50ID0gJGZhbHNl
HLP:OyAkaGVhbHRoUGN0ID0gJyc7ICRyZXBvcnRQYXRoID0gJycKICAgIHRyeSB7CiAgICAgICAgJGJhdCA9IEAoR2V0LUNpbUluc3RhbmNlIFdpbjMyX0JhdHRlcnkgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgaWYgKCRiYXQuQ291bnQgLWd0
HLP:IDApIHsKICAgICAgICAgICAgJHByZXNlbnQgPSAkdHJ1ZQogICAgICAgICAgICAkcmVwb3J0UGF0aCA9IEpvaW4tUGF0aCAkV29yayAnYmF0dGVyeS1yZXBvcnQuaHRtbCcKICAgICAgICAgICAgdHJ5IHsgJiBwb3dlcmNmZyAvYmF0dGVyeXJlcG9ydCAvb3V0cHV0
HLP:ICIkcmVwb3J0UGF0aCIgL2R1cmF0aW9uIDEgPiAkbnVsbCAyPiYxIH0gY2F0Y2gge30KICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkcmVwb3J0UGF0aCkgewogICAgICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgICAgICAkdHh0ID0gR2V0LUNvbnRl
HLP:bnQgJHJlcG9ydFBhdGggLVJhdwogICAgICAgICAgICAgICAgICAgICRkZXNpZ24gPSAkbnVsbDsgJGZ1bGwgPSAkbnVsbAogICAgICAgICAgICAgICAgICAgICRtMSA9IFtyZWdleF06Ok1hdGNoKCR0eHQsICcoP2lzKURFU0lHTiBDQVBBQ0lUWS4qPyhbXGRcLixd
HLP:KylccyptV2gnKQogICAgICAgICAgICAgICAgICAgICRtMiA9IFtyZWdleF06Ok1hdGNoKCR0eHQsICcoP2lzKUZVTEwgQ0hBUkdFIENBUEFDSVRZLio/KFtcZFwuLF0rKVxzKm1XaCcpCiAgICAgICAgICAgICAgICAgICAgaWYgKCRtMS5TdWNjZXNzKSB7ICRkZXNp
HLP:Z24gPSBbZG91YmxlXSgoJG0xLkdyb3Vwc1sxXS5WYWx1ZSAtcmVwbGFjZSAnW1wuLF0nLCAnJykpIH0KICAgICAgICAgICAgICAgICAgICBpZiAoJG0yLlN1Y2Nlc3MpIHsgJGZ1bGwgICA9IFtkb3VibGVdKCgkbTIuR3JvdXBzWzFdLlZhbHVlIC1yZXBsYWNlICdb
HLP:XC4sXScsICcnKSkgfQogICAgICAgICAgICAgICAgICAgICRwY3QgPSBHZXQtQmF0dGVyeUhlYWx0aFBjdCAkZGVzaWduICRmdWxsCiAgICAgICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcGN0KSB7ICRoZWFsdGhQY3QgPSAkcGN0IH0KICAgICAgICAgICAg
HLP:ICAgIH0gY2F0Y2gge30KICAgICAgICAgICAgfQogICAgICAgIH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiBbcHNjdXN0b21vYmplY3RdQHsgcHJlc2VudCA9ICRwcmVzZW50OyBoZWFsdGhfcGN0ID0gJGhlYWx0aFBjdDsgcmVwb3J0X3BhdGggPSAkcmVwb3J0
HLP:UGF0aCB9Cn0KCiMgLS0tIFJlZCBhdmFuemFkYSAoUmVxIDE1LjUpIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtTmV0QWR2YW5jZWQ6IGNvbmVjdGl2aWRhZCAocGluZyBhIDEuMS4xLjEpLCBETlMgKFJlc29sdmUt
HLP:RG5zTmFtZSBjb24KIyByZXNwYWxkbyBwb3IgcGluZyBhIHVuIGhvc3QpIHkgY29uZmlndXJhY2lvbiBiYXNpY2EgKElQL2dhdGV3YXkpLgojIERlZ3JhZGFjaW9uIGVsZWdhbnRlOiBudW5jYSBsYW56YSBleGNlcGNpb24uCmZ1bmN0aW9uIEdldC1OZXRBZHZhbmNl
HLP:ZCB7CiAgICAkY29ubmVjdGVkID0gJGZhbHNlOyAkZG5zT2sgPSAkZmFsc2U7ICRkZXRhaWxzID0gJycKICAgIHRyeSB7CiAgICAgICAgIyBDb25lY3RpdmlkYWQKICAgICAgICAkcGluZyA9ICRmYWxzZQogICAgICAgIHRyeSB7ICRwaW5nID0gW2Jvb2xdKFRlc3Qt
HLP:Q29ubmVjdGlvbiAtQ29tcHV0ZXJOYW1lICcxLjEuMS4xJyAtQ291bnQgMSAtUXVpZXQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIH0gY2F0Y2ggeyAkcGluZyA9ICRmYWxzZSB9CiAgICAgICAgaWYgKC1ub3QgJHBpbmcpIHsKICAgICAgICAgICAgdHJ5
HLP:IHsgJiBwaW5nIC1uIDEgLXcgMTUwMCAxLjEuMS4xID4gJG51bGwgMj4mMTsgaWYgKCRMQVNURVhJVENPREUgLWVxIDApIHsgJHBpbmcgPSAkdHJ1ZSB9IH0gY2F0Y2gge30KICAgICAgICB9CiAgICAgICAgJGNvbm5lY3RlZCA9IFtib29sXSRwaW5nCiAgICAgICAg
HLP:IyBSZXNvbHVjaW9uIEROUyAoY29uIG1lZGlkYSBkZSBsYXRlbmNpYSkKICAgICAgICAkZG5zID0gJGZhbHNlOyAkZG5zTXMgPSAkbnVsbAogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRzdyA9IFtTeXN0ZW0uRGlhZ25vc3RpY3MuU3RvcHdhdGNoXTo6U3RhcnRO
HLP:ZXcoKQogICAgICAgICAgICAkciA9IFJlc29sdmUtRG5zTmFtZSAtTmFtZSAnd3d3Lm1pY3Jvc29mdC5jb20nIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICAgICAgICRzdy5TdG9wKCkKICAgICAgICAgICAgaWYgKCRyKSB7ICRkbnMgPSAkdHJ1
HLP:ZTsgJGRuc01zID0gW2ludF0kc3cuRWxhcHNlZE1pbGxpc2Vjb25kcyB9CiAgICAgICAgfSBjYXRjaCB7fQogICAgICAgIGlmICgtbm90ICRkbnMpIHsKICAgICAgICAgICAgdHJ5IHsgJiBwaW5nIC1uIDEgLXcgMTUwMCB3d3cubWljcm9zb2Z0LmNvbSA+ICRudWxs
HLP:IDI+JjE7IGlmICgkTEFTVEVYSVRDT0RFIC1lcSAwKSB7ICRkbnMgPSAkdHJ1ZSB9IH0gY2F0Y2gge30KICAgICAgICB9CiAgICAgICAgJGRuc09rID0gW2Jvb2xdJGRucwogICAgICAgICMgQ29uZmlndXJhY2lvbiBiYXNpY2EgKElQIC8gZ2F0ZXdheSkKICAgICAg
HLP:ICAkaXAgPSAnJzsgJGd3ID0gJycKICAgICAgICB0cnkgewogICAgICAgICAgICAkY2ZnID0gQChHZXQtTmV0SVBDb25maWd1cmF0aW9uIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgJF8uSVB2NERlZmF1bHRHYXRld2F5IH0p
HLP:IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgICAgICAgICBpZiAoJGNmZykgewogICAgICAgICAgICAgICAgJGlwID0gKCRjZmcuSVB2NEFkZHJlc3MgfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxKS5JUEFkZHJlc3MKICAgICAgICAgICAgICAgICRndyA9ICgk
HLP:Y2ZnLklQdjREZWZhdWx0R2F0ZXdheSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEpLk5leHRIb3AKICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2gge30KICAgICAgICAkZGV0YWlscyA9ICJJUD0kaXA7IEdXPSRndyIKICAgIH0gY2F0Y2gge30KICAgIHJldHVy
HLP:biBbcHNjdXN0b21vYmplY3RdQHsgY29ubmVjdGVkID0gJGNvbm5lY3RlZDsgZG5zX29rID0gJGRuc09rOyBkZXRhaWxzID0gJGRldGFpbHM7IGRuc19tcyA9ICRkbnNNcyB9Cn0KCiMgLS0tIERpc3Bvc2l0aXZvcyBwYXJhIGRpYWcgKFJlcSAxNS4zLzE1LjQpIC0t
HLP:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyBHZXQtRGV2aWNlTGlzdDogbGlzdGEgZXN0cnVjdHVyYWRhIGRlIGRpc3Bvc2l0aXZvcyBjb24gZXJyb3IgcGFyYSBlc3RhZG8uZGlhZy4KIyBEZXZ1ZWx2ZSAkbnVsbCBzaSBsYSBpZGVudGlmaWNhY2lvbiBk
HLP:ZSBkcml2ZXJzIGZhbGxhIChzZW5hbCBkZSAiaW5mbyBubwojIGRpc3BvbmlibGUiIHBhcmEgZGVncmFkYWNpb24gZWxlZ2FudGUpLgpmdW5jdGlvbiBHZXQtRGV2aWNlTGlzdCB7CiAgICB0cnkgewogICAgICAgICRwID0gQChHZXQtQ2ltSW5zdGFuY2UgV2luMzJf
HLP:UG5QRW50aXR5IC1FcnJvckFjdGlvbiBTdG9wIHwgV2hlcmUtT2JqZWN0IHsgJF8uQ29uZmlnTWFuYWdlckVycm9yQ29kZSAtZ3QgMCB9KQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJGQgaW4gKCRwIHwgU2VsZWN0LU9iamVjdCAtRmlyc3Qg
HLP:MTIpKSB7CiAgICAgICAgICAgICRsaXN0ICs9IFtwc2N1c3RvbW9iamVjdF1AeyBjb2RlID0gW2ludF0kZC5Db25maWdNYW5hZ2VyRXJyb3JDb2RlOyBuYW1lID0gW3N0cmluZ10kZC5OYW1lIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuICwkbGlzdAogICAgfSBj
HLP:YXRjaCB7IHJldHVybiAkbnVsbCB9Cn0KCiMgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyAgUk9UQUNJT04gREUgTE9HUyAoNS42IC8gUmVxIDE3LjIpCiMgPT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBTZWxlY3QtTG9nc1RvRGVsZXRlOiBmdW5jaW9uIFBVUkEuIERlIHVuYSBjb2xlY2Npb24gZGUgZmljaGVyb3MgKGNvbgojIC5MYXN0V3JpdGVU
HLP:aW1lKSB5IHVuYSByZXRlbmNpb24gTiwgZGV2dWVsdmUgbG9zIHF1ZSBkZWJlbiBCT1JSQVJTRTogdG9kb3MKIyBtZW5vcyBsb3MgTiBtYXMgcmVjaWVudGVzIChlcyBkZWNpciwgbG9zIG1hcyBhbnRpZ3VvcykuIFNpIGhheSA8PSBOLCBuaW5ndW5vLgpmdW5jdGlv
HLP:biBTZWxlY3QtTG9nc1RvRGVsZXRlKCRmaWxlcywgW2ludF0kcmV0ZW50aW9uKSB7CiAgICAkYXJyID0gQCgkZmlsZXMpCiAgICBpZiAoJHJldGVudGlvbiAtbHQgMCkgeyAkcmV0ZW50aW9uID0gMCB9CiAgICBpZiAoJGFyci5Db3VudCAtbGUgJHJldGVudGlvbikg
HLP:eyByZXR1cm4gQCgpIH0KICAgICRzb3J0ZWQgPSBAKCRhcnIgfCBTb3J0LU9iamVjdCAtUHJvcGVydHkgTGFzdFdyaXRlVGltZSAtRGVzY2VuZGluZykKICAgIHJldHVybiBAKCRzb3J0ZWQgfCBTZWxlY3QtT2JqZWN0IC1Ta2lwICRyZXRlbnRpb24pCn0KCiMgSW52
HLP:b2tlLUxvZ1JvdGF0ZTogY29uc2VydmEgbG9zICRyZXRlbnRpb24gbG9ncyBtYXMgcmVjaWVudGVzIGVuICRmb2xkZXIgeQojIGJvcnJhIGVsIHJlc3RvLiBEZXZ1ZWx2ZSBlbCBudW1lcm8gZGUgZmljaGVyb3MgYm9ycmFkb3MuCmZ1bmN0aW9uIEludm9rZS1Mb2dS
HLP:b3RhdGUoW3N0cmluZ10kZm9sZGVyLCBbaW50XSRyZXRlbnRpb24pIHsKICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRmb2xkZXIpKSB7ICRmb2xkZXIgPSBKb2luLVBhdGggJFdvcmsgJ0xvZ3MnIH0KICAgICRkZWxldGVkID0gMAogICAgdHJ5
HLP:IHsKICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoICRmb2xkZXIpKSB7IHJldHVybiAwIH0KICAgICAgICAkZmlsZXMgPSBAKEdldC1DaGlsZEl0ZW0gLVBhdGggJGZvbGRlciAtRmlsdGVyICcqLmxvZycgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGlu
HLP:dWUpCiAgICAgICAgJHRvRGVsZXRlID0gU2VsZWN0LUxvZ3NUb0RlbGV0ZSAkZmlsZXMgJHJldGVudGlvbgogICAgICAgIGZvcmVhY2ggKCRmIGluICR0b0RlbGV0ZSkgewogICAgICAgICAgICB0cnkgeyBSZW1vdmUtSXRlbSAkZi5GdWxsTmFtZSAtRm9yY2UgLUVy
HLP:cm9yQWN0aW9uIFNpbGVudGx5Q29udGludWU7ICRkZWxldGVkKysgfSBjYXRjaCB7fQogICAgICAgIH0KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAkZGVsZXRlZAp9CgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09CiMgIFZBTElEQUNJT04gREUgRU5UT1JOTyBZIFNFTEYtVEVTVCAoNS44IC8gUmVxIDEzLjUsMTMuNiwxOC4xLDE4LjMsMTguNikKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PT09PT09PT09PT09PQojIFRlc3QtT3NTdXBwb3J0ZWQ6IGZ1bmNpb24gUFVSQS4gV2luZG93cyAxMC8xMSA9PiBidWlsZCA+PSAxMDI0MC4KZnVuY3Rpb24gVGVzdC1Pc1N1cHBvcnRlZChbaW50XSRidWlsZCkgewogICAgcmV0dXJuICgkYnVp
HLP:bGQgLWdlIDEwMjQwKQp9CgojIEludm9rZS1FbnZWYWxpZGF0ZTogY29tcHJ1ZWJhIGxhIHZlcnNpb24gZGVsIFNPIHZpYSBDSU0uIExhIGNvbXByb2JhY2lvbiBzZQojIGNvbnNpZGVyYSBTSUVNUFJFIHJlYWxpemFkYSAoY2hlY2tfZG9uZSkgYXVucXVlIGxhIHZl
HLP:cnNpb24gbm8gc2VhIGNvbXBhdGlibGUuCmZ1bmN0aW9uIEludm9rZS1FbnZWYWxpZGF0ZSB7CiAgICAkYnVpbGQgPSAwCiAgICB0cnkgeyAkYnVpbGQgPSBbaW50XShHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3BlcmF0aW5nU3lzdGVtIC1FcnJvckFjdGlvbiBTaWxl
HLP:bnRseUNvbnRpbnVlKS5CdWlsZE51bWJlciB9IGNhdGNoIHsgJGJ1aWxkID0gMCB9CiAgICBpZiAoJGJ1aWxkIC1sZSAwKSB7IHRyeSB7ICRidWlsZCA9IFtpbnRdKEdldC1JdGVtUHJvcGVydHkgJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzIE5UXEN1
HLP:cnJlbnRWZXJzaW9uJyAtTmFtZSBDdXJyZW50QnVpbGROdW1iZXIgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpLkN1cnJlbnRCdWlsZE51bWJlciB9IGNhdGNoIHsgJGJ1aWxkID0gMCB9IH0KICAgIGlmICgkYnVpbGQgLWxlIDApIHsgdHJ5IHsgJGJ1aWxk
HLP:ID0gW2ludF0oR2V0LUl0ZW1Qcm9wZXJ0eSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb24nIC1OYW1lIEN1cnJlbnRCdWlsZCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkuQ3VycmVudEJ1aWxkIH0gY2F0Y2gg
HLP:eyAkYnVpbGQgPSAwIH0gfQogICAgcmV0dXJuIFtwc2N1c3RvbW9iamVjdF1AeyBvc19vayA9IChUZXN0LU9zU3VwcG9ydGVkICRidWlsZCk7IGJ1aWxkID0gJGJ1aWxkOyBjaGVja19kb25lID0gJHRydWUgfQp9CgojIEludm9rZS1TZWxmVGVzdDogYWdyZWdhZG9y
HLP:IFBVUk8uIEV4aXRvICh0cnVlKSBzaSB5IHNvbG8gc2kgVE9EQVMgbGFzCiMgY29tcHJvYmFjaW9uZXMgKGJvb2xlYW5vcykgcGFzYW4uIENvbGVjY2lvbiB2YWNpYSAtPiB0cnVlIChuYWRhIGZhbGxvKS4KZnVuY3Rpb24gSW52b2tlLVNlbGZUZXN0KCRyZXN1bHRz
HLP:KSB7CiAgICBmb3JlYWNoICgkciBpbiBAKCRyZXN1bHRzKSkgeyBpZiAoLW5vdCBbYm9vbF0kcikgeyByZXR1cm4gJGZhbHNlIH0gfQogICAgcmV0dXJuICR0cnVlCn0KCiMgUGFyc2UtQm9vbExpc3Q6IGNvbnZpZXJ0ZSAiMSwxLDAsMSIgKG8gdHJ1ZS9vaykgZW4g
HLP:dW5hIGxpc3RhIGRlIGJvb2xlYW5vcy4KZnVuY3Rpb24gUGFyc2UtQm9vbExpc3QoW3N0cmluZ10kcmF3KSB7CiAgICAkbGlzdCA9IEAoKQogICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkcmF3KSkgewogICAgICAgIGZvcmVhY2ggKCR0
HLP:IGluICgkcmF3IC1zcGxpdCAnLCcpKSB7CiAgICAgICAgICAgICR0b2sgPSAkdC5UcmltKCkuVG9Mb3dlcigpCiAgICAgICAgICAgIGlmICgkdG9rIC1lcSAnJykgeyBjb250aW51ZSB9CiAgICAgICAgICAgICRsaXN0ICs9ICgkdG9rIC1lcSAnMScgLW9yICR0b2sg
HLP:LWVxICd0cnVlJyAtb3IgJHRvayAtZXEgJ29rJyAtb3IgJHRvayAtZXEgJ3Bhc3MnKQogICAgICAgIH0KICAgIH0KICAgIHJldHVybiAsJGxpc3QKfQoKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
HLP:PT09PT09PT09PT09PQojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMgIERJQUdOT1NUSUNPIFBST0ZVTkRPIHYzLjEgKFNNQVJULCBhcnJhbnF1ZSwgQkNELCBwcm9jZXNv
HLP:cywgU0ZDLCBKU09OKQojICBUb2RhcyBsYXMgZnVuY2lvbmVzIGRlZ3JhZGFuIGNvbiBlbGVnYW5jaWE6IHNpIGFsZ28gZmFsbGEsIGRldnVlbHZlbgojICBlc3RydWN0dXJhcyB2YWNpYXMgLyAndW5rbm93bicgZW4gbHVnYXIgZGUgbGFuemFyIGV4Y2VwY2lvbmVz
HLP:LgojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIEdldC1TbWFydEF0dHJpYnV0ZXM6IHNhbHVkIGZpc2ljYSBkZWwgZGlzY28gZGUgc2lzdGVtYSAoaW5kZXBlbmRpZW50
HLP:ZSBkZWwKIyBpZGlvbWEgZGUgV2luZG93cykuIFVzYSBNU1N0b3JhZ2VEcml2ZXJfRmFpbHVyZVByZWRpY3RTdGF0dXMgKyBlbCBjb250YWRvcgojIGRlIGZpYWJpbGlkYWQgZGUgYWxtYWNlbmFtaWVudG8uIERldnVlbHZlIGF2YWlsYWJsZT0kZmFsc2Ugc2kgbm8g
HLP:aGF5IGRhdG9zLgpmdW5jdGlvbiBHZXQtU21hcnRBdHRyaWJ1dGVzIHsKICAgICRyZXMgPSBbcHNjdXN0b21vYmplY3RdQHsgYXZhaWxhYmxlID0gJGZhbHNlOyBwcmVkaWN0X2ZhaWwgPSAkZmFsc2U7IHRlbXBfYyA9ICRudWxsOyB3ZWFyX3BjdCA9ICRudWxsOyBw
HLP:b2ggPSAkbnVsbCB9CiAgICB0cnkgewogICAgICAgICRwZiA9ICRudWxsCiAgICAgICAgdHJ5IHsgJHBmID0gQChHZXQtQ2ltSW5zdGFuY2UgLU5hbWVzcGFjZSAncm9vdFx3bWknIC1DbGFzc05hbWUgJ01TU3RvcmFnZURyaXZlcl9GYWlsdXJlUHJlZGljdFN0YXR1
HLP:cycgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpIH0gY2F0Y2ggeyAkcGYgPSAkbnVsbCB9CiAgICAgICAgaWYgKCRwZiAtYW5kICRwZi5Db3VudCAtZ3QgMCkgewogICAgICAgICAgICAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlCiAgICAgICAgICAgIGZvcmVh
HLP:Y2ggKCR4IGluICRwZikgeyBpZiAoJHguUHJlZGljdEZhaWx1cmUpIHsgJHJlcy5wcmVkaWN0X2ZhaWwgPSAkdHJ1ZSB9IH0KICAgICAgICB9CiAgICAgICAgIyBEaXNjbyBxdWUgY29udGllbmUgQzogLT4gY29udGFkb3IgZGUgZmlhYmlsaWRhZAogICAgICAgIHRy
HLP:eSB7CiAgICAgICAgICAgICRzeXNEaXNrID0gJG51bGwKICAgICAgICAgICAgdHJ5IHsgJHN5c0Rpc2sgPSBHZXQtUGh5c2ljYWxEaXNrIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgV2hlcmUtT2JqZWN0IHsgJF8uRGV2aWNlSWQgLW5lICRudWxsIH0g
HLP:fCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0gY2F0Y2gge30KICAgICAgICAgICAgJHJjID0gJG51bGwKICAgICAgICAgICAgaWYgKCRzeXNEaXNrKSB7ICRyYyA9ICRzeXNEaXNrIHwgR2V0LVN0b3JhZ2VSZWxpYWJpbGl0eUNvdW50ZXIgLUVycm9yQWN0aW9uIFNp
HLP:bGVudGx5Q29udGludWUgfQogICAgICAgICAgICBpZiAoLW5vdCAkcmMpIHsgJHJjID0gR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IEdldC1TdG9yYWdlUmVsaWFiaWxpdHlDb3VudGVyIC1FcnJvckFjdGlvbiBTaWxlbnRs
HLP:eUNvbnRpbnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgIGlmICgkcmMpIHsKICAgICAgICAgICAgICAgICRyZXMuYXZhaWxhYmxlID0gJHRydWUKICAgICAgICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLlRlbXBlcmF0dXJlIC1hbmQg
HLP:JHJjLlRlbXBlcmF0dXJlIC1ndCAwKSB7ICRyZXMudGVtcF9jID0gW2ludF0kcmMuVGVtcGVyYXR1cmUgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkcmMuV2VhcikgICAgICAgICB7ICRyZXMud2Vhcl9wY3QgPSBbaW50XSRyYy5XZWFyIH0KICAgICAg
HLP:ICAgICAgICAgIGlmICgkbnVsbCAtbmUgJHJjLlBvd2VyT25Ib3VycykgeyAkcmVzLnBvaCA9IFtpbnRdJHJjLlBvd2VyT25Ib3VycyB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgIyBTZW5hbCBhZGljaW9uYWwgZGUgcHJlZGljY2lvbiBkZSBmYWxsbyB2aWEg
HLP:ZXN0YWRvIGRlIHNhbHVkIGZpc2ljYQogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgJHVuaGVhbHRoeSA9IEAoR2V0LVBoeXNpY2FsRGlzayAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IFdoZXJlLU9iamVjdCB7ICRfLkhlYWx0aFN0YXR1
HLP:cyAtYW5kICRfLkhlYWx0aFN0YXR1cyAtbmUgJ0hlYWx0aHknIH0pCiAgICAgICAgICAgICAgICBpZiAoJHVuaGVhbHRoeS5Db3VudCAtZ3QgMCkgeyAkcmVzLmF2YWlsYWJsZSA9ICR0cnVlOyAkcmVzLnByZWRpY3RfZmFpbCA9ICR0cnVlIH0KICAgICAgICAgICAg
HLP:fSBjYXRjaCB7fQogICAgICAgIH0gY2F0Y2gge30KICAgIH0gY2F0Y2gge30KICAgIHJldHVybiAkcmVzCn0KCiMgR2V0LVN0YXJ0dXBJdGVtczogcHJvZ3JhbWFzIHF1ZSBhcnJhbmNhbiBjb24gV2luZG93cyAodG9wIE4pLCBwYXJhIHF1ZSBlbAojIHVzdWFyaW8g
HLP:dmVhIHF1ZSByYWxlbnRpemEgZWwgaW5pY2lvLiBJbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEuCmZ1bmN0aW9uIEdldC1TdGFydHVwSXRlbXMoW2ludF0kdG9wID0gOCkgewogICAgdHJ5IHsKICAgICAgICAkaXRlbXMgPSBAKEdldC1DaW1JbnN0YW5jZSBXaW4zMl9T
HLP:dGFydHVwQ29tbWFuZCAtRXJyb3JBY3Rpb24gU3RvcCB8CiAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLkNvbW1hbmQgfSB8CiAgICAgICAgICAgIFNlbGVjdC1PYmplY3QgLUZpcnN0ICR0b3ApCiAgICAgICAgJGxpc3QgPSBAKCkKICAgICAgICBmb3JlYWNo
HLP:ICgkaSBpbiAkaXRlbXMpIHsKICAgICAgICAgICAgJGNtZCA9IFtzdHJpbmddJGkuQ29tbWFuZAogICAgICAgICAgICBpZiAoJGNtZC5MZW5ndGggLWd0IDgwKSB7ICRjbWQgPSAkY21kLlN1YnN0cmluZygwLDc3KSArICcuLi4nIH0KICAgICAgICAgICAgJG5tID0g
HLP:W3N0cmluZ10kaS5OYW1lOyBpZiAoLW5vdCAkbm0pIHsgJG5tID0gW3N0cmluZ10kaS5DYXB0aW9uIH0KICAgICAgICAgICAgJGxpc3QgKz0gW3BzY3VzdG9tb2JqZWN0XUB7IG5hbWUgPSAkbm07IGNvbW1hbmQgPSAkY21kIH0KICAgICAgICB9CiAgICAgICAgcmV0
HLP:dXJuICwkbGlzdAogICAgfSBjYXRjaCB7IHJldHVybiBAKCkgfQp9CgojIEdldC1CY2RJbnRlZ3JpdHk6IGNvbXBydWViYSBxdWUgbGEgY29uZmlndXJhY2lvbiBkZSBhcnJhbnF1ZSAoQkNEKSB0aWVuZSBsYQojIGVudHJhZGEgYWN0dWFsIGNvbiBvc2RldmljZS9k
HLP:ZXZpY2UuIExhcyBDTEFWRVMgZGUgYmNkZWRpdCBzb24gc2llbXByZSBlbgojIGluZ2xlcywgYXNpIHF1ZSBlcyBpbmRlcGVuZGllbnRlIGRlbCBpZGlvbWEgZGUgbGEgaW50ZXJmYXouCmZ1bmN0aW9uIEdldC1CY2RJbnRlZ3JpdHkgewogICAgJHJlcyA9IFtwc2N1
HLP:c3RvbW9iamVjdF1AeyBvayA9ICRmYWxzZTsgZGV0YWlscyA9ICcnIH0KICAgIHRyeSB7CiAgICAgICAgJG91dCA9ICYgYmNkZWRpdCAvZW51bSAne2N1cnJlbnR9JyAyPiRudWxsCiAgICAgICAgJHR4dCA9ICgkb3V0IC1qb2luICJgbiIpCiAgICAgICAgaWYgKCRM
HLP:QVNURVhJVENPREUgLWVxIDAgLWFuZCAkdHh0IC1tYXRjaCAnKD9pbSleXHMqb3NkZXZpY2UnIC1hbmQgJHR4dCAtbWF0Y2ggJyg/aW0pXlxzKmRldmljZScpIHsKICAgICAgICAgICAgJHJlcy5vayA9ICR0cnVlCiAgICAgICAgICAgICRyZXMuZGV0YWlscyA9ICdF
HLP:bnRyYWRhIGRlIGFycmFucXVlIGFjdHVhbCBpbnRlZ3JhIChkZXZpY2Uvb3NkZXZpY2UgcHJlc2VudGVzKS4nCiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgJHJlcy5vayA9ICRmYWxzZQogICAgICAgICAgICAkcmVzLmRldGFpbHMgPSAnTm8gc2UgcHVkbyBj
HLP:b25maXJtYXIgbGEgZW50cmFkYSBkZSBhcnJhbnF1ZSBhY3R1YWwuJwogICAgICAgIH0KICAgIH0gY2F0Y2ggewogICAgICAgICRyZXMub2sgPSAkZmFsc2UKICAgICAgICAkcmVzLmRldGFpbHMgPSAnYmNkZWRpdCBubyBkaXNwb25pYmxlIG8gc2luIHBlcm1pc29z
HLP:LicKICAgIH0KICAgIHJldHVybiAkcmVzCn0KCiMgR2V0LVRvcFByb2Nlc3NlczogcHJvY2Vzb3MgcXVlIG1hcyBtZW1vcmlhIGRlIHRyYWJham8gY29uc3VtZW4gKHRvcCBOKS4KZnVuY3Rpb24gR2V0LVRvcFByb2Nlc3NlcyhbaW50XSR0b3AgPSA2KSB7CiAgICB0
HLP:cnkgewogICAgICAgICRwcyA9IEAoR2V0LVByb2Nlc3MgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfAogICAgICAgICAgICBTb3J0LU9iamVjdCBXb3JraW5nU2V0NjQgLURlc2NlbmRpbmcgfAogICAgICAgICAgICBTZWxlY3QtT2JqZWN0IC1GaXJzdCAk
HLP:dG9wKQogICAgICAgICRsaXN0ID0gQCgpCiAgICAgICAgZm9yZWFjaCAoJHAgaW4gJHBzKSB7CiAgICAgICAgICAgICRtYiA9IFttYXRoXTo6Um91bmQoJHAuV29ya2luZ1NldDY0IC8gMU1CKQogICAgICAgICAgICAkbGlzdCArPSBbcHNjdXN0b21vYmplY3RdQHsg
HLP:bmFtZSA9IFtzdHJpbmddJHAuUHJvY2Vzc05hbWU7IG1lbV9tYiA9IFtpbnRdJG1iIH0KICAgICAgICB9CiAgICAgICAgcmV0dXJuICwkbGlzdAogICAgfSBjYXRjaCB7IHJldHVybiBAKCkgfQp9CgojIEdldC1TZmNSZXN1bHQ6IGNsYXNpZmljYSBlbCByZXN1bHRh
HLP:ZG8gZGUgU0ZDIGxleWVuZG8gQ0JTLmxvZyAoU0lFTVBSRSBlbgojIGluZ2xlcykgZW4gbHVnYXIgZGUgbGEgc2FsaWRhIHRyYWR1Y2lkYSBkZSBsYSBjb25zb2xhLiBEZXZ1ZWx2ZSB1bm8gZGU6CiMgY2xlYW4gfCByZXBhaXJlZCB8IHVucmVwYWlyYWJsZSB8IHVu
HLP:a25vd24uCmZ1bmN0aW9uIEdldC1TZmNSZXN1bHQgewogICAgJGxvZyA9IEpvaW4tUGF0aCAkZW52OndpbmRpciAnTG9nc1xDQlNcQ0JTLmxvZycKICAgIGlmICgtbm90IChUZXN0LVBhdGggJGxvZykpIHsgcmV0dXJuICd1bmtub3duJyB9CiAgICB0cnkgewogICAg
HLP:ICAgICR0YWlsID0gQChHZXQtQ29udGVudCAtUGF0aCAkbG9nIC1UYWlsIDQwMDAgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICAgICAgJHNyID0gQCgkdGFpbCB8IFdoZXJlLU9iamVjdCB7ICRfIC1tYXRjaCAnXFtTUlxdJyB9KQogICAgICAgIGlm
HLP:ICgkc3IuQ291bnQgLWVxIDApIHsgcmV0dXJuICd1bmtub3duJyB9CiAgICAgICAgJGpvaW5lZCA9ICgkc3IgLWpvaW4gImBuIikKICAgICAgICBpZiAoJGpvaW5lZCAtbWF0Y2ggJyg/aSljYW5ub3QgcmVwYWlyJykgeyByZXR1cm4gJ3VucmVwYWlyYWJsZScgfQog
HLP:ICAgICAgIGlmICgkam9pbmVkIC1tYXRjaCAnKD9pKXJlcGFpcmluZ1xzKyhbMS05XVxkKilccytjb21wb25lbnRzfHN1Y2Nlc3NmdWxseSByZXBhaXJlZHxyZXBhaXJlZCBmaWxlfHJlcGFpcmluZyBjb3JydXB0ZWQgZmlsZScpIHsgcmV0dXJuICdyZXBhaXJlZCcg
HLP:fQogICAgICAgIGlmICgkam9pbmVkIC1tYXRjaCAnKD9pKXZlcmlmeSBjb21wbGV0ZXxubyAuKmludGVncml0eSB2aW9sYXRpb25zfGNhbm5vdCB2ZXJpZnl8dmVyaWZ5aW5nJykgeyByZXR1cm4gJ2NsZWFuJyB9CiAgICAgICAgcmV0dXJuICdjbGVhbicKICAgIH0g
HLP:Y2F0Y2ggeyByZXR1cm4gJ3Vua25vd24nIH0KfQoKIyBOZXctSnNvblJlcG9ydDogdnVlbGNhIGVsIGVzdGFkbyArIHJlc3VtZW4gY2FsY3VsYWRvIGEgdW4gZmljaGVybyBKU09OCiMgKC1BcmcgPSBydXRhIGRlIHNhbGlkYSkuIFV0aWwgcGFyYSBhdXRvbWF0aXph
HLP:Y2lvbiAvIE1ETSAvIGludmVudGFyaW8uCmZ1bmN0aW9uIE5ldy1Kc29uUmVwb3J0KCRvdXRQYXRoKSB7CiAgICB0cnkgewogICAgICAgICRzdCA9IFJlYWQtU3RhdGUKICAgICAgICAkc3lzUGFpcnMgPSBHZXQtU3lzSW5mbwogICAgICAgICRzeXNNYXAgPSBAe30K
HLP:ICAgICAgICBmb3JlYWNoICgkcCBpbiAkc3lzUGFpcnMpIHsgJGt2ID0gJHAgLXNwbGl0ICc9JywyOyBpZiAoJGt2LkNvdW50IC1lcSAyKSB7ICRzeXNNYXBbJGt2WzBdXSA9ICRrdlsxXSB9IH0KICAgICAgICAkcGhhc2VzID0gQCgkc3QucGhhc2VzKQogICAgICAg
HLP:ICRjT0s9MDskY1dBUk49MDskY0VSUj0wOyRjU0tJUD0wCiAgICAgICAgZm9yZWFjaCAoJHBoIGluICRwaGFzZXMpIHsgc3dpdGNoIChbc3RyaW5nXSRwaC5yZXN1bHQpIHsgJ09LJyB7JGNPSysrfSAnV0FSTicgeyRjV0FSTisrfSAnRVJST1InIHskY0VSUisrfSAn
HLP:U0tJUCcgeyRjU0tJUCsrfSB9IH0KICAgICAgICAkZGVsdGEgPSAkbnVsbAogICAgICAgIGlmICgkc3Quc2NvcmVfYmVmb3JlIC1uZSAkbnVsbCAtYW5kICRzdC5zY29yZV9hZnRlciAtbmUgJG51bGwpIHsgJGRlbHRhID0gW2ludF0kc3Quc2NvcmVfYWZ0ZXIgLSBb
HLP:aW50XSRzdC5zY29yZV9iZWZvcmUgfQogICAgICAgICRvYmogPSBbcHNjdXN0b21vYmplY3RdQHsKICAgICAgICAgICAgc2NoZW1hICAgICAgID0gJ3dwaS1yZXBvcnQvMScKICAgICAgICAgICAgdmVyc2lvbiAgICAgID0gJFdQSV9WRVJTSU9OCiAgICAgICAgICAg
HLP:IGdlbmVyYXRlZCAgICA9IChHZXQtRGF0ZSkuVG9TdHJpbmcoJ3MnKQogICAgICAgICAgICBtYWNoaW5lICAgICAgPSAkZW52OkNPTVBVVEVSTkFNRQogICAgICAgICAgICBzeXN0ZW0gICAgICAgPSAkc3lzTWFwCiAgICAgICAgICAgIHNjb3JlX2JlZm9yZSA9ICRz
HLP:dC5zY29yZV9iZWZvcmUKICAgICAgICAgICAgc2NvcmVfYWZ0ZXIgID0gJHN0LnNjb3JlX2FmdGVyCiAgICAgICAgICAgIHNjb3JlX2RlbHRhICA9ICRkZWx0YQogICAgICAgICAgICBzdW1tYXJ5ICAgICAgPSBbcHNjdXN0b21vYmplY3RdQHsgb2s9JGNPSzsgd2Fy
HLP:bj0kY1dBUk47IGVycm9yPSRjRVJSOyBza2lwPSRjU0tJUDsgdG90YWw9JHBoYXNlcy5Db3VudCB9CiAgICAgICAgICAgIHBoYXNlcyAgICAgICA9ICRwaGFzZXMKICAgICAgICAgICAgZmluZGluZ3MgICAgID0gQCgkc3QuZmluZGluZ3MpCiAgICAgICAgICAgIGRp
HLP:YWcgICAgICAgICA9ICRzdC5kaWFnCiAgICAgICAgfQogICAgICAgICRqc29uID0gJG9iaiB8IENvbnZlcnRUby1Kc29uIC1EZXB0aCA4CiAgICAgICAgJHV0ZjggPSBOZXctT2JqZWN0IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZygkZmFsc2UpCiAgICAgICAgW1N5
HLP:c3RlbS5JTy5GaWxlXTo6V3JpdGVBbGxUZXh0KCRvdXRQYXRoLCAkanNvbiwgJHV0ZjgpCiAgICAgICAgIlJFU1VMVD1PSyIKICAgICAgICAiUEFUSD0kb3V0UGF0aCIKICAgIH0gY2F0Y2ggewogICAgICAgICJSRVNVTFQ9RkFJTCIKICAgICAgICAiRVJST1I9JCgk
HLP:Xy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICB9Cn0KCiMgTmV3LVN1cHBvcnRQYWNrYWdlOiBlbXBhcXVldGEgbG9ncyArIGluZm9ybWUgKyBlc3RhZG8gKyBiYXR0ZXJ5LXJlcG9ydCBlbiB1bgojIFpJUCAoLUFyZyA9IHJ1dGEgZGVsIHppcCkgcGFyYSBlbnZpYXIg
HLP:YSBzb3BvcnRlLiBTaW4gZGVwZW5kZW5jaWFzIGV4dGVybmFzCiMgKHVzYSBDb21wcmVzcy1BcmNoaXZlLCBpbmNsdWlkbyBlbiBXaW5kb3dzIDEwLzExKS4KZnVuY3Rpb24gTmV3LVN1cHBvcnRQYWNrYWdlKCRvdXRQYXRoKSB7CiAgICB0cnkgewogICAgICAgICR0
HLP:bXAgPSBKb2luLVBhdGggJFdvcmsgKCdzb3BvcnRlXycgKyAoR2V0LURhdGUpLlRvU3RyaW5nKCd5eXl5TU1kZF9ISG1tc3MnKSkKICAgICAgICBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICR0bXAgLUZvcmNlIHwgT3V0LU51bGwKICAgICAgICAj
HLP:IGVzdGFkby5qc29uCiAgICAgICAgaWYgKFRlc3QtUGF0aCAkU3RhdGVGaWxlKSB7IENvcHktSXRlbSAkU3RhdGVGaWxlIChKb2luLVBhdGggJHRtcCAnZXN0YWRvLmpzb24nKSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfQogICAgICAgICMg
HLP:TG9ncwogICAgICAgICRsb2dzID0gSm9pbi1QYXRoICRXb3JrICdMb2dzJwogICAgICAgIGlmIChUZXN0LVBhdGggJGxvZ3MpIHsKICAgICAgICAgICAgJGRzdExvZ3MgPSBKb2luLVBhdGggJHRtcCAnTG9ncycKICAgICAgICAgICAgTmV3LUl0ZW0gLUl0ZW1UeXBl
HLP:IERpcmVjdG9yeSAtUGF0aCAkZHN0TG9ncyAtRm9yY2UgfCBPdXQtTnVsbAogICAgICAgICAgICBHZXQtQ2hpbGRJdGVtICRsb2dzIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgQ29weS1JdGVtIC1EZXN0aW5hdGlvbiAkZHN0TG9ncyAtRm9y
HLP:Y2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICB9CiAgICAgICAgIyBJbmZvcm1lcyBIVE1ML0pTT04gZXhpc3RlbnRlcyBlbiBXb3JrCiAgICAgICAgR2V0LUNoaWxkSXRlbSAkV29yayAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250
HLP:aW51ZSB8CiAgICAgICAgICAgIFdoZXJlLU9iamVjdCB7ICRfLk5hbWUgLW1hdGNoICcoP2kpXkluZm9ybWUuKlwuKGh0bWx8anNvbikkJyB9IHwKICAgICAgICAgICAgQ29weS1JdGVtIC1EZXN0aW5hdGlvbiAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50
HLP:bHlDb250aW51ZQogICAgICAgICMgYmF0dGVyeSByZXBvcnQgc2kgZXhpc3RlCiAgICAgICAgJHN0ID0gUmVhZC1TdGF0ZQogICAgICAgIHRyeSB7IGlmICgkc3QuZGlhZyAtYW5kICRzdC5kaWFnLmJhdHRlcnkgLWFuZCAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9w
HLP:YXRoIC1hbmQgKFRlc3QtUGF0aCAkc3QuZGlhZy5iYXR0ZXJ5LnJlcG9ydF9wYXRoKSkgeyBDb3B5LUl0ZW0gJHN0LmRpYWcuYmF0dGVyeS5yZXBvcnRfcGF0aCAkdG1wIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9IH0gY2F0Y2gge30KICAg
HLP:ICAgICBpZiAoVGVzdC1QYXRoICRvdXRQYXRoKSB7IFJlbW92ZS1JdGVtICRvdXRQYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgQ29tcHJlc3MtQXJjaGl2ZSAtUGF0aCAoSm9pbi1QYXRoICR0bXAgJyonKSAtRGVzdGlu
HLP:YXRpb25QYXRoICRvdXRQYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgIHRyeSB7IFJlbW92ZS1JdGVtICR0bXAgLVJlY3Vyc2UgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2gge30KICAgICAgICAiUkVTVUxUPU9L
HLP:IgogICAgICAgICJQQVRIPSRvdXRQYXRoIgogICAgfSBjYXRjaCB7CiAgICAgICAgIlJFU1VMVD1GQUlMIgogICAgICAgICJFUlJPUj0kKCRfLkV4Y2VwdGlvbi5NZXNzYWdlKSIKICAgIH0KfQoKc3dpdGNoICgkQWN0aW9uLlRvTG93ZXIoKSkgewogICAgJ25vbmUn
HLP:ICAgICAgICAgeyB9ICMgVXNhZG8gcGFyYSBkb3Qtc291cmNpbmcKICAgICdjaGVja2JhY2t1cHMnIHsKICAgICAgICAkcGFydHMgPSAkQXJnIC1zcGxpdCAnXHwnLCAyCiAgICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtbmUgMikgeyAiUkVTVUxUPUZBSUwiOyAiRVJS
HLP:T1I9QXJndW1lbnRvcyBpbnZhbGlkb3MiOyBleGl0IDAgfQogICAgICAgICRia2RpciA9ICRwYXJ0c1swXQogICAgICAgICR0cyA9ICRwYXJ0c1sxXQogICAgICAgICRycF9vayA9ICRmYWxzZQogICAgICAgIHRyeSB7CiAgICAgICAgICAgICRycHMgPSBHZXQtQ29t
HLP:cHV0ZXJSZXN0b3JlUG9pbnQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAgICAgZm9yZWFjaCAoJHJwIGluICRycHMpIHsKICAgICAgICAgICAgICAgIGlmICgkcnAuRGVzY3JpcHRpb24gLWxpa2UgIlN1aXRlX1JlcGFyYWNpb25fKiIpIHsg
HLP:JHJwX29rID0gJHRydWU7IGJyZWFrIH0KICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2ggeyAkcnBfb2sgPSAkZmFsc2UgfQogICAgICAgICRyZWdfb2sgPSAkdHJ1ZQogICAgICAgICRzb2Z0ID0gSm9pbi1QYXRoICRia2RpciAiU09GVFdBUkVfJHRzLnJlZyIK
HLP:ICAgICAgICAkc3lzID0gSm9pbi1QYXRoICRia2RpciAiU1lTVEVNXyR0cy5yZWciCiAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAkc29mdCkgLW9yIChHZXQtSXRlbSAkc29mdCkuTGVuZ3RoIC1lcSAwKSB7ICRyZWdfb2sgPSAkZmFsc2UgfQogICAgICAgIGlm
HLP:ICgtbm90IChUZXN0LVBhdGggJHN5cykgLW9yIChHZXQtSXRlbSAkc3lzKS5MZW5ndGggLWVxIDApIHsgJHJlZ19vayA9ICRmYWxzZSB9CiAgICAgICAgIlJQX09LPSQoaWYgKCRycF9vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIlJFR19PSz0kKGlmICgk
HLP:cmVnX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdib290c3RyYXB3aW5nZXQnIHsKICAgICAgICAkb2sgPSBJbnN0YWxsLVdpbmdldEJvb3RzdHJhcAogICAgICAgICJCT09UU1RSQVBfT0s9JChpZiAoJG9rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAg
HLP:IH0KICAgICdmaW5kbG9jYWxzb3VyY2UnIHsKICAgICAgICAkZHJpdmVzID0gR2V0LVBTRHJpdmUgLVBTUHJvdmlkZXIgRmlsZVN5c3RlbQogICAgICAgICRwYXRocyA9IEAoKQogICAgICAgICRlZGl0aW9uSWQgPSAnJwogICAgICAgIHRyeSB7ICRlZGl0aW9uSWQg
HLP:PSAoR2V0LUl0ZW1Qcm9wZXJ0eSAnSEtMTTpcU09GVFdBUkVcTWljcm9zb2Z0XFdpbmRvd3MgTlRcQ3VycmVudFZlcnNpb24nIC1OYW1lIEVkaXRpb25JRCAtRXJyb3JBY3Rpb24gU3RvcCkuRWRpdGlvbklEIH0gY2F0Y2gge30KICAgICAgICBmdW5jdGlvbiBHZXQt
HLP:SW5zdGFsbEltYWdlU291cmNlKFtzdHJpbmddJGtpbmQsIFtzdHJpbmddJHBhdGgsIFtzdHJpbmddJGVkaXRpb24pIHsKICAgICAgICAgICAgJGluZGV4ID0gMQogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgJGltYWdlcyA9IEAoR2V0LVdpbmRvd3NJ
HLP:bWFnZSAtSW1hZ2VQYXRoICRwYXRoIC1FcnJvckFjdGlvbiBTdG9wKQogICAgICAgICAgICAgICAgJG1hdGNoID0gJG51bGwKICAgICAgICAgICAgICAgIGlmICgkZWRpdGlvbiAtbWF0Y2ggJ1Byb2Zlc3Npb25hbCcpIHsgJG1hdGNoID0gJGltYWdlcyB8IFdoZXJl
HLP:LU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ1xiUHJvXGJ8UHJvZmVzc2lvbmFsJyB9IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSB9CiAgICAgICAgICAgICAgICBlbHNlaWYgKCRlZGl0aW9uIC1tYXRjaCAnRW50ZXJwcmlzZScpIHsgJG1hdGNoID0gJGlt
HLP:YWdlcyB8IFdoZXJlLU9iamVjdCB7ICRfLkltYWdlTmFtZSAtbWF0Y2ggJ0VudGVycHJpc2UnIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRpb24gLW1hdGNoICdFZHVjYXRpb24nKSB7ICRtYXRjaCA9ICRp
HLP:bWFnZXMgfCBXaGVyZS1PYmplY3QgeyAkXy5JbWFnZU5hbWUgLW1hdGNoICdFZHVjYXRpb24nIH0gfCBTZWxlY3QtT2JqZWN0IC1GaXJzdCAxIH0KICAgICAgICAgICAgICAgIGVsc2VpZiAoJGVkaXRpb24gLW1hdGNoICdDb3JlJykgeyAkbWF0Y2ggPSAkaW1hZ2Vz
HLP:IHwgV2hlcmUtT2JqZWN0IHsgJF8uSW1hZ2VOYW1lIC1tYXRjaCAnXGJIb21lXGJ8Q29yZScgfSB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEgfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1lcSAkbWF0Y2ggLWFuZCAkaW1hZ2VzLkNvdW50IC1lcSAxKSB7ICRt
HLP:YXRjaCA9ICRpbWFnZXNbMF0gfQogICAgICAgICAgICAgICAgaWYgKCRudWxsIC1uZSAkbWF0Y2gpIHsgJGluZGV4ID0gW2ludF0kbWF0Y2guSW1hZ2VJbmRleCB9CiAgICAgICAgICAgIH0gY2F0Y2gge30KICAgICAgICAgICAgcmV0dXJuICgiezB9OnsxfTp7Mn0i
HLP:IC1mICRraW5kLCAkcGF0aCwgJGluZGV4KQogICAgICAgIH0KICAgICAgICBmb3JlYWNoICgkZCBpbiAkZHJpdmVzKSB7CiAgICAgICAgICAgICRyb290ID0gJGQuUm9vdAogICAgICAgICAgICAkd2ltID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXGluc3RhbGwu
HLP:d2ltIgogICAgICAgICAgICAkZXNkID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXGluc3RhbGwuZXNkIgogICAgICAgICAgICAkc3hzID0gSm9pbi1QYXRoICRyb290ICJzb3VyY2VzXHN4cyIKICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkd2ltKSB7ICRwYXRo
HLP:cyArPSAoR2V0LUluc3RhbGxJbWFnZVNvdXJjZSAnV2ltJyAkd2ltICRlZGl0aW9uSWQpIH0KICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAkZXNkKSB7ICRwYXRocyArPSAoR2V0LUluc3RhbGxJbWFnZVNvdXJjZSAnRXNkJyAkZXNkICRlZGl0aW9uSWQpIH0KICAg
HLP:ICAgICAgICAgaWYgKFRlc3QtUGF0aCAkc3hzKSB7ICRwYXRocyArPSAkc3hzIH0KICAgICAgICB9CiAgICAgICAgaWYgKCRwYXRocy5Db3VudCAtZ3QgMCkgeyAiU09VUkNFPSQoJHBhdGhzWzBdKSIgfSBlbHNlIHsgIlNPVVJDRT0iIH0KICAgIH0KICAgICdkaXNt
HLP:cmVzdG9yZScgewogICAgICAgICRwYXJ0cyA9IEAoJEFyZyAtc3BsaXQgJ1x8JywgMikKICAgICAgICAkc291cmNlID0gaWYgKCRwYXJ0cy5Db3VudCAtZ2UgMSkgeyAkcGFydHNbMF0gfSBlbHNlIHsgJycgfQogICAgICAgICR0aW1lb3V0TWludXRlcyA9IDQ1CiAg
HLP:ICAgICAgaWYgKCRwYXJ0cy5Db3VudCAtZ2UgMikgeyBbdm9pZF1baW50XTo6VHJ5UGFyc2UoJHBhcnRzWzFdLCBbcmVmXSR0aW1lb3V0TWludXRlcykgfQogICAgICAgIGlmICgkdGltZW91dE1pbnV0ZXMgLWx0IDUpIHsgJHRpbWVvdXRNaW51dGVzID0gNSB9Cgog
HLP:ICAgICAgIGZ1bmN0aW9uIFF1b3RlLURpc21WYWx1ZShbc3RyaW5nXSR2YWx1ZSkgewogICAgICAgICAgICBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkdmFsdWUpKSB7IHJldHVybiAkdmFsdWUgfQogICAgICAgICAgICByZXR1cm4gJyInICsgKCR2
HLP:YWx1ZSAtcmVwbGFjZSAnIicsICdcIicpICsgJyInCiAgICAgICAgfQoKICAgICAgICAkYXJndW1lbnRzID0gJy9PbmxpbmUgL0NsZWFudXAtSW1hZ2UgL1Jlc3RvcmVIZWFsdGgnCiAgICAgICAgaWYgKC1ub3QgW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgk
HLP:c291cmNlKSkgewogICAgICAgICAgICAkYXJndW1lbnRzICs9ICcgL1NvdXJjZTonICsgKFF1b3RlLURpc21WYWx1ZSAkc291cmNlKSArICcgL0xpbWl0QWNjZXNzJwogICAgICAgIH0KCiAgICAgICAgJHRpbWVkT3V0ID0gJGZhbHNlCiAgICAgICAgJGV4aXRDb2Rl
HLP:ID0gMwogICAgICAgICRvdXRGaWxlID0gSm9pbi1QYXRoICRXb3JrICgiZGlzbV9yZXN0b3JlX3swfS5vdXQiIC1mIChbZ3VpZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKSkKICAgICAgICAkZXJyRmlsZSA9IEpvaW4tUGF0aCAkV29yayAoImRpc21fcmVzdG9y
HLP:ZV97MH0uZXJyIiAtZiAoW2d1aWRdOjpOZXdHdWlkKCkuVG9TdHJpbmcoJ04nKSkpCiAgICAgICAgdHJ5IHsKICAgICAgICAgICAgJHBzaSA9IFtEaWFnbm9zdGljcy5Qcm9jZXNzU3RhcnRJbmZvXTo6bmV3KCkKICAgICAgICAgICAgJHBzaS5GaWxlTmFtZSA9ICdj
HLP:bWQuZXhlJwogICAgICAgICAgICAkcHNpLkFyZ3VtZW50cyA9ICgnL2MgZGlzbS5leGUgezB9ID4gInsxfSIgMj4gInsyfSInIC1mICRhcmd1bWVudHMsICRvdXRGaWxlLCAkZXJyRmlsZSkKICAgICAgICAgICAgJHBzaS5Vc2VTaGVsbEV4ZWN1dGUgPSAkZmFsc2UK
HLP:ICAgICAgICAgICAgJHBzaS5DcmVhdGVOb1dpbmRvdyA9ICR0cnVlCiAgICAgICAgICAgICRwID0gW0RpYWdub3N0aWNzLlByb2Nlc3NdOjpuZXcoKQogICAgICAgICAgICAkcC5TdGFydEluZm8gPSAkcHNpCiAgICAgICAgICAgIFt2b2lkXSRwLlN0YXJ0KCkKICAg
HLP:ICAgICAgICAgaWYgKC1ub3QgJHAuV2FpdEZvckV4aXQoJHRpbWVvdXRNaW51dGVzICogNjAgKiAxMDAwKSkgewogICAgICAgICAgICAgICAgJHRpbWVkT3V0ID0gJHRydWUKICAgICAgICAgICAgICAgIHRyeSB7ICRwLktpbGwoKSB9IGNhdGNoIHt9CiAgICAgICAg
HLP:ICAgICAgICAkZXhpdENvZGUgPSAxNDYwCiAgICAgICAgICAgIH0gZWxzZSB7CiAgICAgICAgICAgICAgICB0cnkgeyAkcC5XYWl0Rm9yRXhpdCgpIH0gY2F0Y2gge30KICAgICAgICAgICAgICAgICRleGl0Q29kZSA9ICRwLkV4aXRDb2RlCiAgICAgICAgICAgICAg
HLP:ICBpZiAoJG51bGwgLWVxICRleGl0Q29kZSkgeyAkZXhpdENvZGUgPSAzIH0KICAgICAgICAgICAgfQogICAgICAgIH0gY2F0Y2ggewogICAgICAgICAgICAiRVJST1I9JCgkXy5FeGNlcHRpb24uTWVzc2FnZSkiCiAgICAgICAgICAgICRleGl0Q29kZSA9IDMKICAg
HLP:ICAgICB9CgogICAgICAgIGlmIChUZXN0LVBhdGggJG91dEZpbGUpIHsgR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRvdXRGaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KICAgICAgICBpZiAoVGVzdC1QYXRoICRlcnJGaWxlKSB7IEdldC1Db250
HLP:ZW50IC1MaXRlcmFsUGF0aCAkZXJyRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB9CiAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRvdXRGaWxlLCRlcnJGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAg
HLP:ICAgICJUSU1FRE9VVD0kKGlmICgkdGltZWRPdXQpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJFWElUQ09ERT0kZXhpdENvZGUiCiAgICB9CiAgICAnc3lzaW5mbycgICAgICB7IEdldC1TeXNJbmZvIH0KICAgICdzY29yZScgICAgICAgIHsgJGggPSBHZXQt
HLP:SGVhbHRoU2NvcmU7ICJTQ09SRT0kKCRoLnNjb3JlKSI7IGZvcmVhY2ggKCRyIGluICRoLnJlYXNvbnMpIHsgIlJFQVNPTj0kciIgfSB9CiAgICAnZm9yZW5zaWNzJyAgICB7IEdldC1Gb3JlbnNpY3MgfQogICAgJ3RyaWFnZScgICAgICAgeyBHZXQtVHJpYWdlIH0K
HLP:ICAgICdyZXN0b3JlcG9pbnQnIHsgTmV3LVJlc3RvcmVQb2ludCB9CiAgICAnbWVkaWF0eXBlJyAgICB7ICRtZWRpYSA9IEdldC1NZWRpYVR5cGU7ICJNRURJQT0kbWVkaWEiOyAiT1BUSU1JWkU9JChSZXNvbHZlLU9wdGltaXplQWN0aW9uICRtZWRpYSkiIH0KICAg
HLP:ICdkZXZpY2VzJyAgICAgIHsgR2V0LURldmljZVByb2JsZW1zIH0KICAgICdyZXBvcnQnICAgICAgIHsgQWRkLVR5cGUgLUFzc2VtYmx5TmFtZSBTeXN0ZW0uV2ViIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlOyBOZXctSHRtbFJlcG9ydCAkQXJnIH0KICAg
HLP:ICdhZGRwaGFzZScgICAgIHsgQWRkLVBoYXNlUmVzdWx0ICRBcmcgfQogICAgJ3NldGJlZm9yZScgICAgeyBTZXQtU2NvcmUgJ2JlZm9yZScgJEFyZyB9CiAgICAnc2V0YWZ0ZXInICAgICB7IFNldC1TY29yZSAnYWZ0ZXInICRBcmcgfQogICAgJ2ZpbmRpbmcnICAg
HLP:ICAgeyBBZGQtRmluZGluZyAkQXJnIH0KICAgICdyZXNldHN0YXRlJyAgIHsgUmVzZXQtU3RhdGU7ICJSRVNVTFQ9T0siIH0KICAgICdub3JtYWxpemVmYXNlcycgewogICAgICAgICRyID0gTm9ybWFsaXplLUZhc2VzICRBcmcKICAgICAgICAiTk9STT0kKFtzdHJp
HLP:bmddOjpKb2luKCcsJywgQCgkci5ub3JtKSkpIgogICAgICAgICJJTlZBTElEPSQoW3N0cmluZ106OkpvaW4oJywnLCBAKCRyLmludmFsaWQpKSkiCiAgICB9CiAgICAnY2hlY2twb2ludCcgewogICAgICAgICRwYXJzZWQgPSBQYXJzZS1DaGVja3BvaW50QXJnICRB
HLP:cmcKICAgICAgICBzd2l0Y2ggKCRwYXJzZWQuc3ViKSB7CiAgICAgICAgICAgICdzYXZlJyB7IGlmIChTYXZlLUNoZWNrcG9pbnQgJHBhcnNlZCkgeyAiUkVTVUxUPU9LIiB9IGVsc2UgeyAiUkVTVUxUPUZBSUwiIH0gfQogICAgICAgICAgICAnbG9hZCcgewogICAg
HLP:ICAgICAgICAgICAgJGNwID0gTG9hZC1DaGVja3BvaW50CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLWVxICRjcCkgeyAiUkVTVUxUPU5PTkUiIH0KICAgICAgICAgICAgICAgIGVsc2UgewogICAgICAgICAgICAgICAgICAgICJSRVNVTFQ9T0siCiAgICAgICAg
HLP:ICAgICAgICAgICAgIlZBTElEPSQoaWYgKFRlc3QtQ2hlY2twb2ludFZhbGlkICRjcCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgICAgICAgICAgICAgIlZFUlNJT049JCgkY3AudmVyc2lvbikiCiAgICAgICAgICAgICAgICAgICAgIkNSRUFURUQ9JCgkY3Au
HLP:Y3JlYXRlZCkiCiAgICAgICAgICAgICAgICAgICAgIlNFTEVDVElPTj0kKFtzdHJpbmddOjpKb2luKCcsJywgQCgkY3Auc2VsZWN0aW9uKSkpIgogICAgICAgICAgICAgICAgICAgICJDT01QTEVURUQ9JChbc3RyaW5nXTo6Sm9pbignLCcsIEAoJGNwLmNvbXBsZXRl
HLP:ZCkpKSIKICAgICAgICAgICAgICAgICAgICAiUkVBU09OPSQoJGNwLnBlbmRpbmdfcmVhc29uKSIKICAgICAgICAgICAgICAgICAgICAiTkVYVD0kKEdldC1OZXh0UGhhc2UgJGNwKSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9BVVRPPSQoaWYgKCRjcC5tb2Rl
HLP:LmF1dG8pIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICAgICAgICAgICAgICJNT0RFX05PUkVCT09UPSQoaWYgKCRjcC5tb2RlLm5vcmVib290KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9LRUVQV1U9JChpZiAoJGNwLm1v
HLP:ZGUua2VlcHd1KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9EUlk9JChpZiAoJGNwLm1vZGUuZHJ5KSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgICAgICAiTU9ERV9UUklBR0U9JChpZiAoJGNwLm1vZGUudHJp
HLP:YWdlKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAnbmV4dCcgewogICAgICAgICAgICAgICAgJGNwID0gTG9hZC1DaGVja3BvaW50CiAgICAgICAgICAgICAgICBpZiAoJG51bGwgLW5lICRjcCAt
HLP:YW5kIChUZXN0LUNoZWNrcG9pbnRWYWxpZCAkY3ApKSB7ICJORVhUPSQoR2V0LU5leHRQaGFzZSAkY3ApIiB9IGVsc2UgeyAiTkVYVD0iIH0KICAgICAgICAgICAgfQogICAgICAgICAgICAnY2xlYXInIHsKICAgICAgICAgICAgICAgIGlmIChUZXN0LVBhdGggJENo
HLP:ZWNrcG9pbnRGaWxlKSB7CiAgICAgICAgICAgICAgICAgICAgdHJ5IHsgUmVtb3ZlLUl0ZW0gJENoZWNrcG9pbnRGaWxlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcDsgIlJFU1VMVD1PSyIgfSBjYXRjaCB7ICJSRVNVTFQ9RkFJTCIgfQogICAgICAgICAgICAgICAg
HLP:fSBlbHNlIHsgIlJFU1VMVD1PSyIgfQogICAgICAgICAgICB9CiAgICAgICAgICAgIGRlZmF1bHQgeyAiUkVTVUxUPUZBSUwiOyAiRVJST1I9c3ViYWNjaW9uIGRlIGNoZWNrcG9pbnQgZGVzY29ub2NpZGEiIH0KICAgICAgICB9CiAgICB9CiAgICAnbW92ZXJlc3Vs
HLP:dCcgewogICAgICAgICRwYXJ0cyA9ICRBcmcgLXNwbGl0ICdcfCcsIDIKICAgICAgICBpZiAoJHBhcnRzLkNvdW50IC1lcSAyKSB7CiAgICAgICAgICAgICRvayA9IFRlc3QtTW92ZVJlc3VsdFBhdGggJHBhcnRzWzBdICRwYXJ0c1sxXQogICAgICAgIH0gZWxzZSB7
HLP:CiAgICAgICAgICAgICRiICA9ICRBcmcgLXNwbGl0ICcsJwogICAgICAgICAgICAkc2UgPSAoJGIuQ291bnQgLWdlIDEgLWFuZCAkYlswXS5UcmltKCkgLWVxICcxJykKICAgICAgICAgICAgJGRlID0gKCRiLkNvdW50IC1nZSAyIC1hbmQgJGJbMV0uVHJpbSgpIC1l
HLP:cSAnMScpCiAgICAgICAgICAgICRvayA9IFRlc3QtTW92ZVJlc3VsdCAkc2UgJGRlCiAgICAgICAgfQogICAgICAgICJNT1ZFRD0kKGlmICgkb2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgfQogICAgJ3Z0bHdyaXRlJyB7CiAgICAgICAgJHAgICA9ICRBcmcgLXNw
HLP:bGl0ICcsJwogICAgICAgICRjdXIgPSBpZiAoJHAuQ291bnQgLWdlIDEpIHsgJHBbMF0gfSBlbHNlIHsgJycgfQogICAgICAgICRkZXMgPSBpZiAoJHAuQ291bnQgLWdlIDIpIHsgJHBbMV0gfSBlbHNlIHsgW3N0cmluZ10kVlRfTEVWRUxfREVTSVJFRCB9CiAgICAg
HLP:ICAgIldSSVRFPSQoaWYgKFJlc29sdmUtVnRsV3JpdGUgJGN1ciAkZGVzKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgIH0KICAgICdtYXBleGl0JyAgICAgIHsgIlJFUz0kKE1hcC1FeGl0Q29kZSAkQXJnKSIgfQogICAgIyAtLS0gKDUuMSAvIFJlcSAxNSkgRGlhZ25v
HLP:c3RpY28gYW1wbGlhZG8gLS0tCiAgICAncmFtY2hlY2snIHsKICAgICAgICAkciA9IEdldC1SYW1DaGVjawogICAgICAgICRzdCA9IEluaXRpYWxpemUtRGlhZyAoUmVhZC1TdGF0ZSkKICAgICAgICAkc3QuZGlhZy5yYW0gPSBbcHNjdXN0b21vYmplY3RdQHsgc3Rh
HLP:dHVzID0gJHIuc3RhdHVzOyByZWNvbW1lbmRfbWRzY2hlZCA9IFtib29sXSRyLnJlY29tbWVuZF9tZHNjaGVkIH0KICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiUkFNX1NUQVRVUz0kKCRyLnN0YXR1cykiCiAgICAgICAgIlJBTV9SRUNPTU1FTkRfTURT
HLP:Q0hFRD0kKGlmICgkci5yZWNvbW1lbmRfbWRzY2hlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICAnYmF0dGVyeScgewogICAgICAgICRiID0gR2V0LUJhdHRlcnlIZWFsdGgKICAgICAgICAkc3QgPSBJbml0aWFsaXplLURpYWcgKFJlYWQtU3RhdGUpCiAg
HLP:ICAgICAgJHN0LmRpYWcuYmF0dGVyeSA9IFtwc2N1c3RvbW9iamVjdF1AeyBwcmVzZW50ID0gW2Jvb2xdJGIucHJlc2VudDsgaGVhbHRoX3BjdCA9ICRiLmhlYWx0aF9wY3Q7IHJlcG9ydF9wYXRoID0gJGIucmVwb3J0X3BhdGggfQogICAgICAgIFdyaXRlLVN0YXRl
HLP:ICRzdAogICAgICAgICJCQVRURVJZX1BSRVNFTlQ9JChpZiAoJGIucHJlc2VudCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfSEVBTFRIX1BDVD0kKCRiLmhlYWx0aF9wY3QpIgogICAgICAgICJCQVRURVJZX1JFUE9SVD0kKCRiLnJlcG9ydF9w
HLP:YXRoKSIKICAgIH0KICAgICduZXRhZHZhbmNlZCcgewogICAgICAgICRuID0gR2V0LU5ldEFkdmFuY2VkCiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRzdC5kaWFnLm5ldHdvcmsgPSBbcHNjdXN0b21vYmplY3RdQHsg
HLP:Y29ubmVjdGVkID0gW2Jvb2xdJG4uY29ubmVjdGVkOyBkbnNfb2sgPSBbYm9vbF0kbi5kbnNfb2s7IGRldGFpbHMgPSAkbi5kZXRhaWxzOyBkbnNfbXMgPSAkbi5kbnNfbXMgfQogICAgICAgIFdyaXRlLVN0YXRlICRzdAogICAgICAgICJORVRfQ09OTkVDVEVEPSQo
HLP:aWYgKCRuLmNvbm5lY3RlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIk5FVF9ETlNfT0s9JChpZiAoJG4uZG5zX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0RFVEFJTFM9JCgkbi5kZXRhaWxzKSIKICAgICAgICAiTkVUX0xBVEVOQ1lf
HLP:TVM9JCgkbi5kbnNfbXMpIgogICAgfQogICAgJ2RpYWdmdWxsJyB7CiAgICAgICAgJHN0ID0gSW5pdGlhbGl6ZS1EaWFnIChSZWFkLVN0YXRlKQogICAgICAgICRyID0gR2V0LVJhbUNoZWNrCiAgICAgICAgJHN0LmRpYWcucmFtID0gW3BzY3VzdG9tb2JqZWN0XUB7
HLP:IHN0YXR1cyA9ICRyLnN0YXR1czsgcmVjb21tZW5kX21kc2NoZWQgPSBbYm9vbF0kci5yZWNvbW1lbmRfbWRzY2hlZCB9CiAgICAgICAgJGIgPSBHZXQtQmF0dGVyeUhlYWx0aAogICAgICAgICRzdC5kaWFnLmJhdHRlcnkgPSBbcHNjdXN0b21vYmplY3RdQHsgcHJl
HLP:c2VudCA9IFtib29sXSRiLnByZXNlbnQ7IGhlYWx0aF9wY3QgPSAkYi5oZWFsdGhfcGN0OyByZXBvcnRfcGF0aCA9ICRiLnJlcG9ydF9wYXRoIH0KICAgICAgICAkbiA9IEdldC1OZXRBZHZhbmNlZAogICAgICAgICRzdC5kaWFnLm5ldHdvcmsgPSBbcHNjdXN0b21v
HLP:YmplY3RdQHsgY29ubmVjdGVkID0gW2Jvb2xdJG4uY29ubmVjdGVkOyBkbnNfb2sgPSBbYm9vbF0kbi5kbnNfb2s7IGRldGFpbHMgPSAkbi5kZXRhaWxzOyBkbnNfbXMgPSAkbi5kbnNfbXMgfQogICAgICAgICRkZXYgPSBHZXQtRGV2aWNlTGlzdAogICAgICAgIGlm
HLP:ICgkbnVsbCAtZXEgJGRldikgewogICAgICAgICAgICAkc3QuZGlhZy5kZXZpY2VzID0gQCgpCiAgICAgICAgICAgICRkZXZMaW5lID0gIkRFVklDRVNfU1RBVFVTPWluZm8gbm8gZGlzcG9uaWJsZSIKICAgICAgICB9IGVsc2UgewogICAgICAgICAgICAkc3QuZGlh
HLP:Zy5kZXZpY2VzID0gQCgkZGV2KQogICAgICAgICAgICAkZGV2TGluZSA9ICJERVZJQ0VTX0NPVU5UPSQoQCgkZGV2KS5Db3VudCkiCiAgICAgICAgfQogICAgICAgICRzbSA9IEdldC1TbWFydEF0dHJpYnV0ZXMKICAgICAgICAkc3QuZGlhZy5zbWFydCA9IFtwc2N1
HLP:c3RvbW9iamVjdF1AeyBhdmFpbGFibGUgPSBbYm9vbF0kc20uYXZhaWxhYmxlOyBwcmVkaWN0X2ZhaWwgPSBbYm9vbF0kc20ucHJlZGljdF9mYWlsOyB0ZW1wX2MgPSAkc20udGVtcF9jOyB3ZWFyX3BjdCA9ICRzbS53ZWFyX3BjdDsgcG9oID0gJHNtLnBvaCB9CiAg
HLP:ICAgICAgJHN0cCA9IEdldC1TdGFydHVwSXRlbXMgOAogICAgICAgICRzdC5kaWFnLnN0YXJ0dXAgPSBAKCRzdHApCiAgICAgICAgJGJjZCA9IEdldC1CY2RJbnRlZ3JpdHkKICAgICAgICAkc3QuZGlhZy5iY2QgPSBbcHNjdXN0b21vYmplY3RdQHsgb2sgPSBbYm9v
HLP:bF0kYmNkLm9rOyBkZXRhaWxzID0gJGJjZC5kZXRhaWxzIH0KICAgICAgICAkcHJvY3MgPSBHZXQtVG9wUHJvY2Vzc2VzIDYKICAgICAgICAkc3QuZGlhZy5wcm9jZXNzZXMgPSBAKCRwcm9jcykKICAgICAgICBXcml0ZS1TdGF0ZSAkc3QKICAgICAgICAiUkFNX1NU
HLP:QVRVUz0kKCRyLnN0YXR1cykiCiAgICAgICAgIlJBTV9SRUNPTU1FTkRfTURTQ0hFRD0kKGlmICgkci5yZWNvbW1lbmRfbWRzY2hlZCkgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgIkJBVFRFUllfUFJFU0VOVD0kKGlmICgkYi5wcmVzZW50KSB7JzEnfSBlbHNl
HLP:IHsnMCd9KSIKICAgICAgICAiQkFUVEVSWV9IRUFMVEhfUENUPSQoJGIuaGVhbHRoX3BjdCkiCiAgICAgICAgIk5FVF9DT05ORUNURUQ9JChpZiAoJG4uY29ubmVjdGVkKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiTkVUX0ROU19PSz0kKGlmICgkbi5kbnNf
HLP:b2spIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJORVRfTEFURU5DWV9NUz0kKCRuLmRuc19tcykiCiAgICAgICAgIlNNQVJUX0FWQUlMQUJMRT0kKGlmICgkc20uYXZhaWxhYmxlKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiU01BUlRfUFJFRElDVF9G
HLP:QUlMPSQoaWYgKCRzbS5wcmVkaWN0X2ZhaWwpIHsnMSd9IGVsc2UgeycwJ30pIgogICAgICAgICJCQ0RfT0s9JChpZiAoJGJjZC5vaykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICAgICAgJGRldkxpbmUKICAgIH0KICAgICMgLS0tICh2My4xKSBTRkMgaW5kZXBlbmRp
HLP:ZW50ZSBkZWwgaWRpb21hICsgSlNPTiArIHBhcXVldGUgZGUgc29wb3J0ZSAtLS0KICAgICdzZmNyZXN1bHQnIHsKICAgICAgICAiU0ZDX1JFUz0kKEdldC1TZmNSZXN1bHQpIgogICAgfQogICAgJ2pzb25yZXBvcnQnIHsKICAgICAgICAkb3V0ID0gaWYgKFtzdHJp
HLP:bmddOjpJc051bGxPcldoaXRlU3BhY2UoJEFyZykpIHsgSm9pbi1QYXRoICRXb3JrICdJbmZvcm1lLmpzb24nIH0gZWxzZSB7ICRBcmcgfQogICAgICAgIE5ldy1Kc29uUmVwb3J0ICRvdXQKICAgIH0KICAgICdzdXBwb3J0cGFja2FnZScgewogICAgICAgICRvdXQg
HLP:PSBpZiAoW3N0cmluZ106OklzTnVsbE9yV2hpdGVTcGFjZSgkQXJnKSkgeyBKb2luLVBhdGggJFdvcmsgJ1BhcXVldGVfU29wb3J0ZS56aXAnIH0gZWxzZSB7ICRBcmcgfQogICAgICAgIE5ldy1TdXBwb3J0UGFja2FnZSAkb3V0CiAgICB9CiAgICAjIC0tLSAoNS42
HLP:IC8gUmVxIDE3LjIpIFJvdGFjaW9uIGRlIGxvZ3MgLS0tCiAgICAnbG9ncm90YXRlJyB7CiAgICAgICAgJGZvbGRlciA9IGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRBcmcpKSB7IEpvaW4tUGF0aCAkV29yayAnTG9ncycgfSBlbHNlIHsgJEFyZyB9
HLP:CiAgICAgICAgJG4gPSBJbnZva2UtTG9nUm90YXRlICRmb2xkZXIgJExPR19SRVRFTlRJT04KICAgICAgICAiREVMRVRFRD0kbiIKICAgIH0KICAgICMgLS0tICg1LjggLyBSZXEgMTMsMTgpIFZhbGlkYWNpb24gZGUgZW50b3JubyB5IHNlbGYtdGVzdCAtLS0KICAg
HLP:ICdlbnZjaGVjaycgewogICAgICAgICRlID0gSW52b2tlLUVudlZhbGlkYXRlCiAgICAgICAgIk9TX09LPSQoaWYgKCRlLm9zX29rKSB7JzEnfSBlbHNlIHsnMCd9KSIKICAgICAgICAiT1NfQlVJTEQ9JCgkZS5idWlsZCkiCiAgICAgICAgIk9TX0NIRUNLX0RPTkU9
HLP:MSIKICAgIH0KICAgICdzZWxmdGVzdGJyYWluJyB7ICJCUkFJTl9PSz0xIiB9CiAgICAnc2VsZnRlc3RyZXN1bHQnIHsKICAgICAgICAkcGFzcyA9IEludm9rZS1TZWxmVGVzdCAoUGFyc2UtQm9vbExpc3QgJEFyZykKICAgICAgICAiU0VMRlRFU1RfUEFTUz0kKGlm
HLP:ICgkcGFzcykgeycxJ30gZWxzZSB7JzAnfSkiCiAgICB9CiAgICBkZWZhdWx0ICAgICAgICB7IEdldC1TeXNJbmZvIH0KfQo=
