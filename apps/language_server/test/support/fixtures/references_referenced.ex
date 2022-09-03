defmodule ElixirLS.Test.ReferencesReferenced do
  def b_fun do
    some_var = 42

    IO.puts(some_var + 1)
    :ok
  end

  defmacro macro_unless(clause, do: expression) do
    quote do
      if(!unquote(clause), do: unquote(expression))
    end
  end

  def local(a) do
    macro_unless a do
      b_fun
    end
  end

  @some "123"

  def use_attribute do
    @some
  end
end
