defmodule ElixirSenseExample.FunctionsWithDefaultArgs do
  @doc "no params version"
  @spec my_func :: binary
  def my_func, do: "not this one"

  @doc "2 params version"
  @spec my_func(1 | 2) :: binary
  @spec my_func(1 | 2, binary) :: binary
  def my_func(a, b \\ "")
  def my_func(1, b), do: "1" <> b
  def my_func(2, b), do: "2" <> b

  @doc "3 params version"
  @spec my_func(1, 2, 3) :: :ok
  def my_func(1, 2, 3), do: :ok

  @spec my_func(2, 2, 3) :: :error
  def my_func(2, 2, 3), do: :error
end

for i <- 1..1 do
  defmodule :"Elixir.ElixirSenseExample.FunctionsWithDefaultArgs#{i}" do
    @moduledoc "example module"

    @doc "no params version"
    @spec my_func :: binary
    def my_func, do: "not this one"

    @doc "2 params version"
    @spec my_func(1 | 2) :: binary
    @spec my_func(1 | 2, binary) :: binary
    def my_func(a, b \\ "")
    def my_func(1, b), do: "1" <> b
    def my_func(2, b), do: "2" <> b

    @doc "3 params version"
    @spec my_func(1, 2, 3) :: :ok
    def my_func(1, 2, 3), do: :ok

    @spec my_func(2, 2, 3) :: :error
    def my_func(2, 2, 3), do: :error
  end
end

defmodule ElixirSenseExample.FunctionsWithDefaultArgsCaller do
  alias ElixirSenseExample.FunctionsWithDefaultArgs, as: F

  def go() do
    F.my_func()
    F.my_func(1)
    F.my_func(1, "a")
    F.my_func(1, 2, 3)
  end
end
