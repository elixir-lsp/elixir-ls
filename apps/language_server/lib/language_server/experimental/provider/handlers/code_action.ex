defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.CodeAction do
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses

  require Logger

  @code_actions [ReplaceRemoteFunction, ReplaceWithUnderscore]

  def handle(%Requests.CodeAction{} = request, %Env{}) do
    code_actions =
      Enum.flat_map(@code_actions, fn code_action_module -> code_action_module.apply(request) end)

    reply = Responses.CodeAction.new(request.id, code_actions)

    {:reply, reply}
  end
end
