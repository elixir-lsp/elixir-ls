# codegen: do not edit
defmodule GenLSP.Structures.TextDocumentSyncOptions do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * open_close: Open and close notifications are sent to the server. If omitted open close notification should not
    be sent.
  * change: Change notifications are sent to the server. See TextDocumentSyncKind.None, TextDocumentSyncKind.Full
    and TextDocumentSyncKind.Incremental. If omitted it defaults to TextDocumentSyncKind.None.
  * will_save: If present will save notifications are sent to the server. If omitted the notification should not be
    sent.
  * will_save_wait_until: If present will save wait until requests are sent to the server. If omitted the request should not be
    sent.
  * save: If present save notifications are sent to the server. If omitted the notification should not be
    sent.
  """
  
  typedstruct do
    field :open_close, boolean()
    field :change, GenLSP.Enumerations.TextDocumentSyncKind.t()
    field :will_save, boolean()
    field :will_save_wait_until, boolean()
    field :save, boolean() | GenLSP.Structures.SaveOptions.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"openClose", :open_close}) => bool(),
      optional({"change", :change}) => GenLSP.Enumerations.TextDocumentSyncKind.schematic(),
      optional({"willSave", :will_save}) => bool(),
      optional({"willSaveWaitUntil", :will_save_wait_until}) => bool(),
      optional({"save", :save}) => oneof([bool(), GenLSP.Structures.SaveOptions.schematic()])
    })
  end
end
