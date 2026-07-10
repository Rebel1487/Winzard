::SRC fase_03.body.cmd | Cuerpo de arranque de la fase 03 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase03, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase03. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 03 - CHKDSK%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "03" "CHKDSK" "Comprueba el sistema de archivos del disco C: en busca de errores."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase03 ) else ( call :menu_fase03 )
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
    call :title_of 03
    call :pshq addphase "03;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase03
if "%DRY%"=="1" ( call :dry "Comprobaria el disco %SystemDrive% con chkdsk /scan y, si hace falta, programaria CHKDSK" & exit /b 2 )
if "%QUICK%"=="1" (
    call :step "CHKDSK /scan en %SystemDrive% (solo escaneo, sin reparar)"
    chkdsk %SystemDrive% /scan > "%CAP%" 2>&1
    set "CHK=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!CHK!"=="0" ( call :ok "CHKDSK /scan sin errores en %SystemDrive%" & exit /b 0 )
    call :warn "CHKDSK /scan detecto inconsistencias en %SystemDrive% (codigo !CHK!)"
    exit /b 1
)
call :step "CHKDSK /scan /perf en %SystemDrive% (rapido, en caliente)"
chkdsk %SystemDrive% /scan /perf > "%CAP%" 2>&1
set "CHK=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!CHK!"=="0" ( call :ok "CHKDSK sin errores en %SystemDrive%" & exit /b 0 )
call :warn "CHKDSK detecto inconsistencias (codigo !CHK!)"
if "%MODE_AUTO%"=="0" (
    choice /M "Programar comprobacion profunda al proximo reinicio"
    if !errorlevel! equ 2 ( set "PH_NOTE=chkdsk profundo no programado (usuario)" & exit /b 1 )
)
call :step "Programando la comprobacion de disco para el proximo reinicio (independiente del idioma)"
fsutil dirty set %SystemDrive% >nul 2>&1
fsutil dirty query %SystemDrive% > "%CAP%" 2>&1
set "DIRTY=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!DIRTY!"=="0" (
    call :pshq finding "Comprobacion de disco (CHKDSK) programada para el proximo reinicio"
    set "PH_NOTE=chkdsk programado (proximo reinicio)"
    call :ok "Comprobacion de disco programada para el proximo reinicio"
    exit /b 1
)
call :warn "No se pudo marcar el volumen para CHKDSK (fsutil no confirmo el bit dirty)"
set "PH_NOTE=no se pudo programar chkdsk"
exit /b 1
