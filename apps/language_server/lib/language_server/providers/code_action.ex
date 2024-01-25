defmodule ElixirLS.LanguageServer.Providers.CodeAction do
  alias ElixirLS.LanguageServer.Providers.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.Providers.CodeAction.ReplaceWithUnderscore

  @code_actions [ReplaceRemoteFunction, ReplaceWithUnderscore]

  def code_actions(source_file, uri, diagnostic) do
    code_actions = Enum.flat_map(@code_actions, & &1.apply(source_file, uri, diagnostic))

    {:ok, code_actions}
  end
end
