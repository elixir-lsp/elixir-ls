defmodule ElixirLS.LanguageServer.Providers.FoldingRangeTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.FoldingRange

  test "returns an :error tuple if input is not a source file" do
    assert {:error, _} = %{} |> FoldingRange.provide()
  end

  describe "indentation" do
    setup [:fold_via_indentation]

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             :world        # 2
           end             # 3
         end               # 4
         """
    test "basic test", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 3}, {1, 2}])
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
    test "consecutive matching levels", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 6}, {1, 5}, {3, 4}])
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
                 Logger.warn(\"\"\"
                 Could not use data map from #\{inspect(value)\}  # 13
                 #\{inspect(e)\}                                  # 14
                 \"\"\")

                 :could_not_parse_value                         # 17
             end                                                # 18
           end                                                  # 19
         end                                                    # 20
         """
    test "complicated function", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      expected = [{0, 19}, {1, 18}, {2, 17}, {3, 9}, {4, 7}, {11, 17}]
      assert compare_condensed_ranges(ranges, expected)
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
    test "different complicated function", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 12}, {1, 11}, {2, 5}, {7, 9}])
    end

    defp fold_via_indentation(%{text: text} = context) do
      ranges_result =
        text
        |> FoldingRange.convert_text_to_input()
        |> FoldingRange.Indentation.provide_ranges()

      {:ok, Map.put(context, :ranges_result, ranges_result)}
    end
  end

  describe "token pairs" do
    setup [:fold_via_token_pairs]

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             :world        # 2
           end             # 3
         end               # 4
         """
    test "basic test", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 3}, {1, 2}])
    end

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             :world        # 2
               end         # 3
                 end       # 4
         """
    test "unusual indentation", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 3}, {1, 2}])
    end

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             if true do    # 2
               :hello      # 3
             else          # 4
               :error      # 5
             end           # 6
           end             # 7
         end               # 8
         """
    test "if-do-else-end", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 7}, {1, 6}, {2, 3}, {4, 5}])
    end

    @tag text: """
         defmodule A do             # 0
           def hello() do           # 1
             try do                 # 2
               :hello               # 3
             rescue                 # 4
               ArgumentError ->     # 5
                 IO.puts("rescue")  # 6
             catch                  # 7
               value ->             # 8
                 IO.puts("catch")   # 9
             else                   # 10
               value ->             # 11
                 IO.puts("else")    # 12
             after                  # 13
               IO.puts("after")     # 14
             end                    # 15
           end                      # 16
         end                        # 17
         """
    test "try block", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      expected = [{0, 16}, {1, 15}, {2, 3}, {4, 6}, {7, 9}, {10, 12}, {13, 14}]
      assert compare_condensed_ranges(ranges, expected)
    end

    @tag text: """
         defmodule A do     # 0
           def hello() do   # 1
             a = 20         # 2

             case a do      # 4
               20 ->        # 5
                :ok         # 6

               _ ->         # 8
                :error      # 9
             end            # 10
           end              # 11
         end                # 12
         """
    test "1 defmodule, 1 def, 1 case", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 11}, {1, 10}, {4, 9}])
    end

    @tag text: """
         defmodule A do                   # 0
           @moduledoc "This is module A"  # 1
         end                              # 2

         defmodule B do                   # 4
           @moduledoc "This is module B"  # 5
         end                              # 6
         """
    test "2 defmodules in the top-level of file", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 1}, {4, 5}])
    end

    @tag text: """
         defmodule A do                       # 0
           def compare_and_hello(list) do     # 1
             assert list == [                 # 2
                      %{"a" => 1, "b" => 2},  # 3
                      %{"a" => 3, "b" => 4},  # 4
                    ]                         # 5

             :world                           # 7
           end                                # 8
         end                                  # 9
         """
    test "1 defmodule, 1 def, 1 list", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 8}, {1, 7}, {2, 4}])
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
                 Logger.warn(\"\"\"
                 Could not use data map from #\{inspect(value)\}  # 13
                 #\{inspect(e)\}                                  # 14
                 \"\"\")

                 :could_not_parse_value                         # 17
             end                                                # 18
           end                                                  # 19
         end                                                    # 20
         """
    test "complicated function", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 19}, {1, 18}, {2, 17}, {12, 14}])
    end

    defp fold_via_token_pairs(%{text: text} = context) do
      ranges_result =
        text
        |> FoldingRange.convert_text_to_input()
        |> FoldingRange.TokenPairs.provide_ranges()

      {:ok, Map.put(context, :ranges_result, ranges_result)}
    end
  end

  describe "heredocs" do
    setup [:fold_via_heredocs]

    @tag text: """
         defmodule A do                                 # 0
          @moduledoc \"\"\"
          I'm a @moduledoc heredoc.                     # 2
          \"\"\"

          @doc \"\"\"
          I'm a @doc heredoc.                           # 6
          \"\"\"
           def f(%{"key" => value} = map) do            # 8
             case NaiveDateTime.from_iso8601(value) do  # 9
               {:ok, ndt} ->                            # 10
                 dt =                                   # 11
                   ndt                                  # 12
                   |> DateTime.from_naive!("Etc/UTC")   # 13
                   |> Map.put(:microsecond, {0, 6})     # 14

                 %{map | "key" => dt}                   # 16

               e ->                                     # 18
                 Logger.warn(\"\"\"
                 I'm a regular heredoc                  # 20
                 \"\"\")

                 :could_not_parse_value                 # 23
             end                                        # 24
           end                                          # 25
         end                                            # 26
         """
    test "@moduledoc, @doc, and stand-alone heredocs", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{1, 2}, {5, 6}, {19, 20}])
    end

    defp fold_via_heredocs(%{text: text} = context) do
      ranges_result =
        text
        |> FoldingRange.convert_text_to_input()
        |> FoldingRange.Heredoc.provide_ranges()

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
    test "no single line comment blocks", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [])
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
    test "@moduledoc, @doc, and stand-alone heredocs", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{5, 7}])
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
           @moduledoc \"\"\"
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
                 Logger.warn(\"\"\"
                 Could not use data map from #\{inspect(value)\}  # 19
                 #\{inspect(e)\}                                  # 20
                 \"\"\")

                 :could_not_parse_value                         # 23
             end                                                # 24
           end                                                  # 25
         end                                                    # 26
         """
    test "complicated function", %{ranges_result: ranges_result} do
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

      assert compare_condensed_ranges(ranges, expected)
    end

    defp fold_text(%{text: _text} = context) do
      ranges_result = FoldingRange.provide(context)
      {:ok, Map.put(context, :ranges_result, ranges_result)}
    end
  end

  defp compare_condensed_ranges(result, condensed_expected) do
    condensed_result = result |> Enum.map(&{&1.startLine, &1.endLine})
    assert Enum.sort(condensed_result) == Enum.sort(condensed_expected)
  end
end
