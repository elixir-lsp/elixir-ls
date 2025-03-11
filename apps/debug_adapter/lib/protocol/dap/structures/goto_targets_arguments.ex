# codegen: do not edit
defmodule GenDAP.Structures.GotoTargetsArguments do
  @moduledoc """
  Arguments for `gotoTargets` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * line: The line location for which the goto targets are determined.
  * column: The position within `line` for which the goto targets are determined. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * source: The source location for which the goto targets are determined.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :line, integer(), enforce: true
    field :column, integer()
    field :source, GenDAP.Structures.Source.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"line", :line} => int(),
      optional({"column", :column}) => int(),
      {"source", :source} => GenDAP.Structures.Source.schematic(),
    })
  end
end
