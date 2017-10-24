defmodule Mix.Tasks.Release do
  @switches [destination: :string]
  @aliases [o: :destination]

  def run(args) do
    version_warning()
    {opts, _} = OptionParser.parse!(args, aliases: @aliases, switches: @switches)
    destination = opts[:destination] || "release"

    Path.join(destination, "*.ez")
    |> Path.wildcard()
    |> Enum.each(&File.rm(&1))

    Mix.Task.run("archive.build.deps", [
      "--skip",
      "mix_task_archive_deps",
      "--destination",
      destination
    ])
  end

  defp version_warning do
    {otp_version, _} = Integer.parse(to_string(:erlang.system_info(:otp_release)))

    if otp_version > 19 do
      IO.warn(
        "Building with Erlang/OTP #{otp_version}. Make sure to build with OTP 19 if " <>
          "publishing the compiled packages because modules built with higher versions are not " <>
          "backwards-compatible.",
        []
      )
    end
  end
end
