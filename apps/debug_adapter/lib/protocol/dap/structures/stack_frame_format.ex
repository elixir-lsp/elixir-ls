# codegen: do not edit
defmodule GenDAP.Structures.StackFrameFormat do
  @moduledoc """
  Provides formatting information for a stack frame.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * line: Displays the line number of the stack frame.
  * module: Displays the module of the stack frame.
  * parameters: Displays parameters for the stack frame.
  * parameter_types: Displays the types of parameters for the stack frame.
  * parameter_names: Displays the names of parameters for the stack frame.
  * parameter_values: Displays the values of parameters for the stack frame.
  * include_all: Includes all stack frames, including those the debug adapter might otherwise hide.
  * hex: Display the value in hex.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :line, boolean()
    field :module, boolean()
    field :parameters, boolean()
    field :parameter_types, boolean()
    field :parameter_names, boolean()
    field :parameter_values, boolean()
    field :include_all, boolean()
    field :hex, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"line", :line}) => bool(),
      optional({"module", :module}) => bool(),
      optional({"parameters", :parameters}) => bool(),
      optional({"parameterTypes", :parameter_types}) => bool(),
      optional({"parameterNames", :parameter_names}) => bool(),
      optional({"parameterValues", :parameter_values}) => bool(),
      optional({"includeAll", :include_all}) => bool(),
      optional({"hex", :hex}) => bool(),
    })
  end
end
