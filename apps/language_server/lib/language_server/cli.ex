defmodule ElixirLS.LanguageServer.CLI do
  
  def main(_args) do
    Mix.Local.append_archives
    Mix.Local.append_paths
    :timer.sleep(:infinity)
  end
end