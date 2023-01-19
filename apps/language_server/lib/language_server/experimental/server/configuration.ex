defmodule ElixirLS.LanguageServer.Experimental.Server.Configuration do
  alias ElixirLS.LanguageServer.Dialyzer
  alias ElixirLS.LanguageServer.Experimental.LanguageServer
  alias ElixirLS.LanguageServer.Experimental.Project
  alias ElixirLS.LanguageServer.Experimental.Protocol.Id
  alias ElixirLS.LanguageServer.Experimental.Protocol.Notifications.DidChangeConfiguration
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.LspTypes.Registration
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests
  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.RegisterCapability
  alias ElixirLS.LanguageServer.Experimental.Server.Configuration.Support

  defstruct project: nil,
            support: nil,
            additional_watched_extensions: nil,
            dialyzer_enabled?: false

  @type t :: %__MODULE__{}

  @spec new(LanguageServer.uri(), map()) :: t
  def new(root_uri, client_capabilities) do
    support = Support.new(client_capabilities)
    project = Project.new(root_uri)
    %__MODULE__{support: support, project: project}
  end

  @spec default(t) ::
          {:ok, t}
          | {:ok, t, Requests.RegisterCapability.t()}
          | {:restart, Logger.level(), String.t()}
          | {:error, String.t()}
  def default(%__MODULE__{} = config) do
    apply_config_change(config, default_config())
  end

  @spec on_change(t, DidChangeConfiguration.t()) ::
          {:ok, t}
          | {:ok, t, Requests.RegisterCapability.t()}
          | {:restart, Logger.level(), String.t()}
          | {:error, String.t()}
  def on_change(%__MODULE__{} = old_config, :defaults) do
    apply_config_change(old_config, default_config())
  end

  def on_change(%__MODULE__{} = old_config, %DidChangeConfiguration{} = change) do
    apply_config_change(old_config, change.lsp.settings)
  end

  defp default_config do
    %{}
  end

  defp apply_config_change(%__MODULE__{} = old_config, %{} = settings) do
    with {:ok, new_config} <- maybe_set_mix_env(old_config, settings),
         {:ok, new_config} <- maybe_set_env_vars(new_config, settings),
         {:ok, new_config} <- maybe_set_mix_target(new_config, settings),
         {:ok, new_config} <- maybe_set_project_directory(new_config, settings),
         {:ok, new_config} <- maybe_enable_dialyzer(new_config, settings) do
      maybe_add_watched_extensions(new_config, settings)
    end
  end

  defp maybe_set_mix_env(%__MODULE__{} = old_config, settings) do
    new_env = Map.get(settings, "mixEnv")

    with {:ok, new_project} <- Project.change_mix_env(old_config.project, new_env) do
      {:ok, %__MODULE__{old_config | project: new_project}}
    end
  end

  defp maybe_set_env_vars(%__MODULE__{} = old_config, settings) do
    env_vars = Map.get(settings, "envVariables")

    with {:ok, new_project} <- Project.set_env_vars(old_config.project, env_vars) do
      {:ok, %__MODULE__{old_config | project: new_project}}
    end
  end

  defp maybe_set_mix_target(%__MODULE__{} = old_config, settings) do
    mix_target = Map.get(settings, "mixTarget")

    with {:ok, new_project} <- Project.change_mix_target(old_config.project, mix_target) do
      {:ok, %__MODULE__{old_config | project: new_project}}
    end
  end

  defp maybe_set_project_directory(%__MODULE__{} = old_config, settings) do
    project_dir = Map.get(settings, "projectDir")

    with {:ok, new_project} <- Project.change_project_directory(old_config.project, project_dir) do
      {:ok, %__MODULE__{old_config | project: new_project}}
    end
  end

  defp maybe_enable_dialyzer(%__MODULE__{} = old_config, settings) do
    enabled? =
      case Dialyzer.check_support() do
        :ok ->
          Map.get(settings, "dialyzerEnabled", true)

        _ ->
          false
      end

    {:ok, %__MODULE__{old_config | dialyzer_enabled?: enabled?}}
  end

  defp maybe_add_watched_extensions(%__MODULE__{} = old_config, %{
         "additionalWatchedExtensions" => []
       }) do
    {:ok, old_config}
  end

  defp maybe_add_watched_extensions(%__MODULE__{} = old_config, %{
         "additionalWatchedExtensions" => extensions
       })
       when is_list(extensions) do
    register_id = Id.next()
    request_id = Id.next()

    watchers = Enum.map(extensions, fn ext -> %{"globPattern" => "**/*#{ext}"} end)

    registration =
      Registration.new(
        id: request_id,
        method: "workspace/didChangeWatchedFiles",
        register_options: %{"watchers" => watchers}
      )

    request = RegisterCapability.new(id: register_id, registrations: [registration])

    {:ok, old_config, request}
  end

  defp maybe_add_watched_extensions(%__MODULE__{} = old_config, _) do
    {:ok, old_config}
  end
end
