# codegen: do not edit
defmodule GenLSP.Structures.WorkDoneProgressCreateParams do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * token: The token to be used to report progress.
  """

  typedstruct do
    field(:token, GenLSP.TypeAlias.ProgressToken.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"token", :token} => GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
