#!/usr/bin/env sh
# Runs an Elixir escript that was compiled without embedding Elixir.
# It looks for the system Elixir installation and includes it in the VM's code path.

readlink_f () {
  cd "$(dirname "$1")" > /dev/null
  filename="$(basename "$1")"
  if [ -h "$filename" ]; then
    readlink_f "$(readlink "$filename")"
  else
    echo "`pwd -P`/$filename"
  fi
}

export ERL_LIBS=$(cd "$(dirname $(readlink_f $(which elixir)))/../lib"; pwd)
/usr/bin/env escript "$1"