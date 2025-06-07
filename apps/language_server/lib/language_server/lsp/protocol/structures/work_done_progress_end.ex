# codegen: do not edit
defmodule GenLSP.Structures.WorkDoneProgressEnd do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * kind
  * message: Optional, a final message indicating to for example indicate the outcome
    of the operation.
  """
  
  typedstruct do
    field :kind, String.t(), enforce: true
    field :message, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"kind", :kind} => "end",
      optional({"message", :message}) => str()
    })
  end
end
