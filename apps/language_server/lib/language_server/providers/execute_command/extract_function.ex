defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExtractFunction do
  @moduledoc """
  This module implements a custom command extract function.
  Sends applyEdit request.
  """

  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ExtractFunction.CodeModExtractFunction
  alias ElixirLS.LanguageServer.Server

  alias VendoredSourceror.Zipper

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri, start_line, end_line, new_function_name], state) do
    with source_file <- Server.get_source_file(state, uri),
         {:ok, tree} <- VendoredSourceror.parse_string(source_file.text),
         {:ok, text_edits} <-
           text_edits(source_file.text, tree, start_line, end_line, new_function_name) do
      apply_edits(uri, text_edits)
      {:ok, nil}
    end
  end

  def apply_edits(uri, text_edits) do
    JsonRpc.send_request("workspace/applyEdit", %{
      "label" => "Extract function",
      "edit" => %{"changes" => %{uri => text_edits}}
    })
    |> IO.inspect(label: :rpc_response, limit: :infinity)
  end

  def text_edits(original_text, tree, start_line, end_line, new_function_name) do
    result =
      tree
      |> Zipper.zip()
      |> CodeModExtractFunction.extract_function(start_line + 1, end_line + 1, new_function_name)
      |> VendoredSourceror.to_string()

    {:ok, Diff.diff(original_text, result)}
  end
end
