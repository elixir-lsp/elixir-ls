# codegen: do not edit
defmodule GenLSP.Structures.InitializedParams do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  """

  typedstruct do
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{})
  end
end
