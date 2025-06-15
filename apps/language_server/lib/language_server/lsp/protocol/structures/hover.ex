# codegen: do not edit
defmodule GenLSP.Structures.Hover do
  @moduledoc """
  The result of a hover request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * contents: The hover's content
  * range: An optional range inside the text document that is used to
    visualize the hover, e.g. by changing the background color.
  """

  typedstruct do
    field(
      :contents,
      GenLSP.Structures.MarkupContent.t()
      | GenLSP.TypeAlias.MarkedString.t()
      | list(GenLSP.TypeAlias.MarkedString.t()),
      enforce: true
    )

    field(:range, GenLSP.Structures.Range.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"contents", :contents} =>
        oneof([
          GenLSP.Structures.MarkupContent.schematic(),
          GenLSP.TypeAlias.MarkedString.schematic(),
          list(GenLSP.TypeAlias.MarkedString.schematic())
        ]),
      optional({"range", :range}) => GenLSP.Structures.Range.schematic()
    })
  end
end
