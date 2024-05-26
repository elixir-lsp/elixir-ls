defmodule ElixirSenseExample.Subscriber do
  def some do
    ElixirSenseExample.Subscription.check("user", [:a, :b], :c)
    ElixirSenseExample.Subscription.check("user", [:a, :b], :c, :s)
  end
end
