# codegen: do not edit
defmodule GenLSP.Structures.DocumentSymbolClientCapabilities do
  @moduledoc """
  Client Capabilities for a {@link DocumentSymbolRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether document symbol supports dynamic registration.
  * symbol_kind: Specific capabilities for the `SymbolKind` in the
    `textDocument/documentSymbol` request.
  * hierarchical_document_symbol_support: The client supports hierarchical document symbols.
  * tag_support: The client supports tags on `SymbolInformation`. Tags are supported on
    `DocumentSymbol` if `hierarchicalDocumentSymbolSupport` is set to true.
    Clients supporting tags have to handle unknown tags gracefully.

    @since 3.16.0
  * label_support: The client supports an additional label presented in the UI when
    registering a document symbol provider.

    @since 3.16.0
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:symbol_kind, map())
    field(:hierarchical_document_symbol_support, boolean())
    field(:tag_support, map())
    field(:label_support, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"symbolKind", :symbol_kind}) =>
        map(%{
          optional({"valueSet", :value_set}) => list(GenLSP.Enumerations.SymbolKind.schematic())
        }),
      optional({"hierarchicalDocumentSymbolSupport", :hierarchical_document_symbol_support}) =>
        bool(),
      optional({"tagSupport", :tag_support}) =>
        map(%{
          {"valueSet", :value_set} => list(GenLSP.Enumerations.SymbolTag.schematic())
        }),
      optional({"labelSupport", :label_support}) => bool()
    })
  end
end
