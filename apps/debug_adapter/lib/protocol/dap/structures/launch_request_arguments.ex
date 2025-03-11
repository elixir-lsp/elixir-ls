# codegen: do not edit
defmodule GenDAP.Structures.LaunchRequestArguments do
  @moduledoc """
  Arguments for `launch` request. Additional attributes are implementation specific.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * no_debug: If true, the launch request should launch the program without enabling debugging.
  * __restart: Arbitrary data from the previous, restarted session.
    The data is sent as the `restart` attribute of the `terminated` event.
    The client should leave the data intact.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :no_debug, boolean()
    field :__restart, list() | boolean() | integer() | nil | number() | map() | String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"noDebug", :no_debug}) => bool(),
      optional({"__restart", :__restart}) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
    })
  end
end
