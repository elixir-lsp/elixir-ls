# codegen: do not edit
defmodule GenLSP.ErrorResponse do
  @moduledoc """
  A Response Message sent as a result of a request.

  If a request doesn’t provide a result value the receiver of a request still needs to return a response message to conform to the JSON-RPC specification.

  The result property of the ResponseMessage should be set to null in this case to signal a successful request.
  """
  import Schematic

  use TypedStruct

  typedstruct do
    field(:data, String.t() | number() | boolean() | list() | map() | nil)
    field(:code, integer(), enforce: true)
    field(:message, String.t(), enforce: true)
  end

  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional(:data) => oneof([str(), int(), bool(), list(), map(), nil]),
      code: int(),
      message: str()
    })
  end
end
