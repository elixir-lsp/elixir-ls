# codegen: do not edit
defmodule GenLSP.Structures.FileOperationClientCapabilities do
  @moduledoc """
  Capabilities relating to events from file operations by the user in the client.

  These events do not come from the file system, they come from user operations
  like renaming a file in the UI.

  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether the client supports dynamic registration for file requests/notifications.
  * did_create: The client has support for sending didCreateFiles notifications.
  * will_create: The client has support for sending willCreateFiles requests.
  * did_rename: The client has support for sending didRenameFiles notifications.
  * will_rename: The client has support for sending willRenameFiles requests.
  * did_delete: The client has support for sending didDeleteFiles notifications.
  * will_delete: The client has support for sending willDeleteFiles requests.
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:did_create, boolean())
    field(:will_create, boolean())
    field(:did_rename, boolean())
    field(:will_rename, boolean())
    field(:did_delete, boolean())
    field(:will_delete, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"didCreate", :did_create}) => bool(),
      optional({"willCreate", :will_create}) => bool(),
      optional({"didRename", :did_rename}) => bool(),
      optional({"willRename", :will_rename}) => bool(),
      optional({"didDelete", :did_delete}) => bool(),
      optional({"willDelete", :will_delete}) => bool()
    })
  end
end
