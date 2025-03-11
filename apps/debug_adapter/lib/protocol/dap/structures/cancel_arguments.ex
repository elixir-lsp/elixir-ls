# codegen: do not edit
defmodule GenDAP.Structures.CancelArguments do
  @moduledoc """
  Arguments for `cancel` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * request_id: The ID (attribute `seq`) of the request to cancel. If missing no request is cancelled.
    Both a `requestId` and a `progressId` can be specified in one request.
  * progress_id: The ID (attribute `progressId`) of the progress to cancel. If missing no progress is cancelled.
    Both a `requestId` and a `progressId` can be specified in one request.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :request_id, integer()
    field :progress_id, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"requestId", :request_id}) => int(),
      optional({"progressId", :progress_id}) => str(),
    })
  end
end
