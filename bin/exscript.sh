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

REL_DIR="$(dirname $(readlink_f $(which elixir)))/../lib"

# If directory does not exist, it could be because the `elixir` in the PATH runs a script which runs
# elixir. (Installations via the "asdf" tool work this way.) We run Elixir and ask it its path as a
# fallback. This is slower.
if [ -d "$REL_DIR" ]; then 
  ELIXIR_LIB=$(cd "$REL_DIR"; pwd)
else
  ELIXIR_LIB=`elixir -e "IO.puts Path.expand(Path.join(Application.app_dir(:elixir), '..'))"`
fi

export ERL_LIBS="$ERL_LIBS:$ELIXIR_LIB"
/usr/bin/env escript $@