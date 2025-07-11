defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDocsAggregatorTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDocsAggregator

  describe "execute/2" do
    test "aggregates documentation for multiple modules" do
      modules = ["String", "Enum"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 2
      
      # Check String module
      string_result = Enum.find(result.results, &(&1.name == "String"))
      assert string_result
      assert string_result.module == "String"
      assert string_result.moduledoc
      assert is_list(string_result.functions)
      assert length(string_result.functions) > 0
      
      # Check Enum module
      enum_result = Enum.find(result.results, &(&1.name == "Enum"))
      assert enum_result
      assert enum_result.module == "Enum"
      assert enum_result.moduledoc
      assert is_list(enum_result.functions)
      assert length(enum_result.functions) > 0
    end

    test "handles function documentation with arity" do
      modules = ["String.split/2"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
      
      func_result = hd(result.results)
      assert func_result.name == "String.split/2"
      # For functions, we might get module and function info
      # depending on how get_documentation handles it
    end

    test "handles function documentation without arity" do
      modules = ["Enum.map"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
      
      func_result = hd(result.results)
      assert func_result.name == "Enum.map"
    end

    test "handles type documentation" do
      # Types are typically accessed with module.t format
      modules = ["String.t"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
    end

    test "handles attribute documentation" do
      modules = ["@moduledoc"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
    end

    test "handles builtin type documentation" do
      modules = ["t:binary"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
    end

    test "handles Erlang module format" do
      modules = [":erlang"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
      
      erlang_result = hd(result.results)
      assert erlang_result.name == ":erlang"
    end

    test "handles invalid symbol gracefully" do
      modules = [":::invalid:::"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
      
      invalid_result = hd(result.results)
      assert invalid_result.name == ":::invalid:::"
      # V2 parser might successfully parse this but return module with no docs
      # Both error and empty module result are acceptable
      assert invalid_result[:error] || (invalid_result[:module] && invalid_result[:moduledoc] == nil)
    end

    test "handles mix of valid and invalid modules" do
      modules = ["String", ":::invalid:::", "Enum"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 3
      
      # Check that we have results for all 3 modules
      # V2 parser might parse all of them, so we should have either:
      # - All successful with module info, or
      # - Some with errors and some successful
      results_with_modules = Enum.filter(result.results, &(&1[:module]))
      results_with_errors = Enum.filter(result.results, &(&1[:error]))
      
      # We should have at least String and Enum as successful
      assert length(results_with_modules) >= 2
      # Total results should be 3
      assert length(results_with_modules) + length(results_with_errors) == 3
    end

    test "handles modules without documentation" do
      # Define a module without docs for testing
      defmodule TestModuleWithoutDocs do
        def hello, do: :world
      end
      
      module_name = "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDocsAggregatorTest.TestModuleWithoutDocs"
      modules = [module_name]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
      
      test_result = hd(result.results)
      assert test_result.name == module_name
      # Module exists but may not have documentation
    end

    test "handles nested module names" do
      modules = ["GenServer"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
      
      genserver_result = hd(result.results)
      assert genserver_result.module == "GenServer"
      assert genserver_result.moduledoc
    end

    test "returns error for invalid arguments" do
      # Test with non-list argument
      assert {:ok, result} = LlmDocsAggregator.execute("String", %{})
      assert Map.has_key?(result, :error)
      assert result.error == "Invalid arguments: expected [modules_list]"
      
      # Test with empty arguments
      assert {:ok, result} = LlmDocsAggregator.execute([], %{})
      assert Map.has_key?(result, :error)
      assert result.error == "Invalid arguments: expected [modules_list]"
      
      # Test with nil
      assert {:ok, result} = LlmDocsAggregator.execute(nil, %{})
      assert Map.has_key?(result, :error)
      assert result.error == "Invalid arguments: expected [modules_list]"
    end
  end
end
