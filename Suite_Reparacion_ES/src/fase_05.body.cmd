::SRC fase_05.body.cmd | Cuerpo de arranque de la fase 05 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase05, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase05. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 05 - DISM%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "05" "DISM" "Repara la imagen de componentes de Windows (el origen de SFC)."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase05 ) else ( call :menu_fase05 )
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
    call :title_of 05
    call :pshq addphase "05;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase05
if "%DRY%"=="1" ( call :dry "Repararia la imagen de componentes con DISM /RestoreHealth" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "DISM /CheckHealth (solo escaneo rapido)"
    dism /online /cleanup-image /checkhealth > "%CAP%" 2>&1
    set "D=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    if "!D!"=="0" (
        call :ok "Imagen de componentes saludable (CheckHealth)"
        exit /b 0
    ) else (
        call :warn "DISM detecto corrupcion en la imagen de componentes (codigo !D!)"
        exit /b 1
    )
)

call :step "DISM CheckHealth"
dism /online /cleanup-image /checkhealth >> "%LOGFILE%" 2>&1
call :step "DISM ScanHealth (varios minutos)"
dism /online /cleanup-image /scanhealth >> "%LOGFILE%" 2>&1

call :step "DISM RestoreHealth (puede tardar bastante)"
set "DISM_OK=0"
set "RESTORE_SOURCE=%CUSTOM_SOURCE%"
if not "!RESTORE_SOURCE!"=="" (
    call :step "Utilizando origen personalizado forzado: !RESTORE_SOURCE!"
) else (
    call :psh findlocalsource > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "LOCSRC="
    for /f "usebackq tokens=1,* delims==" %%A in ("%CAP%") do (
        if "%%A"=="SOURCE" set "LOCSRC=%%B"
    )
    if not "!LOCSRC!"=="" (
        set "RESTORE_SOURCE=!LOCSRC!"
        call :step "Origen offline local encontrado: !RESTORE_SOURCE!"
    ) else (
        ping 1.1.1.1 -n 1 -w 1500 >nul 2>&1
        if !errorlevel! neq 0 call :warn "Sin Internet ni origen offline local: DISM puede agotar el timeout"
    )
)
call :psh dismrestore "!RESTORE_SOURCE!|45" > "%CAP%" 2>&1
set "D=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
for /f "usebackq tokens=1,* delims==" %%A in ("%CAP%") do (
    if "%%A"=="EXITCODE" set "D=%%B"
    if "%%A"=="TIMEDOUT" set "DISM_TIMEDOUT=%%B"
)

if "!D!"=="0" (
    set "DISM_OK=1"
    call :ok "Imagen de componentes reparada (DISM)"
) else (
    if "!DISM_TIMEDOUT!"=="1" (
        call :warn "DISM RestoreHealth agoto el timeout de seguridad (45 min)"
        set "PH_NOTE=DISM timeout"
    ) else (
        set "PH_NOTE=DISM fallo codigo !D!"
        call :warn "DISM RestoreHealth fallo (codigo !D!). Revisa el log."
    )
)

call :step "Liberando espacio del almacen de componentes"
if "%RESETBASE%"=="1" (
    call :step "Limpieza profunda de componentes con /ResetBase"
    dism /online /cleanup-image /startcomponentcleanup /ResetBase >> "%LOGFILE%" 2>&1
) else (
    dism /online /cleanup-image /startcomponentcleanup >> "%LOGFILE%" 2>&1
)
set "CLEANRC=!errorlevel!"
if not "!CLEANRC!"=="0" ( call :warn "La limpieza del almacen de componentes termino con codigo !CLEANRC!" & if "!DISM_OK!"=="1" exit /b 1 )
if "!DISM_OK!"=="1" ( call :ok "Almacen de componentes optimizado" & exit /b 0 )
call :warn "DISM no pudo confirmar reparacion de la imagen de componentes"
exit /b 1
