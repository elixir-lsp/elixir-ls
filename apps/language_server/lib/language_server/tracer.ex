defmodule ElixirLS.LanguageServer.Tracer do
  @moduledoc """
  """
  use GenServer
  alias ElixirLS.LanguageServer.JsonRpc
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

  def notify_settings_stored() do
    GenServer.cast(__MODULE__, :notify_settings_stored)
  end

  def save() do
    GenServer.cast(__MODULE__, :save)
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

    {:ok, %{project_dir: nil}}
  end

  @impl true
  def handle_call(:get_project_dir, _from, %{project_dir: project_dir} = state) do
    {:reply, project_dir, state}
  end

  @impl true
  def handle_cast(:notify_settings_stored, state) do
    project_dir = :persistent_term.get(:language_server_project_dir)
    maybe_close_tables(state)

    for table <- @tables do
      table_name = table_name(table)
      :ets.delete_all_objects(table_name)
    end

    if project_dir != nil do
      {us, _} =
        :timer.tc(fn ->
          for table <- @tables do
            init_table(table, project_dir)
          end
        end)

      Logger.info("Loaded DETS databases in #{div(us, 1000)}ms")
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

  def handle_cast(:save, %{project_dir: project_dir} = state) do
    for table <- @tables do
      table_name = table_name(table)

      sync(table_name)
    end

    write_manifest(project_dir)

    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    maybe_close_tables(state)

    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        message = Exception.format_exit(reason)

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => message
          },
          %{}
        )

        Logger.info("Terminating #{__MODULE__}: #{message}")
    end
  end

  defp maybe_close_tables(%{project_dir: nil}), do: :ok

  defp maybe_close_tables(%{project_dir: project_dir}) do
    for table <- @tables do
      close_table(table, project_dir)
    end

    :ok
  end

  defp dets_path(project_dir, table) do
    Path.join([project_dir, ".elixir_ls", "#{table}.dets"])
  end

  def init_table(table, project_dir) do
    table_name = table_name(table)
    path = dets_path(project_dir, table)

    opts = [file: path |> String.to_charlist(), auto_save: 60_000]

    :ok = path |> Path.dirname() |> File.mkdir_p()

    case :dets.open_file(table_name, opts) do
      {:ok, _} ->
        :ok

      {:error, {:not_a_dets_file, _} = reason} ->
        Logger.warning("Unable to open DETS #{path}: #{inspect(reason)}")
        File.rm_rf!(path)
        {:ok, _} = :dets.open_file(table_name, opts)

      {:error, {:file_error, _, :enoent} = reason} ->
        Logger.warning("Unable to open DETS #{path}: #{inspect(reason)}")
        :ok = path |> Path.dirname() |> File.mkdir_p()
        {:ok, _} = :dets.open_file(table_name, opts)
    end

    Process.sleep(200)

    case :dets.to_ets(table_name, table_name) do
      ^table_name ->
        :ok

      {:error, reason} ->
        Logger.warning("Unable to read DETS #{path}: #{inspect(reason)}")
        File.rm_rf!(path)
        Process.sleep(200)
        {:ok, _} = :dets.open_file(table_name, opts)
        Process.sleep(200)
        ^table_name = :dets.to_ets(table_name, table_name)
    end
  catch
    kind, payload ->
      {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
      error_msg = Exception.format(kind, payload, stacktrace)

      Logger.error(
        "Unable to init tracer table #{table} in directory #{project_dir}: #{error_msg}"
      )

      JsonRpc.show_message(
        :error,
        "Unable to init tracer tables in #{project_dir}"
      )

      JsonRpc.telemetry(
        "lsp_server_error",
        %{
          "elixir_ls.lsp_process" => inspect(__MODULE__),
          "elixir_ls.lsp_server_error" => error_msg
        },
        %{}
      )

      unless Application.get_env(:language_server, :test_mode) do
        Process.sleep(2000)
        System.halt(1)
      end
  end

  def close_table(table, project_dir) do
    path = dets_path(project_dir, table)
    table_name = table_name(table)
    sync(table_name)

    case :dets.close(table_name) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Unable to close DETS #{path}, #{inspect(reason)}")

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => "Unable to close DETS #{path}, #{inspect(reason)}"
          },
          %{}
        )
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

    :ets.select(table_name(:modules), ms)
  end

  def delete_modules_by_file(file) do
    ms = modules_by_file_matchspec(file, true)
    # ms = :ets.fun2ms(fn {_, map} when :erlang.map_get(:file, map) == file -> true end)

    :ets.select_delete(table_name(:modules), ms)
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
        def_info = apply(Module, :get_definition, [module, {name, arity}])
        {{name, arity}, build_def_info(def_info)}
      end

    attributes =
      if Version.match?(System.version(), ">= 1.13.0-dev") do
        for name <- apply(Module, :attributes_in, [module]) do
          {name, Module.get_attribute(module, name)}
        end
      else
        []
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
    :ets.tab2list(table_name(:calls))
    |> Enum.map(fn {{callee, file, line, column}, _} ->
      %{
        callee: callee,
        file: file,
        line: line,
        column: column
      }
    end)
    |> Enum.group_by(fn %{callee: callee} -> callee end)
  end

  defp sync(table_name) do
    with :ok <- :dets.from_ets(table_name, table_name),
         :ok <- :dets.sync(table_name) do
      :ok
    else
      other ->
        Logger.error("Unable to sync DETS #{table_name}, #{inspect(other)}")

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => "Unable to sync DETS #{table_name}, #{inspect(other)}"
          },
          %{}
        )
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

    :ets.select(table_name(:calls), ms)
  end

  def delete_calls_by_file(file) do
    ms = calls_by_file_matchspec(file, true)

    :ets.select_delete(table_name(:calls), ms)
  end

  defp manifest_path(project_dir) do
    Path.join([project_dir, ".elixir_ls", "tracer_db.manifest"])
  end

  def write_manifest(project_dir) do
    path = manifest_path(project_dir)
    File.rm_rf!(path)

    with :ok <- path |> Path.dirname() |> File.mkdir_p(),
         :ok <- File.write(path, "#{@version}", [:write]) do
      :ok
    else
      {:error, err} ->
        Logger.warning(
          "Cannot create manifest .elixir_ls/tracer_db.manifest, cause: #{Atom.to_string(err)}"
        )
    end
  end

  def read_manifest(project_dir) do
    with {:ok, text} <- File.read(manifest_path(project_dir)),
         {version, ""} <- Integer.parse(text) do
      version
    else
      _ -> nil
    end
  end

  def manifest_version_current?(project_dir) do
    read_manifest(project_dir) == @version
  end

  def clean_dets(project_dir) do
    for path <-
          Path.join([project_dir, ".elixir_ls/*.dets"])
          |> Path.wildcard(),
        do: File.rm_rf!(path)
  end
end
