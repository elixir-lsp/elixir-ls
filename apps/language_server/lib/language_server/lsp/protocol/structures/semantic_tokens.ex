# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokens do
  @moduledoc """
  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * result_id: An optional result id. If provided and clients support delta updating
    the client will include the result id in the next semantic token request.
    A server can then instead of computing all semantic tokens again simply
    send a delta.
  * data: The actual tokens.
  """

  typedstruct do
    field(:result_id, String.t())
    field(:data, list(GenLSP.BaseTypes.uinteger()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"resultId", :result_id}) => str(),
      {"data", :data} => list(int())
    })
  end
end
