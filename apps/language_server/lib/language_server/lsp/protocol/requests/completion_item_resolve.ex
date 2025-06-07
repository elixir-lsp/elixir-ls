# codegen: do not edit
defmodule GenLSP.Requests.CompletionItemResolve do
  @moduledoc """
  Request to resolve additional information for a given completion item.The request's
  parameter is of type {@link CompletionItem} the response
  is of type {@link CompletionItem} or a Thenable that resolves to such.

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  
  typedstruct do
    field :method, String.t(), default: "completionItem/resolve"
    field :jsonrpc, String.t(), default: "2.0"
    field :id, integer(), enforce: true
    field :params, GenLSP.Structures.CompletionItem.t()
  end

  @type result :: GenLSP.Structures.CompletionItem.t()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "completionItem/resolve",
      jsonrpc: "2.0",
      id: int(),
      params: GenLSP.Structures.CompletionItem.schematic()
    })
  end

  @doc false
  @spec result() :: Schematic.t()
  def result() do
    oneof([
      GenLSP.Structures.CompletionItem.schematic(),
      GenLSP.ErrorResponse.schematic()
    ])
  end
end
