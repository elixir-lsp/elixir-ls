# codegen: do not edit
defmodule GenLSP.Structures.ProgressParams do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * token: The progress token provided by the client or server.
  * value: The progress data.
  """
  
  typedstruct do
    field :token, GenLSP.TypeAlias.ProgressToken.t(), enforce: true
    field :value, GenLSP.TypeAlias.LSPAny.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"token", :token} => GenLSP.TypeAlias.ProgressToken.schematic(),
      {"value", :value} => GenLSP.TypeAlias.LSPAny.schematic()
    })
  end
end
