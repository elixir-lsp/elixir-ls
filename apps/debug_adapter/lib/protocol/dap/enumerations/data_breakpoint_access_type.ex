# codegen: do not edit
defmodule GenDAP.Enumerations.DataBreakpointAccessType do
  @moduledoc """
  This enumeration defines all possible access types for data breakpoints.
  """

  @typedoc "A type defining DAP enumeration DataBreakpointAccessType"
  @type t :: String.t()

  import SchematicV, warn: false

  @spec read() :: String.t()
  def read, do: "read"

  @spec write() :: String.t()
  def write, do: "write"

  @spec read_write() :: String.t()
  def read_write, do: "readWrite"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "read",
      "write",
      "readWrite"
    ])
  end
end
