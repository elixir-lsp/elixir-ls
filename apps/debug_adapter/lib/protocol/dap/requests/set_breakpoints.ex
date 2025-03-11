# codegen: do not edit
defmodule GenDAP.Requests.SetBreakpoints do
  @moduledoc """
  Sets multiple breakpoints for a single source and clears all previous breakpoints in that source.
  To clear all breakpoint for a source, specify an empty array.
  When a breakpoint is hit, a `stopped` event (with reason `breakpoint`) is generated.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "setBreakpoints"
    field :arguments, GenDAP.Structures.SetBreakpointsArguments.t()
  end

  @type response :: %{breakpoints: list(GenDAP.Structures.Breakpoint.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setBreakpoints",
      :arguments => GenDAP.Structures.SetBreakpointsArguments.schematic()
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
      :command => "setBreakpoints",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :breakpoints => list(GenDAP.Structures.Breakpoint.schematic())
    })
    })
  end
end
