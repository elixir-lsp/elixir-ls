defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfoDialyzerTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  use ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.{Server, Build, MixProjectCache, Parser, Tracer}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmTypeInfo
  import ElixirLS.LanguageServer.Test.ServerTestHelpers

  setup_all do
    compiler_options = Code.compiler_options()
    Build.set_compiler_options()

    on_exit(fn ->
      Code.compiler_options(compiler_options)
    end)

    {:ok, %{}}
  end

  setup do
    {:ok, server} = Server.start_link()
    {:ok, _} = start_supervised(MixProjectCache)
    {:ok, _} = start_supervised(Parser)
    start_server(server)
    {:ok, _tracer} = start_supervised(Tracer)

    on_exit(fn ->
      if Process.alive?(server) do
        Process.monitor(server)
        GenServer.stop(server)

        receive do
          {:DOWN, _, _, ^server, _} ->
            :ok
        end
      end
    end)

    {:ok, %{server: server}}
  end

  @tag :slow
  @tag :fixture
  test "includes dialyzer contracts when PLT is available", %{server: server} do
    in_fixture(Path.join(__DIR__, "../.."), "dialyzer", fn ->
      # Get the file URI for Suggest module
      file_suggest =
        ElixirLS.LanguageServer.SourceFile.Path.to_uri(Path.absname("lib/suggest.ex"))

      # Initialize with dialyzer enabled (incremental is default)
      initialize(server, %{
        "dialyzerEnabled" => true,
        "dialyzerFormat" => "dialyxir_long",
        "suggestSpecs" => true
      })

      # Wait for dialyzer to finish initial analysis
      assert_receive %{"method" => "textDocument/publishDiagnostics"}, 30000

      # Open the file so server knows about it
      Server.receive_packet(
        server,
        did_open(file_suggest, "elixir", 1, File.read!(Path.absname("lib/suggest.ex")))
      )

      # Give dialyzer time to analyze the file
      Process.sleep(1000)

      # Get the server state which should have PLT loaded and contracts available
      state = :sys.get_state(server)

      # Now test our LlmTypeInfo command with module Suggest which has unspecced functions
      assert {:ok, result} = LlmTypeInfo.execute(["Suggest"], state)

      # Module Suggest should have dialyzer contracts for its unspecced functions
      assert result.module == "Suggest"
      assert is_list(result.dialyzer_contracts)
      assert length(result.dialyzer_contracts) > 0

      # Check contracts for different types of functions from the fixture

      # Regular function with no arguments
      no_arg_contract = Enum.find(result.dialyzer_contracts, &(&1.name == "no_arg/0"))
      assert no_arg_contract
      assert no_arg_contract.contract
      assert String.contains?(no_arg_contract.contract, "no_arg() :: :ok")

      # Function with pattern matching
      one_arg_contract = Enum.find(result.dialyzer_contracts, &(&1.name == "one_arg/1"))
      assert one_arg_contract
      assert one_arg_contract.contract
      assert String.contains?(one_arg_contract.contract, "one_arg(")

      # Function with multiple arities
      multiple_arities_1_contract =
        Enum.find(result.dialyzer_contracts, &(&1.name == "multiple_arities/1"))

      if multiple_arities_1_contract do
        assert multiple_arities_1_contract.contract
        assert String.contains?(multiple_arities_1_contract.contract, "multiple_arities(")
      end

      multiple_arities_2_contract =
        Enum.find(result.dialyzer_contracts, &(&1.name == "multiple_arities/2"))

      if multiple_arities_2_contract do
        assert multiple_arities_2_contract.contract
        assert String.contains?(multiple_arities_2_contract.contract, "multiple_arities(")
      end

      # Function with default arguments (creates multiple arities internally)
      default_arg_contract =
        Enum.find(result.dialyzer_contracts, fn contract ->
          String.starts_with?(contract.name, "default_arg_functions/")
        end)

      if default_arg_contract do
        assert default_arg_contract.contract
        assert String.contains?(default_arg_contract.contract, "default_arg_functions(")
      end

      # Macro (should have normalized name)
      macro_contract = Enum.find(result.dialyzer_contracts, &(&1.name == "macro/1"))

      if macro_contract do
        assert macro_contract.contract
        assert String.contains?(macro_contract.contract, "macro(")
      end

      # Function with guards and multiple clauses
      multiple_clauses_contract =
        Enum.find(result.dialyzer_contracts, &(&1.name == "multiple_clauses/1"))

      if multiple_clauses_contract do
        assert multiple_clauses_contract.contract
        assert String.contains?(multiple_clauses_contract.contract, "multiple_clauses(")
      end

      # Ensure all contracts are in Elixir format (not Erlang)
      for contract <- result.dialyzer_contracts do
        # Should not contain Erlang-style syntax
        refute String.contains?(contract.contract, "->")
        refute String.contains?(contract.contract, "fun(")

        # Should contain Elixir-style syntax
        assert String.contains?(contract.contract, "::")
      end

      wait_until_compiled(server)
    end)
  end

  @tag :slow
  @tag :fixture
  test "filters dialyzer contracts by specific arity (MFA)", %{server: server} do
    in_fixture(Path.join(__DIR__, "../.."), "dialyzer", fn ->
      # Get the file URI for Suggest module
      file_suggest =
        ElixirLS.LanguageServer.SourceFile.Path.to_uri(Path.absname("lib/suggest.ex"))

      # Initialize with dialyzer enabled
      initialize(server, %{
        "dialyzerEnabled" => true,
        "dialyzerFormat" => "dialyxir_long",
        "suggestSpecs" => true
      })

      # Wait for dialyzer to finish initial analysis
      assert_receive %{"method" => "textDocument/publishDiagnostics"}, 30000

      # Open the file so server knows about it
      Server.receive_packet(
        server,
        did_open(file_suggest, "elixir", 1, File.read!(Path.absname("lib/suggest.ex")))
      )

      # Give dialyzer time to analyze the file
      Process.sleep(1000)

      # Get the server state
      state = :sys.get_state(server)

      # Test MFA - should return contracts only for specific arity
      assert {:ok, result} = LlmTypeInfo.execute(["Suggest.multiple_arities/1"], state)

      assert result.module == "Suggest"
      assert is_list(result.dialyzer_contracts)

      # Should only include contracts for multiple_arities/1, not multiple_arities/2
      arity_1_contracts =
        Enum.filter(result.dialyzer_contracts, &(&1.name == "multiple_arities/1"))

      arity_2_contracts =
        Enum.filter(result.dialyzer_contracts, &(&1.name == "multiple_arities/2"))

      # Should have the arity 1 contract
      assert length(arity_1_contracts) == 1
      arity_1_contract = hd(arity_1_contracts)
      assert String.contains?(arity_1_contract.contract, "multiple_arities(")
      assert String.contains?(arity_1_contract.contract, "::")

      # Should NOT have the arity 2 contract
      assert length(arity_2_contracts) == 0

      # Should not have contracts for other functions
      refute Enum.any?(result.dialyzer_contracts, &(&1.name == "no_arg/0"))
      refute Enum.any?(result.dialyzer_contracts, &(&1.name == "one_arg/1"))

      wait_until_compiled(server)
    end)
  end

  @tag :slow
  @tag :fixture
  test "filters dialyzer contracts by function name (MF)", %{server: server} do
    in_fixture(Path.join(__DIR__, "../.."), "dialyzer", fn ->
      # Get the file URI for Suggest module
      file_suggest =
        ElixirLS.LanguageServer.SourceFile.Path.to_uri(Path.absname("lib/suggest.ex"))

      # Initialize with dialyzer enabled
      initialize(server, %{
        "dialyzerEnabled" => true,
        "dialyzerFormat" => "dialyxir_long",
        "suggestSpecs" => true
      })

      # Wait for dialyzer to finish initial analysis
      assert_receive %{"method" => "textDocument/publishDiagnostics"}, 30000

      # Open the file so server knows about it
      Server.receive_packet(
        server,
        did_open(file_suggest, "elixir", 1, File.read!(Path.absname("lib/suggest.ex")))
      )

      # Give dialyzer time to analyze the file
      Process.sleep(1000)

      # Get the server state
      state = :sys.get_state(server)

      # Test MF - should return contracts for all arities of the function
      assert {:ok, result} = LlmTypeInfo.execute(["Suggest.multiple_arities"], state)

      assert result.module == "Suggest"
      assert is_list(result.dialyzer_contracts)

      # Should include contracts for both multiple_arities/1 and multiple_arities/2
      arity_1_contracts =
        Enum.filter(result.dialyzer_contracts, &(&1.name == "multiple_arities/1"))

      arity_2_contracts =
        Enum.filter(result.dialyzer_contracts, &(&1.name == "multiple_arities/2"))

      # Should have both arity contracts
      assert length(arity_1_contracts) == 1
      assert length(arity_2_contracts) == 1

      arity_1_contract = hd(arity_1_contracts)
      assert String.contains?(arity_1_contract.contract, "multiple_arities(")
      assert String.contains?(arity_1_contract.contract, "::")

      arity_2_contract = hd(arity_2_contracts)
      assert String.contains?(arity_2_contract.contract, "multiple_arities(")
      assert String.contains?(arity_2_contract.contract, "::")

      # Should not have contracts for other functions
      refute Enum.any?(result.dialyzer_contracts, &(&1.name == "no_arg/0"))
      refute Enum.any?(result.dialyzer_contracts, &(&1.name == "one_arg/1"))

      wait_until_compiled(server)
    end)
  end
end
