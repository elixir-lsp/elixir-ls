defmodule ElixirLS.LanguageServer.Fixtures.ExampleBehaviour do
  @callback greet_world() :: nil
  @callback build_greeting(name :: String.t()) :: String.t()
end

defmodule ElixirLS.LanguageServer.Fixtures.ExampleBehaviourImpl do
  @behaviour ElixirLS.LanguageServer.Fixtures.ExampleBehaviour

  @impl true
  def greet_world(), do: nil

  @impl true
  def build_greeting(name), do: name
end
