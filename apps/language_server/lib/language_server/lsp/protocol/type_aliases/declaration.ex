# codegen: do not edit
defmodule GenLSP.TypeAlias.Declaration do
  @moduledoc """
  The declaration of a symbol representation as one or many {@link Location locations}.
  """

  import Schematic, warn: false

  @type t :: GenLSP.Structures.Location.t() | list(GenLSP.Structures.Location.t())

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([GenLSP.Structures.Location.schematic(), list(GenLSP.Structures.Location.schematic())])
  end
end
