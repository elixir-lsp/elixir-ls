defmodule ElixirLS.Test.ReferencesReferenced do
  def referenced_fun do
    referenced_variable = 42

    IO.puts(referenced_variable + 1)
    :ok
  end

  defmacro referenced_macro(clause, do: expression) do
    quote do
      if(!unquote(clause), do: unquote(expression))
    end
  end

  def uses_fun(a) do
    referenced_fun
  end

  def uses_macro(a) do
    referenced_macro a do
      :ok
    end
  end

  @referenced_attribute "123"

  def uses_attribute do
    @referenced_attribute
  end
end
