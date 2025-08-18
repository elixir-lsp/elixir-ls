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
      assert atom_result
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

      if Version.match?(System.version(), ">= 1.18.0") do
        # Check Protocol module
        protocol_result = Enum.find(result.results, &(&1.module == "Protocol"))
        assert protocol_result
        assert is_list(protocol_result.macrocallbacks)
        assert length(protocol_result.macrocallbacks) > 0

        assert "__deriving__/2" in protocol_result.macrocallbacks
      end
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
      string_result = Enum.find(result.results, &(&1.module == "String"))
      assert string_result
      assert string_result.module == "String"
      assert string_result.moduledoc
      assert is_list(string_result.functions)
      assert length(string_result.functions) > 0

      # Check Enum module
      enum_result = Enum.find(result.results, &(&1.module == "Enum"))
      assert enum_result
      assert enum_result.module == "Enum"
      assert enum_result.moduledoc
      assert is_list(enum_result.functions)
      assert length(enum_result.functions) > 0
    end

    test "handles function documentation with arity" do
      modules = ["String.split/1"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
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

    if Version.match?(System.version(), ">= 1.15.0") do
      test "handles type documentation with arity" do
        modules = ["Enumerable.t/0"]

        assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

        assert Map.has_key?(result, :results)
        assert length(result.results) == 1

        result = hd(result.results)
        assert result.module == "Enumerable"
        assert result.type == "t"
        assert result.arity == 0
        assert result.documentation =~ "All the types that implement this protocol"
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "handles type documentation without arity" do
        modules = ["Enumerable.t"]

        assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

        assert Map.has_key?(result, :results)
        assert length(result.results) == 2

        arity_0_result = result.results |> Enum.find(&(&1.arity == 0))
        assert arity_0_result.module == "Enumerable"
        assert arity_0_result.type == "t"
        assert arity_0_result.documentation =~ "All the types that implement this protocol"

        arity_1_result = result.results |> Enum.find(&(&1.arity == 1))
        assert arity_1_result.module == "Enumerable"
        assert arity_1_result.type == "t"
        assert arity_1_result.documentation =~ "An enumerable of elements of type `element`"
      end
    end

    test "handles callback documentation with arity" do
      modules = ["GenServer.handle_info/2"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      result = hd(result.results)
      assert result.module == "GenServer"
      assert result.callback == "handle_info"
      assert result.arity == 2
      assert result.documentation =~ "handle all other messages"
    end

    test "handles callback documentation without arity" do
      modules = ["GenServer.handle_info"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      result = result.results |> hd
      assert result.module == "GenServer"
      assert result.callback == "handle_info"
      assert result.documentation =~ "handle all other messages"
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

      assert Map.has_key?(result, :results)
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

    test "handles non existing module symbol gracefully" do
      modules = ["NonExisting.non_existing_function/1"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 0
    end

    test "handles non existing function symbol gracefully" do
      modules = ["String.non_existing_function/1"]

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

      module_name =
        "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDocsAggregatorTest.TestModuleWithoutDocs"

      modules = [module_name]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      test_result = hd(result.results)
      assert test_result.module == module_name
      # No documentation available
      assert test_result.moduledoc == nil
      assert test_result.functions == ["hello/0"]
    end

    test "includes metadata in documentation types" do
      # Test module metadata
      assert {:ok, result} =
               LlmDocsAggregator.execute([["ElixirSenseExample.ModuleWithDocs"]], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      module_result = hd(result.results)
      assert Map.has_key?(module_result, :moduledoc_metadata)
      # ModuleWithDocs has a @moduledoc since: "1.2.3" 
      assert is_binary(module_result.moduledoc_metadata)
      assert String.contains?(module_result.moduledoc_metadata, "Since")

      # Test function metadata
      assert {:ok, result} =
               LlmDocsAggregator.execute([["ElixirSenseExample.ModuleWithDocs.some_fun/2"]], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      function_result = hd(result.results)
      assert Map.has_key?(function_result, :documentation)
      # some_fun has @doc since: "1.1.0" so metadata should be included in formatted docs
      assert String.contains?(function_result.documentation, "Since")

      # Test type metadata (metadata is included in module aggregation, not individual type calls)
      assert {:ok, result} =
               LlmDocsAggregator.execute([["ElixirSenseExample.ModuleWithDocs.some_type/0"]], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      type_result = hd(result.results)
      # Individual type calls return documentation directly, metadata is preserved in module calls
      assert Map.has_key?(type_result, :documentation)
      assert String.contains?(type_result.documentation, "An example type")
    end

    test "handles macro documentation with specs" do
      modules = ["ElixirSenseExample.ModuleWithDocs.some_macro/2"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      macro_result = hd(result.results)
      assert macro_result.module == "ElixirSenseExample.ModuleWithDocs"
      assert macro_result.function == "some_macro"
      assert macro_result.arity == 2
      assert macro_result.documentation =~ "An example macro"

      # Check that metadata is included (since: "1.1.0")
      assert macro_result.documentation =~ "Since"
      assert macro_result.documentation =~ "1.1.0"
    end

    test "handles macro documentation without arity" do
      modules = ["ElixirSenseExample.ModuleWithDocs.some_macro"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      # Should find at least the some_macro/2 (from the fixture)
      assert length(result.results) >= 1

      macro_result = result.results |> Enum.find(&(&1.arity == 2))
      assert macro_result.module == "ElixirSenseExample.ModuleWithDocs"
      assert macro_result.function == "some_macro"
      assert macro_result.arity == 2
      assert macro_result.documentation =~ "An example macro"
    end

    test "handles macrocallback documentation with arity" do
      modules = ["ElixirSenseExample.ModuleWithDocs.some_macrocallback/1"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      macrocallback_result = hd(result.results)
      assert macrocallback_result.module == "ElixirSenseExample.ModuleWithDocs"
      assert macrocallback_result.callback == "some_macrocallback"
      assert macrocallback_result.arity == 1
      assert macrocallback_result.documentation =~ "An example callback"

      # Check that we got the documentation (metadata may be formatted differently for callbacks)
      assert macrocallback_result.documentation
    end

    test "handles macrocallback documentation without arity" do
      modules = ["ElixirSenseExample.ModuleWithDocs.some_macrocallback"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) >= 1

      macrocallback_result = result.results |> Enum.find(&(&1.arity == 1))
      assert macrocallback_result.module == "ElixirSenseExample.ModuleWithDocs"
      assert macrocallback_result.callback == "some_macrocallback"
      assert macrocallback_result.arity == 1
      assert macrocallback_result.documentation =~ "An example callback"
    end

    test "verifies macro and macrocallback specs are included" do
      # Test callback spec
      assert {:ok, result} =
               LlmDocsAggregator.execute(
                 [["ElixirSenseExample.ModuleWithDocs.some_callback/1"]],
                 %{}
               )

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      callback_result = hd(result.results)
      assert Map.has_key?(callback_result, :spec)
      assert Map.has_key?(callback_result, :kind)
      assert Map.has_key?(callback_result, :metadata)
      assert callback_result.spec == "@callback some_callback(integer()) :: atom()"
      assert callback_result.kind == :callback
      assert String.contains?(callback_result.metadata, "Since")
      assert String.contains?(callback_result.metadata, "1.1.0")

      # Test macrocallback spec  
      assert {:ok, result} =
               LlmDocsAggregator.execute(
                 [["ElixirSenseExample.ModuleWithDocs.some_macrocallback/1"]],
                 %{}
               )

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      macrocallback_result = hd(result.results)
      assert Map.has_key?(macrocallback_result, :spec)
      assert Map.has_key?(macrocallback_result, :kind)
      assert Map.has_key?(macrocallback_result, :metadata)
      assert macrocallback_result.spec == "@macrocallback some_macrocallback(integer()) :: atom()"
      assert macrocallback_result.kind == :macrocallback
      assert String.contains?(macrocallback_result.metadata, "Since")
      assert String.contains?(macrocallback_result.metadata, "1.1.0")
    end

    test "verifies function documentation contains specs" do
      # Test with ElixirSenseExample.ModuleWithDocs.some_fun/2 which has a @spec
      modules = ["ElixirSenseExample.ModuleWithDocs.some_fun/2"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      func_result = hd(result.results)
      assert func_result.module == "ElixirSenseExample.ModuleWithDocs"
      assert func_result.function == "some_fun"
      assert func_result.arity == 2
      assert func_result.documentation =~ "An example fun"

      # Verify that specs are included in the documentation
      assert func_result.documentation =~ "**Specs:**"
      assert func_result.documentation =~ "@spec some_fun"
      assert func_result.documentation =~ "```elixir"
      assert func_result.documentation =~ "integer()"
    end

    test "verifies macro documentation contains specs" do
      # Test with ElixirSenseExample.ModuleWithDocs.some_macro/2 which has a @spec
      modules = ["ElixirSenseExample.ModuleWithDocs.some_macro/2"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      macro_result = hd(result.results)
      assert macro_result.module == "ElixirSenseExample.ModuleWithDocs"
      assert macro_result.function == "some_macro"
      assert macro_result.arity == 2
      assert macro_result.documentation =~ "An example macro"

      # Verify that specs are included in the macro documentation
      assert macro_result.documentation =~ "**Specs:**"
      assert macro_result.documentation =~ "@spec some_macro"
      assert macro_result.documentation =~ "```elixir"
      assert macro_result.documentation =~ "Macro.t()"
    end

    test "verifies function specs are properly formatted" do
      # Test function without arity to get all arities
      modules = ["ElixirSenseExample.ModuleWithDocs.some_fun"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) >= 1

      # Find the result with arity 2 (which has specs)
      func_result = Enum.find(result.results, &(&1.arity == 2))
      assert func_result

      # Verify spec formatting
      assert func_result.documentation =~ "**Specs:**"
      assert func_result.documentation =~ "```elixir"

      assert func_result.documentation =~
               "@spec some_fun(integer(), integer() | nil) :: integer()"
    end

    test "verifies macro specs are properly formatted" do
      # Test macro without arity to get all arities
      modules = ["ElixirSenseExample.ModuleWithDocs.some_macro"]

      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})

      assert Map.has_key?(result, :results)
      assert length(result.results) >= 1

      # Find the result with arity 2 (which has specs)
      macro_result = Enum.find(result.results, &(&1.arity == 2))
      assert macro_result

      # Verify spec formatting for macro
      assert macro_result.documentation =~ "**Specs:**"
      assert macro_result.documentation =~ "```elixir"

      assert macro_result.documentation =~
               "@spec some_macro(Macro.t(), Macro.t() | nil) :: Macro.t()"
    end

    test "handles builtin types with various arities" do
      # Test builtin type without arity - returns all matching types
      modules = ["list"]
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      assert Map.has_key?(result, :results)
      assert length(result.results) == 2

      # Should get both list() and list/1
      list_result = Enum.find(result.results, &(&1.type == "list()"))
      assert list_result
      assert list_result.documentation == "A list"

      list1_result = Enum.find(result.results, &(&1.type == "list/1"))
      assert list1_result
      assert list1_result.documentation == "Proper list ([]-terminated)"

      # Test builtin type with arity 0
      modules = ["list/0"]
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      list0_result = hd(result.results)
      assert list0_result.type == "list()"
      assert list0_result.documentation == "A list"

      # Test builtin type with arity 1
      modules = ["list/1"]
      assert {:ok, result} = LlmDocsAggregator.execute([modules], %{})
      assert Map.has_key?(result, :results)
      assert length(result.results) == 1

      list1_single = hd(result.results)
      assert list1_single.type == "list/1"
      assert list1_single.documentation == "Proper list ([]-terminated)"
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
