defmodule ElixirLS.LanguageServer.Providers.FoldingRangeTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.FoldingRange

  test "returns an :error tuple if input is not a source file" do
    assert {:error, _} = %{} |> FoldingRange.provide()
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
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 3}, {1, 2}])
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
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 5}, {1, 4}, {2, 3}])
    end

    @tag text: """
         defmodule A do     # 0
           def hello() do   # 1
             a = 20         # 2
                            # 3
             case a do      # 4
               20 -> :ok    # 5
               _ -> :error  # 6
             end            # 7
           end              # 8
         end                # 9
         """
    test "can fold 1 defmodule, 1 complex def", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 8}, {1, 7}, {4, 6}])
    end

    @tag text: """
         defmodule A do                   # 0
           @moduledoc "This is module A"  # 1
         end                              # 2
                                          # 3
         defmodule B do                   # 4
           @moduledoc "This is module B"  # 5
         end                              # 6
         """
    test "can fold 2 defmodules in the top-level of file", %{ranges_result: ranges_result} do
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
                                              # 6
             :world                           # 7
           end                                # 8
         end                                  # 9
         """
    test "can fold 1 defmodule, 1 def, 1 list", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      assert compare_condensed_ranges(ranges, [{0, 8}, {1, 7}, {2, 4}])
    end

    @tag text: """
         defmodule A do                                             # 0
           def f(%{"key" => value} = map) do                        # 1
             case NaiveDateTime.from_iso8601(value) do              # 2
               {:ok, ndt} ->                                        # 3
                 dt =                                               # 4
                  ndt                                               # 5
                  |> DateTime.from_naive!("Etc/UTC")                # 6
                  |> Map.put(:microsecond, {0, 6})                  # 7
                                                                    # 8
                 %{map | "key" => dt}                               # 9
                                                                    # 10
               e ->                                                 # 11
                 Logger.warn(\"\"\"
                 Could not use data map from #\{inspect(value)\}    # 13
                 #\{inspect(e)\}                                    # 14
                 \"\"\")
                                                                    # 16
                 :could_not_parse_value                             # 17
             end                                                    # 18
           end                                                      # 19
         end                                                        # 20
         """
    test "can fold heredoc w/ closing paren", %{ranges_result: ranges_result} do
      assert {:ok, ranges} = ranges_result
      ranges |> IO.inspect()
      # assert compare_condensed_ranges(ranges, [{0, 8}, {1, 7}, {2, 4}])
    end
  end

  defp fold_text(%{text: text} = context) do
    ranges_result = %{text: text} |> FoldingRange.provide()
    {:ok, Map.put(context, :ranges_result, ranges_result)}
  end

  defp compare_condensed_ranges(result, condensed_expected) do
    condensed_result = result |> Enum.map(&condense_range/1)
    assert condensed_result == condensed_expected
  end

  defp condense_range(range) do
    {range["startLine"], range["endLine"]}
  end
end
