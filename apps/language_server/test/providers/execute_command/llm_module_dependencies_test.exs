defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmModuleDependenciesTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmModuleDependencies
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.LanguageServer.Build

  setup_all context do
    {:ok, pid} = Tracer.start_link([])
    project_path = FixtureHelpers.get_path("")

    Tracer.notify_settings_stored(project_path)

    compiler_options = Code.compiler_options()
    Build.set_compiler_options(ignore_module_conflict: true, tracers: [Tracer])

    on_exit(fn ->
      Code.compiler_options(compiler_options)
      Process.monitor(pid)

      GenServer.stop(pid)

      receive do
        {:DOWN, _, _, _, _} -> :ok
      end
    end)

    # Compile test modules with the tracer enabled
    Code.compile_file(FixtureHelpers.get_path("module_deps_a.ex"))
    Code.compile_file(FixtureHelpers.get_path("module_deps_b.ex"))
    Code.compile_file(FixtureHelpers.get_path("module_deps_c.ex"))
    Code.compile_file(FixtureHelpers.get_path("module_deps_d.ex"))
    
    {:ok, context}
  end

  describe "execute/2" do
    test "returns direct dependencies for a module" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA"], state)
      
      assert result.module == "ElixirLS.Test.ModuleDepsA"

      direct_deps = result.direct_dependencies
      
      # Check imports
      assert "Enum.filter/2" in direct_deps.imports
      
      # Check aliases
      assert "ElixirLS.Test.ModuleDepsB" in direct_deps.aliases
      
      # Check requires
      assert "Logger" in direct_deps.requires
      
      # Check compile-time dependencies
      assert "Logger" in direct_deps.compile_dependencies
      assert "ElixirLS.Test.ModuleDepsB" in direct_deps.compile_dependencies
      
      # Check runtime dependencies
      assert "Enum" in direct_deps.runtime_dependencies
      assert "ElixirLS.Test.ModuleDepsC" in direct_deps.runtime_dependencies

      # Check exported dependencies
      assert "Logger" in direct_deps.exports_dependencies
      assert "Enum" in direct_deps.exports_dependencies
      assert "ElixirLS.Test.ModuleDepsC" in direct_deps.exports_dependencies

      # Check function calls
      assert "ElixirLS.Test.ModuleDepsC.function_in_c/0" in direct_deps.function_calls

      # Check struct expansions
      assert "ElixirLS.Test.ModuleDepsC" in direct_deps.struct_expansions
    end
    
    test "returns reverse dependencies" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsC"], state)
      
      assert result.module == "ElixirLS.Test.ModuleDepsC"

      reverse_deps = result.reverse_dependencies
      
      # Check imports
      assert "ElixirLS.Test.ModuleDepsD imports ElixirLS.Test.ModuleDepsC.function_in_c/0" in reverse_deps.imports
      
      # Check aliases
      assert "ElixirLS.Test.ModuleDepsD" in reverse_deps.aliases
      
      # Check requires
      assert "ElixirLS.Test.ModuleDepsD" in reverse_deps.requires
      
      # Check compile-time dependencies
      assert "ElixirLS.Test.ModuleDepsD" in reverse_deps.compile_dependencies
      
      # Check runtime dependencies
      assert "ElixirLS.Test.ModuleDepsA" in reverse_deps.runtime_dependencies

      # Check exported dependencies
      assert "ElixirLS.Test.ModuleDepsB" in reverse_deps.exports_dependencies

      # Check function calls
      assert "ElixirLS.Test.ModuleDepsA calls ElixirLS.Test.ModuleDepsC.function_in_c/0" in reverse_deps.function_calls

      # Check struct expansions
      assert "ElixirLS.Test.ModuleDepsB" in reverse_deps.struct_expansions
    end
    
    test "returns transitive compile dependencies" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA"], state)
      
      # ModuleDepsA compile depends on B and C
      # B depends on E
      # B, C are already in direct deps, E is transitive
      transitive = result.transitive_dependencies
      assert "ElixirLS.Test.ModuleDepsE" in transitive
      refute "ElixirLS.Test.ModuleDepsB" in transitive
      refute "ElixirLS.Test.ModuleDepsC" in transitive
      refute "ElixirLS.Test.ModuleDepsA" in transitive
    end

    test "returns reverse transitive compile dependencies" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsE"], state)
      
      # ModuleDepsA compile depends on B and C
      # B depends on E
      # B, C are already in direct deps, E is transitive
      transitive = result.reverse_transitive_dependencies
      assert "ElixirLS.Test.ModuleDepsA" in transitive
      refute "ElixirLS.Test.ModuleDepsB" in transitive
      refute "ElixirLS.Test.ModuleDepsC" in transitive
      refute "ElixirLS.Test.ModuleDepsE" in transitive
    end
    
    test "handles Erlang module names" do
      state = %{source_files: %{}}
      
      # Test with :erlang module
      assert {:ok, result} = LlmModuleDependencies.execute([":erlang"], state)
      assert result.module == ":erlang"
      
      # Should have reverse dependencies from modules using :erlang
      assert %{runtime_dependencies: reverse_modules} = result.reverse_dependencies
      assert length(reverse_modules) > 0
    end
    
    test "handles module name variations" do
      state = %{source_files: %{}}
      
      # Test different module name formats
      test_cases = [
        {"ElixirLS.Test.ModuleDepsA", "ElixirLS.Test.ModuleDepsA"},
        {"Elixir.ElixirLS.Test.ModuleDepsA", "ElixirLS.Test.ModuleDepsA"}
      ]
      
      for {input, expected} <- test_cases do
        assert {:ok, result} = LlmModuleDependencies.execute([input], state)
        assert result.module == expected
      end
    end

    test "handles remote call symbols by extracting module" do
      state = %{source_files: %{}}
      
      # Test that remote call symbols like "String.split/2" extract the module part correctly
      assert {:ok, result} = LlmModuleDependencies.execute(["String.split/2"], state)
      assert result.module == "String"
      
      # Test another remote call  
      assert {:ok, result} = LlmModuleDependencies.execute(["Enum.map/2"], state)
      assert result.module == "Enum"
      
      # Test erlang remote call
      assert {:ok, result} = LlmModuleDependencies.execute([":lists.append/2"], state)
      assert result.module == ":lists"
    end
    
    test "rejects unsupported symbol types" do
      state = %{source_files: %{}}
      
      # Test that local calls return an error
      assert {:ok, %{error: error}} = LlmModuleDependencies.execute(["my_function"], state)
      assert error =~ "Symbol type local_call is not supported"
      
      # Test that module attributes return an error
      assert {:ok, %{error: error}} = LlmModuleDependencies.execute(["@doc"], state)
      assert error =~ "Symbol type attribute is not supported"
    end
    
    test "handles non-existent module gracefully" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["NonExistentModule"], state)
      # V2 parser successfully parses this as a module name, so we get valid results
      # (but likely empty dependencies since the module doesn't exist in the trace)
      assert result.module == "NonExistentModule"
      assert is_map(result.direct_dependencies)
    end
    
    test "returns error for invalid arguments" do
      state = %{source_files: %{}}
      
      assert {:ok, %{error: error}} = LlmModuleDependencies.execute([], state)
      assert error =~ "Invalid arguments"
      
      assert {:ok, %{error: error}} = LlmModuleDependencies.execute([123], state)
      assert error =~ "Invalid arguments"
    end
    
    test "correctly identifies compile-time vs runtime dependencies" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsB"], state)
      
      # Macros and aliases should be compile-time
      compile_time = result.compile_time_dependencies
      assert "Logger" in compile_time  # require Logger
      
      # Function calls should be runtime
      runtime = result.runtime_dependencies
      assert "ElixirLS.Test.ModuleDepsC" in runtime
      assert "ElixirLS.Test.ModuleDepsD" in runtime
    end
    
    test "detects struct dependencies" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsD"], state)
      
      # Check that struct usage is detected as compile-time dependency
      assert "ElixirLS.Test.ModuleDepsC" in result.compile_time_dependencies
    end
    
    test "includes location when module is in source files" do
      # Create a mock state with source files
      uri = "file:///path/to/module_deps_a.ex"
      source_text = """
      defmodule ElixirLS.Test.ModuleDepsA do
        def test, do: :ok
      end
      """
      
      state = %{
        source_files: %{
          uri => %SourceFile{
            text: source_text,
            version: 1,
            language_id: "elixir"
          }
        }
      }
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA"], state)
      
      # Should include location information
      assert result.location
      assert result.location.uri == uri
    end
    
    test "formats function calls correctly" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA"], state)
      
      # Check that function calls are properly formatted
      assert is_list(result.direct_dependencies.function_calls)
      
      # Should include specific function calls
      function_calls = result.direct_dependencies.function_calls
      assert Enum.any?(function_calls, &String.contains?(&1, "function_in_b"))
      assert Enum.any?(function_calls, &String.contains?(&1, "function_in_c"))
    end
  end
end
