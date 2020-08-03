defmodule ElixirLS.LanguageServer.ConfigLoader do
  @moduledoc """
  Responsible for loading the configuration. Applies configuration in this
  order: defaults, previously loaded configuration, user home dir configuration,
  editor configuration
  """

  # Configuration Loading Order
  #
  # - Server starts up (it knows the root directory)
  # - User provides did_change_configuration (or we fall back to defaults)
  #   - NOTE: This is where all the configuration is loaded
  # - Load and apply all the configuration in this order:
  #   - Existing Server Config
  #   - User Home Config
  #   - Workspace Config
  #   - Editor Config

  alias ElixirLS.Utils.ConfigParser
  alias ElixirLS.LanguageServer.JsonRpc

  # Can we change this to load also from the workspace root? Note: might need multiple passes for that to work

  def load(prev_config, editor_config, opts \\ []) do
    user_home_config =
      Keyword.get_lazy(opts, :load_user_home_config, fn ->
        load_user_home_config()
      end)

    default_config = ConfigParser.default_config()
    editor_config = ConfigParser.parse_config(editor_config)

    config =
      [default_config, prev_config, user_home_config, editor_config]
      |> Enum.reduce(%{}, fn
        {:ok, :skip}, acc ->
          acc

        {:ok, config, errors}, acc when is_map(config) ->
          Enum.each(errors, fn {:error, {:unrecognized_configuration_key, key, value}} ->
            JsonRpc.log_message(:warning, "Invalid configuration key: #{key} with value #{inspect value}")
          end)

          Map.merge(acc, config)

        config, acc when is_map(config) ->
          Map.merge(acc, config)
      end)

    errors = []
    {:ok, config, errors}
  end

  defp load_user_home_config do
    case xdg_module().read_elixir_ls_config_file("config.json") do
      {:ok, file_contents} ->
        ConfigParser.load_config(file_contents)

      {:error, :enoent} ->
        {:ok, :skip}

      {:error, err} ->
        {:error, err}
    end
  end

   defp xdg_module, do: Application.fetch_env!(:language_server, :xdg_module)
end
