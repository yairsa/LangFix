@echo off
REM ---------------------------------------------------------------------------
REM  LangFix control panel - double-click me.
REM  Shows whether LangFix is running and whether it starts at logon, then
REM  offers the action that makes sense (Stop if it is up, Launch if it is not).
REM
REM  Pass arguments straight through for the non-interactive forms:
REM     LangFix.bat -Status        LangFix.bat -Start        LangFix.bat -Stop
REM     LangFix.bat -Restart       LangFix.bat -Autostart on
REM ---------------------------------------------------------------------------
setlocal
title LangFix control

set "PS=pwsh.exe"
where /q pwsh.exe || set "PS=powershell.exe"

"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0LangFix-Control.ps1" %*
set "RC=%ERRORLEVEL%"

REM Only pause when double-clicked with no arguments; scripted calls exit clean.
if "%~1"=="" (
  echo.
  timeout /t 3 >nul
)
exit /b %RC%
