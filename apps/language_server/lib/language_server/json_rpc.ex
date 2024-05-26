defmodule ElixirLS.LanguageServer.JsonRpc do
  @moduledoc """
  Macros and functions for JSON RPC

  Contains macros for creating or pattern-matching against packets and helper functions for sending
  responses and notifications
  """

  use GenServer
  alias ElixirLS.LanguageServer
  alias ElixirLS.Utils.WireProtocol

  @default_server LanguageServer.Server

  defstruct language_server: @default_server,
            next_id: 1,
            outgoing_requests: %{}

  ## Macros

  defmacro notification(method, params) do
    quote do
      %{"method" => unquote(method), "params" => unquote(params), "jsonrpc" => "2.0"}
    end
  end

  defmacro notification(method) do
    quote do
      %{"method" => unquote(method), "jsonrpc" => "2.0"}
    end
  end

  defmacro request(id, method) do
    quote do
      %{
        "id" => unquote(id),
        "method" => unquote(method),
        "jsonrpc" => "2.0"
      }
    end
  end

  defmacro request(id, method, params) do
    quote do
      %{
        "id" => unquote(id),
        "method" => unquote(method),
        "params" => unquote(params),
        "jsonrpc" => "2.0"
      }
    end
  end

  defmacro response(id, result) do
    quote do
      %{"result" => unquote(result), "id" => unquote(id), "jsonrpc" => "2.0"}
    end
  end

  defmacro error_response(id, code, message) do
    quote do
      %{
        "error" => %{"code" => unquote(code), "message" => unquote(message)},
        "id" => unquote(id),
        "jsonrpc" => "2.0"
      }
    end
  end

  defmacro error_response(id, code, message, data) do
    quote do
      %{
        "error" => %{
          "code" => unquote(code),
          "message" => unquote(message),
          "data" => unquote(data)
        },
        "id" => unquote(id),
        "jsonrpc" => "2.0"
      }
    end
  end

  ## Utils

  def notify(method, params) do
    WireProtocol.send(notification(method, params))
  end

  def respond(id, result) do
    WireProtocol.send(response(id, result))
  end

  def respond_with_error(id, type, message \\ nil, data \\ nil) do
    {code, default_message} = error_code_and_message(type)

    if data do
      WireProtocol.send(error_response(id, code, message || default_message, data))
    else
      WireProtocol.send(error_response(id, code, message || default_message))
    end
  end

  def show_message(type, message) do
    notify("window/showMessage", %{type: message_type_code(type), message: to_string(message)})
  end

  def log_message(type, message) do
    notify("window/logMessage", %{type: message_type_code(type), message: to_string(message)})
  end

  def telemetry(name, properties, measurements) do
    elixir_release =
      case Regex.run(~r/^(\d+\.\d+)/, System.version()) do
        [_, version] -> version
        nil -> "unknown"
      end

    {mix_env, mix_target} =
      try do
        {Mix.env(), Mix.target()}
      rescue
        ArgumentError ->
          {nil, nil}
      end

    common_properties = %{
      "elixir_ls.elixir_release" => elixir_release,
      "elixir_ls.elixir_version" => System.version(),
      "elixir_ls.otp_release" => System.otp_release(),
      "elixir_ls.erts_version" => to_string(Application.spec(:erts, :vsn)),
      "elixir_ls.mix_env" => mix_env,
      "elixir_ls.mix_target" => mix_target
    }

    notify("telemetry/event", %{
      name: name,
      properties: Map.merge(common_properties, properties),
      measurements: measurements
    })
  end

  def register_capability_request(server \\ __MODULE__, server_instance_id, method, options) do
    id = server_instance_id <> method <> JasonV.encode!(options)

    send_request(server, "client/registerCapability", %{
      "registrations" => [
        %{
          "id" => :crypto.hash(:sha, id) |> Base.encode16(),
          "method" => method,
          "registerOptions" => options
        }
      ]
    })
  end

  def get_configuration_request(server \\ __MODULE__, scope_uri, section) do
    send_request(server, "workspace/configuration", %{
      "items" => [
        %{
          "scopeUri" => scope_uri,
          "section" => section
        }
      ]
    })
  end

  def show_message_request(server \\ __MODULE__, type, message, actions) do
    send_request(server, "window/showMessageRequest", %{
      "type" => message_type_code(type),
      "message" => message,
      "actions" => actions
    })
  end

  # Used to intercept :user/:standard_io output
  def print(str) when is_binary(str) do
    log_message(:log, String.replace_suffix(str, "\n", ""))
  end

  # Used to intercept :standard_error output
  def print_err(str) when is_binary(str) do
    log_message(:warning, String.replace_suffix(str, "\n", ""))
  end

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, Keyword.delete(opts, :name), name: opts[:name])
  end

  def receive_packet(server \\ __MODULE__, packet) do
    GenServer.call(server, {:packet, packet}, :infinity)
  end

  def send_request(server \\ __MODULE__, method, params) do
    GenServer.call(server, {:request, method, params}, :infinity)
  end

  ## Server callbacks

  @impl GenServer
  def init(opts) do
    language_server_module = Keyword.get(opts, :language_server, @default_server)
    state = %__MODULE__{language_server: language_server_module}
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:packet, notification(_) = packet}, _from, state) do
    state.language_server.receive_packet(packet)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:packet, request(_, _, _) = packet}, _from, state) do
    state.language_server.receive_packet(packet)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:packet, response(id, result)}, _from, state) do
    %{^id => from} = state.outgoing_requests
    GenServer.reply(from, {:ok, result})
    state = update_in(state.outgoing_requests, &Map.delete(&1, id))
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:packet, error_response(id, code, message)}, _from, state) do
    %{^id => from} = state.outgoing_requests
    GenServer.reply(from, {:error, code, message})
    state = update_in(state.outgoing_requests, &Map.delete(&1, id))
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:request, method, params}, from, state) do
    WireProtocol.send(request(state.next_id, method, params))
    state = update_in(state.outgoing_requests, &Map.put(&1, state.next_id, from))
    state = %__MODULE__{state | next_id: state.next_id + 1}
    {:noreply, state}
  end

  ## Helpers

  defp message_type_code(type) do
    case type do
      :error -> 1
      :warning -> 2
      :info -> 3
      :log -> 4
    end
  end

  # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#errorCodes

  # Defined by JSON-RPC
  defp error_code_and_message(:parse_error), do: {-32700, "Parse error"}
  defp error_code_and_message(:invalid_request), do: {-32600, "Invalid Request"}
  defp error_code_and_message(:method_not_found), do: {-32601, "Method not found"}
  defp error_code_and_message(:invalid_params), do: {-32602, "Invalid params"}
  defp error_code_and_message(:internal_error), do: {-32603, "Internal error"}

  # -32099 - -32000 - JSON-RPC reserved error codes
  # No LSP error codes should be defined between the start and end range.
  # For backwards compatibility the `ServerNotInitialized` and the `UnknownErrorCode`
  # are left in the range.
  defp error_code_and_message(:server_not_initialized), do: {-32002, "Server not initialized"}
  defp error_code_and_message(:unknown_error_code), do: {-32001, "Unknown error code"}

  # -32899 - -32800 - LSP reserved error codes
  defp error_code_and_message(:request_failed), do: {-32803, "Request failed"}
  defp error_code_and_message(:server_cancelled), do: {-32802, "Server cancelled"}
  defp error_code_and_message(:content_modified), do: {-32801, "Content modified"}
  defp error_code_and_message(:request_cancelled), do: {-32800, "Request cancelled"}
end
