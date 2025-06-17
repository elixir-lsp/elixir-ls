# codegen: do not edit
defmodule GenLSP.Structures.FileOperationPattern do
  @moduledoc """
  A pattern to describe in which file operation requests or notifications
  the server is interested in receiving.

  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * glob: The glob pattern to match. Glob patterns can have the following syntax:
    - `*` to match one or more characters in a path segment
    - `?` to match on one character in a path segment
    - `**` to match any number of path segments, including none
    - `{}` to group sub patterns into an OR expression. (e.g. `**​/*.{ts,js}` matches all TypeScript and JavaScript files)
    - `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
    - `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
  * matches: Whether to match files or folders with this pattern.

    Matches both if undefined.
  * options: Additional options used during matching.
  """

  typedstruct do
    field(:glob, String.t(), enforce: true)
    field(:matches, GenLSP.Enumerations.FileOperationPatternKind.t())
    field(:options, GenLSP.Structures.FileOperationPatternOptions.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"glob", :glob} => str(),
      optional({"matches", :matches}) => GenLSP.Enumerations.FileOperationPatternKind.schematic(),
      optional({"options", :options}) => GenLSP.Structures.FileOperationPatternOptions.schematic()
    })
  end
end
