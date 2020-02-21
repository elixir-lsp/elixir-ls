defmodule Eels.Application do
  use Application

  def start(_type, _args) do
    IO.puts("Starting EELS application")
  end

  def start() do
    IO.puts("Starting EELS application")
  end
end
