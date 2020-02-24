#!/usr/bin/env bash
# Launches the language server. Very simple wrapper around the generated
# startup script.

# For now, we assume that this script lives in the root of the unpacked
# distribution (so that the distribution wrapper script lives in bin/).
# TODO this is a manual post-install step so we should thinkg about this.

# TODO lots of duplication with language_server.sh here

readlink_f () {
  cd "$(dirname "$1")" > /dev/null
  filename="$(basename "$1")"
  if [ -h "$filename" ]; then
    readlink_f "$(readlink "$filename")"
  else
    echo "`pwd -P`/$filename"
  fi
}
rand () {
  od -t xS -N 2 -A n /dev/urandom | tr -d " \n"
}

SCRIPT=$(readlink_f $0)
SCRIPTPATH=`dirname $SCRIPT`/bin

export RELEASE_NODE=elixir-ls-$(rand)

export ELS_STARTUP_TYPE=debugger

$SCRIPTPATH/elixir_ls start
