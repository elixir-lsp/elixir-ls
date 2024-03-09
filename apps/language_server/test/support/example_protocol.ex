defprotocol ElixirSenseExample.ExampleProtocol do
  @spec some(t) :: any
  def some(t)
end

defimpl ElixirSenseExample.ExampleProtocol, for: List do
  def some(t), do: t
end

defimpl ElixirSenseExample.ExampleProtocol, for: Map do
  def some(t), do: t
end
