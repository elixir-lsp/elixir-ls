# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
# import_config "../apps/*/config/config.exs"

# Sample configuration (overrides the imported configuration above):
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

env_bool = fn name ->
  enabled_str =
    name
    |> System.get_env("false")
    |> String.downcase()

  enabled_str == "true"
end

# Enable ElixirSense's native Module.Types backend (set-theoretic type inference
# powering inlay hints, hover, and completion). Requires Elixir 1.19+; falls
# back to the custom engine automatically when unavailable. On by default on
# this branch — set ELIXIR_LS_TYPE_INFERENCE=false to disable for A/B testing.
config :elixir_sense,
  use_elixir_types:
    System.get_env("ELIXIR_LS_TYPE_INFERENCE", "true") |> String.downcase() != "false"

# NOTE: the native-typing backend's verbose degradation-log flood on Elixir
# 1.18/1.19 is tamed in apps/language_server/test/test_helper.exs via per-module
# Logger levels (`Logger.put_module_level/2`) scoped to the offending dep
# modules, rather than a global level change here (which would suppress the
# language server's own LSP logging that several tests assert on).
