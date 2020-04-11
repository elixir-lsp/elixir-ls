REM TODO test me on Win1rand () {
  od -t xS -N 2 -A n /dev/urandom | tr -d " \n"
}
0
@echo off & setlocal enabledelayedexpansion

set ELS_STARTUP_TYPE=debugger
set RELEASE_NODE="elixir-ls-!RANDOM!"

@bin/elixir_ls.bat start
