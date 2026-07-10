::SRC fase_11.body.cmd | Cuerpo de arranque de la fase 11 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase11, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase11. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 11 - Red%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "11" "Red" "Reinicia winsock, IP, DNS y proxy, y revisa el archivo hosts."
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
rem (v3.2) fase suelta: registrar resultado en el estado y generar informe HTML
if not "%DRY%"=="1" (
    call :title_of 11
    call :pshq addphase "11;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase11
if "%DRY%"=="1" ( call :dry "Reiniciaria winsock, IP, DNS y proxy" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Ping de prueba a DNS publico (solo escaneo)"
    ping 1.1.1.1 -n 1 -w 1500 > "%CAP%" 2>&1
    set "P1=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!P1!"=="0" (
        call :ok "Conectividad a Internet OK (ping a 1.1.1.1)"
        exit /b 0
    ) else (
        ping 8.8.8.8 -n 1 -w 1500 > "%CAP%" 2>&1
        set "P2=!errorlevel!"
        type "%CAP%" >> "%LOGFILE%"
        if "!P2!"=="0" (
            call :ok "Conectividad a Internet OK (ping a 8.8.8.8)"
            exit /b 0
        ) else (
            call :warn "Fallo de ping a servidores DNS publicos (sin conexion o bloqueado)"
            exit /b 1
        )
    )
)

set "NET_RC=0"
call :step "Reiniciando Winsock e IP"
netsh winsock reset >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 ( call :warn "netsh winsock reset devolvio error (revisa el log)" & set "NET_RC=1" )
netsh int ip reset >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 call :info "netsh int ip reset devolvio avisos (claves protegidas; suele ser normal)"
call :step "Renovando DHCP y vaciando DNS"
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
ipconfig /flushdns >nul 2>&1
call :step "Quitando proxy de WinHTTP"
netsh winhttp reset proxy >> "%LOGFILE%" 2>&1

call :step "Purgando tablas ARP y rutas de red"
arp -d * >> "%LOGFILE%" 2>&1
route -f >> "%LOGFILE%" 2>&1

if "%FWRESET%"=="1" (
    call :step "Restableciendo el Firewall de Windows (/fwreset)"
    netsh advfirewall reset >> "%LOGFILE%" 2>&1
    if !errorlevel! equ 0 ( call :ok "Firewall restablecido a los valores predeterminados" ) else ( call :warn "netsh advfirewall reset devolvio error (revisa el log)" & set "NET_RC=1" )
)

call :step "Revisando el archivo hosts"
findstr /v /b "#" "%SystemRoot%\System32\drivers\etc\hosts" | findstr /r "[0-9]" >nul 2>&1
if !errorlevel! equ 0 ( call :warn "El archivo hosts tiene entradas activas. Revisalo por si bloquea webs." ) else ( call :ok "Archivo hosts limpio" )
set "PH_NOTE=winsock/ip reset; requiere reinicio"
if "!NET_RC!"=="1" ( call :warn "Pila de red restablecida con avisos: revisa el log" & exit /b 1 )
call :ok "Pila de red restablecida (winsock requiere reinicio)"
exit /b 0
