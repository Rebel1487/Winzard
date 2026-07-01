::SRC fase_06.body.cmd | Cuerpo de arranque de la fase 06 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase06, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase06. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 06 - SFC y verificacion%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "06" "SFC y verificacion" "Repara archivos de sistema y verifica el resultado tras DISM."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase06 ) else ( call :menu_fase06 )
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


:Fase06
if "%DRY%"=="1" ( call :dry "Ejecutaria SFC /scannow y verificaria con una segunda pasada" & exit /b 2 )
if "%QUICK%"=="1" (
    call :step "SFC /verifyonly (solo verificacion rapida, sin reparar)"
    sfc /verifyonly > "%CAP%" 2>&1
    set "SFCRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    call :sfc_classify !SFCRC!
    if "!SFC_RES!"=="clean" (
        call :ok "SFC: sin violaciones de integridad"
        exit /b 0
    ) else (
        call :warn "SFC detecto problemas de integridad en modo solo verificacion"
        exit /b 1
    )
)
call :substep 1 2 "SFC /scannow (primera pasada)"
sfc /scannow > "%CAP%" 2>&1
set "SFCRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :sfc_classify !SFCRC!
if "!SFC_RES!"=="clean" ( call :ok "SFC: sin violaciones de integridad" & exit /b 0 )
if "!SFC_RES!"=="unrepairable" ( call :warn "SFC: danos no reparables. Ejecuta la fase DISM (05) y reintenta." & call :pshq finding "SFC: danos de sistema no reparables (requiere DISM)" & set "PH_NOTE=danos no reparables" & exit /b 1 )
if not "!SFC_RES!"=="repaired" ( call :warn "Resultado de SFC indeterminado. Revisa CBS.log." & set "PH_NOTE=resultado SFC indeterminado" & exit /b 1 )
call :warn "SFC reparo archivos. Reinicia y vuelve a ejecutar la fase 06 para verificar sin bloquear esta sesion."
call :pshq finding "SFC: archivos reparados; requiere reinicio/reverificacion"
set "PH_NOTE=archivos reparados por SFC; requiere reverificacion"
exit /b 1
