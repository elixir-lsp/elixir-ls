defmodule ElixirLS.LanguageServer.Providers.CodeLens do
  @moduledoc """
  Collects the success typings inferred by Dialyzer, translates the syntax to Elixir, and shows them
  inline in the editor as @spec suggestions.

  The server, unfortunately, has no way to force the client to refresh the @spec code lenses when new
  success typings, so we let this request block until we know we have up-to-date results from
  Dialyzer. We rely on the client being able to await this result while still making other requests
  in parallel. If the client is unable to perform requests in parallel, the client or user should
  disable this feature.
  """

  alias ElixirLS.LanguageServer.Providers.CodeLens
  import ElixirLS.LanguageServer.Protocol

  def spec_code_lens(server_instance_id, uri, text),
    do: CodeLens.Spec.code_lens(server_instance_id, uri, text)

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
