defmodule ElixirLS.LanguageServer.Project do
  use GenServer

  alias ElixirLS.LanguageServer.{Build, JsonRpc}

  @timeout :infinity

  # Client APIs

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, :ok, name: name || __MODULE__)
  end

  def reload(server \\ __MODULE__) do
    GenServer.call(server, :reload, @timeout)
  end

  def formatter_opts_for_file(server \\ __MODULE__, path) do
    GenServer.call(server, {:formatter_opts, path}, @timeout)
  end

  # Callbacks

  @impl GenServer
  def init(:ok) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call(:reload, _from, state) do
    {:reply, reload_project(), state}
  end

  @impl GenServer
  def handle_call({:formatter_opts, path}, _from, state) do
    {:reply, formatter_opts(path), state}
  end

  # Internals

  defp reload_project do
    mixfile = Path.absname(System.get_env("MIX_EXS") || "mix.exs")

    if File.exists?(mixfile) do
      # FIXME: Private API
      case Mix.ProjectStack.peek() do
        %{file: ^mixfile, name: module} ->
          # FIXME: Private API
          Mix.Project.pop()
          Build.purge_module(module)

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
            {:ok, Enum.map(warnings, &Build.mixfile_diagnostic(&1, :warning))}

          {:error, errors, warnings} ->
            {
              :error,
              Enum.map(warnings, &Build.mixfile_diagnostic(&1, :warning)) ++
                Enum.map(errors, &Build.mixfile_diagnostic(&1, :error))
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

  defp formatter_opts(path) do
    try do
      opts =
        path
        |> Mix.Tasks.Format.formatter_opts_for_file()

      {:ok, opts}
    rescue
      e ->
        IO.warn(
          "Unable to get formatter options for #{path}: #{inspect(e.__struct__)} #{e.message}"
        )

        :error
    end
  end
end
