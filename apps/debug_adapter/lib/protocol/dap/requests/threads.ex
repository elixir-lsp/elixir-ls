# codegen: do not edit
defmodule GenDAP.Requests.Threads do
  @moduledoc """
  The request retrieves a list of all threads.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "threads"
  end

  @type response :: %{threads: list(GenDAP.Structures.Thread.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "threads",
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
      :command => "threads",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :threads => list(GenDAP.Structures.Thread.schematic())
    })
    })
  end
end
