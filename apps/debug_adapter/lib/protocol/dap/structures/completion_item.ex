# codegen: do not edit
defmodule GenDAP.Structures.CompletionItem do
  @moduledoc """
  `CompletionItems` are the suggestions returned from the `completions` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * label: The label of this completion item. By default this is also the text that is inserted when selecting this completion.
  * start: Start position (within the `text` attribute of the `completions` request) where the completion text is added. The position is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based. If the start position is omitted the text is added at the location specified by the `column` attribute of the `completions` request.
  * type: The item's type. Typically the client uses this information to render the item in the UI with an icon.
  * length: Length determines how many characters are overwritten by the completion text and it is measured in UTF-16 code units. If missing the value 0 is assumed which results in the completion text being inserted.
  * text: If text is returned and not an empty string, then it is inserted instead of the label.
  * sort_text: A string that should be used when comparing this item with other items. If not returned or an empty string, the `label` is used instead.
  * detail: A human-readable string with additional information about this item, like type or symbol information.
  * selection_start: Determines the start of the new selection after the text has been inserted (or replaced). `selectionStart` is measured in UTF-16 code units and must be in the range 0 and length of the completion text. If omitted the selection starts at the end of the completion text.
  * selection_length: Determines the length of the new selection after the text has been inserted (or replaced) and it is measured in UTF-16 code units. The selection can not extend beyond the bounds of the completion text. If omitted the length is assumed to be 0.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :label, String.t(), enforce: true
    field :start, integer()
    field :type, GenDAP.Enumerations.CompletionItemType.t()
    field :length, integer()
    field :text, String.t()
    field :sort_text, String.t()
    field :detail, String.t()
    field :selection_start, integer()
    field :selection_length, integer()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"label", :label} => str(),
      optional({"start", :start}) => int(),
      optional({"type", :type}) => GenDAP.Enumerations.CompletionItemType.schematic(),
      optional({"length", :length}) => int(),
      optional({"text", :text}) => str(),
      optional({"sortText", :sort_text}) => str(),
      optional({"detail", :detail}) => str(),
      optional({"selectionStart", :selection_start}) => int(),
      optional({"selectionLength", :selection_length}) => int(),
    })
  end
end
