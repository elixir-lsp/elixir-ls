defmodule ElixirLS.LanguageServer.Server do
  @moduledoc """
  Language Server Protocol server

  This server tracks open files, attempts to rebuild the project when a file changes, and handles
  requests from the IDE (for things like autocompletion, hover, etc.)

  Notifications from the IDE are handled synchronously, whereas requests can be handled sychronously
  or asynchronously.

  When possible, handling the request asynchronously has several advantages. The asynchronous
  request handling cannot modify the server state.  That way, if the process handling the request
  crashes, we can report that error to the client and continue knowing that the state is
  uncorrupted. Also, asynchronous requests can be cancelled by the client if they're taking too long
  or the user no longer cares about the result.
  """

  use GenServer
  alias ElixirLS.LanguageServer.{SourceFile, Build, Protocol, JsonRpc, Dialyzer}

  alias ElixirLS.LanguageServer.Providers.{
    Completion,
    Hover,
    Definition,
    References,
    Formatting,
    SignatureHelp,
    DocumentSymbols,
    OnTypeFormatting,
    CodeLens,
    ExecuteCommand
  }

  use Protocol
  require Logger

  defstruct [
    :build_ref,
    :dialyzer_sup,
    :client_capabilities,
    :root_uri,
    :project_dir,
    :settings,
    build_diagnostics: [],
    dialyzer_diagnostics: [],
    needs_build?: false,
    build_running?: false,
    analysis_ready?: false,
    received_shutdown?: false,
    requests: %{},
    source_files: %{},
    awaiting_contracts: []
  ]

  ## Client API

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, :ok, name: name)
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

  def rebuild(server \\ __MODULE__) do
    GenServer.cast(server, :rebuild)
  end

  def suggest_contracts(server \\ __MODULE__, uri) do
    GenServer.call(server, {:suggest_contracts, uri}, :infinity)
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  def handle_call({:request_finished, id, result}, _from, state) do
    case result do
      {:error, type, msg} -> JsonRpc.respond_with_error(id, type, msg)
      {:ok, result} -> JsonRpc.respond(id, result)
    end

    state = %{state | requests: Map.delete(state.requests, id)}
    {:reply, :ok, state}
  end

  def handle_call({:suggest_contracts, uri}, from, state) do
    case state do
      %{analysis_ready?: true, source_files: %{^uri => %{dirty?: false}}} ->
        {:reply, Dialyzer.suggest_contracts([uri]), state}

      _ ->
        {:noreply, %{state | awaiting_contracts: [{from, uri} | state.awaiting_contracts]}}
    end
  end

  def handle_call(msg, from, state) do
    super(msg, from, state)
  end

  def handle_cast({:build_finished, {status, diagnostics}}, state)
      when status in [:ok, :noop, :error] and is_list(diagnostics) do
    {:noreply, handle_build_result(status, diagnostics, state)}
  end

  # Pre Elixir 1.6, we can't get diagnostics from builds
  def handle_cast({:build_finished, _}, state) do
    {:noreply, handle_build_result(:ok, [], state)}
  end

  def handle_cast({:dialyzer_finished, diagnostics, build_ref}, state) do
    {:noreply, handle_dialyzer_result(diagnostics, build_ref, state)}
  end

  def handle_cast({:receive_packet, request(id, _, _) = packet}, state) do
    state =
      case handle_request(packet, state) do
        {:ok, result, state} ->
          JsonRpc.respond(id, result)
          state

        {:error, type, msg, state} ->
          JsonRpc.respond_with_error(id, type, msg)
          state

        {:async, fun, state} ->
          {pid, _ref} = handle_request_async(id, fun)
          %{state | requests: Map.put(state.requests, id, pid)}
      end

    {:noreply, state}
  end

  def handle_cast({:receive_packet, notification(_) = packet}, state) do
    {:noreply, handle_notification(packet, state)}
  end

  def handle_cast(:rebuild, state) do
    {:noreply, trigger_build(state)}
  end

  def handle_cast(msg, state) do
    super(msg, state)
  end

  def handle_info(:default_config, state) do
    state =
      case state do
        %{settings: nil} ->
          Logger.warn(
            "Did not receive workspace/didChangeConfiguration notification after 5 seconds. " <>
              "Using default settings."
          )

          set_settings(state, %{})

        _ ->
          state
      end

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, _, _pid, reason}, %{build_ref: ref, build_running?: true} = state) do
    state = %{state | build_running?: false}

    state =
      case reason do
        :normal -> state
        _ -> handle_build_result(:error, [Build.exception_to_diagnostic(reason)], state)
      end

    state = if state.needs_build?, do: trigger_build(state), else: state
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{requests: requests} = state) do
    state =
      case Enum.find(requests, &match?({_, ^pid}, &1)) do
        {id, _} ->
          error_msg = Exception.format_exit(reason)
          JsonRpc.respond_with_error(id, :server_error, error_msg)
          %{state | requests: Map.delete(requests, id)}

        nil ->
          state
      end

    {:noreply, state}
  end

  def handle_info(info, state) do
    super(info, state)
  end

  ## Helpers

  defp handle_notification(notification("initialized"), state) do
    state
  end

  defp handle_notification(notification("$/setTraceNotification"), state) do
    # noop
    state
  end

  defp handle_notification(cancel_request(id), %{requests: requests} = state) do
    case requests do
      %{^id => pid} ->
        Process.exit(pid, :cancelled)
        JsonRpc.respond_with_error(id, :request_cancelled, "Request cancelled")
        %{state | requests: Map.delete(requests, id)}

      _ ->
        state
    end
  end

  defp handle_notification(did_change_configuration(settings), state) do
    settings = Map.get(settings, "elixirLS", %{})
    set_settings(state, settings)
  end

  defp handle_notification(notification("exit"), state) do
    code = if state.received_shutdown?, do: 0, else: 1
    System.halt(code)
    state
  end

  defp handle_notification(did_open(uri, _language_id, version, text), state) do
    source_file = %SourceFile{text: text, version: version}

    Build.publish_file_diagnostics(
      uri,
      state.build_diagnostics ++ state.dialyzer_diagnostics,
      source_file
    )

    put_in(state.source_files[uri], source_file)
  end

  defp handle_notification(did_close(uri), state) do
    %{state | source_files: Map.delete(state.source_files, uri)}
  end

  defp handle_notification(did_change(uri, version, content_changes), state) do
    update_in(state.source_files[uri], fn source_file ->
      source_file = %{source_file | version: version, dirty?: true}
      SourceFile.apply_content_changes(source_file, content_changes)
    end)
  end

  defp handle_notification(did_save(uri), state) do
    state = update_in(state.source_files[uri], &%{&1 | dirty?: false})
    trigger_build(state)
  end

  defp handle_notification(did_change_watched_files(changes), state) do
    needs_build =
      Enum.any?(changes, fn %{"uri" => uri, "type" => type} ->
        Path.extname(uri) in [".ex", ".exs", ".erl", ".yrl", ".xrl", ".eex"] and
          (type in [1, 3] or not Map.has_key?(state.source_files, uri))
      end)

    if needs_build, do: trigger_build(state), else: state
  end

  defp handle_notification(notification(_, _) = packet, state) do
    IO.warn("Received unmatched notification: #{inspect(packet)}")
    state
  end

  defp handle_request(initialize_req(_id, root_uri, client_capabilities), state) do
    show_version_warnings()

    state =
      case root_uri do
        "file://" <> _ ->
          root_path = SourceFile.path_from_uri(root_uri)
          File.cd!(root_path)
          %{state | root_uri: root_uri}

        nil ->
          state
      end

    state = %{state | client_capabilities: client_capabilities}

    # If we don't receive workspace/didChangeConfiguration for 5 seconds, use default settings
    Process.send_after(self(), :default_config, 5000)

    {:ok, %{"capabilities" => server_capabilities()}, state}
  end

  defp handle_request(request(_id, "shutdown", _params), state) do
    {:ok, nil, %{state | received_shutdown?: true}}
  end

  defp handle_request(definition_req(_id, uri, line, character), state) do
    fun = fn ->
      Definition.definition(uri, state.source_files[uri].text, line, character)
    end

    {:async, fun, state}
  end

  defp handle_request(references_req(_id, uri, line, character, include_declaration), state) do
    fun = fn ->
      {:ok,
       References.references(
         state.source_files[uri].text,
         line,
         character,
         include_declaration
       )}
    end

    {:async, fun, state}
  end

  defp handle_request(hover_req(_id, uri, line, character), state) do
    fun = fn ->
      Hover.hover(state.source_files[uri].text, line, character)
    end

    {:async, fun, state}
  end

  defp handle_request(document_symbol_req(_id, uri), state) do
    fun = fn ->
      DocumentSymbols.symbols(uri, state.source_files[uri].text)
    end

    {:async, fun, state}
  end

  defp handle_request(completion_req(_id, uri, line, character), state) do
    snippets_supported =
      !!get_in(state.client_capabilities, [
        "textDocument",
        "completion",
        "completionItem",
        "snippetSupport"
      ])

    fun = fn ->
      Completion.completion(state.source_files[uri].text, line, character, snippets_supported)
    end

    {:async, fun, state}
  end

  defp handle_request(formatting_req(_id, uri, _options), state) do
    fun = fn -> Formatting.format(state.source_files[uri], uri, state.project_dir) end
    {:async, fun, state}
  end

  defp handle_request(signature_help_req(_id, uri, line, character), state) do
    fun = fn -> SignatureHelp.signature(state.source_files[uri], line, character) end
    {:async, fun, state}
  end

  defp handle_request(on_type_formatting_req(_id, uri, line, character, ch, options), state) do
    fun = fn ->
      OnTypeFormatting.format(state.source_files[uri], line, character, ch, options)
    end

    {:async, fun, state}
  end

  defp handle_request(code_lens_req(_id, uri), state) do
    if dialyzer_enabled?(state) and state.settings["suggestSpecs"] != false do
      %{^uri => %{text: text}} = state.source_files
      {:async, fn -> CodeLens.code_lens(uri, text) end, state}
    else
      {:ok, nil, state}
    end
  end

  defp handle_request(execute_command_req(_id, command, args), state) do
    {:async, fn -> ExecuteCommand.execute(command, args, state.source_files) end, state}
  end

  defp handle_request(request(_, _, _) = req, state) do
    IO.inspect(req, label: "Unmatched request")
    {:error, :invalid_request, nil, state}
  end

  defp handle_request_async(id, func) do
    parent = self()

    spawn_monitor(fn ->
      result = func.()
      GenServer.call(parent, {:request_finished, id, result}, :infinity)
    end)
  end

  defp server_capabilities do
    %{
      "textDocumentSync" => 2,
      "hoverProvider" => true,
      "completionProvider" => %{"triggerCharacters" => Completion.trigger_characters()},
      "definitionProvider" => true,
      "referencesProvider" => References.supported?(),
      "documentFormattingProvider" => Formatting.supported?(),
      "signatureHelpProvider" => %{"triggerCharacters" => ["("]},
      "documentSymbolProvider" => true,
      "documentOnTypeFormattingProvider" => %{"firstTriggerCharacter" => "\n"},
      "codeLensProvider" => %{"resolveProvider" => false},
      "executeCommandProvider" => %{"commands" => ["spec"]}
    }
  end

  # Build

  defp trigger_build(state) do
    if build_enabled?(state) and not state.build_running? do
      fetch_deps? = Map.get(state.settings || %{}, "fetchDeps", true)
      {_pid, build_ref} = Build.build(self(), state.project_dir, fetch_deps?)

      %__MODULE__{
        state
        | build_ref: build_ref,
          needs_build?: false,
          build_running?: true,
          analysis_ready?: false
      }
    else
      %__MODULE__{state | needs_build?: true, analysis_ready?: false}
    end
  end

  defp dialyze(state) do
    warn_opts =
      (state.settings["dialyzerWarnOpts"] || [])
      |> Enum.map(&String.to_atom/1)

    if dialyzer_enabled?(state), do: Dialyzer.analyze(state.build_ref, warn_opts)
    state
  end

  defp handle_build_result(status, diagnostics, state) do
    old_diagnostics = state.build_diagnostics ++ state.dialyzer_diagnostics
    state = put_in(state.build_diagnostics, diagnostics)

    state =
      cond do
        state.needs_build? ->
          state

        status == :error or not dialyzer_enabled?(state) ->
          put_in(state.dialyzer_diagnostics, [])

        true ->
          dialyze(state)
      end

    publish_diagnostics(
      state.build_diagnostics ++ state.dialyzer_diagnostics,
      old_diagnostics,
      state.source_files
    )

    state
  end

  defp handle_dialyzer_result(diagnostics, build_ref, state) do
    old_diagnostics = state.build_diagnostics ++ state.dialyzer_diagnostics
    state = put_in(state.dialyzer_diagnostics, diagnostics)

    publish_diagnostics(
      state.build_diagnostics ++ state.dialyzer_diagnostics,
      old_diagnostics,
      state.source_files
    )

    # If these results were triggered by the most recent build and files are not dirty, then we know
    # we're up to date and can release spec suggestions to the code lens provider
    if build_ref == state.build_ref do
      JsonRpc.log_message(:info, "Dialyzer analysis is up to date")

      {dirty, not_dirty} =
        Enum.split_with(state.awaiting_contracts, fn {_, uri} ->
          state.source_files[uri].dirty?
        end)

      contracts =
        not_dirty
        |> Enum.uniq()
        |> Enum.map(fn {_from, uri} -> SourceFile.path_from_uri(uri) end)
        |> Dialyzer.suggest_contracts()

      for {from, uri} <- not_dirty do
        contracts =
          Enum.filter(contracts, fn {file, _, _, _} -> SourceFile.path_from_uri(uri) == file end)

        GenServer.reply(from, contracts)
      end

      %{state | analysis_ready?: true, awaiting_contracts: dirty}
    else
      state
    end
  end

  defp build_enabled?(state) do
    is_binary(state.project_dir)
  end

  defp dialyzer_enabled?(state) do
    Dialyzer.check_support() == :ok and build_enabled?(state) and state.dialyzer_sup != nil
  end

  defp publish_diagnostics(new_diagnostics, old_diagnostics, source_files) do
    files =
      Enum.uniq(Enum.map(new_diagnostics, & &1.file) ++ Enum.map(old_diagnostics, & &1.file))

    for file <- files,
        uri = SourceFile.path_to_uri(file),
        do: Build.publish_file_diagnostics(uri, new_diagnostics, Map.get(source_files, uri))
  end

  defp show_version_warnings do
    unless Version.match?(System.version(), ">= 1.6.0") do
      JsonRpc.show_message(
        :warning,
        "Elixir versions below 1.6 are not supported. (Currently v#{System.version()})"
      )
    end

    otp_release = String.to_integer(System.otp_release())

    if otp_release < 19 do
      JsonRpc.show_message(
        :info,
        "Upgrade Erlang to version OTP 20 for debugging support (Currently OTP #{otp_release})"
      )
    end

    case Dialyzer.check_support() do
      :ok -> :ok
      {:error, msg} -> JsonRpc.show_message(:info, msg)
    end

    :ok
  end

  defp set_settings(state, settings) do
    enable_dialyzer =
      Dialyzer.check_support() == :ok && Map.get(settings, "dialyzerEnabled", true)

    mix_env = Map.get(settings, "mixEnv", "test")
    project_dir = Map.get(settings, "projectDir")

    state =
      state
      |> set_mix_env(mix_env)
      |> set_project_dir(project_dir)
      |> set_dialyzer_enabled(enable_dialyzer)

    trigger_build(%{state | settings: settings})
  end

  defp set_dialyzer_enabled(state, enable_dialyzer) do
    cond do
      enable_dialyzer and state.dialyzer_sup == nil and is_binary(state.project_dir) ->
        {:ok, pid} = Dialyzer.Supervisor.start_link(state.project_dir)
        %{state | dialyzer_sup: pid}

      not enable_dialyzer and state.dialyzer_sup != nil ->
        Process.exit(state.dialyzer_sup, :normal)
        %{state | dialyzer_sup: nil, analysis_ready?: false}

      true ->
        state
    end
  end

  defp set_mix_env(state, env) do
    prev_env = state.settings["mixEnv"]

    if is_nil(prev_env) or env == prev_env do
      Mix.env(String.to_atom(env))
    else
      JsonRpc.show_message(:warning, "You must restart ElixirLS after changing Mix env")
    end

    state
  end

  defp set_project_dir(%{project_dir: prev_project_dir, root_uri: root_uri} = state, project_dir)
       when is_binary(root_uri) do
    root_dir = SourceFile.path_from_uri(root_uri)

    project_dir =
      if is_binary(project_dir) do
        Path.absname(Path.join(root_dir, project_dir))
      else
        root_dir
      end

    cond do
      not File.dir?(project_dir) ->
        JsonRpc.show_message(:error, "Project directory #{project_dir} does not exist")
        state

      is_nil(prev_project_dir) ->
        File.cd!(project_dir)
        put_in(state.project_dir, project_dir)

      prev_project_dir != project_dir ->
        JsonRpc.show_message(
          :warning,
          "You must restart ElixirLS after changing the project directory"
        )

        state

      true ->
        state
    end
  end

  defp set_project_dir(state, _) do
    state
  end
end
