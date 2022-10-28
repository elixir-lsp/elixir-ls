defmodule ElixirLS.LanguageServer.Experimental.ProcessCache do
  @moduledoc """
  A simple cache with a timeout that lives in the process dictionary
  """

  defmodule Entry do
    defstruct [:value, :expiry]

    def new(value, timeout_ms) do
      expiry_ts = now_ts() + timeout_ms
      %__MODULE__{value: value, expiry: expiry_ts}
    end

    def valid?(%__MODULE__{} = entry) do
      now_ts() < entry.expiry
    end

    defp now_ts do
      System.os_time(:millisecond)
    end
  end

  @type key :: term()
  @type fetch_result :: {:ok, term()} | :error

  @doc """
  Retrieves a value from the cache
  If the value is not found, the default is returned
  """
  @spec get(key()) :: term() | nil
  @spec get(key(), term()) :: term() | nil
  def get(key, default \\ nil) do
    case fetch(key) do
      {:ok, val} -> val
      :error -> default
    end
  end

  @doc """
  Retrieves a value from the cache
  If the value is not found, the default is returned
  """
  @spec fetch(key()) :: fetch_result()
  def fetch(key) do
    case Process.get(key, :unset) do
      %Entry{} = entry ->
        if Entry.valid?(entry) do
          {:ok, entry.value}
        else
          Process.delete(key)
          :error
        end

      :unset ->
        :error
    end
  end

  @doc """
  Retrieves and optionally sets a value in the cache.

  Trans looks up a value in the cache under key. If that value isn't
  found, the compute_fn is then executed, and its return value is set
  in the cache. The cached value will live in the cache for `timeout`
  milliseconds
  """
  def trans(key, timeout_ms \\ 5000, compute_fn) do
    case fetch(key) do
      :error ->
        set(key, timeout_ms, compute_fn)

      {:ok, result} ->
        result
    end
  end

  defp set(key, timeout_ms, compute_fn) do
    value = compute_fn.()
    Process.put(key, Entry.new(value, timeout_ms))
    value
  end
end
