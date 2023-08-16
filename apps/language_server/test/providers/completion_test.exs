defmodule ElixirLS.LanguageServer.Providers.CompletionTest do
  use ExUnit.Case, async: false

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

  test "do is returned" do
    text = """
    defmodule MyModule do
      require Logger

      def fun do
        #       ^
      end
    end
    """

    {line, char} = {3, 12}
    TestUtils.assert_has_cursor_char(text, line, char)

    {:ok, %{"items" => [first_item | _items]}} =
      Completion.completion(text, line, char, @supports)

    assert first_item["label"] == "do"
    assert first_item["preselect"] == true
  end

  test "end is returned" do
    text = """
    defmodule MyModule do
      require Logger

      def engineering_department, do: :eng

      def fun do
        :ok
      end
    #    ^
    end
    """

    {line, char} = {7, 5}
    TestUtils.assert_has_cursor_char(text, line, char)

    {:ok, %{"items" => [first_item | items]}} = Completion.completion(text, line, char, @supports)

    assert first_item["label"] == "end"

    completions =
      items
      |> Enum.filter(&(&1["label"] =~ "engineering_department"))
      |> Enum.map(& &1["insertText"])

    assert completions == ["engineering_department()"]
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

    logger_labels = ["warn", "debug", "error", "info"]

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

    logger_labels = ["warn", "debug", "error", "info"]

    for lfn <- logger_labels do
      assert(Enum.any?(items, fn %{"label" => label} -> label == lfn end))
    end
  end

  test "returns fn autocompletion when inside parentheses" do
    text = """
    defmodule MyModule do

      def dummy_function() do
        Task.async(fn)
        #            ^
      end
    end
    """

    {line, char} = {3, 17}
    TestUtils.assert_has_cursor_char(text, line, char)

    {:ok, %{"items" => [first_suggestion | _tail]}} =
      Completion.completion(text, line, char, @supports)

    assert first_suggestion["label"] === "fn"
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

  test "completions of protocols are rendered as an interface" do
    text = """
    defmodule MyModule do
      def dummy_function() do
        ElixirLS.LanguageServer.Fixtures.ExampleP
        #                                        ^
      end
    end
    """

    {line, char} = {2, 45}
    TestUtils.assert_has_cursor_char(text, line, char)

    {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)

    # 8 is interface
    assert item["kind"] == 8
    assert item["label"] == "ExampleProtocol"
    assert item["labelDetails"]["detail"] == "protocol"

    assert item["labelDetails"]["description"] ==
             "ElixirLS.LanguageServer.Fixtures.ExampleProtocol"
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

  test "completions of behaviours are rendered as an interface" do
    text = """
    defmodule MyModule do
      def dummy_function() do
        ElixirLS.LanguageServer.Fixtures.ExampleB
        #                                        ^
      end
    end
    """

    {line, char} = {2, 45}
    TestUtils.assert_has_cursor_char(text, line, char)

    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    assert [item, _] = items

    # 8 is interface
    assert item["kind"] == 8
    assert item["label"] == "ExampleBehaviour"
    assert item["labelDetails"]["detail"] == "behaviour"

    assert item["labelDetails"]["description"] ==
             "ElixirLS.LanguageServer.Fixtures.ExampleBehaviour"
  end

  test "completions of exceptions are rendered as a struct" do
    text = """
    defmodule MyModule do
      def dummy_function() do
        ElixirLS.LanguageServer.Fixtures.ExampleE
        #                                        ^
      end
    end
    """

    {line, char} = {2, 45}
    TestUtils.assert_has_cursor_char(text, line, char)

    {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

    assert [item] = items

    # 22 is struct
    assert item["kind"] == 22
    assert item["label"] == "ExampleException"
    assert item["labelDetails"]["detail"] == "exception"

    assert item["labelDetails"]["description"] ==
             "ElixirLS.LanguageServer.Fixtures.ExampleException"
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

  describe "auto alias" do
    test "suggests full module path as additionalTextEdits" do
      text = """
      defmodule MyModule do
        @moduledoc \"\"\"
        This
        is a
        long
        moduledoc

        \"\"\"

        def dummy_function() do
          ExampleS
          #       ^
        end
      end
      """

      {line, char} = {10, 12}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert [item] = items

      # 22 is struct
      assert item["kind"] == 22
      assert item["label"] == "ExampleStruct"
      assert item["labelDetails"]["detail"] == "struct"

      assert item["labelDetails"]["description"] ==
               "alias ElixirLS.LanguageServer.Fixtures.ExampleStruct"

      assert [%{newText: "alias ElixirLS.LanguageServer.Fixtures.ExampleStruct\n"}] =
               item["additionalTextEdits"]

      assert [
               %{
                 range: %{
                   "end" => %{"character" => 0, "line" => 8},
                   "start" => %{"character" => 0, "line" => 8}
                 }
               }
             ] = item["additionalTextEdits"]
    end

    test "suggests nothing when auto_insert_required_alias is false" do
      supports = Keyword.put(@supports, :auto_insert_required_alias, false)

      text = """
      defmodule MyModule do
        @moduledoc \"\"\"
        This
        is a
        long
        moduledoc

        \"\"\"

        def dummy_function() do
          ExampleS
          #       ^
        end
      end
      """

      {line, char} = {10, 12}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => items}} = Completion.completion(text, line, char, supports)

      # nothing is suggested
      assert [] = items
    end

    test "no crash on first line" do
      text = "defmodule MyModule do"

      {:ok, %{"items" => items}} = Completion.completion(text, 0, 21, @supports)

      assert [item | _] = items

      assert item["label"] == "do"
    end
  end

  describe "auto require" do
    test "suggests require as additionalTextEdits" do
      text = """
      defmodule MyModule do
        def dummy_function() do
          Logger.err
          #         ^
        end
      end
      """

      {line, char} = {2, 14}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert [item] = items

      # 3 is function
      assert item["kind"] == 3
      assert item["label"] == "error"
      assert item["detail"] == "macro"
      assert item["labelDetails"]["detail"] == "(message_or_fun, metadata \\\\ [])"

      assert item["labelDetails"]["description"] ==
               "require Logger.error/2"

      assert [%{newText: "  require Logger\n"}] = item["additionalTextEdits"]

      assert [
               %{
                 range: %{
                   "end" => %{"character" => 0, "line" => 1},
                   "start" => %{"character" => 0, "line" => 1}
                 }
               }
             ] = item["additionalTextEdits"]
    end
  end

  describe "auto import" do
    test "no suggestion if import excluded" do
      text = """
      defmodule MyModule do
        import Enum, only: [all?: 1]
        def dummy_function() do
          cou
          #  ^
        end
      end
      """

      {line, char} = {3, 7}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert [] == items
    end
  end

  describe "structs and maps" do
    test "completions of structs are rendered as a struct" do
      text = """
      defmodule MyModule do
        def dummy_function() do
          ElixirLS.LanguageServer.Fixtures.ExampleS
          #                                        ^
        end
      end
      """

      {line, char} = {2, 45}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert [item] = items

      # 22 is struct
      assert item["kind"] == 22
      assert item["label"] == "ExampleStruct"
      assert item["labelDetails"]["detail"] == "struct"

      assert item["labelDetails"]["description"] ==
               "ElixirLS.LanguageServer.Fixtures.ExampleStruct"
    end

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
          #       ^
        end
      end
      """

      {line, char} = {4, 12}
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
          #       ^
        end
      end
      """

      {line, char} = {2, 12}
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

        def dummy_function() do123
          #                       ^
      end
      """

      {line, char} = {3, 28}
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
        def add_2_numbers(a, b), do: a + b

        def dummy_function() do
          ad2n
            # ^
        end
      end
      """

      %{text: text, location: {4, 8}}
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

      assert item["insertText"] == "add_2_numbers"
      assert item["command"] == nil

      opts =
        Keyword.merge(@supports,
          snippets_supported: false,
          locals_without_parens: MapSet.new(add_2_numbers: 2)
        )

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add_2_numbers "
      assert item["command"] == @signature_command
    end

    test "with signature support and no snippets support, complete with the name and trigger signature",
         context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, snippets_supported: false)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add_2_numbers("
      assert item["command"] == @signature_command
    end

    test "with snippets support and no signature support, complete with name and args",
         context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, signature_help_supported: false)
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add_2_numbers(${1:a}, ${2:b})"
      assert item["command"] == nil
    end

    test "with snippets/signature support, add placeholder between parens and trigger signature",
         context do
      %{text: text, location: {line, char}} = context

      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)

      assert item["insertText"] == "add_2_numbers($1)$0"
      assert item["command"] == @signature_command
    end

    test "with snippets/signature support, before valid arg, do not close parens" do
      text = """
      defmodule MyModule do
        def add_2_numbers(a, b), do: a + b

        def dummy_function() do
          ad2n100
            # ^
        end
      end
      """

      {line, char} = {4, 8}
      TestUtils.assert_has_cursor_char(text, line, char)

      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, @supports)

      assert item["insertText"] == "add_2_numbers("
      assert item["command"] == @signature_command
    end

    test "function in :locals_without_parens doesn't complete with args if there's text after cursor" do
      text = """
      defmodule MyModule do
        def add_2_numbers(a, b), do: a + b

        def dummy_function() do
          ad2n 100
            # ^
        end
      end
      """

      {line, char} = {4, 8}
      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, locals_without_parens: MapSet.new(add_2_numbers: 2))
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "add_2_numbers"
      assert item["command"] == @signature_command
    end

    test "complete with parens if there are remote calls" do
      text = """
      defmodule MyModule do
        def dummy_function() do
          Map.drop
          #       ^
        end
      end
      """

      {line, char} = {2, 12}
      TestUtils.assert_has_cursor_char(text, line, char)

      opts = Keyword.merge(@supports, locals_without_parens: MapSet.new(drop: 2))
      {:ok, %{"items" => [item]}} = Completion.completion(text, line, char, opts)

      assert item["insertText"] == "drop($1)$0"
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

      assert item1["label"] == "my_func"
      assert item1["insertText"] == "my_func(${1:text})"

      assert item2["label"] == "my_func"
      assert item2["insertText"] == "my_func(${1:text}, ${2:opts1})"

      assert item3["label"] == "my_func"
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

      assert item1["label"] == "my_func"
      assert item1["insertText"] == "my_func${1:/1}$0"
      assert item1["command"] == nil

      assert item2["label"] == "my_func"
      assert item2["insertText"] == "my_func${1:/2}$0"
      assert item2["command"] == nil

      assert item3["label"] == "my_func"
      assert item3["insertText"] == "my_func${1:/3}$0"
      assert item3["command"] == nil

      opts = Keyword.merge(@supports, snippets_supported: false)
      {:ok, %{"items" => [item1, item2, item3]}} = Completion.completion(text, line, char, opts)

      assert item1["label"] == "my_func"
      assert item1["insertText"] == "my_func/1"
      assert item1["command"] == nil

      assert item2["label"] == "my_func"
      assert item2["insertText"] == "my_func/2"
      assert item2["command"] == nil

      assert item3["label"] == "my_func"
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
      assert item["label"] == "my_func"
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

      assert item_1["label"] == "timestamps"
      assert item_1["labelDetails"]["detail"] == "()"
      assert item_1["labelDetails"]["description"] == "MyModule.timestamps/0"
      assert item_2["label"] == "timestamps"
      assert item_2["labelDetails"]["detail"] == "(a)"
      assert item_2["labelDetails"]["description"] == "MyModule.timestamps/1"
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
      assert item["label"] == "func_with_1_arg"
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
      assert item["label"] == "func_with_1_arg"
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

      assert pub["label"] == "my_func"
      assert pub["detail"] == "function"
      assert pub["labelDetails"]["detail"] == "(text)"
      assert pub["labelDetails"]["description"] == "MyModule.my_func/1"
      assert priv["label"] == "my_func_priv"
      assert priv["detail"] == "function"
      assert priv["labelDetails"]["detail"] == "(text)"
      assert priv["labelDetails"]["description"] == "MyModule.my_func_priv/1"
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

      assert item["label"] == "func"
      assert item["detail"] == "function"
      assert item["labelDetails"]["detail"] == "()"
      assert item["labelDetails"]["description"] == "RemoteMod.func/0"
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

    test "will suggest defmodule with module_name snippet when file path matches **/lib/**/*.ex" do
      text = """
      defmod
      #     ^
      """

      {line, char} = {0, 6}

      TestUtils.assert_has_cursor_char(text, line, char)

      assert {:ok, %{"items" => [first | _] = _items}} =
               Completion.completion(
                 text,
                 line,
                 char,
                 @supports
                 |> Keyword.put(
                   :file_path,
                   "/some/path/my_project/lib/my_project/sub_folder/my_file.ex"
                 )
               )

      assert %{
               "label" => "defmodule",
               "insertText" => "defmodule MyProject.SubFolder.MyFile$1 do\n\t$0\nend"
             } = first
    end

    test "will suggest defmodule without module_name snippet when file path does not match expected patterns" do
      text = """
      defmod
      #     ^
      """

      {line, char} = {0, 6}

      TestUtils.assert_has_cursor_char(text, line, char)

      assert {:ok, %{"items" => [first | _] = _items}} =
               Completion.completion(
                 text,
                 line,
                 char,
                 @supports
                 |> Keyword.put(
                   :file_path,
                   "/some/path/my_project/lib/my_project/sub_folder/my_file.heex"
                 )
               )

      assert %{
               "label" => "defmodule",
               "insertText" => "defmodule $1 do\n\t$0\nend"
             } = first
    end

    test "will suggest defmodule without module_name snippet when file path is nil" do
      text = """
      defmod
      #     ^
      """

      {line, char} = {0, 6}

      TestUtils.assert_has_cursor_char(text, line, char)

      assert {:ok, %{"items" => [first | _] = _items}} =
               Completion.completion(
                 text,
                 line,
                 char,
                 @supports
                 |> Keyword.put(
                   :file_path,
                   nil
                 )
               )

      assert %{
               "label" => "defmodule",
               "insertText" => "defmodule $1 do\n\t$0\nend"
             } = first
    end

    test "will suggest defprotocol with protocol_name snippet when file path matches **/lib/**/*.ex" do
      text = """
      defpro
      #     ^
      """

      {line, char} = {0, 6}

      TestUtils.assert_has_cursor_char(text, line, char)

      assert {:ok, %{"items" => [first | _] = _items}} =
               Completion.completion(
                 text,
                 line,
                 char,
                 @supports
                 |> Keyword.put(
                   :file_path,
                   "/some/path/my_project/lib/my_project/sub_folder/my_file.ex"
                 )
               )

      assert %{
               "label" => "defprotocol",
               "insertText" => "defprotocol MyProject.SubFolder.MyFile$1 do\n\t$0\nend"
             } = first
    end

    test "will suggest defprotocol without protocol_name snippet when file path does not match expected patterns" do
      text = """
      defpro
      #     ^
      """

      {line, char} = {0, 6}

      TestUtils.assert_has_cursor_char(text, line, char)

      assert {:ok, %{"items" => [first | _] = _items}} =
               Completion.completion(
                 text,
                 line,
                 char,
                 @supports
                 |> Keyword.put(
                   :file_path,
                   "/some/path/my_project/lib/my_project/sub_folder/my_file.heex"
                 )
               )

      assert %{
               "label" => "defprotocol",
               "insertText" => "defprotocol $1 do\n\t$0\nend"
             } = first
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

  describe "function_snippets" do
    test "return valid for record arg" do
      opts = [
        snippets_supported: true,
        deprecated_supported: true,
        tags_supported: [1],
        signature_help_supported: true,
        signature_after_complete: true,
        pipe_before?: true,
        capture_before?: false,
        trigger_signature?: false,
        locals_without_parens: MapSet.new(),
        text_after_cursor: "",
        with_parens?: true,
        snippet: nil
      ]

      assert "do_sth()" ==
               Completion.function_snippet("do_sth", ["My.record(x: x0, y: y0)"], 1, opts)
    end
  end

  describe "do not suggest 0 arity functions after pipe" do
    test "moduledoc completion" do
      text = """
      defmodule MyModule do
        def hello do
          Date.today() |> 
          #               ^
        end
      end
      """

      {line, char} = {2, 20}

      TestUtils.assert_has_cursor_char(text, line, char)

      assert {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      refute Enum.any?(items, fn i -> i["label"] == "make_ref/0" end)
    end
  end

  describe "use the (arity - 1) version of snippets after pipe" do
    test "case/2 snippet skips the condition argument" do
      text = """
      defmodule MyModule do
        def hello do
          [1, 2]
          |> Enum.random()
          |> ca
          #    ^
        end
      end
      """

      {line, char} = {4, 9}
      TestUtils.assert_has_cursor_char(text, line, char)
      assert {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)
      assert %{"insertText" => insert_text} = Enum.find(items, &match?(%{"label" => "case"}, &1))
      assert insert_text =~ "case do\n\t"
    end

    test "unless/2 snippet skips the condition argument" do
      text = """
      defmodule MyModule do
        def hello do
          [1, 2]
          |> Enum.random()
          |> unl
          #     ^
        end
      end
      """

      {line, char} = {4, 10}
      TestUtils.assert_has_cursor_char(text, line, char)
      assert {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert %{"insertText" => insert_text} =
               Enum.find(items, &match?(%{"label" => "unless"}, &1))

      assert insert_text =~ "unless do\n\t"
    end

    test "if/2 snippet skips the condition argument" do
      text = """
      defmodule MyModule do
        def hello do
          [1, 2]
          |> Enum.random()
          |> if
          #    ^
        end
      end
      """

      {line, char} = {4, 9}
      TestUtils.assert_has_cursor_char(text, line, char)
      assert {:ok, %{"items" => items}} = Completion.completion(text, line, char, @supports)

      assert %{"insertText" => insert_text} = Enum.find(items, &match?(%{"label" => "if"}, &1))

      assert insert_text =~ "if do\n\t"
    end
  end

  describe "suggest_module_name/1" do
    import Completion, only: [suggest_module_name: 1]

    test "returns nil if current file_path is empty" do
      assert nil == suggest_module_name("")
    end

    test "returns nil if current file is not an .ex file" do
      assert nil == suggest_module_name("some/path/lib/dir/file.heex")
    end

    test "returns nil if current file is an .ex file but no lib folder exists in path" do
      assert nil == suggest_module_name("some/path/not_lib/dir/file.ex")
    end

    test "returns nil if current file is an *_test.exs file but no test folder exists in path" do
      assert nil == suggest_module_name("some/path/not_test/dir/file_test.exs")
    end

    test "returns an appropriate suggestion if file directly under lib" do
      assert "MyProject" == suggest_module_name("some/path/my_project/lib/my_project.ex")
    end

    test "returns an appropriate suggestion if file arbitrarily nested under lib/" do
      assert "MyProject.Foo.Bar.Baz.MyFile" =
               suggest_module_name("some/path/my_project/lib/my_project/foo/bar/baz/my_file.ex")
    end

    test "returns an appropriate suggestion if file directly under test/" do
      assert "MyProjectTest" ==
               suggest_module_name("some/path/my_project/test/my_project_test.exs")
    end

    test "returns an appropriate suggestion if file arbitrarily nested under test" do
      assert "MyProject.Foo.Bar.Baz.MyFileTest" ==
               suggest_module_name(
                 "some/path/my_project/test/my_project/foo/bar/baz/my_file_test.exs"
               )
    end

    test "returns an appropriate suggestion if file is part of an umbrella project" do
      assert "MySubApp.Foo.Bar.Baz" ==
               suggest_module_name(
                 "some/path/my_umbrella_project/apps/my_sub_app/lib/my_sub_app/foo/bar/baz.ex"
               )
    end

    test "returns appropriate suggestions for modules nested under known phoenix dirs" do
      [
        {"MyProjectWeb.MyController", "controllers/my_controller.ex"},
        {"MyProjectWeb.MyPlug", "plugs/my_plug.ex"},
        {"MyProjectWeb.MyView", "views/my_view.ex"},
        {"MyProjectWeb.MyChannel", "channels/my_channel.ex"},
        {"MyProjectWeb.MyEndpoint", "endpoints/my_endpoint.ex"},
        {"MyProjectWeb.MySocket", "sockets/my_socket.ex"},
        {"MyProjectWeb.MyviewLive.MyComponent", "live/myview_live/my_component.ex"},
        {"MyProjectWeb.MyComponent", "components/my_component.ex"}
      ]
      |> Enum.each(fn {expected_module_name, partial_path} ->
        path = "some/path/my_project/lib/my_project_web/#{partial_path}"
        assert expected_module_name == suggest_module_name(path)
      end)
    end

    test "uses known Phoenix dirs as part of a module's name if these are not located directly beneath the *_web folder" do
      assert "MyProject.Controllers.MyController" ==
               suggest_module_name(
                 "some/path/my_project/lib/my_project/controllers/my_controller.ex"
               )

      assert "MyProjectWeb.SomeNestedDir.Controllers.MyController" ==
               suggest_module_name(
                 "some/path/my_project/lib/my_project_web/some_nested_dir/controllers/my_controller.ex"
               )
    end
  end
end
