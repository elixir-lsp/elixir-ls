defmodule ElixirLS.LanguageServer.Providers.Formatting do
  alias ElixirLS.LanguageServer.SourceFile

  def supported? do
    :erlang.function_exported(Code, :format_string!, 2)
  end

  def format(source_file, uri, project_dir) do
    file = SourceFile.path_from_uri(uri) |> Path.relative_to(project_dir)
    opts = formatter_opts(file, project_dir)
    formatted = IO.iodata_to_binary([Code.format_string!(source_file.text, opts), ?\n])

    response = [
      %{"newText" => formatted, "range" => SourceFile.full_range(source_file)}
    ]

    {:ok, response}
  end

  defp formatter_opts(for_file, project_dir) do
    # Elixir 1.6.5+ has a function that returns formatter options, so we use that if available
    if Code.ensure_loaded?(Mix.Tasks.Format) and
         function_exported?(Mix.Tasks.Format, :formatter_opts_for_file, 1) do
      Mix.Tasks.Format.formatter_opts_for_file(for_file)
    else
      read_formatter_exs(project_dir)
    end
  end

  # TODO: Deprecate once Elixir 1.7 released
  defp read_formatter_exs(project_dir) do
    dot_formatter = Path.join(project_dir, ".formatter.exs")

    if File.regular?(dot_formatter) do
      {formatter_opts, _} = Code.eval_file(dot_formatter)

      unless Keyword.keyword?(formatter_opts) do
        Mix.raise(
          "Expected #{inspect(dot_formatter)} to return a keyword list, " <>
            "got: #{inspect(formatter_opts)}"
        )
      end

      formatter_opts
    else
      []
    end
  end
end
