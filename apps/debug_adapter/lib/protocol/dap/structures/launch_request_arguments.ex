# codegen: do not edit


defmodule GenDAP.Structures.LaunchRequestArguments do
  
  @moduledoc """
  Arguments for `launch` request. Additional attributes are implementation specific.
  """
  

  import Schematic, warn: false

  @typedoc "A type defining DAP structure LaunchRequestArguments"
  @type t() :: %{
    optional(:__restart) => list() | boolean() | integer() | nil | number() | map() | String.t(),optional(:no_debug) => boolean(),
    optional(String.t()) => any()
  }

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    map(%{
      optional({"__restart", :__restart}) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
      optional({"noDebug", :no_debug}) => bool(),
      optional(str()) => any()
    })
  end
end

