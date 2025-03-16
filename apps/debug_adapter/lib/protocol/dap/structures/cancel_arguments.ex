# codegen: do not edit

defmodule GenDAP.Structures.CancelArguments do
  @moduledoc """
  Arguments for `cancel` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * progress_id: The ID (attribute `progressId`) of the progress to cancel. If missing no progress is cancelled.
    Both a `requestId` and a `progressId` can be specified in one request.
  * request_id: The ID (attribute `seq`) of the request to cancel. If missing no request is cancelled.
    Both a `requestId` and a `progressId` can be specified in one request.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure CancelArguments"
    field(:progress_id, String.t())
    field(:request_id, integer())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"progressId", :progress_id}) => str(),
      optional({"requestId", :request_id}) => int()
    })
  end
end
