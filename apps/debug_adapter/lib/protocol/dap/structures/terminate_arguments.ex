# codegen: do not edit
defmodule GenDAP.Structures.TerminateArguments do
  @moduledoc """
  Arguments for `terminate` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * restart: A value of true indicates that this `terminate` request is part of a restart sequence.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure TerminateArguments"
    field :restart, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"restart", :restart}) => bool(),
    })
  end
end
