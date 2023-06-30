defmodule LSP.NotificationsTest do
  alias LSP.Notifications
  import Notifications
  use ExUnit.Case

  defp fixture(:notification, opts \\ []) do
    [method: "something/didChange", params: %{"foo" => 3, "bar" => 6}]
    |> Keyword.merge(opts)
    |> Enum.reduce(%{"jsonrpc" => "2.0"}, fn
      {_k, :drop}, acc ->
        acc

      {k, v}, acc ->
        Map.put(acc, Atom.to_string(k), v)
    end)
  end

  describe "matching macros" do
    test "can identify a notification  with params" do
      notification(method, params) = fixture(:notification)

      assert method == "something/didChange"
      assert params == %{"foo" => 3, "bar" => 6}
    end

    test "can identify a notification without params" do
      notification(method) = fixture(:notification, params: :drop)

      assert method == "something/didChange"
    end

    test "a notification's params can be an array" do
      notification(_method, params) = fixture(:notification, params: [1, 2, 3, 4])
      assert params == [1, 2, 3, 4]
    end

    test "a notification's params can be map" do
      notification(_method, params) = fixture(:notification, params: %{"a" => "b"})

      assert params == %{"a" => "b"}
    end
  end
end
