# we need to make sure ELS_ELIXIR_OPTS gets splitted by word
# parse it as bash array
# shellcheck disable=SC3045
# shellcheck disable=SC3011
IFS=' ' read -ra elixir_opts <<< "$ELS_ELIXIR_OPTS"
# shellcheck disable=SC3054
# shellcheck disable=SC2068
exec elixir ${elixir_opts[@]} --erl "$default_erl_opts $ELS_ERL_OPTS" "$SCRIPTPATH/launch.exs"
