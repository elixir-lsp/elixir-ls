defmodule Abc do
  def debug_me() do
    a = [1, 2, 3]
    b = Enum.map(a, &(&1 + 1))
    b
  end
end

a = [1, 2, 3]
b = Enum.map(a, &(&1 + 1))
IO.puts("done #{inspect(b)}, #{Abc.debug_me()}")

Task.start(fn ->
  Process.sleep(1000)
  IO.puts("done from task #{inspect(b)}, #{Abc.debug_me()}")
end)
