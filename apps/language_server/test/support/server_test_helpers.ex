defmodule ElixirLS.LanguageServer.Test.ServerTestHelpers do
  import ExUnit.Callbacks, only: [start_supervised!: 1]

  alias ElixirLS.LanguageServer.Server
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols
  alias ElixirLS.Utils.PacketCapture

  def start_server do
    packet_capture = start_supervised!({PacketCapture, self()})

    replace_logger(packet_capture)

    server = start_supervised!({Server, nil})
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
end
