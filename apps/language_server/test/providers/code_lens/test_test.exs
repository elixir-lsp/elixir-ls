defmodule ElixirLS.LanguageServer.Providers.CodeLens.TestTest do
  use ExUnit.Case

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
    uri = "file://project/file.ex"

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
               build_code_lens(0, :module, "/file.ex", %{"module" => MyModule}),
               build_code_lens(4, :module, "/file.ex", %{"module" => MyModule2})
             ]
  end

  test "returns all nested module code lenses" do
    uri = "file://project/file.ex"

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
               build_code_lens(0, :module, "/file.ex", %{"module" => MyModule}),
               build_code_lens(3, :module, "/file.ex", %{"module" => MyModule.MyModule2})
             ]
  end

  test "does not return lenses for modules that don't import ExUnit.case" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
    end
    """

    {:ok, lenses} = CodeLens.Test.code_lens(uri, text)

    assert lenses == []
  end

  test "returns lenses for all describe blocks" do
    uri = "file://project/file.ex"

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
             build_code_lens(3, :describe, "/file.ex", %{"describe" => "describe1"})
           )

    assert Enum.member?(
             lenses,
             build_code_lens(6, :describe, "/file.ex", %{"describe" => "describe2"})
           )
  end

  test "returns lenses for all test blocks" do
    uri = "file://project/file.ex"

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
             build_code_lens(3, :test, "/file.ex", %{"testName" => "test1"})
           )

    assert Enum.member?(
             lenses,
             build_code_lens(6, :test, "/file.ex", %{"testName" => "test2"})
           )
  end

  test "given test blocks inside describe blocks, should return code lenses with the test and describe name" do
    uri = "file://project/file.ex"

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
             build_code_lens(4, :test, "/file.ex", %{
               "testName" => "test1",
               "describe" => "describe1"
             })
           )
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
