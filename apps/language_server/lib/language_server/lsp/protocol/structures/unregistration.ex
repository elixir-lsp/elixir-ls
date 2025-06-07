# codegen: do not edit
defmodule GenLSP.Structures.Unregistration do
  @moduledoc """
  General parameters to unregister a request or notification.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * id: The id used to unregister the request or notification. Usually an id
    provided during the register request.
  * method: The method to unregister for.
  """
  
  typedstruct do
    field :id, String.t(), enforce: true
    field :method, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"id", :id} => str(),
      {"method", :method} => str()
    })
  end
end
