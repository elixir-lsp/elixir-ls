defmodule ElixirLS.LanguageServer.Providers.CodeLens.Test.TestBlock do
  @struct_keys [:name, :describe, :line, :module]

  @enforce_keys @struct_keys
  defstruct @struct_keys
end
