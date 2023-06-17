defmodule ElixirLS.Shell.Quiet do
  @moduledoc false

  @behaviour Mix.Shell

  @impl true
  def print_app() do
    if name = Mix.Shell.printable_app_name() do
      IO.puts(:stderr, "==> #{name}")
    end

    :ok
  end

  @impl true
  def info(message) do
    print_app()
    IO.puts(:stderr, IO.ANSI.format(message))
  end

  @impl true
  def error(message) do
    print_app()
    IO.puts(:stderr, IO.ANSI.format(message))
  end

  @impl true
  def prompt(message) do
    print_app()
    IO.puts(:stderr, IO.ANSI.format(message))
    raise "Mix.Shell.prompt is not supported at this time"
  end

  @impl true
  def yes?(message, options \\ []) do
    default = Keyword.get(options, :default, :yes)

    unless default in [:yes, :no] do
      raise ArgumentError,
            "expected :default to be either :yes or :no, got: #{inspect(default)}"
    end

    IO.puts(:stderr, IO.ANSI.format(message))

    default == :yes
  end

  @impl true
  def cmd(command, opts \\ []) do
    print_app? = Keyword.get(opts, :print_app, true)

    Mix.Shell.cmd(command, opts, fn data ->
      if print_app?, do: print_app()
      IO.write(:stderr, data)
    end)
  end
end

defmodule ElixirLS.Installer do
  defp local_dir, do: Path.expand("#{__DIR__}/..")

  defp run_mix_install({:local, dir}, force?) do
    Mix.install(
      [
        {:elixir_ls, path: dir},
      ],
      force: force?,
      consolidate_protocols: false,
      config_path: Path.join(dir, "config/config.exs"),
      lockfile: Path.join(dir, "mix.lock")
    )
  end

  defp run_mix_install({:tag, tag}, force?) do
    Mix.install([
        {:elixir_ls, github: "elixir-lsp/elixir-ls", tag: tag}
      ],
      force: force?,
      consolidate_protocols: false
    )
  end

  defp local? do
    System.get_env("ELS_LOCAL") == "1"
  end

  defp get_release do
    version = Path.expand("#{__DIR__}/VERSION")
    |> File.read!()
    |> String.trim()
    {:tag, "v#{version}"}
  end

  def install(force?) do
    if local?() do
      dir = local_dir()
      IO.puts(:stderr, "Installing local ElixirLS from #{dir}")
      IO.puts(:stderr, "Running in #{File.cwd!}")
      
      run_mix_install({:local, dir}, force?)
    else
      {:tag, tag} = get_release()
      IO.puts(:stderr, "Installing ElixirLS release #{tag}")
      IO.puts(:stderr, "Running in #{File.cwd!}")
      
      run_mix_install({:tag, tag}, force?)
    end
    IO.puts(:stderr, "Install complete")
  end

  def install_for_launch do
    if local?() do
      dir = Path.expand("#{__DIR__}/..")
      run_mix_install({:local, dir}, false)
    else
      run_mix_install(get_release(), false)
    end
  end

  def install_with_retry do
    try do
      install(false)
    catch
      kind, error ->
        IO.puts(:stderr, "Mix.install failed with #{Exception.format(kind, error, __STACKTRACE__)}")
        IO.puts(:stderr, "Retrying Mix.install with force: true")
        install(true)
    end
  end
end
