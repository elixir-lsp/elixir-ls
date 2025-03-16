# codegen: do not edit

defmodule GenDAP.Events.OutputEvent do
  @moduledoc """
  The event indicates that the target has produced some output.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * body: Event-specific information.
  * event: Type of event.
  * seq: Sequence number of the message (also known as message ID). The `seq` for the first message sent by a client or debug adapter is 1, and for each subsequent message is 1 greater than the previous message sent by that actor. `seq` can be used to order requests, responses, and events, and to associate requests with their corresponding responses. For protocol messages of type `request` the sequence number can be used to cancel the request.
  * type: Message type.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP event output"

    field(:seq, integer(), enforce: true)
    field(:type, String.t(), default: "event")
    field(:event, String.t(), default: "output")

    field(
      :body,
      %{
        optional(:data) => list() | boolean() | integer() | nil | number() | map() | String.t(),
        optional(:line) => integer(),
        required(:output) => String.t(),
        optional(:group) => String.t(),
        optional(:column) => integer(),
        optional(:category) => String.t(),
        optional(:source) => GenDAP.Structures.Source.t(),
        optional(:variables_reference) => integer(),
        optional(:location_reference) => integer()
      },
      enforce: true
    )
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "output",
      :body =>
        map(%{
          optional({"data", :data}) =>
            oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
          optional({"line", :line}) => int(),
          {"output", :output} => str(),
          optional({"group", :group}) => oneof(["start", "startCollapsed", "end"]),
          optional({"column", :column}) => int(),
          optional({"category", :category}) =>
            oneof(["console", "important", "stdout", "stderr", "telemetry", str()]),
          optional({"source", :source}) => GenDAP.Structures.Source.schematic(),
          optional({"variablesReference", :variables_reference}) => int(),
          optional({"locationReference", :location_reference}) => int()
        })
    })
  end
end
