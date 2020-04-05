defmodule ElixirLS.LanguageServer.Providers.CompletionTest do
  use ExUnit.Case

  require Logger

  alias ElixirLS.LanguageServer.Providers.Completion
  alias ElixirLS.Utils.TestUtils

  @supports [snippets_supported: true, deprecated_supported: false, tag_supported: []]

  test "returns all Logger completions on normal require" do
    text = """
    defmodule MyModule do
      require Logger

      def dummy_function() do
        Logger.
        #      ^
      end
    end
    """

    {line, char} = {4, 11}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    logger_labels =
      ["warn", "debug", "error", "info"]
      |> Enum.map(&(&1 <> "(chardata_or_fun, metadata \\\\ [])"))

    for lfn <- logger_labels do
      assert(Enum.any?(items, fn %{"label" => label} -> label == lfn end))
    end
  end

  test "returns all Logger completions on require with alias" do
    text = """
    defmodule MyModule do
      require Logger, as: LAlias

      def dummy_function() do
        LAlias.
        #      ^
      end
    end
    """

    {line, char} = {4, 11}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    logger_labels =
      ["warn", "debug", "error", "info"]
      |> Enum.map(&(&1 <> "(chardata_or_fun, metadata \\\\ [])"))

    for lfn <- logger_labels do
      assert(Enum.any?(items, fn %{"label" => label} -> label == lfn end))
    end
  end

  test "unless with snippets not supported does not return a completion" do
    text = """
    defmodule MyModule do
      require Logger, as: LAlias

      def dummy_function() do
        unless
        #     ^
      end
    end
    """

    {line, char} = {4, 10}
    TestUtils.assert_has_cursor_char(text, line, char)

    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)
    assert length(items) == 1

    {:ok, %{"items" => items}} =
      Completion.completion(
        text,
        line,
        char,
        @supports |> Keyword.put(:snippets_supported, false)
      )

    assert length(items) == 0
  end

  test "provides completions for protocol functions" do
    text = """
    defimpl ElixirLS.LanguageServer.Fixtures.ExampleProtocol, for: MyModule do

    #^
    end
    """

    {line, char} = {1, 1}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    completions =
      items
      |> Enum.filter(&(&1["detail"] =~ "protocol function"))
      |> Enum.map(& &1["label"])

    assert completions == [
             "def my_fun(example, arg)"
           ]
  end

  test "returns module completions after pipe" do
    text = """
    defmodule MyModule do
      NaiveDateTime.utc_now() |> Naiv
    #                                ^
    1..100
    |> Enum.map(&Inte)
    #                ^
    def my(%Naiv)
    #           ^
    end
    """

    {line, char} = {1, 33}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    completions =
      items
      |> Enum.filter(&(&1["detail"] =~ "struct"))
      |> Enum.map(& &1["label"])

    assert "NaiveDateTime" in completions

    {line, char} = {4, 17}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    completions =
      items
      |> Enum.filter(&(&1["detail"] =~ "module"))
      |> Enum.map(& &1["label"])

    assert "Integer" in completions

    {line, char} = {6, 12}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    completions =
      items
      |> Enum.filter(&(&1["detail"] =~ "struct"))
      |> Enum.map(& &1["label"])

    assert "NaiveDateTime" in completions
  end

  describe "deprecated" do
    defp get_deprecated_completion_item(options) do
      text = """
      ElixirLS.LanguageServer.Fixtures.ExampleDeprecated
                                                        ^
      """

      {line, char} = {0, 50}
      TestUtils.assert_has_cursor_char(text, line, char)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, options)
      item
    end

    test "returns deprecated flag when supported" do
      assert %{"deprecated" => true} = get_deprecated_completion_item(deprecated_supported: true)
    end

    test "returns deprecated completion tag when supported" do
      assert %{"tags" => [1]} = get_deprecated_completion_item(tags_supported: [1])
    end

    test "returns no deprecated indicator when not supported" do
      # deprecated and tags not supported
      item = get_deprecated_completion_item([])
      refute Map.has_key?(item, "deprecated")
      refute Map.has_key?(item, "tags")

      # tags supported but not deprecated tag
      assert %{"tags" => []} = get_deprecated_completion_item(tags_supported: [2])
    end
  end
end
