# codegen: do not edit
defmodule GenDAP.Requests.SetDataBreakpoints do
  @moduledoc """
  Replaces all existing data breakpoints with new data breakpoints.
  To clear all data breakpoints, specify an empty array.
  When a data breakpoint is hit, a `stopped` event (with reason `data breakpoint`) is generated.
  Clients should only call this request if the corresponding capability `supportsDataBreakpoints` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "setDataBreakpoints"
    field :arguments, GenDAP.Structures.SetDataBreakpointsArguments.t()
  end

  @type response :: %{breakpoints: list(GenDAP.Structures.Breakpoint.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setDataBreakpoints",
      :arguments => GenDAP.Structures.SetDataBreakpointsArguments.schematic()
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
      :command => "setDataBreakpoints",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :breakpoints => list(GenDAP.Structures.Breakpoint.schematic())
    })
    })
  end
end
