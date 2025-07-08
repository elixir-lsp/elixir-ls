defmodule ElixirLS.Test.ModuleDepsA do
  @moduledoc """
  Test module A for module dependency analysis.
  Demonstrates various types of dependencies.
  """
  
  # Compile-time dependencies
  alias ElixirLS.Test.ModuleDepsB, as: B
  require Logger
  import Enum, only: [map: 2, filter: 2]
  
  # Module attribute using another module
  @b_constant B.get_constant()
  
  def function_using_alias do
    # Runtime dependency through alias
    B.function_in_b()
  end
  
  def function_using_import(list) do
    # Runtime dependency through import
    list
    |> map(&(&1 * 2))
    |> filter(&(&1 > 10))
  end
  
  def function_using_require do
    # Compile-time dependency through require
    Logger.info("Using required module")
  end
  
  def function_with_direct_call do
    # Runtime dependency without alias
    ElixirLS.Test.ModuleDepsC.function_in_c()
  end
  
  def function_calling_erlang do
    # Runtime dependency on Erlang module
    :erlang.system_info(:otp_release)
  end
  
  defmacro macro_example do
    quote do
      # This creates compile-time dependency for callers
      IO.puts("Macro expanded")
    end
  end
  
  def multiple_dependencies do
    # Multiple runtime dependencies
    B.function_in_b()
    ElixirLS.Test.ModuleDepsC.function_in_c()
    :ets.new(:test, [:set])
  end
  
  # Private function - internal dependency
  defp private_helper(x), do: x * 2
  
  def uses_private(x) do
    private_helper(x)
  end
end