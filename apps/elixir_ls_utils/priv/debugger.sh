#!/bin/sh
# Launches the debugger. This script must be in the same directory as the compiled .ez archives.

dir=$(dirname "$0")

export ELS_MODE=debugger
export ELS_SCRIPT="ElixirLS.Debugger.CLI.main()"

exec "${dir}/launch.sh"
