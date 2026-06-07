defmodule ElixirLS.LanguageServer.Providers.InlayHintsTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.InlayHints
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder
  alias GenLSP.Enumerations.InlayHintKind

  defp hints(source, settings \\ %{}) do
    parser_context = ParserContextBuilder.from_string(source)
    range = SourceFile.full_range(parser_context.source_file)

    {:ok, hints} = InlayHints.inlay_hints(parser_context, range, settings: settings)
    hints
  end

  defp type_labels(hints) do
    hints |> Enum.filter(&(&1.kind == InlayHintKind.type())) |> Enum.map(& &1.label)
  end

  defp param_labels(hints) do
    hints |> Enum.filter(&(&1.kind == InlayHintKind.parameter())) |> Enum.map(& &1.label)
  end

  # Wrap a fragment in a module/function so it parses with a real env.
  defp wrap(body) do
    indented = body |> String.split("\n") |> Enum.map_join("\n", &("    " <> &1))
    "defmodule Sample do\n  def run(arg) do\n" <> indented <> "\n    arg\n  end\nend\n"
  end

  describe "variable type hints — precision from the type engine" do
    test "integer literal binding" do
      assert ": 42" in type_labels(hints(wrap("value = 42")))
    end

    test "binary literal binding" do
      assert ~s(: "hi") in type_labels(hints(wrap(~s(text = "hi"))))
    end

    test "tuple literal binding" do
      assert ": {:ok, 1}" in type_labels(hints(wrap("pair = {:ok, 1}")))
    end

    test "map literal binding renders field types" do
      assert ~s(: %{a: 1, b: "s"}) in type_labels(hints(wrap(~s(m = %{a: 1, b: "s"}))))
    end

    test "list literal binding" do
      assert ": [1]" in type_labels(hints(wrap("list = [1, 2, 3]")))
    end

    test "struct binding renders struct shape" do
      type_hints = type_labels(hints(wrap(~s|u = URI.parse("http://example.com")|)))
      assert Enum.any?(type_hints, &String.starts_with?(&1, ": %URI{"))
    end

    test "function binding renders an arrow" do
      assert ": (term(), term() -> term())" in type_labels(
               hints(wrap("f = fn a, b -> a + b end"))
             )
    end
  end

  describe "variable hints — suppression" do
    test "uninformative types (unresolved calls) are skipped" do
      assert [] == type_labels(hints(wrap("only = to_string(123)")))
    end

    test "underscore-prefixed variables are ignored" do
      assert [] == type_labels(hints(wrap("_ignored = 42")))
    end

    test "labels always carry the leading colon" do
      for label <- type_labels(hints(wrap("value = 42"))) do
        assert String.starts_with?(label, ": ")
      end
    end
  end

  describe "variable hints — binding vs read occurrences" do
    test "by default only the binding is annotated, not reads" do
      source =
        wrap("""
        value = 42
        _ = value
        _ = value
        """)

      assert Enum.count(type_labels(hints(source)), &(&1 == ": 42")) == 1
    end

    test "showOnlyBindings=false annotates reads too" do
      source =
        wrap("""
        value = 42
        other = value
        """)

      settings = %{"inlayHints" => %{"variableTypes" => %{"showOnlyBindings" => false}}}

      assert Enum.count(type_labels(hints(source, settings)), &(&1 == ": 42")) >= 2
    end
  end

  describe "variable hints — settings" do
    test "respects the enabled toggle" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"enabled" => false}}}
      assert [] == type_labels(hints(wrap("value = 42"), settings))
    end

    test "maxLength truncates long labels with an ellipsis" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"maxLength" => 8}}}
      type_hints = type_labels(hints(wrap(~s|u = URI.parse("http://example.com")|), settings))

      truncated = Enum.filter(type_hints, &String.ends_with?(&1, "…"))
      assert truncated != []
      assert Enum.all?(truncated, &(String.length(&1) <= String.length(": ") + 8))
    end
  end

  describe "call parameter-name hints" do
    test "annotates local call arguments with parameter names" do
      source = """
      defmodule Sample do
        defp add(left, right), do: left + right
        def run, do: add(1, 2)
      end
      """

      labels = param_labels(hints(source))
      assert "left:" in labels
      assert "right:" in labels
    end

    test "annotates remote call arguments" do
      labels = param_labels(hints(wrap("Map.put(acc, :key, 42)")))
      assert "map:" in labels
      assert "key:" in labels
      assert "value:" in labels
    end

    test "shifts the parameter window for piped calls" do
      labels = param_labels(hints(wrap("list |> Enum.map(fn x -> x end)")))
      # Enum.map/2: the piped `enumerable` is implicit; only `fun` is explicit.
      assert "fun:" in labels
      refute "enumerable:" in labels
    end

    test "does not annotate when the argument already matches the parameter name" do
      source = """
      defmodule Sample do
        defp add(left, right), do: left + right
        def run(left) do
          add(left, 9)
        end
      end
      """

      labels = param_labels(hints(source))
      refute "left:" in labels
      assert "right:" in labels
    end

    test "ignores commas inside string arguments" do
      labels = param_labels(hints(wrap(~s|String.split("a, b", ", ")|)))
      assert Enum.filter(labels, &(&1 in ["string:", "pattern:"])) == ["string:", "pattern:"]
    end

    test "does not split on commas inside fn arguments" do
      labels = param_labels(hints(wrap("Enum.reduce(arg, 0, fn x, acc -> x + acc end)")))
      # If the comma inside `fn x, acc ->` split the call's args, arity would be
      # 4 != 3 and the call would be skipped. Getting exactly the 3 params of
      # Enum.reduce/3 (enumerable, acc, fun) proves the fn body stayed intact.
      assert labels == ["enumerable:", "acc:", "fun:"]
    end

    test "respects the parameterNames toggle" do
      settings = %{"inlayHints" => %{"parameterNames" => %{"enabled" => false}}}
      assert [] == param_labels(hints(wrap("Map.put(acc, :key, 42)"), settings))
    end
  end
end
