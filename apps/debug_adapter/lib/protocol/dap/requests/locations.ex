# codegen: do not edit
defmodule GenDAP.Requests.LocationsRequest do
  @moduledoc """
  Looks up information about a location reference previously returned by the debug adapter.

  Message Direction: client -> adapter
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * arguments: Object containing arguments for the command.
  * command: The command to execute.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """

  typedstruct do
    @typedoc "A type defining DAP request locations"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "request")
    field(:command, String.t(), default: "locations")
    field(:arguments, GenDAP.Structures.LocationsArguments.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "locations",
      :arguments => GenDAP.Structures.LocationsArguments.schematic()
    })
  end
end

defmodule GenDAP.Requests.LocationsResponse do
  @moduledoc """
  Response to `locations` request.

  Message Direction: adapter -> client
  """

  import SchematicV, warn: false

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
    @typedoc "A type defining DAP request locations response"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "response")
    field(:request_seq, integer(), enforce: true)
    field(:success, boolean(), default: true)
    field(:command, String.t(), default: "locations")

    field(:body, %{
      required(:line) => integer(),
      optional(:column) => integer(),
      required(:source) => GenDAP.Structures.Source.t(),
      optional(:end_line) => integer(),
      optional(:end_column) => integer()
    })
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => true,
      :command => "locations",
      optional(:body) =>
        map(%{
          {"line", :line} => int(),
          optional({"column", :column}) => int(),
          {"source", :source} => GenDAP.Structures.Source.schematic(),
          optional({"endLine", :end_line}) => int(),
          optional({"endColumn", :end_column}) => int()
        })
    })
  end
end
