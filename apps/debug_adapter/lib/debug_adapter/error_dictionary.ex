defmodule ElixirLS.DebugAdapter.ErrorDictionary do
  @moduledoc """
  Provides mapping from error names to unique integer codes for DAP error messages.
  """

  @codes %{
    "internalServerError" => 1,
    "cancelled" => 2,
    "invalidRequest" => 3,
    "launchError" => 4,
    "attachError" => 5,
    "invalidArgument" => 6,
    "evaluateError" => 7,
    "argumentError" => 8,
    "runtimeError" => 9,
    "notSupported" => 10
  }

  @spec code(String.t()) :: integer()
  def code(name) do
    Map.fetch!(@codes, name)
  end
end
