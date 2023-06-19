@echo off & setlocal enabledelayedexpansion

SET ELS_MODE=language_server
IF EXIST "%APPDATA%\elixir_ls\setup.bat" (
    CALL "%APPDATA%\elixir_ls\setup.bat" > nul
)

SET ERL_LIBS=%~dp0;%ERL_LIBS%
elixir %ELS_ELIXIR_OPTS% --erl "+sbwt none +sbwtdcpu none +sbwtdio none %ELS_ERL_OPTS%" -e "ElixirLS.LanguageServer.CLI.main()"
