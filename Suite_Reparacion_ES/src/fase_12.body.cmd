::SRC fase_12.body.cmd | Cuerpo de arranque de la fase 12 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase12, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase12. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 12 - Directivas (GPO)%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "12" "Directivas (GPO)" "Reaplica las directivas de grupo para deshacer politicas mal aplicadas."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase12 ) else ( call :menu_fase12 )
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
    call :title_of 12
    call :pshq addphase "12;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase12
if "%DRY%"=="1" ( call :dry "Reaplicaria las directivas de grupo (gpupdate /force)" & exit /b 2 )
call :step "Reaplicando directivas de grupo"
gpupdate /force >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 ( call :warn "gpupdate /force devolvio error. Revisa el log." & set "PH_NOTE=gpupdate con error" & exit /b 1 )
call :ok "Directivas reaplicadas y verificadas (gpupdate /force)"
exit /b 0
