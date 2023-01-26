defmodule ElixirLS.LanguageServer.Experimental.Provider.Queue.Supervisor do
  def name do
    __MODULE__
  end

  def child_spec do
    {Task.Supervisor, name: name()}
  end

  def run_in_task(provider_fn) do
    name()
    |> Task.Supervisor.async(provider_fn)
    |> unlink()
  end

  defp unlink(%Task{} = task) do
    Process.unlink(task.pid)
    task
  end
end
