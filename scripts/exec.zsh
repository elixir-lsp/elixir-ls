# we need to make sure ELS_ELIXIR_OPTS gets splitted by word
# parse it as zsh array
# shellcheck disable=SC3030
# shellcheck disable=SC2296
elixir_opts=("${(z)ELS_ELIXIR_OPTS}")
# shellcheck disable=SC2128
# shellcheck disable=SC2086
exec elixir $elixir_opts --erl "$default_erl_opts $ELS_ERL_OPTS" "$SCRIPTPATH/launch.exs"
