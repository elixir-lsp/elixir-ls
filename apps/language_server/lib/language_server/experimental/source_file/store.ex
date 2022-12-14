defmodule ElixirLS.LanguageServer.Experimental.SourceFile.Store do
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  defmodule State do
    alias ElixirLS.LanguageServer.Experimental.SourceFile.Store
    defstruct source_files: %{}
    @type t :: %__MODULE__{}
    def new do
      %__MODULE__{}
    end

    @spec fetch(t, Store.uri()) :: {:ok, SourceFile.t()} | {:error, :not_open}
    def fetch(%__MODULE__{} = store, uri) do
      case Map.fetch(store.source_files, uri) do
        :error -> {:error, :not_open}
        success -> success
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

    defp normalize_error(:error), do: {:error, :not_open}
    defp normalize_error(e), do: e
  end

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

  @spec open(uri(), String.t(), pos_integer()) :: :ok | {:error, :already_open}
  def open(uri, text, version) do
    GenServer.call(__MODULE__, {:open, uri, text, version})
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
end
