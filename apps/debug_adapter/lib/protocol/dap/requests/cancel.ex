# codegen: do not edit
defmodule GenDAP.Requests.Cancel do
  @moduledoc """
  The `cancel` request is used by the client in two situations:
  - to indicate that it is no longer interested in the result produced by a specific request issued earlier
  - to cancel a progress sequence.
  Clients should only call this request if the corresponding capability `supportsCancelRequest` is true.
  This request has a hint characteristic: a debug adapter can only be expected to make a 'best effort' in honoring this request but there are no guarantees.
  The `cancel` request may return an error if it could not cancel an operation but a client should refrain from presenting this error to end users.
  The request that got cancelled still needs to send a response back. This can either be a normal result (`success` attribute true) or an error response (`success` attribute false and the `message` set to `cancelled`).
  Returning partial results from a cancelled request is possible but please note that a client has no generic way for detecting that a response is partial or not.
  The progress that got cancelled still needs to send a `progressEnd` event back.
   A client should not assume that progress just got cancelled after sending the `cancel` request.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "cancel"
    field :arguments, GenDAP.Structures.CancelArguments.t(), enforce: false
  end

  @type response :: map()

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "cancel",
      optional(:arguments) => GenDAP.Structures.CancelArguments.schematic()
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
      :command => "cancel",
      optional(:message) => str(),
      optional(:body) => map()
    })
  end
end
