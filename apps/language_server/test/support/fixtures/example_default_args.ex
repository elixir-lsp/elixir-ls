defmodule ElixirLS.LanguageServer.Fixtures.ExampleDefaultArgs do
  def my_func(text, opts1 \\ [], opts2 \\ []) do
    IO.inspect({text, opts1, opts2})
  end

  def func_with_1_arg(text \\ "hi") do
    IO.inspect(text)
  end
end
