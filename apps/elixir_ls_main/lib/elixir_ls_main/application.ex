defmodule ElixirLsMain.Application do
  use Application

  def start(_type, _args) do
    task_mod = if System.get_env("ELS_STARTUP_TYPE") == "debugger" do
      ElixirLS.Debugger.CLI
    else
      ElixlrLS.LanguageServer.CLI
    end
    Task.start_link(&task_mod.main/0)
  end
end
