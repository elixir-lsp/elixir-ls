defmodule ElixirLS.Debugger.Server do
  @moduledoc """
  Implements the VS Code Debug Protocol

  Refer to the protocol's [documentation](https://github.com/Microsoft/vscode/blob/master/src/vs/workbench/parts/debug/common/debugProtocol.d.ts)
  for details.

  The protocol specifies that we must assign unique IDs to "threads" (or processes), to stack
  frames, and to any variables that can be expanded. We keep a counter with the next ID to use and
  increment it any time we assign an ID.
  """

  defmodule ServerError do
    defexception [:message, :format, :variables]
  end

  alias ElixirLS.Debugger.{Output, Stacktrace, Protocol, Variables}
  alias ElixirLS.Debugger.Stacktrace.Frame
  use GenServer
  use Protocol

  @temp_beam_dir ".elixir_ls/temp_beams"

  defstruct client_info: nil,
            config: %{},
            task_ref: nil,
            threads: %{},
            threads_inverse: %{},
            paused_processes: %{},
            next_id: 1,
            output: Output,
            breakpoints: %{}

  defmodule PausedProcess do
    defstruct stack: nil,
              frames: %{},
              frames_inverse: %{},
              vars: %{},
              vars_inverse: %{}
  end

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

  ## Server Callbacks

  @impl GenServer
  def init(opts) do
    state = if opts[:output], do: %__MODULE__{output: opts[:output]}, else: %__MODULE__{}
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:receive_packet, request(_, _) = packet}, state) do
    try do
      {response_body, state} = handle_request(packet, state)
      Output.send_response(packet, response_body)
      {:noreply, state}
    rescue
      e in ServerError ->
        Output.send_error_response(packet, e.message, e.format, e.variables)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:breakpoint_reached, pid}, state) do
    {state, thread_id} = ensure_thread_id(state, pid)

    paused_process = %PausedProcess{stack: Stacktrace.get(pid)}
    state = put_in(state.paused_processes[pid], paused_process)

    body = %{"reason" => "breakpoint", "threadId" => thread_id, "allThreadsStopped" => false}
    Output.send_event("stopped", body)

    {:noreply, state}
  end

  # the `:DOWN` message is not delivered under normal conditions as the process calls `Process.sleep(:infinity)`
  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    exit_code =
      case reason do
        :normal ->
          0

        _ ->
          IO.puts(
            :standard_error,
            "(Debugger) Task failed because " <> Exception.format_exit(reason)
          )

          1
      end

    Output.send_event("exited", %{"exitCode" => exit_code})
    Output.send_event("terminated", %{"restart" => false})

    {:noreply, %{state | task_ref: nil}}
  end

  # If we get the disconnect request from the client, we send :disconnect to the server so it will
  # die right after responding to the request
  @impl GenServer
  def handle_info(:disconnect, state) do
    System.halt(0)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    if reason != :normal do
      IO.puts(:standard_error, "(Debugger) Terminating because #{Exception.format_exit(reason)}")
    end
  end

  ## Helpers

  defp handle_request(initialize_req(_, client_info), state) do
    {capabilities(), %{state | client_info: client_info}}
  end

  defp handle_request(launch_req(_, config), state) do
    {_, ref} = spawn_monitor(fn -> initialize(config) end)

    receive do
      {:DOWN, ^ref, :process, _pid, reason} ->
        if reason != :normal do
          IO.puts(
            :standard_error,
            "(Debugger) Initialization failed because " <> Exception.format_exit(reason)
          )

          Output.send_event("exited", %{"exitCode" => 1})
          Output.send_event("terminated", %{"restart" => false})
        end
    end

    {%{}, %{state | config: config}}
  end

  defp handle_request(set_breakpoints_req(_, %{"path" => path}, breakpoints), state) do
    new_lines = for %{"line" => line} <- breakpoints, do: line
    existing_bps = state.breakpoints[path] || []
    existing_bp_lines = for {_module, line} <- existing_bps, do: line
    removed_lines = existing_bp_lines -- new_lines
    removed_bps = Enum.filter(existing_bps, fn {_, line} -> line in removed_lines end)

    for {module, line} <- removed_bps do
      :int.delete_break(module, line)
    end

    result = set_breakpoints(path, new_lines)
    new_bps = for {:ok, module, line} <- result, do: {module, line}
    state = put_in(state.breakpoints[path], new_bps)

    breakpoints_json =
      Enum.map(result, fn
        {:ok, _, _} -> %{"verified" => true}
        {:error, error} -> %{"verified" => false, "message" => error}
      end)

    {%{"breakpoints" => breakpoints_json}, state}
  end

  defp handle_request(set_exception_breakpoints_req(_), state) do
    {%{}, state}
  end

  defp handle_request(configuration_done_req(_), state) do
    server = :erlang.process_info(self())[:registered_name] || self()
    :int.auto_attach([:break], {__MODULE__, :breakpoint_reached, [server]})

    task = state.config["task"] || Mix.Project.config()[:default_task]
    args = state.config["taskArgs"] || []
    {_pid, task_ref} = spawn_monitor(fn -> launch_task(task, args) end)

    {%{}, %{state | task_ref: task_ref}}
  end

  defp handle_request(threads_req(_), state) do
    pids = :erlang.processes()
    {state, thread_ids} = ensure_thread_ids(state, pids)

    threads =
      for {pid, thread_id} <- List.zip([pids, thread_ids]), (info = Process.info(pid)) != nil do
        thread_info = Enum.into(info, %{})

        name =
          case Enum.into(thread_info, %{}) do
            %{:registered_name => registered_name} ->
              inspect(registered_name)

            %{:initial_call => {mod, func, arity}} ->
              "#{inspect(mod)}.#{to_string(func)}/#{arity}"
          end

        full_name = Enum.join([name, String.trim_leading(inspect(pid), "#PID")], " ")
        %{"id" => thread_id, "name" => full_name}
      end

    threads = Enum.sort_by(threads, fn %{"name" => name} -> name end)
    {%{"threads" => threads}, state}
  end

  defp handle_request(request(_, "stackTrace", %{"threadId" => thread_id} = args), state) do
    pid = state.threads[thread_id]
    paused_process = state.paused_processes[pid]

    total_frames = Enum.count(paused_process.stack)

    start_frame =
      case args do
        %{"startFrame" => start_frame} when is_integer(start_frame) -> start_frame
        _ -> 0
      end

    end_frame =
      case args do
        %{"levels" => levels} when is_integer(levels) and levels > 0 -> start_frame + levels
        _ -> -1
      end

    stack_frames = Enum.slice(paused_process.stack, start_frame..end_frame)
    {state, frame_ids} = ensure_frame_ids(state, pid, stack_frames)

    stack_frames_json =
      for {stack_frame, frame_id} <- List.zip([stack_frames, frame_ids]) do
        %{
          "id" => frame_id,
          "name" => Stacktrace.Frame.name(stack_frame),
          "line" => stack_frame.line,
          "column" => 0,
          "source" => %{"path" => stack_frame.file}
        }
      end

    {%{"stackFrames" => stack_frames_json, "totalFrames" => total_frames}, state}
  end

  defp handle_request(request(_, "scopes", %{"frameId" => frame_id}), state) do
    {pid, frame} = find_frame(state.paused_processes, frame_id)

    {state, args_id} = ensure_var_id(state, pid, frame.args)
    {state, bindings_id} = ensure_var_id(state, pid, frame.bindings)

    vars_scope = %{
      "name" => "variables",
      "variablesReference" => bindings_id,
      "namedVariables" => Enum.count(frame.bindings),
      "indexedVariables" => 0,
      "expensive" => false
    }

    args_scope = %{
      "name" => "arguments",
      "variablesReference" => args_id,
      "namedVariables" => 0,
      "indexedVariables" => Enum.count(frame.args),
      "expensive" => false
    }

    scopes = if Enum.count(frame.args) > 0, do: [vars_scope, args_scope], else: [vars_scope]
    {%{"scopes" => scopes}, state}
  end

  defp handle_request(request(_, "variables", %{"variablesReference" => var_id} = args), state) do
    {pid, var} = find_var(state.paused_processes, var_id)
    {state, vars_json} = variables(state, pid, var, args["start"], args["count"], args["filter"])

    {%{"variables" => vars_json}, state}
  end

  defp handle_request(request(_cmd, "evaluate", %{"expression" => expr} = _args), state) do
    timeout = 1_000
    bindings = all_variables(state.paused_processes)

    result = evaluate_code_expression(expr, bindings, timeout)

    {%{"result" => inspect(result), "variablesReference" => 0}, state}
  end

  defp handle_request(request(_, "disconnect"), state) do
    send(self(), :disconnect)
    {%{}, state}
  end

  defp handle_request(continue_req(_, thread_id), state) do
    pid = state.threads[thread_id]
    state = remove_paused_process(state, pid)

    :ok = :int.continue(pid)
    {%{"allThreadsContinued" => false}, state}
  end

  defp handle_request(next_req(_, thread_id), state) do
    pid = state.threads[thread_id]
    state = remove_paused_process(state, pid)

    :int.next(pid)
    {%{}, state}
  end

  defp handle_request(step_in_req(_, thread_id), state) do
    pid = state.threads[thread_id]
    state = remove_paused_process(state, pid)

    :int.step(pid)
    {%{}, state}
  end

  defp handle_request(step_out_req(_, thread_id), state) do
    pid = state.threads[thread_id]
    state = remove_paused_process(state, pid)

    :int.finish(pid)
    {%{}, state}
  end

  defp handle_request(request(_, command), _state) when is_binary(command) do
    raise ServerError,
      message: "notSupported",
      format: "Debugger request {command} is currently not supported",
      variables: %{
        "command" => command
      }
  end

  defp remove_paused_process(state, pid) do
    update_in(state.paused_processes, fn paused_processes ->
      Map.delete(paused_processes, pid)
    end)
  end

  defp variables(state, pid, var, start, count, filter) do
    children =
      if (filter == "named" and Variables.child_type(var) == :indexed) or
           (filter == "indexed" and Variables.child_type(var) == :named) do
        []
      else
        Variables.children(var, start, count)
      end

    Enum.reduce(children, {state, []}, fn {name, value}, {state, result} ->
      {state, var_id} =
        if Variables.expandable?(value) do
          ensure_var_id(state, pid, value)
        else
          {state, 0}
        end

      json = %{
        "name" => to_string(name),
        "value" => inspect(value),
        "variablesReference" => var_id,
        "type" => Variables.type(value)
      }

      json =
        case Variables.child_type(value) do
          :indexed -> Map.put(json, "indexedVariables", Variables.num_children(value))
          :named -> Map.put(json, "namedVariables", Variables.num_children(value))
          nil -> json
        end

      {state, result ++ [json]}
    end)
  end

  defp evaluate_code_expression(expr, bindings, timeout) do
    task =
      Task.async(fn ->
        try do
          {term, _bindings} = Code.eval_string(expr, bindings)
          term
        catch
          error -> error
        end
      end)

    Process.unlink(task.pid)

    result = Task.yield(task, timeout) || Task.shutdown(task)

    case result do
      {:ok, data} -> data
      nil -> :elixir_ls_expression_timeout
      _otherwise -> result
    end
  end

  defp all_variables(paused_processes) do
    paused_processes
    |> Enum.flat_map(fn {_pid, paused_process} -> paused_process.frames |> Map.values() end)
    |> Enum.filter(&match?(%Frame{bindings: bindings} when is_map(bindings), &1))
    |> Enum.flat_map(fn %Frame{bindings: bindings} ->
      bindings |> Enum.map(&rename_binding_to_classic_variable/1)
    end)
  end

  defp rename_binding_to_classic_variable({key, value}) do
    # binding is present with prefix _ and postfix @
    # for example _key@1 and _value@1 are representations of current function variables
    new_key =
      key
      |> Atom.to_string()
      |> String.replace(~r/_(.*)@\d/, "\\1")
      |> String.to_atom()

    {new_key, value}
  end

  defp find_var(paused_processes, var_id) do
    Enum.find_value(paused_processes, fn {pid, paused_process} ->
      if Map.has_key?(paused_process.vars, var_id) do
        {pid, paused_process.vars[var_id]}
      end
    end)
  end

  defp find_frame(paused_processes, frame_id) do
    Enum.find_value(paused_processes, fn {pid, paused_process} ->
      if Map.has_key?(paused_process.frames, frame_id) do
        {pid, paused_process.frames[frame_id]}
      end
    end)
  end

  defp ensure_thread_id(state, pid) do
    if Map.has_key?(state.threads_inverse, pid) do
      {state, state.threads_inverse[pid]}
    else
      id = state.next_id
      state = put_in(state.threads[id], pid)
      state = put_in(state.threads_inverse[pid], id)
      state = put_in(state.next_id, id + 1)
      {state, id}
    end
  end

  defp ensure_thread_ids(state, pids) do
    Enum.reduce(pids, {state, []}, fn pid, {state, ids} ->
      {state, id} = ensure_thread_id(state, pid)
      {state, ids ++ [id]}
    end)
  end

  defp ensure_var_id(state, pid, var) do
    if Map.has_key?(state.paused_processes[pid].vars_inverse, var) do
      {state, state.paused_processes[pid].vars_inverse[var]}
    else
      id = state.next_id
      state = put_in(state.paused_processes[pid].vars[id], var)
      state = put_in(state.paused_processes[pid].vars_inverse[var], id)
      state = put_in(state.next_id, id + 1)
      {state, id}
    end
  end

  defp ensure_frame_ids(state, pid, stack_frames) do
    Enum.reduce(stack_frames, {state, []}, fn stack_frame, {state, ids} ->
      {state, id} = ensure_frame_id(state, pid, stack_frame)
      {state, ids ++ [id]}
    end)
  end

  defp ensure_frame_id(state, pid, frame) do
    if Map.has_key?(state.paused_processes[pid].frames_inverse, frame) do
      {state, state.paused_processes[pid].frames_inverse[frame]}
    else
      id = state.next_id
      state = put_in(state.paused_processes[pid].frames[id], frame)
      state = put_in(state.paused_processes[pid].frames_inverse[frame], id)
      state = put_in(state.next_id, id + 1)
      {state, id}
    end
  end

  defp initialize(%{"projectDir" => project_dir} = config) do
    prev_env = Mix.env()
    task = config["task"]
    task_args = config["taskArgs"]

    set_stack_trace_mode(config["stackTraceMode"])
    set_env_vars(config["env"])

    File.cd!(project_dir)

    # Mixfile may already be loaded depending on cwd when launching debugger task
    mixfile = Path.absname(System.get_env("MIX_EXS") || "mix.exs")

    # FIXME: Private API
    unless match?(%{file: ^mixfile}, Mix.ProjectStack.peek()) do
      Code.compile_file(System.get_env("MIX_EXS") || "mix.exs")
    end

    task = task || Mix.Project.config()[:default_task]
    env = task_env(task)
    if env != prev_env, do: change_env(env)

    Mix.Task.run("loadconfig")

    unless is_list(task_args) and "--no-compile" in task_args do
      case Mix.Task.run("compile", ["--ignore-module-conflict"]) do
        {:error, _} ->
          IO.puts(:standard_error, "Aborting debugger due to compile errors")
          :init.stop(1)

        _ ->
          :ok
      end
    end

    # Some tasks (such as Phoenix tests) expect apps to already be running before the test files are
    # required
    if config["startApps"] do
      Mix.Task.run("app.start", [])
    end

    exclude_modules =
      config
      |> Map.get("excludeModules", [])
      |> Enum.map(&string_to_module/1)

    interpret_modules_in(Mix.Project.build_path(), exclude_modules)

    if required_files = config["requireFiles"], do: require_files(required_files)

    ElixirLS.Debugger.Output.send_event("initialized", %{})
  end

  defp set_env_vars(env) when is_map(env) do
    for {k, v} <- env, do: System.put_env(k, v)
    :ok
  end

  defp set_env_vars(env) when is_nil(env), do: :ok

  defp set_stack_trace_mode("all"), do: :int.stack_trace(:all)
  defp set_stack_trace_mode("no_tail"), do: :int.stack_trace(:no_tail)
  defp set_stack_trace_mode("false"), do: :int.stack_trace(false)
  defp set_stack_trace_mode(nil), do: nil

  defp set_stack_trace_mode(_) do
    IO.warn(~S(stackTraceMode must be "all", "no_tail", or "false"))
  end

  defp capabilities do
    %{
      "supportsConfigurationDoneRequest" => true,
      "supportsFunctionBreakpoints" => false,
      "supportsConditionalBreakpoints" => false,
      "supportsHitConditionalBreakpoints" => false,
      "supportsEvaluateForHovers" => false,
      "exceptionBreakpointFilters" => [],
      "supportsStepBack" => false,
      "supportsSetVariable" => false,
      "supportsRestartFrame" => false,
      "supportsGotoTargetsRequest" => false,
      "supportsStepInTargetsRequest" => false,
      "supportsCompletionsRequest" => false,
      "supportsModulesRequest" => false,
      "additionalModuleColumns" => [],
      "supportedChecksumAlgorithms" => [],
      "supportsRestartRequest" => false,
      "supportsExceptionOptions" => false,
      "supportsValueFormattingOptions" => false,
      "supportsExceptionInfoRequest" => false,
      "supportTerminateDebuggee" => false
    }
  end

  defp interpret_modules_in(path, exclude_modules) do
    path
    |> Path.join("**/*.beam")
    |> Path.wildcard()
    |> Enum.map(&(Path.basename(&1, ".beam") |> String.to_atom()))
    |> Enum.filter(&interpretable?(&1, exclude_modules))
    |> Enum.map(fn mod ->
      try do
        {:module, _} = :int.ni(mod)
      catch
        _, _ ->
          IO.warn(
            "Module #{inspect(mod)} cannot be interpreted. Consider adding it to `excludeModules`."
          )
      end
    end)
  end

  defp interpretable?(module, exclude_modules) do
    :int.interpretable(module) == true and !:code.is_sticky(module) and module != __MODULE__ and
      module not in exclude_modules
  end

  defp change_env(env) do
    Mix.env(env)

    # FIXME: Private API
    if project = Mix.Project.pop() do
      %{name: name, file: file} = project
      :code.purge(name)
      :code.delete(name)
      # It's important to use `compile_file` here instead of `require_file`
      # because we are recompiling this file to reload the mix project back onto
      # the project stack.
      Code.compile_file(file)
    end
  end

  defp task_env(task) do
    if System.get_env("MIX_ENV") do
      String.to_atom(System.get_env("MIX_ENV"))
    else
      task = String.to_atom(task)
      Mix.Project.config()[:preferred_cli_env][task] || Mix.Task.preferred_cli_env(task) || :dev
    end
  end

  defp launch_task(task, args) do
    Mix.Task.run(task, args)

    # Starting from Elixir 1.9 Mix.Task.run will return so we need to sleep our
    # process so that the code keeps running (Note: process is expected to be
    # killed by stopping the debugger)
    Process.sleep(:infinity)
  end

  # Interpreting modules defined in .exs files requires that we first load the file and save any
  # modules it defines to actual .beam files in the code path. The user must specify which .exs
  # files to load via the launch configuration. They must be in the correct order (for example,
  # test helpers before tests). We save the .beam files to a temporary folder which we add to the
  # code path.
  defp require_files(required_files) do
    {:ok, _} = File.rm_rf(@temp_beam_dir)
    :ok = File.mkdir_p(@temp_beam_dir)
    true = Code.append_path(Path.expand(@temp_beam_dir))

    for path <- required_files,
        file <- Path.wildcard(path),
        modules = Code.require_file(file),
        is_list(modules),
        {module, beam_bin} <- modules,
        do: save_and_reload(module, beam_bin)
  end

  defp save_and_reload(module, beam_bin) do
    :ok = File.write(Path.join(@temp_beam_dir, to_string(module) <> ".beam"), beam_bin)
    true = :code.delete(module)
    {:module, _} = :int.ni(module)
  end

  defp set_breakpoints(path, lines) do
    if Path.extname(path) == ".erl" do
      module = String.to_atom(Path.basename(path, ".erl"))
      for line <- lines, do: set_breakpoint(module, line)
    else
      try do
        metadata = ElixirSense.Core.Parser.parse_file(path, false, false, nil)

        for line <- lines do
          env = ElixirSense.Core.Metadata.get_env(metadata, line)

          if env.module == nil do
            {:error, "Could not determine module at line"}
          else
            set_breakpoint(env.module, line)
          end
        end
      rescue
        error ->
          for _line <- lines, do: {:error, Exception.format_exit(error)}
      end
    end
  end

  defp set_breakpoint(module, line) do
    case :int.ni(module) do
      {:module, _} ->
        :ok = :int.break(module, line)
        {:ok, module, line}

      _ ->
        {:error, "Cannot interpret module #{inspect(module)}"}
    end
  end

  defp string_to_module(str) when is_binary(str) do
    case str do
      ":" <> name -> String.to_atom(name)
      name -> String.to_atom("Elixir." <> name)
    end
  end
end
