#!/usr/bin/env fish
# Actual launcher. This does the hard work of figuring out the best way
# to launch the language server or the debug adapter.

# Running this script is a one-time action per project launch, so we opt for
# code simplicity instead of performance. Hence some potentially redundant
# moves here.

# First order of business, see whether we can setup asdf

function readlink_f
  cd (dirname $argv[1]) || exit 1
  set filename (basename $argv[1])
  if test -L $filename
    readlink_f (readlink $filename)
  else
    echo (pwd -P)"/$filename"
  end
end

function export_stdlib_path
  set -l current_dir (pwd)

  set -l which_elixir_expr $argv[1]
  # Separate evaluation from readlink_f call to avoid infinite loop
  # when elixir is not found
  set -l stdlib_path (eval $which_elixir_expr 2>/dev/null)

  # Only proceed if elixir was found
  if test -n "$stdlib_path"
    set -l stdlib_real_path (readlink_f "$stdlib_path")
    set -gx ELX_STDLIB_PATH (echo $stdlib_real_path | string replace -r '(.*)\/bin\/elixir' '$1')
  end

  # readlink_f changes the current directory (since fish doesn't have
  # subshells), so it needs to be restored.
  cd $current_dir
end

echo "Looking for asdf install" >&2

# Check if we have the asdf binary for version >= 0.16.0
set asdf (which asdf)
if test -n "$asdf"
    set asdf_version (asdf --version)
    set semver (string match -r '(\d+)\.(\d+)\.(\d+)' $asdf_version)
    if test $semver[2] -eq 0 -a $semver[3] -lt 16
        # Fallback to old method for asdf version <= 0.15.x
        test -n "$ASDF_DIR"; or set ASDF_DIR "$HOME/.asdf"
        set ASDF_SH "$ASDF_DIR/asdf.fish"
        echo "Legacy pre v0.16.0 asdf install found at $ASDF_SH, sourcing" >&2
        # Source the old asdf.sh script for versions <= 0.15.0
        source "$ASDF_SH"
    else
        echo "asdf executable found at $asdf. Using ASDF_DIR=$ASDF_DIR, ASDF_DATA_DIR=$ASDF_DATA_DIR." >&2
    end
    export_stdlib_path "asdf which elixir"
else
    # Fallback to old method for asdf version <= 0.15.x
    test -n "$ASDF_DIR"; or set ASDF_DIR "$HOME/.asdf"
    set ASDF_SH "$ASDF_DIR/asdf.fish"
    if test -f "$ASDF_SH"
        echo "Legacy pre v0.16.0 asdf install found at $ASDF_SH, sourcing" >&2
        # Source the old asdf.sh script for versions <= 0.15.0
        source "$ASDF_SH"
        export_stdlib_path "asdf which elixir"
    else
        echo "asdf not found" >&2
        echo "Looking for mise executable" >&2

        set mise (which mise)
        if test -n "$mise"
            echo "mise executable found at $mise, activating" >&2
            "$mise" env -s fish | source
            export_stdlib_path "mise which elixir"
        else
            echo "mise not found" >&2
            echo "Looking for vfox executable" >&2

            set vfox (which vfox)
            if test -n "$vfox"
                echo "vfox executable found at $vfox, activating" >&2
                "$vfox" activate fish | source
            else
                echo "vfox not found" >&2
                export_stdlib_path "which elixir"
            end
        end
    end
end

# In case that people want to tweak the path, which Elixir to use, or
# whatever prior to launching the language server or the debug adapter, we
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

if test -z "$ELS_INSTALL_PREFIX"
  set -l current_dir (pwd)
  set scriptpath (dirname (readlink_f (status -f)))

  # readlink_f changes the current directory (since fish doesn't have
  # subshells), so it needs to be restored.
  cd $current_dir
else
  set scriptpath $ELS_INSTALL_PREFIX
end

# Unset MIX_OS_DEPS_COMPILE_PARTITION_COUNT as it pollutes stdout
# breaking LSP protocol. See https://github.com/elixir-lsp/elixir-ls/issues/1195
set -e MIX_OS_DEPS_COMPILE_PARTITION_COUNT

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

exec elixir $elixir_opts --erl "$erl_opts" "$scriptpath/launch.exs"
