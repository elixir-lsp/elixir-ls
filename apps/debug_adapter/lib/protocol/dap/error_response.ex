# codegen: do not edit
defmodule GenDAP.ErrorResponse do
  @moduledoc """
  A Response Message sent as a result of a request.

  If a request doesn't provide a result value the receiver of a request still needs to return a response message to conform to the protocol specification.
  """
  import Schematic

  use TypedStruct

  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "response"
    field :request_seq, integer(), enforce: true
    field :success, boolean(), default: false
    field :command, String.t(), enforce: true
    field :message, String.t(), enforce: true
    # TODO: Add body field
    field :body, map()
  end

  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional(:body) => map(),
      seq: int(),
      type: str(),
      request_seq: int(),
      success: bool(),
      command: str(),
      message: str()
    })
  end
end
