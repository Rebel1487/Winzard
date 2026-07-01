::SRC fase_04.body.cmd | Cuerpo de arranque de la fase 04 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase04, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase04. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 04 - Optimizacion de disco%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "04" "Optimizacion de disco" "TRIM si es SSD o desfragmenta si es HDD, segun el tipo de disco."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase04 ) else ( call :menu_fase04 )
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


:Fase04
if "%DRY%"=="1" ( call :dry "Optimizaria el disco (TRIM si SSD, desfrag si HDD; nada si el tipo es incierto)" & exit /b 2 )
call :step "Detectando el tipo del disco del sistema"
call :psh mediatype > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "MEDIA=" & set "OPTIMIZE="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MEDIA=" "%CAP%"`) do set "MEDIA=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OPTIMIZE=" "%CAP%"`) do set "OPTIMIZE=%%a"
call :info "Tipo de disco: !MEDIA!  (accion recomendada: !OPTIMIZE!)"
if /i "!OPTIMIZE!"=="TRIM" (
    call :step "SSD detectado: enviando TRIM"
    powershell -NoProfile -Command "Optimize-Volume -DriveLetter %SystemDrive:~0,1% -ReTrim -Verbose" >> "%LOGFILE%" 2>&1
    set "PH_NOTE=TRIM enviado (SSD)"
    call :ok "TRIM completado en %SystemDrive%"
    exit /b 0
)
if /i "!OPTIMIZE!"=="DEFRAG" (
    call :step "HDD detectado: desfragmentando %SystemDrive% (puede tardar)"
    powershell -NoProfile -Command "Optimize-Volume -DriveLetter %SystemDrive:~0,1% -Defrag -Verbose" >> "%LOGFILE%" 2>&1
    set "PH_NOTE=desfragmentado (HDD)"
    call :ok "Desfragmentacion completada en %SystemDrive%"
    exit /b 0
)
call :warn "Tipo de disco indeterminado: no se optimiza para no arriesgar un SSD"
set "PH_NOTE=tipo de disco indeterminado; no se optimiza"
exit /b 1
