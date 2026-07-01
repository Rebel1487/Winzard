::SRC fase_00.body.cmd | Cuerpo de arranque de la fase 00 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase00, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase00. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 00 - Diagnostico y triage%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "00" "Diagnostico y triage" "Mira discos, espacio y eventos, y detecta la causa raiz."
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
echo(
echo %BL%------------------------------------------------------------%R%
echo    Resultado: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b %RC%


:Fase00
set "DIAG_RC=0"
call :step "Comprobando salud SMART de los discos"
powershell -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus | Format-Table -AutoSize" > "%CAP%" 2>&1
type "%CAP%"
type "%CAP%" >> "%LOGFILE%"
findstr /i "Unhealthy Warning" "%CAP%" >nul 2>&1 && ( set "DIAG_RC=1" & call :warn "Algun disco reporta SMART degradado. Haz copia de tus datos antes de seguir." & call :pshq finding "Disco con SMART degradado" )
call :step "Espacio libre en C:"
set "FREE_GB=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB)"`) do set "FREE_GB=%%a"
call :info "C: tiene !FREE_GB! GB libres"
if !FREE_GB! lss 10 ( set "DIAG_RC=1" & call :warn "Poco espacio libre en C: (!FREE_GB! GB)" & call :pshq finding "Poco espacio libre en C: (!FREE_GB! GB)" )
call :step "Comprobando reinicio pendiente"
set "PENDREB=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "PENDREB=1"
if "!PENDREB!"=="1" ( set "DIAG_RC=1" & call :warn "Hay un reinicio pendiente. Lo ideal es reiniciar antes de reparar." ) else ( call :ok "Sin reinicios pendientes" )
call :step "Eventos criticos recientes (causa raiz, ultimos 7 dias)"
call :psh forensics > "%CAP%" 2>&1
for /f "usebackq tokens=1-4 delims=|" %%a in ("%CAP%") do (
    if /i "%%a"=="OK" ( call :ok "Sin errores criticos en 7 dias" ) else ( set "DIAG_RC=1" & echo     %DIM%%%a  [id %%b]  %%c  %%d%R% & >>"%LOGFILE%" echo     %%a [id %%b] %%c %%d )
)
call :step "Diagnostico ampliado (RAM, bateria, red, SMART, arranque)"
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
if /i "!RAM_STATUS!"=="suspect" ( set "DIAG_RC=1" & call :warn "La RAM parece sospechosa: ejecuta el diagnostico de memoria (mdsched)." & call :pshq finding "RAM sospechosa: ejecutar mdsched" )
if "!SMART_PREDICT_FAIL!"=="1" ( set "DIAG_RC=1" & call :warn "SMART predice un posible fallo de disco: respalda tus datos cuanto antes." & call :pshq finding "SMART predice un posible fallo de disco" )
if "!NET_CONNECTED!"=="0" ( set "DIAG_RC=1" & call :warn "Sin conectividad de red detectada." & call :pshq finding "Sin conectividad de red" )
if "!NET_CONNECTED!"=="1" if "!NET_DNS_OK!"=="0" ( set "DIAG_RC=1" & call :warn "Hay conexion pero la resolucion DNS falla." & call :pshq finding "DNS con fallos" )
if "!BATTERY_PRESENT!"=="1" if defined BATTERY_HEALTH_PCT if !BATTERY_HEALTH_PCT! lss 60 ( set "DIAG_RC=1" & call :warn "Bateria degradada (!BATTERY_HEALTH_PCT!%% de salud)." & call :pshq finding "Bateria degradada (!BATTERY_HEALTH_PCT!%% de salud)" )
if defined NET_LATENCY_MS if "!NET_DNS_OK!"=="1" call :info "Latencia DNS: !NET_LATENCY_MS! ms"
call :ok "Diagnostico ampliado completado"
if "!DIAG_RC!"=="1" ( call :warn "Diagnostico completado con hallazgos. Revisa avisos y log." & exit /b 1 )
call :ok "Diagnostico previo completado"
exit /b 0
