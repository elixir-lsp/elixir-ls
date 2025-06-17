# codegen: do not edit
defmodule GenLSP.Enumerations.FoldingRangeKind do
  @moduledoc """
  A set of predefined range kinds.
  """

  @type t :: String.t()

  import SchematicV, warn: false

  @doc """
  Folding range for a comment
  """
  @spec comment() :: String.t()
  def comment, do: "comment"

  @doc """
  Folding range for an import or include
  """
  @spec imports() :: String.t()
  def imports, do: "imports"

  @doc """
  Folding range for a region (e.g. `#region`)
  """
  @spec region() :: String.t()
  def region, do: "region"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "comment",
      "imports",
      "region",
      str()
    ])
  end
end
