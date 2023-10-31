#!/usr/bin/env fish
# Actual launcher. This does the hard work of figuring out the best way
# to launch the language server or the debugger.

# Running this script is a one-time action per project launch, so we opt for
# code simplicity instead of performance. Hence some potentially redundant
# moves here.

# First order of business, see whether we can setup asdf-vm

set asdf_dir $ASDF_DIR

test -z "$asdf_dir"; and set asdf_dir "$HOME/.asdf"

set asdf_vm "$asdf_dir/asdf.fish"

echo "Looking for ASDF install" >&2

if test -f "$asdf_vm"
  echo "ASDF install found in $asdf_vm, sourcing" >&2
  source "$asdf_vm"
else
  echo "ASDF not found" >&2
  echo "Looking for rtx executable" >&2

  set rtx (which rtx)
  if test -n "$rtx"
    echo "rtx executable found in $rtx, activating" >&2

    "$rtx" env -s fish | source
  else
    echo "rtx not found" >&2
  end
end

# In case that people want to tweak the path, which Elixir to use, or
# whatever prior to launching the language server or the debugger, we
# give them the chance here. ELS_MODE will be set for
# the really complex stuff. Use an XDG compliant path.

set els_dir $XDG_CONFIG_HOME
test -z "$els_dir"; and set els_dir "$HOME/.config"

set els_setup "$els_dir/elixir_ls/setup.fish"

if test -f "$els_setup"
  echo "Running setup script $els_setup" >&2
  source "$els_setup"
end

# Setup done. Make sure that we have the proper actual path to this
# script so we can correctly configure the Erlang library path to
# include the local .ez files, and then do what we were asked to do.

function readlink_f
  cd (dirname $argv[1]) || exit 1
  set filename (basename $argv[1])
  if test -L $filename
    readlink_f (readlink $filename)
  else
    echo (pwd -P)"/$filename"
  end
end

if test -z "$ELS_INSTALL_PREFIX"
  set -l current_dir (pwd)
  set scriptpath (dirname (readlink_f (status -f)))

  # readlink_f changes the current directory (since fish doesn't have
  # subshells), so it needs to be restored.
  cd $current_dir
else
  set scriptpath $ELS_INSTALL_PREFIX
end

set -x MIX_ENV prod
# Mix.install prints to stdout and reads from stdin
# we need to make sure it doesn't interfere with LSP/DAP
echo "" | elixir "$scriptpath/quiet_install.exs" >/dev/null || exit 1

set erl_opts -kernel standard_io_encoding latin1 +sbwt none +sbwtdcpu none +sbwtdio none

if test -n "$ELS_ELIXIR_OPTS"
  set elixir_opts (string join ' ' -- $ELS_ELIXIR_OPTS)
else
  set elixir_opts
end

if test -n "$ELS_ERL_OPTS"
  set erl_opts -a $ELS_ERL_OPTS
end

set erl_opts (string join ' ' -- $erl_opts)

eval elixir $elixir_opts --erl \"$erl_opts \" \"$scriptpath/launch.exs\"
