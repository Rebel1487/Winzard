::SRC fase_11.body.cmd | Cuerpo de arranque of the phase 11 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase11, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase11. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
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
