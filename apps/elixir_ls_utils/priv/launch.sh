#!/bin/sh
# Actual launcher. This does the hard work of figuring out the best way
# to launch the language server or the debugger.
#

# Running this script is a one-time action per project launch, so we opt for
# code simplicity instead of performance. Hence some potentially redundant
# moves here.

# First order of business, see whether we can setup asdf-vm

did_relaunch=$1

ASDF_DIR=${ASDF_DIR:-"${HOME}/.asdf"}

asdf_vm="${ASDF_DIR}/asdf.sh"
if test -f "${asdf_vm}"
then
  # asdf-vm does not support the plain posix shell. Figure out
  # which one we need and relaunch ourselves with that.
  case "${did_relaunch}" in
    "")
      if which bash >/dev/null
      then
        exec "$(which bash)" "$0" relaunch
      elif which zsh >/dev/null
      then
        exec "$(which zsh)" "$0" relaunch
      fi
      ;;
    *)
      # We have an arg2, so we got relaunched. Therefore, we're running in a
      # shell that supports asdf-vm.
      .  "${asdf_vm}"
      ;;
  esac
fi

# In case that people want to tweak the path, which Elixir to use, or
# whatever prior to launching the language server or the debugger, we
# give them the chance here. ELS_MODE will be set for
# the really complex stuff. Use an XDG compliant path.

els_setup="${XDG_CONFIG_HOME:-~/.config}/elixir_ls/setup.sh"
if test -f "${els_setup}"
then
  .  "${els_setup}"
fi

# Setup done. Make sure that we have the proper actual path to this
# script so we can correctly configure the Erlang library path to
# include the local .ez files, and then do what we were asked to do.

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
  SCRIPT=$(readlink_f "$0")
  SCRIPTPATH=$(dirname "$SCRIPT")
else
  SCRIPTPATH=${ELS_INSTALL_PREFIX}
fi

export ERL_LIBS="$SCRIPTPATH:$ERL_LIBS"

exec elixir --erl "+sbwt none +sbwtdcpu none +sbwtdio none"  -e "$ELS_SCRIPT"
