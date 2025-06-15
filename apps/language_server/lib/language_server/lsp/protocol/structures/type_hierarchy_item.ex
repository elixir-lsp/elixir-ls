# codegen: do not edit
defmodule GenLSP.Structures.TypeHierarchyItem do
  @moduledoc """
  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * name: The name of this item.
  * kind: The kind of this item.
  * tags: Tags for this item.
  * detail: More detail for this item, e.g. the signature of a function.
  * uri: The resource identifier of this item.
  * range: The range enclosing this symbol not including leading/trailing whitespace
    but everything else, e.g. comments and code.
  * selection_range: The range that should be selected and revealed when this symbol is being
    picked, e.g. the name of a function. Must be contained by the
    {@link TypeHierarchyItem.range `range`}.
  * data: A data entry field that is preserved between a type hierarchy prepare and
    supertypes or subtypes requests. It could also be used to identify the
    type hierarchy in the server, helping improve the performance on
    resolving supertypes and subtypes.
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
  @spec schematic() :: Schematic.t()
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
