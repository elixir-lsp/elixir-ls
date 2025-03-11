# codegen: do not edit
defmodule GenDAP.Structures.GotoResponse do
  @moduledoc """
  Response to `goto` request. This is just an acknowledgement, so no body field is required.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * command: The command requested.
  * message: Contains the raw error in short form if `success` is false.
    This raw error might be interpreted by the client and is not shown in the UI.
    Some predefined values exist.
  * type
  * success: Outcome of the request.
    If true, the request was successful and the `body` attribute may contain the result of the request.
    If the value is false, the attribute `message` contains the error in short form and the `body` may contain additional information (see `ErrorResponse.body.error`).
  * body: Contains request result if success is true and error details if success is false.
  * request_seq: Sequence number of the corresponding request.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :command, String.t(), enforce: true
    field :message, String.t()
    field :type, String.t(), enforce: true
    field :success, boolean(), enforce: true
    field :body, list() | boolean() | integer() | nil | number() | map() | String.t()
    field :request_seq, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"command", :command} => str(),
      optional({"message", :message}) => oneof(["cancelled", "notStopped"]),
      {"type", :type} => oneof(["response"]),
      {"success", :success} => bool(),
      optional({"body", :body}) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
      {"request_seq", :request_seq} => int(),
    })
  end
end
