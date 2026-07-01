::SRC fase_16.body.cmd | Cuerpo de arranque de la fase 16 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase16, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase16. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 16 - Limpieza final e informe%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "16" "Limpieza final e informe" "Limpieza profunda, recalcula la salud y genera el informe HTML."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase16 ) else ( call :menu_fase16 )
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


:Fase16
if "%DRY%"=="0" (
    call :step "Limpieza profunda final"
    del /f /q /s "%SystemRoot%\Logs\CBS\CbsPersist_*.log" >nul 2>&1
    rem (v3.1) liberar espacio: logs de instalacion antiguos (seguros de borrar)
    del /f /q "%SystemRoot%\Panther\*.log" >nul 2>&1
    del /f /q "%SystemRoot%\inf\setupapi.dev.log" >nul 2>&1
    del /f /q "%SystemRoot%\inf\setupapi.setup.log" >nul 2>&1
    ipconfig /flushdns >nul 2>&1
)
call :step "Recalculando la salud del sistema"
call :psh score > "%CAP%" 2>&1
set "SCORE_AFTER="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SCORE=" "%CAP%"`) do set "SCORE_AFTER=%%a"
if defined SCORE_AFTER ( call :pshq setafter "!SCORE_AFTER!" & call :info "Salud despues: !SCORE_AFTER!/100" )
call :step "Generando informe HTML"
set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
call :psh report "%REPORT%"
if exist "%REPORT%" ( call :ok "Informe creado en !REPORT!" & set "PH_NOTE=informe HTML generado" ) else ( call :warn "No se pudo generar el informe HTML" )
exit /b 0
