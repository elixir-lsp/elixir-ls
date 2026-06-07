defmodule ElixirLS.LanguageServer.Providers.InlayHintsTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.InlayHints
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder

  defp hints(source, settings \\ %{}) do
    parser_context = ParserContextBuilder.from_string(source)
    range = SourceFile.full_range(parser_context.source_file)

    {:ok, hints} = InlayHints.inlay_hints(parser_context, range, settings: settings)
    hints
  end

  defp labels(hints), do: Enum.map(hints, & &1.label)

  defp wrap(body) do
    indented = body |> String.split("\n") |> Enum.map_join("\n", &("    " <> &1))
    "defmodule Sample do\n  def run(arg) do\n" <> indented <> "\n    arg\n  end\nend\n"
  end

  describe "variable type hints — precision from the type engine" do
    test "integer literal binding" do
      assert ": 42" in labels(hints(wrap("value = 42")))
    end

    test "binary literal binding" do
      assert ~s(: "hi") in labels(hints(wrap(~s(text = "hi"))))
    end

    test "tuple literal binding" do
      assert ": {:ok, 1}" in labels(hints(wrap("pair = {:ok, 1}")))
    end

    test "map literal binding renders field types" do
      assert ~s(: %{a: 1, b: "s"}) in labels(hints(wrap(~s(m = %{a: 1, b: "s"}))))
    end

    test "list literal binding" do
      assert ": [1]" in labels(hints(wrap("list = [1, 2, 3]")))
    end

    test "struct binding renders struct shape" do
      hint_labels = labels(hints(wrap(~s|u = URI.parse("http://example.com")|)))
      assert Enum.any?(hint_labels, &String.starts_with?(&1, ": %URI{"))
    end

    test "function binding renders an arrow" do
      assert ": (term(), term() -> term())" in labels(hints(wrap("f = fn a, b -> a + b end")))
    end
  end

  describe "suppression" do
    test "uninformative types (unresolved calls) are skipped" do
      # `to_string/1` is an unresolved remote-call thunk here -> render_hint :skip
      assert [] == hints(wrap("only = to_string(123)"))
    end

    test "underscore-prefixed variables are ignored" do
      assert [] == hints(wrap("_ignored = 42"))
    end

    test "labels always carry the leading colon" do
      for label <- labels(hints(wrap("value = 42"))) do
        assert String.starts_with?(label, ": ")
      end
    end
  end

  describe "binding vs read occurrences" do
    test "by default only the binding is annotated, not reads" do
      source =
        wrap("""
        value = 42
        _ = value
        _ = value
        """)

      assert Enum.count(labels(hints(source)), &(&1 == ": 42")) == 1
    end

    test "showOnlyBindings=false annotates reads too" do
      source =
        wrap("""
        value = 42
        other = value
        """)

      settings = %{"inlayHints" => %{"variableTypes" => %{"showOnlyBindings" => false}}}

      assert Enum.count(labels(hints(source, settings)), &(&1 == ": 42")) >= 2
    end
  end

  describe "settings" do
    test "respects the enabled toggle" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"enabled" => false}}}
      assert [] == hints(wrap("value = 42"), settings)
    end

    test "maxLength truncates long labels with an ellipsis" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"maxLength" => 8}}}
      hint_labels = labels(hints(wrap(~s|u = URI.parse("http://example.com")|), settings))

      truncated = Enum.filter(hint_labels, &String.ends_with?(&1, "…"))
      assert truncated != []
      assert Enum.all?(truncated, &(String.length(&1) <= String.length(": ") + 8))
    end
  end
end
