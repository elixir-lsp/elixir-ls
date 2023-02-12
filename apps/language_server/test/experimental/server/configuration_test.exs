defmodule ElixirLS.Experimental.Server.ConfigurationTest do
  alias ElixirLS.LanguageServer.Dialyzer
  alias ElixirLS.LanguageServer.Experimental.Project
  alias ElixirLS.LanguageServer.Experimental.Protocol.Notifications.DidChangeConfiguration
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.LspTypes.Registration
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.RegisterCapability
  alias ElixirLS.LanguageServer.Experimental.Server.Configuration
  alias ElixirLS.LanguageServer.SourceFile

  use ExUnit.Case, async: false
  use Patch

  def fixture(opts \\ []) do
    signature_help? = Keyword.get(opts, :signature_help?, false)
    dynamic_registration? = Keyword.get(opts, :dynamic_registration?, false)
    hierarchical_symbols? = Keyword.get(opts, :hierarchical_symbols?, false)
    snippet? = Keyword.get(opts, :snippet?, false)
    deprecated? = Keyword.get(opts, :deprecated?, false)
    tag? = Keyword.get(opts, :tag?, false)

    %{
      "textDocument" => %{
        "signatureHelp" => signature_help?,
        "codeAction" => %{"dynamicRegistration" => dynamic_registration?},
        "documentSymbol" => %{"hierarchicalDocumentSymbolSupport" => hierarchical_symbols?},
        "completion" => %{
          "completionItem" => %{
            "snippetSupport" => snippet?,
            "deprecatedSupport" => deprecated?,
            "tagSupport" => tag?
          }
        }
      }
    }
  end

  def root_uri do
    "file:///tmp/my_project"
  end

  def with_a_root_uri(_) do
    {:ok, root_uri: "file:///tmp/my_project"}
  end

  setup do
    patch(File, :cd, :ok)
    patch(File, :dir?, true)
    patch(Mix, :env, :ok)
    :ok
  end

  describe "new/2" do
    setup [:with_a_root_uri]

    test "should set the root uri" do
      patch(File, :cwd, {:ok, SourceFile.Path.absolute_from_uri(root_uri())})
      config = Configuration.new(root_uri(), fixture())
      assert config.project.root_uri == root_uri()
    end

    test "should handle a nil root uri" do
      config = Configuration.new(nil, fixture())
      assert config.project.root_uri == nil
    end

    test "should cd to the root uri if it exists" do
      Configuration.new(root_uri(), fixture())
      root_path = SourceFile.Path.absolute_from_uri(root_uri())

      assert_called(File.cd(^root_path))
    end

    test "shouldn't cd to the root uri if it doesn't exist" do
      non_existent_uri = "file:///hopefully/doesn_t/exist"
      patch(File, :cd, {:error, :enoent})

      config = Configuration.new(non_existent_uri, fixture())

      assert config.project.root_uri == nil
    end

    test "should read dynamic registration" do
      pos_config = Configuration.new(root_uri(), fixture(dynamic_registration?: true))
      neg_config = Configuration.new(root_uri(), fixture(dynamic_registration?: false))

      assert pos_config.support.code_action_dynamic_registration?
      refute neg_config.support.code_action_dynamic_registration?
      refute Configuration.new(root_uri(), %{}).support.code_action_dynamic_registration?
    end

    test "it should support signature_help" do
      assert Configuration.new(root_uri(), fixture(signature_help?: true)).support.signature_help?

      refute Configuration.new(root_uri(), fixture(signature_help?: false)).support.signature_help?

      refute Configuration.new(root_uri(), %{}).support.signature_help?
    end

    test "it should support hierarchical registration" do
      assert Configuration.new(root_uri(), fixture(hierarchical_symbols?: true)).support.hierarchical_document_symbols?

      refute Configuration.new(root_uri(), fixture(hierarchical_symbols?: false)).support.hierarchical_document_symbols?

      refute Configuration.new(root_uri(), %{}).support.hierarchical_document_symbols?
    end

    test "it should support snippets" do
      assert Configuration.new(root_uri(), fixture(snippet?: true)).support.snippet?
      refute Configuration.new(root_uri(), fixture(snippet?: false)).support.snippet?
      refute Configuration.new(root_uri(), %{}).support.snippet?
    end

    test "it should support deprecated" do
      assert Configuration.new(root_uri(), fixture(deprecated?: true)).support.deprecated?
      refute Configuration.new(root_uri(), fixture(deprecated?: false)).support.deprecated?
      refute Configuration.new(root_uri(), %{}).support.deprecated?
    end

    test "it should support tags" do
      assert Configuration.new(root_uri(), fixture(deprecated?: true)).support.deprecated?
      refute Configuration.new(root_uri(), fixture(deprecated?: false)).support.deprecated?
      refute Configuration.new(root_uri(), %{}).support.deprecated?
    end
  end

  def with_an_empty_config(_) do
    {:ok, config: Configuration.new(root_uri(), %{})}
  end

  describe "changing mix.env" do
    setup [:with_an_empty_config]

    test "overwrites an unset env ", ctx do
      change = DidChangeConfiguration.new(settings: %{"mixEnv" => "dev"})
      assert {:ok, %Configuration{} = config} = Configuration.on_change(ctx.config, change)

      assert config.project.mix_env == :dev
      assert_called(Mix.env(:dev))
    end

    test "defaults to test", ctx do
      change = DidChangeConfiguration.new(settings: %{})
      assert {:ok, %Configuration{} = config} = Configuration.on_change(ctx.config, change)

      assert config.project.mix_env == :test
      assert_called(Mix.env(:test))
    end
  end

  def with_patched_system_put_env(_) do
    patch(System, :put_env, :ok)

    on_exit(fn ->
      restore(System)
    end)

    :ok
  end

  describe "setting env vars" do
    setup [:with_an_empty_config, :with_patched_system_put_env]

    test "overwrites existing env vars if it wasn't set", ctx do
      vars = %{"first_var" => "first_value", "second_var" => "second_value"}

      change = DidChangeConfiguration.new(settings: %{"envVariables" => vars})
      assert {:ok, %Configuration{} = config} = Configuration.on_change(ctx.config, change)

      expected_env_vars = %{
        "first_var" => "first_value",
        "second_var" => "second_value"
      }

      assert config.project.env_variables == expected_env_vars
      assert_called(System.put_env(^expected_env_vars))
    end
  end

  def with_patched_mix_target(_) do
    patch(Mix, :target, :ok)
    :ok
  end

  describe "setting the mix target" do
    setup [:with_an_empty_config, :with_patched_mix_target]

    test "allows you to set the mix target if it was unset", ctx do
      change = DidChangeConfiguration.new(settings: %{"mixTarget" => "local"})

      assert {:ok, %Configuration{} = config} = Configuration.on_change(ctx.config, change)
      assert config.project.mix_target == :local
      assert_called(Mix.target(:local))
    end
  end

  describe("setting the project dir") do
    setup [:with_an_empty_config]

    test "becomes part of the project if the state is empty", ctx do
      change = DidChangeConfiguration.new(settings: %{"projectDir" => "sub_dir/new/dir"})

      assert {:ok, %Configuration{} = config} = Configuration.on_change(ctx.config, change)
      assert Project.project_path(config.project) == "#{File.cwd!()}/sub_dir/new/dir"
    end

    test "only sets the project directory if the root uri is set" do
      config = Configuration.new(nil, fixture())
      change = DidChangeConfiguration.new(settings: %{"projectDir" => "sub_dir/new/dir"})

      assert {:ok, config} = Configuration.on_change(config, change)
      assert config.project.root_uri == nil
      assert Project.project_path(config.project) == nil
    end
  end

  def with_patched_dialyzer_support(_) do
    patch(Dialyzer, :check_support, :ok)
    :ok
  end

  describe("setting dialyzer being enabled") do
    setup [:with_an_empty_config, :with_patched_dialyzer_support]

    test "it can be enabled if it is supported", ctx do
      refute ctx.config.dialyzer_enabled?
      change = DidChangeConfiguration.new(settings: %{"dialyzer_enabled" => true})

      assert {:ok, config} = Configuration.on_change(ctx.config, change)
      assert config.dialyzer_enabled?
    end

    test "it should be on by default", ctx do
      change = DidChangeConfiguration.new(settings: %{})

      assert {:ok, config} = Configuration.on_change(ctx.config, change)
      assert config.dialyzer_enabled?
    end

    test "if dialyzer is not supported, it can't be turned on", ctx do
      patch(Dialyzer, :check_support, {:error, "Dialyzer is broken"})
      change = DidChangeConfiguration.new(settings: %{"dialyzer_enabled" => true})

      assert {:ok, config} = Configuration.on_change(ctx.config, change)
      refute config.dialyzer_enabled?
    end
  end

  describe("setting watched extensions") do
    setup [:with_an_empty_config]

    test "it returns the state if no extenstions are given", ctx do
      config = ctx.config
      change = DidChangeConfiguration.new(settings: %{"additionalWatchedExtensions" => []})
      # ensuring it didn't send back any messages for us to process
      assert {:ok, _} = Configuration.on_change(config, change)
    end

    test "it returns a register capability request with watchers for each extension", ctx do
      config = ctx.config

      change =
        DidChangeConfiguration.new(
          settings: %{"additionalWatchedExtensions" => [".ex3", ".heex"]}
        )

      assert {:ok, _config, %RegisterCapability{} = watch_request} =
               Configuration.on_change(config, change)

      assert [%Registration{} = registration] = watch_request.lsp.registrations
      assert registration.method == "workspace/didChangeWatchedFiles"

      assert %{"watchers" => watchers} = registration.register_options
      assert %{"globPattern" => "**/*.ex3"} in watchers
      assert %{"globPattern" => "**/*.heex"} in watchers
    end
  end
end
