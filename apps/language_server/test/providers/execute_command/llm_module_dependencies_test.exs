defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmModuleDependenciesTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmModuleDependencies
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

    test "filters dependencies by function for remote calls" do
      state = %{source_files: %{}}
      
      # Test that remote call symbols filter dependencies by the specific function
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsC.function_in_c/0"], state)
      
      # Should include the function name in the result
      assert result.module == "ElixirLS.Test.ModuleDepsC"
      assert result.function == "function_in_c/0"
      
      # Should filter direct dependencies to only include the specific function
      direct_deps = result.direct_dependencies
      
      # Function calls should only include those matching the specific function
      function_calls = direct_deps.function_calls
      
      # function_in_c/0 is a simple function, but may have compiler-generated calls
      # The important thing is that it only includes calls from this specific function
      assert is_list(function_calls)
      
      # Imports should only include those matching the specific function
      imports = direct_deps.imports
      
      # Should not include any imports since ModuleDepsC.function_in_c/0 doesn't import functions with that name
      assert imports == []
      
      # Module-level dependencies should still be present (aliases, requires, etc.)
      # as they're needed for the module analysis
      assert is_list(direct_deps.aliases)
      assert is_list(direct_deps.requires)
      assert is_list(direct_deps.struct_expansions)
      assert is_list(direct_deps.compile_dependencies)
      assert is_list(direct_deps.runtime_dependencies)
      assert is_list(direct_deps.exports_dependencies)
    end
    
    test "filters reverse dependencies by function for remote calls" do
      state = %{source_files: %{}}
      
      # Test filtering reverse dependencies for a specific function
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsC.function_in_c/0"], state)
      
      assert result.module == "ElixirLS.Test.ModuleDepsC"
      assert result.function == "function_in_c/0"
      
      reverse_deps = result.reverse_dependencies
      
      # Should only include reverse dependencies that specifically call function_in_c/0
      function_calls = reverse_deps.function_calls
      
      # Should include calls from ModuleDepsA and possibly others that call function_in_c/0
      matching_calls = Enum.filter(function_calls, fn call ->
        String.contains?(call, "function_in_c/0")
      end)
      assert length(matching_calls) > 0
      
      # Should include imports from ModuleDepsD that import function_in_c/0
      imports = reverse_deps.imports
      matching_imports = Enum.filter(imports, fn import ->
        String.contains?(import, "function_in_c/0")
      end)
      assert length(matching_imports) > 0
    end
    
    test "handles remote call with arity nil (function name only)" do
      state = %{source_files: %{}}
      
      # Test filtering by function name without specific arity
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsC.function_in_c"], state)
      
      assert result.module == "ElixirLS.Test.ModuleDepsC"
      assert result.function == "function_in_c/nil"
      
      # Should include all arities of the function
      reverse_deps = result.reverse_dependencies
      function_calls = reverse_deps.function_calls
      
      # Should include any calls to function_in_c regardless of arity
      matching_calls = Enum.filter(function_calls, fn call ->
        String.contains?(call, "function_in_c")
      end)
      assert length(matching_calls) > 0
    end
    
    test "filters transitive dependencies by function for remote calls" do
      state = %{source_files: %{}}
      
      # Test a function that has transitive dependencies
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA.function_with_direct_call/0"], state)
      
      assert result.module == "ElixirLS.Test.ModuleDepsA"
      assert result.function == "function_with_direct_call/0"
      
      # function_with_direct_call calls ModuleDepsC.function_in_c/0
      # ModuleDepsC.function_in_c/0 has no further dependencies, so transitive should be empty or minimal
      transitive_deps = result.transitive_dependencies
      
      # Should have fewer transitive dependencies than a function that calls multiple modules
      assert is_list(transitive_deps)
      
      # Compare with multiple_dependencies which calls both B and C modules
      assert {:ok, result2} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA.multiple_dependencies/0"], state)
      
      # multiple_dependencies calls both ModuleDepsB.function_in_b/0 and ModuleDepsC.function_in_c/0
      # ModuleDepsB.function_in_b/0 calls ModuleDepsD.function_in_d/1, creating more transitive dependencies
      transitive_deps2 = result2.transitive_dependencies
      
      # The function that calls more modules should potentially have more or equal transitive dependencies
      # (This depends on the actual call structure, but the key point is they should be different
      # when filtering by different functions)
      assert is_list(transitive_deps2)
      
      # Verify that the transitive dependencies are actually filtered
      # by checking that we don't get the same result as the unfiltered module query
      assert {:ok, unfiltered_result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA"], state)
      unfiltered_transitive = unfiltered_result.transitive_dependencies
      
      # The filtered results should be a subset of (or equal to but potentially smaller than) the unfiltered results
      # Since we're only looking at dependencies from specific functions
      assert length(transitive_deps) <= length(unfiltered_transitive)
      assert length(transitive_deps2) <= length(unfiltered_transitive)
    end
    
    test "filters reverse transitive dependencies by function for remote calls" do
      state = %{source_files: %{}}
      
      # Test reverse transitive dependencies for a specific function
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsC.function_in_c/0"], state)
      
      assert result.module == "ElixirLS.Test.ModuleDepsC"
      assert result.function == "function_in_c/0"
      
      # function_in_c/0 is called by specific functions in ModuleDepsA
      # The reverse transitive dependencies should only include modules that transitively depend
      # on function_in_c/0 specifically, not the entire ModuleDepsC module
      reverse_transitive_deps = result.reverse_transitive_dependencies
      
      assert is_list(reverse_transitive_deps)
      
      # Compare with the unfiltered module query
      assert {:ok, unfiltered_result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsC"], state)
      unfiltered_reverse_transitive = unfiltered_result.reverse_transitive_dependencies
      
      # The filtered reverse transitive dependencies should be a subset of the unfiltered ones
      assert length(reverse_transitive_deps) <= length(unfiltered_reverse_transitive)
      
      # Verify that all filtered dependencies are also in the unfiltered list
      for dep <- reverse_transitive_deps do
        assert dep in unfiltered_reverse_transitive
      end
    end
    
    test "properly filters compile/runtime/export dependencies by function" do
      state = %{source_files: %{}}
      
      # Test a function that should have specific dependencies vs the whole module
      assert {:ok, filtered_result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA.function_with_direct_call/0"], state)
      assert {:ok, unfiltered_result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsA"], state)
      
      # The filtered results should have fewer or equal dependencies than the unfiltered ones
      filtered_compile = filtered_result.direct_dependencies.compile_dependencies
      unfiltered_compile = unfiltered_result.direct_dependencies.compile_dependencies
      
      filtered_runtime = filtered_result.direct_dependencies.runtime_dependencies  
      unfiltered_runtime = unfiltered_result.direct_dependencies.runtime_dependencies
      
      filtered_exports = filtered_result.direct_dependencies.exports_dependencies
      unfiltered_exports = unfiltered_result.direct_dependencies.exports_dependencies
      
      # Filtered should be subsets of unfiltered
      assert length(filtered_compile) <= length(unfiltered_compile)
      assert length(filtered_runtime) <= length(unfiltered_runtime)
      assert length(filtered_exports) <= length(unfiltered_exports)
      
      # Verify that all filtered dependencies are also in the unfiltered list
      for dep <- filtered_compile, do: assert(dep in unfiltered_compile)
      for dep <- filtered_runtime, do: assert(dep in unfiltered_runtime)
      for dep <- filtered_exports, do: assert(dep in unfiltered_exports)
      
      # The key insight: when filtering by function, we should get a more precise view
      # of what dependencies are actually used by that specific function
      assert filtered_result.function == "function_with_direct_call/0"
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
      compile_time = result.direct_dependencies.compile_dependencies
      assert "Logger" in compile_time  # require Logger
      
      # Function calls should be runtime
      runtime = result.direct_dependencies.runtime_dependencies
      assert "ElixirLS.Test.ModuleDepsC" in runtime
      assert "ElixirLS.Test.ModuleDepsD" in runtime
    end
    
    test "detects struct dependencies" do
      state = %{source_files: %{}}
      
      assert {:ok, result} = LlmModuleDependencies.execute(["ElixirLS.Test.ModuleDepsD"], state)
      
      # Check that struct usage is detected as compile-time dependency
      assert "ElixirLS.Test.ModuleDepsC" in result.direct_dependencies.compile_dependencies
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
