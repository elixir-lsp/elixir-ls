defmodule ElixirLS.Utils.Launch do
  @compiled_elixir_version System.version()
  @compiled_otp_version System.otp_release()

  def start_mix do
    if Version.match?(System.version(), "< 1.15.0-dev") do
      # since 1.15 Mix.start() calls append_archives() and append_paths()
      Mix.Local.append_archives()
      Mix.Local.append_paths()
    end

    Mix.start()
    
    true = Mix.Hex.ensure_installed?(false)
    # when running via mix install script mix starts and stops hex
    # we need to make sure it's started
    if function_exported?(Hex, :start, 0) do
      Hex.start()
    end

    # reset env and target if it is set
    Mix.env(:dev)
    Mix.target(:host)

    for env <- ["MIX_ENV", "MIX_TARGET"] do
      System.delete_env(env)
    end

    load_dot_config()

    # as of 1.15 mix supports two environment variables MIX_QUIET and MIX_DEBUG
    # that are not important for our use cases

    :ok
  end

  def get_versions do
    %{
      current_elixir_version: inspect(System.build_info()[:build]),
      current_otp_version: inspect(System.otp_release()),
      compile_elixir_version: inspect(@compiled_elixir_version),
      compile_otp_version: inspect(@compiled_otp_version)
    }
  end

  def language_server_version do
    get_version(:language_server)
  end

  def debugger_version do
    get_version(:elixir_ls_debugger)
  end

  def limit_num_schedulers do
    case System.schedulers_online() do
      num_schedulers when num_schedulers >= 4 ->
        :erlang.system_flag(:schedulers_online, num_schedulers - 2)

      _ ->
        :ok
    end
  end

  defp get_version(app) do
    case :application.get_key(app, :vsn) do
      {:ok, version} -> List.to_string(version)
      :undefined -> "dev"
    end
  end

  defp load_dot_config do
    path = Path.join(Mix.Utils.mix_home(), "config.exs")

    if File.regular?(path) do
      Mix.Task.run("loadconfig", [path])
    end
  end

  def load_mix_exs(args) do
    file = ElixirLS.Utils.MixfileHelpers.mix_exs()

    if File.regular?(file) do
      if Version.match?(System.version(), ">= 1.15.0-dev") do
        Mix.ProjectStack.post_config(state_loader: {:cli, List.first(args)})
      end

      old_undefined = Code.get_compiler_option(:no_warn_undefined)
      Code.put_compiler_option(:no_warn_undefined, :all)
      Code.compile_file(file)
      Code.put_compiler_option(:no_warn_undefined, old_undefined)
    end
  end

  def get_task(["-" <> _ | _], project) do
    task = "mix #{default_task(project)}"

    Mix.shell().error(
      "** (Mix) Mix only recognizes the options --help and --version.\n" <>
        "You may have wanted to invoke a task instead, such as #{inspect(task)}"
    )

    display_usage()
    exit({:shutdown, 1})
  end

  def get_task([h | t], _project) do
    {h, t}
  end

  def get_task([], nil) do
    Mix.shell().error(
      "** (Mix) \"mix\" with no arguments must be executed in a directory with a mix.exs file"
    )

    display_usage()
    exit({:shutdown, 1})
  end

  def get_task([], project) do
    {default_task(project), []}
  end

  defp default_task(project) do
    if function_exported?(project, :cli, 0) do
      project.cli()[:default_task] || "run"
    else
      # TODO: Deprecate default_task in v1.19
      Mix.Project.config()[:default_task] || "run"
    end
  end

  def maybe_change_env_and_target(task, project) do
    task = String.to_atom(task)
    config = Mix.Project.config()

    env = preferred_cli_env(project, task, config)
    target = preferred_cli_target(project, task, config)
    env && Mix.env(env)
    target && Mix.target(target)

    if env || target do
      reload_project()
    end
  end

  def preferred_cli_env(task) when is_atom(task) or is_binary(task) do
    case Mix.Task.get(task) do
      nil ->
        nil

      module ->
        case List.keyfind(module.__info__(:attributes), :preferred_cli_env, 0) do
          {:preferred_cli_env, [setting]} ->
            IO.warn(
              """
              setting @preferred_cli_env is deprecated inside Mix tasks.
              Please remove it from #{inspect(module)} and set your preferred environment in mix.exs instead:

                  def cli do
                    [
                      preferred_envs: [docs: "docs"]
                    ]
                  end
              """,
              []
            )

            setting

          _ ->
            nil
        end
    end
  end

  defp reload_project() do
    if project = Mix.Project.pop() do
      %{name: name, file: file} = project
      Mix.Project.push(name, file)
    end
  end

  # TODO: Deprecate preferred_cli_env in v1.19
  defp preferred_cli_env(project, task, config) do
    if function_exported?(project, :cli, 0) || System.get_env("MIX_ENV") do
      nil
    else
      config[:preferred_cli_env][task] || preferred_cli_env(task)
    end
  end

  # TODO: Deprecate preferred_cli_target in v1.19
  defp preferred_cli_target(project, task, config) do
    if function_exported?(project, :cli, 0) || System.get_env("MIX_TARGET") do
      nil
    else
      config[:preferred_cli_target][task]
    end
  end

  defp display_usage do
    Mix.shell().info("""
    Usage: mix [task]
    Examples:
        mix             - Invokes the default task (mix run) in a project
        mix new PATH    - Creates a new Elixir project at the given path
        mix help        - Lists all available tasks
        mix help TASK   - Prints documentation for a given task
    The --help and --version options can be given instead of a task for usage and versioning information.
    """)
  end

  defp from_env(varname, default) do
    case System.get_env(varname) do
      nil -> default
      "" -> default
      value -> String.to_atom(value)
    end
  end

  # this code is executed on Mix.State.init
  # since we start mix earlier with language server/debugger
  # we need to reinitialize Mix.State when env is loaded form client settings
  def reload_mix_env_and_target() do
    Mix.env(from_env("MIX_ENV", :dev))
    Mix.target(from_env("MIX_TARGET", :host))
  end
end
