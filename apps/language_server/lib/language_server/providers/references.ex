defmodule ElixirLS.LanguageServer.Providers.References do
  @moduledoc """
  This module provides References support by using `ElixirSense.references/3` to
  find all references to any function or module identified at the provided
  location.

  Does not support configuring "includeDeclaration" and assumes it is always
  `true`

  https://microsoft.github.io//language-server-protocol/specifications/specification-3-14/#textDocument_references
  """

  alias ElixirLS.LanguageServer.{SourceFile, Build}
  import ElixirLS.LanguageServer.Protocol
  require Logger

  def references(text, uri, line, character, _include_declaration) do
    {line, character} = SourceFile.lsp_position_to_elixir(text, {line, character})

    Build.with_build_lock(fn ->
      trace = ElixirLS.LanguageServer.Tracer.get_trace()

      ElixirSense.references(text, line, character, trace)
      |> Enum.map(fn elixir_sense_reference ->
        elixir_sense_reference
        |> build_reference(uri, text)
      end)
      |> Enum.filter(&(not is_nil(&1)))
      # ElixirSense returns references from both compile tracer and current buffer
      # There may be duplicates
      |> Enum.uniq()
    end)
  end

  defp build_reference(ref, current_file_uri, current_file_text) do
    case get_text(ref, current_file_text) do
      {:ok, text} ->
        {start_line, start_column} =
          SourceFile.elixir_position_to_lsp(text, {ref.range.start.line, ref.range.start.column})

        {end_line, end_column} =
          SourceFile.elixir_position_to_lsp(text, {ref.range.end.line, ref.range.end.column})

        range = range(start_line, start_column, end_line, end_column)

        %{
          "range" => range,
          "uri" => build_uri(ref, current_file_uri)
        }

      {:error, :nofile} ->
        Logger.debug("Skipping reference from `nofile`")
        nil

      {:error, reason} ->
        # workaround for elixir tracer returning invalid paths
        # https://github.com/elixir-lang/elixir/issues/12393
        Logger.warning("Unable to open reference from #{inspect(ref.uri)}: #{inspect(reason)}")
        nil
    end
  end

  def build_uri(elixir_sense_ref, current_file_uri) do
    case elixir_sense_ref.uri do
      # A `nil` uri indicates that the reference was in the passed in text
      # https://github.com/elixir-lsp/elixir-ls/pull/82#discussion_r351922803
      nil -> current_file_uri
      # ElixirSense returns a plain path (e.g. "/home/bob/my_app/lib/a.ex") as
      # the "uri" so we convert it to an actual uri
      path when is_binary(path) -> SourceFile.Path.to_uri(path)
    end
  end

  def get_text(elixir_sense_ref, current_file_text) do
    case elixir_sense_ref.uri do
      nil -> {:ok, current_file_text}
      "nofile" -> {:error, :nofile}
      path when is_binary(path) -> File.read(path)
    end
  end
end
