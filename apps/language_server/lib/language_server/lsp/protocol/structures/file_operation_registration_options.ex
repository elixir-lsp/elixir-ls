# codegen: do not edit
defmodule GenLSP.Structures.FileOperationRegistrationOptions do
  @moduledoc """
  The options to register for file operations.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * filters: The actual filters.
  """
  
  typedstruct do
    field :filters, list(GenLSP.Structures.FileOperationFilter.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"filters", :filters} => list(GenLSP.Structures.FileOperationFilter.schematic())
    })
  end
end
