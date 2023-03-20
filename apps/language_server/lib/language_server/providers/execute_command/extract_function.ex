defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExtractFunction do
  @moduledoc """
  This module implements a custom command extract function.
  Sends applyEdit request.
  """

  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Server
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast
  alias ElixirLS.LanguageServer.Experimental.CodeMod.RefactorExtractFunction

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri, start_line, end_line, new_function_name], state) do
    with source_file <- Server.get_source_file(state, uri),
         {:ok, tree} <- Ast.from(source_file.text, include_comments: true),
         {:ok, text_edits} <-
           RefactorExtractFunction.text_edits(
             source_file.text,
             tree,
             start_line,
             end_line,
             new_function_name
           ) do
      apply_edits(uri, text_edits)
      {:ok, nil}
    end
  end

  def apply_edits(uri, text_edits) do
    JsonRpc.send_request("workspace/applyEdit", %{
      "label" => "Extract function",
      "edit" => %{"changes" => %{uri => text_edits}}
    }) |> IO.inspect(label: :rpc_response, limit: :infinity)
  end
end
