defmodule ElixirLS.DebugAdapter.OutputTest do
  use ExUnit.Case, async: true
  import ElixirLS.DebugAdapter.Protocol.Basic

  alias ElixirLS.DebugAdapter.Output

  setup do
    {:ok, capture} = ElixirLS.Utils.PacketCapture.start_link(self())
    {:ok, output} = Output.start(:output_test)
    Process.group_leader(output, capture)

    on_exit(fn ->
      if Process.alive?(output), do: GenServer.stop(output)
    end)

    {:ok, %{output: output}}
  end

  test "error response uses provided id", %{output: output} do
    req = request(1, "cmd")
    Output.send_error_response(output, req, 42, "err", "fmt", %{}, false, false)

    assert_receive %{
      "body" => %{"error" => %{"id" => 42}},
      "seq" => 1,
      "request_seq" => 1
    }
  end
end
