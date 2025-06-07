# codegen: do not edit
defmodule GenLSP.Structures.DidChangeTextDocumentParams do
  @moduledoc """
  The change text document notification's parameters.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * text_document: The document that did change. The version number points
    to the version after all provided content changes have
    been applied.
  * content_changes: The actual content changes. The content changes describe single state changes
    to the document. So if there are two content changes c1 (at array index 0) and
    c2 (at array index 1) for a document in state S then c1 moves the document from
    S to S' and c2 from S' to S''. So c1 is computed on the state S and c2 is computed
    on the state S'.

    To mirror the content of a document using change events use the following approach:
    - start with the same initial content
    - apply the 'textDocument/didChange' notifications in the order you receive them.
    - apply the `TextDocumentContentChangeEvent`s in a single notification in the order
      you receive them.
  """
  
  typedstruct do
    field :text_document, GenLSP.Structures.VersionedTextDocumentIdentifier.t(), enforce: true

    field :content_changes, list(GenLSP.TypeAlias.TextDocumentContentChangeEvent.t()),
      enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"textDocument", :text_document} =>
        GenLSP.Structures.VersionedTextDocumentIdentifier.schematic(),
      {"contentChanges", :content_changes} =>
        list(GenLSP.TypeAlias.TextDocumentContentChangeEvent.schematic())
    })
  end
end
