defmodule ElixirLS.Test.ReferencesRemote do
  require ElixirLS.Test.ReferencesReferenced, as: ReferencesReferenced

  def a_fun do
    ReferencesReferenced.b_fun()
  end

  def b_fun(a) do
    ReferencesReferenced.macro_unless a do
      :ok
    end
  end
end
