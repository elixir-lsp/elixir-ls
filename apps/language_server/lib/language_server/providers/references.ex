defmodule ElixirLS.LanguageServer.Providers.References do
  @moduledoc """
  This module provides References support by using
  the `Mix.Tasks.Xref` task to find all references to
  any function found at the provided location.
  """

  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Core.Metadata

  def references(text, line, character, _include_declaration) do
    # support _include_declaration
    subject = get_subject(text, line, character)
    {module, scope, arity} = get_line_scope(text, line)

    cond do
      subject == scope -> xref(module, scope, arity) |> Enum.map(&build_location/1)
      true -> []
    end
  end

  @xref_pattern ~r/(?<path>.*):(?<line>\d+): (?<function>.*)/
  defp xref(module, scope, arity) do
    ExUnit.CaptureIO.capture_io(fn ->
      Mix.Tasks.Xref.run(["callers", "#{module}.#{scope}/#{arity}"])
    end)
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(fn line ->
      %{"path" => caller_path, "line" => caller_line} = Regex.named_captures(@xref_pattern, line)
      %{uri: SourceFile.path_to_uri(caller_path), line: String.to_integer(caller_line) - 1}
    end)
  end

  defp build_location(caller) do
    %{
      "uri" => caller.uri,
      "range" => %{
        "start" => %{"line" => caller.line, "character" => 0},
        "end" => %{"line" => caller.line, "character" => 0}
      }
    }
  end

  defp get_subject(text, line, character) do
    ElixirSense.Core.Source.subject(text, line + 1, character + 1) |> String.to_atom()
  end

  defp get_line_scope(text, line) do
    %{module: module, scope: {scope, arity}} =
      ElixirSense.Core.Parser.parse_string(text, true, true, line + 1)
      |> Metadata.get_env(line + 1)

    {module, scope, arity}
  end
end
