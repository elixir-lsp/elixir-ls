defmodule ElixirLS.LanguageServer.Build do
  alias ElixirLS.LanguageServer.{Server, JsonRpc, Diagnostics, Tracer}
  alias ElixirLS.Utils.MixfileHelpers
  require Logger

  def build(parent, root_path, opts) when is_binary(root_path) do
    if Path.absname(File.cwd!()) != Path.absname(root_path) do
      Logger.info("Skipping build because cwd changed from #{root_path} to #{File.cwd!()}")
      {nil, nil}
    else
      spawn_monitor(fn ->
        with_build_lock(fn ->
          {us, _} =
            :timer.tc(fn ->
              Logger.info("Starting build with MIX_ENV: #{Mix.env()} MIX_TARGET: #{Mix.target()}")

              # read cache before cleaning up mix state in reload_project
              cached_deps = read_cached_deps()

              case reload_project() do
                {:ok, mixfile_diagnostics} ->
                  # FIXME: Private API

                  try do
                    # this call can raise
                    current_deps = Mix.Dep.load_on_environment([])

                    purge_changed_deps(current_deps, cached_deps)

                    if Keyword.get(opts, :fetch_deps?) and current_deps != cached_deps do
                      fetch_deps(current_deps)
                    end

                    # if we won't do it elixir >= 1.11 warns that protocols have already been consolidated
                    purge_consolidated_protocols()
                    {status, diagnostics} = run_mix_compile()

                    diagnostics = Diagnostics.normalize(diagnostics, root_path)
                    Server.build_finished(parent, {status, mixfile_diagnostics ++ diagnostics})
                  rescue
                    e ->
                      Logger.warn(
                        "Mix.Dep.load_on_environment([]) failed: #{inspect(e.__struct__)} #{Exception.message(e)}"
                      )

                      # TODO pass diagnostic
                      Server.build_finished(parent, {:error, []})
                  end

                {:error, mixfile_diagnostics} ->
                  Server.build_finished(parent, {:error, mixfile_diagnostics})

                :no_mixfile ->
                  Server.build_finished(parent, {:no_mixfile, []})
              end
            end)

          Tracer.save()
          Logger.info("Compile took #{div(us, 1000)} milliseconds")
        end)
      end)
    end
  end

  def clean(clean_deps? \\ false) do
    with_build_lock(fn ->
      Mix.Task.clear()
      run_mix_clean(clean_deps?)
    end)
  end

  def with_build_lock(func) do
    :global.trans({__MODULE__, self()}, func)
  end

  def reload_project do
    mixfile = Path.absname(MixfileHelpers.mix_exs())

    if File.exists?(mixfile) do
      if module = Mix.Project.get() do
        # FIXME: Private API
        Mix.Project.pop()
        purge_module(module)
      end

      # We need to clear persistent cache, otherwise `deps.loadpaths` task fails with
      # (Mix.Error) Can't continue due to errors on dependencies
      # see https://github.com/elixir-lsp/elixir-ls/issues/120
      # originally reported in https://github.com/JakeBecker/elixir-ls/issues/71
      # Note that `Mix.State.clear_cache()` is not enough (at least on elixir 1.14)
      Mix.Project.clear_deps_cache()
      Mix.State.clear_cache()

      Mix.Task.clear()

      # we need to reset compiler options
      # project may leave tracers after previous compilation and we don't woant them interfeering
      # see https://github.com/elixir-lsp/elixir-ls/issues/717
      set_compiler_options()

      # Override build directory to avoid interfering with other dev tools
      # FIXME: Private API
      Mix.ProjectStack.post_config(build_path: ".elixir_ls/build")

      # We can get diagnostics if Mixfile fails to load
      {status, diagnostics} =
        case Kernel.ParallelCompiler.compile([mixfile]) do
          {:ok, _, warnings} ->
            {:ok, Enum.map(warnings, &Diagnostics.mixfile_diagnostic(&1, :warning))}

          {:error, errors, warnings} ->
            {
              :error,
              Enum.map(warnings, &Diagnostics.mixfile_diagnostic(&1, :warning)) ++
                Enum.map(errors, &Diagnostics.mixfile_diagnostic(&1, :error))
            }
        end

      if status == :ok do
        # The project may override our logger config, so we reset it after loading their config
        logger_config = Application.get_all_env(:logger)
        Mix.Task.run("loadconfig")
        Application.put_all_env([logger: logger_config], persistent: true)
      end

      {status, diagnostics}
    else
      msg =
        "No mixfile found in project. " <>
          "To use a subdirectory, set `elixirLS.projectDir` in your settings"

      Logger.warn(msg <> ". Looked for mixfile at #{inspect(mixfile)}")

      :no_mixfile
    end
  end

  defp run_mix_compile do
    # TODO consider adding --no-compile
    case Mix.Task.run("compile", ["--return-errors", "--ignore-module-conflict"]) do
      {status, diagnostics} when status in [:ok, :error, :noop] and is_list(diagnostics) ->
        {status, diagnostics}

      status when status in [:ok, :noop] ->
        {status, []}

      _ ->
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
      {:error, :clean_failed}
    end
  end

  defp purge_consolidated_protocols do
    config = Mix.Project.config()
    path = Mix.Project.consolidation_path(config)

    with {:ok, beams} <- File.ls(path) do
      Enum.map(beams, &(&1 |> Path.rootname(".beam") |> String.to_atom() |> purge_module()))
    else
      {:error, :enoent} ->
        # consolidation_path does not exist
        :ok

      {:error, reason} ->
        Logger.warn("Unable to purge consolidated protocols from #{path}: #{inspect(reason)}")
    end

    # NOTE this implementation is based on https://github.com/phoenixframework/phoenix/commit/b5580e9
    # calling `Code.delete_path(path)` may be unnecessary in our case
    Code.delete_path(path)
  end

  defp purge_module(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp cached_deps do
    try do
      # FIXME: Private API
      Mix.Dep.cached()
    rescue
      e ->
        Logger.warn("Mix.Dep.cached() failed: #{inspect(e.__struct__)} #{Exception.message(e)}")
        []
    end
  end

  defp purge_app(app) do
    # TODO use hack with ets
    modules =
      case :application.get_key(app, :modules) do
        {:ok, modules} -> modules
        _ -> []
      end

    if modules != [] do
      Logger.debug("Purging #{length(modules)} modules from #{app}")
      for module <- modules, do: purge_module(module)
    end

    Logger.debug("Unloading #{app}")

    case Application.stop(app) do
      :ok -> :ok
      {:error, :not_started} -> :ok
      {:error, error} -> Logger.error("Application.stop failed for #{app}: #{inspect(error)}")
    end

    case Application.unload(app) do
      :ok -> :ok
      {:error, error} -> Logger.error("Application.unload failed for #{app}: #{inspect(error)}")
    end

    # Code.delete_path()
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

  defp maybe_purge_dep(
         %Mix.Dep{status: status, app: app, deps: deps, requirement: requirement} = dep
       ) do
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

    removed_deps = cached_deps_by_app |> Map.take(removed_apps)

    for {_app, deps} <- removed_deps,
        dep <- deps do
      purge_dep(dep)
    end

    for dep <- current_deps do
      maybe_purge_dep(dep)
    end
  end

  defp fetch_deps(current_deps) do
    # FIXME: private struct
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
      # FIXME: Private struct
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
      parser_options
      |> Keyword.merge(
        columns: true,
        token_metadata: true
      )

    options =
      options
      |> Keyword.merge(
        tracers: [Tracer],
        parser_options: parser_options
      )

    Code.compiler_options(options)
  end

  defp read_cached_deps() do
    if project = Mix.Project.get() do
      env_target = {Mix.env(), Mix.target()}

      case Mix.State.read_cache({:cached_deps, project}) do
        {^env_target, deps} -> deps
        _ -> nil
      end
    end
  end
end
