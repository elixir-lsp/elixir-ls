defmodule ElixirLS.Test.ReferencesA do
  def a_fun do
    ElixirLS.Test.ReferencesB.b_fun()
  end
end
