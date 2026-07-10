::SRC fase_07.body.cmd | Cuerpo de arranque of the phase 07 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase07, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase07. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 07 - Repair WMI%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "07" "Repair WMI" "Checks and repairs the WMI repository (a broken one causes odd failures)."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase07 ) else ( call :menu_fase07 )
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
    call :title_of 07
    call :pshq addphase "07;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase07
if "%DRY%"=="1" ( call :dry "Would verify and, if needed, salvage the WMI repository" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Verifying WMI repository (scan only)"
    winmgmt /verifyrepository > "%CAP%" 2>&1
    set "WMIRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    call :wmi_consistent !WMIRC!
    if "!WMI_OK!"=="1" (
        call :ok "WMI repository consistent"
        exit /b 0
    ) else (
        call :warn "WMI repository inconsistent (detected in scan-only)"
        exit /b 1
    )
)

call :step "Verifying the WMI repository"
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "WMI repository coherent" & exit /b 0 )
call :warn "WMI inconsistent: trying to salvage"
winmgmt /salvagerepository >> "%LOGFILE%" 2>&1
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "WMI repaired (salvage)" & exit /b 0 )

call :step "WMI still damaged after salvage. Compiling MOF files from System32\wbem..."
cd /d %SystemRoot%\System32\wbem >nul 2>&1
for /f %%s in ('dir /b *.mof *.mfl') do (
    mofcomp %%s >> "%LOGFILE%" 2>&1
)
cd /d "%SELFDIR%" >nul 2>&1

winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" (
    call :ok "WMI repaired compiling MOF/MFL files"
    exit /b 0
)

call :warn "WMI still damaged after salvage and mofcomp. Full reset stays manual: winmgmt /resetrepository"
call :pshq finding "WMI repository damaged (requires manual reset)"
set "PH_NOTE=WMI requires manual reset"
exit /b 1
