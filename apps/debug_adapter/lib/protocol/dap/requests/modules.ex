# codegen: do not edit
defmodule GenDAP.Requests.Modules do
  @moduledoc """
  Modules can be retrieved from the debug adapter with this request which can either return all modules or a range of modules to support paging.
  Clients should only call this request if the corresponding capability `supportsModulesRequest` is true.

  Message Direction: client -> adapter
  """

  import Schematic, warn: false

  use TypedStruct

  @derive JasonV.Encoder
  typedstruct do
    field :seq, integer(), enforce: true
    field :type, String.t(), default: "request"
    field :command, String.t(), default: "modules"
    field :arguments, GenDAP.Structures.ModulesArguments.t()
  end

  @type response :: %{modules: list(GenDAP.Structures.Module.t()), total_modules: integer()}

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      :seq => int(),
      :type => "request",
      :command => "modules",
      :arguments => GenDAP.Structures.ModulesArguments.schematic()
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
      :command => "modules",
      optional(:message) => str(),
      optional(:body) => schema(__MODULE__, %{
      :modules => list(GenDAP.Structures.Module.schematic()),
      optional(:totalModules) => int()
    })
    })
  end
end
