::SRC fase_07.body.cmd | Cuerpo de arranque de la fase 07 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase07, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase07. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 07 - Reparar WMI%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "07" "Reparar WMI" "Comprueba y repara el repositorio WMI (su rotura causa fallos raros)."
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
rem (v3.2) fase suelta: registrar resultado en el estado y generar informe HTML
if not "%DRY%"=="1" (
    call :title_of 07
    call :pshq addphase "07;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
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


:Fase07
if "%DRY%"=="1" ( call :dry "Verificaria y, si hace falta, salvaria el repositorio WMI" & exit /b 2 )

if "%QUICK%"=="1" (
    call :step "Verificando repositorio WMI (solo escaneo)"
    winmgmt /verifyrepository > "%CAP%" 2>&1
    set "WMIRC=!errorlevel!"
    type "%CAP%" >> "%LOGFILE%"
    call :wmi_consistent !WMIRC!
    if "!WMI_OK!"=="1" (
        call :ok "Repositorio WMI consistente"
        exit /b 0
    ) else (
        call :warn "Repositorio WMI inconsistente (detectado en solo escaneo)"
        exit /b 1
    )
)

call :step "Verificando el repositorio WMI"
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "Repositorio WMI coherente" & exit /b 0 )
call :warn "WMI inconsistente: intentando salvarlo"
winmgmt /salvagerepository >> "%LOGFILE%" 2>&1
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "WMI reparado (salvage)" & exit /b 0 )

call :step "WMI sigue danado despues de salvamento. Compilando archivos MOF de System32\wbem..."
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
    call :ok "WMI reparado compilando archivos MOF/MFL"
    exit /b 0
)

call :warn "WMI sigue danado despues de salvamento y mofcomp. El reset total queda manual: winmgmt /resetrepository"
call :pshq finding "Repositorio WMI danado (requiere reset manual)"
set "PH_NOTE=WMI requiere reset manual"
exit /b 1
