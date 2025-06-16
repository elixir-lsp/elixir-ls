# codegen: do not edit

defmodule GenDAP.Structures.GotoTargetsArguments do
  @moduledoc """
  Arguments for `gotoTargets` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * column: The position within `line` for which the goto targets are determined. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * line: The line location for which the goto targets are determined.
  * source: The source location for which the goto targets are determined.
  """

  typedstruct do
    @typedoc "A type defining DAP structure GotoTargetsArguments"
    field(:column, integer())
    field(:line, integer(), enforce: true)
    field(:source, GenDAP.Structures.Source.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      {"line", :line} => int(),
      {"source", :source} => GenDAP.Structures.Source.schematic()
    })
  end
end
