# codegen: do not edit

defmodule GenDAP.Structures.AttachRequestArguments do
  @moduledoc """
  Arguments for `attach` request. Additional attributes are implementation specific.
  """

  import SchematicV, warn: false

  @typedoc "A type defining DAP structure AttachRequestArguments"
  @type t() :: %{
          optional(:__restart) =>
            list() | boolean() | integer() | nil | number() | map() | String.t(),
          optional(String.t()) => any()
        }

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    all([
      map(%{
        optional({"__restart", :__restart}) =>
          oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()])
      }),
      map()
    ])
  end
end
