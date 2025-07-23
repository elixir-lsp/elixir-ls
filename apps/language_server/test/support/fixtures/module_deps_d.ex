defmodule ElixirLS.Test.ModuleDepsD do
  @moduledoc """
  Test module D for module dependency analysis.
  End of the dependency chain.
  """

  import ElixirLS.Test.ModuleDepsC, only: [function_in_c: 0]

  # Using struct from C creates compile-time dependency
  @default_struct %ElixirLS.Test.ModuleDepsC{field: "default"}

  def function_in_d(arg) do
    {:ok, arg}
  end

  def uses_module_attribute do
    @default_struct
  end

  def no_dependencies do
    # Pure function with no external dependencies
    fn x, y -> x + y end
  end

  def calls_kernel_functions do
    # These are auto-imported, not explicit dependencies
    length([1, 2, 3])
    hd([1, 2, 3])
    tl([1, 2, 3])
  end

  def uses_elixir_modules do
    # Standard library dependencies
    String.upcase("hello")
    Map.new([{:a, 1}, {:b, 2}])
    Keyword.get([a: 1], :a)
  end

  def calls_c_function do
    # Calls a function from ModuleDepsC
    function_in_c()
  end

  @foo function_in_c()
end
