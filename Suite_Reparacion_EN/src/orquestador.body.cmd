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
echo  %DIM%System:%R%
for /f "usebackq tokens=1,* delims==" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%HELPER%" -Action sysinfo -Work "%WORK%"`) do echo    %CY%%%a%R%  %%b
echo(
call :step "Calculating initial system health"
call :psh score > "%CAP%" 2>&1
set "SCORE_BEFORE="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SCORE=" "%CAP%"`) do set "SCORE_BEFORE=%%a"
if defined SCORE_BEFORE ( call :pshq setbefore "!SCORE_BEFORE!" & call :info "Current health: !SCORE_BEFORE!/100" )
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b /c:"REASON=" "%CAP%"`) do call :pshq finding "%%b"

:: --- menu interactivo solo si no se ha especificado ningun modo por argumento ---
set "MENU_SESSION=0"
if "%MODE_AUTO%"=="0" if not defined SEL_FASES if "%USE_TRIAGE%"=="0" if "!RESUME_ACTIVE!"=="0" if "%QUICK%"=="0" if "%PLAN_MODE%"=="0" if "%MANUAL%"=="0" if "%DRY%"=="0" set "MENU_SESSION=1"
:session_loop
if "!MENU_SESSION!"=="1" call :menu
:: (Task 8.1 / Bug 1) If "Exit" was chosen in the menu, close cleanly with NO phases.
if "!DO_EXIT!"=="1" ( endlocal & exit /b 0 )

:: --- (v3.1) Plan personalizado: ejecuta el asistente y termina ---
if "%PLAN_MODE%"=="1" call :plan_wizard
if "%PLAN_MODE%"=="1" goto :tail_end_noop

:: --- triage: convierte la recomendacion del Cerebro en SEL_FASES ---
if "%USE_TRIAGE%"=="1" (
    call :step "Auto-triage: deciding which phases you need"
    call :psh triage > "%CAP%" 2>&1
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"RECOMENDADAS=" "%CAP%"`) do set "SEL_FASES=%%a"
    call :info "Triage recomienda: !SEL_FASES!"
)

:: --- (v3.1) /quick: fast inspection, diagnosis only (overrides selection/triage) ---
rem (v3.1) Inspeccion RAPIDA con submodos (scan / scan+fix); termina al acabar.
if "%QUICK%"=="1" if "%QUICK_WIZ%"=="1" call :quick_wizard
if "%QUICK%"=="1" if not "%QUICK_WIZ%"=="1" call :quick_run %QSUB%
if "%QUICK%"=="1" goto :tail_end_noop

:: --- (Task 8.2 / Bug 4 / Req 6) Normalizar la seleccion con el Cerebro ---
if defined SEL_FASES call :normalize_selection

:: --- (intuitiveness) confirm before real changes (not in auto/dry/manual) ---
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

set "SUM="
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
echo  %B%%WH%What do you want to do%R%
echo  %DIM%Not sure? Press 1 ^(fixes everything^) or 2 ^(only what is needed^).%R%
echo(
echo    %GR%1%R%  FULL automatic repair    %DIM%- all phases - changes + reboot - ~10-20 min%R%
echo    %GR%2%R%  Smart repair             %DIM%- auto-triage - only what is needed - ~5-15 min%R%
echo    %GR%3%R%  QUICK inspection         %DIM%- scan, or scan + safe repair - ~1-2 min%R%
echo    %GR%4%R%  MANUAL mode              %DIM%- one command per phase, at your pace%R%
echo    %GR%5%R%  Guided CUSTOM PLAN       %DIM%- choose all, review and confirm - ~5-15 min%R%
echo    %GR%6%R%  Choose specific phases   %DIM%- you decide which phases run - variable%R%
echo    %GR%7%R%  Simulation ^(dry-run^)     %DIM%- touches nothing, only shows what it would do - ~1 min%R%
echo    %GR%8%R%  Guide                    %DIM%- what each phase and mode does - reading%R%
echo    %GR%0%R%  Exit
echo(
choice /C 123456780 /N /M "  Choose an option: "
set "OPC=!errorlevel!"
rem choice: 1..8 -> errorlevel 1..8 ; "0" (Exit) -> 9
if "!OPC!"=="9" ( set "DO_EXIT=1" & exit /b 0 )
if "!OPC!"=="8" ( call :guide & goto :menu_again )
if "!OPC!"=="2" set "USE_TRIAGE=1"
if "!OPC!"=="3" ( set "QUICK=1" & set "QUICK_WIZ=1" )
if "!OPC!"=="4" set "MANUAL=1"
if "!OPC!"=="5" set "PLAN_MODE=1"
if "!OPC!"=="7" set "DRY=1"
if "!OPC!"=="6" (
    echo(
    echo  Available phases:
    for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do ( call :title_of %%P & echo    %CY%%%P%R%  !PH_TITLE! )
    echo(
    set /p "SEL_FASES=  Type the phases separated by commas (e.g. 05,06,13): "
)
exit /b 0

:: --- GUIA: explica cada modo y lista las fases con su numero y proposito ---
:guide
cls
call :bigbanner
echo  %B%%WH%QUICK GUIDE%R%   %DIM%what each mode and phase does%R%
echo(
echo  %B%%CY%MODES%R%
echo    %GR%1%R% Full repair: runs all 17 phases automatically.
echo    %GR%2%R% Smart ^(triage^): only the phases the diagnosis recommends.
echo    %GR%3%R% Quick: scan only ^(changes nothing^) or scan + safe repair.
echo    %GR%4%R% Manual: in each phase YOU pick the command and it runs right away.
echo    %GR%5%R% Guided plan: pick a command per phase, review the plan and confirm.
echo    %GR%6%R% Choose phases: type which phase numbers to run ^(see list below^).
echo    %GR%7%R% Simulation ^(/dry^): shows what it would do without changing anything.
echo(
echo  %B%%CY%PHASES%R%  %DIM%^(use these numbers in option 6^)%R%
for %%P in (00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16) do call :guide_line %%P
echo(
echo  %DIM%Expert tip: add /cmd to see the exact command of each option.%R%
echo  %DIM%E.g.: Repair_Suite_AllInOne.bat /cmd /manual%R%
echo(
echo  Press any key to return to the menu...
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
if defined _INVALID call :warn "Invalid phases ignored: !_INVALID!"
set "SEL_FASES=!_NORM!"
if not defined SEL_FASES call :warn "No valid phase selected; no phase will run"
exit /b 0

:: --- (Task 8.3 / Bug 2 / Req 4) carga el checkpoint y prepara la reanudacion
:resume_load
call :checkpoint_load
if /i not "!CP_RESULT!"=="OK" ( call :info "/resume: no saved checkpoint; running normally" & exit /b 0 )
if not "!CP_VALID!"=="1" ( call :info "/resume: the checkpoint is invalid or has expired; running normally" & exit /b 0 )
set "RESUME_ACTIVE=1"
set "SEL_FASES=!CP_SELECTION!"
set "COMPLETED=!CP_COMPLETED!"
set "RESUME_NEXT=!CP_NEXT!"
set "MODE_AUTO=!CP_MODE_AUTO!"
set "NO_REBOOT=!CP_MODE_NOREBOOT!"
set "KEEPWU=!CP_MODE_KEEPWU!"
set "DRY=!CP_MODE_DRY!"
set "USE_TRIAGE=!CP_MODE_TRIAGE!"
if defined RESUME_NEXT ( call :info "/resume: resuming from phase !RESUME_NEXT! (completed: !COMPLETED!)" ) else ( call :info "/resume: the checkpoint has no pending phases" )
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
        ) else ( call :info "Phase %%P already completed (resume): skipped" )
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
echo  %B%%WH%SUMMARY%R%
echo %BL%============================================================%R%
for %%S in (!SUM!) do (
    for /f "tokens=1-3 delims=|" %%a in ("%%S") do (
        set "RES=%%b"
        set "COL=%GR%"
        if "%%b"=="WARN" set "COL=%YE%"
        if "%%b"=="SKIP" set "COL=%DIM%"
        if "%%b"=="ERROR" set "COL=%RE%"
        echo    Phase %%a   !COL!%%b%R%   %DIM%%%c s%R%
    )
)
echo(
:: --- (v3.1) asegurar puntuacion final SIEMPRE (aunque no corriera la Phase 16) ---
if not defined SCORE_AFTER (
    call :psh score > "%CAP%" 2>&1
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SCORE=" "%CAP%"`) do set "SCORE_AFTER=%%a"
    if defined SCORE_AFTER call :pshq setafter "!SCORE_AFTER!" >nul 2>&1
)
if defined SCORE_BEFORE if defined SCORE_AFTER echo    %WH%Health:%R%  !SCORE_BEFORE!/100  %DIM%-^>%R%  %GR%!SCORE_AFTER!/100%R%
if not defined SCORE_BEFORE if defined SCORE_AFTER echo    %WH%Health:%R%  %GR%!SCORE_AFTER!/100%R%
:: --- (v3.1) generar el informe SIEMPRE, aunque la Phase 16 no se ejecutara ---
set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
if not exist "!REPORT!" call :psh report "!REPORT!" > "%CAP%" 2>&1
if exist "!REPORT!" (
    echo    %WH%Report:%R%  !REPORT!
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
    if exist "!PKG!" echo    %WH%Support:%R%  !PKG!
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
echo    %WH%Global result:%R%  !AGGCOL!!AGG_RES!%R%
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
        call :warn "The PC will reboot in 60 seconds. Close this window to cancel."
        shutdown /r /t 60 /c "Reboot after WPI repair" >nul 2>&1
        goto :tail_end
    )
    call :checkpoint_clear
    goto :tail_end
)
echo(
choice /M "Do you want to reboot now to apply all changes"
if !errorlevel! equ 1 ( call :prepare_resume_checkpoint & set "DID_REBOOT=1" & shutdown /r /t 5 >nul 2>&1 ) else ( call :checkpoint_clear )
:tail_end
if "!DID_REBOOT!"=="1" ( endlocal & exit /b %WORST_RC% )
if "!MENU_SESSION!"=="1" ( echo( & echo  %DIM%Press a key to return to the menu...%R% & pause >nul & cls & call :bigbanner & call :reset_session & goto :session_loop )
if "%MODE_AUTO%"=="0" if "%DRY%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %WORST_RC%

:: --- guarda checkpoint antes de reiniciar (selection completa si era todo) ---
:prepare_resume_checkpoint
set "_SEL_SAVE=!SEL_FASES!"
if not defined _SEL_SAVE set "_SEL_SAVE=00,01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16"
set "SEL_FASES=!_SEL_SAVE!"
call :checkpoint_save
exit /b 0

:: --- salida limpia sin ejecutar fases (menu "Exit", Bug 1 / Task 8.1) ---
:tail_end_noop
if "!MENU_SESSION!"=="1" ( echo( & echo  %DIM%Press a key to return to the menu...%R% & pause >nul & cls & call :bigbanner & call :reset_session & goto :session_loop )
if "%MODE_AUTO%"=="0" if "%DRY%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b 0
:confirm_changes
if "%MODE_AUTO%"=="1" exit /b 0
if "%DRY%"=="1" exit /b 0
if "%MANUAL%"=="1" exit /b 0
echo(
echo  %YE%Notice:%R% REAL repairs will run on this PC.
echo  %DIM%A restore point (Phase 01) is created before the heavy changes.%R%
choice /C YN /N /M "  Continue with the repair? (Y/N): "
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
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b 3

:: --- (Task 10.3 / Req 18) ejecuta el self-test y devuelve su codigo ---
:run_selftest
call :selftest
set "ST_RC=!errorlevel!"
if "%MODE_AUTO%"=="0" ( echo( & echo  Press any key to close... & pause >nul )
endlocal & exit /b %ST_RC%

:Fase00
set "DIAG_RC=0"
call :step "Checking disk SMART health"
powershell -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus | Format-Table -AutoSize" > "%CAP%" 2>&1
type "%CAP%"
type "%CAP%" >> "%LOGFILE%"
findstr /i "Unhealthy Warning" "%CAP%" >nul 2>&1 && ( set "DIAG_RC=1" & call :warn "A disk reports degraded SMART. Back up your data before continuing." & call :pshq finding "Disk with degraded SMART" )
call :step "Free space on C:"
set "FREE_GB=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB)"`) do set "FREE_GB=%%a"
call :info "C: has !FREE_GB! GB free"
if !FREE_GB! lss 10 ( set "DIAG_RC=1" & call :warn "Low free space on C: (!FREE_GB! GB)" & call :pshq finding "Low free space on C: (!FREE_GB! GB)" )
call :step "Checking for a pending reboot"
set "PENDREB=0"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1 && set "PENDREB=1"
if "!PENDREB!"=="1" ( set "DIAG_RC=1" & call :warn "There is a pending reboot. It's best to reboot before repairing." ) else ( call :ok "No pending reboots" )
call :step "Recent critical events (root cause, last 7 days)"
call :psh forensics > "%CAP%" 2>&1
for /f "usebackq tokens=1-4 delims=|" %%a in ("%CAP%") do (
    if /i "%%a"=="OK" ( call :ok "No critical errors in 7 days" ) else ( set "DIAG_RC=1" & echo     %DIM%%%a  [id %%b]  %%c  %%d%R% & >>"%LOGFILE%" echo     %%a [id %%b] %%c %%d )
)
call :step "Extended diagnosis (RAM, battery, network, SMART, boot)"
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
if /i "!RAM_STATUS!"=="suspect" ( set "DIAG_RC=1" & call :warn "RAM looks suspicious: run the memory diagnostic (mdsched)." & call :pshq finding "RAM suspicious: run mdsched" )
if "!SMART_PREDICT_FAIL!"=="1" ( set "DIAG_RC=1" & call :warn "SMART predicts a possible disk failure: back up your data as soon as possible." & call :pshq finding "SMART predicts a possible disk failure" )
if "!NET_CONNECTED!"=="0" ( set "DIAG_RC=1" & call :warn "No network connectivity detected." & call :pshq finding "No network connectivity" )
if "!NET_CONNECTED!"=="1" if "!NET_DNS_OK!"=="0" ( set "DIAG_RC=1" & call :warn "There is a connection but DNS resolution fails." & call :pshq finding "DNS failing" )
if "!BATTERY_PRESENT!"=="1" if defined BATTERY_HEALTH_PCT if !BATTERY_HEALTH_PCT! lss 60 ( set "DIAG_RC=1" & call :warn "Battery degraded (!BATTERY_HEALTH_PCT!%% health)." & call :pshq finding "Battery degraded (!BATTERY_HEALTH_PCT!%% health)" )
if defined NET_LATENCY_MS if "!NET_DNS_OK!"=="1" call :info "DNS latency: !NET_LATENCY_MS! ms"
call :ok "Extended diagnosis completed"
if "!DIAG_RC!"=="1" ( call :warn "Diagnosis completed with findings. Review warnings and log." & exit /b 1 )
call :ok "Initial diagnosis completed"
exit /b 0
:Fase01
if "%DRY%"=="1" ( call :dry "Would create a restore point and back up the registry" & exit /b 2 )
call :step "Creating restore point (may take a while)"
call :psh restorepoint > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /c:"RESULT=OK" "%CAP%" >nul 2>&1
if !errorlevel! equ 0 ( call :ok "Restore point created and verified" ) else ( call :warn "Could not create the restore point (continuing anyway)" )
call :step "Backing up the registry (SOFTWARE and SYSTEM)"
reg export HKLM\SOFTWARE "%BKDIR%\SOFTWARE_%TIMESTAMP%.reg" /y >nul 2>&1
reg export HKLM\SYSTEM "%BKDIR%\SYSTEM_%TIMESTAMP%.reg" /y >nul 2>&1
call :info "Registry backup requested in Backups"
call :step "Verifying safety net and backups"
call :psh checkbackups "%BKDIR%|%TIMESTAMP%" > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "RP_OK=0"
set "REG_OK=0"
for /f "tokens=1,2 delims==" %%A in (%CAP%) do (
    if "%%A"=="RP_OK" set "RP_OK=%%B"
    if "%%A"=="REG_OK" set "REG_OK=%%B"
)
if "!RP_OK!"=="1" if "!REG_OK!"=="1" (
    call :ok "Safety net verified (Restore point and registry backups OK)"
    exit /b 0
)
call :warn "Safety net failed: restore point or registry backups not verified"
if "!RP_OK!"=="0" call :pshq finding "Restore point not verified"
if "!REG_OK!"=="0" call :pshq finding "Registry backups not verified"
if "%MODE_AUTO%"=="1" exit /b 3
exit /b 1
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
:Fase03
if "%DRY%"=="1" ( call :dry "Would check %SystemDrive% with chkdsk /scan and, if needed, schedule CHKDSK" & exit /b 2 )
call :step "CHKDSK /scan /perf on %SystemDrive% (fast, online)"
chkdsk %SystemDrive% /scan /perf > "%CAP%" 2>&1
set "CHK=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!CHK!"=="0" ( call :ok "CHKDSK found no errors on %SystemDrive%" & exit /b 0 )
call :warn "CHKDSK detected inconsistencies (code !CHK!)"
if "%MODE_AUTO%"=="0" (
    choice /M "Schedule a deep check at the next reboot"
    if !errorlevel! equ 2 ( set "PH_NOTE=deep chkdsk not scheduled (user)" & exit /b 1 )
)
call :step "Scheduling the disk check for the next reboot (language-independent)"
fsutil dirty set %SystemDrive% >nul 2>&1
fsutil dirty query %SystemDrive% > "%CAP%" 2>&1
set "DIRTY=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
if "!DIRTY!"=="0" (
    call :pshq finding "Disk check (CHKDSK) scheduled for the next reboot"
    set "CHKDSK_SCHEDULED=1"
    set "PH_NOTE=chkdsk scheduled (next reboot)"
    call :ok "Disk check scheduled for the next reboot"
    exit /b 1
)
call :warn "Could not mark the volume for CHKDSK (fsutil did not confirm the dirty bit)"
set "PH_NOTE=could not schedule chkdsk"
exit /b 1
:Fase04
if "%DRY%"=="1" ( call :dry "Would optimize the disk (TRIM if SSD, defrag if HDD; nothing if type is uncertain)" & exit /b 2 )
call :step "Detecting the system disk type"
call :psh mediatype > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
set "MEDIA=" & set "OPTIMIZE="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MEDIA=" "%CAP%"`) do set "MEDIA=%%a"
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"OPTIMIZE=" "%CAP%"`) do set "OPTIMIZE=%%a"
call :info "Disk type: !MEDIA!  (recommended action: !OPTIMIZE!)"
if /i "!OPTIMIZE!"=="TRIM" (
    call :step "SSD detected: sending TRIM"
    powershell -NoProfile -Command "Optimize-Volume -DriveLetter %SystemDrive:~0,1% -ReTrim -Verbose" >> "%LOGFILE%" 2>&1
    set "PH_NOTE=TRIM enviado (SSD)"
    call :ok "TRIM completed on %SystemDrive%"
    exit /b 0
)
if /i "!OPTIMIZE!"=="DEFRAG" (
    call :step "HDD detected: defragmenting %SystemDrive% (may take a while)"
    powershell -NoProfile -Command "Optimize-Volume -DriveLetter %SystemDrive:~0,1% -Defrag -Verbose" >> "%LOGFILE%" 2>&1
    set "PH_NOTE=defragmented (HDD)"
    call :ok "Defragmentation completed on %SystemDrive%"
    exit /b 0
)
call :warn "Disk type undetermined: skipping optimization to avoid risking an SSD"
set "PH_NOTE=undetermined disk type; skipped optimization"
exit /b 1
:Fase05
if "%DRY%"=="1" ( call :dry "Would repair the component image with DISM /RestoreHealth" & exit /b 2 )
call :step "DISM CheckHealth"
dism /online /cleanup-image /checkhealth >> "%LOGFILE%" 2>&1
call :step "DISM ScanHealth (varios minutos)"
dism /online /cleanup-image /scanhealth >> "%LOGFILE%" 2>&1
call :step "DISM RestoreHealth (puede tardar bastante)"
set "DISM_OK=0"
set "RESTORE_SOURCE=%CUSTOM_SOURCE%"
if not "!RESTORE_SOURCE!"=="" (
    call :step "Using forced custom source: !RESTORE_SOURCE!"
) else (
    call :psh findlocalsource > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "LOCSRC="
    for /f "tokens=1,* delims==" %%A in (%CAP%) do if "%%A"=="SOURCE" set "LOCSRC=%%B"
    if not "!LOCSRC!"=="" (
        set "RESTORE_SOURCE=!LOCSRC!"
        call :step "Local offline source found: !RESTORE_SOURCE!"
    ) else (
        ping 1.1.1.1 -n 1 -w 1500 >nul 2>&1
        if !errorlevel! neq 0 call :warn "No Internet or local offline source: DISM may hit the timeout"
    )
)
call :psh dismrestore "!RESTORE_SOURCE!|45" > "%CAP%" 2>&1
set "D=3" & set "DISM_TIMEDOUT=0"
type "%CAP%" >> "%LOGFILE%"
for /f "tokens=1,* delims==" %%A in (%CAP%) do (
    if "%%A"=="EXITCODE" set "D=%%B"
    if "%%A"=="TIMEDOUT" set "DISM_TIMEDOUT=%%B"
)
if "!D!"=="0" ( set "DISM_OK=1" & call :ok "Component image repaired (DISM)" ) else if "!DISM_TIMEDOUT!"=="1" ( call :warn "DISM RestoreHealth hit the safety timeout (45 min)" & set "PH_NOTE=DISM timeout" ) else ( call :warn "DISM RestoreHealth failed (code !D!). Check the log." & set "PH_NOTE=DISM failed code !D!" )
call :step "Freeing space from the component store"
dism /online /cleanup-image /startcomponentcleanup >> "%LOGFILE%" 2>&1
set "CLEANRC=!errorlevel!"
if not "!CLEANRC!"=="0" ( call :warn "Component store cleanup finished with code !CLEANRC!" & if "!DISM_OK!"=="1" exit /b 1 )
if "!DISM_OK!"=="1" ( call :ok "Component store optimized" & exit /b 0 )
call :warn "DISM could not confirm component image repair"
exit /b 1
:Fase06
if "%DRY%"=="1" ( call :dry "Would run SFC /scannow and verify with a second pass" & exit /b 2 )
call :substep 1 2 "SFC /scannow (primera pasada)"
sfc /scannow > "%CAP%" 2>&1
set "SFCRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :sfc_classify !SFCRC!
if "!SFC_RES!"=="clean" ( call :ok "SFC: sin violaciones de integridad" & exit /b 0 )
if "!SFC_RES!"=="unrepairable" ( call :warn "SFC: unrepairable damage. Run phase DISM (05) and retry." & call :pshq finding "SFC: unrepairable system damage (requires DISM)" & set "PH_NOTE=unrepairable damage" & exit /b 1 )
if not "!SFC_RES!"=="repaired" ( call :warn "Undetermined SFC result. Review CBS.log." & set "PH_NOTE=undetermined SFC result" & exit /b 1 )
call :warn "SFC repaired files. Reboot and run phase 06 again to verify without blocking this session."
call :pshq finding "SFC: files repaired; reboot/reverification required"
set "PH_NOTE=files repaired by SFC; reverification required"
exit /b 1
:Fase07
if "%DRY%"=="1" ( call :dry "Would verify and, if needed, salvage the WMI repository" & exit /b 2 )
call :step "Verifying the WMI repository (by exit code, language-independent)"
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "WMI repository coherent" & exit /b 0 )
call :warn "WMI inconsistent: trying to salvage"
winmgmt /salvagerepository >> "%LOGFILE%" 2>&1
winmgmt /verifyrepository > "%CAP%" 2>&1
set "WMIRC=!errorlevel!"
type "%CAP%" >> "%LOGFILE%"
call :wmi_consistent !WMIRC!
if "!WMI_OK!"=="1" ( call :ok "WMI repaired (salvage)" & exit /b 0 )
call :warn "WMI is still damaged. For safety, full reset stays manual: winmgmt /resetrepository"
call :pshq finding "WMI repository damaged (requires manual reset)"
set "PH_NOTE=WMI requires manual reset"
exit /b 1
:Fase08
if "%DRY%"=="1" ( call :dry "Would re-register Store apps and restart the Start menu" & exit /b 2 )
call :step "Re-registering Microsoft Store apps (may take a while)"
powershell -NoProfile -Command "Get-AppxPackage -AllUsers | ForEach-Object { try { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + '\AppXManifest.xml') -ErrorAction SilentlyContinue } catch {} }" >> "%LOGFILE%" 2>&1
call :step "Restarting the Start menu"
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1
taskkill /f /im ShellExperienceHost.exe >nul 2>&1
call :ok "Store apps re-registered and Start restarted"
exit /b 0
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
:Fase10
if "%DRY%"=="1" ( call :dry "Would sync the clock and refresh the root certificates" & exit /b 2 )
call :step "Synchronizing the system clock"
net start w32time >nul 2>&1
w32tm /resync /force >> "%LOGFILE%" 2>&1
call :step "Updating trusted root certificates"
certutil -generateSSTFromWU "%WORK%\roots.sst" >> "%LOGFILE%" 2>&1
if exist "%WORK%\roots.sst" (
    powershell -NoProfile -Command "try { Import-Certificate -FilePath '%WORK%\roots.sst' -CertStoreLocation Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Out-Null } catch {}" >> "%LOGFILE%" 2>&1
    call :ok "Root certificates refreshed and clock synchronized"
) else (
    call :warn "Could not download root certificates (no Internet). Clock synchronized."
    set "PH_NOTE=no Internet for certificates"
)
exit /b 0
:Fase11
if "%DRY%"=="1" ( call :dry "Would reset winsock, IP, DNS and proxy" & exit /b 2 )
call :step "Resetting Winsock and IP"
netsh winsock reset >> "%LOGFILE%" 2>&1
netsh int ip reset >> "%LOGFILE%" 2>&1
call :step "Renewing DHCP and flushing DNS"
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
ipconfig /flushdns >nul 2>&1
call :step "Removing WinHTTP proxy"
netsh winhttp reset proxy >> "%LOGFILE%" 2>&1
call :step "Reviewing hosts file"
findstr /v /b "#" "%SystemRoot%\System32\drivers\etc\hosts" | findstr /r "[0-9]" >nul 2>&1
if !errorlevel! equ 0 ( call :warn "The hosts file has active entries. Review it in case it blocks sites." ) else ( call :ok "Clean hosts file" )
set "PH_NOTE=winsock/ip reset; requires reboot"
call :ok "Network stack reset (winsock requires reboot)"
exit /b 0
:Fase12
if "%DRY%"=="1" ( call :dry "Would re-apply the group policies (gpupdate /force)" & exit /b 2 )
call :step "Re-applying group policies"
gpupdate /force >> "%LOGFILE%" 2>&1
call :ok "Policies re-applied (gpupdate /force)"
exit /b 0
:Fase13
call :step "Checking whether Windows Update is intentionally blocked"
set "WU_BLOCKED=0"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate >nul 2>&1 && set "WU_BLOCKED=1"
sc query wuauserv | findstr /i "DISABLED" >nul 2>&1 && set "WU_BLOCKED=1"
if "!WU_BLOCKED!"=="1" if "%KEEPWU%"=="1" ( call :info "WU blocked and /keepwu requested: respected and phase skipped" & set "PH_NOTE=WU blocking respected" & exit /b 2 )
if "%QUICK%"=="1" (
    call :step "Checking Windows Update service status (scan only)"
    sc query wuauserv > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    findstr /i "RUNNING" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 ( call :ok "wuauserv service is running" & exit /b 0 )
    findstr /i "STOPPED" "%CAP%" >nul 2>&1
    if !errorlevel! equ 0 (
        call :step "Trying to start wuauserv (service check only)"
        net start wuauserv > "%CAP%" 2>&1
        type "%CAP%" >> "%LOGFILE%"
        if !errorlevel! equ 0 ( call :ok "wuauserv service started successfully" & exit /b 0 )
    )
    call :warn "The Windows Update service is not running or is disabled"
    exit /b 1
)
if "%DRY%"=="1" ( call :dry "Would repair Windows Update services and cache" & exit /b 2 )
call :step "Stopping Windows Update services"
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop appidsvc /y >nul 2>&1
net stop cryptsvc /y >nul 2>&1
net stop msiserver /y >nul 2>&1
call :step "Cleaning BITS job data (qmgr*.dat)"
del /f /q "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1
del /f /q "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" >nul 2>&1
call :step "Backing up and clearing cache (SoftwareDistribution, catroot2)"
set "WU_WARN=0"
if exist "%SystemRoot%\SoftwareDistribution" (
    move "%SystemRoot%\SoftwareDistribution" "%BKDIR%\SoftwareDistribution_%TIMESTAMP%" >nul 2>&1
    call :psh moveresult "%SystemRoot%\SoftwareDistribution|%BKDIR%\SoftwareDistribution_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "Could not move SoftwareDistribution" )
)
if exist "%SystemRoot%\System32\catroot2" (
    move "%SystemRoot%\System32\catroot2" "%BKDIR%\catroot2_%TIMESTAMP%" >nul 2>&1
    call :psh moveresult "%SystemRoot%\System32\catroot2|%BKDIR%\catroot2_%TIMESTAMP%" > "%CAP%" 2>&1
    type "%CAP%" >> "%LOGFILE%"
    set "MOVED="
    for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"MOVED=" "%CAP%"`) do set "MOVED=%%a"
    if not "!MOVED!"=="1" ( set "WU_WARN=1" & call :warn "Could not move catroot2" )
)
call :step "Removing stale WSUS client settings"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f >nul 2>&1
call :step "Re-registering Windows Update and BITS DLLs"
pushd "%SystemRoot%\System32"
for %%D in (atl.dll urlmon.dll mshtml.dll shdocvw.dll browseui.dll jscript.dll vbscript.dll scrrun.dll msxml.dll msxml3.dll msxml6.dll actxprxy.dll softpub.dll wintrust.dll dssenh.dll rsaenh.dll gpkcsp.dll sccbase.dll slbcsp.dll cryptdlg.dll oleaut32.dll ole32.dll shell32.dll initpki.dll wuapi.dll wuaueng.dll wuaueng1.dll wucltui.dll wups.dll wups2.dll wuweb.dll qmgr.dll qmgrprxy.dll wucltux.dll muweb.dll wuwebv.dll) do (
    regsvr32 /s %%D >> "%LOGFILE%" 2>&1
)
popd
call :step "Restarting services"
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start appidsvc >nul 2>&1
net start wuauserv >nul 2>&1
set "WUSTART=!errorlevel!"
net start msiserver >nul 2>&1
if "!WUSTART!" neq "0" ( call :warn "The wuauserv service could not start after DLL registration" & set "WU_WARN=1" )
call :step "Forcing update discovery"
wuauclt /resetauthorization /detectnow >nul 2>&1
if "!WU_WARN!"=="1" ( set "PH_NOTE=cache not moved or service failed" & call :warn "Windows Update: cache not moved or wuauserv did not start" & exit /b 1 )
call :ok "Windows Update repaired: cache cleared, DLLs registered, discovery forced"
exit /b 0
:Fase14
if "%DRY%"=="1" ( call :dry "Would repair the winget sources and update them" & exit /b 2 )
call :step "Checking winget"
where winget >nul 2>&1
if !errorlevel! neq 0 ( call :warn "winget is not available. Install App Installer from the Store." & set "PH_NOTE=winget absent" & exit /b 1 )
call :step "Repairing sources and updating winget"
winget source reset --force >> "%LOGFILE%" 2>&1
winget source update >> "%LOGFILE%" 2>&1
call :ok "winget operational and sources updated"
exit /b 0
:Fase15
call :step "Looking for devices or drivers with errors"
call :psh devices > "%CAP%" 2>&1
type "%CAP%" >> "%LOGFILE%"
findstr /b /c:"OK|" "%CAP%" >nul 2>&1
if !errorlevel! equ 0 ( call :ok "No devices with problems" & exit /b 0 )
set "DEVN=0"
for /f "usebackq tokens=1-3 delims=|" %%a in ("%CAP%") do (
    if /i "%%a"=="PROB" ( set /a "DEVN+=1" & echo     %YE%[dev ]%R%  code %%b  -  %%c & >>"%LOGFILE%" echo     [dev] code %%b - %%c )
)
call :warn "There are !DEVN! device(s) with errors. Update their driver from the maker's site."
set "PH_NOTE=!DEVN! devices with errors"
exit /b 1
:Fase16
if "%DRY%"=="0" (
    call :step "Final deep cleanup"
    del /f /q /s "%SystemRoot%\Logs\CBS\CbsPersist_*.log" >nul 2>&1
    rem (v3.1) liberar espacio: logs de instalacion antiguos (seguros de borrar)
    del /f /q "%SystemRoot%\Panther\*.log" >nul 2>&1
    del /f /q "%SystemRoot%\inf\setupapi.dev.log" >nul 2>&1
    del /f /q "%SystemRoot%\inf\setupapi.setup.log" >nul 2>&1
    ipconfig /flushdns >nul 2>&1
)
call :step "Recalculating system health"
call :psh score > "%CAP%" 2>&1
set "SCORE_AFTER="
for /f "usebackq tokens=2 delims==" %%a in (`findstr /b /c:"SCORE=" "%CAP%"`) do set "SCORE_AFTER=%%a"
if defined SCORE_AFTER ( call :pshq setafter "!SCORE_AFTER!" & call :info "Health after: !SCORE_AFTER!/100" )
call :step "Generating HTML report"
set "REPORT=%WORK%\Informe_%TIMESTAMP%.html"
call :psh report "%REPORT%"
if exist "%REPORT%" ( call :ok "Report created at !REPORT!" & set "PH_NOTE=HTML report generated" ) else ( call :warn "Could not generate HTML report" )
exit /b 0
