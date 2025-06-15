# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceSymbolRegistrationOptions do
  @moduledoc """
  Registration options for a {@link WorkspaceSymbolRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * resolve_provider: The server provides support to resolve additional
    information for a workspace symbol.

    @since 3.17.0
  """

  typedstruct do
    field(:resolve_provider, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"resolveProvider", :resolve_provider}) => bool()
    })
  end
end
