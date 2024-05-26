defmodule ElixirSenseExample.ModuleWithTypes do
  @type pub_type :: integer
  @typep priv_type :: integer
  @opaque opaque_type :: priv_type
  @callback some_callback(integer) :: atom
  @macrocallback some_macrocallback(integer) :: atom

  @spec some_fun_priv(integer) :: integer
  defp some_fun_priv(a), do: a + 1

  @spec some_fun(integer) :: integer
  def some_fun(a), do: some_fun_priv(a) + 1

  @spec some_macro_priv() :: Macro.t()
  defmacrop some_macro_priv(), do: :abc

  @spec some_macro(integer) :: Macro.t()
  defmacro some_macro(_a), do: some_macro_priv()
end
