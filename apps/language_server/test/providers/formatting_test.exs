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

    assert Enum.all?(changes, fn change ->
             assert_position_type(change["range"]["end"]) and
               assert_position_type(change["range"]["start"])
           end)
  end

  defp assert_position_type(%{"character" => ch, "line" => line}),
    do: is_integer(ch) and is_integer(line)

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

  test "Proper utf-16 format: emoji 😀" do
    uri = "file://project/file.ex"

    text = """
    IO.puts "😀"
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
                 "end" => %{"character" => 12, "line" => 0},
                 "start" => %{"character" => 12, "line" => 0}
               }
             },
             %{
               "newText" => "(",
               "range" => %{
                 "end" => %{"character" => 8, "line" => 0},
                 "start" => %{"character" => 7, "line" => 0}
               }
             }
           ]
  end

  test "Proper utf-16 format: emoji 🏳️‍🌈" do
    uri = "file://project/file.ex"

    text = """
    IO.puts "🏳️‍🌈"
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
                 "end" => %{"character" => 16, "line" => 0},
                 "start" => %{"character" => 16, "line" => 0}
               }
             },
             %{
               "newText" => "(",
               "range" => %{
                 "end" => %{"character" => 8, "line" => 0},
                 "start" => %{"character" => 7, "line" => 0}
               }
             }
           ]
  end

  test "Proper utf-16 format: zalgo" do
    uri = "file://project/file.ex"

    text = """
    IO.puts "ẕ̸͇̞̲͇͕̹̙̄͆̇͂̏̊͒̒̈́́̕͘͠͝à̵̢̛̟̞͚̟͖̻̹̮̘͚̻͍̇͂̂̅́̎̉͗́́̃̒l̴̻̳͉̖̗͖̰̠̗̃̈́̓̓̍̅͝͝͝g̷̢͚̠̜̿̊́̋͗̔ȍ̶̹̙̅̽̌̒͌͋̓̈́͑̏͑͊͛͘ ̸̨͙̦̫̪͓̠̺̫̖͙̫̏͂̒̽́̿̂̊́͂͋͜͠͝͝ṭ̴̜͎̮͉̙͍͔̜̾͋͒̓̏̉̄͘͠͝ͅę̷̡̭̹̰̺̩̠͓͌̃̕͜͝ͅͅx̵̧͍̦͈͍̝͖͙̘͎̥͕̾̾̍̀̿̔̄̑̈͝t̸̛͇̀̕"
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
                 "end" => %{"character" => 213, "line" => 0},
                 "start" => %{"character" => 213, "line" => 0}
               }
             },
             %{
               "newText" => "(",
               "range" => %{
                 "end" => %{"character" => 8, "line" => 0},
                 "start" => %{"character" => 7, "line" => 0}
               }
             }
           ]
  end
end
