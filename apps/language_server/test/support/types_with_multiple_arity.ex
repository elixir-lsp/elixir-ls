defmodule ElixirSenseExample.TypesWithMultipleArity do
  @typedoc "no params version"
  @type my_type :: integer
  @typedoc "one param version"
  @type my_type(a) :: {integer, a}
  @typedoc "two params version"
  @type my_type(a, b) :: {integer, a, b}
end

for i <- 1..1 do
  defmodule :"Elixir.ElixirSenseExample.TypesWithMultipleArity#{i}" do
    @typedoc "no params version"
    @type my_type :: integer
    @typedoc "one param version"
    @type my_type(a) :: {integer, a}
    @typedoc "two params version"
    @type my_type(a, b) :: {integer, a, b}
  end
end
