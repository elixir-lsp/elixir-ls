# codegen: do not edit
defmodule GenDAP.Requests.LoadedSources do
  @moduledoc """
  Retrieves the set of all sources currently loaded by the debugged process.
  Clients should only call this request if the corresponding capability `supportsLoadedSourcesRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "loadedSources"
    field :arguments, GenDAP.Structures.LoadedSourcesArguments.t(), enforce: false
  end

  @type response :: %{sources: list(GenDAP.Structures.Source.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "loadedSources",
      optional(:arguments) => GenDAP.Structures.LoadedSourcesArguments.schematic()
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
      :command => "loadedSources",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :sources => list(GenDAP.Structures.Source.schematic())
    })
    })
  end
end
