defmodule ElixirLS.DebugAdapter.Output do
  @moduledoc """
  Implements the JSON-based request protocol for VS Code debug adapters.

  VS Code debug protocol specifies that a message is either a request, a response, or an event.
  All messages must include a sequence number. This server keeps a counter to ensure that messages
  are sent with sequence numbers that are unique and sequential, and includes client functions for
  sending these messages.
  """
  alias ElixirLS.Utils.WireProtocol
  use GenServer
  use ElixirLS.DebugAdapter.Protocol

  ## Client API

  def start(name \\ __MODULE__) do
    GenServer.start(__MODULE__, :ok, name: name)
  end

  def send_response(server \\ __MODULE__, request_packet, response_body) do
    GenServer.call(server, {:send_response, request_packet, response_body}, :infinity)
  end

  def send_error_response(
        server \\ __MODULE__,
        request_packet,
        message,
        format,
        variables,
        send_telemetry,
        show_user
      ) do
    GenServer.call(
      server,
      {:send_error_response, request_packet, message, format, variables, send_telemetry,
       show_user},
      :infinity
    )
  end

  def send_event(server \\ __MODULE__, event, body) do
    GenServer.call(server, {:send_event, event, body}, :infinity)
  end

  def send_event_(server \\ __MODULE__, body) do
    GenServer.call(server, {:send_event_, body}, :infinity)
  end

  def debugger_console(server \\ __MODULE__, str) when is_binary(str) do
    send_event_(server, %GenDAP.Events.OutputEvent{seq: nil, body: %{category: "console", output: maybe_append_newline(str)}})
  end

  def debugger_important(server \\ __MODULE__, str) when is_binary(str) do
    send_event_(server, %GenDAP.Events.OutputEvent{seq: nil, body: %{
      category: "important",
      output: maybe_append_newline(str)
    }})
  end

  def debuggee_out(server \\ __MODULE__, str) when is_binary(str) do
    send_event_(server, %GenDAP.Events.OutputEvent{seq: nil, body: %{category: "stdout", output: maybe_append_newline(str)}})
  end

  def debuggee_err(server \\ __MODULE__, str) when is_binary(str) do
    send_event_(server, %GenDAP.Events.OutputEvent{seq: nil, body: %{category: "stderr", output: maybe_append_newline(str)}})
  end

  def ex_unit_event(server \\ __MODULE__, data) when is_map(data) do
    send_event_(server, %GenDAP.Events.OutputEvent{seq: nil, body: %{category: "ex_unit", output: "", data: data}})
  end

  def telemetry(server \\ __MODULE__, event, properties, measurements)
      when is_binary(event) and is_map(properties) and is_map(measurements) do
    elixir_release =
      case Regex.run(~r/^(\d+\.\d+)/, System.version()) do
        [_, version] -> version
        nil -> "unknown"
      end

    common_properties = %{
      "elixir_ls.elixir_release" => elixir_release,
      "elixir_ls.elixir_version" => System.version(),
      "elixir_ls.otp_release" => System.otp_release(),
      "elixir_ls.erts_version" => to_string(Application.spec(:erts, :vsn)),
      "elixir_ls.mix_env" => Mix.env(),
      "elixir_ls.mix_target" => Mix.target()
    }

    send_event_(server, %GenDAP.Events.OutputEvent{seq: nil, body: %{
      category: "telemetry",
      output: event,
      data: %{
        "name" => event,
        "properties" => Map.merge(common_properties, properties),
        "measurements" => measurements
      }
    }})
  end

  defp maybe_append_newline(message) do
    unless String.ends_with?(message, "\n") do
      message <> "\n"
    else
      message
    end
  end

  ## Server callbacks

  @impl GenServer
  def init(:ok) do
    {:ok, 1}
  end

  @impl GenServer
  def handle_call({:send_response, request_packet, body}, _from, seq) do
    res = WireProtocol.send(response(seq, request_packet["seq"], request_packet["command"], body))
    {:reply, res, seq + 1}
  end

  def handle_call(
        {:send_error_response, request_packet, message, format, variables, send_telemetry,
         show_user},
        _from,
        seq
      ) do
    res =
      WireProtocol.send(
        error_response(
          seq,
          request_packet["seq"],
          request_packet["command"],
          message,
          format,
          variables,
          send_telemetry,
          show_user
        )
      )

    {:reply, res, seq + 1}
  end

  def handle_call({:send_event, event, body}, _from, seq) do
    dumped_event = event(seq, event, body)
    IO.warn(inspect(dumped_event))
    res = WireProtocol.send(dumped_event)
    {:reply, res, seq + 1}
  end

  def handle_call({:send_event_, body = %struct{seq: _}}, _from, seq) do
    # IO.warn(inspect(%{body | seq: seq}))
    {:ok, dumped_event} = Schematic.dump(struct.schematic(), %{body | seq: seq})
    # IO.warn(inspect(dumped_event))
    res = WireProtocol.send(dumped_event)
    {:reply, res, seq + 1}
  end
end
