# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentSemanticTokensFull do
  @moduledoc """
  @since 3.16.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/semanticTokens/full")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.SemanticTokensParams.t())
  end

  @type result :: GenLSP.Structures.SemanticTokens.t() | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/semanticTokens/full",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.SemanticTokensParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([GenLSP.Structures.SemanticTokens.schematic(), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
