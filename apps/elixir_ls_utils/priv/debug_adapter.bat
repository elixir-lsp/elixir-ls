@echo off & setlocal enabledelayedexpansion

SET ELS_MODE=debug_adapter
IF EXIST "%APPDATA%\elixir_ls\setup.bat" (
    CALL "%APPDATA%\elixir_ls\setup.bat" > nul
)

SET ERL_LIBS=%~dp0;%ERL_LIBS%
elixir %ELS_ELIXIR_OPTS% --erl "-kernel standard_io_encoding latin1 +sbwt none +sbwtdcpu none +sbwtdio none %ELS_ERL_OPTS%" -e "ElixirLS.DebugAdapter.main()"
