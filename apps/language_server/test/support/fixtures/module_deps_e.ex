defmodule ElixirLS.Test.ModuleDepsE do
  @moduledoc """
  Test module E for module dependency analysis.
  End of the dependency chain.
  """

  def function_in_e(arg) do
    {:ok, arg}
  end
end
