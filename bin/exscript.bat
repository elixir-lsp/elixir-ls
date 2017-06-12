@echo off & setlocal enabledelayedexpansion

rem // Runs an Elixir escript that was compiled without embedding Elixir.
rem // It looks for the system Elixir installation and includes it in the VM's code path.

rem // Get path to elixir.bat
SET COMMAND=where elixir
FOR /F "delims=" %%A IN ('%COMMAND%') DO (
    SET ELIXIR_PATH=%%A
    GOTO :found_elixir 
)
:found_elixir

rem // Get folder containing elixir.bat
For %%A in ("%ELIXIR_PATH%") do (
    set ELIXIR_DIR=%%~dpA
)

rem // Get relative path of lib folder
set REL_PATH="%ELIXIR_DIR%..\lib"

rem // Save current directory and change to target directory
pushd %REL_PATH%

rem // Save value of CD variable (current directory)
set ABS_PATH=%CD%

rem // Restore original directory
popd

rem // Set ERL_LIBS to include lib folder
set ERL_LIBS=%ERL_LIBS%;%ABS_PATH%

rem // Remove first arg (this script) and shift over other args
SHIFT

rem // Run escript with the args that were passed to this script
escript %*