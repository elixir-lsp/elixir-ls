defmodule ElixirLS.LanguageServer.Providers.CallHierarchyTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.CallHierarchy
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.LanguageServer.Build
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder
  require ElixirLS.Test.TextLoc

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
    test "prepares call hierarchy for a function" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      uri = SourceFile.Path.to_uri(file_path)

      {line, char} = {1, 8}

      ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        def function_a do
              ^
      """)

      {line, char} =
        SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

      result = CallHierarchy.prepare(parser_context, uri, line, char, File.cwd!())

      assert [item] = result
      assert item.name =~ "function_a"
      assert item.kind == GenLSP.Enumerations.SymbolKind.function()
      assert item.uri == uri
    end

    test "returns nil for non-function positions" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      uri = SourceFile.Path.to_uri(file_path)

      # Position on a variable
      {line, char} = {2, 4}

      ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
          result = :ok
          ^
      """)

      {line, char} =
        SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

      result = CallHierarchy.prepare(parser_context, uri, line, char, File.cwd!())

      assert result == nil
    end

    test "prepares call hierarchy for a function with arity" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      uri = SourceFile.Path.to_uri(file_path)

      {line, char} = {12, 6}

      ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        def function_with_arg(arg) do
            ^
      """)

      {line, char} =
        SourceFile.lsp_position_to_elixir(parser_context.source_file.text, {line, char})

      result = CallHierarchy.prepare(parser_context, uri, line, char, File.cwd!())

      assert [item] = result
      assert item.name =~ "function_with_arg"
      assert item.kind == GenLSP.Enumerations.SymbolKind.function()
    end
  end

  describe "incoming_calls/8" do
    test "finds all incoming calls including from other modules" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      source_file = parser_context.source_file
      uri = SourceFile.Path.to_uri(file_path)

      result =
        CallHierarchy.incoming_calls(
          uri,
          "ElixirLS.Test.CallHierarchyA.function_a/0",
          :function,
          2,
          2,
          File.cwd!(),
          source_file,
          parser_context
        )

      # function_a is called by:
      # - calls_function_a and another_caller in the same module
      # - CallHierarchyB.another_function_in_b
      # - CallHierarchyC.start_chain
      assert length(result) == 4

      caller_names = result |> Enum.map(& &1.from.name) |> Enum.sort()
      assert "ElixirLS.Test.CallHierarchyA.another_caller/0" in caller_names
      assert "ElixirLS.Test.CallHierarchyA.calls_function_a/0" in caller_names
      assert "ElixirLS.Test.CallHierarchyB.another_function_in_b/0" in caller_names
      assert "ElixirLS.Test.CallHierarchyC.start_chain/0" in caller_names
    end

    test "finds remote calls from other modules" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      source_file = parser_context.source_file
      uri = SourceFile.Path.to_uri(file_path)

      result =
        CallHierarchy.incoming_calls(
          uri,
          "ElixirLS.Test.CallHierarchyA.called_from_other_modules/0",
          :function,
          28,
          2,
          File.cwd!(),
          source_file,
          parser_context
        )

      # This function is called from CallHierarchyB and CallHierarchyC
      assert length(result) >= 2

      caller_names = result |> Enum.map(& &1.from.name)
      assert Enum.any?(caller_names, &String.contains?(&1, "CallHierarchyB"))
      assert Enum.any?(caller_names, &String.contains?(&1, "CallHierarchyC"))
    end

    test "handles functions with arity" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      source_file = parser_context.source_file
      uri = SourceFile.Path.to_uri(file_path)

      result =
        CallHierarchy.incoming_calls(
          uri,
          "ElixirLS.Test.CallHierarchyA.function_with_arg/1",
          :function,
          13,
          2,
          File.cwd!(),
          source_file,
          parser_context
        )

      # function_with_arg is called by function_b
      assert length(result) >= 1

      caller_names = result |> Enum.map(& &1.from.name)
      assert Enum.any?(caller_names, &String.contains?(&1, "function_b"))
    end
  end

  describe "outgoing_calls/8" do
    test "finds local calls within a function" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      source_file = parser_context.source_file
      uri = SourceFile.Path.to_uri(file_path)

      result =
        CallHierarchy.outgoing_calls(
          uri,
          "ElixirLS.Test.CallHierarchyA.function_a/0",
          :function,
          2,
          2,
          File.cwd!(),
          source_file,
          parser_context
        )

      # function_a calls function_b
      assert length(result) == 1
      assert List.first(result).to.name == "ElixirLS.Test.CallHierarchyA.function_b/0"
    end

    test "finds remote calls to other modules" do
      file_path = FixtureHelpers.get_path("call_hierarchy_a.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      source_file = parser_context.source_file
      uri = SourceFile.Path.to_uri(file_path)

      result =
        CallHierarchy.outgoing_calls(
          uri,
          "ElixirLS.Test.CallHierarchyA.function_b/0",
          :function,
          8,
          2,
          File.cwd!(),
          source_file,
          parser_context
        )

      # function_b calls CallHierarchyB.function_in_b and function_with_arg
      assert length(result) == 2

      callee_names = result |> Enum.map(& &1.to.name) |> Enum.sort()
      assert Enum.any?(callee_names, &String.contains?(&1, "function_in_b"))
      assert Enum.any?(callee_names, &String.contains?(&1, "function_with_arg"))
    end

    test "finds multiple calls to the same function" do
      file_path = FixtureHelpers.get_path("call_hierarchy_b.ex")
      parser_context = ParserContextBuilder.from_path(file_path)
      source_file = parser_context.source_file
      uri = SourceFile.Path.to_uri(file_path)

      result =
        CallHierarchy.outgoing_calls(
          uri,
          "ElixirLS.Test.CallHierarchyB.another_function_in_b/0",
          :function,
          10,
          2,
          File.cwd!(),
          source_file,
          parser_context
        )

      # another_function_in_b calls function_a twice and multi_clause_fun once
      callees = result |> Enum.map(& &1.to.name)
      assert Enum.any?(callees, &String.contains?(&1, "function_a"))
      assert Enum.any?(callees, &String.contains?(&1, "multi_clause_fun"))

      # Check that we have multiple ranges for function_a
      function_a_call = Enum.find(result, &String.contains?(&1.to.name, "function_a"))
      assert length(function_a_call.from_ranges) == 2
    end
  end
end
