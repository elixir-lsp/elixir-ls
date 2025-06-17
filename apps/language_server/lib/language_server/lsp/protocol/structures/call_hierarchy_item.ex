# codegen: do not edit
defmodule GenLSP.Structures.CallHierarchyItem do
  @moduledoc """
  Represents programming constructs like functions or constructors in the context
  of call hierarchy.

  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * name: The name of this item.
  * kind: The kind of this item.
  * tags: Tags for this item.
  * detail: More detail for this item, e.g. the signature of a function.
  * uri: The resource identifier of this item.
  * range: The range enclosing this symbol not including leading/trailing whitespace but everything else, e.g. comments and code.
  * selection_range: The range that should be selected and revealed when this symbol is being picked, e.g. the name of a function.
    Must be contained by the {@link CallHierarchyItem.range `range`}.
  * data: A data entry field that is preserved between a call hierarchy prepare and
    incoming calls or outgoing calls requests.
  """

  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:kind, GenLSP.Enumerations.SymbolKind.t(), enforce: true)
    field(:tags, list(GenLSP.Enumerations.SymbolTag.t()))
    field(:detail, String.t())
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
    field(:range, GenLSP.Structures.Range.t(), enforce: true)
    field(:selection_range, GenLSP.Structures.Range.t(), enforce: true)
    field(:data, GenLSP.TypeAlias.LSPAny.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"name", :name} => str(),
      {"kind", :kind} => GenLSP.Enumerations.SymbolKind.schematic(),
      optional({"tags", :tags}) => list(GenLSP.Enumerations.SymbolTag.schematic()),
      optional({"detail", :detail}) => str(),
      {"uri", :uri} => str(),
      {"range", :range} => GenLSP.Structures.Range.schematic(),
      {"selectionRange", :selection_range} => GenLSP.Structures.Range.schematic(),
      optional({"data", :data}) => GenLSP.TypeAlias.LSPAny.schematic()
    })
  end
end
