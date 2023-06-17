@echo off & setlocal enabledelayedexpansion

SET ELS_MODE=debugger

IF EXIST "%APPDATA%\elixir_ls\setup.bat" (
    ECHO "" | CALL "%APPDATA%\elixir_ls\setup.bat" > nul
    IF %ERRORLEVEL% NEQ 0 EXIT 1
)

SET MIX_ENV=prod
@REM pipe echo to avoid passing protocol messages to quiet install command
@REM intercept stdout
@REM elixir is a batch script and needs to be called
ECHO "" | CALL elixir "%~dp0quiet_install.exs" > nul
IF %ERRORLEVEL% NEQ 0 EXIT 1
elixir --erl "+sbwt none +sbwtdcpu none +sbwtdio none" "%~dp0launch.exs"
