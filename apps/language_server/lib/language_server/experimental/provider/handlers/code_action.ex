defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.CodeAction do
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceLocalFunction
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias LSP.Requests
  alias LSP.Responses

  require Logger

  @code_actions [ReplaceLocalFunction, ReplaceRemoteFunction, ReplaceWithUnderscore]

  def handle(%Requests.CodeAction{} = request, %Env{}) do
    code_actions =
      Enum.flat_map(@code_actions, fn code_action_module -> code_action_module.apply(request) end)

    reply = Responses.CodeAction.new(request.id, code_actions)

    {:reply, reply}
  end
end
