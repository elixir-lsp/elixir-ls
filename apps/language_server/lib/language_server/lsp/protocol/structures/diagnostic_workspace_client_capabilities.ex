# codegen: do not edit
defmodule GenLSP.Structures.DiagnosticWorkspaceClientCapabilities do
  @moduledoc """
  Workspace client capabilities specific to diagnostic pull requests.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * refresh_support: Whether the client implementation supports a refresh request sent from
    the server to the client.

    Note that this event is global and will force the client to refresh all
    pulled diagnostics currently shown. It should be used with absolute care and
    is useful for situation where a server for example detects a project wide
    change that requires such a calculation.
  """
  
  typedstruct do
    field :refresh_support, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"refreshSupport", :refresh_support}) => bool()
    })
  end
end
