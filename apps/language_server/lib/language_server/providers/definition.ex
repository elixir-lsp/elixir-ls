defmodule ElixirLS.LanguageServer.Providers.Definition do
  @moduledoc """
  Go-to-definition provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.Protocol

  def definition(uri, text, line, character) do
    result =
      case ElixirSense.definition(text, line + 1, character + 1) do
        nil ->
          nil

        %ElixirSense.Location{} = location ->
          Protocol.Location.new(location, uri)
      end

    {:ok, result}
  end
end
