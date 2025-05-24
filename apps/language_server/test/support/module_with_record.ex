defmodule ElixirSenseExample.ModuleWithRecord do
  require Record
  @doc "user docs"
  @doc since: "1.0.0"
  Record.defrecord(:user, name: "john", age: 25)
  @type user :: record(:user, name: String.t(), age: integer)
end
