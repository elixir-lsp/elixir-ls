# codegen: do not edit
defmodule GenLSP.Requests.TextDocumentHover do
  @moduledoc """
  Request to request hover information at a given text document position. The request's
  parameter is of type {@link TextDocumentPosition} the response is of
  type {@link Hover} or a Thenable that resolves to such.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "textDocument/hover")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:id, integer(), enforce: true)
    field(:params, GenLSP.Structures.HoverParams.t())
  end

  @type result :: GenLSP.Structures.Hover.t() | nil

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "textDocument/hover",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.HoverParams.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      oneof([GenLSP.Structures.Hover.schematic(), nil]),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
