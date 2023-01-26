defmodule ElixirLS.LanguageServer.Experimental.Supervisor do
  alias ElixirLS.LanguageServer.Experimental
  alias ElixirLS.LanguageServer.Experimental.Provider
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_) do
    children = [
      Experimental.SourceFile.Store,
      Experimental.Server,
      Provider.Queue.Supervisor.child_spec(),
      Provider.Queue.child_spec()
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
