#!/usr/bin/env sh

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
"$SCRIPTPATH/exscript.sh" "$SCRIPTPATH/debugger" $@