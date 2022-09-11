defmodule ElixirLS.LanguageServer.Build do
  alias ElixirLS.LanguageServer.{Server, JsonRpc, Diagnostics}
  alias ElixirLS.Utils.MixfileHelpers

  def build(parent, root_path, opts) when is_binary(root_path) do
    if Path.absname(File.cwd!()) != Path.absname(root_path) do
      IO.puts("Skipping build because cwd changed from #{root_path} to #{File.cwd!()}")
      {nil, nil}
    else
      spawn_monitor(fn ->
        with_build_lock(fn ->
          {us, _} =
            :timer.tc(fn ->
              IO.puts("MIX_ENV: #{Mix.env()}")
              IO.puts("MIX_TARGET: #{Mix.target()}")

              case reload_project() do
                {:ok, mixfile_diagnostics} ->
                  # FIXME: Private API
                  if Keyword.get(opts, :fetch_deps?) and
                       Mix.Dep.load_on_environment([]) != cached_deps() do
                    # NOTE: Clear deps cache when deps in mix.exs has change to prevent
                    # formatter crash from clearing deps during build.
                    :ok = Mix.Project.clear_deps_cache()
                    fetch_deps()
                  end

                  # if we won't do it elixir >= 1.11 warns that protocols have already been consolidated
                  purge_consolidated_protocols()
                  {status, diagnostics} = run_mix_compile()

                  diagnostics = Diagnostics.normalize(diagnostics, root_path)
                  Server.build_finished(parent, {status, mixfile_diagnostics ++ diagnostics})

                {:error, mixfile_diagnostics} ->
                  Server.build_finished(parent, {:error, mixfile_diagnostics})

                :no_mixfile ->
                  Server.build_finished(parent, {:no_mixfile, []})
              end
            end)

          JsonRpc.log_message(:info, "Compile took #{div(us, 1000)} milliseconds")
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

  defp reload_project do
    mixfile = Path.absname(MixfileHelpers.mix_exs())

    if File.exists?(mixfile) do
      # FIXME: Private API
      case Mix.ProjectStack.peek() do
        %{file: ^mixfile, name: module} ->
          # FIXME: Private API
          Mix.Project.pop()
          purge_module(module)

        _ ->
          :ok
      end

      Mix.Task.clear()

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

      JsonRpc.log_message(:info, msg <> ". Looked for mixfile at #{inspect(mixfile)}")

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
    opts = if clean_deps? do
      opts ++ ["--deps"]
    else
      opts
    end
    results = Mix.Task.run("clean", opts) |> List.wrap
    if Enum.all?(results, & match?(:ok, &1)) do
      :ok
    else
      JsonRpc.log_message(:error, "mix clean returned #{inspect(results)}")
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
        JsonRpc.log_message(
          :warning,
          "Unable to purge consolidated protocols from #{path}: #{inspect(reason)}"
        )
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
      _ ->
        []
    end
  end

  defp fetch_deps do
    # FIXME: Private API and struct
    missing_deps =
      Mix.Dep.load_on_environment([])
      |> Enum.filter(fn %Mix.Dep{status: status} ->
        case status do
          {:unavailable, _} -> true
          {:nomatchvsn, _} -> true
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
    end

    :ok
  end
end
