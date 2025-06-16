# codegen: do not edit
defmodule GenLSP.TypeAlias.Pattern do
  @moduledoc """
  The glob pattern to watch relative to the base path. Glob patterns can have the following syntax:
  - `*` to match one or more characters in a path segment
  - `?` to match on one character in a path segment
  - `**` to match any number of path segments, including none
  - `{}` to group conditions (e.g. `**​/*.{ts,js}` matches all TypeScript and JavaScript files)
  - `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
  - `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)

  @since 3.17.0
  """

  import SchematicV, warn: false

  @type t :: String.t()

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    str()
  end
end
