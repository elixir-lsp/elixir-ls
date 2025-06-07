# codegen: do not edit
defmodule GenLSP.Structures.CodeDescription do
  @moduledoc """
  Structure to capture a description for an error code.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * href: An URI to open with more information about the diagnostic error.
  """
  
  typedstruct do
    field :href, GenLSP.BaseTypes.uri(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"href", :href} => str()
    })
  end
end
