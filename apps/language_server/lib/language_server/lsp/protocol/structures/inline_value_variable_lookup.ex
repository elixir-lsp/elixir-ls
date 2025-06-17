# codegen: do not edit
defmodule GenLSP.Structures.InlineValueVariableLookup do
  @moduledoc """
  Provide inline value through a variable lookup.
  If only a range is specified, the variable name will be extracted from the underlying document.
  An optional variable name can be used to override the extracted name.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * range: The document range for which the inline value applies.
    The range is used to extract the variable name from the underlying document.
  * variable_name: If specified the name of the variable to look up.
  * case_sensitive_lookup: How to perform the lookup.
  """

  typedstruct do
    field(:range, GenLSP.Structures.Range.t(), enforce: true)
    field(:variable_name, String.t())
    field(:case_sensitive_lookup, boolean(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"range", :range} => GenLSP.Structures.Range.schematic(),
      optional({"variableName", :variable_name}) => str(),
      {"caseSensitiveLookup", :case_sensitive_lookup} => bool()
    })
  end
end
