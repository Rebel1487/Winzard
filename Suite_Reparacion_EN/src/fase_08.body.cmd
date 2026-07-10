::SRC fase_08.body.cmd | Cuerpo de arranque of the phase 08 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase08, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase08. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 08 - Store apps and Startup%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "08" "Store apps and Startup" "Re-registers Store apps and repairs the Start menu."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase08 ) else ( call :menu_fase08 )
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
    call :title_of 08
    call :pshq addphase "08;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase08
if "%DRY%"=="1" ( call :dry "Would re-register Store apps and restart the Start menu" & exit /b 2 )
call :step "Re-registering Microsoft Store apps (may take a while)"
powershell -NoProfile -Command "Get-AppxPackage -AllUsers | ForEach-Object { try { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppXManifest.xml') -ErrorAction SilentlyContinue } catch {} }" >> "%LOGFILE%" 2>&1
call :step "Restarting the Start menu"
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1
taskkill /f /im ShellExperienceHost.exe >nul 2>&1
timeout /t 3 /nobreak >nul 2>&1
tasklist /fi "imagename eq StartMenuExperienceHost.exe" 2>nul | find /i "StartMenuExperienceHost.exe" >nul 2>&1
if !errorlevel! neq 0 ( call :warn "Re-registration launched, but the Start menu has not relaunched yet (it relaunches on use). Check the log if any app still fails." & set "PH_NOTE=Start pending relaunch" & exit /b 1 )
call :ok "Store apps re-registered and Start restarted (verified)"
exit /b 0
