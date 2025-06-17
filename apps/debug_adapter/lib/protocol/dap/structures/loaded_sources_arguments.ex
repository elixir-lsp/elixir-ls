# codegen: do not edit

defmodule GenDAP.Structures.LoadedSourcesArguments do
  @moduledoc """
  Arguments for `loadedSources` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  """

  typedstruct do
    @typedoc "A type defining DAP structure LoadedSourcesArguments"
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{})
  end
end
