defmodule ElixirLS.LanguageServer.Providers.References do
  @moduledoc """
  This module provides textDocument/references support. Currently its able to find references to
  functions, macros, variables and module attributes

  Supports configuring "includeDeclaration" as defined by the LSP.

  https://microsoft.github.io//language-server-protocol/specifications/specification-3-14/#textDocument_references
  """

  alias ElixirLS.LanguageServer.{SourceFile, Build, Parser}
  alias ElixirLS.LanguageServer.Providers.References.Locator
  require Logger

  alias ElixirLS.LanguageServer.Providers.{Definition, Declaration}

  def references(
        parser_context = %Parser.Context{source_file: source_file, metadata: metadata},
        uri,
        line,
        character,
        include_declaration,
        project_dir
      ) do
    Build.with_build_lock(fn ->
      trace = ElixirLS.LanguageServer.Tracer.get_trace()

      base_refs =
        Locator.references(source_file.text, line, character, trace, metadata: metadata)
        |> Enum.map(fn elixir_sense_reference ->
          elixir_sense_reference
          |> build_reference(uri, source_file.text, project_dir)
        end)
        |> Enum.filter(&(not is_nil(&1)))

      {definition_locations, declaration_locations} =
        definition_and_declaration_locations(uri, parser_context, line, character, project_dir)

      references =
        if include_declaration do
          base_refs ++ definition_locations ++ declaration_locations
        else
          locations_to_exclude = MapSet.new(definition_locations ++ declaration_locations)
          Enum.reject(base_refs, fn ref -> ref in locations_to_exclude end)
        end
        |> Enum.uniq()

      references
    end)
  end

  defp definition_and_declaration_locations(uri, parser_context, line, character, project_dir) do
    definition_locations =
      case Definition.definition(uri, parser_context, line, character, project_dir) do
        {:ok, def_loc} -> List.wrap(def_loc || [])
        _ -> []
      end

    declaration_locations =
      case Declaration.declaration(uri, parser_context, line, character, project_dir) do
        {:ok, decl_loc} -> List.wrap(decl_loc || [])
        _ -> []
      end

    {definition_locations, declaration_locations}
  end

  defp build_reference(ref, current_file_uri, current_file_text, project_dir) do
    case get_text(ref, current_file_text) do
      {:ok, text} ->
        {start_line, start_column} =
          SourceFile.elixir_position_to_lsp(text, {ref.range.start.line, ref.range.start.column})

        {end_line, end_column} =
          SourceFile.elixir_position_to_lsp(text, {ref.range.end.line, ref.range.end.column})

        uri = build_uri(ref, current_file_uri, project_dir)

        %GenLSP.Structures.Location{
          uri: uri,
          range: %GenLSP.Structures.Range{
            start: %GenLSP.Structures.Position{line: start_line, character: start_column},
            end: %GenLSP.Structures.Position{line: end_line, character: end_column}
          }
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
