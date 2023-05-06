defmodule ElixirLS.Experimental.Provider.Handlers.FindReferencesTest do
  alias ElixirLS.LanguageServer.Build
  alias LSP.Requests.FindReferences
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias LSP.Types
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Provider.Handlers
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  alias ElixirLS.LanguageServer.Tracer

  import LspProtocol
  import ElixirLS.Test.TextLoc, only: [annotate_assert: 4]
  require ElixirLS.Test.TextLoc
  use ExUnit.Case, async: false

  @fixtures_to_load [
    "references_referenced.ex",
    "references_imported.ex",
    "references_remote.ex",
    "uses_macro_a.ex",
    "macro_a.ex"
  ]

  setup_all do
    File.rm_rf!(FixtureHelpers.get_path(".elixir_ls/calls.dets"))
    {:ok, _} = start_supervised(Tracer)

    Tracer.set_project_dir(FixtureHelpers.get_path(""))

    compiler_options = Code.compiler_options()
    Build.set_compiler_options(ignore_module_conflict: true)

    on_exit(fn ->
      Code.compiler_options(compiler_options)
    end)

    names_to_paths =
      for file <- @fixtures_to_load,
          path = FixtureHelpers.get_path(file),
          into: %{} do
        Code.compile_file(path)
        {file, path}
      end

    {:ok, paths: names_to_paths}
  end

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  def request(file_path, line, char) do
    uri = Conversions.ensure_uri(file_path)

    params = [
      text_document: [uri: uri],
      position: [line: line, character: char]
    ]

    with {:ok, contents} <- File.read(file_path),
         :ok <- SourceFile.Store.open(uri, contents, 1),
         {:ok, _source_file} <- SourceFile.Store.fetch(uri),
         {:ok, req} <- build(FindReferences, params) do
      FindReferences.to_elixir(req)
    end
  end

  def handle(request) do
    Handlers.FindReferences.handle(request, Env.new())
  end

  test "finds local, remote and imported references to a function", ctx do
    line = 1
    char = 8
    file_path = ctx.paths["references_referenced.ex"]
    {:ok, request} = request(file_path, line, char)

    annotate_assert(file_path, line, char, """
      def referenced_fun do
            ^
    """)

    {:reply, %Responses.FindReferences{result: references}} = handle(request)

    assert length(references) == 3
    assert Enum.any?(references, &String.ends_with?(&1.uri, "references_remote.ex"))
    assert Enum.any?(references, &String.ends_with?(&1.uri, "references_imported.ex"))
    assert Enum.any?(references, &String.ends_with?(&1.uri, "references_referenced.ex"))
  end

  test "finds local, remote and imported references to a macro", ctx do
    line = 8
    char = 12

    file_path = ctx.paths["references_referenced.ex"]
    {:ok, request} = request(file_path, line, char)

    annotate_assert(file_path, line, char, """
      defmacro referenced_macro(clause, do: expression) do
                ^
    """)

    {:reply, %Responses.FindReferences{result: references}} = handle(request)

    assert length(references) == 3

    assert Enum.any?(references, &String.ends_with?(&1.uri, "references_remote.ex"))
    assert Enum.any?(references, &String.ends_with?(&1.uri, "references_imported.ex"))
    assert Enum.any?(references, &String.ends_with?(&1.uri, "references_referenced.ex"))
  end

  test "find a references to a macro generated function call", ctx do
    line = 6
    char = 13

    file_path = ctx.paths["uses_macro_a.ex"]

    annotate_assert(file_path, line, char, """
        macro_a_func()
                 ^
    """)

    {:ok, request} = request(file_path, line, char)
    uri = request.source_file.uri

    {:reply, %Responses.FindReferences{result: result}} = handle(request)

    assert [location] = result

    %Types.Location{
      range: %Types.Range{
        start: %Types.Position{character: 4, line: 6},
        end: %Types.Position{character: 16, line: 6}
      },
      uri: ^uri
    } = location
  end

  test "finds a references to a macro imported function call", ctx do
    line = 10
    char = 4

    file_path = ctx.paths["uses_macro_a.ex"]

    {:ok, request} = request(file_path, line, char)

    uri = request.source_file.uri

    annotate_assert(file_path, line, char, """
        macro_imported_fun()
        ^
    """)

    {:reply, %Responses.FindReferences{result: [reference]}} = handle(request)

    assert %Types.Location{
             range: %Types.Range{
               start: %Types.Position{line: 10, character: 4},
               end: %Types.Position{line: 10, character: 22}
             },
             uri: ^uri
           } = reference
  end

  test "finds references to a variable", ctx do
    line = 4
    char = 14
    file_path = ctx.paths["references_referenced.ex"]

    annotate_assert(file_path, line, char, """
        IO.puts(referenced_variable + 1)
                  ^
    """)

    assert {:ok, request} = request(file_path, line, char)
    uri = request.source_file.uri

    {:reply, %Responses.FindReferences{result: [first, second]}} = handle(request)

    assert %Types.Location{
             uri: ^uri,
             range: %Types.Range{
               start: %Types.Position{character: 4, line: 2},
               end: %Types.Position{character: 23, line: 2}
             }
           } = first

    assert %Types.Location{
             range: %Types.Range{
               start: %Types.Position{character: 12, line: 4},
               end: %Types.Position{character: 31, line: 4}
             }
           } = second
  end

  test "finds references to an attribute", ctx do
    line = 24
    char = 5
    file_path = ctx.paths["references_referenced.ex"]

    annotate_assert(file_path, line, char, """
      @referenced_attribute \"123\"
         ^
    """)

    {:ok, request} = request(file_path, line, char)

    {:reply, %Responses.FindReferences{result: [first, second]}} = handle(request)

    uri = request.source_file.uri

    assert %Types.Location{
             uri: ^uri,
             range: %Types.Range{
               start: %Types.Position{character: 2, line: 24},
               end: %Types.Position{character: 23, line: 24}
             }
           } = first

    assert %Types.Location{
             uri: ^uri,
             range: %Types.Range{
               start: %Types.Position{character: 4, line: 27},
               end: %Types.Position{character: 25, line: 27}
             }
           } = second
  end
end
