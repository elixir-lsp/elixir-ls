defmodule ElixirLS.DebugAdapter.CoverageDataTest do
  use ExUnit.Case, async: true

  alias ElixirLS.DebugAdapter.CoverageData

  describe "ignored_function?/1" do
    test "skips underscore-prefixed (compiler/macro generated) functions" do
      assert CoverageData.ignored_function?(:__struct__)
      assert CoverageData.ignored_function?(:__info__)
      assert CoverageData.ignored_function?(:__impl__)
      assert CoverageData.ignored_function?(:_internal)
    end

    test "keeps ordinary functions" do
      refute CoverageData.ignored_function?(:foo)
      refute CoverageData.ignored_function?(:decode_payload)
      refute CoverageData.ignored_function?(:my_fun!)
    end
  end

  describe "branchable_clauses?/2" do
    test "true for multiple clauses on distinct lines" do
      assert CoverageData.branchable_clauses?([{1, 5}, {2, 0}], [10, 20])
      assert CoverageData.branchable_clauses?([{1, 5}, {2, 0}, {3, 1}], [10, 20, 30])
    end

    test "false for a single clause" do
      refute CoverageData.branchable_clauses?([{1, 5}], [10])
    end

    test "false when clauses collapse onto one line (generated dispatch)" do
      # e.g. `for ... do defp f(unquote(x)), do: ... end` lookup table
      refute CoverageData.branchable_clauses?([{1, 0}, {2, 5}, {3, 0}], [11, 11, 11])
    end

    test "false when cover clause count does not match source clause count" do
      refute CoverageData.branchable_clauses?([{1, 5}, {2, 0}, {3, 0}], [10, 20])
    end
  end

  describe "build/4 declaration (function) coverage" do
    setup do
      meta = %{
        MyMod => %{
          source: "/abs/my_mod.ex",
          defs: %{
            {:foo, 0} => %{line: 2, clause_lines: [2]},
            {:bar, 1} => %{line: 8, clause_lines: [8]},
            {:__struct__, 0} => %{line: 1, clause_lines: [1]}
          }
        }
      }

      {:ok, meta: meta}
    end

    test "emits per-function counts and skips underscored functions", %{meta: meta} do
      function_rows = [
        {{MyMod, :foo, 0}, 3},
        {{MyMod, :bar, 1}, 0},
        {{MyMod, :__struct__, 0}, 0}
      ]

      [file] = CoverageData.build([], function_rows, [], meta)

      assert file["file"] == "/abs/my_mod.ex"

      functions = Enum.sort_by(file["functions"], & &1["name"])

      assert functions == [
               %{"name" => "bar/1", "line" => 8, "count" => 0},
               %{"name" => "foo/0", "line" => 2, "count" => 3}
             ]
    end

    test "ignores functions of modules without metadata", %{meta: meta} do
      function_rows = [{{Unknown, :whatever, 0}, 5}]
      assert CoverageData.build([], function_rows, [], meta) == []
    end
  end

  describe "build/4 line (statement) coverage" do
    test "maps lines to source files and keeps uncovered lines" do
      meta = %{MyMod => %{source: "/abs/my_mod.ex", defs: %{}}}

      line_rows = [
        {{MyMod, 2}, 3},
        {{MyMod, 3}, 0},
        # a module without metadata is dropped
        {{Other, 9}, 7}
      ]

      [file] = CoverageData.build(line_rows, [], [], meta)
      assert Enum.sort(file["lines"]) == [[2, 3], [3, 0]]
    end
  end

  describe "build/4 branch (clause) coverage" do
    setup do
      meta = %{
        MyMod => %{
          source: "/abs/my_mod.ex",
          defs: %{
            # genuine multi-clause function on distinct lines
            {:kind, 1} => %{line: 5, clause_lines: [5, 6, 7]},
            # generated dispatch: clauses collapse onto one line
            {:lookup, 1} => %{line: 11, clause_lines: [11, 11, 11]},
            # single clause
            {:foo, 0} => %{line: 2, clause_lines: [2]}
          }
        }
      }

      {:ok, meta: meta}
    end

    test "emits branches for genuine multi-clause functions only", %{meta: meta} do
      clause_rows = [
        # kind/1 — branchable (distinct lines)
        {{MyMod, :kind, 1, 1}, 2},
        {{MyMod, :kind, 1, 2}, 0},
        {{MyMod, :kind, 1, 3}, 1},
        # lookup/1 — generated dispatch, dropped
        {{MyMod, :lookup, 1, 1}, 0},
        {{MyMod, :lookup, 1, 2}, 5},
        {{MyMod, :lookup, 1, 3}, 0},
        # foo/0 — single clause, dropped
        {{MyMod, :foo, 0, 1}, 3}
      ]

      [file] = CoverageData.build([], [], clause_rows, meta)

      assert [branch_group] = file["branches"]

      assert branch_group == %{
               "line" => 5,
               "branches" => [
                 %{"line" => 5, "count" => 2, "label" => "clause 1"},
                 %{"line" => 6, "count" => 0, "label" => "clause 2"},
                 %{"line" => 7, "count" => 1, "label" => "clause 3"}
               ]
             }
    end

    test "skips underscored functions even when multi-clause", %{meta: meta} do
      meta =
        put_in(meta[MyMod].defs[{:__struct__, 1}], %{line: 1, clause_lines: [1, 3]})

      clause_rows = [
        {{MyMod, :__struct__, 1, 1}, 0},
        {{MyMod, :__struct__, 1, 2}, 0}
      ]

      assert CoverageData.build([], [], clause_rows, meta) == []
    end
  end

  describe "build/4 integration" do
    test "combines lines, functions and branches for one file" do
      meta = %{
        MyMod => %{
          source: "/abs/my_mod.ex",
          defs: %{
            {:kind, 1} => %{line: 5, clause_lines: [5, 6]}
          }
        }
      }

      [file] =
        CoverageData.build(
          [{{MyMod, 5}, 4}, {{MyMod, 6}, 0}],
          [{{MyMod, :kind, 1}, 4}],
          [{{MyMod, :kind, 1, 1}, 4}, {{MyMod, :kind, 1, 2}, 0}],
          meta
        )

      assert file["file"] == "/abs/my_mod.ex"
      assert Enum.sort(file["lines"]) == [[5, 4], [6, 0]]
      assert file["functions"] == [%{"name" => "kind/1", "line" => 5, "count" => 4}]
      assert [%{"line" => 5, "branches" => branches}] = file["branches"]
      assert length(branches) == 2
    end
  end
end
