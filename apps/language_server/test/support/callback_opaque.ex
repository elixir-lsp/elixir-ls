defmodule ElixirSenseExample.CallbackOpaque do
  @moduledoc """
  Behaviour with opaque type in callback
  """

  @typedoc """
  Opaque type
  """
  @opaque t(x) :: {term, x}

  @doc """
  Does stuff to opaque arg
  """
  @callback do_stuff(t(a), term) :: t(a) when a: any
end
