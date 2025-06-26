defmodule ElixirLS.Test.CallHierarchyB do
  alias ElixirLS.Test.CallHierarchyA

  def function_in_b do
    # Calls function from module A
    CallHierarchyA.called_from_other_modules()
    :from_b
  end

  def another_function_in_b do
    # Multiple calls to same function
    CallHierarchyA.function_a()
    CallHierarchyA.function_a()

    # Call with pattern matching
    case CallHierarchyA.multi_clause_fun(2) do
      :zero -> :was_zero
      {:number, n} -> {:got_number, n}
      _ -> :other
    end
  end

  # Function that calls multiple functions
  def calls_many_functions do
    function_in_b()
    CallHierarchyA.function_with_arg("hello")
    ElixirLS.Test.CallHierarchyC.function_in_c(123)
  end

  # Recursive function
  def recursive_function(0), do: :done

  def recursive_function(n) when n > 0 do
    recursive_function(n - 1)
  end

  # Function with dynamic calls
  def dynamic_caller(module, function, args) do
    apply(module, function, args)
  end
end
