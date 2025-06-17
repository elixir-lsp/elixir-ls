# codegen: do not edit
defmodule GenLSP.TypeAlias.GlobPattern do
  @moduledoc """
  The glob pattern. Either a string pattern or a relative pattern.

  @since 3.17.0
  """

  import SchematicV, warn: false

  @type t :: GenLSP.TypeAlias.Pattern.t() | GenLSP.Structures.RelativePattern.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([GenLSP.TypeAlias.Pattern.schematic(), GenLSP.Structures.RelativePattern.schematic()])
  end
end
