defmodule ElixirSenseExample.ModuleWithBuiltinTypeShadowing do
  @compile {:no_warn_undefined, {B.Callee, :fun, 0}}
  def plain_fun do
    B.Callee.fun()
  end
end
