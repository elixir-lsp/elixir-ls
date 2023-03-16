defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunctionTest do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction, as: CodeActionRequest
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionReply
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Position
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.SourceFile.Path, as: SourceFilePath

  import LspProtocol
  import ReplaceRemoteFunction

  use ExUnit.Case
  use Patch

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
    assert [] = apply(action)
  end

  test "produces no actions if the line is empty" do
    {_, action} = code_action("", "/project/file.ex", 0)
    assert [] = apply(action)
  end

  test "produces no results if the diagnostic message doesn't fit the format" do
    assert {_, action} =
             code_action("", "/project/file.ex", 0, diagnostic_message: "This isn't cool")

    assert [] = apply(action)
  end

  test "produces no results for buggy source code" do
    {_, action} =
      ~S[
        1 + 2~/3 ; 4ab(
        ]
      |> code_action("/project/file.ex", 0)

    assert [] = apply(action)
  end

  test "handles nil context" do
    assert {_, action} = code_action("other_var = 6", "/project/file.ex", 0)

    action = put_in(action, [:context], nil)

    assert [] = apply(action)
  end

  test "handles nil diagnostics" do
    assert {_, action} = code_action("other_var = 6", "/project/file.ex", 0)

    action = put_in(action, [:context, :diagnostics], nil)

    assert [] = apply(action)
  end

  test "handles empty diagnostics" do
    assert {_, action} = code_action("other_var = 6", "/project/file.ex", 0)

    action = put_in(action, [:context, :diagnostics], [])

    assert [] = apply(action)
  end

  test "applied to an isolated function" do
    {file_uri, code_action} =
      ~S[
          Enum.counts(a)
        ]
      |> code_action("/project/file.ex", 0)

    assert [to_count_action, to_concat_action] = apply(code_action)

    assert_expected_text_edits(file_uri, to_count_action, "count", 0)
    assert_expected_text_edits(file_uri, to_concat_action, "concat", 0)
  end

  test "works for a function assigned to a variable" do
    {file_uri, code_action} =
      ~S[
          var = &Enum.counts/1
        ]
      |> code_action("/project/file.ex", 0)

    assert [to_count_action, to_concat_action] = apply(code_action)

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

    assert [to_count_action, to_concat_action] = apply(code_action)

    assert_expected_text_edits(file_uri, to_count_action, "count", 2)
    assert_expected_text_edits(file_uri, to_concat_action, "concat", 2)
  end

  test "proposed functions need to match the replaced function arity" do
    {_, code_action} =
      ~S[
          Enum.counts(a)
        ]
      |> code_action("/project/file.ex", 0, diagnostic_message: diagnostic_message(3))

    assert [] = apply(code_action)
  end

  test "does not replace variables" do
    {_, code_action} =
      ~S[
          counts + 42
        ]
      |> code_action("/project/file.ex", 0)

    assert [] = apply(code_action)
  end

  test "works with aliased modules" do
    diagnostic_message = """
    Example.A.B.my_fun/1 is undefined or private. Did you mean:

          * my_func/1
    """

    code = ~S[
        defmodule Example do
          defmodule A.B do
            def my_func(a), do: a
          end

          defmodule C do
            def my_fun(a), do: a
          end

          defmodule D do
            alias Example.A
            alias Example.A.B
            alias Example.C
            def bar() do
              A.B.my_fun(42)
              C.my_fun(42) + B.my_fun(42)
            end
          end
        end
    ]

    # A.B.my_fun(42)
    {file_uri, code_action} =
      code_action(code, "/project/file.ex", 14, diagnostic_message: diagnostic_message)

    assert [%CodeActionReply{edit: %{changes: %{^file_uri => edits}}}] = apply(code_action)

    assert [
             %TextEdit{
               new_text: "c",
               range: %Range{
                 end: %Position{character: 24, line: 14},
                 start: %Position{character: 24, line: 14}
               }
             }
           ] = edits

    # B.my_fun(42)
    {file_uri, code_action} =
      code_action(code, "/project/file.ex", 15, diagnostic_message: diagnostic_message)

    assert [%CodeActionReply{edit: %{changes: %{^file_uri => edits}}}] = apply(code_action)

    assert [
             %TextEdit{
               new_text: "c",
               range: %Range{
                 end: %Position{character: 37, line: 15},
                 start: %Position{character: 37, line: 15}
               }
             }
           ] = edits
  end
end
