defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Convert do
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  def to_elixir(%{text_document: _} = request) do
    with {:ok, source_file} <- fetch_source_file(request.lsp),
         {:ok, updates} <- convert(request.lsp, source_file) do
      updated_request =
        request
        |> Map.put(:source_file, source_file)
        |> Map.merge(updates)

      {:ok, updated_request}
    end
  end

  def to_elixir(request) do
    request = Map.merge(request, Map.from_struct(request.lsp))

    {:ok, request}
  end

  defp fetch_source_file(%{text_document: %{uri: uri}}) do
    SourceFile.Store.fetch(uri)
  end

  defp fetch_source_file(%{source_file: %SourceFile{} = source_file}) do
    {:ok, source_file}
  end

  defp fetch_source_file(_) do
    :error
  end

  defp convert(%{range: range}, source_file) do
    with {:ok, ex_range} <- Conversions.to_elixir(range, source_file) do
      {:ok, %{range: ex_range}}
    end
  end

  defp convert(%{position: position}, source_file) do
    with {:ok, ex_pos} <- Conversions.to_elixir(position, source_file) do
      {:ok, %{position: ex_pos}}
    end
  end

  defp convert(_, _) do
    {:ok, %{}}
  end
end
