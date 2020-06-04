defmodule MixProject do
  def quadruple(x) do
    double(double(x))
  end

  def double(y) do
    2 * y
  end
end
