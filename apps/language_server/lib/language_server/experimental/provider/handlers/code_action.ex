defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.CodeAction do
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore

  require Logger

  def handle(%Requests.CodeAction{} = request, %Env{}) do
    code_actions = ReplaceWithUnderscore.apply(request)
    reply = Responses.CodeAction.new(request.id, code_actions)

    {:reply, reply}
  end
end
