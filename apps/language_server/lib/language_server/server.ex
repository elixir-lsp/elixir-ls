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
  or the user no longer cares about the result. Regardless of completion order, the protocol
  specifies that requests must be replied to in the order they are received.
  """

  use GenServer
  alias ElixirLS.LanguageServer.{SourceFile, BuildError, Builder, Protocol, JsonRpc, 
                                 Completion, Hover, Definition}
  require Logger
  use Protocol

  defstruct [
    build_errors: %{},
    build_failures: 0,
    builder: nil,
    changed_sources: %{},
    client_capabilities: nil,
    currently_compiling: nil, 
    force_rebuild?: false,
    received_shutdown?: false, 
    requests: [],
    root_uri: nil,
    settings: nil,
    source_files: %{},
  ]

  defmodule Request do
    defstruct [:id, :status, :pid, :ref, :result, :error_type, :error_msg]
  end

  ## Client API

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def receive_packet(server \\ __MODULE__, packet) do
    GenServer.call(server, {:receive_packet, packet})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  def handle_call({:request_finished, id, {:error, type, msg}}, _from, state) do
    state = update_request(state, id, &(%{&1 | status: :error, error_type: type, error_msg: msg}))
    {:reply, :ok, send_responses(state)}
  end

  def handle_call({:request_finished, id, {:ok, result}}, _from, state) do
    state = update_request(state, id, &(%{&1 | status: :ok, result: result}))
    {:reply, :ok, send_responses(state)}
  end

  def handle_call({:build_finished, build_errors}, _from, state) do
    state = update_build_errors(build_errors, state)
    state = %{state | currently_compiling: nil, build_failures: 0}
    state = 
      if pending_changes?(state) do
        queue_build(state)
      else
        state
      end

    {:reply, :ok, state}
  end

  def handle_call({:build_failed, error}, _from, state) do
    {:reply, :ok, build_failed(error, state)}
  end

  def handle_call({:receive_packet, request(id, _, _) = packet}, _from, state) do 
    {request, state} = 
      case handle_request(packet, state) do
        {:ok, result, state} ->
          {%Request{id: id, status: :ok, result: result}, state}
        {:error, type, msg, state} ->
          {%Request{id: id, status: :error, error_type: type, error_msg: msg}, state}
        {:async, fun, state} ->
          {pid, ref} = handle_request_async(id, fun)
          {%Request{id: id, status: :async, pid: pid, ref: ref}, state}
      end

    state = %{state | requests: state.requests ++ [request]}
    {:reply, :ok, send_responses(state)}
  end

  def handle_call({:receive_packet, notification(_) = packet}, _from, state) do
    {:reply, :ok, handle_notification(packet, state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, :normal}, state) do
    state = 
      update_request_by_ref state, ref, fn
        %{status: :async} = req ->
          error_msg = "Internal error: Request ended without result"
          %{req | ref: nil, pid: nil, status: :error, error_type: :internal_error, 
                  error_msg: error_msg}
        req ->
          %{req | ref: nil, pid: nil}
      end

    {:noreply, send_responses(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    state = 
      update_request_by_ref state, ref, fn
        %{status: :async} = req ->
          error_msg = "Internal error: " <> Exception.format_exit(reason)
          %{req | ref: nil, pid: nil, status: :error, error_type: :internal_error, 
                  error_msg: error_msg}
        req ->
          %{req | ref: nil, pid: nil}
      end

    {:noreply, send_responses(state)}
  end

  def handle_info(info, state) do
    super(info, state)
  end

  def terminate(reason, state) do
    unless reason == :normal do
      msg = "Elixir Language Server terminated abnormally because "
        <> Exception.format_exit(reason)
      JsonRpc.log_message(:error, msg)
    end
    super(reason, state)
  end

  ## Helpers

  defp find_and_update(list, find_fn, update_fn) do
    idx = Enum.find_index(list, find_fn)
    if idx do
      List.update_at(list, idx, update_fn)
    else
      list
    end
  end

  defp handle_notification(notification("initialized"), state) do
    state  # noop
  end

  defp handle_notification(notification("$/setTraceNotification"), state) do
    state  # noop
  end

  defp handle_notification(cancel_request(id), state) do
    state = 
      update_request state, id, fn
        %{status: :async, pid: pid} = req ->
          Process.exit(pid, :kill)
          %{req | pid: nil, ref: nil, status: :error, error_type: :request_cancelled}
        req ->
          req
      end

    send_responses(state)
  end

  defp handle_notification(did_change_configuration(settings), state) do
    %{state | settings: settings}
  end

  defp handle_notification(notification("exit"), state) do
    System.halt(0)
    state
  end

  defp handle_notification(did_open(uri, _language_id, version, text), state) do
    path = if is_binary(state.root_uri), do: Path.relative_to(uri, state.root_uri)
    source_file = %SourceFile{text: text, path: path, version: version}
    publish_file_diagnostics(uri, state.build_errors[uri], source_file)
    state = put_in state.source_files[uri], source_file
    track_change(uri, source_file, state)
  end

  defp handle_notification(did_close(uri), state) do
    state = %{state | source_files: Map.delete(state.source_files, uri)}
    track_change(uri, nil, state)
  end

  defp handle_notification(did_change(uri, version, content_changes), state) do
    state = 
      update_in state.source_files[uri], fn source_file ->
        source_file = %{source_file | version: version}
        SourceFile.apply_content_changes(source_file, content_changes)
      end

    track_change(uri, state.source_files[uri], state)
  end

  defp handle_notification(did_save(uri), state) do
    track_change(uri, state.source_files[uri], state)
  end

  defp handle_notification(did_change_watched_files(_changes), state) do
    force_build(state)
  end

  defp handle_notification(notification(_, _) = packet, state) do
    Logger.warn("Received unmatched notification: #{inspect(packet)}")
    state
  end

  defp handle_request(initialize_req(_id, root_uri, client_capabilities), state) do
    state = %{state | root_uri: root_uri}
    Mix.ProjectStack.clear_stack
    state = 
      case root_uri do
        "file://" <> root_path ->
          File.cd!(root_path)
          force_build(state)
        _ ->
          state
      end

    state = %{state | client_capabilities: client_capabilities, root_uri: root_uri}

    {:ok, %{"capabilities" => server_capabilities()}, state}
  end

  defp handle_request(request(_id, "shutdown", _params), state) do
    {:ok, nil, %{state | received_shutdown?: true}}
  end

  defp handle_request(definition_req(_id, uri, line, character), state) do
    fun = fn ->
      {:ok, Definition.definition(state.source_files[uri].text, line, character)}
    end
    {:async, fun, state}
  end

  defp handle_request(hover_req(_id, uri, line, character), state) do
    fun = fn ->
      {:ok, Hover.hover(state.source_files[uri].text, line, character)}
    end
    {:async, fun, state}
  end

  defp handle_request(completion_req(_id, uri, line, character), state) do
    fun = fn ->
      {:ok, Completion.completion(state.source_files[uri].text, line, character)}
    end
    {:async, fun, state}
  end

  defp handle_request(request(_, _, _), state) do
    {:error, :invalid_request, nil, state}
  end

  defp handle_request_async(id, func) do
    parent = self()
    Process.spawn(fn ->
      result = func.()
      GenServer.call(parent, {:request_finished, id, result})
    end, [:monitor])
  end

  defp publish_file_diagnostics(uri, build_errors, source_file) do
    diagnostics = for error <- build_errors || [], do: BuildError.to_diagnostic(error, source_file)
    JsonRpc.notify("textDocument/publishDiagnostics", %{"uri" => uri, "diagnostics" => diagnostics})
  end

  defp send_responses(state) do
    case state.requests do
      [%Request{id: id, status: :ok, result: result} | rest] ->
        JsonRpc.respond(id, result)
        send_responses(%{state | requests: rest})
      [%Request{id: id, status: :error, error_type: error_type, error_msg: error_msg} | rest] ->
        JsonRpc.respond_with_error(id, error_type, error_msg)
        send_responses(%{state | requests: rest})
      _ ->
        state
    end
  end

  defp server_capabilities do
    %{"textDocumentSync" => 1,
      "hoverProvider" => true,
      "completionProvider" => %{},
      "definitionProvider" => true}
  end

  defp update_request(state, id, update_fn) do
    update_in state.requests, fn requests ->
      find_and_update(requests, &(&1.id == id), update_fn)
    end
  end

  defp update_request_by_ref(state, ref, update_fn) do
    update_in state.requests, fn requests ->
      find_and_update(requests, &(&1.ref == ref), update_fn)
    end
  end

  defp track_change(uri, source_file, state) do
    state = put_in state.changed_sources[uri], source_file
    queue_build(state)
  end

  defp force_build(state) do
    state = %{state | force_rebuild?: true}
    queue_build(state)
  end

  defp update_build_errors(build_errors, state) do
    build_errors = Enum.group_by(build_errors, &(Path.join(state.root_uri, &1.file)))

    all_uris = 
      [Map.keys(state.build_errors), Map.keys(build_errors), Map.keys(state.source_files)]
      |> List.flatten
      |> Enum.uniq

    for uri <- all_uris do
      publish_file_diagnostics(uri, build_errors[uri], state.source_files[uri])
    end

    %{state | build_errors: build_errors}
  end

  defp build_failed(error, state) do
    Logger.warn("Build failed: #{inspect(error)}")
    cond do
      pending_changes?(state) ->
        # Retry with the new changes
        all_sources = Map.merge(state.currently_compiling, state.changed_sources)
        build_async(all_sources)
        %{state | currently_compiling: all_sources, changed_sources: %{}, force_rebuild?: false}
      state.build_failures >= 3 ->
        if state.build_failures == 3 do
          message = 
            "Build failed after #{state.build_failures} tries. See error log for details."
          JsonRpc.show_message(:error, message)
        end

        # Wait for additional file changes before retrying the build
        %{state | changed_sources: state.currently_compiling, currently_compiling: nil, 
                  build_failures: state.build_failures + 1}
      true ->
        build_async(state.currently_compiling)
        %{state | build_failures: state.build_failures + 1, force_rebuild?: false}
    end
  end

  defp pending_changes?(state) do
    state.changed_sources != %{} or state.force_rebuild?
  end
        
  defp queue_build(state) do
    if state.currently_compiling == nil and match?("file://" <> _, state.root_uri) do
      build_async(state.changed_sources)
      %{state | currently_compiling: state.changed_sources, changed_sources: %{}, 
                force_rebuild?: false}
    else
      state
    end
  end

  defp build_async(source_files) do
    parent = self()
    Process.spawn(fn ->
      case Builder.build(source_files) do
        {:ok, build_errors} -> GenServer.call(parent, {:build_finished, build_errors})
        {:error, error} -> GenServer.call(parent, {:build_failed, error})
      end
    end, [:link])
  end
end
