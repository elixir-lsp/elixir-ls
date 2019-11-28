defmodule ElixirLS.LanguageServer.Providers.References do
  @moduledoc """
  This module provides References support by using `ElixirSense.references/3` to
  find all references to any function or module identified at the provided
  location.
  """
  require Logger

  alias ElixirLS.LanguageServer.{SourceFile, Build}

  def references(text, line, character, _include_declaration) do
    Build.with_build_lock(fn ->
      ElixirSense.references(text, line + 1, character + 1)
      |> Enum.map(&build_reference/1)
      |> Enum.map(&build_loc/1)
    end)
  end

  def supported? do
    Mix.Tasks.Xref.__info__(:functions) |> Enum.member?({:calls, 0})
  end

  defp build_reference(ref) do
    %{
      range: %{
        start: %{line: ref.range.start.line, column: ref.range.start.column},
        end: %{line: ref.range.end.line, column: ref.range.end.column}
      },
      uri: ref.uri
    }
  end

  defp build_loc(reference) do
    # Adjust for ElixirSense 1-based indexing
    line_start = reference.range.start.line - 1
    line_end = reference.range.end.line - 1
    column_start = reference.range.start.column - 1
    column_end = reference.range.end.column - 1

    %{
      "uri" => SourceFile.path_to_uri(reference.uri),
      "range" => %{
        "start" => %{"line" => line_start, "character" => column_start},
        "end" => %{"line" => line_end, "character" => column_end}
      }
    }
  end
end
