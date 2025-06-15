# codegen: do not edit
defmodule GenLSP.Structures.CompletionItem do
  @moduledoc """
  A completion item represents a text snippet that is
  proposed to complete text that is being typed.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * label: The label of this completion item.

    The label property is also by default the text that
    is inserted when selecting this completion.

    If label details are provided the label itself should
    be an unqualified name of the completion item.
  * label_details: Additional details for the label

    @since 3.17.0
  * kind: The kind of this completion item. Based of the kind
    an icon is chosen by the editor.
  * tags: Tags for this completion item.

    @since 3.15.0
  * detail: A human-readable string with additional information
    about this item, like type or symbol information.
  * documentation: A human-readable string that represents a doc-comment.
  * deprecated: Indicates if this item is deprecated.
    @deprecated Use `tags` instead.
  * preselect: Select this item when showing.

    *Note* that only one completion item can be selected and that the
    tool / client decides which item that is. The rule is that the *first*
    item of those that match best is selected.
  * sort_text: A string that should be used when comparing this item
    with other items. When `falsy` the {@link CompletionItem.label label}
    is used.
  * filter_text: A string that should be used when filtering a set of
    completion items. When `falsy` the {@link CompletionItem.label label}
    is used.
  * insert_text: A string that should be inserted into a document when selecting
    this completion. When `falsy` the {@link CompletionItem.label label}
    is used.

    The `insertText` is subject to interpretation by the client side.
    Some tools might not take the string literally. For example
    VS Code when code complete is requested in this example
    `con<cursor position>` and a completion item with an `insertText` of
    `console` is provided it will only insert `sole`. Therefore it is
    recommended to use `textEdit` instead since it avoids additional client
    side interpretation.
  * insert_text_format: The format of the insert text. The format applies to both the
    `insertText` property and the `newText` property of a provided
    `textEdit`. If omitted defaults to `InsertTextFormat.PlainText`.

    Please note that the insertTextFormat doesn't apply to
    `additionalTextEdits`.
  * insert_text_mode: How whitespace and indentation is handled during completion
    item insertion. If not provided the clients default value depends on
    the `textDocument.completion.insertTextMode` client capability.

    @since 3.16.0
  * text_edit: An {@link TextEdit edit} which is applied to a document when selecting
    this completion. When an edit is provided the value of
    {@link CompletionItem.insertText insertText} is ignored.

    Most editors support two different operations when accepting a completion
    item. One is to insert a completion text and the other is to replace an
    existing text with a completion text. Since this can usually not be
    predetermined by a server it can report both ranges. Clients need to
    signal support for `InsertReplaceEdits` via the
    `textDocument.completion.insertReplaceSupport` client capability
    property.

    *Note 1:* The text edit's range as well as both ranges from an insert
    replace edit must be a [single line] and they must contain the position
    at which completion has been requested.
    *Note 2:* If an `InsertReplaceEdit` is returned the edit's insert range
    must be a prefix of the edit's replace range, that means it must be
    contained and starting at the same position.

    @since 3.16.0 additional type `InsertReplaceEdit`
  * text_edit_text: The edit text used if the completion item is part of a CompletionList and
    CompletionList defines an item default for the text edit range.

    Clients will only honor this property if they opt into completion list
    item defaults using the capability `completionList.itemDefaults`.

    If not provided and a list's default range is provided the label
    property is used as a text.

    @since 3.17.0
  * additional_text_edits: An optional array of additional {@link TextEdit text edits} that are applied when
    selecting this completion. Edits must not overlap (including the same insert position)
    with the main {@link CompletionItem.textEdit edit} nor with themselves.

    Additional text edits should be used to change text unrelated to the current cursor position
    (for example adding an import statement at the top of the file if the completion item will
    insert an unqualified type).
  * commit_characters: An optional set of characters that when pressed while this completion is active will accept it first and
    then type that character. *Note* that all commit characters should have `length=1` and that superfluous
    characters will be ignored.
  * command: An optional {@link Command command} that is executed *after* inserting this completion. *Note* that
    additional modifications to the current document should be described with the
    {@link CompletionItem.additionalTextEdits additionalTextEdits}-property.
  * data: A data entry field that is preserved on a completion item between a
    {@link CompletionRequest} and a {@link CompletionResolveRequest}.
  """

  typedstruct do
    field(:label, String.t(), enforce: true)
    field(:label_details, GenLSP.Structures.CompletionItemLabelDetails.t())
    field(:kind, GenLSP.Enumerations.CompletionItemKind.t())
    field(:tags, list(GenLSP.Enumerations.CompletionItemTag.t()))
    field(:detail, String.t())
    field(:documentation, String.t() | GenLSP.Structures.MarkupContent.t())
    field(:deprecated, boolean())
    field(:preselect, boolean())
    field(:sort_text, String.t())
    field(:filter_text, String.t())
    field(:insert_text, String.t())
    field(:insert_text_format, GenLSP.Enumerations.InsertTextFormat.t())
    field(:insert_text_mode, GenLSP.Enumerations.InsertTextMode.t())
    field(:text_edit, GenLSP.Structures.TextEdit.t() | GenLSP.Structures.InsertReplaceEdit.t())
    field(:text_edit_text, String.t())
    field(:additional_text_edits, list(GenLSP.Structures.TextEdit.t()))
    field(:commit_characters, list(String.t()))
    field(:command, GenLSP.Structures.Command.t())
    field(:data, GenLSP.TypeAlias.LSPAny.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"label", :label} => str(),
      optional({"labelDetails", :label_details}) =>
        GenLSP.Structures.CompletionItemLabelDetails.schematic(),
      optional({"kind", :kind}) => GenLSP.Enumerations.CompletionItemKind.schematic(),
      optional({"tags", :tags}) => list(GenLSP.Enumerations.CompletionItemTag.schematic()),
      optional({"detail", :detail}) => str(),
      optional({"documentation", :documentation}) =>
        oneof([str(), GenLSP.Structures.MarkupContent.schematic()]),
      optional({"deprecated", :deprecated}) => bool(),
      optional({"preselect", :preselect}) => bool(),
      optional({"sortText", :sort_text}) => str(),
      optional({"filterText", :filter_text}) => str(),
      optional({"insertText", :insert_text}) => str(),
      optional({"insertTextFormat", :insert_text_format}) =>
        GenLSP.Enumerations.InsertTextFormat.schematic(),
      optional({"insertTextMode", :insert_text_mode}) =>
        GenLSP.Enumerations.InsertTextMode.schematic(),
      optional({"textEdit", :text_edit}) =>
        oneof([
          GenLSP.Structures.TextEdit.schematic(),
          GenLSP.Structures.InsertReplaceEdit.schematic()
        ]),
      optional({"textEditText", :text_edit_text}) => str(),
      optional({"additionalTextEdits", :additional_text_edits}) =>
        list(GenLSP.Structures.TextEdit.schematic()),
      optional({"commitCharacters", :commit_characters}) => list(str()),
      optional({"command", :command}) => GenLSP.Structures.Command.schematic(),
      optional({"data", :data}) => GenLSP.TypeAlias.LSPAny.schematic()
    })
  end
end
