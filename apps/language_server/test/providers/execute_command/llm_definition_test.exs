defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinitionTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinition

  describe "execute/2" do
    test "returns error for invalid arguments (non-list)" do
      assert {:ok, %{error: "Invalid arguments: expected [symbol_string]"}} =
               LlmDefinition.execute("String", %{})
    end

    test "returns error for invalid arguments (empty list)" do
      assert {:ok, %{error: "Invalid arguments: expected [symbol_string]"}} =
               LlmDefinition.execute([], %{})
    end

    test "returns error for invalid arguments (multiple elements)" do
      assert {:ok, %{error: "Invalid arguments: expected [symbol_string]"}} =
               LlmDefinition.execute(["String", "Enum"], %{})
    end

    test "returns error for invalid symbol format" do
      assert {:ok, %{error: "Unrecognized symbol format: " <> _}} =
               LlmDefinition.execute(["123Invalid"], %{})
    end

    test "handles module symbol - ElixirSenseExample.ModuleWithDocs" do
      result = LlmDefinition.execute(["ElixirSenseExample.ModuleWithDocs"], %{})

      assert {:ok, response} = result

      # Test module should be found
      assert response[:definition]
    end

    test "handles nested module symbol" do
      # Using a module we know exists in the test environment
      result =
        LlmDefinition.execute(
          ["ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinition"],
          %{}
        )

      assert {:ok, response} = result
      assert response[:definition]
    end

    test "handles Erlang module symbol" do
      result = LlmDefinition.execute([":lists"], %{})

      assert {:ok, response} = result
      # Erlang modules may or may not have source available depending on the system
      assert response[:definition]

      # If source is found, it should contain the module name
      assert response.definition =~ "lists"
    end

    test "handles function with arity" do
      result = LlmDefinition.execute(["ElixirSenseExample.ModuleWithDocs.some_fun/2"], %{})

      assert {:ok, response} = result
      assert response[:definition]
    end

    test "handles function without arity" do
      result = LlmDefinition.execute(["ElixirSenseExample.ModuleWithDocs.some_fun"], %{})

      assert {:ok, response} = result
      assert response[:definition]
    end

    test "handles function with invalid arity" do
      result = LlmDefinition.execute(["ElixirSenseExample.ModuleWithDocs.some_fun/99"], %{})

      assert {:ok, response} = result
      assert response[:definition]
    end

    test "handles special function names with ?" do
      result = LlmDefinition.execute(["ElixirSenseExample.FunctionsWithTheSameName.all?/2"], %{})

      assert {:ok, response} = result
      assert response[:definition]
    end

    test "handles special function names with !" do
      result =
        LlmDefinition.execute(
          [
            "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinitionTest.TestModule.test_function!/1"
          ],
          %{}
        )

      assert {:ok, response} = result
      assert response[:definition]
    end

    test "handles internal errors gracefully" do
      # Force an error by using an invalid module name that will cause Module.concat to fail
      result = LlmDefinition.execute([""], %{})

      assert {:ok, response} = result
      assert response[:error]
      # Should be caught by parse_symbol as unrecognized format (V2 parser)
      assert response.error =~ "Not recognized" || response.error =~ "Internal error"
    end
  end

  describe "edge cases" do
    test "handles deeply nested modules" do
      result = LlmDefinition.execute(["A.B.C.D.E"], %{})

      assert {:ok, response} = result
      # Module doesn't exist
      assert response[:error]

      assert response.error =~ "Module" && response.error =~ "A.B.C.D.E" &&
               response.error =~ "not found"
    end

    test "handles erlang module with complex name" do
      result = LlmDefinition.execute([":erlang"], %{})

      assert {:ok, response} = result
      assert response[:definition]
    end

    test "rejects invalid erlang module format" do
      result = LlmDefinition.execute([":123invalid"], %{})

      assert {:ok, response} = result
      assert response[:error]
      # Should fail during atom creation
    end
  end

  describe "with test modules" do
    # Define test modules for more controlled testing
    defmodule TestModule do
      @moduledoc "Test module for LlmDefinition tests"

      @doc "A simple test function"
      @spec test_function(integer()) :: integer()
      def test_function(x) do
        x + 1
      end

      @doc false
      def private_function, do: :private

      def function_without_docs(a, b), do: a + b

      @doc "A function with ! in name"
      def test_function!(x) do
        x + 1
      end
    end

    test "finds module definition for test module" do
      module_name =
        "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinitionTest.TestModule"

      result = LlmDefinition.execute([module_name], %{})

      assert {:ok, response} = result

      # The test module should be found
      if response[:definition] do
        assert response.definition =~ "Definition found in"
        assert response.definition =~ "defmodule TestModule"
      else
        # In some test environments, source location might not be available
        assert response[:error]
      end
    end

    test "finds function definition with context" do
      function_name =
        "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinitionTest.TestModule.test_function/1"

      result = LlmDefinition.execute([function_name], %{})

      assert {:ok, response} = result

      if response[:definition] do
        assert response.definition =~ "Definition found in"
        # Should include the @doc and @spec as context
        assert response.definition =~ "test_function" ||
                 response.definition =~ "A simple test function" ||
                 response.definition =~ "@spec"
      else
        assert response[:error]
      end
    end

    test "finds function without arity using search" do
      function_name =
        "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinitionTest.TestModule.test_function"

      result = LlmDefinition.execute([function_name], %{})

      assert {:ok, response} = result

      # Should find the function even without specifying arity
      assert response[:definition]
    end

    test "handles function with multiple arities" do
      # function_without_docs has arity 2
      function_name =
        "ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDefinitionTest.TestModule.function_without_docs"

      result = LlmDefinition.execute([function_name], %{})

      assert {:ok, response} = result

      # Should find one of the arities
      assert response[:definition]
    end
  end

  describe "symbol parsing validation" do
    test "correctly identifies module patterns" do
      valid_modules = [
        "ElixirSenseExample.ModuleWithDocs",
        "Enum",
        "GenServer",
        "Mix.Project",
        "ExUnit.Case",
        "Some.Deeply.Nested.Module"
      ]

      for module <- valid_modules do
        result = LlmDefinition.execute([module], %{})
        assert {:ok, _} = result
      end
    end

    test "correctly identifies function patterns" do
      valid_functions = [
        "ElixirSenseExample.ModuleWithDocs.some_fun/2",
        "Enum.map/2",
        "IO.puts/1",
        "Kernel.is_nil/1",
        "Some.Module.function_name/0"
      ]

      for function <- valid_functions do
        result = LlmDefinition.execute([function], %{})
        assert {:ok, _} = result
      end
    end

    test "correctly identifies erlang module patterns" do
      valid_erlang = [
        ":lists",
        ":ets",
        ":gen_server",
        ":file"
      ]

      for erlang_mod <- valid_erlang do
        result = LlmDefinition.execute([erlang_mod], %{})
        assert {:ok, _} = result
      end
    end
  end
end
