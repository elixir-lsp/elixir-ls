defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.CodeAction do
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceRemoteFunction
  alias ElixirLS.LanguageServer.Experimental.Provider.CodeAction.ReplaceWithUnderscore
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses

  require Logger

  def handle(%Requests.CodeAction{} = request, %Env{}) do
    source_file = request.source_file
    diagnostics = get_in(request, [:context, :diagnostics]) || []

    code_actions =
      Enum.flat_map(diagnostics, fn %{message: message} = diagnostic ->
        cond do
          String.match?(message, ReplaceRemoteFunction.pattern()) ->
            ReplaceRemoteFunction.apply(source_file, diagnostic)

          String.match?(message, ReplaceWithUnderscore.pattern()) ->
            ReplaceWithUnderscore.apply(source_file, diagnostic)

          true ->
            []
        end
      end)

    reply = Responses.CodeAction.new(request.id, code_actions)

    {:reply, reply}
  end
end
