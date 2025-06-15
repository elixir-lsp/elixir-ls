# codegen: do not edit
defmodule GenLSP.Structures.LogMessageParams do
  @moduledoc """
  The log message parameters.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * type: The message type. See {@link MessageType}
  * message: The actual message.
  """

  typedstruct do
    field(:type, GenLSP.Enumerations.MessageType.t(), enforce: true)
    field(:message, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"type", :type} => GenLSP.Enumerations.MessageType.schematic(),
      {"message", :message} => str()
    })
  end
end
