defmodule ElixirLS.LanguageServer.SourceFile.ExperimentalTest do
  use ExUnit.Case, async: true

  use ExUnitProperties
  use Patch

  import ExUnit.CaptureIO
  alias ElixirLS.LanguageServer.SourceFile
  import ElixirLS.LanguageServer.SourceFile.Experimental

  test "format_spec/2 with nil" do
    assert SourceFile.format_spec(nil, []) == ""
  end

  test "format_spec/2 with empty string" do
    assert SourceFile.format_spec("", []) == ""
  end

  test "format_spec/2 with a plain string" do
    spec = "@spec format_spec(String.t(), keyword()) :: String.t()"

    assert SourceFile.format_spec(spec, line_length: 80) == """

           ```
           @spec format_spec(String.t(), keyword()) :: String.t()
           ```
           """
  end

  test "format_spec/2 with a spec that needs to be broken over lines" do
    spec = "@spec format_spec(String.t(), keyword()) :: String.t()"

    assert SourceFile.format_spec(spec, line_length: 30) == """

           ```
           @spec format_spec(
             String.t(),
             keyword()
           ) :: String.t()
           ```
           """
  end

  def new(text) do
    %SourceFile{text: text}
  end

  def with_a_simple_module(_) do
    module = """
    defmodule MyModule do
      def foo, do: 3

      def bar(a, b) do
        a + b
      end
    end
    """

    {:ok, module: module}
  end

  describe "new" do
    setup [:with_a_simple_module]

    test "it should be able to parse a single line" do
      assert parsed = new("file:///elixir.ex", "hello", 1)

      assert {:ok, "hello"} = fetch_text_at(parsed, 1)
    end

    test "it should parse its input into lines", ctx do
      assert parsed = new("file:///elixir.ex", ctx.module, 100)
      refute parsed.dirty?
      assert parsed.version == 100

      assert {:ok, "defmodule MyModule do"} = fetch_text_at(parsed, 1)
      assert {:ok, "  def foo, do: 3"} = fetch_text_at(parsed, 2)
      assert {:ok, ""} = fetch_text_at(parsed, 3)
      assert {:ok, "  def bar(a, b) do"} = fetch_text_at(parsed, 4)
      assert {:ok, "    a + b"} = fetch_text_at(parsed, 5)
      assert {:ok, "  end"} = fetch_text_at(parsed, 6)
      assert {:ok, "end"} = fetch_text_at(parsed, 7)

      assert :error = fetch_text_at(parsed, 8)
    end
  end

  describe "apply_content_changes" do
    # tests and helper functions ported from https://github.com/microsoft/vscode-languageserver-node
    # note thet those functions are not production quality e.g. they don't deal with utf8/utf16 encoding issues
    defp index_of(string, substring) do
      case String.split(string, substring, parts: 2) do
        [left, _] -> left |> String.codepoints() |> length
        [_] -> -1
      end
    end

    def get_line_offsets(text) do
      text
      |> String.codepoints()
      |> do_line_offset(1, 0, [{0, 0}])
    end

    def do_line_offset([], _current_line, _current_index, offsets) do
      Map.new(offsets)
    end

    def do_line_offset(["\r", "\n" | rest], current_line, current_index, offsets) do
      do_line_offset(rest, current_line + 1, current_index + 2, [
        {current_line, current_index + 2} | offsets
      ])
    end

    def do_line_offset(["\n" | rest], current_line, current_index, offsets) do
      do_line_offset(rest, current_line + 1, current_index + 1, [
        {current_line, current_index + 1} | offsets
      ])
    end

    def do_line_offset(["\r" | rest], current_line, current_index, offsets) do
      do_line_offset(rest, current_line + 1, current_index + 1, [
        {current_line, current_index + 1} | offsets
      ])
    end

    def do_line_offset([_c | rest], current_line, current_index, offsets) do
      do_line_offset(rest, current_line, current_index + 1, offsets)
    end

    defp find_low_high(low, high, offset, line_offsets) when low < high do
      mid = floor((low + high) / 2)

      if line_offsets[mid] > offset do
        find_low_high(low, mid, offset, line_offsets)
      else
        find_low_high(mid + 1, high, offset, line_offsets)
      end
    end

    defp find_low_high(low, _high, _offset, _line_offsets), do: low

    def position_at(text, offset) do
      offset = clamp(offset, 0, text |> String.codepoints() |> length)

      line_offsets = get_line_offsets(text)
      low = 0
      high = map_size(line_offsets)

      if high == 0 do
        %{"line" => 0, "character" => offset}
      else
        low = find_low_high(low, high, offset, line_offsets)

        # low is the least x for which the line offset is larger than the current offset
        # or array.length if no line offset is larger than the current offset
        line = low - 1
        %{"line" => line, "character" => offset - line_offsets[line]}
      end
    end

    def clamp(num, low, high) do
      num
      |> max(low)
      |> min(high)
    end

    def position_create(l, c) do
      %{"line" => l, "character" => c}
    end

    def position_after_substring(text, sub_text) do
      index = index_of(text, sub_text)
      position_at(text, index + (String.to_charlist(sub_text) |> length))
    end

    def range_for_substring(%SourceFile{} = source_file, sub_text) do
      range_for_substring(source_file.text, sub_text)
    end

    def range_for_substring(source, sub_text) do
      index = index_of(source, sub_text)

      substring_len =
        sub_text
        |> String.to_charlist()
        |> length()

      %{
        "start" => position_at(source, index),
        "end" => position_at(source, index + substring_len)
      }
    end

    def range_after_substring(%SourceFile{} = source_file, substring) do
      range_after_substring(source_file.text, substring)
    end

    def range_after_substring(source_text, sub_text) do
      pos = position_after_substring(source_text, sub_text)
      %{"start" => pos, "end" => pos}
    end

    def range_create(sl, sc, el, ec) do
      %{"start" => position_create(sl, sc), "end" => position_create(el, ec)}
    end

    def run_changes(original, changes) do
      "file:///elixir.ex"
      |> new(original, 0)
      |> apply_content_changes(changes)
    end

    test "empty update" do
      assert {:ok, source} = run_changes("abc123", [])
      assert "abc123" == text(source)
      assert source.version == 0
    end

    test "full update" do
      assert {:ok, source} = run_changes("abc123", [%{"text" => "efg456"}])
      assert "efg456" == text(source)
      assert source.version == 1

      assert {:ok, source} =
               run_changes("abc123", [
                 %{"text" => "hello"},
                 %{"text" => "world"}
               ])

      assert "world" == text(source)
      assert 2 = source.version
    end

    test "incrementally removing content" do
      hello_world = "function abc() {\n  console.log(\"hello, world!\");\n}"

      assert {:ok, source} =
               run_changes(hello_world, [
                 %{
                   "text" => "",
                   "range" => range_for_substring(hello_world, "hello, world!")
                 }
               ])

      assert "function abc() {\n  console.log(\"\");\n}" = text(source)
    end

    test "incrementally removing multi-line content" do
      orig = "function abc() {\n  foo();\n  bar();\n  \n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "",
                   "range" => range_for_substring(orig, "  foo();\n  bar();\n")
                 }
               ])

      assert "function abc() {\n  \n}" = text(source)
    end

    test "incrementally removing multi-line content 2" do
      orig = "function abc() {\n  foo();\n  bar();\n  \n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "",
                   "range" => range_for_substring(orig, "foo();\n  bar();")
                 }
               ])

      assert "function abc() {\n  \n  \n}" == text(source)
    end

    test "incrementally adding content" do
      orig = "function abc() {\n  console.log(\"hello\");\n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => ", world!",
                   "range" => range_after_substring(orig, "hello")
                 }
               ])

      assert "function abc() {\n  console.log(\"hello, world!\");\n}" == text(source)
    end

    test "incrementally adding multi-line content" do
      orig = "function abc() {\n  while (true) {\n    foo();\n  };\n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "\n    bar();",
                   "range" => range_after_substring(orig, "foo();")
                 }
               ])

      assert "function abc() {\n  while (true) {\n    foo();\n    bar();\n  };\n}" == text(source)
    end

    test "incrementally replacing single-line content, more chars" do
      orig = "function abc() {\n  console.log(\"hello, world!\");\n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "hello, test case!!!",
                   "range" => range_for_substring(orig, "hello, world!")
                 }
               ])

      assert "function abc() {\n  console.log(\"hello, test case!!!\");\n}" == text(source)
    end

    test "incrementally replacing single-line content, less chars" do
      orig = "function abc() {\n  console.log(\"hello, world!\");\n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "hey",
                   "range" => range_for_substring(orig, "hello, world!")
                 }
               ])

      assert "function abc() {\n  console.log(\"hey\");\n}" == text(source)
    end

    test "incrementally replacing single-line content, same num of chars" do
      orig = "function abc() {\n  console.log(\"hello, world!\");\n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "world, hello!",
                   "range" => range_for_substring(orig, "hello, world!")
                 }
               ])

      assert "function abc() {\n  console.log(\"world, hello!\");\n}" == text(source)
    end

    test "incrementally replacing multi-line content, more lines" do
      orig = "function abc() {\n  console.log(\"hello, world!\");\n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "\n//hello\nfunction d(){",
                   "range" => range_for_substring(orig, "function abc() {")
                 }
               ])

      assert "\n//hello\nfunction d(){\n  console.log(\"hello, world!\");\n}" == text(source)
    end

    test "incrementally replacing multi-line content, fewer lines" do
      orig = "a1\nb1\na2\nb2\na3\nb3\na4\nb4\n"

      {:ok, source} =
        run_changes(orig, [
          %{
            "text" => "xx\nyy",
            "range" => range_for_substring(orig, "\na3\nb3\na4\nb4\n")
          }
        ])

      assert "a1\nb1\na2\nb2xx\nyy" == text(source)
    end

    test "incrementally replacing multi-line content, same num of lines and chars" do
      orig = "a1\nb1\na2\nb2\na3\nb3\na4\nb4\n"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "\nxx1\nxx2",
                   "range" => range_for_substring(orig, "a2\nb2\na3")
                 }
               ])

      assert "a1\nb1\n\nxx1\nxx2\nb3\na4\nb4\n" = text(source)
    end

    test "incrementally replacing multi-line content, same num of lines but diff chars" do
      orig = "a1\nb1\na2\nb2\na3\nb3\na4\nb4\n"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "\ny\n",
                   "range" => range_for_substring(orig, "a2\nb2\na3")
                 }
               ])

      assert "a1\nb1\n\ny\n\nb3\na4\nb4\n" == text(source)
    end

    test "incrementally replacing multi-line content, huge number of lines" do
      orig = "a1\ncc\nb1"
      text = for _ <- 1..20000, into: "", do: "\ndd"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => text,
                   "range" => range_for_substring(orig, "\ncc")
                 }
               ])

      assert "a1" <> text <> "\nb1" == text(source)
    end

    test "several incremental content changes" do
      orig = "function abc() {\n  console.log(\"hello, world!\");\n}"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "defg",
                   "range" => range_create(0, 12, 0, 12)
                 },
                 %{
                   "text" => "hello, test case!!!",
                   "range" => range_create(1, 15, 1, 28)
                 },
                 %{
                   "text" => "hij",
                   "range" => range_create(0, 16, 0, 16)
                 }
               ])

      assert "function abcdefghij() {\n  console.log(\"hello, test case!!!\");\n}" = text(source)
    end

    test "basic append" do
      orig = "foooo\nbar\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => " some extra content",
                   "range" => range_create(1, 3, 1, 3)
                 }
               ])

      assert "foooo\nbar some extra content\nbaz" == text(source)
    end

    test "multi-line append" do
      orig = "foooo\nbar\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => " some extra\ncontent",
                   "range" => range_create(1, 3, 1, 3)
                 }
               ])

      assert "foooo\nbar some extra\ncontent\nbaz" == text(source)
    end

    test "basic delete" do
      orig = "foooo\nbar\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "",
                   "range" => range_create(1, 0, 1, 3)
                 }
               ])

      assert "foooo\n\nbaz" = text(source)
    end

    test "multi-line delete" do
      orig = "foooo\nbar\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "",
                   "range" => range_create(0, 5, 1, 3)
                 }
               ])

      assert "foooo\nbaz" == text(source)
    end

    test "single character replace" do
      orig = "foooo\nbar\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "z",
                   "range" => range_create(1, 2, 1, 3)
                 }
               ])

      assert "foooo\nbaz\nbaz" == text(source)
    end

    test "multi-character replace" do
      orig = "foo\nbar"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "foobar",
                   "range" => range_create(1, 0, 1, 3)
                 }
               ])

      assert "foo\nfoobar" == text(source)
    end

    test "windows line endings are preserved in document" do
      orig = "foooo\r\nbar\rbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "z",
                   "range" => range_create(1, 2, 1, 3)
                 }
               ])

      assert "foooo\r\nbaz\rbaz" == text(source)
    end

    test "windows line endings are preserved in inserted text" do
      orig = "foooo\nbar\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "z\r\nz\rz",
                   "range" => range_create(1, 2, 1, 3)
                 }
               ])

      assert "foooo\nbaz\r\nz\rz\nbaz" == text(source)
    end

    test "utf8 glyphs are preserved in document" do
      orig = "foooo\nb🏳️‍🌈r\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "z",
                   "range" => range_create(1, 7, 1, 8)
                 }
               ])

      assert "foooo\nb🏳️‍🌈z\nbaz" == text(source)
    end

    test "utf8 glyphs are preserved in inserted text" do
      orig = "foooo\nbar\nbaz"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "z🏳️‍🌈z",
                   "range" => range_create(1, 2, 1, 3)
                 }
               ])

      assert "foooo\nbaz🏳️‍🌈z\nbaz" == text(source)
    end

    test "invalid update range - before the document starts -> before the document starts" do
      orig = "foo\nbar"
      invalid_range = range_create(-2, 0, -1, 3)

      assert {:error, {:invalid_range, ^invalid_range}} =
               run_changes(orig, [
                 %{
                   "text" => "abc123",
                   "range" => range_create(-2, 0, -1, 3)
                 }
               ])
    end

    test "invalid update range - before the document starts -> the middle of document" do
      orig = "foo\nbar"
      invalid_range = range_create(-1, 0, 0, 3)

      assert {:error, {:invalid_range, ^invalid_range}} =
               run_changes(orig, [
                 %{
                   "text" => "foobar",
                   "range" => range_create(-1, 0, 0, 3)
                 }
               ])
    end

    test "invalid update range - the middle of document -> after the document ends" do
      orig = "foo\nbar"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "foobar",
                   "range" => range_create(1, 0, 1, 10)
                 }
               ])

      assert "foo\nfoobar" == text(source)
    end

    test "invalid update range - after the document ends -> after the document ends" do
      orig = "foo\nbar"

      assert {:ok, source} =
               run_changes(orig, [
                 %{
                   "text" => "abc123",
                   "range" => range_create(3, 0, 6, 10)
                 }
               ])

      assert "foo\nbarabc123" == text(source)
    end

    test "invalid update range - before the document starts -> after the document ends" do
      orig = "foo\nbar"
      invalid_range = range_create(-1, 1, 2, 10000)

      assert {:error, {:invalid_range, ^invalid_range}} =
               run_changes(orig, [
                 %{
                   "text" => "entirely new content",
                   "range" => invalid_range
                 }
               ])
    end
  end

  test "lines" do
    assert [""] == SourceFile.lines("")
    assert ["abc"] == SourceFile.lines("abc")
    assert ["", ""] == SourceFile.lines("\n")
    assert ["a", ""] == SourceFile.lines("a\n")
    assert ["", "a"] == SourceFile.lines("\na")
    assert ["ABCDE", "FGHIJ"] == SourceFile.lines("ABCDE\rFGHIJ")
    assert ["ABCDE", "FGHIJ"] == SourceFile.lines("ABCDE\r\nFGHIJ")
    assert ["ABCDE", "", "FGHIJ"] == SourceFile.lines("ABCDE\n\nFGHIJ")
    assert ["ABCDE", "", "FGHIJ"] == SourceFile.lines("ABCDE\r\rFGHIJ")
    assert ["ABCDE", "", "FGHIJ"] == SourceFile.lines("ABCDE\n\rFGHIJ")
  end

  test "full_range" do
    assert %{
             "end" => %{"character" => 0, "line" => 0},
             "start" => %{"character" => 0, "line" => 0}
           } = SourceFile.full_range(new(""))

    assert %{"end" => %{"character" => 1, "line" => 0}} = SourceFile.full_range(new("a"))
    assert %{"end" => %{"character" => 0, "line" => 1}} = SourceFile.full_range(new("\n"))
    assert %{"end" => %{"character" => 2, "line" => 1}} = SourceFile.full_range(new("a\naa"))
    assert %{"end" => %{"character" => 2, "line" => 1}} = SourceFile.full_range(new("a\r\naa"))
    assert %{"end" => %{"character" => 8, "line" => 1}} = SourceFile.full_range(new("a\naa🏳️‍🌈"))
  end

  describe "positions" do
    test "lsp_position_to_elixir empty" do
      assert {1, 1} == SourceFile.lsp_position_to_elixir("", {0, 0})
    end

    test "lsp_position_to_elixir single first char" do
      assert {1, 1} == SourceFile.lsp_position_to_elixir("abcde", {0, 0})
    end

    test "lsp_position_to_elixir single line" do
      assert {1, 2} == SourceFile.lsp_position_to_elixir("abcde", {0, 1})
    end

    test "lsp_position_to_elixir single line utf8" do
      assert {1, 2} == SourceFile.lsp_position_to_elixir("🏳️‍🌈abcde", {0, 6})
    end

    test "lsp_position_to_elixir multi line" do
      assert {2, 2} == SourceFile.lsp_position_to_elixir("abcde\n1234", {1, 1})
    end

    test "elixir_position_to_lsp empty" do
      assert {0, 0} == SourceFile.elixir_position_to_lsp("", {1, 1})
    end

    test "elixir_position_to_lsp single line first char" do
      assert {0, 0} == SourceFile.elixir_position_to_lsp("abcde", {1, 1})
    end

    test "elixir_position_to_lsp single line" do
      assert {0, 1} == SourceFile.elixir_position_to_lsp("abcde", {1, 2})
    end

    test "elixir_position_to_lsp single line utf8" do
      assert {0, 6} == SourceFile.elixir_position_to_lsp("🏳️‍🌈abcde", {1, 2})
    end

    test "elixir_position_to_lsp multi line" do
      assert {1, 1} == SourceFile.elixir_position_to_lsp("abcde\n1234", {2, 2})
    end

    test "sanity check" do
      text = "aąłsd🏳️‍🌈abcde"

      for i <- 0..String.length(text) do
        elixir_pos = {1, i + 1}
        lsp_pos = SourceFile.elixir_position_to_lsp(text, elixir_pos)

        assert elixir_pos == SourceFile.lsp_position_to_elixir(text, lsp_pos)
      end
    end
  end

  describe "lsp_character_to_elixir" do
    test "it should handle a nil line" do
      assert 0 = SourceFile.line_length_utf16(nil)
    end
  end

  describe "formatter_for" do
    setup [:temporary_elixir_file]

    def temporary_elixir_file(_) do
      unique_number = System.unique_integer([:positive, :monotonic])
      path = Path.join([System.tmp_dir!(), "formatted_#{unique_number}.ex"])
      File.touch!(path)
      uri = %URI{path: path, scheme: "file://"}

      on_exit(fn ->
        File.rm(path)
      end)

      {:ok, file_path: path, file_uri: URI.to_string(uri)}
    end

    def as_contents(contents, %{file_path: file_path}) do
      File.write!(file_path, contents)
    end

    test "it should not crash on syntax errors", ctx do
      as_contents("", ctx)

      patch(Mix.Tasks.Format, :formatter_for_file, fn _ -> raise %SyntaxError{} end)

      assert {:error, message} =
               with_io(:stderr, fn ->
                 SourceFile.formatter_for(ctx.file_uri)
               end)

      assert String.contains?(message, "Unable to get formatter options for")
    end
  end
end
