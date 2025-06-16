# codegen: do not edit
defmodule GenLSP.TypeAlias.LSPObject do
  @moduledoc """
  LSP object definition.
  @since 3.17.0
  """

  import SchematicV, warn: false

  @type t :: %{String.t() => any()}

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    map(keys: str(), values: any())
  end
end
