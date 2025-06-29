defmodule ElixirLS.LanguageServer.MixProjectCacheTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.MixProjectCache

  setup do
    {:ok, pid} = start_supervised(MixProjectCache)
    %{pid: pid}
  end

  test "returns not_loaded when state is nil", %{pid: pid} do
    assert {:error, :not_loaded} = MixProjectCache.get()
    assert {:error, :not_loaded} = MixProjectCache.config()
    assert Process.alive?(pid)
  end
end
