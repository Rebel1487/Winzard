::SRC fase_03.body.cmd | Cuerpo de arranque of the phase 03 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase03, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase03. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 03 - CHKDSK%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "03" "CHKDSK" "Checks the C: drive file system for errors."
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
echo(
echo %BL%------------------------------------------------------------%R%
echo    Result: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %RC%


:Fase03
if "%DRY%"=="1" ( call :dry "Would check %SystemDrive% with chkdsk /scan and, if needed, schedule CHKDSK" & exit /b 2 )
if "%QUICK%"=="1" (
    call :step "CHKDSK /scan on %SystemDrive% (scan only, no repair)"
    chkdsk %SystemDrive% /scan > "%CAP%" 2>&1
    set "CHK=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!CHK!"=="0" ( call :ok "CHKDSK /scan found no errors on %SystemDrive%" & exit /b 0 )
    call :warn "CHKDSK /scan detected inconsistencies on %SystemDrive% (code !CHK!)"
    exit /b 1
)
call :step "CHKDSK /scan /perf on %SystemDrive% (fast, online)"
chkdsk %SystemDrive% /scan /perf > "%CAP%" 2>&1
set "CHK=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!CHK!"=="0" ( call :ok "CHKDSK found no errors on %SystemDrive%" & exit /b 0 )
call :warn "CHKDSK detected inconsistencies (code !CHK!)"
if "%MODE_AUTO%"=="0" (
    choice /M "Schedule a deep check at the next reboot"
    if !errorlevel! equ 2 ( set "PH_NOTE=deep chkdsk not scheduled (user)" & exit /b 1 )
)
call :step "Scheduling the disk check for the next reboot (language-independent)"
fsutil dirty set %SystemDrive% >nul 2>&1
fsutil dirty query %SystemDrive% > "%CAP%" 2>&1
set "DIRTY=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!DIRTY!"=="0" (
    call :pshq finding "Disk check (CHKDSK) scheduled for the next reboot"
    set "PH_NOTE=chkdsk scheduled (next reboot)"
    call :ok "Disk check scheduled for the next reboot"
    exit /b 1
)
call :warn "Could not mark the volume for CHKDSK (fsutil did not confirm the dirty bit)"
set "PH_NOTE=could not schedule chkdsk"
exit /b 1
