::SRC fase_14.body.cmd | Cuerpo de arranque of the phase 14 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase14, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase14. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 14 - Winget%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "14" "Winget" "Repairs winget and updates the package manager."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase14 ) else ( call :menu_fase14 )
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
    call :title_of 14
    call :pshq addphase "14;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase14
if "%DRY%"=="1" ( call :dry "Would repair the winget sources and update them" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Verifying winget (scan only)"
    where winget >nul 2>&1
    if !errorlevel! neq 0 (
        call :warn "winget is not available on the system"
        exit /b 1
    )
    winget --version > "%CAP%" 2>&1
    set "WRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!WRC!"=="0" (
        for /f "usebackq tokens=*" %%v in ("%CAP%") do set "WVER=%%v"
        call :ok "winget is available (version !WVER!)"
        exit /b 0
    ) else (
        call :warn "winget installed but not responding correctly"
        exit /b 1
    )
)

call :step "Verifying winget"
where winget >nul 2>&1
if !errorlevel! neq 0 (
    call :warn "winget is not available on the system. Attempting App Installer bootstrap..."
    call :psh bootstrapwinget > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "BOOTSTRAP_OK=0"
    for /f "usebackq tokens=1,2 delims==" %%A in ("%CAP%") do (
        if "%%A"=="BOOTSTRAP_OK" set "BOOTSTRAP_OK=%%B"
    )
    if "!BOOTSTRAP_OK!"=="1" (
        call :ok "winget successfully installed via bootstrap"
        where winget >nul 2>&1
        if !errorlevel! neq 0 (
            set "PATH=%PATH%;%LOCALAPPDATA%\Microsoft\WindowsApps"
        )
    ) else (
        call :warn "winget bootstrap failed. Install App Installer manually from the Store."
        set "PH_NOTE=winget missing"
        exit /b 1
    )
)
call :step "Repairing sources and updating winget"
winget source reset --force >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 ( call :warn "winget source reset returned an error. Check the log." & set "PH_NOTE=winget source reset failed" & exit /b 1 )
winget source update >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 call :warn "winget source update returned warnings (some source did not update)"
winget --version >nul 2>&1
if !errorlevel! neq 0 ( call :warn "winget is not responding after the repair" & set "PH_NOTE=winget not responding" & exit /b 1 )
call :ok "winget operational and sources updated (verified)"
exit /b 0
