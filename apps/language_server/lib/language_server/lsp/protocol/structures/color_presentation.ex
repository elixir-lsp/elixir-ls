# codegen: do not edit
defmodule GenLSP.Structures.ColorPresentation do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * label: The label of this color presentation. It will be shown on the color
    picker header. By default this is also the text that is inserted when selecting
    this color presentation.
  * text_edit: An {@link TextEdit edit} which is applied to a document when selecting
    this presentation for the color.  When `falsy` the {@link ColorPresentation.label label}
    is used.
  * additional_text_edits: An optional array of additional {@link TextEdit text edits} that are applied when
    selecting this color presentation. Edits must not overlap with the main {@link ColorPresentation.textEdit edit} nor with themselves.
  """

  typedstruct do
    field(:label, String.t(), enforce: true)
    field(:text_edit, GenLSP.Structures.TextEdit.t())
    field(:additional_text_edits, list(GenLSP.Structures.TextEdit.t()))
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"label", :label} => str(),
      optional({"textEdit", :text_edit}) => GenLSP.Structures.TextEdit.schematic(),
      optional({"additionalTextEdits", :additional_text_edits}) =>
        list(GenLSP.Structures.TextEdit.schematic())
    })
  end
end
