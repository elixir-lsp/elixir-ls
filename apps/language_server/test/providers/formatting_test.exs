defmodule ElixirLS.LanguageServer.Providers.FormattingTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  import ElixirLS.LanguageServer.Test.PlatformTestHelpers
  alias ElixirLS.LanguageServer.Providers.Formatting
  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.MixProjectCache
  alias ElixirLS.LanguageServer.Test.FixtureHelpers

  setup do
    {:ok, _} = start_supervised(MixProjectCache)
    :ok
  end

  @tag :fixture
  test "no mixfile" do
    in_fixture(Path.join(__DIR__, ".."), "no_mixfile", fn ->
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

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

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("no_mixfile"))

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, false)

      assert changes == [
               %TextEdit{
                 newText: ")",
                 range: %{
                   "end" => %{"character" => 23, "line" => 4},
                   "start" => %{"character" => 23, "line" => 4}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
                   "end" => %{"character" => 16, "line" => 4},
                   "start" => %{"character" => 15, "line" => 4}
                 }
               }
             ]

      assert Enum.all?(changes, fn change ->
               assert_position_type(change.range["end"]) and
                 assert_position_type(change.range["start"])
             end)
    end)
  end

  @tag :fixture
  test "no project dir" do
    in_fixture(Path.join(__DIR__, ".."), "no_mixfile", fn ->
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

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

      project_dir = nil

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, false)

      assert changes == [
               %TextEdit{
                 newText: ")",
                 range: %{
                   "end" => %{"character" => 23, "line" => 4},
                   "start" => %{"character" => 23, "line" => 4}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
                   "end" => %{"character" => 16, "line" => 4},
                   "start" => %{"character" => 15, "line" => 4}
                 }
               }
             ]

      assert Enum.all?(changes, fn change ->
               assert_position_type(change.range["end"]) and
                 assert_position_type(change.range["start"])
             end)
    end)
  end

  @tag :fixture
  test "Formats a file with LF line endings" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

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

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, true)

      assert changes == [
               %TextEdit{
                 newText: ")",
                 range: %{
                   "end" => %{"character" => 23, "line" => 4},
                   "start" => %{"character" => 23, "line" => 4}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
                   "end" => %{"character" => 16, "line" => 4},
                   "start" => %{"character" => 15, "line" => 4}
                 }
               }
             ]

      assert Enum.all?(changes, fn change ->
               assert_position_type(change.range["end"]) and
                 assert_position_type(change.range["start"])
             end)
    end)
  end

  @tag :fixture
  test "Formats a file with CRLF line endings" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

      text = """
      defmodule MyModule do
        require Logger

        def dummy_function() do
          Logger.info "dummy"
        end
      end
      """

      text = text |> String.replace("\n", "\r\n")

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, true)

      assert changes == [
               %TextEdit{
                 newText: "\n",
                 range: %{
                   "end" => %{"character" => 0, "line" => 7},
                   "start" => %{"character" => 3, "line" => 6}
                 }
               },
               %TextEdit{
                 newText: "\n",
                 range: %{
                   "end" => %{"character" => 0, "line" => 6},
                   "start" => %{"character" => 5, "line" => 5}
                 }
               },
               %TextEdit{
                 newText: ")\n",
                 range: %{
                   "end" => %{"character" => 0, "line" => 5},
                   "start" => %{"character" => 23, "line" => 4}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
                   "end" => %{"character" => 16, "line" => 4},
                   "start" => %{"character" => 15, "line" => 4}
                 }
               },
               %TextEdit{
                 newText: "\n",
                 range: %{
                   "end" => %{"character" => 0, "line" => 4},
                   "start" => %{"character" => 25, "line" => 3}
                 }
               },
               %TextEdit{
                 newText: "\n\n",
                 range: %{
                   "end" => %{"character" => 0, "line" => 3},
                   "start" => %{"character" => 16, "line" => 1}
                 }
               },
               %TextEdit{
                 newText: "\n",
                 range: %{
                   "end" => %{"character" => 0, "line" => 1},
                   "start" => %{"character" => 21, "line" => 0}
                 }
               }
             ]

      assert Enum.all?(changes, fn change ->
               assert_position_type(change.range["end"]) and
                 assert_position_type(change.range["start"])
             end)
    end)
  end

  @tag :fixture
  test "elixir formatter does not support CR line endings" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

      text = """
      defmodule MyModule do
        require Logger

        def dummy_function() do
          Logger.info "dummy"
        end
      end
      """

      text = text |> String.replace("\n", "\r")

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

      assert {:ok, []} =
               Formatting.format(source_file, uri, project_dir, true)
    end)
  end

  @tag :fixture
  test "formatting preserves line indings inside a string" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

      text = """
      defmodule MyModule do
        require Logger

        def dummy_function() do
          Logger.info "dummy"
        end
      end
      """

      text = text |> String.replace("\"dummy\"", "    \"du\nm\rm\r\ny\"")

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, true)

      assert changes == [
               %TextEdit{
                 newText: ")",
                 range: %{
                   "end" => %{"character" => 2, "line" => 7},
                   "start" => %{"character" => 2, "line" => 7}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
                   "end" => %{"character" => 20, "line" => 4},
                   "start" => %{"character" => 15, "line" => 4}
                 }
               }
             ]

      assert Enum.all?(changes, fn change ->
               assert_position_type(change.range["end"]) and
                 assert_position_type(change.range["start"])
             end)
    end)
  end

  defp assert_position_type(%{"character" => ch, "line" => line}),
    do: is_integer(ch) and is_integer(line)

  @tag :fixture
  test "returns an error when formatting a file with a syntax error" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

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

      assert {:ok, []} =
               Formatting.format(source_file, uri, project_dir, true)
    end)
  end

  @tag :fixture
  test "Proper utf-16 format: emoji 😀" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

      text = """
      IO.puts "😀"
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators("/project")

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, true)

      assert changes == [
               %TextEdit{
                 newText: ")",
                 range: %{
                   "end" => %{"character" => 12, "line" => 0},
                   "start" => %{"character" => 12, "line" => 0}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
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
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

      text = """
      IO.puts "🏳️‍🌈"
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, true)

      assert changes == [
               %TextEdit{
                 newText: ")",
                 range: %{
                   "end" => %{"character" => 16, "line" => 0},
                   "start" => %{"character" => 16, "line" => 0}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
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
      store_mix_cache()
      path = "lib/file.ex"
      uri = SourceFile.Path.to_uri(path)

      text = """
      IO.puts "ẕ̸͇̞̲͇͕̹̙̄͆̇͂̏̊͒̒̈́́̕͘͠͝à̵̢̛̟̞͚̟͖̻̹̮̘͚̻͍̇͂̂̅́̎̉͗́́̃̒l̴̻̳͉̖̗͖̰̠̗̃̈́̓̓̍̅͝͝͝g̷̢͚̠̜̿̊́̋͗̔ȍ̶̹̙̅̽̌̒͌͋̓̈́͑̏͑͊͛͘ ̸̨͙̦̫̪͓̠̺̫̖͙̫̏͂̒̽́̿̂̊́͂͋͜͠͝͝ṭ̴̜͎̮͉̙͍͔̜̾͋͒̓̏̉̄͘͠͝ͅę̷̡̭̹̰̺̩̠͓͌̃̕͜͝ͅͅx̵̧͍̦͈͍̝͖͙̘͎̥͕̾̾̍̀̿̔̄̑̈͝t̸̛͇̀̕"
      """

      source_file = %SourceFile{
        text: text,
        version: 1,
        dirty?: true
      }

      project_dir = maybe_convert_path_separators(FixtureHelpers.get_path("formatter"))

      assert {:ok, changes} = Formatting.format(source_file, uri, project_dir, true)

      assert changes == [
               %TextEdit{
                 newText: ")",
                 range: %{
                   "end" => %{"character" => 213, "line" => 0},
                   "start" => %{"character" => 213, "line" => 0}
                 }
               },
               %TextEdit{
                 newText: "(",
                 range: %{
                   "end" => %{"character" => 8, "line" => 0},
                   "start" => %{"character" => 7, "line" => 0}
                 }
               }
             ]
    end)
  end

  @tag :fixture
  test "honors :inputs when deciding to format" do
    in_fixture(Path.join(__DIR__, ".."), "formatter", fn ->
      store_mix_cache()
      project_dir = Path.expand(".")

      assert_formatted("file.ex", project_dir, true)

      # test/.formatter.exs has [inputs: ["*.exs"]]
      assert_formatted("test/file.exs", project_dir, true)
      refute_formatted("test/file.ex", project_dir, true)

      unless is_windows() do
        assert_formatted("symlink/file.exs", project_dir, true)
        refute_formatted("symlink/file.ex", project_dir, true)
      end

      File.mkdir!("#{project_dir}/test/foo")
      refute_formatted("test/foo/file.ex", project_dir, true)

      # apps/foo/bar/.formatter.exs has [inputs: ["foo.ex"]]
      assert_formatted("apps/foo/foo.ex", project_dir, true)
      refute_formatted("apps/foo/bar.ex", project_dir, true)
      refute_formatted("apps/foo.ex", project_dir, true)
    end)
  end

  def assert_formatted(path, project_dir, mix_file?) do
    assert match?(
             {:ok, [%ElixirLS.LanguageServer.Protocol.TextEdit{} | _]},
             format(path, project_dir, mix_file?)
           ),
           "expected '#{path}' to be formatted"
  end

  def refute_formatted(path, project_dir, mix_file?) do
    assert match?({:ok, []}, format(path, project_dir, mix_file?)),
           "expected '#{path}' not to be formatted"
  end

  defp format(path, project_dir, mix_project?) do
    project_dir =
      maybe_convert_path_separators(project_dir)
      |> Path.absname()

    path = maybe_convert_path_separators("#{project_dir}/#{path}")

    source_file = %SourceFile{
      text: " asd  = 1",
      version: 1,
      dirty?: true
    }

    File.write!(path, " asd  = 1")
    Formatting.format(source_file, SourceFile.Path.to_uri(path), project_dir, mix_project?)
  end

  defp store_mix_cache() do
    state = %{
      get: Mix.Project.get(),
      # project_file: Mix.Project.project_file(),
      config: Mix.Project.config(),
      # config_files: Mix.Project.config_files(),
      config_mtime: Mix.Project.config_mtime(),
      umbrella?: Mix.Project.umbrella?(),
      apps_paths: Mix.Project.apps_paths(),
      # deps_path: Mix.Project.deps_path(),
      # deps_apps: Mix.Project.deps_apps(),
      # deps_scms: Mix.Project.deps_scms(),
      deps_paths: Mix.Project.deps_paths(),
      # build_path: Mix.Project.build_path(),
      manifest_path: Mix.Project.manifest_path()
    }

    MixProjectCache.store(state)
  end
end
