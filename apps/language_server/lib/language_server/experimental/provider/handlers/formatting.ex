defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.Formatting do
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Format
  alias LSP.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  require Logger

  def handle(%Requests.Formatting{} = request, %Env{} = env) do
    document = request.source_file

    with {:ok, text_edits} <- Format.text_edits(document, env.project_path) do
      response = Responses.Formatting.new(request.id, text_edits)
      {:reply, response}
    else
      {:error, reason} ->
        Logger.error("Formatter failed #{inspect(reason)}")

        {:reply, Responses.Formatting.error(request.id, :request_failed, message(reason))}
    end
  end

  defp message(reason) when is_exception(reason) do
    Exception.message(reason)
  end

  defp message(reason) do
    inspect(reason)
  end
end
