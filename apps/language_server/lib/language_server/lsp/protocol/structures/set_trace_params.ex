# codegen: do not edit
defmodule GenLSP.Structures.SetTraceParams do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * value
  """

  typedstruct do
    field(:value, GenLSP.Enumerations.TraceValues.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"value", :value} => GenLSP.Enumerations.TraceValues.schematic()
    })
  end
end
