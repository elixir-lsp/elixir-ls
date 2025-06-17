# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentColorPresentation do
  @moduledoc """
  A request to list all presentation for a color. The request's
  parameter is of type {@link ColorPresentationParams} the
  response is of type {@link ColorInformation ColorInformation[]} or a Thenable
  that resolves to such.

  Message Direction: clientToServer
  """

  import SchematicV, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/colorPresentation")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.ColorPresentationParams.t())
  end

  @type result :: list(GenLSP.Structures.ColorPresentation.t())

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/colorPresentation",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.ColorPresentationParams.schematic()
    })
  end

  @doc false
  @spec result() :: SchematicV.t()
  def result() do
    oneof([
      list(GenLSP.Structures.ColorPresentation.schematic()),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
