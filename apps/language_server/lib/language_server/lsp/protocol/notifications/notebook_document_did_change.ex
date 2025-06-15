# codegen: do not edit
defmodule GenLSP.Notifications.NotebookDocumentDidChange do
  import Schematic, warn: false

  use TypedStruct

  typedstruct do
    field(:method, String.t(), default: "notebookDocument/didChange")
    field(:jsonrpc, String.t(), default: "2.0")
    field(:params, GenLSP.Structures.DidChangeNotebookDocumentParams.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      method: "notebookDocument/didChange",
      jsonrpc: "2.0",
      params: GenLSP.Structures.DidChangeNotebookDocumentParams.schematic()
    })
  end
end
