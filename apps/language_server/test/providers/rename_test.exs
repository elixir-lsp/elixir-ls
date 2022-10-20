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

      assert {:ok, %{"documentChanges" => changes}} =
               Rename.rename(%SourceFile{text: text, version: 0}, @fake_uri, line, char, "test")

      assert %{
               "textDocument" => %{
                 "uri" => @fake_uri,
                 "version" => 1
               },
               "edits" => [
                 %{
                   "range" => %{end: %{character: 11, line: 1}, start: %{character: 10, line: 1}},
                   "newText" => "test"
                 },
                 %{
                   "range" => %{end: %{character: 5, line: 2}, start: %{character: 4, line: 2}},
                   "newText" => "test"
                 }
               ]
             } == List.first(changes)
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

      assert {:ok, %{"documentChanges" => [changes]}} =
               Rename.rename(
                 %SourceFile{text: text, version: 0},
                 @fake_uri,
                 line,
                 char,
                 "name"
               )

      assert %{
               "textDocument" => %{
                 "uri" => @fake_uri,
                 "version" => 1
               },
               "edits" => [
                 %{
                   "range" => %{end: %{character: 16, line: 1}, start: %{character: 12, line: 1}},
                   "newText" => "name"
                 },
                 %{
                   "range" => %{end: %{character: 20, line: 2}, start: %{character: 16, line: 2}},
                   "newText" => "name"
                 }
               ]
             } == changes
    end
  end

  describe "renaming local function" do
    test "create_message -> store_message" do
      file_path = FixtureHelpers.get_path("rename_example.exs")
      text = File.read!(file_path)
      uri = SourceFile.path_to_uri(file_path)

      # |> _create_message
      {line, char} = {28, 8}

      assert {:ok, %{"documentChanges" => [changes]}} =
               Rename.rename(
                 %SourceFile{text: text, version: 0},
                 uri,
                 line,
                 char,
                 "store_message"
               )

      assert %{
               "textDocument" => %{
                 "uri" => uri,
                 "version" => 1
               },
               "edits" => [
                 %{
                   "newText" => "store_message",
                   "range" => %{end: %{character: 21, line: 43}, start: %{character: 7, line: 43}}
                 },
                 %{
                   "newText" => "store_message",
                   "range" => %{end: %{character: 21, line: 27}, start: %{character: 7, line: 27}}
                 }
               ]
             } == changes
    end

    test "rename function with multiple heads: handle_error -> handle_errors" do
      file_path = FixtureHelpers.get_path("rename_example.exs")
      text = File.read!(file_path)
      uri = SourceFile.path_to_uri(file_path)

      {line, char} = {29, 8}

      assert {:ok, %{"documentChanges" => [changes]}} =
               Rename.rename(
                 %SourceFile{text: text, version: 0},
                 uri,
                 line,
                 char,
                 "handle_errors"
               )

      assert %{
               "textDocument" => %{
                 "uri" => uri,
                 "version" => 1
               },
               "edits" => [
                 %{
                   "newText" => "handle_errors",
                   "range" => %{end: %{character: 19, line: 39}, start: %{character: 7, line: 39}}
                 },
                 %{
                   "newText" => "handle_errors",
                   "range" => %{end: %{character: 19, line: 37}, start: %{character: 7, line: 37}}
                 },
                 %{
                   "newText" => "handle_errors",
                   "range" => %{end: %{character: 19, line: 28}, start: %{character: 7, line: 28}}
                 }
               ]
             } == changes
    end
  end

  describe "not yet (fully) supported/working renaming cases" do
    test "rename started with cursor at function definition" do
      file_path = FixtureHelpers.get_path("rename_example.exs")
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
end
