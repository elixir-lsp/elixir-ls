defmodule Mix.Tasks.ElixirLs.Release do
  use Mix.Task

  @switches [destination: :string, zip: :string]
  @aliases [o: :destination, z: :zip]

  @impl Mix.Task
  def run(args) do
    version_warning()
    {opts, _} = OptionParser.parse!(args, aliases: @aliases, switches: @switches)
    destination = Path.expand(opts[:destination] || "release")

    Path.join(destination, "*.ez")
    |> Path.wildcard()
    |> Enum.each(&File.rm(&1))

    Mix.Task.run("archive.build.deps", [
      "--skip",
      "mix_task_archive_deps",
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

  defp version_warning do
    {otp_version, _} = Integer.parse(to_string(:erlang.system_info(:otp_release)))

    if otp_version > 21 do
      IO.warn(
        "Building with Erlang/OTP #{otp_version}. Make sure to build with OTP 21 if " <>
          "publishing the compiled packages because modules built with higher versions are not " <>
          "backwards-compatible.",
        []
      )
    end
  end
end
