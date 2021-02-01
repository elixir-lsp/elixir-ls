#!/bin/sh
# Launches the language server. This script must be in the same directory as the compiled .ez archives.

if [ -z "${ELS_INSTALL_PREFIX}" ]; then
  dir=$(dirname "$0")
else
  dir=${ELS_INSTALL_PREFIX}
fi

export ELS_MODE=language_server
export ELS_SCRIPT="ElixirLS.LanguageServer.CLI.main()"

exec "${dir}/launch.sh"
