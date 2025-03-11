# codegen: do not edit
defmodule GenDAP.Structures.ModulesArguments do
  @moduledoc """
  Arguments for `modules` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * start_module: The index of the first module to return; if omitted modules start at 0.
  * module_count: The number of modules to return. If `moduleCount` is not specified or 0, all modules are returned.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :start_module, integer()
    field :module_count, integer()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"startModule", :start_module}) => int(),
      optional({"moduleCount", :module_count}) => int(),
    })
  end
end
