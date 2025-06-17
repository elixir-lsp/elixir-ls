# codegen: do not edit
defmodule GenLSP.TypeAlias.ChangeAnnotationIdentifier do
  @moduledoc """
  An identifier to refer to a change annotation stored with a workspace edit.
  """

  import SchematicV, warn: false

  @type t :: String.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    str()
  end
end
