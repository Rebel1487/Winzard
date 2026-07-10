::SRC fase_00.body.cmd | Cuerpo de arranque of the phase 00 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase00, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase00. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 00 - Diagnostics and triage%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "00" "Diagnostics and triage" "Checks disks, space and events, and finds the root cause."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase00 ) else ( call :menu_fase00 )
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
    call :title_of 00
    call :pshq addphase "00;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase00
set "DIAG_RC=0"
call :step "Checking disk SMART health"
powershell -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus | Format-Table -AutoSize" > "%CAP%" 2>&1
type "%CAP%"
type "%CAP%" >> "%LOGFILE%"
findstr /i "Unhealthy Warning" "%CAP%" >nul 2>&1 && ( set "DIAG_RC=1" & call :warn "A disk reports degraded SMART. Back up your data before continuing." & call :pshq finding "Disk with degraded SMART" )
call :step "Free space on C:"
set "FREE_GB=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB)"`) do set "FREE_GB=%%a"
call :info "C: has !FREE_GB! GB free"
if !FREE_GB! lss 10 ( set "DIAG_RC=1" & call :warn "Low free space on C: (!FREE_GB! GB)" & call :pshq finding "Low free space on C: (!FREE_GB! GB)" )
call :step "Checking for a pending reboot"
set "PENDREB=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "PENDREB=1"
if "!PENDREB!"=="1" ( set "DIAG_RC=1" & call :warn "There is a pending reboot. It's best to reboot before repairing." ) else ( call :ok "No pending reboots" )
call :step "Recent critical events (root cause, last 7 days)"
call :psh forensics > "%CAP%" 2>&1
for /f "usebackq tokens=1-4 delims=|" %%a in ("%CAP%") do (
    if /i "%%a"=="OK" ( call :ok "No critical errors in 7 days" ) else ( set "DIAG_RC=1" & echo     %DIM%%%a  [id %%b]  %%c  %%d%R% & >>"%LOGFILE%" echo     %%a [id %%b] %%c %%d )
)
call :step "Extended diagnosis (RAM, battery, network, SMART, boot)"
call :psh diagfull > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "RAM_STATUS=" & set "BATTERY_PRESENT=" & set "BATTERY_HEALTH_PCT=" & set "NET_CONNECTED=" & set "NET_DNS_OK=" & set "NET_LATENCY_MS=" & set "SMART_PREDICT_FAIL=" & set "BCD_OK="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"RAM_STATUS=" "%CAP%"`) do set "RAM_STATUS=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"BATTERY_PRESENT=" "%CAP%"`) do set "BATTERY_PRESENT=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"BATTERY_HEALTH_PCT=" "%CAP%"`) do set "BATTERY_HEALTH_PCT=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"NET_CONNECTED=" "%CAP%"`) do set "NET_CONNECTED=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"NET_DNS_OK=" "%CAP%"`) do set "NET_DNS_OK=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"NET_LATENCY_MS=" "%CAP%"`) do set "NET_LATENCY_MS=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SMART_PREDICT_FAIL=" "%CAP%"`) do set "SMART_PREDICT_FAIL=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"BCD_OK=" "%CAP%"`) do set "BCD_OK=%%a"
if /i "!RAM_STATUS!"=="suspect" ( set "DIAG_RC=1" & call :warn "RAM looks suspicious: run the memory diagnostic (mdsched)." & call :pshq finding "RAM suspicious: run mdsched" )
if "!SMART_PREDICT_FAIL!"=="1" ( set "DIAG_RC=1" & call :warn "SMART predicts a possible disk failure: back up your data as soon as possible." & call :pshq finding "SMART predicts a possible disk failure" )
if "!NET_CONNECTED!"=="0" ( set "DIAG_RC=1" & call :warn "No network connectivity detected." & call :pshq finding "No network connectivity" )
if "!NET_CONNECTED!"=="1" if "!NET_DNS_OK!"=="0" ( set "DIAG_RC=1" & call :warn "There is a connection but DNS resolution fails." & call :pshq finding "DNS failing" )
if "!BATTERY_PRESENT!"=="1" if defined BATTERY_HEALTH_PCT if !BATTERY_HEALTH_PCT! lss 60 ( set "DIAG_RC=1" & call :warn "Battery degraded (!BATTERY_HEALTH_PCT!%% health)." & call :pshq finding "Battery degraded (!BATTERY_HEALTH_PCT!%% health)" )
if defined NET_LATENCY_MS if "!NET_DNS_OK!"=="1" call :info "DNS latency: !NET_LATENCY_MS! ms"
call :ok "Extended diagnosis completed"
if "!DIAG_RC!"=="1" ( call :warn "Diagnosis completed with findings. Review warnings and log." & exit /b 1 )
call :ok "Initial diagnosis completed"
exit /b 0
