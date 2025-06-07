# codegen: do not edit
defmodule GenLSP.Structures.DocumentRangeFormattingClientCapabilities do
  @moduledoc """
  Client capabilities of a {@link DocumentRangeFormattingRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether range formatting supports dynamic registration.
  """
  
  typedstruct do
    field :dynamic_registration, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool()
    })
  end
end
