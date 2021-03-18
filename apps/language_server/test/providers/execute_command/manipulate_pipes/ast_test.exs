defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes.ASTTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes.AST

  describe "to_pipe/1" do
    test "single-line selection with two args in named function" do
      assert_piped("A.B.C.a |> X.Y.Z.function_name(b)", "X.Y.Z.function_name(A.B.C.a, b)")
    end

    test "single-line selection with single arg in named function" do
      assert_piped("A.B.C.a |> X.Y.Z.function_name()", "X.Y.Z.function_name(A.B.C.a)")
    end

    test "single-line selection with two args in anonymous function" do
      assert_piped("A.B.C.a |> X.Y.Z.function_name.(b)", "X.Y.Z.function_name.(A.B.C.a, b)")
    end

    test "single-line selection with single arg in anonymous function" do
      assert_piped("A.B.C.a |> function_name.()", "function_name.(A.B.C.a)")
    end

    test "multi-line selection with two args in named function" do
      assert_piped("X.Y.Z.a |> X.Y.Z.function_name(b, c)", """
        X.Y.Z.function_name(
        X.Y.Z.a,
        b,
        c
      )
      """)
    end
  end

  defp assert_piped(expected, input) do
    assert expected ==
             input
             |> Code.string_to_quoted!()
             |> AST.to_pipe()
             |> Macro.to_string()
  end
end
