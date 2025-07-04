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
  import ElixirLS.DebugAdapter.Protocol.Basic

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
        error_code,
        message,
        format,
        variables,
        send_telemetry,
        show_user
      ) do
    GenServer.call(
      server,
      {:send_error_response, request_packet, error_code, message, format, variables,
       send_telemetry, show_user},
      :infinity
    )
  end

  def send_event(server \\ __MODULE__, body) do
    GenServer.call(server, {:send_event, body}, :infinity)
  end

  def debugger_console(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, %GenDAP.Events.OutputEvent{
      seq: nil,
      body: %{category: "console", output: maybe_append_newline(str)}
    })
  end

  def debugger_important(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, %GenDAP.Events.OutputEvent{
      seq: nil,
      body: %{
        category: "important",
        output: maybe_append_newline(str)
      }
    })
  end

  def debuggee_out(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, %GenDAP.Events.OutputEvent{
      seq: nil,
      body: %{category: "stdout", output: maybe_append_newline(str)}
    })
  end

  def debuggee_err(server \\ __MODULE__, str) when is_binary(str) do
    send_event(server, %GenDAP.Events.OutputEvent{
      seq: nil,
      body: %{category: "stderr", output: maybe_append_newline(str)}
    })
  end

  def ex_unit_event(server \\ __MODULE__, data) when is_map(data) do
    send_event(server, %GenDAP.Events.OutputEvent{
      seq: nil,
      body: %{category: "ex_unit", output: "", data: data}
    })
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

    send_event(server, %GenDAP.Events.OutputEvent{
      seq: nil,
      body: %{
        category: "telemetry",
        output: event,
        data: %{
          "name" => event,
          "properties" => Map.merge(common_properties, properties),
          "measurements" => measurements
        }
      }
    })
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
  def handle_call({:send_response, request_packet, body = %struct{}}, _from, seq) do
    {:ok, dumped_body} =
      SchematicV.dump(struct.schematic(), %{body | seq: seq, request_seq: request_packet["seq"]})

    res = WireProtocol.send(dumped_body)

    {:reply, res, seq + 1}
  end

  def handle_call({:send_response, request_packet, body}, _from, seq) do
    res = WireProtocol.send(response(seq, request_packet["seq"], request_packet["command"], body))
    {:reply, res, seq + 1}
  end

  def handle_call(
        {:send_error_response, request_packet, error_code, message, format, variables,
         send_telemetry, show_user},
        _from,
        seq
      ) do
    {:ok, dumped_error} =
      SchematicV.dump(
        GenDAP.Structures.ErrorResponse.schematic(),
        %GenDAP.Structures.ErrorResponse{
          seq: seq,
          request_seq: request_packet["seq"],
          command: request_packet["command"],
          type: "response",
          success: false,
          message: message,
          body: %{
            error: %GenDAP.Structures.Message{
              id: error_code,
              format: format,
              variables: variables,
              send_telemetry: send_telemetry,
              show_user: show_user
            }
          }
        }
      )

    res = WireProtocol.send(dumped_error)

    {:reply, res, seq + 1}
  end

  def handle_call({:send_event, body = %struct{seq: _}}, _from, seq) do
    # IO.warn(inspect(%{body | seq: seq}))
    {:ok, dumped_event} = SchematicV.dump(struct.schematic(), %{body | seq: seq})
    # IO.warn(inspect(dumped_event))
    res = WireProtocol.send(dumped_event)
    {:reply, res, seq + 1}
  end
end
