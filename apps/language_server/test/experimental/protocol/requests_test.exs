defmodule ElixirLS.LanguageServer.Experimental.Protocol.RequestsTest do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  import Requests
  use ExUnit.Case

  defp fixture(opts \\ []) do
    [method: "something/didChange", id: 3, params: %{"foo" => 3, "bar" => 6}]
    |> Keyword.merge(opts)
    |> Enum.reduce(%{"jsonrpc" => "2.0"}, fn
      {_k, :drop}, acc ->
        acc

      {k, v}, acc ->
        Map.put(acc, Atom.to_string(k), v)
    end)
  end

  describe "matching macros" do
    test "can identify a request  with params" do
      request(id, method, params) = fixture()

      assert id == 3
      assert method == "something/didChange"
      assert params == %{"foo" => 3, "bar" => 6}
    end

    test "can identify a request without params" do
      request(id, method) = fixture(params: :drop)

      assert id == 3
      assert method == "something/didChange"
    end

    test "a request's params can be an array" do
      request(_id, _method, params) = fixture(params: [1, 2, 3, 4])
      assert params == [1, 2, 3, 4]
    end

    test "a request's params can be map" do
      request(_id, _method, params) = fixture(params: %{"a" => "b"})

      assert params == %{"a" => "b"}
    end
  end
end
