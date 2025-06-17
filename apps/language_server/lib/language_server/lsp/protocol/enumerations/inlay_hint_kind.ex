# codegen: do not edit
defmodule GenLSP.Enumerations.InlayHintKind do
  @moduledoc """
  Inlay hint kinds.

  @since 3.17.0
  """

  @type t :: 1 | 2

  import SchematicV, warn: false

  @doc """
  An inlay hint that for a type annotation.
  """
  @spec type() :: 1
  def type, do: 1

  @doc """
  An inlay hint that is for a parameter.
  """
  @spec parameter() :: 2
  def parameter, do: 2

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      1,
      2
    ])
  end
end
