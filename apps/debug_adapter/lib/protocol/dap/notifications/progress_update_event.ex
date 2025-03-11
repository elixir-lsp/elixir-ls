# codegen: do not edit

defmodule GenDAP.Notifications.ProgressUpdateEvent do

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "progressUpdate"
    field :body, %{message: String.t(), progress_id: String.t(), percentage: number()}, enforce: false
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "progressUpdate",
      optional(:body) => map(%{
        :message => str(),
        {:progressId, :progress_id} => str(),
        :percentage => oneof([int(), float()])
      })
    })
  end
end
