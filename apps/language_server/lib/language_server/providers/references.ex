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

  def references(text, uri, line, character, _include_declaration) do
    Build.with_build_lock(fn ->
      ElixirSense.references(text, line + 1, character + 1)
      |> Enum.map(fn elixir_sense_reference ->
        elixir_sense_reference
        |> build_reference(uri)
        |> build_loc()
      end)
      |> Enum.filter(&has_uri?/1)
    end)
  end

  defp build_reference(ref, current_file_uri) do
    %{
      range: %{
        start: %{line: ref.range.start.line, column: ref.range.start.column},
        end: %{line: ref.range.end.line, column: ref.range.end.column}
      },
      uri: build_uri(ref, current_file_uri)
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
      _ -> nil
    end
  end

  defp has_uri?(reference), do: !is_nil(reference["uri"])

  defp build_loc(reference) do
    # Adjust for ElixirSense 1-based indexing
    line_start = reference.range.start.line - 1
    line_end = reference.range.end.line - 1
    column_start = reference.range.start.column - 1
    column_end = reference.range.end.column - 1

    %{
      "uri" => reference.uri,
      "range" => %{
        "start" => %{"line" => line_start, "character" => column_start},
        "end" => %{"line" => line_end, "character" => column_end}
      }
    }
  end
end
