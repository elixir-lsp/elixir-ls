# codegen: do not edit

defmodule GenDAP.Structures.ModulesArguments do
  @moduledoc """
  Arguments for `modules` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * module_count: The number of modules to return. If `moduleCount` is not specified or 0, all modules are returned.
  * start_module: The index of the first module to return; if omitted modules start at 0.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ModulesArguments"
    field(:module_count, integer())
    field(:start_module, integer())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"moduleCount", :module_count}) => int(),
      optional({"startModule", :start_module}) => int()
    })
  end
end
