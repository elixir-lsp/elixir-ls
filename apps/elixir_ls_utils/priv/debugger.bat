@echo off & setlocal enabledelayedexpansion

SET ERL_LIBS=%~dp0

REM HACK: We don't want Mix to load the mixfile in the cwd, so we override MIX_EXS here. We can
REM restore it from ELIXIR_LS_MIX_EXS once we've launched.
SET ELIXIR_LS_MIX_EXS=%MIX_EXS%
SET MIX_EXS="."

mix elixir_ls.debugger
