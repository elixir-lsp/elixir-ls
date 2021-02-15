defmodule ElixirLS.LanguageServer.Providers.FoldingRangeTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.FoldingRange

  test "returns an :error tuple if input is not a source file" do
    assert {:error, _} = %{} |> FoldingRange.provide()
  end

  describe "indentation" do
    setup [:pair_cells]

    # defmodule A do    # 0
    #   def hello() do  # 1
    #     :world        # 2
    #   end             # 3
    # end               # 4
    @tag cells: [{0, 0}, {1, 2}, {2, 4}, {3, 2}, {4, 0}]
    test "basic indentation test", %{pairs: pairs} do
      assert pairs == [{{0, 0}, {4, 0}}, {{1, 2}, {3, 2}}]
    end

    # defmodule A do    # 0
    #   def hello() do  # 1
    #     # world       # 2
    #     if true do    # 3
    #       :world      # 4
    #     end           # 5
    #   end             # 6
    # end               # 7
    @tag cells: [{0, 0}, {1, 2}, {2, 4}, {3, 4}, {4, 6}, {5, 4}, {6, 2}, {7, 0}]
    test "indent w/ successive matching levels", %{pairs: pairs} do
      assert pairs == [{{0, 0}, {7, 0}}, {{1, 2}, {6, 2}}, {{3, 4}, {5, 4}}]
    end

    # defmodule A do                                         # 0
    #   def f(%{"key" => value} = map) do                    # 1
    #     case NaiveDateTime.from_iso8601(value) do          # 2
    #       {:ok, ndt} ->                                    # 3
    #         dt =                                           # 4
    #           ndt                                          # 5
    #           |> DateTime.from_naive!("Etc/UTC")           # 6
    #           |> Map.put(:microsecond, {0, 6})             # 7
    #                                                        # 8
    #         %{map | "key" => dt}                           # 9
    #                                                        # 10
    #       e ->                                             # 11
    #         Logger.warn("""                                # 12
    #         Could not use data map from #{inspect(value)}  # 13
    #         #{inspect(e)}                                  # 14
    #         """)                                           # 15
    #                                                        # 16
    #         :could_not_parse_value                         # 17
    #     end                                                # 18
    #   end                                                  # 19
    # end                                                    # 20
    @tag cells: [
           {0, 0},
           {1, 2},
           {2, 4},
           {3, 6},
           {4, 8},
           {5, 10},
           {6, 10},
           {7, 10},
           {8, nil},
           {9, 8},
           {10, nil},
           {11, 6},
           {12, 8},
           {13, 8},
           {14, 8},
           {15, 8},
           {16, nil},
           {17, 8},
           {18, 4},
           {19, 2},
           {20, 0}
         ]
    test "indent w/ complicated function", %{pairs: pairs} do
      assert pairs == [
               {{0, 0}, {20, 0}},
               {{1, 2}, {19, 2}},
               {{2, 4}, {18, 4}},
               {{3, 6}, {9, nil}},
               {{4, 8}, {7, nil}},
               {{11, 6}, {18, 4}}
             ]
    end

    defp pair_cells(%{cells: cells} = context) do
      pairs = FoldingRange.Indentation.pair_cells(cells)
      {:ok, Map.put(context, :pairs, pairs)}
    end
  end

  describe "genuine source files" do
    setup [:fold_text]

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             :world        # 2
           end             # 3
         end               # 4
         """
    test "can fold 1 defmodule, 1 def", %{ranges_result: ranges_result} do
      assert {:ok, _ranges} = ranges_result
      # assert compare_condensed_ranges(ranges, [{0, 3}, {1, 2}])
    end

    @tag text: """
         defmodule A do    # 0
           def hello() do  # 1
             \"\"\"
             hello         # 3
             \"\"\"
           end             # 5
         end               # 6
         """
    test "can fold 1 defmodule, 1 def, 1 heredoc", %{ranges_result: ranges_result} do
      assert {:ok, _ranges} = ranges_result
      # assert compare_condensed_ranges(ranges, [{0, 5}, {1, 4}, {2, 3}])
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
    test "can fold 1 defmodule, 1 complex def", %{ranges_result: ranges_result} do
      assert {:ok, _ranges} = ranges_result
      # assert compare_condensed_ranges(ranges, [{0, 8}, {1, 7}, {4, 6}])
    end

    @tag text: """
         defmodule A do                   # 0
           @moduledoc "This is module A"  # 1
         end                              # 2

         defmodule B do                   # 4
           @moduledoc "This is module B"  # 5
         end                              # 6
         """
    test "can fold 2 defmodules in the top-level of file", %{ranges_result: ranges_result} do
      assert {:ok, _ranges} = ranges_result
      # assert compare_condensed_ranges(ranges, [{0, 1}, {4, 5}])
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
    test "can fold 1 defmodule, 1 def, 1 list", %{ranges_result: ranges_result} do
      assert {:ok, _ranges} = ranges_result
      # assert compare_condensed_ranges(ranges, [{0, 8}, {1, 7}, {2, 4}])
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
    test "can fold heredoc w/ closing paren", %{ranges_result: ranges_result} do
      assert {:ok, _ranges} = ranges_result
      # ranges |> IO.inspect()
      # assert compare_condensed_ranges(ranges, [{0, 8}, {1, 7}, {2, 4}])
    end
  end

  defp fold_text(%{text: text} = context) do
    "" |> IO.puts()
    text |> IO.puts()
    ranges_result = %{text: text} |> FoldingRange.provide()
    {:ok, Map.put(context, :ranges_result, ranges_result)}
  end

  # defp compare_condensed_ranges(result, condensed_expected) do
  #   condensed_result = result |> Enum.map(&condense_range/1)
  #   assert condensed_result == condensed_expected
  # end

  # defp condense_range(range) do
  #   {range["startLine"], range["endLine"]}
  # end
end
