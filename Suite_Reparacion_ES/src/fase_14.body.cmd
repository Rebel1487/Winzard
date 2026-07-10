::SRC fase_14.body.cmd | Cuerpo de arranque de la fase 14 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase14, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase14. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 14 - Winget%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "14" "Winget" "Repara winget y actualiza el gestor de paquetes."
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
rem (v3.2) fase suelta: registrar resultado en el estado y generar informe HTML
if not "%DRY%"=="1" (
    call :title_of 14
    call :pshq addphase "14;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase14
if "%DRY%"=="1" ( call :dry "Repararia los origenes de winget y los actualizaria" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Verificando winget (solo escaneo)"
    where winget >nul 2>&1
    if !errorlevel! neq 0 (
        call :warn "winget no esta disponible en el sistema"
        exit /b 1
    )
    winget --version > "%CAP%" 2>&1
    set "WRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!WRC!"=="0" (
        for /f "usebackq tokens=*" %%v in ("%CAP%") do set "WVER=%%v"
        call :ok "winget esta disponible (version !WVER!)"
        exit /b 0
    ) else (
        call :warn "winget instalado pero no responde correctamente"
        exit /b 1
    )
)

call :step "Comprobando winget"
where winget >nul 2>&1
if !errorlevel! neq 0 (
    call :warn "winget no esta disponible en el sistema. Intentando bootstrap de App Installer..."
    call :psh bootstrapwinget > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "BOOTSTRAP_OK=0"
    for /f "usebackq tokens=1,2 delims==" %%A in ("%CAP%") do (
        if "%%A"=="BOOTSTRAP_OK" set "BOOTSTRAP_OK=%%B"
    )
    if "!BOOTSTRAP_OK!"=="1" (
        call :ok "winget instalado correctamente mediante bootstrap"
        where winget >nul 2>&1
        if !errorlevel! neq 0 (
            set "PATH=%PATH%;%LOCALAPPDATA%\Microsoft\WindowsApps"
        )
    ) else (
        call :warn "Fallo el bootstrap de winget. Instala App Installer manualmente desde la Store."
        set "PH_NOTE=winget ausente"
        exit /b 1
    )
)
call :step "Reparando origenes y actualizando winget"
winget source reset --force >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 ( call :warn "winget source reset devolvio error. Revisa el log." & set "PH_NOTE=winget source reset fallo" & exit /b 1 )
winget source update >> "%LOGFILE%" 2>&1
if !errorlevel! neq 0 call :warn "winget source update devolvio avisos (algun origen no se actualizo)"
winget --version >nul 2>&1
if !errorlevel! neq 0 ( call :warn "winget no responde tras la reparacion" & set "PH_NOTE=winget no responde" & exit /b 1 )
call :ok "winget operativo y origenes actualizados (verificado)"
exit /b 0
