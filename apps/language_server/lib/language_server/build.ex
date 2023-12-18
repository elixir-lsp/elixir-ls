defmodule ElixirLS.LanguageServer.Build do
  alias ElixirLS.LanguageServer.{Server, JsonRpc, Diagnostics, Tracer, SourceFile}
  alias ElixirLS.Utils.MixfileHelpers
  require Logger

  def build(parent, root_path, opts) when is_binary(root_path) do
    build_pid_reference =
      spawn_monitor(fn ->
        with_build_lock(fn ->
          {us, result} =
            :timer.tc(fn ->
              Logger.info("Starting build with MIX_ENV: #{Mix.env()} MIX_TARGET: #{Mix.target()}")

              # read cache before cleaning up mix state in reload_project
              cached_deps = read_cached_deps()
              mixfile = SourceFile.Path.absname(MixfileHelpers.mix_exs(), root_path)

              case reload_project(mixfile, root_path) do
                {:ok, mixfile_diagnostics} ->
                  {deps_result, deps_raw_diagnostics} =
                    with_diagnostics([log: true], fn ->
                      try do
                        # this call can raise
                        current_deps =
                          if Version.match?(System.version(), "< 1.16.0-dev") do
                            Mix.Dep.load_on_environment([])
                          else
                            Mix.Dep.Converger.converge([])
                          end

                        purge_changed_deps(current_deps, cached_deps)

                        if Keyword.get(opts, :fetch_deps?) and current_deps != cached_deps do
                          fetch_deps(current_deps)
                        end

                        state = %{
                          get: Mix.Project.get(),
                          # project_file: Mix.Project.project_file(),
                          config: Mix.Project.config(),
                          # config_files: Mix.Project.config_files(),
                          config_mtime: Mix.Project.config_mtime(),
                          umbrella?: Mix.Project.umbrella?(),
                          apps_paths: Mix.Project.apps_paths(),
                          # deps_path: Mix.Project.deps_path(),
                          # deps_apps: Mix.Project.deps_apps(),
                          # deps_scms: Mix.Project.deps_scms(),
                          deps_paths: Mix.Project.deps_paths(),
                          # build_path: Mix.Project.build_path(),
                          manifest_path: Mix.Project.manifest_path()
                        }

                        ElixirLS.LanguageServer.MixProjectCache.store(state)

                        :ok
                      catch
                        kind, err ->
                          {payload, stacktrace} = Exception.blame(kind, err, __STACKTRACE__)
                          {:error, kind, payload, stacktrace}
                      end
                    end)

                  deps_diagnostics =
                    deps_raw_diagnostics
                    |> Enum.map(&Diagnostics.from_code_diagnostic(&1, mixfile, root_path))

                  case deps_result do
                    :ok ->
                      if Keyword.get(opts, :compile?) do
                        {status, compile_diagnostics} =
                          run_mix_compile(Keyword.get(opts, :force?, false))

                        compile_diagnostics =
                          compile_diagnostics
                          |> Enum.map(
                            &Diagnostics.from_mix_task_compiler_diagnostic(&1, mixfile, root_path)
                          )

                        Server.build_finished(
                          parent,
                          {status, mixfile_diagnostics ++ deps_diagnostics ++ compile_diagnostics}
                        )

                        :"mix_compile_#{status}"
                      else
                        Server.build_finished(
                          parent,
                          {:ok, mixfile_diagnostics ++ deps_diagnostics}
                        )

                        :mix_compile_disabled
                      end

                    {:error, kind, err, stacktrace} ->
                      Server.build_finished(
                        parent,
                        {:error,
                         mixfile_diagnostics ++
                           deps_diagnostics ++
                           [
                             Diagnostics.from_error(
                               kind,
                               err,
                               stacktrace,
                               mixfile,
                               root_path
                             )
                           ]}
                      )

                      :deps_error
                  end

                {:error, mixfile_diagnostics} ->
                  Server.build_finished(parent, {:error, mixfile_diagnostics})
                  :mixfile_error

                :no_mixfile ->
                  Server.build_finished(parent, {:no_mixfile, []})
                  :no_mixfile
              end
            end)

          if Keyword.get(opts, :compile?) do
            Tracer.save()
            Logger.info("Compile took #{div(us, 1000)} milliseconds")
          else
            Logger.info("Mix project load took #{div(us, 1000)} milliseconds")
          end

          JsonRpc.telemetry("build", %{"elixir_ls.build_result" => result}, %{
            "elixir_ls.build_time" => div(us, 1000)
          })
        end)
      end)

    spawn(fn ->
      Process.monitor(parent)
      {build_process, _ref} = build_pid_reference
      Process.monitor(build_process)

      receive do
        {:DOWN, _ref, _, ^build_process, _reason} ->
          :ok

        {:DOWN, _ref, _, ^parent, _reason} ->
          Process.exit(build_process, :kill)
      end
    end)

    build_pid_reference
  end

  def clean(root_path, clean_deps? \\ false) when is_binary(root_path) do
    with_build_lock(fn ->
      mixfile = SourceFile.Path.absname(MixfileHelpers.mix_exs(), root_path)

      case reload_project(mixfile, root_path) do
        {:ok, _} ->
          Mix.Task.clear()
          run_mix_clean(clean_deps?)

        other ->
          other
      end
    end)
  end

  def with_build_lock(func) do
    :global.trans({__MODULE__, self()}, func)
  end

  defp reload_project(mixfile, root_path) do
    if File.exists?(mixfile) do
      if module = Mix.Project.get() do
        if module != ElixirLS.LanguageServer.MixProject do
          build_path = Mix.Project.config()[:build_path]

          deps_paths =
            try do
              # this call can raise (RuntimeError) cannot retrieve dependencies information because dependencies
              # were not loaded. Please invoke one of "deps.loadpaths", "loadpaths", or "compile" Mix task
              Mix.Project.deps_paths()
            catch
              kind, payload ->
                {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
                message = Exception.format(kind, payload, stacktrace)
                Logger.warning("Unable to prune mix project: #{message}")
                []
            end

          for {app, path} <- deps_paths do
            child_module =
              try do
                Mix.Project.in_project(app, path, [build_path: build_path], fn mix_project ->
                  mix_project
                end)
              catch
                kind, payload ->
                  {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
                  message = Exception.format(kind, payload, stacktrace)
                  Logger.warning("Unable to prune mix project module for #{app}: #{message}")
                  nil
              end

            if child_module do
              purge_module(child_module)
            end
          end

          unload_mix_project_apps()

          Mix.Project.pop()
          purge_module(module)
        else
          # don't do any pruning in language server tests
          Mix.Project.pop()
        end
      end

      # We need to clear persistent cache, otherwise `deps.loadpaths` task fails with
      # (Mix.Error) Can't continue due to errors on dependencies
      # see https://github.com/elixir-lsp/elixir-ls/issues/120
      # originally reported in https://github.com/JakeBecker/elixir-ls/issues/71
      # Note that `Mix.State.clear_cache()` is not enough (at least on elixir 1.14)
      Mix.Project.clear_deps_cache()
      Mix.State.clear_cache()

      Mix.Task.clear()

      if Version.match?(System.version(), ">= 1.15.0-dev") do
        if Logger.Backends.JsonRpc not in :logger.get_handler_ids() do
          Logger.error("Build without intercepted logger #{inspect(:logger.get_handler_ids())}")

          for handler_id <- :logger.get_handler_ids() do
            :ok = :logger.remove_handler(handler_id)
          end

          :ok =
            :logger.add_handler(
              Logger.Backends.JsonRpc,
              Logger.Backends.JsonRpc,
              Logger.Backends.JsonRpc.handler_config()
            )
        end
      end

      # we need to reset compiler options
      # project may leave tracers after previous compilation and we don't want them interfering
      # see https://github.com/elixir-lsp/elixir-ls/issues/717
      set_compiler_options()

      # Override build directory to avoid interfering with other dev tools
      Mix.ProjectStack.post_config(build_path: ".elixir_ls/build")
      Mix.ProjectStack.post_config(prune_code_paths: false)

      Mix.ProjectStack.post_config(
        test_elixirc_options: [
          docs: true,
          debug_info: true
        ]
      )

      # Mix.ProjectStack.post_config(state_loader: {:cli, List.first(args)})
      # added in https://github.com/elixir-lang/elixir/commit/9e07da862784ac7d18a1884141c49ab049e61691
      # TODO refactor to use a custom state loader when we require elixir 1.15?

      # since elixir 1.10 mix disables undefined warnings for mix.exs
      # see discussion in https://github.com/elixir-lang/elixir/issues/9676
      # https://github.com/elixir-lang/elixir/blob/6f96693b355a9b670f2630fd8e6217b69e325c5a/lib/mix/lib/mix/cli.ex#L41
      old_undefined = Code.get_compiler_option(:no_warn_undefined)
      Code.put_compiler_option(:no_warn_undefined, :all)

      # We can get diagnostics if Mixfile fails to load
      {mixfile_status, mixfile_diagnostics} =
        if Version.match?(System.version(), ">= 1.15.3") do
          {result, raw_diagnostics} =
            with_diagnostics([log: true], fn ->
              try do
                Code.compile_file(mixfile)
                :ok
              catch
                kind, err ->
                  {payload, stacktrace} = Exception.blame(kind, err, __STACKTRACE__)
                  {:error, kind, payload, stacktrace}
              end
            end)

          diagnostics =
            raw_diagnostics
            |> Enum.map(&Diagnostics.from_code_diagnostic(&1, mixfile, root_path))

          case result do
            :ok ->
              {:ok, diagnostics}

            {:error, kind, err, stacktrace} ->
              {:error,
               diagnostics ++
                 [Diagnostics.from_error(kind, err, stacktrace, mixfile, root_path)]}
          end
        else
          case Kernel.ParallelCompiler.compile([mixfile]) do
            {:ok, _, warnings} ->
              {:ok,
               Enum.map(
                 warnings,
                 &Diagnostics.from_kernel_parallel_compiler_tuple(&1, :warning, mixfile)
               )}

            {:error, errors, warnings} ->
              {
                :error,
                Enum.map(
                  warnings,
                  &Diagnostics.from_kernel_parallel_compiler_tuple(&1, :warning, mixfile)
                ) ++
                  Enum.map(
                    errors,
                    &Diagnostics.from_kernel_parallel_compiler_tuple(&1, :error, mixfile)
                  )
              }
          end
        end

      # restore warnings
      Code.put_compiler_option(:no_warn_undefined, old_undefined)

      if mixfile_status == :ok do
        # The project may override our logger config, so we reset it after loading their config
        # store log config
        logger_config = Application.get_all_env(:logger)

        {config_result, config_raw_diagnostics} =
          with_diagnostics([log: true], fn ->
            try do
              Mix.Task.run("loadconfig")
              :ok
            catch
              kind, err ->
                {payload, stacktrace} = Exception.blame(kind, err, __STACKTRACE__)
                {:error, kind, payload, stacktrace}
            after
              # reset log config
              Application.put_all_env(logger: logger_config)

              if Version.match?(System.version(), ">= 1.15.0-dev") do
                # remove all log handlers and restore our
                for handler_id <- :logger.get_handler_ids(),
                    handler_id != Logger.Backends.JsonRpc do
                  :ok = :logger.remove_handler(handler_id)
                end

                if Logger.Backends.JsonRpc not in :logger.get_handler_ids() do
                  :ok =
                    :logger.add_handler(
                      Logger.Backends.JsonRpc,
                      Logger.Backends.JsonRpc,
                      Logger.Backends.JsonRpc.handler_config()
                    )
                end
              end

              # make sure ANSI is disabled
              Application.put_env(:elixir, :ansi_enabled, false)
            end
          end)

        config_path = SourceFile.Path.absname(Mix.Project.config()[:config_path], root_path)

        config_diagnostics =
          config_raw_diagnostics
          |> Enum.map(&Diagnostics.from_code_diagnostic(&1, config_path, root_path))

        case config_result do
          {:error, kind, err, stacktrace} ->
            {:error,
             mixfile_diagnostics ++
               config_diagnostics ++
               [Diagnostics.from_error(kind, err, stacktrace, config_path, root_path)]}

          :ok ->
            {:ok, mixfile_diagnostics ++ config_diagnostics}
        end
      else
        {mixfile_status, mixfile_diagnostics}
      end
    else
      msg =
        "No mixfile found in project. " <>
          "To use a subdirectory, set `elixirLS.projectDir` in your settings"

      Logger.warning(msg <> ". Looked for mixfile at #{inspect(mixfile)}")

      :no_mixfile
    end
  end

  defp run_mix_compile(force?) do
    opts = [
      "--return-errors",
      "--ignore-module-conflict",
      "--no-protocol-consolidation"
    ]

    opts =
      if Version.match?(System.version(), ">= 1.15.0-dev") do
        opts
      else
        opts ++ ["--all-warnings"]
      end

    opts =
      if force? do
        opts ++ ["--force"]
      else
        opts
      end

    case Mix.Task.run("compile", opts) do
      {status, diagnostics} when status in [:ok, :error, :noop] and is_list(diagnostics) ->
        {status, diagnostics}

      status when status in [:ok, :noop] ->
        {status, []}

      other ->
        Logger.debug("mix compile returned #{inspect(other)}")
        {:ok, []}
    end
  end

  defp run_mix_clean(clean_deps?) do
    opts = []

    opts =
      if clean_deps? do
        opts ++ ["--deps"]
      else
        opts
      end

    results = Mix.Task.run("clean", opts) |> List.wrap()

    if Enum.all?(results, &match?(:ok, &1)) do
      :ok
    else
      Logger.error("mix clean returned #{inspect(results)}")

      JsonRpc.telemetry(
        "mix_clean_error",
        %{"elixir_ls.mix_clean_error" => inspect(results)},
        %{}
      )

      {:error, :clean_failed}
    end
  end

  defp purge_module(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp purge_app(app, purge_modules? \\ true) do
    Logger.debug("Stopping #{app}")

    case Application.stop(app) do
      :ok -> :ok
      {:error, {:not_started, _}} -> :ok
      {:error, error} -> Logger.warning("Application.stop failed for #{app}: #{inspect(error)}")
    end

    if purge_modules? do
      modules =
        case :application.get_key(app, :modules) do
          {:ok, modules} -> modules
          _ -> []
        end

      if modules != [] do
        Logger.debug("Purging #{length(modules)} modules from #{app}")
        for module <- modules, do: purge_module(module)
      end
    end

    Logger.debug("Unloading #{app}")

    case Application.unload(app) do
      :ok -> :ok
      {:error, {:not_loaded, _}} -> :ok
      {:error, error} -> Logger.warning("Application.unload failed for #{app}: #{inspect(error)}")
    end
  end

  defp get_deps_by_app(deps), do: get_deps_by_app(deps, %{})
  defp get_deps_by_app([], acc), do: acc

  defp get_deps_by_app([curr = %Mix.Dep{app: app, deps: deps} | rest], acc) do
    acc = get_deps_by_app(deps, acc)

    list =
      case acc[app] do
        nil -> [curr]
        list -> [curr | list]
      end

    get_deps_by_app(rest, acc |> Map.put(app, list))
  end

  defp maybe_purge_dep(%Mix.Dep{status: status, deps: deps} = dep) do
    for dep <- deps, do: maybe_purge_dep(dep)

    purge? =
      case status do
        {:nomatchvsn, _} -> true
        :lockoutdated -> true
        {:lockmismatch, _} -> true
        _ -> false
      end

    if purge? do
      purge_dep(dep)
    end
  end

  defp purge_dep(%Mix.Dep{app: app} = dep) do
    if app in [
         :language_server,
         :elixir_ls_utils,
         :elixir_sense,
         :jason_v,
         :path_glob_vendored,
         :dialyxir_vendored,
         :erlex_vendored,
         :erl2ex_vendored
       ] do
      raise "Unloading required #{app}"
    end

    for path <- Mix.Dep.load_paths(dep) do
      Code.delete_path(path)
    end

    purge_app(app)
  end

  defp purge_changed_deps(_current_deps, nil), do: :ok

  defp purge_changed_deps(current_deps, cached_deps) do
    current_deps_by_app = get_deps_by_app(current_deps)
    cached_deps_by_app = get_deps_by_app(cached_deps)
    removed_apps = Map.keys(cached_deps_by_app) -- Map.keys(current_deps_by_app)

    removed_deps =
      cached_deps_by_app
      |> Map.take(removed_apps)
      |> Enum.flat_map(&elem(&1, 1))
      |> Enum.uniq()

    # purge removed dependencies
    for dep <- removed_deps do
      purge_dep(dep)
    end

    # purge current dependencies in invalid state
    for dep <- current_deps do
      maybe_purge_dep(dep)
    end
  end

  defp unload_mix_project_apps() do
    # note that this will unload config so we need to call loadconfig afterwards
    mix_project_apps =
      if Mix.Project.umbrella?() do
        Mix.Project.apps_paths() |> Enum.map(&elem(&1, 0))
      else
        # in umbrella Mix.Project.apps_paths() returns nil
        # get app from config instead
        [Mix.Project.config()[:app]]
      end

    # purge mix project apps
    # elixir compiler loads apps only on initial compilation
    # on subsequent ones it does not update application controller state
    # if we don't unload the apps we end up with invalid state
    # e.g. :application.get_key(app, :modules) returns outdated module list
    # see https://github.com/elixir-lang/elixir/issues/13001
    for app <- mix_project_apps do
      purge_app(app, false)
    end
  end

  defp fetch_deps(current_deps) do
    missing_deps =
      current_deps
      |> Enum.filter(fn %Mix.Dep{status: status, scm: scm} ->
        case status do
          {:unavailable, _} -> scm.fetchable?()
          {:nomatchvsn, _} -> true
          :nolock -> true
          :lockoutdated -> true
          {:lockmismatch, _} -> true
          _ -> false
        end
      end)
      |> Enum.map(fn %Mix.Dep{app: app, requirement: requirement} -> "#{app} #{requirement}" end)

    if missing_deps != [] do
      JsonRpc.show_message(
        :info,
        "Fetching #{Enum.count(missing_deps)} deps: #{Enum.join(missing_deps, ", ")}"
      )

      Mix.Task.run("deps.get")

      JsonRpc.show_message(
        :info,
        "Done fetching deps"
      )
    else
      Logger.debug("All deps are up to date")
    end

    :ok
  end

  def set_compiler_options(options \\ [], parser_options \\ []) do
    parser_options =
      Keyword.merge(parser_options,
        columns: true,
        token_metadata: true
      )

    options =
      Keyword.merge(options,
        tracers: [Tracer],
        debug_info: true,
        docs: true,
        parser_options: parser_options
      )

    options =
      if Version.match?(System.version(), ">= 1.14.0-dev") do
        Keyword.merge(options,
          # this disables warnings `X has already been consolidated`
          # when running `compile` task
          ignore_already_consolidated: true
        )
      else
        options
      end

    Code.compiler_options(options)
  end

  defp read_cached_deps() do
    # we cannot use Mix.Dep.cached() here as it tries to load deps
    project = Mix.Project.get()
    # in test do not try to load cache from elixir_ls
    if project != nil and project != ElixirLS.LanguageServer.MixProject do
      env_target = {Mix.env(), Mix.target()}

      case Mix.State.read_cache({:cached_deps, project}) do
        {^env_target, deps} -> deps
        _ -> nil
      end
    end
  end

  def with_diagnostics(opts \\ [], fun) do
    # Code.with_diagnostics is broken on elixir < 1.15.3
    if Version.match?(System.version(), ">= 1.15.3") do
      Code.with_diagnostics(opts, fun)
    else
      {fun.(), []}
    end
  end
end
