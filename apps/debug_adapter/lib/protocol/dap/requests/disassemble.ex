# codegen: do not edit
defmodule GenDAP.Requests.Disassemble do
  @moduledoc """
  Disassembles code stored at the provided location.
  Clients should only call this request if the corresponding capability `supportsDisassembleRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "disassemble"
    field :arguments, GenDAP.Structures.DisassembleArguments.t()
  end

  @type response :: %{instructions: list(GenDAP.Structures.DisassembledInstruction.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "disassemble",
      :arguments => GenDAP.Structures.DisassembleArguments.schematic()
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
      :command => "disassemble",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :instructions => list(GenDAP.Structures.DisassembledInstruction.schematic())
    })
    })
  end
end
