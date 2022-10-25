defmodule ElixirLS.LanguageServer.Experimental.Server do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Notifications
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Server.State

  import Logger
  import Notifications, only: [notification: 1]
  import Requests, only: [request: 2]

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, State.new()}
  end

  def handle_cast({:receive_packet, request(method, _id) = request}, %State{} = state) do
    new_state =
      with {:ok, request} <- Requests.decode(method, request),
           {:ok, new_state} <- handle_request(request, %State{} = state) do
        info("Decoded #{request.__struct__}")
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

  def handle_request(_, %State{} = state) do
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

  defp apply_to_state(%State{} = state, %protocol_module{} = protocol_action) do
    {elapsed_us, result} = :timer.tc(fn -> State.apply(state, protocol_action) end)
    elapsed_ms = Float.round(elapsed_us / 1000, 2)
    method_name = protocol_module.__meta__(:method_name)

    info("#{method_name} took #{elapsed_ms}ms")

    case result do
      {:ok, new_state} -> {:ok, new_state}
      :ok -> {:ok, state}
      error -> {error, state}
    end
  end
end
