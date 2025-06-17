# codegen: do not edit
defmodule GenLSP.Enumerations.TraceValues do
  @type t :: String.t()

  import SchematicV, warn: false

  @doc """
  Turn tracing off.
  """
  @spec off() :: String.t()
  def off, do: "off"

  @doc """
  Trace messages only.
  """
  @spec messages() :: String.t()
  def messages, do: "messages"

  @doc """
  Verbose message tracing.
  """
  @spec verbose() :: String.t()
  def verbose, do: "verbose"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "off",
      "messages",
      "verbose"
    ])
  end
end
