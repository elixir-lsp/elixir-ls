defmodule ElixirLS.LanguageServer.MixProjectCache do
  @moduledoc """
  This module serves as a caching layer guaranteeing a safe access to Mix.Project functions. Note that
  Mix.Project functions cannot be safely called during a build as dep mix projects are being pushed and
  popped
  """
  use GenServer
  alias ElixirLS.LanguageServer.JsonRpc
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def store(state) do
    GenServer.call(__MODULE__, {:store, state})
  end

  def loaded? do
    GenServer.call(__MODULE__, :loaded?)
  end

  @spec get() :: {:ok, module | nil} | {:error, :not_loaded}
  def get do
    GenServer.call(__MODULE__, {:get, :get})
  end

  @spec get!() :: module
  def get! do
    case get() do
      {:ok, project} when not is_nil(project) -> project
      _ -> raise Mix.NoProjectError, []
    end
  end

  @spec project_file() :: {:ok, binary | nil} | {:error, :not_loaded}
  def project_file() do
    GenServer.call(__MODULE__, {:get, :project_file})
  end

  # @doc since: "1.15.0"
  # @spec parent_umbrella_project_file() :: binary | nil
  # defdelegate parent_umbrella_project_file(), to: Mix.ProjectStack

  @spec config() :: {:ok, keyword} | {:error, :not_loaded}
  def config do
    GenServer.call(__MODULE__, {:get, :config})
  end

  @spec config_files() :: {:ok, [Path.t()]} | {:error, :not_loaded}
  def config_files do
    GenServer.call(__MODULE__, {:get, :config_files})
  end

  @spec config_mtime() :: {:ok, posix_mtime} | {:error, :not_loaded} when posix_mtime: integer()
  def config_mtime do
    GenServer.call(__MODULE__, {:get, :config_mtime})
  end

  @spec umbrella?() :: {:ok, boolean} | {:error, :not_loaded}
  def umbrella?() do
    GenServer.call(__MODULE__, {:get, :umbrella?})
  end

  @spec apps_paths() :: {:ok, %{optional(atom) => Path.t()} | nil} | {:error, :not_loaded}
  def apps_paths() do
    GenServer.call(__MODULE__, {:get, :apps_paths})
  end

  @spec deps_path() :: {:ok, Path.t()} | {:error, :not_loaded}
  def deps_path() do
    GenServer.call(__MODULE__, {:get, :deps_path})
  end

  @spec deps_apps() :: {:ok, [atom()]} | {:error, :not_loaded}
  def deps_apps() do
    GenServer.call(__MODULE__, {:get, :deps_apps})
  end

  @spec deps_scms() :: {:ok, %{optional(atom) => Mix.SCM.t()}} | {:error, :not_loaded}
  def deps_scms() do
    GenServer.call(__MODULE__, {:get, :deps_scms})
  end

  @spec deps_paths() :: {:ok, %{optional(atom) => Path.t()}} | {:error, :not_loaded}
  def deps_paths() do
    GenServer.call(__MODULE__, {:get, :deps_paths})
  end

  # @doc since: "1.15.0"
  # @spec deps_tree(keyword) :: %{optional(atom) => [atom]}
  # def deps_tree(opts \\ []) when is_list(opts) do
  #   traverse_deps(opts, fn %{deps: deps} -> Enum.map(deps, & &1.app) end)
  # end

  @spec build_path() :: {:ok, Path.t()} | {:error, :not_loaded}
  def build_path() do
    GenServer.call(__MODULE__, {:get, :build_path})
  end

  @spec manifest_path() :: {:ok, Path.t()} | {:error, :not_loaded}
  def manifest_path() do
    GenServer.call(__MODULE__, {:get, :manifest_path})
  end

  @spec app_path() :: {:ok, Path.t()} | {:error, :not_loaded}
  def app_path() do
    {:ok, config} = config()

    config[:deps_app_path] ||
      cond do
        app = config[:app] ->
          {:ok, build_path} = build_path()
          Path.join([build_path, "lib", Atom.to_string(app)])

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

  @spec compile_path() :: {:ok, Path.t()} | {:error, :not_loaded}
  def compile_path() do
    with {:ok, app_path} <- app_path() do
      {:ok, Path.join(app_path, "ebin")}
    end
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

        Logger.info("Terminating #{__MODULE__}: #{message}")
    end

    :ok
  end

  @impl GenServer
  def handle_call({:get, _key}, _from, nil = state) do
    {:reply, {:error, :not_loaded}, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, {:ok, Map.fetch!(state, key)}, state}
  end

  def handle_call({:store, state}, _from, _state) do
    {:reply, :ok, state}
  end

  def handle_call(:loaded?, _from, state) do
    {:reply, is_map(state), state}
  end
end
