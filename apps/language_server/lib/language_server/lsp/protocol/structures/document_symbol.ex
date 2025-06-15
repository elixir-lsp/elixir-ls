# codegen: do not edit
defmodule GenLSP.Structures.DocumentSymbol do
  @moduledoc """
  Represents programming constructs like variables, classes, interfaces etc.
  that appear in a document. Document symbols can be hierarchical and they
  have two ranges: one that encloses its definition and one that points to
  its most interesting range, e.g. the range of an identifier.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * name: The name of this symbol. Will be displayed in the user interface and therefore must not be
    an empty string or a string only consisting of white spaces.
  * detail: More detail for this symbol, e.g the signature of a function.
  * kind: The kind of this symbol.
  * tags: Tags for this document symbol.

    @since 3.16.0
  * deprecated: Indicates if this symbol is deprecated.

    @deprecated Use tags instead
  * range: The range enclosing this symbol not including leading/trailing whitespace but everything else
    like comments. This information is typically used to determine if the clients cursor is
    inside the symbol to reveal in the symbol in the UI.
  * selection_range: The range that should be selected and revealed when this symbol is being picked, e.g the name of a function.
    Must be contained by the `range`.
  * children: Children of this symbol, e.g. properties of a class.
  """

  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:detail, String.t())
    field(:kind, GenLSP.Enumerations.SymbolKind.t(), enforce: true)
    field(:tags, list(GenLSP.Enumerations.SymbolTag.t()))
    field(:deprecated, boolean())
    field(:range, GenLSP.Structures.Range.t(), enforce: true)
    field(:selection_range, GenLSP.Structures.Range.t(), enforce: true)
    field(:children, list(GenLSP.Structures.DocumentSymbol.t()))
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"name", :name} => str(),
      optional({"detail", :detail}) => str(),
      {"kind", :kind} => GenLSP.Enumerations.SymbolKind.schematic(),
      optional({"tags", :tags}) => list(GenLSP.Enumerations.SymbolTag.schematic()),
      optional({"deprecated", :deprecated}) => bool(),
      {"range", :range} => GenLSP.Structures.Range.schematic(),
      {"selectionRange", :selection_range} => GenLSP.Structures.Range.schematic(),
      optional({"children", :children}) => list({__MODULE__, :schematic, []})
    })
  end
end
