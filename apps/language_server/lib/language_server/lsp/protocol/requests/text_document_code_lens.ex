# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentCodeLens do
  @moduledoc """
  A request to provide code lens for the given text document.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/codeLens")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.CodeLensParams.t())
  end

  @type result :: list(GenLSP.Structures.CodeLens.t()) | nil

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/codeLens",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.CodeLensParams.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      oneof([list(GenLSP.Structures.CodeLens.schematic()), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
