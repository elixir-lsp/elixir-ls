# codegen: do not edit
defmodule GenLSP.Structures.TextDocumentEdit do
  @moduledoc """
  Describes textual changes on a text document. A TextDocumentEdit describes all changes
  on a document version Si and after they are applied move the document to version Si+1.
  So the creator of a TextDocumentEdit doesn't need to sort the array of edits or do any
  kind of ordering. However the edits must be non overlapping.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * text_document: The text document to change.
  * edits: The edits to be applied.

    @since 3.16.0 - support for AnnotatedTextEdit. This is guarded using a
    client capability.
  """
  
  typedstruct do
    field :text_document, GenLSP.Structures.OptionalVersionedTextDocumentIdentifier.t(),
      enforce: true

    field :edits, list(GenLSP.Structures.TextEdit.t() | GenLSP.Structures.AnnotatedTextEdit.t()),
      enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"textDocument", :text_document} =>
        GenLSP.Structures.OptionalVersionedTextDocumentIdentifier.schematic(),
      {"edits", :edits} =>
        list(
          oneof([
            GenLSP.Structures.TextEdit.schematic(),
            GenLSP.Structures.AnnotatedTextEdit.schematic()
          ])
        )
    })
  end
end
