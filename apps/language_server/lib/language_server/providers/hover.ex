defmodule ElixirLS.LanguageServer.Providers.Hover do
  alias ElixirLS.LanguageServer.SourceFile

  @moduledoc """
  Hover provider utilizing Elixir Sense
  """

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
    IO.inspect(subject)

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

    cond do
      func?(t) ->
        mod_name = module_name(t)

        if elixir_module?(mod_name) do
          "https://hexdocs.pm/elixir/#{module_name(subject)}.html##{func_name(subject)}/#{params_cnt(t)}"
        else
          ""
        end

      true ->
        if elixir_module?(t) do
          "https://hexdocs.pm/elixir/#{t}.html"
        else
          ""
        end
    end
  end

  defp remove_special_symbol(s) do
    s |> String.replace("!", "") |> String.replace("?", "")
  end

  defp groups_for_modules do
    [
      Kernel: [Kernel, Kernel.SpecialForms],
      "Basic Types": [
        Atom,
        Base,
        Bitwise,
        Date,
        DateTime,
        Exception,
        Float,
        Function,
        Integer,
        Module,
        NaiveDateTime,
        Record,
        Regex,
        String,
        Time,
        Tuple,
        URI,
        Version,
        Version.Requirement
      ],
      "Collections & Enumerables": [
        Access,
        Date.Range,
        Enum,
        Keyword,
        List,
        Map,
        MapSet,
        Range,
        Stream
      ],
      "IO & System": [
        File,
        File.Stat,
        File.Stream,
        IO,
        IO.ANSI,
        IO.Stream,
        OptionParser,
        Path,
        Port,
        StringIO,
        System
      ],
      Calendar: [
        Calendar,
        Calendar.ISO,
        Calendar.TimeZoneDatabase,
        Calendar.UTCOnlyTimeZoneDatabase
      ],
      "Processes & Applications": [
        Agent,
        Application,
        Config,
        Config.Provider,
        Config.Reader,
        DynamicSupervisor,
        GenServer,
        Node,
        Process,
        Registry,
        Supervisor,
        Task,
        Task.Supervisor
      ],
      Protocols: [
        Collectable,
        Enumerable,
        Inspect,
        Inspect.Algebra,
        Inspect.Opts,
        List.Chars,
        Protocol,
        String.Chars
      ],
      "Code & Macros": [
        Code,
        Kernel.ParallelCompiler,
        Macro,
        Macro.Env
      ]
    ]
  end

  defp func?(s) do
    s =~ ~r/.*\..*\(.*\)/
  end

  defp elixir_module?(s) do
    groups_for_modules()
    |> Enum.map(fn x -> elem(x, 1) end)
    |> Enum.reduce(fn x, y -> x ++ y end)
    |> Enum.any?(fn x ->
      x == String.to_atom("Elixir." <> s)
    end)
  end

  defp module_name(s) do
    [_ | tail] = s |> String.split(".") |> Enum.reverse()
    Enum.join(tail, ".")
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
end
