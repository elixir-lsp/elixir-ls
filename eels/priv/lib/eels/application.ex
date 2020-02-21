defmodule Eels.Application do
  use Application

  def start(_type, _args) do
    IO.puts("Starting EELS application")
    {:ok, self()}
  end
end
