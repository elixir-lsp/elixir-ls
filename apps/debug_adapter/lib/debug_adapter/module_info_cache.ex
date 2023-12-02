defmodule ElixirLS.DebugAdapter.ModuleInfoCache do
  @moduledoc """
  Caches module_info of interpreted modules. There are cases when module_info call
  may deadlock (https://github.com/elixir-lsp/elixir-ls/issues/940)
  """

  use Agent

  def start_link(args) do
    Agent.start_link(fn -> args end, name: __MODULE__)
  end

  def get(module) do
    Agent.get(__MODULE__, & &1[module])
  end

  def store(module) do
    Agent.update(__MODULE__, fn map ->
      if Map.has_key?(map, module) do
        map
      else
        Map.put(map, module, module.module_info())
      end
    end)
  end

  def clear() do
    Agent.update(__MODULE__, fn _map -> %{} end)
  end
end
