defmodule ElixirLS.DebugAdapter.CompilationListener do
  @moduledoc """
  Server that tracks compilation in other OS processes
  https://hexdocs.pm/mix/1.18.1/Mix.Task.Compiler.html#module-listening-to-compilation
  """

  use GenServer
  alias ElixirLS.DebugAdapter.Output

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.delete(args, :name),
      name: Keyword.get(args, :name, __MODULE__)
    )
  end

  @impl GenServer
  def init(_args) do
    Output.debugger_console("Starting compilation listener")
    {:ok, :ok}
  end

  @impl GenServer
  def terminate(reason, _state) do
    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        message = Exception.format_exit(reason)

        Output.telemetry(
          "dap_server_error",
          %{
            "elixir_ls.dap_process" => inspect(__MODULE__),
            "elixir_ls.dap_server_error" => message
          },
          %{}
        )

        Output.debugger_important("Terminating #{__MODULE__}: #{message}")
    end

    :ok
  end

  @impl GenServer
  def handle_info({:modules_compiled, info} = msg, state) do
    Output.debugger_console(inspect(msg))
    {:noreply, state}
  end

  def handle_info({:dep_compiled, info} = msg, state) do
    Output.debugger_console(inspect(msg))
    {:noreply, state}
  end

  def handle_info(message, state) do
    # catch-all
    # as stated in https://hexdocs.pm/mix/1.18.1/Mix.Task.Compiler.html#module-listening-to-compilation
    # new messages may be added in future releases.
    Output.debugger_console("Unhandled message in #{__MODULE__}: #{inspect(message)}")
    {:noreply, state}
  end
end
