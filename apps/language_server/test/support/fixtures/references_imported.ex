defmodule ElixirLS.Test.ReferencesImported do
  import ElixirLS.Test.ReferencesReferenced

  def uses_fun do
    referenced_fun()
  end

  def uses_macro(a) do
    referenced_macro a do
      :ok
    end
  end
end
