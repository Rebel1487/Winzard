::SRC header.cmd | Cabecera comun canonica (Task 1.1/10.1, Req 12.x/14.1-14.3). Compartida VERBATIM por los 18 .bat.
::SRC Parseo de argumentos (incl. /help /? /version /selftest /quiet), /help y /version SIN admin, auto-elevacion,
::SRC carpetas WORK/LOGDIR/BKDIR, TIMESTAMP, LOGFILE, CAP, :wpi_initcolors, :require_powershell, :wpi_extracthelper.
::SRC El generador descarta las lineas iniciales ::SRC antes de ensamblar.
@echo off
setlocal EnableDelayedExpansion
:: --- Consola estilo WinUtil: fondo azul oscuro, texto claro (Req B/D) ---
:: Se aplica a la suite completa y a CADA fase suelta (todas incluyen esta cabecera).
:: 'color' repinta el bufer; 'cls' garantiza el fondo azul desde el inicio.
color 0F
cls
:: --- parseo de argumentos (antes de elevar, para que /help y /version no pidan UAC) ---
set "MODE_AUTO=0" & set "NO_REBOOT=0" & set "KEEPWU=0" & set "DRY=0" & set "RESUME=0" & set "SEL_FASES=" & set "USE_TRIAGE=0"
set "SELFTEST=0" & set "QUIET=0" & set "SHOW_HELP=0" & set "SHOW_VERSION=0"
set "JSON=0" & set "SUPPORT=0" & set "QUICK=0" & set "NOCOLOR=0" & set "MANUAL=0" & set "PLAN_MODE=0" & set "QSUB=scan" & set "QUICK_WIZ=0" & set "SHOWCMD=0"
set "RESETBASE=0" & set "FWRESET=0" & set "CUSTOM_SOURCE="
:parse_loop
if "%~1"=="" goto parse_done
set "ARG=%~1"
if /i "!ARG!"=="/auto"     set "MODE_AUTO=1"
if /i "!ARG!"=="/noreboot" set "NO_REBOOT=1"
if /i "!ARG!"=="/keepwu"   set "KEEPWU=1"
if /i "!ARG!"=="/dry"      set "DRY=1"
if /i "!ARG!"=="/resume"   set "RESUME=1"
if /i "!ARG!"=="/triage"   set "USE_TRIAGE=1"
if /i "!ARG!"=="/selftest" set "SELFTEST=1"
if /i "!ARG!"=="/quiet"    set "QUIET=1"
if /i "!ARG!"=="/help"     set "SHOW_HELP=1"
if /i "!ARG!"=="/?"        set "SHOW_HELP=1"
if /i "!ARG!"=="/version"  set "SHOW_VERSION=1"
if /i "!ARG!"=="/json"     set "JSON=1"
if /i "!ARG!"=="/support"  set "SUPPORT=1"
if /i "!ARG!"=="/quick"    set "QUICK=1"
if /i "!ARG!"=="/quickfix" ( set "QUICK=1" & set "QSUB=fix" )
if /i "!ARG!"=="/nocolor"  set "NOCOLOR=1"
if /i "!ARG!"=="/manual"   set "MANUAL=1"
if /i "!ARG!"=="/cmd"      set "SHOWCMD=1"
if /i "!ARG!"=="/plan"     set "PLAN_MODE=1"
if /i "!ARG!"=="/resetbase" set "RESETBASE=1"
if /i "!ARG!"=="/fwreset"  set "FWRESET=1"
if /i "!ARG:~0,8!"=="/source:" set "CUSTOM_SOURCE=!ARG:~8!"
if /i "!ARG:~0,7!"=="/fases:" (
    set "SEL_FASES=!ARG:~7!"
    set "SEL_FASES=!SEL_FASES:+=,!"
)
if /i "!ARG:~0,8!"=="/phases:" (
    set "SEL_FASES=!ARG:~8!"
    set "SEL_FASES=!SEL_FASES:+=,!"
)
shift
goto parse_loop
:parse_done
:: por seguridad, /selftest implies simulation (no toca el sistema)
if "!SELFTEST!"=="1" set "DRY=1"
rem (v3.1) en modo desatendido el menu manual no aplica (no hay quien elija)
if "!MODE_AUTO!"=="1" set "MANUAL=0"
if "!MODE_AUTO!"=="1" set "PLAN_MODE=0"
call :wpi_initcolors
:: (Task 10.1 / Req 12) /version y /help salen de inmediato, sin elevar ni ejecutar fases.
if "!SHOW_VERSION!"=="1" ( call :show_version & endlocal & exit /b 0 )
if "!SHOW_HELP!"=="1" ( call :show_help & endlocal & exit /b 0 )
:: --- Verificar Administrador (re-lanzamiento elevado) ---
:: (v3.1 Bug#1) Las operaciones que NO tocan el sistema no requieren admin:
:: /dry, /quick, /selftest (ademas de /help y /version, que ya salieron antes).
:: Asi funcionan en terminales no elevados. (Bug#2: NUNCA usar set errorlevel=.)
set "NEED_ADMIN=1"
if "%DRY%"=="1" set "NEED_ADMIN=0"
if "%SELFTEST%"=="1" set "NEED_ADMIN=0"
if "%NEED_ADMIN%"=="0" goto :admin_done
net session >nul 2>&1
if !errorLevel! neq 0 (
    echo Solicitando privilegios de Administrador...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/k \"%~f0\" %*' -Verb RunAs"
    exit /b
)
:admin_done
:: --- carpetas de trabajo ---
set "WORK=%~dp0WPI_Suite"
set "LOGDIR=%WORK%\Logs"
set "BKDIR=%WORK%\Backups"
if not exist "%WORK%" mkdir "%WORK%" >nul 2>&1
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%BKDIR%" mkdir "%BKDIR%" >nul 2>&1
for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')"`) do set "TIMESTAMP=%%t"
set "LOGFILE=%LOGDIR%\reparacion_%TIMESTAMP%.log"
set "RUNID=%RANDOM%%RANDOM%"
set "CAP=%WORK%\_cap_%RUNID%.txt"
:: Bug 9 / Req 11: verificar PowerShell ANTES de extraer el Cerebro. Si falta o
:: no arranca, :require_powershell devuelve 3; en el ambito principal de la
:: cabecera propagamos ese 3 con un exit /b 3 incondicional => parada total.
call :require_powershell
if errorlevel 3 exit /b 3
call :wpi_extracthelper
