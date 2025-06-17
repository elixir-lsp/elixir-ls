# codegen: do not edit
defmodule GenLSP.Structures.LocationLink do
  @moduledoc """
  Represents the connection of two locations. Provides additional metadata over normal {@link Location locations},
  including an origin range.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * origin_selection_range: Span of the origin of this link.

    Used as the underlined span for mouse interaction. Defaults to the word range at
    the definition position.
  * target_uri: The target resource identifier of this link.
  * target_range: The full target range of this link. If the target for example is a symbol then target range is the
    range enclosing this symbol not including leading/trailing whitespace but everything else
    like comments. This information is typically used to highlight the range in the editor.
  * target_selection_range: The range that should be selected and revealed when this link is being followed, e.g the name of a function.
    Must be contained by the `targetRange`. See also `DocumentSymbol#range`
  """

  typedstruct do
    field(:origin_selection_range, GenLSP.Structures.Range.t())
    field(:target_uri, GenLSP.BaseTypes.document_uri(), enforce: true)
    field(:target_range, GenLSP.Structures.Range.t(), enforce: true)
    field(:target_selection_range, GenLSP.Structures.Range.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"originSelectionRange", :origin_selection_range}) =>
        GenLSP.Structures.Range.schematic(),
      {"targetUri", :target_uri} => str(),
      {"targetRange", :target_range} => GenLSP.Structures.Range.schematic(),
      {"targetSelectionRange", :target_selection_range} => GenLSP.Structures.Range.schematic()
    })
  end
end
