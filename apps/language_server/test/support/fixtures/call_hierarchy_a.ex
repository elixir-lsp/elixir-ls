defmodule ElixirLS.Test.CallHierarchyA do
  def function_a do
    result = :ok
    function_b()
    result
  end

  def function_b do
    ElixirLS.Test.CallHierarchyB.function_in_b()
    function_with_arg(42)
  end

  def function_with_arg(arg) do
    IO.puts("Arg: #{arg}")
    ElixirLS.Test.CallHierarchyC.function_in_c(arg)
  end

  def calls_function_a do
    function_a()
  end

  def another_caller do
    function_a()
    function_b()
  end

  # Function that is called from other modules
  def called_from_other_modules do
    :called
  end

  # Function with multiple clauses
  def multi_clause_fun(0), do: :zero
  def multi_clause_fun(1), do: :one
  def multi_clause_fun(n), do: {:number, n}

  # Private function
  defp private_function do
    :private
  end

  def calls_private do
    private_function()
  end
end
