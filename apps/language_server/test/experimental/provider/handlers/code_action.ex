defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.CodeAction do
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.CodeAction
  ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore

  def handle(%CodeAction{} = request, %Env{}) do
    case ReplaceWithUnderscore.apply(reqest) do
      [] ->
        nil
    end
  end
end
