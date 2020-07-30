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
    WorkspaceSymbols,
    OnTypeFormatting,
    CodeLens,
    ExecuteCommand
  }

  use Protocol

  defstruct [
    :server_instance_id,
    :build_ref,
    :dialyzer_sup,
    :client_capabilities,
    :root_uri,
    :project_dir,
    :settings,
    build_diagnostics: [],
    dialyzer_diagnostics: [],
    needs_build?: false,
    load_all_modules?: false,
    build_running?: false,
    analysis_ready?: false,
    received_shutdown?: false,
    requests: %{},
    # Tracks source files that are currently open in the editor
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

  @impl GenServer
  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call({:request_finished, id, result}, _from, state) do
    case result do
      {:error, type, msg} -> JsonRpc.respond_with_error(id, type, msg)
      {:ok, result} -> JsonRpc.respond(id, result)
    end

    state = %{state | requests: Map.delete(state.requests, id)}
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:suggest_contracts, uri}, from, state) do
    case state do
      %{analysis_ready?: true, source_files: %{^uri => %{dirty?: false}}} ->
        {:reply, Dialyzer.suggest_contracts([SourceFile.path_from_uri(uri)]), state}

      _ ->
        {:noreply, %{state | awaiting_contracts: [{from, uri} | state.awaiting_contracts]}}
    end
  end

  @impl GenServer
  def handle_cast({:build_finished, {status, diagnostics}}, state)
      when status in [:ok, :noop, :error] and is_list(diagnostics) do
    {:noreply, handle_build_result(status, diagnostics, state)}
  end

  @impl GenServer
  def handle_cast({:dialyzer_finished, diagnostics, build_ref}, state) do
    {:noreply, handle_dialyzer_result(diagnostics, build_ref, state)}
  end

  @impl GenServer
  def handle_cast({:receive_packet, request(id, _, _) = packet}, state) do
    {:noreply, handle_request_packet(id, packet, state)}
  end

  def handle_cast({:receive_packet, request(id, method)}, state) do
    {:noreply, handle_request_packet(id, request(id, method, nil), state)}
  end

  @impl GenServer
  def handle_cast({:receive_packet, notification(_) = packet}, state) do
    {:noreply, handle_notification(packet, state)}
  end

  @impl GenServer
  def handle_cast(:rebuild, state) do
    {:noreply, trigger_build(state)}
  end

  @impl GenServer
  def handle_info(:send_file_watchers, state) do
    JsonRpc.register_capability_request("workspace/didChangeWatchedFiles", %{
      "watchers" => [
        %{"globPattern" => "**/*.ex"},
        %{"globPattern" => "**/*.exs"},
        %{"globPattern" => "**/*.eex"},
        %{"globPattern" => "**/*.leex"}
      ]
    })

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:default_config, state) do
    state =
      case state do
        %{settings: nil} ->
          JsonRpc.show_message(
            :info,
            "Did not receive workspace/didChangeConfiguration notification after 5 seconds. " <>
              "Using default settings."
          )

          set_settings(state, %{})

        _ ->
          state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, _, _pid, reason}, %{build_ref: ref, build_running?: true} = state) do
    state = %{state | build_running?: false}

    state =
      case reason do
        :normal -> state
        _ -> handle_build_result(:error, [Build.exception_to_diagnostic(reason)], state)
      end

    if reason == :normal do
      WorkspaceSymbols.notify_build_complete()
    end

    state = if state.needs_build?, do: trigger_build(state), else: state
    {:noreply, state}
  end

  @impl GenServer
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

  # We don't start performing builds until we receive settings from the client in case they've set
  # the `projectDir` or `mixEnv` settings. If the settings don't match the format expected, leave
  # settings unchanged or set default settings if this is the first request.
  defp handle_notification(did_change_configuration(changed_settings), state) do
    prev_settings = state.settings || %{}

    new_settings =
      case changed_settings do
        %{"elixirLS" => changed_settings} when is_map(changed_settings) ->
          Map.merge(prev_settings, changed_settings)

        _ ->
          prev_settings
      end

    set_settings(state, new_settings)
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
    awaiting_contracts =
      Enum.reject(state.awaiting_contracts, fn
        {from, ^uri} -> GenServer.reply(from, [])
        _ -> false
      end)

    %{
      state
      | source_files: Map.delete(state.source_files, uri),
        awaiting_contracts: awaiting_contracts
    }
  end

  defp handle_notification(did_change(uri, version, content_changes), state) do
    update_in(state.source_files[uri], fn
      nil ->
        # The source file was not marked as open either due to a bug in the
        # client or a restart of the server. So just ignore the message and do
        # not update the state
        JsonRpc.log_message(
          :warning,
          "Received textDocument/didChange for file that is not open. Received uri: #{
            inspect(uri)
          }"
        )

        nil

      source_file ->
        source_file = %{source_file | version: version, dirty?: true}
        SourceFile.apply_content_changes(source_file, content_changes)
    end)
  end

  defp handle_notification(did_save(uri), state) do
    WorkspaceSymbols.notify_uris_modified([uri])
    state = update_in(state.source_files[uri], &%{&1 | dirty?: false})
    trigger_build(state)
  end

  defp handle_notification(did_change_watched_files(changes), state) do
    needs_build =
      Enum.any?(changes, fn %{"uri" => uri, "type" => type} ->
        Path.extname(uri) in [".ex", ".exs", ".erl", ".yrl", ".xrl", ".eex", ".leex"] and
          (type in [1, 3] or not Map.has_key?(state.source_files, uri))
      end)

    changes
    |> Enum.map(& &1["uri"])
    |> Enum.uniq()
    |> WorkspaceSymbols.notify_uris_modified()

    if needs_build, do: trigger_build(state), else: state
  end

  defp handle_notification(notification(_, _) = packet, state) do
    IO.warn("Received unmatched notification: #{inspect(packet)}")
    state
  end

  defp handle_request_packet(id, packet, state) do
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
  end

  defp handle_request(initialize_req(_id, root_uri, client_capabilities), state) do
    show_version_warnings()

    server_instance_id =
      :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)

    state =
      case root_uri do
        "file://" <> _ ->
          root_path = SourceFile.path_from_uri(root_uri)
          File.cd!(root_path)
          %{state | root_uri: root_uri}

        nil ->
          state
      end

    state = %{
      state
      | client_capabilities: client_capabilities,
        server_instance_id: server_instance_id
    }

    # If we don't receive workspace/didChangeConfiguration for 5 seconds, use default settings
    Process.send_after(self(), :default_config, 5000)

    # Explicitly request file watchers from the client if supported
    supports_dynamic =
      get_in(client_capabilities, [
        "textDocument",
        "codeAction",
        "dynamicRegistration"
      ])

    if supports_dynamic do
      Process.send_after(self(), :send_file_watchers, 100)
    end

    {:ok, %{"capabilities" => server_capabilities(server_instance_id)}, state}
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
         uri,
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
      hierarchical? =
        get_in(state.client_capabilities, [
          "textDocument",
          "documentSymbol",
          "hierarchicalDocumentSymbolSupport"
        ]) || false

      source_file = state.source_files[uri]

      if source_file && String.ends_with?(uri, [".ex", ".exs"]) do
        DocumentSymbols.symbols(uri, source_file.text, hierarchical?)
      else
        {:ok, []}
      end
    end

    {:async, fun, state}
  end

  defp handle_request(workspace_symbol_req(_id, query), state) do
    fun = fn ->
      state.source_files
      WorkspaceSymbols.symbols(query)
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
      case SourceFile.formatter_opts(uri) do
        {:ok, opts} -> Keyword.get(opts, :locals_without_parens, [])
        :error -> []
      end
      |> MapSet.new()

    signature_after_complete = Map.get(state.settings || %{}, "signatureAfterComplete", true)

    fun = fn ->
      Completion.completion(state.source_files[uri].text, line, character,
        snippets_supported: snippets_supported,
        deprecated_supported: deprecated_supported,
        tags_supported: tags_supported,
        signature_help_supported: signature_help_supported,
        locals_without_parens: locals_without_parens,
        signature_after_complete: signature_after_complete
      )
    end

    {:async, fun, state}
  end

  defp handle_request(formatting_req(_id, uri, _options), state) do
    case state.source_files[uri] do
      nil ->
        {:error, :server_error, "Missing source file", state}

      source_file ->
        fun = fn -> Formatting.format(source_file, uri, state.project_dir) end
        {:async, fun, state}
    end
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
      {:async,
       fn -> CodeLens.code_lens(state.server_instance_id, uri, state.source_files[uri].text) end,
       state}
    else
      {:ok, nil, state}
    end
  end

  defp handle_request(execute_command_req(_id, command, args), state) do
    {:async, fn -> ExecuteCommand.execute(command, args, state.source_files) end, state}
  end

  defp handle_request(macro_expansion(_id, whole_buffer, selected_macro, macro_line), state) do
    x = ElixirSense.expand_full(whole_buffer, selected_macro, macro_line)
    {:ok, x, state}
  end

  defp handle_request(request(_, _) = req, state) do
    handle_invalid_request(req, state)
  end

  defp handle_request(request(_, _, _) = req, state) do
    handle_invalid_request(req, state)
  end

  defp handle_invalid_request(req, state) do
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
      "referencesProvider" => References.supported?(),
      "documentFormattingProvider" => Formatting.supported?(),
      "signatureHelpProvider" => %{"triggerCharacters" => ["("]},
      "documentSymbolProvider" => true,
      "workspaceSymbolProvider" => true,
      "documentOnTypeFormattingProvider" => %{"firstTriggerCharacter" => "\n"},
      "codeLensProvider" => %{"resolveProvider" => false},
      "executeCommandProvider" => %{"commands" => ["spec:#{server_instance_id}"]},
      "workspace" => %{
        "workspaceFolders" => %{"supported" => false, "changeNotifications" => false}
      }
    }
  end

  # Build

  defp trigger_build(state) do
    if build_enabled?(state) and not state.build_running? do
      fetch_deps? = Map.get(state.settings || %{}, "fetchDeps", true)

      {_pid, build_ref} =
        Build.build(self(), state.project_dir,
          fetch_deps?: fetch_deps?,
          load_all_modules?: state.load_all_modules?
        )

      %__MODULE__{
        state
        | build_ref: build_ref,
          needs_build?: false,
          build_running?: true,
          analysis_ready?: false,
          load_all_modules?: false
      }
    else
      %__MODULE__{state | needs_build?: true, analysis_ready?: false}
    end
  end

  defp dialyze(state) do
    warn_opts =
      (state.settings["dialyzerWarnOpts"] || [])
      |> Enum.map(&String.to_atom/1)

    if dialyzer_enabled?(state),
      do: Dialyzer.analyze(state.build_ref, warn_opts, dialyzer_default_format(state))

    state
  end

  defp dialyzer_default_format(state) do
    state.settings["dialyzerFormat"] || "dialyxir_long"
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
        state.awaiting_contracts
        |> Enum.filter(fn {_, uri} ->
          state.source_files[uri] != nil
        end)
        |> Enum.split_with(fn {_, uri} ->
          state.source_files[uri].dirty?
        end)

      contracts =
        not_dirty
        |> Enum.uniq()
        |> Enum.map(fn {_from, uri} -> SourceFile.path_from_uri(uri) end)
        |> Dialyzer.suggest_contracts()

      for {from, uri} <- not_dirty do
        contracts =
          Enum.filter(contracts, fn {file, _, _, _, _} ->
            SourceFile.path_from_uri(uri) == file
          end)

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
    unless Version.match?(System.version(), ">= 1.7.0") do
      JsonRpc.show_message(
        :warning,
        "Elixir versions below 1.7 are not supported. (Currently v#{System.version()})"
      )
    end

    otp_release = String.to_integer(System.otp_release())

    if otp_release < 20 do
      JsonRpc.show_message(
        :info,
        "Erlang OTP releases below 20 are not supported (Currently OTP #{otp_release})"
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
    mix_target = Map.get(settings, "mixTarget")
    project_dir = Map.get(settings, "projectDir")

    state =
      state
      |> set_mix_env(mix_env)
      |> maybe_set_mix_target(mix_target)
      |> set_project_dir(project_dir)
      |> set_dialyzer_enabled(enable_dialyzer)

    state = create_gitignore(state)
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

  defp maybe_set_mix_target(state, nil), do: state

  defp maybe_set_mix_target(state, target) do
    if Version.match?(System.version(), ">= 1.8.0") do
      set_mix_target(state, target)
    else
      JsonRpc.show_message(
        :warning,
        "MIX_TARGET was set, but it requires Elixir >= 1.8.0. This setting will be ignored"
      )

      state
    end
  end

  defp set_mix_target(state, target) do
    target = target || "host"

    prev_target = state.settings["mixTarget"]

    if is_nil(prev_target) or target == prev_target do
      # We've already checked for Elixir >= 1.8.0 by this point
      # but compilation will fail if we just call Mix.target/0
      # so we get around that via apply/3
      apply(Mix, :target, [String.to_atom(target)])
    else
      JsonRpc.show_message(:warning, "You must restart ElixirLS after changing Mix target")
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
        Map.merge(state, %{project_dir: project_dir, load_all_modules?: true})

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

  defp create_gitignore(%{project_dir: project_dir} = state) when is_binary(project_dir) do
    with gitignore_path <- Path.join([project_dir, ".elixir_ls", ".gitignore"]),
         false <- File.exists?(gitignore_path),
         :ok <- gitignore_path |> Path.dirname() |> File.mkdir_p(),
         :ok <- File.write(gitignore_path, "*", [:write]) do
      state
    else
      true ->
        state

      {:error, err} ->
        JsonRpc.log_message(
          :warning,
          "Cannot create .elixir_ls/.gitignore, cause: #{Atom.to_string(err)}"
        )

        state
    end
  end

  defp create_gitignore(state) do
    JsonRpc.log_message(
      :warning,
      "Cannot create .elixir_ls/.gitignore, cause: project_dir not set"
    )

    state
  end
end
