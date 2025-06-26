defmodule ElixirLS.LanguageServer.Providers.CallHierarchy.LocatorTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.CallHierarchy.Locator
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.LanguageServer.Build
  alias ElixirSense.Core.Parser

  setup_all context do
    {:ok, pid} = Tracer.start_link([])
    project_path = FixtureHelpers.get_path("")

    Tracer.notify_settings_stored(project_path)

    compiler_options = Code.compiler_options()
    Build.set_compiler_options(ignore_module_conflict: true)

    on_exit(fn ->
      Code.compiler_options(compiler_options)
      Process.monitor(pid)

      GenServer.stop(pid)

      receive do
        {:DOWN, _, _, _, _} -> :ok
      end
    end)

    Code.compile_file(FixtureHelpers.get_path("call_hierarchy_a.ex"))
    Code.compile_file(FixtureHelpers.get_path("call_hierarchy_b.ex"))
    Code.compile_file(FixtureHelpers.get_path("call_hierarchy_c.ex"))
    {:ok, context}
  end

  describe "prepare/5" do
    test "finds function at cursor position" do
      code = """
      defmodule TestModule do
        def test_function do
          :ok
        end
      end
      """

      trace = Tracer.get_trace()

      # Position on "test_function"
      result = Locator.prepare(code, 2, 6, trace)

      assert result != nil
      assert result.name =~ "test_function"
      assert result.kind == GenLSP.Enumerations.SymbolKind.function()
    end

    test "returns nil for variable at cursor" do
      code = """
      defmodule TestModule do
        def test_function do
          variable = 42
          variable
        end
      end
      """

      trace = Tracer.get_trace()

      # Position on "variable"
      result = Locator.prepare(code, 3, 4, trace)

      assert result == nil
    end

    test "returns nil for attribute at cursor" do
      code = """
      defmodule TestModule do
        @attribute "value"
        
        def test_function do
          @attribute
        end
      end
      """

      trace = Tracer.get_trace()

      # Position on "@attribute"
      result = Locator.prepare(code, 5, 4, trace)

      assert result == nil
    end

    test "finds function with metadata" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      {:ok, code} = File.read(file_path)

      # Parse with metadata
      metadata = Parser.parse_string(code, true, false, {2, 6})
      trace = Tracer.get_trace()

      # Position on "function_a"
      result = Locator.prepare(code, 2, 6, trace, metadata: metadata)

      assert result != nil
      assert result.name =~ "function_a"
      assert result.kind == GenLSP.Enumerations.SymbolKind.function()
    end

    test "returns nil for remote function calls" do
      code = """
      defmodule TestModule do
        def test_function do
          OtherModule.remote_function()
        end
      end
      """

      trace = Tracer.get_trace()

      # Position on "remote_function" - this is a call, not a definition
      result = Locator.prepare(code, 3, 17, trace)

      # Should return nil for function calls (prepare only works on definitions)
      assert result == nil
    end

    test "returns nil for aliased module calls" do
      code = """
      defmodule TestModule do
        alias Some.Long.Module
        
        def test_function do
          Module.function_call()
        end
      end
      """

      trace = Tracer.get_trace()

      # Position on "function_call" - this is a call, not a definition
      result = Locator.prepare(code, 5, 11, trace)

      # Should return nil for function calls (prepare only works on definitions)
      assert result == nil
    end

    test "finds function with arity when on definition" do
      code = """
      defmodule TestModule do
        def test_function(arg1, arg2) do
          :ok
        end
        
        def caller do
          test_function(1, 2)
        end
      end
      """

      trace = Tracer.get_trace()
      metadata = Parser.parse_string(code, true, false, {2, 6})

      # Position on "test_function" in the definition
      result = Locator.prepare(code, 2, 6, trace, metadata: metadata)

      assert result != nil
      assert result.name =~ "test_function"
      # Should show arity 2
      assert result.name =~ "/2"
    end
  end

  describe "incoming_calls/5" do
    test "finds calls in metadata" do
      code = """
      defmodule TestModule do
        def test_function do
          :ok
        end
        
        def caller1 do
          test_function()
        end
        
        def caller2 do
          test_function()
          test_function()
        end
      end
      """

      metadata = Parser.parse_string(code, true, false, {2, 6})
      trace = Tracer.get_trace()

      result =
        Locator.incoming_calls("TestModule.test_function/0", :function, {2, 2}, trace,
          metadata: metadata
        )

      # Should find calls from caller1 and caller2
      assert length(result) == 2

      caller_names = result |> Enum.map(& &1.from.name) |> Enum.sort()
      assert "TestModule.caller1/0" in caller_names
      assert "TestModule.caller2/0" in caller_names

      # caller2 should have 2 call locations
      caller2 = Enum.find(result, &(&1.from.name == "TestModule.caller2/0"))
      assert length(caller2.from_ranges) == 2
    end

    test "finds remote calls in trace" do
      # First compile some modules with tracer
      trace = Tracer.get_trace()

      # The fixture files already have cross-module calls
      result =
        Locator.incoming_calls(
          "ElixirLS.Test.CallHierarchyA.called_from_other_modules/0",
          :function,
          {28, 2},
          trace
        )

      # Should find calls from other modules via tracer
      assert length(result) >= 1
    end
  end

  describe "outgoing_calls/5" do
    test "finds calls made by a function" do
      code = """
      defmodule TestModule do
        def test_function do
          helper1()
          helper2()
          OtherModule.remote_call()
        end
        
        def helper1, do: :ok
        def helper2, do: :ok
      end
      """

      metadata = Parser.parse_string(code, true, false, {2, 6})
      trace = Tracer.get_trace()

      result =
        Locator.outgoing_calls("TestModule.test_function/0", :function, {2, 2}, trace,
          metadata: metadata
        )

      # Should find calls to helper1, helper2, and remote_call
      assert length(result) == 3

      callee_names = result |> Enum.map(& &1.to.name)
      assert "TestModule.helper1/0" in callee_names
      assert "TestModule.helper2/0" in callee_names
      assert Enum.any?(callee_names, &String.contains?(&1, "remote_call"))
    end

    test "handles multiple calls to same function" do
      code = """
      defmodule TestModule do
        def test_function do
          helper()
          helper()
          helper()
        end
        
        def helper, do: :ok
      end
      """

      metadata = Parser.parse_string(code, true, false, {2, 6})
      trace = Tracer.get_trace()

      result =
        Locator.outgoing_calls("TestModule.test_function/0", :function, {2, 2}, trace,
          metadata: metadata
        )

      # Should find one callee with three call locations
      assert length(result) == 1
      assert List.first(result).to.name == "TestModule.helper/0"
      assert length(List.first(result).from_ranges) == 3
    end
  end
end
