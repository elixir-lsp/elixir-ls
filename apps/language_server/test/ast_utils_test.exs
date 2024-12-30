defmodule ElixirLS.LanguageServer.AstUtilsTest do
  use ExUnit.Case

  import ElixirLS.LanguageServer.Protocol
  import ElixirLS.LanguageServer.AstUtils

  defp get_range(code) do
    # IO.puts(code)

    {:ok, ast} =
      Code.string_to_quoted(code,
        columns: true,
        token_metadata: true,
        unescape: false,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}}
      )

    # dbg(ast)
    node_range(ast)
  end

  describe "literals" do
    test "true" do
      assert get_range("true") == range(0, 0, 0, 4)
    end

    test "false" do
      assert get_range("false") == range(0, 0, 0, 5)
    end

    test "nil" do
      assert get_range("nil") == range(0, 0, 0, 3)
    end

    if Version.match?(System.version(), ">= 1.18.0") do
      test "true as atom" do
        assert get_range(":true") == range(0, 0, 0, 5)
      end
    end

    test "integer" do
      assert get_range("1234") == range(0, 0, 0, 4)

      assert node_range({:__block__, [token: "2", line: 1, column: 10], [2]}) ==
               range(0, 9, 0, 10)
    end

    test "float" do
      assert get_range("123.4") == range(0, 0, 0, 5)
    end

    test "atom" do
      assert get_range(":abc") == range(0, 0, 0, 4)
    end

    test "quoted atom string" do
      assert get_range(":\"abc\"") == range(0, 0, 0, 6)
    end

    test "quoted atom charlist" do
      assert get_range(":'abc'") == range(0, 0, 0, 6)
    end

    test "quoted atom string interpolated" do
      assert get_range(":\"ab\#{inspect(self())}c\"") == range(0, 0, 0, 24)
    end

    test "quoted atom charlist interpolated" do
      assert get_range(":'ab\#{inspect(self())}c'") == range(0, 0, 0, 24)
    end

    test "string" do
      assert get_range("\"abc\"") == range(0, 0, 0, 5)
    end

    test "charlist" do
      assert get_range("'abc'") == range(0, 0, 0, 5)
    end

    test "string with newlines" do
      assert get_range("\"ab\nc\"") == range(0, 0, 1, 2)
    end

    test "charlist with newlines" do
      assert get_range("'ab\nc'") == range(0, 0, 1, 2)
    end

    test "string heredoc" do
      assert get_range("\"\"\"\nabc\n\"\"\"") == range(0, 0, 2, 3)
    end

    test "string heredoc with indentation" do
      assert get_range("\"\"\"\n  abc\n  \"\"\"") == range(0, 0, 2, 5)
    end

    test "charlist heredoc" do
      assert get_range("'''\nabc\n'''") == range(0, 0, 2, 3)
    end

    test "charlist heredoc with indentation" do
      assert get_range("'''\n  abc\n  '''") == range(0, 0, 2, 5)
    end

    test "string interpolated" do
      assert get_range("\"abc \#{inspect(a)} sd\"") == range(0, 0, 0, 22)
    end

    test "charlist interpolated" do
      assert get_range("'abc \#{inspect(a)} sd'") == range(0, 0, 0, 22)
    end

    test "string heredoc interpolated" do
      assert get_range("\"\"\"\nab\#{inspect(a)}c\n\"\"\"") == range(0, 0, 2, 3)
    end

    test "charlist heredoc interpolated" do
      assert get_range("'''\nab\#{inspect(a)}c\n'''") == range(0, 0, 2, 3)
    end

    test "sigil" do
      assert get_range("~w(asd fgh)") == range(0, 0, 0, 11)
    end

    test "sigil with modifier" do
      assert get_range("~w(asd fgh)a") == range(0, 0, 0, 12)
    end

    test "sigil with interpolation" do
      text = "~s(asd \#{inspect(self())} fgh)"
      assert get_range(text) == range(0, 0, 0, 30)
    end

    test "sigil with heredoc string" do
      text = """
      ~S\"\"\"
      some text
      \"\"\"
      """

      assert get_range(text) == range(0, 0, 2, 3)
    end

    test "sigil with heredoc charlist" do
      text = """
      ~S'''
      some text
      '''
      """

      assert get_range(text) == range(0, 0, 2, 3)
    end

    test "empty tuple" do
      assert get_range("{}") == range(0, 0, 0, 2)
    end

    test "1 element tuple" do
      assert get_range("{:ok}") == range(0, 0, 0, 5)
    end

    test "2 element tuple" do
      assert get_range("{:ok, 123}") == range(0, 0, 0, 10)
    end

    test "3 element tuple" do
      assert get_range("{:ok, 123, nil}") == range(0, 0, 0, 15)
    end

    test "empty list" do
      assert get_range("[]") == range(0, 0, 0, 2)
    end

    test "1 element list" do
      assert get_range("[123]") == range(0, 0, 0, 5)
    end

    test "2 element list" do
      assert get_range("[123, 456]") == range(0, 0, 0, 10)
    end

    test "1 element list with cons operator" do
      assert get_range("[123 | abc]") == range(0, 0, 0, 11)
    end

    test "2 element list with cons operator" do
      assert get_range("[123, 456 | abc]") == range(0, 0, 0, 16)
    end

    test "keyword" do
      assert get_range("[abc: 2]") == range(0, 0, 0, 8)
    end

    test "empty map" do
      assert get_range("%{}") == range(0, 0, 0, 3)
    end

    test "map with string key" do
      assert get_range("%{\"abc\" => 1}") == range(0, 0, 0, 13)
    end

    test "map with atom key" do
      assert get_range("%{abc: 1}") == range(0, 0, 0, 9)
    end

    test "map update syntax" do
      assert get_range("%{var | abc: 1}") == range(0, 0, 0, 15)
    end

    test "alias" do
      assert get_range("Some") == range(0, 0, 0, 4)
    end

    test "alias nested" do
      assert get_range("Some.Foo") == range(0, 0, 0, 8)
    end

    test "empty struct" do
      assert get_range("%Some{}") == range(0, 0, 0, 7)
    end

    test "struct with atom key" do
      assert get_range("%Some{abc: 1}") == range(0, 0, 0, 13)
    end

    test "struct update syntax" do
      assert get_range("%Some{var | abc: 1}") == range(0, 0, 0, 19)
    end

    test "empty bitstring" do
      assert get_range("<<>>") == range(0, 0, 0, 4)
    end

    test "bitstring with content" do
      assert get_range("<< 0 >>") == range(0, 0, 0, 7)
    end

    test "variable" do
      assert get_range("var") == range(0, 0, 0, 3)
    end

    test "module attribute" do
      assert get_range("@attr") == range(0, 0, 0, 5)
    end

    test "module attribute definition" do
      assert get_range("@attr 123") == range(0, 0, 0, 9)
    end

    test "binary operator" do
      assert get_range("var + foo") == range(0, 0, 0, 9)
    end

    test "nested binary operators" do
      assert get_range("var * 3 + foo / x") == range(0, 0, 0, 17)
    end

    # Parser is simplifying the expression and not including the parens
    # we handle parens meta in selection ranges
    # test "nested binary operators with parens" do
    #   assert get_range("var * 3 * (foo + x)") == range(0, 0, 0, 19)
    # end

    test "nested binary and unary operators" do
      assert get_range("var * 3 + foo / -x") == range(0, 0, 0, 18)
    end

    test "if" do
      text = """
      if true do
        1
      end
      """

      assert get_range(text) == range(0, 0, 2, 3)
    end

    test "if else" do
      text = """
      if true do
        1
      else
        2
      end
      """

      assert get_range(text) == range(0, 0, 4, 3)
    end

    test "if short notation" do
      text = """
      if true, do: 1
      """

      assert get_range(text) == range(0, 0, 0, 14)
    end

    test "case" do
      text = """
      case x do
        ^abc ->
          :ok
        true ->
          :error
      end
      """

      assert get_range(text) == range(0, 0, 5, 3)
    end

    test "cond" do
      text = """
      cond do
        abc == 1 ->
          :ok
        true ->
          :error
      end
      """

      assert get_range(text) == range(0, 0, 5, 3)
    end

    test "local call" do
      assert get_range("local(123)") == range(0, 0, 0, 10)
    end

    test "variable call" do
      assert get_range("local.(123)") == range(0, 0, 0, 11)
    end

    test "nested call" do
      assert get_range("local.prop.foo") == range(0, 0, 0, 14)
    end

    test "access" do
      assert get_range("local[\"some\"]") == range(0, 0, 0, 13)
    end

    test "nested access" do
      assert get_range("local[\"some\"][1]") == range(0, 0, 0, 16)
    end

    test "remote call" do
      assert get_range("Some.fun(123)") == range(0, 0, 0, 13)
    end

    test "remote call on atom" do
      assert get_range(":some.fun(123)") == range(0, 0, 0, 14)
    end

    test "remote call quoted string" do
      assert get_range("Some.\"0fun\"(123)") == range(0, 0, 0, 16)
    end

    test "remote call quoted charlist" do
      assert get_range("Some.'0fun'(123)") == range(0, 0, 0, 16)
    end

    test "remote call pipe" do
      text = """
      123
      |> Some.fun1()
      """

      assert get_range(text) == range(0, 0, 1, 14)
    end

    test "remote call pipe no parens" do
      text = """
      123
      |> Some.fun1
      """

      assert get_range(text) == range(0, 0, 1, 12)
    end

    test "local call pipe" do
      text = """
      123
      |> local()
      """

      assert get_range(text) == range(0, 0, 1, 10)
    end

    test "local call pipe no parens" do
      text = """
      123
      |> local
      """

      assert get_range(text) == range(0, 0, 1, 8)
    end

    test "local call no parens" do
      assert get_range("local 123") == range(0, 0, 0, 9)
    end

    test "remote call no parens" do
      assert get_range("Some.fun 123") == range(0, 0, 0, 12)
    end

    test "local capture" do
      assert get_range("&local/1") == range(0, 0, 0, 8)
    end

    test "remote capture" do
      assert get_range("&Some.fun/1") == range(0, 0, 0, 11)
    end

    test "remote capture quoted" do
      assert get_range("&Some.\"fun\"/1") == range(0, 0, 0, 13)
    end

    test "anonymous capture" do
      assert get_range("& &1 + 1") == range(0, 0, 0, 8)
    end

    test "complicated local call" do
      text = """
      fun(%My{} = my, keyword: 123, other: [:a, ""])
      """

      assert get_range(text) == range(0, 0, 0, 46)
    end

    test "block" do
      text = """
      a = foo()
      b = bar()
      :ok
      """

      assert get_range(text) == range(0, 0, 2, 3)
    end

    test "anonymous function no args" do
      test = """
      fn -> 1 end
      """

      assert get_range(test) == range(0, 0, 0, 11)
    end

    test "anonymous function multiple args" do
      test = """
      fn a, b -> 1 end
      """

      assert get_range(test) == range(0, 0, 0, 16)
    end

    test "anonymous function multiple clauses" do
      test = """
      fn
        1 -> 1
        _ -> 2
      end
      """

      assert get_range(test) == range(0, 0, 3, 3)
    end

    test "with" do
      text = """
      with {:ok, x} <- foo() do
        x
      end
      """

      assert get_range(text) == range(0, 0, 2, 3)
    end

    test "def short notation" do
      test = ~S"""
      defp name(%Config{} = config),
        do: :"#{__MODULE__}_#{config.node_id}_#{config.channel_unique_id}"
      """

      assert get_range(test) == range(0, 0, 1, 68)
    end
  end
end
