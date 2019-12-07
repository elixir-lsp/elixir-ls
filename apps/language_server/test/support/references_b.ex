defmodule ElixirLS.Test.ReferencesB do
  def b_fun do
    some_var = 42

    IO.puts(some_var + 1)
    :ok
  end
end
