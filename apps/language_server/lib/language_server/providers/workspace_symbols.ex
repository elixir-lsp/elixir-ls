defmodule ElixirLS.LanguageServer.Providers.WorkspaceSymbols do
  @moduledoc """
  Workspace Symbols provider. Generates and returns `SymbolInformation[]`.

  https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#workspace_symbol
  """
  use GenServer

  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Providers.DocumentSymbols
  alias ElixirLS.LanguageServer.Protocol.SymbolInformation

  @spec symbols(String.t(), module()) :: {:ok, [SymbolInformation.t()]}
  def symbols(query, server \\ __MODULE__) do
    results = query(query, server)

    {:ok, results}
  end

  defp query(query, server) do
    query = String.trim(query)

    case query do
      "" ->
        GenServer.call(server, :all_symbols)

      query ->
        GenServer.call(server, {:query, query})
    end
  end

  def set_paths(paths, server \\ __MODULE__, override_test_mode \\ false) do
    unless Application.get_env(:language_server, :test_mode) && not override_test_mode do
      GenServer.call(server, {:paths, paths})
    end
  end

  @spec notify_uris_modified([String.t()]) :: :ok
  def notify_uris_modified(uris, server \\ __MODULE__, override_test_mode \\ false) do
    unless Application.get_env(:language_server, :test_mode) && not override_test_mode do
      GenServer.cast(server, {:uris_modified, uris})
    end
  end

  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      Keyword.get(opts, :args, []),
      Keyword.put_new(opts, :name, __MODULE__)
    )
  end

  ## Server Callbacks

  @impl GenServer
  def init(args) do
    if Keyword.has_key?(args, :paths) do
      {:ok,
       %{
         symbols: Map.new(),
         paths: Keyword.get(args, :paths),
         log?: Keyword.get(args, :log?, false)
       }, {:continue, :index}}
    else
      {:ok,
       %{
         symbols: Map.new(),
         paths: Keyword.get(args, :paths),
         log?: Keyword.get(args, :log?, false)
       }}
    end
  end

  @impl GenServer
  def handle_continue(:index, state) do
    symbols = index(state.paths, state)

    {:noreply, %{state | symbols: symbols}}
  end

  defp index(paths, state) do
    show(state, :log, "[ElixirLS WorkspaceSymbols] Indexing...")

    root_paths = paths

    paths = Enum.flat_map(root_paths, fn rp -> Path.wildcard("#{rp}/**/*.{ex,exs}") end)

    symbols =
      for file <- paths, into: %{} do
        file = Path.absname(file)
        uri = "file://#{file}"

        with {:ok, source_file_text} <- File.read(file),
             {:ok, symbols} <- DocumentSymbols.symbols(uri, source_file_text, false) do
          {uri, symbols}
        else
          _ ->
            {uri, []}
        end
      end

    show(state, :log, "[ElixirLS WorkspaceSymbols] Finished indexing!")

    symbols
  end

  @impl GenServer
  def handle_call({:paths, paths}, _from, state) do
    symbols = index(paths, state)

    {:reply, :ok, %{state | paths: paths, symbols: symbols}}
  end

  def handle_call({:query, _query}, _from, %{paths: nil} = state) do
    {:reply, [], state}
  end

  def handle_call({:query, query}, from, state) do
    log(state, :info, "[ElixirLS WorkspaceSymbols] Querying...")

    {:ok, _pid} =
      Task.start_link(fn ->
        results =
          state.symbols
          |> Map.values()
          |> List.flatten()
          |> Enum.map(fn %{name: name} = symbol ->
            {String.jaro_distance(String.downcase(name), String.downcase(query)), symbol}
          end)
          |> Enum.filter(fn {score, _} -> score > 0.1 end)
          |> Enum.sort_by(fn {score, _} -> score end, &>=/2)
          |> Enum.map(fn {_, symbol} -> symbol end)

        GenServer.reply(from, results)
      end)

    {:noreply, state}
  end

  def handle_call(:all_symbols, _from, %{paths: nil} = state) do
    {:reply, [], state}
  end

  def handle_call(:all_symbols, from, state) do
    log(state, :info, "[ElixirLS WorkspaceSymbols] Empty query, returning all symbols!")

    {:ok, _pid} =
      Task.start_link(fn ->
        results =
          state.symbols
          |> Map.values()
          |> List.flatten()

        GenServer.reply(from, results)
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:uris_modified, uris}, state) do
    show(state, :log, "[ElixirLS WorkspaceSymbols] Indexing...")

    symbols =
      for uri <- uris, into: state.symbols do
        file = URI.parse(uri).path

        with {:ok, source_file_text} <- File.read(file),
             {:ok, symbols} <- DocumentSymbols.symbols(uri, source_file_text, false) do
          {uri, symbols}
        else
          _ ->
            {uri, []}
        end
      end

    show(state, :log, "[ElixirLS WorkspaceSymbols] Finished indexing!")

    {:noreply, %{state | symbols: symbols}}
  end

  defp log(state, type, message) do
    if state.log? do
      JsonRpc.log_message(type, message)
    end
  end

  defp show(state, type, message) do
    if state.log? do
      JsonRpc.show_message(type, message)
    end
  end
end
