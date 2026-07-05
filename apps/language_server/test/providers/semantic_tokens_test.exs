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
