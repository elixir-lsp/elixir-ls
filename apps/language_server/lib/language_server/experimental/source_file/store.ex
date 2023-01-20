defmodule ElixirLS.LanguageServer.Experimental.SourceFile.Store do
  defmodule State do
    alias ElixirLS.LanguageServer.Experimental.SourceFile
    alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
    alias ElixirLS.LanguageServer.Experimental.SourceFile.Store
    require Logger

    defstruct source_files: %{}, temp_files: %{}, temporary_open_refs: %{}
    @type t :: %__MODULE__{}
    def new do
      %__MODULE__{}
    end

    @spec fetch(t, Store.uri()) :: {:ok, SourceFile.t()} | {:error, :not_open}
    def fetch(%__MODULE__{} = store, uri) do
      with :error <- Map.fetch(store.source_files, uri),
           :error <- Map.fetch(store.temp_files, uri) do
        {:error, :not_open}
      end
    end

    @spec save(t, Store.uri()) :: {:ok, t()} | {:error, :not_open}
    def save(%__MODULE__{} = store, uri) do
      case Map.fetch(store.source_files, uri) do
        {:ok, source_file} ->
          source_file = SourceFile.mark_clean(source_file)
          store = %__MODULE__{store | source_files: Map.put(store.source_files, uri, source_file)}
          {:ok, store}

        :error ->
          {:error, :not_open}
      end
    end

    @spec open(t, Store.uri(), String.t(), pos_integer()) :: {:ok, t} | {:error, :already_open}
    def open(%__MODULE__{} = store, uri, text, version) do
      case Map.fetch(store.source_files, uri) do
        {:ok, _} ->
          {:error, :already_open}

        :error ->
          source_file = SourceFile.new(uri, text, version)
          store = %__MODULE__{store | source_files: Map.put(store.source_files, uri, source_file)}
          {:ok, store}
      end
    end

    def open?(%__MODULE__{} = store, uri) do
      Map.has_key?(store.source_files, uri) or Map.has_key?(store.temp_files, uri)
    end

    def close(%__MODULE__{} = store, uri) do
      case Map.pop(store.source_files, uri) do
        {nil, _store} ->
          {:error, :not_open}

        {_, source_files} ->
          store = %__MODULE__{store | source_files: source_files}
          {:ok, store}
      end
    end

    def get_and_update(%__MODULE__{} = store, uri, updater_fn) do
      with {:ok, source_file} <- fetch(store, uri),
           {:ok, updated_source} <- updater_fn.(source_file) do
        new_store = %__MODULE__{
          store
          | source_files: Map.put(store.source_files, uri, updated_source)
        }

        {:ok, updated_source, new_store}
      else
        error ->
          normalize_error(error)
      end
    end

    def update(%__MODULE__{} = store, uri, updater_fn) do
      with {:ok, _, new_store} <- get_and_update(store, uri, updater_fn) do
        {:ok, new_store}
      end
    end

    def open_temporarily(%__MODULE__{} = store, path_or_uri, timeout) do
      uri = Conversions.ensure_uri(path_or_uri)
      path = Conversions.ensure_path(path_or_uri)

      with {:ok, contents} <- File.read(path) do
        source_file = SourceFile.new(uri, contents, 0)
        ref = schedule_unload(uri, timeout)

        new_refs =
          store
          |> maybe_cancel_old_ref(uri)
          |> Map.put(uri, ref)

        temp_files = Map.put(store.temp_files, uri, source_file)

        new_store = %__MODULE__{store | temp_files: temp_files, temporary_open_refs: new_refs}

        {:ok, source_file, new_store}
      end
    end

    def extend_timeout(%__MODULE__{} = store, uri, timeout) do
      case store.temporary_open_refs do
        %{^uri => ref} ->
          Process.cancel_timer(ref)
          new_ref = schedule_unload(uri, timeout)
          new_open_refs = Map.put(store.temporary_open_refs, uri, new_ref)
          %__MODULE__{store | temporary_open_refs: new_open_refs}

        _ ->
          store
      end
    end

    def unload(%__MODULE__{} = store, uri) do
      new_refs = Map.delete(store.temporary_open_refs, uri)
      temp_files = Map.delete(store.temp_files, uri)

      %__MODULE__{
        store
        | temp_files: temp_files,
          temporary_open_refs: new_refs
      }
    end

    defp maybe_cancel_old_ref(%__MODULE__{} = store, uri) do
      {_, new_refs} =
        Map.get_and_update(store.temporary_open_refs, uri, fn
          nil ->
            :pop

          old_ref when is_reference(old_ref) ->
            Process.cancel_timer(old_ref)
            :pop
        end)

      new_refs
    end

    defp schedule_unload(uri, timeout) do
      Process.send_after(self(), {:unload, uri}, timeout)
    end

    defp normalize_error(:error), do: {:error, :not_open}
    defp normalize_error(e), do: e
  end

  alias ElixirLS.LanguageServer.Experimental.ProcessCache
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  import ElixirLS.LanguageServer.Experimental.Log

  @type t :: %State{}

  @type uri :: String.t()
  @type updater :: (SourceFile.t() -> {:ok, SourceFile.t()} | {:error, any()})

  use GenServer

  @spec fetch(uri()) :: {:ok, SourceFile.t()} | :error
  def fetch(uri) do
    GenServer.call(__MODULE__, {:fetch, uri})
  end

  @spec save(uri()) :: :ok | {:error, :not_open}
  def save(uri) do
    GenServer.call(__MODULE__, {:save, uri})
  end

  @spec open?(uri()) :: boolean()
  def open?(uri) do
    GenServer.call(__MODULE__, {:open?, uri})
  end

  @spec open(uri(), String.t(), pos_integer()) :: :ok | {:error, :already_open}
  def open(uri, text, version) do
    GenServer.call(__MODULE__, {:open, uri, text, version})
  end

  def open_temporary(uri, timeout \\ 5000) do
    path = uri |> Conversions.ensure_path() |> Path.basename()
    file_name = Path.basename(path)

    ProcessCache.trans(uri, 50, fn ->
      log_and_time "open temporarily: #{file_name}" do
        GenServer.call(__MODULE__, {:open_temporarily, uri, timeout})
      end
    end)
  end

  @spec close(uri()) :: :ok | {:error, :not_open}
  def close(uri) do
    GenServer.call(__MODULE__, {:close, uri})
  end

  @spec get_and_update(uri(), updater()) :: {SourceFile.t(), State.t()}
  def get_and_update(uri, update_fn) do
    GenServer.call(__MODULE__, {:get_and_update, uri, update_fn})
  end

  @spec update(uri(), updater()) :: :ok | {:error, any()}
  def update(uri, update_fn) do
    GenServer.call(__MODULE__, {:update, uri, update_fn})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, State.new()}
  end

  def handle_call({:fetch, uri}, _, %State{} = state) do
    {reply, new_state} =
      case State.fetch(state, uri) do
        {:ok, _} = success -> {success, state}
        error -> {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:save, uri}, _from, %State{} = state) do
    {reply, new_state} =
      case State.save(state, uri) do
        {:ok, _} = success -> success
        error -> {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:open, uri, text, version}, _from, %State{} = state) do
    {reply, new_state} =
      case State.open(state, uri, text, version) do
        {:ok, _} = success -> success
        error -> {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:open_temporarily, uri, timeout_ms}, _, %State{} = state) do
    {reply, new_state} =
      with {:error, :not_open} <- State.fetch(state, uri),
           {:ok, source_file, new_state} <- State.open_temporarily(state, uri, timeout_ms) do
        {{:ok, source_file}, new_state}
      else
        {:ok, source_file} ->
          new_state = State.extend_timeout(state, uri, timeout_ms)
          {{:ok, source_file}, new_state}

        error ->
          {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:open?, uri}, _from, %State{} = state) do
    {:reply, State.open?(state, uri), state}
  end

  def handle_call({:close, uri}, _from, %State{} = state) do
    {reply, new_state} =
      case State.close(state, uri) do
        {:ok, _} = success -> success
        error -> {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:get_and_update, uri, update_fn}, _from, %State{} = state) do
    {reply, new_state} =
      case State.get_and_update(state, uri, update_fn) do
        {:ok, updated_source, new_state} -> {{:ok, updated_source}, new_state}
        error -> {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:update, uri, updater_fn}, _, %State{} = state) do
    {reply, new_state} =
      case State.update(state, uri, updater_fn) do
        {:ok, _} = success -> success
        error -> {error, state}
      end

    {:reply, reply, new_state}
  end

  def handle_info({:unload, uri}, %State{} = state) do
    {:noreply, State.unload(state, uri)}
  end
end
