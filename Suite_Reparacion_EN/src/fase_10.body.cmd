::SRC fase_10.body.cmd | Cuerpo de arranque of the phase 10 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase10, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase10. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 10 - Certificates and time%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "10" "Certificates and time" "Refreshes root certificates and syncs the clock (fixes WU/Store/cert)."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase10 ) else ( call :menu_fase10 )
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
rem (v3.2) single phase: record result in state and generate the HTML report
if not "%DRY%"=="1" (
    call :title_of 10
    call :pshq addphase "10;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
    set "REPORT=%WORK%\Report_%TIMESTAMP%.html"
    call :psh report "!REPORT!" >nul 2>&1
)
echo(
echo %BL%------------------------------------------------------------%R%
echo    Result: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
if exist "!REPORT!" echo    %WH%Report:%R% !REPORT!
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %RC%


:Fase10
if "%DRY%"=="1" ( call :dry "Would sync the clock and refresh the root certificates" & exit /b 2 )
call :step "Synchronizing the system clock"
net start w32time >nul 2>&1
w32tm /resync /force >> "%LOGFILE%" 2>&1
set "TIME_OK=1"
if !errorlevel! neq 0 ( set "TIME_OK=0" & call :warn "w32tm /resync returned an error (no network or time service stopped)" )
call :step "Updating trusted root certificates"
certutil -generateSSTFromWU "%WORK%\roots.sst" >> "%LOGFILE%" 2>&1
set "CERT_OK=0"
if exist "%WORK%\roots.sst" (
    powershell -NoProfile -Command "try { Import-Certificate -FilePath '%WORK%\roots.sst' -CertStoreLocation Cert:\LocalMachine\Root -ErrorAction Stop | Out-Null; exit 0 } catch { Write-Output $_.Exception.Message; exit 1 }" >> "%LOGFILE%" 2>&1
    if !errorlevel! equ 0 ( set "CERT_OK=1" ) else ( call :warn "Could not import the root certificates (check the log)" & set "PH_NOTE=certificate import failed" )
) else (
    call :warn "Could not download root certificates (no Internet)."
    set "PH_NOTE=no Internet for certificates"
)
if "!CERT_OK!"=="1" if "!TIME_OK!"=="1" ( call :ok "Root certificates refreshed and clock synchronized (verified)" & exit /b 0 )
if "!TIME_OK!"=="1" ( call :warn "Clock synchronized; certificates NOT refreshed" ) else ( call :warn "The clock could NOT be synchronized" )
exit /b 1
