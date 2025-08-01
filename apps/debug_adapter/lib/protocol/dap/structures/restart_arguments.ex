# codegen: do not edit

defmodule GenDAP.Structures.RestartArguments do
  @moduledoc """
  Arguments for `restart` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * arguments: The latest version of the `launch` or `attach` configuration.
  """

  typedstruct do
    @typedoc "A type defining DAP structure RestartArguments"
    field(
      :arguments,
      GenDAP.Structures.LaunchRequestArguments.t() | GenDAP.Structures.AttachRequestArguments.t()
    )
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"arguments", :arguments}) =>
        oneof([
          GenDAP.Structures.LaunchRequestArguments.schematic(),
          GenDAP.Structures.AttachRequestArguments.schematic()
        ])
    })
  end
end
