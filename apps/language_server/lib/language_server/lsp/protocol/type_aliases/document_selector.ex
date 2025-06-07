# codegen: do not edit
defmodule GenLSP.TypeAlias.DocumentSelector do
  @moduledoc """
  A document selector is the combination of one or many document filters.

  @sample `let sel:DocumentSelector = [{ language: 'typescript' }, { language: 'json', pattern: '**∕tsconfig.json' }]`;

  The use of a string as a document filter is deprecated @since 3.16.0.
  """

  import Schematic, warn: false

  @type t :: list(GenLSP.TypeAlias.DocumentFilter.t())

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    list(GenLSP.TypeAlias.DocumentFilter.schematic())
  end
end
