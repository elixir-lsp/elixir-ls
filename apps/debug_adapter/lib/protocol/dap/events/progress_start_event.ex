# codegen: do not edit

defmodule GenDAP.Events.ProgressStartEvent do
  @moduledoc """
  The event signals that a long running operation is about to start and provides additional information for the client to set up a corresponding progress and cancellation UI.
  The client is free to delay the showing of the UI in order to reduce flicker.
  This event should only be sent if the corresponding capability `supportsProgressReporting` is true.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "progressStart"
    field :body, %{message: String.t(), title: String.t(), request_id: integer(), progress_id: String.t(), cancellable: boolean(), percentage: number()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "progressStart",
      :body => map(%{
        optional(:message) => str(),
        :title => str(),
        optional({:requestId, :request_id}) => int(),
        {:progressId, :progress_id} => str(),
        optional(:cancellable) => bool(),
        optional(:percentage) => oneof([int(), float()])
      })
    })
  end
end
