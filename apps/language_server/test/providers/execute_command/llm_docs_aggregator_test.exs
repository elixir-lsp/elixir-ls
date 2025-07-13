defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDocsAggregatorTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDocsAggregator

  describe "execute/2" do
    test "gets module documentation" do
      modules = ["Atom"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      # Check Atom module
      atom_result = Enum.find(result.results, &(&1.module == "Atom"))
      assert atom_result |> dbg
      assert is_binary(atom_result.moduledoc)
      assert is_list(atom_result.functions)
      assert length(atom_result.functions) > 0
    end

    test "gets module function and macro list" do
      modules = ["Kernel"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      # Check Kernel module
      kernel_result = Enum.find(result.results, &(&1.module == "Kernel"))
      assert kernel_result
      assert is_list(kernel_result.functions)
      assert length(kernel_result.functions) > 0

      assert is_list(kernel_result.macros)
      assert length(kernel_result.macros) > 0

      assert "send/2" in kernel_result.functions

      assert "defdelegate/2" in kernel_result.macros
    end

    test "gets module type list" do
      modules = ["Date"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      # Check Date module
      date_result = Enum.find(result.results, &(&1.module == "Date"))
      assert date_result
      assert is_list(date_result.types)
      assert length(date_result.types) > 0

      assert "t/0" in date_result.types
    end

    test "gets module callback list" do
      modules = ["Access"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      # Check Access module
      access_result = Enum.find(result.results, &(&1.module == "Access"))
      assert access_result
      assert is_list(access_result.callbacks)
      assert length(access_result.callbacks) > 0

      assert "fetch/2" in access_result.callbacks
    end


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
