# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceFoldersServerCapabilities do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * supported: The server has support for workspace folders
  * change_notifications: Whether the server wants to receive workspace folder
    change notifications.

    If a string is provided the string is treated as an ID
    under which the notification is registered on the client
    side. The ID can be used to unregister for these events
    using the `client/unregisterCapability` request.
  """

  typedstruct do
    field(:supported, boolean())
    field(:change_notifications, String.t() | boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"supported", :supported}) => bool(),
      optional({"changeNotifications", :change_notifications}) => oneof([str(), bool()])
    })
  end
end
