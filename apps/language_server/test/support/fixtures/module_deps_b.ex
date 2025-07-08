defmodule ElixirLS.Test.ModuleDepsB do
  @moduledoc """
  Test module B for module dependency analysis.
  Has dependencies on C and D.
  """
  
  require Logger
  alias ElixirLS.Test.ModuleDepsC
  alias ElixirLS.Test.ModuleDepsD
  
  def get_constant do
    # Used at compile time by ModuleDepsA
    42
  end
  
  def function_in_b do
    # Runtime dependencies
    result = ModuleDepsC.function_in_c()
    ModuleDepsD.function_in_d(result)
  end
  
  def function_using_logger do
    # Compile-time dependency through macro
    Logger.debug("Debug message")
    Logger.info("Info message")
  end
  
  def function_with_struct do
    # Compile-time dependency through struct expansion
    %ModuleDepsC{field: "value"}
  end
  
  def function_with_pattern_match(%ModuleDepsC{} = struct) do
    # Pattern matching on struct - compile-time dependency
    struct.field
  end
  
  def dynamic_call(module, function, args) do
    # Dynamic runtime dependency
    apply(module, function, args)
  end
  
  # Circular dependency - B depends on C, C depends on B
  def circular_dependency do
    ModuleDepsC.calls_b()
  end
  
  def uses_anonymous_function do
    # Anonymous function with dependency
    fun = fn x -> ModuleDepsD.function_in_d(x) end
    fun.(10)
  end
  
  def uses_capture do
    # Function capture creates runtime dependency
    Enum.map([1, 2, 3], &ModuleDepsD.function_in_d/1)
  end

  @foo ElixirLS.Test.ModuleDepsE.function_in_e("foo")
end
