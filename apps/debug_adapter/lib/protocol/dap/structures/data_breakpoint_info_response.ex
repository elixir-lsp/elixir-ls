# codegen: do not edit
defmodule GenDAP.Structures.DataBreakpointInfoResponse do
  @moduledoc """
  Response to `dataBreakpointInfo` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * body
  * command: The command requested.
  * message: Contains the raw error in short form if `success` is false.
    This raw error might be interpreted by the client and is not shown in the UI.
    Some predefined values exist.
  * type
  * success: Outcome of the request.
    If true, the request was successful and the `body` attribute may contain the result of the request.
    If the value is false, the attribute `message` contains the error in short form and the `body` may contain additional information (see `ErrorResponse.body.error`).
  * request_seq: Sequence number of the corresponding request.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :body, %{description: String.t(), data_id: String.t() | nil, access_types: list(GenDAP.Enumerations.DataBreakpointAccessType.t()), can_persist: boolean()}, enforce: true
    field :command, String.t(), enforce: true
    field :message, String.t()
    field :type, String.t(), enforce: true
    field :success, boolean(), enforce: true
    field :request_seq, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"body", :body} => schema(__MODULE__, %{
      :description => str(),
      :dataId => oneof([str(), nil]),
      optional(:accessTypes) => list(GenDAP.Enumerations.DataBreakpointAccessType.schematic()),
      optional(:canPersist) => bool()
    }),
      {"command", :command} => str(),
      optional({"message", :message}) => oneof(["cancelled", "notStopped"]),
      {"type", :type} => oneof(["response"]),
      {"success", :success} => bool(),
      {"request_seq", :request_seq} => int(),
    })
  end
end
