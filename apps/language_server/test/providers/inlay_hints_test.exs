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

  defp hints_in_range(source, {start_line, start_char}, {end_line, end_char}) do
    alias GenLSP.Structures.{Position, Range}
    parser_context = ParserContextBuilder.from_string(source)

    range = %Range{
      start: %Position{line: start_line, character: start_char},
      end: %Position{line: end_line, character: end_char}
    }

    {:ok, hints} = InlayHints.inlay_hints(parser_context, range, settings: %{})
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

  describe "variable type hints — non-obvious bindings" do
    test "renders the inferred type for an expression binding" do
      assert ": integer()" in type_labels(hints(wrap("total = 1 + 2")))
    end

    test "struct binding (from a call) renders struct shape" do
      type_hints = type_labels(hints(wrap(~s|u = URI.parse("http://example.com")|)))
      assert Enum.any?(type_hints, &String.starts_with?(&1, ": %URI{"))
    end

    test "function binding renders an arrow with inferred argument types" do
      # Native mode infers the arithmetic operand types; the full arrow may be
      # truncated by maxLength, so assert the (stable) prefix.
      labels = type_labels(hints(wrap("f = fn a, b -> a + b end")))
      assert Enum.any?(labels, &String.starts_with?(&1, ": (float() | integer()"))
      assert Enum.any?(labels, &String.contains?(&1, "->"))
    end
  end

  describe "variable hints — obvious literal bindings are skipped" do
    # When the RHS is a literal value or literal data constructor, the type is
    # already evident from the source, so no hint is rendered.
    for {label, body} <- [
          {"integer", "x = 1"},
          {"string", ~s(s = "foo")},
          {"atom", "a = :ok"},
          {"tuple", "t = {:ok, 1}"},
          {"map", "m = %{a: 1, b: 2}"},
          {"list", "l = [1, 2, 3]"},
          {"struct", "u = %URI{}"}
        ] do
      test "no hint for #{label} literal binding" do
        assert [] == type_labels(hints(wrap(unquote(body))))
      end
    end

    test "no hint when a bare variable is matched against an obvious pattern (match LHS)" do
      source = """
      defmodule Sample do
        def run(%URI{} = uri), do: uri
      end
      """

      assert [] == type_labels(hints(source))
    end
  end

  describe "variable hints — suppression" do
    test "uninformative types (unresolved calls) are skipped" do
      assert [] == type_labels(hints(wrap("only = to_string(123)")))
    end

    test "underscore-prefixed variables are ignored" do
      assert [] == type_labels(hints(wrap("_ignored = 1 + 2")))
    end

    test "labels always carry the leading colon" do
      labels = type_labels(hints(wrap("total = 1 + 2")))
      assert labels != []
      assert Enum.all?(labels, &String.starts_with?(&1, ": "))
    end
  end

  describe "variable hints — binding vs read occurrences" do
    test "by default only the binding is annotated, not reads" do
      source =
        wrap("""
        value = 1 + 2
        _ = value
        _ = value
        """)

      assert Enum.count(type_labels(hints(source)), &(&1 == ": integer()")) == 1
    end

    test "showOnlyBindings=false annotates reads too" do
      source =
        wrap("""
        value = 1 + 2
        other = value
        """)

      settings = %{"inlayHints" => %{"variableTypes" => %{"showOnlyBindings" => false}}}

      assert Enum.count(type_labels(hints(source, settings)), &(&1 == ": integer()")) >= 2
    end
  end

  describe "variable hints — settings" do
    test "respects the enabled toggle" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"enabled" => false}}}
      assert [] == type_labels(hints(wrap("total = 1 + 2"), settings))
    end

    test "maxLength truncates long labels with an ellipsis" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"maxLength" => 8}}}
      # The inferred fn type is long, so it gets truncated.
      type_hints = type_labels(hints(wrap("f = fn a, b -> a + b end"), settings))

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

  describe "call parameter-name hints — robustness" do
    test "dynamic remote receivers produce no hints and do not raise" do
      source = """
      defmodule Sample do
        def run(acc) do
          mod = Map
          mod.put(acc, :a, 1)
          factory().call(acc, :b)
        end
      end
      """

      # Must not raise (regression: raw AST receiver reaching Code.ensure_loaded/1).
      assert param_labels(hints(source)) == []
    end

    test "only calls intersecting the requested range are annotated" do
      source = """
      defmodule Sample do
        def run(acc) do
          Map.put(acc, :a, 1)
          Map.put(acc, :b, 2)
        end
      end
      """

      # 0-based lines: 2 = first Map.put, 3 = second Map.put. Request line 3 only.
      params = hints_in_range(source, {3, 0}, {3, 100}) |> param_labels_with_line()

      assert Enum.all?(params, fn {line, _label} -> line == 3 end)
      assert {3, "key:"} in params
      refute Enum.any?(params, fn {line, _label} -> line == 2 end)
    end

    test "hints are returned in document order" do
      source =
        wrap("""
        x = 1
        Map.put(acc, :key, 2)
        """)

      positions = hints(source) |> Enum.map(&{&1.position.line, &1.position.character})
      assert positions == Enum.sort(positions)
    end
  end

  defp param_labels_with_line(hints) do
    hints
    |> Enum.filter(&(&1.kind == InlayHintKind.parameter()))
    |> Enum.map(&{&1.position.line, &1.label})
  end
end
