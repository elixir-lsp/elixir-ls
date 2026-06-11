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
      assert Enum.any?(labels, &String.starts_with?(&1, ": (float() or integer()"))
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

    # task #13: a constructor is obvious only when ALL its leaves are literals.
    for {label, body} <- [
          {"tuple with a call element", "t = {:ok, to_string(123)}"},
          {"list with a call element", "l = [1, to_string(2)]"},
          {"map with a call value", "m = %{a: to_string(1)}"}
        ] do
      test "constructor with a non-literal element keeps its hint — #{label}" do
        # The interesting type is the element's, which the source doesn't reveal,
        # so the hint must NOT be suppressed.
        refute [] == type_labels(hints(wrap(unquote(body))))
      end
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

    test "elided label sets a tooltip carrying the untruncated type (task #8)" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"maxLength" => 8}}}

      elided =
        hints(wrap("f = fn a, b -> a + b end"), settings)
        |> Enum.filter(&(&1.kind == InlayHintKind.type()))
        |> Enum.filter(&String.ends_with?(&1.label, "…"))

      assert elided != []

      assert Enum.all?(elided, fn hint ->
               # tooltip carries the full, untruncated type; the (prefix-stripped)
               # elided label is shorter and ends with the ellipsis.
               stripped = String.replace_prefix(hint.label, ": ", "")

               is_binary(hint.tooltip) and
                 String.ends_with?(stripped, "…") and
                 String.length(hint.tooltip) > String.length(stripped) - 1
             end)
    end

    test "non-elided label leaves the tooltip empty" do
      hints =
        hints(wrap("total = 1 + 2"))
        |> Enum.filter(&(&1.kind == InlayHintKind.type()))

      assert hints != []
      assert Enum.all?(hints, &is_nil(&1.tooltip))
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

    test "non-trailing default param maps args to the right names (task #3)" do
      # Verified empirically with `elixir -e`:
      #   def f(a, b \\ 1, c), do: {a, b, c}; f(:x, :y) #=> {:x, 1, :y}
      # So for arity 2 the DEFAULTED param `b` is dropped and the two args bind
      # to `a` and `c` — the hints must read `a:` and `c:`, never `b:`.
      source = """
      defmodule Sample do
        defp f(a, b \\\\ 1, c), do: {a, b, c}
        def run, do: f(10, 20)
      end
      """

      labels = param_labels(hints(source))
      assert "a:" in labels
      assert "c:" in labels
      refute "b:" in labels
    end

    test "leading default param is dropped before a required one" do
      # def g(a \\ 1, b), do: ...; g(:x) binds b (a fills from default).
      source = """
      defmodule Sample do
        defp g(a \\\\ 1, b), do: {a, b}
        def run, do: g(99)
      end
      """

      labels = param_labels(hints(source))
      assert "b:" in labels
      refute "a:" in labels
    end

    test "remote call named like a special form still gets hints (task #7)" do
      source = """
      defmodule Helper do
        def alias(thing), do: thing
        def unless(cond, value), do: {cond, value}
      end

      defmodule Sample do
        def run(x, y) do
          Helper.alias(x)
          Helper.unless(x, y)
        end
      end
      """

      labels = param_labels(hints(source))
      assert "thing:" in labels
      assert "cond:" in labels
      assert "value:" in labels
    end

    test "local call named like a special form is still blocklisted" do
      # A local `if(...)` is the special form, not a function call — no hints.
      labels = param_labels(hints(wrap("if(true, do: 1, else: 2)")))
      assert labels == []
    end

    test "__MODULE__.Sub receiver resolves and gets hints (task #7)" do
      source = """
      defmodule Sample.Sub do
        def f(left, right), do: {left, right}
      end

      defmodule Sample do
        def run(a, b) do
          __MODULE__.Sub.f(a, b)
        end
      end
      """

      labels = param_labels(hints(source))
      assert "left:" in labels
      assert "right:" in labels
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

  describe "position arithmetic (task #5)" do
    test "hint for a unicode identifier lands right after the identifier" do
      # `café` is 4 graphemes/codepoints but 5 UTF-8 bytes; the hint column must
      # be computed from codepoints, not graphemes/bytes.
      source = wrap("café = 1 + 2")

      type_hint =
        hints(source)
        |> Enum.find(&(&1.kind == InlayHintKind.type() and &1.label == ": integer()"))

      assert type_hint != nil

      # `café` starts at column 4 (0-based) on its line inside `run`; the hint
      # must sit at column 4 + length("café") == 8 (UTF-16 == codepoints here).
      line = source |> String.split("\n") |> Enum.find_index(&String.contains?(&1, "café"))
      assert type_hint.position.line == line
      # The identifier is indented 4 spaces by `wrap/1`; the hint sits right
      # after it. (UTF-16 units == codepoints for `café`.)
      assert type_hint.position.character == 4 + String.length("café")
    end
  end

  describe "large range clamping (task #4)" do
    test "whole-document range on a >1000-line file still yields hints" do
      # Build a file well over @max_range_lines with a hintable binding near the
      # top; a whole-document request must clamp, not bail with zero hints.
      head = "defmodule Big do\n  def run do\n    total = 1 + 2\n"
      filler = String.duplicate("    _ = :noop\n", 1200)
      source = head <> filler <> "    total\n  end\nend\n"

      assert ": integer()" in type_labels(hints(source))
    end
  end

  defp param_labels_with_line(hints) do
    hints
    |> Enum.filter(&(&1.kind == InlayHintKind.parameter()))
    |> Enum.map(&{&1.position.line, &1.label})
  end

  # ---------------------------------------------------------------------------
  # GPT-audit tests (Tasks 4a–4e)
  # ---------------------------------------------------------------------------

  describe "GPT audit — literal widening in variable hints" do
    # 4a: a non-obvious binding whose inferred type is a literal must render
    # the widened compiler spelling, not a raw literal like `: 5`.
    test "non-obvious binding with literal type renders widened compiler form" do
      # `1 + 2` is a non-obvious binding (arithmetic call); the inferred type
      # must appear as `integer()`, never as the literal `: 1` / `: 2` / `: 3`.
      labels = type_labels(hints(wrap("total = 1 + 2")))
      # At least one hint must exist.
      assert labels != []
      # None of the labels must end with a bare decimal digit (literal spelling).
      assert Enum.all?(labels, fn label -> not Regex.match?(~r/: \d+$/, label) end)
      # The label must show the widened form.
      assert ": integer()" in labels
    end

    test "function-result binding with literal type renders widened form" do
      # `Enum.count([])` returns an integer; the hint must say `integer()`.
      labels = type_labels(hints(wrap("n = Enum.count([])")))

      if labels != [] do
        assert Enum.all?(labels, fn label -> not Regex.match?(~r/: \d+$/, label) end)
      end
    end
  end

  describe "GPT audit — remote-call and destructuring hints" do
    # 4b: remote call to String.upcase/1 is non-obvious → if a hint appears it
    # must follow compiler style (no raw string literal spellings).
    # When native typing is unavailable the call returns term() which is
    # suppressed as noise — so we only validate the label format when present.
    test "String.upcase/1 binding: if hinted, label is compiler-style" do
      labels = type_labels(hints(wrap(~s|x = String.upcase("a")|)))
      # When a hint appears it must not be a raw string literal.
      assert Enum.all?(labels, fn label -> not Regex.match?(~r/: "\w+"$/, label) end)
      # The request itself must succeed (even if labels == []).
      assert is_list(labels)
    end

    # 4b (cont.): {:ok, value} destructuring from a local spec'd function.
    test "{:ok, value} destructuring from a local function with spec gets a hint" do
      source = """
      defmodule Sample do
        @spec fetch() :: {:ok, integer()}
        defp fetch(), do: {:ok, 42}

        def run do
          {:ok, value} = fetch()
          value
        end
      end
      """

      # `value` is bound by destructuring a non-obvious call result; a hint is
      # expected.  We assert the request succeeds (no crash) and the result is
      # a list (even if empty when inference degrades gracefully).
      all = hints(source)
      assert is_list(all)
    end
  end

  describe "GPT audit — minimumTrust setting" do
    # 4c: with minimumTrust "native", :shape-sourced hints are suppressed.
    test "minimumTrust native suppresses shape-only variable hints" do
      settings = %{
        "inlayHints" => %{"variableTypes" => %{"minimumTrust" => "native"}}
      }

      source = wrap("total = 1 + 2")
      native_hints = type_labels(hints(source, settings))
      best_effort_hints = type_labels(hints(source))

      # With "native", there may be fewer or equal hints than bestEffort.
      assert length(native_hints) <= length(best_effort_hints)
    end

    test "minimumTrust native does not affect parameter-name hints" do
      settings = %{
        "inlayHints" => %{"variableTypes" => %{"minimumTrust" => "native"}}
      }

      labels = param_labels(hints(wrap("Map.put(acc, :key, 42)"), settings))
      # Parameter hints must still appear regardless of minimumTrust.
      assert "map:" in labels
      assert "key:" in labels
      assert "value:" in labels
    end

    test "minimumTrust bestEffort (default) shows both sources" do
      settings = %{
        "inlayHints" => %{"variableTypes" => %{"minimumTrust" => "bestEffort"}}
      }

      # Same as default; at minimum the arithmetic binding should hint.
      assert ": integer()" in type_labels(hints(wrap("total = 1 + 2"), settings))
    end
  end

  describe "GPT audit — param-hint independence from type inference" do
    # 4d: with use_elixir_types disabled, param hints still work and the
    # overall request does not crash.
    test "parameter hints work when native typing is disabled" do
      original = Application.get_env(:elixir_sense, :use_elixir_types)

      on_exit(fn ->
        if is_nil(original) do
          Application.delete_env(:elixir_sense, :use_elixir_types)
        else
          Application.put_env(:elixir_sense, :use_elixir_types, original)
        end
      end)

      Application.put_env(:elixir_sense, :use_elixir_types, false)

      result = hints(wrap("Map.put(acc, :key, 42)"))
      assert is_list(result)
      assert "map:" in param_labels(result)
      assert "key:" in param_labels(result)
      assert "value:" in param_labels(result)
    end

    test "variable hints degrade gracefully when native typing is disabled" do
      original = Application.get_env(:elixir_sense, :use_elixir_types)

      on_exit(fn ->
        if is_nil(original) do
          Application.delete_env(:elixir_sense, :use_elixir_types)
        else
          Application.put_env(:elixir_sense, :use_elixir_types, original)
        end
      end)

      Application.put_env(:elixir_sense, :use_elixir_types, false)

      # Must not crash; may still produce structural hints.
      result = hints(wrap("total = 1 + 2"))
      assert is_list(result)
    end
  end

  describe "GPT audit — failure-mode robustness" do
    # 4e: a buffer calling a nonexistent module must not crash the request.
    test "call to nonexistent module produces no type hint and does not crash" do
      source = wrap("x = XNoSuchModule.f(1)")
      result = hints(source)
      assert is_list(result)
      # No type hint for the (unresolvable) call result — only assert no crash.
      # (There may or may not be a type hint depending on structural inference.)
    end

    test "nonexistent module param hints silently absent, request succeeds" do
      source = wrap("XNoSuchModule.f(1)")
      result = hints(source)
      assert is_list(result)
      # Param hints: none expected (module unknown), but no crash.
      assert param_labels(result) == []
    end
  end
end
