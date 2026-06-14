defmodule ElixirLS.LanguageServer.Providers.FoldingRangeTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.FoldingRange

  doctest(FoldingRange)

  describe "indentation" do
    setup [:fold_via_indentation]

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             :world        # 2
           end             # 3
         end               # 4
         """
    test "basic test", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 3}, {1, 2}], text)
    end

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             # world       # 2
             if true do    # 3
               :world      # 4
             end           # 5
           end             # 6
         end               # 7
         """
    test "consecutive matching levels", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 6}, {1, 5}, {3, 4}], text)
    end

    @tag text: """
         defmodule A do                                         # 0
           def f(%{"key" => value} = map) do                    # 1
             case NaiveDateTime.from_iso8601(value) do          # 2
               {:ok, ndt} ->                                    # 3
                 dt =                                           # 4
                   ndt                                          # 5
                   |> DateTime.from_naive!("Etc/UTC")           # 6
                   |> Map.put(:microsecond, {0, 6})             # 7

                 %{map | "key" => dt}                           # 9

               e ->                                             # 11
                 Logger.warning(\"\"\"
                 Could not use data map from #\{inspect(value)\}  # 13
                 #\{inspect(e)\}                                  # 14
                 \"\"\")

                 :could_not_parse_value                         # 17
             end                                                # 18
           end                                                  # 19
         end                                                    # 20
         """
    test "complicated function", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      expected = [{0, 19}, {1, 18}, {2, 17}, {3, 9}, {4, 7}, {11, 17}]
      assert compare_condensed_ranges(ranges, expected, text)
    end

    @tag text: """
         defmodule A do                      # 0
           def get_info(args) do             # 1
             org =                           # 2
               args                          # 3
               |> Ecto.assoc(:organization)  # 4
               |> Repo.one!()                # 5

             user =                          # 7
               org                           # 8
               |> Organization.user!()       # 9

             {:ok, %{org: org, user: user}}  # 11
           end                               # 12
         end                                 # 13
         """
    test "different complicated function", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 12}, {1, 11}, {2, 5}, {7, 9}], text)
    end

    defp fold_via_indentation(%{text: text} = context) do
      ranges_result =
        text
        |> FoldingRange.convert_text_to_input()
        |> FoldingRange.Indentation.provide_ranges()

      {:ok, Map.put(context, :ranges_result, ranges_result)}
    end
  end

  describe "comment blocks" do
    setup [:fold_via_comment_blocks]

    @tag text: """
         defmodule A do                 # 0
           def hello() do               # 1
             # single comment           # 2
             do_hello()                 # 3
           end                          # 4
         end                            # 5
         """
    test "no single line comment blocks", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [], text)
    end

    @tag text: """
         defmodule A do                 # 0
           def hello() do               # 1
             do_hello()                 # 2
           end                          # 3

           # comment block 0            # 5
           # comment block 1            # 6
           # comment block 2            # 7
           defp do_hello(), do: :world  # 8
         end                            # 9
         """
    test "@moduledoc, @doc, and stand-alone heredocs", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{5, 7}], text)
    end

    defp fold_via_comment_blocks(%{text: text} = context) do
      ranges_result =
        text
        |> FoldingRange.convert_text_to_input()
        |> FoldingRange.CommentBlock.provide_ranges()

      {:ok, Map.put(context, :ranges_result, ranges_result)}
    end
  end

  describe "end to end" do
    setup [:fold_text]

    @tag text: """
         defmodule A do                                         # 0
           @moduledoc ~S\"\"\"
           I'm a @moduledoc heredoc.                            # 2
           \"\"\"

           def f(%{"key" => value} = map) do                    # 5
             # comment block 0                                  # 6
             # comment block 1                                  # 7
             case NaiveDateTime.from_iso8601(value) do          # 8
               {:ok, ndt} ->                                    # 9
                 dt =                                           # 10
                   ndt                                          # 11
                   |> DateTime.from_naive!("Etc/UTC")           # 12
                   |> Map.put(:microsecond, {0, 6})             # 13

                 %{map | "key" => dt}                           # 15

               e ->                                             # 17
                 Logger.warning(\"\"\"
                 Could not use data map from #\{inspect(value)\}  # 19
                 #\{inspect(e)\}                                  # 20
                 \"\"\")

                 :could_not_parse_value                         # 23
             end                                                # 24
           end                                                  # 25
         end                                                    # 26
         """
    test "complicated function", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result

      expected = [
        {0, 25},
        {1, 2},
        {5, 24},
        {6, 7},
        {8, 23},
        {9, 15},
        {10, 13},
        {17, 23},
        {18, 20}
      ]

      assert compare_condensed_ranges(ranges, expected, text)
    end

    @tag text: """
         defmodule A do
           @doc false
           def init(_) do
             IO.puts("Hello World!")
             {:ok, []}
           end
         end
         """
    test "@doc false does not create a folding range", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      expected = [{0, 5, "region"}, {2, 4, "region"}]
      assert compare_condensed_ranges(ranges, expected, text)
    end

    @tag text: """
         defmodule A do
           @typedoc false
           @type t :: %{}

           def init(_) do
             IO.puts("Hello World!")
             {:ok, []}
           end
         end
         """
    test "@typedoc example", %{ranges_result: ranges_result, text: text} do
      assert {:ok, ranges} = ranges_result
      expected = [{0, 7, "region"}, {4, 6, "region"}]
      assert compare_condensed_ranges(ranges, expected, text)
    end

    @tag text: """
         defmodule A do
           @moduledoc false

           def init(_) do
             IO.puts("Hello World!")
             {:ok, []}
           end
         end
         """
    test "@moduledoc false does not create a folding range", %{
      ranges_result: ranges_result,
      text: text
    } do
      assert {:ok, ranges} = ranges_result
      expected = [{0, 6, "region"}, {3, 5, "region"}]
      assert compare_condensed_ranges(ranges, expected, text)
    end

    @tag text: """
         defmodule A do
           def check(value) do
             if value not in [1, 2, 3] do
               :ok
             end
           end
         end
         """
    test "handles 'not in' operator from Elixir 1.19+", %{
      ranges_result: ranges_result,
      text: text
    } do
      assert {:ok, ranges} = ranges_result
      expected = [{0, 5, "region"}, {1, 4, "region"}, {2, 3, "region"}]
      assert compare_condensed_ranges(ranges, expected, text)
    end

    defp fold_text(%{text: _text} = context) do
      ranges_result = FoldingRange.provide(context)
      {:ok, Map.put(context, :ranges_result, ranges_result)}
    end
  end

  defp compare_condensed_ranges(result, expected_condensed, text) do
    result_condensed =
      result
      |> Enum.map(fn
        %GenLSP.Structures.FoldingRange{start_line: start_line, end_line: end_line, kind: kind} ->
          {start_line, end_line, kind}

        %GenLSP.Structures.FoldingRange{start_line: start_line, end_line: end_line} ->
          {start_line, end_line, :any}
      end)
      |> Enum.sort()

    expected_condensed =
      expected_condensed
      |> Enum.map(fn
        {start_line, end_line, kind} ->
          {start_line, end_line, kind}

        {start_line, end_line} ->
          {start_line, end_line, :any}
      end)
      |> Enum.sort()

    {result_condensed, expected_condensed} =
      Enum.zip(result_condensed, expected_condensed)
      |> Enum.map(fn
        {{rs, re, rk}, {es, ee, ek}} when rk == :any or ek == :any ->
          {{rs, re, :any}, {es, ee, :any}}

        otherwise ->
          otherwise
      end)
      |> Enum.unzip()

    if result_condensed != expected_condensed do
      visualize_folding(text, result_condensed)
    end

    assert result_condensed == expected_condensed
  end

  def visualize_folding(nil, _), do: :ok

  def visualize_folding(text, result_condensed) do
    lines =
      String.split(text, "\n")
      |> Enum.with_index()
      |> Enum.map(fn {line, index} ->
        String.pad_leading(to_string(index), 2, " ") <> ": " <> line
      end)

    result_condensed
    |> Enum.map(fn {line_start, line_end, descriptor} ->
      out =
        Enum.slice(lines, line_start, line_end - line_start + 2)
        |> Enum.join("\n")

      IO.puts("Folding lines #{line_start}, #{line_end} (#{descriptor}):")
      IO.puts(out)
      IO.puts("\n")
    end)
  end
end
