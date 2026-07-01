::SRC fase_09.body.cmd | Cuerpo de arranque of the phase 09 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase09, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase09. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Standalone phase 09 - Search and caches%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "09" "Search and caches" "Rebuilds the Search index, icon/font caches and the spooler."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase09 ) else ( call :menu_fase09 )
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


:Fase09
if "%DRY%"=="1" ( call :dry "Would rebuild the Search index and icon/font caches and restart the spooler" & exit /b 2 )
call :step "Rebuilding the Search index"
net stop WSearch /y >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows Search" /v SetupCompletedSuccessfully /t REG_DWORD /d 0 /f >nul 2>&1
net start WSearch >nul 2>&1
call :step "Clearing icon and thumbnail cache"
taskkill /f /im explorer.exe >nul 2>&1
del /f /q /a "%LocalAppData%\IconCache.db" >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
start "" explorer.exe
call :step "Clearing font cache"
net stop FontCache /y >nul 2>&1
del /f /q /s "%SystemRoot%\ServiceProfiles\LocalService\AppData\Local\FontCache\*.*" >nul 2>&1
del /f /q "%SystemRoot%\System32\FNTCACHE.DAT" >nul 2>&1
net start FontCache >nul 2>&1
call :step "Restarting print spooler"
net stop Spooler /y >nul 2>&1
del /f /q "%SystemRoot%\System32\spool\PRINTERS\*.*" >nul 2>&1
net start Spooler >nul 2>&1
call :ok "Search, caches and spooler reset"
exit /b 0
