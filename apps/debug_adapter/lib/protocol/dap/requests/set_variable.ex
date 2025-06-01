# codegen: do not edit
defmodule GenDAP.Requests.SetVariableRequest do
  @moduledoc """
  Set the variable with the given name in the variable container to a new value. Clients should only call this request if the corresponding capability `supportsSetVariable` is true.
  If a debug adapter implements both `setVariable` and `setExpression`, a client will only use `setExpression` if the variable has an `evaluateName` property.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * arguments: Object containing arguments for the command.
  * command: The command to execute.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """

  typedstruct do
    @typedoc "A type defining DAP request setVariable"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "setVariable")
    field(:arguments, GenDAP.Structures.SetVariableArguments.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setVariable",
      :arguments => GenDAP.Structures.SetVariableArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.SetVariableResponse do
  @moduledoc """
  Response to `setVariable` request.

  Message Direction: adapter -> client
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

  typedstruct do
    @typedoc "A type defining DAP request setVariable response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "setVariable")

    field(
      :body,
      %{
        optional(:type) => String.t(),
        required(:value) => String.t(),
        optional(:variables_reference) => integer(),
        optional(:memory_reference) => String.t(),
        optional(:named_variables) => integer(),
        optional(:indexed_variables) => integer(),
        optional(:value_location_reference) => integer()
      },
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => true,
      :command => "setVariable",
      :body =>
        map(%{
          optional({"type", :type}) => str(),
          {"value", :value} => str(),
          optional({"variablesReference", :variables_reference}) => int(),
          optional({"memoryReference", :memory_reference}) => str(),
          optional({"namedVariables", :named_variables}) => int(),
          optional({"indexedVariables", :indexed_variables}) => int(),
          optional({"valueLocationReference", :value_location_reference}) => int()
        })
    })
  end
end
