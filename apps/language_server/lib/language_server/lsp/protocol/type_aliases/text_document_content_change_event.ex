# codegen: do not edit
defmodule GenLSP.TypeAlias.TextDocumentContentChangeEvent do
  @moduledoc """
  An event describing a change to a text document. If only a text is provided
  it is considered to be the full content of the document.
  """

  import SchematicV, warn: false

  @type t :: map() | map()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      map(%{
        {"range", :range} => GenLSP.Structures.Range.schematic(),
        optional({"rangeLength", :range_length}) => int(),
        {"text", :text} => str()
      }),
      map(%{
        {"text", :text} => str()
      })
    ])
  end
end
