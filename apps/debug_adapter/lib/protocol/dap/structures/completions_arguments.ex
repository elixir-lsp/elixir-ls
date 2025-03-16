# codegen: do not edit


defmodule GenDAP.Structures.CompletionsArguments do
  @moduledoc """
  Arguments for `completions` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * column: The position within `text` for which to determine the completion proposals. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * frame_id: Returns completions in the scope of this stack frame. If not specified, the completions are returned for the global scope.
  * line: A line for which to determine the completion proposals. If missing the first line of the text is assumed.
  * text: One or more source lines. Typically this is the text users have typed into the debug console before they asked for completion.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure CompletionsArguments"
    field :column, integer(), enforce: true
    field :frame_id, integer()
    field :line, integer()
    field :text, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"column", :column} => int(),
      optional({"frameId", :frame_id}) => int(),
      optional({"line", :line}) => int(),
      {"text", :text} => str(),
    })
  end
end

