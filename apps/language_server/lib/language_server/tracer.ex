defmodule ElixirLS.LanguageServer.Tracer do
  @moduledoc """
  """
  use GenServer
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.LanguageServer.SourceFile
  require Logger

  @version 3

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

    state = %{project_dir: nil}

    {:ok, state}
  end

  @impl true
  def handle_call(:get_project_dir, _from, %{project_dir: project_dir} = state) do
    {:reply, project_dir, state}
  end

  @impl true
  def handle_cast({:notify_settings_stored, project_dir}, state) do
    for table <- @tables do
      table_name = table_name(table)
      :ets.delete_all_objects(table_name)
    end

    {:noreply, %{state | project_dir: project_dir}}
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
  def terminate(reason, state) do
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

  def trace({kind, meta, module, name, arity}, %Macro.Env{} = env)
      when kind in [:imported_function, :imported_macro, :remote_function, :remote_macro] do
    register_call(meta, module, name, arity, env)
  end

  def trace({kind, meta, name, arity}, %Macro.Env{} = env)
      when kind in [:local_function, :local_macro] do
    register_call(meta, env.module, name, arity, env)
  end

  def trace({:alias_reference, meta, module}, %Macro.Env{} = env) do
    register_call(meta, module, nil, nil, env)
  end

  def trace({:alias, meta, module, _as, _opts}, %Macro.Env{} = env) do
    register_call(meta, module, nil, nil, env)
  end

  def trace({kind, meta, module, _opts}, %Macro.Env{} = env) when kind in [:import, :require] do
    register_call(meta, module, nil, nil, env)
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

  defp register_call(meta, module, name, arity, env) do
    if in_project_sources?(env.file) do
      do_register_call(meta, module, name, arity, env)
    end

    :ok
  end

  defp do_register_call(meta, module, name, arity, env) do
    callee = {module, name, arity}

    line = meta[:line]
    column = meta[:column]
    # TODO meta can have last or maybe other?

    :ets.insert(table_name(:calls), {{callee, env.file, line, column}, :ok})
  end

  def get_trace do
    # TODO get by callee
    table = table_name(:calls)
    :ets.safe_fixtable(table, true)

    try do
      :ets.tab2list(table)
      |> Enum.map(fn {{callee, file, line, column}, _} ->
        %{
          callee: callee,
          file: file,
          line: line,
          column: column
        }
      end)
      |> Enum.group_by(fn %{callee: callee} -> callee end)
    after
      :ets.safe_fixtable(table, false)
    end
  end

  defp in_project_sources?(path) do
    project_dir = get_project_dir()

    if project_dir != nil do
      topmost_path_segment =
        path
        |> Path.relative_to(project_dir)
        |> Path.split()
        |> hd

      topmost_path_segment != "deps"
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
