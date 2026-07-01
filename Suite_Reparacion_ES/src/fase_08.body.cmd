::SRC fase_08.body.cmd | Cuerpo de arranque de la fase 08 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase08, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase08. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 08 - Apps de Store e Inicio%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "08" "Apps de Store e Inicio" "Re-registra las apps de la Store y repara el menu Inicio."
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
echo(
echo %BL%------------------------------------------------------------%R%
echo    Resultado: !COL!!RES!%R%   %DIM%^(!SECS!s^)%R%
echo    %WH%Log:%R% %LOGFILE%
echo %BL%------------------------------------------------------------%R%
if "%MODE_AUTO%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b %RC%


:Fase08
if "%DRY%"=="1" ( call :dry "Re-registraria las apps de la Store y reiniciaria el Inicio" & exit /b 2 )
call :step "Re-registrando apps de la Microsoft Store (puede tardar)"
powershell -NoProfile -Command "Get-AppxPackage -AllUsers | ForEach-Object { try { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppXManifest.xml') -ErrorAction SilentlyContinue } catch {} }" >> "%LOGFILE%" 2>&1
call :step "Reiniciando el menu Inicio"
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1
taskkill /f /im ShellExperienceHost.exe >nul 2>&1
call :ok "Apps de Store re-registradas e Inicio reiniciado"
exit /b 0
