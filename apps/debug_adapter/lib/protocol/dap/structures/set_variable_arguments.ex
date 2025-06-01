# codegen: do not edit

defmodule GenDAP.Structures.SetVariableArguments do
  @moduledoc """
  Arguments for `setVariable` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * format: Specifies details on how to format the response value.
  * name: The name of the variable in the container.
  * value: The value of the variable.
  * variables_reference: The reference of the variable container. The `variablesReference` must have been obtained in the current suspended state. See 'Lifetime of Object References' in the Overview section for details.
  """

  typedstruct do
    @typedoc "A type defining DAP structure SetVariableArguments"
    field(:format, GenDAP.Structures.ValueFormat.t())
    field(:name, String.t(), enforce: true)
    field(:value, String.t(), enforce: true)
    field(:variables_reference, integer(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"format", :format}) => GenDAP.Structures.ValueFormat.schematic(),
      {"name", :name} => str(),
      {"value", :value} => str(),
      {"variablesReference", :variables_reference} => int()
    })
  end
end
