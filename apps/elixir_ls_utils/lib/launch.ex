defmodule ElixirLS.Utils.Launch do
  @compiled_elixir_version System.version()
  @compiled_otp_version System.otp_release()

  def start_mix do
    Mix.start()
    Mix.Local.append_archives()
    Mix.Local.append_paths()
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

    # as of 1.14 mix supports two environment variables MIX_QUIET and MIX_DEBUG
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

  def load_mix_exs() do
    file = ElixirLS.Utils.MixfileHelpers.mix_exs()

    if File.regular?(file) do
      # TODO elixir 1.15 calls
      # Mix.ProjectStack.post_config(state_loader: {:cli, List.first(args)})
      # added in https://github.com/elixir-lang/elixir/commit/9e07da862784ac7d18a1884141c49ab049e61691
      # def cli
      # do we need that?
      old_undefined = Code.get_compiler_option(:no_warn_undefined)
      Code.put_compiler_option(:no_warn_undefined, :all)
      Code.compile_file(file)
      Code.put_compiler_option(:no_warn_undefined, old_undefined)
    end
  end

  # TODO add support for def cli
  def get_task(["-" <> _ | _]) do
    task = "mix #{Mix.Project.config()[:default_task]}"

    Mix.shell().error(
      "** (Mix) Mix only recognizes the options --help and --version.\n" <>
        "You may have wanted to invoke a task instead, such as #{inspect(task)}"
    )

    display_usage()
    exit({:shutdown, 1})
  end

  def get_task([h | t]) do
    {h, t}
  end

  def get_task([]) do
    case Mix.Project.get() do
      nil ->
        Mix.shell().error(
          "** (Mix) \"mix\" with no arguments must be executed in a directory with a mix.exs file"
        )

        display_usage()
        exit({:shutdown, 1})

      _ ->
        {Mix.Project.config()[:default_task], []}
    end
  end

  def maybe_change_env_and_target(task) do
    task = String.to_atom(task)
    config = Mix.Project.config()

    env = preferred_cli_env(task, config)
    target = preferred_cli_target(task, config)
    env && Mix.env(env)
    target && Mix.target(target)

    if env || target do
      reload_project()
    end
  end

  defp reload_project() do
    if project = Mix.Project.pop() do
      %{name: name, file: file} = project
      Mix.Project.push(name, file)
    end
  end

  defp preferred_cli_env(task, config) do
    if System.get_env("MIX_ENV") do
      nil
    else
      config[:preferred_cli_env][task] || Mix.Task.preferred_cli_env(task)
    end
  end

  defp preferred_cli_target(task, config) do
    config[:preferred_cli_target][task]
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
end
