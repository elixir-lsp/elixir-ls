defmodule ElixirLS.LanguageServer.Fixtures.ExampleQuotedDefs do
  @doc """
  quoted def
  """
  @spec unquote(:"0abc\"asd")(any, integer) :: :ok
  def unquote(:"0abc\"asd")(_example, _arg) do
    :ok
  end
end
