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

  def test_code_lens(uri, text, project_dir), do: CodeLens.Test.code_lens(uri, text, project_dir)

  def build_code_lens(line, title, command, argument) do
    %{
      # we don't care about utf16 positions here as we send 0
      "range" => range(line - 1, 0, line - 1, 0),
      "command" => %{
        "title" => title,
        "command" => command,
        "arguments" => [argument]
      }
    }
  end
end
