defmodule ElixirSenseExample.FunctionsWithTheSameName do
  @doc "all?/2 docs"
  def all?(enumerable, fun \\ fn x -> x end) do
    IO.inspect({enumerable, fun})
  end

  @doc "concat/1 docs"
  def concat(enumerables) do
    IO.inspect(enumerables)
  end

  @doc "concat/2 docs"
  def concat(left, right) do
    IO.inspect({left, right})
  end
end
