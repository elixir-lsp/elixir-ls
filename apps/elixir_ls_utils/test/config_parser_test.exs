defmodule ElixirLS.Utils.ConfigParserTest do
  use ExUnit.Case, async: true

  alias ElixirLS.Utils.ConfigParser

  @default_mix_env "test"
  @default_dialyzer_enabled true
  @default_project_dir ""

  test "default_config returns the defaults" do
    config = ConfigParser.default_config()

    assert config.mix_env == @default_mix_env
    assert config.dialyzer_enabled == @default_dialyzer_enabled
    assert config.project_dir == @default_project_dir
  end

  test "load_config new defaults" do
    config_contents = "{\"dialyzerFormat\": \"dialyxir_short\"}"

    assert {:ok, %{dialyzer_format: "dialyxir_short"}, []} =
             ConfigParser.load_config(config_contents)
  end

  test "load_config with an empty configuration file returns an empty config" do
    config_contents = "{}"

    assert {:ok, config, errors} = ConfigParser.load_config(config_contents)

    assert config == %{}
    assert errors == []
  end

  test "load_config with an invalid setting key" do
    config_contents = JasonVendored.encode!(%{"badKey" => "invalid"})

    assert {:ok, config, errors} = ConfigParser.load_config(config_contents)

    assert [error: {:unrecognized_configuration_key, "badKey", "invalid"}] = errors
  end

  test "load_config with dialyzer disabled and false" do
    config_contents = "{\n\t\"dialyzerEnabled\": false,\n\t\"dialyzerFormat\": \"dialyzer\"\n}\n"
    assert {:ok, config, errors} = ConfigParser.load_config(config_contents)

    assert config == %{
             dialyzer_enabled: false,
             dialyzer_format: "dialyzer"
           }
  end

  @tag :pending
  test "load_config with a setting with an invalid value" do
    config_contents = JasonVendored.encode!(%{"dialyzerFormat" => "other_format"})

    assert {:ok, _config, errors} = ConfigParser.load_config(config_contents)

    assert [
             error:
               {:value_not_allowed, "other_format", "dialyzerFormat",
                ["dialyzer", "dialyxir_short", "dialyxir_long"]}
           ] = errors
  end

  test "load_config can set the default mix env" do
    config_contents = JasonVendored.encode!(%{"mixEnv" => "dev"})

    assert {:ok, config, errors} = ConfigParser.load_config(config_contents)

    assert config.mix_env == "dev"
    assert errors == []
  end

  test "load_config with an invalid json file" do
    config_contents = "this is not json"

    assert {:error, {:invalid_json, decode_error}} = ConfigParser.load_config(config_contents)

    assert decode_error.data == config_contents
  end

  test "load_config/1 ignores lines with comments" do
    config_contents = """
    // This is the configuration file for ElixirLS
    {
      // Disable dialyzer
      "dialyzerEnabled": false
    }
    """

    assert {:ok, config, _} = ConfigParser.load_config(config_contents)

    assert config.dialyzer_enabled == false
  end

  test "load_config_file/1 loads a valid configuration file" do
    path =
      Path.join([__DIR__, "support/example_config_file.jsonc"])
      |> Path.expand()

    assert {:ok, config, errors} = ConfigParser.load_config_file(path)
    assert config.dialyzer_enabled == false
    assert config.fetch_deps == false
    assert config.mix_env == "dev"
    assert errors == []
  end

  test "load_config_file/1 with a missing configuration file" do
    path = "non-existant-file"

    assert {:error, :enoent} = ConfigParser.load_config_file(path)
  end
end
