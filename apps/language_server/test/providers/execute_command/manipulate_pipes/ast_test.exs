defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes.ASTTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes.AST

  describe "to_pipe/1" do
    test "single-line selection with two args in named function" do
      assert AST.to_pipe("X.Y.Z.function_name(A.B.C.a(), b)") ==
               "A.B.C.a() |> X.Y.Z.function_name(b)"
    end

    test "single-line selection with single arg in named function" do
      assert AST.to_pipe("X.Y.Z.function_name(A.B.C.a())") == "A.B.C.a() |> X.Y.Z.function_name()"
    end

    test "single-line selection with two args in anonymous function" do
      assert AST.to_pipe("X.Y.Z.function_name.(A.B.C.a(), b)") ==
               "A.B.C.a() |> X.Y.Z.function_name.(b)"
    end

    test "single-line selection with single arg in anonymous function" do
      assert AST.to_pipe("function_name.(A.B.C.a())") == "A.B.C.a() |> function_name.()"
    end

    test "multi-line selection with two args in named function" do
      assert AST.to_pipe("""
               X.Y.Z.function_name(
               X.Y.Z.a(),
               b,
               c
             )
             """) == "X.Y.Z.a() |> X.Y.Z.function_name(b, c)"
    end
  end

  describe "from_pipe/1 single-line" do
    test "three args in named function" do
      piped = "a |> function_name(b, c) |> after_call"
      unpiped = "function_name(a, b, c) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "pipe chain" do
      piped = "a |> b() |> function_name(c, d) |> after_call"
      unpiped = "b(a) |> function_name(c, d) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "pipe chain with no raw start" do
      piped = "b(a) |> function_name(c, d) |> after_call"
      unpiped = "function_name(b(a), c, d) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "single arg in named function" do
      piped = "a |> function_name() |> after_call"
      unpiped = "function_name(a) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "three args in anonymous function" do
      piped = "a |> function_name.(b, c) |> after_call"
      unpiped = "function_name.(a, b, c) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "single arg in anonymous function" do
      piped = "a |> function_name.() |> after_call"
      unpiped = "function_name.(a) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "three args in named function and statement before call" do
      piped = "a |> function_name(b, c) |> after_call"
      unpiped = "function_name(a, b, c) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "single arg in named function and statement before call" do
      piped = "a |> function_name() |> after_call"
      unpiped = "function_name(a) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "three args in anonymous function and statement before call" do
      piped = "a |> function_name.(b, c) |> after_call"
      unpiped = "function_name.(a, b, c) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end

    test "single arg in anonymous function and statement before call" do
      piped = "a |> function_name.() |> after_call"
      unpiped = "function_name.(a) |> after_call"
      assert AST.from_pipe(piped) == unpiped
    end
  end

  describe "from_pipe/1 multi-line" do
    test "three args in named function" do
      piped = """
      a
      |> function_name(b, c)
      |> after_call
      """

      unpiped = "function_name(a, b, c) |> after_call"

      assert AST.from_pipe(piped) == unpiped
    end

    test "single arg in named function" do
      piped = """
      a
      |> function_name()
      |> after_call
      """

      unpiped = "function_name(a) |> after_call"

      assert AST.from_pipe(piped) == unpiped
    end

    test "three args in anonymous function" do
      piped = """
      a
      |> function_name.(b, c)
      |> after_call
      """

      unpiped = "function_name.(a, b, c) |> after_call"

      assert AST.from_pipe(piped) == unpiped
    end

    test "single arg in anonymous function" do
      piped = """
      MyModule.f(a)
      |> function_name.()
      |> after_call
      """

      unpiped = "function_name.(MyModule.f(a)) |> after_call"

      assert AST.from_pipe(piped) == unpiped
    end

    test "function call piped into another function" do
      piped = """
      f(a)
      |> g(b, c)
      |> after_call
      """

      unpiped = "g(f(a), b, c) |> after_call"

      assert AST.from_pipe(piped) == unpiped
    end
  end
end
