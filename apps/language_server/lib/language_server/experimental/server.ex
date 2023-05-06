defmodule ElixirLS.LanguageServer.Experimental.Server do
  alias ElixirLS.LanguageServer.Experimental.Provider
  alias LSP.Notifications
  alias LSP.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Responses
  alias ElixirLS.LanguageServer.Experimental.Server.State

  import Logger
  import Notifications, only: [notification: 1]
  import Requests, only: [request: 2]

  use GenServer

  @spec response_complete(Requests.request(), Responses.response()) :: :ok
  def response_complete(request, response) do
    GenServer.call(__MODULE__, {:response_complete, request, response})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, State.new()}
  end

  def handle_call({:response_complete, _request, _response}, _from, %State{} = state) do
    {:reply, :ok, state}
  end

  def handle_cast({:receive_packet, request(_id, method) = request}, %State{} = state) do
    new_state =
      with {:ok, request} <- Requests.decode(method, request),
           {:ok, new_state} <- handle_request(request, %State{} = state) do
        new_state
      else
        {:error, {:unknown_request, _}} ->
          state

        error ->
          error("Could not decode request #{method} #{inspect(error)}")
          state
      end

    {:noreply, new_state}
  end

  def handle_cast({:receive_packet, notification(method) = notification}, %State{} = state) do
    new_state =
      with {:ok, notification} <- Notifications.decode(method, notification),
           {:ok, new_state} <- handle_notification(notification, %State{} = state) do
        new_state
      else
        {:error, {:unknown_notification, _}} ->
          state

        error ->
          error("Failed to handle #{method} #{inspect(error)}")
          state
      end

    {:noreply, new_state}
  end

  def handle_cast(other, %State{} = state) do
    info("got other: #{inspect(other)}")

    {:noreply, state}
  end

  def handle_info(:default_config, %State{configuration: nil} = state) do
    Logger.warn(
      "Did not receive workspace/didChangeConfiguration notification after 5 seconds. " <>
        "Using default settings."
    )

    {:ok, config} = State.default_configuration(state.configuration)
    {:noreply, %State{state | configuration: config}}
  end

  def handle_info(:default_config, %State{} = state) do
    {:noreply, state}
  end

  def handle_request(%Requests.Initialize{} = initialize, %State{} = state) do
    Logger.info("handling initialize")
    Process.send_after(self(), :default_config, :timer.seconds(5))

    case State.initialize(state, initialize) do
      {:ok, _state} = success ->
        success

      error ->
        {error, state}
    end
  end

  def handle_request(request, %State{} = state) do
    Provider.Queue.add(request, state.configuration)

    {:ok, %State{} = state}
  end

  def handle_notification(notification, %State{} = state) do
    case apply_to_state(state, notification) do
      {:ok, _} = success ->
        success

      error ->
        error("Failed to handle #{notification.__struct__}, #{inspect(error)}")
    end
  end

  defp apply_to_state(%State{} = state, %{} = request_or_notification) do
    case State.apply(state, request_or_notification) do
      {:ok, new_state} -> {:ok, new_state}
      error -> {error, state}
    end
  end
end
