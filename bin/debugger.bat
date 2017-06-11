@echo off & setlocal enabledelayedexpansion
rem // VS Code starts the debugger with the cwd set to 
rem // C:\\Program Files (x86)\Microsoft VS Code
rem // so we have to use the batch script's directory to find the escript file.
rem // (TL;DR: debugger.bat must be in the same folder as exscript.bat and debugger)

set SCRIPT_DIR=%~dp0
shift
%SCRIPT_DIR%exscript.bat %SCRIPT_DIR%debugger %*