# codegen: do not edit
defmodule GenLSP.Structures.ColorInformation do
  @moduledoc """
  Represents a color range from a document.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * range: The range in the document where this color appears.
  * color: The actual color value for this color range.
  """

  typedstruct do
    field(:range, GenLSP.Structures.Range.t(), enforce: true)
    field(:color, GenLSP.Structures.Color.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"range", :range} => GenLSP.Structures.Range.schematic(),
      {"color", :color} => GenLSP.Structures.Color.schematic()
    })
  end
end
