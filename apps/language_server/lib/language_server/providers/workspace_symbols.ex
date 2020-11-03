defmodule ElixirLS.LanguageServer.Providers.WorkspaceSymbols do
  @moduledoc """
  Workspace Symbols provider. Generates and returns `SymbolInformation[]`.

  https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#workspace_symbol
  """
  use GenServer

  alias ElixirLS.LanguageServer.ErlangSourceFile
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Providers.SymbolUtils
  alias ElixirLS.LanguageServer.JsonRpc

  @arity_suffix_regex ~r/\/\d+$/

  @type position_t :: %{
          line: non_neg_integer,
          character: non_neg_integer
        }

  @type range_t :: %{
          start: position_t,
          end: position_t
        }

  @type location_t :: %{
          uri: String.t(),
          range: range_t
        }

  @type symbol_information_t :: %{
          kind: integer,
          name: String.t(),
          location: location_t
        }

  @typep key_t :: :modules | :functions | :types | :callbacks
  @typep symbol_t :: module | {module, atom, non_neg_integer}
  @typep state_t :: %{
           required(key_t) => [symbol_information_t],
           modified_uris: [String.t()]
         }

  @symbol_codes for {key, kind} <- [
                      modules: :module,
                      functions: :function,
                      types: :class,
                      callbacks: :event
                    ],
                    into: %{},
                    do: {key, SymbolUtils.symbol_kind_to_code(kind)}

  ## Client API

  @spec symbols(String.t()) :: {:ok, [symbol_information_t]}
  def symbols(query, server \\ __MODULE__) do
    results = query(query, server)

    {:ok, results}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts |> Keyword.put_new(:name, __MODULE__))
  end

  def notify_build_complete(server \\ __MODULE__, override_test_mode \\ false) do
    unless Application.get_env(:language_server, :test_mode) && not override_test_mode do
      GenServer.cast(server, :build_complete)
    end
  end

  @spec notify_uris_modified([String.t()]) :: :ok
  def notify_uris_modified(uris, server \\ __MODULE__, override_test_mode \\ false) do
    unless Application.get_env(:language_server, :test_mode) && not override_test_mode do
      GenServer.cast(server, {:uris_modified, uris})
    end
  end

  ## Server Callbacks

  @impl GenServer
  def init(:ok) do
    {:ok,
     %{
       modules: [],
       modules_indexed: false,
       types: [],
       types_indexed: false,
       callbacks: [],
       callbacks_indexed: false,
       functions: [],
       functions_indexed: false,
       indexing: false,
       modified_uris: []
     }}
  end

  @impl GenServer
  def handle_call({:query, query}, from, state) do
    {:ok, _pid} =
      Task.start_link(fn ->
        results = get_results(state, query)
        GenServer.reply(from, results)
      end)

    {:noreply, state}
  end

  @impl GenServer
  # not yet indexed
  def handle_cast(
        :build_complete,
        state = %{
          indexing: false,
          modules_indexed: false,
          functions_indexed: false,
          types_indexed: false,
          callbacks_indexed: false
        }
      ) do
    JsonRpc.log_message(:info, "[ElixirLS WorkspaceSymbols] Indexing...")

    module_paths =
      :code.all_loaded()
      |> process_chunked(fn chunk ->
        for {module, beam_file} <- chunk,
            path = find_module_path(module, beam_file),
            path != nil,
            do: {module, path}
      end)

    JsonRpc.log_message(:info, "[ElixirLS WorkspaceSymbols] Module discovery complete")

    index(module_paths)

    {:noreply, %{state | indexing: true}}
  end

  @impl GenServer
  # indexed but some uris were modified
  def handle_cast(
        :build_complete,
        %{
          indexing: false,
          modified_uris: modified_uris = [_ | _]
        } = state
      ) do
    JsonRpc.log_message(:info, "[ElixirLS WorkspaceSymbols] Updating index...")

    module_paths =
      :code.all_loaded()
      |> process_chunked(fn chunk ->
        for {module, beam_file} <- chunk,
            path = find_module_path(module, beam_file),
            SourceFile.path_to_uri(path) in modified_uris,
            do: {module, path}
      end)

    JsonRpc.log_message(
      :info,
      "[ElixirLS WorkspaceSymbols] #{length(module_paths)} modules need reindexing"
    )

    index(module_paths)

    modules =
      state.modules
      |> Enum.reject(&(&1.location.uri in modified_uris))

    functions =
      state.functions
      |> Enum.reject(&(&1.location.uri in modified_uris))

    types =
      state.types
      |> Enum.reject(&(&1.location.uri in modified_uris))

    callbacks =
      state.callbacks
      |> Enum.reject(&(&1.location.uri in modified_uris))

    {:noreply,
     %{
       state
       | modules: modules,
         modules_indexed: false,
         functions: functions,
         functions_indexed: false,
         types: types,
         types_indexed: false,
         callbacks: callbacks,
         callbacks_indexed: false,
         indexing: true,
         modified_uris: []
     }}
  end

  # indexed and no uris momified or already indexing
  def handle_cast(:build_complete, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:uris_modified, uris}, state) do
    state = %{state | modified_uris: uris ++ state.modified_uris}

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:indexing_complete, key, results}, state) do
    state =
      state
      |> Map.put(key, results ++ state[key])
      |> Map.put(:"#{key}_indexed", true)

    indexed =
      state.modules_indexed and state.functions_indexed and state.types_indexed and
        state.callbacks_indexed

    {:noreply, %{state | indexing: not indexed}}
  end

  ## Helpers

  defp find_module_line(module, path) do
    if String.ends_with?(path, ".erl") do
      ErlangSourceFile.module_line(path)
    else
      SourceFile.module_line(module)
    end
  end

  defp find_function_line(module, function, arity, path) do
    if String.ends_with?(path, ".erl") do
      ErlangSourceFile.function_line(path, function)
    else
      SourceFile.function_line(module, function, arity)
    end
  end

  defp find_module_path(module, beam_file) do
    file =
      with true <- Code.ensure_loaded?(module),
           path when not is_nil(path) <- module.module_info(:compile)[:source],
           path_binary = List.to_string(path),
           true <- File.exists?(path_binary, [:raw]) do
        path_binary
      else
        _ -> nil
      end

    if file do
      file
    else
      with beam_file when not is_nil(beam_file) <-
             ErlangSourceFile.get_beam_file(module, beam_file),
           erl_file = ErlangSourceFile.beam_file_to_erl_file(beam_file),
           true <- File.exists?(erl_file, [:raw]) do
        erl_file
      else
        _ -> nil
      end
    end
  end

  defp get_score(item, query, query_downcase, query_length, arity_suffix) do
    item_downcase = String.downcase(item)

    parts = item |> String.split(".")

    cond do
      # searching for an erlang module but item is an Elixir module
      String.starts_with?(query, ":") and not String.starts_with?(item, ":") ->
        0.0

      # searching for an Elixir module but item is an erlang module
      Regex.match?(~r/^[A-Z]/, query) and String.starts_with?(item, ":") ->
        0.0

      # searching for an Elixir module or erlang/Elixir function but item has no `.`
      String.contains?(query, ".") and not String.contains?(item, ".") ->
        0.0

      # query specifies arity and item's arity does not match
      arity_suffix != nil and not String.ends_with?(item, arity_suffix) ->
        0.0

      length(parts) > 1 and Enum.at(parts, -1) |> exact_or_contains?(query, query_length) ->
        2.0

      length(parts) > 1 and
          Enum.at(parts, -1)
          |> String.downcase()
          |> exact_or_contains?(query_downcase, query_length) ->
        1.8

      exact_or_contains?(item, query, query_length) ->
        1.3

      exact_or_contains?(item_downcase, query_downcase, query_length) ->
        1.2

      query_length >= 3 ->
        String.jaro_distance(item_downcase, query_downcase)

      true ->
        0.0
    end
  end

  defp exact_or_contains?(string, needle = "/" <> _, needle_length) when needle_length < 3 do
    String.ends_with?(string, needle)
  end

  defp exact_or_contains?(string, needle, needle_length) when needle_length < 3 do
    string_no_arity = Regex.replace(@arity_suffix_regex, string, "")
    string_no_arity == needle
  end

  defp exact_or_contains?(string, needle, _needle_length), do: String.contains?(string, needle)

  defp limit_results(list) do
    list
    |> Enum.sort_by(&elem(&1, 1), &>=/2)
    |> Enum.reduce_while({[], false}, fn {element, score}, {list, match_found} ->
      match_found = match_found or score > 1.0

      if match_found do
        if score > 1.0 do
          {:cont, {[element | list], match_found}}
        else
          {:halt, {list, match_found}}
        end
      else
        if length(list) < 15 do
          {:cont, {[element | list], match_found}}
        else
          {:halt, {list, match_found}}
        end
      end
    end)
    |> elem(0)
  end

  defp query(query, server) do
    case String.trim(query) do
      "" ->
        []

      trimmed ->
        GenServer.call(server, {:query, trimmed})
    end
  end

  defp index(module_paths) do
    chunked_module_paths = chunk_by_schedulers(module_paths)

    index_async(:modules, fn ->
      chunked_module_paths
      |> do_process_chunked(fn chunk ->
        for {module, path} <- chunk do
          line = find_module_line(module, path)
          build_result(:modules, module, path, line)
        end
      end)
    end)

    index_async(:functions, fn ->
      chunked_module_paths
      |> do_process_chunked(fn chunk ->
        for {module, path} <- chunk,
            Code.ensure_loaded?(module),
            {function, arity} <- module.module_info(:exports) do
          {function, arity} = SourceFile.strip_macro_prefix({function, arity})
          line = find_function_line(module, function, arity, path)

          build_result(:functions, {module, function, arity}, path, line)
        end
      end)
    end)

    index_async(:types, fn ->
      chunked_module_paths
      |> do_process_chunked(fn chunk ->
        for {module, path} <- chunk,
            # TODO: Don't call into here directly
            {kind, {type, type_ast, args}} <-
              ElixirSense.Core.Normalized.Typespec.get_types(module),
            kind in [:type, :opaque] do
          line =
            case type_ast do
              {_, line, _, _} -> line
              {_, line, _} -> line
            end

          build_result(:types, {module, type, length(args)}, path, line)
        end
      end)
    end)

    index_async(:callbacks, fn ->
      chunked_module_paths
      |> do_process_chunked(fn chunk ->
        for {module, path} <- chunk,
            function_exported?(module, :behaviour_info, 1),
            # TODO: Don't call into here directly
            {{callback, arity}, [{:type, line, _, _}]} <-
              ElixirSense.Core.Normalized.Typespec.get_callbacks(module) do
          {callback, arity} = SourceFile.strip_macro_prefix({callback, arity})

          build_result(:callbacks, {module, callback, arity}, path, line)
        end
      end)
    end)
  end

  defp index_async(key, fun) do
    self = self()

    {:ok, _pid} =
      Task.start_link(fn ->
        results = fun.()

        send(self, {:indexing_complete, key, results})

        JsonRpc.log_message(
          :info,
          "[ElixirLS WorkspaceSymbols] #{length(results)} #{key} added to index"
        )
      end)

    :ok
  end

  @spec get_results(state_t, String.t()) :: [symbol_information_t]
  defp get_results(state, query) do
    query_downcase = String.downcase(query)
    query_length = String.length(query)
    arity_suffix = Regex.run(@arity_suffix_regex, query)

    (state.modules ++ state.functions ++ state.types ++ state.callbacks)
    |> process_chunked(fn chunk ->
      chunk
      |> Enum.map(&{&1, get_score(&1.name, query, query_downcase, query_length, arity_suffix)})
      |> Enum.reject(fn {_item, score} -> score < 0.1 end)
    end)
    |> limit_results
  end

  defp chunk_by_schedulers(enumerable) do
    chunk_size =
      Enum.count(enumerable)
      |> div(System.schedulers_online())
      |> max(1)

    enumerable
    |> Enum.chunk_every(chunk_size)
  end

  defp process_chunked(enumerable, fun) do
    enumerable
    |> chunk_by_schedulers
    |> do_process_chunked(fun)
  end

  defp do_process_chunked(chunked_enumerable, fun) do
    chunked_enumerable
    |> Enum.map(fn chunk when is_list(chunk) ->
      Task.async(fn ->
        fun.(chunk)
      end)
    end)
    |> Task.yield_many(:infinity)
    |> Enum.flat_map(fn {_task, {:ok, result}} when is_list(result) ->
      result
    end)
  end

  @spec build_result(key_t, symbol_t, String.t(), nil | non_neg_integer) :: symbol_information_t
  defp build_result(key, symbol, path, line) do
    %{
      kind: @symbol_codes |> Map.fetch!(key),
      name: symbol_name(key, symbol),
      location: %{
        uri: SourceFile.path_to_uri(path),
        range: build_range(line)
      }
    }
  end

  @spec symbol_name(key_t, symbol_t) :: String.t()
  defp symbol_name(:modules, module) do
    inspect(module)
  end

  defp symbol_name(:functions, {module, function, arity}) do
    "#{inspect(module)}.#{function}/#{arity}"
  end

  defp symbol_name(:types, {module, type, arity}) do
    "#{inspect(module)}.#{type}/#{arity}"
  end

  defp symbol_name(:callbacks, {module, callback, arity}) do
    "#{inspect(module)}.#{callback}/#{arity}"
  end

  @spec build_range(nil | non_neg_integer) :: range_t
  defp build_range(nil) do
    %{
      start: %{line: 0, character: 0},
      end: %{line: 1, character: 0}
    }
  end

  defp build_range(line) do
    %{
      start: %{line: max(line - 1, 0), character: 0},
      end: %{line: line, character: 0}
    }
  end
end
