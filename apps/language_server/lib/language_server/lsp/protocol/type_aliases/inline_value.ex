# codegen: do not edit
defmodule GenLSP.TypeAlias.InlineValue do
  @moduledoc """
  Inline value information can be provided by different means:
  - directly as a text value (class InlineValueText).
  - as a name to use for a variable lookup (class InlineValueVariableLookup)
  - as an evaluatable expression (class InlineValueEvaluatableExpression)
  The InlineValue types combines all inline value types into one type.

  @since 3.17.0
  """

  import SchematicV, warn: false

  @type t ::
          GenLSP.Structures.InlineValueText.t()
          | GenLSP.Structures.InlineValueVariableLookup.t()
          | GenLSP.Structures.InlineValueEvaluatableExpression.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      GenLSP.Structures.InlineValueText.schematic(),
      GenLSP.Structures.InlineValueVariableLookup.schematic(),
      GenLSP.Structures.InlineValueEvaluatableExpression.schematic()
    ])
  end
end
