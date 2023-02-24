defmodule ElixirLS.LanguageServer.Experimental.Provider.Handlers.Hover do
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Hover, as: LSHover
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Hover
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  require Logger

  def handle(%Requests.Hover{} = request, %Env{} = env) do
    source_file = request.source_file
    pos = request.position

    elixir_sense_hover =
      source_file
      |> SourceFile.to_string()
      |> ElixirSense.docs(pos.line, pos.character + 1)

    case to_response(request, elixir_sense_hover, env.project_path) do
      {:ok, response} ->
        {:reply, response}

      :error ->
        Logger.error("Hover conversion failed")
        {:reply, Responses.Hover.error(request.id, :hover_failed, "")}
    end
  end

  defp to_response(request, %{subject: ""}, _project_path) do
    {:ok, Responses.Hover.new(request.id, nil)}
  end

  defp to_response(request, elixir_sense_hover, project_path) do
    with {:ok, line_text} <- fetch_line_text(request.source_file, request.position.line) do
      range =
        Hover.highlight_range(
          line_text,
          request.position.line,
          request.position.character - 1,
          elixir_sense_hover.subject,
          request.source_file
        )

      %{docs: docs, actual_subject: actual_subject} = elixir_sense_hover
      contents = Hover.contents(docs, actual_subject, project_path)

      {:ok, Responses.Hover.new(request.id, %LSHover{contents: contents, range: range})}
    end
  end

  defp fetch_line_text(source_file, line) do
    with {:ok, {:line, line_text, _, _, _}} <- SourceFile.fetch_line_at(source_file, line) do
      {:ok, line_text}
    end
  end
end
