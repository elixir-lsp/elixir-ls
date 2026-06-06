defmodule ElixirLS.LanguageServer.Dialyzer.Supervisor do
  use Supervisor

  alias ElixirLS.LanguageServer.DialyzerIncremental

  def start_link(parent \\ self(), name \\ nil, root_path) do
    Supervisor.start_link(__MODULE__, {parent, root_path}, name: name || __MODULE__)
  end

  @impl Supervisor
  def init({parent, root_path}) do
    Supervisor.init(
      [
        {DialyzerIncremental, {parent, root_path}}
      ],
      strategy: :one_for_one
    )
  end
end
