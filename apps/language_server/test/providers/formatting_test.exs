defmodule ElixirLS.LanguageServer.Providers.FormattingTest do
  use ExUnit.Case
  alias ElixirLS.LanguageServer.Providers.Formatting

  test "Formats a file" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      require Logger

      def dummy_function() do
        Logger.info "dummy"
      end
    end
    """

    source_file = %ElixirLS.LanguageServer.SourceFile{
      text: text,
      version: 1,
      dirty?: true
    }

    project_dir = "/project"

    assert {:ok, changes} = Formatting.format(source_file, uri, project_dir)

    assert changes == [
             %{
               "newText" => ")",
               "range" => %{
                 "end" => %{"character" => 23, "line" => 4},
                 "start" => %{"character" => 23, "line" => 4}
               }
             },
             %{
               "newText" => "(",
               "range" => %{
                 "end" => %{"character" => 16, "line" => 4},
                 "start" => %{"character" => 15, "line" => 4}
               }
             }
           ]
  end

  test "returns an error when formatting a file with a syntax error" do
    uri = "file://project/file.ex"

    text = """
    defmodule MyModule do
      require Logger

      def dummy_function() do
        Logger.info("dummy
      end
    end
    """

    source_file = %ElixirLS.LanguageServer.SourceFile{
      text: text,
      version: 1,
      dirty?: true
    }

    project_dir = "/project"

    assert {:error, :internal_error, msg} = Formatting.format(source_file, uri, project_dir)
    assert String.contains?(msg, "Unable to format")
  end
end
