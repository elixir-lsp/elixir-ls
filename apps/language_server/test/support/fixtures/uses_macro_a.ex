defmodule ElixirLS.Test.UsesMacroA do
  use ElixirLS.Test.MacroA

  @inputs [1, 2, 3]

  def my_fun do
    macro_a_func()
  end

  def my_other_fun do
    macro_imported_fun()
  end

  for input <- @inputs do
    def gen_fun(unquote(input)) do
      unquote(input) + 1
    end
  end
end
