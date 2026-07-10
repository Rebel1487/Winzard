::SRC fase_02.body.cmd | Cuerpo de arranque of the phase 02 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase02, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase02. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 02 - Initial cleanup%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "02" "Initial cleanup" "Clears temp files, recycle bin and caches to free up the disk."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase02 ) else ( call :menu_fase02 )
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
    call :title_of 02
    call :pshq addphase "02;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase02
if "%DRY%"=="1" ( call :dry "Would delete temp files, Recycle Bin, prefetch and delivery cache" & exit /b 2 )
set "FREE_BEFORE=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1MB)"`) do set "FREE_BEFORE=%%a"
net stop DoSvc /y >nul 2>&1
call :step "Cleaning user and system temp files"
del /f /q /s "%TEMP%\*.*" >nul 2>&1
del /f /q /s "%SystemRoot%\Temp\*.*" >nul 2>&1
del /f /q /s "%SystemRoot%\Prefetch\*.*" >nul 2>&1
del /f /q /s "%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*.*" >nul 2>&1
net start DoSvc >nul 2>&1
ipconfig /flushdns >nul 2>&1
call :step "Emptying Recycle Bin and thumbnails"
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
set "FREE_AFTER=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1MB)"`) do set "FREE_AFTER=%%a"
set /a "FREED=FREE_AFTER-FREE_BEFORE"
if !FREED! lss 0 set "FREED=0"
set "PH_NOTE=freed ~!FREED! MB"
call :ok "Initial cleanup completed. Freed ~!FREED! MB"
exit /b 0
