# codegen: do not edit
defmodule GenLSP.Structures.InlayHint do
  @moduledoc """
  Inlay hint information.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * position: The position of this hint.
  * label: The label of this hint. A human readable string or an array of
    InlayHintLabelPart label parts.

    *Note* that neither the string nor the label part can be empty.
  * kind: The kind of this hint. Can be omitted in which case the client
    should fall back to a reasonable default.
  * text_edits: Optional text edits that are performed when accepting this inlay hint.

    *Note* that edits are expected to change the document so that the inlay
    hint (or its nearest variant) is now part of the document and the inlay
    hint itself is now obsolete.
  * tooltip: The tooltip text when you hover over this item.
  * padding_left: Render padding before the hint.

    Note: Padding should use the editor's background color, not the
    background color of the hint itself. That means padding can be used
    to visually align/separate an inlay hint.
  * padding_right: Render padding after the hint.

    Note: Padding should use the editor's background color, not the
    background color of the hint itself. That means padding can be used
    to visually align/separate an inlay hint.
  * data: A data entry field that is preserved on an inlay hint between
    a `textDocument/inlayHint` and a `inlayHint/resolve` request.
  """
  
  typedstruct do
    field :position, GenLSP.Structures.Position.t(), enforce: true
    field :label, String.t() | list(GenLSP.Structures.InlayHintLabelPart.t()), enforce: true
    field :kind, GenLSP.Enumerations.InlayHintKind.t()
    field :text_edits, list(GenLSP.Structures.TextEdit.t())
    field :tooltip, String.t() | GenLSP.Structures.MarkupContent.t()
    field :padding_left, boolean()
    field :padding_right, boolean()
    field :data, GenLSP.TypeAlias.LSPAny.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"position", :position} => GenLSP.Structures.Position.schematic(),
      {"label", :label} => oneof([str(), list(GenLSP.Structures.InlayHintLabelPart.schematic())]),
      optional({"kind", :kind}) => GenLSP.Enumerations.InlayHintKind.schematic(),
      optional({"textEdits", :text_edits}) => list(GenLSP.Structures.TextEdit.schematic()),
      optional({"tooltip", :tooltip}) =>
        oneof([str(), GenLSP.Structures.MarkupContent.schematic()]),
      optional({"paddingLeft", :padding_left}) => bool(),
      optional({"paddingRight", :padding_right}) => bool(),
      optional({"data", :data}) => GenLSP.TypeAlias.LSPAny.schematic()
    })
  end
end
