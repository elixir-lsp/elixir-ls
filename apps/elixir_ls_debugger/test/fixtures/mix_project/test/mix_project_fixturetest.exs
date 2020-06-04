defmodule MixProjectTest do
  use ExUnit.Case
  doctest MixProject

  test "double" do
    assert MixProject.double(2) == 4
  end

  test "quadruple" do
    assert MixProject.quadruple(2) == 8
  end
end
