defmodule ElixirLS.LanguageServer.Providers.CodeLens.TestTest do
  use ExUnit.Case

  import ElixirLS.LanguageServer.Test.PlatformTestHelpers
  alias ElixirLS.LanguageServer.Providers.CodeLens

  setup context do
    ElixirLS.LanguageServer.Build.load_all_modules()

    unless context[:skip_server] do
      server = ElixirLS.LanguageServer.Test.ServerTestHelpers.start_server()

      {:ok, %{server: server}}
    else
      :ok
    end
  end

  test "returns all module code lenses" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      use ExUnit.Case
    end

    defmodule MyModule2 do
      use ExUnit.Case
    end
    """

    {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

    assert lenses ==
             [
               build_code_lens(0, :module, maybe_convert_path_separators("/project/file.ex"), %{
                 "module" => MyModule
               }),
               build_code_lens(4, :module, maybe_convert_path_separators("/project/file.ex"), %{
                 "module" => MyModule2
               })
             ]
  end

  test "returns all nested module code lenses" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      use ExUnit.Case

      defmodule MyModule2 do
        use ExUnit.Case
      end
    end
    """

    {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

    assert lenses ==
             [
               build_code_lens(0, :module, maybe_convert_path_separators("/project/file.ex"), %{
                 "module" => MyModule
               }),
               build_code_lens(3, :module, maybe_convert_path_separators("/project/file.ex"), %{
                 "module" => MyModule.MyModule2
               })
             ]
  end

  test "does not return lenses for modules that don't import ExUnit.case" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
    end
    """

    {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

    assert lenses == []
  end

  test "returns lenses for all describe blocks" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      use ExUnit.Case

      describe "describe1" do
      end

      describe "describe2" do
      end
    end
    """

    {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

    assert Enum.member?(
             lenses,
             build_code_lens(3, :describe, maybe_convert_path_separators("/project/file.ex"), %{
               "describe" => "describe1"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(6, :describe, maybe_convert_path_separators("/project/file.ex"), %{
               "describe" => "describe2"
             })
           )
  end

  test "returns lenses for all test blocks" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      use ExUnit.Case

      test "test1" do
      end

      test "test2" do
      end
    end
    """

    {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

    assert Enum.member?(
             lenses,
             build_code_lens(3, :test, maybe_convert_path_separators("/project/file.ex"), %{
               "testName" => "test1"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(6, :test, maybe_convert_path_separators("/project/file.ex"), %{
               "testName" => "test2"
             })
           )
  end

  test "given test blocks inside describe blocks, should return code lenses with the test and describe name" do
    uri = "file:///project/file.ex"

    text = """
    defmodule MyModule do
      use ExUnit.Case

      describe "describe1" do
        test "test1" do
        end
      end
    end
    """

    {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

    assert Enum.member?(
             lenses,
             build_code_lens(4, :test, maybe_convert_path_separators("/project/file.ex"), %{
               "testName" => "test1",
               "describe" => "describe1"
             })
           )
  end

  describe "in large files" do
    setup do
      text = """
      defmodule ElixirLS.LanguageServer.DiagnosticsTest do
        alias ElixirLS.LanguageServer.Diagnostics
        use ExUnit.Case

        describe "normalize/2" do
          test "extract the stacktrace from the message and format it" do
            root_path = Path.join(__DIR__, "fixtures/build_errors")
            file = Path.join(root_path, "lib/has_error.ex")
            position = 2

            message = \"""
            ** (CompileError) some message

            Hint: Some hint
            (elixir 1.10.1) lib/macro.ex:304: Macro.pipe/3
            (stdlib 3.7.1) lists.erl:1263: :lists.foldl/3
            (elixir 1.10.1) expanding macro: Kernel.|>/2
            expanding macro: SomeModule.sigil_L/2
            lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
            \"""

            [diagnostic | _] =
              [build_diagnostic(message, file, position)]
              |> Diagnostics.normalize(root_path)

            assert diagnostic.message == \"""
            (CompileError) some message

            Hint: Some hint

            Stacktrace:
            │ (elixir 1.10.1) lib/macro.ex:304: Macro.pipe/3
            │ (stdlib 3.7.1) lists.erl:1263: :lists.foldl/3
            │ (elixir 1.10.1) expanding macro: Kernel.|>/2
            │ expanding macro: SomeModule.sigil_L/2
            │ lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
            \"""
          end

          test "update file and position if file is present in the message" do
            root_path = Path.join(__DIR__, "fixtures/build_errors")
            file = Path.join(root_path, "lib/has_error.ex")
            position = 2

            message = \"""
            ** (CompileError) lib/has_error.ex:3: some message
            lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
            \"""

            [diagnostic | _] =
              [build_diagnostic(message, file, position)]
              |> Diagnostics.normalize(root_path)

            assert diagnostic.message == \"""
            (CompileError) some message

            Stacktrace:
            │ lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
            \"""

            assert diagnostic.position == 3
          end

          test "update file and position if file is present in the message (umbrella)" do
            root_path = Path.join(__DIR__, "fixtures/umbrella")
            file = Path.join(root_path, "lib/file_to_be_replaced.ex")
            position = 3

            message = \"""
            ** (CompileError) lib/app2.ex:5: some message
            (elixir 1.10.1) lib/macro.ex:304: Macro.pipe/3
            lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
            \"""

            [diagnostic | _] =
              [build_diagnostic(message, file, position)]
              |> Diagnostics.normalize(root_path)

            assert diagnostic.message =~ "(CompileError) some message"
            assert diagnostic.file =~ "umbrella/apps/app2/lib/app2.ex"
            assert diagnostic.position == 5
          end

          test "don't update file nor position if file in message does not exist" do
            root_path = Path.join(__DIR__, "fixtures/build_errors_on_external_resource")
            file = Path.join(root_path, "lib/has_error.ex")
            position = 2

            message = \"""
            ** (CompileError) lib/non_existing.ex:3: some message
            lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
            \"""

            [diagnostic | _] =
              [build_diagnostic(message, file, position)]
              |> Diagnostics.normalize(root_path)

            assert diagnostic.message == \"""
            (CompileError) lib/non_existing.ex:3: some message

            Stacktrace:
            │ lib/my_app/my_module.ex:10: MyApp.MyModule.render/1
            \"""

            assert diagnostic.position == 2
          end

          defp build_diagnostic(message, file, position) do
            %Mix.Task.Compiler.Diagnostic{
              compiler_name: "Elixir",
              details: nil,
              file: file,
              message: message,
              position: position,
              severity: :error
            }
          end
        end
      end
      """

      %{text: text}
    end

    test "returns module lens on the module declaration line", %{text: text} do
      uri = "file://project/file.ex"

      {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

      assert Enum.member?(
               lenses,
               build_code_lens(0, :module, "/file.ex", %{
                 "module" => ElixirLS.LanguageServer.DiagnosticsTest
               })
             )
    end

    test "returns test lenses with describe info", %{text: text} do
      uri = "file://project/file.ex"

      {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

      assert Enum.member?(
               lenses,
               build_code_lens(5, :test, "/file.ex", %{
                 "testName" => "extract the stacktrace from the message and format it",
                 "describe" => "normalize/2"
               })
             )
    end
  end

  defp build_code_lens(line, target, file_path, args) do
    arguments =
      %{
        "filePath" => file_path
      }
      |> Map.merge(args)

    %{
      "range" => %{
        "start" => %{
          "line" => line,
          "character" => 0
        },
        "end" => %{
          "line" => line,
          "character" => 0
        }
      },
      "command" => %{
        "title" => get_lens_title(target),
        "command" => "elixir.lens.test.run",
        "arguments" => [arguments]
      }
    }
  end

  defp get_lens_title(:module), do: "Run tests in module"
  defp get_lens_title(:describe), do: "Run tests"
  defp get_lens_title(:test), do: "Run test"
end
