# codegen: do not edit
defmodule GenDAP.Requests.Completions do
  @moduledoc """
  Returns a list of possible completions for a given caret position and text.
  Clients should only call this request if the corresponding capability `supportsCompletionsRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "completions"
    field :arguments, GenDAP.Structures.CompletionsArguments.t()
  end

  @type response :: %{targets: list(GenDAP.Structures.CompletionItem.t())}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "completions",
      :arguments => GenDAP.Structures.CompletionsArguments.schematic()
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
      :command => "completions",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :targets => list(GenDAP.Structures.CompletionItem.schematic())
    })
    })
  end
end
