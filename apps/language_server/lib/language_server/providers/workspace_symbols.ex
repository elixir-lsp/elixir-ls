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
  alias ElixirSense.Providers.Suggestion.Matcher
  require ElixirSense.Core.Introspection, as: Introspection
  require Logger

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

  @typep key_t :: :modules
  @typep symbol_t :: module | {module, atom, non_neg_integer}
  @typep state_t :: %{
           required(key_t) => [symbol_information_t],
           modified_uris: [String.t()]
         }

  @symbol_codes for kind <- [
                      :module,
                      :interface,
                      :struct,
                      :function,
                      :constant,
                      :class,
                      :event
                    ],
                    into: %{},
                    do: {kind, SymbolUtils.symbol_kind_to_code(kind)}

  ## Client API

  @spec symbols(String.t()) :: {:ok, [symbol_information_t]}
  def symbols(query, server \\ __MODULE__) do
    results = query(query, server)

    {:ok, results}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts |> Keyword.put_new(:name, __MODULE__))
  end

  def notify_settings_stored() do
    GenServer.cast(__MODULE__, :notify_settings_stored)
  end

  def notify_build_complete(server \\ __MODULE__) do
    unless :persistent_term.get(:language_server_test_mode, false) and
             not :persistent_term.get(:language_server_override_test_mode, false) do
      GenServer.cast(server, :build_complete)
    end
  end

  @spec notify_uris_modified([String.t()]) :: :ok | nil
  def notify_uris_modified(uris, server \\ __MODULE__) do
    unless :persistent_term.get(:language_server_test_mode, false) and
             not :persistent_term.get(:language_server_override_test_mode, false) do
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
       modified_uris: [],
       project_dir: nil,
       tag_support: false
     }}
  end

  @impl GenServer
  def terminate(reason, _state) do
    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        ElixirLS.LanguageServer.Server.do_sanity_check()
        message = Exception.format_exit(reason)

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => message
          },
          %{}
        )

        Logger.info("Terminating #{__MODULE__}: #{message}")
    end

    :ok
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
  def handle_cast(:notify_settings_stored, state) do
    project_dir = :persistent_term.get(:language_server_project_dir)

    # as of LSP 3.17 only one tag is defined and clients are required to silently ignore unknown tags
    # so there's no need to pass the list
    tag_support =
      :persistent_term.get(:language_server_client_capabilities)["workspace"]["symbol"][
        "tagSupport"
      ] != nil

    {:noreply, %{state | project_dir: project_dir, tag_support: tag_support}}
  end

  # not yet indexed
  def handle_cast(
        :build_complete,
        state = %{
          indexing: false,
          modules_indexed: false,
          project_dir: project_dir,
          tag_support: tag_support
        }
      ) do
    Logger.info("[ElixirLS WorkspaceSymbols] Indexing...")

    module_paths =
      get_app_modules()
      |> process_chunked(fn chunk ->
        for module <- chunk,
            path = find_module_path(module),
            do: {module, path}
      end)

    Logger.info("[ElixirLS WorkspaceSymbols] Module discovery complete")

    index(module_paths, project_dir, tag_support)

    {:noreply, %{state | indexing: true}}
  end

  @impl GenServer
  # indexed but some uris were modified
  def handle_cast(
        :build_complete,
        %{
          indexing: false,
          modified_uris: modified_uris = [_ | _],
          project_dir: project_dir,
          tag_support: tag_support
        } = state
      ) do
    Logger.info("[ElixirLS WorkspaceSymbols] Updating index...")

    module_paths =
      get_app_modules()
      |> process_chunked(fn chunk ->
        for module <- chunk,
            path = find_module_path(module),
            SourceFile.Path.to_uri(path, project_dir) in modified_uris,
            do: {module, path}
      end)

    Logger.info("[ElixirLS WorkspaceSymbols] #{length(module_paths)} modules need reindexing")

    index(module_paths, project_dir, tag_support)

    modules =
      state.modules
      |> Enum.reject(&(&1.location.uri in modified_uris))

    {:noreply,
     %{
       state
       | modules: modules,
         modules_indexed: false,
         indexing: true,
         modified_uris: []
     }}
  end

  # indexed and no uris modified or already indexing
  def handle_cast(:build_complete, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:uris_modified, uris}, state) do
    state = %{state | modified_uris: Enum.uniq(uris ++ state.modified_uris)}

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:indexing_complete, key, results}, state) do
    state =
      state
      |> Map.put(key, results ++ state[key])
      |> Map.put(:"#{key}_indexed", true)

    indexed = state.modules_indexed

    {:noreply, %{state | indexing: not indexed}}
  end

  ## Helpers

  defp get_app_modules() do
    config = Mix.Project.config()

    apps =
      case Mix.Project.apps_paths(config) do
        nil ->
          config[:app] |> List.wrap()

        map ->
          Map.keys(map)
      end

    for app <- apps do
      case :application.get_key(app, :modules) do
        {:ok, modules} ->
          modules

        :undefined ->
          []
      end
    end
    |> List.flatten()
    |> Enum.filter(&Code.ensure_loaded?/1)
  end

  defp find_module_path(module) do
    with true <- Code.ensure_loaded?(module),
         path when not is_nil(path) <- module.module_info(:compile)[:source],
         path_binary = List.to_string(path),
         true <- File.exists?(path_binary, [:raw]) do
      path_binary
    else
      _ -> nil
    end
  end

  @module_kind_codes [
    SymbolUtils.symbol_kind_to_code(:module),
    SymbolUtils.symbol_kind_to_code(:interface)
  ]

  defp get_score(%{name: name, kind: kind_code}, %{
         query: query,
         query_downcase: query_downcase,
         query_parts: query_parts
       }) do
    name_downcase = String.downcase(name)
    name_length = String.length(name)

    last_part = name |> String.split(".") |> List.last()
    last_part_downcase = String.downcase(last_part)

    res =
      cond do
        Matcher.match?(" " <> last_part, " " <> query) ->
          # exact case match on function/type/callback or last part in module alias
          # assumes query does not include `.`

          # 0-1 boost for similarity
          distance = String.jaro_distance(last_part, query)
          1.9 + distance

        Matcher.match?(" " <> last_part_downcase, " " <> query_downcase) ->
          # non exact case match on function/type/callback or last part in module alias
          # assumes query does not include `.`

          # 0-1 boost for similarity
          distance = String.jaro_distance(last_part_downcase, query_downcase)
          1.7 + distance

        Matcher.match?(" " <> name, " " <> query) ->
          # exact case match on full name

          # 0-1 boost for similarity
          distance = String.jaro_distance(name, query)

          # 0-1 penalty starting for names longer than 8 codepoints
          length_penalty = 1.0 - 1.0 / max(1, name_length / 8.0)

          1.5 + distance - length_penalty

        Matcher.match?(" " <> name_downcase, " " <> query_downcase) ->
          # non exact case match on full name

          # 0-1 boost for similarity
          distance = String.jaro_distance(name_downcase, query_downcase)

          # 0-1 penalty starting for names longer than 8 codepoints
          length_penalty = 1.0 - 1.0 / max(1, name_length / 8.0)

          1.2 + distance - length_penalty

        true ->
          0.0
      end

    res =
      if res > 0.0 and kind_code not in @module_kind_codes and length(query_parts) == 1 and
           not Matcher.match?(" " <> last_part_downcase, " " <> query_downcase) do
        # exclude functions/types/callbacks when module matches and function/type/callback does not contribute
        0.0
      else
        res
      end

    res
  end

  defp query(query, server) do
    GenServer.call(server, {:query, String.trim(query)})
  end

  @builtin_functions [{:module_info, 0}, {:module_info, 1}, {:behaviour_info, 1}, {:__info__, 1}]

  defp index(module_paths, project_dir, tag_support) do
    chunked_module_paths = chunk_by_schedulers(module_paths)

    index_async(:modules, fn ->
      chunked_module_paths
      |> do_process_chunked(fn chunk ->
        for {module, path} <- chunk do
          {module_annotation, module_metadata, docs} =
            case Code.fetch_docs(module) do
              {:docs_v1, module_annotation, _, _, _, module_metadata, docs} ->
                {module_annotation, module_metadata, docs}

              _ ->
                {0, %{}, []}
            end

          # TODO migrate Complete to use Code.fetch_docs format?
          # docs = ElixirSense.Core.Normalized.Code.get_docs(module, :moduledoc)
          # # fetching docs is quite costly, since we already do it here we can use it to fill up caches
          # if ElixirSense.Core.Introspection.elixir_module?(module) do
          #   ElixirSense.Providers.Suggestion.Complete.fill_elixir_module_cache(module, docs)
          # else
          #   ElixirSense.Providers.Suggestion.Complete.fill_erlang_module_cache(module, docs)
          # end

          # TODO @moduledoc location
          location = find_module_location(path, module_annotation)

          module_symbol_kind =
            cond do
              function_exported?(module, :behaviour_info, 1) ->
                :interface

              function_exported?(module, :__struct__, 0) ->
                :struct

              true ->
                :module
            end

          module_result =
            build_result(
              module_symbol_kind,
              module,
              path,
              location,
              module_metadata,
              project_dir,
              tag_support
            )

          # functions/macros
          function_results =
            for {function, arity_original} <- module.module_info(:exports),
                {function, arity_original} not in @builtin_functions,
                {function, arity} = SourceFile.strip_macro_prefix({function, arity_original}) do
              kind =
                if arity == arity_original do
                  :function
                else
                  :macro
                end

              {annotation, metadata, found_arity} =
                Enum.find_value(docs, {0, %{}, arity}, fn
                  {{^kind, ^function, a}, annotation, _, _, metadata} ->
                    default_args = Map.get(metadata, :defaults, 0)

                    if Introspection.matches_arity_with_defaults?(a, default_args, arity) do
                      {annotation, metadata, a}
                    end

                  _ ->
                    nil
                end)

              # discard lower arity results for functions/macros with default args
              if found_arity == arity do
                # TODO @doc location
                location = find_function_location(function, path, annotation)
                symbol_kind = if kind == :function, do: :function, else: :constant

                build_result(
                  symbol_kind,
                  {module, function, arity},
                  path,
                  location,
                  metadata,
                  project_dir,
                  tag_support
                )
              end
            end
            |> Enum.reject(&is_nil/1)

          # callbacks/macrocallbacks

          callback_results =
            if function_exported?(module, :behaviour_info, 1) do
              for {{callback, arity}, [{:type, location, _, _}]} <-
                    ElixirSense.Core.Normalized.Typespec.get_callbacks(module) do
                {callback, arity} = SourceFile.strip_macro_prefix({callback, arity})

                {annotation, metadata} =
                  Enum.find_value(docs, {0, %{}}, fn
                    {{kind, ^callback, ^arity}, annotation, _, _, metadata}
                    when kind in [:callback, :macrocallback] ->
                      {annotation, metadata}

                    _ ->
                      nil
                  end)

                location =
                  if :erl_anno.line(annotation) != 0 do
                    # TODO @doc location
                    annotation
                  else
                    location
                  end

                build_result(
                  :event,
                  {module, callback, arity},
                  path,
                  location,
                  metadata,
                  project_dir,
                  tag_support
                )
              end
            else
              []
            end

          # typespecs

          typespec_results =
            for {kind, {type, type_ast, args}} <-
                  ElixirSense.Core.Normalized.Typespec.get_types(module),
                kind in [:type, :opaque] do
              arity = length(args)

              location =
                case type_ast do
                  {_, location, _, _} -> location
                  {_, location, _} -> location
                end

              {annotation, metadata} =
                Enum.find_value(docs, {0, %{}}, fn
                  {{:type, ^type, ^arity}, annotation, _, _, metadata} ->
                    {annotation, metadata}

                  _ ->
                    nil
                end)

              location =
                if :erl_anno.line(annotation) != 0 do
                  # TODO @typedoc location
                  annotation
                else
                  location
                end

              build_result(
                :class,
                {module, type, arity},
                path,
                location,
                metadata,
                project_dir,
                tag_support
              )
            end

          [module_result] ++ function_results ++ callback_results ++ typespec_results
        end
        |> List.flatten()
      end)
    end)
  end

  defp find_module_location(path, 0) do
    # TODO read the file only once
    if String.ends_with?(path, ".erl") do
      ErlangSourceFile.module_line(path)
    end || 0
  end

  defp find_module_location(_path, annotation), do: annotation

  defp find_function_location(function, path, 0) do
    if String.ends_with?(path, ".erl") do
      ErlangSourceFile.function_line(path, function)
    end || 0
  end

  defp find_function_location(_function, _path, annotation), do: annotation

  defp index_async(key, fun) do
    self = self()

    {:ok, _pid} =
      Task.start_link(fn ->
        {us, results} = :timer.tc(fun)

        send(self, {:indexing_complete, key, results})

        Logger.info(
          "[ElixirLS WorkspaceSymbols] #{length(results)} symbols added to index in #{div(us, 1000)}ms"
        )
      end)

    :ok
  end

  @spec get_results(state_t, String.t()) :: [symbol_information_t]
  defp get_results(state, query) do
    query_downcase = String.downcase(query)
    query_parts = query |> String.split(".")

    query_context = %{query: query, query_downcase: query_downcase, query_parts: query_parts}

    (state.modules ++ state.functions ++ state.types ++ state.callbacks)
    |> process_chunked(fn chunk ->
      chunk
      |> Enum.map(&{&1, get_score(&1, query_context)})
      |> Enum.filter(fn {_item, score} -> score > 0.0 end)
    end)
    |> Enum.sort_by(&elem(&1, 1), &>=/2)
    |> Enum.map(&elem(&1, 0))
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

  @spec build_result(atom, symbol_t, String.t(), :erl_anno.anno(), map(), String.t(), boolean) ::
          symbol_information_t
  defp build_result(key, symbol, path, annotation, metadata, project_dir, tag_support) do
    res = %{
      kind: @symbol_codes |> Map.fetch!(key),
      name: symbol_name(key, symbol),
      location: %{
        uri: SourceFile.Path.to_uri(path, project_dir),
        range: build_range(annotation)
      }
    }

    container_name = container_name(key, symbol)

    res =
      if container_name do
        Map.put(res, :containerName, container_name)
      else
        res
      end

    if tag_support do
      tags = metadata_to_tags(metadata)
      Map.put(res, :tags, tags)
    else
      res
    end
  end

  @module_kinds [:module, :interface, :struct]

  @spec symbol_name(atom, symbol_t) :: String.t()
  defp symbol_name(kind, module) when kind in @module_kinds do
    inspect(module)
  end

  defp symbol_name(:function, {module, function, arity}) do
    "#{inspect(module)}.#{function}/#{arity}"
  end

  defp symbol_name(:constant, {module, function, arity}) do
    "#{inspect(module)}.#{function}/#{arity}"
  end

  defp symbol_name(:class, {module, type, arity}) do
    "#{inspect(module)}.#{type}/#{arity}"
  end

  defp symbol_name(:event, {module, callback, arity}) do
    "#{inspect(module)}.#{callback}/#{arity}"
  end

  @spec container_name(atom, symbol_t) :: String.t() | nil
  defp container_name(kind, _module) when kind in @module_kinds, do: nil

  defp container_name(_, {module, _, _}) do
    inspect(module)
  end

  @spec build_range(:erl_anno.anno()) :: range_t
  defp build_range(annotation) do
    line = max(:erl_anno.line(annotation), 1) - 1
    # we don't care about utf16 positions here as we send 0
    # it's not worth to present column info here
    %{
      start: %{line: line, character: 0},
      end: %{line: line + 1, character: 0}
    }
  end

  # As defined by SymbolTag in https://microsoft.github.io/language-server-protocol/specifications/specification-current/
  defp tag_to_code(:deprecated), do: 1

  defp metadata_to_tags(metadata) do
    # As of Language Server Protocol Specification - 3.17 only one tag is supported
    case metadata[:deprecated] do
      nil -> []
      _ -> [tag_to_code(:deprecated)]
    end
  end
end
