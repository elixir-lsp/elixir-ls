defmodule ElixirLS.LanguageServer.Fixtures.ExampleDocs do
  @doc """
  The summary

  Ths rest
  """
  @spec add(a_big_name :: integer, b_big_name :: integer) :: integer
  def add(a, b) do
    a + b
  end
end
