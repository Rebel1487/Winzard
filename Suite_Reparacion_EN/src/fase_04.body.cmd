::SRC fase_04.body.cmd | Cuerpo de arranque of the phase 04 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase04, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase04. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 04 - Disk optimization%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "04" "Disk optimization" "TRIM for SSDs or defragment for HDDs, depending on the disk type."
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
rem (v3.2) single phase: record result in state and generate the HTML report
if not "%DRY%"=="1" (
    call :title_of 04
    call :pshq addphase "04;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase04
if "%DRY%"=="1" ( call :dry "Would optimize the disk (TRIM if SSD, defrag if HDD; nothing if type is uncertain)" & exit /b 2 )
call :step "Detecting the system disk type"
call :psh mediatype > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "MEDIA=" & set "OPTIMIZE="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MEDIA=" "%CAP%"`) do set "MEDIA=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OPTIMIZE=" "%CAP%"`) do set "OPTIMIZE=%%a"
call :info "Disk type: !MEDIA!  (recommended action: !OPTIMIZE!)"
if /i "!OPTIMIZE!"=="TRIM" (
    call :step "SSD detected: sending TRIM"
    powershell -NoProfile -Command "try { Optimize-Volume -DriveLetter %SystemDrive:~0,1% -ReTrim -Verbose -ErrorAction Stop; exit 0 } catch { Write-Output $_.Exception.Message; exit 1 }" >> "%LOGFILE%" 2>&1
    if !errorlevel! neq 0 ( call :warn "Optimize-Volume failed to send TRIM (check the log)" & set "PH_NOTE=TRIM failed" & exit /b 1 )
    set "PH_NOTE=TRIM sent (SSD)"
    call :ok "TRIM completed and verified on %SystemDrive%"
    exit /b 0
)
if /i "!OPTIMIZE!"=="DEFRAG" (
    call :step "HDD detected: defragmenting %SystemDrive% (may take a while)"
    powershell -NoProfile -Command "try { Optimize-Volume -DriveLetter %SystemDrive:~0,1% -Defrag -Verbose -ErrorAction Stop; exit 0 } catch { Write-Output $_.Exception.Message; exit 1 }" >> "%LOGFILE%" 2>&1
    if !errorlevel! neq 0 ( call :warn "Optimize-Volume failed to defragment (check the log)" & set "PH_NOTE=defrag failed" & exit /b 1 )
    set "PH_NOTE=defragmented (HDD)"
    call :ok "Defragmentation completed and verified on %SystemDrive%"
    exit /b 0
)
if /i "!MEDIA!"=="VIRTUAL" (
    call :info "Virtual machine disk detected: optimization skipped (not applicable; TRIM/defrag do not benefit a virtual disk)"
    set "PH_NOTE=virtual disk: optimization not applicable"
    exit /b 2
)
call :warn "Disk type undetermined: skipping optimization to avoid risking an SSD"
set "PH_NOTE=undetermined disk type; skipped optimization"
exit /b 1
