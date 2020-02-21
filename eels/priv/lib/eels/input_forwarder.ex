defmodule Eels.InputForwarder do
  @moduledoc """
  Sends (LSP) commands that appear on stdin on to the language server.
  """

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker
    }
  end

  def start_link() do
    Task.start_link(&read_loop/0)
  end

  defp read_loop do
    input = IO.read(:stdin, :line)
    Eels.LSClient.send_input_data(input)
    read_loop()
  end
end
