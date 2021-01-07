#!/bin/sh
# Launches the language server. This script must be in the same directory as the compiled .ez archives.

readlink_f () {
  cd "$(dirname "$1")" > /dev/null
  filename="$(basename "$1")"
  if [ -h "$filename" ]; then
    readlink_f "$(readlink "$filename")"
  else
    echo "$(pwd -P)/$filename"
  fi
}

dir=$(dirname $(readlink_f "$0"))

export ELS_MODE=language_server
export ELS_SCRIPT="ElixirLS.LanguageServer.CLI.main()"

exec "${dir}/launch.sh"
