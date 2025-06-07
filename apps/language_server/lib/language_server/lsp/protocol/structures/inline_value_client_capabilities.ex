# codegen: do not edit
defmodule GenLSP.Structures.InlineValueClientCapabilities do
  @moduledoc """
  Client capabilities specific to inline values.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether implementation supports dynamic registration for inline value providers.
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
