# codegen: do not edit
defmodule GenLSP.Structures.BaseSymbolInformation do
  @moduledoc """
  A base for all symbol information.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * name: The name of this symbol.
  * kind: The kind of this symbol.
  * tags: Tags for this symbol.

    @since 3.16.0
  * container_name: The name of the symbol containing this symbol. This information is for
    user interface purposes (e.g. to render a qualifier in the user interface
    if necessary). It can't be used to re-infer a hierarchy for the document
    symbols.
  """
  
  typedstruct do
    field :name, String.t(), enforce: true
    field :kind, GenLSP.Enumerations.SymbolKind.t(), enforce: true
    field :tags, list(GenLSP.Enumerations.SymbolTag.t())
    field :container_name, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"name", :name} => str(),
      {"kind", :kind} => GenLSP.Enumerations.SymbolKind.schematic(),
      optional({"tags", :tags}) => list(GenLSP.Enumerations.SymbolTag.schematic()),
      optional({"containerName", :container_name}) => str()
    })
  end
end
