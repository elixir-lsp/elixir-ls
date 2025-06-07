# codegen: do not edit
defmodule GenLSP.Structures.TextDocumentSyncClientCapabilities do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether text document synchronization supports dynamic registration.
  * will_save: The client supports sending will save notifications.
  * will_save_wait_until: The client supports sending a will save request and
    waits for a response providing text edits which will
    be applied to the document before it is saved.
  * did_save: The client supports did save notifications.
  """
  
  typedstruct do
    field :dynamic_registration, boolean()
    field :will_save, boolean()
    field :will_save_wait_until, boolean()
    field :did_save, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"willSave", :will_save}) => bool(),
      optional({"willSaveWaitUntil", :will_save_wait_until}) => bool(),
      optional({"didSave", :did_save}) => bool()
    })
  end
end
