defmodule ElixirLS.DebugAdapter.ThreadRegistry do
  @moduledoc """
  Registry for managing thread ID to PID mappings.

  This module provides bidirectional mapping between Debug Adapter Protocol
  thread IDs and Erlang PIDs, using the global IdManager for ID allocation.
  """

  alias ElixirLS.DebugAdapter.IdManager

  defstruct thread_ids_to_pids: %{},
            pids_to_thread_ids: %{}

  @type t :: %__MODULE__{
          thread_ids_to_pids: %{integer() => pid()},
          pids_to_thread_ids: %{pid() => integer()}
        }

  @doc """
  Creates a new empty thread registry.
  """
  def new, do: %__MODULE__{}

  @doc """
  Ensures a PID has a thread ID, creating one if necessary.
  Returns {registry, thread_id, new_ids}.
  """
  def ensure_thread_id(registry = %__MODULE__{}, pid, new_ids) when is_pid(pid) do
    case registry.pids_to_thread_ids do
      %{^pid => thread_id} ->
        {registry, thread_id, new_ids}

      _ ->
        id = IdManager.next_id()

        registry = %{
          registry
          | thread_ids_to_pids: Map.put(registry.thread_ids_to_pids, id, pid),
            pids_to_thread_ids: Map.put(registry.pids_to_thread_ids, pid, id)
        }

        {registry, id, [id | new_ids]}
    end
  end

  @doc """
  Ensures multiple PIDs have thread IDs.
  Returns {registry, thread_ids, new_ids}.
  """
  def ensure_thread_ids(registry = %__MODULE__{}, pids) do
    {registry, ids, new_ids} =
      Enum.reduce(pids, {registry, [], []}, fn pid, {registry, ids, new_ids} ->
        {registry, id, new_ids} = ensure_thread_id(registry, pid, new_ids)
        {registry, [id | ids], new_ids}
      end)

    {registry, Enum.reverse(ids), Enum.reverse(new_ids)}
  end

  @doc """
  Gets the PID for a given thread ID.
  Returns {:ok, pid} or :error.
  """
  def get_pid_by_thread_id(registry = %__MODULE__{}, thread_id) do
    Map.fetch(registry.thread_ids_to_pids, thread_id)
  end

  @doc """
  Gets the thread ID for a given PID.
  Returns {:ok, thread_id} or :error.
  """
  def get_thread_id_by_pid(registry = %__MODULE__{}, pid) do
    Map.fetch(registry.pids_to_thread_ids, pid)
  end

  @doc """
  Removes a PID and its associated thread ID from the registry.
  Returns {thread_id, updated_registry}.
  """
  def remove_pid(registry = %__MODULE__{}, pid) do
    {thread_id, pids_to_thread_ids} = Map.pop(registry.pids_to_thread_ids, pid)

    registry = %{
      registry
      | thread_ids_to_pids: Map.delete(registry.thread_ids_to_pids, thread_id),
        pids_to_thread_ids: pids_to_thread_ids
    }

    {thread_id, registry}
  end

  @doc """
  Gets all thread IDs currently in the registry.
  """
  def all_thread_ids(registry = %__MODULE__{}) do
    Map.keys(registry.thread_ids_to_pids)
  end

  @doc """
  Gets all PIDs currently in the registry.
  """
  def all_pids(registry = %__MODULE__{}) do
    Map.keys(registry.pids_to_thread_ids)
  end
end
