# codegen: do not edit

defmodule GenDAP.Structures.LocationsArguments do
  @moduledoc """
  Arguments for `locations` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * location_reference: Location reference to resolve.
  """

  typedstruct do
    @typedoc "A type defining DAP structure LocationsArguments"
    field(:location_reference, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"locationReference", :location_reference} => int()
    })
  end
end
