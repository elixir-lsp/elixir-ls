defmodule Suggest do
  def no_arg, do: :ok

  def one_arg(arg = %{foo: 1}), do: {:ok, arg}

  def multiple_arities(arg1) do
    {:ok, arg1 * 1}
  end

  def multiple_arities(arg1, arg2) do
    {:ok, arg1 * 1, arg2 * 1}
  end

  def default_arg_functions(arg1 \\ 1, arg2 \\ 2) do
    {:ok, arg1 * 1, arg2 * 1}
  end

  defguard foo(arg) when is_integer(arg) and arg > 0

  defmacro macro(ast) do
    ast
  end

  def multiple_clauses(arg1) when is_integer(arg1) do
    {:ok, arg1 * 1}
  end

  def multiple_clauses(arg1) when is_float(arg1) do
    {:ok, arg1 * 1.0}
  end
end
