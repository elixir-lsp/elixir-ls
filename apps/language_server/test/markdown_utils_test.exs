defmodule ElixirLS.LanguageServer.MarkdownUtilsTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.MarkdownUtils

  @main_document """
  # Main Title

  ## Sub Title

  ### Section to Embed Fragment

  """

  describe "adjust_headings/3" do
    test "no headings" do
      fragment = """
      Regular text without any heading.
      """

      adjusted_fragment = MarkdownUtils.adjust_headings(fragment, 3)

      main_document = @main_document <> adjusted_fragment

      assert main_document == """
             # Main Title

             ## Sub Title

             ### Section to Embed Fragment

             Regular text without any heading.
             """
    end

    test "headings lower than main document" do
      fragment = """
      # Fragment Title

      ## Fragment Subtitle
      """

      adjusted_fragment = MarkdownUtils.adjust_headings(fragment, 3)

      main_document = @main_document <> adjusted_fragment

      assert main_document == """
             # Main Title

             ## Sub Title

             ### Section to Embed Fragment

             #### Fragment Title

             ##### Fragment Subtitle
             """
    end

    test "headings higher than main document" do
      fragment = """
      ##### Fragment Title

      ###### Fragment Subtitle
      """

      adjusted_fragment = MarkdownUtils.adjust_headings(fragment, 3)

      main_document = @main_document <> adjusted_fragment

      assert main_document == """
             # Main Title

             ## Sub Title

             ### Section to Embed Fragment

             #### Fragment Title

             ##### Fragment Subtitle
             """
    end
  end

  test "join_with_horizontal_rule/1" do
    part_1 = """

    Foo

    """

    part_2 = """
    Bar
    """

    assert MarkdownUtils.join_with_horizontal_rule([part_1, part_2]) == """
           Foo

           ---

           Bar
           """
  end

  describe "ex_doc links" do
    # The test cases here base on autolink documentation from https://hexdocs.pm/ex_doc/readme.html#auto-linking
    # and test cases from https://github.com/elixir-lang/ex_doc/blob/v0.31.1/test/ex_doc/language/elixir_test.exs
    # TODO add support for OTP 27

    @version System.version()
    test "elixir module link with prefix" do
      assert MarkdownUtils.transform_ex_doc_links("`m:Keyword`") ==
               "[`Keyword`](https://hexdocs.pm/elixir/#{@version}/Keyword.html)"
    end

    test "elixir module link without prefix" do
      assert MarkdownUtils.transform_ex_doc_links("`Keyword`") ==
               "[`Keyword`](https://hexdocs.pm/elixir/#{@version}/Keyword.html)"
    end

    test "elixir module link with Elixir." do
      assert MarkdownUtils.transform_ex_doc_links("`Elixir.Keyword`") ==
               "[`Elixir.Keyword`](https://hexdocs.pm/elixir/#{@version}/Keyword.html)"
    end

    test "elixir module link nested" do
      assert MarkdownUtils.transform_ex_doc_links("`IEx.Helpers`") ==
               "[`IEx.Helpers`](https://hexdocs.pm/iex/#{@version}/IEx.Helpers.html)"
    end

    test "module not found" do
      assert MarkdownUtils.transform_ex_doc_links("`PATH`") == "`PATH`"
    end

    test "atom" do
      assert MarkdownUtils.transform_ex_doc_links("`:atom`") == "`:atom`"
    end

    test "elixir module link with anchor" do
      assert MarkdownUtils.transform_ex_doc_links(
               "`m:Keyword#module-duplicate-keys-and-ordering`"
             ) ==
               "[`Keyword`](https://hexdocs.pm/elixir/#{@version}/Keyword.html#module-duplicate-keys-and-ordering)"
    end

    test "erlang module link with prefix" do
      assert MarkdownUtils.transform_ex_doc_links("`m:elixir_tokenizer`") ==
               "[`elixir_tokenizer`](https://hexdocs.pm/elixir/#{@version}/elixir_tokenizer.html)"
    end

    test "elixir type link with prefix" do
      assert MarkdownUtils.transform_ex_doc_links("`t:Macro.t/0`") ==
               "[`Macro.t/0`](https://hexdocs.pm/elixir/#{@version}/Macro.html#t:t/0)"
    end

    test "elixir type link without module" do
      assert MarkdownUtils.transform_ex_doc_links("`t:t/0`", Macro) ==
               "[`t/0`](https://hexdocs.pm/elixir/#{@version}/Macro.html#t:t/0)"
    end

    test "elixir basic/builtin type" do
      assert MarkdownUtils.transform_ex_doc_links("`t:atom/0`", Macro) ==
               "[`atom/0`](https://hexdocs.pm/elixir/#{@version}/typespecs.html#basic-types)"

      assert MarkdownUtils.transform_ex_doc_links("`t:keyword/0`", Macro) ==
               "[`keyword/0`](https://hexdocs.pm/elixir/#{@version}/typespecs.html#built-in-types)"
    end

    test "erlang type" do
      expected =
        if System.otp_release() |> String.to_integer() >= 27 do
          "[`:array.array/0`](https://www.erlang.org/doc/apps/stdlib/array.html#t:array/0)"
        else
          "[`:array.array/0`](https://www.erlang.org/doc/man/array.html#type-array)"
        end

      assert MarkdownUtils.transform_ex_doc_links("`t::array.array/0`") == expected
    end

    test "elixir callback link with prefix" do
      assert MarkdownUtils.transform_ex_doc_links("`c:GenServer.init/1`") ==
               "[`GenServer.init/1`](https://hexdocs.pm/elixir/#{@version}/GenServer.html#c:init/1)"
    end

    test "erlang callback" do
      expected =
        if System.otp_release() |> String.to_integer() >= 27 do
          "[`:gen_server.handle_call/3`](https://www.erlang.org/doc/apps/stdlib/gen_server.html#c:handle_call/3)"
        else
          "[`:gen_server.handle_call/3`](https://www.erlang.org/doc/man/gen_server.html#Module:handle_call-3)"
        end

      assert MarkdownUtils.transform_ex_doc_links("`c::gen_server.handle_call/3`") == expected
    end

    test "elixir callback link without module" do
      assert MarkdownUtils.transform_ex_doc_links("`c:init/1`", GenServer) ==
               "[`init/1`](https://hexdocs.pm/elixir/#{@version}/GenServer.html#c:init/1)"
    end

    test "elixir function link with prefix" do
      assert MarkdownUtils.transform_ex_doc_links("`Node.alive?/0`") ==
               "[`Node.alive?/0`](https://hexdocs.pm/elixir/#{@version}/Node.html#alive?/0)"
    end

    test "elixir function link with custom test" do
      assert MarkdownUtils.transform_ex_doc_links("[custom text](`Node.alive?/0`)") ==
               "[custom text](https://hexdocs.pm/elixir/#{@version}/Node.html#alive?/0)"
    end

    test "elixir function link without module" do
      assert MarkdownUtils.transform_ex_doc_links("`alive?/0`", Node) ==
               "[`alive?/0`](https://hexdocs.pm/elixir/#{@version}/Node.html#alive?/0)"
    end

    test "elixir auto imported function" do
      assert MarkdownUtils.transform_ex_doc_links("`+/2`", Kernel) ==
               "[`+/2`](https://hexdocs.pm/elixir/#{@version}/Kernel.html#+/2)"

      assert MarkdownUtils.transform_ex_doc_links("`for/1`", Kernel.SpecialForms) ==
               "[`for/1`](https://hexdocs.pm/elixir/#{@version}/Kernel.SpecialForms.html#for/1)"
    end

    test "elixir auto imported function from other module" do
      assert MarkdownUtils.transform_ex_doc_links("`+/2`", List) ==
               "[`+/2`](https://hexdocs.pm/elixir/#{@version}/Kernel.html#+/2)"

      assert MarkdownUtils.transform_ex_doc_links("`for/1`", List) ==
               "[`for/1`](https://hexdocs.pm/elixir/#{@version}/Kernel.SpecialForms.html#for/1)"
    end

    test "special cases" do
      assert MarkdownUtils.transform_ex_doc_links("`..///3`", Kernel) ==
               "[`..///3`](https://hexdocs.pm/elixir/#{@version}/Kernel.html#..///3)"

      assert MarkdownUtils.transform_ex_doc_links("`../2`", Kernel) ==
               "[`../2`](https://hexdocs.pm/elixir/#{@version}/Kernel.html#../2)"

      assert MarkdownUtils.transform_ex_doc_links("`../0`", Kernel) ==
               "[`../0`](https://hexdocs.pm/elixir/#{@version}/Kernel.html#../0)"

      assert MarkdownUtils.transform_ex_doc_links("`::/2`", Kernel.SpecialForms) ==
               "[`::/2`](https://hexdocs.pm/elixir/#{@version}/Kernel.SpecialForms.html#::/2)"
    end

    test "erlang function link" do
      assert MarkdownUtils.transform_ex_doc_links("`elixir_tokenizer:tokenize/1`") ==
               "[`elixir_tokenizer:tokenize/1`](https://hexdocs.pm/elixir/#{@version}/elixir_tokenizer.html#tokenize/1)"
    end

    test "erlang stdlib function link" do
      expected =
        if System.otp_release() |> String.to_integer() >= 27 do
          "[`:lists.all/2`](https://www.erlang.org/doc/apps/stdlib/lists.html#all/2)"
        else
          "[`:lists.all/2`](https://www.erlang.org/doc/man/lists.html#all-2)"
        end

      assert MarkdownUtils.transform_ex_doc_links("`:lists.all/2`") == expected
    end

    test "extra page" do
      assert MarkdownUtils.transform_ex_doc_links("[Up and running](Up and running.md)", Kernel) ==
               "[Up and running](https://hexdocs.pm/elixir/#{@version}/up-and-running.html)"
    end

    test "extra page with anchor" do
      assert MarkdownUtils.transform_ex_doc_links(
               "[Expressions](`e:elixir:syntax-reference.md#expressions`)"
             ) ==
               "[Expressions](https://hexdocs.pm/elixir/#{@version}/syntax-reference.html#expressions)"
    end

    test "extra page with anchor no prefix" do
      assert MarkdownUtils.transform_ex_doc_links(
               "[\"The need for monitoring\"](genservers.md#the-need-for-monitoring)",
               Process
             ) ==
               "[\"The need for monitoring\"](https://hexdocs.pm/elixir/#{@version}/genservers.html#the-need-for-monitoring)"
    end

    test "extra page only anchor" do
      assert MarkdownUtils.transform_ex_doc_links(
               "[the module documentation](#module-aliases)",
               Process
             ) ==
               "[the module documentation](https://hexdocs.pm/elixir/#{@version}/Process.html#module-aliases)"
    end

    test "extra page external" do
      assert MarkdownUtils.transform_ex_doc_links(
               "[Up and running](http://example.com/foo.md)",
               Kernel
             ) == "[Up and running](http://example.com/foo.md)"
    end

    test "erlang extra page" do
      assert MarkdownUtils.transform_ex_doc_links(
               "[Up and running](e:erts_alloc.md)",
               :erlang
             ) == "[Up and running](https://www.erlang.org/doc/apps/erts/erts_alloc.html)"
    end

    test "erlang extra page with app" do
      assert MarkdownUtils.transform_ex_doc_links(
               "[Up and running](e:system:expressions.md#term-comparisons)",
               :lists
             ) ==
               "[Up and running](https://www.erlang.org/doc/system/expressions.html#term-comparisons)"
    end

    test "expression" do
      assert MarkdownUtils.transform_ex_doc_links("`1 + 2`") == "`1 + 2`"
    end
  end

  @tag :skip
  test "integration" do
    for app <- [
          :elixir,
          :iex,
          :exunit,
          :logger,
          :mix,
          :stdlib,
          :erts
        ] do
      modules =
        case :application.get_key(app, :modules) do
          {:ok, modules} -> modules
          :undefined -> []
        end

      for module <- modules do
        case ElixirSense.Core.Normalized.Code.get_docs(module, :moduledoc) do
          {_, doc, _} when is_binary(doc) ->
            MarkdownUtils.transform_ex_doc_links(doc, module)

          _ ->
            :ok
        end

        for {_ma, _, _, doc, _} when is_binary(doc) <-
              ElixirSense.Core.Normalized.Code.get_docs(module, :type_docs) |> List.wrap() do
          MarkdownUtils.transform_ex_doc_links(doc, module)
        end

        for {_ma, _, _, doc, _} when is_binary(doc) <-
              ElixirSense.Core.Normalized.Code.get_docs(module, :callback_docs) |> List.wrap() do
          MarkdownUtils.transform_ex_doc_links(doc, module)
        end

        for {_ma, _, _, _, doc, _} when is_binary(doc) <-
              ElixirSense.Core.Normalized.Code.get_docs(module, :docs) |> List.wrap() do
          MarkdownUtils.transform_ex_doc_links(doc, module)
        end
      end
    end
  end
end
