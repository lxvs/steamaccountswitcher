@echo off
setlocal
chcp 65001 >nul
set version=0.1.0
set update=2022-08-27
set _exit=
set ec=0
set regpath=HKCU\Software\Valve\Steam
call:findsteam || exit /b
call:parseloginusers || exit /b
call:showit || exit /b
call:choose || exit /b
if defined _exit (exit /b)
call:switchto "%chosenaccount%" || exit /b
call:launchsteam || exit /b
set _exit=1
goto end

:findsteam
set "steampath=%STEAMACCOUNTSWITCHER_STEAMPATH%"
if not defined steampath (call:getreg "%regpath%" SteamPath steampath)
if not defined steampath (call:findsteamharder)
if not defined steampath (
    call:err "error: steam path not found" "You can specify it manually using environment variable `STEAMACCOUNTSWITCHER_STEAMPATH'"
    goto end
)
set "steampath=%steampath:/=\%"
exit /b 0

:findsteamharder
if exist "%ProgramFiles(x86)%\Steam\Steam.exe" ((set "steampath=%ProgramFiles(x86)%\Steam") & (exit /b 0))
if exist "%ProgramFiles%\Steam\Steam.exe" ((set "steampath=%ProgramFiles%\Steam") & (exit /b 0))
if exist "C:\Steam\Steam.exe" ((set "steampath=C:\Steam") & (exit /b 0))
if exist "D:\Steam\Steam.exe" ((set "steampath=D:\Steam") & (exit /b 0))
if exist "E:\Steam\Steam.exe" ((set "steampath=E:\Steam") & (exit /b 0))
if exist "F:\Steam\Steam.exe" ((set "steampath=F:\Steam") & (exit /b 0))
exit /b 1

:parseloginusers
set "loginusersvdf=%steampath%\config\loginusers.vdf"
if not exist "%loginusersvdf%" (
    call:err "error: failed to find file `loginusers.vdf'"
    goto end
)
set /a amount=0
set accounts=
set names=
for /f "usebackq tokens=1* delims=	" %%a in ("%loginusersvdf%") do (call:_parseloginusers "%%~a" "%%~b")
if not defined accounts (
    call:err "error: no account allowing auto login"
    goto end
)
exit /b 0

:_parseloginusers
set "_parseloginusers_k=%~1"
set "_parseloginusers_v=%~2"
if "%_parseloginusers_k%" == "AccountName" (
    set "account=%_parseloginusers_v%"
) else if "%_parseloginusers_k%" == "PersonaName" (
    set "name=%_parseloginusers_v%"
) else if "%_parseloginusers_k%" == "AllowAutoLogin" (
    if "%_parseloginusers_v%" == "1" (
        set /a amount+=1
        set "accounts=%accounts%%account% "
        set "names=%names%%name% "
    )
    set account=
    set name=
)
exit /b 0

:showit
call:showversion
set "_accounts=%accounts%"
set "_names=%names%"
@echo;
@echo Switchable accounts:
@echo;
for /l %%i in (1,1,%amount%) do (
    set /p="%%~i. " <nul
    call:spitaccount || exit /b
    set /p="(" <nul
    call:spitname || exit /b
    set /p=")" <nul
    echo;
)
@echo;
exit /b 0

:showversion
@echo Steam Account Switcher %version% ^(%update%^)
@echo https://github.com/lxvs/steamaccountswitcher
exit /b

:spitaccount
call:getaccount || exit /b
set /p="%_account% " <nul
exit /b 0

:spitname
call:getname || exit /b
set /p="%_name%" <nul
exit /b 0

:getaccount
set _account=
if %1. == . (set which=1) else (set /a "which=%~1")
if not defined _accounts ((call:err "error: error parsing accounts") & (exit /b 1))
for /l %%i in (1,1,%which%) do (call:_getaccount %%i)
if not defined _account ((call:err "error: got no account") & (exit /b 1))
exit /b 0

:getname
set _name=
if %1. == . (set which=1) else (set /a "which=%~1")
if not defined _names ((call:err "error: error parsing names") & (exit /b 1))
for /l %%i in (1,1,%which%) do (call:_getname %%i)
if not defined _name ((call:err "error: got no name") & (exit /b 1))
exit /b 0

:_getaccount
for /f "tokens=1* delims= " %%a in ("%_accounts%") do ((if %1 EQU %which% (set "_account=%%~a")) & (set "_accounts=%%~b"))
exit /b

:_getname
for /f "tokens=1* delims= " %%a in ("%_names%") do ((if %1 EQU %which% (set "_name=%%~a")) & (set "_names=%%~b"))
exit /b

:choose
set chosenaccount=
set "_accounts=%accounts%"
set "_names=%names%"
if %amount% LEQ 9 (goto theeasyway) else (goto thehardway)
:theeasyway
choice /c 1234567890 /n /m "Choose a number (0 to exit): "
set choice=%ERRORLEVEL%
if %choice% EQU 0 ((set _exit=1) & (set ec=0) & (goto end))
if %choice% EQU 10 ((set _exit=1) & (set ec=0) & (goto end))
call:getaccount %choice% || goto choose
set "chosenaccount=%_account%"
exit /b 0
:thehardway
set choice=
set /p choice="Enter a number and press ENTER (0 to exit): "
set /a choice_a=choice 2>nul || goto choose
if "%choice_a%" NEQ "%choice%" (goto choose)
if "%choice_a%" EQU "0" ((set _exit=1) & (set ec=0) & (goto end))
call:getaccount %choice_a% || goto choose
set "chosenaccount=%_account%"
exit /b 0

:switchto
reg add "%regpath%" /v "AutoLoginUser" /t "REG_SZ" /d "%chosenaccount%" /f 1>nul || goto end
echo Switched to account: %chosenaccount%
exit /b 0

:launchsteam
call:getsteampid || ((echo Steam already running) & (goto end))
if defined STEAMACCOUNTSWITCHER_AUTOLAUNCH ((if "%STEAMACCOUNTSWITCHER_AUTOLAUNCH%" EQU "1" (call:_launchsteam)) & (exit /b 0))
choice /c YN /n /m "Launch Steam now (Y/N)? "
set choice=%ERRORLEVEL%
if %choice% EQU 1 (call:_launchsteam)
exit /b 0

:getsteampid
call:getreg "%regpath%\ActiveProcess" pid steampid
set /a steampid=steampid
exit /b %steampid%

:_launchsteam
echo Launch Steam
start "" /d "%steampath%" /i "%steampath%\Steam.exe"
exit /b

:err
set ec=1
:err_loop
if %1. == . (exit /b %ec%)
if "%~1" == "" (
    >&2 echo;
) else (
    >&2 echo %~1
)
shift /1
goto err_loop

:getreg
set "getreg_path=%~1"
set getreg_key="%~2"
set %3=
set "getreg_name=%~2"
set getregretval=
if /i "%getreg_key%" == "/ve" (
    set getreg_switch=/ve
    set getreg_key=
    set "getreg_name=(Default)"
) else (
    set getreg_switch=/v
)
for /f "skip=2 tokens=1* delims=" %%a in ('reg query "%getreg_path%" %getreg_switch% %getreg_key% 2^>nul') do (
    call:getregparse "%%~a"
)
if defined getregretval (set "%3=%getregretval%")
exit /b

:getregparse
if "%~1" == "" (exit /b 1)
set "getregparse_str=%~1"
set "getregparse_str=%getregparse_str:    =	%
for /f "tokens=1,2* delims=	" %%A in ("%getregparse_str%") do (
    if /i "%getreg_name%" == "%%~A" (set "getregretval=%%~C")
)
exit /b

:pause
echo Press any key to exit.
pause >nul
exit /b

:end
if not defined _exit (call:pause)
exit /b %ec%
