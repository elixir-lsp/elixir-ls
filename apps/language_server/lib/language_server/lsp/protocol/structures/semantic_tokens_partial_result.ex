# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokensPartialResult do
  @moduledoc """
  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * data
  """

  typedstruct do
    field(:data, list(GenLSP.BaseTypes.uinteger()), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"data", :data} => list(int())
    })
  end
end
