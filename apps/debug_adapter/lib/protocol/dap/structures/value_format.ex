# codegen: do not edit

defmodule GenDAP.Structures.ValueFormat do
  @moduledoc """
  Provides formatting information for a value.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * hex: Display the value in hex.
  """

  typedstruct do
    @typedoc "A type defining DAP structure ValueFormat"
    field(:hex, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"hex", :hex}) => bool()
    })
  end
end
