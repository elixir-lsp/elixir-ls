defmodule ElixirLS.LanguageServer.Fixtures.TokenMissingError.HasError do
  def my_fn1 do
    "no problem here"
  end

  def my_fn2 do
    for i <- 1..100 do
      i + 1
    # missing terminator: end
  end

  def my_fn3 do
    :ok_too
  end
end
