defmodule Mix.Tasks.ElixirLs.Release2 do
  use Mix.Task

  @switches [destination: :string, local: :boolean]
  @aliases [o: :destination, l: :local]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, aliases: @aliases, switches: @switches)
    destination = Path.expand(opts[:destination] || "release")

    File.rm_rf!(destination)

    File.cp_r!("./scripts", destination)

    unless opts[:local] do
      File.cp!("./VERSION", Path.join(destination, "VERSION"))
    end

    :ok
  end
end
