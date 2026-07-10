::SRC fase_13.body.cmd | Cuerpo de arranque de la fase 13 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase13, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase13. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
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
