@echo off & setlocal enabledelayedexpansion

SET ERL_LIBS=%~dp0;%ERL_LIBS%
elixir --erl "+sbwt none +sbwtdcpu none +sbwtdio none" -e "ElixirLS.LanguageServer.CLI.main()"
