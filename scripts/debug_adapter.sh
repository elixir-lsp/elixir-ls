#!/bin/sh
# Launches the debug adapter. This script must be in the same directory as mix install launch script.

readlink_f () {
  cd "$(dirname "$1")" > /dev/null || exit 1
  filename="$(basename "$1")"
  if [ -h "$filename" ]; then
    readlink_f "$(readlink "$filename")"
  else
    echo "$(pwd -P)/$filename"
  fi
}

if [ -z "${ELS_INSTALL_PREFIX}" ]; then
  dir="$(dirname "$(readlink_f "$0")")"
  >&2 echo "running ${dir}/launch.sh"
else
  dir=${ELS_INSTALL_PREFIX}
  >&2 echo "ELS_INSTALL_PREFIX is set, running ${ELS_INSTALL_PREFIX}/launch.sh"
fi

export ELS_MODE=debug_adapter
exec "${dir}/launch.sh"
