defmodule ElixirLS.LanguageServer.Providers.CodeLens.TestTest do
  use ExUnit.Case

  import ElixirLS.LanguageServer.Test.PlatformTestHelpers
  alias ElixirLS.LanguageServer.Providers.CodeLens
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder

  @project_dir "/project"

  test "returns all module code lenses" do
    text = """
    defmodule MyModule do
      use ExUnit.Case
    end

    defmodule MyModule2 do
      use ExUnit.Case
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert lenses ==
             [
               build_code_lens(0, :module, maybe_convert_path_separators("nofile"), %{
                 "module" => MyModule
               }),
               build_code_lens(4, :module, maybe_convert_path_separators("nofile"), %{
                 "module" => MyModule2
               })
             ]
  end

  test "returns all separate code lenses in different modules" do
    text = """
    defmodule MyModule do
      use ExUnit.Case

      doctest MyModule

      test "test1" do
      end
    end

    defmodule MyModule2 do
      use ExUnit.Case

      doctest MyModule2

      test "test1" do
      end

      describe "nested" do
        doctest MyModule
        test "test2" do
        end
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert Enum.member?(
             lenses,
             build_code_lens(0, :module, maybe_convert_path_separators("nofile"), %{
               "module" => MyModule
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(9, :module, maybe_convert_path_separators("nofile"), %{
               "module" => MyModule2
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(3, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule",
               "testName" => "doctest MyModule"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(5, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule",
               "testName" => "test1"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(14, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule2",
               "testName" => "test1"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(12, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule2",
               "testName" => "doctest MyModule2"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(18, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule2",
               "testName" => "doctest MyModule",
               "describe" => "nested"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(17, :describe, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule2",
               "describe" => "nested"
             })
           )
  end

  test "returns all nested module code lenses" do
    text = """
    defmodule MyModule do
      use ExUnit.Case

      defmodule MyModule2 do
        use ExUnit.Case
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert lenses ==
             [
               build_code_lens(0, :module, maybe_convert_path_separators("nofile"), %{
                 "module" => MyModule
               }),
               build_code_lens(3, :module, maybe_convert_path_separators("nofile"), %{
                 "module" => MyModule.MyModule2
               })
             ]
  end

  test "returns all code lenses in nested modules" do
    text = """
    defmodule MyModule do
      use ExUnit.Case

      doctest MyModule

      test "test1" do
      end

      defmodule MyModule2 do
        use ExUnit.Case

        doctest MyModule2

        test "test1" do
        end

        describe "nested" do
          doctest MyModule
          test "test2" do
          end
        end
      end
    end


    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert Enum.member?(
             lenses,
             build_code_lens(0, :module, maybe_convert_path_separators("nofile"), %{
               "module" => MyModule
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(8, :module, maybe_convert_path_separators("nofile"), %{
               "module" => MyModule.MyModule2
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(3, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule",
               "testName" => "doctest MyModule"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(5, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule",
               "testName" => "test1"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(13, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule.MyModule2",
               "testName" => "test1"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(11, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule.MyModule2",
               "testName" => "doctest MyModule2"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(17, :test, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule.MyModule2",
               "testName" => "doctest MyModule",
               "describe" => "nested"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(16, :describe, maybe_convert_path_separators("nofile"), %{
               "module" => "MyModule.MyModule2",
               "describe" => "nested"
             })
           )
  end

  test "returns lenses for all describe blocks" do
    text = """
    defmodule MyModule do
      use ExUnit.Case

      describe "describe1" do
      end

      describe "describe2" do
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert Enum.member?(
             lenses,
             build_code_lens(3, :describe, maybe_convert_path_separators("nofile"), %{
               "describe" => "describe1",
               "module" => "MyModule"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(6, :describe, maybe_convert_path_separators("nofile"), %{
               "describe" => "describe2",
               "module" => "MyModule"
             })
           )
  end

  test "returns lenses for all test blocks" do
    text = """
    defmodule MyModule do
      use ExUnit.Case

      test "test1" do
      end

      test "test2" do
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert Enum.member?(
             lenses,
             build_code_lens(3, :test, maybe_convert_path_separators("nofile"), %{
               "testName" => "test1",
               "module" => "MyModule"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(6, :test, maybe_convert_path_separators("nofile"), %{
               "testName" => "test2",
               "module" => "MyModule"
             })
           )
  end

  test "returns lenses for all test blocks including doctests" do
    text = """
    defmodule MyModuleTest do
      use ExUnit.Case

      doctest MyModule

      test "test1" do
      end

      test "test2" do
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert Enum.member?(
             lenses,
             build_code_lens(3, :test, maybe_convert_path_separators("nofile"), %{
               "testName" => "doctest MyModule",
               "module" => "MyModuleTest"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(5, :test, maybe_convert_path_separators("nofile"), %{
               "testName" => "test1",
               "module" => "MyModuleTest"
             })
           )

    assert Enum.member?(
             lenses,
             build_code_lens(8, :test, maybe_convert_path_separators("nofile"), %{
               "testName" => "test2",
               "module" => "MyModuleTest"
             })
           )
  end

  test "given test blocks inside describe blocks, should return code lenses with the test and describe name" do
    text = """
    defmodule MyModule do
      use ExUnit.Case

      describe "describe1" do
        test "test1" do
        end
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert Enum.member?(
             lenses,
             build_code_lens(4, :test, maybe_convert_path_separators("nofile"), %{
               "testName" => "test1",
               "describe" => "describe1",
               "module" => "MyModule"
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
      parser_context = ParserContextBuilder.from_string(text)

      {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

      assert Enum.member?(
               lenses,
               build_code_lens(0, :module, maybe_convert_path_separators("nofile"), %{
                 "module" => ElixirLS.LanguageServer.DiagnosticsTest
               })
             )
    end

    test "returns test lenses with describe info", %{text: text} do
      parser_context = ParserContextBuilder.from_string(text)

      {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

      assert Enum.member?(
               lenses,
               build_code_lens(5, :test, maybe_convert_path_separators("nofile"), %{
                 "testName" => "extract the stacktrace from the message and format it",
                 "describe" => "normalize/2",
                 "module" => "ElixirLS.LanguageServer.DiagnosticsTest"
               })
             )
    end
  end

  test "returns lenses for tests with multiline context parameters" do
    text = """
    defmodule MyModule do
      use ExUnit.Case

      test "test1", %{
      } do
      end
    end
    """

    parser_context = ParserContextBuilder.from_string(text)

    {:ok, lenses} = CodeLens.Test.code_lens(parser_context, @project_dir)

    assert Enum.member?(
             lenses,
             build_code_lens(3, :test, maybe_convert_path_separators("nofile"), %{
               "testName" => "test1",
               "module" => "MyModule"
             })
           )
  end

  defp build_code_lens(line, target, file_path, args) do
    arguments =
      %{
        "filePath" => file_path,
        "projectDir" => @project_dir
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
