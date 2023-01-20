defmodule ElixirLS.LanguageServer.Experimental.Provider.Env do
  @moduledoc """
  An environment passed to provider handlers.
  This represents the current state of the project, and should include additional
  information that provider handles might need to complete their tasks.
  """

  alias ElixirLS.LanguageServer.Experimental.Project
  alias ElixirLS.LanguageServer.Experimental.Server.Configuration

  defstruct [:root_uri, :root_path, :project_uri, :project_path]

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  def from_configuration(%Configuration{} = config) do
    %__MODULE__{
      root_uri: config.project.root_uri,
      root_path: Project.root_path(config.project),
      project_uri: config.project.root_uri,
      project_path: Project.project_path(config.project)
    }
  end
end
