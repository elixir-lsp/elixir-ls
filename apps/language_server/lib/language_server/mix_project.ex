defmodule ElixirLS.LanguageServer.MixProject do
  @moduledoc """
  This module serves as a caching layer guarantying a safe access to Mix.Project functions. Note that
  Mix.Project functions cannot be safely called during a build as dep mix projects are being pushed and
  popped
  """
  use GenServer
  alias ElixirLS.LanguageServer.JsonRpc
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def store do
    GenServer.call(__MODULE__, :store)
  end

  def loaded? do
    GenServer.call(__MODULE__, :loaded?)
  end

  @spec get() :: module | nil
  def get do
    GenServer.call(__MODULE__, {:get, :get})
  end

  @spec get!() :: module
  def get! do
    get() || raise Mix.NoProjectError, []
  end

  @spec project_file() :: binary | nil
  def project_file() do
    GenServer.call(__MODULE__, {:get, :project_file})
  end

  # @doc since: "1.15.0"
  # @spec parent_umbrella_project_file() :: binary | nil
  # defdelegate parent_umbrella_project_file(), to: Mix.ProjectStack

  @spec config() :: keyword
  def config do
    GenServer.call(__MODULE__, {:get, :config})
  end

  @spec config_files() :: [Path.t()]
  def config_files do
    GenServer.call(__MODULE__, {:get, :config_files})
  end

  @spec config_mtime() :: posix_mtime when posix_mtime: integer()
  def config_mtime do
    GenServer.call(__MODULE__, {:get, :config_mtime})
  end

  @spec umbrella?() :: boolean
  def umbrella?() do
    GenServer.call(__MODULE__, {:get, :umbrella?})
  end

  @spec apps_paths() :: %{optional(atom) => Path.t()} | nil
  def apps_paths() do
    GenServer.call(__MODULE__, {:get, :apps_paths})
  end

  @spec deps_path() :: Path.t()
  def deps_path() do
    GenServer.call(__MODULE__, {:get, :deps_path})
  end

  @spec deps_apps() :: [atom()]
  def deps_apps() do
    GenServer.call(__MODULE__, {:get, :deps_apps})
  end

  @spec deps_scms() :: %{optional(atom) => Mix.SCM.t()}
  def deps_scms() do
    GenServer.call(__MODULE__, {:get, :deps_scms})
  end

  @spec deps_paths() :: %{optional(atom) => Path.t()}
  def deps_paths() do
    GenServer.call(__MODULE__, {:get, :deps_paths})
  end

  # @doc since: "1.15.0"
  # @spec deps_tree(keyword) :: %{optional(atom) => [atom]}
  # def deps_tree(opts \\ []) when is_list(opts) do
  #   traverse_deps(opts, fn %{deps: deps} -> Enum.map(deps, & &1.app) end)
  # end

  @spec build_path() :: Path.t()
  def build_path() do
    GenServer.call(__MODULE__, {:get, :build_path})
  end

  @spec manifest_path() :: Path.t()
  def manifest_path() do
    GenServer.call(__MODULE__, {:get, :manifest_path})
  end

  @spec app_path() :: Path.t()
  def app_path() do
    config = config()

    config[:deps_app_path] ||
      cond do
        app = config[:app] ->
          Path.join([build_path(), "lib", Atom.to_string(app)])

        config[:apps_path] ->
          raise "trying to access Mix.Project.app_path/1 for an umbrella project but umbrellas have no app"

        true ->
          Mix.raise(
            "Cannot access build without an application name, " <>
              "please ensure you are in a directory with a mix.exs file and it defines " <>
              "an :app name under the project configuration"
          )
      end
  end

  @spec compile_path() :: Path.t()
  def compile_path() do
    Path.join(app_path(), "ebin")
  end

  # @spec consolidation_path() :: Path.t()
  # def consolidation_path() do
  #   GenServer.call(__MODULE__, {:get, :consolidation_path})
  # end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def terminate(reason, _state) do
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

    :ok
  end

  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.fetch!(state, key), state}
  end

  def handle_call(:store, _from, _state) do
    state = %{
      get: Mix.Project.get(),
      project_file: Mix.Project.project_file(),
      config: Mix.Project.config(),
      config_files: Mix.Project.config_files(),
      config_mtime: Mix.Project.config_mtime(),
      umbrella?: Mix.Project.umbrella?(),
      apps_paths: Mix.Project.apps_paths(),
      deps_path: Mix.Project.deps_path(),
      deps_apps: Mix.Project.deps_apps(),
      deps_scms: Mix.Project.deps_scms(),
      deps_paths: Mix.Project.deps_paths(),
      build_path: Mix.Project.build_path(),
      manifest_path: Mix.Project.manifest_path()
    }

    {:reply, :ok, state}
  end

  def handle_call(:loaded?, _from, state) do
    {:reply, is_map(state), state}
  end
end
