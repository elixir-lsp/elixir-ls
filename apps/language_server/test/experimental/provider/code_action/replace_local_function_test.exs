defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceLocalFunctionTest do
  alias LSP.Requests
  alias LSP.Requests.CodeAction, as: CodeActionRequest
  alias LSP.Types.CodeAction
  alias LSP.Types.CodeAction, as: CodeActionReply
  alias LSP.Types.Diagnostic
  alias LSP.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceLocalFunction
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Document
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.SourceFile.Path, as: SourceFilePath

  import LspProtocol
  import ReplaceLocalFunction

  use ExUnit.Case
  use Patch

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  defp diagnostic_message(module, function_name, arity) do
    "(CompileError) undefined function #{function_name}/#{arity} (expected #{inspect(module)} to define such a function or for it to be imported, but none are available)"
  end

  defp code_action(file_body, file_path, line, opts \\ []) do
    file_uri = SourceFilePath.to_uri(file_path)
    SourceFile.Store.open(file_uri, file_body, 0)

    {:ok, range} =
      build(Range,
        start: [line: line, character: 0],
        end: [line: line, character: 0]
      )

    message =
      Keyword.get_lazy(opts, :diagnostic_message, fn ->
        diagnostic_message(Example, :fo, 0)
      end)

    diagnostic = Diagnostic.new(range: range, message: message)
    {:ok, context} = build(CodeAction.Context, diagnostics: [diagnostic])

    {:ok, action} =
      build(CodeActionRequest,
        text_document: [uri: file_uri],
        range: range,
        context: context
      )

    {:ok, action} = Requests.to_elixir(action)

    {file_uri, file_body, action}
  end

  defp apply_selected_action({file_uri, file_body, code_action}, index) do
    action =
      code_action
      |> apply()
      |> Enum.at(index)

    assert %CodeActionReply{edit: %{changes: %{^file_uri => edits}}} = action

    {:ok, %SourceFile{document: document}} =
      file_uri
      |> SourceFile.new(file_body, 0)
      |> SourceFile.apply_content_changes(1, edits)

    document
  end

  test "produces no actions if the function is not found" do
    message = diagnostic_message(Example, :bar, 0)

    {_, _, action} = ~S[
      defmodule Example do
        def main do
          fo()
        end
        def foo do
          42
        end
      end
    ] |> code_action("/project/file.ex", 3, diagnostic_message: message)

    assert [] = apply(action)
  end

  test "produces no actions if the line is empty" do
    {_, _, action} = code_action("", "/project/file.ex", 1)
    assert [] = apply(action)
  end

  test "produces no results if the diagnostic message doesn't fit the format" do
    assert {_, _, action} =
             code_action("", "/project/file.ex", 1, diagnostic_message: "This isn't cool")

    assert [] = apply(action)
  end

  test "produces no results for buggy source code" do
    {_, _, action} = ~S[
      1 + 2~/3 ; 4ab(
    ] |> code_action("/project/file.ex", 0)

    assert [] = apply(action)
  end

  test "handles nil context" do
    {_, _, action} = ~S[
      defmodule Example do
        def main do
          fo()
        end
        def foo do
          42
        end
      end
    ] |> code_action("/project/file.ex", 3)

    action = put_in(action, [:context], nil)

    assert [] = apply(action)
  end

  test "handles nil diagnostics" do
    {_, _, action} = ~S[
      defmodule Example do
        def main do
          fo()
        end
        def foo do
          42
        end
      end
    ] |> code_action("/project/file.ex", 3)

    action = put_in(action, [:context, :diagnostics], nil)

    assert [] = apply(action)
  end

  test "handles empty diagnostics" do
    {_, _, action} = ~S[
      defmodule Example do
        def main do
          fo()
        end
        def foo do
          42
        end
      end
    ] |> code_action("/project/file.ex", 3)

    action = put_in(action, [:context, :diagnostics], [])

    assert [] = apply(action)
  end

  test "suggestions are sorted alphabetically" do
    actual_code = ~S[
      defmodule Example do
        def main do
          fo()
        end
        def foo do
          42
        end
        def f do
          43
        end
      end
    ]

    expected_doc = ~S[
      defmodule Example do
        def main do
          f()
        end
        def foo do
          42
        end
        def f do
          43
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(0)

    expected_doc = ~S[
      defmodule Example do
        def main do
          foo()
        end
        def foo do
          42
        end
        def f do
          43
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(1)
  end

  test "suggested functions need to match the replaced function arity" do
    actual_code = ~S[
      defmodule Example do
        def main do
          fo()
        end
        def foo do
          42
        end
        def f(x) do
          x
        end
      end
    ]

    expected_doc = ~S[
      defmodule Example do
        def main do
          foo()
        end
        def foo do
          42
        end
        def f(x) do
          x
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(0)
  end

  test "does not suggest too different functions" do
    actual_code = ~S[
      defmodule Example do
        def main do
          fo()
        end
        def foo do
          42
        end
        def ff do
          43
        end
      end
    ]

    expected_doc = ~S[
      defmodule Example do
        def main do
          foo()
        end
        def foo do
          42
        end
        def ff do
          43
        end
      end
    ] |> Document.new()

    # Jaro distance between "fo" and "ff" is 0.6666666666666666 so less than the threshold
    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(0)
  end

  test "works for a function assigned to a variable" do
    actual_code = ~S[
      defmodule Example do
        def main do
          var = &fo/1
        end
        def foo do
          42
        end
      end
    ]

    expected_doc = ~S[
      defmodule Example do
        def main do
          var = &foo/1
        end
        def foo do
          42
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(0)
  end

  test "does not suggest automatically generated functions" do
    code = ~S[
      defmodule Example do
        def main do
          __inf__(:module)
          module_inf()
        end
      end
    ]

    message = diagnostic_message(Example, :__inf__, 1)

    assert [] =
             code
             |> code_action("/project/file.ex", 3, diagnostic_message: message)
             |> then(fn {_, _, action} -> action end)
             |> apply()

    message = diagnostic_message(Example, :module_inf, 0)

    assert [] =
             code
             |> code_action("/project/file.ex", 4, diagnostic_message: message)
             |> then(fn {_, _, action} -> action end)
             |> apply()
  end
end
