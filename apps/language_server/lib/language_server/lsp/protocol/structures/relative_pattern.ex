# codegen: do not edit
defmodule GenLSP.Structures.RelativePattern do
  @moduledoc """
  A relative pattern is a helper to construct glob patterns that are matched
  relatively to a base URI. The common value for a `baseUri` is a workspace
  folder root, but it can be another absolute URI as well.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * base_uri: A workspace folder or a base URI to which this pattern will be matched
    against relatively.
  * pattern: The actual glob pattern;
  """
  
  typedstruct do
    field :base_uri, GenLSP.Structures.WorkspaceFolder.t() | GenLSP.BaseTypes.uri(), enforce: true
    field :pattern, GenLSP.TypeAlias.Pattern.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"baseUri", :base_uri} => oneof([GenLSP.Structures.WorkspaceFolder.schematic(), str()]),
      {"pattern", :pattern} => GenLSP.TypeAlias.Pattern.schematic()
    })
  end
end
