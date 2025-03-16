# codegen: do not edit


defmodule GenDAP.Structures.ErrorResponse do
  @moduledoc """
  On error (whenever `success` is false), the body can provide more details.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * body: Contains request result if success is true and error details if success is false.
  * command: The command requested.
  * message: Contains the raw error in short form if `success` is false.
    This raw error might be interpreted by the client and is not shown in the UI.
    Some predefined values exist.
  * request_seq: Sequence number of the corresponding request.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * success: Outcome of the request.
    If true, the request was successful and the `body` attribute may contain the result of the request.
    If the value is false, the attribute `message` contains the error in short form and the `body` may contain additional information (see `ErrorResponse.body.error`).
  * type: Message type.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ErrorResponse"
    field :body, %{optional(:error) => GenDAP.Structures.Message.t()}, enforce: true
    field :command, String.t(), enforce: true
    field :message, String.t()
    field :request_seq, integer(), enforce: true
    field :seq, integer(), enforce: true
    field :success, boolean(), enforce: true
    field :type, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"body", :body} => map(%{
        optional({"error", :error}) => GenDAP.Structures.Message.schematic()
      }),
      {"command", :command} => str(),
      optional({"message", :message}) => oneof(["cancelled", "notStopped", str()]),
      {"request_seq", :request_seq} => int(),
      {"seq", :seq} => int(),
      {"success", :success} => bool(),
      {"type", :type} => oneof(["request", "response", "event", str()]),
    })
  end
end

