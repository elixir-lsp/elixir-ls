# codegen: do not edit
defmodule GenDAP.Structures.StartDebuggingRequestArguments do
  @moduledoc """
  Arguments for `startDebugging` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * request: Indicates whether the new debug session should be started with a `launch` or `attach` request.
  * configuration: Arguments passed to the new debug session. The arguments must only contain properties understood by the `launch` or `attach` requests of the debug adapter and they must not contain any client-specific properties (e.g. `type`) or client-specific features (e.g. substitutable 'variables').
  """
  @derive JasonV.Encoder
  typedstruct do
    field :request, String.t(), enforce: true
    field :configuration, %{String.t() => any()}, enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"request", :request} => oneof(["launch", "attach"]),
      {"configuration", :configuration} => map(keys: str(), values: any()),
    })
  end
end
