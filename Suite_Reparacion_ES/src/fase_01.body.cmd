::SRC fase_01.body.cmd | Cuerpo de arranque de la fase 01 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase01, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase01. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 01 - Punto de restauracion%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "01" "Punto de restauracion" "Crea un punto de restauracion y respalda el registro para volver atras."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase01 ) else ( call :menu_fase01 )
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


:Fase01
if "%DRY%"=="1" ( call :dry "Crearia un punto de restauracion y respaldaria el registro" & exit /b 2 )
call :step "Creando punto de restauracion (puede tardar)"
call :psh restorepoint > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /c:"RESULT=OK" "%CAP%" >nul 2>&1
if !errorlevel! equ 0 ( call :ok "Punto de restauracion creado y verificado" ) else ( call :warn "No se pudo crear el punto de restauracion (continuo igualmente)" )
call :step "Respaldando el registro (SOFTWARE y SYSTEM)"
reg export HKLM\SOFTWARE "%BKDIR%\SOFTWARE_%TIMESTAMP%.reg" /y >nul 2>&1
reg export HKLM\SYSTEM "%BKDIR%\SYSTEM_%TIMESTAMP%.reg" /y >nul 2>&1
call :info "Copia del registro solicitada en Backups"

call :step "Verificando red de seguridad y respaldos"
call :psh checkbackups "%BKDIR%|%TIMESTAMP%" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"

set "RP_OK=0"
set "REG_OK=0"
for /f "tokens=1,2 delims==" %%A in (%CAP%) do (
    if "%%A"=="RP_OK" set "RP_OK=%%B"
    if "%%A"=="REG_OK" set "REG_OK=%%B"
)

if "!RP_OK!"=="1" if "!REG_OK!"=="1" (
    call :ok "Red de seguridad verificada (Punto de restauracion y copias del registro OK)"
    exit /b 0
)

echo(
call :warn "FALLO EN LA RED DE SEGURIDAD:"
if "!RP_OK!"=="0" echo   [X] No se pudo crear/verificar el Punto de Restauracion.
if "!REG_OK!"=="0" echo   [X] Las copias del registro (.reg) estan ausentes o vacias.
echo(

if "%MODE_AUTO%"=="1" (
    call :err "Modo desatendido: Abortando ejecucion por seguridad."
    exit /b 3
)

echo %YE%[!] ATENCION: Continuar sin red de seguridad es arriesgado.%R%
choice /C SC /M "Presiona [S] para salir/abortar o [C] para continuar bajo tu propio riesgo"
if !errorlevel! equ 1 (
    call :err "Cancelado por el usuario."
    exit /b 3
) else (
    call :warn "Continuando sin red de seguridad por eleccion del usuario."
    exit /b 0
)
