# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceSymbol do
  @moduledoc """
  A special workspace symbol that supports locations without a range.

  See also SymbolInformation.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * location: The location of the symbol. Whether a server is allowed to
    return a location without a range depends on the client
    capability `workspace.symbol.resolveSupport`.

    See SymbolInformation#location for more details.
  * data: A data entry field that is preserved on a workspace symbol between a
    workspace symbol request and a workspace symbol resolve request.
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
    field(:location, GenLSP.Structures.Location.t() | map(), enforce: true)
    field(:data, GenLSP.TypeAlias.LSPAny.t())
    field(:name, String.t(), enforce: true)
    field(:kind, GenLSP.Enumerations.SymbolKind.t(), enforce: true)
    field(:tags, list(GenLSP.Enumerations.SymbolTag.t()))
    field(:container_name, String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"location", :location} =>
        oneof([
          GenLSP.Structures.Location.schematic(),
          map(%{
            {"uri", :uri} => str()
          })
        ]),
      optional({"data", :data}) => GenLSP.TypeAlias.LSPAny.schematic(),
      {"name", :name} => str(),
      {"kind", :kind} => GenLSP.Enumerations.SymbolKind.schematic(),
      optional({"tags", :tags}) => list(GenLSP.Enumerations.SymbolTag.schematic()),
      optional({"containerName", :container_name}) => str()
    })
  end
end
