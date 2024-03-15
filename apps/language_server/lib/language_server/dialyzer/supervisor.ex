defmodule ElixirLS.LanguageServer.Dialyzer.Supervisor do
  alias ElixirLS.LanguageServer.{Dialyzer, DialyzerIncremental}
  use Supervisor

  def start_link(parent \\ self(), root_path) do
    Supervisor.start_link(__MODULE__, {parent, root_path})
  end

  @impl Supervisor
  def init({parent, root_path}) do
    Supervisor.init(
      [
        {Dialyzer, {parent, root_path}},
        {DialyzerIncremental, {parent, root_path}}
      ],
      strategy: :one_for_one
    )
  end
end
