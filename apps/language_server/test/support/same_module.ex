defmodule ElixirSenseExample.SameModule do
  def test_fun(), do: :ok

  defmacro some_test_macro() do
    quote do
      @attr "val"
    end
  end
end
