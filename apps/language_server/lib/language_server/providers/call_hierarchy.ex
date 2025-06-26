defmodule ElixirLS.LanguageServer.Providers.CallHierarchy do
  @moduledoc """
  This module provides textDocument/prepareCallHierarchy, 
  callHierarchy/incomingCalls and callHierarchy/outgoingCalls support.

  It enables finding all callers and callees of functions using the language server's
  tracer and metadata.

  https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_prepareCallHierarchy
  """

  alias ElixirLS.LanguageServer.{SourceFile, Build, Parser}
  alias ElixirLS.LanguageServer.Providers.CallHierarchy.Locator
  require Logger

  def prepare(
        %Parser.Context{source_file: source_file, metadata: metadata},
        uri,
        line,
        character,
        project_dir
      ) do
    Build.with_build_lock(fn ->
      trace = ElixirLS.LanguageServer.Tracer.get_trace()

      case Locator.prepare(source_file.text, line, character, trace, metadata: metadata) do
        nil ->
          nil

        call_hierarchy_item ->
          # The LSP spec expects a list of CallHierarchyItem or null
          [convert_to_lsp_item(call_hierarchy_item, uri, source_file.text, project_dir)]
      end
    end)
  end

  def incoming_calls(
        uri,
        name,
        kind,
        line,
        character,
        project_dir,
        source_file,
        parser_context
      ) do
    Build.with_build_lock(fn ->
      trace = ElixirLS.LanguageServer.Tracer.get_trace()

      Locator.incoming_calls(
        name,
        kind,
        {line, character},
        trace,
        metadata: parser_context.metadata,
        source_file: source_file
      )
      |> Enum.map(fn incoming_call ->
        convert_to_lsp_incoming_call(incoming_call, uri, project_dir)
      end)
      |> Enum.filter(&(not is_nil(&1)))
      |> Enum.uniq()
    end)
  end

  def outgoing_calls(
        uri,
        name,
        kind,
        line,
        character,
        project_dir,
        source_file,
        parser_context
      ) do
    Build.with_build_lock(fn ->
      trace = ElixirLS.LanguageServer.Tracer.get_trace()

      Locator.outgoing_calls(
        name,
        kind,
        {line, character},
        trace,
        metadata: parser_context.metadata,
        source_file: source_file
      )
      |> Enum.map(fn outgoing_call ->
        convert_to_lsp_outgoing_call(outgoing_call, uri, project_dir)
      end)
      |> Enum.filter(&(not is_nil(&1)))
      |> Enum.uniq()
    end)
  end

  defp convert_to_lsp_item(item, uri, text, project_dir) do
    {start_line, start_column} =
      SourceFile.elixir_position_to_lsp(text, {item.range.start.line, item.range.start.column})

    {end_line, end_column} =
      SourceFile.elixir_position_to_lsp(text, {item.range.end.line, item.range.end.column})

    {selection_start_line, selection_start_column} =
      SourceFile.elixir_position_to_lsp(
        text,
        {item.selection_range.start.line, item.selection_range.start.column}
      )

    {selection_end_line, selection_end_column} =
      SourceFile.elixir_position_to_lsp(
        text,
        {item.selection_range.end.line, item.selection_range.end.column}
      )

    uri = build_uri(item.uri, uri, project_dir)

    %GenLSP.Structures.CallHierarchyItem{
      name: item.name,
      kind: item.kind,
      tags: item.tags,
      detail: item.detail,
      uri: uri,
      range: %GenLSP.Structures.Range{
        start: %GenLSP.Structures.Position{line: start_line, character: start_column},
        end: %GenLSP.Structures.Position{line: end_line, character: end_column}
      },
      selection_range: %GenLSP.Structures.Range{
        start: %GenLSP.Structures.Position{
          line: selection_start_line,
          character: selection_start_column
        },
        end: %GenLSP.Structures.Position{
          line: selection_end_line,
          character: selection_end_column
        }
      }
    }
  end

  defp convert_to_lsp_incoming_call(incoming_call, current_uri, project_dir) do
    with {:ok, text} <- get_text(incoming_call.from.uri, current_uri),
         lsp_item <- convert_to_lsp_item(incoming_call.from, current_uri, text, project_dir) do
      ranges =
        incoming_call.from_ranges
        |> Enum.map(fn range ->
          {start_line, start_column} =
            SourceFile.elixir_position_to_lsp(text, {range.start.line, range.start.column})

          {end_line, end_column} =
            SourceFile.elixir_position_to_lsp(text, {range.end.line, range.end.column})

          %GenLSP.Structures.Range{
            start: %GenLSP.Structures.Position{line: start_line, character: start_column},
            end: %GenLSP.Structures.Position{line: end_line, character: end_column}
          }
        end)

      %GenLSP.Structures.CallHierarchyIncomingCall{
        from: lsp_item,
        from_ranges: ranges
      }
    else
      _ -> nil
    end
  end

  defp convert_to_lsp_outgoing_call(outgoing_call, current_uri, project_dir) do
    with {:ok, text} <- get_text(outgoing_call.to.uri, current_uri),
         lsp_item <- convert_to_lsp_item(outgoing_call.to, current_uri, text, project_dir) do
      ranges =
        outgoing_call.from_ranges
        |> Enum.map(fn range ->
          {start_line, start_column} =
            SourceFile.elixir_position_to_lsp(text, {range.start.line, range.start.column})

          {end_line, end_column} =
            SourceFile.elixir_position_to_lsp(text, {range.end.line, range.end.column})

          %GenLSP.Structures.Range{
            start: %GenLSP.Structures.Position{line: start_line, character: start_column},
            end: %GenLSP.Structures.Position{line: end_line, character: end_column}
          }
        end)

      %GenLSP.Structures.CallHierarchyOutgoingCall{
        to: lsp_item,
        from_ranges: ranges
      }
    else
      _ -> nil
    end
  end

  defp build_uri(nil, current_file_uri, _project_dir), do: current_file_uri

  defp build_uri(path, _current_file_uri, project_dir) when is_binary(path) do
    SourceFile.Path.to_uri(path, project_dir)
  end

  defp get_text(nil, current_text) when is_binary(current_text), do: {:ok, current_text}
  defp get_text("nofile", _), do: {:error, :nofile}
  defp get_text(path, _) when is_binary(path), do: File.read(path)
end
