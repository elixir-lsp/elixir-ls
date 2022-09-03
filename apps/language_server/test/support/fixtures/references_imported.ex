defmodule ElixirLS.Test.ReferencesImported do
  import ElixirLS.Test.ReferencesReferenced

  def a_fun do
    b_fun()
  end

  def b_fun(a) do
    macro_unless a do
      :ok
    end
  end
end
