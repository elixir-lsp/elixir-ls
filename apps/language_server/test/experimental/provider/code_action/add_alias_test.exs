defmodule ElixirLS.LanguageServer.Experimental.Provider.CodeAction.AddAliasTest do
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.AddAlias
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Document
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol
  alias ElixirLS.LanguageServer.SourceFile.Path, as: SourceFilePath
  alias LSP.Requests
  alias LSP.Requests.CodeAction, as: CodeActionRequest
  alias LSP.Types.CodeAction
  alias LSP.Types.CodeAction, as: CodeActionReply
  alias LSP.Types.Diagnostic
  alias LSP.Types.Range

  import LspProtocol
  import AddAlias

  use ExUnit.Case
  use Patch

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  def module_diagnostic_message(module) do
    """
    #{module} is undefined (module #{module} is not available or is yet to be defined)
    """
  end

  def struct_diagnostic_message(module) do
    """
    (CompileError) #{module}.__struct__/1 is undefined, cannot expand struct #{module}. Make sure the struct name is correct. If the struct name exists and is correct but it still cannot be found, you likely have cyclic module usage in your code
        expanding struct: #{module}.__struct__/1
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
        module_diagnostic_message("ExampleDefaultArgs")
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

  test "produces no actions if the module is not found in the code" do
    actual_code = ~S[
      defmodule MyModule do
        def foo do
          ExampleDefaultArg.my_func("text")
        end
      end
    ]

    assert {_, _, action} = code_action(actual_code, "/project/file.ex", 3)
    assert [] = apply(action)
  end

  test "produces no actions if the line is empty" do
    {_, _, action} = code_action("", "/project/file.ex", 0)
    assert [] = apply(action)
  end

  test "produces no results if the diagnostic message doesn't fit the format" do
    actual_code = ~S[
      defmodule MyModule do
        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ]

    assert {_, _, action} =
             code_action(actual_code, "/project/file.ex", 3, diagnostic_message: "This isn't cool")

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
    actual_code = ~S[
      defmodule MyModule do
        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ]

    assert {_, _, action} = code_action(actual_code, "/project/file.ex", 3)

    action = put_in(action, [:context], nil)

    assert [] = apply(action)
  end

  test "handles nil diagnostics" do
    actual_code = ~S[
      defmodule MyModule do
        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ]

    assert {_, _, action} = code_action(actual_code, "/project/file.ex", 3)

    action = put_in(action, [:context, :diagnostics], nil)

    assert [] = apply(action)
  end

  test "handles empty diagnostics" do
    actual_code = ~S[
      defmodule MyModule do
        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ]

    assert {_, _, action} = code_action(actual_code, "/project/file.ex", 3)

    action = put_in(action, [:context, :diagnostics], [])

    assert [] = apply(action)
  end

  test "add alias for an unknown struct" do
    actual_code = ~S[
      defmodule MyModule do
        def foo do
          %ExampleStruct{}
        end
      end
    ]

    diagnostic_message = struct_diagnostic_message("ExampleStruct")

    expected_doc = ~S[
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleStruct

        def foo do
          %ExampleStruct{}
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3, diagnostic_message: diagnostic_message)
             |> apply_selected_action(0)
  end

  test "add alias for an unknown function call" do
    actual_code = ~S[
      defmodule MyModule do
        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ]

    expected_doc = ~S[
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 3)
             |> apply_selected_action(0)
  end

  test "add alias in a nested module" do
    actual_code = ~S[
      defmodule MyModule do
        defmodule Example do
          def foo do
            ExampleDefaultArgs.my_func("text")
          end
        end
      end
    ]

    expected_doc = ~S[
      defmodule MyModule do
        defmodule Example do
          alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

          def foo do
            ExampleDefaultArgs.my_func("text")
          end
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 4)
             |> apply_selected_action(0)
  end

  test "add alias when there are already other aliases" do
    actual_code = ~S[
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDocs

        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ]

    expected_doc = ~S[
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs
        alias ElixirLS.LanguageServer.Fixtures.ExampleDocs

        def foo do
          ExampleDefaultArgs.my_func("text")
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 5)
             |> apply_selected_action(0)
  end

  test "add alias when there are already other directives" do
    actual_code = ~S[
      defmodule MyModule do
        @moduledoc """

        """
        import ElixirLS.LanguageServer.Fixtures.ExampleDocs

        def foo do
          ExampleDefaultArgs.my_func(@text)
        end
      end
    ]

    expected_doc = ~S[
      defmodule MyModule do
        @moduledoc """

        """

        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

        import ElixirLS.LanguageServer.Fixtures.ExampleDocs

        def foo do
          ExampleDefaultArgs.my_func(@text)
        end
      end
    ] |> Document.new()

    assert expected_doc ==
             actual_code
             |> code_action("/project/file.ex", 8)
             |> apply_selected_action(0)
  end
end
