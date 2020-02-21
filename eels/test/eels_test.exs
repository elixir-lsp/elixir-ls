defmodule EelsTest do
  use ExUnit.Case
  doctest Eels

  test "greets the world" do
    assert Eels.hello() == :world
  end
end
