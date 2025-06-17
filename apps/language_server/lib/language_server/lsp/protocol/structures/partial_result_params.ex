# codegen: do not edit
defmodule GenLSP.Structures.PartialResultParams do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * partial_result_token: An optional token that a server can use to report partial results (e.g. streaming) to
    the client.
  """

  typedstruct do
    field(:partial_result_token, GenLSP.TypeAlias.ProgressToken.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"partialResultToken", :partial_result_token}) =>
        GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
