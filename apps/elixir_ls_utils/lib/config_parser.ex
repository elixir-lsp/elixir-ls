defmodule ElixirLS.Utils.ConfigParser do
  @moduledoc """
  Parses and loads an ElixirLS configuration file
  """

  alias ElixirLS.Utils.Config.SettingDef

  @settings [
    %SettingDef{
      key: :dialyzer_enabled,
      json_key: "dialyzerEnabled",
      type: :boolean,
      default: true,
      doc: "Run ElixirLS's rapid Dialyzer when code is saved"
    },
    %SettingDef{
      key: :dialyzer_format,
      json_key: "dialyzerFormat",
      type: {:one_of, ["dialyzer", "dialyxir_short", "dialyxir_long"]},
      default: "dialyxir_long",
      doc: "Formatter to use for Dialyzer warnings"
    },
    %SettingDef{
      key: :dialyzer_warn_opts,
      json_key: "dialyzerWarnOpts",
      type:
        {:custom, ElixirLS.Utils.NimbleListChecker, :list,
         [
           "error_handling",
           "no_behaviours",
           "no_contracts",
           "no_fail_call",
           "no_fun_app",
           "no_improper_lists",
           "no_match",
           "no_missing_calls",
           "no_opaque",
           "no_return",
           "no_undefined_callbacks",
           "no_unused",
           "underspecs",
           "unknown",
           "unmatched_returns",
           "overspecs",
           "specdiffs"
         ]},
      default: [],
      doc:
        "Dialyzer options to enable or disable warnings. See Dialyzer's documentation for options. Note that the `race_conditions` option is unsupported"
    },
    %SettingDef{
      key: :fetch_deps,
      json_key: "fetchDeps",
      type: :boolean,
      default: true,
      doc: "Automatically fetch project dependencies when compiling"
    },
    %SettingDef{
      key: :mix_env,
      json_key: "mixEnv",
      type: :string,
      default: "test",
      doc: "Mix environment to use for compilation"
    },
    %SettingDef{
      key: :mix_target,
      json_key: "mixTarget",
      type: :string,
      default: "host",
      doc: "Mix target (`MIX_TARGET`) to use for compilation (requires Elixir >= 1.8)"
    },
    %SettingDef{
      key: :project_dir,
      json_key: "projectDir",
      type: :string,
      default: "",
      doc:
        "Subdirectory containing Mix project if not in the project root. " <>
          "If value is \"\" then defaults to the workspace rootUri."
    },
    %SettingDef{
      key: :suggest_specs,
      json_key: "suggestSpecs",
      type: :boolean,
      default: true,
      doc:
        "Suggest @spec annotations inline using Dialyzer's inferred success typings " <>
          "(Requires Dialyzer)"
    },
    %SettingDef{
      key: :trace,
      json_key: "trace",
      type: :map,
      default: %{},
      doc: "Ignored"
    }
  ]

  def load_config_file(path) do
    with {:ok, contents} <- File.read(path) do
      load_config(contents)
    end
  end

  def load_config(contents) do
    with {:ok, settings_map} <- json_decode(contents),
         {:ok, validated_options} <- parse_config(settings_map) do
      {:ok, Map.new(validated_options), []}
    end
  end

  def default_config do
    @settings
    |> Map.new(fn %SettingDef{} = setting_def ->
      %SettingDef{key: key, default: default} = setting_def
      {key, default}
    end)
  end

  @doc """
  Parse the raw decoded JSON to the settings map (including translation from
  camelCase to snake_case)
  """
  def parse_config(settings_map) do
    # Because we use a configuration layering approach, this configuration
    # parsing should be based on the settings_map and not the possible settings.
    # The return value should be *only* the settings that were passed in, don't
    # return the defaults here.
    values =
      settings_map
      |> Enum.map(fn {json_key, value} ->
        case translate_key(json_key) do
          {:ok, key} -> {:ok, {key, value}}
          {:error, "unknown key"} -> {:error, {:unrecognized_configuration_key, json_key, value}}
        end
      end)

    {good, errors} = Enum.split_with(values, &match?({:ok, _}, &1))
    config = Map.new(good, fn {:ok, {key, val}} -> {key, val} end)

    {:ok, config, errors}
  end

  for %SettingDef{key: key, json_key: json_key} <- @settings do
    defp translate_key(unquote(json_key)) do
      {:ok, unquote(key)}
    end
  end

  defp translate_key(_), do: {:error, "unknown key"}

  for setting <- @settings do
    def valid_key?(unquote(setting.json_key)), do: true
  end

  def valid_key?(_), do: false

  def json_decode(contents) when is_binary(contents) do
    contents
    |> String.split(["\n", "\r", "\r\n"], trim: true)
    |> Enum.map(&String.trim/1)
    # Ignore json comments
    |> Enum.reject(&String.starts_with?(&1, "//"))
    |> Enum.join()
    |> JasonVendored.decode()
    |> case do
      {:ok, _} = ok -> ok
      {:error, %JasonVendored.DecodeError{} = err} -> {:error, {:invalid_json, err}}
    end
  end
end
