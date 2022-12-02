defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscoreTest do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionReply
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeActionContext
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.SourceFile.Path, as: SourceFilePath

  import LspProtocol
  import ReplaceWithUnderscore

  use ExUnit.Case
  use Patch

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  def diagnostic_message(file_path, line, variable_name, {module_name, function_name, arity}) do
    """
    warning: variable "#{variable_name}" is unused (if the variable is not meant to be used, prefix it with an underscore)
      #{file_path}:#{line}: #{module_name}.#{function_name}/#{arity}
    """
  end

  def code_action(file_body, file_path, line, variable_name, opts \\ []) do
    trimmed_body = String.trim(file_body, "\n")

    file_uri = SourceFilePath.to_uri(file_path)
    SourceFile.Store.open(file_uri, trimmed_body, 0)

    {:ok, range} =
      build(Range,
        start: [line: line, character: 0],
        end: [line: line, character: 0]
      )

    message_file_path = Keyword.get(opts, :message_file_path, file_path)
    mfa = Keyword.get(opts, :mfa, {"MyModule", "myfunc", 1})

    message =
      Keyword.get_lazy(opts, :diagnostic_message, fn ->
        diagnostic_message(message_file_path, line, variable_name, mfa)
      end)

    diagnostic = Diagnostic.new(range: range, message: message)
    {:ok, context} = build(CodeActionContext, diagnostics: [diagnostic])

    {:ok, action} =
      build(CodeAction,
        text_document: [uri: file_uri],
        range: range,
        context: context
      )

    {:ok, action} = Requests.to_elixir(action)
    {file_uri, action}
  end

  def to_map(%Range{} = range) do
    range
    |> JasonVendored.encode!()
    |> JasonVendored.decode!()
  end

  test "produces no actions if the name or variable is not found" do
    assert {_, action} = code_action("other_var = 6", "/project/file.ex", 1, "not_found")
    assert [] = apply(action)
  end

  test "produces no actions if the line is empty" do
    {_, action} = code_action("", "/project/file.ex", 1, "a")
    assert [] = apply(action)
  end

  test "produces no results if the diagnostic message doesn't fit the format" do
    assert {_, action} =
             code_action("", "/project/file.ex", 1, "not_found",
               diagnostic_message: "This isn't cool"
             )

    assert [] = apply(action)
  end

  test "produces no results for buggy source code" do
    {_, action} =
      ~S[
        1 + 2~/3 ; 4ab(
        ]
      |> code_action("/project/file.ex", 0, "unused")

    assert [] = apply(action)
  end

  test "handles nil context" do
    assert {_, action} = code_action("other_var = 6", "/project/file.ex", 1, "not_found")

    action = put_in(action, [:context], nil)

    assert [] = apply(action)
  end

  test "handles nil diagnostics" do
    assert {_, action} = code_action("other_var = 6", "/project/file.ex", 1, "not_found")

    action = put_in(action, [:context, :diagnostics], nil)

    assert [] = apply(action)
  end

  test "handles empty diagnostics" do
    assert {_, action} = code_action("other_var = 6", "/project/file.ex", 1, "not_found")

    action = put_in(action, [:context, :diagnostics], [])

    assert [] = apply(action)
  end

  test "applied to an unadorned param" do
    {file_uri, code_action} =
      ~S[
          def my_func(a) do
        ]
      |> code_action("/project/file.ex", 0, "a")

    assert [%CodeActionReply{edit: %{changes: %{^file_uri => [edit]}}}] = apply(code_action)
    assert edit.new_text == "_"
  end

  test "works with multiple lines" do
    {file_uri, code_action} = ~S[
      defmodule MyModule do
        def my_func(a) do
        end
      end
    ] |> code_action("/project/file.ex", 1, "a")

    assert [%CodeActionReply{edit: %{changes: %{^file_uri => [edit]}}}] = apply(code_action)
    assert edit.new_text == "_"
    assert edit.range.start.line == 1
    assert edit.range.end.line == 1
  end
end
