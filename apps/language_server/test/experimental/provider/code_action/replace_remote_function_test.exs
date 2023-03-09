defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunctionTest do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction, as: CodeActionRequest
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionReply
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.SourceFile.Path, as: SourceFilePath

  import LspProtocol

  use ExUnit.Case

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  defp diagnostic_message(arity) do
    """
    Enum.counts/#{arity} is undefined or private. Did you mean:

          * concat/1
          * concat/2
          * count/1
          * count/2
    """
  end

  defp code_action(file_body, file_path, line, opts \\ []) do
    trimmed_body = String.trim(file_body, "\n")

    file_uri = SourceFilePath.to_uri(file_path)
    SourceFile.Store.open(file_uri, trimmed_body, 0)

    {:ok, range} =
      build(Range,
        start: [line: line, character: 0],
        end: [line: line, character: 0]
      )

    message =
      Keyword.get_lazy(opts, :diagnostic_message, fn ->
        diagnostic_message(1)
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
    {file_uri, action}
  end

  defp assert_expected_text_edits(file_uri, action, expected_name, line) do
    assert %CodeActionReply{edit: %{changes: %{^file_uri => edits}}} = action

    expected_edits = Diff.diff("counts", expected_name)

    assert edits
           |> Enum.zip(expected_edits)
           |> Enum.all?(fn {%TextEdit{new_text: new_text}, %TextEdit{new_text: expected_new_text}} ->
             new_text == expected_new_text
           end)

    assert Enum.all?(edits, fn edit -> edit.range.start.line == line end)
    assert Enum.all?(edits, fn edit -> edit.range.end.line == line end)
  end

  test "produces no actions if the function is not found" do
    assert {_, action} = code_action("Enum.count([1, 2])", "/project/file.ex", 0)

    source_file = action.source_file
    diagnostics = get_in(action, [:context, :diagnostics])

    Enum.each(diagnostics, fn diagnostic ->
      assert [] = ReplaceRemoteFunction.apply(source_file, diagnostic)
    end)
  end

  test "produces no actions if the line is empty" do
    {_, action} = code_action("", "/project/file.ex", 0)

    source_file = action.source_file
    diagnostics = get_in(action, [:context, :diagnostics])

    Enum.each(diagnostics, fn diagnostic ->
      assert [] = ReplaceRemoteFunction.apply(source_file, diagnostic)
    end)
  end

  test "produces no results if the diagnostic message doesn't fit the format" do
    assert {_, action} =
             code_action("", "/project/file.ex", 0, diagnostic_message: "This isn't cool")

    source_file = action.source_file
    diagnostics = get_in(action, [:context, :diagnostics])

    Enum.each(diagnostics, fn diagnostic ->
      assert [] = ReplaceRemoteFunction.apply(source_file, diagnostic)
    end)
  end

  test "produces no results for buggy source code" do
    {_, action} =
      ~S[
        1 + 2~/3 ; 4ab(
        ]
      |> code_action("/project/file.ex", 0)

    source_file = action.source_file
    diagnostics = get_in(action, [:context, :diagnostics])

    Enum.each(diagnostics, fn diagnostic ->
      assert [] = ReplaceRemoteFunction.apply(source_file, diagnostic)
    end)
  end

  test "applied to an isolated function" do
    {file_uri, code_action} =
      ~S[
          Enum.counts(a)
        ]
      |> code_action("/project/file.ex", 0)

    source_file = code_action.source_file
    [diagnostic] = get_in(code_action, [:context, :diagnostics])

    assert [to_count_action, to_concat_action] =
             ReplaceRemoteFunction.apply(source_file, diagnostic)

    assert_expected_text_edits(file_uri, to_count_action, "count", 0)
    assert_expected_text_edits(file_uri, to_concat_action, "concat", 0)
  end

  test "works for a function assigned to a variable" do
    {file_uri, code_action} =
      ~S[
          var = &Enum.counts/1
        ]
      |> code_action("/project/file.ex", 0)

    source_file = code_action.source_file
    [diagnostic] = get_in(code_action, [:context, :diagnostics])

    assert [to_count_action, to_concat_action] =
             ReplaceRemoteFunction.apply(source_file, diagnostic)

    assert_expected_text_edits(file_uri, to_count_action, "count", 0)
    assert_expected_text_edits(file_uri, to_concat_action, "concat", 0)
  end

  test "works with multiple lines" do
    {file_uri, code_action} = ~S[
      defmodule MyModule do
        def my_func(a) do
          Enum.counts(a)
        end
      end
    ] |> code_action("/project/file.ex", 2)

    source_file = code_action.source_file
    [diagnostic] = get_in(code_action, [:context, :diagnostics])

    assert [to_count_action, to_concat_action] =
             ReplaceRemoteFunction.apply(source_file, diagnostic)

    assert_expected_text_edits(file_uri, to_count_action, "count", 2)
    assert_expected_text_edits(file_uri, to_concat_action, "concat", 2)
  end

  test "proposed functions need to match function arity" do
    {_, code_action} =
      ~S[
          Enum.counts(a)
        ]
      |> code_action("/project/file.ex", 0, diagnostic_message: diagnostic_message(3))

    source_file = code_action.source_file
    [diagnostic] = get_in(code_action, [:context, :diagnostics])

    assert [] = ReplaceRemoteFunction.apply(source_file, diagnostic)
  end

  test "does not replace variables" do
    {_, code_action} =
      ~S[
          counts + 42
        ]
      |> code_action("/project/file.ex", 0)

    source_file = code_action.source_file
    [diagnostic] = get_in(code_action, [:context, :diagnostics])

    assert [] = ReplaceRemoteFunction.apply(source_file, diagnostic)
  end
end
