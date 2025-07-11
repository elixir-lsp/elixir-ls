# codegen: do not edit

defmodule GenDAP.Structures.SourceArguments do
  @moduledoc """
  Arguments for `source` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * source: Specifies the source content to load. Either `source.path` or `source.sourceReference` must be specified.
  * source_reference: The reference to the source. This is the same as `source.sourceReference`.
    This is provided for backward compatibility since old clients do not understand the `source` attribute.
  """

  typedstruct do
    @typedoc "A type defining DAP structure SourceArguments"
    field(:source, GenDAP.Structures.Source.t())
    field(:source_reference, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"source", :source}) => GenDAP.Structures.Source.schematic(),
      {"sourceReference", :source_reference} => int()
    })
  end
end
