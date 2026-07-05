defmodule ElixirLS.LanguageServer.Providers.SemanticTokensTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.SemanticTokens
  alias ElixirLS.LanguageServer.SourceFile
  alias GenLSP.Structures.{Range, Position}

  defp sf(text), do: %SourceFile{text: text, version: 1, language_id: "elixir"}

  # Decode the flat LSP stream back into absolute {line, start, len, type, mods} tuples.
  defp decode(data) do
    types = SemanticTokens.legend().token_types
    modifiers = SemanticTokens.legend().token_modifiers

    {rows, _l, _s} =
      data
      |> Enum.chunk_every(5)
      |> Enum.reduce({[], 0, 0}, fn [dl, ds, len, t, m], {acc, line, start} ->
        line = line + dl
        start = if dl == 0, do: start + ds, else: ds
        type = Enum.at(types, t)

        mods =
          for {name, i} <- Enum.with_index(modifiers), Bitwise.band(m, Bitwise.bsl(1, i)) != 0, do: name

        {[{line, start, len, type, mods} | acc], line, start}
      end)

    Enum.reverse(rows)
  end

  describe "legend" do
    test "advertises stable string types/modifiers" do
      legend = SemanticTokens.legend()
      assert "function" in legend.token_types
      assert "namespace" in legend.token_types
      # custom types
      assert "atom" in legend.token_types
      assert "sigil" in legend.token_types
      assert "definition" in legend.token_modifiers
      # append-only contract: the first entry must never move
      assert hd(legend.token_types) == "namespace"
    end

    test "covers every type and modifier toxic2 can emit" do
      legend = SemanticTokens.legend()

      for type <- Toxic2.SemanticTokens.known_types() do
        assert Atom.to_string(type) in legend.token_types
      end

      for modifier <- Toxic2.SemanticTokens.known_modifiers() do
        assert Atom.to_string(modifier) in legend.token_modifiers
      end
    end
  end

  describe "full/1" do
    test "encodes a simple module into a relative token stream" do
      text = "defmodule Foo do\n  def bar(x), do: x\nend\n"
      assert {:ok, %GenLSP.Structures.SemanticTokens{data: data}} = SemanticTokens.full(sf(text))
      assert is_list(data)
      assert rem(length(data), 5) == 0

      decoded = decode(data)

      # `Foo` is a class definition on line 0.
      assert Enum.any?(decoded, fn {l, _s, _len, t, m} ->
               l == 0 and t == "class" and "definition" in m
             end)

      # `bar` is a function definition on line 1.
      assert Enum.any?(decoded, fn {l, _s, _len, t, m} ->
               l == 1 and t == "function" and "definition" in m
             end)
    end

    test "first token's delta-line is absolute and deltas are non-negative within a line" do
      {:ok, %{data: data}} = SemanticTokens.full(sf("alias Foo.Bar\n"))
      [dl0, ds0 | _] = data
      assert dl0 >= 0
      assert ds0 >= 0
    end

    test "UTF-16: a token after an emoji has a correctly offset start" do
      # "🚀" is 2 UTF-16 code units. `x` sits at codepoint col 3 → UTF-16 col 4.
      text = ~s(x = "🚀" <> y)
      {:ok, %{data: data}} = SemanticTokens.full(sf(text))
      decoded = decode(data)

      # `y` is a variable; its UTF-16 start must account for the surrogate pair.
      assert Enum.any?(decoded, fn {l, s, _len, t, _m} ->
               l == 0 and t == "variable" and s == byte_like_utf16_col(text, "y")
             end)
    end

    test "returns an empty stream for empty input, never raises" do
      assert {:ok, %{data: []}} = SemanticTokens.full(sf(""))
      assert {:ok, %{data: data}} = SemanticTokens.full(sf("@@@ (("))
      assert is_list(data)
    end

    test "explicit delta stream for two tokens on one line" do
      # `x = 1` → `x` variable at col 0 len 1, `1` number at col 4 len 1.
      {:ok, %{data: data}} = SemanticTokens.full(sf("x = 1"))
      types = SemanticTokens.legend().token_types
      var = Enum.find_index(types, &(&1 == "variable"))
      num = Enum.find_index(types, &(&1 == "number"))

      assert data == [0, 0, 1, var, 0, 0, 4, 1, num, 0]
    end

    test "multiple modifiers pack into one bitset (__MODULE__ is readonly + defaultLibrary)" do
      {:ok, %{data: data}} = SemanticTokens.full(sf("x = __MODULE__"))

      assert Enum.any?(decode(data), fn {_l, _s, _len, t, m} ->
               t == "variable" and "readonly" in m and "defaultLibrary" in m
             end)
    end

    test "CRLF line endings do not shift lines or columns" do
      {:ok, %{data: data}} = SemanticTokens.full(sf("a = 1\r\nb = 2\r\n"))
      decoded = decode(data)

      assert Enum.any?(decoded, fn {l, s, _len, t, _m} -> l == 1 and s == 0 and t == "variable" end)
    end

    test "many emoji on one line: every start matches an independent UTF-16 count" do
      # Exercises the per-line running cursor across repeated surrogate pairs.
      text = "v1 = \"🚀🚀\" <> v2 <> \"🚀\" <> v3"
      {:ok, %{data: data}} = SemanticTokens.full(sf(text))

      starts =
        decode(data)
        |> Enum.filter(fn {_l, _s, _len, t, _m} -> t == "variable" end)
        |> Enum.map(fn {_l, s, _len, _t, _m} -> s end)

      assert starts == [
               byte_like_utf16_col(text, "v1"),
               byte_like_utf16_col(text, "v2"),
               byte_like_utf16_col(text, "v3")
             ]
    end
  end

  describe "range/2" do
    test "only emits tokens on lines within the range" do
      text = "a = 1\nb = 2\nc = 3\n"
      range = %Range{start: %Position{line: 1, character: 0}, end: %Position{line: 1, character: 5}}
      {:ok, %{data: data}} = SemanticTokens.range(sf(text), range)
      decoded = decode(data)

      assert Enum.all?(decoded, fn {l, _s, _len, _t, _m} -> l == 1 end)
      assert Enum.any?(decoded, fn {l, _s, _len, t, _m} -> l == 1 and t == "variable" end)
    end

    test "the LSP end position is exclusive — a token on the end line at char 0 is excluded" do
      text = "a = 1\nb = 2\nc = 3\n"
      # Range covers lines 0..1 with an exclusive end at the start of line 2.
      range = %Range{start: %Position{line: 0, character: 0}, end: %Position{line: 2, character: 0}}
      {:ok, %{data: data}} = SemanticTokens.range(sf(text), range)
      decoded = decode(data)

      # `c` lives on line 2 and must NOT be returned.
      refute Enum.any?(decoded, fn {l, _s, _len, _t, _m} -> l == 2 end)
      # lines 0 and 1 are present
      assert Enum.any?(decoded, fn {l, _s, _len, _t, _m} -> l == 0 end)
      assert Enum.any?(decoded, fn {l, _s, _len, _t, _m} -> l == 1 end)
    end

    test "a token on the end line IS included when the range extends into it" do
      text = "a = 1\nb = 2\nc = 3\n"
      range = %Range{start: %Position{line: 0, character: 0}, end: %Position{line: 2, character: 3}}
      {:ok, %{data: data}} = SemanticTokens.range(sf(text), range)
      assert Enum.any?(decode(data), fn {l, _s, _len, _t, _m} -> l == 2 end)
    end
  end

  # The UTF-16 column of the first occurrence of `needle` in `line` (single-line helper).
  defp byte_like_utf16_col(line, needle) do
    [before, _] = String.split(line, needle, parts: 2)
    before |> :unicode.characters_to_binary(:utf8, :utf16) |> byte_size() |> div(2)
  end
end
