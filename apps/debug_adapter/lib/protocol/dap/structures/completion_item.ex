# codegen: do not edit
defmodule GenDAP.Structures.CompletionItem do
  @moduledoc """
  `CompletionItems` are the suggestions returned from the `completions` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * detail: A human-readable string with additional information about this item, like type or symbol information.
  * label: The label of this completion item. By default this is also the text that is inserted when selecting this completion.
  * length: Length determines how many characters are overwritten by the completion text and it is measured in UTF-16 code units. If missing the value 0 is assumed which results in the completion text being inserted.
  * selection_length: Determines the length of the new selection after the text has been inserted (or replaced) and it is measured in UTF-16 code units. The selection can not extend beyond the bounds of the completion text. If omitted the length is assumed to be 0.
  * selection_start: Determines the start of the new selection after the text has been inserted (or replaced). `selectionStart` is measured in UTF-16 code units and must be in the range 0 and length of the completion text. If omitted the selection starts at the end of the completion text.
  * sort_text: A string that should be used when comparing this item with other items. If not returned or an empty string, the `label` is used instead.
  * start: Start position (within the `text` attribute of the `completions` request) where the completion text is added. The position is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based. If the start position is omitted the text is added at the location specified by the `column` attribute of the `completions` request.
  * text: If text is returned and not an empty string, then it is inserted instead of the label.
  * type: The item's type. Typically the client uses this information to render the item in the UI with an icon.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure CompletionItem"
    field :detail, String.t()
    field :label, String.t(), enforce: true
    field :length, integer()
    field :selection_length, integer()
    field :selection_start, integer()
    field :sort_text, String.t()
    field :start, integer()
    field :text, String.t()
    field :type, GenDAP.Enumerations.CompletionItemType.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"detail", :detail}) => str(),
      {"label", :label} => str(),
      optional({"length", :length}) => int(),
      optional({"selectionLength", :selection_length}) => int(),
      optional({"selectionStart", :selection_start}) => int(),
      optional({"sortText", :sort_text}) => str(),
      optional({"start", :start}) => int(),
      optional({"text", :text}) => str(),
      optional({"type", :type}) => GenDAP.Enumerations.CompletionItemType.schematic(),
    })
  end
end
