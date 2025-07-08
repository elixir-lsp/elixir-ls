defmodule ElixirLS.Test.ModuleDepsC do
  @moduledoc """
  Test module C for module dependency analysis.
  Provides a struct and is called by both A and B.
  """
  
  defstruct [:field, :another_field]
  
  # No explicit dependencies in module header
  # But will have runtime dependency when called
  
  def function_in_c do
    {:ok, "result from C"}
  end
  
  def calls_b do
    # Creates circular dependency with B
    ElixirLS.Test.ModuleDepsB.get_constant()
  end
  
  def standalone_function do
    # No dependencies
    :standalone
  end
  
  def calls_erlang_modules do
    # Multiple Erlang module dependencies
    :crypto.strong_rand_bytes(16)
    :base64.encode("test")
    :timer.sleep(10)
  end
  
  def creates_struct do
    # Self-referential struct creation
    %__MODULE__{field: "test", another_field: 123}
  end
  
  # Guard using Erlang module
  def with_guard(x) when is_binary(x) and byte_size(x) > 0 do
    :ok
  end
  
  def with_guard(_), do: :error
end