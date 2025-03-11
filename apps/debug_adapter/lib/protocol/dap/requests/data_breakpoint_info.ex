# codegen: do not edit
defmodule GenDAP.Requests.DataBreakpointInfo do
  @moduledoc """
  Obtains information on a possible data breakpoint that could be set on an expression or variable.
  Clients should only call this request if the corresponding capability `supportsDataBreakpoints` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "dataBreakpointInfo"
    field :arguments, GenDAP.Structures.DataBreakpointInfoArguments.t()
  end

  @type response :: %{description: String.t(), data_id: String.t() | nil, access_types: list(GenDAP.Enumerations.DataBreakpointAccessType.t()), can_persist: boolean()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "dataBreakpointInfo",
      :arguments => GenDAP.Structures.DataBreakpointInfoArguments.schematic()
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
      :command => "dataBreakpointInfo",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :description => str(),
      :dataId => oneof([str(), nil]),
      optional(:accessTypes) => list(GenDAP.Enumerations.DataBreakpointAccessType.schematic()),
      optional(:canPersist) => bool()
    })
    })
  end
end
