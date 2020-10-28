defmodule ElixirLS.LanguageServer.Providers.Formatting do
  @moduledoc """
  Formatting Provider. Caches the list of files to be formatted, and formats them.
  """

  use GenServer

  import ElixirLS.LanguageServer.Protocol, only: [range: 4]
  alias ElixirLS.LanguageServer.SourceFile

  def build_cache(root_uri) do
    GenServer.call(__MODULE__, {:build_cache, root_uri})
  end

  def format(%SourceFile{} = source_file, uri, project_dir) do
    if can_format?(uri, project_dir) do
      case lookup_cached_opts() do
        {:ok, opts} ->
          if should_format?(uri, opts[:inputs]) do
            formatted = IO.iodata_to_binary([Code.format_string!(source_file.text, opts), ?\n])

            response =
              source_file.text
              |> String.myers_difference(formatted)
              |> myers_diff_to_text_edits()

            {:ok, response}
          else
            {:ok, []}
          end

        :error ->
          {:error, :internal_error, "Unable to fetch formatter options"}
      end
    else
      msg =
        "Cannot format file from current directory " <>
          "(Currently in #{Path.relative_to(File.cwd!(), project_dir)})"

      {:error, :internal_error, msg}
    end
  rescue
    _e in [TokenMissingError, SyntaxError] ->
      {:error, :internal_error, "Unable to format due to syntax error"}
  end

  # If in an umbrella project, the cwd might be set to a sub-app if it's being compiled. This is
  # fine if the file we're trying to format is in that app. Otherwise, we return an error.
  defp can_format?(file_uri, project_dir) do
    file_path = file_uri |> SourceFile.path_from_uri() |> Path.absname()

    not String.starts_with?(file_path, project_dir) or
      String.starts_with?(file_path, File.cwd!())
  end

  def should_format?(file_uri, inputs) when is_list(inputs) do
    file_path = file_uri |> SourceFile.path_from_uri() |> Path.absname()
    :ets.member(__MODULE__, file_path)
  end

  def should_format?(_file_uri, _inputs), do: true

  defp myers_diff_to_text_edits(myers_diff, starting_pos \\ {0, 0}) do
    myers_diff_to_text_edits(myers_diff, starting_pos, [])
  end

  defp myers_diff_to_text_edits([], _pos, edits) do
    edits
  end

  defp myers_diff_to_text_edits([diff | rest], {line, col}, edits) do
    case {diff, rest} do
      {{:eq, str}, _} ->
        myers_diff_to_text_edits(rest, advance_pos({line, col}, str), edits)

      {{:ins, str}, _} ->
        edit = %{"range" => range(line, col, line, col), "newText" => str}
        myers_diff_to_text_edits(rest, {line, col}, [edit | edits])

      {{:del, del_str}, [{:ins, ins_str} | rest]} ->
        {end_line, end_col} = advance_pos({line, col}, del_str)
        edit = %{"range" => range(line, col, end_line, end_col), "newText" => ins_str}
        myers_diff_to_text_edits(rest, {end_line, end_col}, [edit | edits])

      {{:del, str}, _} ->
        {end_line, end_col} = advance_pos({line, col}, str)
        edit = %{"range" => range(line, col, end_line, end_col), "newText" => ""}
        myers_diff_to_text_edits(rest, {end_line, end_col}, [edit | edits])
    end
  end

  defp advance_pos({line, col}, str) do
    Enum.reduce(String.split(str, "", trim: true), {line, col}, fn char, {line, col} ->
      if char in ["\n", "\r"] do
        {line + 1, 0}
      else
        # LSP contentChanges positions are based on UTF-16 string representation
        # https://microsoft.github.io/language-server-protocol/specification#textDocuments
        {line, col + div(byte_size(:unicode.characters_to_binary(char, :utf8, :utf16)), 2)}
      end
    end)
  end

  ## GenServer Callbacks
  #####################
  def start_link(opts) do
    if supported?() do
      GenServer.start_link(__MODULE__, :ok, opts |> Keyword.put_new(:name, __MODULE__))
    else
      :ignore
    end
  end

  def init(_) do
    _ = :ets.new(__MODULE__, [:set, :protected, :named_table, read_concurrency: true])
    {:ok, nil}
  end

  def handle_call({:build_cache, dir}, _, state) do
    opts_result = SourceFile.formatter_opts(dir)
    :ets.delete_all_objects(__MODULE__)
    :ets.insert(__MODULE__, {:formatter_opts, opts_result})

    case opts_result do
      {:ok, opts} ->
        IO.puts("[ElixirLS FormattingCache] Formatter building cache")
        populate_cache(dir, opts)
        IO.puts("[ElixirLS FormattingCache] Formatter cache built")

      :error ->
        IO.puts(
          "[ElixirLS FormattingCache] Formatter cache will not be built: unable to handle formatter opts"
        )
    end

    {:reply, :ok, state}
  end

  defp populate_cache(project_dir, opts) do
    IO.puts("formatting cache with #{inspect(opts)}")
    inputs = opts[:inputs]

    if inputs do
      inputs
      |> Stream.flat_map(fn glob ->
        [
          Path.join([project_dir, glob]),
          Path.join([project_dir, "apps", "*", glob])
        ]
      end)
      |> Stream.flat_map(&Path.wildcard(&1, match_dot: true))
      |> Enum.each(fn file ->
        :ets.insert(__MODULE__, {file})
      end)
    end
  end

  defp lookup_cached_opts() do
    [{:formatter_opts, opts}] = :ets.lookup(__MODULE__, :formatter_opts)
    opts
  end
end
