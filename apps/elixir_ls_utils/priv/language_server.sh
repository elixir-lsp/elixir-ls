#!/bin/sh
# Launches the language server. This script must be in the same directory as the compiled .ez archives.

dir=$(dirname "$0")

export ELS_MODE=language_server
export ELS_SCRIPT="ElixirLS.LanguageServer.CLI.main()"

exec "${dir}/launch.sh"
