defmodule ElixirLS.LanguageServer.Tracer do
  @moduledoc """
  """
  use GenServer
  alias ElixirLS.LanguageServer.JsonRpc
  require Logger

  @tables ~w(modules calls)a

  for table <- @tables do
    defp table_name(unquote(table)) do
      :"#{__MODULE__}:#{unquote(table)}"
    end
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def notify_settings_stored(project_dir) do
    GenServer.cast(__MODULE__, {:notify_settings_stored, project_dir})
  end

  def notify_deps_path(deps_path) do
    GenServer.cast(__MODULE__, {:notify_deps_path, deps_path})
  end

  defp get_project_dir() do
    case Process.get(:elixir_ls_project_dir) do
      nil ->
        project_dir = GenServer.call(__MODULE__, :get_project_dir)
        Process.put(:elixir_ls_project_dir, project_dir)
        project_dir

      project_dir ->
        project_dir
    end
  end

  defp get_deps_path() do
    case Process.get(:elixir_ls_deps_path) do
      nil ->
        deps_path = GenServer.call(__MODULE__, :get_deps_path)
        Process.put(:elixir_ls_deps_path, deps_path)
        deps_path

      deps_path ->
        deps_path
    end
  end

  def notify_file_deleted(file) do
    GenServer.cast(__MODULE__, {:notify_file_deleted, file})
  end

  @impl true
  def init(_args) do
    for table <- @tables do
      table_name = table_name(table)

      :ets.new(table_name, [
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    state = %{project_dir: nil, deps_path: nil}

    {:ok, state}
  end

  @impl true
  def handle_call(:get_project_dir, _from, %{project_dir: project_dir} = state) do
    {:reply, project_dir, state}
  end

  def handle_call(:get_deps_path, _from, %{deps_path: deps_path} = state) do
    {:reply, deps_path, state}
  end

  @impl true
  def handle_cast({:notify_settings_stored, project_dir}, state) do
    for table <- @tables do
      table_name = table_name(table)
      :ets.delete_all_objects(table_name)
    end

    {:noreply, %{state | project_dir: project_dir}}
  end

  def handle_cast({:notify_deps_path, deps_path}, state) do
    {:noreply, %{state | deps_path: deps_path}}
  end

  def handle_cast({:notify_file_deleted, file}, state) do
    delete_modules_by_file(file)
    delete_calls_by_file(file)
    {:noreply, state}
  end

  def handle_cast(:save, %{project_dir: nil} = state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, _state) do
    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        ElixirLS.LanguageServer.Server.do_sanity_check()
        message = Exception.format_exit(reason)

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => message
          },
          %{}
        )

        JsonRpc.show_message(
          :error,
          "Tracer process exited due to critical error"
        )

        Logger.error("Terminating #{__MODULE__}: #{message}")

        unless :persistent_term.get(:language_server_test_mode, false) do
          Process.sleep(2000)
          System.halt(1)
        else
          IO.warn("Terminating #{__MODULE__}: #{message}")
        end
    end
  end

  defp modules_by_file_matchspec(file, return) do
    [
      {{:"$1", :"$2"},
       [
         {
           :andalso,
           {:andalso, {:==, {:map_get, :file, :"$2"}, file}}
         }
       ], [return]}
    ]
  end

  def get_modules_by_file(file) do
    ms = modules_by_file_matchspec(file, :"$_")
    # ms = :ets.fun2ms(fn {_, map} when :erlang.map_get(:file, map) == file -> map end)

    table = table_name(:modules)
    :ets.safe_fixtable(table, true)

    try do
      :ets.select(table, ms)
    after
      :ets.safe_fixtable(table, false)
    end
  end

  def delete_modules_by_file(file) do
    ms = modules_by_file_matchspec(file, true)
    # ms = :ets.fun2ms(fn {_, map} when :erlang.map_get(:file, map) == file -> true end)

    table = table_name(:modules)
    :ets.safe_fixtable(table, true)

    try do
      :ets.select_delete(table, ms)
    after
      :ets.safe_fixtable(table, false)
    end
  end

  def trace(:start, %Macro.Env{} = env) do
    delete_modules_by_file(env.file)
    delete_calls_by_file(env.file)

    :ok
  end

  def trace({:on_module, _, _}, %Macro.Env{} = env) do
    info = build_module_info(env.module, env.file, env.line)
    :ets.insert(table_name(:modules), {env.module, info})

    :ok
  end

  def trace({kind, meta, module, name, arity} = event, %Macro.Env{} = env)
      when kind in [:imported_function, :imported_macro, :remote_function, :remote_macro] do
    register_call(meta, module, name, arity, kind, event, env)
  end

  def trace({:imported_quoted, meta, module, name, arities} = event, %Macro.Env{} = env) do
    for arity <- arities do
      register_call(meta, module, name, arity, :imported_quoted, event, env)
    end

    :ok
  end

  def trace({kind, meta, name, arity} = event, %Macro.Env{} = env)
      when kind in [:local_function, :local_macro] do
    register_call(meta, env.module, name, arity, kind, event, env)
  end

  def trace({:alias_reference, meta, module} = event, %Macro.Env{} = env) do
    register_call(meta, module, nil, nil, :alias_reference, event, env)
  end

  def trace({:alias, meta, module, _as, _opts} = event, %Macro.Env{} = env) do
    register_call(meta, module, nil, nil, :alias, event, env)
  end

  def trace({kind, meta, module, _opts} = event, %Macro.Env{} = env) when kind in [:import, :require] do
    register_call(meta, module, nil, nil, kind, event, env)
  end

  def trace({:struct_expansion, meta, name, _assocs} = event, %Macro.Env{} = env) do
    register_call(meta, name, nil, nil, :struct_expansion, event, env)
  end

  def trace({:alias_expansion, meta, as, alias} = event, %Macro.Env{} = env) do
    register_call(meta, as, nil, nil, :alias_expansion_as, event, env)
    register_call(meta, alias, nil, nil, :alias_expansion, event, env)
  end

  def trace(_trace, _env) do
    # IO.inspect(trace, label: "skipped")
    :ok
  end

  defp build_module_info(module, file, line) do
    defs =
      for {name, arity} <- Module.definitions_in(module) do
        def_info = Module.get_definition(module, {name, arity})
        {{name, arity}, build_def_info(def_info)}
      end

    attributes =
      for name <- Module.attributes_in(module) do
        # reading attribute value here breaks unused attributes warnings
        # https://github.com/elixir-lang/elixir/issues/13168
        # {name, Module.get_attribute(module, name)}
        {name, nil}
      end

    %{
      defs: defs,
      attributes: attributes,
      file: file,
      line: line
    }
  end

  defp build_def_info({:v1, def_kind, meta_1, clauses}) do
    clauses =
      for {meta_2, arguments, guards, _body} <- clauses do
        %{
          arguments: arguments,
          guards: guards,
          meta: meta_2
        }
      end

    %{
      kind: def_kind,
      clauses: clauses,
      meta: meta_1
    }
  end

  defp register_call(meta, module, name, arity, kind, event, env) do
    if in_project_sources?(env.file) do
      do_register_call(meta, module, name, arity, kind, event, env)
    end

    :ok
  end

  defp do_register_call(meta, module, name, arity, kind, event, env) do
    callee = {module, name, arity}

    line = meta[:line]
    column = meta[:column]

    # Determine reference type based on kind (similar to Mix.Tasks.Xref)
    reference_type = determine_reference_type(event, env)
    
    # Store call info with reference type
    call_info = %{
      kind: kind,
      reference_type: reference_type,
      caller_module: env.module,
      caller_function: env.function
    }

    # TODO meta can have last or maybe other?
    # last
    # end_of_expression
    # closing

    :ets.insert(table_name(:calls), {{callee, env.file, line, column}, call_info})
  end
  
  # Determine reference type based on trace kind (following Mix.Tasks.Xref logic)
  def determine_reference_type({:alias_reference, _meta, module}, %Macro.Env{} = env) when env.module != module do
    case env do
      %Macro.Env{function: nil} -> :compile
      %Macro.Env{context: nil} -> :runtime
      %Macro.Env{} -> nil
    end
  end
  def determine_reference_type({:require, meta, _module, _opts}, _env),
    do: require_mode(meta)

  def determine_reference_type({:struct_expansion, _meta, _module, _keys}, _env),
    do: :export

  def determine_reference_type({:remote_function, _meta, _module, _function, _arity}, env),
    do: mode(env)

  def determine_reference_type({:remote_macro, _meta, _module, _function, _arity}, _env),
    do: :compile

  def determine_reference_type({:imported_function, _meta, _module, _function, _arity}, env),
    do: mode(env)

  def determine_reference_type({:imported_macro, _meta, _module, _function, _arity}, _env),
    do: :compile

  def determine_reference_type(_event, _env),
    do: nil

  defp require_mode(meta), do: if(meta[:from_macro], do: :compile, else: :export)

  defp mode(%Macro.Env{function: nil}), do: :compile
  defp mode(_), do: :runtime

  def get_trace do
    # TODO get by callee
    table = table_name(:calls)
    :ets.safe_fixtable(table, true)

    try do
      :ets.tab2list(table)
      |> Enum.map(fn 
        # Handle new format with call_info map
        {{callee, file, line, column}, %{} = call_info} ->
          %{
            callee: callee,
            file: file,
            line: line,
            column: column,
            kind: call_info.kind,
            reference_type: call_info.reference_type,
            caller_module: call_info.caller_module,
            caller_function: call_info.caller_function
          }
      end)
      |> Enum.group_by(fn %{callee: callee} -> callee end)
    after
      :ets.safe_fixtable(table, false)
    end
  end

  defp in_project_sources?(path) do
    project_dir = get_project_dir()
    deps_path = get_deps_path()

    if project_dir != nil do
      cond do
        deps_path && Path.relative_to(path, deps_path) != path ->
          # path is in deps_path
          false

        Path.relative_to(path, project_dir) == path ->
          # path not in project_dir, probably a path dep
          false

        true ->
          true
      end
    else
      false
    end
  end

  defp calls_by_file_matchspec(file, return) do
    [
      {{{:_, :"$1", :_, :_}, :_}, [{:==, :"$1", file}], [return]}
    ]
  end

  def get_calls_by_file(file) do
    ms = calls_by_file_matchspec(file, :"$_")

    table = table_name(:calls)
    :ets.safe_fixtable(table, true)

    try do
      :ets.select(table, ms)
    after
      :ets.safe_fixtable(table, false)
    end
  end

  def delete_calls_by_file(file) do
    ms = calls_by_file_matchspec(file, true)

    table = table_name(:calls)
    :ets.safe_fixtable(table, true)

    try do
      :ets.select_delete(table, ms)
    after
      :ets.safe_fixtable(table, false)
    end
  end
end
