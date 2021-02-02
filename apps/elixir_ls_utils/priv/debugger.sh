#!/bin/sh
# Launches the debugger. This script must be in the same directory as the compiled .ez archives.

if [ -z "${ELS_INSTALL_PREFIX}" ]; then
  dir=$(dirname "$0")
else
  dir=${ELS_INSTALL_PREFIX}
fi

export ELS_MODE=debugger
export ELS_SCRIPT="ElixirLS.Debugger.CLI.main()"

exec "${dir}/launch.sh"
