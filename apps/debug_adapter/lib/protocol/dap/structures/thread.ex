# codegen: do not edit

defmodule GenDAP.Structures.Thread do
  @moduledoc """
  A Thread
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * id: Unique identifier for the thread.
  * name: The name of the thread.
  """

  typedstruct do
    @typedoc "A type defining DAP structure Thread"
    field(:id, integer(), enforce: true)
    field(:name, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"id", :id} => int(),
      {"name", :name} => str()
    })
  end
end
