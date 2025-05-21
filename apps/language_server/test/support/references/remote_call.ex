defmodule ElixirSenseExample.References.RemoteCall do
  def foo(), do: :ok
end

defmodule ElixirSenseExample.References.RemoteCallCaller do
  def abc() do
    ElixirSenseExample.References.RemoteCall.foo()
  end
end
