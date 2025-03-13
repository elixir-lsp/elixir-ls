# codegen: do not edit
defmodule GenDAP.Structures.Variable do
  @moduledoc """
  A Variable is a name/value pair.
  The `type` attribute is shown if space permits or when hovering over the variable's name.
  The `kind` attribute is used to render additional properties of the variable, e.g. different icons can be used to indicate that a variable is public or private.
  If the value is structured (has children), a handle is provided to retrieve the children with the `variables` request.
  If the number of named or indexed children is large, the numbers should be returned via the `namedVariables` and `indexedVariables` attributes.
  The client can use this information to present the children in a paged UI and fetch them in chunks.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * declaration_location_reference: A reference that allows the client to request the location where the variable is declared. This should be present only if the adapter is likely to be able to resolve the location.
    
    This reference shares the same lifetime as the `variablesReference`. See 'Lifetime of Object References' in the Overview section for details.
  * evaluate_name: The evaluatable name of this variable which can be passed to the `evaluate` request to fetch the variable's value.
  * indexed_variables: The number of indexed child variables.
    The client can use this information to present the children in a paged UI and fetch them in chunks.
  * memory_reference: A memory reference associated with this variable.
    For pointer type variables, this is generally a reference to the memory address contained in the pointer.
    For executable data, this reference may later be used in a `disassemble` request.
    This attribute may be returned by a debug adapter if corresponding capability `supportsMemoryReferences` is true.
  * name: The variable's name.
  * named_variables: The number of named child variables.
    The client can use this information to present the children in a paged UI and fetch them in chunks.
  * presentation_hint: Properties of a variable that can be used to determine how to render the variable in the UI.
  * type: The type of the variable's value. Typically shown in the UI when hovering over the value.
    This attribute should only be returned by a debug adapter if the corresponding capability `supportsVariableType` is true.
  * value: The variable's value.
    This can be a multi-line text, e.g. for a function the body of a function.
    For structured variables (which do not have a simple value), it is recommended to provide a one-line representation of the structured object. This helps to identify the structured object in the collapsed state when its children are not yet visible.
    An empty string can be used if no value should be shown in the UI.
  * value_location_reference: A reference that allows the client to request the location where the variable's value is declared. For example, if the variable contains a function pointer, the adapter may be able to look up the function's location. This should be present only if the adapter is likely to be able to resolve the location.
    
    This reference shares the same lifetime as the `variablesReference`. See 'Lifetime of Object References' in the Overview section for details.
  * variables_reference: If `variablesReference` is > 0, the variable is structured and its children can be retrieved by passing `variablesReference` to the `variables` request as long as execution remains suspended. See 'Lifetime of Object References' in the Overview section for details.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure Variable"
    field :declaration_location_reference, integer()
    field :evaluate_name, String.t()
    field :indexed_variables, integer()
    field :memory_reference, String.t()
    field :name, String.t(), enforce: true
    field :named_variables, integer()
    field :presentation_hint, GenDAP.Structures.VariablePresentationHint.t()
    field :type, String.t()
    field :value, String.t(), enforce: true
    field :value_location_reference, integer()
    field :variables_reference, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"declarationLocationReference", :declaration_location_reference}) => int(),
      optional({"evaluateName", :evaluate_name}) => str(),
      optional({"indexedVariables", :indexed_variables}) => int(),
      optional({"memoryReference", :memory_reference}) => str(),
      {"name", :name} => str(),
      optional({"namedVariables", :named_variables}) => int(),
      optional({"presentationHint", :presentation_hint}) => GenDAP.Structures.VariablePresentationHint.schematic(),
      optional({"type", :type}) => str(),
      {"value", :value} => str(),
      optional({"valueLocationReference", :value_location_reference}) => int(),
      {"variablesReference", :variables_reference} => int(),
    })
  end
end
