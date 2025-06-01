# codegen: do not edit
defmodule GenDAP.Requests.EvaluateRequest do
  @moduledoc """
  Evaluates the given expression in the context of a stack frame.
  The expression has access to any variables and arguments that are in scope.

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
    @typedoc "A type defining DAP request evaluate"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "evaluate")
    field(:arguments, GenDAP.Structures.EvaluateArguments.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "evaluate",
      :arguments => GenDAP.Structures.EvaluateArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.EvaluateResponse do
  @moduledoc """
  Response to `evaluate` request.

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
    @typedoc "A type defining DAP request evaluate response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "evaluate")

    field(
      :body,
      %{
        optional(:type) => String.t(),
        required(:result) => String.t(),
        required(:variables_reference) => integer(),
        optional(:memory_reference) => String.t(),
        optional(:named_variables) => integer(),
        optional(:indexed_variables) => integer(),
        optional(:value_location_reference) => integer(),
        optional(:presentation_hint) => GenDAP.Structures.VariablePresentationHint.t()
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
      :command => "evaluate",
      :body =>
        map(%{
          optional({"type", :type}) => str(),
          {"result", :result} => str(),
          {"variablesReference", :variables_reference} => int(),
          optional({"memoryReference", :memory_reference}) => str(),
          optional({"namedVariables", :named_variables}) => int(),
          optional({"indexedVariables", :indexed_variables}) => int(),
          optional({"valueLocationReference", :value_location_reference}) => int(),
          optional({"presentationHint", :presentation_hint}) =>
            GenDAP.Structures.VariablePresentationHint.schematic()
        })
    })
  end
end
