# codegen: do not edit
defmodule GenLSP.Structures.AnnotatedTextEdit do
  @moduledoc """
  A special text edit with an additional change annotation.

  @since 3.16.0.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * annotation_id: The actual identifier of the change annotation
  * range: The range of the text document to be manipulated. To insert
    text into a document create a range where start === end.
  * new_text: The string to be inserted. For delete operations use an
    empty string.
  """

  typedstruct do
    field(:annotation_id, GenLSP.TypeAlias.ChangeAnnotationIdentifier.t(), enforce: true)
    field(:range, GenLSP.Structures.Range.t(), enforce: true)
    field(:new_text, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"annotationId", :annotation_id} => GenLSP.TypeAlias.ChangeAnnotationIdentifier.schematic(),
      {"range", :range} => GenLSP.Structures.Range.schematic(),
      {"newText", :new_text} => str()
    })
  end
end
