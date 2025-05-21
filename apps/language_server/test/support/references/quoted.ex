defmodule ElixirSenseExample.References.Quoted do
  def aaa, do: :ok
  defmacro bbb, do: :ok

  defmacro foo do
    quote do
      aaa()
      &aaa/0
      bbb()
      &bbb/0
      inspect(1)
      &inspect/1
      Node.list()
      &Node.list/0
    end
  end
end
