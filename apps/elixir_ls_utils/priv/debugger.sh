#!/usr/bin/env sh
# Launches the debugger. This script must be in the same directory as the compiled .ez archives.

readlink_f () {
  cd "$(dirname "$1")" > /dev/null
  filename="$(basename "$1")"
  if [ -h "$filename" ]; then
    readlink_f "$(readlink "$filename")"
  else
    echo "`pwd -P`/$filename"
  fi
}

SCRIPT=$(readlink_f $0)
SCRIPTPATH=`dirname $SCRIPT`
export ERL_LIBS="$SCRIPTPATH:$ERL_LIBS"

elixir -e "ElixirLS.Debugger.CLI.main()"
