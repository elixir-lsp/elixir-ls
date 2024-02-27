defmodule ElixirSenseExample.DummyBehaviour do
  @callback foo() :: any
end

defmodule ElixirSenseExample.DummyBehaviourImplementation do
  @behaviour ElixirSenseExample.DummyBehaviour
  def foo(), do: :ok
end
