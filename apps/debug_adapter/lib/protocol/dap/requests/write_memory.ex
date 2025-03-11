# codegen: do not edit
defmodule GenDAP.Requests.WriteMemory do
  @moduledoc """
  Writes bytes to memory at the provided location.
  Clients should only call this request if the corresponding capability `supportsWriteMemoryRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "writeMemory"
    field :arguments, GenDAP.Structures.WriteMemoryArguments.t()
  end

  @type response :: %{offset: integer(), bytes_written: integer()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "writeMemory",
      :arguments => GenDAP.Structures.WriteMemoryArguments.schematic()
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
      :command => "writeMemory",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:offset) => int(),
      optional(:bytesWritten) => int()
    })
    })
  end
end
