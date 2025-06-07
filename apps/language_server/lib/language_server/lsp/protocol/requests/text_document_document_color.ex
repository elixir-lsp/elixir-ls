# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentDocumentColor do
  @moduledoc """
  A request to list all color symbols found in a given text document. The request's
  parameter is of type {@link DocumentColorParams} the
  response is of type {@link ColorInformation ColorInformation[]} or a Thenable
  that resolves to such.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "textDocument/documentColor"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.DocumentColorParams.t()
  end

  @type result :: list(GenLSP.Structures.ColorInformation.t())

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/documentColor",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.DocumentColorParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      list(GenLSP.Structures.ColorInformation.schematic()),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
