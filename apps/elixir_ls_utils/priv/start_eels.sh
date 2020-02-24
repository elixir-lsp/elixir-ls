#!/usr/bin/env bash
# Launches a new Elixir Embedded Language Server, which
# runs the Elixir/OTP version-specific bits of Elixir-LS

# TODO Win10 version

[ -f "$HOME/.asdf/asdf.sh" ] && . "$HOME/.asdf/asdf.sh"

echo "Starting Eels, PWD=$PWD"
echo "Language Server Release Dir: RELEASE_ROOT"

# Run elixir, asdf-vm makes it the project specific version.
elixir ${RELEASE_DIR}/lib/eels-${EELS_VERSION}/priv/eels_main.exs
