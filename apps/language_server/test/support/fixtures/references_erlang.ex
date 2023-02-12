defmodule ElixirLS.Test.ReferencesErlang do
  def uses_fun do
    :ets.new(:my_table, [])
  end
end
