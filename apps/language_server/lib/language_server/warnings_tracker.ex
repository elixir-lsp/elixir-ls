defmodule ElixirLS.LanguageServer.WarningsTracker do
  @moduledoc """
  Replaces registered process :standard_error and records warnings that are printed

  Unfortunately, the Elixir compiler doesn't keep track of warnings it emits, it simply prints them
  to the console. In order to intercept them, we replace the registered process :standard_error
  with this server. It checks the content of any IO output sent to it for warnings, and records the
  warnings if it finds any and forwards the request to the original :standard_error process
  otherwise.
  """

  alias ElixirLS.LanguageServer.BuildError
  use GenServer

  defstruct [
    original_device: nil, 
    warnings: []
  ]

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, %__MODULE__{})
  end

  def stop do
    GenServer.stop(:standard_error)
  end

  def warnings do
    GenServer.call(:standard_error, :warnings)
  end

  ## Server Callbacks

  def init(s) do
    s = %{s | original_device: Process.whereis(:standard_error)}
    Process.unregister(:standard_error)
    Process.register(self(), :standard_error)
    {:ok, s}
  end

  def handle_call(:warnings, _from, s) do
    {:reply, s.warnings, s}
  end

  def handle_call(call, from, s) do
    super(call, from, s)
  end

  def handle_info(req = {:io_request, from, reply_as, {:put_chars, _encoding, characters}}, s) do
    warnings = BuildError.warnings_from_log(to_string(characters))

    s = 
      if warnings == [] do
        send(s.original_device, req)
        s
      else
        send(from, {:io_reply, reply_as, :ok})
        %{s | warnings: s.warnings ++ warnings}
      end

    {:noreply, s}
  end

  def handle_info(req = {:io_request, _, _, _}, s) do
    send(s.device_pid, req)
    {:noreply, s}
  end

  def handle_info(msg, s) do
    super(msg, s)
  end

  def terminate(reason, s) do
    Process.unregister(:standard_error)
    Process.register(s.original_device, :standard_error)
    super(reason, s)
  end

end