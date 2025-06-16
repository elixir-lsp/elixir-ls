# codegen: do not edit
defmodule GenLSP.Structures.FoldingRange do
  @moduledoc """
  Represents a folding range. To be valid, start and end line must be bigger than zero and smaller
  than the number of lines in the document. Clients are free to ignore invalid ranges.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * start_line: The zero-based start line of the range to fold. The folded area starts after the line's last character.
    To be valid, the end must be zero or larger and smaller than the number of lines in the document.
  * start_character: The zero-based character offset from where the folded range starts. If not defined, defaults to the length of the start line.
  * end_line: The zero-based end line of the range to fold. The folded area ends with the line's last character.
    To be valid, the end must be zero or larger and smaller than the number of lines in the document.
  * end_character: The zero-based character offset before the folded range ends. If not defined, defaults to the length of the end line.
  * kind: Describes the kind of the folding range such as 'comment' or 'region'. The kind
    is used to categorize folding ranges and used by commands like 'Fold all comments'.
    See {@link FoldingRangeKind} for an enumeration of standardized kinds.
  * collapsed_text: The text that the client should show when the specified range is
    collapsed. If not defined or not supported by the client, a default
    will be chosen by the client.

    @since 3.17.0
  """

  typedstruct do
    field(:start_line, GenLSP.BaseTypes.uinteger(), enforce: true)
    field(:start_character, GenLSP.BaseTypes.uinteger())
    field(:end_line, GenLSP.BaseTypes.uinteger(), enforce: true)
    field(:end_character, GenLSP.BaseTypes.uinteger())
    field(:kind, GenLSP.Enumerations.FoldingRangeKind.t())
    field(:collapsed_text, String.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"startLine", :start_line} => int(),
      optional({"startCharacter", :start_character}) => int(),
      {"endLine", :end_line} => int(),
      optional({"endCharacter", :end_character}) => int(),
      optional({"kind", :kind}) => GenLSP.Enumerations.FoldingRangeKind.schematic(),
      optional({"collapsedText", :collapsed_text}) => str()
    })
  end
end
