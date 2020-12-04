defmodule ElixirLS.LanguageServer.Providers.CodeLens do
  @moduledoc """
  Provides different code lenses to the client.

  Supports the following code lenses:
  * Suggestions for Dialyzer @spec definitions
  * Shortcuts for executing tests
  """

  alias ElixirLS.LanguageServer.Providers.CodeLens
  import ElixirLS.LanguageServer.Protocol

  def spec_code_lens(server_instance_id, uri, text),
    do: CodeLens.TypeSpec.code_lens(server_instance_id, uri, text)

  def test_code_lens(uri, text), do: CodeLens.Test.code_lens(uri, text)

  def build_code_lens(line, title, command, argument) do
    %{
      "range" => range(line - 1, 0, line - 1, 0),
      "command" => %{
        "title" => title,
        "command" => command,
        "arguments" => [argument]
      }
    }
  end
end
