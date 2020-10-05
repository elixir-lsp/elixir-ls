@echo off & setlocal enabledelayedexpansion

IF EXIST "%APPDATA%\elixir_ls\setup.bat" (
    CALL "%APPDATA%\elixir_ls\setup.bat"
)

SET ERL_LIBS=%~dp0;%ERL_LIBS%
elixir --erl "+sbwt none +sbwtdcpu none +sbwtdio none" -e "ElixirLS.Debugger.CLI.main()"
