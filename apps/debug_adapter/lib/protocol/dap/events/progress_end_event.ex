# codegen: do not edit

defmodule GenDAP.Events.ProgressEndEvent do
  @moduledoc """
  The event signals the end of the progress reporting with a final message.
  This event should only be sent if the corresponding capability `supportsProgressReporting` is true.

  Message Direction: adapter -> client
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "progressEnd"
    field :body, %{message: String.t(), progress_id: String.t()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "progressEnd",
      :body => map(%{
        optional(:message) => str(),
        {:progressId, :progress_id} => str()
      })
    })
  end
end
