#!/usr/bin/env sh
SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

cd "$SCRIPTPATH"
mix deps.get
mix deps.clean --unused

rm -rf "$SCRIPTPATH"/release
mkdir release
cp bin/exscript* release/

cd "$SCRIPTPATH"/apps/language_server
mix escript.build
cd "$SCRIPTPATH"/apps/debugger
mix escript.build
