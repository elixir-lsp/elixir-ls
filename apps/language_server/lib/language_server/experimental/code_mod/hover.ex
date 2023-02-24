defmodule ElixirLS.LanguageServer.Experimental.CodeMod.Hover do
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Position, as: ElixirPosition
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Range, as: ElixirRange
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.MarkupContent, as: LSMarkupContent

  @hex_base_url "https://hexdocs.pm"
  @builtin_flag [
                  "elixir",
                  "eex",
                  "ex_unit",
                  "iex",
                  "logger",
                  "mix"
                ]
                |> Enum.map(fn x -> "lib/#{x}/lib" end)

  def highlight_range(line_text, line, character, substr, source_file) do
    regex_ranges =
      Regex.scan(
        Regex.recompile!(~r/\b#{Regex.escape(substr)}\b/),
        line_text,
        capture: :first,
        return: :index
      )

    Enum.find_value(regex_ranges, fn
      [{start, length}] when start <= character and character <= start + length ->
        elixir_range =
          ElixirRange.new(
            ElixirPosition.new(line, start),
            ElixirPosition.new(line, start + length)
          )

        {:ok, range} = Conversions.to_lsp(elixir_range, source_file)
        range

      _ ->
        nil
    end)
  end

  def contents(%{docs: "No documentation available\n"}, _subject, _project_dir) do
    []
  end

  def contents(%{docs: markdown}, subject, project_dir) do
    %LSMarkupContent{
      kind: "markdown",
      value: add_hexdocs_link(markdown, subject, project_dir)
    }
  end

  defp add_hexdocs_link(markdown, subject, project_dir) do
    [hd | tail] = markdown |> String.split("\n\n", parts: 2)

    link = hexdocs_link(hd, subject, project_dir)

    case link do
      "" ->
        markdown

      _ ->
        ["#{hd}  [view on hexdocs](#{link})" | tail] |> Enum.join("\n\n")
    end
  end

  defp hexdocs_link(hd, subject, project_dir) do
    title = hd |> String.replace(">", "") |> String.trim() |> URI.encode()

    cond do
      erlang_module?(subject) ->
        # TODO erlang module is currently not supported
        ""

      true ->
        dep = subject |> root_module_name() |> dep_name(project_dir) |> URI.encode()

        cond do
          func?(title) ->
            if dep != "" do
              "#{@hex_base_url}/#{dep}/#{module_name(subject)}.html##{func_name(subject)}/#{params_cnt(title)}"
            else
              ""
            end

          true ->
            if dep != "" do
              "#{@hex_base_url}/#{dep}/#{title}.html"
            else
              ""
            end
        end
    end
  end

  defp func?(s) do
    s =~ ~r/.*\..*\(.*\)/
  end

  defp module_name(s) do
    [_ | tail] = s |> String.split(".") |> Enum.reverse()
    tail |> Enum.reverse() |> Enum.join(".") |> URI.encode()
  end

  defp func_name(s) do
    s |> String.split(".") |> Enum.at(-1) |> URI.encode()
  end

  defp params_cnt(s) do
    cond do
      s =~ ~r/\(\)/ -> 0
      not String.contains?(s, ",") -> 1
      true -> s |> String.split(",") |> length()
    end
  end

  defp dep_name(root_mod_name, project_dir) do
    if not elixir_mod_exported?(root_mod_name) do
      ""
    else
      s = root_mod_name |> source()

      cond do
        third_dep?(s, project_dir) -> third_dep_name(s, project_dir)
        builtin?(s) -> builtin_dep_name(s)
        true -> ""
      end
    end
  end

  defp root_module_name(subject) do
    subject |> String.split(".") |> hd()
  end

  defp source(mod_name) do
    dep = ("Elixir." <> mod_name) |> String.to_atom()
    dep.__info__(:compile) |> Keyword.get(:source) |> List.to_string()
  end

  defp elixir_mod_exported?(mod_name) do
    ("Elixir." <> mod_name) |> String.to_atom() |> function_exported?(:__info__, 1)
  end

  defp third_dep?(_source, nil), do: false

  defp third_dep?(source, project_dir) do
    prefix = deps_path(project_dir)
    String.starts_with?(source, prefix)
  end

  defp third_dep_name(source, project_dir) do
    prefix = deps_path(project_dir) <> "/"
    String.replace_prefix(source, prefix, "") |> String.split("/") |> hd()
  end

  defp deps_path(project_dir) do
    project_dir |> Path.expand() |> Path.join("deps")
  end

  defp builtin?(source) do
    @builtin_flag |> Enum.any?(fn y -> String.contains?(source, y) end)
  end

  defp builtin_dep_name(source) do
    [_, name | _] = String.split(source, "/lib/")
    name
  end

  defp erlang_module?(subject) do
    subject |> root_module_name() |> String.starts_with?(":")
  end
end
