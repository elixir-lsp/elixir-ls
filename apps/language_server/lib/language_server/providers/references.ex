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

  def references(text, uri, line, character, _include_declaration) do
    {line, character} = SourceFile.lsp_position_to_elixr(text, {line, character})

    Build.with_build_lock(fn ->
      ElixirSense.references(text, line, character)
      |> Enum.map(fn elixir_sense_reference ->
        elixir_sense_reference
        |> build_reference(uri, text)
      end)
    end)
  end

  defp build_reference(ref, current_file_uri, current_file_text) do
    text = get_text(ref, current_file_text)

    {start_line, start_column} =
      SourceFile.elixir_position_to_lsp(text, {ref.range.start.line, ref.range.start.column})

    {end_line, end_column} =
      SourceFile.elixir_position_to_lsp(text, {ref.range.end.line, ref.range.end.column})

    range = range(start_line, start_column, end_line, end_column)

    %{
      "range" => range,
      "uri" => build_uri(ref, current_file_uri)
    }
  end

  def build_uri(elixir_sense_ref, current_file_uri) do
    case elixir_sense_ref.uri do
      # A `nil` uri indicates that the reference was in the passed in text
      # https://github.com/elixir-lsp/elixir-ls/pull/82#discussion_r351922803
      nil -> current_file_uri
      # ElixirSense returns a plain path (e.g. "/home/bob/my_app/lib/a.ex") as
      # the "uri" so we convert it to an actual uri
      path when is_binary(path) -> SourceFile.path_to_uri(path)
    end
  end

  def get_text(elixir_sense_ref, current_file_text) do
    case elixir_sense_ref.uri do
      nil -> current_file_text
      path when is_binary(path) -> File.read!(path)
    end
  end
end
