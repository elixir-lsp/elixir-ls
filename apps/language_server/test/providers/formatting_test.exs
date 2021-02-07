defmodule ElixirLS.LanguageServer.Providers.FormattingTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  import ElixirLS.LanguageServer.Test.PlatformTestHelpers
  alias ElixirLS.LanguageServer.Providers.Formatting
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers

  @tag :fixture
  test "Formats a file" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      path = "lib/file.ex"
      uri = SourceFile.path_to_uri(path)

      text = """
      defmodule MyModule do
        require Logger

        def dummy_function() do
          Logger.info "dummy"
        end
      end
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

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
    end)
  end

  defp assert_position_type(%{"character" => ch, "line" => line}),
    do: is_integer(ch) and is_integer(line)

  @tag :fixture
  test "returns an error when formatting a file with a syntax error" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      path = "lib/file.ex"
      uri = SourceFile.path_to_uri(path)

      text = """
      defmodule MyModule do
        require Logger

        def dummy_function() do
          Logger.info("dummy
        end
      end
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

      assert {:error, :internal_error, msg} = Formatting.format(source_file, uri, project_dir)
      assert String.contains?(msg, "Unable to format")
    end)
  end

  @tag :fixture
  test "Proper utf-16 format: emoji 😀" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      path = "lib/file.ex"
      uri = SourceFile.path_to_uri(path)

      text = """
      IO.puts "😀"
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators("/project")

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
    end)
  end

  @tag :fixture
  test "Proper utf-16 format: emoji 🏳️‍🌈" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      path = "lib/file.ex"
      uri = SourceFile.path_to_uri(path)

      text = """
      IO.puts "🏳️‍🌈"
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

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
    end)
  end

  @tag :fixture
  test "Proper utf-16 format: zalgo" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      path = "lib/file.ex"
      uri = SourceFile.path_to_uri(path)

      text = """
      IO.puts "ẕ̸͇̞̲͇͕̹̙̄͆̇͂̏̊͒̒̈́́̕͘͠͝à̵̢̛̟̞͚̟͖̻̹̮̘͚̻͍̇͂̂̅́̎̉͗́́̃̒l̴̻̳͉̖̗͖̰̠̗̃̈́̓̓̍̅͝͝͝g̷̢͚̠̜̿̊́̋͗̔ȍ̶̹̙̅̽̌̒͌͋̓̈́͑̏͑͊͛͘ ̸̨͙̦̫̪͓̠̺̫̖͙̫̏͂̒̽́̿̂̊́͂͋͜͠͝͝ṭ̴̜͎̮͉̙͍͔̜̾͋͒̓̏̉̄͘͠͝ͅę̷̡̭̹̰̺̩̠͓͌̃̕͜͝ͅͅx̵̧͍̦͈͍̝͖͙̘͎̥͕̾̾̍̀̿̔̄̑̈͝t̸̛͇̀̕"
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

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
    end)
  end

  test "honors :inputs when deciding to format" do
    file = __ENV__.file
    uri = SourceFile.path_to_uri(file)
    project_dir = Path.dirname(file)

    opts = []
    assert Formatting.should_format?(uri, project_dir, opts[:inputs])

    opts = [inputs: ["*.exs"]]
    assert Formatting.should_format?(uri, project_dir, opts[:inputs])

    opts = [inputs: ["*.ex"]]
    refute Formatting.should_format?(uri, project_dir, opts[:inputs])
  end
end
