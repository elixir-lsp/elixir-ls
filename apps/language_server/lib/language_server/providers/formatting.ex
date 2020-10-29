defmodule ElixirLS.LanguageServer.Providers.Formatting do
  @moduledoc """
  Formatting Provider. Caches the list of files to be formatted, and formats them.
  """

  ## Approach
  # On initialization, the GenServer in this module populates an `:ets` table
  # with paths that should be formatted, allowing for rapid lookup when a given
  # file is saved.
  #
  # Lookups _are_ serialized through this genserver to avoid race conditions
  # when the server boots or when the cache has to be rebuilt due to changes in
  # a .formatter.exs file. The GenServer call is extremely fast, since all of the
  # actual formatting is accomplished client side.

  use GenServer

  defstruct [
    :format_table,
    :no_format_table,
    :formatter_opts,
    :project_dir
  ]

  import ElixirLS.LanguageServer.Protocol, only: [range: 4]
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.SourceFile

  def build_cache(root_uri) do
    GenServer.call(__MODULE__, {:build_cache, root_uri})
  end

  def formatting_opts_for_file(uri) do
    GenServer.call(__MODULE__, {:opts_for_file, uri})
  end

  def format(%SourceFile{} = source_file, uri, project_dir) do
    if can_format?(uri, project_dir) do
      case formatting_opts_for_file(uri) do
        {:format, opts} ->
          formatted = IO.iodata_to_binary([Code.format_string!(source_file.text, opts), ?\n])

          response =
            source_file.text
            |> String.myers_difference(formatted)
            |> myers_diff_to_text_edits()

          {:ok, response}

        :ignore ->
          {:ok, []}

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
    format_table = :ets.new(__MODULE__, [:set, :private])
    no_format_table = :ets.new(__MODULE__, [:set, :private])

    state = %__MODULE__{
      format_table: format_table,
      no_format_table: no_format_table,
      formatter_opts: :error
    }

    {:ok, state}
  end

  def handle_call({:opts_for_file, file_uri}, _, state) do
    file_path = file_uri |> SourceFile.path_from_uri() |> Path.absname()

    reply =
      case state.formatter_opts do
        {:ok, opts} ->
          formatting_directive(state, opts, file_path)

        :error ->
          :error
      end

    {:reply, reply, state}
  end

  def handle_call({:build_cache, dir}, _, state) do
    opts_result = SourceFile.formatter_opts(dir)
    :ets.delete_all_objects(state.format_table)
    :ets.delete_all_objects(state.no_format_table)

    case opts_result do
      {:ok, opts} ->
        JsonRpc.log_message(:info, "[ElixirLS Formatting] Building cache...")
        populate_cache(dir, state.format_table, opts)
        JsonRpc.log_message(:info, "[ElixirLS Formatting] Cache built.")

      :error ->
        JsonRpc.log_message(:info,
          "[ElixirLS Formatting] Cache will not be built: unable to handle formatter opts"
        )
    end

    {:reply, :ok, %{state | project_dir: dir, formatter_opts: opts_result}}
  end

  defp populate_cache(project_dir, ets, opts) do
    if inputs = opts[:inputs] do
      inputs
      |> Stream.flat_map(fn glob ->
        [
          Path.join([project_dir, glob]),
          Path.join([project_dir, "apps", "*", glob])
        ]
      end)
      |> Stream.flat_map(&Path.wildcard(&1, match_dot: true))
      |> Enum.each(fn file ->
        :ets.insert(ets, {file})
      end)
    end
  end

  defp formatting_directive(state, opts, file_path) do
    cond do
      !opts[:inputs] ->
        {:format, opts}

      :ets.member(state.format_table, file_path) ->
        {:format, opts}

      :ets.member(state.no_format_table, file_path) ->
        :ignore

      true ->
        # If the file is a path we have never seen before, we know there is
        # a new file. We have no way of knowing whether that file should
        # be formatted or not, so we have to rebuild the cache from the globs
        # and re-check membership. If it's a member, great! If it is not,
        # then we know for sure it should not be formatted and we cache that
        # information for fast future lookup.
        # :ets.insert(state.no_format_table, {file_path})

        populate_cache(state.project_dir, state.format_table, opts)

        if :ets.member(state.format_table, file_path) do
          {:format, opts}
        else
          :ets.insert(state.no_format_table, {file_path})
          :ignore
        end
    end
  end
end
