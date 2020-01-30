defmodule ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols do
  def some_function(a), do: a
  defmacro some_macro(a), do: Macro.expand(a, __CALLER__)

  @callback some_callback(integer) :: atom
  @callback some_macrocallback(integer) :: Macro.t()

  @type some_type :: atom
  @type some_opaque_type :: atom
end
