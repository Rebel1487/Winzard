::SRC fase_05.body.cmd | Cuerpo de arranque of the phase 05 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase05, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase05. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 05 - DISM%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "05" "DISM" "Repairs the Windows component image (the source SFC relies on)."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase05 ) else ( call :menu_fase05 )
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


:Fase05
if "%DRY%"=="1" ( call :dry "Would repair the component image with DISM /RestoreHealth" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "DISM /CheckHealth (quick scan only)"
    dism /online /cleanup-image /checkhealth > "%CAP%" 2>&1
    set "D=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!D!"=="0" (
        call :ok "Component image healthy (CheckHealth)"
        exit /b 0
    ) else (
        call :warn "DISM detected corruption in the component store (code !D!)"
        exit /b 1
    )
)

call :step "DISM CheckHealth"
dism /online /cleanup-image /checkhealth >> "%LOGFILE%" 2>&1
call :step "DISM ScanHealth (several minutes)"
dism /online /cleanup-image /scanhealth >> "%LOGFILE%" 2>&1

call :step "DISM RestoreHealth (may take a while)"
set "DISM_OK=0"
set "RESTORE_SOURCE=%CUSTOM_SOURCE%"
if not "!RESTORE_SOURCE!"=="" (
    call :step "Using forced custom source: !RESTORE_SOURCE!"
) else (
    call :psh findlocalsource > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "LOCSRC="
    for /f "tokens=1,* delims==" %%A in (%CAP%) do (
        if "%%A"=="SOURCE" set "LOCSRC=%%B"
    )
    if not "!LOCSRC!"=="" (
        set "RESTORE_SOURCE=!LOCSRC!"
        call :step "Local offline source found: !RESTORE_SOURCE!"
    ) else (
        ping 1.1.1.1 -n 1 -w 1500 >nul 2>&1
        if !errorlevel! neq 0 call :warn "No Internet or local offline source: DISM may hit the timeout"
    )
)
call :psh dismrestore "!RESTORE_SOURCE!|45" > "%CAP%" 2>&1
set "D=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
for /f "tokens=1,* delims==" %%A in (%CAP%) do (
    if "%%A"=="EXITCODE" set "D=%%B"
    if "%%A"=="TIMEDOUT" set "DISM_TIMEDOUT=%%B"
)

if "!D!"=="0" (
    set "DISM_OK=1"
    call :ok "Component image repaired (DISM)"
) else (
    if "!DISM_TIMEDOUT!"=="1" (
        call :warn "DISM RestoreHealth hit the safety timeout (45 min)"
        set "PH_NOTE=DISM timeout"
    ) else (
        set "PH_NOTE=DISM failed code !D!"
        call :warn "DISM RestoreHealth failed (code !D!). Check the log."
    )
)

call :step "Freeing space from the component store"
if "%RESETBASE%"=="1" (
    call :step "Deep component cleanup with /ResetBase"
    dism /online /cleanup-image /startcomponentcleanup /ResetBase >> "%LOGFILE%" 2>&1
) else (
    dism /online /cleanup-image /startcomponentcleanup >> "%LOGFILE%" 2>&1
)
set "CLEANRC=!errorlevel!"
if not "!CLEANRC!"=="0" ( call :warn "Component store cleanup finished with code !CLEANRC!" & if "!DISM_OK!"=="1" exit /b 1 )
if "!DISM_OK!"=="1" ( call :ok "Component store optimized" & exit /b 0 )
call :warn "DISM could not confirm component image repair"
exit /b 1
