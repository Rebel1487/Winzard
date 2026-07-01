::SRC fase_01.body.cmd | Cuerpo de arranque of the phase 01 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase01, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase01. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 01 - Restore point%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "01" "Restore point" "Creates a restore point and backs up the registry so you can roll back."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase01 ) else ( call :menu_fase01 )
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


:Fase01
if "%DRY%"=="1" ( call :dry "Would create a restore point and back up the registry" & exit /b 2 )
call :step "Creating restore point (may take a while)"
call :psh restorepoint > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /c:"RESULT=OK" "%CAP%" >nul 2>&1
if !errorlevel! equ 0 ( call :ok "Restore point created and verified" ) else ( call :warn "Could not create the restore point (continuing anyway)" )
call :step "Backing up the registry (SOFTWARE and SYSTEM)"
reg export HKLM\SOFTWARE "%BKDIR%\SOFTWARE_%TIMESTAMP%.reg" /y >nul 2>&1
reg export HKLM\SYSTEM "%BKDIR%\SYSTEM_%TIMESTAMP%.reg" /y >nul 2>&1
call :info "Registry backup requested in Backups"

call :step "Verifying safety net and backups"
call :psh checkbackups "%BKDIR%|%TIMESTAMP%" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"

set "RP_OK=0"
set "REG_OK=0"
for /f "tokens=1,2 delims==" %%A in (%CAP%) do (
    if "%%A"=="RP_OK" set "RP_OK=%%B"
    if "%%A"=="REG_OK" set "REG_OK=%%B"
)

if "!RP_OK!"=="1" if "!REG_OK!"=="1" (
    call :ok "Safety net verified (Restore point and registry backups OK)"
    exit /b 0
)

echo(
call :warn "SAFETY NET FAILED:"
if "!RP_OK!"=="0" echo   [X] Could not create/verify the Restore Point.
if "!REG_OK!"=="0" echo   [X] The registry backups (.reg) are missing or empty.
echo(

if "%MODE_AUTO%"=="1" (
    call :err "Unattended mode: aborting execution for safety."
    exit /b 3
)

echo %YE%[!] WARNING: Continuing without a safety net is risky.%R%
choice /C SC /M "Press [S] to exit/abort or [C] to continue at your own risk"
if !errorlevel! equ 1 (
    call :err "Cancelled by the user."
    exit /b 3
) else (
    call :warn "Continuing without a safety net by user choice."
    exit /b 0
)
