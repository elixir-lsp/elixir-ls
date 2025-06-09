defmodule ElixirLS.LanguageServer.Test.ServerTestHelpers do
  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias ElixirLS.LanguageServer.Server
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols
  alias ElixirLS.Utils.PacketCapture
  use ElixirLS.LanguageServer.Protocol

  def start_server(server) do
    packet_capture = start_supervised!({PacketCapture, self()})

    replace_logger(packet_capture)

    Process.group_leader(server, packet_capture)

    json_rpc = start_supervised!({JsonRpc, name: JsonRpc})
    Process.group_leader(json_rpc, packet_capture)

    workspace_symbols = start_supervised!({WorkspaceSymbols, []})
    Process.group_leader(workspace_symbols, packet_capture)

    server
  end

  def replace_logger(packet_capture) do
    # :logger application is already started
    # replace console logger with LSP
    if Version.match?(System.version(), ">= 1.15.0") do
      configs =
        for handler_id <- :logger.get_handler_ids() do
          {:ok, config} = :logger.get_handler_config(handler_id)
          :ok = :logger.remove_handler(handler_id)
          config
        end

      :ok =
        :logger.add_handler(
          Logger.Backends.JsonRpc,
          Logger.Backends.JsonRpc,
          Logger.Backends.JsonRpc.handler_config()
        )

      ExUnit.Callbacks.on_exit(fn ->
        :ok = :logger.remove_handler(Logger.Backends.JsonRpc)

        for config <- configs do
          :ok = :logger.add_handler(config.id, config.module, config)
        end
      end)
    else
      Application.put_env(:logger, :backends, [Logger.Backends.JsonRpc])

      Application.put_env(:logger, Logger.Backends.JsonRpc,
        level: :debug,
        format: "$message",
        metadata: []
      )

      {:ok, _logger_backend} = Logger.add_backend(Logger.Backends.JsonRpc)
      :ok = Logger.remove_backend(:console, flush: true)

      # Logger.add_backend returns Logger.Watcher pid
      # the handler is supervised by :gen_event and the pid cannot be received via public api
      # instead we call it to set group leader in the callback
      :gen_event.call(Logger, Logger.Backends.JsonRpc, {:set_group_leader, packet_capture})

      ExUnit.Callbacks.on_exit(fn ->
        Application.put_env(:logger, :backends, [:console])

        {:ok, _} = Logger.add_backend(:console)
        :ok = Logger.remove_backend(Logger.Backends.JsonRpc, flush: false)
      end)
    end
  end

  def initialize(server, config \\ nil) do
    Server.receive_packet(
      server,
      initialize_req(1, root_uri(), %{
        "workspace" => %{
          "configuration" => true
        }
      })
    )

    Server.receive_packet(server, notification("initialized", %{}))

    config = config || %{"dialyzerEnabled" => false}

    id =
      receive do
        %{
          "id" => id,
          "method" => "workspace/configuration"
        } ->
          id
      after
        1000 -> raise "timeout"
      end

    JsonRpc.receive_packet(response(id, [config]))

    wait_until_compiled(server)
  end

  def fake_initialize(server, mix_project? \\ true) do
    :sys.replace_state(server, fn state ->
      %{state | server_instance_id: "123", project_dir: File.cwd!(), mix_project?: mix_project?}
    end)
  end

  def wait_until_compiled(pid) do
    state = :sys.get_state(pid)

    if state.build_running? do
      Process.sleep(500)
      wait_until_compiled(pid)
    end
  end

  def root_uri do
    SourceFile.Path.to_uri(File.cwd!())
  end
end
