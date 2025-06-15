# codegen: do not edit
defmodule GenLSP.Notifications.NotebookDocumentDidOpen do
  @moduledoc """
  A notification sent when a notebook opens.

  @since 3.17.0

  Message Direction: clientToServer
  """

  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "notebookDocument/didOpen")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.DidOpenNotebookDocumentParams.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "notebookDocument/didOpen",
      jsonrpc: "2.0",
      params: GenLSP.Structures.DidOpenNotebookDocumentParams.schematic()
    })
  end
end
