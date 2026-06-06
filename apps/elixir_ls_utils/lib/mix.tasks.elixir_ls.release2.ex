defmodule Mix.Tasks.ElixirLs.Release2 do
  use Mix.Task

  @switches [destination: :string, local: :boolean]
  @aliases [o: :destination, l: :local]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, aliases: @aliases, switches: @switches)
    destination = Path.expand(opts[:destination] || "release")

    File.mkdir_p!(destination)

    "./scripts"
    |> File.ls!()
    |> Enum.each(fn entry ->
      File.cp_r!(Path.join("./scripts", entry), Path.join(destination, entry))
    end)

    unless opts[:local] do
      File.cp!("./VERSION", Path.join(destination, "VERSION"))
    end

    :ok
  end
end
