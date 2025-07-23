defmodule ElixirLS.Test.CallHierarchyC do
  def function_in_c(param) do
    # Calls functions from both A and B
    ElixirLS.Test.CallHierarchyA.called_from_other_modules()
    ElixirLS.Test.CallHierarchyB.function_in_b()

    # Process the parameter
    process_param(param)
  end

  defp process_param(param) when is_number(param) do
    param * 2
  end

  defp process_param(param) do
    to_string(param)
  end

  # Function that creates a call chain
  def start_chain do
    ElixirLS.Test.CallHierarchyA.function_a()
  end

  # Function with macro calls
  def uses_macros do
    require Logger
    Logger.info("Using macros")

    # Using Kernel macros
    if true do
      :ok
    else
      :error
    end
  end

  # Function calling Erlang modules
  def calls_erlang do
    :ets.new(:my_table, [:set, :public])
    :gen_server.call(self(), :request)
  end

  # Anonymous function usage
  def uses_anonymous_functions do
    fun = fn x -> x * 2 end
    Enum.map([1, 2, 3], fun)

    # Capture syntax
    Enum.map([1, 2, 3], &process_param/1)
  end
end
