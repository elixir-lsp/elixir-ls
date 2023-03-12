defmodule ElixirLS.LanguageServer.Experimental.CodeMod.AstTest do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast

  use ExUnit.Case

  describe "ast" do
    test "from\2 / to_string\1" do
      string = """
      defmodule Bar do
        def foo(baz) do
          # TODO
        end
      end
      """

      {:ok, ast} = Ast.from(string, include_comments: true)
      assert string == Ast.to_string(ast) <> "\n"

      {:ok, ast_missing_comments} = Ast.from(string)

      assert """
             defmodule Bar do
               def foo(baz) do
               end
             end
             """ == Ast.to_string(ast_missing_comments) <> "\n"
    end

    test "from\1" do
      assert {:ok,
              {:def, [do: [line: 1, column: 16], end: [line: 3, column: 3], line: 1, column: 3],
               [
                 {:foo, [closing: [line: 1, column: 14], line: 1, column: 7],
                  [{:baz, [line: 1, column: 11], nil}]},
                 [do: {:__block__, [], []}]
               ]}} =
               Ast.from("""
                 def foo(baz) do
                   # TODO
                 end
               """)
    end

    test "from\2" do
      assert {:ok,
              {:def,
               [
                 trailing_comments: [
                   %{column: 5, line: 2, next_eol_count: 1, previous_eol_count: 1, text: "# TODO"}
                 ],
                 leading_comments: [],
                 do: [line: 1, column: 16],
                 end: [line: 3, column: 3],
                 line: 1,
                 column: 3
               ],
               [
                 {:foo,
                  [
                    trailing_comments: [],
                    leading_comments: [],
                    closing: [line: 1, column: 14],
                    line: 1,
                    column: 7
                  ],
                  [
                    {:baz, [trailing_comments: [], leading_comments: [], line: 1, column: 11],
                     nil}
                  ]},
                 [
                   {{:__block__,
                     [trailing_comments: [], leading_comments: [], line: 1, column: 16], [:do]},
                    {:__block__, [trailing_comments: [], leading_comments: []], []}}
                 ]
               ]}} =
               Ast.from(
                 """
                   def foo(baz) do
                     # TODO
                   end
                 """,
                 include_comments: true
               )
    end
  end
end
