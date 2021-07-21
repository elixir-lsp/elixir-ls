defmodule ElixirLS.LanguageServer.Providers.Hover do
  alias ElixirLS.LanguageServer.SourceFile

  @moduledoc """
  Hover provider utilizing Elixir Sense
  """

  @hex_base_url "https://hexdocs.pm"

  def hover(text, line, character) do
    response =
      case ElixirSense.docs(text, line + 1, character + 1) do
        %{subject: ""} ->
          nil

        %{subject: subject, docs: docs} ->
          line_text = Enum.at(SourceFile.lines(text), line)
          range = highlight_range(line_text, line, character, subject)

          %{"contents" => contents(docs, subject), "range" => range}
      end

    {:ok, response}
  end

  ## Helpers

  defp highlight_range(line_text, line, character, substr) do
    regex_ranges =
      Regex.scan(
        Regex.recompile!(~r/\b#{Regex.escape(substr)}\b/),
        line_text,
        capture: :first,
        return: :index
      )

    Enum.find_value(regex_ranges, fn
      [{start, length}] when start <= character and character <= start + length ->
        %{
          "start" => %{"line" => line, "character" => start},
          "end" => %{"line" => line, "character" => start + length}
        }

      _ ->
        nil
    end)
  end

  defp contents(%{docs: "No documentation available\n"}, _subject \\ "") do
    []
  end

  defp contents(%{docs: markdown}, subject) do
    %{
      kind: "markdown",
      value: add_hexdocs_link(markdown, subject)
    }
  end

  defp add_hexdocs_link(markdown, subject) do
    [hd | tail] = markdown |> String.split("\n\n")

    link = hexdocs_link(markdown, subject)

    case link do
      "" ->
        markdown

      _ ->
        hd <> "  [view on hexdocs](#{link})\n\n" <> Enum.join(tail, "")
    end
  end

  defp hexdocs_link(markdown, subject) do
    t = markdown |> String.split("\n\n") |> hd() |> String.replace(">", "") |> String.trim()
    dep = subject |> root_module_name() |> dep_name()

    cond do
      func?(t) ->
        if dep != "" do
          "#{@hex_base_url}/#{dep}/#{module_name(subject)}.html##{func_name(subject)}/#{params_cnt(t)}"
        else
          ""
        end

      true ->
        if dep != "" do
          "#{@hex_base_url}/#{dep}/#{t}.html"
        else
          ""
        end
    end
  end

  defp remove_special_symbol(s) do
    s |> String.replace("!", "") |> String.replace("?", "")
  end

  defp func?(s) do
    s =~ ~r/.*\..*\(.*\)/
  end

  defp module_name(s) do
    [_ | tail] = s |> String.split(".") |> Enum.reverse()
    tail |> Enum.reverse() |> Enum.join(".")
  end

  defp func_name(s) do
    s |> String.split(".") |> Enum.reverse() |> hd()
  end

  defp params_cnt(s) do
    cond do
      true == (s =~ ~r/\(\)/) -> 0
      false == String.contains?(s, ",") -> 1
      true -> s |> String.split(",") |> length()
    end
  end

  defp dep_name(root_mod_name) do
    s = root_mod_name |> source()

    cond do
      third_dep?(s) -> third_dep_name(s)
      builtin?(s) -> builtin_dep_name(s)
      true -> ""
    end
  end

  defp root_module_name(subject) do
    subject |> String.split(".") |> hd()
  end

  defp source(mod_name) do
    dep = ("Elixir." <> mod_name) |> String.to_atom()
    dep.__info__(:compile) |> Keyword.get(:source) |> List.to_string()
  end

  defp third_dep?(source) do
    prefix = File.cwd!() <> "/deps"
    String.starts_with?(source, prefix)
  end

  defp third_dep_name(source) do
    prefix = File.cwd!() <> "/deps/"
    String.replace(source, prefix, "") |> String.split("/") |> hd()
  end

  defp builtin?(source) do
    [
      "elixir",
      "eex",
      "ex_unit",
      "iex",
      "logger",
      "mix"
    ]
    |> Enum.map(fn x -> "lib/#{x}/lib" end)
    |> Enum.any?(fn y -> String.contains?(source, y) end)
  end

  def builtin_dep_name(source) do
    [_, name | _] = String.split(source, "/lib/")
    name
  end
end
