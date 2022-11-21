defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscoreTest do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction

  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeAction, as: CodeActionReply
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.CodeActionContext
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Diagnostic
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextDocument.ContentChangeEvent

  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.SourceFile.Path, as: SourceFilePath

  import LspProtocol
  import ReplaceWithUnderscore

  use ExUnit.Case
  use Patch

  def diagnostic_message(file_path, line, variable_name, {module_name, function_name, arity}) do
    """
    warning: variable "#{variable_name}" is unused (if the variable is not meant to be used, prefix it with an underscore)
      #{file_path}:#{line}: #{module_name}.#{function_name}/#{arity}
    """
  end

  def code_action(file_body, file_path, line, variable_name, opts \\ []) do
    trimmed_body = String.trim(file_body)
    file_uri = SourceFilePath.to_uri(file_path)
    patch(SourceFile.Store, :fetch, {:ok, SourceFile.new(file_uri, trimmed_body, 1)})

    {:ok, range} =
      build(Range,
        start: [line: line, character: 0],
        end: [line: line, character: 0]
      )

    message_file_path = Keyword.get(opts, :message_file_path, file_path)
    mfa = Keyword.get(opts, :mfa, {"MyModule", "myfunc", 1})

    message = diagnostic_message(message_file_path, line, variable_name, mfa)
    diagnostic = Diagnostic.new(range: range, message: message)
    {:ok, context} = build(CodeActionContext, diagnostics: [diagnostic])

    {:ok, action} =
      build(CodeAction,
        text_document: [uri: file_uri],
        range: range,
        context: context
      )

    {:ok, action} = Requests.to_elixir(action)
    {file_uri, trimmed_body, action}
  end

  def to_map(%Range{} = range) do
    range
    |> JasonVendored.encode!()
    |> JasonVendored.decode!()
  end

  def apply_edit(source, edits) do
    source_file = SourceFile.new("file:///none", source, 1)

    converted_edits =
      Enum.map(edits, fn edit ->
        ContentChangeEvent.new(text: edit.new_text, range: edit.range)
      end)

    {:ok, source} = SourceFile.apply_content_changes(source_file, 3, converted_edits)

    source
    |> SourceFile.to_string()
    |> String.trim()
  end

  test "produces no actions if the line is empty" do
    {_, _, action} = code_action("", "/project/file.ex", 1, "a")
    assert [] = apply(action)
  end

  describe "fixes in parameters" do
    test "applied to an unadorned param" do
      {file_uri, source, code_action} =
        ~S[
          def my_func(a) do
        ]
        |> code_action("/project/file.ex", 0, "a")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func(_a) do" == apply_edit(source, edit)
    end

    test "applied to a pattern match in params" do
      {file_uri, source, code_action} =
        ~S[
          def my_func(%SourceFile{} = unused) do
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func(%SourceFile{} = _unused) do" = apply_edit(source, edit)
    end

    test "applied to a pattern match preceding a struct in params" do
      {file_uri, source, code_action} =
        ~S[
          def my_func(unused = %SourceFile{}) do
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func(_unused = %SourceFile{}) do" = apply_edit(source, edit)
    end

    test "applied prior to a map" do
      {file_uri, source, code_action} =
        ~S[
          def my_func(unused = %{}) do
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func(_unused = %{}) do" = apply_edit(source, edit)
    end

    test "applied after a map %{} = unused" do
      {file_uri, source, code_action} =
        ~S[
          def my_func(%{} = unused) do
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func(%{} = _unused) do" = apply_edit(source, edit)
    end

    test "applied to a map key %{foo: unused}" do
      {file_uri, source, code_action} =
        ~S[
          def my_func(%{foo: unused}) do
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func(%{foo: _unused}) do" = apply_edit(source, edit)
    end

    test "applied to a list element params = [unused, a, b | rest]" do
      {file_uri, source, code_action} =
        ~S{
          def my_func([unused, a, b | rest]) do
        }
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func([_unused, a, b | rest]) do" = apply_edit(source, edit)
    end

    test "applied to the tail of a list params = [a, b, | unused]" do
      {file_uri, source, code_action} =
        ~S{
          def my_func([a, b | unused]) do
        }
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "def my_func([a, b | _unused]) do" = apply_edit(source, edit)
    end
  end

  describe "fixes in variables" do
    test "applied to a variable match " do
      {file_uri, source, code_action} =
        ~S[
          x = 3
        ]
        |> code_action("/project/file.ex", 0, "x", mfa: {"iex", "nofunction", 0})

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)

      assert "_x = 3" == apply_edit(source, edit)
    end

    test "applied to a variable with a pattern matched struct" do
      {file_uri, source, code_action} =
        ~S[
          unused = %Struct{}
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "_unused = %Struct{}" = apply_edit(source, edit)
    end

    test "applied to struct param matches" do
      {file_uri, source, code_action} =
        ~S[
          %Struct{field: unused, other_field: used}
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "%Struct{field: _unused, other_field: used}" = apply_edit(source, edit)
    end

    test "applied to a struct module match %module{}" do
      {file_uri, source, code_action} =
        ~S[
          %unused{field: first, other_field: used}
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "%_unused{field: first, other_field: used}" = apply_edit(source, edit)
    end

    test "applied to a tuple value" do
      {file_uri, source, code_action} =
        ~S[
          {a, b, unused, c} = whatever
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "{a, b, _unused, c} = whatever" = apply_edit(source, edit)
    end

    test "applied to a list element" do
      {file_uri, source, code_action} =
        ~S{
          [a, b, unused, c] = whatever
        }
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "[a, b, _unused, c] = whatever" = apply_edit(source, edit)
    end

    test "applied to map value" do
      {file_uri, source, code_action} =
        ~S[
          %{foo: a, bar: unused} = whatever
        ]
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)
      assert "%{foo: a, bar: _unused} = whatever" = apply_edit(source, edit)
    end
  end

  describe "fixes in structures" do
    test "applied to a match of a comprehension" do
      {file_uri, source, code_action} =
        "for {unused, something_else} <- my_enum, do: something_else"
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)

      assert "for {_unused, something_else} <- my_enum, do: something_else" ==
               apply_edit(source, edit)
    end

    test "applied to a match in a with block" do
      {file_uri, source, code_action} =
        "with {unused, something_else} <- my_enum, do: something_else"
        |> code_action("/project/file.ex", 0, "unused")

      assert [%CodeActionReply{edit: %{changes: %{^file_uri => edit}}}] = apply(code_action)

      expected = "with {_unused, something_else} <- my_enum, do: something_else"

      assert String.trim(expected) == apply_edit(source, edit)
    end
  end
end
