defmodule ElixirLS.LanguageServer.Providers.RenameTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.Rename
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  # mix cmd --app language_server mix test test/providers/rename_test.exs

  @fake_uri "file:///World/Netherlands/Amsterdam/supercomputer/amazing.ex"

  test "rename blank space" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    {line, char} = {2, 1}

    assert {:ok, %{"documentChanges" => []}} =
             Rename.rename(%SourceFile{text: text, version: 0}, @fake_uri, line, char, "test")
  end

  describe "renaming variable" do
    test "a -> test" do
      text = """
      defmodule MyModule do
        def add(a, b) do
          a + b
        end
      end
      """

      # _a + b
      {line, char} = {3, 5}

      edits =
        Rename.rename(%SourceFile{text: text, version: 0}, @fake_uri, line, char, "test")
        |> assert_return_structure_and_get_edits(@fake_uri, 1)

      expected_edits =
        [
          %{line: 1, start_char: 10, end_char: 11},
          %{line: 2, start_char: 4, end_char: 5}
        ]
        |> get_expected_edits("test")

      assert sort_edit_by_start_line(edits) == expected_edits
    end

    test "nema -> name" do
      text = """
      defmodule MyModule do
        def hello(nema) do
          "Hello " <> nema
        end
      end
      """

      # "Hello " <> ne_ma
      {line, char} = {3, 19}

      edits =
        Rename.rename(
          %SourceFile{text: text, version: 0},
          @fake_uri,
          line,
          char,
          "name"
        )
        |> assert_return_structure_and_get_edits(@fake_uri, 1)

      expected_edits =
        [
          %{line: 1, start_char: 12, end_char: 16},
          %{line: 2, start_char: 16, end_char: 20}
        ]
        |> get_expected_edits("name")

      assert sort_edit_by_start_line(edits) == expected_edits
    end
  end

  describe "renaming local function" do
    test "subtract -> new_subtract" do
      file_path = FixtureHelpers.get_path("rename_example.ex")
      text = File.read!(file_path)
      uri = SourceFile.path_to_uri(file_path)

      #     d = subtract(a, b)
      {line, char} = {6, 10}

      edits =
        Rename.rename(
          %SourceFile{text: text, version: 0},
          uri,
          line,
          char,
          "new_subtract"
        )
        |> assert_return_structure_and_get_edits(uri, 1)

      expected_edits =
        [
          %{line: 5, start_char: 8, end_char: 16},
          %{line: 13, start_char: 7, end_char: 15}
        ]
        |> get_expected_edits("new_subtract")

      assert sort_edit_by_start_line(edits) == expected_edits
    end

    test "rename function with multiple heads: handle_error -> handle_errors" do
      file_path = FixtureHelpers.get_path("rename_example.ex")
      text = File.read!(file_path)
      uri = SourceFile.path_to_uri(file_path)

      #     c = add(a, b)
      {line, char} = {5, 9}

      edits =
        Rename.rename(
          %SourceFile{text: text, version: 0},
          uri,
          line,
          char,
          "new_add"
        )
        |> assert_return_structure_and_get_edits(uri, 1)

      expected_edits =
        [
          %{line: 4, start_char: 8, end_char: 11},
          %{line: 6, start_char: 4, end_char: 7},
          %{line: 9, start_char: 7, end_char: 10},
          %{line: 10, start_char: 7, end_char: 10},
          %{line: 11, start_char: 7, end_char: 10}
        ]
        |> get_expected_edits("new_add")

      assert sort_edit_by_start_line(edits) == expected_edits
    end
  end

  describe "not yet (fully) supported/working renaming cases" do
    test "rename started with cursor at function definition" do
      file_path = FixtureHelpers.get_path("rename_example.ex")
      text = File.read!(file_path)
      uri = SourceFile.path_to_uri(file_path)

      # defp _handle_error({:ok, message})
      {line, char} = {4, 8}

      assert {:ok, %{"documentChanges" => changes}} =
               Rename.rename(
                 %SourceFile{text: text, version: 0},
                 uri,
                 line,
                 char,
                 "handle_errors"
               )

      refute %{
               "textDocument" => %{
                 "uri" => uri,
                 "version" => 1
               },
               "edits" => [
                 %{
                   "newText" => "handle_errors",
                   "range" => %{end: %{character: 19, line: 37}, start: %{character: 7, line: 37}}
                 },
                 %{
                   "newText" => "handle_errors",
                   "range" => %{end: %{character: 19, line: 39}, start: %{character: 7, line: 39}}
                 },
                 %{
                   "newText" => "handle_errors",
                   "range" => %{end: %{character: 19, line: 28}, start: %{character: 7, line: 28}}
                 }
               ]
             } == List.first(changes)
    end
  end

  defp get_expected_edits(edits, new_text) when is_list(edits),
    do: Enum.map(edits, &get_expected_edits(&1, new_text))

  defp get_expected_edits(%{line: line, start_char: start_char, end_char: end_char}, new_text) do
    %{
      "newText" => new_text,
      "range" => %{
        start: %{line: line, character: start_char},
        end: %{line: line, character: end_char}
      }
    }
  end

  defp assert_return_structure_and_get_edits(rename_result, uri, version) do
    assert {:ok,
            %{
              "documentChanges" => [
                %{
                  "textDocument" => %{
                    "uri" => ^uri,
                    "version" => ^version
                  },
                  "edits" => edits
                }
              ]
            }} = rename_result

    edits
  end

  defp sort_edit_by_start_line(edits) do
    Enum.sort(edits, &(&1["range"].start.line < &2["range"].start.line))
  end
end
