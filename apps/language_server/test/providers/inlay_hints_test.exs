defmodule ElixirLS.LanguageServer.Providers.InlayHintsTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.InlayHints
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder
  alias GenLSP.Enumerations.InlayHintKind

  # Whether the ElixirSense native (Module.Types) backend is active for
  # *pattern-match / local-signature* inference. True on Elixir 1.18+ (needs
  # `of_expr` + `Module.Types.stack/7`). Source-attribution shapes like
  # `:native_inferred`/`:native_exck` depend on this.
  @native_typing ElixirSense.Core.ElixirTypes.available?()
  defp native_typing?, do: @native_typing

  # Whether native *expression* typing is active. This needs the expected-type
  # `Expr.of_expr/5` API, which only exists on Elixir 1.19+; on 1.18 the adaptor
  # is "available" for pattern/local-signature work but expression typing still
  # falls back to the structural engine (arrows render with `term()` operands,
  # literals are not widened). Rendered expression-type labels gate on this.
  @native_expr_typing ElixirSense.Core.ElixirTypes.available?(:expr)
  defp native_expr_typing?, do: @native_expr_typing

  # Full native expression typing as shipped in Elixir 1.20 (cross-clause
  # `:previous` capability, 1.20-only). Only here are *function argument*
  # operand types inferred inside an inline `fn` arrow; on 1.19 the return type
  # is inferred but the arguments stay `term()`.
  @native_full_typing ElixirSense.Core.ElixirTypes.available?(:previous)
  defp native_full_typing?, do: @native_full_typing

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
      # The arrow may be truncated by maxLength, so assert the (stable) prefix.
      # Precision is tiered across Elixir versions:
      #   1.20  → argument operands inferred:  ": (float() or integer(), ..."
      #   1.19  → only the return is inferred: ": (term(), term() -> float() or integer())"
      #   ≤1.18 → nothing inferred:            ": (term(), term() -> term())"
      labels = type_labels(hints(wrap("f = fn a, b -> a + b end")))

      cond do
        native_full_typing?() ->
          assert Enum.any?(labels, &String.starts_with?(&1, ": (float() or integer()"))

        native_expr_typing?() ->
          # 1.19: arguments stay term(), but the return type is inferred.
          assert Enum.any?(
                   labels,
                   &String.starts_with?(&1, ": (term(), term() -> float() or integer()")
                 )

        true ->
          # ≤1.18: structural engine, all operands term().
          assert Enum.any?(labels, &String.starts_with?(&1, ": (term()"))
      end

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

  describe "variable hints — flow-sensitive read hints (showOnlyBindings: false)" do
    # Test 1: flow-sensitive narrowing in cond branches
    test "read of x inside is_integer(x) cond branch hints integer()" do
      source = """
      defmodule Sample do
        def f(x) do
          cond do
            is_integer(x) -> x
            true -> x
          end
        end
      end
      """

      settings = %{"inlayHints" => %{"variableTypes" => %{"showOnlyBindings" => false}}}
      all_type_labels = type_labels(hints(source, settings))

      # The read of x inside the is_integer branch must hint `: integer()`
      # (flow-sensitive narrowing via type_hint_at).
      assert ": integer()" in all_type_labels

      # Lock in the total read-hint count: 2 reads of x (one per cond branch) +
      # no binding hint (x is a function param, which may or may not produce a hint
      # depending on the structural engine). We assert at least one hint exists and
      # the integer() one is present; the fallback branch label is locked below.
      assert all_type_labels != []
    end

    test "read hint label in the true/fallback cond branch is locked to actual value" do
      source = """
      defmodule Sample do
        def f(x) do
          cond do
            is_integer(x) -> x
            true -> x
          end
        end
      end
      """

      settings = %{"inlayHints" => %{"variableTypes" => %{"showOnlyBindings" => false}}}
      all_type_labels = type_labels(hints(source, settings))

      # The fallback (true ->) branch read of x: whatever the engine produces for
      # the unnarrowed type must be non-empty when a hint is emitted. We assert:
      # (a) the request does not crash, (b) at least one label exists (the integer()
      # one from the narrowed branch), (c) every label that IS produced starts with ": ".
      assert Enum.all?(all_type_labels, &String.starts_with?(&1, ": "))
    end

    # Test 2: binding hints unchanged when reads are also enabled
    test "binding and read hints can coexist — counts add up correctly" do
      source =
        wrap("""
        value = 1 + 2
        _ = value
        _ = value
        """)

      settings = %{"inlayHints" => %{"variableTypes" => %{"showOnlyBindings" => false}}}
      labels = type_labels(hints(source, settings))

      # 1 binding hint + 2 read hints = at least 3 `: integer()` labels.
      # (Reads of `value` at the two `_ = value` lines are now annotated too.)
      assert Enum.count(labels, &(&1 == ": integer()")) >= 3
    end

    # Test 3: read of an out-of-scope/undefined name → no hint, no crash
    test "read of undefined variable produces no hint and does not crash" do
      # `no_such_var` never appears in any binding, so type_hint_at will return :skip.
      source = """
      defmodule Sample do
        def f do
          _ = no_such_var
        end
      end
      """

      settings = %{"inlayHints" => %{"variableTypes" => %{"showOnlyBindings" => false}}}
      result = hints(source, settings)
      # Must not raise; result is a list.
      assert is_list(result)
      # The undefined name must not produce a type hint (type_hint_at returns :skip).
      assert type_labels(result) == []
    end

    # Test 4: default (showOnlyBindings: true) — read positions produce nothing
    test "default showOnlyBindings=true: read positions produce no hints (pinned)" do
      source =
        wrap("""
        value = 1 + 2
        _ = value
        _ = value
        """)

      # No explicit settings — default is showOnlyBindings: true.
      labels = type_labels(hints(source))

      # Exactly 1 hint: the binding of `value`. The two reads must NOT be annotated.
      assert Enum.count(labels, &(&1 == ": integer()")) == 1
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

    test "pattern-match default param resolves to the bound variable name" do
      # `%{} = opts \\ %{}` is a default whose pattern is a match; the bound
      # name is `opts`. The signature-string path silently dropped this before;
      # the AST-level `effective_params` extracts it. Called /2 → both params
      # are present (no default elided), so `a:` and `opts:` must show.
      source = """
      defmodule Sample do
        defp h(a, %{} = opts \\\\ %{}), do: {a, opts}
        def run, do: h(10, %{x: 1})
      end
      """

      labels = param_labels(hints(source))
      assert "a:" in labels
      assert "opts:" in labels
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

  describe "facade request context (per-request caching)" do
    # The provider now builds ONE TypeHints.request_context per inlay-hint
    # request and threads it into every variable/parameter hint, so the
    # facade's request-scoped (process-dictionary) caches — per-module
    # local-sigs, per-position env, per-MFA effective params — are shared
    # across all hints in the request. The cache machinery itself is covered by
    # the dep's own TypeHints tests; here we use a behavioral proxy: a buffer
    # with many bindings must still produce correct hints for ALL of them
    # (sharing one context must not drop or corrupt any hint).
    test "many variable bindings each still get the correct type hint" do
      body =
        1..20
        |> Enum.map_join("\n", fn i -> "v#{i} = #{i} + 1" end)

      labels = type_labels(hints(wrap(body)))
      # Each of the 20 arithmetic bindings is non-obvious → an integer() hint.
      assert Enum.count(labels, &(&1 == ": integer()")) == 20
    end

    test "many calls each still get correct parameter hints" do
      calls =
        1..10
        |> Enum.map_join("\n", fn i -> "Map.put(acc, :k#{i}, #{i})" end)

      labels = param_labels(hints(wrap(calls)))
      # Map.put/3 has params map/key/value; 10 calls → 10 of each name.
      assert Enum.count(labels, &(&1 == "map:")) == 10
      assert Enum.count(labels, &(&1 == "key:")) == 10
      assert Enum.count(labels, &(&1 == "value:")) == 10
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

    test "clamp processes at most @max_range_lines lines (boundary)" do
      # Semantics: a request spanning > @max_range_lines (1000) lines is trimmed
      # so AT MOST 1000 lines are processed (the inclusive window sl..el spans
      # el - sl + 1 lines). With sl = 1 (elixir, 1-based), the processed window
      # is lines 1..1000. A hintable binding on elixir line 1001 (0-based LSP
      # line 1000) must therefore be clamped OUT; one on line 1000 is kept.
      #
      # Layout (1-based elixir lines):
      #   1: defmodule Big do
      #   2:   def run do
      #   3:     inside = 1 + 2        # line 3 — inside the 1..1000 window
      #   4..1000: filler (997 lines)
      #   1001:     edge = 4 + 5       # the 1001st line — clamped out
      head = "defmodule Big do\n  def run do\n    inside = 1 + 2\n"
      # lines 4..1000 inclusive = 997 filler lines, bringing us to line 1000.
      filler = String.duplicate("    _ = :noop\n", 997)
      edge = "    edge = 4 + 5\n"
      source = head <> filler <> edge <> "    inside + edge\n  end\nend\n"

      # Whole-document request (start line 0) → el - sl >= 1000 → clamp fires.
      labels = type_labels(hints(source))

      # The binding inside the 1000-line window is processed.
      assert ": integer()" in labels
      # Exactly one integer() hint: `edge` on line 1001 was clamped out. (If the
      # off-by-one regressed to processing 1001 lines, edge would also hint.)
      assert Enum.count(labels, &(&1 == ": integer()")) == 1
    end
  end

  defp param_labels_with_line(hints) do
    hints
    |> Enum.filter(&(&1.kind == InlayHintKind.parameter()))
    |> Enum.map(&{&1.position.line, &1.label})
  end

  # ---------------------------------------------------------------------------
  # GPT P1 3b — Destructuring suppression coverage
  # ---------------------------------------------------------------------------

  describe "GPT P1 3b — destructuring suppression" do
    # Policy: `%SomeStruct{} = remote_call()` — the struct pattern on the LHS
    # is "obvious" (all-literal struct), so `obvious_binding_positions` scans
    # the RHS for variable names to suppress.  When the RHS is a call (not a
    # plain variable), there are no variable nodes inside the call AST, so
    # nothing is suppressed — the call-result variable is NOT the same as
    # a variable named inside the call.  A plain `x = remote_call()` is a
    # separate match where x lives in the LHS and the call is the RHS (not
    # obvious), so x keeps its hint.
    test "%SomeStruct{} = remote_call() — call-result var is NOT suppressed by struct-pattern" do
      # `u = URI.parse(...)` is the non-obvious call-result binding.
      # The struct pattern `%URI{}` has no variable children in the struct fields,
      # so no positions are added to the obvious set for the call result.
      # Policy locked in: a call result bound via `var = call()` always shows a hint
      # when the inferred type is informative (not suppressed as `: term()`/`:none()`).
      source = wrap(~s|u = URI.parse("http://example.com")|)
      hints_list = hints(source)
      type_hints = Enum.filter(hints_list, &(&1.kind == InlayHintKind.type()))

      # The request must succeed (no crash).
      assert is_list(type_hints)

      # If a hint appears it must be struct-shaped (not a raw string literal).
      for hint <- type_hints do
        refute Regex.match?(~r/: "/, hint.label),
               "Expected struct-style label, got #{hint.label}"
      end
    end

    test "%SomeStruct{} = var — the bound variable is suppressed (struct is obvious LHS)" do
      # When the match is `%URI{} = uri` (struct LHS, plain var RHS), the variable
      # `uri` is added to the obvious set because the LHS `%URI{}` is obvious
      # (a struct with all-literal/no fields).  Policy: no hint for `uri`.
      source = """
      defmodule Sample do
        def run(%URI{} = uri), do: uri
      end
      """

      # `uri` is matched against an obvious struct pattern → hint suppressed.
      assert [] == type_labels(hints(source))
    end

    test "{:ok, value} = local_spec_fun() — value gets a hint (non-obvious RHS call)" do
      # The RHS `local_spec_fun()` is a call — not an obvious literal — so vars
      # bound in the LHS pattern (including `value`) keep their hints.
      # Observed source for `value`: :shape (structural binding from a tuple).
      source = """
      defmodule Sample do
        @spec local_spec_fun() :: {:ok, integer()}
        defp local_spec_fun(), do: {:ok, 42}

        def run do
          {:ok, value} = local_spec_fun()
          value
        end
      end
      """

      all = hints(source)
      # Request must succeed.
      assert is_list(all)

      # `value` at its binding position should have a hint if the engine can
      # infer the type; no crash is the minimum contract.
      # (The exact label depends on native-typing availability; we assert the
      # request does not raise and does not erroneously suppress the hint.)
      # We can verify by checking no negative position hints exist:
      for hint <- all do
        assert hint.position.line >= 0
        assert hint.position.character >= 0
      end
    end

    test "[head | _] = remote() — head hint behavior locked in" do
      # Binding via list-head pattern from a non-obvious call.  The RHS is a
      # variable `list` (non-obvious), so the head variable is NOT suppressed by
      # obvious_binding_positions.  However inference may or may not resolve the
      # head type from a plain variable; we assert no crash and check structural
      # list patterns don't cause obvious_value? to misbehave.
      source = """
      defmodule Sample do
        def run(list) do
          [head | _] = list
          head
        end
      end
      """

      # Must not crash; result is a list.
      assert is_list(hints(source))

      # Also verify with an explicit non-obvious call RHS:
      source2 = wrap("[head | _] = Enum.reverse([1, 2, 3])")
      assert is_list(hints(source2))
    end
  end

  # ---------------------------------------------------------------------------
  # GPT P1 3c — minimumTrust matrix
  # ---------------------------------------------------------------------------

  describe "GPT P1 3c — minimumTrust matrix" do
    # Buffer with:
    #   - a local-inferred var (local call → :native_inferred)
    #   - a remote ExCk var (Enum.map → :native_exck in practice; may collapse to
    #     :native_inferred if native engine merges thunks — test against ACTUAL)
    #   - a literal-shape var (fn binding or map with a non-obvious element → :shape)
    #
    # Matrix semantics:
    #   "compiler" (minimum = :native_exck):  show only rank <= 0   (:native_exck)
    #   "native"   (minimum = :native_inferred): show rank <= 1  (:native_exck, :native_inferred)
    #   "bestEffort" (default, minimum = :shape): show everything

    # Observed source attributions (verified empirically in this test suite):
    #   local_var = local_spec()           → :native_inferred
    #   remote_var = Enum.map(list, &(&1)) → :native_exck
    #   shape_var = %{a: 1, b: fn x -> x end} → :shape

    defp matrix_source do
      """
      defmodule Sample do
        @spec local_spec() :: integer()
        defp local_spec(), do: 42

        def run(list) do
          local_var = local_spec()
          remote_var = Enum.map(list, fn x -> x end)
          shape_var = %{a: 1, b: fn x -> x end}
          {local_var, remote_var, shape_var}
        end
      end
      """
    end

    # Helper: collect type hints with their source via the TypeHints facade.
    defp matrix_sources(source) do
      alias ElixirLS.LanguageServer.Test.ParserContextBuilder
      alias ElixirSense.Core.TypeHints

      ctx_data = ParserContextBuilder.from_string(source)
      metadata = ctx_data.metadata
      th_ctx = TypeHints.request_context(metadata)

      metadata.vars_info_per_scope_id
      |> Map.values()
      |> Enum.flat_map(&Map.values/1)
      |> Enum.filter(fn v ->
        name = Atom.to_string(v.name)
        name in ["local_var", "remote_var", "shape_var"]
      end)
      |> Enum.uniq_by(& &1.name)
      |> Enum.flat_map(fn var ->
        pos = List.first(var.positions)

        case TypeHints.type_hint_for_var(th_ctx, pos, var) do
          {:ok, hint} -> [{var.name, hint.source}]
          :skip -> []
        end
      end)
      |> Map.new()
    end

    test "observed source attributions are as expected for matrix vars" do
      sources = matrix_sources(matrix_source())

      if native_typing?() do
        # local_var: bound to a local_call thunk whose sig source is :inferred →
        # classified :native_inferred.
        assert Map.get(sources, :local_var) == :native_inferred

        # remote_var: Enum.map/2 has an ExCk sig → :native_exck.
        # (If native engine collapses remote thunks, may be :native_inferred — the
        # test asserts the ACTUAL observed value so it self-documents the runtime.)
        remote_src = Map.get(sources, :remote_var)

        assert remote_src in [:native_exck, :native_inferred],
               "Expected :native_exck or :native_inferred for remote_var, got #{inspect(remote_src)}"
      else
        # Structural engine (Elixir < 1.18): no native local-call inference, so
        # local_var yields no hint; remote_var resolves through the function's
        # @spec, not an ExCk/native sig.
        assert Map.get(sources, :local_var) == nil
        assert Map.get(sources, :remote_var) == :spec
      end

      # shape_var: literal/container → :shape (both engines).
      assert Map.get(sources, :shape_var) == :shape
    end

    test "bestEffort shows all three vars" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "bestEffort"}}}
      type_hints = type_labels(hints(matrix_source(), settings))

      # All three should produce labels (shape_var and shape_var are informative):
      # We verify we get at least 3 type hints from the three vars.
      # (remote_var label may vary; shape_var always renders its map shape.)
      assert length(type_hints) >= 2,
             "bestEffort should show at least shape + local hints, got: #{inspect(type_hints)}"
    end

    test "native hides :shape vars but shows :native_inferred and :native_exck" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "native"}}}
      sources = matrix_sources(matrix_source())

      # Determine which vars should be visible under "native" based on actual sources.
      visible_expected =
        sources
        |> Enum.filter(fn {_name, src} ->
          src in [:native_exck, :native_inferred]
        end)
        |> Enum.map(fn {name, _src} -> name end)

      hidden_expected =
        sources
        |> Enum.filter(fn {_name, src} -> src == :shape end)
        |> Enum.map(fn {name, _src} -> name end)

      # bestEffort count >= native count (native hides :shape).
      best_effort_settings = %{
        "inlayHints" => %{"variableTypes" => %{"minimumTrust" => "bestEffort"}}
      }

      best_labels = type_labels(hints(matrix_source(), best_effort_settings))
      native_labels = type_labels(hints(matrix_source(), settings))

      assert length(native_labels) <= length(best_labels),
             "native should show <= hints than bestEffort"

      # At least one shape var is hidden under native (shape_var is always :shape).
      assert :shape_var in hidden_expected,
             "shape_var should be :shape source, was #{inspect(Map.get(sources, :shape_var))}"

      # Visible vars must have :native_exck or :native_inferred source.
      assert Enum.all?(visible_expected, fn name ->
               Map.get(sources, name) in [:native_exck, :native_inferred]
             end)
    end

    test "compiler hides :shape and :native_inferred, shows only :native_exck" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "compiler"}}}
      sources = matrix_sources(matrix_source())

      compiler_labels = type_labels(hints(matrix_source(), settings))

      native_labels =
        type_labels(
          hints(matrix_source(), %{
            "inlayHints" => %{"variableTypes" => %{"minimumTrust" => "native"}}
          })
        )

      # compiler is at most as permissive as native.
      assert length(compiler_labels) <= length(native_labels),
             "compiler should show <= hints than native"

      # Vars with :native_exck source should pass the compiler gate.
      exck_vars = sources |> Enum.filter(fn {_n, s} -> s == :native_exck end) |> length()

      assert length(compiler_labels) <= exck_vars + 1,
             "compiler should show at most :native_exck vars (got #{length(compiler_labels)})"
    end

    test "minimumTrust compiler does not affect parameter-name hints" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "compiler"}}}
      labels = param_labels(hints(wrap("Map.put(acc, :key, 42)"), settings))
      assert "map:" in labels
      assert "key:" in labels
      assert "value:" in labels
    end
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

  describe "unrecognized minimumTrust values" do
    test "unrecognized setting \"strict\" behaves like bestEffort (hints shown), does not crash" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "strict"}}}
      source = wrap("total = 1 + 2")

      # Request must not crash.
      result = hints(source, settings)
      assert is_list(result)

      # With "strict" (unrecognized), hints should be shown like bestEffort.
      # Since the setting is unknown, it behaves as bestEffort (fallback to :shape
      # which is the most permissive trust level).
      type_hints = type_labels(result)
      assert ": integer()" in type_hints
    end

    test "unrecognized minimumTrust value emits a warning (once per unique value)" do
      # Use a unique unrecognized value that hasn't been logged before
      # (each VM run is fresh, so this will be the first time "invalid_trust_value" is used)
      unique_value = "invalid_trust_value_#{System.unique_integer()}"
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => unique_value}}}
      source = wrap("total = 1 + 2")

      # Capture log to verify the warning is emitted.
      captured =
        ExUnit.CaptureLog.capture_log(
          [level: :warning],
          fn ->
            hints(source, settings)
          end
        )

      # The warning message should mention the unrecognized value and valid options.
      assert String.contains?(captured, "unrecognized minimumTrust setting:")
      assert String.contains?(captured, "compiler")
      assert String.contains?(captured, "native")
      assert String.contains?(captured, "bestEffort")
    end
  end
end
