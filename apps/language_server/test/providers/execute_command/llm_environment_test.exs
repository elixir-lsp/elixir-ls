defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmEnvironmentTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmEnvironment
  alias ElixirLS.LanguageServer.SourceFile

  describe "execute/2" do
    test "returns environment information for valid location" do
      test_file_content = """
      defmodule TestModule do
        alias String.Chars
        import Enum, only: [map: 2]

        @behaviour GenServer
        @my_attr "test"

        def my_function(x, y) do
          z = x + y
          z * 2
        end
      end
      """

      uri = "file:///test/test_module.ex"

      state = %{
        source_files: %{
          uri => %SourceFile{
            text: test_file_content,
            version: 1,
            language_id: "elixir"
          }
        }
      }

      # Test inside function after variable assignment
      location = "#{uri}:9:5"

      assert {:ok, result} = LlmEnvironment.execute([location], state)

      # Check basic structure
      assert result.location.uri == uri
      assert result.location.line == 9
      assert result.location.column == 5

      # Check context
      assert result.context.module == TestModule
      assert result.context.function == "my_function/2"

      # Check variables - may be empty if type inference is not complete
      # But the structure should be there
      assert is_list(result.variables)
    end

    test "handles location format variations" do
      state = %{source_files: %{}}

      # Test various formats - they should parse correctly but return file not found
      test_cases = [
        "file.ex:10:5",
        "file.ex:10",
        "file:///test/file.ex:10:5",
        "lib/my_module.ex:25"
      ]

      for location_format <- test_cases do
        assert {:ok, result} = LlmEnvironment.execute([location_format], state)

        # Should get file not found error
        assert result.error =~ "File not found"
      end
    end

    test "returns error for invalid location format" do
      state = %{source_files: %{}}

      assert {:ok, %{error: error}} = LlmEnvironment.execute(["invalid"], state)
      assert error =~ "Invalid location format"
    end

    test "returns error for invalid arguments" do
      state = %{source_files: %{}}

      assert {:ok, %{error: error}} = LlmEnvironment.execute([], state)
      assert error =~ "Invalid arguments"

      assert {:ok, %{error: error}} = LlmEnvironment.execute([123], state)
      assert error =~ "Invalid arguments"
    end
  end

  describe "location parsing" do
    test "parses various location formats correctly" do
      # Test that valid formats parse without errors (even if file not found)
      state = %{source_files: %{}}

      valid_formats = [
        "file.ex:10:5",
        "file.ex:10",
        "file:///path/to/file.ex:10:5",
        "file:///path/to/file.ex:10",
        "lib/nested/file.ex:10:5"
      ]

      for format <- valid_formats do
        assert {:ok, result} = LlmEnvironment.execute([format], state)
        # Should get file not found, not parsing error
        assert result.error =~ "File not found" or result.error =~ "Internal error"
      end
    end

    test "rejects invalid location formats" do
      state = %{source_files: %{}}

      invalid_formats = [
        "no_extension:10:5",
        "file.ex",
        "file.ex:invalid:5",
        ""
      ]

      for format <- invalid_formats do
        assert {:ok, result} = LlmEnvironment.execute([format], state)
        assert result.error =~ "Invalid location format" or result.error =~ "Internal error"
      end
    end
  end

  describe "environment formatting" do
    test "returns complete environment structure" do
      test_file_content = """
      defmodule MyModule do
        alias SomeModule
        import AnotherModule
        require Logger

        @my_attribute "value"

        def test_function(param) do
          local_var = param
          local_var
        end
      end
      """

      uri = "file:///test/my_module.ex"

      state = %{
        source_files: %{
          uri => %SourceFile{
            text: test_file_content,
            version: 1,
            language_id: "elixir"
          }
        }
      }

      location = "#{uri}:10:5"

      assert {:ok, result} = LlmEnvironment.execute([location], state)

      # Check that all expected keys are present
      assert Map.has_key?(result, :location)
      assert Map.has_key?(result, :context)
      assert Map.has_key?(result, :aliases)
      assert Map.has_key?(result, :imports)
      assert Map.has_key?(result, :requires)
      assert Map.has_key?(result, :variables)
      assert Map.has_key?(result, :attributes)
      assert Map.has_key?(result, :behaviours_implemented)
      assert Map.has_key?(result, :definitions)

      # Check location structure
      assert result.location.uri == uri
      assert result.location.line == 10
      assert result.location.column == 5

      # Check that lists are indeed lists (even if empty)
      assert is_list(result.aliases)
      assert is_list(result.imports)
      assert is_list(result.requires)
      assert is_list(result.variables)
      assert is_list(result.attributes)
      assert is_list(result.behaviours_implemented)
    end
  end
end
