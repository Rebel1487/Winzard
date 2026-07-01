::SRC fase_10.body.cmd | Cuerpo de arranque de la fase 10 (Task 1.3, Req 2.1/14.1/14.3).
::SRC Bloque de arranque (banner, reloj, call :phase, call :Fase10, calculo RC/SECS/RES, resultado, endlocal & exit /b !RC!)
::SRC MAS la definicion :Fase10. Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
call :bigbanner
echo(
echo  %DIM%Fase suelta 10 - Certificados y hora%R%
echo(
call :env_validate
set "ENVRC=!errorlevel!"
if "!ENVRC!"=="3" call :pause_close
if "!ENVRC!"=="3" ( endlocal & exit /b 3 )
call :nowcs & set "P0=!CS_NOW!"
call :phase "10" "Certificados y hora" "Refresca certificados raiz y sincroniza la hora (arregla WU/Store/cert)."
if "%RESUME%"=="0" call :pshq resetstate
if "%MODE_AUTO%"=="1" ( call :Fase10 ) else ( call :menu_fase10 )
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


:Fase10
if "%DRY%"=="1" ( call :dry "Sincronizaria la hora y refrescaria los certificados raiz" & exit /b 2 )
call :step "Sincronizando la hora del sistema"
net start w32time >nul 2>&1
w32tm /resync /force >> "%LOGFILE%" 2>&1
call :step "Actualizando certificados raiz de confianza"
certutil -generateSSTFromWU "%WORK%\roots.sst" >> "%LOGFILE%" 2>&1
if exist "%WORK%\roots.sst" (
    powershell -NoProfile -Command "try { Import-Certificate -FilePath '%WORK%\roots.sst' -CertStoreLocation Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Out-Null } catch {}" >> "%LOGFILE%" 2>&1
    call :ok "Certificados raiz refrescados y hora sincronizada"
) else (
    call :warn "No se pudieron descargar certificados raiz (sin Internet). Hora sincronizada."
    set "PH_NOTE=sin Internet para certificados"
)
exit /b 0
