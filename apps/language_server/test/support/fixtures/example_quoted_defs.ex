defmodule ElixirLS.LanguageServer.Fixtures.ExampleQuotedDefs do
  @doc """
  quoted def
  """
  @spec unquote(:"0abc\"asd")(any, integer) :: :ok
  def unquote(:"0abc\"asd")(example, arg) do
    :ok
  end
end
