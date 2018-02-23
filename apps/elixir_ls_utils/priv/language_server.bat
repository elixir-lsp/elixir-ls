@echo off & setlocal enabledelayedexpansion

SET ERL_LIBS=%~dp0
mix elixir_ls.language_server
