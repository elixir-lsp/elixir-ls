# codegen: do not edit

defmodule GenDAP.Structures.ConfigurationDoneArguments do
  @moduledoc """
  Arguments for `configurationDone` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  """

  typedstruct do
    @typedoc "A type defining DAP structure ConfigurationDoneArguments"
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{})
  end
end
