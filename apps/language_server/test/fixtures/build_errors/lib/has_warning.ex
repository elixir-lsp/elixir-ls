defmodule ElixirLS.LanguageServer.Fixtures.BuildErrors.HasError do

  # Should cause an unused variable warning
  def my_fn(unused) do
    :ok
  end
end