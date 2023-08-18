#!/bin/sh
# Actual launcher. This does the hard work of figuring out the best way
# to launch the language server or the debugger.

# Running this script is a one-time action per project launch, so we opt for
# code simplicity instead of performance. Hence some potentially redundant
# moves here.

# First order of business, see whether we can setup asdf-vm

did_relaunch=$1

case "${did_relaunch}" in
  "")
    # Get the user's preferred shell
    preferred_shell=$(basename "$SHELL")
    if [ "$preferred_shell" = "bash" ]; then
      >&2 echo "Preffered shell is bash, relaunching"
      exec "$(which bash)" "$0" relaunch
    elif [ "$preferred_shell" = "zsh" ]; then
      >&2 echo "Preffered shell is zsh, relaunching"
      exec "$(which zsh)" "$0" relaunch
    else
      >&2 echo "Preffered shell $preferred_shell is not supported, continuing in POSIX shell"
    fi
    ;;
  *)
    # We have an arg2, so we got relaunched
    ;;
esac

ASDF_DIR=${ASDF_DIR:-"${HOME}/.asdf"}

asdf_vm="${ASDF_DIR}/asdf.sh"

>&2 echo "Looking for ASDF install"
if test -f "${asdf_vm}"
then
  >&2 echo "ASDF install found in $asdf_vm, sourcing"
  # shellcheck disable=SC1090
  .  "${asdf_vm}"
else
  >&2 echo "ASDF not found"
  >&2 echo "Looking for rtx executable"

  if which rtx >/dev/null
  then
    >&2 echo "rtx executable found in $(which rtx), activating"
    preferred_shell=$(basename "$SHELL")
    eval "$($(which rtx) activate "$preferred_shell")"
  else
    >&2 echo "rtx not found"
  fi
fi

# In case that people want to tweak the path, which Elixir to use, or
# whatever prior to launching the language server or the debugger, we
# give them the chance here. ELS_MODE will be set for
# the really complex stuff. Use an XDG compliant path.

els_setup="${XDG_CONFIG_HOME:-$HOME/.config}/elixir_ls/setup.sh"
if test -f "${els_setup}"
then
  >&2 echo "Running setup script $els_setup"
  # shellcheck disable=SC1090
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

# shellcheck disable=SC2086
exec elixir $ELS_ELIXIR_OPTS --erl "-kernel standard_io_encoding latin1 +sbwt none +sbwtdcpu none +sbwtdio none $ELS_ERL_OPTS" -e "$ELS_SCRIPT"
