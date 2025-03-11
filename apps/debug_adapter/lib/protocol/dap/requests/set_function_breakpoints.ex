# codegen: do not edit
defmodule GenDAP.Requests.SetFunctionBreakpoints do
  @moduledoc """
  Replaces all existing function breakpoints with new function breakpoints.
  To clear all function breakpoints, specify an empty array.
  When a function breakpoint is hit, a `stopped` event (with reason `function breakpoint`) is generated.
  Clients should only call this request if the corresponding capability `supportsFunctionBreakpoints` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "setFunctionBreakpoints"
    field :arguments, GenDAP.Structures.SetFunctionBreakpointsArguments.t()
  end

  @type response :: %{breakpoints: list(GenDAP.Structures.Breakpoint.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setFunctionBreakpoints",
      :arguments => GenDAP.Structures.SetFunctionBreakpointsArguments.schematic()
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
      :command => "setFunctionBreakpoints",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :breakpoints => list(GenDAP.Structures.Breakpoint.schematic())
    })
    })
  end
end
