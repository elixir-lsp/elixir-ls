defmodule ElixirLS.DebugAdapter.IdManager do
  @moduledoc """
  Global ID manager for Debug Adapter Protocol objects.

  Uses ERTS :atomics module for thread-safe, shared mutable counters
  that can be accessed from any process without blocking.
  """

  @counter_ref :dap_id_counter

  @doc """
  Initializes the global ID counter.
  Should be called once during server startup.
  """
  def init do
    # Create a single atomic counter starting at 1
    counter = :atomics.new(1, [])
    :atomics.put(counter, 1, 1)
    :persistent_term.put(@counter_ref, counter)
    :ok
  end

  @doc """
  Gets the next unique ID atomically.
  This is thread-safe and can be called from any process.
  """
  def next_id do
    case :persistent_term.get(@counter_ref, nil) do
      nil ->
        raise "IdManager not initialized. Call IdManager.init/0 first."

      counter ->
        :atomics.add_get(counter, 1, 1)
    end
  end

  @doc """
  Cleans up the global ID counter.
  Should be called during server shutdown.
  """
  def cleanup do
    :persistent_term.erase(@counter_ref)
    :ok
  end

  @doc """
  Gets the current ID value without incrementing.
  Mainly for testing/debugging purposes.
  """
  def current_id do
    case :persistent_term.get(@counter_ref, nil) do
      nil ->
        raise "IdManager not initialized. Call IdManager.init/0 first."

      counter ->
        :atomics.get(counter, 1)
    end
  end
end
