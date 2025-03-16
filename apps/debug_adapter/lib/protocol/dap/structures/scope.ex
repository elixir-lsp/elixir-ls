# codegen: do not edit


defmodule GenDAP.Structures.Scope do
  @moduledoc """
  A `Scope` is a named container for variables. Optionally a scope can map to a source or a range within a source.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * column: Start position of the range covered by the scope. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_column: End position of the range covered by the scope. It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * end_line: The end line of the range covered by this scope.
  * expensive: If true, the number of variables in this scope is large or expensive to retrieve.
  * indexed_variables: The number of indexed variables in this scope.
    The client can use this information to present the variables in a paged UI and fetch them in chunks.
  * line: The start line of the range covered by this scope.
  * name: Name of the scope such as 'Arguments', 'Locals', or 'Registers'. This string is shown in the UI as is and can be translated.
  * named_variables: The number of named variables in this scope.
    The client can use this information to present the variables in a paged UI and fetch them in chunks.
  * presentation_hint: A hint for how to present this scope in the UI. If this attribute is missing, the scope is shown with a generic UI.
  * source: The source for this scope.
  * variables_reference: The variables of this scope can be retrieved by passing the value of `variablesReference` to the `variables` request as long as execution remains suspended. See 'Lifetime of Object References' in the Overview section for details.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure Scope"
    field :column, integer()
    field :end_column, integer()
    field :end_line, integer()
    field :expensive, boolean(), enforce: true
    field :indexed_variables, integer()
    field :line, integer()
    field :name, String.t(), enforce: true
    field :named_variables, integer()
    field :presentation_hint, String.t()
    field :source, GenDAP.Structures.Source.t()
    field :variables_reference, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      optional({"endColumn", :end_column}) => int(),
      optional({"endLine", :end_line}) => int(),
      {"expensive", :expensive} => bool(),
      optional({"indexedVariables", :indexed_variables}) => int(),
      optional({"line", :line}) => int(),
      {"name", :name} => str(),
      optional({"namedVariables", :named_variables}) => int(),
      optional({"presentationHint", :presentation_hint}) => oneof(["arguments", "locals", "registers", "returnValue", str()]),
      optional({"source", :source}) => GenDAP.Structures.Source.schematic(),
      {"variablesReference", :variables_reference} => int(),
    })
  end
end

