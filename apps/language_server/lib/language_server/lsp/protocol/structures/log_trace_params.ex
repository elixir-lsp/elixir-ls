# codegen: do not edit
defmodule GenLSP.Structures.LogTraceParams do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * message
  * verbose
  """

  typedstruct do
    field(:message, String.t(), enforce: true)
    field(:verbose, String.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"message", :message} => str(),
      optional({"verbose", :verbose}) => str()
    })
  end
end
