defprotocol ElixirLS.LanguageServer.Fixtures.ExampleProtocol do
  @moduledoc """
  ExampleProtocol protocol used in tests.
  """

  @doc """
  Does what `my_fun` does for `t`
  """
  @spec my_fun(t, integer) :: binary
  def my_fun(example, arg)
end
