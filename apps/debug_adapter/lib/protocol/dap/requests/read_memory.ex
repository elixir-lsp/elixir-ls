# codegen: do not edit
defmodule GenDAP.Requests.ReadMemory do
  @moduledoc """
  Reads bytes from memory at the provided location.
  Clients should only call this request if the corresponding capability `supportsReadMemoryRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "readMemory"
    field :arguments, GenDAP.Structures.ReadMemoryArguments.t()
  end

  @type response :: %{data: String.t(), address: String.t(), unreadable_bytes: integer()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "readMemory",
      :arguments => GenDAP.Structures.ReadMemoryArguments.schematic()
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
      :command => "readMemory",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      optional(:data) => str(),
      :address => str(),
      optional(:unreadableBytes) => int()
    })
    })
  end
end
