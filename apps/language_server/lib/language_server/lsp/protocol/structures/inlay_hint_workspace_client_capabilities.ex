# codegen: do not edit
defmodule GenLSP.Structures.InlayHintWorkspaceClientCapabilities do
  @moduledoc """
  Client workspace capabilities specific to inlay hints.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * refresh_support: Whether the client implementation supports a refresh request sent from
    the server to the client.

    Note that this event is global and will force the client to refresh all
    inlay hints currently shown. It should be used with absolute care and
    is useful for situation where a server for example detects a project wide
    change that requires such a calculation.
  """

  typedstruct do
    field(:refresh_support, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"refreshSupport", :refresh_support}) => bool()
    })
  end
end
