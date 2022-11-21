defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Convert do
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  def to_elixir(%{lsp: lsp_request} = request) do
    with {:ok, elixir_request, source_file} <- convert(lsp_request) do
      updated_request =
        case Map.merge(request, Map.from_struct(elixir_request)) do
          %_{source_file: _} = updated -> Map.put(updated, :source_file, source_file)
          updated -> updated
        end

      {:ok, updated_request}
    end
  end

  def to_elixir(%_request_module{lsp: lsp_request} = request) do
    converted = Map.merge(request, Map.from_struct(lsp_request))
    {:ok, converted}
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

  defp convert(%_{text_document: _} = request) do
    with {:ok, source_file} <- fetch_source_file(request),
         {:ok, converted} <- convert(request, source_file) do
      {:ok, converted, source_file}
    end
  end

  defp convert(%_{} = request) do
    {:ok, request, nil}
  end

  defp convert(%Types.Range{} = range, %SourceFile{} = source_file) do
    Conversions.to_elixir(range, source_file)
  end

  defp convert(%Types.Position{} = pos, %SourceFile{} = source_file) do
    Conversions.to_elixir(pos, source_file)
  end

  defp convert(%_struct{} = request, %SourceFile{} = source_file) do
    kvps =
      request
      |> Map.from_struct()
      |> Enum.reduce(request, fn {key, value}, request ->
        {:ok, value} = convert(value, source_file)
        Map.put(request, key, value)
      end)

    {:ok, Map.merge(request, kvps)}
  end

  defp convert(list, %SourceFile{} = source_file) when is_list(list) do
    items =
      Enum.map(list, fn item ->
        {:ok, item} = convert(item, source_file)
        item
      end)

    {:ok, items}
  end

  defp convert(%{} = map, %SourceFile{} = source_file) do
    converted =
      Map.new(map, fn {k, v} ->
        {:ok, converted} = convert(v, source_file)
        {k, converted}
      end)

    {:ok, converted}
  end

  defp convert(item, %SourceFile{} = _) do
    {:ok, item}
  end
end
