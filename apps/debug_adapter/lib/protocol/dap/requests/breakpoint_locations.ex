# codegen: do not edit
defmodule GenDAP.Requests.BreakpointLocations do
  @moduledoc """
  The `breakpointLocations` request returns all possible locations for source breakpoints in a given range.
  Clients should only call this request if the corresponding capability `supportsBreakpointLocationsRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "breakpointLocations"
    field :arguments, GenDAP.Structures.BreakpointLocationsArguments.t(), enforce: false
  end

  @type response :: %{breakpoints: list(GenDAP.Structures.BreakpointLocation.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "breakpointLocations",
      optional(:arguments) => GenDAP.Structures.BreakpointLocationsArguments.schematic()
    })
  end

  @doc false
  @spec response() :: Schematic.t()
  def response() do
    schema(GenDAP.Response, %{
      :seq => int(),
      :type => "response",
      :request_seq => int(),
      :success => bool(),
      :command => "breakpointLocations",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :breakpoints => list(GenDAP.Structures.BreakpointLocation.schematic())
    })
    })
  end
end
