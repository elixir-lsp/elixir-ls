# codegen: do not edit


defmodule GenDAP.Structures.StackFrameFormat do
  @moduledoc """
  Provides formatting information for a stack frame.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * hex: Display the value in hex.
  * include_all: Includes all stack frames, including those the debug adapter might otherwise hide.
  * line: Displays the line number of the stack frame.
  * module: Displays the module of the stack frame.
  * parameter_names: Displays the names of parameters for the stack frame.
  * parameter_types: Displays the types of parameters for the stack frame.
  * parameter_values: Displays the values of parameters for the stack frame.
  * parameters: Displays parameters for the stack frame.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure StackFrameFormat"
    field :hex, boolean()
    field :include_all, boolean()
    field :line, boolean()
    field :module, boolean()
    field :parameter_names, boolean()
    field :parameter_types, boolean()
    field :parameter_values, boolean()
    field :parameters, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"hex", :hex}) => bool(),
      optional({"includeAll", :include_all}) => bool(),
      optional({"line", :line}) => bool(),
      optional({"module", :module}) => bool(),
      optional({"parameterNames", :parameter_names}) => bool(),
      optional({"parameterTypes", :parameter_types}) => bool(),
      optional({"parameterValues", :parameter_values}) => bool(),
      optional({"parameters", :parameters}) => bool(),
    })
  end
end

