# codegen: do not edit

defmodule GenDAP.Events.ProgressUpdateEvent do
  @moduledoc """
  The event signals that the progress reporting needs to be updated with a new message and/or percentage.
  The client does not have to update the UI immediately, but the clients needs to keep track of the message and/or percentage values.
  This event should only be sent if the corresponding capability `supportsProgressReporting` is true.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "progressUpdate"
    field :body, %{message: String.t(), progress_id: String.t(), percentage: number()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "progressUpdate",
      :body => map(%{
        optional(:message) => str(),
        {:progressId, :progress_id} => str(),
        optional(:percentage) => oneof([int(), float()])
      })
    })
  end
end
