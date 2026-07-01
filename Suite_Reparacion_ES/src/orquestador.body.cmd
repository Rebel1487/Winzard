::SRC orquestador.body.cmd | Cuerpo del orquestador (Task 1.3/8/10, Req 1.x/2.x/4.x/6.x/8.x/13.x/14.x/18.x).
::SRC Flujo ORQUESTADOR (env-validate, self-test, /resume, menu, run_all, run_phase, finish, tail) MAS las 17 :FaseNN.
::SRC Se ensambla como: cabecera + ESTE cuerpo + libreria + bloque HLP. El generador descarta las lineas ::SRC.
:: ======================= ORQUESTADOR ========================

:: --- (Task 10.2 / Req 13) Validacion de entorno: admin (ya elevado en la
::     cabecera), version de Windows 10/11 y PowerShell, registrando cada
::     resultado en el log. Si el SO no es compatible, se detiene (exit 3). ---
call :env_validate
if errorlevel 3 goto :tail_end_envfail

:: --- (Task 10.3 / Req 18) Modo /selftest: no toca el sistema, resume y sale. ---
if "%SELFTEST%"=="1" goto :run_selftest

:: --- Estado de control de la ejecucion ---
set "DO_EXIT=0"
set "RESUME_ACTIVE=0"
set "COMPLETED="
set "RESUME_NEXT="
set "WORST_RC=0"
set "CHKDSK_SCHEDULED="

:: --- (Task 8.3 / Bug 2 / Req 4) /resume real: cargar checkpoint valido y
::     reanudar desde la primera fase no completada. ---
if "%RESUME%"=="1" call :resume_load

:: --- (Task 8.4 / Bug 6 / Req 8) resetstate UNICO al inicio, salvo en /resume. ---
if "!RESUME_ACTIVE!"=="0" call :pshq resetstate

call :bigbanner
echo(
echo  %DIM%Sistema:%R%
for /f "usebackq tokens=1,* delims==" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%HELPER%" -Action sysinfo -Work "%WORK%"`) do echo    %CY%%%a%R%  %%b
echo(
call :step "Calculando salud inicial del sistema"
call :psh score > "%CAP%" 2>&1
set "SCORE_BEFORE="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SCORE=" "%CAP%"`) do set "SCORE_BEFORE=%%a"
if defined SCORE_BEFORE ( call :pshq setbefore "!SCORE_BEFORE!" & call :info "Salud actual: !SCORE_BEFORE!/100" )
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /c:"REASON=" "%CAP%"`) do call :pshq finding "%%b"

:: --- menu interactivo solo si no se ha especificado ningun modo por argumento ---
set "MENU_SESSION=0"
if "%MODE_AUTO%"=="0" if not defined SEL_FASES if "%USE_TRIAGE%"=="0" if "!RESUME_ACTIVE!"=="0" if "%QUICK%"=="0" if "%PLAN_MODE%"=="0" if "%MANUAL%"=="0" if "%DRY%"=="0" set "MENU_SESSION=1"
:session_loop
if "!MENU_SESSION!"=="1" call :menu
:: (Task 8.1 / Bug 1) Si en el menu se eligio "Salir", cerrar limpio SIN fases.
if "!DO_EXIT!"=="1" ( endlocal & exit /b 0 )

:: --- (v3.1) Plan personalizado: ejecuta el asistente y termina ---
if "%PLAN_MODE%"=="1" call :plan_wizard
if "%PLAN_MODE%"=="1" goto :tail_end_noop

:: --- triage: convierte la recomendacion del Cerebro en SEL_FASES ---
if "%USE_TRIAGE%"=="1" (
    call :step "Auto-triage: decidiendo que fases necesitas"
    call :psh triage > "%CAP%" 2>&1
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"RECOMENDADAS=" "%CAP%"`) do set "SEL_FASES=%%a"
    call :info "Triage recomienda: !SEL_FASES!"
)

:: --- (v3.1) /quick: inspeccion rapida, solo diagnostico (anula seleccion/triage) ---
rem (v3.1) Inspeccion RAPIDA con submodos (scan / scan+fix); termina al acabar.
if "%QUICK%"=="1" if "%QUICK_WIZ%"=="1" call :quick_wizard
if "%QUICK%"=="1" if not "%QUICK_WIZ%"=="1" call :quick_run %QSUB%
if "%QUICK%"=="1" goto :tail_end_noop

:: --- (Task 8.2 / Bug 4 / Req 6) Normalizar la seleccion con el Cerebro ---
if defined SEL_FASES call :normalize_selection

:: --- (intuitividad) confirmar antes de cambios reales (no en auto/dry/manual) ---
call :confirm_changes
if errorlevel 1 goto :tail_end_noop

:: --- precontar fases a ejecutar (para el indicador de progreso) ---
set "RUN_TOTAL=0"
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do (
    call :should_run %%P
    if !errorlevel! equ 0 (
        call :is_completed %%P
        if !errorlevel! neq 0 set /a "RUN_TOTAL+=1"
    )
)
set "RUN_IDX=0"

call :run_all
if "!ABORT_LOOP!"=="1" (
    set "ABORT_LOOP="
    if "!MENU_SESSION!"=="1" (
        cls
        goto :session_loop
    ) else (
        goto :tail_end_noop
    )
)
goto :finish

:: ------------------------------------------------------------------
:menu
echo(
:menu_again
echo  %B%%WH%Que quieres hacer%R%
echo  %DIM%Si no lo tienes claro: pulsa 1 ^(lo arregla todo^) o 2 ^(solo lo necesario^).%R%
echo(
echo    %GR%1%R%  Reparacion COMPLETA automatica   %DIM%- todas las fases - cambios + reinicio - ~10-20 min%R%
echo    %GR%2%R%  Reparacion inteligente           %DIM%- auto-triage - solo lo necesario - ~5-15 min%R%
echo    %GR%3%R%  Inspeccion RAPIDA                %DIM%- escaneo o escaneo + reparacion - ~1-2 min%R%
echo    %GR%4%R%  Modo MANUAL                      %DIM%- un comando por fase, a tu ritmo%R%
echo    %GR%5%R%  PLAN guiado                      %DIM%- eliges todo, revisas y confirmas - ~5-15 min%R%
echo    %GR%6%R%  Elegir fases concretas           %DIM%- tu indicas que fases ejecutar - variable%R%
echo    %GR%7%R%  Simulacion ^(dry-run^)             %DIM%- no toca nada, solo muestra que haria - ~1 min%R%
echo    %GR%8%R%  Guia                             %DIM%- que hace cada fase y cada modo - lectura%R%
echo    %GR%0%R%  Salir
echo(
choice /C 123456780 /N /M "  Elige una opcion: "
set "OPC=!errorlevel!"
set "NEEDS_CONFIRM=0"
if "!OPC!"=="1" set "NEEDS_CONFIRM=1"
if "!OPC!"=="2" set "NEEDS_CONFIRM=1"
if "!OPC!"=="6" set "NEEDS_CONFIRM=1"
rem choice: 1..8 -> errorlevel 1..8 ; "0" (Salir) -> 9
if "!OPC!"=="9" ( set "DO_EXIT=1" & exit /b 0 )
if "!OPC!"=="8" ( call :guide & goto :menu_again )
if "!OPC!"=="2" set "USE_TRIAGE=1"
if "!OPC!"=="3" ( set "QUICK=1" & set "QUICK_WIZ=1" )
if "!OPC!"=="4" set "MANUAL=1"
if "!OPC!"=="5" set "PLAN_MODE=1"
if "!OPC!"=="7" set "DRY=1"
if "!OPC!"=="6" (
    echo(
    echo  Fases disponibles:
    for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do ( call :title_of %%P & echo    %CY%%%P%R%  !PH_TITLE! )
    echo(
    set /p "SEL_FASES=  Escribe las fases separadas por coma (ej 05,06,13): "
)
exit /b 0

:: --- GUIA: explica cada modo y lista las fases con su numero y proposito ---
:guide
cls
call :bigbanner
echo  %B%%WH%GUIA RAPIDA%R%   %DIM%que hace cada modo y cada fase%R%
echo(
echo  %B%%CY%MODOS%R%
echo    %GR%1%R% Reparacion completa: ejecuta las 17 fases automaticamente.
echo    %GR%2%R% Inteligente ^(triage^): solo las fases que el diagnostico recomienda.
echo    %GR%3%R% Rapida: solo escaneo ^(no cambia nada^) o escaneo + reparacion segura.
echo    %GR%4%R% Manual: en cada fase eliges TU el comando y se ejecuta al momento.
echo    %GR%5%R% Plan guiado: eliges un comando por fase, revisas el plan y confirmas.
echo    %GR%6%R% Elegir fases: escribes que numeros de fase ejecutar ^(ver lista abajo^).
echo    %GR%7%R% Simulacion ^(/dry^): muestra lo que haria sin tocar nada.
echo(
echo  %B%%CY%FASES%R%  %DIM%^(usa estos numeros en la opcion 6^)%R%
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do call :guide_line %%P
echo(
echo  %B%%CY%PARA EXPERTOS%R%  %DIM%^(flags por linea de comandos^)%R%
echo    %CY%/cmd%R%           muestra el comando exacto debajo de cada opcion.
echo    %CY%/dry%R%           simulacion: no toca nada.
echo    %CY%/auto%R%          repara todo sin preguntar ^(desatendido^).
echo    %CY%/fases:LISTA%R%   ejecuta solo esas fases. Ej: /fases:05,06,13
echo  %DIM%Ej: Suite_Reparacion_TodoEnUno.bat /cmd /manual%R%
echo(
echo  Pulsa una tecla para volver al menu...
pause >nul
exit /b 0

:guide_line
call :title_of %~1
echo    %CY%%~1%R%  %WH%!PH_TITLE!%R%  %DIM%- !PH_WHY!%R%
exit /b 0

:: --- (Task 8.2 / Bug 4) normaliza SEL_FASES via el Cerebro y avisa de invalidas
:normalize_selection
call :psh normalizefases "!SEL_FASES!" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "_NORM=" & set "_INVALID="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"NORM=" "%CAP%"`) do set "_NORM=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"INVALID=" "%CAP%"`) do set "_INVALID=%%a"
if defined _INVALID call :warn "Fases no validas ignoradas: !_INVALID!"
set "SEL_FASES=!_NORM!"
if not defined SEL_FASES call :warn "Ninguna fase valida seleccionada; no se ejecutara ninguna fase"
exit /b 0

:: --- (Task 8.3 / Bug 2 / Req 4) carga el checkpoint y prepara la reanudacion
:resume_load
call :checkpoint_load
if /i not "!CP_RESULT!"=="OK" ( call :info "/resume: no hay checkpoint guardado; se ejecuta de forma normal" & exit /b 0 )
if not "!CP_VALID!"=="1" ( call :info "/resume: el checkpoint no es valido o ha caducado; ejecucion normal" & exit /b 0 )
set "RESUME_ACTIVE=1"
set "SEL_FASES=!CP_SELECTION!"
set "COMPLETED=!CP_COMPLETED!"
set "RESUME_NEXT=!CP_NEXT!"
set "MODE_AUTO=!CP_MODE_AUTO!"
set "NO_REBOOT=!CP_MODE_NOREBOOT!"
set "KEEPWU=!CP_MODE_KEEPWU!"
set "DRY=!CP_MODE_DRY!"
set "USE_TRIAGE=!CP_MODE_TRIAGE!"
if defined RESUME_NEXT ( call :info "/resume: reanudando desde la fase !RESUME_NEXT! (completadas: !COMPLETED!)" ) else ( call :info "/resume: el checkpoint no tiene fases pendientes" )
exit /b 0

:run_all
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do (
    if defined ABORT_LOOP goto :run_all_end
    call :should_run %%P
    if !errorlevel! equ 0 (
        call :is_completed %%P
        if !errorlevel! neq 0 (
            call :run_phase %%P
            if !errorlevel! equ 10 (
                set "ABORT_LOOP=1"
            )
        ) else ( call :info "Fase %%P ya completada (reanudacion): se omite" )
    )
)
:run_all_end
exit /b 0

:should_run
if not defined SEL_FASES exit /b 0
echo ,!SEL_FASES!, | findstr /c:",%~1," >nul 2>&1
exit /b !errorlevel!

:: --- 0 = ya completada (solo en /resume); 1 = pendiente ---
:is_completed
if "!RESUME_ACTIVE!"=="0" exit /b 1
if not defined COMPLETED exit /b 1
echo ,!COMPLETED!, | findstr /c:",%~1," >nul 2>&1
exit /b !errorlevel!

:run_phase
set "PID=%~1"
set /a "RUN_IDX+=1"
call :title_of !PID!
set "PH_NOTE="
call :nowcs & set "P0=!CS_NOW!"
if not "!RUN_TOTAL!"=="0" call :progress_bar !RUN_IDX! !RUN_TOTAL!
call :phase "!PID!/16" "!PH_TITLE!" "!PH_WHY!"
if "%MANUAL%"=="1" ( call :menu_fase!PID! ) else ( call :Fase!PID! )
set "RC=!errorlevel!"
if "!RC!"=="10" exit /b 10
call :nowcs & set /a "SECS=(CS_NOW-P0)/100"
if !SECS! lss 0 set /a "SECS+=86400"
set "RES=OK"
if "!RC!"=="1" set "RES=WARN"
if "!RC!"=="2" set "RES=SKIP"
if "!RC!"=="3" set "RES=ERROR"
:: codigo de salida agregado: gana la severidad mas alta (0<1<2<3)
if !RC! gtr !WORST_RC! set "WORST_RC=!RC!"
call :pshq addphase "!PID!;!PH_TITLE!;!RES!;!SECS!;!PH_NOTE!"
set "SUM=!SUM! !PID!|!RES!|!SECS!"
if not defined COMPLETED ( set "COMPLETED=!PID!" ) else ( set "COMPLETED=!COMPLETED!,!PID!" )
exit /b 0

:finish
echo(
echo %BL%============================================================%R%
echo  %B%%WH%RESUMEN%R%
echo %BL%============================================================%R%
for %%S in (!SUM!) do (
    for /f "tokens=1-3 delims=|" %%a in ("%%S") do (
        set "RES=%%b"
        set "COL=%GR%"
        if "%%b"=="WARN" set "COL=%YE%"
        if "%%b"=="SKIP" set "COL=%DIM%"
        if "%%b"=="ERROR" set "COL=%RE%"
        echo    Fase %%a   !COL!%%b%R%   %DIM%%%c s%R%
    )
)
echo(
:: --- (v3.1) asegurar puntuacion final SIEMPRE (aunque no corriera la Fase 16) ---
if not defined SCORE_AFTER (
    call :psh score > "%CAP%" 2>&1
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SCORE=" "%CAP%"`) do set "SCORE_AFTER=%%a"
    if defined SCORE_AFTER call :pshq setafter "!SCORE_AFTER!" >nul 2>&1
)
if defined SCORE_BEFORE if defined SCORE_AFTER echo    %WH%Salud:%R%  !SCORE_BEFORE!/100  %DIM%-^>%R%  %GR%!SCORE_AFTER!/100%R%
if not defined SCORE_BEFORE if defined SCORE_AFTER echo    %WH%Salud:%R%  %GR%!SCORE_AFTER!/100%R%
:: --- (v3.1) generar el informe SIEMPRE, aunque la Fase 16 no se ejecutara ---
set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
if not exist "!REPORT!" call :psh report "!REPORT!" > "%CAP%" 2>&1
if exist "!REPORT!" (
    echo    %WH%Informe:%R%  !REPORT!
    if "%MODE_AUTO%"=="0" start "" "!REPORT!"
)
:: --- (v3.1) informe JSON opcional (/json) ---
if "%JSON%"=="1" (
    set "REPORT_JSON=%WORK%\Informe_%TIMESTAMP%.json"
    call :psh jsonreport "!REPORT_JSON!" > "%CAP%" 2>&1
    if exist "!REPORT_JSON!" echo    %WH%JSON:%R%     !REPORT_JSON!
)
:: --- (v3.1) paquete de soporte opcional (/support) ---
if "%SUPPORT%"=="1" (
    set "PKG=%WORK%\Paquete_Soporte_%TIMESTAMP%.zip"
    call :psh supportpackage "!PKG!" > "%CAP%" 2>&1
    if exist "!PKG!" echo    %WH%Soporte:%R%  !PKG!
)
echo    %WH%Log:%R%      %LOGFILE%
:: --- resultado global agregado (Map-ExitCode del peor RC) ---
call :psh mapexit "!WORST_RC!" > "%CAP%" 2>&1
set "AGG_RES=OK"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"RES=" "%CAP%"`) do set "AGG_RES=%%a"
set "AGGCOL=%GR%"
if "!AGG_RES!"=="WARN" set "AGGCOL=%YE%"
if "!AGG_RES!"=="SKIP" set "AGGCOL=%DIM%"
if "!AGG_RES!"=="ERROR" set "AGGCOL=%RE%"
echo    %WH%Resultado global:%R%  !AGGCOL!!AGG_RES!%R%
echo %BL%============================================================%R%
:: --- rotacion de logs (Req 17.2) ---
call :log_rotate
:: --- reinicio + checkpoint para /resume (Task 8.3 / Req 4) ---
set "CP_REASON=reparacion_completada"
if defined CHKDSK_SCHEDULED set "CP_REASON=chkdsk_programado"
if "%DRY%"=="1" ( call :checkpoint_clear & goto :tail_end )
if "%MODE_AUTO%"=="1" (
    if "%NO_REBOOT%"=="0" (
        call :prepare_resume_checkpoint
        call :warn "El equipo se reiniciara en 60 segundos. Cierra esta ventana para cancelar."
        shutdown /r /t 60 /c "Reinicio tras reparacion WPI" >nul 2>&1
        goto :tail_end
    )
    call :checkpoint_clear
    goto :tail_end
)
echo(
choice /M "Quieres reiniciar ahora para aplicar todos los cambios"
if !errorlevel! equ 1 ( call :prepare_resume_checkpoint & set "DID_REBOOT=1" & shutdown /r /t 5 >nul 2>&1 ) else ( call :checkpoint_clear )
:tail_end
if "!DID_REBOOT!"=="1" ( endlocal & exit /b %WORST_RC% )
if "!MENU_SESSION!"=="1" ( echo( & echo  %DIM%Pulsa una tecla para volver al menu...%R% & pause >nul & cls & call :bigbanner & call :reset_session & goto :session_loop )
if "%MODE_AUTO%"=="0" if "%DRY%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b %WORST_RC%

:: --- guarda checkpoint antes de reiniciar (selection completa si era todo) ---
:prepare_resume_checkpoint
set "_SEL_SAVE=!SEL_FASES!"
if not defined _SEL_SAVE set "_SEL_SAVE=00,01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16"
set "SEL_FASES=!_SEL_SAVE!"
call :checkpoint_save
exit /b 0

:: --- salida limpia sin ejecutar fases (menu "Salir", Bug 1 / Task 8.1) ---
:tail_end_noop
if "!MENU_SESSION!"=="1" ( echo( & echo  %DIM%Pulsa una tecla para volver al menu...%R% & pause >nul & cls & call :bigbanner & call :reset_session & goto :session_loop )
if "%MODE_AUTO%"=="0" if "%DRY%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b 0
:confirm_changes
if "%MODE_AUTO%"=="1" exit /b 0
if "%DRY%"=="1" exit /b 0
if "%MANUAL%"=="1" exit /b 0
echo(
echo  %YE%Aviso:%R% se ejecutaran reparaciones REALES en este equipo.
echo  %DIM%Antes de los cambios fuertes se crea un punto de restauracion (Fase 01).%R%
choice /C SN /N /M "  Continuar con la reparacion? (S/N): "
if errorlevel 2 exit /b 1
exit /b 0

:reset_session
set "USE_TRIAGE=0" & set "QUICK=0" & set "QUICK_WIZ=0" & set "MANUAL=0" & set "PLAN_MODE=0" & set "DRY=0"
set "SEL_FASES=" & set "DO_EXIT=0" & set "DID_REBOOT=0"
set "WORST_RC=0" & set "RUN_TOTAL=0" & set "RUN_IDX=0" & set "SUM="
set "SCORE_BEFORE=" & set "SCORE_AFTER=" & set "CHKDSK_SCHEDULED=" & set "CP_REASON="
call :pshq resetstate
exit /b 0

:: --- entorno no compatible (Task 10.2 / Req 13): parada con codigo 3 ---
:tail_end_envfail
if "%MODE_AUTO%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b 3

:: --- (Task 10.3 / Req 18) ejecuta el self-test y devuelve su codigo ---
:run_selftest
call :selftest
set "ST_RC=!errorlevel!"
if "%MODE_AUTO%"=="0" ( echo( & echo  Pulsa una tecla para cerrar... & pause >nul )
endlocal & exit /b %ST_RC%

:Fase00
set "DIAG_RC=0"
call :step "Comprobando salud SMART de los discos"
powershell -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus | Format-Table -AutoSize" > "%CAP%" 2>&1
type "%CAP%"
type "%CAP%" >> "%LOGFILE%"
findstr /i "Unhealthy Warning" "%CAP%" >nul 2>&1 && ( set "DIAG_RC=1" & call :warn "Algun disco reporta SMART degradado. Haz copia de tus datos antes de seguir." & call :pshq finding "Disco con SMART degradado" )
call :step "Espacio libre en C:"
set "FREE_GB=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB)"`) do set "FREE_GB=%%a"
call :info "C: tiene !FREE_GB! GB libres"
if !FREE_GB! lss 10 ( set "DIAG_RC=1" & call :warn "Poco espacio libre en C: (!FREE_GB! GB)" & call :pshq finding "Poco espacio libre en C: (!FREE_GB! GB)" )
call :step "Comprobando reinicio pendiente"
set "PENDREB=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "PENDREB=1"
if "!PENDREB!"=="1" ( set "DIAG_RC=1" & call :warn "Hay un reinicio pendiente. Lo ideal es reiniciar antes de reparar." ) else ( call :ok "Sin reinicios pendientes" )
call :step "Eventos criticos recientes (causa raiz, ultimos 7 dias)"
call :psh forensics > "%CAP%" 2>&1
for /f "usebackq tokens=1-4 delims=|" %%a in ("%CAP%") do (
    if /i "%%a"=="OK" ( call :ok "Sin errores criticos en 7 dias" ) else ( set "DIAG_RC=1" & echo     %DIM%%%a  [id %%b]  %%c  %%d%R% & >>"%LOGFILE%" echo     %%a [id %%b] %%c %%d )
)
call :step "Diagnostico ampliado (RAM, bateria, red, SMART, arranque)"
call :psh diagfull > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "RAM_STATUS=" & set "BATTERY_PRESENT=" & set "BATTERY_HEALTH_PCT=" & set "NET_CONNECTED=" & set "NET_DNS_OK=" & set "NET_LATENCY_MS=" & set "SMART_PREDICT_FAIL=" & set "BCD_OK="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"RAM_STATUS=" "%CAP%"`) do set "RAM_STATUS=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"BATTERY_PRESENT=" "%CAP%"`) do set "BATTERY_PRESENT=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"BATTERY_HEALTH_PCT=" "%CAP%"`) do set "BATTERY_HEALTH_PCT=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"NET_CONNECTED=" "%CAP%"`) do set "NET_CONNECTED=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"NET_DNS_OK=" "%CAP%"`) do set "NET_DNS_OK=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"NET_LATENCY_MS=" "%CAP%"`) do set "NET_LATENCY_MS=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SMART_PREDICT_FAIL=" "%CAP%"`) do set "SMART_PREDICT_FAIL=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"BCD_OK=" "%CAP%"`) do set "BCD_OK=%%a"
if /i "!RAM_STATUS!"=="suspect" ( set "DIAG_RC=1" & call :warn "La RAM parece sospechosa: ejecuta el diagnostico de memoria (mdsched)." & call :pshq finding "RAM sospechosa: ejecutar mdsched" )
if "!SMART_PREDICT_FAIL!"=="1" ( set "DIAG_RC=1" & call :warn "SMART predice un posible fallo de disco: respalda tus datos cuanto antes." & call :pshq finding "SMART predice un posible fallo de disco" )
if "!NET_CONNECTED!"=="0" ( set "DIAG_RC=1" & call :warn "Sin conectividad de red detectada." & call :pshq finding "Sin conectividad de red" )
if "!NET_CONNECTED!"=="1" if "!NET_DNS_OK!"=="0" ( set "DIAG_RC=1" & call :warn "Hay conexion pero la resolucion DNS falla." & call :pshq finding "DNS con fallos" )
if "!BATTERY_PRESENT!"=="1" if defined BATTERY_HEALTH_PCT if !BATTERY_HEALTH_PCT! lss 60 ( set "DIAG_RC=1" & call :warn "Bateria degradada (!BATTERY_HEALTH_PCT!%% de salud)." & call :pshq finding "Bateria degradada (!BATTERY_HEALTH_PCT!%% de salud)" )
if defined NET_LATENCY_MS if "!NET_DNS_OK!"=="1" call :info "Latencia DNS: !NET_LATENCY_MS! ms"
call :ok "Diagnostico ampliado completado"
if "!DIAG_RC!"=="1" ( call :warn "Diagnostico completado con hallazgos. Revisa avisos y log." & exit /b 1 )
call :ok "Diagnostico previo completado"
exit /b 0
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
call :warn "Fallo en red de seguridad: punto de restauracion o copias del registro no verificados"
if "!RP_OK!"=="0" call :pshq finding "Punto de restauracion no verificado"
if "!REG_OK!"=="0" call :pshq finding "Copias del registro no verificadas"
if "%MODE_AUTO%"=="1" exit /b 3
exit /b 1
:Fase02
if "%DRY%"=="1" ( call :dry "Borraria temporales, papelera, prefetch y cache de entrega" & exit /b 2 )
set "FREE_BEFORE=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1MB)"`) do set "FREE_BEFORE=%%a"
net stop DoSvc /y >nul 2>&1
call :step "Limpiando temporales de usuario y sistema"
del /f /q /s "%TEMP%\*.*" >nul 2>&1
del /f /q /s "%SystemRoot%\Temp\*.*" >nul 2>&1
del /f /q /s "%SystemRoot%\Prefetch\*.*" >nul 2>&1
del /f /q /s "%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*.*" >nul 2>&1
net start DoSvc >nul 2>&1
ipconfig /flushdns >nul 2>&1
call :step "Vaciando papelera y miniaturas"
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
del /f /q /s "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
set "FREE_AFTER=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1MB)"`) do set "FREE_AFTER=%%a"
set /a "FREED=FREE_AFTER-FREE_BEFORE"
if !FREED! lss 0 set "FREED=0"
set "PH_NOTE=liberados ~!FREED! MB"
call :ok "Limpieza inicial completada. Liberados ~!FREED! MB"
exit /b 0
:Fase03
if "%DRY%"=="1" ( call :dry "Comprobaria el disco %SystemDrive% con chkdsk /scan y, si hace falta, programaria CHKDSK" & exit /b 2 )
call :step "CHKDSK /scan /perf en %SystemDrive% (rapido, en caliente)"
chkdsk %SystemDrive% /scan /perf > "%CAP%" 2>&1
set "CHK=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!CHK!"=="0" ( call :ok "CHKDSK sin errores en %SystemDrive%" & exit /b 0 )
call :warn "CHKDSK detecto inconsistencias (codigo !CHK!)"
if "%MODE_AUTO%"=="0" (
    choice /M "Programar comprobacion profunda al proximo reinicio"
    if !errorlevel! equ 2 ( set "PH_NOTE=chkdsk profundo no programado (usuario)" & exit /b 1 )
)
call :step "Programando la comprobacion de disco para el proximo reinicio (independiente del idioma)"
fsutil dirty set %SystemDrive% >nul 2>&1
fsutil dirty query %SystemDrive% > "%CAP%" 2>&1
set "DIRTY=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!DIRTY!"=="0" (
    call :pshq finding "Comprobacion de disco (CHKDSK) programada para el proximo reinicio"
    set "CHKDSK_SCHEDULED=1"
    set "PH_NOTE=chkdsk programado (proximo reinicio)"
    call :ok "Comprobacion de disco programada para el proximo reinicio"
    exit /b 1
)
call :warn "No se pudo marcar el volumen para CHKDSK (fsutil no confirmo el bit dirty)"
set "PH_NOTE=no se pudo programar chkdsk"
exit /b 1
:Fase04
if "%DRY%"=="1" ( call :dry "Optimizaria el disco (TRIM si SSD, desfrag si HDD; nada si el tipo es incierto)" & exit /b 2 )
call :step "Detectando el tipo del disco del sistema"
call :psh mediatype > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "MEDIA=" & set "OPTIMIZE="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MEDIA=" "%CAP%"`) do set "MEDIA=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OPTIMIZE=" "%CAP%"`) do set "OPTIMIZE=%%a"
call :info "Tipo de disco: !MEDIA!  (accion recomendada: !OPTIMIZE!)"
if /i "!OPTIMIZE!"=="TRIM" (
    call :step "SSD detectado: enviando TRIM"
    powershell -NoProfile -Command "Optimize-Volume -DriveLetter %SystemDrive:~0,1% -ReTrim -Verbose" >> "%LOGFILE%" 2>&1
    set "PH_NOTE=TRIM enviado (SSD)"
    call :ok "TRIM completado en %SystemDrive%"
    exit /b 0
)
if /i "!OPTIMIZE!"=="DEFRAG" (
    call :step "HDD detectado: desfragmentando %SystemDrive% (puede tardar)"
    powershell -NoProfile -Command "Optimize-Volume -DriveLetter %SystemDrive:~0,1% -Defrag -Verbose" >> "%LOGFILE%" 2>&1
    set "PH_NOTE=desfragmentado (HDD)"
    call :ok "Desfragmentacion completada en %SystemDrive%"
    exit /b 0
)
call :warn "Tipo de disco indeterminado: no se optimiza para no arriesgar un SSD"
set "PH_NOTE=tipo de disco indeterminado; no se optimiza"
exit /b 1
:Fase05
if "%DRY%"=="1" ( call :dry "Repararia la imagen de componentes con DISM /RestoreHealth" & exit /b 2 )
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
    for /f "tokens=1,* delims==" %%A in (%CAP%) do if "%%A"=="SOURCE" set "LOCSRC=%%B"
    if not "!LOCSRC!"=="" (
        set "RESTORE_SOURCE=!LOCSRC!"
        call :step "Origen offline local encontrado: !RESTORE_SOURCE!"
    ) else (
        ping 1.1.1.1 -n 1 -w 1500 >nul 2>&1
        if !errorlevel! neq 0 call :warn "Sin Internet ni origen offline local: DISM puede agotar el timeout"
    )
)
call :psh dismrestore "!RESTORE_SOURCE!|45" > "%CAP%" 2>&1
set "D=3" & set "DISM_TIMEDOUT=0"
type "%CAP%" >> "%LOGFILE%"
for /f "tokens=1,* delims==" %%A in (%CAP%) do (
    if "%%A"=="EXITCODE" set "D=%%B"
    if "%%A"=="TIMEDOUT" set "DISM_TIMEDOUT=%%B"
)
if "!D!"=="0" ( set "DISM_OK=1" & call :ok "Imagen de componentes reparada (DISM)" ) else if "!DISM_TIMEDOUT!"=="1" ( call :warn "DISM RestoreHealth agoto el timeout de seguridad (45 min)" & set "PH_NOTE=DISM timeout" ) else ( call :warn "DISM RestoreHealth fallo (codigo !D!). Revisa el log." & set "PH_NOTE=DISM fallo codigo !D!" )
call :step "Liberando espacio del almacen de componentes"
dism /online /cleanup-image /startcomponentcleanup >> "%LOGFILE%" 2>&1
set "CLEANRC=!errorlevel!"
if not "!CLEANRC!"=="0" ( call :warn "La limpieza del almacen de componentes termino con codigo !CLEANRC!" & if "!DISM_OK!"=="1" exit /b 1 )
if "!DISM_OK!"=="1" ( call :ok "Almacen de componentes optimizado" & exit /b 0 )
call :warn "DISM no pudo confirmar reparacion de la imagen de componentes"
exit /b 1
:Fase06
if "%DRY%"=="1" ( call :dry "Ejecutaria SFC /scannow y verificaria con una segunda pasada" & exit /b 2 )
call :substep 1 2 "SFC /scannow (primera pasada)"
sfc /scannow > "%CAP%" 2>&1
set "SFCRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :sfc_classify !SFCRC!
if "!SFC_RES!"=="clean" ( call :ok "SFC: sin violaciones de integridad" & exit /b 0 )
if "!SFC_RES!"=="unrepairable" ( call :warn "SFC: danos no reparables. Ejecuta la fase DISM (05) y reintenta." & call :pshq finding "SFC: danos de sistema no reparables (requiere DISM)" & set "PH_NOTE=danos no reparables" & exit /b 1 )
if not "!SFC_RES!"=="repaired" ( call :warn "Resultado de SFC indeterminado. Revisa CBS.log." & set "PH_NOTE=resultado SFC indeterminado" & exit /b 1 )
call :warn "SFC reparo archivos. Reinicia y vuelve a ejecutar la fase 06 para verificar sin bloquear esta sesion."
call :pshq finding "SFC: archivos reparados; requiere reinicio/reverificacion"
set "PH_NOTE=archivos reparados por SFC; requiere reverificacion"
exit /b 1
:Fase07
if "%DRY%"=="1" ( call :dry "Verificaria y, si hace falta, salvaria el repositorio WMI" & exit /b 2 )
call :step "Verificando el repositorio WMI (por codigo de salida, independiente del idioma)"
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
call :warn "WMI sigue danado. Por seguridad, el reset total queda manual: winmgmt /resetrepository"
call :pshq finding "Repositorio WMI danado (requiere reset manual)"
set "PH_NOTE=WMI requiere reset manual"
exit /b 1
:Fase08
if "%DRY%"=="1" ( call :dry "Re-registraria las apps de la Store y reiniciaria el Inicio" & exit /b 2 )
call :step "Re-registrando apps de la Microsoft Store (puede tardar)"
powershell -NoProfile -Command "Get-AppxPackage -AllUsers | ForEach-Object { try { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppXManifest.xml') -ErrorAction SilentlyContinue } catch {} }" >> "%LOGFILE%" 2>&1
call :step "Reiniciando el menu Inicio"
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1
taskkill /f /im ShellExperienceHost.exe >nul 2>&1
call :ok "Apps de Store re-registradas e Inicio reiniciado"
exit /b 0
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
call :ok "Busqueda, caches y spooler restablecidos"
exit /b 0
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
:Fase11
if "%DRY%"=="1" ( call :dry "Reiniciaria winsock, IP, DNS y proxy" & exit /b 2 )
call :step "Reiniciando Winsock e IP"
netsh winsock reset >> "%LOGFILE%" 2>&1
netsh int ip reset >> "%LOGFILE%" 2>&1
call :step "Renovando DHCP y vaciando DNS"
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
ipconfig /flushdns >nul 2>&1
call :step "Quitando proxy de WinHTTP"
netsh winhttp reset proxy >> "%LOGFILE%" 2>&1
call :step "Revisando el archivo hosts"
findstr /v /b "#" "%SystemRoot%\System32\drivers\etc\hosts" | findstr /r "[0-9]" >nul 2>&1
if !errorlevel! equ 0 ( call :warn "El archivo hosts tiene entradas activas. Revisalo por si bloquea webs." ) else ( call :ok "Archivo hosts limpio" )
set "PH_NOTE=winsock/ip reset; requiere reinicio"
call :ok "Pila de red restablecida (winsock requiere reinicio)"
exit /b 0
:Fase12
if "%DRY%"=="1" ( call :dry "Reaplicaria las directivas de grupo (gpupdate /force)" & exit /b 2 )
call :step "Reaplicando directivas de grupo"
gpupdate /force >> "%LOGFILE%" 2>&1
call :ok "Directivas reaplicadas (gpupdate /force)"
exit /b 0
:Fase13
call :step "Comprobando si Windows Update esta bloqueado a proposito"
set "WU_BLOCKED=0"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate >nul 2>&1 && set "WU_BLOCKED=1"
sc query wuauserv | findstr /i "DISABLED" >nul 2>&1 && set "WU_BLOCKED=1"
if "!WU_BLOCKED!"=="1" if "%KEEPWU%"=="1" ( call :info "WU bloqueado y se pidio /keepwu: se respeta y se salta la fase" & set "PH_NOTE=bloqueo de WU respetado" & exit /b 2 )
if "%QUICK%"=="1" (
    call :step "Verificando estado del servicio Windows Update (solo escaneo)"
    sc query wuauserv > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    findstr /i "RUNNING" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 ( call :ok "Servicio wuauserv en ejecucion" & exit /b 0 )
    findstr /i "STOPPED" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :step "Intentando arrancar wuauserv (solo comprobacion de servicio)"
        net start wuauserv > "%CAP%" 2>&1
        type "%CAP%" >> "%LOGFILE%"
        if !errorlevel! equ 0 ( call :ok "Servicio wuauserv arrancado correctamente" & exit /b 0 )
    )
    call :warn "El servicio Windows Update no esta funcionando o esta desactivado"
    exit /b 1
)
if "%DRY%"=="1" ( call :dry "Repararia servicios y cache de Windows Update" & exit /b 2 )
call :step "Deteniendo servicios de Windows Update"
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop appidsvc /y >nul 2>&1
net stop cryptsvc /y >nul 2>&1
net stop msiserver /y >nul 2>&1
call :step "Limpiando datos de trabajos BITS (qmgr*.dat)"
del /f /q "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1
del /f /q "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1
call :step "Respaldando y vaciando cache (SoftwareDistribution, catroot2)"
set "WU_WARN=0"
if exist "%SystemRoot%\SoftwareDistribution" (
    move "%SystemRoot%\SoftwareDistribution" "%BKDIR%\SoftwareDistribution_%TIMESTAMP%" >nul 2>&1
    call :psh moveresult "%SystemRoot%\SoftwareDistribution|%BKDIR%\SoftwareDistribution_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "No se pudo mover SoftwareDistribution" )
)
if exist "%SystemRoot%\System32\catroot2" (
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
    call :psh moveresult "%SystemRoot%\System32\catroot2|%BKDIR%\catroot2_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "No se pudo mover catroot2" )
)
call :step "Eliminando configuracion de cliente WSUS obsoleta"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f >nul 2>&1
call :step "Re-registrando DLLs de Windows Update y BITS"
pushd "%SystemRoot%\System32"
for %%D in (atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll wuwebv.dll) do (
    regsvr32 /s %%D >> "%LOGFILE%" 2>&1
)
popd
call :step "Reiniciando servicios"
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start appidsvc >nul 2>&1
net start wuauserv >nul 2>&1
set "WUSTART=!errorlevel!"
net start msiserver >nul 2>&1
if "!WUSTART!" neq "0" ( call :warn "El servicio wuauserv no pudo arrancar tras el registro de DLLs" & set "WU_WARN=1" )
call :step "Forzando deteccion de actualizaciones"
wuauclt /resetauthorization /detectnow >nul 2>&1
if "!WU_WARN!"=="1" ( set "PH_NOTE=cache no movida o servicio fallo" & call :warn "Windows Update: la cache no se movio o wuauserv no arranco" & exit /b 1 )
call :ok "Windows Update reparado: cache vaciada, DLLs registradas, deteccion forzada"
exit /b 0
:Fase14
if "%DRY%"=="1" ( call :dry "Repararia los origenes de winget y los actualizaria" & exit /b 2 )
call :step "Comprobando winget"
where winget >nul 2>&1
if !errorlevel! neq 0 ( call :warn "winget no esta disponible. Instala App Installer desde la Store." & set "PH_NOTE=winget ausente" & exit /b 1 )
call :step "Reparando origenes y actualizando winget"
winget source reset --force >> "%LOGFILE%" 2>&1
winget source update >> "%LOGFILE%" 2>&1
call :ok "winget operativo y origenes actualizados"
exit /b 0
:Fase15
call :step "Buscando dispositivos o drivers con error"
call :psh devices > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /b /c:"OK|" "%CAP%" >nul 2>&1
if !errorlevel! equ 0 ( call :ok "Sin dispositivos con problema" & exit /b 0 )
set "DEVN=0"
for /f "usebackq tokens=1-3 delims=|" %%a in ("%CAP%") do (
    if /i "%%a"=="PROB" ( set /a "DEVN+=1" & echo     %YE%[dev ]%R%  codigo %%b  -  %%c & >>"%LOGFILE%" echo     [dev] codigo %%b - %%c )
)
call :warn "Hay !DEVN! dispositivo(s) con error. Actualiza su driver desde la web del fabricante."
set "PH_NOTE=!DEVN! dispositivos con error"
exit /b 1
:Fase16
if "%DRY%"=="0" (
    call :step "Limpieza profunda final"
    del /f /q /s "%SystemRoot%\Logs\CBS\CbsPersist_*.log" >nul 2>&1
    rem (v3.1) liberar espacio: logs de instalacion antiguos (seguros de borrar)
    del /f /q "%SystemRoot%\Panther\*.log" >nul 2>&1
    del /f /q "%SystemRoot%\inf\setupapi.dev.log" >nul 2>&1
    del /f /q "%SystemRoot%\inf\setupapi.setup.log" >nul 2>&1
    ipconfig /flushdns >nul 2>&1
)
call :step "Recalculando la salud del sistema"
call :psh score > "%CAP%" 2>&1
set "SCORE_AFTER="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SCORE=" "%CAP%"`) do set "SCORE_AFTER=%%a"
if defined SCORE_AFTER ( call :pshq setafter "!SCORE_AFTER!" & call :info "Salud despues: !SCORE_AFTER!/100" )
call :step "Generando informe HTML"
set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
call :psh report "%REPORT%"
if exist "%REPORT%" ( call :ok "Informe creado en !REPORT!" & set "PH_NOTE=informe HTML generado" ) else ( call :warn "No se pudo generar el informe HTML" )
exit /b 0
