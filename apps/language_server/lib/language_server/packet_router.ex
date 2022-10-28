defmodule ElixirLS.LanguageServer.PacketRouter do
  defmodule State do
    defstruct monitor_references: %{}, names_to_pids: %{}

    def new(names_or_pids) when is_list(names_or_pids) do
      Enum.reduce(names_or_pids, %__MODULE__{}, &add(&2, &1))
    end

    def add(%__MODULE__{} = state, pid) when is_pid(pid) do
      new_monitors = Map.put(state.monitor_references, Process.monitor(pid), pid)
      %__MODULE__{state | monitor_references: new_monitors}
    end

    def add(%__MODULE__{} = state, name) do
      add(state, Process.whereis(name))
    end

    def delete_ref(%__MODULE__{} = state, ref) when is_reference(ref) do
      new_references = Map.pop(state.monitor_references, ref)
      %__MODULE__{state | monitor_references: new_references}
    end

    def broadcast(%__MODULE__{} = state, type, message) do
      broadcast_fn =
        case type do
          :call -> &GenServer.call/2
          :cast -> &GenServer.cast/2
          :info -> &send/2
        end

      state.monitor_references
      |> Map.values()
      |> Enum.each(fn pid ->
        broadcast_fn.(pid, message)
      end)

      state
    end
  end

  use GenServer

  def registrations do
    GenServer.call(__MODULE__, :registrations)
  end

  def receive_packet(packet) do
    broadcast_cast({:receive_packet, packet})
  end

  def register do
    GenServer.call(__MODULE__, {:register, self()})
  end

  def broadcast_call(message) do
    GenServer.cast(__MODULE__, {:broadcast, :call, message})
  end

  def broadcast_cast(message) do
    GenServer.cast(__MODULE__, {:broadcast, :cast, message})
  end

  def broadcast_info(message) do
    GenServer.cast(__MODULE__, {:broadcast, :info, message})
  end

  def start_link(names_or_pids) do
    GenServer.start_link(__MODULE__, [names_or_pids], name: __MODULE__)
  end

  def init([names_or_pids]) do
    {:ok, State.new(names_or_pids)}
  end

  def handle_call(:registrations, _, %State{} = state) do
    {:reply, Map.values(state.monitor_references), state}
  end

  def handle_call({:register, caller}, _, %State{} = state) do
    new_state = State.add(state, caller)
    {:reply, :ok, new_state}
  end

  def handle_cast({:broadcast, type, message}, %State{} = state) do
    State.broadcast(state, type, message)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _}, %State{} = state) do
    {:noreply, State.delete_ref(state, ref)}
  end
end
