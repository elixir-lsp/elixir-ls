# codegen: do not edit
defmodule GenLSP.TypeAlias.NotebookDocumentFilter do
  @moduledoc """
  A notebook document filter denotes a notebook document by
  different properties. The properties will be match
  against the notebook's URI (same as with documents)

  @since 3.17.0
  """

  import SchematicV, warn: false

  @type t :: map() | map() | map()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      map(%{
        {"notebookType", :notebook_type} => str(),
        optional({"scheme", :scheme}) => str(),
        optional({"pattern", :pattern}) => str()
      }),
      map(%{
        optional({"notebookType", :notebook_type}) => str(),
        {"scheme", :scheme} => str(),
        optional({"pattern", :pattern}) => str()
      }),
      map(%{
        optional({"notebookType", :notebook_type}) => str(),
        optional({"scheme", :scheme}) => str(),
        {"pattern", :pattern} => str()
      })
    ])
  end
end
