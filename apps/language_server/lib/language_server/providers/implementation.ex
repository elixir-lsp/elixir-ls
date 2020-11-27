defmodule ElixirLS.LanguageServer.Providers.Implementation do
  @moduledoc """
  Go-to-implementation provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.Protocol

  def implementation(uri, text, line, character) do
    locations = ElixirSense.implementations(text, line + 1, character + 1)
    results = for location <- locations, do: Protocol.Location.new(location, uri)

    {:ok, results}
  end
end
