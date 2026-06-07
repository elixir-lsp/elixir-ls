defmodule ElixirLS.DebugAdapter.CoverageData do
  @moduledoc """
  Pure transformation of `:cover` analysis results into the per-file coverage
  payload streamed to the client.

  Kept separate from `ElixirLS.DebugAdapter.ExUnitFormatter` so the shaping and
  filtering logic (which `:cover`/Mix do not expose — declaration and branch
  coverage) can be unit tested without a running cover server.

  `meta` maps each cover-compiled module to its source file and per-function line
  metadata extracted from BEAM debug info:

      %{module => %{
        source: "/abs/path/file.ex",
        defs: %{{name, arity} => %{line: integer, clause_lines: [integer]}}
      }}

  The analysis rows are the `ok` lists from `:cover.analyse(:calls, level)`:

      line_rows     :: [{{module, line}, count}]
      function_rows :: [{{module, name, arity}, count}]
      clause_rows   :: [{{module, name, arity, clause_index}, count}]
  """

  @doc """
  Builds the per-file coverage list from cover analysis rows and module metadata.

  Each entry is `%{"file" => path, "lines" => [[line, count]], "functions" =>
  [%{"name", "line", "count"}], "branches" => [%{"line", "branches" => [...]}]}`.
  """
  def build(line_rows, function_rows, clause_rows, meta) do
    %{}
    |> reduce_lines(line_rows, meta)
    |> reduce_functions(function_rows, meta)
    |> reduce_clauses(clause_rows, meta)
    |> Enum.map(&format_file/1)
  end

  @doc """
  Whether a function name should be skipped from coverage.

  Names starting with an underscore are compiler/macro generated (`__struct__`,
  `__impl__`, `__protocol__`, `__info__`, ...) and are never "called" in a
  meaningful sense, so counting them would artificially lower coverage.
  """
  def ignored_function?(name) do
    name |> Atom.to_string() |> String.starts_with?("_")
  end

  @doc """
  Whether a function's clauses should be reported as branches.

  Only true when there is more than one clause, `:cover`'s clause count matches
  the number of source clauses (so indices line up), and every clause is on a
  distinct source line. The distinct-line check drops compiler-generated dispatch
  clauses (e.g. `for ... do defp f(unquote(x)), do: ... end` lookup tables) that
  all collapse onto the macro-expansion line and would otherwise read as
  misleading branch coverage.
  """
  def branchable_clauses?(clause_counts, clause_lines) do
    count = length(clause_counts)

    count > 1 and
      length(clause_lines) == count and
      length(Enum.uniq(clause_lines)) == count
  end

  defp reduce_lines(files, rows, meta) do
    Enum.reduce(rows, files, fn
      {{module, line}, count}, acc when is_integer(line) and line > 0 and is_integer(count) ->
        case meta[module] do
          %{source: path} ->
            update_file(acc, path, :lines, fn lines ->
              # the same line can be reported for multiple clauses; keep max
              Map.update(lines, line, count, &max(&1, count))
            end)

          _ ->
            acc
        end

      _, acc ->
        acc
    end)
  end

  defp reduce_functions(files, rows, meta) do
    Enum.reduce(rows, files, fn
      {{module, name, arity}, count}, acc when is_integer(count) ->
        with false <- ignored_function?(name),
             %{source: path, defs: defs} <- meta[module],
             %{line: line} <- defs[{name, arity}] do
          update_file(acc, path, :functions, fn functions ->
            entry =
              Map.get(functions, {name, arity}, %{
                name: "#{name}/#{arity}",
                line: line,
                count: 0
              })

            Map.put(functions, {name, arity}, %{entry | count: entry.count + count})
          end)
        else
          _ -> acc
        end

      _, acc ->
        acc
    end)
  end

  defp reduce_clauses(files, rows, meta) do
    rows
    |> Enum.reduce(%{}, fn
      {{module, name, arity, index}, count}, acc
      when is_integer(index) and is_integer(count) ->
        Map.update(acc, {module, name, arity}, [{index, count}], &[{index, count} | &1])

      _, acc ->
        acc
    end)
    |> Enum.reduce(files, fn {{module, name, arity}, clause_counts}, acc ->
      with false <- ignored_function?(name),
           %{source: path, defs: defs} <- meta[module],
           %{line: line, clause_lines: clause_lines} <- defs[{name, arity}],
           true <- branchable_clauses?(clause_counts, clause_lines) do
        branches =
          clause_counts
          |> Enum.sort()
          |> Enum.map(fn {index, count} ->
            clause_line = Enum.at(clause_lines, index - 1, line)
            %{"line" => clause_line, "count" => count, "label" => "clause #{index}"}
          end)

        update_file(acc, path, :branches, fn br ->
          Map.put(br, {name, arity}, %{"line" => line, "branches" => branches})
        end)
      else
        _ -> acc
      end
    end)
  end

  defp update_file(files, path, key, fun) do
    file = Map.get(files, path, %{lines: %{}, functions: %{}, branches: %{}})
    Map.put(files, path, Map.update!(file, key, fun))
  end

  defp format_file({path, %{lines: lines, functions: functions, branches: branches}}) do
    %{
      "file" => path,
      "lines" => Enum.map(lines, fn {line, count} -> [line, count] end),
      "functions" =>
        Enum.map(functions, fn {_key, %{name: name, line: line, count: count}} ->
          %{"name" => name, "line" => line, "count" => count}
        end),
      "branches" => Map.values(branches)
    }
  end
end
