::SRC fase_13.body.cmd | Cuerpo de arranque of the phase 13 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase13, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase13. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 13 - Windows Update%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "13" "Windows Update" "Repairs Windows Update (services and cache). Honors /keepwu."
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
rem (v3.2) single phase: record result in state and generate the HTML report
if not "%DRY%"=="1" (
    call :title_of 13
    call :pshq addphase "13;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase13
call :step "Checking whether Windows Update is intentionally blocked"
set "WU_BLOCKED=0"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate >nul 2>&1 && set "WU_BLOCKED=1"
sc query wuauserv | findstr /i "DISABLED" >nul 2>&1 && set "WU_BLOCKED=1"
if "!WU_BLOCKED!"=="1" if "%KEEPWU%"=="1" ( call :info "WU blocked and /keepwu requested: respected and phase skipped" & set "PH_NOTE=WU block respected" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Checking Windows Update service status (scan only)"
    sc query wuauserv > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    findstr /i "RUNNING" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :ok "wuauserv service is running"
        exit /b 0
    )
    findstr /i "STOPPED" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :step "Trying to start wuauserv (service check only)"
        net start wuauserv > "%CAP%" 2>&1
        type "%CAP%" >> "%LOGFILE%"
        if !errorlevel! equ 0 (
            call :ok "wuauserv service started successfully"
            exit /b 0
        )
    )
    call :warn "The Windows Update service is not running or is disabled"
    exit /b 1
)

if "%DRY%"=="1" ( call :dry "Would repair Windows Update services and cache" & exit /b 2 )
call :step "Stopping Windows Update services"
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop appidsvc /y >nul 2>&1
net stop cryptsvc /y >nul 2>&1
net stop msiserver /y >nul 2>&1

call :step "Cleaning BITS job data (qmgr*.dat)"
del /f /q "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1
del /f /q "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1

call :step "Backing up and clearing cache (SoftwareDistribution, catroot2)"
set "WU_WARN=0"
if exist "%SystemRoot%\SoftwareDistribution" (
    move "%SystemRoot%\SoftwareDistribution" "%BKDIR%\SoftwareDistribution_%TIMESTAMP%" >nul 2>&1
    call :psh moveresult "%SystemRoot%\SoftwareDistribution|%BKDIR%\SoftwareDistribution_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "Could not move SoftwareDistribution" )
)
rem (v3.2) catroot2 is often locked by cryptsvc for a few seconds: retries with waits
set "CAT_EXISTS=0"
if exist "%SystemRoot%\System32\catroot2" set "CAT_EXISTS=1"
if "!CAT_EXISTS!"=="1" (
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
)
if "!CAT_EXISTS!"=="1" if exist "%SystemRoot%\System32\catroot2" (
    call :step "catroot2 busy: second attempt after a short pause"
    net stop cryptsvc /y >nul 2>&1
    ping 127.0.0.1 -n 5 >nul
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
)
if "!CAT_EXISTS!"=="1" if exist "%SystemRoot%\System32\catroot2" (
    call :step "catroot2 busy: third attempt after a longer pause"
    net stop cryptsvc /y >nul 2>&1
    ping 127.0.0.1 -n 9 >nul
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
)
if "!CAT_EXISTS!"=="1" (
    call :psh moveresult "%SystemRoot%\System32\catroot2|%BKDIR%\catroot2_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "Could not move catroot2 (3 attempts)" )
)

call :step "Removing stale WSUS client settings"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f >nul 2>&1

call :step "Re-registering Windows Update and BITS DLLs"
pushd "%SystemRoot%\System32"
for %%D in (atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll wuwebv.dll) do (
    regsvr32 /s %%D >> "%LOGFILE%" 2>&1
)
popd

call :step "Restarting services"
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start appidsvc >nul 2>&1
net start wuauserv >nul 2>&1
set "WUSTART=!errorlevel!"
net start msiserver >nul 2>&1

if "!WUSTART!" neq "0" (
    call :warn "The wuauserv service could not start after DLL registration"
    set "WU_WARN=1"
)

call :step "Forcing update discovery"
wuauclt /resetauthorization /detectnow >nul 2>&1

if "!WU_WARN!"=="1" ( set "PH_NOTE=cache not moved or service failed" & call :warn "Windows Update: cache not moved or wuauserv did not start" & exit /b 1 )
call :ok "Windows Update repaired: cache cleared, DLLs registered, discovery forced"
exit /b 0
