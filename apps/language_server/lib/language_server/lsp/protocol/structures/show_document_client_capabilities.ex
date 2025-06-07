# codegen: do not edit
defmodule GenLSP.Structures.ShowDocumentClientCapabilities do
  @moduledoc """
  Client capabilities for the showDocument request.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * support: The client has support for the showDocument
    request.
  """
  
  typedstruct do
    field :support, boolean(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"support", :support} => bool()
    })
  end
end
