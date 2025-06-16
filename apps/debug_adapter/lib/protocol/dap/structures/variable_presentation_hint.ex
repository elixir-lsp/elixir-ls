# codegen: do not edit

defmodule GenDAP.Structures.VariablePresentationHint do
  @moduledoc """
  Properties of a variable that can be used to determine how to render the variable in the UI.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * attributes: Set of attributes represented as an array of strings. Before introducing additional values, try to use the listed values.
  * kind: The kind of variable. Before introducing additional values, try to use the listed values.
  * lazy: If true, clients can present the variable with a UI that supports a specific gesture to trigger its evaluation.
    This mechanism can be used for properties that require executing code when retrieving their value and where the code execution can be expensive and/or produce side-effects. A typical example are properties based on a getter function.
    Please note that in addition to the `lazy` flag, the variable's `variablesReference` is expected to refer to a variable that will provide the value through another `variable` request.
  * visibility: Visibility of variable. Before introducing additional values, try to use the listed values.
  """

  typedstruct do
    @typedoc "A type defining DAP structure VariablePresentationHint"
    field(:attributes, list(String.t()))
    field(:kind, String.t())
    field(:lazy, boolean())
    field(:visibility, String.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"attributes", :attributes}) =>
        list(
          oneof([
            "static",
            "constant",
            "readOnly",
            "rawString",
            "hasObjectId",
            "canHaveObjectId",
            "hasSideEffects",
            "hasDataBreakpoint",
            str()
          ])
        ),
      optional({"kind", :kind}) =>
        oneof([
          "property",
          "method",
          "class",
          "data",
          "event",
          "baseClass",
          "innerClass",
          "interface",
          "mostDerivedClass",
          "virtual",
          "dataBreakpoint",
          str()
        ]),
      optional({"lazy", :lazy}) => bool(),
      optional({"visibility", :visibility}) =>
        oneof(["public", "private", "protected", "internal", "final", str()])
    })
  end
end
