defmodule MixProject.Crash do
  def fun_that_raises() do
    raise "foo"
  end
end
