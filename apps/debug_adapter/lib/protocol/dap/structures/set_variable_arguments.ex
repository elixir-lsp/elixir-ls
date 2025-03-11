# codegen: do not edit
defmodule GenDAP.Structures.SetVariableArguments do
  @moduledoc """
  Arguments for `setVariable` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * name: The name of the variable in the container.
  * value: The value of the variable.
  * format: Specifies details on how to format the response value.
  * variables_reference: The reference of the variable container. The `variablesReference` must have been obtained in the current suspended state. See 'Lifetime of Object References' in the Overview section for details.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :name, String.t(), enforce: true
    field :value, String.t(), enforce: true
    field :format, GenDAP.Structures.ValueFormat.t()
    field :variables_reference, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"name", :name} => str(),
      {"value", :value} => str(),
      optional({"format", :format}) => GenDAP.Structures.ValueFormat.schematic(),
      {"variablesReference", :variables_reference} => int(),
    })
  end
end
