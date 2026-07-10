::SRC fase_09.body.cmd | Cuerpo de arranque de la fase 09 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase09, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase09. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 09 - Busqueda y caches%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "09" "Busqueda y caches" "Reconstruye el indice de Busqueda, cache de iconos/fuentes y el spooler."
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
rem (v3.2) fase suelta: registrar resultado en el estado y generar informe HTML
if not "%DRY%"=="1" (
    call :title_of 09
    call :pshq addphase "09;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
    set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
    call :psh report "!REPORT!" >nul 2>&1
)
echo(
echo %BL%------------------------------------------------------------%R%
echo    Resultado: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
if exist "!REPORT!" echo    %WH%Informe:%R% !REPORT!
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b %RC%


:Fase09
if "%DRY%"=="1" ( call :dry "Reconstruiria indice de Busqueda y caches de iconos/fuentes y reiniciaria el spooler" & exit /b 2 )
call :step "Reconstruyendo el indice de Busqueda"
net stop WSearch /y >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows Search" /v SetupCompletedSuccessfully /t REG_DWORD /d 0 /f >nul 2>&1
net start WSearch >nul 2>&1
call :step "Limpiando cache de iconos y miniaturas"
taskkill /f /im explorer.exe >nul 2>&1
del /f /q /a "%LocalAppData%\IconCache.db" >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
start "" explorer.exe
call :step "Limpiando cache de fuentes"
net stop FontCache /y >nul 2>&1
del /f /q /s "%SystemRoot%\ServiceProfiles\LocalService\AppData\Local\FontCache\*.*" >nul 2>&1
del /f /q "%SystemRoot%\System32\FNTCACHE.DAT" >nul 2>&1
net start FontCache >nul 2>&1
call :step "Reiniciando la cola de impresion"
net stop Spooler /y >nul 2>&1
del /f /q "%SystemRoot%\System32\spool\PRINTERS\*.*" >nul 2>&1
net start Spooler >nul 2>&1
call :step "Verificando que los servicios han vuelto a arrancar"
set "SVCFAIL="
sc query WSearch 2>nul | findstr /i "RUNNING START_PENDING" >nul 2>&1
if !errorlevel! neq 0 set "SVCFAIL=!SVCFAIL! WSearch"
sc query FontCache 2>nul | findstr /i "RUNNING START_PENDING" >nul 2>&1
if !errorlevel! neq 0 set "SVCFAIL=!SVCFAIL! FontCache"
sc query Spooler 2>nul | findstr /i "RUNNING START_PENDING" >nul 2>&1
if !errorlevel! neq 0 set "SVCFAIL=!SVCFAIL! Spooler"
if defined SVCFAIL ( call :warn "Servicio(s) sin arrancar tras el reset:!SVCFAIL!. Revisa el log." & set "PH_NOTE=servicios sin arrancar:!SVCFAIL!" & exit /b 1 )
call :ok "Busqueda, caches y spooler restablecidos (servicios verificados)"
exit /b 0
