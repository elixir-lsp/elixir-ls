# codegen: do not edit
defmodule GenLSP.Structures.SymbolInformation do
  @moduledoc """
  Represents information about programming constructs like variables, classes,
  interfaces etc.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * deprecated: Indicates if this symbol is deprecated.

    @deprecated Use tags instead
  * location: The location of this symbol. The location's range is used by a tool
    to reveal the location in the editor. If the symbol is selected in the
    tool the range's start information is used to position the cursor. So
    the range usually spans more than the actual symbol's name and does
    normally include things like visibility modifiers.

    The range doesn't have to denote a node range in the sense of an abstract
    syntax tree. It can therefore not be used to re-construct a hierarchy of
    the symbols.
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
    field(:deprecated, boolean())
    field(:location, GenLSP.Structures.Location.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:kind, GenLSP.Enumerations.SymbolKind.t(), enforce: true)
    field(:tags, list(GenLSP.Enumerations.SymbolTag.t()))
    field(:container_name, String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"deprecated", :deprecated}) => bool(),
      {"location", :location} => GenLSP.Structures.Location.schematic(),
      {"name", :name} => str(),
      {"kind", :kind} => GenLSP.Enumerations.SymbolKind.schematic(),
      optional({"tags", :tags}) => list(GenLSP.Enumerations.SymbolTag.schematic()),
      optional({"containerName", :container_name}) => str()
    })
  end
end
