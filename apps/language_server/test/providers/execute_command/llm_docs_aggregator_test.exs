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
      modules = ["Macro", "Date"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 2

      # Check Macro module
      macro_result = Enum.find(result.results, &(&1.module == "Macro"))
      assert macro_result
      assert is_list(macro_result.types)
      assert length(macro_result.types) > 0

      assert "metadata/0" in macro_result.types

      # Check Date module
      date_result = Enum.find(result.results, &(&1.module == "Date"))
      assert date_result
      assert is_list(date_result.types)
      assert length(date_result.types) > 0

      assert "t/0" in date_result.types
    end

    test "gets module callback list" do
      modules = ["Access", "Protocol"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 2

      # Check Access module
      access_result = Enum.find(result.results, &(&1.module == "Access"))
      assert access_result
      assert is_list(access_result.callbacks)
      assert length(access_result.callbacks) > 0

      assert "fetch/2" in access_result.callbacks

      # Check Protocol module
      protocol_result = Enum.find(result.results, &(&1.module == "Protocol"))
      assert protocol_result
      assert is_list(protocol_result.macrocallbacks)
      assert length(protocol_result.macrocallbacks) > 0

      assert "__deriving__/2" in protocol_result.macrocallbacks
    end

    test "gets module behaviours" do
      modules = ["DynamicSupervisor"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      # Check DynamicSupervisor module
      dynamic_supervisor_result = Enum.find(result.results, &(&1.module == "DynamicSupervisor"))
      assert dynamic_supervisor_result
      assert is_list(dynamic_supervisor_result.behaviours)
      assert length(dynamic_supervisor_result.behaviours) > 0

      assert "GenServer" in dynamic_supervisor_result.behaviours
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
      modules = ["String.split/1"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result |> dbg, :results)
      assert length(result.results) == 1
      
      func_result = hd(result.results)

      assert func_result.module == "String"
      assert func_result.function == "split"
      assert func_result.arity == 1
      assert func_result.documentation =~ "Divides a string into substrings"

      assert func_result.documentation =~ "@spec split(t()) :: [t()]"
    end

    test "handles function documentation without arity" do
      modules = ["String.split"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 2
      
      arity_1_result = result.results |> Enum.find(&(&1.arity == 1))
      assert arity_1_result.module == "String"
      assert arity_1_result.function == "split"
      assert arity_1_result.arity == 1

      arity_3_result = result.results |> Enum.find(&(&1.arity == 3))
      assert arity_3_result.module == "String"
      assert arity_3_result.function == "split"
      assert arity_3_result.arity == 3
    end

    test "handles type documentation with arity" do
      modules = ["Enumerable.t/0"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results |> dbg) == 1

      func_result = hd(result.results)
      assert func_result.module == "Enumerable"
      assert func_result.type == "t"
      assert func_result.arity == 0
      assert func_result.documentation =~ "All the types that implement this protocol"

    end

    test "handles type documentation without arity" do
      modules = ["Enumerable.t"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results |> dbg) == 2

      arity_0_result = result.results |> Enum.find(&(&1.arity == 0))
      assert arity_0_result.module == "Enumerable"
      assert arity_0_result.type == "t"
      assert arity_0_result.documentation =~ "All the types that implement this protocol"

      arity_1_result = result.results |> Enum.find(&(&1.arity == 1))
      assert arity_1_result.module == "Enumerable"
      assert arity_1_result.type == "t"
      assert arity_1_result.documentation =~ "An enumerable of elements of type `element`"
    end

    test "handles attribute documentation" do
      modules = ["@moduledoc"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      doc = hd(result.results)
      assert doc.attribute == "@moduledoc"
      assert doc.documentation =~ "Provides documentation for the current module."
    end

    test "handles Kernel import" do
      modules = ["send/2"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result |> dbg, :results)
      assert length(result.results) == 1
      
      func_result = hd(result.results)

      assert func_result.module == "Kernel"
      assert func_result.function == "send"
      assert func_result.arity == 2
      assert func_result.documentation =~ "Sends a message to the given"

      assert func_result.documentation =~ "@spec send(dest :: Process.dest()"
    end

    test "handles builtin type documentation" do
      modules = ["binary"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      doc = hd(result.results)
      assert doc.type == "binary()"
      assert doc.documentation =~ "A blob of binary data"
    end

    test "handles Erlang module format" do
      modules = [":erlang"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1
      
      erlang_result = hd(result.results)
      assert erlang_result.module == ":erlang"
    end

    test "handles invalid symbol gracefully" do
      modules = [":::invalid:::"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 0
    end

    test "handles mix of valid and invalid modules" do
      modules = ["String", ":::invalid:::", "Enum"]
      
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      
      assert Map.has_key?(result, :results)
      assert length(result.results) == 2
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
      assert test_result.module == module_name
      assert test_result.moduledoc == nil  # No documentation available
      assert test_result.functions == ["hello/0"]
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
