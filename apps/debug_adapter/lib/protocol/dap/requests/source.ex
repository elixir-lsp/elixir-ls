# codegen: do not edit
defmodule GenDAP.Requests.Source do
  @moduledoc """
  The request retrieves the source code for a given source reference.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "source"
    field :arguments, GenDAP.Structures.SourceArguments.t()
  end

  @type response :: %{content: String.t(), mime_type: String.t()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "source",
      :arguments => GenDAP.Structures.SourceArguments.schematic()
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
      :command => "source",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :content => str(),
      optional(:mimeType) => str()
    })
    })
  end
end
