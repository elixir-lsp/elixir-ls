defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.GetEnvironmentTest do
  use ExUnit.Case
  
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.GetEnvironment
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
      
      # Test inside function
      location = "#{uri}:9:5"
      
      assert {:ok, result} = GetEnvironment.execute([location], state)
      
      # Check basic structure
      assert result.location.uri == uri
      assert result.location.line == 9
      assert result.location.column == 5
      
      # Check context
      assert result.context.module == TestModule
      assert result.context.function == "my_function/2"
      
      # Check variables
      var_names = Enum.map(result.variables, & &1.name)
      assert "x" in var_names
      assert "y" in var_names
      assert "z" in var_names
    end
    
    test "handles location format variations" do
      uri = "file:///test/file.ex"
      state = %{source_files: %{}}
      
      # Test various formats
      test_cases = [
        {"file.ex:10:5", "/file.ex", 10, 5},
        {"file.ex:10", "/file.ex", 10, 1},
        {"#{uri}:10:5", uri, 10, 5},
        {"lib/my_module.ex:25", "/lib/my_module.ex", 25, 1}
      ]
      
      for {input, expected_path_end, expected_line, expected_column} <- test_cases do
        assert {:ok, result} = GetEnvironment.execute([input], state)
        
        # Will get file not found, but check parsing worked
        assert result.error =~ "File not found"
        assert result.error =~ expected_path_end
      end
    end
    
    test "returns error for invalid location format" do
      state = %{source_files: %{}}
      
      assert {:ok, %{error: error}} = GetEnvironment.execute(["invalid"], state)
      assert error =~ "Invalid location format"
    end
    
    test "returns error for invalid arguments" do
      state = %{source_files: %{}}
      
      assert {:ok, %{error: error}} = GetEnvironment.execute([], state)
      assert error =~ "Invalid arguments"
      
      assert {:ok, %{error: error}} = GetEnvironment.execute([123], state)
      assert error =~ "Invalid arguments"
    end
  end
  
  describe "parse_location/1" do
    test "parses various location formats correctly" do
      # Note: This is a private function, so we test it indirectly through execute
      state = %{source_files: %{}}
      
      # Should parse successfully (even if file not found)
      valid_formats = [
        "file.ex:10:5",
        "file.ex:10",
        "file:///path/to/file.ex:10:5",
        "file:///path/to/file.ex:10",
        "lib/nested/file.ex:10:5"
      ]
      
      for format <- valid_formats do
        assert {:ok, result} = GetEnvironment.execute([format], state)
        # Should get file not found, not parsing error
        assert result.error =~ "File not found" or result.error =~ "Internal error"
      end
    end
  end
end