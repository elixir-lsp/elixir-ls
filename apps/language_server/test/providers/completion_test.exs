defmodule ElixirLS.LanguageServer.Providers.CompletionTest do
  use ExUnit.Case

  require Logger

  alias ElixirLS.LanguageServer.Providers.Completion
  alias ElixirLS.Utils.TestUtils

  @supports [
    snippets_supported: true,
    deprecated_supported: false,
    tags_supported: [],
    signature_help_supported: true,
    locals_without_parens: MapSet.new()
  ]

  @signature_command %{
    "title" => "Trigger Parameter Hint",
    "command" => "editor.action.triggerParameterHints"
  }

  setup context do
    ElixirLS.LanguageServer.Build.load_all_modules()

    unless context[:skip_server] do
      server = ElixirLS.LanguageServer.Test.ServerTestHelpers.start_server()

      {:ok, %{server: server}}
    else
      :ok
    end
  end

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
      |> Enum.map(&(&1 <> "/2"))

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
      |> Enum.map(&(&1 <> "/2"))

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
             "def my_fun/2"
           ]
  end

  test "provides completions for callbacks without `def` before" do
    text = """
    defmodule MyModule do
      @behaviour ElixirLS.LanguageServer.Fixtures.ExampleBehaviour

    # ^
    end
    """

    {line, char} = {2, 2}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    first_completion =
      items
      |> Enum.filter(&(&1["detail"] =~ "callback"))
      |> Enum.at(0)

    assert first_completion["label"] =~ "def build_greeting"

    assert first_completion["insertText"] == "def build_greeting(${1:name}) do\n\t$0\nend"
  end

  test "provides completions for callbacks with `def` before" do
    text = """
    defmodule MyModule do
      @behaviour ElixirLS.LanguageServer.Fixtures.ExampleBehaviour

      def
       # ^
    end
    """

    {line, char} = {3, 5}
    TestUtils.assert_has_cursor_char(text, line, char)
    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    first_completion =
      items
      |> Enum.filter(&(&1["detail"] =~ "callback"))
      |> Enum.at(0)

    assert first_completion["label"] =~ "def build_greeting"
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

  describe "structs and maps" do
    test "returns struct fields in call syntax" do
      text = """
      defmodule MyModule do
        defstruct [some: nil, other: 1]

        def dummy_function(var = %MyModule{}) do
          var.
          #   ^
        end
      end
      """

      {line, char} = {4, 8}
      TestUtils.assert_has_cursor_char(text, line, char)
      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert ["__struct__", "other", "some"] == items |> Enum.map(& &1["label"]) |> Enum.sort()
      assert (items |> hd)["detail"] == "MyModule struct field"
    end

    test "returns map keys in call syntax" do
      text = """
      defmodule MyModule do
        def dummy_function(var = %{some: nil, other: 1}) do
          var.
          #   ^
        end
      end
      """

      {line, char} = {2, 8}
      TestUtils.assert_has_cursor_char(text, line, char)
      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert ["other", "some"] == items |> Enum.map(& &1["label"]) |> Enum.sort()
      assert (items |> hd)["detail"] == "map key"
    end

    test "returns struct fields in update syntax" do
      text = """
      defmodule MyModule do
        defstruct [some: nil, other: 1]

        def dummy_function(var = %MyModule{}) do
          %{var |
          #      ^
        end
      end
      """

      {line, char} = {4, 11}
      TestUtils.assert_has_cursor_char(text, line, char)
      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert ["__struct__", "other", "some"] ==
               items |> Enum.filter(&(&1["kind"] == 5)) |> Enum.map(& &1["label"]) |> Enum.sort()

      assert (items |> hd)["detail"] == "MyModule struct field"
    end

    test "returns map keys in update syntax" do
      text = """
      defmodule MyModule do
        def dummy_function(var = %{some: nil, other: 1}) do
          %{var |
          #      ^
        end
      end
      """

      {line, char} = {2, 11}
      TestUtils.assert_has_cursor_char(text, line, char)
      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert ["other", "some"] ==
               items |> Enum.filter(&(&1["kind"] == 5)) |> Enum.map(& &1["label"]) |> Enum.sort()

      assert (items |> hd)["detail"] == "map key"
    end

    test "returns struct fields in definition syntax" do
      text = """
      defmodule MyModule do
        defstruct [some: nil, other: 1]

        def dummy_function() do
          %MyModule{}
          #         ^
        end
      end
      """

      {line, char} = {4, 14}
      TestUtils.assert_has_cursor_char(text, line, char)
      {:ok, result} = Completion.completion(text, line, char, @supports)

      assert result["isIncomplete"] == true
      items = result["items"]

      assert ["__struct__", "other", "some"] ==
               items |> Enum.filter(&(&1["kind"] == 5)) |> Enum.map(& &1["label"]) |> Enum.sort()

      assert (items |> hd)["detail"] == "MyModule struct field"
    end

    test "isIncomplete is false when there are no results" do
      text = """
      defmodule MyModule do
        defstruct [some: nil, other: 1]

        def dummy_function() do
          #                    ^
      end
      """

      {line, char} = {3, 25}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, result} = Completion.completion(text, line, char, @supports)
      assert result["isIncomplete"] == false
      assert result["items"] == []
    end
  end

  describe "function completion" do
    setup do
      text = """
      defmodule MyModule do
        def add(a, b), do: a + b

        def dummy_function() do
          ad
          # ^
        end
      end
      """

      %{text: text, location: {4, 6}}
    end

    test "setting 'signature_after_complete'", context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, signature_after_complete: true)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)
      assert item["command"] == @signature_command

      opts = Keyword.merge(@supports, signature_after_complete: false)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)
      assert item["command"] == nil
    end

    test "without snippets nor signature support, complete with just the name", context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, snippets_supported: false, signature_help_supported: false)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add"
      assert item["command"] == nil

      opts =
        Keyword.merge(@supports,
          snippets_supported: false,
          locals_without_parens: MapSet.new(add: 2)
        )

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add "
      assert item["command"] == @signature_command
    end

    test "with signature support and no snippets support, complete with the name and trigger signature",
         context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, snippets_supported: false)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add("
      assert item["command"] == @signature_command
    end

    test "with snippets support and no signature support, complete with name and args",
         context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, signature_help_supported: false)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add(${1:a}, ${2:b})"
      assert item["command"] == nil
    end

    test "with snippets/signature support, add placeholder between parens and trigger signature",
         context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)

      assert item["insertText"] == "add($1)$0"
      assert item["command"] == @signature_command
    end

    test "with snippets/signature support, before valid arg, do not close parens" do
      text = """
      defmodule MyModule do
        def add(a, b), do: a + b

        def dummy_function() do
          ad100
          # ^
        end
      end
      """

      {line, char} = {4, 6}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)

      assert item["insertText"] == "add("
      assert item["command"] == @signature_command
    end

    test "function in :locals_without_parens doesn't complete with args if there's text after cursor" do
      text = """
      defmodule MyModule do
        def add(a, b), do: a + b

        def dummy_function() do
          ad 100
          # ^
        end
      end
      """

      {line, char} = {4, 6}
      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, locals_without_parens: MapSet.new(add: 2))
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add"
      assert item["command"] == @signature_command
    end

    test "function with arity 0 does not triggers signature" do
      text = """
      defmodule MyModule do
        def my_func(), do: false

        def dummy_function() do
          my
          # ^
        end
      end
      """

      {line, char} = {4, 6}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)

      assert item["insertText"] == "my_func()"
      assert item["command"] == nil
    end

    test "without signature support, unused default arguments are removed from the snippet" do
      text = """
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

        def dummy_function() do
          ExampleDefaultArgs.my
          #                    ^
        end
      end
      """

      {line, char} = {4, 25}
      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, signature_help_supported: false)

      {:ok, %{"items" => [item1, item2, item3]}} = Completion.completion(text, line, char, opts)

      assert item1["label"] == "my_func/1"
      assert item1["insertText"] == "my_func(${1:text})"

      assert item2["label"] == "my_func/2"
      assert item2["insertText"] == "my_func(${1:text}, ${2:opts1})"

      assert item3["label"] == "my_func/3"
      assert item3["insertText"] == "my_func(${1:text}, ${2:opts1}, ${3:opts2})"
    end

    test "when after a capture, derived functions from default arguments are listed and no signature is triggered" do
      text = """
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

        def dummy_function() do
          &ExampleDefaultArgs.my
          #                     ^
        end
      end
      """

      {line, char} = {4, 26}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item1, item2, item3]}} =
        Completion.completion(text, line, char, @supports)

      assert item1["label"] == "my_func/1"
      assert item1["insertText"] == "my_func${1:/1}$0"
      assert item1["command"] == nil

      assert item2["label"] == "my_func/2"
      assert item2["insertText"] == "my_func${1:/2}$0"
      assert item2["command"] == nil

      assert item3["label"] == "my_func/3"
      assert item3["insertText"] == "my_func${1:/3}$0"
      assert item3["command"] == nil

      opts = Keyword.merge(@supports, snippets_supported: false)
      {:ok, %{"items" => [item1, item2, item3]}} = Completion.completion(text, line, char, opts)

      assert item1["label"] == "my_func/1"
      assert item1["insertText"] == "my_func/1"
      assert item1["command"] == nil

      assert item2["label"] == "my_func/2"
      assert item2["insertText"] == "my_func/2"
      assert item2["command"] == nil

      assert item3["label"] == "my_func/3"
      assert item3["insertText"] == "my_func/3"
      assert item3["command"] == nil
    end

    test "with signature support, a function with default arguments generate just one suggestion" do
      text = """
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

        def dummy_function() do
          ExampleDefaultArgs.my
          #                    ^
        end
      end
      """

      {line, char} = {4, 25}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)
      assert item["label"] == "my_func/3"
      assert item["insertText"] == "my_func($1)$0"
      assert item["command"] == @signature_command
    end

    test "with signature support, a function with a derived in locals_without_parens generate more than one suggestion" do
      text = """
      defmodule MyModule do
        def timestamps, do: 1
        def timestamps(a), do: a

        def dummy_function() do
          timestamps
          #        ^
        end
      end
      """

      {line, char} = {5, 13}
      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, locals_without_parens: MapSet.new(timestamps: 0))
      {:ok, %{"items" => [item_1, item_2]}} = Completion.completion(text, line, char, opts)

      assert item_1["label"] == "timestamps/0"
      assert item_2["label"] == "timestamps/1"
    end

    test "with signature support, a function with 1 default argument triggers signature" do
      text = """
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

        def dummy_function() do
          ExampleDefaultArgs.func_with_1_arg
          #                                 ^
        end
      end
      """

      {line, char} = {4, 38}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)
      assert item["label"] == "func_with_1_arg/1"
      assert item["insertText"] == "func_with_1_arg($1)$0"
      assert item["command"] == @signature_command
    end

    test "a function with 1 default argument after a pipe does not trigger signature" do
      text = """
      defmodule MyModule do
        alias ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs

        def dummy_function() do
          [] |> ExampleDefaultArgs.func_with_1_arg
          #                                       ^
        end
      end
      """

      {line, char} = {4, 44}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)
      assert item["label"] == "func_with_1_arg/1"
      assert item["insertText"] == "func_with_1_arg()"
      assert item["command"] == nil
    end

    test "the detail of a local function is visibility + type + signature" do
      text = """
      defmodule MyModule do
        def my_func(text), do: true
        defp my_func_priv(text), do: true

        def dummy_function() do
          my
          # ^
        end
      end
      """

      {line, char} = {5, 6}

      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [pub, priv]}} = Completion.completion(text, line, char, @supports)

      assert pub["detail"] == "(function) my_func(text)"

      assert priv["detail"] == "(function) my_func_priv(text)"
    end

    test "the detail of a remote function is origin + type + signature" do
      text = """
      defmodule RemoteMod do
        def func(), do: true
      end

      defmodule MyModule do
        def dummy_function() do
          RemoteMod.
          #         ^
        end
      end
      """

      {line, char} = {6, 14}

      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item | _]}} = Completion.completion(text, line, char, @supports)

      assert item["detail"] == "(function) RemoteMod.func()"
    end

    test "documentation is the markdown of summary + formatted spec" do
      text = """
      defmodule MyModule do
        def dummy_function() do
          ElixirLS.LanguageServer.Fixtures.ExampleDocs.ad
          #                                              ^
        end
      end
      """

      {line, char} = {2, 51}

      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item | _]}} = Completion.completion(text, line, char, @supports)

      assert item["documentation"] == %{
               :kind => "markdown",
               "value" => """
               The summary
               ```
               @spec add(
                 a_big_name :: integer,
                 b_big_name :: integer
               ) :: integer
               ```
               """
             }
    end
  end

  describe "generic suggestions" do
    test "moduledoc completion" do
      text = """
      defmodule MyModule do
        @mod
        #   ^
      end
      """

      {line, char} = {1, 6}

      TestUtils.assert_has_cursor_char(text, line, char)

      assert {:ok, %{"items" => [first | _] = items}} =
               Completion.completion(text, line, char, @supports)

      labels = Enum.map(items, & &1["label"])

      assert labels == [
               ~s(@moduledoc """"""),
               "@moduledoc",
               "@moduledoc false"
             ]

      assert first == %{
               "detail" => "module attribute snippet",
               "documentation" => %{:kind => "markdown", "value" => "Documents a module"},
               "filterText" => "moduledoc",
               "insertText" => ~s(moduledoc """\n$0\n"""),
               "insertTextFormat" => 2,
               "kind" => 15,
               "label" => ~s(@moduledoc """"""),
               "sortText" => "00000000"
             }
    end
  end
end
