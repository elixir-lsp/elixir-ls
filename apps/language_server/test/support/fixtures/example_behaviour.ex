defmodule ElixirLS.LanguageServer.Fixtures.ExampleBehaviour do
  @callback greet_world() :: nil
  @callback build_greeting(name :: String.t()) :: String.t()
end
