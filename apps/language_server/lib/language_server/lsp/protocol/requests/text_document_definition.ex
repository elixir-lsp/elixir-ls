# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentDefinition do
  @moduledoc """
  A request to resolve the definition location of a symbol at a given text
  document position. The request's parameter is of type [TextDocumentPosition]
  (#TextDocumentPosition) the response is of either type {@link Definition}
  or a typed array of {@link DefinitionLink} or a Thenable that resolves
  to such.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/definition")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.DefinitionParams.t())
  end

  @type result ::
          GenLSP.TypeAlias.Definition.t() | list(GenLSP.TypeAlias.DefinitionLink.t()) | nil

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/definition",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.DefinitionParams.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      oneof([
        GenLSP.TypeAlias.Definition.schematic(),
        list(GenLSP.TypeAlias.DefinitionLink.schematic()),
        nil
      ]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
