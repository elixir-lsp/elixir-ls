# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentOnTypeFormatting do
  @moduledoc """
  A request to format a document on type.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/onTypeFormatting")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.DocumentOnTypeFormattingParams.t())
  end

  @type result :: list(GenLSP.Structures.TextEdit.t()) | nil

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/onTypeFormatting",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.DocumentOnTypeFormattingParams.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      oneof([list(GenLSP.Structures.TextEdit.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
