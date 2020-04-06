#!/usr/bin/env bash

[ -f "$HOME/.asdf/asdf.sh" ] && . "$HOME/.asdf/asdf.sh"

readlink_f () {
  cd "$(dirname "$1")" > /dev/null
  filename="$(basename "$1")"
  if [ -h "$filename" ]; then
    readlink_f "$(readlink "$filename")"
  else
    echo "`pwd -P`/$filename"
  fi
}

version=$(elixir -v|grep ^Elixir| sed 's/Elixir \(.*\) (compiled with Erlang\/OTP \(.*\))/\1-\2/')

target_dir=~/.cache/elixir-ls/$version

if [ ! -d $target_dir ]; then
  mkdir -p $target_dir
  cp -r . $target_dir
  cd $target_dir
  mix do deps.get, compile, elixir_ls.release -o .
  rm -rf apps config deps _build mix.* *.sh *.bat
fi

export ERL_LIBS="$target_dir:$ERL_LIBS"

elixir -e "ElixirLS.LanguageServer.CLI.main()"
