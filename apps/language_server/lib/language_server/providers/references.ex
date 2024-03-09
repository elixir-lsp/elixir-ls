defmodule ElixirLS.LanguageServer.Providers.References do
  @moduledoc """
  This module provides textDocument/references support. Currently its able to find references to
  functions, macros, variables and module attributes

  Does not support configuring "includeDeclaration" and assumes it is always
  `true`

  https://microsoft.github.io//language-server-protocol/specifications/specification-3-14/#textDocument_references
  """

  alias ElixirLS.LanguageServer.{SourceFile, Build, Parser}
  import ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.Providers.References.Locator
  require Logger

  def references(
        %Parser.Context{source_file: source_file, metadata: metadata},
        uri,
        line,
        character,
        _include_declaration,
        project_dir
      ) do
    Build.with_build_lock(fn ->
      trace = ElixirLS.LanguageServer.Tracer.get_trace()

      Locator.references(source_file.text, line, character, trace, metadata: metadata)
      |> Enum.map(fn elixir_sense_reference ->
        elixir_sense_reference
        |> build_reference(uri, source_file.text, project_dir)
      end)
      |> Enum.filter(&(not is_nil(&1)))
      # Returned references come from both compile tracer and current buffer
      # There may be duplicates
      |> Enum.uniq()
    end)
  end

  defp build_reference(ref, current_file_uri, current_file_text, project_dir) do
    case get_text(ref, current_file_text) do
      {:ok, text} ->
        {start_line, start_column} =
          SourceFile.elixir_position_to_lsp(text, {ref.range.start.line, ref.range.start.column})

        {end_line, end_column} =
          SourceFile.elixir_position_to_lsp(text, {ref.range.end.line, ref.range.end.column})

        range = range(start_line, start_column, end_line, end_column)

        %{
          "range" => range,
          "uri" => build_uri(ref, current_file_uri, project_dir)
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

  def build_uri(elixir_sense_ref, current_file_uri, project_dir) do
    case elixir_sense_ref.uri do
      # A `nil` uri indicates that the reference was in the passed in text
      # https://github.com/elixir-lsp/elixir-ls/pull/82#discussion_r351922803
      nil -> current_file_uri
      # ElixirSense returns a plain path (e.g. "/home/bob/my_app/lib/a.ex") as
      # the "uri" so we convert it to an actual uri
      path when is_binary(path) -> SourceFile.Path.to_uri(path, project_dir)
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
