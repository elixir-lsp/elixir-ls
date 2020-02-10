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
  def symbols(query) do
    results =
      case query do
        "f " <> fun_query ->
          query(:functions, fun_query)

        "t " <> type_query ->
          query(:types, type_query)

        "c " <> callback_query ->
          query(:callbacks, callback_query)

        module_query ->
          query(:modules, module_query)
      end

    {:ok, results}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts |> Keyword.put(:name, __MODULE__))
  end

  def notify_build_complete do
    GenServer.cast(__MODULE__, :build_complete)
  end

  @spec notify_uris_modified([String.t()]) :: :ok
  def notify_uris_modified(uris) do
    GenServer.cast(__MODULE__, {:uris_modified, uris})
  end

  ## Server Callbacks

  @impl GenServer
  def init(:ok) do
    {:ok,
     %{
       modules: [],
       types: [],
       callbacks: [],
       functions: [],
       modified_uris: []
     }}
  end

  @impl GenServer
  def handle_call({:query, key, query}, from, state) do
    Task.start_link(fn ->
      results = get_results(state, key, query)
      GenServer.reply(from, results)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:build_complete, %{modified_uris: []} = state) do
    JsonRpc.log_message(:info, "[ElixirLS WorkspaceSymbols] Indexing...")

    module_paths =
      :code.all_loaded()
      |> chunk_by_schedulers(fn chunk ->
        for {module, beam_file} <- chunk,
            path = find_module_path(module, beam_file),
            path != nil,
            do: {module, path}
      end)

    JsonRpc.log_message(:info, "[ElixirLS WorkspaceSymbols] Module discovery complete")

    index(module_paths)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:build_complete, %{modified_uris: modified_uris} = state) do
    JsonRpc.log_message(:info, "[ElixirLS WorkspaceSymbols] Updating index...")

    module_paths =
      :code.all_loaded()
      |> chunk_by_schedulers(fn chunk ->
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
         functions: functions,
         types: types,
         callbacks: callbacks,
         modified_uris: []
     }}
  end

  @impl GenServer
  def handle_cast({:uris_modified, uris}, state) do
    state =
      if state.modules == [] or state.types == [] or state.callbacks == [] or
           state.functions == [] do
        state
      else
        %{state | modified_uris: uris ++ state.modified_uris}
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:results, key, results}, state) do
    {:noreply, state |> Map.put(key, results ++ state[key])}
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
           true <- File.exists?(path_binary) do
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
           true <- File.exists?(erl_file) do
        erl_file
      else
        _ -> nil
      end
    end
  end

  defp get_score(item, query) do
    item_downcase = String.downcase(item)
    query_downcase = String.downcase(query)

    parts = item |> String.split(".")
    arity_suffix = Regex.run(~r/\/\d+$/, query)

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

      length(parts) > 1 and Enum.at(parts, -1) |> String.contains?(query) ->
        2.0

      length(parts) > 1 and
          Enum.at(parts, -1) |> String.downcase() |> String.contains?(query_downcase) ->
        1.8

      String.contains?(item, query) ->
        1.3

      String.contains?(item_downcase, query_downcase) ->
        1.2

      true ->
        String.jaro_distance(item_downcase, query_downcase)
    end
  end

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

  defp query(kind, query) do
    case String.trim(query) do
      "" ->
        []

      trimmed ->
        GenServer.call(__MODULE__, {:query, kind, trimmed})
    end
  end

  defp index(module_paths) do
    index_async(:modules, fn ->
      module_paths
      |> chunk_by_schedulers(fn chunk ->
        for {module, path} <- chunk do
          line = find_module_line(module, path)
          build_result(:modules, module, path, line)
        end
      end)
    end)

    index_async(:functions, fn ->
      module_paths
      |> chunk_by_schedulers(fn chunk ->
        for {module, path} <- chunk,
            {function, arity} <- module.module_info(:exports) do
          {function, arity} = strip_macro_prefix({function, arity})
          line = find_function_line(module, function, arity, path)

          build_result(:functions, {module, function, arity}, path, line)
        end
      end)
    end)

    index_async(:types, fn ->
      module_paths
      |> chunk_by_schedulers(fn chunk ->
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
      module_paths
      |> chunk_by_schedulers(fn chunk ->
        for {module, path} <- chunk,
            function_exported?(module, :behaviour_info, 1),
            # TODO: Don't call into here directly
            {{callback, arity}, [{:type, line, _, _}]} <-
              ElixirSense.Core.Normalized.Typespec.get_callbacks(module) do
          {callback, arity} = strip_macro_prefix({callback, arity})

          build_result(:callbacks, {module, callback, arity}, path, line)
        end
      end)
    end)
  end

  defp index_async(key, fun) do
    self = self()

    Task.start_link(fn ->
      results = fun.()

      send(self, {:results, key, results})

      JsonRpc.log_message(
        :info,
        "[ElixirLS WorkspaceSymbols] #{length(results)} #{key} added to index"
      )
    end)
  end

  @spec get_results(state_t, key_t, String.t()) :: [symbol_information_t]
  defp get_results(state, key, query) do
    state
    |> Map.fetch!(key)
    |> chunk_by_schedulers(fn chunk ->
      chunk
      |> Enum.map(&{&1, get_score(&1.name, query)})
      |> Enum.reject(fn {_item, score} -> score < 0.1 end)
    end)
    |> limit_results
  end

  defp chunk_by_schedulers(enumerable, fun) do
    chunk_size =
      Enum.count(enumerable)
      |> div(System.schedulers_online())
      |> max(1)

    enumerable
    |> Enum.chunk_every(chunk_size)
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
    "f #{inspect(module)}.#{function}/#{arity}"
  end

  defp symbol_name(:types, {module, type, arity}) do
    "t #{inspect(module)}.#{type}/#{arity}"
  end

  defp symbol_name(:callbacks, {module, callback, arity}) do
    "c #{inspect(module)}.#{callback}/#{arity}"
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

  defp strip_macro_prefix({function, arity}) do
    case Atom.to_string(function) do
      "MACRO-" <> rest -> {String.to_atom(rest), arity - 1}
      _other -> {function, arity}
    end
  end
end
