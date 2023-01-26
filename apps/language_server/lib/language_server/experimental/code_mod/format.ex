defmodule ElixirLS.LanguageServer.Experimental.CodeMod.Format do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextEdit

  require Logger
  @type formatter_function :: (String.t() -> any) | nil

  @spec text_edits(SourceFile.t(), String.t() | nil) :: {:ok, [TextEdit.t()]} | {:error, any}
  def text_edits(%SourceFile{} = document, project_path_or_uri) do
    with {:ok, unformatted, formatted} <- do_format(document, project_path_or_uri) do
      edits = Diff.diff(unformatted, formatted)
      {:ok, edits}
    end
  end

  @spec format(SourceFile.t(), String.t() | nil) :: {:ok, String.t()} | {:error, any}
  def format(%SourceFile{} = document, project_path_or_uri) do
    with {:ok, _, formatted_code} <- do_format(document, project_path_or_uri) do
      {:ok, formatted_code}
    end
  end

  defp do_format(%SourceFile{} = document, project_path_or_uri)
       when is_binary(project_path_or_uri) do
    project_path = Conversions.ensure_path(project_path_or_uri)

    with :ok <- check_current_directory(document, project_path),
         {:ok, formatter, options} <- formatter_for(document.path),
         :ok <-
           check_inputs_apply(document, project_path, Keyword.get(options, :inputs)) do
      document
      |> SourceFile.to_string()
      |> formatter.()
    end
  end

  defp do_format(%SourceFile{} = document, _) do
    formatter = build_formatter([])

    document
    |> SourceFile.to_string()
    |> formatter.()
  end

  @spec formatter_for(String.t()) ::
          {:ok, formatter_function, keyword()} | {:error, :no_formatter_available}
  defp formatter_for(uri_or_path) do
    path = Conversions.ensure_path(uri_or_path)

    try do
      true = Code.ensure_loaded?(Mix.Tasks.Format)

      if function_exported?(Mix.Tasks.Format, :formatter_for_file, 1) do
        {formatter_function, options} = Mix.Tasks.Format.formatter_for_file(path)

        wrapped_formatter_function = wrap_with_try_catch(formatter_function)

        {:ok, wrapped_formatter_function, options}
      else
        options = Mix.Tasks.Format.formatter_opts_for_file(path)
        formatter = build_formatter(options)
        {:ok, formatter, Mix.Tasks.Format.formatter_opts_for_file(path)}
      end
    rescue
      e ->
        message = Exception.message(e)

        Logger.warn(
          "Unable to get formatter options for #{path}: #{inspect(e.__struct__)} #{message}"
        )

        {:error, :no_formatter_available}
    end
  end

  defp build_formatter(opts) do
    fn code ->
      formatted_iodata = Code.format_string!(code, opts)
      IO.iodata_to_binary([formatted_iodata, ?\n])
    end
    |> wrap_with_try_catch()
  end

  defp wrap_with_try_catch(formatter_fn) do
    fn code ->
      try do
        {:ok, code, formatter_fn.(code)}
      rescue
        e ->
          {:error, e}
      end
    end
  end

  defp check_current_directory(%SourceFile{} = document, project_path) do
    cwd = File.cwd!()

    if subdirectory?(document.path, parent: project_path) or
         subdirectory?(document.path, parent: cwd) do
      :ok
    else
      message =
        "Cannot format file from current directory " <>
          "(Currently in #{Path.relative_to(cwd, project_path)})"

      {:error, message}
    end
  end

  defp check_inputs_apply(%SourceFile{} = document, project_path, inputs)
       when is_list(inputs) do
    formatter_dir = dominating_formatter_exs_dir(document, project_path)

    inputs_apply? =
      Enum.any?(inputs, fn input_glob ->
        glob = Path.join(formatter_dir, input_glob)
        PathGlobVendored.match?(document.path, glob, match_dot: true)
      end)

    if inputs_apply? do
      :ok
    else
      {:error, :input_mismatch}
    end
  end

  defp check_inputs_apply(_, _, _), do: :ok

  defp subdirectory?(child, parent: parent) do
    normalized_parent = Path.absname(parent)
    String.starts_with?(child, normalized_parent)
  end

  # Finds the directory with the .formatter.exs that's the nearest parent to the
  # source file, or the project dir if none was found.
  defp dominating_formatter_exs_dir(%SourceFile{} = document, project_path) do
    document.path
    |> Path.dirname()
    |> dominating_formatter_exs_dir(project_path)
  end

  defp dominating_formatter_exs_dir(project_dir, project_dir) do
    project_dir
  end

  defp dominating_formatter_exs_dir(current_dir, project_path) do
    formatter_exs_name = Path.join(current_dir, ".formatter.exs")

    if File.exists?(formatter_exs_name) do
      current_dir
    else
      current_dir
      |> Path.dirname()
      |> dominating_formatter_exs_dir(project_path)
    end
  end
end
