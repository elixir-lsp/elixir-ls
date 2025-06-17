# codegen: do not edit
defmodule GenLSP.Structures.FormattingOptions do
  @moduledoc """
  Value-object describing what options formatting should use.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * tab_size: Size of a tab in spaces.
  * insert_spaces: Prefer spaces over tabs.
  * trim_trailing_whitespace: Trim trailing whitespace on a line.

    @since 3.15.0
  * insert_final_newline: Insert a newline character at the end of the file if one does not exist.

    @since 3.15.0
  * trim_final_newlines: Trim all newlines after the final newline at the end of the file.

    @since 3.15.0
  """

  typedstruct do
    field(:tab_size, GenLSP.BaseTypes.uinteger(), enforce: true)
    field(:insert_spaces, boolean(), enforce: true)
    field(:trim_trailing_whitespace, boolean())
    field(:insert_final_newline, boolean())
    field(:trim_final_newlines, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"tabSize", :tab_size} => int(),
      {"insertSpaces", :insert_spaces} => bool(),
      optional({"trimTrailingWhitespace", :trim_trailing_whitespace}) => bool(),
      optional({"insertFinalNewline", :insert_final_newline}) => bool(),
      optional({"trimFinalNewlines", :trim_final_newlines}) => bool()
    })
  end
end
