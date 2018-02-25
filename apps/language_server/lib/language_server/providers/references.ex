defmodule ElixirLS.LanguageServer.Providers.References do
  @moduledoc """
  This module provides References support by using
  the `Mix.Tasks.Xref` task to find all references to
  any function or module identified at the provided location.
  """

  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Core.Metadata

  def references(text, line, character, _include_declaration) do
    subject_at_cursor(text, line, character)
    |> derive_function_subject(get_line_context(text, line))
    |> xref()
    |> Enum.map(&build_location/1)
  end

  # Guard against reference requests that lack a subject
  defp derive_function_subject(nil, _line_context), do: ""

  # Support finding references to a function by clicking on its function head
  # e.g. "foo" in `def foo`
  defp derive_function_subject(subject, {module, subject, arity}),
    do: "#{module}.#{subject}/#{arity}"

  # Support finding references to an erlang module or function reference
  # e.g. `:timer` or `:timer.tc`
  defp derive_function_subject(":" <> _ = subject, _line_context), do: ":" <> derive_mfa(subject)

  # Support finding references to an elixir module or function reference
  # e.g. `Application` or `Application.get_env`
  defp derive_function_subject(subject, _line_context), do: derive_mfa(subject)

  defp derive_mfa(subject) do
    case Mix.Utils.parse_mfa(subject) do
      :error -> ""
      {:ok, [module]} -> "#{module}"
      {:ok, [module, function]} -> "#{module}.#{function}"
      {:ok, [module, function, arity]} -> "#{module}.#{function}/#{arity}"
    end
  end

  defp xref(""), do: []

  defp xref(func) do
    ExUnit.CaptureIO.capture_io(fn ->
      Mix.Tasks.Xref.run(["callers", func])
    end)
    |> String.split("\n")
    |> Enum.reject(&match?("", &1))
    |> Enum.map(&parse_xref_line/1)
  end

  @xref_line_pattern ~r/(?<path>.*):(?<line>\d+): (?<function>.*)/
  defp parse_xref_line(line) do
    %{"path" => caller_path, "line" => caller_line} =
      Regex.named_captures(@xref_line_pattern, line)

    %{uri: SourceFile.path_to_uri(caller_path), line: String.to_integer(caller_line) - 1}
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

  defp subject_at_cursor(text, line, character) do
    ElixirSense.Core.Source.subject(text, line + 1, character + 1)
  end

  defp get_line_context(text, line) do
    ElixirSense.Core.Parser.parse_string(text, true, true, line + 1)
    |> Metadata.get_env(line + 1)
    |> case do
      %{module: module, scope: {scope, arity}} -> {"#{module}", "#{scope}", "#{arity}"}
      _ -> nil
    end
  end
end
