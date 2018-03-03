@echo off & setlocal enabledelayedexpansion

SET ERL_LIBS=%~dp0;%ERL_LIBS%
elixir -e "ElixirLS.Debugger.CLI.main()"
