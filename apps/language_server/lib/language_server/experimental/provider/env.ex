defmodule ElixirLS.LanguageServer.Experimental.Provider.Env do
  alias ElixirLS.LanguageServer.Experimental.Project
  alias ElixirLS.LanguageServer.Experimental.Server.Configuration
  alias ElixirLS.LanguageServer.SourceFile

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
