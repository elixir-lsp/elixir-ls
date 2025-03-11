# codegen: do not edit

defmodule GenDAP.Notifications.ProgressStartEvent do

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "event"
    field :event, String.t(), default: "progressStart"
    field :body, %{message: String.t(), title: String.t(), request_id: integer(), progress_id: String.t(), cancellable: boolean(), percentage: number()}, enforce: false
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "event",
      :event => "progressStart",
      optional(:body) => map(%{
        :message => str(),
        :title => str(),
        {:requestId, :request_id} => int(),
        {:progressId, :progress_id} => str(),
        :cancellable => bool(),
        :percentage => oneof([int(), float()])
      })
    })
  end
end
