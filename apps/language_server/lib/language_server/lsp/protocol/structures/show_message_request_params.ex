# codegen: do not edit
defmodule GenLSP.Structures.ShowMessageRequestParams do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * type: The message type. See {@link MessageType}
  * message: The actual message.
  * actions: The message action items to present.
  """

  typedstruct do
    field(:type, GenLSP.Enumerations.MessageType.t(), enforce: true)
    field(:message, String.t(), enforce: true)
    field(:actions, list(GenLSP.Structures.MessageActionItem.t()))
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"type", :type} => GenLSP.Enumerations.MessageType.schematic(),
      {"message", :message} => str(),
      optional({"actions", :actions}) => list(GenLSP.Structures.MessageActionItem.schematic())
    })
  end
end
