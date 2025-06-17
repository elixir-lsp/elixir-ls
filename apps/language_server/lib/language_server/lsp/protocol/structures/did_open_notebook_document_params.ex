# codegen: do not edit
defmodule GenLSP.Structures.DidOpenNotebookDocumentParams do
  @moduledoc """
  The params sent in an open notebook document notification.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * notebook_document: The notebook document that got opened.
  * cell_text_documents: The text documents that represent the content
    of a notebook cell.
  """

  typedstruct do
    field(:notebook_document, GenLSP.Structures.NotebookDocument.t(), enforce: true)
    field(:cell_text_documents, list(GenLSP.Structures.TextDocumentItem.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"notebookDocument", :notebook_document} => GenLSP.Structures.NotebookDocument.schematic(),
      {"cellTextDocuments", :cell_text_documents} =>
        list(GenLSP.Structures.TextDocumentItem.schematic())
    })
  end
end
