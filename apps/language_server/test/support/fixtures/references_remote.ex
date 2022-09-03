defmodule ElixirLS.Test.ReferencesRemote do
  require ElixirLS.Test.ReferencesReferenced, as: ReferencesReferenced

  def uses_fun do
    ReferencesReferenced.referenced_fun()
  end

  def uses_macro(a) do
    ReferencesReferenced.referenced_macro a do
      :ok
    end
  end
end
