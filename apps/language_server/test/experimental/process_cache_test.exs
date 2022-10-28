defmodule ElixirLS.LanguageServer.Experimental.ProcessCacheTest do
  alias ElixirLS.LanguageServer.Experimental.ProcessCache
  import ProcessCache
  use ExUnit.Case
  use Patch

  setup do
    expose(ProcessCache.Entry, now_ts: 0)
    {:ok, now: 1}
  end

  test "calls the compute function" do
    assert 3 == trans("my key", fn -> 3 end)
  end

  test "pulls from the process cache when an entry exists" do
    assert 3 == trans("my key", fn -> 3 end)
    assert 3 == trans("my key", fn -> 6 end)
  end

  test "times out after a given timeout", ctx do
    now = ctx.now

    patch(ProcessCache.Entry, :now_ts, cycle([now, now + 4999, now + 5000]))

    assert 3 == trans("my key", fn -> 3 end)
    assert {:ok, 3} == fetch("my key")
    assert :error == fetch("my key")
  end

  test "calling get also clears the key after the timeout", ctx do
    now = ctx.now

    patch(ProcessCache.Entry, :now_ts, cycle([now, now + 4999, now + 5000]))

    assert 3 == trans("my key", fn -> 3 end)
    assert 3 == get("my key")
    assert nil == get("my key")
  end

  test "the timeout is configurable", ctx do
    now = ctx.now
    patch(ProcessCache.Entry, :now_ts, cycle([now, now + 49, now + 50]))

    assert 3 = trans("my key", 50, fn -> 3 end)
    assert {:ok, 3} == fetch("my key")
    assert :error == fetch("my key")
  end

  test "trans will replace an expired key", ctx do
    now = ctx.now
    patch(ProcessCache.Entry, :now_ts, cycle([now, now + 49, now + 50]))

    assert 3 = trans("my key", 50, fn -> 3 end)
    assert 3 = trans("my key", 50, fn -> 6 end)
    assert 6 = trans("my key", 50, fn -> 6 end)
  end
end
