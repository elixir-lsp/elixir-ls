defmodule ElixirLS.DebugAdapter.Server do
  @moduledoc """
  Implements Debug Adapter Protocol

  Refer to the protocol's [documentation](https://microsoft.github.io/debug-adapter-protocol)
  for details.

  The protocol specifies that we must assign unique IDs to "threads" (or processes), to stack
  frames, and to any variables that can be expanded. We keep a counter with the next ID to use and
  increment it any time we assign an ID. Note that besides thread ids all other are defined in
  the suspended state and can be reused.
  See [Lifetime of Objects References](https://microsoft.github.io/debug-adapter-protocol/overview#lifetime-of-objects-references)
  """

  defmodule ServerError do
    defexception [:message, :format, :variables, {:send_telemetry, true}, {:show_user, false}]
  end

  alias ElixirLS.DebugAdapter.{
    Output,
    Stacktrace,
    Variables,
    Utils,
    BreakpointCondition,
    Binding,
    ModuleInfoCache,
    IdManager,
    VariableRegistry,
    ThreadRegistry,
    ErrorDictionary
  }

  alias ElixirLS.DebugAdapter.Stacktrace.Frame
  alias ElixirLS.Utils.Launch
  import ElixirLS.DebugAdapter.Protocol.Basic
  use GenServer

  @temp_beam_dir ".elixir_ls/temp_beams"

  defmodule PausedProcess do
    defstruct stack: nil,
              registry: %ElixirLS.DebugAdapter.VariableRegistry{},
              ref: nil
  end

  defstruct client_info: nil,
            config: %{},
            dbg_session: nil,
            task_ref: nil,
            update_threads_ref: nil,
            thread_registry: %ThreadRegistry{},
            paused_processes: %{},
            requests: %{},
            requests_seqs_by_pid: %{},
            progresses: MapSet.new(),
            output: Output,
            breakpoints: %{},
            function_breakpoints: %{}

  ## Client API

  def start_link(opts \\ []) do
    name = opts[:name]
    opts = Keyword.delete(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def receive_packet(server \\ __MODULE__, packet) do
    GenServer.cast(server, {:receive_packet, packet})
  end

  def breakpoint_reached(pid, server) do
    GenServer.cast(server, {:breakpoint_reached, pid})
  end

  def paused(pid, server) do
    GenServer.cast(server, {:paused, pid})
  end

  @spec dbg(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def dbg({:|>, _meta, _args} = ast, options, %Macro.Env{} = env) when is_list(options) do
    [first_ast_chunk | asts_chunks] = ast |> Macro.unpipe() |> chunk_pipeline_asts_by_line(env)

    initial_acc = [
      quote do
        env = __ENV__
        options = unquote(options)

        options =
          if IO.ANSI.enabled?() do
            Keyword.put_new(options, :syntax_colors, IO.ANSI.syntax_colors())
          else
            options
          end

        env = unquote(env_with_line_from_asts(first_ast_chunk))

        next? = unquote(__MODULE__).__next__(true, binding(), env)
        value = unquote(pipe_chunk_of_asts(first_ast_chunk))

        unquote(__MODULE__).__dbg_pipe_step__(
          value,
          unquote(asts_chunk_to_strings(first_ast_chunk)),
          _start_with_pipe? = false,
          options
        )
      end
    ]

    for asts_chunk <- asts_chunks, reduce: initial_acc do
      ast_acc ->
        piped_asts = pipe_chunk_of_asts([{quote(do: value), _index = 0}] ++ asts_chunk)

        quote do
          unquote(ast_acc)
          env = unquote(env_with_line_from_asts(asts_chunk))
          next? = unquote(__MODULE__).__next__(next?, binding(), env)
          value = unquote(piped_asts)

          unquote(__MODULE__).__dbg_pipe_step__(
            value,
            unquote(asts_chunk_to_strings(asts_chunk)),
            _start_with_pipe? = true,
            options
          )
        end
    end
  end

  def dbg(code, options, %Macro.Env{} = caller) do
    quote do
      {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
      GenServer.call(unquote(__MODULE__), {:dbg, binding(), __ENV__, stacktrace}, :infinity)
      unquote(Macro.dbg(code, options, caller))
    end
  end

  def __next__(next?, binding, opts_or_env) when is_boolean(next?) do
    if next? do
      {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

      GenServer.call(__MODULE__, {:dbg, binding, opts_or_env, stacktrace}, :infinity) ==
        {:ok, true}
    else
      false
    end
  end

  @elixir_internals [:elixir, :erl_eval]
  @elixir_ls_internals [__MODULE__]
  @debugger_internals @elixir_internals ++ @elixir_ls_internals

  defp prune_stacktrace([{mod, _, _, _} | t]) when mod in @debugger_internals do
    prune_stacktrace(t)
  end

  defp prune_stacktrace([{Process, :info, 2, _} | t]) do
    prune_stacktrace(t)
  end

  defp prune_stacktrace([h | t]) do
    [h | prune_stacktrace(t)]
  end

  defp prune_stacktrace([]) do
    []
  end

  ## Server Callbacks

  @impl GenServer
  def init(opts) do
    IdManager.init()
    state = if opts[:output], do: %__MODULE__{output: opts[:output]}, else: %__MODULE__{}

    # Initialize the evaluator process entry
    evaluator_process = %PausedProcess{}
    state = put_in(state.paused_processes[:evaluator], evaluator_process)

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    IdManager.cleanup()

    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        message = Exception.format_exit(reason)

        Output.telemetry(
          "dap_server_error",
          %{
            "elixir_ls.dap_process" => inspect(__MODULE__),
            "elixir_ls.dap_server_error" => message
          },
          %{}
        )

        Output.debugger_important("Terminating #{__MODULE__}: #{message}")

        unless :persistent_term.get(:debug_adapter_test_mode, false) do
          System.halt(1)
        end
    end

    :ok
  end

  @impl GenServer
  def handle_call(
        {:dbg, _binding, %Macro.Env{}, _stacktrace},
        _from,
        state = %__MODULE__{config: %{"noDebug" => true}}
      ) do
    # auto continue
    {:reply, {:ok, false}, state}
  end

  def handle_call(
        {:dbg, _binding, %Macro.Env{}, _stacktrace},
        _from,
        state = %__MODULE__{config: %{"breakOnDbg" => false}}
      ) do
    # auto continue
    {:reply, {:ok, false}, state}
  end

  def handle_call({:dbg, binding, %Macro.Env{} = env, stacktrace}, from, state = %__MODULE__{}) do
    {pid, _ref} = from
    ref = Process.monitor(pid)

    {state, thread_id, _new_ids} = ensure_thread_id(state, pid, [])

    stacktrace =
      case Stacktrace.get(pid) do
        [_gen_server_frame, first_frame | stacktrace] ->
          # drop GenServer call to DebugAdapter.Server from dbg callback
          # overwrite erlang debugger bindings with exact elixir ones
          first_frame = %{
            first_frame
            | bindings: Map.new(binding),
              dbg_frame?: true,
              dbg_env: env,
              module: env.module,
              function: env.function,
              file: env.file,
              line: env.line || 1
          }

          [first_frame | stacktrace]

        _ ->
          # no stacktrace if we are running in non interpreted mode
          # or only 1 frame with module: :undefined, function: {:undefined, :undefined}, args: :undefined
          # build frames from Process.info stacktrace
          # drop first entry as we get it from env
          [_ | stacktrace_rest] = prune_stacktrace(stacktrace)

          total_frames = length(stacktrace_rest) + 1

          first_frame = %Frame{
            level: total_frames,
            module: env.module,
            function: env.function,
            file: env.file,
            args: [],
            messages: [],
            bindings: Map.new(binding),
            dbg_frame?: true,
            dbg_env: env,
            line: env.line || 1
          }

          frames_rest =
            for {{m, f, a, keyword}, index} <- Enum.with_index(stacktrace_rest, 1) do
              file = Stacktrace.get_file(m)
              line = Keyword.get(keyword, :line, 1)

              %Frame{
                level: total_frames - index,
                module: m,
                function: {f, a},
                file: file,
                args: [],
                messages: [],
                bindings: %{},
                dbg_frame?: true,
                dbg_env: nil,
                line: line
              }
            end

          [first_frame | frames_rest]
      end

    paused_process = %PausedProcess{stack: stacktrace, ref: ref}
    state = put_in(state.paused_processes[pid], paused_process)

    Output.send_event(%GenDAP.Events.StoppedEvent{
      seq: nil,
      body: %{reason: "breakpoint", thread_id: thread_id, all_threads_stopped: false}
    })

    {:noreply, %{state | dbg_session: from}}
  end

  def handle_call(
        {:request_finished, request(_, command) = packet, start_time, result},
        _from,
        state = %__MODULE__{}
      ) do
    seq = packet["seq"]
    {request, updated_requests} = Map.pop(state.requests, seq)

    {updated_requests_seqs_by_pid, updated_progresses} =
      if request do
        {pid, ref, _packet} = request

        # we are not interested in :DOWN message anymore
        Process.demonitor(ref, [:flush])

        updated_progresses =
          if MapSet.member?(state.progresses, seq) do
            Output.send_event(%GenDAP.Events.ProgressEndEvent{
              seq: nil,
              body: %{
                progress_id: to_string(seq)
              }
            })

            MapSet.delete(state.progresses, seq)
          else
            state.progresses
          end

        case result do
          {:error, e = %ServerError{}} ->
            Output.send_error_response(
              packet,
              ErrorDictionary.code(e.message),
              e.message,
              e.format,
              e.variables,
              e.send_telemetry,
              e.show_user
            )

          {:ok, response_body} ->
            elapsed = System.monotonic_time(:millisecond) - start_time
            Output.send_response(packet, response_body)

            Output.telemetry(
              "dap_request",
              %{"elixir_ls.dap_command" => String.replace(command, "/", "_")},
              %{
                "elixir_ls.dap_request_time" => elapsed
              }
            )
        end

        {Map.delete(state.requests_seqs_by_pid, pid), updated_progresses}
      else
        {state.requests_seqs_by_pid, state.progresses}
      end

    state = %{
      state
      | requests: updated_requests,
        requests_seqs_by_pid: updated_requests_seqs_by_pid,
        progresses: updated_progresses
    }

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast(
        {:receive_packet, request(seq, "disconnect" = command) = packet},
        state = %__MODULE__{}
      ) do
    case GenDAP.Requests.new(packet) do
      {:ok, _} ->
        :ok

      {:error, "unexpected request payload"} ->
        :ok

      {:error, e} ->
        e |> IO.inspect(label: "#{command}: #{seq}")
        # Process.sleep(200)
        System.halt(1)
        # raise "#{command}: #{seq}"
        e |> IO.inspect(label: "#{command}: #{seq}")
    end

    Output.debugger_console("Received disconnect request\n")

    Output.telemetry("dap_request", %{"elixir_ls.dap_command" => "disconnect"}, %{
      "elixir_ls.dap_request_time" => 0
    })

    if state.config["request"] == "attach" do
      # we need to clean up before we disconnect
      Output.debugger_console("Disabling all breakpoints")
      :int.no_break()
      :int.auto_attach(false)

      # do not leave interpreted modules on remote nodes
      for module <- :int.interpreted() do
        Output.debugger_console("Uninterpreting module #{inspect(module)}")
        :int.nn(module)
      end
    end

    # disable logger so we do not get unexpected
    # [notice] SIGTERM received - shutting down
    Logger.configure(level: :none)
    Output.send_response(packet, %GenDAP.Requests.DisconnectResponse{seq: 0, request_seq: 0})

    {:noreply, state, {:continue, :disconnect}}
  end

  def handle_cast({:receive_packet, request(seq, command) = packet}, state = %__MODULE__{}) do
    start_time = System.monotonic_time(:millisecond)

    struct =
      case GenDAP.Requests.new(packet) do
        {:ok, struct} ->
          struct

        {:error, "unexpected request payload"} ->
          packet
      end

    try do
      if state.client_info == nil do
        case packet do
          request(_, "initialize") ->
            {response_body, state} = handle_request(struct, state)
            elapsed = System.monotonic_time(:millisecond) - start_time
            Output.send_response(packet, response_body)

            Output.telemetry(
              "dap_request",
              %{"elixir_ls.dap_command" => "initialize"},
              %{
                "elixir_ls.dap_request_time" => elapsed
              }
            )

            {:noreply, state}

          request(_, command) ->
            raise ServerError,
              message: "invalidRequest",
              format: "Debugger request #{command} was not expected",
              variables: %{}
        end
      else
        state =
          case handle_request(struct, state) do
            {response_body, state} ->
              elapsed = System.monotonic_time(:millisecond) - start_time
              Output.send_response(packet, response_body)

              Output.telemetry(
                "dap_request",
                %{"elixir_ls.dap_command" => String.replace(command, "/", "_")},
                %{
                  "elixir_ls.dap_request_time" => elapsed
                }
              )

              state

            {:async, fun, state} ->
              {pid, ref} = handle_request_async(packet, start_time, fun)

              %{
                state
                | requests: Map.put(state.requests, seq, {pid, ref, packet}),
                  requests_seqs_by_pid: Map.put(state.requests_seqs_by_pid, pid, seq)
              }
          end

        {:noreply, state}
      end
    rescue
      e in ServerError ->
        Output.send_error_response(
          packet,
          ErrorDictionary.code(e.message),
          e.message,
          e.format,
          e.variables,
          e.send_telemetry,
          e.show_user
        )

        {:noreply, state}
    catch
      kind, error ->
        stacktrace = __STACKTRACE__

        {payload, stacktrace} =
          try do
            Exception.blame(kind, error, stacktrace)
          catch
            kind_1, error_1 ->
              # in case of error in Exception.blame we want to use the original error and stacktrace
              Output.debugger_console(
                "Exception.blame failed: #{Exception.format(kind_1, error_1, __STACKTRACE__)}"
              )

              {error, stacktrace}
          end

        message = Exception.format(kind, payload, stacktrace)
        Output.debugger_console(message)

        Output.send_error_response(
          packet,
          ErrorDictionary.code("internalServerError"),
          "internalServerError",
          message,
          %{},
          true,
          false
        )

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:merge_registry, pid, registry}, state = %__MODULE__{}) do
    case Map.fetch(state.paused_processes, pid) do
      {:ok, paused_process = %PausedProcess{}} ->
        merged_registry = VariableRegistry.merge(paused_process.registry, registry)
        paused_process = %{paused_process | registry: merged_registry}
        state = put_in(state.paused_processes[pid], paused_process)
        {:noreply, state}

      :error ->
        # Process might have been resumed or exited, ignore
        {:noreply, state}
    end
  end

  def handle_cast({event, pid}, state = %__MODULE__{})
      when event in [:breakpoint_reached, :paused] do
    # when debugged pid exits we get another breakpoint reached message (at least on OTP 23)
    # check if process is alive to not debug dead ones

    alive? =
      try do
        Process.alive?(pid)
      rescue
        ArgumentError ->
          # Process.alive?(pid) raises ArgumentError for remote pids, assume alive
          true
      end

    state =
      if alive? do
        # monitor to cleanup state if process dies
        ref = Process.monitor(pid)
        {state, thread_id, _new_ids} = ensure_thread_id(state, pid, [])

        paused_process = %PausedProcess{stack: Stacktrace.get(pid), ref: ref}
        state = put_in(state.paused_processes[pid], paused_process)

        reason = get_stop_reason(state, event, paused_process.stack)

        Output.send_event(%GenDAP.Events.StoppedEvent{
          seq: nil,
          body: %{reason: reason, thread_id: thread_id, all_threads_stopped: false}
        })

        state
      else
        Process.monitor(pid)
        state
      end

    {:noreply, state}
  end

  # the `:DOWN` message is not delivered under normal conditions as the process calls `Process.sleep(:infinity)`
  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, reason}, %__MODULE__{task_ref: ref} = state) do
    exit_code =
      case reason do
        :normal ->
          0

        _ ->
          Output.debugger_important("Mix task failed")

          1
      end

    message =
      "Mix task exited with reason\n#{Exception.format_exit(reason)}\nreturning code #{exit_code}"

    IO.puts(message)

    Output.debugger_console(message)

    if reason != :normal do
      Output.telemetry(
        "debuggee_mix_task_error",
        %{
          "elixir_ls.debuggee_mix_task_error" => message
        },
        %{}
      )
    end

    Output.send_event(%GenDAP.Events.TerminatedEvent{seq: nil, body: %{restart: false}})
    Output.send_event(%GenDAP.Events.ExitedEvent{seq: nil, body: %{exit_code: exit_code}})

    {:noreply, %{state | task_ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state = %__MODULE__{}) do
    paused_processes_count_before = map_size(state.paused_processes)
    state = handle_process_exit(state, pid)
    paused_processes_count_after = map_size(state.paused_processes)

    if paused_processes_count_after < paused_processes_count_before do
      Output.debugger_important(
        "Paused process #{inspect(pid)} exited with reason #{Exception.format_exit(reason)}"
      )
    end

    # if the exited process was a request handler respond with error
    # and optionally end progress
    {seq, updated_requests_seqs_by_pid} = Map.pop(state.requests_seqs_by_pid, pid)

    {updated_requests, updated_progresses} =
      if seq do
        {{^pid, ^ref, packet}, updated_requests} = Map.pop!(state.requests, seq)

        Output.send_error_response(
          packet,
          ErrorDictionary.code("internalServerError"),
          "internalServerError",
          "Request handler exited with reason #{Exception.format_exit(reason)}",
          %{},
          true,
          false
        )

        # no MapSet.pop...
        updated_progresses =
          if MapSet.member?(state.progresses, seq) do
            Output.send_event(%GenDAP.Events.ProgressEndEvent{
              seq: nil,
              body: %{
                progress_id: to_string(seq)
              }
            })

            MapSet.delete(state.progresses, seq)
          else
            state.progresses
          end

        {updated_requests, updated_progresses}
      else
        {state.requests, state.progresses}
      end

    state = %{
      state
      | requests: updated_requests,
        requests_seqs_by_pid: updated_requests_seqs_by_pid,
        progresses: updated_progresses
    }

    {:noreply, state}
  end

  def handle_info(:update_threads, state = %__MODULE__{}) do
    {state, _thread_ids} = update_threads(state)

    {:noreply, state}
  end

  def handle_info({:nodeup, node, %{node_type: node_type}}, state = %__MODULE__{}) do
    Output.debugger_console("#{node_type} node #{node} connected\n")
    {:noreply, state}
  end

  def handle_info(
        {:nodedown, node, %{node_type: node_type, nodedown_reason: nodedown_reason}},
        state = %__MODULE__{}
      ) do
    Output.debugger_console(
      "#{node_type} node #{node} disconnected: #{inspect(nodedown_reason)}\n"
    )

    {:noreply, state}
  end

  def handle_info({:ok, [%Frame{} | _]}, state = %__MODULE__{}) do
    # timed out response from Stacktrace.get/1
    # we already emitted a warning
    {:noreply, state}
  end

  # If we get the disconnect request from the client, we continue with :disconnect so the server will
  # die right after responding to the request
  @impl GenServer
  def handle_continue(:disconnect, state = %__MODULE__{}) do
    unless :persistent_term.get(:debug_adapter_test_mode, false) do
      Process.sleep(200)
      System.halt(0)
    else
      Process.exit(self(), {:exit_code, 0})
    end

    {:noreply, state}
  end

  ## Helpers

  defp handle_request(
         %GenDAP.Requests.InitializeRequest{
           arguments: %GenDAP.Structures.InitializeRequestArguments{} = args
         },
         %__MODULE__{client_info: nil} = state
       ) do
    # linesStartAt1 is true by default and we only support 1-based indexing
    if args.lines_start_at1 == false do
      raise ServerError,
        message: "invalidRequest",
        format: "0-based lines are not supported",
        variables: %{},
        show_user: true
    end

    # columnsStartAt1 is true by default and we only support 1-based indexing
    if args.columns_start_at1 == false do
      raise ServerError,
        message: "invalidRequest",
        format: "0-based columns are not supported",
        variables: %{},
        show_user: true
    end

    # pathFormat is `path` by default and we do not support other, e.g. `uri`
    if args.path_format not in [nil, "path"] do
      raise ServerError,
        message: "invalidRequest",
        format: "pathFormat {pathFormat} is not supported",
        variables: %{"pathFormat" => args.path_format},
        show_user: true
    end

    {%GenDAP.Requests.InitializeResponse{seq: 0, request_seq: 0, body: capabilities()},
     %{state | client_info: args}}
  end

  defp handle_request(%GenDAP.Requests.InitializeRequest{}, _state = %__MODULE__{}) do
    raise ServerError,
      message: "invalidRequest",
      format: "Debugger request initialize was not expected",
      variables: %{}
  end

  defp handle_request(
         %GenDAP.Requests.CancelRequest{arguments: args = %GenDAP.Structures.CancelArguments{}},
         %__MODULE__{requests: requests} = state
       ) do
    # in or case progressId is requestId so choose first not null
    request_or_progress_id = args.request_id || args.progress_id

    request_or_progress_id =
      if is_binary(request_or_progress_id) do
        String.to_integer(request_or_progress_id)
      else
        request_or_progress_id
      end

    {request, updated_requests} = Map.pop(requests, request_or_progress_id)

    {updated_requests_seqs_by_pid, updated_progresses} =
      if request do
        {pid, ref, packet} = request
        # flush as we are not interested in :DOWN message anymore
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :cancelled)

        Output.send_error_response(
          packet,
          ErrorDictionary.code("cancelled"),
          "cancelled",
          "cancelled",
          %{},
          false,
          false
        )

        # send progressEnd if cancelling a progress
        updated_progresses =
          if MapSet.member?(state.progresses, request_or_progress_id) do
            Output.send_event(%GenDAP.Events.ProgressEndEvent{
              seq: nil,
              body: %{
                progress_id: to_string(request_or_progress_id)
              }
            })

            MapSet.delete(state.progresses, request_or_progress_id)
          else
            state.progresses
          end

        {Map.delete(state.requests_seqs_by_pid, pid), updated_progresses}
      else
        raise ServerError,
          message: "invalidRequest",
          format: "Request or progress {requestOrProgressId} cannot be cancelled",
          variables: %{
            "requestOrProgressId" => inspect(request_or_progress_id)
          },
          send_telemetry: false
      end

    state = %{
      state
      | requests: updated_requests,
        requests_seqs_by_pid: updated_requests_seqs_by_pid,
        progresses: updated_progresses
    }

    {%GenDAP.Requests.CancelResponse{seq: 0, request_seq: 0}, state}
  end

  defp handle_request(%GenDAP.Requests.LaunchRequest{arguments: config}, state = %__MODULE__{}) do
    server = self()

    {_, ref} = spawn_monitor(fn -> launch(config, server) end)

    config =
      receive do
        {:ok, config} ->
          # sending `initialized` signals that we are ready to receive configuration requests
          # setBreakpoints, setFunctionBreakpoints and configurationDone
          Output.send_event(%GenDAP.Events.InitializedEvent{seq: nil})
          # Process.sleep(30000)
          send(self(), :update_threads)

          Output.telemetry(
            "dap_launch_config",
            %{
              "elixir_ls.startApps" => to_string(Map.get(config, "startApps", false)),
              "elixir_ls.debugAutoInterpretAllModules" =>
                to_string(Map.get(config, "debugAutoInterpretAllModules", true)),
              "elixir_ls.stackTraceMode" =>
                to_string(Map.get(config, "stackTraceMode", "no_tail")),
              "elixir_ls.exitAfterTaskReturns" =>
                to_string(Map.get(config, "exitAfterTaskReturns", true)),
              "elixir_ls.noDebug" => to_string(Map.get(config, "noDebug", false)),
              "elixir_ls.breakOnDbg" => to_string(Map.get(config, "breakOnDbg", true)),
              "elixir_ls.env" => to_string(Map.get(config, "env", %{}) != %{}),
              "elixir_ls.requireFiles" => to_string(Map.get(config, "requireFiles", []) != []),
              "elixir_ls.debugInterpretModulesPatterns" =>
                to_string(Map.get(config, "debugInterpretModulesPatterns", []) != []),
              "elixir_ls.excludeModules" =>
                to_string(Map.get(config, "excludeModules", []) != []),
              "elixir_ls.task" => to_string(Map.get(config, "task", ":default_task"))
            },
            %{}
          )

          config

        {:DOWN, ^ref, :process, _pid, reason} ->
          case reason do
            :normal ->
              :ok

            {%ServerError{} = error, stack} ->
              exit_code = 1
              Output.send_event(%GenDAP.Events.TerminatedEvent{seq: nil, body: %{restart: false}})

              Output.send_event(%GenDAP.Events.ExitedEvent{
                seq: nil,
                body: %{exit_code: exit_code}
              })

              reraise error, stack

            _other ->
              message = "Launch request failed with reason\n" <> Exception.format_exit(reason)

              Output.debugger_console(message)

              exit_code = 1
              Output.send_event(%GenDAP.Events.TerminatedEvent{seq: nil, body: %{restart: false}})

              Output.send_event(%GenDAP.Events.ExitedEvent{
                seq: nil,
                body: %{exit_code: exit_code}
              })

              raise ServerError,
                message: "launchError",
                format: message,
                variables: %{},
                send_telemetry: false,
                show_user: true
          end
      end

    {%GenDAP.Requests.LaunchResponse{seq: 0, request_seq: 0}, %{state | config: config}}
  end

  defp handle_request(%GenDAP.Requests.AttachRequest{arguments: config}, state = %__MODULE__{}) do
    server = self()

    :net_kernel.monitor_nodes(true, %{
      connection_id: false,
      node_type: :all,
      nodedown_reason: true
    })

    {_, ref} = spawn_monitor(fn -> attach(config, server) end)

    config =
      receive do
        {:ok, config} ->
          # sending `initialized` signals that we are ready to receive configuration requests
          # setBreakpoints, setFunctionBreakpoints and configurationDone
          Output.send_event(%GenDAP.Events.InitializedEvent{seq: nil})
          send(self(), :update_threads)

          Output.telemetry(
            "dap_attach_config",
            %{
              "elixir_ls.debugAutoInterpretAllModules" =>
                to_string(Map.get(config, "debugAutoInterpretAllModules", true)),
              "elixir_ls.stackTraceMode" =>
                to_string(Map.get(config, "stackTraceMode", "no_tail")),
              "elixir_ls.noDebug" => to_string(Map.get(config, "noDebug", false)),
              "elixir_ls.env" => to_string(Map.get(config, "env", %{}) != %{}),
              "elixir_ls.debugInterpretModulesPatterns" =>
                to_string(Map.get(config, "debugInterpretModulesPatterns", []) != []),
              "elixir_ls.excludeModules" => to_string(Map.get(config, "excludeModules", []) != [])
            },
            %{}
          )

          config

        {:DOWN, ^ref, :process, _pid, reason} ->
          case reason do
            :normal ->
              :ok

            {%ServerError{} = error, stack} ->
              Output.send_event(%GenDAP.Events.TerminatedEvent{
                seq: nil,
                body: %{restart: false}
              })

              reraise error, stack

            _other ->
              message = "Attach request failed with reason\n" <> Exception.format_exit(reason)

              Output.debugger_console(message)

              Output.send_event(%GenDAP.Events.TerminatedEvent{
                seq: nil,
                body: %{restart: false}
              })

              raise ServerError,
                message: "attachError",
                format: message,
                variables: %{},
                send_telemetry: false,
                show_user: true
          end
      end

    {%GenDAP.Requests.AttachResponse{seq: 0, request_seq: 0}, %{state | config: config}}
  end

  defp handle_request(
         %GenDAP.Requests.SourceRequest{arguments: args = %GenDAP.Structures.SourceArguments{}},
         state = %__MODULE__{}
       ) do
    source = %GenDAP.Structures.Source{} = args.source
    path = source.path

    content =
      cond do
        path == "replinput" ->
          # this is a special path that VSCode uses for debugger console
          # return an empty string as we do not need anything there
          ""

        String.starts_with?(path, "vs.editor.ICodeEditor:") ->
          # some undocumented VSCode behavior related to Monaco editor
          # vs.editor.ICodeEditor:1%3Abreakpointinput
          ""

        true ->
          File.read!(path)
      end

    {%GenDAP.Requests.SourceResponse{seq: 0, request_seq: 0, body: %{content: content}}, state}
  end

  defp handle_request(
         %GenDAP.Requests.SetBreakpointsRequest{},
         %__MODULE__{config: %{"noDebug" => true}}
       ) do
    raise ServerError,
      message: "invalidRequest",
      format: "Cannot set breakpoints when running with no debug",
      variables: %{},
      show_user: true
  end

  defp handle_request(
         %GenDAP.Requests.SetBreakpointsRequest{
           arguments: args = %GenDAP.Structures.SetBreakpointsArguments{}
         },
         state = %__MODULE__{}
       ) do
    source = %GenDAP.Structures.Source{} = args.source
    path = Path.absname(source.path)
    new_lines = for %GenDAP.Structures.SourceBreakpoint{line: line} <- args.breakpoints, do: line

    new_conditions =
      for b = %GenDAP.Structures.SourceBreakpoint{} <- args.breakpoints,
          do: {b.condition, b.log_message, b.hit_condition}

    existing_bps = state.breakpoints[path] || []
    existing_bp_lines = for {_modules, line} <- existing_bps, do: line
    removed_lines = existing_bp_lines -- new_lines
    removed_bps = Enum.filter(existing_bps, fn {_, line} -> line in removed_lines end)

    for {modules, line} <- removed_bps, module <- modules do
      :int.delete_break(module, line)
      BreakpointCondition.unregister_condition(module, [line])
    end

    result = set_breakpoints(path, new_lines |> Enum.zip(new_conditions), state.config)
    new_bps = for {:ok, modules, line} <- result, do: {modules, line}

    state =
      if new_bps == [] do
        %{state | breakpoints: state.breakpoints |> Map.delete(path)}
      else
        put_in(state.breakpoints[path], new_bps)
      end

    breakpoints_result =
      Enum.map(result, fn
        {:ok, _, _} ->
          %GenDAP.Structures.Breakpoint{verified: true}

        {:error, error} ->
          %GenDAP.Structures.Breakpoint{verified: false, message: error, reason: "failed"}
      end)

    {%GenDAP.Requests.SetBreakpointsResponse{
       seq: 0,
       request_seq: 0,
       body: %{breakpoints: breakpoints_result}
     }, state}
  end

  defp handle_request(
         %GenDAP.Requests.SetFunctionBreakpointsRequest{},
         %__MODULE__{config: %{"noDebug" => true}}
       ) do
    raise ServerError,
      message: "invalidRequest",
      format: "Cannot set function breakpoints when running with no debug",
      variables: %{},
      show_user: true
  end

  defp handle_request(
         %GenDAP.Requests.SetFunctionBreakpointsRequest{
           arguments: args = %GenDAP.Structures.SetFunctionBreakpointsArguments{}
         },
         state = %__MODULE__{}
       ) do
    mfas =
      for %GenDAP.Structures.FunctionBreakpoint{name: name} = breakpoint <- args.breakpoints do
        {Utils.parse_mfa(name), {breakpoint.condition, breakpoint.hit_condition}}
      end

    parsed_mfas_conditions = for {{:ok, mfa}, condition} <- mfas, into: %{}, do: {mfa, condition}

    for {{m, f, a}, lines} <- state.function_breakpoints,
        not Map.has_key?(parsed_mfas_conditions, {m, f, a}) do
      for line <- lines do
        BreakpointCondition.unregister_condition(m, line)
      end

      case :int.del_break_in(m, f, a) do
        :ok ->
          :ok

        {:error, :function_not_found} ->
          Output.debugger_important(
            "Unable to delete function breakpoint on #{inspect({m, f, a})}"
          )
      end
    end

    current = state.function_breakpoints

    results =
      for {{m, f, a}, {condition, hit_count}} <- parsed_mfas_conditions,
          into: %{},
          do:
            (
              path =
                try do
                  module_info = ModuleInfoCache.get(m) || m.module_info()
                  Path.expand(to_string(module_info[:compile][:source]))
                rescue
                  _ -> "nofile"
                end

              result =
                case current[{m, f, a}] do
                  nil ->
                    case interpret(m, false) do
                      :ok ->
                        breaks_before = :int.all_breaks(m)

                        Output.debugger_console(
                          "Setting function breakpoint in #{inspect(m)}.#{f}/#{a}"
                        )

                        case :int.break_in(m, f, a) do
                          :ok ->
                            breaks_after = :int.all_breaks(m)
                            lines = for {{^m, line}, _} <- breaks_after -- breaks_before, do: line

                            # pass nil as log_message - not supported on function breakpoints as of DAP 1.63
                            update_break_condition(
                              path,
                              m,
                              lines,
                              condition,
                              nil,
                              hit_count,
                              state.config
                            )

                            {:ok, lines}

                          {:error, :function_not_found} ->
                            {:error, "Function #{inspect(m)}.#{f}/#{a} not found"}
                        end

                      {:error, :cannot_interpret} ->
                        {:error, "Cannot interpret module #{inspect(m)}"}

                      {:error, :cannot_load} ->
                        {:error, "Module #{inspect(m)} cannot be loaded"}

                      {:error, :excluded} ->
                        {:error,
                         "Module #{inspect(m)} is used internally by the debug adapter and cannot be interpreted"}
                    end

                  lines ->
                    # pass nil as log_message - not supported on function breakpoints as of DAP 1.51
                    update_break_condition(
                      path,
                      m,
                      lines,
                      condition,
                      nil,
                      hit_count,
                      state.config
                    )

                    {:ok, lines}
                end

              {{m, f, a}, result}
            )

    successful = for {mfa, {:ok, lines}} <- results, into: %{}, do: {mfa, lines}

    state = %{
      state
      | function_breakpoints: successful
    }

    breakpoints_result =
      Enum.map(mfas, fn
        {{:ok, mfa}, _} ->
          case results[mfa] do
            {:ok, _} ->
              %GenDAP.Structures.Breakpoint{verified: true}

            {:error, error} ->
              %GenDAP.Structures.Breakpoint{
                verified: false,
                message: inspect(error),
                reason: "failed"
              }
          end

        {{:error, error}, _} ->
          %GenDAP.Structures.Breakpoint{verified: false, message: error, reason: "failed"}
      end)

    {%GenDAP.Requests.SetFunctionBreakpointsResponse{
       seq: 0,
       request_seq: 0,
       body: %{breakpoints: breakpoints_result}
     }, state}
  end

  defp handle_request(
         %GenDAP.Requests.ConfigurationDoneRequest{},
         state = %__MODULE__{}
       ) do
    unless state.config["noDebug"] do
      :int.auto_attach([:break], build_attach_mfa(:breakpoint_reached))
    end

    {_pid, task_ref} = spawn_monitor(fn -> launch_task(state.config) end)

    {%GenDAP.Requests.ConfigurationDoneResponse{seq: 0, request_seq: 0},
     %{state | task_ref: task_ref}}
  end

  defp handle_request(
         %GenDAP.Requests.ThreadsRequest{},
         state = %__MODULE__{}
       ) do
    snapshot_by_pid = get_snapshot_by_pid()
    {state, thread_ids} = update_threads(state, snapshot_by_pid)

    threads =
      for thread_id <- thread_ids,
          {:ok, pid} = ThreadRegistry.get_pid_by_thread_id(state.thread_registry, thread_id),
          (process_name = get_process_name(pid, snapshot_by_pid)) != nil do
        full_name = "#{process_name} #{:erlang.pid_to_list(pid)}"
        %GenDAP.Structures.Thread{id: thread_id, name: full_name}
      end
      |> Enum.sort_by(fn %GenDAP.Structures.Thread{name: name} -> name end)

    {%GenDAP.Requests.ThreadsResponse{seq: 0, request_seq: 0, body: %{threads: threads}}, state}
  end

  defp handle_request(
         %GenDAP.Requests.TerminateThreadsRequest{
           arguments: args = %GenDAP.Structures.TerminateThreadsArguments{}
         },
         state = %__MODULE__{}
       ) do
    for thread_id <- args.thread_ids do
      case ThreadRegistry.get_pid_by_thread_id(state.thread_registry, thread_id) do
        {:ok, pid} ->
          # :kill is untrappable
          # do not need to cleanup here, :DOWN message handler will do it
          Process.monitor(pid)
          Process.exit(pid, :kill)

        :error ->
          # thread_id not found, treat as already terminated
          :ok
      end
    end

    {%GenDAP.Requests.TerminateThreadsResponse{seq: 0, request_seq: 0}, state}
  end

  defp handle_request(
         %GenDAP.Requests.PauseRequest{},
         %__MODULE__{config: %{"noDebug" => true}}
       ) do
    raise ServerError,
      message: "invalidRequest",
      format: "Cannot pause process when running with no debug",
      variables: %{},
      send_telemetry: false,
      show_user: true
  end

  defp handle_request(
         %GenDAP.Requests.PauseRequest{arguments: args = %GenDAP.Structures.PauseArguments{}},
         state = %__MODULE__{}
       ) do
    pid = get_pid_by_thread_id!(state, args.thread_id, true)

    :int.attach(pid, build_attach_mfa(:paused))

    {%GenDAP.Requests.PauseResponse{seq: 0, request_seq: 0}, state}
  end

  defp handle_request(
         %GenDAP.Requests.StackTraceRequest{
           arguments: args = %GenDAP.Structures.StackTraceArguments{}
         },
         state = %__MODULE__{}
       ) do
    pid = get_pid_by_thread_id!(state, args.thread_id, false)

    case state.paused_processes[pid] do
      %PausedProcess{} = paused_process ->
        total_frames = Enum.count(paused_process.stack)

        start_frame =
          case args do
            %GenDAP.Structures.StackTraceArguments{start_frame: start_frame}
            when is_integer(start_frame) ->
              start_frame

            _ ->
              0
          end

        end_frame =
          case args do
            %GenDAP.Structures.StackTraceArguments{levels: levels}
            when is_integer(levels) and levels > 0 ->
              start_frame + levels

            _ ->
              -1
          end

        stack_frames = Enum.slice(paused_process.stack, start_frame..end_frame//1)
        {state, frame_ids} = ensure_frame_ids(state, pid, stack_frames)

        stack_frames_result =
          for {%Frame{} = stack_frame, frame_id} <- Enum.zip([stack_frames, frame_ids]) do
            %GenDAP.Structures.StackFrame{
              id: frame_id,
              name: Stacktrace.Frame.name(stack_frame),
              line: stack_frame.line,
              column: 0,
              source: %GenDAP.Structures.Source{path: stack_frame.file}
            }
          end

        {%GenDAP.Requests.StackTraceResponse{
           seq: 0,
           request_seq: 0,
           body: %{stack_frames: stack_frames_result, total_frames: total_frames}
         }, state}

      nil ->
        raise ServerError,
          message: "invalidArgument",
          format: "Process with threadId {threadId} and pid {pid} is not paused",
          variables: %{
            "threadId" => inspect(args.thread_id),
            "pid" => inspect(pid)
          },
          send_telemetry: false
    end
  end

  defp handle_request(
         %GenDAP.Requests.ScopesRequest{arguments: args = %GenDAP.Structures.ScopesArguments{}},
         state = %__MODULE__{}
       ) do
    {state, scopes} =
      case find_frame(state.paused_processes, args.frame_id) do
        {pid, %Frame{dbg_frame?: true} = frame} ->
          {state, bindings_id} = ensure_var_id(state, pid, frame.bindings)
          process_info = Process.info(pid) || []
          {state, process_info_id} = ensure_var_id(state, pid, process_info)

          vars_scope = %GenDAP.Structures.Scope{
            name: "variables",
            presentation_hint: "locals",
            variables_reference: bindings_id,
            named_variables: Enum.count(frame.bindings),
            indexed_variables: 0,
            expensive: false
          }

          process_info_scope = %GenDAP.Structures.Scope{
            name: "process info",
            variables_reference: process_info_id,
            named_variables: length(process_info),
            indexed_variables: 0,
            expensive: false
          }

          scopes =
            [vars_scope, process_info_scope]

          {state, scopes}

        {pid, %Frame{} = frame} ->
          {state, args_id} = ensure_var_id(state, pid, frame.args)
          variables = Binding.to_elixir_variable_names(frame.bindings) |> Map.new()
          {state, vars_id} = ensure_var_id(state, pid, variables)
          {state, versioned_vars_id} = ensure_var_id(state, pid, frame.bindings)
          {state, messages_id} = ensure_var_id(state, pid, frame.messages)

          process_info =
            try do
              Process.info(pid) || []
            rescue
              ArgumentError ->
                # remote pid
                []
            end

          {state, process_info_id} = ensure_var_id(state, pid, process_info)

          vars_scope = %GenDAP.Structures.Scope{
            name: "variables",
            presentation_hint: "locals",
            variables_reference: vars_id,
            named_variables: map_size(variables),
            indexed_variables: 0,
            expensive: false
          }

          versioned_vars_scope = %GenDAP.Structures.Scope{
            name: "versioned variables",
            presentation_hint: "locals",
            variables_reference: versioned_vars_id,
            named_variables: Enum.count(frame.bindings),
            indexed_variables: 0,
            expensive: false
          }

          args_scope =
            if frame.args != :undefined do
              %GenDAP.Structures.Scope{
                name: "arguments",
                presentation_hint: "arguments",
                variables_reference: args_id,
                named_variables: 0,
                indexed_variables: Enum.count(frame.args),
                expensive: false
              }
            end

          messages_scope = %GenDAP.Structures.Scope{
            name: "messages",
            variables_reference: messages_id,
            named_variables: 0,
            indexed_variables: Enum.count(frame.messages),
            expensive: false
          }

          process_info_scope = %GenDAP.Structures.Scope{
            name: "process info",
            presentation_hint: "registers",
            variables_reference: process_info_id,
            named_variables: length(process_info),
            indexed_variables: 0,
            expensive: false
          }

          scopes =
            [vars_scope, versioned_vars_scope, process_info_scope]
            |> Kernel.++(
              if frame.args != :undefined and Enum.count(frame.args) > 0,
                do: [args_scope],
                else: []
            )
            |> Kernel.++(if Enum.count(frame.messages) > 0, do: [messages_scope], else: [])

          {state, scopes}

        nil ->
          raise ServerError,
            message: "invalidArgument",
            format: "frameId not found: {frameId}",
            variables: %{
              "frameId" => inspect(args.frame_id)
            },
            send_telemetry: false
      end

    {%GenDAP.Requests.ScopesResponse{seq: 0, request_seq: 0, body: %{scopes: scopes}}, state}
  end

  defp handle_request(
         %GenDAP.Requests.VariablesRequest{
           arguments: args = %GenDAP.Structures.VariablesArguments{}
         },
         state = %__MODULE__{}
       ) do
    async_fn = fn ->
      {pid, var} = find_var!(state.paused_processes, args.variables_reference)

      # Get the existing registry from the paused process
      existing_registry =
        case Map.fetch!(state.paused_processes, pid) do
          %PausedProcess{registry: registry} -> registry
        end

      {updated_registry, variables} =
        variables_async(
          var,
          args.start,
          args.count,
          args.filter,
          state.client_info,
          existing_registry
        )

      # Merge the registry back to the server state
      GenServer.cast(__MODULE__, {:merge_registry, pid, updated_registry})

      %GenDAP.Requests.VariablesResponse{seq: 0, request_seq: 0, body: %{variables: variables}}
    end

    {:async, async_fn, state}
  end

  defp handle_request(
         %GenDAP.Requests.EvaluateRequest{
           arguments: args = %GenDAP.Structures.EvaluateArguments{},
           seq: seq
         },
         state = %__MODULE__{
           client_info: client_info = %GenDAP.Structures.InitializeRequestArguments{}
         }
       ) do
    state =
      if client_info.supports_progress_reporting do
        Output.send_event(%GenDAP.Events.ProgressStartEvent{
          seq: nil,
          body: %{
            progress_id: to_string(seq),
            title: "Evaluating expression",
            message: args.expression,
            request_id: seq,
            cancellable: true
          }
        })

        %{state | progresses: MapSet.put(state.progresses, seq)}
      else
        state
      end

    async_fn = fn ->
      frame = frame_for_eval(state.paused_processes, args.frame_id)
      {_metadata, _env, binding, env_for_eval} = binding_and_env(state.paused_processes, frame)
      value = evaluate_code_expression(args.expression, binding, env_for_eval)

      # Get the existing evaluator registry
      existing_registry =
        case Map.fetch!(state.paused_processes, :evaluator) do
          %PausedProcess{registry: registry} -> registry
        end

      {updated_registry, var_id} =
        VariableRegistry.get_variable_reference(existing_registry, value)

      # Merge the registry back to the server state
      GenServer.cast(__MODULE__, {:merge_registry, :evaluator, updated_registry})

      child_type = Variables.child_type(value)

      variable =
        %{
          result: inspect(value),
          variables_reference: var_id,
          type: nil,
          indexed_variables: nil,
          named_variables: nil
        }
        |> maybe_append_children_number(state.client_info, child_type, value)
        |> maybe_append_variable_type(state.client_info, value)

      %GenDAP.Requests.EvaluateResponse{seq: 0, request_seq: 0, body: variable}
    end

    {:async, async_fn, state}
  end

  defp handle_request(
         %GenDAP.Requests.ContinueRequest{
           arguments: args = %GenDAP.Structures.ContinueArguments{}
         },
         state = %__MODULE__{}
       ) do
    pid = get_pid_by_thread_id!(state, args.thread_id, true)

    state =
      case state.dbg_session do
        {^pid, _ref} = from ->
          GenServer.reply(from, {:ok, false})
          %{state | dbg_session: nil}

        _ ->
          safe_int_action(pid, :continue)
          state
      end

    state =
      state
      |> remove_paused_process(pid)
      |> maybe_continue_other_processes(args)

    processes_paused? = state.paused_processes |> Map.keys() |> Enum.any?(&is_pid/1)

    {%GenDAP.Requests.ContinueResponse{
       seq: 0,
       request_seq: 0,
       body: %{all_threads_continued: not processes_paused?}
     }, state}
  end

  defp handle_request(
         %GenDAP.Requests.NextRequest{arguments: args = %GenDAP.Structures.NextArguments{}},
         state = %__MODULE__{}
       ) do
    pid = get_pid_by_thread_id!(state, args.thread_id, true)

    state =
      if match?({^pid, _ref}, state.dbg_session) do
        GenServer.reply(state.dbg_session, {:ok, true})
        %{state | dbg_session: nil}
      else
        safe_int_action(pid, :next)
        state
      end

    state =
      state
      |> remove_paused_process(pid)
      |> maybe_continue_other_processes(args)

    {%GenDAP.Requests.NextResponse{seq: 0, request_seq: 0}, state}
  end

  defp handle_request(
         %GenDAP.Requests.StepInRequest{
           command: command,
           arguments: args = %GenDAP.Structures.StepInArguments{}
         },
         state = %__MODULE__{}
       ) do
    pid = get_pid_by_thread_id!(state, args.thread_id, true)

    validate_dbg_pid!(state, pid, command)

    safe_int_action(pid, :step)

    state =
      state
      |> remove_paused_process(pid)
      |> maybe_continue_other_processes(args)

    {%GenDAP.Requests.StepInResponse{seq: 0, request_seq: 0}, state}
  end

  defp handle_request(
         %GenDAP.Requests.StepOutRequest{
           command: command,
           arguments: args = %GenDAP.Structures.StepOutArguments{}
         },
         state = %__MODULE__{}
       ) do
    pid = get_pid_by_thread_id!(state, args.thread_id, true)

    validate_dbg_pid!(state, pid, command)

    safe_int_action(pid, :finish)

    state =
      state
      |> remove_paused_process(pid)
      |> maybe_continue_other_processes(args)

    {%GenDAP.Requests.StepOutResponse{seq: 0, request_seq: 0}, state}
  end

  defp handle_request(
         %GenDAP.Requests.CompletionsRequest{
           arguments: args = %GenDAP.Structures.CompletionsArguments{}
         },
         state = %__MODULE__{}
       ) do
    async_fn = fn ->
      # assume that the position is 1-based
      line = (args.line || 1) - 1
      column = (args.column || 1) - 1

      # for simplicity take only text from the given line up to column
      line =
        args.text
        |> String.split(["\r\n", "\n", "\r"])
        |> Enum.at(line, "")

      # It is measured in UTF-16 code units and the client capability
      # `columnsStartAt1` determines whether it is 0- or 1-based.
      column = Utils.dap_character_to_elixir(line, column)
      prefix = String.slice(line, 0, column)

      frame = frame_for_eval(state.paused_processes, args.frame_id)

      {metadata, env, _binding, _env_for_eval} = binding_and_env(state.paused_processes, frame)

      cursor_position =
        case frame do
          nil -> {1, 1}
          frame -> {frame.line, 1}
        end

      results =
        ElixirLS.Utils.CompletionEngine.complete(prefix, env, metadata, cursor_position)
        |> Enum.map(&ElixirLS.DebugAdapter.Completions.map/1)
        |> Enum.reject(&is_nil/1)

      %GenDAP.Requests.CompletionsResponse{seq: 0, request_seq: 0, body: %{targets: results}}
    end

    {:async, async_fn, state}
  end

  defp handle_request(%_{command: command}, %__MODULE__{}) do
    raise ServerError,
      message: "notSupported",
      format: "Debugger request #{command} is currently not supported",
      variables: %{},
      show_user: true
  end

  defp handle_request(request(_seq, command), %__MODULE__{}) do
    raise ServerError,
      message: "notSupported",
      format: "Debugger request #{command} is currently not supported",
      variables: %{},
      show_user: true
  end

  defp maybe_continue_other_processes(state, %{single_thread: true}) do
    # continue dbg debug session
    state =
      case state.dbg_session do
        {pid, _ref} = from ->
          GenServer.reply(from, {:ok, false})
          {%PausedProcess{ref: ref}, paused_processes} = Map.pop!(state.paused_processes, pid)
          true = Process.demonitor(ref, [:flush])
          %{state | dbg_session: nil, paused_processes: paused_processes}

        _ ->
          state
      end

    # continue erlang debugger paused processes
    for {paused_pid, %PausedProcess{ref: ref}} <- state.paused_processes do
      safe_int_action(paused_pid, :continue)
      true = Process.demonitor(ref, [:flush])
      paused_pid
    end

    %{state | paused_processes: %{}}
  end

  defp maybe_continue_other_processes(state, _), do: state

  # TODO consider removing this workaround as the problem seems to no longer affect OTP 24
  defp safe_int_action(pid, action) do
    apply(:int, action, [pid])
    :ok
  catch
    kind, payload ->
      # when stepping out of interpreted code a MatchError is risen inside :int module (at least in OTP 23)
      Output.debugger_important(
        ":int.#{action}(#{inspect(pid)}) failed: #{Exception.format(kind, payload)}"
      )

      unless action == :continue do
        safe_int_action(pid, :continue)
      end

      :ok
  end

  defp get_pid_by_thread_id!(state = %__MODULE__{}, thread_id, show_message_on_error?) do
    case ThreadRegistry.get_pid_by_thread_id(state.thread_registry, thread_id) do
      {:ok, pid} ->
        pid

      :error ->
        raise ServerError,
          message: "invalidArgument",
          format: "Unable to find process pid for DAP threadId {threadId}",
          variables: %{
            "threadId" => inspect(thread_id)
          },
          send_telemetry: false,
          show_user: show_message_on_error?
    end
  end

  defp remove_paused_process(state = %__MODULE__{}, pid) do
    {process, paused_processes} = Map.pop(state.paused_processes, pid)

    if process do
      true = Process.demonitor(process.ref, [:flush])
    end

    %{state | paused_processes: paused_processes}
  end

  defp variables_async(var, start, count, filter, client_info, registry) do
    var_child_type = Variables.child_type(var)

    children =
      if var_child_type == nil or (filter != nil and Atom.to_string(var_child_type) != filter) do
        []
      else
        Variables.children(var, start, count)
      end

    {updated_registry, variables} =
      Enum.reduce(children, {registry, []}, fn {name, value}, {registry_acc, acc} ->
        {registry_acc, var_id} = VariableRegistry.get_variable_reference(registry_acc, value)
        child_type = Variables.child_type(value)

        json =
          %GenDAP.Structures.Variable{
            name: to_string(name),
            value: inspect(value),
            variables_reference: var_id
          }
          |> maybe_append_children_number(client_info, child_type, value)
          |> maybe_append_variable_type(client_info, value)

        {registry_acc, [json | acc]}
      end)

    {updated_registry, Enum.reverse(variables)}
  end

  defp maybe_append_children_number(
         variable,
         %GenDAP.Structures.InitializeRequestArguments{supports_variable_paging: true},
         :indexed,
         value
       ),
       do: %{variable | indexed_variables: Variables.num_children(value)}

  defp maybe_append_children_number(
         variable,
         %GenDAP.Structures.InitializeRequestArguments{supports_variable_paging: true},
         :named,
         value
       ),
       do: %{variable | named_variables: Variables.num_children(value)}

  defp maybe_append_children_number(variable, _, _, _value), do: variable

  defp maybe_append_variable_type(
         variable,
         %GenDAP.Structures.InitializeRequestArguments{supports_variable_type: true},
         value
       ) do
    %{variable | type: Variables.type(value)}
  end

  defp maybe_append_variable_type(variable, _, _value), do: variable

  defp evaluate_code_expression(expr, binding, env_or_opts) do
    try do
      # TODO use Code.env_for_eval when we require elixir 1.14
      env = ElixirLS.DebugAdapter.Code.env_for_eval(env_or_opts)
      {term, _bindings} = Code.eval_string(expr, binding, env)
      term
    catch
      kind, error ->
        stacktrace = prune_stacktrace(__STACKTRACE__)

        {payload, stacktrace} =
          try do
            Exception.blame(kind, error, stacktrace)
          catch
            kind_1, error_1 ->
              # in case of error in Exception.blame we want to use the original error and stacktrace
              Output.debugger_console(
                "Exception.blame failed: #{Exception.format(kind_1, error_1, __STACKTRACE__)}"
              )

              {error, stacktrace}
          end

        message = Exception.format(kind, payload, stacktrace)

        reraise(
          %ServerError{
            message: "evaluateError",
            format: message,
            variables: %{},
            send_telemetry: false
          },
          stacktrace
        )
    end
  end

  defp frame_for_eval(_paused_processes, nil), do: nil

  defp frame_for_eval(paused_processes, frame_id) do
    case find_frame(paused_processes, frame_id) do
      {_pid, %Frame{} = frame} ->
        frame

      _ ->
        raise ServerError,
          message: "argumentError",
          format: "Unable to find frame {frameId}",
          variables: %{"frameId" => frame_id},
          send_telemetry: false
    end
  end

  # for null frameId DAP spec suggest to return variables in the global scope
  # there is no global scope in erlang/elixir so instead we flat map all variables
  # from all paused processes and evaluator
  defp binding_and_env(paused_processes, nil) do
    binding =
      paused_processes
      |> Enum.flat_map(fn
        {:evaluator, _} ->
          # TODO setVariable?
          []

        {_pid, %PausedProcess{} = paused_process} ->
          Map.values(paused_process.registry.frame_ids_to_frames)
      end)
      |> Enum.filter(&match?(%Frame{bindings: bindings} when is_map(bindings), &1))
      |> Enum.flat_map(fn %Frame{bindings: bindings} ->
        Binding.to_elixir_variable_names(bindings)
      end)

    {%ElixirSense.Core.Metadata{},
     update_env_vars_from_binding(%ElixirSense.Core.State.Env{}, binding), binding, []}
  end

  defp binding_and_env(
         _paused_processes,
         %Frame{bindings: bindings, dbg_frame?: dbg_frame?} = frame
       )
       when is_map(bindings) do
    {metadata, env, macro_env} = parse_file(frame.file, frame.line)

    if dbg_frame? do
      if frame.dbg_env do
        # we are evaluating an expression in dbg breakpoint - take dbg macro env as env for eval
        # we have exact elixir bindings here
        env = ElixirSense.Core.State.Env.update_from_macro_env(env, frame.dbg_env)
        binding = bindings |> Enum.to_list()
        {metadata, update_env_vars_from_binding(env, binding), binding, frame.dbg_env}
      else
        # we are evaluating an expression in dbg breakpoint but frame is upper in the stacktrace
        # we don't have any bindings here
        # take env from metadata builder as env for eval
        {metadata, env, [], macro_env}
      end
    else
      # we are evaluating an expression in OTP debugger breakpoint
      # take env from metadata builder as env for eval
      # bindings come from OTP debugger
      # unfortunately there is no way to select right versions of variables in binding
      # translation in :elixir_erl_var.translate is one way
      binding = Binding.to_elixir_variable_names(bindings)
      {metadata, update_env_vars_from_binding(env, binding), binding, macro_env}
    end
  end

  defp find_var!(paused_processes, var_id) do
    result =
      Enum.find_value(paused_processes, fn
        {pid, %PausedProcess{registry: registry}} ->
          case VariableRegistry.find_var(registry, var_id) do
            {:ok, var} -> {pid, var}
            :error -> nil
          end

        _ ->
          nil
      end)

    case result do
      nil ->
        raise ServerError,
          message: "invalidArgument",
          format: "variablesReference not found: {variablesReference}",
          variables: %{
            "variablesReference" => inspect(var_id)
          },
          send_telemetry: false

      other ->
        other
    end
  end

  defp find_frame(paused_processes, frame_id) do
    Enum.find_value(paused_processes, fn
      {pid, %{registry: registry}} when is_pid(pid) ->
        case VariableRegistry.find_frame(registry, frame_id) do
          {:ok, frame} -> {pid, frame}
          :error -> nil
        end

      _ ->
        nil
    end)
  end

  defp ensure_thread_id(state = %__MODULE__{}, pid, new_ids) when is_pid(pid) do
    {updated_registry, thread_id, new_ids} =
      ThreadRegistry.ensure_thread_id(state.thread_registry, pid, new_ids)

    state = %{state | thread_registry: updated_registry}
    {state, thread_id, new_ids}
  end

  defp ensure_thread_ids(state = %__MODULE__{}, pids) do
    {updated_registry, thread_ids, new_ids} =
      ThreadRegistry.ensure_thread_ids(state.thread_registry, pids)

    state = %{state | thread_registry: updated_registry}
    {state, thread_ids, new_ids}
  end

  defp ensure_var_id(state = %__MODULE__{}, pid, var) when is_pid(pid) or pid == :evaluator do
    paused_process = %PausedProcess{} = Map.fetch!(state.paused_processes, pid)
    {registry, var_id} = VariableRegistry.ensure_var_id(paused_process.registry, var)
    paused_process = %{paused_process | registry: registry}
    state = put_in(state.paused_processes[pid], paused_process)
    {state, var_id}
  end

  defp ensure_frame_ids(state = %__MODULE__{}, pid, stack_frames) do
    Enum.reduce(stack_frames, {state, []}, fn stack_frame, {state, ids} ->
      {state, id} = ensure_frame_id(state, pid, stack_frame)
      {state, ids ++ [id]}
    end)
  end

  defp ensure_frame_id(state = %__MODULE__{}, pid, %Frame{} = frame) when is_pid(pid) do
    paused_process = %PausedProcess{} = Map.fetch!(state.paused_processes, pid)
    {registry, frame_id} = VariableRegistry.ensure_frame_id(paused_process.registry, frame)
    paused_process = %{paused_process | registry: registry}
    state = put_in(state.paused_processes[pid], paused_process)
    {state, frame_id}
  end

  defp launch(config, server) do
    # IO.warn(config |> Map.from_struct |> inspect)
    project_dir = config["projectDir"]

    project_dir =
      if project_dir not in [nil, ""] do
        if not is_binary(project_dir) do
          raise ServerError,
            message: "argumentError",
            format:
              "Invalid `projectDir` in launch config. Expected string or nil, got #{inspect(project_dir)}",
            variables: %{},
            send_telemetry: false,
            show_user: true
        end

        Output.debugger_console("Starting debugger in directory: #{project_dir}\n")
        project_dir
      else
        cwd = File.cwd!()

        Output.debugger_console(
          "projectDir is not set, starting debugger in current directory: #{cwd}\n"
        )

        cwd
      end

    task = config["task"]

    if not (is_nil(task) or is_binary(task)) do
      raise ServerError,
        message: "argumentError",
        format:
          "Invalid `taskArgs` in launch config. Expected string or nil, got #{inspect(task)}",
        variables: %{},
        send_telemetry: false,
        show_user: true
    end

    task_args = config["taskArgs"] || []

    if not (is_list(task_args) and Enum.all?(task_args, &is_binary/1)) do
      raise ServerError,
        message: "argumentError",
        format:
          "Invalid `taskArgs` in launch config. Expected list of strings or nil, got #{inspect(task_args)}",
        variables: %{},
        send_telemetry: false,
        show_user: true
    end

    auto_interpret_files? = Map.get(config, "debugAutoInterpretAllModules", true)

    set_env_vars(config["env"])

    try do
      File.cd!(project_dir)
    rescue
      e in File.Error ->
        raise ServerError,
          message: "argumentError",
          format: Exception.format_banner(:error, e, __STACKTRACE__),
          variables: %{},
          send_telemetry: false,
          show_user: true
    end

    # the startup sequence here is taken from
    # https://github.com/elixir-lang/elixir/blob/v1.14.4/lib/mix/lib/mix/cli.ex#L158
    # we assume that mix is already started and has archives and tasks loaded
    Launch.reload_mix_env_and_target()

    Mix.ProjectStack.post_config(build_path: ".elixir_ls/debug_adapter/build")

    Mix.ProjectStack.post_config(
      test_elixirc_options: [
        docs: true,
        debug_info: true
      ]
    )

    Mix.ProjectStack.post_config(prune_code_paths: false)

    Code.put_compiler_option(:docs, true)
    Code.put_compiler_option(:debug_info, true)

    args = List.wrap(task) ++ task_args
    Launch.load_mix_exs(args)
    project = Mix.Project.get()
    {task, task_args} = Launch.get_task(args, project)
    Launch.maybe_change_env_and_target(task, project)

    Output.debugger_console("Running with MIX_ENV: #{Mix.env()} MIX_TARGET: #{Mix.target()}\n")

    Launch.ensure_no_slashes(task)

    unless "--no-mix-exs" in task_args do
      Mix.Task.run("loadconfig")
    end

    unless "--no-compile" in task_args or "--no-mix-exs" in task_args do
      case Mix.Task.run("compile", ["--ignore-module-conflict", "--return-errors"]) do
        {:error, diagnostics} ->
          message =
            diagnostics
            |> Enum.filter(fn %Mix.Task.Compiler.Diagnostic{} = diag ->
              diag.severity == :error
            end)
            |> Enum.map_join("\n", fn %Mix.Task.Compiler.Diagnostic{} = diag -> diag.message end)

          raise ServerError,
            message: "launchError",
            format: message,
            variables: %{},
            send_telemetry: false,
            show_user: true

        _ ->
          :ok
      end
    end

    # Some tasks (such as Phoenix tests) expect apps to already be running before the test files are
    # required
    if config["startApps"] do
      Mix.Task.run("app.start", [])
    end

    exclude_module_names =
      config
      |> Map.get("excludeModules", [])

    if not (is_list(exclude_module_names) and Enum.all?(exclude_module_names, &is_binary/1)) do
      raise ServerError,
        message: "argumentError",
        format:
          "Invalid `excludeModules` in launch config. Expected list of strings or nil, got #{inspect(exclude_module_names)}",
        variables: %{},
        send_telemetry: false,
        show_user: true
    end

    exclude_module_pattern =
      exclude_module_names
      |> Enum.map(&wildcard_module_name_to_pattern/1)

    unless config["noDebug"] do
      set_stack_trace_mode(config["stackTraceMode"])

      if auto_interpret_files? do
        auto_interpret_modules(Mix.Project.build_path(), exclude_module_pattern)
      end

      required_files = Map.get(config, "requireFiles", [])

      if not (is_list(required_files) and Enum.all?(required_files, &is_binary/1)) do
        raise ServerError,
          message: "argumentError",
          format:
            "Invalid `requireFiles` in launch config. Expected list of strings or nil, got #{inspect(required_files)}",
          variables: %{},
          send_telemetry: false,
          show_user: true
      end

      require_files(required_files)

      interpret_modules_patterns = Map.get(config, "debugInterpretModulesPatterns", [])

      if not (is_list(interpret_modules_patterns) and
                Enum.all?(interpret_modules_patterns, &is_binary/1)) do
        raise ServerError,
          message: "argumentError",
          format:
            "Invalid `debugInterpretModulesPatterns` in launch config. Expected list of strings or nil, got #{inspect(interpret_modules_patterns)}",
          variables: %{},
          send_telemetry: false,
          show_user: true
      end

      interpret_specified_modules(interpret_modules_patterns, exclude_module_pattern)
    else
      Output.debugger_console("Running without debugging")
    end

    updated_config = Map.merge(config, %{"task" => task, "taskArgs" => task_args})
    send(server, {:ok, updated_config})
  rescue
    e in [
      Mix.Error,
      Mix.NoProjectError,
      Mix.ElixirVersionError,
      Mix.InvalidTaskError,
      Mix.NoTaskError,
      CompileError,
      SyntaxError,
      TokenMissingError
    ] ->
      raise ServerError,
        message: "launchError",
        format: Exception.format_banner(:error, e, __STACKTRACE__),
        variables: %{},
        send_telemetry: false,
        show_user: true
  end

  defp attach(config, server) do
    remote_node = config["remoteNode"]

    if not is_binary(remote_node) or remote_node == "" or not String.contains?(remote_node, "@") do
      raise ServerError,
        message: "argumentError",
        format:
          "Invalid `remoteNode` in launch config. Expected OTP node name, got #{inspect(remote_node)}",
        variables: %{},
        send_telemetry: false,
        show_user: true
    else
      node_atom = String.to_atom(remote_node)

      case Node.connect(node_atom) do
        true ->
          load_debugger_app(node_atom)

        false ->
          raise ServerError,
            message: "runtimeError",
            format: "Unable to connect to `remoteNode` #{inspect(remote_node)}",
            variables: %{},
            send_telemetry: false,
            show_user: true
      end
    end

    project_dir = config["projectDir"]

    project_dir =
      if project_dir not in [nil, ""] do
        if not is_binary(project_dir) do
          raise ServerError,
            message: "argumentError",
            format:
              "Invalid `projectDir` in launch config. Expected string or nil, got #{inspect(project_dir)}",
            variables: %{},
            send_telemetry: false,
            show_user: true
        end

        Output.debugger_console("Starting debugger in directory: #{project_dir}\n")
        project_dir
      else
        cwd = File.cwd!()

        Output.debugger_console(
          "projectDir is not set, starting debugger in current directory: #{cwd}\n"
        )

        cwd
      end

    auto_interpret_files? = Map.get(config, "debugAutoInterpretAllModules", true)

    set_env_vars(config["env"])

    try do
      File.cd!(project_dir)
    rescue
      e in File.Error ->
        raise ServerError,
          message: "argumentError",
          format: Exception.format_banner(:error, e, __STACKTRACE__),
          variables: %{},
          send_telemetry: false,
          show_user: true
    end

    # the startup sequence here is taken from
    # https://github.com/elixir-lang/elixir/blob/v1.14.4/lib/mix/lib/mix/cli.ex#L158
    # we assume that mix is already started and has archives and tasks loaded
    Launch.reload_mix_env_and_target()

    Launch.load_mix_exs([])

    Mix.Task.run("loadconfig")

    Mix.Task.run("loadpaths")

    exclude_module_names =
      config
      |> Map.get("excludeModules", [])

    if not (is_list(exclude_module_names) and Enum.all?(exclude_module_names, &is_binary/1)) do
      raise ServerError,
        message: "argumentError",
        format:
          "Invalid `excludeModules` in launch config. Expected list of strings or nil, got #{inspect(exclude_module_names)}",
        variables: %{},
        send_telemetry: false,
        show_user: true
    end

    exclude_module_pattern =
      exclude_module_names
      |> Enum.map(&wildcard_module_name_to_pattern/1)

    unless config["noDebug"] do
      set_stack_trace_mode(config["stackTraceMode"])

      if auto_interpret_files? do
        auto_interpret_modules(Mix.Project.build_path(), exclude_module_pattern)
      end

      interpret_modules_patterns = Map.get(config, "debugInterpretModulesPatterns", [])

      if not (is_list(interpret_modules_patterns) and
                Enum.all?(interpret_modules_patterns, &is_binary/1)) do
        raise ServerError,
          message: "argumentError",
          format:
            "Invalid `debugInterpretModulesPatterns` in launch config. Expected list of strings or nil, got #{inspect(interpret_modules_patterns)}",
          variables: %{},
          send_telemetry: false,
          show_user: true
      end

      interpret_specified_modules(interpret_modules_patterns, exclude_module_pattern)
    else
      Output.debugger_console("Running without debugging")
    end

    send(server, {:ok, config})
  rescue
    e in [
      Mix.Error,
      Mix.NoProjectError,
      Mix.ElixirVersionError,
      Mix.InvalidTaskError,
      Mix.NoTaskError,
      CompileError,
      SyntaxError,
      TokenMissingError
    ] ->
      raise ServerError,
        message: "attachError",
        format: Exception.format_banner(:error, e, __STACKTRACE__),
        variables: %{},
        send_telemetry: false,
        show_user: true
  end

  defp load_debugger_app(node) do
    Output.debugger_console("Loading debugger app on #{node}\n")

    res =
      case :rpc.call(node, Application, :load, [:debugger], 5000) do
        :ok ->
          :ok

        {:error, {:already_loaded, :debugger}} ->
          :ok

        other ->
          Output.debugger_console(
            "Unable to load debugger app via Application.load on #{node}: #{inspect(other)}\n"
          )

          case :rpc.call(node, Mix, :ensure_application!, [:debugger], 5000) do
            :ok ->
              :ok

            other ->
              Output.debugger_console(
                "Unable to load debugger app via Mix.ensure_application! on #{node}: #{inspect(other)}\n"
              )

              :error
          end
      end

    case res do
      :ok ->
        Output.debugger_console("Debugger app loaded on #{node}\n")

      :error ->
        Output.debugger_important(
          "Please make sure that OTP debugger application is installed and loadable on #{node}. You may need to include it in extra_applications.\n"
        )
    end
  end

  defp set_env_vars(env) when is_map(env) do
    try do
      System.put_env(env)
    rescue
      e ->
        Output.debugger_console(
          "Cannot set environment variables to #{inspect(env)}: #{Exception.message(e)}"
        )

        raise ServerError,
          message: "argumentError",
          format:
            "Invalid `env` in launch configuration. Expected a map with string key value pairs, got #{inspect(env)}",
          variables: %{},
          send_telemetry: false,
          show_user: true
    end

    :ok
  end

  defp set_env_vars(env) when is_nil(env), do: :ok

  defp set_env_vars(env) do
    raise ServerError,
      message: "argumentError",
      format:
        "Invalid `env` in launch configuration. Expected a map with string key value pairs, got #{inspect(env)}",
      variables: %{},
      send_telemetry: false,
      show_user: true
  end

  defp set_stack_trace_mode("all"), do: :int.stack_trace(:all)
  defp set_stack_trace_mode("no_tail"), do: :int.stack_trace(:no_tail)
  defp set_stack_trace_mode("false"), do: :int.stack_trace(false)
  defp set_stack_trace_mode(false), do: :int.stack_trace(false)
  defp set_stack_trace_mode(nil), do: nil

  defp set_stack_trace_mode(mode) do
    raise ServerError,
      message: "argumentError",
      format:
        "Invalid `stackTraceMode` in launch configuration. Must be `all`, `no_tail` or `false`, got #{inspect(mode)}",
      variables: %{},
      send_telemetry: false,
      show_user: true
  end

  defp capabilities do
    %GenDAP.Structures.Capabilities{
      supports_configuration_done_request: true,
      supports_function_breakpoints: true,
      supports_conditional_breakpoints: true,
      supports_hit_conditional_breakpoints: true,
      supports_log_points: true,
      exception_breakpoint_filters: [],
      supports_step_back: false,
      supports_set_variable: false,
      supports_restart_frame: false,
      supports_goto_targets_request: false,
      supports_step_in_targets_request: false,
      supports_completions_request: true,
      completion_trigger_characters: [".", "&", "%", "^", ":", "!", "-", "~"],
      supports_modules_request: false,
      additional_module_columns: [],
      supported_checksum_algorithms: [],
      supports_restart_request: false,
      supports_exception_options: false,
      supports_value_formatting_options: false,
      supports_exception_info_request: false,
      supports_terminate_threads_request: true,
      supports_single_thread_execution_requests: true,
      supports_evaluate_for_hovers: true,
      supports_clipboard_context: true,
      support_terminate_debuggee: false,
      supports_cancel_request: true
    }
  end

  defp auto_interpret_modules(path, exclude_module_pattern) do
    path
    |> Path.join("**/*.beam")
    |> Path.wildcard()
    |> Enum.map(&(Path.basename(&1, ".beam") |> String.to_atom()))
    |> interpret_modules(exclude_module_pattern)
  end

  defp wildcard_module_name_to_pattern(module_name) do
    module_name
    |> prefix_module_name()
    |> Regex.escape()
    |> String.replace("\\*", ~s(.+))
    |> Regex.compile!()
  end

  defp should_interpret?(module, exclude_module_pattern) do
    :int.interpretable(module) == true and !:code.is_sticky(module) and module != __MODULE__ and
      not excluded_module?(module, exclude_module_pattern)
  end

  defp excluded_module?(module, exclude_module_pattern) do
    module_name = module |> Atom.to_string()

    Enum.any?(exclude_module_pattern, &Regex.match?(&1, module_name))
  end

  defp prefix_module_name(module_name) when is_binary(module_name) do
    case module_name do
      ":" <> name -> name
      _ -> "Elixir." <> module_name
    end
  end

  defp launch_task(config = %{"request" => "launch"}) do
    # This fixes a race condition in the tests and likely improves reliability when using the
    # debugger as well.
    Process.sleep(100)

    task = config["task"]
    args = config["taskArgs"]

    if args != [] do
      Output.debugger_console("Running mix #{task} #{Enum.join(args, " ")}\n")
    else
      Output.debugger_console("Running mix #{task}\n")
    end

    res = Mix.Task.run(task, args)

    Output.debugger_console("Mix.Task.run returned:\n#{inspect(res)}\n")

    if Map.get(config, "exitAfterTaskReturns", true) do
      Output.debugger_console(
        "Exiting debugger.\nIf this behavior is undesired consider setting `exitAfterTaskReturns` to `false` in launch config.\n"
      )
    else
      # Starting from Elixir 1.9 Mix.Task.run will return so some task require sleeping
      # process so that the code can keep running (Note: process is expected to be
      # killed by stopping the debugger)
      Output.debugger_console("Sleeping. The debugger will need to be stopped manually.\n")
      Process.sleep(:infinity)
    end
  end

  defp launch_task(%{"request" => "attach"}) do
    Output.debugger_console("Sleeping. The debugger will need to be stopped manually.\n")
    Process.sleep(:infinity)
  end

  # Interpreting modules defined in .exs files requires that we first load the file and save any
  # modules it defines to actual .beam files in the code path. The user must specify which .exs
  # files to load via the launch configuration. They must be in the correct order (for example,
  # test helpers before tests). We save the .beam files to a temporary folder which we add to the
  # code path.
  defp require_files([]), do: :ok

  defp require_files(required_files) do
    File.rm_rf!(@temp_beam_dir)
    File.mkdir_p!(@temp_beam_dir)
    true = Code.append_path(Path.expand(@temp_beam_dir))

    for path <- required_files,
        file <- Path.wildcard(path),
        modules = Code.require_file(file),
        is_list(modules),
        {module, beam_bin} <- modules,
        do: save_and_reload(module, beam_bin)
  end

  defp interpret_specified_modules([], _exclude_module_pattern), do: :ok

  defp interpret_specified_modules(file_patterns, exclude_module_pattern) do
    regexes =
      Enum.map(file_patterns, fn pattern ->
        case Regex.compile(pattern) do
          {:ok, regex} ->
            regex

          {:error, error} ->
            raise ServerError,
              message: "argumentError",
              format: "Unable to compile file pattern {pattern} into a regex: {error}",
              variables: %{"pattern" => inspect(pattern), "error" => inspect(error)},
              send_telemetry: false,
              show_user: true
        end
      end)

    if String.to_integer(System.otp_release()) >= 23 do
      for {module_charlist, _beam_path, _loaded} <- :code.all_available(),
          module = List.to_atom(module_charlist),
          module_name = inspect(module),
          Enum.any?(regexes, fn regex ->
            Regex.match?(regex, module_name)
          end) do
        module
      end
    else
      # TODO remove when we drop OTP 22 and elixir 1.13 support
      ElixirSense.all_modules()
      |> Enum.filter(fn module_name ->
        Enum.find(regexes, fn regex ->
          Regex.match?(regex, module_name)
        end)
      end)
      |> Enum.map(fn module_name -> Module.concat(Elixir, module_name) end)
    end
    |> interpret_modules(exclude_module_pattern)
  end

  defp save_and_reload(module, beam_bin) do
    :ok = File.write(Path.join(@temp_beam_dir, to_string(module) <> ".beam"), beam_bin)
    :code.purge(module)
    :code.delete(module)
    :ok = interpret(module)
  end

  defp set_breakpoints(path, lines, config) do
    if Path.extname(path) == ".erl" do
      module = String.to_atom(Path.basename(path, ".erl"))
      for line <- lines, do: set_breakpoint([module], path, line, config)
    else
      loaded_elixir_modules =
        :code.all_loaded()
        |> Enum.map(&elem(&1, 0))
        |> Enum.filter(fn module -> String.starts_with?(Atom.to_string(module), "Elixir.") end)
        |> Enum.group_by(fn module ->
          module_info = ModuleInfoCache.get(module) || module.module_info()
          Path.expand(to_string(module_info[:compile][:source]))
        end)

      loaded_modules_from_path = Map.get(loaded_elixir_modules, path, [])
      metadata = ElixirSense.Core.Parser.parse_file(path, false, false, nil)

      for line <- lines do
        env = ElixirSense.Core.Metadata.get_cursor_env(metadata, {line |> elem(0), 1})
        metadata_module = env.module

        modules_to_break =
          cond do
            metadata_module != nil and metadata_module in loaded_modules_from_path and
                env.protocol == nil ->
              # prefer metadata modules if valid and loaded
              [metadata_module]

            env.protocol != nil ->
              {protocol, implementations} = env.protocol

              for implementation <- implementations do
                Module.concat(protocol, implementation)
              end

            true ->
              # fall back to all loaded modules from file
              # this may create breakpoints outside module line range
              loaded_modules_from_path
          end

        set_breakpoint(modules_to_break, path, line, config)
      end
    end
  rescue
    error ->
      for _line <- lines, do: {:error, Exception.format_exit(error)}
  end

  defp set_breakpoint([], path, {line, _}, _config) do
    {:error, "Could not determine module at line #{line} in #{path}"}
  end

  defp set_breakpoint(modules, path, {line, {condition, log_message, hit_count}}, config) do
    modules_with_breakpoints =
      Enum.reduce(modules, [], fn module, added ->
        case interpret(module, false) do
          :ok ->
            Output.debugger_console("Setting breakpoint in #{inspect(module)} #{path}:#{line}")
            # no need to handle errors here, it can fail only with {:error, :break_exists}
            :int.break(module, line)
            update_break_condition(path, module, line, condition, log_message, hit_count, config)

            [module | added]

          {:error, :cannot_interpret} ->
            Output.debugger_console("Could not interpret module #{inspect(module)} in #{path}")
            added

          {:error, :cannot_load} ->
            Output.debugger_console("Module #{inspect(module)} in #{path} cannot be loaded")
            added

          {:error, :excluded} ->
            Output.debugger_console(
              "Module #{inspect(module)} in #{path} is used internally by the debugger and cannot be interpreted"
            )

            added
        end
      end)

    if modules_with_breakpoints == [] do
      {:error,
       "Could not interpret any of the modules #{Enum.map_join(modules, ", ", &inspect/1)} in #{path}"}
    else
      # return :ok if at least one breakpoint was set
      {:ok, modules_with_breakpoints, line}
    end
  end

  defp interpret_modules(modules, exclude_module_pattern) do
    modules
    |> Enum.each(fn mod ->
      if should_interpret?(mod, exclude_module_pattern) do
        interpret_module(mod)
      end
    end)
  end

  defp interpret_module(mod) do
    case interpret(mod) do
      :ok ->
        :ok

      {:error, :cannot_interpret} ->
        Output.debugger_important(
          "Module #{inspect(mod)} cannot be interpreted. Consider adding it to `excludeModules`."
        )

        :ok

      {:error, :excluded} ->
        :ok

      {:error, :cannot_load} ->
        Output.debugger_important(
          "Module #{inspect(mod)} cannot be loaded. Consider adding it to `excludeModules`."
        )

        :ok
    end
  end

  def update_break_condition(path, module, lines, condition, log_message, hit_count, config) do
    lines = List.wrap(lines)

    condition = parse_condition(condition, "true")

    hit_count = parse_condition(hit_count, "0")

    log_message = if log_message not in ["", nil], do: log_message

    register_break_condition(path, module, lines, condition, log_message, hit_count, config)
  end

  defp register_break_condition(file, module, lines, condition, log_message, hit_count, %{
         "request" => "launch"
       }) do
    for line <- lines do
      {_metadata, _env, macro_env_or_opts} = parse_file(file, line)
      # TODO use Code.env_for_eval when we require elixir 1.14
      env = ElixirLS.DebugAdapter.Code.env_for_eval(macro_env_or_opts)

      case BreakpointCondition.register_condition(
             module,
             line,
             env,
             condition,
             log_message,
             hit_count
           ) do
        {:ok, mf} ->
          :int.test_at_break(module, line, mf)

        {:error, reason} ->
          Output.debugger_important(
            "Unable to set condition on a breakpoint in #{module}:#{inspect(line)}: #{inspect(reason)}"
          )
      end
    end
  end

  defp register_break_condition(_file, _module, _lines, condition, log_message, hit_count, %{
         "request" => "attach"
       }) do
    if condition != "true" || log_message || hit_count != "0" do
      # Module passed to :int.test_at_break has to be available on remote nodes. Otherwise break condition will
      # always evaluate to false. We cannot easily distribute BreakpointCondition to remote nodes.
      Output.debugger_important(
        "Conditional, hit conditional breakpoints and log points are not supported in attach mode"
      )
    end
  end

  defp parse_condition(condition, default) when condition in [nil, ""], do: default

  defp parse_condition(condition, default) do
    case Code.string_to_quoted(condition) do
      {:ok, _} ->
        condition

      {:error, reason} ->
        Output.debugger_important("Cannot parse breakpoint condition: #{inspect(reason)}")
        default
    end
  end

  defp build_attach_mfa(reason) do
    server = Process.info(self())[:registered_name] || self()
    {__MODULE__, reason, [server]}
  end

  defp get_snapshot_by_pid do
    for {pid, function, status, info} <- :int.snapshot(),
        status not in [:exit, :no_conn],
        into: %{},
        do: {pid, {function, status, info}}
  rescue
    e in MatchError ->
      if Exception.message(e) =~ ":already_started" do
        # workaround for a crash in tests (probably caused by race conditions)
        # ** (MatchError) no match of right hand side value: {:error, {:already_started, #PID<0.385.0>}}
        # (debugger 5.3.4) dbg_iserver.erl:75: :dbg_iserver.safe_call/1
        %{}
      else
        reraise(e, __STACKTRACE__)
      end
  end

  defp update_threads(state = %__MODULE__{}, snapshot_by_pid \\ get_snapshot_by_pid()) do
    # status :: idle | running | waiting | break | exit | no_conn
    # Info :: {} | {Module, Line} | ExitReason
    snapshot_pids = Map.keys(snapshot_by_pid)
    local_pids = :erlang.processes()

    pids =
      case state.config["request"] do
        "launch" ->
          # return all processes from local node, make sure interpreted ones are included
          (local_pids ++ snapshot_pids) |> Enum.uniq()

        "attach" ->
          # return only interpreted processes from remote node
          # exclude local interpreted processes
          snapshot_pids -- local_pids
      end

    {state, thread_ids, new_ids} = ensure_thread_ids(state, pids)

    for thread_id <- new_ids do
      Output.send_event(%GenDAP.Events.ThreadEvent{
        seq: nil,
        body: %{
          reason: "started",
          thread_id: thread_id
        }
      })
    end

    exited_pids = ThreadRegistry.all_pids(state.thread_registry) -- pids

    state =
      Enum.reduce(exited_pids, state, fn pid, state ->
        handle_process_exit(state, pid)
      end)

    {schedule_update_threads(state), thread_ids}
  end

  defp handle_process_exit(state = %__MODULE__{}, pid) when is_pid(pid) do
    # Get thread_id before removing from registry
    {thread_id, updated_registry} = ThreadRegistry.remove_pid(state.thread_registry, pid)
    state = %{state | thread_registry: updated_registry}

    # Remove from paused processes
    state = remove_paused_process(state, pid)

    if thread_id do
      Output.send_event(%GenDAP.Events.ThreadEvent{
        seq: nil,
        body: %{
          reason: "exited",
          thread_id: thread_id
        }
      })
    end

    if match?({^pid, _ref}, state.dbg_session) do
      # no need to respond - the debugged process was waiting in GenServer.call but it exited
      %{state | dbg_session: nil}
    else
      state
    end
  end

  defp get_process_name(pid, snapshot_by_pid) do
    try do
      Process.info(pid)
    rescue
      ArgumentError ->
        # remote process
        process_name_from_snapshot(Map.fetch!(snapshot_by_pid, pid))
    else
      nil -> nil
      process_info -> process_name_from_info(process_info)
    end
  end

  defp process_name_from_info(process_info) do
    # if present registered_name is na atom
    registered_name = Keyword.fetch(process_info, :registered_name)
    # OTP 27+ process label may be any term
    # it's not documented but :proc_lib.get_label reads `:$process_label` key from process dictionary
    # https://github.com/erlang/otp/blob/601a012837ea0a5c8095bf24223132824177124d/lib/stdlib/src/proc_lib.erl#L876
    # we have already read it so can get it directly
    label = process_info |> Keyword.fetch!(:dictionary) |> Keyword.fetch(:"$process_label")

    case {registered_name, label} do
      {{:ok, registered_name}, {:ok, label}} ->
        "#{inspect(registered_name)}: #{inspect(label)}"

      {{:ok, registered_name}, _} ->
        inspect(registered_name)

      {_, {:ok, label}} ->
        inspect(label)

      _ ->
        {mod, func, arity} = Keyword.fetch!(process_info, :initial_call)
        "#{inspect(mod)}.#{to_string(func)}/#{arity}"
    end
  end

  defp process_name_from_snapshot({{mod, func, args}, _status, _info}) do
    "#{inspect(mod)}.#{to_string(func)}/#{length(args)}"
  end

  defp schedule_update_threads(state = %__MODULE__{update_threads_ref: old_ref}) do
    if old_ref, do: Process.cancel_timer(old_ref, info: false)
    ref = Process.send_after(self(), :update_threads, 3000)
    %__MODULE__{state | update_threads_ref: ref}
  end

  # Debugger Adapter Protocol stop reasons 'step' | 'breakpoint' | 'exception' | 'pause' | 'entry' | 'goto'
  # | 'function breakpoint' | 'data breakpoint' | 'instruction breakpoint'
  defp get_stop_reason(_state, :paused, _frames), do: "pause"
  defp get_stop_reason(_state, :breakpoint_reached, []), do: "breakpoint"

  defp get_stop_reason(state = %__MODULE__{}, :breakpoint_reached, [first_frame = %Frame{} | _]) do
    file_breakpoints = Map.get(state.breakpoints, first_frame.file, [])

    frame_mfa =
      case first_frame.function do
        {f, a} -> {first_frame.module, f, a}
        _ -> nil
      end

    function_breakpoints = Map.get(state.function_breakpoints, frame_mfa, [])

    cond do
      Enum.any?(file_breakpoints, fn {modules, line} ->
        line == first_frame.line and first_frame.module in modules
      end) ->
        "breakpoint"

      first_frame.line in function_breakpoints ->
        "function breakpoint"

      true ->
        "step"
    end
  end

  @exclude_protocols_from_interpreting [
    Enumerable,
    Collectable,
    List.Chars,
    String.Chars,
    Inspect,
    IEx.Info,
    JasonV.Encoder
  ]

  @exclude_implementations_from_interpreting [Inspect]

  defp interpret(module, print_message? \\ true)

  defp interpret(module, _print_message?) when module in @exclude_protocols_from_interpreting do
    {:error, :excluded}
  end

  defp interpret(module, print_message?) do
    if Code.ensure_loaded?(module) do
      module_behaviours =
        module.module_info(:attributes) |> Keyword.get_values(:behaviour) |> Enum.concat()

      if Enum.any?(@exclude_implementations_from_interpreting, &(&1 in module_behaviours)) do
        # debugger uses Inspect protocol and setting breakpoints in implementations leads to deadlocks
        # https://github.com/elixir-lsp/elixir-ls/issues/903
        {:error, :excluded}
      else
        if print_message? do
          Output.debugger_console("Interpreting module #{inspect(module)}")
        end

        try do
          case :int.ni(module) do
            :error ->
              {:error, :cannot_interpret}

            {:module, _} ->
              # calling module_info when paused on a breakpoint can deadlock the debugger
              # cache it for each interpreted module
              ModuleInfoCache.store(module)
              :ok
          end
        catch
          kind, error ->
            # :int.ni can raise
            #     ** (MatchError) no match of right hand side value: {:error, :on_load_failure}
            # (debugger 5.3) int.erl:531: anonymous fn_3 in :int.load_2
            # (debugger 5.3) int.erl:527: :int.load_2
            stacktrace = __STACKTRACE__

            {payload, stacktrace} =
              try do
                Exception.blame(kind, error, stacktrace)
              catch
                kind_1, error_1 ->
                  # in case of error in Exception.blame we want to use the original error and stacktrace
                  Output.debugger_console(
                    "Exception.blame failed: #{Exception.format(kind_1, error_1, __STACKTRACE__)}"
                  )

                  {error, stacktrace}
              end

            message = Exception.format(kind, payload, stacktrace)

            Output.debugger_console(
              "Error during interpreting module #{inspect(module)}: #{message}"
            )

            {:error, :cannot_interpret}
        end
      end
    else
      {:error, :cannot_load}
    end
  end

  defp validate_dbg_pid!(state, pid, command) do
    if match?({^pid, _ref}, state.dbg_session) do
      raise ServerError,
        message: "notSupported",
        format: "Kernel.dbg breakpoints do not support {command} command",
        variables: %{
          "command" => command
        },
        show_user: true,
        send_telemetry: false
    end
  end

  # Made public to be called from dbg/3 to reduce the amount of generated code.
  @doc false
  def __dbg_pipe_step__(value, string_asts, start_with_pipe?, options) do
    asts_string = Enum.intersperse(string_asts, [:faint, " |> ", :reset])

    asts_string =
      if start_with_pipe? do
        IO.ANSI.format([:faint, "|> ", :reset, asts_string])
      else
        asts_string
      end

    [asts_string, :faint, " #=> ", :reset, inspect(value, options), "\n\n"]
    |> IO.ANSI.format()
    |> IO.write()

    value
  end

  defp chunk_pipeline_asts_by_line(asts, %Macro.Env{line: env_line}) do
    Enum.chunk_by(asts, fn
      {{_fun_or_var, meta, _args}, _pipe_index} -> meta[:line] || env_line
      {_other_ast, _pipe_index} -> env_line
    end)
  end

  defp pipe_chunk_of_asts([{first_ast, _first_index} | asts] = _ast_chunk) do
    Enum.reduce(asts, first_ast, fn {ast, index}, acc -> Macro.pipe(acc, ast, index) end)
  end

  defp asts_chunk_to_strings(asts) do
    Enum.map(asts, fn {ast, _pipe_index} -> Macro.to_string(ast) end)
  end

  defp env_with_line_from_asts(asts) do
    line =
      Enum.find_value(asts, fn
        {{_fun_or_var, meta, _args}, _pipe_index} -> meta[:line]
        {_ast, _pipe_index} -> nil
      end)

    if line do
      quote do
        %{env | line: unquote(line)}
      end
    else
      quote do: env
    end
  end

  defp handle_request_async(packet, start_time, func) do
    parent = self()

    spawn_monitor(fn ->
      result =
        try do
          {:ok, func.()}
        rescue
          e in ServerError ->
            {:error, e}
        catch
          kind, error ->
            stacktrace = __STACKTRACE__

            {payload, stacktrace} =
              try do
                Exception.blame(kind, error, stacktrace)
              catch
                kind_1, error_1 ->
                  # in case of error in Exception.blame we want to use the original error and stacktrace
                  Output.debugger_console(
                    "Exception.blame failed: #{Exception.format(kind_1, error_1, __STACKTRACE__)}"
                  )

                  {error, stacktrace}
              end

            message = Exception.format(kind, payload, stacktrace)
            Output.debugger_console(message)

            {:error,
             %ServerError{message: "internalServerError", format: message, variables: %{}}}
        end

      GenServer.call(parent, {:request_finished, packet, start_time, result}, :infinity)
    end)
  end

  defp parse_file(file, line) do
    try do
      if String.ends_with?(file, ".ex") or String.ends_with?(file, ".exs") do
        code = File.read!(file)
        buffer_file_metadata = ElixirSense.Core.Parser.parse_string(code, false, true, {line, 1})
        env = ElixirSense.Core.Metadata.get_cursor_env(buffer_file_metadata, {line, 1})

        {buffer_file_metadata, env, ElixirSense.Core.State.Env.to_macro_env(env, file, line)}
      else
        # do not try to parse non elixir files
        {%ElixirSense.Core.Metadata{}, %ElixirSense.Core.State.Env{}, [file: file, line: line]}
      end
    rescue
      error ->
        stacktrace = __STACKTRACE__

        {payload, stacktrace} =
          try do
            Exception.blame(:error, error, stacktrace)
          catch
            kind_1, error_1 ->
              # in case of error in Exception.blame we want to use the original error and stacktrace
              Output.debugger_console(
                "Exception.blame failed: #{Exception.format(kind_1, error_1, __STACKTRACE__)}"
              )

              {error, stacktrace}
          end

        message = Exception.format(:error, payload, stacktrace)

        Output.debugger_console(
          "Unable to parse file #{file}: #{message}; Using stub evaluator environment."
        )

        {%ElixirSense.Core.Metadata{}, %ElixirSense.Core.State.Env{}, [file: file, line: line]}
    end
  end

  defp update_env_vars_from_binding(env, binding) do
    env_vars = env.vars |> Map.new(&{&1.name, &1})
    env_var_names = env_vars |> Map.keys()
    binding_var_names = binding |> Keyword.keys()

    vars =
      for var_name <- Enum.uniq(env_var_names ++ binding_var_names) do
        case {Keyword.fetch(binding, var_name), Map.fetch(env_vars, var_name)} do
          {{:ok, binding_value}, {:ok, env_var}} ->
            # var both in env and in binding - prefer type from binding
            type = ElixirSense.Core.Binding.from_var(binding_value)
            %ElixirSense.Core.State.VarInfo{env_var | type: type}

          {_, {:ok, env_var}} ->
            # var only in env - keep it, binding may not have everything
            env_var

          {{:ok, binding_value}, _} ->
            # var only in binding - add var to env
            %ElixirSense.Core.State.VarInfo{
              name: var_name,
              type: ElixirSense.Core.Binding.from_var(binding_value)
            }
        end
      end

    %{env | vars: vars}
  end
end
