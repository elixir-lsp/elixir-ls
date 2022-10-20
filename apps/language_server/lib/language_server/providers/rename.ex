defmodule ElixirLS.LanguageServer.Providers.Rename do
  @moduledoc """
  Provides functionality to rename a symbol inside a workspace

  https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rename
  """

  alias ElixirLS.LanguageServer.SourceFile

  def rename(%SourceFile{} = source_file, start_uri, line, character, new_name) do
    edits =
      with %{context: {context, char_ident}} when context in [:local_or_var, :local_call] <-
             Code.Fragment.surround_context(source_file.text, {line, character}),
           %ElixirSense.Location{} = definition <-
             ElixirSense.definition(source_file.text, line, character),
           references <- ElixirSense.references(source_file.text, line, character) do
        length_old = length(char_ident)

        definition_references =
          case definition do
            %{type: :function} ->
              parse_definition_source_code(definition, source_file.text)
              |> get_all_fn_header_positions(char_ident)
              |> positions_to_references(start_uri, length_old)

            _ ->
              positions_to_references(
                [{definition.line, definition.column}],
                start_uri,
                length_old
              )
          end

        definition_references ++ repack_references(references, start_uri)
      else
        _ ->
          []
      end

    changes =
      edits
      |> Enum.group_by(& &1.uri)
      |> Enum.map(fn {uri, edits} ->
        %{
          "textDocument" => %{
            "uri" => uri,
            "version" => source_file.version + 1
          },
          "edits" =>
            Enum.map(edits, fn edit ->
              %{"range" => edit.range, "newText" => new_name}
            end)
        }
      end)

    {:ok, %{"documentChanges" => changes}}
  end

  def prepare(%SourceFile{} = source_file, _uri, line, character) do
    result =
      with %{
             begin: {start_line, start_col},
             end: {end_line, end_col},
             context: {context, char_ident}
           }
           when context in [:local_or_var, :local_call] <-
             Code.Fragment.surround_context(source_file.text, {line, character}) do
        %{
          range: adjust_range(start_line, start_col, end_line, end_col),
          placeholder: to_string(char_ident)
        }
      else
        _ ->
          # Not a variable or local call, skipping for now
          nil
      end

    {:ok, result}
  end

  defp repack_references(references, uri) do
    for reference <- references do
      %{
        uri: uri,
        range: %{
          end: %{character: reference.range.end.column - 1, line: reference.range.end.line - 1},
          start: %{
            character: reference.range.start.column - 1,
            line: reference.range.start.line - 1
          }
        }
      }
    end
  end

  defp parse_definition_source_code(definition, source_text)

  defp parse_definition_source_code(%{file: nil}, source_text) do
    ElixirSense.Core.Parser.parse_string(source_text, true, true, 0)
  end

  defp parse_definition_source_code(%{file: file}, _) do
    ElixirSense.Core.Parser.parse_file(file, true, true, 0)
  end

  defp get_all_fn_header_positions(parsed_source, char_ident) do
    parsed_source.mods_funs_to_positions
    |> Map.filter(fn
      {{_, fn_name, _}, _} -> Atom.to_charlist(fn_name) == char_ident
    end)
    |> Enum.flat_map(fn {_, %{positions: positions}} -> positions end)
    |> Enum.uniq()
  end

  defp positions_to_references(header_positions, start_uri, length_old)
       when is_list(header_positions) do
    header_positions
    |> Enum.map(fn {line, column} ->
      %{
        uri: start_uri,
        range: adjust_range(line, column, line, column + length_old)
      }
    end)
  end

  defp adjust_range(start_line, start_character, end_line, end_character) do
    %{
      start: %{line: start_line - 1, character: start_character - 1},
      end: %{line: end_line - 1, character: end_character - 1}
    }
  end
end
