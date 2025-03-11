# codegen: do not edit
defmodule GenDAP.Structures.LoadedSourcesArguments do
  @moduledoc """
  Arguments for `loadedSources` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  """
  @derive JasonV.Encoder
  typedstruct do
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
    })
  end
end
