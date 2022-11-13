defmodule ElixirLS.LanguageServer.Providers.Rename do
  @moduledoc """
  Provides functionality to rename a symbol inside a workspace

  https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rename
  """

  alias ElixirLS.LanguageServer.SourceFile

  def rename(%SourceFile{} = source_file, start_uri, line, character, new_name) do
    edits =
      with char_ident when not is_nil(char_ident) <-
             get_char_ident(source_file.text, line, character),
           %ElixirSense.Location{} = definition <-
             ElixirSense.definition(source_file.text, line, character),
           references <- ElixirSense.references(source_file.text, line, character) do
        length_old = length(char_ident)

        definition_references =
          case definition do
            %{file: nil, type: :function} ->
              parse_definition_source_code(source_file.text)
              |> get_all_fn_header_positions(char_ident)
              |> positions_to_references(start_uri, length_old)

            %{file: separate_file_path, type: :function} ->
              parse_definition_source_code(definition)
              |> get_all_fn_header_positions(char_ident)
              |> positions_to_references(SourceFile.path_to_uri(separate_file_path), length_old)

            _ ->
              positions_to_references(
                [{definition.line, definition.column}],
                start_uri,
                length_old
              )
          end

        Enum.uniq(definition_references ++ repack_references(references, start_uri))
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
            "version" => nil
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
             char_ident: char_ident
           } = res
           when not is_nil(res) <-
             get_begin_end_and_char_ident(source_file.text, line, character) do
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

  defp repack_references(references, start_uri) do
    for reference <- references do
      uri = if reference.uri, do: SourceFile.path_to_uri(reference.uri), else: start_uri

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

  defp parse_definition_source_code(%{file: file}) do
    ElixirSense.Core.Parser.parse_file(file, true, true, nil)
  end

  defp parse_definition_source_code(source_text) when is_binary(source_text) do
    ElixirSense.Core.Parser.parse_string(source_text, true, true, nil)
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

  defp get_char_ident(text, line, character) do
    case Code.Fragment.surround_context(text, {line, character}) do
      %{context: {context, char_ident}} when context in [:local_or_var, :local_call] -> char_ident
      %{context: {:dot, _, char_ident}} -> char_ident
      _ -> nil
    end
  end

  defp get_begin_end_and_char_ident(text, line, character) do
    case Code.Fragment.surround_context(text, {line, character}) do
      %{begin: begin, end: the_end, context: {context, char_ident}}
      when context in [:local_or_var, :local_call] ->
        %{begin: begin, end: the_end, char_ident: char_ident}

      %{begin: begin, end: the_end, context: {:dot, _, char_ident}} ->
        %{begin: begin, end: the_end, char_ident: char_ident}

      _ ->
        nil
    end
  end
end
