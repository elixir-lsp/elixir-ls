@echo off & setlocal enabledelayedexpansion

SET ELS_MODE=language_server
IF EXIST "%APPDATA%\elixir_ls\setup.bat" (
    CALL "%APPDATA%\elixir_ls\setup.bat" > nul
)

SET ERL_LIBS=%~dp0;%ERL_LIBS%
elixir --erl "+sbwt none +sbwtdcpu none +sbwtdio none" -e "ElixirLS.LanguageServer.CLI.main()"
