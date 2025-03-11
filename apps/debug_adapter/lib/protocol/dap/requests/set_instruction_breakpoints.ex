# codegen: do not edit
defmodule GenDAP.Requests.SetInstructionBreakpoints do
  @moduledoc """
  Replaces all existing instruction breakpoints. Typically, instruction breakpoints would be set from a disassembly window. 
  To clear all instruction breakpoints, specify an empty array.
  When an instruction breakpoint is hit, a `stopped` event (with reason `instruction breakpoint`) is generated.
  Clients should only call this request if the corresponding capability `supportsInstructionBreakpoints` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "setInstructionBreakpoints"
    field :arguments, GenDAP.Structures.SetInstructionBreakpointsArguments.t()
  end

  @type response :: %{breakpoints: list(GenDAP.Structures.Breakpoint.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "setInstructionBreakpoints",
      :arguments => GenDAP.Structures.SetInstructionBreakpointsArguments.schematic()
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
      :command => "setInstructionBreakpoints",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :breakpoints => list(GenDAP.Structures.Breakpoint.schematic())
    })
    })
  end
end
