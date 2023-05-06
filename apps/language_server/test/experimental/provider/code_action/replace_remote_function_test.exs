defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunctionTest do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction, as: CodeActionRequest
  alias LSP.Types.CodeAction
  alias LSP.Types.CodeAction, as: CodeActionReply
  alias LSP.Types.Diagnostic
  alias LSP.Types.Range
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Document
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
    file_uri = SourceFilePath.to_uri(file_path)
    SourceFile.Store.open(file_uri, file_body, 0)

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
    assert {_, _, action} = code_action("Enum.count([1, 2])", "/project/file.ex", 0)
    assert [] = apply(action)
  end

  test "produces no actions if the line is empty" do
    {_, _, action} = code_action("", "/project/file.ex", 0)
    assert [] = apply(action)
  end

  test "produces no results if the diagnostic message doesn't fit the format" do
    assert {_, _, action} =
             code_action("", "/project/file.ex", 0, diagnostic_message: "This isn't cool")

    assert [] = apply(action)
  end

  test "produces no results for buggy source code" do
    {_, _, action} =
      ~S[
        1 + 2~/3 ; 4ab(
        ]
      |> code_action("/project/file.ex", 0)

    assert [] = apply(action)
  end

  test "handles nil context" do
    assert {_, _, action} = code_action("other_var = 6", "/project/file.ex", 0)

    action = put_in(action, [:context], nil)

    assert [] = apply(action)
  end

  test "handles nil diagnostics" do
    assert {_, _, action} = code_action("other_var = 6", "/project/file.ex", 0)

    action = put_in(action, [:context, :diagnostics], nil)

    assert [] = apply(action)
  end

  test "handles empty diagnostics" do
    assert {_, _, action} = code_action("other_var = 6", "/project/file.ex", 0)

    action = put_in(action, [:context, :diagnostics], [])

    assert [] = apply(action)
  end

  test "applied to an isolated function" do
    actual_code = ~S[
        Enum.counts(a)
      ]

    expected_doc = ~S[
        Enum.count(a)
      ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 1)
             |> apply_selected_action(0)

    expected_doc = ~S[
        Enum.concat(a)
      ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 1)
             |> apply_selected_action(1)
  end

  test "works for a function assigned to a variable" do
    actual_code = ~S[
      var = &Enum.counts/1
    ]

    expected_doc = ~S[
      var = &Enum.count/1
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 1)
             |> apply_selected_action(0)

    expected_doc = ~S[
      var = &Enum.concat/1
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 1)
             |> apply_selected_action(1)
  end

  test "works with multiple lines" do
    actual_code = ~S[
      defmodule MyModule do
        def my_func(a) do
          Enum.counts(a)
        end
      end
    ]

    expected_doc = ~S[
      defmodule MyModule do
        def my_func(a) do
          Enum.count(a)
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(0)

    expected_doc = ~S[
      defmodule MyModule do
        def my_func(a) do
          Enum.concat(a)
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(1)
  end

  test "proposed functions need to match the replaced function arity" do
    {_, _, code_action} =
      ~S[
          Enum.counts(a)
        ]
      |> code_action("/project/file.ex", 0, diagnostic_message: diagnostic_message(3))

    assert [] = apply(code_action)
  end

  test "does not replace variables" do
    {_, _, code_action} =
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

    actual_code = ~S[
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
    expected_doc = ~S[
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
            A.B.my_func(42)
            C.my_fun(42) + B.my_fun(42)
          end
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 15, diagnostic_message: diagnostic_message)
             |> apply_selected_action(0)

    # B.my_fun(42)
    expected_doc = ~S[
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
            C.my_fun(42) + B.my_func(42)
          end
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 16, diagnostic_message: diagnostic_message)
             |> apply_selected_action(0)
  end
end
