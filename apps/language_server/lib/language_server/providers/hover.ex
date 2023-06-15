defmodule ElixirLS.LanguageServer.Providers.Hover do
  alias ElixirLS.LanguageServer.SourceFile
  import ElixirLS.LanguageServer.Protocol

  @moduledoc """
  Hover provider utilizing Elixir Sense
  """

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

  def hover(text, line, character, project_dir) do
    {line, character} = SourceFile.lsp_position_to_elixir(text, {line, character})

    response =
      case ElixirSense.docs(text, line, character) do
        nil ->
          nil

        %{actual_subject: subject, docs: docs, range: es_range} ->
          lines = SourceFile.lines(text)

          %{
            "contents" => contents(docs, subject, project_dir),
            "range" => build_range(lines, es_range)
          }
      end

    {:ok, response}
  end

  ## Helpers

  def build_range(lines, %{begin: {begin_line, begin_char}, end: {end_line, end_char}}) do
    range(
      begin_line - 1,
      SourceFile.elixir_character_to_lsp(lines |> Enum.at(begin_line - 1), begin_char),
      end_line - 1,
      SourceFile.elixir_character_to_lsp(lines |> Enum.at(end_line - 1), end_char)
    )
  end

  defp contents(%{docs: "No documentation available\n"}, _subject, _project_dir) do
    []
  end

  defp contents(%{docs: markdown}, subject, project_dir) do
    %{
      kind: "markdown",
      value: add_hexdocs_link(markdown, subject, project_dir)
    }
  end

  defp add_hexdocs_link(markdown, subject, project_dir) do
    with [hd | tail] <- markdown |> String.split("\n\n", parts: 2),
         link when link != "" <- hexdocs_link(hd, subject, project_dir) do
      ["#{hd}  [view on hexdocs](#{link})" | tail] |> Enum.join("\n\n")
    else
      _ -> markdown
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
