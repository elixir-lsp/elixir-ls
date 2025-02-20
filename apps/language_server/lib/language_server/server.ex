defmodule ElixirLS.LanguageServer.Server do
  @moduledoc """
  Language Server Protocol server

  This server tracks open files, attempts to rebuild the project when a file changes, and handles
  requests from the IDE (for things like autocompletion, hover, etc.)

  Notifications from the IDE are handled synchronously, whereas requests can be handled synchronously
  or asynchronously.

  When possible, handling the request asynchronously has several advantages. The asynchronous
  request handling cannot modify the server state.  That way, if the process handling the request
  crashes, we can report that error to the client and continue knowing that the state is
  uncorrupted. Also, asynchronous requests can be cancelled by the client if they're taking too long
  or the user no longer cares about the result.
  """

  use GenServer
  require Logger

  alias ElixirLS.LanguageServer.{
    SourceFile,
    Build,
    Protocol,
    JsonRpc,
    Dialyzer,
    DialyzerIncremental,
    Diagnostics,
    MixProjectCache,
    Parser
  }

  alias ElixirLS.LanguageServer.Providers.{
    Completion,
    Hover,
    Definition,
    Implementation,
    References,
    Formatting,
    SignatureHelp,
    DocumentSymbols,
    WorkspaceSymbols,
    OnTypeFormatting,
    CodeLens,
    ExecuteCommand,
    FoldingRange,
    SelectionRanges,
    CodeAction
  }

  alias ElixirLS.Utils.Launch
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.Utils.MixfileHelpers

  use Protocol

  defstruct [
    :server_instance_id,
    :build_ref,
    :dialyzer_sup,
    :client_capabilities,
    :root_uri,
    :project_dir,
    :settings,
    last_published_diagnostics_uris: [],
    parser_diagnostics: %{},
    document_versions_on_build: %{},
    build_diagnostics: [],
    dialyzer_diagnostics: [],
    needs_build?: false,
    full_build_done?: false,
    build_running?: false,
    analysis_ready?: false,
    received_shutdown?: false,
    requests: %{},
    requests_ids_by_pid: %{},
    # Tracks source files that are currently open in the editor
    source_files: %{},
    awaiting_contracts: [],
    mix_project?: false,
    mix_env: nil,
    mix_target: nil,
    no_mixfile_warned?: false,
    default_settings: %{}
  ]

  defmodule InvalidParamError do
    defexception [:uri, :message]

    @impl true
    def exception(uri) do
      msg = "invalid URI: #{inspect(uri)}"
      %InvalidParamError{message: msg, uri: uri}
    end
  end

  defmodule ContentModifiedError do
    defexception [:uri, :message]

    @impl true
    def exception(uri) do
      msg = "document URI: #{inspect(uri)} modified"
      %ContentModifiedError{message: msg, uri: uri}
    end
  end

  @default_watched_extensions [
    ".ex",
    ".exs",
    ".erl",
    ".hrl",
    ".yrl",
    ".xrl",
    ".eex",
    ".leex",
    ".heex",
    ".sface"
  ]

  @default_config_timeout 3

  ## Client API

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, :ok, name: name || __MODULE__)
  end

  def receive_packet(server \\ __MODULE__, packet) do
    GenServer.cast(server, {:receive_packet, packet})
  end

  def build_finished(server \\ __MODULE__, result) do
    GenServer.cast(server, {:build_finished, result})
  end

  def dialyzer_finished(server \\ __MODULE__, diagnostics, build_ref) do
    GenServer.cast(server, {:dialyzer_finished, diagnostics, build_ref})
  end

  def parser_finished(server \\ __MODULE__, diagnostics) do
    GenServer.cast(server, {:parser_finished, diagnostics})
  end

  def rebuild(server \\ __MODULE__) do
    GenServer.cast(server, :rebuild)
  end

  def suggest_contracts(server \\ __MODULE__, uri) do
    GenServer.call(server, {:suggest_contracts, uri}, :infinity)
  end

  defguardp is_initialized(server_instance_id) when not is_nil(server_instance_id)

  ## Server Callbacks

  @impl GenServer
  def init(:ok) do
    {:ok, %__MODULE__{}}
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
        do_sanity_check()
        message = Exception.format_exit(reason)

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => message
          },
          %{}
        )

        Logger.error("Terminating #{__MODULE__}: #{message}")

        unless :persistent_term.get(:language_server_test_mode, false) do
          Process.sleep(2000)
          System.halt(1)
        else
          IO.warn("Terminating #{__MODULE__}: #{message}")
        end
    end

    :ok
  end

  @impl GenServer
  def handle_call({:request_finished, id, result}, _from, state = %__MODULE__{}) do
    # in case the request has been cancelled we silently ignore
    {popped_request, updated_requests} = Map.pop(state.requests, id)

    requests_ids_by_pid =
      if popped_request do
        {pid, ref, command, start_time} = popped_request
        # we are no longer interested in :DOWN message
        Process.demonitor(ref, [:flush])

        case result do
          {:error, type, msg, send_telemetry} ->
            JsonRpc.respond_with_error(id, type, msg)

            do_sanity_check(msg || to_string(type))

            if send_telemetry do
              JsonRpc.telemetry(
                "lsp_request_error",
                %{
                  "elixir_ls.lsp_command" => String.replace(command, "/", "_"),
                  "elixir_ls.lsp_error" => to_string(type),
                  "elixir_ls.lsp_error_message" => msg || to_string(type)
                },
                %{}
              )
            end

          {:ok, result} ->
            elapsed = System.monotonic_time(:millisecond) - start_time
            JsonRpc.respond(id, result)

            JsonRpc.telemetry(
              "lsp_request",
              %{"elixir_ls.lsp_command" => String.replace(command, "/", "_")},
              %{
                "elixir_ls.lsp_request_time" => elapsed
              }
            )
        end

        Map.delete(state.requests_ids_by_pid, pid)
      else
        state.requests_ids_by_pid
      end

    state = %{state | requests: updated_requests, requests_ids_by_pid: requests_ids_by_pid}
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:suggest_contracts, uri = "file:" <> _}, from, state = %__MODULE__{}) do
    case state do
      %{analysis_ready?: true, source_files: %{^uri => %{dirty?: false}}} ->
        abs_path = SourceFile.Path.absolute_from_uri(uri, state.project_dir)
        parent = self()

        spawn(fn ->
          contracts = dialyzer_module(state.settings).suggest_contracts(parent, [abs_path])
          GenServer.reply(from, contracts)
        end)

        {:noreply, state}

      %{source_files: %{^uri => _}} ->
        # file not saved or analysis not finished
        awaiting_contracts = reject_awaiting_contracts(state.awaiting_contracts, uri)

        {:noreply, %{state | awaiting_contracts: [{from, uri} | awaiting_contracts]}}

      _ ->
        # file not or no longer open
        {:reply, [], state}
    end
  end

  def handle_call({:suggest_contracts, _uri}, _from, state = %__MODULE__{}) do
    {:reply, [], state}
  end

  @impl GenServer
  def handle_cast({:build_finished, {status, diagnostics}}, state = %__MODULE__{})
      when status in [:ok, :noop, :error, :no_mixfile] and is_list(diagnostics) do
    {:noreply, handle_build_result(status, diagnostics, state)}
  end

  @impl GenServer
  def handle_cast({:dialyzer_finished, diagnostics, build_ref}, state = %__MODULE__{}) do
    {:noreply, handle_dialyzer_result(diagnostics, build_ref, state)}
  end

  @impl GenServer
  def handle_cast({:parser_finished, diagnostics}, state = %__MODULE__{}) do
    state =
      %{state | parser_diagnostics: diagnostics}
      |> publish_diagnostics()

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:receive_packet, request(id, _method, _) = packet}, state = %__MODULE__{}) do
    new_state = handle_request_packet(id, packet, state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:receive_packet, request(id, method)}, state = %__MODULE__{}) do
    new_state = handle_request_packet(id, request(id, method, nil), state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(
        {:receive_packet, notification(_method) = packet},
        state = %__MODULE__{received_shutdown?: false, server_instance_id: server_instance_id}
      )
      when is_initialized(server_instance_id) do
    new_state = handle_notification(packet, state)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:receive_packet, notification(_) = packet}, state = %__MODULE__{}) do
    case packet do
      notification("exit") ->
        new_state = handle_notification(packet, state)

        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast(:rebuild, state = %__MODULE__{}) do
    {:noreply, trigger_build(state)}
  end

  @impl GenServer
  def handle_info(:default_config, state = %__MODULE__{settings: nil}) do
    Logger.warning(
      "Did not receive workspace/didChangeConfiguration notification after #{@default_config_timeout} seconds. " <>
        "The server will use default config."
    )

    state = set_settings(state, state.default_settings)
    {:noreply, state}
  end

  def handle_info(:default_config, state = %__MODULE__{}) do
    # we got workspace/didChangeConfiguration in time, nothing to do here
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:DOWN, ref, _, _pid, reason},
        %__MODULE__{build_ref: ref, build_running?: true} = state
      ) do
    state = %{state | build_running?: false}

    # in case the build was interrupted make sure that cwd is reset to project dir
    case File.cd(state.project_dir) do
      :ok ->
        :ok

      {:error, reason} ->
        message =
          "Cannot change directory to project dir #{state.project_dir}: #{inspect(reason)}"

        Logger.error(message)
        JsonRpc.show_message(:error, message)

        unless :persistent_term.get(:language_server_test_mode, false) do
          Process.sleep(2000)
          System.halt(1)
        else
          IO.warn(message)
        end
    end

    state =
      case reason do
        :normal ->
          WorkspaceSymbols.notify_build_complete()
          state

        _ ->
          message = Exception.format_exit(reason)

          JsonRpc.telemetry(
            "build_error",
            %{"elixir_ls.build_error" => message},
            %{}
          )

          path = Path.join(state.project_dir, MixfileHelpers.mix_exs())

          handle_build_result(
            :error,
            [Diagnostics.from_shutdown_reason(reason, path, state.project_dir)],
            state
          )
      end

    state =
      if state.needs_build? do
        trigger_build(state)
      else
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %__MODULE__{requests: requests, requests_ids_by_pid: requests_ids_by_pid} = state
      ) do
    {id, updated_requests_ids_by_pid} = Map.pop(requests_ids_by_pid, pid)

    updated_requests =
      if id do
        {{^pid, ^ref, command, _start_time}, updated_requests} = Map.pop!(requests, id)
        error_msg = Exception.format_exit(reason)
        JsonRpc.respond_with_error(id, :internal_error, error_msg)

        do_sanity_check(error_msg)

        JsonRpc.telemetry(
          "lsp_request_error",
          %{
            "elixir_ls.lsp_command" => String.replace(command, "/", "_"),
            "elixir_ls.lsp_error" => :internal_error,
            "elixir_ls.lsp_error_message" => error_msg
          },
          %{}
        )

        updated_requests
      else
        requests
      end

    {:noreply,
     %{state | requests: updated_requests, requests_ids_by_pid: updated_requests_ids_by_pid}}
  end

  ## Helpers

  defp handle_notification(notification("initialized"), state = %__MODULE__{}) do
    # according to https://github.com/microsoft/language-server-protocol/issues/567#issuecomment-1060605611
    # this is the best point to pull configuration

    state = pull_configuration(state)

    unless state.settings do
      # We still don't have the configuration. Let's wait for workspace/didChangeConfiguration
      Process.send_after(self(), :default_config, @default_config_timeout * 1000)
    end

    supports_dynamic_configuration_change_registration =
      get_in(state.client_capabilities, [
        "workspace",
        "didChangeConfiguration",
        "dynamicRegistration"
      ])

    if supports_dynamic_configuration_change_registration do
      Logger.info("Registering for workspace/didChangeConfiguration notifications")
      listen_for_configuration_changes(state.server_instance_id)
    else
      Logger.info("Client does not support workspace/didChangeConfiguration dynamic registration")
    end

    supports_dynamic_file_watcher_registration =
      get_in(state.client_capabilities, [
        "workspace",
        "didChangeWatchedFiles",
        "dynamicRegistration"
      ])

    if supports_dynamic_file_watcher_registration do
      Logger.info("Registering for workspace/didChangeWatchedFiles notifications")
      add_watched_extensions(state.server_instance_id, @default_watched_extensions)
    else
      Logger.info("Client does not support workspace/didChangeWatchedFiles dynamic registration")
    end

    state
  end

  defp handle_notification(
         cancel_request(id),
         %__MODULE__{requests: requests, requests_ids_by_pid: requests_ids_by_pid} = state
       ) do
    {request, updated_requests} = Map.pop(requests, id)

    updated_requests_ids_by_pid =
      if request do
        {pid, ref, _command, _start_time} = request
        # we are no longer interested in :DOWN message
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :cancelled)
        JsonRpc.respond_with_error(id, :request_cancelled, "Request cancelled")
        Map.delete(requests_ids_by_pid, pid)
      else
        Logger.debug("Received $/cancelRequest for unknown request id: #{inspect(id)}")
        requests_ids_by_pid
      end

    %{state | requests: updated_requests, requests_ids_by_pid: updated_requests_ids_by_pid}
  end

  # We don't start performing builds until we receive settings from the client in case they've set
  # the `projectDir` or `mixEnv` settings.
  # note that clients supporting `workspace/configuration` will send nil and we need to pull
  defp handle_notification(did_change_configuration(changed_settings), state = %__MODULE__{}) do
    Logger.info("Received workspace/didChangeConfiguration")
    prev_settings = state.settings || %{}

    case changed_settings do
      %{"elixirLS" => settings} when is_map(settings) ->
        Logger.info(
          "Received client configuration via workspace/didChangeConfiguration\n#{inspect(settings)}"
        )

        # deprecated push based configuration - interesting config updated
        new_settings = Map.merge(prev_settings, settings)
        set_settings(state, new_settings)

      nil ->
        # pull based configuration
        # on notification the server should pull current configuration
        # see https://github.com/microsoft/language-server-protocol/issues/1792
        pull_configuration(state)

      _ ->
        # deprecated push based configuration - some other config updated
        set_settings(state, prev_settings)
    end
  end

  defp handle_notification(notification("exit"), state = %__MODULE__{}) do
    code = if state.received_shutdown?, do: 0, else: 1

    unless :persistent_term.get(:language_server_test_mode, false) do
      System.stop(code)
    else
      Logger.info("Received exit with code #{code}")
    end

    state
  end

  defp handle_notification(did_open(uri, language_id, version, text), state = %__MODULE__{}) do
    if Map.has_key?(state.source_files, uri) do
      # An open notification must not be sent more than once without a corresponding
      # close notification send before
      Logger.warning(
        "Received textDocument/didOpen for file that is already open. Received uri: #{inspect(uri)}"
      )

      state
    else
      unless String.valid?(text) do
        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => "File not valid on open:\n#{inspect(text)}"
          },
          %{}
        )

        Logger.error("File not valid on open:\n#{inspect(text)}")
      end

      source_file = %SourceFile{text: text, version: version, language_id: language_id}

      Parser.parse_with_debounce(uri, source_file)

      put_in(state.source_files[uri], source_file)
    end
  end

  defp handle_notification(did_close(uri), state = %__MODULE__{}) do
    if not Map.has_key?(state.source_files, uri) do
      # A close notification requires a previous open notification to be sent
      Logger.warning(
        "Received textDocument/didClose for file that is not open. Received uri: #{inspect(uri)}"
      )

      state
    else
      awaiting_contracts = reject_awaiting_contracts(state.awaiting_contracts, uri)

      Parser.notify_closed(uri)

      %{
        state
        | source_files: Map.delete(state.source_files, uri),
          awaiting_contracts: awaiting_contracts
      }
    end
  end

  defp handle_notification(did_change(uri, version, content_changes), state = %__MODULE__{}) do
    if not Map.has_key?(state.source_files, uri) do
      # The source file was not marked as open either due to a bug in the
      # client or a restart of the server. So just ignore the message and do
      # not update the state
      Logger.warning(
        "Received textDocument/didChange for file that is not open. Received uri: #{inspect(uri)}"
      )

      state
    else
      state =
        update_in(state.source_files[uri], fn source_file ->
          # LSP 3.17: The version number points to the version after all provided content changes have
          # been applied
          updated_source_file =
            %SourceFile{source_file | version: version, dirty?: true}
            |> SourceFile.apply_content_changes(content_changes)

          Parser.parse_with_debounce(uri, updated_source_file)

          unless String.valid?(updated_source_file.text) do
            JsonRpc.telemetry(
              "lsp_server_error",
              %{
                "elixir_ls.lsp_process" => inspect(__MODULE__),
                "elixir_ls.lsp_server_error" =>
                  "File not valid after: #{inspect(content_changes)} text was:\n#{inspect(source_file.text)}"
              },
              %{}
            )

            Logger.error(
              "File not valid after: #{inspect(content_changes)} text was:\n#{inspect(source_file.text)}"
            )
          end

          updated_source_file
        end)

      state
    end
  end

  defp handle_notification(did_save(uri), state = %__MODULE__{}) do
    if not Map.has_key?(state.source_files, uri) do
      Logger.warning(
        "Received textDocument/didSave for file that is not open. Received uri: #{inspect(uri)}"
      )

      state
    else
      WorkspaceSymbols.notify_uris_modified([uri])
      state = update_in(state.source_files[uri], &%{&1 | dirty?: false})
      trigger_build(state)
    end
  end

  defp handle_notification(
         did_change_watched_files(changes),
         state = %__MODULE__{project_dir: project_dir}
       )
       when is_binary(project_dir) do
    changes = Enum.filter(changes, &match?(%{"uri" => "file:" <> _}, &1))

    # `settings` may not always be available here, like during testing
    additional_watched_extensions =
      Map.get(state.settings || %{}, "additionalWatchedExtensions", [])

    needs_build =
      Enum.any?(changes, fn %{"uri" => uri = "file:" <> _, "type" => type} ->
        path = SourceFile.Path.from_uri(uri)

        relative_path = Path.relative_to(path, state.project_dir)
        first_path_segment = relative_path |> Path.split() |> hd

        first_path_segment not in [".elixir_ls", "_build"] and
          Path.extname(path) in (additional_watched_extensions ++ @default_watched_extensions) and
          (type in [1, 3] or not Map.has_key?(state.source_files, uri) or
             state.source_files[uri].dirty?)
      end)

    deleted_paths =
      for change <- changes,
          change["type"] == 3,
          do: SourceFile.Path.from_uri(change["uri"])

    for path <- deleted_paths do
      Tracer.notify_file_deleted(path)
    end

    source_files =
      changes
      |> Enum.reduce(state.source_files, fn
        %{"type" => 3}, acc ->
          # deleted file still open in editor, keep dirty flag
          acc

        %{"uri" => uri = "file:" <> _}, acc ->
          # file created/updated - set dirty flag to false if file contents are equal
          case acc[uri] do
            %SourceFile{text: source_file_text, dirty?: true} = source_file ->
              case File.read(SourceFile.Path.from_uri(uri)) do
                {:ok, ^source_file_text} ->
                  Map.put(acc, uri, %SourceFile{source_file | dirty?: false})

                {:ok, _} ->
                  acc

                {:error, reason} ->
                  Logger.warning("Unable to read #{uri}: #{inspect(reason)}")
                  # keep dirty if read fails
                  acc
              end

            _ ->
              # file not open or not dirty
              acc
          end
      end)

    state = %{state | source_files: source_files}

    changes
    |> Enum.map(& &1["uri"])
    |> WorkspaceSymbols.notify_uris_modified()

    if needs_build do
      trigger_build(state)
    else
      state
    end
  end

  defp handle_notification(did_change_watched_files(_changes), state = %__MODULE__{}) do
    # swallow notification if we are not in mix_project
    state
  end

  defp handle_notification(%{"method" => "$/" <> _}, state = %__MODULE__{}) do
    # not supported "$/" notifications may be safely ignored
    state
  end

  defp handle_notification(packet, state = %__MODULE__{}) do
    Logger.warning("Received unmatched notification: #{inspect(packet)}")
    state
  end

  defp handle_request_packet(
         id,
         packet,
         state = %__MODULE__{server_instance_id: server_instance_id}
       )
       when not is_initialized(server_instance_id) do
    start_time = System.monotonic_time(:millisecond)

    case packet do
      initialize_req(_id, _root_uri, _client_capabilities) ->
        try do
          {:ok, result, state} = handle_request(packet, state)
          elapsed = System.monotonic_time(:millisecond) - start_time
          JsonRpc.respond(id, result)

          JsonRpc.telemetry("lsp_request", %{"elixir_ls.lsp_command" => "initialize"}, %{
            "elixir_ls.lsp_request_time" => elapsed
          })

          state
        catch
          kind, payload ->
            {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
            error_msg = Exception.format(kind, payload, stacktrace)

            # on error in initialize the protocol requires to respond with
            # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#initializeError
            # the initialize request can fail on broken OTP installs, no point in retrying
            JsonRpc.respond_with_error(id, :internal_error, error_msg, %{
              "retry" => false
            })

            do_sanity_check(error_msg)

            JsonRpc.telemetry(
              "lsp_request_error",
              %{
                "elixir_ls.lsp_command" => "initialize",
                "elixir_ls.lsp_error" => :internal_error,
                "elixir_ls.lsp_error_message" => error_msg
              },
              %{}
            )

            state
        end

      _ ->
        JsonRpc.respond_with_error(id, :server_not_initialized)

        JsonRpc.telemetry(
          "lsp_request_error",
          %{
            "elixir_ls.lsp_command" => "initialize",
            "elixir_ls.lsp_error" => :server_not_initialized,
            "elixir_ls.lsp_error_message" => "Server not initialized"
          },
          %{}
        )

        state
    end
  end

  defp handle_request_packet(
         id,
         packet = %{"method" => command},
         state = %__MODULE__{received_shutdown?: false}
       ) do
    command =
      case packet do
        execute_command_req(_id, custom_command_with_server_id, _args) ->
          command <> ":" <> (ExecuteCommand.get_command(custom_command_with_server_id) || "")

        _ ->
          command
      end

    start_time = System.monotonic_time(:millisecond)

    try do
      case handle_request(packet, state) do
        {:ok, result, state} ->
          elapsed = System.monotonic_time(:millisecond) - start_time
          JsonRpc.respond(id, result)

          JsonRpc.telemetry(
            "lsp_request",
            %{"elixir_ls.lsp_command" => String.replace(command, "/", "_")},
            %{
              "elixir_ls.lsp_request_time" => elapsed
            }
          )

          state

        {:error, type, msg, send_telemetry, state} ->
          JsonRpc.respond_with_error(id, type, msg)

          do_sanity_check(msg)

          if send_telemetry do
            JsonRpc.telemetry(
              "lsp_request_error",
              %{
                "elixir_ls.lsp_command" => String.replace(command, "/", "_"),
                "elixir_ls.lsp_error" => type,
                "elixir_ls.lsp_error_message" => msg
              },
              %{}
            )
          end

          state

        {:async, fun, state} ->
          {pid, ref} = handle_request_async(id, fun)

          %{
            state
            | requests: Map.put(state.requests, id, {pid, ref, command, start_time}),
              requests_ids_by_pid: Map.put(state.requests_ids_by_pid, pid, id)
          }
      end
    rescue
      e in InvalidParamError ->
        JsonRpc.respond_with_error(id, :invalid_params, e.message)

        state
    catch
      kind, payload ->
        {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
        error_msg = Exception.format(kind, payload, stacktrace)
        JsonRpc.respond_with_error(id, :internal_error, error_msg)

        do_sanity_check(error_msg)

        JsonRpc.telemetry(
          "lsp_request_error",
          %{
            "elixir_ls.lsp_command" => String.replace(command, "/", "_"),
            "elixir_ls.lsp_error" => :internal_error,
            "elixir_ls.lsp_error_message" => error_msg
          },
          %{}
        )

        state
    end
  end

  defp handle_request_packet(id, _packet = %{"method" => command}, state = %__MODULE__{}) do
    JsonRpc.respond_with_error(id, :invalid_request)

    JsonRpc.telemetry(
      "lsp_request_error",
      %{
        "elixir_ls.lsp_command" => String.replace(command, "/", "_"),
        "elixir_ls.lsp_error" => :invalid_request,
        "elixir_ls.lsp_error_message" => "Invalid Request"
      },
      %{}
    )

    state
  end

  defp handle_request(
         initialize_req(_id, root_uri, client_capabilities),
         state = %__MODULE__{server_instance_id: server_instance_id}
       )
       when not is_initialized(server_instance_id) do
    show_version_warnings()

    server_instance_id =
      :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)

    state =
      case root_uri do
        "file://" <> _ ->
          %{state | root_uri: root_uri}

        nil ->
          state
      end

    state = %{
      state
      | client_capabilities: client_capabilities,
        server_instance_id: server_instance_id
    }

    :persistent_term.put(:language_server_client_capabilities, client_capabilities)

    {:ok,
     %{
       "capabilities" => server_capabilities(server_instance_id),
       "serverInfo" => %{
         "name" => "ElixirLS",
         "version" => "#{Launch.language_server_version()}"
       }
     }, state}
  end

  defp handle_request(request(_id, "shutdown", _params), state = %__MODULE__{}) do
    {:ok, nil, %{state | received_shutdown?: true}}
  end

  defp handle_request(definition_req(_id, uri, line, character), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})
      parser_context = Parser.parse_immediate(uri, source_file, {line, character})
      Definition.definition(uri, parser_context, line, character, state.project_dir)
    end

    {:async, fun, state}
  end

  defp handle_request(implementation_req(_id, uri, line, character), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})
      parser_context = Parser.parse_immediate(uri, source_file, {line, character})
      Implementation.implementation(uri, parser_context, line, character, state.project_dir)
    end

    {:async, fun, state}
  end

  defp handle_request(
         references_req(_id, uri, line, character, include_declaration),
         state = %__MODULE__{}
       ) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})
      parser_context = Parser.parse_immediate(uri, source_file, {line, character})

      {:ok,
       References.references(
         parser_context,
         uri,
         line,
         character,
         include_declaration,
         state.project_dir
       )}
    end

    {:async, fun, state}
  end

  defp handle_request(hover_req(_id, uri, line, character), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})
      parser_context = Parser.parse_immediate(uri, source_file, {line, character})
      Hover.hover(parser_context, line, character)
    end

    {:async, fun, state}
  end

  defp handle_request(document_symbol_req(_id, uri), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      hierarchical? =
        get_in(state.client_capabilities, [
          "textDocument",
          "documentSymbol",
          "hierarchicalDocumentSymbolSupport"
        ]) || false

      if String.ends_with?(uri, [".ex", ".exs", ".eex"]) or
           source_file.language_id in ["elixir", "eex", "html-eex"] do
        parser_context = Parser.parse_immediate(uri, source_file)
        DocumentSymbols.symbols(uri, parser_context, hierarchical?)
      else
        {:ok, []}
      end
    end

    {:async, fun, state}
  end

  defp handle_request(workspace_symbol_req(_id, query), state = %__MODULE__{}) do
    fun = fn ->
      WorkspaceSymbols.symbols(query)
    end

    {:async, fun, state}
  end

  defp handle_request(completion_req(_id, uri, line, character), state = %__MODULE__{}) do
    settings = state.settings || %{}

    source_file = get_source_file(state, uri)

    snippets_supported =
      !!get_in(state.client_capabilities, [
        "textDocument",
        "completion",
        "completionItem",
        "snippetSupport"
      ])

    # deprecated as of Language Server Protocol Specification - 3.15
    deprecated_supported =
      !!get_in(state.client_capabilities, [
        "textDocument",
        "completion",
        "completionItem",
        "deprecatedSupport"
      ])

    tags_supported =
      case get_in(state.client_capabilities, [
             "textDocument",
             "completion",
             "completionItem",
             "tagSupport"
           ]) do
        nil -> []
        %{"valueSet" => value_set} -> value_set
      end

    signature_help_supported =
      !!get_in(state.client_capabilities, ["textDocument", "signatureHelp"])

    locals_without_parens =
      case SourceFile.formatter_for(uri, state.project_dir, state.mix_project?) do
        {:ok, {_, opts}} ->
          locals_without_parens = Keyword.get(opts, :locals_without_parens, [])

          if List.improper?(locals_without_parens) do
            []
          else
            locals_without_parens
          end

        {:error, _} ->
          []
      end
      |> MapSet.new()

    auto_insert_required_alias = Map.get(settings, "autoInsertRequiredAlias", true)
    signature_after_complete = Map.get(settings, "signatureAfterComplete", true)

    path =
      case uri do
        "file:" <> _ -> SourceFile.Path.from_uri(uri)
        _ -> nil
      end

    fun = fn ->
      {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})
      parser_context = Parser.parse_immediate(uri, source_file, {line, character})

      Completion.completion(parser_context, line, character,
        snippets_supported: snippets_supported,
        deprecated_supported: deprecated_supported,
        tags_supported: tags_supported,
        signature_help_supported: signature_help_supported,
        locals_without_parens: locals_without_parens,
        auto_insert_required_alias: auto_insert_required_alias,
        signature_after_complete: signature_after_complete,
        file_path: path
      )
    end

    {:async, fun, state}
  end

  defp handle_request(formatting_req(_id, uri, _options), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)
    fun = fn -> Formatting.format(source_file, uri, state.project_dir, state.mix_project?) end
    {:async, fun, state}
  end

  defp handle_request(signature_help_req(_id, uri, line, character), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})
      parser_context = Parser.parse_immediate(uri, source_file, {line, character})
      # TODO not working for eex
      SignatureHelp.signature(parser_context, line, character)
    end

    {:async, fun, state}
  end

  defp handle_request(
         on_type_formatting_req(_id, uri, line, character, ch, options),
         state = %__MODULE__{}
       ) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      if String.ends_with?(uri, [".ex", ".exs"]) or source_file.language_id in ["elixir"] do
        OnTypeFormatting.format(source_file, line, character, ch, options)
      else
        # TODO no support for eex
        {:ok, nil}
      end
    end

    {:async, fun, state}
  end

  defp handle_request(code_lens_req(_id, uri), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      parser_context = Parser.parse_immediate(uri, source_file)
      {:ok, spec_code_lenses} = get_spec_code_lenses(state, uri, source_file)

      {:ok, test_code_lenses} = get_test_code_lenses(state, uri, parser_context)

      {:ok, spec_code_lenses ++ test_code_lenses}
    end

    {:async, fun, state}
  end

  defp handle_request(execute_command_req(_id, command, args) = req, state = %__MODULE__{}) do
    {:async,
     fn ->
       case ExecuteCommand.execute(command, args, state) do
         {:error, :invalid_request, _msg, _} = res ->
           Logger.warning("Unmatched request: #{inspect(req)}")
           res

         other ->
           other
       end
     end, state}
  end

  defp handle_request(folding_range_req(_id, uri), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      if String.ends_with?(uri, [".ex", ".exs"]) or source_file.language_id in ["elixir"] do
        FoldingRange.provide(source_file)
      else
        # TODO no support for eex
        {:ok, []}
      end
    end

    {:async, fun, state}
  end

  defp handle_request(selection_range_req(_id, uri, positions), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    fun = fn ->
      if String.ends_with?(uri, [".ex", ".exs"]) or source_file.language_id in ["elixir"] do
        formatter_opts =
          case SourceFile.formatter_for(uri, state.project_dir, state.mix_project?) do
            {:ok, {_, opts}} -> opts
            {:error, _} -> []
          end

        ranges =
          SelectionRanges.selection_ranges(source_file.text, positions,
            formatter_opts: formatter_opts
          )

        {:ok, ranges}
      else
        # TODO no support for eex
        {:ok, []}
      end
    end

    {:async, fun, state}
  end

  defp handle_request(code_action_req(_id, uri, diagnostics), state = %__MODULE__{}) do
    source_file = get_source_file(state, uri)

    {:async, fn -> CodeAction.code_actions(source_file, uri, diagnostics) end, state}
  end

  defp handle_request(%{"method" => "$/" <> _}, state = %__MODULE__{}) do
    # "$/" requests that the server doesn't support must return method_not_found
    {:error, :method_not_found, nil, false, state}
  end

  defp handle_request(req, state = %__MODULE__{}) do
    Logger.warning("Unmatched request: #{inspect(req)}")
    {:error, :invalid_request, nil, false, state}
  end

  defp handle_request_async(id, func) do
    parent = self()

    spawn_monitor(fn ->
      result =
        try do
          func.()
        rescue
          e in InvalidParamError ->
            {:error, :invalid_params, e.message, false}

          e in ContentModifiedError ->
            {:error, :content_modified, e.message, false}
        end

      GenServer.call(parent, {:request_finished, id, result}, :infinity)
    end)
  end

  defp server_capabilities(server_instance_id) do
    %{
      "macroExpansion" => true,
      "textDocumentSync" => %{
        "change" => 2,
        "openClose" => true,
        "save" => %{"includeText" => true}
      },
      "hoverProvider" => true,
      "completionProvider" => %{"triggerCharacters" => Completion.trigger_characters()},
      "definitionProvider" => true,
      "implementationProvider" => true,
      "referencesProvider" => true,
      "documentFormattingProvider" => true,
      "signatureHelpProvider" => %{"triggerCharacters" => SignatureHelp.trigger_characters()},
      "documentSymbolProvider" => %{"label" => "Elixir outline"},
      "workspaceSymbolProvider" => true,
      "documentOnTypeFormattingProvider" => %{"firstTriggerCharacter" => "\n"},
      "codeLensProvider" => %{"resolveProvider" => false},
      "selectionRangeProvider" => true,
      "executeCommandProvider" => %{
        "commands" => ExecuteCommand.get_commands(server_instance_id)
      },
      "workspace" => %{
        "workspaceFolders" => %{"supported" => false, "changeNotifications" => false}
      },
      "foldingRangeProvider" => true,
      "codeActionProvider" => true
    }
  end

  defp get_spec_code_lenses(state = %__MODULE__{}, uri, source_file) do
    enabled? = Map.get(state.settings || %{}, "suggestSpecs", true)

    if state.mix_project? and dialyzer_enabled?(state) and enabled? do
      CodeLens.spec_code_lens(state.server_instance_id, uri, source_file.text)
    else
      {:ok, []}
    end
  end

  defp get_test_code_lenses(state = %__MODULE__{}, uri, source_file) do
    # TODO check why test run from lense fails when autoBuild is disabled
    enabled? =
      Map.get(state.settings || %{}, "autoBuild", true) and
        Map.get(state.settings || %{}, "enableTestLenses", false)

    if state.mix_project? and enabled? and MixProjectCache.loaded?() do
      get_test_code_lenses(
        state,
        uri,
        source_file,
        MixProjectCache.umbrella?()
      )
    else
      {:ok, []}
    end
  end

  defp get_test_code_lenses(
         state = %__MODULE__{project_dir: project_dir},
         "file:" <> _ = uri,
         parser_context,
         true = _umbrella
       )
       when is_binary(project_dir) do
    file_path = SourceFile.Path.from_uri(uri)

    MixProjectCache.apps_paths()
    |> Enum.find(fn {_app, app_path} -> under_app?(file_path, project_dir, app_path) end)
    |> case do
      nil ->
        {:ok, []}

      {app, app_path} ->
        if is_test_file?(file_path, state, app, app_path) do
          CodeLens.test_code_lens(parser_context, Path.join(project_dir, app_path))
        else
          {:ok, []}
        end
    end
  end

  defp get_test_code_lenses(
         %__MODULE__{project_dir: project_dir},
         "file:" <> _ = uri,
         parser_context,
         false = _umbrella
       )
       when is_binary(project_dir) do
    try do
      file_path = SourceFile.Path.from_uri(uri)

      if is_test_file?(file_path, project_dir) do
        CodeLens.test_code_lens(parser_context, project_dir)
      else
        {:ok, []}
      end
    rescue
      _ in ArgumentError -> {:ok, []}
    end
  end

  defp get_test_code_lenses(%__MODULE__{}, _uri, _parser_context, _), do: {:ok, []}

  defp is_test_file?(file_path, state = %__MODULE__{project_dir: project_dir}, app, app_path)
       when is_binary(project_dir) do
    app_name = Atom.to_string(app)

    test_paths =
      (get_in(state.settings, ["testPaths", app_name]) || ["test"])
      |> Enum.map(fn path -> Path.join([project_dir, app_path, path]) end)

    test_pattern = get_in(state.settings, ["testPattern", app_name]) || "*_test.exs"

    file_path = SourceFile.Path.expand(file_path, project_dir)

    Mix.Utils.extract_files(test_paths, test_pattern)
    |> Enum.any?(fn path -> String.ends_with?(file_path, path) end)
  end

  defp is_test_file?(file_path, project_dir) do
    config = MixProjectCache.config()
    test_paths = config[:test_paths] || ["test"]
    test_pattern = config[:test_pattern] || "*_test.exs"

    file_path = SourceFile.Path.expand(file_path, project_dir)

    Mix.Utils.extract_files(test_paths, test_pattern)
    |> Enum.map(&SourceFile.Path.absname(&1, project_dir))
    |> Enum.any?(&(&1 == file_path))
  end

  defp under_app?(file_path, project_dir, app_path) do
    file_path_list = file_path |> Path.relative_to(project_dir) |> Path.split()
    app_path_list = app_path |> Path.split()

    List.starts_with?(file_path_list, app_path_list)
  end

  # Build

  defp trigger_build(
         state = %__MODULE__{project_dir: project_dir, full_build_done?: full_build_done?}
       ) do
    cond do
      not is_binary(project_dir) ->
        state

      not state.build_running? ->
        opts = [
          fetch_deps?: Map.get(state.settings || %{}, "fetchDeps", false),
          compile?: Map.get(state.settings || %{}, "autoBuild", true),
          force?: not full_build_done?
        ]

        {_pid, build_ref} =
          case File.cwd() do
            {:ok, cwd} ->
              if SourceFile.Path.absname(cwd) == SourceFile.Path.absname(project_dir) do
                Build.build(self(), project_dir, opts)
              else
                Logger.info("Skipping build because cwd changed from #{project_dir} to #{cwd}")
                {nil, nil}
              end

            {:error, reason} ->
              Logger.warning(
                "cwd is not accessible: #{inspect(reason)}, trying to change directory back to #{project_dir}"
              )

              # cwd is not accessible
              # try to change back to project dir
              case File.cd(project_dir) do
                :ok ->
                  Build.build(self(), project_dir, opts)

                {:error, reason} ->
                  message =
                    "Cannot change directory to project dir #{project_dir}: #{inspect(reason)}"

                  Logger.error(message)
                  JsonRpc.show_message(:error, message)

                  unless :persistent_term.get(:language_server_test_mode, false) do
                    Process.sleep(2000)
                    System.halt(1)
                  else
                    IO.warn(message)
                  end
              end
          end

        document_versions_on_build =
          Map.new(state.source_files, fn {uri, source_file} -> {uri, source_file.version} end)

        %__MODULE__{
          state
          | build_ref: build_ref,
            needs_build?: false,
            build_running?: true,
            analysis_ready?: false,
            build_diagnostics: [],
            dialyzer_diagnostics: [],
            document_versions_on_build: document_versions_on_build
        }
        |> publish_diagnostics()

      true ->
        # build already running, schedule another one
        %__MODULE__{state | needs_build?: true, analysis_ready?: false}
    end
  end

  defp dialyze(state = %__MODULE__{}) do
    warn_opts =
      (state.settings["dialyzerWarnOpts"] || [])
      |> Enum.map(&String.to_atom/1)

    dialyzer_module(state.settings).analyze(
      state.build_ref,
      warn_opts,
      dialyzer_default_format(state),
      state.project_dir
    )

    state
  end

  defp dialyzer_default_format(state = %__MODULE__{}) do
    state.settings["dialyzerFormat"] || "dialyxir_long"
  end

  defp handle_build_result(:no_mixfile, _, state = %__MODULE__{}) do
    unless state.no_mixfile_warned? do
      msg =
        "No mixfile found in project. " <>
          "To use a subdirectory, set `elixirLS.projectDir` in your settings"

      JsonRpc.show_message(:info, msg)
    end

    %__MODULE__{state | no_mixfile_warned?: true}
  end

  defp handle_build_result(status, diagnostics, state = %__MODULE__{}) do
    do_sanity_check()

    state =
      if state.needs_build? or status == :error or not dialyzer_enabled?(state) do
        state
      else
        dialyze(state)
      end

    state =
      if state.needs_build? do
        # do not publish diagnostics if we need another build
        state
      else
        put_in(state.build_diagnostics, diagnostics)
        |> publish_diagnostics()
      end

    %{state | full_build_done?: if(status == :ok, do: true, else: state.full_build_done?)}
  end

  defp handle_dialyzer_result(diagnostics, build_ref, state = %__MODULE__{}) do
    # If these results were triggered by the most recent build and files are not dirty, then we know
    # we're up to date and can release spec suggestions to the code lens provider
    if build_ref == state.build_ref do
      Logger.info("Dialyzer analysis is up to date")

      state =
        put_in(state.dialyzer_diagnostics, diagnostics)
        |> publish_diagnostics()

      {dirty, not_dirty} =
        state.awaiting_contracts
        |> Enum.split_with(fn {_, uri} ->
          Map.fetch!(state.source_files, uri).dirty?
        end)

      # Dialyzer.suggest_contracts is blocking and can take a long time to complete
      # if we block here we hang the server
      parent = self()

      spawn(fn ->
        contracts_by_file =
          not_dirty
          |> Enum.map(fn {_from, uri} -> SourceFile.Path.from_uri(uri) end)
          |> then(fn uris -> dialyzer_module(state.settings).suggest_contracts(parent, uris) end)
          |> Enum.group_by(fn {file, _, _, _, _} -> file end)

        for {from, uri} <- not_dirty do
          contracts =
            contracts_by_file
            |> Map.get(SourceFile.Path.from_uri(uri), [])

          GenServer.reply(from, contracts)
        end
      end)

      %{state | analysis_ready?: true, awaiting_contracts: dirty}
    else
      # do not publish diagnostics if those results are not for the current build
      state
    end
  end

  defp dialyzer_enabled?(state = %__MODULE__{}) do
    state.dialyzer_sup != nil
  end

  defp safely_read_file("file:" <> _ = uri) do
    file = SourceFile.Path.from_uri(uri)

    case File.read(file) do
      {:ok, text} ->
        if String.valid?(text) do
          text
        else
          Logger.warning("Invalid encoding in #{file}")
          nil
        end

      {:error, reason} ->
        if reason != :enoent do
          Logger.warning("Cannot read file #{file}: #{inspect(reason)}")
        end

        nil
    end
  end

  defp safely_read_file(_uri), do: nil

  defp publish_diagnostics(
         state = %__MODULE__{
           project_dir: project_dir,
           mix_project?: mix_project?,
           source_files: source_files,
           last_published_diagnostics_uris: last_published_diagnostics_uris
         }
       ) do
    # we need to publish diagnostics for all uris in current diagnostics
    # to clear diagnostics we need to push empty sets for uris from last push
    # in case we missed something or restarted and don't have old diagnostics uris
    # we also push for all open files

    uris_from_parser_diagnostics = Map.keys(state.parser_diagnostics)

    valid_build_and_dialyzer_diagnostics_by_uri =
      (state.build_diagnostics ++ state.dialyzer_diagnostics)
      |> Enum.map(fn %Diagnostics{file: file} = diagnostic ->
        if is_binary(file) or (is_list(file) and to_string(file) != "nofile") do
          diagnostic
        else
          # diagnostics without file are meaningless in LSP, try to point to mixfile instead
          if project_dir != nil and mix_project? do
            file = Path.join(project_dir, MixfileHelpers.mix_exs())
            %Diagnostics{diagnostic | file: file, source: file, position: 0}
          end
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.group_by(fn
        %Diagnostics{file: file} -> SourceFile.Path.to_uri(file, project_dir)
      end)

    uris_from_build_and_dialyzer_diagnostics =
      Map.keys(valid_build_and_dialyzer_diagnostics_by_uri)

    uris_from_open_files = Map.keys(source_files)

    uris_to_publish_diagnostics =
      Enum.uniq(
        last_published_diagnostics_uris ++
          uris_from_parser_diagnostics ++
          uris_from_build_and_dialyzer_diagnostics ++ uris_from_open_files
      )

    for uri <- uris_to_publish_diagnostics do
      {parser_diagnostics_document_version, parser_diagnostics} =
        Map.get(state.parser_diagnostics, uri, {nil, []})

      build_document_version = Map.get(state.document_versions_on_build, uri)

      build_and_dialyzer_diagnostics =
        Map.get(valid_build_and_dialyzer_diagnostics_by_uri, uri, [])

      {version, uri_diagnostics} =
        cond do
          is_integer(parser_diagnostics_document_version) and is_integer(build_document_version) and
              parser_diagnostics_document_version > build_document_version ->
            # document open and edited since build was triggered
            # parser diagnostics are more recent, discard build and dialyzer
            {parser_diagnostics_document_version, parser_diagnostics}

          is_integer(parser_diagnostics_document_version) and is_integer(build_document_version) and
              parser_diagnostics_document_version == build_document_version ->
            # document open and not edited since build was triggered
            # parser build and dialyzer diagnostics are recent
            # prefer them as they will likely contain the same warnings as parser ones
            {build_document_version,
             if(build_and_dialyzer_diagnostics != [],
               do: build_and_dialyzer_diagnostics,
               else: parser_diagnostics
             )}

          is_integer(parser_diagnostics_document_version) and is_nil(build_document_version) ->
            # document open but was closed when build was triggered
            # document could have been edited
            # combine diagnostics
            # they can be duplicated but it is not trivial to deduplicate here
            # instead we deduplicate on publish with rendered messages
            {parser_diagnostics_document_version,
             parser_diagnostics ++ build_and_dialyzer_diagnostics}

          true ->
            # document closed
            # don't emit parser diagnostics
            # return build diagnostics with possibly nil version
            {build_document_version, build_and_dialyzer_diagnostics}
        end

      Diagnostics.publish_file_diagnostics(
        uri,
        uri_diagnostics,
        Map.get_lazy(source_files, uri, fn -> safely_read_file(uri) end),
        version
      )

      # TODO dump last_published_diagnostics_uris to file?
    end

    %{state | last_published_diagnostics_uris: uris_to_publish_diagnostics}
  end

  defp show_version_warnings do
    case ElixirLS.Utils.MinimumVersion.check_elixir_version() do
      {:error, message} ->
        JsonRpc.show_message(:error, message)
        Process.sleep(5000)
        System.halt(1)

      {:warning, message} ->
        JsonRpc.show_message(:warning, message)

      :ok ->
        :ok
    end

    case ElixirLS.Utils.MinimumVersion.check_otp_version() do
      {:error, message} ->
        JsonRpc.show_message(:error, message)
        Process.sleep(5000)
        System.halt(1)

      {:warning, message} ->
        JsonRpc.show_message(:warning, message)

      :ok ->
        :ok
    end

    case Dialyzer.check_support() do
      :ok ->
        JsonRpc.telemetry(
          "dialyzer_support",
          %{
            "elixir_ls.dialyzer_support" => to_string(true),
            "elixir_ls.dialyzer_support_reason" => ""
          },
          %{}
        )

      {:error, reason, msg} ->
        JsonRpc.show_message(:warning, msg)

        JsonRpc.telemetry(
          "dialyzer_support",
          %{
            "elixir_ls.dialyzer_support" => to_string(false),
            "elixir_ls.dialyzer_support_reason" => to_string(reason)
          },
          %{}
        )
    end

    :ok
  end

  defp set_settings(state = %__MODULE__{}, settings) do
    enable_dialyzer =
      Dialyzer.check_support() == :ok and Map.get(settings, "autoBuild", true) and
        Map.get(settings, "dialyzerEnabled", true)

    if enable_dialyzer do
      dialyzer_warn_opts = Map.get(settings, "dialyzerWarnOpts", [])

      if not (is_list(dialyzer_warn_opts) and Enum.all?(dialyzer_warn_opts, &is_binary/1)) do
        Logger.error("Invalid `dialyzerWarnOpts` #{inspect(dialyzer_warn_opts)}")

        JsonRpc.show_message(
          :error,
          "Invalid `dialyzerWarnOpts` in configuration. Expected list of strings or nil, got #{inspect(dialyzer_warn_opts)}."
        )

        unless :persistent_term.get(:language_server_test_mode, false) do
          Process.sleep(2000)
          System.halt(1)
        else
          IO.warn("Invalid `dialyzerWarnOpts` #{inspect(dialyzer_warn_opts)}")
        end
      end

      try do
        ElixirLS.LanguageServer.Dialyzer.Analyzer.matching_tags(
          dialyzer_warn_opts
          |> Enum.map(&String.to_atom/1)
        )
      catch
        {:dialyzer_options_error, message} ->
          Logger.error("Invalid `dialyzerWarnOpts`: #{message}")

          JsonRpc.show_message(
            :error,
            "Invalid `dialyzerWarnOpts` in configuration. #{message}."
          )

          unless :persistent_term.get(:language_server_test_mode, false) do
            Process.sleep(2000)
            System.halt(1)
          else
            IO.warn("Invalid `dialyzerWarnOpts`: #{message}")
          end
      end

      dialyzer_formats = [
        "dialyzer",
        "dialyxir_short",
        "dialyxir_long"
      ]

      dialyzer_format = Map.get(settings, "dialyzerFormat", "dialyxir_long")

      if dialyzer_format not in dialyzer_formats do
        Logger.error("Invalid `dialyzerFormat` #{inspect(dialyzer_format)}")

        JsonRpc.show_message(
          :error,
          "Invalid `dialyzerFormat` in configuration. Expected one of #{Enum.join(dialyzer_formats, ", ")} or nil, got #{inspect(dialyzer_format)}."
        )

        unless :persistent_term.get(:language_server_test_mode, false) do
          Process.sleep(2000)
          System.halt(1)
        else
          IO.warn("Invalid `dialyzerFormat` #{inspect(dialyzer_format)}")
        end
      end
    end

    env_vars = Map.get(settings, "envVariables")
    mix_env = Map.get(settings, "mixEnv")
    mix_target = Map.get(settings, "mixTarget")
    project_dir = Map.get(settings, "projectDir")
    additional_watched_extensions = Map.get(settings, "additionalWatchedExtensions", [])
    stdlib_src_dir = to_string(Map.get(settings, "stdlibSrcDir", ""))

    if stdlib_src_dir != "" do
      Application.put_env(:language_server, :elixir_src, stdlib_src_dir)
    end

    state =
      state
      |> maybe_set_env_vars(env_vars)
      |> set_mix_env(mix_env)
      |> set_mix_target(mix_target)
      |> set_project_dir(project_dir)
      |> Map.put(:settings, settings)
      |> set_dialyzer_enabled(enable_dialyzer)

    add_watched_extensions(state.server_instance_id, additional_watched_extensions)

    # maybe_rebuild(state)
    state = create_gitignore(state)

    if state.mix_project? do
      WorkspaceSymbols.notify_settings_stored(state.project_dir)
      Tracer.notify_settings_stored(state.project_dir)
    end

    JsonRpc.telemetry(
      "lsp_config",
      %{
        "elixir_ls.projectDir" => to_string(Map.get(settings, "projectDir", "") != ""),
        "elixir_ls.autoBuild" => to_string(Map.get(settings, "autoBuild", true)),
        "elixir_ls.dialyzerEnabled" => to_string(Map.get(settings, "dialyzerEnabled", true)),
        "elixir_ls.fetchDeps" => to_string(Map.get(settings, "fetchDeps", false)),
        "elixir_ls.suggestSpecs" => to_string(Map.get(settings, "suggestSpecs", true)),
        "elixir_ls.autoInsertRequiredAlias" =>
          to_string(Map.get(settings, "autoInsertRequiredAlias", true)),
        "elixir_ls.signatureAfterComplete" =>
          to_string(Map.get(settings, "signatureAfterComplete", true)),
        "elixir_ls.enableTestLenses" => to_string(Map.get(settings, "enableTestLenses", false)),
        "elixir_ls.languageServerOverridePath" =>
          to_string(Map.get(settings, "languageServerOverridePath", "") != ""),
        "elixir_ls.envVariables" => to_string(Map.get(settings, "envVariables", %{}) != %{}),
        "elixir_ls.mixEnv" => to_string(Map.get(settings, "mixEnv", "test")),
        "elixir_ls.mixTarget" => to_string(Map.get(settings, "mixTarget", "host")),
        "elixir_ls.stdlibSrcDir" => stdlib_src_dir,
        "elixir_ls.dialyzerFormat" =>
          if(Map.get(settings, "dialyzerEnabled", true),
            do: Map.get(settings, "dialyzerFormat", "dialyxir_long"),
            else: ""
          )
      },
      %{}
    )

    # :observer.start()

    trigger_build(state)
  end

  defp add_watched_extensions(_server_instance_id, []) do
    :ok
  end

  defp add_watched_extensions(server_instance_id, exts) when is_list(exts) do
    if not (is_list(exts) and Enum.all?(exts, &match?("." <> _, &1))) do
      Logger.error("Invalid `additionalWatchedExtensions`: #{inspect(exts)}")

      JsonRpc.show_message(
        :error,
        "Invalid `additionalWatchedExtensions` in configuration. Expected list of extensions starting with `.` or nil, got #{inspect(exts)}."
      )

      unless :persistent_term.get(:language_server_test_mode, false) do
        Process.sleep(2000)
        System.halt(1)
      else
        IO.warn("Invalid `additionalWatchedExtensions`: #{inspect(exts)}")
      end
    end

    case JsonRpc.register_capability_request(
           server_instance_id,
           "workspace/didChangeWatchedFiles",
           %{
             "watchers" => Enum.map(exts, &%{"globPattern" => "**/*" <> &1})
           }
         ) do
      {:ok, nil} ->
        Logger.info("client/registerCapability succeeded")

      other ->
        Logger.error("client/registerCapability returned: #{inspect(other)}")

        JsonRpc.telemetry(
          "lsp_reverse_request_error",
          %{
            "elixir_ls.lsp_reverse_request_error" => inspect(other),
            "elixir_ls.lsp_reverse_request" => "client/registerCapability"
          },
          %{}
        )
    end
  end

  defp listen_for_configuration_changes(server_instance_id) do
    # the schema is not documented but uses https://github.com/microsoft/vscode-languageserver-node/blob/7792b0b21c994cc9bebc3117eeb652a22e2d9e1f/protocol/src/common/protocol.ts#L1504C18-L1504C59
    # passing empty map without `section` results in notification with `{"settings": null}` config but the server should
    # simply pull for configuration instead of depending on data sent in notification
    # see https://github.com/microsoft/language-server-protocol/issues/1792
    case JsonRpc.register_capability_request(
           server_instance_id,
           "workspace/didChangeConfiguration",
           %{}
         ) do
      {:ok, nil} ->
        Logger.info("client/registerCapability succeeded")

      other ->
        Logger.error("client/registerCapability returned: #{inspect(other)}")

        JsonRpc.telemetry(
          "lsp_reverse_request_error",
          %{
            "elixir_ls.lsp_reverse_request_error" => inspect(other),
            "elixir_ls.lsp_reverse_request" => "client/registerCapability"
          },
          %{}
        )
    end
  end

  defp set_dialyzer_enabled(state = %__MODULE__{}, enable_dialyzer) do
    cond do
      enable_dialyzer and state.mix_project? and state.dialyzer_sup == nil ->
        {:ok, pid} =
          Dialyzer.Supervisor.start_link(state.project_dir, dialyzer_module(state.settings))

        %{state | dialyzer_sup: pid, analysis_ready?: false}

      not (enable_dialyzer and state.mix_project?) and state.dialyzer_sup != nil ->
        Process.exit(state.dialyzer_sup, :normal)
        %{state | dialyzer_sup: nil, analysis_ready?: false}

      true ->
        state
    end
  end

  defp maybe_set_env_vars(state = %__MODULE__{}, nil), do: state

  defp maybe_set_env_vars(state = %__MODULE__{}, env) do
    prev_env = state.settings["envVariables"]

    if is_nil(prev_env) or env == prev_env do
      try do
        System.put_env(env)
      rescue
        e ->
          Logger.error(
            "Cannot set environment variables to #{inspect(env)}: #{Exception.message(e)}"
          )

          JsonRpc.show_message(
            :error,
            "Invalid `envVariables` in configuration. Expected a map with string key value pairs, got #{inspect(env)}."
          )

          unless :persistent_term.get(:language_server_test_mode, false) do
            Process.sleep(2000)
            System.halt(1)
          else
            IO.warn(
              "Cannot set environment variables to #{inspect(env)}: #{Exception.message(e)}"
            )
          end
      end
    else
      JsonRpc.show_message(
        :warning,
        "Environment variables change detected. ElixirLS will restart"
      )

      JsonRpc.telemetry(
        "lsp_reload",
        %{
          "elixir_ls.lsp_reload_reason" => "env_variables_changed"
        },
        %{}
      )

      # sleep so the client has time to show the message
      Process.sleep(5000)
      ElixirLS.LanguageServer.Application.restart()
      Process.sleep(:infinity)
    end

    state
  end

  defp set_mix_env(state = %__MODULE__{}, env) when env in [nil, ""] do
    # mix defaults to :dev env but we choose :test as this results in better
    # support for test files
    set_mix_env(state, "test")
  end

  defp set_mix_env(state = %__MODULE__{}, env) do
    prev_env = state.mix_env

    if is_nil(prev_env) or env == prev_env do
      try do
        System.put_env("MIX_ENV", env)
        Mix.env(String.to_atom(env))
        %{state | mix_env: env}
      rescue
        e ->
          Logger.error("Cannot set mix env to #{inspect(env)}: #{Exception.message(e)}")

          JsonRpc.show_message(
            :error,
            "Invalid `mixEnv` in configuration. Expected a string or nil, got #{inspect(env)}."
          )

          unless :persistent_term.get(:language_server_test_mode, false) do
            Process.sleep(2000)
            System.halt(1)
          else
            IO.warn("Cannot set mix env to #{inspect(env)}: #{Exception.message(e)}")
          end
      end
    else
      JsonRpc.show_message(:warning, "Mix env change detected. ElixirLS will restart.")

      JsonRpc.telemetry(
        "lsp_reload",
        %{
          "elixir_ls.lsp_reload_reason" => "mix_env_changed"
        },
        %{}
      )

      # sleep so the client has time to show the message
      Process.sleep(5000)
      ElixirLS.LanguageServer.Application.restart()
      Process.sleep(:infinity)
    end
  end

  defp set_mix_target(state = %__MODULE__{}, target) when target in [nil, ""] do
    # mix defaults to :host target
    set_mix_target(state, "host")
  end

  defp set_mix_target(state = %__MODULE__{}, target) do
    prev_target = state.mix_target

    if is_nil(prev_target) or target == prev_target do
      try do
        System.put_env("MIX_TARGET", target)
        Mix.target(String.to_atom(target))
        %{state | mix_target: target}
      rescue
        e ->
          Logger.error("Cannot set mix target to #{inspect(target)}: #{Exception.message(e)}")

          JsonRpc.show_message(
            :error,
            "Invalid `mixTarget` in configuration. Expected a string or nil, got #{inspect(target)}."
          )

          unless :persistent_term.get(:language_server_test_mode, false) do
            Process.sleep(2000)
            System.halt(1)
          else
            IO.warn("Cannot set mix target to #{inspect(target)}: #{Exception.message(e)}")
          end
      end
    else
      JsonRpc.show_message(:warning, "Mix target change detected. ElixirLS will restart")

      JsonRpc.telemetry(
        "lsp_reload",
        %{
          "elixir_ls.lsp_reload_reason" => "mix_target_changed"
        },
        %{}
      )

      # sleep so the client has time to show the message
      Process.sleep(5000)
      ElixirLS.LanguageServer.Application.restart()
      Process.sleep(:infinity)
    end
  end

  defp set_project_dir(
         %__MODULE__{project_dir: prev_project_dir, root_uri: root_uri} = state,
         project_dir_config
       )
       when is_binary(root_uri) do
    root_dir = SourceFile.Path.absolute_from_uri(root_uri)

    project_dir =
      if is_binary(project_dir_config) do
        SourceFile.Path.absname(Path.join(root_dir, project_dir_config))
      else
        if is_nil(project_dir_config) do
          root_dir
        else
          Logger.error("Invalid `projectDir`: #{inspect(project_dir_config)}")

          JsonRpc.show_message(
            :error,
            "Invalid `projectDir` in configuration. Expected a string or nil, got #{inspect(project_dir_config)}."
          )

          unless :persistent_term.get(:language_server_test_mode, false) do
            Process.sleep(2000)
            System.halt(1)
          else
            IO.warn("Invalid `projectDir`: #{inspect(project_dir_config)}")
          end
        end
      end

    cond do
      not File.dir?(project_dir) ->
        Logger.error("Project directory #{project_dir} does not exist")
        JsonRpc.show_message(:error, "Project directory #{project_dir} does not exist")

        unless :persistent_term.get(:language_server_test_mode, false) do
          Process.sleep(2000)
          System.halt(1)
        else
          IO.warn("Project directory #{project_dir} does not exist")
        end

      is_nil(prev_project_dir) ->
        with :ok <- File.cd(project_dir),
             {:ok, resolved_project_dir} <- File.cwd() do
          %{
            state
            | project_dir: resolved_project_dir,
              mix_project?: File.exists?(MixfileHelpers.mix_exs())
          }
        else
          {:error, reason} ->
            Logger.error("Unable to change directory into #{project_dir}: #{inspect(reason)}")

            JsonRpc.show_message(
              :error,
              "Unable to change directory into #{project_dir}: #{inspect(reason)}. " <>
                "Please make sure the directory exists and you have necessary permissions"
            )

            unless :persistent_term.get(:language_server_test_mode, false) do
              Process.sleep(2000)
              System.halt(1)
            else
              IO.warn("Unable to change directory into #{project_dir}: #{inspect(reason)}")
            end
        end

      prev_project_dir != project_dir ->
        JsonRpc.show_message(
          :warning,
          "Project directory change detected. ElixirLS will restart"
        )

        JsonRpc.telemetry(
          "lsp_reload",
          %{
            "elixir_ls.lsp_reload_reason" => "project_dir_changed"
          },
          %{}
        )

        # sleep so the client has time to show the message
        Process.sleep(5000)
        ElixirLS.LanguageServer.Application.restart()
        Process.sleep(:infinity)

      true ->
        state
    end
  end

  defp set_project_dir(state = %__MODULE__{}, _) do
    state
  end

  defp create_gitignore(%__MODULE__{project_dir: project_dir, mix_project?: true} = state)
       when is_binary(project_dir) do
    with gitignore_path <- Path.join([project_dir, ".elixir_ls", ".gitignore"]),
         false <- File.exists?(gitignore_path),
         :ok <- gitignore_path |> Path.dirname() |> File.mkdir_p(),
         :ok <- File.write(gitignore_path, "*", [:write]) do
      state
    else
      true ->
        state

      {:error, err} ->
        Logger.error("Cannot create .elixir_ls/.gitignore, cause: #{Atom.to_string(err)}")

        JsonRpc.show_message(
          :error,
          "Cannot create .elixir_ls/.gitignore"
        )

        unless :persistent_term.get(:language_server_test_mode, false) do
          Process.sleep(2000)
          System.halt(1)
        else
          IO.warn("Cannot create .elixir_ls/.gitignore, cause: #{Atom.to_string(err)}")
        end
    end
  end

  defp create_gitignore(state = %__MODULE__{}) do
    state
  end

  def get_source_file(state = %__MODULE__{}, uri) do
    case state.source_files[uri] do
      nil ->
        raise InvalidParamError, uri

      source_file ->
        source_file
    end
  end

  defp reject_awaiting_contracts(awaiting_contracts, uri) do
    Enum.reject(awaiting_contracts, fn
      {from, ^uri} -> GenServer.reply(from, [])
      _ -> false
    end)
  end

  defp pull_configuration(state) do
    supports_get_configuration =
      get_in(state.client_capabilities, [
        "workspace",
        "configuration"
      ])

    if supports_get_configuration do
      response = JsonRpc.get_configuration_request(state.root_uri, "elixirLS")

      case response do
        {:ok, [result]} when is_map(result) or is_nil(result) ->
          # result type is LSPAny, we need to handle at least map and nil
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_configuration
          result = result || %{}

          Logger.info(
            "Received client configuration via workspace/configuration\n#{inspect(result)}"
          )

          set_settings(state, result)

        other ->
          Logger.error("Cannot get client configuration: #{inspect(other)}")

          JsonRpc.telemetry(
            "lsp_reverse_request_error",
            %{
              "elixir_ls.lsp_reverse_request_error" => inspect(other),
              "elixir_ls.lsp_reverse_request" => "workspace/configuration"
            },
            %{}
          )

          state
      end
    else
      Logger.info("Client does not support workspace/configuration request")
      state
    end
  end

  defp dialyzer_module(settings) do
    otp_release = String.to_integer(System.otp_release())

    if otp_release >= 26 and Map.get(settings, "incrementalDialyzer", true) do
      DialyzerIncremental
    else
      Dialyzer
    end
  end

  def do_sanity_check(message \\ nil) do
    try do
      if message != nil and String.contains?(message, "UndefinedFunctionError") do
        raise "sanity check failed"
      end

      unless :persistent_term.get(:language_server_test_mode, false) do
        unless function_exported?(ElixirLS.LanguageServer, :module_info, 1) and
                 :persistent_term.get(:language_server_lib_dir) ==
                   ElixirLS.LanguageServer.module_info(:compile)[:source] do
          raise "sanity check failed"
        end

        unless function_exported?(ElixirSense, :module_info, 1) and
                 :persistent_term.get(:language_server_elixir_sense_lib_dir) ==
                   ElixirSense.module_info(:compile)[:source] do
          raise "sanity check failed"
        end
      end
    rescue
      _ ->
        Logger.error("Sanity check failed. ElixirLS needs to restart.")
        IO.warn("sanity")

        Process.sleep(2000)
        System.halt(1)
    end
  end
end
