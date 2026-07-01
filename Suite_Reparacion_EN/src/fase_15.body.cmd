::SRC fase_15.body.cmd | Cuerpo de arranque of the phase 15 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase15, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase15. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 15 - Devices%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "15" "Devices" "Lists drivers/devices with errors so you know what to check."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase15 ) else ( call :menu_fase15 )
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
echo    Result: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %RC%


:Fase15
call :step "Looking for devices or drivers with errors"
call :psh devices > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /b /c:"OK|" "%CAP%" >nul 2>&1
if !errorlevel! equ 0 ( call :ok "No devices with problems" & exit /b 0 )
set "DEVN=0"
for /f "usebackq tokens=1-3 delims=|" %%a in ("%CAP%") do (
    if /i "%%a"=="PROB" ( set /a "DEVN+=1" & echo     %YE%[dev ]%R%  code %%b  -  %%c & >>"%LOGFILE%" echo     [dev] code %%b - %%c )
)
call :warn "There are !DEVN! device(s) with errors. Update their driver from the maker's site."
set "PH_NOTE=!DEVN! devices with errors"
exit /b 1
