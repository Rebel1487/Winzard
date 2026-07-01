::SRC fase_06.body.cmd | Cuerpo de arranque of the phase 06 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase06, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase06. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 06 - SFC and verification%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "06" "SFC and verification" "Repairs system files and verifies the result after DISM."
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
echo    Result: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %RC%


:Fase06
if "%DRY%"=="1" ( call :dry "Would run SFC /scannow and verify with a second pass" & exit /b 2 )
if "%QUICK%"=="1" (
    call :step "SFC /verifyonly (quick check only, no repair)"
    sfc /verifyonly > "%CAP%" 2>&1
    set "SFCRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    call :sfc_classify !SFCRC!
    if "!SFC_RES!"=="clean" (
        call :ok "SFC: no integrity violations found"
        exit /b 0
    ) else (
        call :warn "SFC detected integrity issues in verification-only mode"
        exit /b 1
    )
)
call :substep 1 2 "SFC /scannow (first pass)"
sfc /scannow > "%CAP%" 2>&1
set "SFCRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :sfc_classify !SFCRC!
if "!SFC_RES!"=="clean" ( call :ok "SFC: no integrity violations found" & exit /b 0 )
if "!SFC_RES!"=="unrepairable" ( call :warn "SFC: unrepairable damage. Run phase DISM (05) and retry." & call :pshq finding "SFC: unrepairable system damage (requires DISM)" & set "PH_NOTE=unrepairable damage" & exit /b 1 )
if not "!SFC_RES!"=="repaired" ( call :warn "Undetermined SFC result. Review CBS.log." & set "PH_NOTE=undetermined SFC result" & exit /b 1 )
call :warn "SFC repaired files. Reboot and run phase 06 again to verify without blocking this session."
call :pshq finding "SFC: files repaired; reboot/reverification required"
set "PH_NOTE=files repaired by SFC; reverification required"
exit /b 1
