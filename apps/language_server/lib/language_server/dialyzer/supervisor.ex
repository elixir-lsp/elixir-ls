defmodule ElixirLS.LanguageServer.Dialyzer.Supervisor do
  alias ElixirLS.LanguageServer.{Dialyzer, DialyzerIncremental}
  use Supervisor

  def start_link(parent \\ self(), name \\ nil, root_path, dialyzer_module) do
    Supervisor.start_link(__MODULE__, {parent, root_path, dialyzer_module},
      name: name || __MODULE__
    )
  end

  @impl Supervisor
  def init({parent, root_path, dialyzer_module}) do
    Supervisor.init(
      [
        {dialyzer_module, {parent, root_path}}
      ],
      strategy: :one_for_one
    )
  end
end
