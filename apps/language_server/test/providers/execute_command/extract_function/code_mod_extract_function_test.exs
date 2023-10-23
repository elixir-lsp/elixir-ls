defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExtractFunction.CodeModExtractFunctionTest do
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ExtractFunction.CodeModExtractFunction

  use ExUnit.Case
  alias VendoredSourceror.Zipper, as: Z

  setup ctx do
    if Map.has_key?(ctx, :no_setup) do
      {:ok, []}
    else
      no = Map.get(ctx, :no, "")

      {:ok,
       quoted:
         """
         defmodule Baz#{no} do
           def foo(one, two) do
             three = 3
             IO.inspect(one)
             IO.inspect(two)
             IO.inspect(three)
             four = 4
             IO.inspect(three)

             IO.inspect(four: four,
               force_format_on_new_line_with_really_long_atom: true
             )

             # comment
           end
         end
         """
         |> VendoredSourceror.parse_string!()}
    end
  end

  describe "extract_function" do
    @tag no: 1
    test "extract one line to function", %{quoted: quoted} do
      zipper = CodeModExtractFunction.extract_function(Z.zip(quoted), 3, 3, "bar")
      source = VendoredSourceror.to_string(zipper)

      assert [
               "defmodule Baz1 do",
               "  def foo(one, two) do",
               "    three = bar()",
               "    IO.inspect(one)",
               "    IO.inspect(two)",
               "    IO.inspect(three)",
               "    four = 4",
               "    IO.inspect(three)",
               "",
               "    IO.inspect(",
               "      four: four,",
               "      force_format_on_new_line_with_really_long_atom: true",
               "    )",
               "",
               "    # comment",
               "  end",
               "",
               "  def bar() do",
               "    three = 3",
               "    three",
               "  end",
               "end"
             ] ==
               source |> String.split("\n")

      Code.eval_string(source)
    end

    @tag no: 2
    test "extract multiple lines to function", %{quoted: quoted} do
      zipper = CodeModExtractFunction.extract_function(Z.zip(quoted), 3, 4, :bar)
      source = VendoredSourceror.to_string(zipper)

      assert [
               "defmodule Baz2 do",
               "  def foo(one, two) do",
               "    three = bar(one)",
               "    IO.inspect(two)",
               "    IO.inspect(three)",
               "    four = 4",
               "    IO.inspect(three)",
               "",
               "    IO.inspect(",
               "      four: four,",
               "      force_format_on_new_line_with_really_long_atom: true",
               "    )",
               "",
               "    # comment",
               "  end",
               "",
               "  def bar(one) do",
               "    three = 3",
               "    IO.inspect(one)",
               "    three",
               "  end",
               "end"
             ] ==
               source |> String.split("\n")

      Code.eval_string(source)
    end

    @tag no: 3
    test "extract multiple lines with multiple returns to function", %{quoted: quoted} do
      zipper = CodeModExtractFunction.extract_function(Z.zip(quoted), 3, 7, :bar)
      source = VendoredSourceror.to_string(zipper)

      assert [
               "defmodule Baz3 do",
               "  def foo(one, two) do",
               "    {three, four} = bar(one, two)",
               "    IO.inspect(three)",
               "",
               "    IO.inspect(",
               "      four: four,",
               "      force_format_on_new_line_with_really_long_atom: true",
               "    )",
               "",
               "    # comment",
               "  end",
               "",
               "  def bar(one, two) do",
               "    three = 3",
               "    IO.inspect(one)",
               "    IO.inspect(two)",
               "    IO.inspect(three)",
               "    four = 4",
               "    {three, four}",
               "  end",
               "end"
             ] ==
               source |> String.split("\n")

      Code.eval_string(source)
    end

    @tag no: 4
    test "extract multiple lines with single return value to function", %{quoted: quoted} do
      zipper = CodeModExtractFunction.extract_function(Z.zip(quoted), 3, 8, :bar)
      source = VendoredSourceror.to_string(zipper)

      assert [
               "defmodule Baz4 do",
               "  def foo(one, two) do",
               "    four = bar(one, two)",
               "",
               "    IO.inspect(",
               "      four: four,",
               "      force_format_on_new_line_with_really_long_atom: true",
               "    )",
               "",
               "    # comment",
               "  end",
               "",
               "  def bar(one, two) do",
               "    three = 3",
               "    IO.inspect(one)",
               "    IO.inspect(two)",
               "    IO.inspect(three)",
               "    four = 4",
               "    IO.inspect(three)",
               "",
               "    four",
               "  end",
               "end"
             ] ==
               source |> String.split("\n")

      Code.eval_string(source)
    end

    @tag no: 5
    test "extracts when extract partial function call", %{quoted: quoted} do
      zipper = CodeModExtractFunction.extract_function(Z.zip(quoted), 10, 10, :bar)
      source = VendoredSourceror.to_string(zipper)

      assert [
               "defmodule Baz5 do",
               "  def foo(one, two) do",
               "    three = 3",
               "    IO.inspect(one)",
               "    IO.inspect(two)",
               "    IO.inspect(three)",
               "    four = 4",
               "    IO.inspect(three)",
               "",
               "    bar(four)",
               "",
               "    # comment",
               "  end",
               "",
               "  def bar(four) do",
               "    IO.inspect(",
               "      four: four,",
               "      force_format_on_new_line_with_really_long_atom: true",
               "    )",
               "  end",
               "end"
             ] ==
               source |> String.split("\n")

      Code.eval_string(source)
    end

    @tag no: 6
    test "errors when extract on second line of multi-line function call", %{quoted: quoted} do
      {:error, :not_extractable} =
        CodeModExtractFunction.extract_function(Z.zip(quoted), 11, 11, :bar)
    end
  end

  describe "extract_lines/3" do
    @tag no: 20
    test "extract one line to function", %{quoted: quoted} do
      {zipper, lines} = CodeModExtractFunction.extract_lines(Z.zip(quoted), 3, 3)

      assert "defmodule Baz20 do\n  def foo(one, two) do\n    IO.inspect(one)\n    IO.inspect(two)\n    IO.inspect(three)\n    four = 4\n    IO.inspect(three)\n\n    IO.inspect(\n      four: four,\n      force_format_on_new_line_with_really_long_atom: true\n    )\n\n    # comment\n  end\nend" ==
               VendoredSourceror.to_string(zipper)

      assert [
               "{:def, :foo}",
               "{:def_end, 15}",
               "{:lines, [three = 3]}",
               _,
               "{:vars, [:one, :two, :three, :four]}"
             ] = lines |> Enum.map(&VendoredSourceror.to_string(&1))
    end

    @tag no: 21
    test "extract multiple lines to function", %{quoted: quoted} do
      {zipper, lines} = CodeModExtractFunction.extract_lines(Z.zip(quoted), 3, 4)

      assert "defmodule Baz21 do\n  def foo(one, two) do\n    IO.inspect(two)\n    IO.inspect(three)\n    four = 4\n    IO.inspect(three)\n\n    IO.inspect(\n      four: four,\n      force_format_on_new_line_with_really_long_atom: true\n    )\n\n    # comment\n  end\nend" =
               VendoredSourceror.to_string(zipper)

      assert [
               "{:def, :foo}",
               "{:def_end, 15}",
               "{:lines, [three = 3, IO.inspect(one)]}",
               _,
               "{:vars, [:two, :three, :four]}"
             ] = lines |> Enum.map(&VendoredSourceror.to_string(&1))
    end

    @tag no: 22
    test "extract multi-line function call to function", %{quoted: quoted} do
      {zipper, lines} = CodeModExtractFunction.extract_lines(Z.zip(quoted), 10, 10)

      assert "defmodule Baz22 do\n  def foo(one, two) do\n    three = 3\n    IO.inspect(one)\n    IO.inspect(two)\n    IO.inspect(three)\n    four = 4\n    IO.inspect(three)\n\n    # comment\n  end\nend" =
               VendoredSourceror.to_string(zipper)

      assert [
               "{:def, :foo}",
               "{:def_end, 15}",
               "{:lines,\n [\n   IO.inspect(\n     four: four,\n     force_format_on_new_line_with_really_long_atom: true\n   )\n ]}",
               "{:replace_with, nil}",
               "{:vars, []}"
             ] = lines |> Enum.map(&VendoredSourceror.to_string(&1))
    end

    @tag no: 23
    test "noop when second line of multi-line function call", %{quoted: quoted} do
      {zipper, lines} = CodeModExtractFunction.extract_lines(Z.zip(quoted), 11, 11)

      assert "defmodule Baz23 do\n  def foo(one, two) do\n    three = 3\n    IO.inspect(one)\n    IO.inspect(two)\n    IO.inspect(three)\n    four = 4\n    IO.inspect(three)\n\n    IO.inspect(\n      four: four,\n      force_format_on_new_line_with_really_long_atom: true\n    )\n\n    # comment\n  end\nend" =
               VendoredSourceror.to_string(zipper)

      assert [
               "{:def, :foo}",
               "{:def_end, 15}",
               "{:lines, []}",
               "{:replace_with, nil}",
               "{:vars, []}"
             ] = lines |> Enum.map(&VendoredSourceror.to_string(&1))
    end
  end
end
