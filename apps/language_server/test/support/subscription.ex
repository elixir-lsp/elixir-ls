defmodule ElixirSenseExample.Subscription do
  def check(resource, models, user, opts \\ [])

  def check(nil, models, user, opts) do
    IO.inspect({nil, models, user, opts})
  end

  def check(resource, models, user, opts) do
    IO.inspect({resource, models, user, opts})
  end
end
