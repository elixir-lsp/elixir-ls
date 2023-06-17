defmodule Mix.Tasks.ElixirLs.Release do
  use Mix.Task

  @switches [destination: :string, zip: :string]
  @aliases [o: :destination, z: :zip]

  @impl Mix.Task
  def run(args) do
    IO.warn("This task is deprecated. Consider switching to release2")
    {opts, _} = OptionParser.parse!(args, aliases: @aliases, switches: @switches)
    destination = Path.expand(opts[:destination] || "release")

    Path.join(destination, "*.ez")
    |> Path.wildcard()
    |> Enum.each(&File.rm(&1))

    Mix.Task.run("archive.build.deps", [
      "--skip",
      "mix_task_archive_deps stream_data",
      "--destination",
      destination
    ])

    # Copy launcher scripts
    Path.join([:code.priv_dir(:elixir_ls_utils), "*"])
    |> Path.wildcard()
    |> Enum.map(fn file ->
      dest_file = Path.join([destination, Path.basename(file)])
      File.cp!(file, dest_file)
    end)

    # If --zip <file> option is provided, package into a zip file
    if opts[:zip] do
      zip_file = to_charlist(Path.expand(opts[:zip]))
      files = Enum.map(File.ls!(destination), &to_charlist/1)
      {:ok, _} = :zip.create(zip_file, files, cwd: to_charlist(destination))
    end

    :ok
  end
end
