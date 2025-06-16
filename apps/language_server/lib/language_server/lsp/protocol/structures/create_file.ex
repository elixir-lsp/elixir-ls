# codegen: do not edit
defmodule GenLSP.Structures.CreateFile do
  @moduledoc """
  Create file operation.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * kind: A create
  * uri: The resource to create.
  * options: Additional options
  * annotation_id: An optional annotation identifier describing the operation.

    @since 3.16.0
  """

  typedstruct do
    field(:kind, String.t(), enforce: true)
    field(:uri, GenLSP.BaseTypes.document_uri(), enforce: true)
    field(:options, GenLSP.Structures.CreateFileOptions.t())
    field(:annotation_id, GenLSP.TypeAlias.ChangeAnnotationIdentifier.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"kind", :kind} => "create",
      {"uri", :uri} => str(),
      optional({"options", :options}) => GenLSP.Structures.CreateFileOptions.schematic(),
      optional({"annotationId", :annotation_id}) =>
        GenLSP.TypeAlias.ChangeAnnotationIdentifier.schematic()
    })
  end
end
